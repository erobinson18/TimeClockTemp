import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/api_client.dart';
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

  // Kiosk entry
  String _employeeNumber = "";
  bool _verifying = false;
  bool _punching = false;

  // Verified employee session
  bool _verified = false;
  String? _employeeGuid;
  String? _fullName;
  bool _clockedIn = false;

  String? _message;
  int _pendingCount = 0;

  static const int deviceType = 1;
  static const String deviceId = "KIOSK-TEST-01";

  bool _forceOffline = false;

  Timer? _clockTimer;
  Timer? _syncTimer;
  DateTime _now = DateTime.now();

  DateTime? _lastSyncAttemptLocal;

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
    super.dispose();
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

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

  Future<bool> _isOnline() async {
    if (_forceOffline) return false;

    if (kIsWeb) {
      try {
        await _api.ping();
        return true;
      } catch (_) {
        return false;
      }
    }

    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none)) return false;

    try {
      await _api.ping();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _warmupRoster() async {
    try {
      if (!await _isOnline()) return;
      final items = await _api.rosterAll();
      final json = items.map((e) => e.toJson()).toList();
      await _rosterCache.saveAll(json);
    } catch (_) {
      // ignore
    }
  }

  void _applyVerified(VerifyResponse res, {required String message}) {
    setState(() {
      _verified = true;
      _employeeGuid = res.employeeId;
      _fullName = res.fullName;
      _clockedIn = res.isClockedIn;
      _message = message;
    });
  }

  Future<void> _refreshPending() async {
    final c = await _queue.count();
    if (!mounted) return;
    setState(() => _pendingCount = c);
  }

  Future<void> _trySync() async {
    try {
      _lastSyncAttemptLocal = DateTime.now();

      if (!await _isOnline()) return;

      final pending = await _queue.all();
      if (pending.isEmpty) return;

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
      setState(() => _message = "Synced ${result.processed} punch(es).");

      if (_employeeGuid != null) {
        await _loadStatus(_employeeGuid!);
      }
    } catch (_) {
      // kiosk: keep quiet
    }
  }

  Future<void> _verifyEmployee() async {
    if (_employeeNumber.isEmpty) {
      setState(() => _message = "Enter your Employee ID.");
      return;
    }

    setState(() {
      _verifying = true;
      _message = null;
    });

    try {
      if (await _isOnline()) {
        await _warmupRoster();

        final res = await _api.verify(_employeeNumber);

        if (!res.isValid) {
          setState(() => _message = "Invalid Employee ID");
          return;
        }

        final guid = res.employeeId;
        if (guid == null || guid.trim().isEmpty) {
          setState(() => _message = "Verify failed: missing employee GUID.");
          return;
        }

        _applyVerified(res, message: "Verified.");

        await _statusCache.setIsClockedIn(guid, res.isClockedIn);

        await _loadStatus(guid);
        return;
      }

      // OFFLINE verify
      final cached = await _rosterCache.findByEmployeeNumber(_employeeNumber);
      if (cached == null) {
        setState(() => _message = "Employee not found (offline).");
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
      setState(() => _message = "Verify failed");
    } finally {
      if (!mounted) return;
      setState(() => _verifying = false);
    }
  }

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

  Future<void> _doPunch() async {
    if (!_verified || _employeeGuid == null) {
      setState(() => _message = "Verify first.");
      return;
    }

    setState(() {
      _punching = true;
      _message = null;
    });

    // 0 = ClockIn, 1 = ClockOut
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

    // optimistic toggle
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
        setState(() =>
            _message = "Offline: Punch queued ($_pendingCount pending).");

        Future.delayed(const Duration(seconds: 2), _resetSession);
      }
    } catch (_) {
      await _queue.enqueue(queuedPayload);
      await _refreshPending();

      if (!mounted) return;
      setState(() => _message = "Punch queued ($_pendingCount pending).");

      Future.delayed(const Duration(seconds: 2), _resetSession);
    } finally {
      if (!mounted) return;
      setState(() => _punching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Global scale down so it fits more tablets nicely.
    return LayoutBuilder(
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
                Padding(
                  padding: EdgeInsets.all(s(24)),
                  child: Row(
                    children: [
                      // Left panel
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

                // Top-left: pending + last sync attempt
                Positioned(
                  left: s(24),
                  top: s(10),
                  child: Text(
                    _lastSyncAttemptLocal == null
                        ? "Pending offline punches: $_pendingCount"
                        : "Last Sync Attempt: ${_formatSyncStamp(_lastSyncAttemptLocal!)}   |   Pending: $_pendingCount",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: s(12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Top-right: Sync + Offline toggle
                Positioned(
                  right: s(24),
                  top: s(10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _trySync,
                        child: Text(
                          "Sync Now",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: s(12),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: s(8)),
                      TextButton(
                        onPressed: () =>
                            setState(() => _forceOffline = !_forceOffline),
                        child: Text(
                          _forceOffline ? "OFFLINE: ON" : "OFFLINE: OFF",
                          style: TextStyle(
                            color: _forceOffline
                                ? Colors.orange.withOpacity(0.9)
                                : Colors.white.withOpacity(0.75),
                            fontSize: s(12),
                            fontWeight: FontWeight.w800,
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
                    "ver 4.0.0",
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

          // TIME
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

          // ✅ LOGO ALWAYS VISIBLE
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

          // ✅ Employee info ABOVE the clock button (logo never swaps out)
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

          // Clock button
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