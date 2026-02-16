import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Central place for environment + API base URLs.
/// Usage:
///   final baseUrl = AppConfig.baseUrl;
/// Override without code changes:
///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5160
///   flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:5160
///   flutter run -d <device> --dart-define=API_BASE_URL=http://192.168.1.50:5160
class AppConfig {
  // 1) Prefer compile-time override (best for CI/CD + different environments)
  static const String _definedBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  // 2) Fallback defaults per platform
  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;

    if (kIsWeb) {
      // Website version (browser)
      return 'http://localhost:5160';
    }

    // Native: emulator/simulator defaults
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator -> host machine
        return 'http://10.0.2.2:5160';

      case TargetPlatform.iOS:
        // iOS simulator can reach host via localhost
        return 'http://localhost:5160';

      default:
        // Desktop (Windows/macOS/Linux)
        return 'http://localhost:5160';
    }
  }
}
