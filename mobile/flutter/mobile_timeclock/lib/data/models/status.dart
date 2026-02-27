class StatusResponse {
  final bool isClockedIn;

  const StatusResponse({required this.isClockedIn});

  const StatusResponse.clockedIn() : isClockedIn = true;
  const StatusResponse.clockedOut() : isClockedIn = false;

  const StatusResponse.unknown() : isClockedIn = false;

  Map<String, dynamic> toJson() => {'isClockedIn': isClockedIn};

  factory StatusResponse.fromJson(Map<String, dynamic> json) {
    return StatusResponse(isClockedIn: (json['isClockedIn'] as bool?) ?? false);
  }
}