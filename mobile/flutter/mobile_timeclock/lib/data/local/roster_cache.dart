import 'package:hive_flutter/hive_flutter.dart';

import '../models/employee_directory_item.dart';

class RosterCache {
  static const String _boxName = 'roster_cache';

  Box get _box => Hive.box(_boxName);

  Future<void> saveAll(List<Map<String, dynamic>> items) async {
    // Store as employeeNumber -> map
    final Map<String, Map<String, dynamic>> keyed = {};
    for (final m in items) {
      final empNum = (m['employeeNumber'] ?? '').toString().trim();
      if (empNum.isEmpty) continue;
      keyed[empNum] = m;
    }

    await _box.clear();
    await _box.putAll(keyed);
  }

  Future<EmployeeDirectoryItem?> findByEmployeeNumber(String employeeNumber) async {
    final key = employeeNumber.trim();
    if (key.isEmpty) return null;

    final v = _box.get(key);
    if (v is Map) {
      final map = v.map((k, val) => MapEntry(k.toString(), val));
      return EmployeeDirectoryItem.fromJson(map);
    }
    return null;
  }
}