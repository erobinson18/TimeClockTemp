import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../data/remote/timeclock_api.dart';
import '../status/status_screen.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _employeeNumberCtrl = TextEditingController();
  late final TimeClockApi _api;

  bool _loading = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _api = TimeClockApi(ApiClient());
  }

  @override
  void dispose() {
    _employeeNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final empNum = _employeeNumberCtrl.text.trim();
    if (empNum.isEmpty) {
      setState(() => _msg = "Enter your Employee ID");
      return;
    }

    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final res = await _api.verify(empNum);

      // If your backend includes isValid, respect it
      if (!res.isValid || res.employeeId == null || res.employeeId!.isEmpty) {
        setState(() => _msg = "Invalid Employee ID");
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StatusScreen(employeeGuid: res.employeeId!),
        ),
      );
    } catch (_) {
      // Invalid employee will typically be 401 -> Dio throws -> we land here
      setState(() => _msg = "Verify failed");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("TimeClock - Verify")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _employeeNumberCtrl,
              decoration: const InputDecoration(labelText: "Employee ID"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _verify,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Verify"),
            ),
            if (_msg != null) ...[
              const SizedBox(height: 12),
              Text(_msg!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
