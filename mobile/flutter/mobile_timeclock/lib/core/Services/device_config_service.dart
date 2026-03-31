import 'package:hive_flutter/hive_flutter.dart';

enum DeviceMode {
  none,
  wallTablet,
  mobile,
}

class DeviceConfigService {
  static const String boxName = 'device';

  static const String _kBaseUrlKey = 'baseUrl';
  static const String _kAuthTokenKey = 'authToken';
  static const String _kDeviceIdKey = 'deviceId';

  // New setup / login keys
  static const String _kSetupCompleteKey = 'setupComplete';
  static const String _kDeviceModeKey = 'deviceMode';
  static const String _kWallTabletAccessCodeKey = 'wallTabletAccessCode';
  static const String _kMobileSignedInKey = 'mobileSignedIn';
  static const String _kMobileDisplayNameKey = 'mobileDisplayName';
  static const String _kMobileEmailKey = 'mobileEmail';

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

  static bool get hasAuthToken => authToken.trim().isNotEmpty;

  static bool get isSetupComplete =>
      (_box.get(_kSetupCompleteKey) as bool?) ?? false;

  static DeviceMode get deviceMode {
    final raw = ((_box.get(_kDeviceModeKey) as String?) ?? '').trim();

    switch (raw) {
      case 'wallTablet':
        return DeviceMode.wallTablet;
      case 'mobile':
        return DeviceMode.mobile;
      default:
        return DeviceMode.none;
    }
  }

  static String get wallTabletAccessCode {
    final v = (_box.get(_kWallTabletAccessCodeKey) as String?)?.trim() ?? '';
    return v;
  }

  static bool get mobileSignedIn =>
      (_box.get(_kMobileSignedInKey) as bool?) ?? false;

  static String get mobileDisplayName {
    final v = (_box.get(_kMobileDisplayNameKey) as String?)?.trim() ?? '';
    return v;
  }

  static String get mobileEmail {
    final v = (_box.get(_kMobileEmailKey) as String?)?.trim() ?? '';
    return v;
  }

  static bool get isWallTabletConfigured {
    return isSetupComplete &&
        deviceMode == DeviceMode.wallTablet &&
        wallTabletAccessCode.isNotEmpty;
  }

  static bool get isMobileConfigured {
    return isSetupComplete &&
        deviceMode == DeviceMode.mobile &&
        mobileSignedIn;
  }

  static Future<void> setBaseUrl(String value) async {
    await _box.put(_kBaseUrlKey, value.trim());
  }

  static Future<void> setAuthToken(String value) async {
    await _box.put(_kAuthTokenKey, value.trim());
  }

  static Future<void> setDeviceId(String value) async {
    await _box.put(_kDeviceIdKey, value.trim());
  }

  static Future<void> setSetupComplete(bool value) async {
    await _box.put(_kSetupCompleteKey, value);
  }

  static Future<void> setDeviceMode(DeviceMode mode) async {
    switch (mode) {
      case DeviceMode.wallTablet:
        await _box.put(_kDeviceModeKey, 'wallTablet');
        break;
      case DeviceMode.mobile:
        await _box.put(_kDeviceModeKey, 'mobile');
        break;
      case DeviceMode.none:
        await _box.put(_kDeviceModeKey, 'none');
        break;
    }
  }

  static Future<void> setWallTabletAccessCode(String value) async {
    await _box.put(_kWallTabletAccessCodeKey, value.trim());
  }

  static Future<void> setMobileSignedIn(bool value) async {
    await _box.put(_kMobileSignedInKey, value);
  }

  static Future<void> setMobileDisplayName(String value) async {
    await _box.put(_kMobileDisplayNameKey, value.trim());
  }

  static Future<void> setMobileEmail(String value) async {
    await _box.put(_kMobileEmailKey, value.trim());
  }

  static Future<void> configureAsWallTablet({
    required String accessCode,
  }) async {
    await setDeviceMode(DeviceMode.wallTablet);
    await setWallTabletAccessCode(accessCode);
    await setSetupComplete(true);

    // Clear mobile state
    await setMobileSignedIn(false);
    await setMobileDisplayName('');
    await setMobileEmail('');
  }

  static Future<void> configureAsMobile({
    String displayName = '',
    String email = '',
  }) async {
    await setDeviceMode(DeviceMode.mobile);
    await setMobileSignedIn(true);
    await setMobileDisplayName(displayName);
    await setMobileEmail(email);
    await setSetupComplete(true);

    // Clear wall tablet state
    await setWallTabletAccessCode('');
  }

  static Future<void> clearLoginStateOnly() async {
    await setSetupComplete(false);
    await setDeviceMode(DeviceMode.none);
    await setWallTabletAccessCode('');
    await setMobileSignedIn(false);
    await setMobileDisplayName('');
    await setMobileEmail('');
  }

  static Future<void> resetToDefaults() async {
    await _box.put(_kBaseUrlKey, defaultBaseUrl);
    await _box.put(_kAuthTokenKey, defaultAuthToken);
    await _box.put(_kDeviceIdKey, defaultDeviceId);

    await _box.put(_kSetupCompleteKey, false);
    await _box.put(_kDeviceModeKey, 'none');
    await _box.put(_kWallTabletAccessCodeKey, '');
    await _box.put(_kMobileSignedInKey, false);
    await _box.put(_kMobileDisplayNameKey, '');
    await _box.put(_kMobileEmailKey, '');
  }
}