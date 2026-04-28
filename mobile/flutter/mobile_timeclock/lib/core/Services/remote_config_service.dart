import 'package:hive_flutter/hive_flutter.dart';

class RemoteConfigService {
  static const String _deviceBox = 'device';
  static const String _kLastConfigSync = 'lastConfigSyncIso';

  static DateTime? get lastConfigSync {
    final box = Hive.box(_deviceBox);
    final raw = (box.get(_kLastConfigSync) as String?)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Placeholder: when backend is ready, this should call an endpoint and update:
  /// - baseUrl
  /// - kioskId
  /// - any future flags
  static Future<bool> trySync() async {
    final box = Hive.box(_deviceBox);
    await box.put(_kLastConfigSync, DateTime.now().toIso8601String());

    // No backend yet → return false meaning “no changes applied”
    return false;
  }
}