import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/api_client.dart';
import '../../data/local/punch_queue.dart';
import '../../data/local/roster_cache.dart';
import '../../data/models/punch.dart';
import '../../data/models/status.dart';
import '../../data/models/sync.dart';
import '../../data/models/verify.dart';
import '../../data/remote/timeclock_api.dart';
import '../../data/local/local_seq_store.dart';


class TabletScreen extends StatefulWidget {
  const TabletScreen({super.key});

  @override
  State<TabletScreen> createState() => _TabletScreenState();
}

class _TabletScreenState extends State<TabletScreen> {
  late final TimeClockApi _api;
  final _queue = PunchQueue();
  final _rosterCache = RosterCache();
  final _connectivity = Connectivity();
  final _seqStore = LocalSeqStore();

  // Kiosk entry
  String _employeeNumber = "";
  bool _verifying = false;
  bool _punching = false;

  // Verified employee session
  bool _verified = false;
  String? _employeeGuid; // GUID from verify response
  String? _fullName;
  bool _clockedIn = false;

  // UX
  String? _message;
  int _pendingCount = 0;

  // Device info
  static const int deviceType = 1;
  static const String deviceId = "KIOSK-TEST-01";

  // local sequence
  int _localSeq = 0;
  bool _forceOffline = false;

  Timer? _clockTimer;
  Timer? _syncTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _api = TimeClockApi(ApiClient());

    _refreshPending();
    _startClock();

    // Warm roster so offline verify works
    _warmupRoster();

