class VerifyRequest {
  /// preferred (matches backend VerifyRequestDto / VerifyRequestDto)
  final String employeeNumber;

  /// backward-compat if any old code still sends "employeeId"
  final String? employeeId;

  VerifyRequest({
    required this.employeeNumber,
    this.employeeId,
  });

  Map<String, dynamic> toJson() => {
        "employeeNumber": employeeNumber,
        if (employeeId != null) "employeeId": employeeId,
      };
}

class VerifyResponse {
  final bool isValid;
  final String? employeeId; // GUID string from backend
  final String? employeeNumber;
  final String? fullName;
  final bool isClockedIn;

  VerifyResponse({
    required this.isValid,
    required this.employeeId,
    required this.employeeNumber,
    required this.fullName,
    required this.isClockedIn,
  });

  factory VerifyResponse.fromJson(Map<String, dynamic> json) {
    // Support multiple possible key spellings just in case
    final isValid = (json["isValid"] as bool?) ??
        // if backend returns unauthorized or null, isValid may not exist
        (json["employeeId"] != null);

    return VerifyResponse(
      isValid: isValid,
      employeeId: json["employeeId"] as String?,
      employeeNumber: json["employeeNumber"] as String?,
      fullName: json["fullName"] as String? ?? json["displayName"] as String?,
      isClockedIn: (json["isClockedIn"] as bool?) ??
          (json["clockedIn"] as bool?) ??
          false,
    );
  }

  Map<String, dynamic> toJson() => {
        "isValid": isValid,
        "employeeId": employeeId,
        "employeeNumber": employeeNumber,
        "fullName": fullName,
        "isClockedIn": isClockedIn,
      };
}
