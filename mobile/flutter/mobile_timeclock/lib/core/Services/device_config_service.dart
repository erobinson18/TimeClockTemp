import 'package:hive_flutter/hive_flutter.dart';

class DeviceConfigService {
  static const String _boxName = 'device';

  static const String _kBaseUrlKey = 'baseUrl';
  static const String _kKioskIdKey = 'kioskId';
  static const String _kAuthTokenKey = 'authToken';

  // Defaults
  static const String _defaultBaseUrl = 'https://tcws.tsg.bz/tsgtc.asmx';
  static const String _defaultKioskId = 'tsg-unknown-android';
  static const String _defaultAuthToken = '';

  static Box get _box => Hive.box(_boxName);

  static String get baseUrl {
    final v = (_box.get(_kBaseUrlKey) as String?)?.trim();
    return (v != null && v.isNotEmpty) ? v : _defaultBaseUrl;
  }

  static String get kioskId {
    final v = (_box.get(_kKioskIdKey) as String?)?.trim();
    return (v != null && v.isNotEmpty) ? v : _defaultKioskId;
  }

  static String get authToken {
    final v = (_box.get(_kAuthTokenKey) as String?) ?? _defaultAuthToken;
    return v;
  }

  static Future<void> setBaseUrl(String value) async {
    await _box.put(_kBaseUrlKey, value.trim());
  }

  static Future<void> setKioskId(String value) async {
    await _box.put(_kKioskIdKey, value.trim());
  }

  static Future<void> setAuthToken(String value) async {
    await _box.put(_kAuthTokenKey, value);
  }
}