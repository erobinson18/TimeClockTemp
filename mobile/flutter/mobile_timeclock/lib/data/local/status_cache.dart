import 'package:hive_flutter/hive_flutter.dart';

class StatusCache {
  static const _boxName = 'status_cache';

  static const _kName = '__displayName';
  static const _kRaw = '__rawStatus';

  Box get _box => Hive.box(_boxName);

  Future<void> setIsClockedIn(String employeeId, bool isClockedIn) async {
    await _box.put(employeeId, isClockedIn);
  }

  bool? getIsClockedIn(String employeeId) {
    final v = _box.get(employeeId);
    if (v is bool) return v;
    return null;
  }

  Future<void> setDisplayName(String employeeId, String displayName) async {
    await _box.put('$employeeId$_kName', displayName.trim());
  }

  String? getDisplayName(String employeeId) {
    final v = _box.get('$employeeId$_kName');
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }

  Future<void> setRawStatus(String employeeId, String rawStatus) async {
    await _box.put('$employeeId$_kRaw', rawStatus.trim());
  }

  String? getRawStatus(String employeeId) {
    final v = _box.get('$employeeId$_kRaw');
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }

  Future<void> clear() async => _box.clear();
}