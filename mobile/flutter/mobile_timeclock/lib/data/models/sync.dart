class SyncPunch {
  final String employeeId;
  final int punchType;
  final int localSequenceNumber;
  final DateTime timestampUtc;
  final double? latitude;
  final double? longitude;

  const SyncPunch({
    required this.employeeId,
    required this.punchType,
    required this.localSequenceNumber,
    required this.timestampUtc,
    this.latitude,
    this.longitude,
  });
}

class SyncPunchBatch {
  final String deviceId;
  final int deviceType;
  final List<SyncPunch> punches;

  const SyncPunchBatch({
    required this.deviceId,
    required this.deviceType,
    required this.punches,
  });
}

class SyncResult {
  final int processed;
  final List<int> acceptedSeq;

  const SyncResult({
    required this.processed,
    required this.acceptedSeq,
  });
}