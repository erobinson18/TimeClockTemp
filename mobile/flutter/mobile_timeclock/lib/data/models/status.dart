class StatusResponse {
  final bool isClockedIn;

  StatusResponse({required this.isClockedIn});

  factory StatusResponse.fromJson(Map<String, dynamic> json) {
    return StatusResponse(
      isClockedIn: json['isClockedIn'] as bool? ?? false,
    );
  }
}