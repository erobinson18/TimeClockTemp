class StatusResponse {
  final String employeeId;
  final bool isClockedIn;

  StatusResponse({required this.employeeId, required this.isClockedIn});

  factory StatusResponse.fromJson(Map<String, dynamic> json) => StatusResponse(
        employeeId: json['employeeId'] as String,
        isClockedIn: json['isClockedIn'] as bool,
      );
}