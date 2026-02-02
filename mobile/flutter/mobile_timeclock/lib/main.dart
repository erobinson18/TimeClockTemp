import 'package:flutter/material.dart';
import 'features/verify/verify_screen.dart';

void main() {
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