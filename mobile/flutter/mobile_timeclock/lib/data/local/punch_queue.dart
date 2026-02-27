import 'package:hive_flutter/hive_flutter.dart';

class PunchQueue {
  static const String boxName = 'punch_queue';

  Box get _box => Hive.box(boxName);

  Future<void> enqueue(Map<String, dynamic> payload) async {
    final key = DateTime.now().microsecondsSinceEpoch.toString();
    await _box.put(key, payload);
  }

  Future<int> count() async => _box.length;

  Future<List<Map<String, dynamic>>> all() async {
    final out = <Map<String, dynamic>>[];
    for (final k in _box.keys) {
      final v = _box.get(k);
      if (v is Map) {
        out.add(v.map((key, value) => MapEntry(key.toString(), value)));
      }
    }
    return out;
  }

  Future<void> clear() async {
    await _box.clear();
  }

  Future<void> removeByLocalSeq(Set<int> acceptedSeq) async {
    final keysToDelete = <dynamic>[];

    for (final k in _box.keys) {
      final v = _box.get(k);
      if (v is Map) {
        final seq = (v['localSequenceNumber'] as num?)?.toInt();
        if (seq != null && acceptedSeq.contains(seq)) {
          keysToDelete.add(k);
        }
      }
    }

    for (final k in keysToDelete) {
      await _box.delete(k);
    }
  }
}