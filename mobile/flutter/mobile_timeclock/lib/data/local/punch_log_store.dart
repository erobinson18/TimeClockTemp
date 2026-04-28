import 'package:hive_flutter/hive_flutter.dart';

class PunchLogStore {
  static const String boxName = 'punch_log';

  // Keep the last 14 days of logs (time-based retention)
  static const Duration retention = Duration(days: 14);

  Box get _box => Hive.box(boxName);

  Future<void> add(Map<String, dynamic> entry) async {
    // store only simple map data with string keys
    final clean = entry.map((k, v) => MapEntry(k.toString(), v));
    await _box.add(clean);

    // automatically prune anything older than retention window
    await _pruneOlderThan(DateTime.now().toUtc().subtract(retention));
  }

  List<Map<String, dynamic>> latest({int limit = 300}) {
    final keys = _box.keys.toList();

    final out = <Map<String, dynamic>>[];
    for (final k in keys.reversed.take(limit)) {
      final v = _box.get(k);
      if (v is Map) {
        out.add(v.map((key, value) => MapEntry(key.toString(), value)));
      }
    }
    return out;
  }

  Future<void> clear() async => _box.clear();

  int get length => _box.length;

  // -------------------------
  // Internal helpers
  // -------------------------

  Future<void> _pruneOlderThan(DateTime cutoffUtc) async {
    final keys = _box.keys.toList();

    for (final k in keys) {
      final v = _box.get(k);
      if (v is! Map) continue;

      final m = v.map((key, value) => MapEntry(key.toString(), value));
      final ts = _parseUtc(m['timestampUtc']);

      // If timestamp missing/unparseable, keep it (safer than deleting unknown data)
      if (ts == null) continue;

      if (ts.isBefore(cutoffUtc)) {
        await _box.delete(k);
      }
    }
  }

  DateTime? _parseUtc(dynamic value) {
    if (value == null) return null;

    final s = value.toString().trim();
    if (s.isEmpty) return null;

    try {
      final dt = DateTime.parse(s);
      return dt.isUtc ? dt : dt.toUtc();
    } catch (_) {
      return null;
    }
  }
}