class Nozzle {
  String? id;
  String fuelDispenserUnitId;
  String? fuelType;
  int nozzleNumber;
  String status;
  DateTime? lastCalibrationDate;
  DateTime? createdAt;
  DateTime? updatedAt;
  String? fuelDispenserNumber;
  String? fuelTankId;
  String? petrolPumpId;
  String? assignedEmployee;
  String? assignmentId;
  String? fuelTypeId;

  Nozzle({
    this.id,
    required this.fuelDispenserUnitId,
    this.fuelType,
    required this.nozzleNumber,
    required this.status,
    this.lastCalibrationDate,
    this.createdAt,
    this.updatedAt,
    this.fuelDispenserNumber,
    this.fuelTankId,
    this.petrolPumpId,
    this.assignedEmployee,
    this.assignmentId,
    this.fuelTypeId,
  });

  factory Nozzle.fromJson(Map<String, dynamic> json) {
    return Nozzle(
      id: json['id'] ?? json['nozzleId'],
      fuelDispenserUnitId: json['fuelDispenserUnitId'],
      fuelType: json['fuelType'],
      nozzleNumber: json['nozzleNumber'],
      status: json['status'],
      lastCalibrationDate: json['lastCalibrationDate'] != null
          ? DateTime.parse(json['lastCalibrationDate'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      fuelDispenserNumber: json['fuelDispenserNumber']?.toString(),
      fuelTankId: json['fuelTankId'],
      petrolPumpId: json['petrolPumpId'],
      assignedEmployee: json['assignedEmployee'],
      assignmentId: json['assignmentId'],
      fuelTypeId: json['fuelTypeId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'nozzleId': id,
      'fuelDispenserUnitId': fuelDispenserUnitId,
      if (fuelType != null) 'fuelType': fuelType,
      'nozzleNumber': nozzleNumber,
      'status': status,
      'lastCalibrationDate': lastCalibrationDate?.toIso8601String(),
      if (fuelTankId != null) 'fuelTankId': fuelTankId,
      if (petrolPumpId != null) 'petrolPumpId': petrolPumpId,
      if (assignedEmployee != null) 'assignedEmployee': assignedEmployee,
      if (assignmentId != null) 'assignmentId': assignmentId,
      if (fuelTypeId != null) 'fuelTypeId': fuelTypeId,
    };
  }
} 