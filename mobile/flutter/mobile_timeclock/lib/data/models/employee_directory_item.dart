class EmployeeDirectoryItem {
  final String employeeId; // GUID string
  final String employeeNumber; // 5-6 digit string
  final String fullName;

  EmployeeDirectoryItem({
    required this.employeeId,
    required this.employeeNumber,
    required this.fullName,
  });

  factory EmployeeDirectoryItem.fromJson(Map<String, dynamic> json) {
    return EmployeeDirectoryItem(
      employeeId: json['employeeId'] as String,
      employeeNumber: json['employeeNumber'] as String,
      fullName: json['fullName'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'employeeNumber': employeeNumber,
        'fullName': fullName,
      };
}
