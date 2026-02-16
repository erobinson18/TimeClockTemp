class PunchRequest {
  final String employeeId;

  /// 0 = ClockIn, 1 = ClockOut
  final int punchType;

  final int deviceType;
  final String deviceId;
  final int localSequenceNumber;

  final DateTime timestampUtc;
  final double? latitude;
  final double? longitude;

  PunchRequest({
    required this.employeeId,
    required this.punchType,
    required this.deviceType,
    required this.deviceId,
    required this.localSequenceNumber,
    required this.timestampUtc,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
        "employeeId": employeeId,
        "punchType": punchType,
        "deviceType": deviceType,
        "deviceId": deviceId,
        "localSequenceNumber": localSequenceNumber,
        "timestampUtc": timestampUtc.toUtc().toIso8601String(),
        "latitude": latitude,
        "longitude": longitude,
      };
}
