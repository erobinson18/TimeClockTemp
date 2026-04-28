import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../data/remote/timeclock_api.dart';

class HeartbeatService {
  HeartbeatService({
    required TimeClockApi api,
    Duration interval = const Duration(seconds: 5),
  })  : _api = api,
        _interval = interval;

  final TimeClockApi _api;
  final Duration _interval;

  final ValueNotifier<bool> online = ValueNotifier<bool>(false);

  Timer? _timer;
  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;

    // quick first check
    _tick();

    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    try {
      await _api.ping();
      if (online.value != true) online.value = true;
    } catch (_) {
      if (online.value != false) online.value = false;
    }
  }

  void dispose() {
    stop();
    online.dispose();
  }
}