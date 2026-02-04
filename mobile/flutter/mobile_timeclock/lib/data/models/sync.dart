import 'punch.dart';

class SyncPunchBatch {
  final String deviceId;
  final int deviceType; // backend expects int (1,2)
  final List<SyncPunch> punches;

  SyncPunchBatch({
    required this.deviceId,
    required this.deviceType,
    required this.punches,
  });

  Map<String, dynamic> toJson() {
    return {
      "deviceId": deviceId,
      "deviceType": deviceType,
      "punches": punches.map((p) => p.toJson()).toList(),
    };
  }
}

class SyncPunch {
  final String employeeId; // GUID as string
  final int punchType;     // 1 = in, 2 = out
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

  Map<String, dynamic> toJson() {
    return {
      "employeeId": employeeId,
      "punchType": punchType,
      "localSequenceNumber": localSequenceNumber,
      "timestampUtc": timestampUtc.toIso8601String(),
      "latitude": latitude,
      "longitude": longitude,
    };
  }
}
