class VerifyResponse {
  final String employeeId;
  final String employeeNumber;
  final String fullName;
  final bool isClockedIn;

  VerifyResponse({
    required this.employeeId,
    required this.employeeNumber,
    required this.fullName,
    required this.isClockedIn,
  });

  factory VerifyResponse.fromJson(Map<String, dynamic> json) {
    return VerifyResponse(
      employeeId: json['employeeId'],
      employeeNumber: json['employeeNumber'],
      fullName: json['fullName'],
      isClockedIn: json['isClockedIn'],
    );
  }
}
