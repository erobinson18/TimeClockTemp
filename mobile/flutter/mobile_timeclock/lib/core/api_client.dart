import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> postSoap({
    required Uri url,
    required String soapAction,
    required String envelopeXml,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final res = await _client
        .post(
          url,
          headers: {
            "Content-Type": "text/xml; charset=utf-8",
            "SOAPAction": soapAction,
          },
          body: utf8.encode(envelopeXml),
        )
        .timeout(timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("HTTP ${res.statusCode}: ${res.body}");
    }

    return res.body;
  }

  Future<void> ping(Uri url, {Duration timeout = const Duration(seconds: 6)}) async {
    final res = await _client.get(url).timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 500) {
      throw Exception("Ping failed: HTTP ${res.statusCode}");
    }
  }

  void dispose() => _client.close();
}