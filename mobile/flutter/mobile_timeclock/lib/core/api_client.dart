import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final http.Client _client;
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<String> postForm(String url, Map<String, String> body, {Map<String, String>? headers}) async {
    final res = await _client.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        if (headers != null) ...headers,
      },
      body: body,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    return utf8.decode(res.bodyBytes);
  }

  Future<String> get(String url, {Map<String, String>? headers}) async {
    final res = await _client.get(Uri.parse(url), headers: headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    return utf8.decode(res.bodyBytes);
  }
}