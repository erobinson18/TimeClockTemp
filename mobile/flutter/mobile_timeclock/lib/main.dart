import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:mobile_timeclock/core/services/secure_hive.dart';
import 'package:mobile_timeclock/core/features/tablet/tablet_screen.dart';
import 'package:mobile_timeclock/core/features/verify/verify_screen.dart';
import 'package:mobile_timeclock/core/features/status/status_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await SecureHive.init();

  // If you are NOT using encryption yet, replace these openBox calls
  // with plain Hive.openBox('device') etc.
  await Hive.openBox('device', encryptionCipher: SecureHive.cipher);
  await Hive.openBox('punch_queue', encryptionCipher: SecureHive.cipher);
  await Hive.openBox('roster_cache', encryptionCipher: SecureHive.cipher);
  await Hive.openBox('status_cache', encryptionCipher: SecureHive.cipher);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const TimeClockApp());
}

class TimeClockApp extends StatelessWidget {
  const TimeClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      initialRoute: Routes.tablet,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case Routes.tablet:
            return MaterialPageRoute(builder: (_) => const TabletScreen());

          case Routes.verify:
            return MaterialPageRoute(builder: (_) => const VerifyScreen());

          case Routes.status:
            final guid = settings.arguments as String?;
            if (guid == null || guid.trim().isEmpty) {
              return MaterialPageRoute(
                builder: (_) => const _RouteErrorScreen(
                  message: "Missing employeeGuid for StatusScreen",
                ),
              );
            }
            return MaterialPageRoute(
              builder: (_) => StatusScreen(employeeGuid: guid),
            );

          default:
            return MaterialPageRoute(
              builder: (_) => _RouteErrorScreen(
                message: "Unknown route: ${settings.name}",
              ),
            );
        }
      },
    );
  }
}

class Routes {
  static const tablet = '/';
  static const verify = '/verify';
  static const status = '/status';
}

class _RouteErrorScreen extends StatelessWidget {
  final String message;
  const _RouteErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}