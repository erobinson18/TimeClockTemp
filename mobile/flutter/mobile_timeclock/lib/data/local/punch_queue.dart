import 'package:hive/hive.dart';

class PunchQueue {
  static const String boxName = 'pending_punches';

  Future<Box> _box() async => await Hive.openBox(boxName);

  Future<void> enqueue(Map<String, dynamic> punchJson) async {
    final box = await _box();
    await box.add(punchJson);
  }

  Future<List<Map<String, dynamic>>> all() async {
    final box = await _box();
    return box.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> clear() async {
    final box = await _box();
    await box.clear();
  }

  Future<int> count() async {
    final box = await _box();
    return box.length;
  }
}
