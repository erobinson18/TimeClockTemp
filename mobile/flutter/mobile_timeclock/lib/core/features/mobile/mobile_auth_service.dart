import 'dart:convert';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../Services/device_config_service.dart';

class MobileAuthService {
  MobileAuthService._();

  static final MobileAuthService instance = MobileAuthService._();

  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // =========================================================
  // REPLACE THESE WITH YOUR REAL ENTRA VALUES
  // =========================================================
  static const String clientId = 'YOUR_CLIENT_ID_HERE';
  static const String tenantId = 'YOUR_TENANT_ID_OR_DOMAIN_HERE';

  // Android example:
  // msauth://com.yourcompany.mobile_timeclock/BASE64_SIGNATURE_HASH
  //
  // iOS example:
  // com.yourcompany.mobiletimeclock:/oauthredirect
  //
  // Pick the redirect URI you actually register in Entra.
  static const String redirectUrl = 'YOUR_REDIRECT_URI_HERE';

  // OpenID scopes for sign-in
  static const List<String> scopes = <String>[
    'openid',
    'profile',
    'email',
    'offline_access',
  ];

  //String get _issuer => 'https://login.microsoftonline.com/$tenantId/v2.0';
  String get _discoveryUrl =>
      'https://login.microsoftonline.com/$tenantId/v2.0/.well-known/openid-configuration';

  Future<MobileSsoResult> signIn() async {
    try {
      final AuthorizationTokenResponse? result =
      await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          clientId,
          redirectUrl,
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

      final idToken = result.idToken ?? '';
      final accessToken = result.accessToken ?? '';
      final refreshToken = result.refreshToken ?? '';

      if (idToken.isEmpty) {
        return const MobileSsoResult(
          ok: false,
          message: 'No ID token was returned.',
        );
      }

      final claims = _parseJwt(idToken);

      final email = _extractEmail(claims);
      final displayName = _extractDisplayName(claims);

      if (email.isEmpty) {
        return const MobileSsoResult(
          ok: false,
          message: 'Unable to determine the signed-in email.',
        );
      }

      await _secureStorage.write(key: 'mobile_id_token', value: idToken);
      await _secureStorage.write(key: 'mobile_access_token', value: accessToken);
      await _secureStorage.write(
          key: 'mobile_refresh_token', value: refreshToken);

      await DeviceConfigService.configureAsMobile(
        displayName: displayName,
        email: email,
      );

      return MobileSsoResult(
        ok: true,
        message: 'Signed in successfully.',
        email: email,
        displayName: displayName,
      );
    } catch (e) {
      return MobileSsoResult(
        ok: false,
        message: 'Microsoft sign-in failed: $e',
      );
    }
  }

  Future<void> signOut() async {
    await _secureStorage.delete(key: 'mobile_id_token');
    await _secureStorage.delete(key: 'mobile_access_token');
    await _secureStorage.delete(key: 'mobile_refresh_token');

    await DeviceConfigService.clearLoginStateOnly();
  }

  Map<String, dynamic> _parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return <String, dynamic>{};

    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));

    final map = jsonDecode(decoded);
    if (map is Map<String, dynamic>) return map;
    return <String, dynamic>{};
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