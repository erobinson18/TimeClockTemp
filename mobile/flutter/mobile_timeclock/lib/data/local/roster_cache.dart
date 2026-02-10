import 'package:hive/hive.dart';

class RosterCache {
  static const String boxName = 'roster_cache_v1';

  Future<Box> _box() async => await Hive.openBox(boxName);

  /// Save roster items as:
  /// { "34023": { "employeeId": "...guid...", "fullName": "LAST, FIRST MIDDLE" }, ... }
  Future<void> saveAll(List<Map<String, dynamic>> items) async {
    final box = await _box();
    final Map<String, dynamic> map = {};

    for (final e in items) {
      final empNum = (e['employeeNumber'] ?? '').toString().trim();
      if (empNum.isEmpty) continue;

      map[empNum] = {
        'employeeId': (e['employeeId'] ?? '').toString(),
        'fullName': (e['fullName'] ?? '').toString(),
      };
    }

    await box.put('employees', map);
    await box.put('lastUpdatedUtc', DateTime.now().toUtc().toIso8601String());
  }

  Future<Map<String, dynamic>> _getAllMap() async {
    final box = await _box();
    final data = box.get('employees');
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<({String employeeId, String fullName})?> findByEmployeeNumber(String employeeNumber) async {
    final map = await _getAllMap();
    final key = employeeNumber.trim();
    final raw = map[key];

    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final id = (m['employeeId'] ?? '').toString();
      final name = (m['fullName'] ?? '').toString();

      if (id.isEmpty || name.isEmpty) return null;
      return (employeeId: id, fullName: name);
    }
    return null;
  }

  Future<int> count() async {
    final map = await _getAllMap();
    return map.length;
  }

  Future<String?> lastUpdatedUtc() async {
    final box = await _box();
    final v = box.get('lastUpdatedUtc');
    return v is String ? v : null;
  }
}
