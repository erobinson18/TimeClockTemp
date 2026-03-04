import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

class SecureHive {
  SecureHive._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _hiveKeyName = 'hive_aes_key_v1';

  static HiveAesCipher? _cipher;

  static HiveAesCipher get cipher {
    final c = _cipher;
    if (c == null) {
      throw Exception("SecureHive not initialized. Call SecureHive.init() first.");
    }
    return c;
  }

  static Future<void> init() async {
    final existing = await _storage.read(key: _hiveKeyName);

    List<int> keyBytes;

    if (existing == null || existing.trim().isEmpty) {
      keyBytes = _generateKeyBytes();
      await _storage.write(key: _hiveKeyName, value: _encodeCommaInts(keyBytes));
      _cipher = HiveAesCipher(keyBytes);
      return;
    }

    // 1) New format: "1,2,3,..."
    final parsedInts = _tryParseCommaInts(existing);
    if (parsedInts != null) {
      keyBytes = parsedInts;
      _cipher = HiveAesCipher(keyBytes);
      return;
    }

    // 2) Old format: base64/base64url string
    final decoded = _tryDecodeBase64(existing);
    if (decoded != null) {
      keyBytes = decoded;

      // Migrate to the new safer + human-debuggable format
      await _storage.write(key: _hiveKeyName, value: _encodeCommaInts(keyBytes));

      _cipher = HiveAesCipher(keyBytes);
      return;
    }

    // 3) If it’s garbage, reset (last resort)
    keyBytes = _generateKeyBytes();
    await _storage.write(key: _hiveKeyName, value: _encodeCommaInts(keyBytes));
    _cipher = HiveAesCipher(keyBytes);
  }

  static List<int> _generateKeyBytes() {
    final rnd = Random.secure();
    return List<int>.generate(32, (_) => rnd.nextInt(256)); // 256-bit
  }

  static String _encodeCommaInts(List<int> keyBytes) {
    return keyBytes.map((b) => b.toString()).join(',');
  }

  static List<int>? _tryParseCommaInts(String s) {
    try {
      final parts = s.split(',');
      if (parts.length < 16) return null; // sanity
      final bytes = parts.map((p) => int.parse(p.trim())).toList();
      if (bytes.any((b) => b < 0 || b > 255)) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static List<int>? _tryDecodeBase64(String s) {
    try {
      // Support both base64 and base64url
      final normalized = s.replaceAll('-', '+').replaceAll('_', '/');
      final padded = _padBase64(normalized);
      final bytes = base64Decode(padded);

      // Hive AES key should be 32 bytes, but if older code used other length,
      // we’ll accept 32+ and trim, or reject too-short.
      if (bytes.length < 32) return null;
      if (bytes.length == 32) return bytes;

      return bytes.sublist(0, 32);
    } catch (_) {
      return null;
    }
  }

  static String _padBase64(String s) {
    final mod = s.length % 4;
    if (mod == 0) return s;
    return s + '=' * (4 - mod);
  }
}