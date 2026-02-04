class PunchRequest {
  final String employeeId; // GUID string
  final int punchType; // 1 for clock-in, 2 for clock-out
  final int deviceType; // 1=Android/Web
  final String deviceId;
  final int localSequenceNumber;
  final double? latitude;
  final double? longitude;

  PunchRequest({
    required this.employeeId,
    required this.punchType,
    required this.deviceType,
    required this.deviceId,
    required this.localSequenceNumber,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'punchType': punchType,
        'deviceType': deviceType,
        'deviceId': deviceId,
        'localSequenceNumber': localSequenceNumber,
        'latitude': latitude,
        'longitude': longitude,
      };
}