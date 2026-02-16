import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'features/tablet/tablet_screen.dart';
import 'features/verify/verify_screen.dart';
import 'features/status/status_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter(); // tablet storage
  await Hive.openBox('device');

  // Kiosk default: Landscape only (Android + iOS)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Optional: full-screen kiosk look (hides status/nav bars)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const TimeClockApp());
}

class TimeClockApp extends StatelessWidget {
  const TimeClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // Shared theme across Android/iOS/Web (doesn’t change your TabletScreen widgets)
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),

      // Default screen (kiosk)
      initialRoute: Routes.tablet,

      // Central routing so web/app can share the same structure later
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
        child: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
