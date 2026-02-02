import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../data/remote/timeclock_api.dart';
import '../../data/models/punch.dart';

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
  final int deviceType = 1;
  final String deviceId = "WEB-TEST-01";
  int localSeq = 1;

  @override
  void initState() {
    super.initState();
    _api = TimeClockApi(ApiClient());
    _load();
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

    try {
      final punchType = _clockedIn ? 2 : 1;

      await _api.punch(PunchRequest(
        employeeId: widget.employeeGuid,
        punchType: punchType,
        deviceType: deviceType,
        deviceId: deviceId,
        localSequenceNumber: localSeq++,
      ));

      await _load();
    } catch (e) {
      setState(() => _msg = "Punch failed: $e");
    } finally {
      setState(() => _loading = false);
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