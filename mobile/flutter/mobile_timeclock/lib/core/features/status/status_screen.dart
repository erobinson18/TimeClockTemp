import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../api_client.dart';
import '../../../data/remote/timeclock_api.dart';
import '../../../data/models/punch.dart';
import '../../../data/models/sync.dart';
import '../../../data/local/punch_queue.dart';
import '../../../data/local/local_seq_store.dart';
import '../../../data/local/status_cache.dart';

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
  bool _forceOffline = false;
  String? _msg;

  String? _employeeName;
  String? _rawStatus;

  static const int deviceType = 1;
  static const String deviceId = "KIOSK-TEST-01";

  final _queue = PunchQueue();
  final _connectivity = Connectivity();
  final _seqStore = LocalSeqStore();
  final _statusCache = StatusCache();

  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();

    _api = TimeClockApi(ApiClient(
      log: (m) => debugPrint(m),
    ));

    _hydrateFromCache();
    _load();
    _refreshPending();
  }

  void _hydrateFromCache() {
    final cachedClockedIn = _statusCache.getIsClockedIn(widget.employeeGuid);
    final cachedName = _statusCache.getDisplayName(widget.employeeGuid);
    final cachedRaw = _statusCache.getRawStatus(widget.employeeGuid);

    setState(() {
      if (cachedClockedIn != null) _clockedIn = cachedClockedIn;
      _employeeName = cachedName;
      _rawStatus = cachedRaw;
    });
  }

  bool get _isAmbiguousStatus {
    final s = _rawStatus?.trim().toUpperCase();
    if (s == null || s.isEmpty) return true;
    return !(s == 'IN' || s == 'OUT');
  }

  Future<void> _applyStatusAndCache({
    required bool isClockedIn,
    String? fullName,
    String? rawStatus,
  }) async {
    setState(() {
      _clockedIn = isClockedIn;
      if (fullName != null && fullName.trim().isNotEmpty) {
        _employeeName = fullName.trim();
      }
      if (rawStatus != null && rawStatus.trim().isNotEmpty) {
        _rawStatus = rawStatus.trim();
      }
    });

    await _statusCache.setIsClockedIn(widget.employeeGuid, isClockedIn);

    if (fullName != null && fullName.trim().isNotEmpty) {
      await _statusCache.setDisplayName(widget.employeeGuid, fullName.trim());
    }

    if (rawStatus != null && rawStatus.trim().isNotEmpty) {
      await _statusCache.setRawStatus(widget.employeeGuid, rawStatus.trim());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final s = await _api.status(widget.employeeGuid);
      if (!mounted) return;

      await _applyStatusAndCache(
        isClockedIn: s.isClockedIn,
        fullName: s.fullName,
        rawStatus: s.rawStatus,
      );

      if (_isAmbiguousStatus && mounted) {
        setState(() => _msg = "Status received but looked weird. Tap refresh.");
      }
    } catch (e) {
      if (mounted) setState(() => _msg = "Status failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _isOnline() async {
    if (_forceOffline) return false;

    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none)) return false;

    try {
      await _api.ping();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshPending() async {
    final c = await _queue.count();
    if (!mounted) return;
    setState(() => _pendingCount = c);
  }

  Future<void> _doPunch() async {
    setState(() {
      _msg = null;
      _loading = true;
    });

    final int punchType = _clockedIn ? 1 : 0; // 0=IN, 1=OUT (local UX only)
    final int seq = _seqStore.next();
    final nowUtc = DateTime.now().toUtc();

    final payload = <String, dynamic>{
      'employeeId': widget.employeeGuid,
      'punchType': punchType,
      'localSequenceNumber': seq,
      'timestampUtc': nowUtc.toIso8601String(),
      'latitude': null,
      'longitude': null,
    };

    try {
      final online = await _isOnline();

      // Online + ambiguous => force refresh; do not guess.
      if (online && _isAmbiguousStatus) {
        if (mounted) {
          setState(() {
            _msg = "Status unclear. Please refresh before punching.";
            _loading = false;
          });
        }
        return;
      }

      // Optimistic local update for UX (will be corrected by server on success)
      final bool optimisticClockedIn = (punchType == 0);
      await _applyStatusAndCache(
        isClockedIn: optimisticClockedIn,
        rawStatus: optimisticClockedIn ? "IN" : "OUT",
      );

      if (online) {
        // Server-truth punch: CollectPunches then GetStatus and return final status
        final s = await _api.punchAndGetStatus(PunchRequest(
          employeeId: widget.employeeGuid,
          punchType: punchType,
          deviceType: deviceType,
          deviceId: deviceId,
          localSequenceNumber: seq,
          timestampUtc: nowUtc,
        ));

        if (!mounted) return;

        await _applyStatusAndCache(
          isClockedIn: s.isClockedIn,
          fullName: s.fullName,
          rawStatus: s.rawStatus,
        );
      } else {
        await _queue.enqueue(payload);
        await _refreshPending();
        if (mounted) {
          setState(() => _msg = "Offline: Punch queued ($_pendingCount pending).");
        }
      }
    } catch (e) {
      // If punch fails, queue for safety
      try {
        await _queue.enqueue(payload);
        await _refreshPending();
      } catch (_) {
        // ignore queue failure; show original error
      }

      if (mounted) {
        setState(() => _msg = "Punch failed; queued if possible. Error: $e");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _trySync() async {
    setState(() => _msg = null);

    try {
      if (!await _isOnline()) {
        if (mounted) setState(() => _msg = "Offline: cannot sync.");
        return;
      }

      final pending = await _queue.all();
      if (pending.isEmpty) {
        if (mounted) setState(() => _msg = "No pending punches.");
        return;
      }

      final punches = pending.map((p) {
        final punchType = (p["punchType"] as num?)?.toInt() ?? 0;
        final localSeq = (p["localSequenceNumber"] as num?)?.toInt() ?? 0;
        final ts = p["timestampUtc"] as String? ??
            DateTime.now().toUtc().toIso8601String();

        return SyncPunch(
          employeeId: (p["employeeId"] as String?) ?? widget.employeeGuid,
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

      // Remove only punches confirmed sent successfully
      await _queue.removeByLocalSeq(result.acceptedSeq.toSet());

      await _refreshPending();
      await _load();

      if (mounted) {
        setState(() => _msg = "Synced ${result.acceptedSeq.length} punches.");
      }
    } catch (e) {
      if (mounted) setState(() => _msg = "Sync failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonText = _clockedIn ? "Clock Out" : "Clock In";

    final displayName = (_employeeName == null || _employeeName!.trim().isEmpty)
        ? "(unknown)"
        : _employeeName!.trim();

    final displayRaw = (_rawStatus == null || _rawStatus!.trim().isEmpty)
        ? (_clockedIn ? "IN" : "OUT")
        : _rawStatus!.trim().toUpperCase();

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
            const SizedBox(height: 8),
            Text("Employee: $displayName"),
            const SizedBox(height: 8),
            Text("Server Status: $displayRaw"),
            const SizedBox(height: 12),
            Text("Pending offline punches: $_pendingCount"),
            Row(
              children: [
                const Text("Offline Mode (force queue)"),
                Switch(
                  value: _forceOffline,
                  onChanged: (v) => setState(() => _forceOffline = v),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _loading ? null : _trySync,
              child: const Text("Sync Now"),
            ),
            ElevatedButton(
              onPressed: () async {
                await _queue.clear();
                await _refreshPending();
                if (!mounted) return;
                setState(() => _msg = "Cleared pending punches.");
              },
              child: const Text("Clear Offline Queue"),
            ),
            const SizedBox(height: 10),
            Text("Local Status: ${_clockedIn ? "CLOCKED IN" : "CLOCKED OUT"}"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _doPunch,
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