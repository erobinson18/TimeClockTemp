import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../data/remote/timeclock_api.dart';
import '../../data/models/employee_directory_item.dart';

class TabletScreen extends StatefulWidget {
  const TabletScreen({super.key});

  @override
  State<TabletScreen> createState() => _TabletScreenState();
}

class _TabletScreenState extends State<TabletScreen> {
  late final TimeClockApi _api;

  String _entered = '';
  bool _loading = false;

  EmployeeDirectoryItem? _verified;
  String? _message;

  @override
  void initState() {
    super.initState();
    _api = TimeClockApi(ApiClient());
  }

  void _tap(String digit) {
    setState(() {
      _message = null;
      if (_entered.length < 6) _entered += digit; // 5–6 digits
    });
  }

  void _clear() {
    setState(() {
      _entered = '';
      _verified = null;
      _message = null;
    });
  }

  Future<void> _verify() async {
    if (_entered.length < 5) {
      setState(() => _message = 'Enter a 5–6 digit employee ID.');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
      _verified = null;
    });

    try {
      final roster = await _api.rosterAll();
      final match = roster.firstWhere(
        (e) => e.employeeNumber == _entered,
        orElse: () => EmployeeDirectoryItem(
          employeeId: '',
          employeeNumber: '',
          fullName: '',
        ),
      );

      if (match.employeeId.isEmpty) {
        setState(() => _message = 'Employee not found.');
      } else {
        setState(() => _verified = match);
      }
    } catch (e) {
      setState(() => _message = 'Verify failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _key(String label, {VoidCallback? onPressed}) {
    return SizedBox(
      width: 110,
      height: 90,
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        child: Text(label, style: const TextStyle(fontSize: 28)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              '${now.month}/${now.day}/${now.year}  ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please enter your Employee ID, then press VERIFY.',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 18),

            // Top row: entry + verify button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    readOnly: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'Employee ID',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    controller: TextEditingController(text: _entered),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 200,
                  height: 70,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verify,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('VERIFY', style: TextStyle(fontSize: 26)),
                  ),
                )
              ],
            ),

            const SizedBox(height: 18),

            if (_verified != null) ...[
              Text(
                _verified!.fullName,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text('Verified. Ready to clock in/out.', style: TextStyle(fontSize: 18)),
            ],

            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(_message!, style: const TextStyle(fontSize: 18)),
            ],

            const SizedBox(height: 22),

            // keypad
            Expanded(
              child: Center(
                child: Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: [
                    _key('1', onPressed: () => _tap('1')),
                    _key('2', onPressed: () => _tap('2')),
                    _key('3', onPressed: () => _tap('3')),
                    _key('4', onPressed: () => _tap('4')),
                    _key('5', onPressed: () => _tap('5')),
                    _key('6', onPressed: () => _tap('6')),
                    _key('7', onPressed: () => _tap('7')),
                    _key('8', onPressed: () => _tap('8')),
                    _key('9', onPressed: () => _tap('9')),
                    _key('CLEAR', onPressed: _clear),
                    _key('0', onPressed: () => _tap('0')),
                    _key('⌫', onPressed: () {
                      setState(() {
                        _message = null;
                        if (_entered.isNotEmpty) {
                          _entered = _entered.substring(0, _entered.length - 1);
                        }
                      });
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
