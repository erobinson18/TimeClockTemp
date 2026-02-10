import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/tablet/tablet_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter(); // tablet storage

  runApp(const TimeClockApp());
}

class TimeClockApp extends StatelessWidget {
  const TimeClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TabletScreen(),
    );
  }
}
