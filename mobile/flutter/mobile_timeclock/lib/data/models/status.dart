class StatusResponse {
  final bool isClockedIn;

  const StatusResponse({
    required this.isClockedIn,
  });

  factory StatusResponse.fromRaw(String raw) {
    final r = raw.trim().toLowerCase();

    // Conservative parsing until you provide real raw strings.
    // If it contains "out" => OUT.
    // Else if contains "in" => IN.
    if (r.contains("out")) {
      return StatusResponse(isClockedIn: false);
    }
    if (r.contains("in")) {
      return StatusResponse(isClockedIn: true);
    }
    if (r == "1" || r == "true") {
      return StatusResponse(isClockedIn: true);
    }
    return StatusResponse(isClockedIn: false);
  }
}