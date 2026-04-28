class EmployeeDirectoryItem {
  /// Temporary: until Vista gives a true GUID, we use employeeNumber as the ID.
  final String employeeId;

  final String employeeNumber;
  final String fullName;

  EmployeeDirectoryItem({
    required this.employeeId,
    required this.employeeNumber,
    required this.fullName,
  });

  Map<String, dynamic> toJson() => {
    'employeeId': employeeId,
    'employeeNumber': employeeNumber,
    'fullName': fullName,
  };

  factory EmployeeDirectoryItem.fromJson(Map<String, dynamic> json) {
    final empNum = (json['employeeNumber'] ?? '').toString();
    return EmployeeDirectoryItem(
      employeeId: (json['employeeId'] ?? empNum).toString(),
      employeeNumber: empNum,
      fullName: (json['fullName'] ?? '').toString(),
    );
  }
}