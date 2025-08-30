class EmployeeShift {
  final String? id;
  final String employeeId;
  final String shiftId;
  final DateTime assignedDate;
  final bool isTransfer;

  EmployeeShift({
    this.id,
    required this.employeeId,
    required this.shiftId,
    required this.assignedDate,
    this.isTransfer = false,
  });

  factory EmployeeShift.fromJson(Map<String, dynamic> json) {
    return EmployeeShift(
      id: json['id'],
      employeeId: json['employeeId'],
      shiftId: json['shiftId'],
      assignedDate: DateTime.parse(json['assignedDate']),
      isTransfer: json['isTransfer'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'shiftId': shiftId,
      'assignedDate': assignedDate.toIso8601String(),
      'isTransfer': isTransfer,
    };
  }
} 