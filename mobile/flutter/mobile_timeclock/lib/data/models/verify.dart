class VerifyResponse {
  final bool isValid;
  final String? employeeId;
  final String? employeeNumber;
  final String? fullName;
  final bool isClockedIn;

  const VerifyResponse({
    required this.isValid,
    required this.employeeId,
    required this.employeeNumber,
    required this.fullName,
    required this.isClockedIn,
  });
}