import 'package:hive_flutter/hive_flutter.dart';

class LocalSeqStore {
  static const _boxName = 'device';
  static const _key = 'localSeq';

  Future<Box> _open() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return await Hive.openBox(_boxName);
  }

  /// Returns the next sequence number and persists it.
  Future<int> next() async {
    final box = await _open();
    final current = (box.get(_key, defaultValue: 0) as int);
    final next = current + 1;
    await box.put(_key, next);
    return next;
  }

  Future<int> peek() async {
    final box = await _open();
    return (box.get(_key, defaultValue: 0) as int);
  }

  Future<void> reset([int value = 0]) async {
    final box = await _open();
    await box.put(_key, value);
  }
}
