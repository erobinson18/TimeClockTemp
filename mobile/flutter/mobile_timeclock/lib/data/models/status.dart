class StatusResponse {
  final bool isClockedIn;

  /// Parsed from GetStatus format: "LAST, FIRST MIDDLE;IN"
  final String? fullName;

  /// Usually "IN" or "OUT" when known.
  /// If server gives something else, we store what we can.
  final String? rawStatus;

  const StatusResponse({
    required this.isClockedIn,
    this.fullName,
    this.rawStatus,
  });

  const StatusResponse.clockedIn()
      : isClockedIn = true,
        fullName = null,
        rawStatus = 'IN';

  const StatusResponse.clockedOut()
      : isClockedIn = false,
        fullName = null,
        rawStatus = 'OUT';

  const StatusResponse.unknown()
      : isClockedIn = false,
        fullName = null,
        rawStatus = null;

  Map<String, dynamic> toJson() => {
    'isClockedIn': isClockedIn,
    'fullName': fullName,
    'rawStatus': rawStatus,
  };

  factory StatusResponse.fromJson(Map<String, dynamic> json) {
    return StatusResponse(
      isClockedIn: (json['isClockedIn'] as bool?) ?? false,
      fullName: json['fullName'] as String?,
      rawStatus: json['rawStatus'] as String?,
    );
  }
}