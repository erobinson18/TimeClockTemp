import 'package:flutter/material.dart';
import 'features/tablet/tablet_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TimeClock',
      home: const TabletScreen(),
    );
  }
}
