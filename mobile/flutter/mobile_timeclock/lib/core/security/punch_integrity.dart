import 'dart:convert';
import 'package:crypto/crypto.dart';

class PunchIntegrity {
  /// Stable, device-specific salt. Uses kioskId (MACAddress value) so tablets differ.
  static String computeHash({
    required String kioskId,
    required String employeeId,
    required int punchType,
    required int localSequenceNumber,
    required String timestampUtcIso,
  }) {
    final payload = [
      kioskId.trim(),
      employeeId.trim(),
      punchType.toString(),
      localSequenceNumber.toString(),
      timestampUtcIso.trim(),
    ].join('|');

    return sha256.convert(utf8.encode(payload)).toString();
  }

  static bool verify({
    required String kioskId,
    required String employeeId,
    required int punchType,
    required int localSequenceNumber,
    required String timestampUtcIso,
    required String storedHash,
  }) {
    final expected = computeHash(
      kioskId: kioskId,
      employeeId: employeeId,
      punchType: punchType,
      localSequenceNumber: localSequenceNumber,
      timestampUtcIso: timestampUtcIso,
    );
    return expected == storedHash;
  }
}