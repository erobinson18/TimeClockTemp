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
  final _employeeIdCtrl = TextEditingController();
  final _employeeGuidCtrl = TextEditingController(); // Temp for testing
  late final TimeClockApi _api;

  bool _loading = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _api = TimeClockApi(ApiClient());
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _msg = null;
    });

    try {
      final res = await _api.verify(_employeeIdCtrl.text.trim());
      if (!res.isValid) {
        setState(() => _msg = "Invalid Employee ID");
        return;
      }

      final guid = _employeeGuidCtrl.text.trim();
      if (guid.isEmpty) {
        setState(() => _msg = "Verified. Enter Employee GUID (for testing).");
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StatusScreen(employeeGuid: guid)),
      );
    } catch (e) {
      setState(() => _msg = "Verify failed: $e");
    } finally {
      setState(() => _loading = false);
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
              controller: _employeeIdCtrl,
              decoration: const InputDecoration(labelText: "Employee ID"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _employeeGuidCtrl,
              decoration: const InputDecoration(
                labelText: "Employee GUID (testing)"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _verify,
              child: _loading
                  ? const CircularProgressIndicator()
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