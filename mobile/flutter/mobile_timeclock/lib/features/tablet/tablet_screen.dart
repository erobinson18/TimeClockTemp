import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/api_client.dart';
import '../../data/local/punch_queue.dart';
import '../../data/models/punch.dart';
import '../../data/models/status.dart';
import '../../data/models/sync.dart';
import '../../data/models/verify.dart';
import '../../data/remote/timeclock_api.dart';
import '../../data/local/roster_cache.dart';

class TabletScreen extends StatefulWidget {
  const TabletScreen({super.key});

  @override
  State<TabletScreen> createState() => _TabletScreenState();
}

class _TabletScreenState extends State<TabletScreen> {
  late final TimeClockApi _api;
  final _queue = PunchQueue();
  final _rosterCache = RosterCache();

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

  // Device info (backend expects ints 1,2 etc.)
  // Adjust these if your enums differ.
  static const int deviceType = 1;
  static const String deviceId = "KIOSK-TEST-01";

  // local sequence (simple in-memory counter for now)
  int _localSeq = 0;
  bool _forceOffline = false;

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _api = TimeClockApi(ApiClient());

    _refreshPending();
    _startClock();
    _warmupRoster();

    // optional: auto-sync attempt on launch
    _trySync();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
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
      if (_employeeNumber.length >= 6) return; // 5-6 digits typical
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
      // Do not clear verified state automatically, because “Clear” is keypad clear.
      // If you want a full reset, use _resetSession().
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
  // OFFLINE + SYNC
  // ----------------------------
  Future<void> _refreshPending() async {
    final c = await _queue.count();
    setState(() => _pendingCount = c);
  }

  // For testing offline stacking:
  // This simply treats network errors as "offline" and queues punches.
  Future<bool> _isOnline() async {
    if (_forceOffline) return false;

    try {
      await _api.ping(); // cheap GET
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _warmupRoster() async {
  try {
    if (!await _isOnline()) return;
    final roster = await _api.rosterAll();
    await _rosterCache.saveAll(roster.map((e) => e.toJson()).toList());
  } catch (_) {
    // silent
  }
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

      // refresh current employee status if a person is verified
      if (_employeeGuid != null) {
        await _loadStatus(_employeeGuid!);
      }
    } catch (e) {
      setState(() => _message = "Sync failed: $e");
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
      // Verify by number (backend returns GUID + full name + optional clocked state)
      final VerifyResponse result = await _api.verify(_employeeNumber);

      // IMPORTANT:
      // Your VerifyResponse must include:
      // - employeeId (GUID string)
      // - fullName (string)
      // - isClockedIn (bool) OR we query status after verify
      final guid = result.employeeId;
      final fullName = result.fullName;

      bool clocked = false;
      // If your verify response contains isClockedIn, use it:
      // otherwise we fetch status
      try {
        clocked = result.isClockedIn;
      } catch (_) {
        // ignore if field doesn't exist
      }

      setState(() {
        _verified = true;
        _employeeGuid = guid;
        _fullName = fullName;
        _clockedIn = clocked;
        _message = "Verified.";
      });

      // If verify doesn't carry clocked-in state reliably, load it from status endpoint.
      await _loadStatus(guid);

      // Try syncing in the background for the kiosk (employees don't need to see this)
      await _trySync();
    } catch (e) {
      setState(() {
        _verified = false;
        _employeeGuid = null;
        _fullName = null;
        _clockedIn = false;
        _message = "Verify failed: $e";
      });
    } finally {
      setState(() => _verifying = false);
    }
  }

  Future<void> _loadStatus(String guid) async {
    try {
      final StatusResponse s = await _api.status(guid);
      setState(() => _clockedIn = s.isClockedIn);
    } catch (e) {
      // Don’t hard-fail kiosk, just show message
      setState(() => _message = "Status check failed: $e");
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
    final seq = _localSeq++;

    // Payload used for offline queue (and sync later)
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
        ));

        // refresh status
        await _loadStatus(_employeeGuid!);

        setState(() {
          _message = punchType == 1 ? "Clock In recorded." : "Clock Out recorded.";
        });

        // reset for next employee
        _resetSession();
      } else {
        // Offline: queue punch
        await _queue.enqueue(queuedPayload);
        await _refreshPending();

        setState(() {
          _message = "Offline: Punch queued ($_pendingCount pending).";
        });

        // flip local UI state so kiosk feels responsive even offline
        setState(() => _clockedIn = !_clockedIn);

        // reset for next employee
        _resetSession();
      }
    } catch (e) {
      // If online punch fails, queue it and continue
      await _queue.enqueue(queuedPayload);
      await _refreshPending();

      setState(() {
        _message = "Punch queued ($_pendingCount pending). Error: $e";
      });

      // flip local UI state to simulate the action
      setState(() => _clockedIn = !_clockedIn);

      _resetSession();
    } finally {
      setState(() => _punching = false);
    }
  }

  // ----------------------------
  // UI
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
            // Main layout
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // LEFT: keypad panel
                  SizedBox(
                    width: 420,
                    child: _buildLeftPanel(canVerify),
                  ),

                  const SizedBox(width: 24),

                  // RIGHT: clock + employee info + big action
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

            // Top-left small status (kiosk-friendly)
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

            // Top-right small sync indicator
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
          // entry display
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

          // keypad
          _buildKeypad(),

          const SizedBox(height: 14),

          // verify button
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
          // safety message / header line
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

          // big clock
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

          // employee info
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

          // punch button (big circle)
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
    // 1 2 3
    // 4 5 6
    // 7 8 9
    // CLEAR 0 VERIFY (verify button also exists below, but we match your kiosk)
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
