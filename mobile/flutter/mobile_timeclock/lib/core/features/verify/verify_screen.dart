import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../api_client.dart';
import '../../../data/remote/timeclock_api.dart';
import '../../../data/local/roster_cache.dart';
import '../../../data/local/status_cache.dart';
import '../../../main.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  late final TimeClockApi _api;
  final _rosterCache = RosterCache();
  final _statusCache = StatusCache();
  final _connectivity = Connectivity();

  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _api = TimeClockApi(ApiClient());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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

  Future<void> _warmupRoster() async {
    final items = await _api.rosterAll();
    final json = items.map((e) => e.toJson()).toList();
    await _rosterCache.saveAll(json);
  }

  Future<void> _verify() async {
    final nav = Navigator.of(context); // capture BEFORE awaits

    final empNum = _ctrl.text.trim();
    if (empNum.isEmpty) {
      setState(() => _msg = "Enter your Employee ID.");
      return;
    }

    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      if (await _isOnline()) {
        await _warmupRoster();
      }

      final cached = await _rosterCache.findByEmployeeNumber(empNum);
      if (cached == null) {
        if (mounted) setState(() => _msg = "Invalid Employee ID.");
        return;
      }

      // Optional: read cached status for UX (not required for navigation)
      _statusCache.getIsClockedIn(cached.employeeId);

      if (!mounted) return;
      nav.pushNamed(Routes.status, arguments: cached.employeeId);
    } catch (e) {
      if (mounted) setState(() => _msg = "Verify failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Employee ID",
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text("VERIFY"),
              ),
            ),
            if (_msg != null) ...[
              const SizedBox(height: 12),
              Text(_msg!),
            ],
          ],
        ),
      ),
    );
  }
}