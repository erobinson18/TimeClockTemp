import 'dart:async';
import 'package:http/http.dart' as http;

import 'app_config.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// For ASMX, we call endpoints like:
  ///   {baseUrl}/GetEmps?Auth=...
  Future<String> getText(
    String path, {
    Map<String, String>? query,
  }) async {
    final base = AppConfig.effectiveBaseUrl;
    final uri = Uri.parse("$base/$path").replace(queryParameters: query);

    final res = await _client
        .get(uri, headers: const {"Accept": "text/plain, text/xml, */*"})
        .timeout(AppConfig.timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException("GET $path failed: ${res.statusCode} ${res.body}");
    }

    return res.body;
  }

  void dispose() => _client.close();
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);

  @override
  String toString() => message;
}