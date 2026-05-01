import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/services/secure_hive.dart';

// Screens
import 'core/features/startup/startup_gate_screen.dart';
import 'core/features/tablet/tablet_screen.dart';
import 'core/features/verify/verify_screen.dart';
import 'core/features/status/status_screen.dart';

class Routes {
  static const String startup = '/startup';
  static const String tablet = '/';
  static const String verify = '/verify';
  static const String status = '/status';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await SecureHive.init();

  await Hive.openBox('device', encryptionCipher: SecureHive.cipher);
  await Hive.openBox('punch_queue', encryptionCipher: SecureHive.cipher);
  await Hive.openBox('roster_cache', encryptionCipher: SecureHive.cipher);
  await Hive.openBox('status_cache', encryptionCipher: SecureHive.cipher);
  await Hive.openBox('punch_log', encryptionCipher: SecureHive.cipher);

  await SystemChrome.setPreferredOrientations(const []);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const TimeClockApp());
}

class TimeClockApp extends StatelessWidget {
  const TimeClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TSG Time Clock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),

      // Web is protected by TSG VPN/network access, so it opens directly.
      // Android/iOS still use startup routing for wall tablet/mobile setup.
      initialRoute: kIsWeb ? Routes.tablet : Routes.startup,

      onGenerateRoute: (settings) {
        switch (settings.name) {
          case Routes.startup:
            return MaterialPageRoute(
              builder: (_) => const StartupGateScreen(),
            );

          case Routes.tablet:
            return MaterialPageRoute(
              builder: (_) => const TabletScreen(),
            );

          case Routes.verify:
            return MaterialPageRoute(
              builder: (_) => const VerifyScreen(),
            );

          case Routes.status:
            final guid = settings.arguments as String?;
            if (guid == null || guid.trim().isEmpty) {
              return MaterialPageRoute(
                builder: (_) => const Scaffold(
                  body: Center(
                    child: Text('Missing employee GUID'),
                  ),
                ),
              );
            }

            return MaterialPageRoute(
              builder: (_) => StatusScreen(employeeGuid: guid),
            );

          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(
                  child: Text('Route not found'),
                ),
              ),
            );
        }
      },
    );
  }
}