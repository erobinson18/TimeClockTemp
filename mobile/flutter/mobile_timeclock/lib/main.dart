import 'package:flutter/material.dart';
import 'features/verify/verify_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const TimeClockApp());
}

class TimeClockApp extends StatelessWidget {
  const TimeClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TimeClock',
      theme: ThemeData(useMaterial3: true),
      home: const VerifyScreen(),
    );
  }
}