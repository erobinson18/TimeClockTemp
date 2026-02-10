class VerifyRequest {
  final String employeeId;

  VerifyRequest({required this.employeeId});

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
      };
}

class VerifyResponse {
  final String employeeId; // GUID string from backend
  final String fullName;
  final bool isClockedIn;

  VerifyResponse({
    required this.employeeId,
    required this.fullName,
    required this.isClockedIn,
  });

  factory VerifyResponse.fromJson(Map<String, dynamic> json) {
    return VerifyResponse(
      employeeId: json['employeeId'] as String,
      fullName: json['fullName'] as String,
      isClockedIn: (json['isClockedIn'] as bool?) ?? false,
    );
  }
}
