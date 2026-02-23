class StatusResponse {
  final bool isClockedIn;
  final String raw;

  const StatusResponse({
    required this.isClockedIn,
    required this.raw,
  });

  factory StatusResponse.fromRaw(String raw) {
    final r = raw.trim().toLowerCase();

    // Conservative parsing until you provide real raw strings.
    // If it contains "out" => OUT.
    // Else if contains "in" => IN.
    if (r.contains("out")) {
      return StatusResponse(isClockedIn: false, raw: raw);
    }
    if (r.contains("in")) {
      return StatusResponse(isClockedIn: true, raw: raw);
    }
    if (r == "1" || r == "true") {
      return StatusResponse(isClockedIn: true, raw: raw);
    }
    return StatusResponse(isClockedIn: false, raw: raw);
  }
}