import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CachedEmployee {
  final String employeeId; // GUID string
  final String employeeNumber;
  final String fullName;

  CachedEmployee({
    required this.employeeId,
    required this.employeeNumber,
    required this.fullName,
  });

  factory CachedEmployee.fromJson(Map<String, dynamic> j) => CachedEmployee(
        employeeId: (j["employeeId"] ?? "") as String,
        employeeNumber: (j["employeeNumber"] ?? "") as String,
        fullName: (j["fullName"] ?? "") as String,
      );

  Map<String, dynamic> toJson() => {
        "employeeId": employeeId,
        "employeeNumber": employeeNumber,
        "fullName": fullName,
      };
}

class RosterCache {
  static const _key = "roster_cache_v1";

  Future<void> saveAll(List<Map<String, dynamic>> rosterJson) async {
    final prefs = await SharedPreferences.getInstance();
    final str = jsonEncode(rosterJson);
    await prefs.setString(_key, str);
  }

  Future<List<CachedEmployee>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_key);
    if (str == null || str.isEmpty) return [];

    final decoded = jsonDecode(str);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((m) => CachedEmployee.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<CachedEmployee?> findByEmployeeNumber(String employeeNumber) async {
    final list = await all();
    return list.firstWhere(
      (e) => e.employeeNumber == employeeNumber,
      orElse: () => CachedEmployee(
        employeeId: "",
        employeeNumber: "",
        fullName: "",
      ),
    ).employeeId.isEmpty
        ? null
        : list.firstWhere((e) => e.employeeNumber == employeeNumber);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
