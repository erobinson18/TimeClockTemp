import '../../api_client.dart';
import '../../Services/device_config_service.dart';

class VistaAuthService {
  final ApiClient _client;

  VistaAuthService(this._client);

  Future<VistaValidateResult> validateAccessCode(String accessCode) async {
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

    final actions = <String>[
      'TABLET',
      'VALIDATE',
      'PUNCH',
      '',
    ];

    String bestMessage = 'Invalid access code.';

    for (final action in actions) {
      try {
        final xml = await _client.postForm(
          '$baseUrl/ValidateCode',
          {
            'OTCode': accessCode.trim(),
            'Auth': auth,
            'Action': action,
          },
        );

        final value = _extractSoapStringValue(xml).trim();

        if (value.isNotEmpty) {
          bestMessage = value;
        }

        if (_looksValidResponse(value)) {
          return VistaValidateResult(
            ok: true,
            message: value.isEmpty ? 'Validated.' : value,
          );
        }
      } catch (e) {
        bestMessage = 'Validation failed: $e';
      }
    }

    return VistaValidateResult(
      ok: false,
      message: bestMessage,
    );
  }

  bool _looksValidResponse(String value) {
    final normalized = value.trim().toUpperCase();

    if (normalized.isEmpty) return false;

    const invalidTerms = [
      'INVALID',
      'FAIL',
      'FAILED',
      'ERROR',
      'DENIED',
      'FALSE',
      'NOT FOUND',
      'EXPIRED',
      'DISABLED',
      '0',
    ];

    for (final term in invalidTerms) {
      if (normalized.contains(term)) return false;
    }

    const validTerms = [
      'SUCCESS',
      'VALID',
      'TRUE',
      'APPROVED',
      'ACCEPTED',
      'OK',
      '1',
    ];

    for (final term in validTerms) {
      if (normalized.contains(term)) return true;
    }

    return true;
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