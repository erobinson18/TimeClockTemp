import '../../Services/device_config_service.dart';

class MobileAuthService {
  MobileAuthService._();

  static final MobileAuthService instance = MobileAuthService._();

  Future<MobileSsoResult> signIn() async {
    return const MobileSsoResult(
      ok: false,
      message:
          'Microsoft mobile sign-in is not enabled for the web version yet. Use the Android/iOS app for mobile SSO.',
    );
  }

  Future<bool> hasStoredMobileSession() async {
    return false;
  }

  Future<MobileSsoResult> refreshIfPossible() async {
    return const MobileSsoResult(
      ok: false,
      message: 'Web mobile session refresh is not enabled.',
    );
  }

  Future<void> signOut() async {
    await DeviceConfigService.clearLoginStateOnly();
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