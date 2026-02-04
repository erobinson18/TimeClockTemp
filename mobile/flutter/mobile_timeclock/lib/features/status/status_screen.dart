import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/api_client.dart';
import '../../data/remote/timeclock_api.dart';
import '../../data/models/punch.dart';
import '../../data/models/sync.dart';
import '../../data/local/punch_queue.dart';

class StatusScreen extends StatefulWidget {
  final String employeeGuid;
  const StatusScreen({super.key, required this.employeeGuid});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  late final TimeClockApi _api;

  bool _loading = true;
  bool _clockedIn = false;
  String? _msg;

  // Adjust later if your enums differ:
  static const int deviceType = 1; 
  static const String deviceId = "WEB-TEST-01"; 
  int localSeq = 0;
  final _queue = PunchQueue();
  final _connectivity = Connectivity();
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _api = TimeClockApi(ApiClient());
    _load();
    _refreshPending();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final s = await _api.status(widget.employeeGuid);
      setState(() => _clockedIn = s.isClockedIn);
    } catch (e) {
      setState(() => _msg = "Status failed: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _doPunch() async {
    setState(() {
      _msg = null;
      _loading = true;
    });

      final punchType = _clockedIn ? 2 : 1;

      final seq = localSeq++;
      localSeq++;

      final payload = {
        'employeeId': widget.employeeGuid,
        'punchType': punchType,
        'localSequenceNumber': seq,
        'timestampUtc': DateTime.now().toUtc().toIso8601String(),
        'latitude': null,
        'longitude': null,
        };

        try {
          if (await _isOnline()) {
            await _api.punch(PunchRequest(
              employeeId: widget.employeeGuid,
              punchType: punchType,
              deviceType: deviceType,
              deviceId: deviceId,
              localSequenceNumber: payload['localSequenceNumber'] as int,
            ));
            await _load();
          } else {
            await _queue.enqueue(payload);
            await _refreshPending();
            setState(() => _msg = "Offline: Punch queued ($_pendingCount pending).");
          }
        } catch (e) {
          // if online punch fails, queue it
          await _queue.enqueue(payload);
          await _refreshPending();
          setState(() => _msg = "Punch failed; queued ($_pendingCount pending). Error: $e");
        } finally {
          setState(() => _loading = false);
        }
        }

  Future<bool> _isOnline() async {
    if (kIsWeb) return true; // Assume web is always online for this example
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

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
      final ts = p["timestampUtc"] as String? ?? DateTime.now().toUtc().toIso8601String();

      return SyncPunch(
        employeeId: p["employeeId"] as String? ?? widget.employeeGuid,
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

    await _api.syncBatch(batch);
    await _queue.clear();
    await _refreshPending();
    await _load();
    setState(() => _msg = "Synced ${punches.length} punches.");
  } catch (e) {
    setState(() => _msg = "Sync failed: $e");
  }
}

  @override
  Widget build(BuildContext context) {
    final buttonText = _clockedIn ? "Clock Out" : "Clock In";

    return Scaffold(
      appBar: AppBar(
        title: const Text("TimeClock - Status"),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Employee GUID: ${widget.employeeGuid}"),
                  const SizedBox(height: 12),
                  Text("Pending offline punches: $_pendingCount"),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _loading ? null : _trySync,
                    child: const Text("Sync Now"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _queue.clear();
                      await _refreshPending();
                      setState(() => _msg = "Cleared pending punches.");
                    },
                    child: const Text("Clear Offline Queue"),
                  ),
                  const SizedBox(height: 10),
                  Text("Status: ${_clockedIn ? "CLOCKED IN" : "CLOCKED OUT"}"),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _doPunch,
                    child: Text(buttonText),
                  ),
                  if (_msg != null) ...[
                    const SizedBox(height: 12),
                    Text(_msg!),
                  ]
                ],
              ),
      ),
    );
  }
}