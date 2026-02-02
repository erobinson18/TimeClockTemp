import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  static String get baseUrl {
    if (kIsWeb) return "https://localhost:5160";
    if (Platform.isAndroid) return "http://10.0.2.2:5160";
    return "http://localhost:5160";
  }
}