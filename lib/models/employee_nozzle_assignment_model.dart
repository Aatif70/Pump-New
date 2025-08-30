class EmployeeNozzleAssignment {
  final String employeeNozzleAssignmentId;
  final String employeeId;
  final String employeeName;
  final String fuelDispenserUnitId;
  final int? fuelDispenserNo;
  final String nozzleId;
  final int nozzleNumber;
  final String fuelType;
  final String fuelTypeId;
  final String fuelTankId;
  final String petrolPumpId;
  final String shiftId;
  final int shiftNumber;
  final String shiftStartTime;
  final String shiftEndTime;
  final String startDate;
  final String endDate;
  final String createdAt;
  final bool isActive;

  EmployeeNozzleAssignment({
    required this.employeeNozzleAssignmentId,
    required this.employeeId,
    required this.employeeName,
    required this.fuelDispenserUnitId,
    this.fuelDispenserNo,
    required this.nozzleId,
    required this.nozzleNumber,
    required this.fuelType,
    required this.fuelTypeId,
    required this.fuelTankId,
    required this.petrolPumpId,
    required this.shiftId,
    required this.shiftNumber,
    required this.shiftStartTime,
    required this.shiftEndTime,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.isActive,
  });

  factory EmployeeNozzleAssignment.fromJson(Map<String, dynamic> json) {
    return EmployeeNozzleAssignment(
      employeeNozzleAssignmentId: json['employeeNozzleAssignmentId'] ?? '',
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      fuelDispenserUnitId: json['fuelDispenserUnitId'] ?? '',
      fuelDispenserNo: json['fuelDispenserNo'],
      nozzleId: json['nozzleId'] ?? '',
      nozzleNumber: json['nozzleNumber'] ?? 0,
      fuelType: json['fuelType'] ?? '',
      fuelTypeId: json['fuelTypeId'] ?? '',
      fuelTankId: json['fuelTankId'] ?? '',
      petrolPumpId: json['petrolPumpId'] ?? '',
      shiftId: json['shiftId'] ?? '',
      shiftNumber: json['shiftNumber'] ?? 0,
      shiftStartTime: json['shiftStartTime'] ?? '',
      shiftEndTime: json['shiftEndTime'] ?? '',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      createdAt: json['createdAt'] ?? '',
      isActive: json['isActive'] ?? false,
    );
  }
} 