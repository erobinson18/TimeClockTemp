class EmployeeDirectoryItem {
  final String employeeId;
  final String fullName;

  const EmployeeDirectoryItem({
    required this.employeeId,
    required this.fullName,
  });

  Map<String, dynamic> toJson() => {
        "employeeId": employeeId,
        "fullName": fullName,
      };

  factory EmployeeDirectoryItem.fromJson(Map<dynamic, dynamic> json) {
    return EmployeeDirectoryItem(
      employeeId: (json["employeeId"] as String?) ?? "",
      fullName: (json["fullName"] as String?) ?? "",
    );
  }
}