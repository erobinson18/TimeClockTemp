import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PunchQueue {
  static const _key = "punch_queue_v1";

  Future<List<Map<String, dynamic>>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_key);
    if (str == null || str.isEmpty) return [];

    final decoded = jsonDecode(str);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
  }

  Future<int> count() async => (await all()).length;

  Future<void> enqueue(Map<String, dynamic> punch) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await all();
    list.add(punch);
    await prefs.setString(_key, jsonEncode(list));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> removeByLocalSeq(Set<int> seqs) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await all();

    final kept = list.where((p) {
      final v = p["localSequenceNumber"];
      final n = (v is num) ? v.toInt() : int.tryParse("$v") ?? -1;
      return !seqs.contains(n);
    }).toList();

    await prefs.setString(_key, jsonEncode(kept));
  }
}
