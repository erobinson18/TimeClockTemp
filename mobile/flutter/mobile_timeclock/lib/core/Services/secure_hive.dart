import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SecureHive {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'hive_aes_key_v1';

  static late final HiveAesCipher cipher;

  /// Call once in main() before opening any boxes.
  static Future<void> init() async {
      final key = await _getOrCreateKey();
      cipher = HiveAesCipher(key);
  }

  static Future<List<int>> _getOrCreateKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.trim().isNotEmpty) {
      return base64Url.decode(existing);
    }

    final rnd = Random.secure();
    final key = List<int>.generate(32, (_) => rnd.nextInt(256)); // 256-bit
    await _storage.write(key: _keyName, value: base64UrlEncode(key));
    return key;
  }
}