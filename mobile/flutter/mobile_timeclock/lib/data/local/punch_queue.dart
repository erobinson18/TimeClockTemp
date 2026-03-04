import 'package:hive_flutter/hive_flutter.dart';

import '../../core/Services/device_config_service.dart';
import '../../core/security/punch_integrity.dart';

class PunchQueue {
  static const String _boxName = 'punch_queue';

  Box get _box => Hive.box(_boxName);

  Future<void> enqueue(Map<String, dynamic> payload) async {
    final kioskId = DeviceConfigService.kioskId;

    final employeeId = (payload['employeeId'] ?? '').toString().trim();
    final punchType = (payload['punchType'] as num?)?.toInt() ?? 0;

    // If localSequenceNumber is missing/0, generate a stable fallback key.
    var localSeq = (payload['localSequenceNumber'] as num?)?.toInt() ?? 0;
    if (localSeq <= 0) {
      localSeq = DateTime.now().toUtc().microsecondsSinceEpoch;
    }

    // Force UTC ISO timestamp WITHOUT milliseconds
    final incomingTs = (payload['timestampUtc'] ?? '').toString().trim();
    final timestampUtcIso = incomingTs.isNotEmpty
        ? _normalizeIsoUtcNoMillis(incomingTs)
        : _isoUtcNoMillis(DateTime.now().toUtc());

    // Store when we queued it (UTC, no millis)
    final queuedAtUtc = _isoUtcNoMillis(DateTime.now().toUtc());

    // Minimal validation so we don’t store junk.
    if (employeeId.isEmpty) {
      throw Exception('PunchQueue.enqueue: employeeId is required');
    }

    final normalized = <String, dynamic>{
      ...payload,
      // ✅ ensure these are always present and clean
      'kioskId': (payload['kioskId'] ?? kioskId).toString(),
      'employeeId': employeeId,
      'punchType': punchType,
      'localSequenceNumber': localSeq,
      'timestampUtc': timestampUtcIso,
      'queuedAtUtc': (payload['queuedAtUtc'] ?? queuedAtUtc).toString(),
    };

    final hash = PunchIntegrity.computeHash(
      kioskId: kioskId,
      employeeId: employeeId,
      punchType: punchType,
      localSequenceNumber: localSeq,
      timestampUtcIso: timestampUtcIso,
    );

    final withHash = <String, dynamic>{
      ...normalized,
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

      final employeeId = (m['employeeId'] ?? '').toString().trim();
      final punchType = (m['punchType'] as num?)?.toInt() ?? 0;
      final localSeq = (m['localSequenceNumber'] as num?)?.toInt() ?? 0;
      final ts = (m['timestampUtc'] ?? '').toString().trim();
      final hash = (m['integrityHash'] ?? '').toString().trim();

      // Skip malformed entries.
      if (employeeId.isEmpty || localSeq <= 0 || ts.isEmpty || hash.isEmpty) {
        continue;
      }

      // ✅ ensure timestamp format stays no-millis (helps parsing + integrity stability)
      final cleanTs = _normalizeIsoUtcNoMillis(ts);

      // If it changed, rewrite entry (so future reads are clean)
      if (cleanTs != ts) {
        final patched = <String, dynamic>{...m, 'timestampUtc': cleanTs};
        await _box.put(localSeq, patched);
      }

      final ok = PunchIntegrity.verify(
        kioskId: kioskId,
        employeeId: employeeId,
        punchType: punchType,
        localSequenceNumber: localSeq,
        timestampUtcIso: cleanTs,
        storedHash: hash,
      );

      if (ok) out.add(m);
    }

    // Sort by seq (oldest first).
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

  // -------------------
  // Timestamp helpers
  // -------------------

  /// ISO 8601 UTC with seconds only: YYYY-MM-DDTHH:mm:ssZ
  String _isoUtcNoMillis(DateTime utc) {
    final u = utc.toUtc();
    final yyyy = u.year.toString().padLeft(4, '0');
    final mm = u.month.toString().padLeft(2, '0');
    final dd = u.day.toString().padLeft(2, '0');
    final hh = u.hour.toString().padLeft(2, '0');
    final min = u.minute.toString().padLeft(2, '0');
    final ss = u.second.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd'
        'T$hh:$min:$ss'
        'Z';
  }

  /// Normalize any ISO-ish string to no-millis UTC if it ends with Z.
  /// Examples:
  /// 2026-03-03T10:11:12.345Z -> 2026-03-03T10:11:12Z
  /// 2026-03-03T10:11:12Z -> unchanged
  String _normalizeIsoUtcNoMillis(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;

    final hasZ = t.toUpperCase().endsWith('Z');
    final dot = t.indexOf('.');
    if (dot == -1) {
      // no fractional seconds; keep as-is
      return t;
    }

    final before = t.substring(0, dot);
    return hasZ ? '${before}Z' : before;
  }
}