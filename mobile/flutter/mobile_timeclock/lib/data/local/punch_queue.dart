import 'package:hive_flutter/hive_flutter.dart';

import '../../core/Services/device_config_service.dart';

class PunchQueue {
  static const String boxName = 'punch_queue';

  Box get _box => Hive.box(boxName);

  Future<int> count() async => _box.length;

  /// Returns every queued row as a normalized map.
  /// Used by StatusScreen and admin/debug tools.
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

  /// Clears the entire offline queue.
  Future<void> clear() async {
    await _box.clear();
  }

  /// Adds a punch to the offline queue.
  ///
  /// Expected incoming payload keys:
  /// - employeeId
  /// - punchType
  /// - localSequenceNumber
  /// - timestampUtc
  /// - latitude
  /// - longitude
  /// - accuracyMeters
  /// - locationSource
  Future<void> enqueue(Map<String, dynamic> payload) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    final entry = <String, dynamic>{
      'employeeId': (payload['employeeId'] ?? '').toString(),
      'punchType': (payload['punchType'] as num?)?.toInt() ?? 0,
      'localSequenceNumber':
      (payload['localSequenceNumber'] as num?)?.toInt() ?? 0,
      'timestampUtc': (payload['timestampUtc'] ?? '').toString(),

      // GPS / location audit fields
      'latitude': (payload['latitude'] as num?)?.toDouble(),
      'longitude': (payload['longitude'] as num?)?.toDouble(),
      'accuracyMeters': (payload['accuracyMeters'] as num?)?.toDouble(),
      'locationSource': (payload['locationSource'] ?? '').toString(),

      // queue metadata
      'queuedAtUtc': nowUtc,
      'deviceId': DeviceConfigService.deviceId,
      'verified': (payload['verified'] as bool?) ?? true,
    };

    await _box.add(entry);
  }

  /// Returns only rows marked verified.
  Future<List<Map<String, dynamic>>> allVerified() async {
    final rows = await all();
    return rows.where((m) => (m['verified'] as bool?) ?? true).toList();
  }

  /// Removes queued punches whose local sequence number
  /// has been accepted by the server.
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