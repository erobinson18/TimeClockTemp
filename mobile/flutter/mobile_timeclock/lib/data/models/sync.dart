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
        "timestampUtc": timestampUtc.toUtc().toIso8601String(),
        "latitude": latitude,
        "longitude": longitude,
      };
}

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

/// Response from /api/Sync/batch
class SyncBatchResponse {
  final int processed;
  final List<int> acceptedSeq;

  SyncBatchResponse({
    required this.processed,
    required this.acceptedSeq,
  });

  factory SyncBatchResponse.fromJson(Map<String, dynamic> json) {
    final processed = (json["processed"] as num?)?.toInt() ?? 0;

    final accepted = json["acceptedSeq"];
    final acceptedSeq = (accepted is List)
        ? accepted.map((e) => (e as num).toInt()).toList()
        : <int>[];

    return SyncBatchResponse(
      processed: processed,
      acceptedSeq: acceptedSeq,
    );
  }
}
