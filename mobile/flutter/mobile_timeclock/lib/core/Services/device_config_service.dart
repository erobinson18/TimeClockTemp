import 'package:hive_flutter/hive_flutter.dart';

class DeviceConfigService {
  static const String boxName = 'device';

  static const String _kBaseUrlKey = 'baseUrl';
  static const String _kAuthTokenKey = 'authToken';
  static const String _kDeviceIdKey = 'deviceId';

  // Defaults
  static const String defaultBaseUrl = 'https://tcws.tsg.bz/tsgtc.asmx';
  static const String defaultAuthToken = '';
  static const String defaultDeviceId = 'KIOSK-TEST-01';

  static Box get _box => Hive.box(boxName);

  static String get baseUrl {
    final v = (_box.get(_kBaseUrlKey) as String?)?.trim() ?? '';
    return v.isNotEmpty ? v : defaultBaseUrl;
  }

  static String get authToken {
    final v = (_box.get(_kAuthTokenKey) as String?)?.trim() ?? '';
    return v.isNotEmpty ? v : defaultAuthToken;
  }

  static String get deviceId {
    final v = (_box.get(_kDeviceIdKey) as String?)?.trim() ?? '';
    return v.isNotEmpty ? v : defaultDeviceId;
  }

  static String get kioskId => deviceId;

  static Future<void> setBaseUrl(String value) async {
    await _box.put(_kBaseUrlKey, value.trim());
  }

  static Future<void> setAuthToken(String value) async {
    await _box.put(_kAuthTokenKey, value.trim());
  }

  static Future<void> setDeviceId(String value) async {
    await _box.put(_kDeviceIdKey, value.trim());
  }

  static bool get hasAuthToken => authToken.trim().isNotEmpty;

  static Future<void> resetToDefaults() async {
    await _box.put(_kBaseUrlKey, defaultBaseUrl);
    await _box.put(_kAuthTokenKey, defaultAuthToken);
    await _box.put(_kDeviceIdKey, defaultDeviceId);
  }
}