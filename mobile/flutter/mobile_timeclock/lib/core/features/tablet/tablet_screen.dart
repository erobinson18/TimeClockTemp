import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../api_client.dart';
import '../../Services/device_config_service.dart';
import '../../services/admin_pin_service.dart';
import '../../services/heartbeat_service.dart';
import '../../services/remote_config_service.dart';

import '../../../data/local/local_seq_store.dart';
import '../../../data/local/punch_queue.dart';
import '../../../data/local/roster_cache.dart';
import '../../../data/local/status_cache.dart';

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
  late final TimeClockApi _api;
  late final HeartbeatService _heartbeat;

  final _queue = PunchQueue();
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

  // Device identifiers (Vista mapping can remain server-side)
  static const int deviceType = 1;
  static const String deviceId = "KIOSK-TEST-01";

  Timer? _clockTimer;
  Timer? _syncTimer;
  DateTime _now = DateTime.now();
  DateTime? _lastSyncAttemptLocal;

  // Admin codes (your existing pattern)
  static const String _adminServiceCode = "009876";
  static const String _adminPunchLogCode = "101010";

  @override
  void initState() {
    super.initState();
    _api = TimeClockApi(ApiClient());
    _heartbeat = HeartbeatService(api: _api);

    _refreshPending();
    _startClock();
    _warmupRoster();

    _heartbeat.start();

    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) => _trySync());
    _trySync();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _syncTimer?.cancel();
    _heartbeat.stop();
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
      _employeeNumber = _employeeNumber.substring(0, _employeeNumber.length - 1);
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
  Future<bool> _isOnline() async {
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none)) return false;

    try {
      await _api.ping();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ===== Step 1: Warm roster cache from GetEmps =====
  Future<void> _warmupRoster() async {
    try {
      if (!await _isOnline()) return;
      final items = await _api.rosterAll();
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

  // ===== Sync (uses verified queue items) =====
  Future<void> _trySync() async {
    try {
      _lastSyncAttemptLocal = DateTime.now();

      if (!await _isOnline()) return;

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
        deviceId: deviceId,
        deviceType: deviceType,
        punches: punches,
      );

      final result = await _api.syncBatch(batch);

      await _queue.removeByLocalSeq(result.acceptedSeq.toSet());
      await _refreshPending();

      if (!mounted) return;
      setState(() => _message = "Synced ${result.processed} punch(es).");

      if (_employeeGuid != null && _employeeGuid!.trim().isNotEmpty) {
        await _loadStatus(_employeeGuid!);
      }
    } catch (_) {}
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
    if (_employeeNumber.isEmpty) {
      setState(() => _message = "Enter your Employee ID.");
      return;
    }

    // Admin codes
    if (_employeeNumber == _adminServiceCode) {
      _clearEntry();
      final ok = await _adminGate();
      if (!ok) return;
      await _showServiceSettingsDialog();
      return;
    }

    if (_employeeNumber == _adminPunchLogCode) {
      _clearEntry();
      final ok = await _adminGate();
      if (!ok) return;
      await _showPunchLogDialog();
      return;
    }

    setState(() {
      _verifying = true;
      _message = null;
    });

    try {
      if (await _isOnline()) {
        await _warmupRoster();

        final cached = await _rosterCache.findByEmployeeNumber(_employeeNumber);
        if (cached == null) {
          if (mounted) setState(() => _message = "Invalid Employee ID");
          return;
        }

        final cachedClockedIn =
            _statusCache.getIsClockedIn(cached.employeeId) ?? false;

        final res = VerifyResponse(
          isValid: true,
          employeeId: cached.employeeId,
          employeeNumber: cached.employeeNumber,
          fullName: cached.fullName,
          isClockedIn: cachedClockedIn,
        );

        _applyVerified(res, message: "Verified.");
        await _statusCache.setIsClockedIn(cached.employeeId, cachedClockedIn);

        await _loadStatus(cached.employeeId);
        return;
      }

      // Offline verify
      final cached = await _rosterCache.findByEmployeeNumber(_employeeNumber);
      if (cached == null) {
        if (mounted) setState(() => _message = "Employee not found (offline).");
        return;
      }

      final cachedClockedIn =
          _statusCache.getIsClockedIn(cached.employeeId) ?? false;

      final offlineRes = VerifyResponse(
        isValid: true,
        employeeId: cached.employeeId,
        employeeNumber: cached.employeeNumber,
        fullName: cached.fullName,
        isClockedIn: cachedClockedIn,
      );

      _applyVerified(offlineRes, message: "Verified (offline).");
    } catch (_) {
      if (mounted) setState(() => _message = "Verify failed");
    } finally {
      // no returns in finally
      if (mounted) setState(() => _verifying = false);
    }
  }

  // ===== Status =====
  Future<void> _loadStatus(String guid) async {
    try {
      final StatusResponse s = await _api.status(guid);
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

  // ===== Punch =====
  Future<void> _doPunch() async {
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

    final queuedPayload = <String, dynamic>{
      "employeeId": _employeeGuid!,
      "punchType": punchType,
      "localSequenceNumber": seq,
      "timestampUtc": nowUtc.toIso8601String(),
      "latitude": null,
      "longitude": null,
    };

    final newClockedIn = (punchType == 0);
    setState(() {
      _clockedIn = newClockedIn;
      _message = (punchType == 0) ? "Clock In recorded." : "Clock Out recorded.";
    });
    await _statusCache.setIsClockedIn(_employeeGuid!, newClockedIn);

    try {
      final online = await _isOnline();

      if (online) {
        await _api.punch(PunchRequest(
          employeeId: _employeeGuid!,
          punchType: punchType,
          deviceType: deviceType,
          deviceId: deviceId,
          localSequenceNumber: seq,
          timestampUtc: nowUtc,
        ));

        await Future.delayed(const Duration(milliseconds: 75));
        await _loadStatus(_employeeGuid!);

        Future.delayed(const Duration(seconds: 2), _resetSession);
      } else {
        await _queue.enqueue(queuedPayload);
        await _refreshPending();

        if (!mounted) return;
        setState(() => _message = "Offline: Punch queued ($_pendingCount pending).");

        Future.delayed(const Duration(seconds: 2), _resetSession);
      }
    } catch (_) {
      await _queue.enqueue(queuedPayload);
      await _refreshPending();

      if (!mounted) return;
      setState(() => _message = "Punch queued ($_pendingCount pending).");

      Future.delayed(const Duration(seconds: 2), _resetSession);
    } finally {
      // no returns in finally
      if (mounted) setState(() => _punching = false);
    }
  }

  // ===== Step 4: Admin PIN Gate =====
  Future<bool> _adminGate() async {
    final pinCtrl = TextEditingController();
    final pin2Ctrl = TextEditingController();

    final alreadySet = await AdminPinService.isSet();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(alreadySet ? "Admin PIN" : "Set Admin PIN"),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: alreadySet ? "Enter PIN" : "New PIN",
                  ),
                ),
                if (!alreadySet) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: pin2Ctrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Confirm PIN",
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                try {
                  if (!alreadySet) {
                    if (pinCtrl.text.trim() != pin2Ctrl.text.trim()) {
                      // keep dialog open
                      return;
                    }
                    await AdminPinService.setPin(pinCtrl.text.trim());
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop(true);
                    return;
                  }

                  final ok = await AdminPinService.verifyPin(pinCtrl.text.trim());
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(ok);
                } catch (_) {
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(false);
                }
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ===== Step 5: Remote config sync stub =====
  Future<void> _syncConfig() async {
    final changed = await RemoteConfigService.trySync();
    if (!mounted) return;

    setState(() {
      _message = changed ? "Config updated." : "Config sync recorded (no backend yet).";
    });
  }

  // ===== Admin: Service settings =====
  Future<void> _showServiceSettingsDialog() async {
    final urlCtrl = TextEditingController(text: DeviceConfigService.baseUrl);
    final kioskCtrl = TextEditingController(text: DeviceConfigService.kioskId);
    final authCtrl = TextEditingController(text: DeviceConfigService.authToken);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Service Settings"),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: "Service Base URL",
                      hintText: "https://tcws.tsg.bz/tsgtc.asmx",
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: kioskCtrl,
                    decoration: const InputDecoration(
                      labelText: "Kiosk ID (MACAddress)",
                      hintText: "tsg-eld-android",
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: authCtrl,
                    decoration: const InputDecoration(labelText: "Auth Token"),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Format suggestion: tsg-<locationcode>-<platform>",
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await DeviceConfigService.setBaseUrl(urlCtrl.text);
                await DeviceConfigService.setKioskId(kioskCtrl.text);
                await DeviceConfigService.setAuthToken(authCtrl.text);

                if (mounted) setState(() => _message = "Service settings saved.");

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // ===== Admin: Punch log =====
  Future<void> _showPunchLogDialog() async {
    final box = Hive.box('punch_queue');
    final keys = box.keys.toList();
    final items = <Map<String, dynamic>>[];

    for (final k in keys.reversed.take(50)) {
      final v = box.get(k);
      if (v is Map) {
        items.add(v.map((key, value) => MapEntry(key.toString(), value)));
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Punch History (Offline Queue)"),
          content: SizedBox(
            width: 760,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Pending punches: $_pendingCount"),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: items.map((m) {
                        final emp = (m["employeeId"] ?? "").toString();
                        final type = (m["punchType"] ?? "").toString();
                        final ts = (m["timestampUtc"] ?? "").toString();
                        final seq = (m["localSequenceNumber"] ?? "").toString();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            "Emp: $emp | Type: $type | Seq: $seq | UTC: $ts",
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = (constraints.maxWidth / 1600.0).clamp(0.78, 1.0);
          double s(double v) => v * scale;

          final timeStr = _formatTime(_now);
          final dateStr = _formatDate(_now);

          final actionText = _clockedIn ? "CLOCK OUT" : "CLOCK IN";
          final actionColor = _clockedIn ? Colors.red : Colors.green;

          final canVerify = !_verifying && !_punching;
          final canPunch = _verified && !_verifying && !_punching;

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

                  // Top-left: status line + heartbeat
                  Positioned(
                    left: s(24),
                    top: s(10),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _heartbeat.online,
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

                  // Top-right: Sync + Config Sync
                  Positioned(
                    right: s(24),
                    top: s(10),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: _trySync,
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

  Widget _buildLeftPanel(bool canVerify, double Function(double) s) {
    return Container(
      padding: EdgeInsets.all(s(18)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(s(22)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: s(2)),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: s(2)),
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