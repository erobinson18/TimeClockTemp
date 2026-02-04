class SyncPunchDto {
  final String employeeId;
  final int punchType;
  final int localSequenceNumber;
  final DateTime timestampUtc;
  final double? latitude;
  final double? longitude;

  SyncPunchDto({
    required this.employeeId,
    required this.punchType,
    required this.localSequenceNumber,
    required this.timestampUtc,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'punchType': punchType,
        'localSequenceNumber': localSequenceNumber,
        'timestampUtc': timestampUtc.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
  };
}

class SyncBatchRequest {
  final String deviceId;
  final int deviceType;
  final List<SyncPunchDto> punches;

  SyncBatchRequest({
    required this.deviceId,
    required this.deviceType,
    required this.punches,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceType': deviceType,
        'punches': punches.map((p) => p.toJson()).toList(),
      };
}