    // Auto-sync every 30s (optional, but recommended)
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) => _trySync());

    // optional: one sync on launch
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
      setState(() => _now = DateTime.now());
    });
  }

  // ----------------------------
  // KEYPAD INPUT
  // ----------------------------
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

  // ----------------------------
  // CONNECTIVITY
  // ----------------------------
  Future<bool> _isOnline() async {
    if (_forceOffline) return false;
    if (kIsWeb) return true;

    final result = await _connectivity.checkConnectivity();
    if (result == ConnectivityResult.none) return false;

    try {
      await _api.ping();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ----------------------------
  // ROSTER CACHE (OFFLINE VERIFY)
  // ----------------------------
  Future<void> _warmupRoster() async {
    try {
      if (!await _isOnline()) return;

      final items = await _api.rosterAll();
      final json = items.map((e) => e.toJson()).toList();
      await _rosterCache.saveAll(json);
    } catch (_) {
      // silent fail
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

  // ----------------------------
  // OFFLINE QUEUE + SYNC
  // ----------------------------
  Future<void> _refreshPending() async {
    final c = await _queue.count();
    setState(() => _pendingCount = c);
  }

  Future<void> _trySync() async {
    try {
      if (!await _isOnline()) return;

      final pending = await _queue.all();
      if (pending.isEmpty) return;

      final punches = pending.map((p) {
        final punchType = (p["punchType"] as num?)?.toInt() ?? 0;
        final localSeq = (p["localSequenceNumber"] as num?)?.toInt() ?? 0;
        final ts = p["timestampUtc"] as String? ??
            DateTime.now().toUtc().toIso8601String();

        return SyncPunch(
          employeeId: p["employeeId"] as String? ?? "",
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

      setState(() {
        _message = "Synced ${result.processed} punch(es).";
      });

      if (_employeeGuid != null) {
        await _loadStatus(_employeeGuid!);
      }
    } catch (_) {
      // keep silent for kiosk UX
    }
  }

  // ----------------------------
  // VERIFY + STATUS + PUNCH
  // ----------------------------
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
      // 1) ONLINE verify
      if (await _isOnline()) {
        await _warmupRoster();

        final res = await _api.verify(_employeeNumber);

        if (!res.isValid) {
          setState(() => _message = "Invalid Employee ID");
          return;
        }

        _applyVerified(res, message: "Verified.");
        return;
      }

      // 2) OFFLINE verify via roster cache
      final cached = await _rosterCache.findByEmployeeNumber(_employeeNumber);

      if (cached == null) {
        setState(() => _message = "Employee not found (offline).");
        return;
      }

      final offlineRes = VerifyResponse(
        isValid: true,
        employeeId: cached.employeeId,
        employeeNumber: cached.employeeNumber,
        fullName: cached.fullName,
        isClockedIn: false,
      );

      _applyVerified(offlineRes, message: "Verified (offline).");
    } catch (_) {
      setState(() => _message = "Verify failed");
    } finally {
      setState(() => _verifying = false);
    }
  }

  Future<void> _loadStatus(String guid) async {
    try {
      final StatusResponse s = await _api.status(guid);
      setState(() => _clockedIn = s.isClockedIn);
    } catch (_) {
      // silent
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

    final punchType = _clockedIn ? 2 : 1;
    final int seq = await _seqStore.next();

    final queuedPayload = <String, dynamic>{
      "employeeId": _employeeGuid!,
      "punchType": punchType,
      "localSequenceNumber": seq,
      "timestampUtc": DateTime.now().toUtc().toIso8601String(),
      "latitude": null,
      "longitude": null,
    };

    try {
      final online = await _isOnline();

      if (online) {
        await _api.punch(PunchRequest(
          employeeId: _employeeGuid!,
          punchType: punchType,
          deviceType: deviceType,
          deviceId: deviceId,
          localSequenceNumber: seq,
          timestampUtc: DateTime.now().toUtc(),
        ));

        await Future.delayed(const Duration(milliseconds: 150));
        await _loadStatus(_employeeGuid!);

        setState(() {
          _clockedIn = !_clockedIn;
          _message = punchType == 1 ? "Clock In recorded." : "Clock Out recorded.";
        });

        Future.delayed(const Duration(seconds: 2), _resetSession);

        _resetSession();
      } else {
        await _queue.enqueue(queuedPayload);
        await _refreshPending();

        setState(() {
          _message = "Offline: Punch queued ($_pendingCount pending).";
        });

        setState(() => _clockedIn = !_clockedIn);
        _resetSession();
      }
    } catch (e) {
      await _queue.enqueue(queuedPayload);
      await _refreshPending();

      setState(() {
        _message = "Punch queued ($_pendingCount pending).";
      });

      setState(() => _clockedIn = !_clockedIn);
      _resetSession();
    } finally {
      setState(() => _punching = false);
    }
  }

  // ----------------------------
  // UI (UNCHANGED DESIGN)
  // ----------------------------
  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  SizedBox(width: 420, child: _buildLeftPanel(canVerify)),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildRightPanel(
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
              left: 24,
              top: 10,
              child: Text(
                "Pending offline punches: $_pendingCount",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ),

            Positioned(
              right: 24,
              top: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: _trySync,
                    child: Text(
                      "Sync Now",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _forceOffline = !_forceOffline),
                    child: Text(
                      _forceOffline ? "OFFLINE: ON" : "OFFLINE: OFF",
                      style: TextStyle(
                        color: _forceOffline
                            ? Colors.orange.withOpacity(0.9)
                            : Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftPanel(bool canVerify) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
      ),
      child: Column(
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.18), width: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _employeeNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _employeeNumber.isEmpty ? null : _backspace,
                  icon: Icon(
                    Icons.backspace_outlined,
                    color: Colors.white.withOpacity(0.85),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildKeypad(),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: canVerify ? _verifyEmployee : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.14),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.white.withOpacity(0.18), width: 2),
                ),
              ),
              child: _verifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      "VERIFY",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel({
    required String timeStr,
    required String dateStr,
    required String actionText,
    required Color actionColor,
    required bool canPunch,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "HAVE YOU REMOVED YOUR LOCK TODAY?",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.red.withOpacity(0.9),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            timeStr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 92,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          Text(
            dateStr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          if (_verified && _fullName != null) ...[
            Text(
              _fullName!.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _clockedIn ? "You are currently IN" : "You are currently OUT",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            Text(
              "Enter your Employee ID, then press VERIFY.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Spacer(),
          Center(
            child: GestureDetector(
              onTap: canPunch ? _doPunch : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: canPunch ? 1.0 : 0.35,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: actionColor,
                    boxShadow: [
                      BoxShadow(
                        color: actionColor.withOpacity(0.35),
                        blurRadius: 22,
                        spreadRadius: 4,
                      )
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _punching
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          actionText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_message != null)
            Text(
              _message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _keypadRow(["1", "2", "3"]),
        _keypadRow(["4", "5", "6"]),
        _keypadRow(["7", "8", "9"]),
        Row(
          children: [
            Expanded(
              child: _keyButton(
                label: "CLEAR",
                onTap: _clearEntry,
                filled: true,
                fontSize: 18,
              ),
            ),
            Expanded(
              child: _keyButton(
                label: "0",
                onTap: () => _appendDigit("0"),
              ),
            ),
            Expanded(
              child: _keyButton(
                label: "VERIFY",
                onTap: _verifyEmployee,
                filled: true,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keypadRow(List<String> labels) {
    return Row(
      children: labels
          .map(
            (l) => Expanded(
              child: _keyButton(
                label: l,
                onTap: () => _appendDigit(l),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _keyButton({
    required String label,
    required VoidCallback onTap,
    bool filled = false,
    double fontSize = 26,
  }) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 78,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.20), width: 2),
            color: filled ? Colors.white.withOpacity(0.12) : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
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
}
