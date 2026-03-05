// lib/core/features/tablet/tablet_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../api_client.dart';
import '../../Services/device_config_service.dart';
import '../../services/heartbeat_service.dart';
import '../../services/remote_config_service.dart';

import '../../../data/local/local_seq_store.dart';
import '../../../data/local/punch_queue.dart';
import '../../../data/local/roster_cache.dart';
import '../../../data/local/status_cache.dart';
import '../../../data/local/punch_log_store.dart';

import '../../../data/models/punch.dart';
import '../../../data/models/status.dart';
import '../../../data/models/sync.dart';
import '../../../data/models/verify.dart';
import '../../../data/remote/timeclock_api.dart';

import '../../../widgets/logo_header.dart';

class TabletScreen extends StatefulWidget {
  const TabletScreen({super.key});

  @override
  State<TabletScreen> createState() => _TabletScreenState();
}

class _TabletScreenState extends State<TabletScreen> {
  // NOTE: These are created asynchronously now (pinned TLS)
  TimeClockApi? _api;
  HeartbeatService? _heartbeat;

  bool _ready = false;

  final _queue = PunchQueue();
  final _log = PunchLogStore();
  final _rosterCache = RosterCache();
  final _statusCache = StatusCache();
  final _connectivity = Connectivity();
  final _seqStore = LocalSeqStore();

  // Entry
  String _employeeNumber = "";
  bool _verifying = false;
  bool _punching = false;

  // Session
  bool _verified = false;
  String? _employeeGuid;
  String? _fullName;
  bool _clockedIn = false;

  String? _message;
  int _pendingCount = 0;

  // Device identifiers (Vista mapping NOT used)
  static const int deviceType = 1;

  // ✅ Meraki / deployment will set this in the device config box
  String get _deviceId => DeviceConfigService.deviceId;

  Timer? _clockTimer;
  Timer? _syncTimer;
  DateTime _now = DateTime.now();
  DateTime? _lastSyncAttemptLocal;

  // Special access codes
  static const String _adminServiceCode = "009876";
  static const String _adminPunchLogCode = "101010";

  // Phase 4: ValidateCode "Action" parameter
  static const String _validateActionPunch = "PUNCH";

  // ===== Server-down grace window (automatic failover) =====
  static const Duration _serverDownGrace = Duration(minutes: 2);
  DateTime? _serverDownUntilUtc;

  bool get _serverInGraceWindow {
    final until = _serverDownUntilUtc;
    if (until == null) return false;
    return DateTime.now().toUtc().isBefore(until);
  }

  void _markServerDown() {
    _serverDownUntilUtc = DateTime.now().toUtc().add(_serverDownGrace);
  }

  void _clearServerDown() {
    _serverDownUntilUtc = null;
  }

  @override
  void initState() {
    super.initState();
    _startClock();
    _refreshPending();
    _init(); // async pinned client init
  }

