import 'package:hive_flutter/hive_flutter.dart';

class DeviceConfigService {
  static const String boxName = 'device';

  static const String _kBaseUrlKey = 'baseUrl';
  static const String _kKioskIdKey = 'kioskId';
  static const String _kAuthTokenKey = 'authToken';

  // Defaults (used if box is empty)
  static const String defaultBaseUrl = 'https://tcws.tsg.bz/tsgtc.asmx';
  static const String defaultKioskId = 'tsg-unknown-android';
  static const String defaultAuthToken = '';

  static Box get _box => Hive.box(boxName);

  static String get baseUrl {
    final v = (_box.get(_kBaseUrlKey) as String?)?.trim() ?? '';
    return v.isNotEmpty ? v : defaultBaseUrl;
  }

  static String get kioskId {
    final v = (_box.get(_kKioskIdKey) as String?)?.trim() ?? '';
    return v.isNotEmpty ? v : defaultKioskId;
  }

  static String get authToken {
    final v = (_box.get(_kAuthTokenKey) as String?)?.trim() ?? '';
    return v.isNotEmpty ? v : defaultAuthToken;
  }

  static Future<void> setBaseUrl(String value) async {
    await _box.put(_kBaseUrlKey, value.trim());
  }

  static Future<void> setKioskId(String value) async {
    await _box.put(_kKioskIdKey, value.trim());
  }

  static Future<void> setAuthToken(String value) async {
    await _box.put(_kAuthTokenKey, value.trim());
  }

  // Optional helpers
  static bool get hasAuthToken => authToken.trim().isNotEmpty;

  static Future<void> resetToDefaults() async {
    await _box.put(_kBaseUrlKey, defaultBaseUrl);
    await _box.put(_kKioskIdKey, defaultKioskId);
    await _box.put(_kAuthTokenKey, defaultAuthToken);
  }
}