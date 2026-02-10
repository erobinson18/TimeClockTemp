class SyncPunchBatch {
  final String deviceId;
  final int deviceType;
  final List<SyncPunch> punches;

  SyncPunchBatch({
    required this.deviceId,
    required this.deviceType,
    required this.punches,
  });

  Map<String, dynamic> toJson() => {
        "deviceId": deviceId,
        "deviceType": deviceType,
        "punches": punches.map((p) => p.toJson()).toList(),
      };
}

class SyncPunch {
  final String employeeId;
  final int punchType;
  final int localSequenceNumber;
  final DateTime timestampUtc;
  final double? latitude;
  final double? longitude;

  SyncPunch({
    required this.employeeId,
    required this.punchType,
    required this.localSequenceNumber,
    required this.timestampUtc,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
        "employeeId": employeeId,
        "punchType": punchType,
        "localSequenceNumber": localSequenceNumber,
        "timestampUtc": timestampUtc.toIso8601String(),
        "latitude": latitude,
        "longitude": longitude,
      };
}

class SyncBatchResult {
  final int processed;
  final List<int> acceptedSeq;

  SyncBatchResult({
    required this.processed,
    required this.acceptedSeq,
  });

  factory SyncBatchResult.fromJson(Map<String, dynamic> json) {
    final seq = (json["acceptedSeq"] as List?) ?? const [];
    return SyncBatchResult(
      processed: (json["processed"] as num?)?.toInt() ?? 0,
      acceptedSeq: seq.map((e) => (e as num).toInt()).toList(),
    );
  }
}
