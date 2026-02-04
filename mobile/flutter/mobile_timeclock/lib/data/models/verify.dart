class VerifyRequest {
  final String employeeId;
  VerifyRequest({required this.employeeId});
  Map<String, dynamic> toJson() => {'employeeId': employeeId};
}

class VerifyResponse {
  final bool isValid;
  final String? employeeId;
  final String? displayName;

  VerifyResponse({required this.isValid, this.employeeId, this.displayName});

  factory VerifyResponse.fromJson(Map<String, dynamic> json) => VerifyResponse(
      isValid: json['isValid'] as bool,
      employeeId: json['employeeId'] as String?,
      displayName: json['displayName'] as String?,
    );
}