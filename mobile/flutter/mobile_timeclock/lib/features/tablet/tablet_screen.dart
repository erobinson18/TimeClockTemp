import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/api_client.dart';
import '../../core/Services/device_config_service.dart';

import '../../data/local/punch_queue.dart';
import '../../data/local/roster_cache.dart';
import '../../data/local/status_cache.dart';
import '../../data/local/local_seq_store.dart';

import '../../data/models/punch.dart';
import '../../data/models/status.dart';
import '../../data/models/sync.dart';
import '../../data/models/verify.dart';
import '../../data/remote/timeclock_api.dart';

import '../../widgets/logo_header.dart';

class TabletScreen extends StatefulWidget {
  const TabletScreen({super.key});

  @override
  State<TabletScreen> createState() => _TabletScreenState();
}

class _TabletScreenState extends State<TabletScreen> {
  late final TimeClockApi _api;
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

  // UX + telemetry
  String? _message;
  int _pendingCount = 0;

  bool _syncing = false;
  DateTime? _lastSyncAttemptLocal;
  String? _lastSyncResult;

  // Device identifiers (Vista mapping can remain server-side)
  static const int deviceType = 1;
  static const String deviceId = "KIOSK-TEST-01";

  Timer? _clockTimer;
  Timer? _syncTimer;
  DateTime _now = DateTime.now();

  // Admin codes (MATCH YOUR EXISTING CLOCK)
  static const String _adminServiceCode = "009876"; // Change Server/Auth
  static const String _adminPunchLogCode = "101010"; // Punch History

  // UI overlay feedback
  OverlayEntry? _toastEntry;

