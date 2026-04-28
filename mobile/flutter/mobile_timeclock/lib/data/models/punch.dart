class PunchRequest {
  final String employeeId;

  // Kept for UI logic; backend doesn’t require it but we keep it for your app.
  final int punchType;

  final int deviceType;
  final String deviceId;
  final String macAddress;
  final String description;

  final int localSequenceNumber;
  final DateTime timestampUtc;

  const PunchRequest({
    required this.employeeId,
    required this.punchType,
    required this.deviceType,
    required this.deviceId,
    required this.macAddress,
    required this.description,
    required this.localSequenceNumber,
    required this.timestampUtc,
  });
}