import 'package:hive_flutter/hive_flutter.dart';

import '../../core/Services/device_config_service.dart';
import '../../core/security/punch_integrity.dart';

class PunchQueue {
  static const String _boxName = 'punch_queue';

  Box get _box => Hive.box(_boxName);

  Future<void> enqueue(Map<String, dynamic> payload) async {
    // payload required fields:
    // employeeId, punchType, localSequenceNumber, timestampUtc
    final kioskId = DeviceConfigService.kioskId;

    final employeeId = (payload['employeeId'] ?? '').toString();
    final punchType = (payload['punchType'] as num?)?.toInt() ?? 0;
    final localSeq = (payload['localSequenceNumber'] as num?)?.toInt() ?? 0;
    final ts = (payload['timestampUtc'] ?? '').toString();

    final hash = PunchIntegrity.computeHash(
      kioskId: kioskId,
      employeeId: employeeId,
      punchType: punchType,
      localSequenceNumber: localSeq,
      timestampUtcIso: ts,
    );

    final withHash = <String, dynamic>{
      ...payload,
      'integrityHash': hash,
    };

    // Use localSequenceNumber as the key so we can delete by seq.
    await _box.put(localSeq, withHash);
  }

  Future<int> count() async => _box.length;

  Future<List<Map<String, dynamic>>> allVerified() async {
    final kioskId = DeviceConfigService.kioskId;
    final out = <Map<String, dynamic>>[];

    for (final key in _box.keys) {
      final v = _box.get(key);
      if (v is! Map) continue;

      final m = v.map((k, val) => MapEntry(k.toString(), val));

      final employeeId = (m['employeeId'] ?? '').toString();
      final punchType = (m['punchType'] as num?)?.toInt() ?? 0;
      final localSeq = (m['localSequenceNumber'] as num?)?.toInt() ?? 0;
      final ts = (m['timestampUtc'] ?? '').toString();
      final hash = (m['integrityHash'] ?? '').toString();

      if (employeeId.isEmpty || ts.isEmpty || hash.isEmpty) {
        // skip malformed
        continue;
      }

      final ok = PunchIntegrity.verify(
        kioskId: kioskId,
        employeeId: employeeId,
        punchType: punchType,
        localSequenceNumber: localSeq,
        timestampUtcIso: ts,
        storedHash: hash,
      );

      if (ok) out.add(m);
    }

    // Sort by seq (oldest first)
    out.sort((a, b) {
      final sa = (a['localSequenceNumber'] as num?)?.toInt() ?? 0;
      final sb = (b['localSequenceNumber'] as num?)?.toInt() ?? 0;
      return sa.compareTo(sb);
    });

    return out;
  }

  /// Compatibility if you already call `all()` elsewhere.
  Future<List<Map<String, dynamic>>> all() => allVerified();

  Future<void> removeByLocalSeq(Set<int> seq) async {
    for (final s in seq) {
      await _box.delete(s);
    }
  }

  Future<void> clear() async => _box.clear();
}