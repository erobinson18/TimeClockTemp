import 'package:hive_flutter/hive_flutter.dart';

class StatusCache {
  static const _boxName = 'status_cache';

  Box get _box => Hive.box(_boxName);

  Future<void> setIsClockedIn(String employeeId, bool isClockedIn) async {
    await _box.put(employeeId, isClockedIn);
  }

  bool? getIsClockedIn(String employeeId) {
    final v = _box.get(employeeId);
    if (v is bool) return v;
    return null;
  }

  Future<void> clear() async => _box.clear();
}