  @override
  void initState() {
    super.initState();
    _api = TimeClockApi(ApiClient());

    _refreshPending();
    _startClock();
    _warmupRoster();

    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) => _trySync());
    _trySync();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _syncTimer?.cancel();
    _removeToast();
    super.dispose();
  }

  // ===== Clock =====
  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  // ===== Toast Overlay =====
  void _removeToast() {
    _toastEntry?.remove();
    _toastEntry = null;
  }

  void _showToast({
    required String title,
    String? subtitle,
    required Color color,
    required IconData icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    _removeToast();

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    _toastEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: 24,
        right: 24,
        bottom: 24,
        child: _PunchToast(
          title: title,
          subtitle: subtitle,
          color: color,
          icon: icon,
        ),
      ),
    );

    overlay.insert(_toastEntry!);

    Future.delayed(duration, () {
      if (mounted) _removeToast();
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

  // ===== Step 1: Warm roster cache =====
  Future<void> _warmupRoster() async {
    try {
      if (!await _isOnline()) return;

      final items = await _api.rosterAll();
      final json = items.map((e) => e.toJson()).toList();
      await _rosterCache.saveAll(json);

      _showToast(
        title: "Employees Synced",
        subtitle: "Roster refreshed from server.",
        color: Colors.green,
        icon: Icons.check_circle,
      );
    } catch (_) {
      // don’t spam UI if this fails silently in the field
    }
  }

  // ===== Queue UI =====
  Future<void> _refreshPending() async {
    final c = await _queue.count();
    if (!mounted) return;
    setState(() => _pendingCount = c);
  }

  // ===== Sync =====
  Future<void> _trySync() async {
    if (_syncing) return;

    _syncing = true;
    _lastSyncAttemptLocal = DateTime.now();
    if (mounted) setState(() => _lastSyncResult = null);

    try {
      if (!await _isOnline()) {
        if (mounted) setState(() => _lastSyncResult = "Offline (no sync)");
        return;
      }

      final pending = await _queue.all();
      if (pending.isEmpty) {
        if (mounted) setState(() => _lastSyncResult = "No pending punches");
        return;
      }

      final punches = pending.map((p) {
        final punchType = (p["punchType"] as num?)?.toInt() ?? 0;
        final localSeq = (p["localSequenceNumber"] as num?)?.toInt() ?? 0;
        final ts = p["timestampUtc"] as String? ??
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
      setState(() {
        _message = "Synced ${result.processed} punch(es).";
        _lastSyncResult = "Synced ${result.processed} / ${punches.length}";
      });

      _showToast(
        title: "Sync Complete",
        subtitle: "Processed ${result.processed} punch(es).",
        color: Colors.green,
        icon: Icons.cloud_done,
      );

      if (_employeeGuid != null) {
        await _loadStatus(_employeeGuid!);
      }
    } catch (_) {
      if (mounted) setState(() => _lastSyncResult = "Sync failed");
      _showToast(
        title: "Sync Failed",
        subtitle: "Will retry automatically.",
        color: Colors.orange,
        icon: Icons.cloud_off,
      );
    } finally {
      _syncing = false;
    }
  }

  // ===== Verify =====
  void _applyVerified(VerifyResponse res, {required String message}) {
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
      await _showServiceSettingsSheet();
      _clearEntry();
      return;
    }

    if (_employeeNumber == _adminPunchLogCode) {
      await _showPunchHistorySheet();
      _clearEntry();
      return;
    }

    setState(() {
      _verifying = true;
      _message = null;
    });

    try {
      if (await _isOnline()) {
        // refresh roster cache
        await _warmupRoster();

        // verify from cache
        final cached = await _rosterCache.findByEmployeeNumber(_employeeNumber);
        if (cached == null) {
          setState(() => _message = "Invalid Employee ID");
          _showToast(
            title: "Invalid ID",
            subtitle: "Please try again.",
            color: Colors.red,
            icon: Icons.error,
          );
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
        setState(() => _message = "Employee not found (offline).");
        _showToast(
          title: "Offline",
          subtitle: "Employee not found in local cache.",
          color: Colors.orange,
          icon: Icons.wifi_off,
        );
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
      _showToast(
        title: "Verified (Offline)",
        subtitle: "Punches will queue until online.",
        color: Colors.orange,
        icon: Icons.wifi_off,
      );
    } catch (_) {
      setState(() => _message = "Verify failed");
      _showToast(
        title: "Verify Failed",
        subtitle: "Try again.",
        color: Colors.red,
        icon: Icons.error,
      );
    } finally {
      if (!mounted) return;
      setState(() => _verifying = false);
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
    if (!_verified || _employeeGuid == null) {
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

    // optimistic UI
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

        _showToast(
          title: punchType == 0 ? "Clock In Success" : "Clock Out Success",
          subtitle: _fullName,
          color: Colors.green,
          icon: Icons.check_circle,
        );

        await Future.delayed(const Duration(milliseconds: 100));
        await _loadStatus(_employeeGuid!);

        Future.delayed(const Duration(seconds: 2), _resetSession);
      } else {
        await _queue.enqueue(queuedPayload);
        await _refreshPending();

        if (!mounted) return;
        setState(() => _message = "Offline: Punch queued ($_pendingCount pending).");

        _showToast(
          title: "Offline",
          subtitle: "Punch queued ($_pendingCount pending).",
          color: Colors.orange,
          icon: Icons.wifi_off,
        );

        Future.delayed(const Duration(seconds: 2), _resetSession);
      }
    } catch (_) {
      await _queue.enqueue(queuedPayload);
      await _refreshPending();

      if (!mounted) return;
      setState(() => _message = "Punch queued ($_pendingCount pending).");

      _showToast(
        title: "Queued",
        subtitle: "Punch saved offline ($_pendingCount pending).",
        color: Colors.orange,
        icon: Icons.save,
      );

      Future.delayed(const Duration(seconds: 2), _resetSession);
    } finally {
      if (!mounted) return;
      setState(() => _punching = false);
    }
  }

  // ===== Admin Sheets =====
  Future<void> _showServiceSettingsSheet() async {
    final urlCtrl = TextEditingController(text: DeviceConfigService.baseUrl);
    final kioskCtrl = TextEditingController(text: DeviceConfigService.kioskId);
    final authCtrl = TextEditingController(text: DeviceConfigService.authToken);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _AdminSheetScaffold(
          title: "Service Settings",
          subtitle: "Update server + auth. KioskId can be set later.",
          child: Column(
            children: [
              _AdminTextField(
                controller: urlCtrl,
                label: "Service Base URL",
                hint: "https://tcws.tsg.bz/tsgtc.asmx",
                icon: Icons.link,
              ),
              const SizedBox(height: 12),
              _AdminTextField(
                controller: authCtrl,
                label: "Auth Token",
                hint: "Paste auth token",
                icon: Icons.key,
                obscure: true,
              ),
              const SizedBox(height: 12),
              _AdminTextField(
                controller: kioskCtrl,
                label: "Kiosk ID",
                hint: "tsg-eld-android",
                icon: Icons.badge,
              ),
              const SizedBox(height: 12),
              const Text(
                "Format: tsg-<locationcode>-<platform> (ex: tsg-eld-android)",
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _AdminButton(
                      text: "Cancel",
                      color: Colors.red,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AdminButton(
                      text: "Update",
                      color: Colors.green,
                      onTap: () async {
                        await DeviceConfigService.setBaseUrl(urlCtrl.text);
                        await DeviceConfigService.setAuthToken(authCtrl.text);
                        await DeviceConfigService.setKioskId(kioskCtrl.text);

                        if (mounted) {
                          setState(() => _message = "Service settings saved.");
                        }
                        if (context.mounted) Navigator.pop(context);

                        _showToast(
                          title: "Updated",
                          subtitle: "Service settings saved.",
                          color: Colors.green,
                          icon: Icons.check_circle,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPunchHistorySheet() async {
    final box = Hive.box('punch_queue');
    final keys = box.keys.toList();

    final items = <Map<String, dynamic>>[];
    for (final k in keys.reversed.take(40)) {
      final v = box.get(k);
      if (v is Map) {
        items.add(v.map((key, value) => MapEntry(key.toString(), value)));
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _AdminSheetScaffold(
          title: "Punch History",
          subtitle: "Recent offline punches + tools",
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _AdminStatCard(
                      label: "Pending",
                      value: _pendingCount.toString(),
                      icon: Icons.pending_actions,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AdminStatCard(
                      label: "Last Sync",
                      value: _lastSyncAttemptLocal == null
                          ? "--"
                          : _formatSyncStamp(_lastSyncAttemptLocal!),
                      icon: Icons.cloud,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _AdminButton(
                      text: "Sync Employees",
                      color: Colors.green,
                      onTap: () async {
                        await _warmupRoster();
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AdminButton(
                      text: _syncing ? "Syncing..." : "Sync Now",
                      color: Colors.blue,
                      onTap: _syncing
                          ? null
                          : () async {
                        await _trySync();
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _AdminButton(
                text: "Log Out / Reset",
                color: Colors.red,
                onTap: () async {
                  _resetSession();
                  if (context.mounted) Navigator.pop(context);
                  _showToast(
                    title: "Reset",
                    subtitle: "Session cleared.",
                    color: Colors.red,
                    icon: Icons.logout,
                  );
                },
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Recent Offline Punches",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: SizedBox(
                  height: 320,
                  child: items.isEmpty
                      ? const Center(
                    child: Text(
                      "No offline punches stored.",
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                      : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(
                      color: Colors.white.withOpacity(0.10),
                      height: 16,
                    ),
                    itemBuilder: (_, i) {
                      final m = items[i];
                      final emp = (m["employeeId"] ?? "").toString();
                      final type = (m["punchType"] ?? "").toString();
                      final ts = (m["timestampUtc"] ?? "").toString();
                      final seq = (m["localSequenceNumber"] ?? "").toString();

                      final t = type == "0" ? "IN" : "OUT";

                      return Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: (t == "IN" ? Colors.green : Colors.red)
                                  .withOpacity(0.20),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Emp: $emp  |  Seq: $seq\nUTC: $ts",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _AdminButton(
                text: "Close",
                color: Colors.white24,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // B) Kiosk hardening: disable back navigation
      onWillPop: () async => false,
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

          return Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                children: [
                  // subtle “premium” gradient
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.06),
                              Colors.transparent,
                              Colors.white.withOpacity(0.04),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

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

                  Positioned(
                    left: s(24),
                    top: s(10),
                    child: Text(
                      _lastSyncAttemptLocal == null
                          ? "Pending: $_pendingCount"
                          : "Last Sync: ${_formatSyncStamp(_lastSyncAttemptLocal!)}   |   Pending: $_pendingCount   |   ${_lastSyncResult ?? ""}",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: s(12),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  Positioned(
                    right: s(24),
                    top: s(10),
                    child: TextButton(
                      onPressed: _syncing ? null : _trySync,
                      child: Text(
                        _syncing ? "Syncing..." : "Sync Now",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: s(12),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    right: s(24),
                    bottom: s(8),
                    child: Text(
                      "ver 4.0.1",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
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
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(s(22)),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: s(2)),
      ),
      child: Column(
        children: [
          Container(
            height: s(64),
            padding: EdgeInsets.symmetric(horizontal: s(16)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(s(16)),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
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
                    color: Colors.white.withOpacity(0.85),
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
                backgroundColor: Colors.white.withOpacity(0.14),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(s(16)),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.18),
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
                  fontWeight: FontWeight.w900,
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
    final clockBtnSize = s(170);

    return Container(
      padding: EdgeInsets.all(s(22)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(s(22)),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: s(2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "HAVE YOU REMOVED YOUR LOCK\nTODAY?",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.red.withOpacity(0.9),
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
                color: Colors.white.withOpacity(0.85),
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
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(s(16)),
                border: Border.all(
                  color: Colors.white.withOpacity(0.14),
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
                      color: Colors.white.withOpacity(0.85),
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
                child: AnimatedScale(
                  scale: canPunch ? 1.0 : 0.98,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: clockBtnSize,
                    height: clockBtnSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: actionColor,
                      boxShadow: [
                        BoxShadow(
                          color: actionColor.withOpacity(0.30),
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
          ),
          SizedBox(height: s(12)),
          if (_message != null)
            Text(
              _message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
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
              color: Colors.white.withOpacity(0.20),
              width: s(2),
            ),
            color: filled ? Colors.white.withOpacity(0.12) : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize ?? s(26),
              fontWeight: FontWeight.w900,
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
      "January","February","March","April","May","June",
      "July","August","September","October","November","December"
    ];
    const days = [
      "Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"
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

// ===== Reusable Admin UI widgets (in-file to avoid import errors) =====

class _AdminSheetScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _AdminSheetScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.92),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.admin_panel_settings, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(child: child),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;

  const _AdminTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.28)),
        ),
      ),
    );
  }
}

class _AdminButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback? onTap;

  const _AdminButton({
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.85),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _AdminStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PunchToast extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color color;
  final IconData icon;

  const _PunchToast({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.86),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.30),
              blurRadius: 18,
              spreadRadius: 2,
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}