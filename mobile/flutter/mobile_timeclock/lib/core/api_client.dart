import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiClient {
  final http.Client _client;

  /// Default request timeout.
  final Duration timeout;

  /// Max retry attempts for retryable failures (timeouts, socket issues, 5xx, 429).
  final int maxRetries;

  /// Base delay for exponential backoff (with jitter).
  final Duration retryBaseDelay;

  /// Optional logger hook (wire this to debugPrint or your logger).
  final void Function(String message)? log;

  ApiClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
    this.maxRetries = 2,
    this.retryBaseDelay = const Duration(milliseconds: 350),
    this.log,
  }) : _client = client ?? http.Client();

  /// Sends a form-encoded POST request.
  Future<String> postForm(
      String url,
      Map<String, String> body, {
        Map<String, String>? headers,
      }) async {
    return _sendWithRetry(
      method: 'POST',
      url: url,
      doRequest: () => _client.post(
        Uri.parse(url),
        headers: _mergeHeaders(
          base: const {'Content-Type': 'application/x-www-form-urlencoded'},
          extra: headers,
        ),
        body: body,
      ),
    );
  }

  /// Sends a GET request.
  Future<String> get(
      String url, {
        Map<String, String>? headers,
      }) async {
    return _sendWithRetry(
      method: 'GET',
      url: url,
      doRequest: () => _client.get(
        Uri.parse(url),
        headers: _mergeHeaders(extra: headers),
      ),
    );
  }

  /// Call this if you own the client lifecycle.
  void close() => _client.close();

  // -----------------------
  // Internals
  // -----------------------

  Map<String, String> _mergeHeaders({
    Map<String, String>? base,
    Map<String, String>? extra,
  }) {
    return {
      // Helpful defaults; safe for SOAP-ish services.
      'Accept': '*/*',
      ...?base,
      if (extra != null) ...extra,
    };
  }

  Future<String> _sendWithRetry({
    required String method,
    required String url,
    required Future<http.Response> Function() doRequest,
  }) async {
    Object? lastError;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      final isLast = attempt == maxRetries;

      try {
        final started = DateTime.now();
        final res = await doRequest().timeout(timeout);
        final ms = DateTime.now().difference(started).inMilliseconds;

        if (_isSuccess(res.statusCode)) {
          if (attempt > 0) {
            log?.call('ApiClient $method $url success after retry ${attempt + 1} (${ms}ms)');
          }
          return utf8.decode(res.bodyBytes);
        }

        // Non-2xx: decide retry vs fail.
        final status = res.statusCode;
        final bodyPreview = _preview(res.body);

        if (_isRetryableStatus(status) && !isLast) {
          log?.call('ApiClient $method $url retryable HTTP $status (attempt ${attempt + 1}/${maxRetries + 1})');
          await _backoff(attempt);
          continue;
        }

        throw ApiHttpException(
          statusCode: status,
          url: url,
          method: method,
          body: bodyPreview,
        );
      } on TimeoutException catch (e) {
        lastError = e;
        if (!isLast) {
          log?.call('ApiClient $method $url timeout (attempt ${attempt + 1}/${maxRetries + 1})');
          await _backoff(attempt);
          continue;
        }
        throw ApiNetworkException('Request timed out', cause: e);
      } on SocketException catch (e) {
        lastError = e;
        if (!isLast) {
          log?.call('ApiClient $method $url socket error (attempt ${attempt + 1}/${maxRetries + 1})');
          await _backoff(attempt);
          continue;
        }
        throw ApiNetworkException('Network error', cause: e);
      } on http.ClientException catch (e) {
        lastError = e;
        if (!isLast) {
          log?.call('ApiClient $method $url client error (attempt ${attempt + 1}/${maxRetries + 1})');
          await _backoff(attempt);
          continue;
        }
        throw ApiNetworkException('HTTP client error', cause: e);
      } catch (e) {
        // Unknown error: do not aggressively retry unless we explicitly captured it above.
        lastError = e;
        rethrow;
      }
    }

    // Should never reach here, but just in case.
    throw ApiNetworkException('Request failed after retries', cause: lastError);
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  bool _isRetryableStatus(int statusCode) {
    // 408: timeout, 429: rate limit, 5xx: server issues
    return statusCode == 408 || statusCode == 429 || (statusCode >= 500 && statusCode <= 599);
  }

  Future<void> _backoff(int attempt) async {
    // Exponential backoff with small jitter
    final baseMs = retryBaseDelay.inMilliseconds;
    final exp = 1 << attempt; // 1,2,4,...
    final jitter = (DateTime.now().microsecondsSinceEpoch % 120); // 0..119ms
    final delay = Duration(milliseconds: baseMs * exp + jitter);
    await Future.delayed(delay);
  }

  String _preview(String s, {int max = 600}) {
    final trimmed = s.trim();
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max)}…';
  }
}

class ApiHttpException implements Exception {
  final int statusCode;
  final String url;
  final String method;
  final String body;

  ApiHttpException({
    required this.statusCode,
    required this.url,
    required this.method,
    required this.body,
  });

  @override
  String toString() => 'ApiHttpException($method $url -> HTTP $statusCode: $body)';
}

class ApiNetworkException implements Exception {
  final String message;
  final Object? cause;

  ApiNetworkException(this.message, {this.cause});

  @override
  String toString() => 'ApiNetworkException($message${cause != null ? ', cause: $cause' : ''})';
}