  Future<void> _init() async {
    try {
      // Create a pinned client so Android trusts the site certificate chain
      final client = await ApiClient.pinned(
        pemAssetPath: 'assets/certs/tsg_cert.pem',
        log: (m) => debugPrint(m),
        allowedHosts: const {'apply.tsg.bz', 'tcws.tsg.bz', 'tsg.bz'},
      );

      if (!mounted) return;

      final api = TimeClockApi(client);
      final hb = HeartbeatService(api: api);

      setState(() {
        _api = api;
        _heartbeat = hb;
        _ready = true;
      });

      // Start services that require _api
      await _warmupRoster();
      hb.start();

      _syncTimer =
          Timer.periodic(const Duration(seconds: 30), (_) => _trySync());
      _trySync();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = "Init failed: $e";
        _ready = false;
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _syncTimer?.cancel();
    _heartbeat?.stop();
    super.dispose();
  }

  // ===== Clock =====
  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  // ===== Keypad =====
  void _appendDigit(String digit) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_employeeNumber.length >= 6) return;
      _employeeNumber += digit;
    });
  }

  void _backspace() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_employeeNumber.isEmpty) return;
      _employeeNumber =
          _employeeNumber.substring(0, _employeeNumber.length - 1);
    });
  }

  void _clearEntry() {
    HapticFeedback.selectionClick();
    setState(() {
      _employeeNumber = "";
      _message = null;
    });
  }

  void _resetSession() {
    if (!mounted) return;
    setState(() {
      _employeeNumber = "";
      _verified = false;
      _employeeGuid = null;
      _fullName = null;
      _clockedIn = false;
      _message = null;
    });
  }

  // ===== Connectivity =====
  Future<bool> _isOnline({bool force = false}) async {
    if (!_ready || _api == null) return false;

    // If we recently detected server trouble, act offline for a short window
    // to avoid repeated pings / slow UX. "force" bypasses this (manual sync).
    if (!force && _serverInGraceWindow) return false;

    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none)) return false;

    try {
      await _api!.ping();
      _clearServerDown();
      return true;
    } catch (_) {
      _markServerDown();
      return false;
    }
  }

  Future<bool> _hasNetworkLink() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  // ===== Step 1: Warm roster cache from GetEmps =====
  Future<void> _warmupRoster() async {
    try {
      if (!_ready || _api == null) return;
      if (!await _isOnline()) return;
      final items = await _api!.rosterAll();
      final json = items.map((e) => e.toJson()).toList();
      await _rosterCache.saveAll(json);
    } catch (_) {}
  }

  // ===== Queue UI =====
  Future<void> _refreshPending() async {
    final c = await _queue.count();
    if (!mounted) return;
    setState(() => _pendingCount = c);
  }

  // ===== Sync =====
  Future<void> _trySync({bool forceOnline = false}) async {
    if (!_ready || _api == null) return;

    try {
      _lastSyncAttemptLocal = DateTime.now();

      if (!await _isOnline(force: forceOnline)) {
        if (forceOnline && mounted) {
          setState(() => _message =
          "Offline: cannot sync right now. (${_serverInGraceWindow ? "Server grace window" : "No connection"})");
        }
        return;
      }

      final pending = await _queue.allVerified();
      if (pending.isEmpty) return;

      final punches = pending.map((p) {
        final punchType = (p["punchType"] as num?)?.toInt() ?? 0;
        final localSeq = (p["localSequenceNumber"] as num?)?.toInt() ?? 0;

        final ts = (p["timestampUtc"] as String?) ??
            DateTime.now().toUtc().toIso8601String();

        return SyncPunch(
          employeeId: (p["employeeId"] as String?) ?? "",
          punchType: punchType,
          localSequenceNumber: localSeq,
          timestampUtc: DateTime.parse(ts),
          latitude: (p["latitude"] as num?)?.toDouble(),
          longitude: (p["longitude"] as num?)?.toDouble(),
        );
      }).toList();

      final batch = SyncPunchBatch(
        deviceId: _deviceId,
        deviceType: deviceType,
        punches: punches,
      );

      final result = await _api!.syncBatch(batch);

      await _queue.removeByLocalSeq(result.acceptedSeq.toSet());
      await _refreshPending();

      if (!mounted) return;
      setState(() => _message = "Synced ${result.processed} punch(es).");

      if (_employeeGuid != null && _employeeGuid!.trim().isNotEmpty) {
        await _loadStatus(_employeeGuid!);
      }
    } catch (_) {
      _markServerDown();
    }
  }

  // ===== Verify =====
  void _applyVerified(VerifyResponse res, {required String message}) {
    if (!mounted) return;
    setState(() {
      _verified = true;
      _employeeGuid = res.employeeId;
      _fullName = res.fullName;
      _clockedIn = res.isClockedIn;
      _message = message;
    });
  }

  Future<void> _verifyEmployee() async {
    if (!_ready || _api == null) {
      setState(() => _message = "Initializing… try again in a moment.");
      return;
    }

    final entry = _employeeNumber.trim();

    if (entry.isEmpty) {
      setState(() => _message = "Enter your Employee ID.");
      return;
    }

    // ✅ Admin screens MUST be accessible offline/online
    if (entry == _adminServiceCode) {
      _clearEntry();
      await _showServiceSettingsDialog();
      return;
    }

    if (entry == _adminPunchLogCode) {
      _clearEntry();
      await _showPunchLogDialog();
      return;
    }

    setState(() {
      _verifying = true;
      _message = null;
    });

    try {
      final online = await _isOnline();
      if (online) {
        await _warmupRoster();
      }

      final cached = await _rosterCache.findByEmployeeNumber(entry);
      if (cached == null) {
        if (mounted) setState(() => _message = "Invalid Employee ID.");
        return;
      }

      final cachedClockedIn =
          _statusCache.getIsClockedIn(cached.employeeId) ?? false;

      _applyVerified(
        VerifyResponse(
          isValid: true,
          employeeId: cached.employeeId,
          employeeNumber: cached.employeeNumber,
          fullName: cached.fullName,
          isClockedIn: cachedClockedIn,
        ),
        message: online ? "Verified." : "Verified (offline).",
      );

      await _statusCache.setIsClockedIn(cached.employeeId, cachedClockedIn);

      if (online) {
        await _loadStatus(cached.employeeId);
      }
    } catch (_) {
      if (mounted) setState(() => _message = "Verify failed.");
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  // ===== Status =====
  Future<void> _loadStatus(String guid) async {
    if (!_ready || _api == null) return;

    try {
      final StatusResponse s = await _api!.status(guid);
      if (!mounted) return;
      setState(() => _clockedIn = s.isClockedIn);
      await _statusCache.setIsClockedIn(guid, s.isClockedIn);
    } catch (_) {
      final cached = _statusCache.getIsClockedIn(guid);
      if (cached != null && mounted) {
        setState(() => _clockedIn = cached);
      }
    }
  }

  // ===== Location (warn-only) =====
  Future<Position?> _getBestEffortPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3),
      );
    } catch (_) {
      return null;
    }
  }

  // ===== Phase 4 helper: prompt + validate OTCode (ONLINE ONLY) =====
  Future<String?> _promptForOtCodeOnline() async {
    final ctrl = TextEditingController();

    return _showAppDialog<String?>(
      title: "Optional Site / OT Code",
      width: 560,
      dismissible: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "If your company requires a site/OT code for this punch, enter it now.\n\n"
                "Leave blank to punch normally.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          _darkTextField(
            controller: ctrl,
            label: "OT Code (optional)",
            hint: "",
            inputType: TextInputType.text,
            onSubmitted: (_) => Navigator.of(context).pop(ctrl.text.trim()),
          ),
        ],
      ),
      actions: [
        _dialogButton(
          label: "Cancel",
          filled: false,
          onTap: () => Navigator.of(context).pop(null),
        ),
        _dialogButton(
          label: "Continue",
          filled: true,
          onTap: () => Navigator.of(context).pop(ctrl.text.trim()),
        ),
      ],
    );
  }

  Future<bool> _validateOtCodeIfProvided(String otCode) async {
    if (!_ready || _api == null) return false;

    final code = otCode.trim();
    if (code.isEmpty) return true;

    final result = await _api!.validateCode(
      otCode: code,
      action: _validateActionPunch,
    );

    if (!result.ok) {
      if (!mounted) return false;
      setState(() => _message = "Invalid code: ${result.rawMessage}");
      return false;
    }

    return true;
  }

  Future<void> _writePunchLog({
    required String employeeId,
    required String employeeName,
    required int punchType,
    required int localSeq,
    required String timestampUtc,
    required double? lat,
    required double? lng,
    required String outcome, // ONLINE_OK / OFFLINE_QUEUED / ERROR_QUEUED / CANCELED / BLOCKED
  }) async {
    await _log.add({
      "timestampUtc": timestampUtc,
      "employeeId": employeeId,
      "employeeName": employeeName,
      "punchType": punchType,
      "status": (punchType == 0) ? "IN" : "OUT",
      "localSequenceNumber": localSeq,
      "latitude": lat,
      "longitude": lng,
      "outcome": outcome,
      "deviceId": _deviceId,
    });
  }

  // ===== Punch =====
  Future<void> _doPunch() async {
    if (!_ready || _api == null) {
      setState(() => _message = "Initializing… try again in a moment.");
      return;
    }

    if (!_verified || _employeeGuid == null || _employeeGuid!.trim().isEmpty) {
      setState(() => _message = "Verify first.");
      return;
    }

    setState(() {
      _punching = true;
      _message = null;
    });

    final punchType = _clockedIn ? 1 : 0;
    final seq = _seqStore.next();

    final nowUtc = DateTime.now().toUtc();
    final tsUtcNoMillis = _isoUtcNoMillis(nowUtc);

    // Best-effort GPS (warn-only)
    final pos = await _getBestEffortPosition();
    final lat = pos?.latitude;
    final lng = pos?.longitude;

    final queuedPayload = <String, dynamic>{
      "employeeId": _employeeGuid!,
      "punchType": punchType,
      "localSequenceNumber": seq,
      "timestampUtc": tsUtcNoMillis,
      "latitude": lat,
      "longitude": lng,
    };

    // optimistic UX
    final prevClockedIn = _clockedIn;
    final newClockedIn = (punchType == 0);

    setState(() {
      _clockedIn = newClockedIn;
      _message = (punchType == 0) ? "Clock In recorded." : "Clock Out recorded.";
    });
    await _statusCache.setIsClockedIn(_employeeGuid!, newClockedIn);

    Future<void> revertOptimistic(String msg) async {
      if (!mounted) return;
      setState(() {
        _clockedIn = prevClockedIn;
        _message = msg;
      });
      await _statusCache.setIsClockedIn(_employeeGuid!, prevClockedIn);
    }

    // Always log what the tablet is doing (your requirement)
    final nameForLog =
    (_fullName ?? "").trim().isEmpty ? "(unknown)" : _fullName!.trim();

    try {
      final online = await _isOnline();

      if (!online) {
        await _queue.enqueue(queuedPayload);
        await _refreshPending();

        await _writePunchLog(
          employeeId: _employeeGuid!,
          employeeName: nameForLog,
          punchType: punchType,
          localSeq: seq,
          timestampUtc: tsUtcNoMillis,
          lat: lat,
          lng: lng,
          outcome: "OFFLINE_QUEUED",
        );

        if (!mounted) return;
        setState(() {
          _message = "Offline: Punch queued ($_pendingCount pending)."
              "${pos == null ? " (Location unavailable)" : ""}"
              "${_serverInGraceWindow ? " (Server unreachable)" : ""}";
        });

        Future.delayed(const Duration(seconds: 2), _resetSession);
        return;
      }

      // Online: prompt OT code
      final otPrompt = await _promptForOtCodeOnline();

      if (otPrompt == null) {
        await _writePunchLog(
          employeeId: _employeeGuid!,
          employeeName: nameForLog,
          punchType: punchType,
          localSeq: seq,
          timestampUtc: tsUtcNoMillis,
          lat: lat,
          lng: lng,
          outcome: "CANCELED",
        );
        await revertOptimistic("Punch canceled.");
        return;
      }

      final otCode = otPrompt.trim();

      final ok = await _validateOtCodeIfProvided(otCode);
      if (!ok) {
        await _writePunchLog(
          employeeId: _employeeGuid!,
          employeeName: nameForLog,
          punchType: punchType,
          localSeq: seq,
          timestampUtc: tsUtcNoMillis,
          lat: lat,
          lng: lng,
          outcome: "BLOCKED",
        );
        await revertOptimistic("Punch blocked (invalid code).");
        return;
      }

      final s = await _api!.punchAndGetStatus(
        PunchRequest(
          employeeId: _employeeGuid!,
          punchType: punchType,
          deviceType: deviceType,
          deviceId: _deviceId,
          localSequenceNumber: seq,
          timestampUtc: nowUtc,
        ),
        otCode: otCode,
      );

      await _writePunchLog(
        employeeId: _employeeGuid!,
        employeeName: nameForLog,
        punchType: punchType,
        localSeq: seq,
        timestampUtc: tsUtcNoMillis,
        lat: lat,
        lng: lng,
        outcome: "ONLINE_OK",
      );

      if (!mounted) return;
      setState(() {
        _clockedIn = s.isClockedIn;
        _message = s.isClockedIn ? "You are now IN." : "You are now OUT.";
      });
      await _statusCache.setIsClockedIn(_employeeGuid!, s.isClockedIn);

      Future.delayed(const Duration(seconds: 2), _resetSession);
    } catch (_) {
      _markServerDown();

      await _queue.enqueue(queuedPayload);
      await _refreshPending();

      await _writePunchLog(
        employeeId: _employeeGuid!,
        employeeName: nameForLog,
        punchType: punchType,
        localSeq: seq,
        timestampUtc: tsUtcNoMillis,
        lat: lat,
        lng: lng,
        outcome: "ERROR_QUEUED",
      );

      if (!mounted) return;
      setState(() => _message =
      "Server unreachable: Punch queued ($_pendingCount pending).");

      Future.delayed(const Duration(seconds: 2), _resetSession);
    } finally {
      if (mounted) setState(() => _punching = false);
    }
  }

  // ===== Remote config sync stub =====
  Future<void> _syncConfig() async {
    final changed = await RemoteConfigService.trySync();
    if (!mounted) return;

    setState(() {
      _message =
      changed ? "Config updated." : "Config sync recorded (no backend yet).";
    });
  }

  // ===== Verify & Save helpers for 009876 =====
  String _extractSoapStringValue(String xmlText) {
    final m = RegExp(r'<string[^>]*>(.*?)</string>', dotAll: true)
        .firstMatch(xmlText);
    if (m == null) return '';
    final inner = m.group(1) ?? '';
    return inner
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  Future<({bool ok, String message})> _testServiceSettings({
    required String baseUrl,
    required String authToken,
  }) async {
    final url = baseUrl.trim();
    final auth = authToken.trim();

    if (url.isEmpty) return (ok: false, message: "Base URL is required.");
    if (auth.isEmpty) return (ok: false, message: "Auth token is required.");

    if (!await _hasNetworkLink()) {
      return (ok: true, message: "Saved offline. Will verify when online.");
    }

    try {
      // IMPORTANT: use pinned client here too, otherwise Verify & Save will still fail.
      final client = await ApiClient.pinned(
        pemAssetPath: 'assets/certs/tsg_cert.pem',
        log: (m) => debugPrint(m),
        allowedHosts: const {'apply.tsg.bz', 'tcws.tsg.bz', 'tsg.bz'},
      );

      final xml = await client.postForm('$url/GetEmps', {'Auth': auth});
      final value = _extractSoapStringValue(xml);

      if (value.trim().isEmpty) {
        return (
        ok: false,
        message: "Server responded, but returned an empty value."
        );
      }

      final looksLikeHtml = value.toLowerCase().contains('<html') ||
          xml.toLowerCase().contains('<html');
      if (looksLikeHtml) {
        return (
        ok: false,
        message:
        "Endpoint looks wrong (HTML response). Check the .asmx path."
        );
      }

      return (ok: true, message: "Verified and saved.");
    } catch (e) {
      return (ok: false, message: "Verify failed: $e");
    }
  }

  // ===== Clean dialog framework (fade+scale transition) =====
  Future<T?> _showAppDialog<T>({
    required String title,
    required Widget content,
    required List<Widget> actions,
    double width = 680,
    bool dismissible = true,
  }) async {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierLabel: "dialog",
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, a1, a2) {
        final w = MediaQuery.of(ctx).size.width;
        final maxW = width.clamp(320.0, w - 40.0).toDouble();

        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: maxW,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: Icon(
                            Icons.close,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Flexible(child: content),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions
                          .map((w) => Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: w,
                      ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        final curve =
        CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  static Widget _dialogButton({
    required String label,
    required VoidCallback? onTap,
    required bool filled,
    bool busy = false,
  }) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:
          filled ? Colors.white : Colors.white.withValues(alpha: 0.10),
          foregroundColor: filled ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: Colors.white.withValues(alpha: filled ? 0.00 : 0.18),
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  static Widget _darkTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType inputType = TextInputType.text,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          BorderSide(color: Colors.white.withValues(alpha: 0.16), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          BorderSide(color: Colors.white.withValues(alpha: 0.30), width: 2),
        ),
      ),
    );
  }

  // ===== Service settings (via 009876 only) =====
  Future<void> _showServiceSettingsDialog() async {
    final urlCtrl = TextEditingController(text: DeviceConfigService.baseUrl);
    final authCtrl = TextEditingController(text: DeviceConfigService.authToken);

    bool busy = false;
    String? inlineStatus;
    String? inlineError;

    await _showAppDialog<void>(
      title: "Service Settings",
      width: 620,
      dismissible: true,
      content: StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget banner({required String text, required bool isError}) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: (isError ? Colors.red : Colors.green)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (isError ? Colors.red : Colors.green)
                      .withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.90),
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }

          Future<void> verifyAndSave() async {
            if (busy) return;

            setLocal(() {
              busy = true;
              inlineError = null;
              inlineStatus = "Testing connection…";
            });

            final test = await _testServiceSettings(
              baseUrl: urlCtrl.text,
              authToken: authCtrl.text,
            );

            if (!mounted) return;

            if (!test.ok) {
              setLocal(() {
                busy = false;
                inlineStatus = null;
                inlineError = test.message;
              });
              if (mounted) setState(() => _message = test.message);
              return;
            }

            await DeviceConfigService.setBaseUrl(urlCtrl.text);
            await DeviceConfigService.setAuthToken(authCtrl.text);

            setLocal(() {
              busy = false;
              inlineError = null;
              inlineStatus = test.message;
            });

            if (mounted) setState(() => _message = test.message);

            await Future.delayed(const Duration(milliseconds: 250));
            if (!mounted) return;
            Navigator.of(context).pop();
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _darkTextField(
                controller: urlCtrl,
                label: "Service Base URL",
                hint: "https://apply.tsg.bz/tsgtcwebserviceotc/tsgtc.asmx",
              ),
              const SizedBox(height: 12),
              _darkTextField(
                controller: authCtrl,
                label: "Auth Token",
                hint: "",
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Tip: If punches won’t sync, confirm this URL matches the working kiosk web path.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (inlineError != null) ...[
                const SizedBox(height: 12),
                banner(text: inlineError!, isError: true),
              ],
              if (inlineStatus != null) ...[
                const SizedBox(height: 12),
                banner(text: inlineStatus!, isError: false),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _dialogButton(
                    label: "Cancel",
                    filled: false,
                    busy: busy,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  _dialogButton(
                    label: "Verify & Save",
                    filled: true,
                    busy: busy,
                    onTap: verifyAndSave,
                  ),
                ],
              ),
            ],
          );
        },
      ),
      actions: const [],
    );
  }

  // ===== Punch log (via 101010 only) =====
  Future<void> _showPunchLogDialog() async {
    final items = _log.latest(limit: 300);

    String buildCsv(List<Map<String, dynamic>> rows) {
      final header = [
        'timestampUtc',
        'employeeName',
        'employeeId',
        'status',
        'latitude',
        'longitude',
        'localSequenceNumber',
        'outcome',
        'deviceId',
      ];

      final lines = <String>[];
      lines.add(header.join(','));

      String q(String s) => '"${s.replaceAll('"', '""')}"';

      for (final m in rows) {
        final ts = _normalizeIsoNoMillis((m['timestampUtc'] ?? '').toString());
        final name = (m['employeeName'] ?? '').toString();
        final empId = (m['employeeId'] ?? '').toString();
        final status = (m['status'] ?? '').toString();
        final lat = (m['latitude'] ?? '').toString();
        final lng = (m['longitude'] ?? '').toString();
        final seq = (m['localSequenceNumber'] ?? '').toString();
        final outcome = (m['outcome'] ?? '').toString();
        final dev = (m['deviceId'] ?? '').toString();

        lines.add([
          q(ts),
          q(name),
          q(empId),
          q(status),
          q(lat),
          q(lng),
          q(seq),
          q(outcome),
          q(dev),
        ].join(','));
      }

      return lines.join('\n');
    }

    String buildJson(List<Map<String, dynamic>> rows) {
      final cleaned = rows.map((m) {
        final copy = Map<String, dynamic>.from(m);
        copy['timestampUtc'] =
            _normalizeIsoNoMillis((copy['timestampUtc'] ?? '').toString());
        return copy;
      }).toList();

      return const JsonEncoder.withIndent('  ').convert(cleaned);
    }

    Future<void> copyToClipboard(String label, String text) async {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      setState(() => _message = "$label copied to clipboard.");
    }

    Widget pill(String text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1.6),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      );
    }

    await _showAppDialog<void>(
      title: "Punch Log (This Tablet)",
      width: 1000,
      dismissible: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              pill("Pending: $_pendingCount"),
              const SizedBox(width: 10),
              pill("Showing: ${items.length}"),
              const Spacer(),
              _dialogButton(
                label: "Copy CSV",
                filled: false,
                onTap: () => copyToClipboard("CSV export", buildCsv(items)),
              ),
              const SizedBox(width: 10),
              _dialogButton(
                label: "Copy JSON",
                filled: false,
                onTap: () => copyToClipboard("JSON export", buildJson(items)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 2),
            ),
            child: Row(
              children: [
                _col("TIME (UTC)", flex: 3),
                _col("EMP (NAME / ID)", flex: 4),
                _col("STATUS", flex: 2),
                _col("LAT/LNG", flex: 3),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 420,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 2),
            ),
            child: items.isEmpty
                ? Center(
              child: Text(
                "No punches recorded on this tablet yet.",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
                : Scrollbar(
              thumbVisibility: true,
              child: ListView.separated(
                padding: const EdgeInsets.all(10),
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(
                  color: Colors.white.withValues(alpha: 0.10),
                  height: 10,
                ),
                itemBuilder: (_, i) {
                  final m = items[i];

                  final ts = _normalizeIsoNoMillis((m["timestampUtc"] ?? "").toString());
                  final empId = (m["employeeId"] ?? "").toString();
                  final empName = (m["employeeName"] ?? "").toString();
                  final status = (m["status"] ?? "").toString().toUpperCase();
                  final lat = (m["latitude"] as num?)?.toDouble();
                  final lng = (m["longitude"] as num?)?.toDouble();

                  final statusColor = status == "IN"
                      ? Colors.green.withValues(alpha: 0.90)
                      : status == "OUT"
                      ? Colors.red.withValues(alpha: 0.90)
                      : Colors.white.withValues(alpha: 0.80);

                  final latLngText = (lat == null || lng == null)
                      ? "(no location)"
                      : "${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}";

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1.6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            ts.isEmpty ? "(unknown)" : ts,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            "${empName.isEmpty ? "(unknown)" : empName} / $empId",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            status.isEmpty ? "?" : status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            latLngText,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        _dialogButton(
          label: "Close",
          filled: true,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  static Widget _col(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // ===== Timestamp helpers (NO milliseconds) =====
  String _isoUtcNoMillis(DateTime utc) {
    final u = utc.toUtc();
    final yyyy = u.year.toString().padLeft(4, '0');
    final mm = u.month.toString().padLeft(2, '0');
    final dd = u.day.toString().padLeft(2, '0');
    final hh = u.hour.toString().padLeft(2, '0');
    final min = u.minute.toString().padLeft(2, '0');
    final ss = u.second.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd'
        'T$hh:$min:$ss'
        'Z';
  }

  String _normalizeIsoNoMillis(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;

    final dot = t.indexOf('.');
    if (dot == -1) return t;

    final before = t.substring(0, dot);
    final hasZ = t.toUpperCase().endsWith('Z');
    return hasZ ? '${before}Z' : before;
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale =
          (constraints.maxWidth / 1600.0).clamp(0.78, 1.0).toDouble();
          double s(double v) => v * scale;

          final timeStr = _formatTime(_now);
          final dateStr = _formatDate(_now);

          final actionText = _clockedIn ? "CLOCK OUT" : "CLOCK IN";
          final actionColor = _clockedIn ? Colors.red : Colors.green;

          final canVerify = _ready && !_verifying && !_punching;
          final canPunch = _ready && _verified && !_verifying && !_punching;

          final lastConfig = RemoteConfigService.lastConfigSync;

          return Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.all(s(24)),
                    child: Row(
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: s(320),
                            maxWidth: s(400),
                          ),
                          child: _buildLeftPanel(canVerify, s),
                        ),
                        SizedBox(width: s(24)),
                        Expanded(
                          child: _buildRightPanel(
                            s: s,
                            timeStr: timeStr,
                            dateStr: dateStr,
                            actionText: actionText,
                            actionColor: actionColor,
                            canPunch: canPunch,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Top-left status
                  Positioned(
                    left: s(24),
                    top: s(10),
                    child: !_ready || _heartbeat == null
                        ? Row(
                      children: [
                        Container(
                          width: s(10),
                          height: s(10),
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: s(8)),
                        Text(
                          "INITIALIZING…",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.80),
                            fontSize: s(12),
                            fontWeight: FontWeight.w900,
                            letterSpacing: s(1),
                          ),
                        ),
                      ],
                    )
                        : ValueListenableBuilder<bool>(
                      valueListenable: _heartbeat!.online,
                      builder: (context, online, _) {
                        final dotColor = online ? Colors.green : Colors.red;
                        final text = _lastSyncAttemptLocal == null
                            ? "Pending offline punches: $_pendingCount"
                            : "Last Sync Attempt: ${_formatSyncStamp(_lastSyncAttemptLocal!)}   |   Pending: $_pendingCount";

                        return Row(
                          children: [
                            Container(
                              width: s(10),
                              height: s(10),
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: s(8)),
                            Text(
                              online ? "ONLINE" : "OFFLINE",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.80),
                                fontSize: s(12),
                                fontWeight: FontWeight.w900,
                                letterSpacing: s(1),
                              ),
                            ),
                            SizedBox(width: s(18)),
                            Text(
                              text,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: s(12),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Top-right buttons
                  Positioned(
                    right: s(24),
                    top: s(10),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: !_ready ? null : () => _trySync(forceOnline: true),
                          child: Text(
                            "Sync Now",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: s(12),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: s(12)),
                        TextButton(
                          onPressed: _syncConfig,
                          child: Text(
                            lastConfig == null
                                ? "Config Sync"
                                : "Config Sync (${lastConfig.hour.toString().padLeft(2, '0')}:${lastConfig.minute.toString().padLeft(2, '0')})",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: s(12),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom-right version
                  Positioned(
                    right: s(24),
                    bottom: s(8),
                    child: Text(
                      "ver 4.0.1",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: s(12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===== UI helpers (unchanged layout) =====
  Widget _buildLeftPanel(bool canVerify, double Function(double) s) {
    return Container(
      padding: EdgeInsets.all(s(18)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(s(22)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: s(2),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: s(64),
            padding: EdgeInsets.symmetric(horizontal: s(16)),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(s(16)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: s(2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _employeeNumber,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: s(32),
                      fontWeight: FontWeight.w800,
                      letterSpacing: s(2),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _employeeNumber.isEmpty ? null : _backspace,
                  icon: Icon(
                    Icons.backspace_outlined,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: s(22),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: s(14)),
          _buildKeypad(s),
          SizedBox(height: s(14)),
          SizedBox(
            width: double.infinity,
            height: s(56),
            child: ElevatedButton(
              onPressed: canVerify ? _verifyEmployee : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(s(16)),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: s(2),
                  ),
                ),
              ),
              child: _verifying
                  ? SizedBox(
                width: s(20),
                height: s(20),
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
                  : Text(
                "VERIFY",
                style: TextStyle(
                  fontSize: s(18),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel({
    required double Function(double) s,
    required String timeStr,
    required String dateStr,
    required String actionText,
    required Color actionColor,
    required bool canPunch,
  }) {
    final clockBtnSize = s(160);

    return Container(
      padding: EdgeInsets.all(s(22)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(s(22)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: s(2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "HAVE YOU REMOVED YOUR LOCK\nTODAY?",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.red.withValues(alpha: 0.9),
              fontSize: s(18),
              fontWeight: FontWeight.w900,
              letterSpacing: s(1),
            ),
          ),
          SizedBox(height: s(10)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              timeStr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: s(92),
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
          SizedBox(height: s(6)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              dateStr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: s(20),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: s(18)),
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: s(24)),
                child: LogoHeader(
                  heightFactor: 0.22,
                  padding: EdgeInsets.zero,
                  maxHeight: s(220),
                  minHeight: s(90),
                ),
              ),
            ),
          ),
          if (_verified && _fullName != null) ...[
            SizedBox(height: s(10)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: s(16), vertical: s(10)),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(s(16)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: s(2),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _fullName!.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: s(22),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: s(6)),
                  Text(
                    _clockedIn ? "You are currently IN" : "You are currently OUT",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: s(14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(height: s(8)),
          ],
          SizedBox(height: s(12)),
          Center(
            child: GestureDetector(
              onTap: canPunch ? _doPunch : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: canPunch ? 1.0 : 0.35,
                child: Container(
                  width: clockBtnSize,
                  height: clockBtnSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: actionColor,
                    boxShadow: [
                      BoxShadow(
                        color: actionColor.withValues(alpha: 0.30),
                        blurRadius: s(18),
                        spreadRadius: s(3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _punching
                      ? SizedBox(
                    width: s(28),
                    height: s(28),
                    child: const CircularProgressIndicator(strokeWidth: 3),
                  )
                      : Text(
                    actionText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: s(22),
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: s(12)),
          if (_message != null)
            Text(
              _message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: s(14),
                fontWeight: FontWeight.w600,
              ),
            ),
          SizedBox(height: s(6)),
        ],
      ),
    );
  }

  Widget _buildKeypad(double Function(double) s) {
    return Column(
      children: [
        _keypadRow(["1", "2", "3"], s),
        _keypadRow(["4", "5", "6"], s),
        _keypadRow(["7", "8", "9"], s),
        Row(
          children: [
            Expanded(
              child: _keyButton(
                label: "CLEAR",
                onTap: _clearEntry,
                filled: true,
                fontSize: s(18),
                s: s,
              ),
            ),
            Expanded(
              child: _keyButton(
                label: "0",
                onTap: () => _appendDigit("0"),
                s: s,
              ),
            ),
            Expanded(
              child: _keyButton(
                label: "VERIFY",
                onTap: _verifyEmployee,
                filled: true,
                fontSize: s(18),
                s: s,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keypadRow(List<String> labels, double Function(double) s) {
    return Row(
      children: labels
          .map((l) => Expanded(
        child: _keyButton(
          label: l,
          onTap: () => _appendDigit(l),
          s: s,
        ),
      ))
          .toList(),
    );
  }

  Widget _keyButton({
    required String label,
    required VoidCallback onTap,
    required double Function(double) s,
    bool filled = false,
    double? fontSize,
  }) {
    return Padding(
      padding: EdgeInsets.all(s(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(s(18)),
        onTap: onTap,
        child: Container(
          height: s(78),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(s(18)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.20),
              width: s(2),
            ),
            color: filled ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize ?? s(26),
              fontWeight: FontWeight.w800,
              letterSpacing: s(1),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    int h = dt.hour;
    final m = dt.minute.toString().padLeft(2, "0");
    final ampm = h >= 12 ? "PM" : "AM";
    h = h % 12;
    if (h == 0) h = 12;
    return "$h:$m $ampm";
  }

  String _formatDate(DateTime dt) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    const days = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday"
    ];
    final dayName = days[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    return "$dayName, $monthName ${dt.day}, ${dt.year}";
  }

  String _formatSyncStamp(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, "0");
    final dd = dt.day.toString().padLeft(2, "0");
    final yyyy = dt.year.toString();

    int h = dt.hour;
    final m = dt.minute.toString().padLeft(2, "0");
    final s = dt.second.toString().padLeft(2, "0");
    final ampm = h >= 12 ? "PM" : "AM";
    h = h % 12;
    if (h == 0) h = 12;

    return "$mm/$dd/$yyyy $h:$m:$s $ampm";
  }
}