import 'package:hive_flutter/hive_flutter.dart';

class LocalSeqStore {
  static const _boxName = 'device';
  static const _key = 'localSeq';

  Box get _box => Hive.box(_boxName);

  /// Returns the next sequence number and persists it.
  int next() {
    final current = (_box.get(_key, defaultValue: 0) as int);
    final nextVal = current + 1;
    _box.put(_key, nextVal);
    return nextVal;
  }

  int peek() => (_box.get(_key, defaultValue: 0) as int);

  Future<void> reset([int value = 0]) async => _box.put(_key, value);
}
