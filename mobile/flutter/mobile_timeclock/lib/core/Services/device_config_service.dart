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

  // Setup / login keys
  static const String _kSetupCompleteKey = 'setupComplete';
  static const String _kDeviceModeKey = 'deviceMode';
  static const String _kWallTabletAccessCodeKey = 'wallTabletAccessCode';
  static const String _kMobileSignedInKey = 'mobileSignedIn';
  static const String _kMobileDisplayNameKey = 'mobileDisplayName';
  static const String _kMobileEmailKey = 'mobileEmail';

  // Audit / identity keys
  static const String _kAuditMacAddressKey = 'auditMacAddress';
  static const String _kAppVersionLabelKey = 'appVersionLabel';

  // Defaults
  static const String defaultBaseUrl = 'https://tcws.tsg.bz/tsgtc.asmx';
  static const String defaultAuthToken = 'PIG0L5PRHXMA0KE5R91YEM7HEY1QM';
  static const String defaultDeviceId = '';
  static const String defaultAuditMacAddress = '02:00:00:00:00:00';
  static const String defaultAppVersionLabel = 'ver 5.0.0 CST';

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

  static String get auditMacAddress {
    final v = (_box.get(_kAuditMacAddressKey) as String?)?.trim() ?? '';
    return v.isNotEmpty ? v : defaultAuditMacAddress;
  }

  static String get appVersionLabel {
    final v = (_box.get(_kAppVersionLabelKey) as String?)?.trim() ?? '';
    return v.isNotEmpty ? v : defaultAppVersionLabel;
  }

  static String get deviceAuditIdentity {
    final mac = auditMacAddress.trim().isEmpty
        ? defaultAuditMacAddress
        : auditMacAddress.trim();

    final ver = appVersionLabel.trim().isEmpty
        ? defaultAppVersionLabel
        : appVersionLabel.trim();

    return '$mac - $ver';
  }

  static String get auditDescription {
    if (deviceMode == DeviceMode.wallTablet) {
      return wallTabletAccessCode;
    }

    if (deviceMode == DeviceMode.mobile) {
      return mobileEmail;
    }

    return '';
  }

  static String get runtimeDeviceIdentity {
    if (deviceMode == DeviceMode.wallTablet) {
      return wallTabletAccessCode;
    }

    if (deviceMode == DeviceMode.mobile) {
      return mobileEmail;
    }

    return deviceId;
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

  static Future<void> setAuditMacAddress(String value) async {
    await _box.put(_kAuditMacAddressKey, value.trim());
  }

  static Future<void> setAppVersionLabel(String value) async {
    await _box.put(_kAppVersionLabelKey, value.trim());
  }

  static Future<void> configureAsWallTablet({
    required String accessCode,
  }) async {
    await setDeviceMode(DeviceMode.wallTablet);
    await setWallTabletAccessCode(accessCode);
    await setDeviceId(accessCode);
    await setSetupComplete(true);

    // Device Mac Here (One Time)
    await setAuditMacAddress('02:00:00:00:00:00'); // replace later with real value
    await setAppVersionLabel('ver 5.0.0 CST');
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
    await setDeviceId(email);
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
    await setDeviceId('');
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
    await _box.put(_kAuditMacAddressKey, defaultAuditMacAddress);
    await _box.put(_kAppVersionLabelKey, defaultAppVersionLabel);
  }
}