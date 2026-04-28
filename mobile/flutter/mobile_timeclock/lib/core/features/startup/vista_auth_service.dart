import '../../api_client.dart';
import '../../Services/device_config_service.dart';

class VistaAuthService {
  final ApiClient _client;

  VistaAuthService(this._client);

  Future<VistaValidateResult> validateNewSetupCode(String accessCode) async {
    return _validateCode(
      accessCode: accessCode,
      action: 'N',
    );
  }

  Future<VistaValidateResult> validateScheduledCode(String accessCode) async {
    return _validateCode(
      accessCode: accessCode,
      action: 'S',
    );
  }

  Future<VistaValidateResult> _validateCode({
    required String accessCode,
    required String action,
  }) async {
    final baseUrl = DeviceConfigService.baseUrl.trim();
    final auth = DeviceConfigService.authToken.trim();

    if (baseUrl.isEmpty) {
      return const VistaValidateResult(
        ok: false,
        message: 'Base URL is not configured.',
      );
    }

    if (auth.isEmpty) {
      return const VistaValidateResult(
        ok: false,
        message: 'Auth token is not configured.',
      );
    }

    try {
      final xml = await _client.postForm(
        '$baseUrl/ValidateCode',
        {
          'OTCode': accessCode.trim(),
          'Auth': auth,
          'Action': action,
        },
      );

      final value = _extractSoapStringValue(xml).trim().toLowerCase();

      if (value == 'true') {
        return const VistaValidateResult(
          ok: true,
          message: 'Validated.',
        );
      }

      if (value == 'false') {
        return VistaValidateResult(
          ok: false,
          message: action == 'N'
              ? 'This access code is invalid, inactive, or already claimed.'
              : 'This tablet code is no longer active.',
        );
      }

      return VistaValidateResult(
        ok: false,
        message: value.isEmpty ? 'Unknown validation response.' : value,
      );
    } catch (e) {
      return VistaValidateResult(
        ok: false,
        message: 'Validation failed: $e',
      );
    }
  }

  String _extractSoapStringValue(String xmlText) {
    final match =
    RegExp(r'<string[^>]*>(.*?)</string>', dotAll: true).firstMatch(xmlText);

    if (match == null) return '';

    final inner = match.group(1) ?? '';
    return inner
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}

class VistaValidateResult {
  final bool ok;
  final String message;

  const VistaValidateResult({
    required this.ok,
    required this.message,
  });
}