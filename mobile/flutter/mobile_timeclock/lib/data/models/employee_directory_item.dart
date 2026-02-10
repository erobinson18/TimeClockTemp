class EmployeeDirectoryItem {
  final String employeeId;
  final String employeeNumber;
  final String fullName;

  EmployeeDirectoryItem({
    required this.employeeId,
    required this.employeeNumber,
    required this.fullName,
  });

  factory EmployeeDirectoryItem.fromJson(Map<String, dynamic> json) {
    return EmployeeDirectoryItem(
      employeeId: (json['employeeId'] ?? '').toString(),
      employeeNumber: (json['employeeNumber'] ?? '').toString(),
      fullName: (json['fullName'] ?? '').toString(),
    );
  }
}