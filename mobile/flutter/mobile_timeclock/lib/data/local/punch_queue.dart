import 'package:hive_flutter/hive_flutter.dart';

import '../../core/Services/device_config_service.dart';

class PunchQueue {
  static const String boxName = 'punch_queue';

  Box get _box => Hive.box(boxName);

  Future<int> count() async => _box.length;

  /// Used by StatusScreen (and admin tools)
  Future<List<Map<String, dynamic>>> all() async {
    final keys = _box.keys.toList();
    final out = <Map<String, dynamic>>[];

    for (final k in keys) {
      final v = _box.get(k);
      if (v is Map) {
        out.add(v.map((key, value) => MapEntry(key.toString(), value)));
      }
    }

    return out;
  }

  /// Used by StatusScreen to wipe queue
  Future<void> clear() async {
    await _box.clear();
  }

  Future<void> enqueue(Map<String, dynamic> payload) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    final entry = <String, dynamic>{
      ...payload,
      'queuedAtUtc': nowUtc,
      'deviceId': DeviceConfigService.deviceId,
      'verified': true,
    };

    await _box.add(entry);
  }

  Future<List<Map<String, dynamic>>> allVerified() async {
    final rows = await all();
    return rows.where((m) => (m['verified'] as bool?) ?? true).toList();
  }

  Future<void> removeByLocalSeq(Set<int> acceptedSeq) async {
    final keys = _box.keys.toList();

    for (final k in keys) {
      final v = _box.get(k);
      if (v is Map) {
        final m = v.map((key, value) => MapEntry(key.toString(), value));
        final seq = (m['localSequenceNumber'] as num?)?.toInt();
        if (seq != null && acceptedSeq.contains(seq)) {
          await _box.delete(k);
        }
      }
    }
  }
}