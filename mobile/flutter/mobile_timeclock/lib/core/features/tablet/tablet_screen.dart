import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../api_client.dart';
import '../../Services/device_config_service.dart';
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

  // Special access codes (ONLY way to open these screens)
  static const String _adminServiceCode = "009876";
  static const String _adminPunchLogCode = "101010";

  // Phase 4: ValidateCode "Action" parameter
  // If your server expects a different action token, change it here:
  static const String _validateActionPunch = "PUNCH";

  @override
  void initState() {
    super.initState();

    _api = TimeClockApi(ApiClient(
      log: (m) => debugPrint(m),
    ));
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
    if (results.contains(ConnectivityResult.none)) {
      return false;
    }

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

  // ===== Sync =====
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
    final entry = _employeeNumber.trim();

    if (entry.isEmpty) {
      setState(() => _message = "Enter your Employee ID.");
      return;
    }

    // ✅ SPECIAL CODES MUST ALWAYS WIN (ONLINE/OFFLINE DOESN'T MATTER)
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

      // If online, trust server status to correct cached bool
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

  // ===== Phase 4 helper: prompt + validate OTCode (online only) =====
  Future<String?> _promptForOtCodeIfNeeded() async {
    // Only prompt when online (offline must still work)
    final online = await _isOnline();
    if (!online) return null;

    final ctrl = TextEditingController();

    final res = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return AlertDialog(
          title: const Text("Optional Site / OT Code"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "If your company requires a site/OT code for this punch, enter it now.\n\n"
                    "Leave blank to punch normally.",
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: "OT Code (optional)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => Navigator.of(context).pop(ctrl.text.trim()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
              child: const Text("Continue"),
            ),
          ],
        );
      },
    );

    // null = user canceled dialog
    return res;
  }

  Future<bool> _validateOtCodeIfProvided(String otCode) async {
    final code = otCode.trim();
    if (code.isEmpty) return true; // nothing to validate

    final result = await _api.validateCode(
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

    // IMPORTANT: queue timestamp MUST NOT have milliseconds.
    final nowUtc = DateTime.now().toUtc();
    final tsUtcNoMillis = _isoUtcNoMillis(nowUtc);

    final queuedPayload = <String, dynamic>{
      "employeeId": _employeeGuid!,
      "punchType": punchType,
      "localSequenceNumber": seq,
      "timestampUtc": tsUtcNoMillis, // ✅ no milliseconds
      "latitude": null,
      "longitude": null,
    };

    // optimistic UX
    final newClockedIn = (punchType == 0);
    setState(() {
      _clockedIn = newClockedIn;
      _message = (punchType == 0) ? "Clock In recorded." : "Clock Out recorded.";
    });
    await _statusCache.setIsClockedIn(_employeeGuid!, newClockedIn);

    try {
      final online = await _isOnline();

      if (online) {
        // Phase 4: prompt for optional code and validate before punching
        final otPrompt = await _promptForOtCodeIfNeeded();
        if (otPrompt == null) {
          // User canceled; revert optimistic change to cached value
          final cached = _statusCache.getIsClockedIn(_employeeGuid!);
          if (cached != null && mounted) {
            setState(() {
              _clockedIn = cached;
              _message = "Punch canceled.";
            });
          }
          return;
        }

        final otCode = otPrompt.trim();

        // Validate only if provided
        final ok = await _validateOtCodeIfProvided(otCode);
        if (!ok) {
          // revert optimistic state to cached value
          final cached = _statusCache.getIsClockedIn(_employeeGuid!);
          if (cached != null && mounted) {
            setState(() => _clockedIn = cached);
          }
          return;
        }

        // Punch with (possibly empty) OT code
        final s = await _api.punchAndGetStatus(
          PunchRequest(
            employeeId: _employeeGuid!,
            punchType: punchType,
            deviceType: deviceType,
            deviceId: deviceId,
            localSequenceNumber: seq,
            timestampUtc: nowUtc,
          ),
          otCode: otCode,
        );

        if (!mounted) return;
        setState(() {
          _clockedIn = s.isClockedIn;
          _message = s.isClockedIn ? "You are now IN." : "You are now OUT.";
        });
        await _statusCache.setIsClockedIn(_employeeGuid!, s.isClockedIn);

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

  // ===== Service settings (via 009876 only) =====
  Future<void> _showServiceSettingsDialog() async {
    final urlCtrl = TextEditingController(text: DeviceConfigService.baseUrl);
    final kioskCtrl = TextEditingController(text: DeviceConfigService.kioskId);
    final authCtrl = TextEditingController(text: DeviceConfigService.authToken);

    await showDialog<void>(
      context: context,
      builder: (_) {
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final nav = Navigator.of(context);

                await DeviceConfigService.setBaseUrl(urlCtrl.text);
                await DeviceConfigService.setKioskId(kioskCtrl.text);
                await DeviceConfigService.setAuthToken(authCtrl.text);

                if (!mounted) return;
                setState(() => _message = "Service settings saved.");
                nav.pop();
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // ===== Punch log (via 101010 only) =====
  Future<void> _showPunchLogDialog() async {
    final box = Hive.box('punch_queue');
    final keys = box.keys.toList();
    final items = <Map<String, dynamic>>[];

    for (final k in keys.reversed.take(200)) {
      final v = box.get(k);
      if (v is Map) {
        items.add(v.map((key, value) => MapEntry(key.toString(), value)));
      }
    }

    String buildCsv(List<Map<String, dynamic>> rows) {
      final header = [
        'kioskId',
        'employeeId',
        'punchType',
        'localSequenceNumber',
        'timestampUtc',
        'queuedAtUtc',
      ];

      final lines = <String>[];
      lines.add(header.join(','));

      for (final m in rows) {
        final kioskId = (m['kioskId'] ?? '').toString();
        final emp = (m['employeeId'] ?? '').toString();
        final type = (m['punchType'] ?? '').toString();
        final seq = (m['localSequenceNumber'] ?? '').toString();

        final tsUtc = _normalizeIsoNoMillis((m['timestampUtc'] ?? '').toString());
        final queuedAt = _normalizeIsoNoMillis((m['queuedAtUtc'] ?? '').toString());

        String q(String s) => '"${s.replaceAll('"', '""')}"';

        lines.add([
          q(kioskId),
          q(emp),
          q(type),
          q(seq),
          q(tsUtc),
          q(queuedAt),
        ].join(','));
      }

      return lines.join('\n');
    }

    String buildJson(List<Map<String, dynamic>> rows) {
      final cleaned = rows.map((m) {
        final copy = Map<String, dynamic>.from(m);

        copy['timestampUtc'] =
            _normalizeIsoNoMillis((copy['timestampUtc'] ?? '').toString());
        copy['queuedAtUtc'] =
            _normalizeIsoNoMillis((copy['queuedAtUtc'] ?? '').toString());

        return copy;
      }).toList();

      return const JsonEncoder.withIndent('  ').convert(cleaned);
    }

    Future<void> copyToClipboard(String label, String text) async {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      setState(() => _message = "$label copied to clipboard.");
    }

    await showDialog<void>(
      context: context,
      builder: (_) {
        final csv = buildCsv(items);
        final json = buildJson(items);

        return AlertDialog(
          title: const Text("Punch History (Offline Queue)"),
          content: SizedBox(
            width: 860,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Pending punches: $_pendingCount"),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => copyToClipboard("CSV export", csv),
                      child: const Text("Copy CSV"),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => copyToClipboard("JSON export", json),
                      child: const Text("Copy JSON"),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "(paste into email/notes for admins)",
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: items.map((m) {
                        final kioskId = (m['kioskId'] ?? '').toString();
                        final emp = (m["employeeId"] ?? "").toString();
                        final type = (m["punchType"] ?? "").toString();
                        final ts = _normalizeIsoNoMillis((m["timestampUtc"] ?? "").toString());
                        final seq = (m["localSequenceNumber"] ?? "").toString();

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            "Kiosk: $kioskId | Emp: $emp | Type: $type | Seq: $seq | UTC: $ts",
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // ===== Timestamp helpers (NO milliseconds) =====

  /// ISO 8601 UTC with seconds only: YYYY-MM-DDTHH:mm:ssZ
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

  /// If an ISO string includes fractional seconds, strip them for display/export.
  /// Example: 2026-03-03T10:11:12.345Z -> 2026-03-03T10:11:12Z
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

                  // Top-right: Sync + Config Sync (regular buttons; NOT admin-gated)
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

                  // Bottom-right version label (NOT clickable)
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