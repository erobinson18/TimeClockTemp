import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AdminPinService {
  static const _storage = FlutterSecureStorage();
  static const _saltKey = 'admin_pin_salt_v1';
  static const _hashKey = 'admin_pin_hash_v1';

  static Future<bool> isSet() async {
    final hash = await _storage.read(key: _hashKey);
    return hash != null && hash.trim().isNotEmpty;
  }

  static Future<void> setPin(String pin) async {
    final clean = pin.trim();
    if (clean.length < 4) {
      throw Exception('PIN must be at least 4 digits.');
    }

    final salt = await _getOrCreateSalt();
    final hash = _hashPin(clean, salt);

    await _storage.write(key: _hashKey, value: hash);
  }

  static Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _hashKey);
    if (storedHash == null || storedHash.trim().isEmpty) return false;

    final salt = await _getOrCreateSalt();
    final hash = _hashPin(pin.trim(), salt);
    return hash == storedHash;
  }

  static Future<String> _getOrCreateSalt() async {
    final existing = await _storage.read(key: _saltKey);
    if (existing != null && existing.trim().isNotEmpty) return existing;

    final rnd = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    final salt = base64UrlEncode(saltBytes);

    await _storage.write(key: _saltKey, value: salt);
    return salt;
  }

  static String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt|$pin');
    return sha256.convert(bytes).toString();
  }
}