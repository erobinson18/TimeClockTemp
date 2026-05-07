import 'dart:convert';
import 'dart:io';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../Services/device_config_service.dart';

class MobileAuthService {
  MobileAuthService._();

  static final MobileAuthService instance = MobileAuthService._();

  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String clientId = '2f2431b8-f926-4533-8639-c57af6abb3f5';
  static const String tenantId = 'f8371d35-d7a9-4fc1-8735-c18315f9d2dd';

  static const String _androidRedirectUrl =
      'msauth://bz.tsg.databaseresearch/34gd2zWG0l1PLylv8dptCGNkSCQ%3D';

  static const String _iosRedirectUrl = 'msauth.com.tsg.timekeeper://auth';

  static const List<String> scopes = <String>[
    'openid',
    'profile',
    'email',
    'offline_access',
    'User.Read',
  ];

  static const String _kIdToken = 'mobile_id_token';
  static const String _kAccessToken = 'mobile_access_token';
  static const String _kRefreshToken = 'mobile_refresh_token';

  String get _redirectUrl {
    if (Platform.isIOS) return _iosRedirectUrl;
    return _androidRedirectUrl;
  }

  String get _discoveryUrl =>
      'https://login.microsoftonline.com/$tenantId/v2.0/.well-known/openid-configuration';

  Future<MobileSsoResult> signIn() async {
    try {
      final AuthorizationTokenResponse? result =
      await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          clientId,
          _redirectUrl,
          discoveryUrl: _discoveryUrl,
          scopes: scopes,
          promptValues: const ['select_account'],
        ),
      );

      if (result == null) {
        return const MobileSsoResult(
          ok: false,
          message: 'Sign-in was canceled.',
        );
      }

      return _saveAuthResult(
        idToken: result.idToken ?? '',
        accessToken: result.accessToken ?? '',
        refreshToken: result.refreshToken ?? '',
      );
    } catch (e) {
      return MobileSsoResult(
        ok: false,
        message: 'Microsoft sign-in failed: $e',
      );
    }
  }

  Future<bool> hasStoredMobileSession() async {
    if (!DeviceConfigService.isMobileConfigured) return false;

    final email = DeviceConfigService.mobileEmail.trim();
    if (email.isEmpty) return false;

    final idToken = await _secureStorage.read(key: _kIdToken);
    final refreshToken = await _secureStorage.read(key: _kRefreshToken);

    return (idToken ?? '').isNotEmpty || (refreshToken ?? '').isNotEmpty;
  }

  Future<MobileSsoResult> refreshIfPossible() async {
    final refreshToken = await _secureStorage.read(key: _kRefreshToken);

    if ((refreshToken ?? '').trim().isEmpty) {
      return const MobileSsoResult(
        ok: false,
        message: 'No saved refresh token.',
      );
    }

    try {
      final TokenResponse? result = await _appAuth.token(
        TokenRequest(
          clientId,
          _redirectUrl,
          discoveryUrl: _discoveryUrl,
          refreshToken: refreshToken,
          scopes: scopes,
        ),
      );

      if (result == null) {
        return const MobileSsoResult(
          ok: false,
          message: 'Unable to refresh sign-in.',
        );
      }

      return _saveAuthResult(
        idToken: result.idToken ?? '',
        accessToken: result.accessToken ?? '',
        refreshToken: result.refreshToken ?? refreshToken ?? '',
      );
    } catch (e) {
      return MobileSsoResult(
        ok: false,
        message: 'Refresh failed: $e',
      );
    }
  }

  Future<void> signOut() async {
    await _secureStorage.delete(key: _kIdToken);
    await _secureStorage.delete(key: _kAccessToken);
    await _secureStorage.delete(key: _kRefreshToken);

    await DeviceConfigService.clearLoginStateOnly();
  }

  Future<MobileSsoResult> _saveAuthResult({
    required String idToken,
    required String accessToken,
    required String refreshToken,
  }) async {
    if (idToken.isEmpty) {
      return const MobileSsoResult(
        ok: false,
        message: 'No ID token was returned.',
      );
    }

    final claims = _parseJwt(idToken);
    final email = _extractEmail(claims).toLowerCase();
    final displayName = _extractDisplayName(claims);

    if (email.isEmpty) {
      return const MobileSsoResult(
        ok: false,
        message: 'Unable to determine the signed-in email.',
      );
    }

    if (!email.endsWith('@tsg.bz')) {
      return const MobileSsoResult(
        ok: false,
        message: 'You must sign in with your @tsg.bz account.',
      );
    }

    await _secureStorage.write(key: _kIdToken, value: idToken);
    await _secureStorage.write(key: _kAccessToken, value: accessToken);

    if (refreshToken.isNotEmpty) {
      await _secureStorage.write(key: _kRefreshToken, value: refreshToken);
    }

    await DeviceConfigService.configureAsMobile(
      displayName: displayName.isEmpty ? email : displayName,
      email: email,
    );

    return MobileSsoResult(
      ok: true,
      message: 'Signed in successfully.',
      email: email,
      displayName: displayName,
    );
  }

  Map<String, dynamic> _parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return {};

    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));

    return jsonDecode(decoded) as Map<String, dynamic>;
  }

  String _extractEmail(Map<String, dynamic> claims) {
    final candidates = <String?>[
      claims['preferred_username']?.toString(),
      claims['email']?.toString(),
      claims['upn']?.toString(),
      claims['unique_name']?.toString(),
    ];

    for (final c in candidates) {
      final v = (c ?? '').trim();
      if (v.isNotEmpty && v.contains('@')) return v;
    }

    return '';
  }

  String _extractDisplayName(Map<String, dynamic> claims) {
    final candidates = <String?>[
      claims['name']?.toString(),
      claims['given_name']?.toString(),
      claims['preferred_username']?.toString(),
    ];

    for (final c in candidates) {
      final v = (c ?? '').trim();
      if (v.isNotEmpty) return v;
    }

    return '';
  }
}

class MobileSsoResult {
  final bool ok;
  final String message;
  final String email;
  final String displayName;

  const MobileSsoResult({
    required this.ok,
    required this.message,
    this.email = '',
    this.displayName = '',
  });
}