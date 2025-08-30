class GovernmentTesting {
  final String? governmentTestingId;
  final String petrolPumpId;
  final String? petrolPumpName;
  final String employeeId;
  final String? employeeName;
  final String shiftId;
  final String? shiftName;
  final String nozzleId;
  final String? nozzleNumber;
  final String? dispenserNumber;
  final String? fuelTypeId;
  final String? fuelTypeName;
  String? fuelTankId; // Changed to be mutable for empty string handling
  final String? tankName;
  final double testingLiters;
  final DateTime? testingDateTime;
  final bool isAddedBackToTank;
  final DateTime? addedBackDateTime;
  final String? addedBackByEmployeeId;
  final String? addedBackByEmployeeName;
  final String? managerApprovalStatus;
  final String? approvedByManagerId;
  final String? approvedByManagerName;
  final DateTime? approvalDateTime;
  final String? approvalNotes;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final String? urgencyLevel;
  final int waitingHours;
  final int? approvalTimeHours;
  final bool isOverdue;
  final int? hoursSinceApproval;
  final bool isUrgentAddBack;
  final String? addBackPriority;
  final bool canAddBackNow;
  final double tankSpaceAvailable;
  final int? addBackDelayHours;
  final bool isLateAddBack;
  final int? totalCycleTimeHours;
  final String? performanceRating;

  GovernmentTesting({
    this.governmentTestingId,
    required this.petrolPumpId,
    this.petrolPumpName,
    required this.employeeId,
    this.employeeName,
    required this.shiftId,
    this.shiftName,
    required this.nozzleId,
    this.nozzleNumber,
    this.dispenserNumber,
    this.fuelTypeId,
    this.fuelTypeName,
    this.fuelTankId,
    this.tankName,
    required this.testingLiters,
    this.testingDateTime,
    this.isAddedBackToTank = false,
    this.addedBackDateTime,
    this.addedBackByEmployeeId,
    this.addedBackByEmployeeName,
    this.managerApprovalStatus,
    this.approvedByManagerId,
    this.approvedByManagerName,
    this.approvalDateTime,
    this.approvalNotes,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.urgencyLevel,
    this.waitingHours = 0,
    this.approvalTimeHours,
    this.isOverdue = false,
    this.hoursSinceApproval,
    this.isUrgentAddBack = false,
    this.addBackPriority,
    this.canAddBackNow = false,
    this.tankSpaceAvailable = 0,
    this.addBackDelayHours,
    this.isLateAddBack = false,
    this.totalCycleTimeHours,
    this.performanceRating,
  });

  factory GovernmentTesting.fromJson(Map<String, dynamic> json) {
    return GovernmentTesting(
      governmentTestingId: json['governmentTestingId'],
      petrolPumpId: json['petrolPumpId'],
      petrolPumpName: json['petrolPumpName'],
      employeeId: json['employeeId'],
      employeeName: json['employeeName'],
      shiftId: json['shiftId'],
      shiftName: json['shiftName'],
      nozzleId: json['nozzleId'],
      nozzleNumber: json['nozzleNumber'],
      dispenserNumber: json['dispenserNumber'],
      fuelTypeId: json['fuelTypeId'],
      fuelTypeName: json['fuelTypeName'],
      fuelTankId: json['fuelTankId'],
      tankName: json['tankName'],
      testingLiters: json['testingLiters']?.toDouble() ?? 0.0,
      testingDateTime: json['testingDateTime'] != null ? DateTime.parse(json['testingDateTime']) : null,
      isAddedBackToTank: json['isAddedBackToTank'] ?? false,
      addedBackDateTime: json['addedBackDateTime'] != null ? DateTime.parse(json['addedBackDateTime']) : null,
      addedBackByEmployeeId: json['addedBackByEmployeeId'],
      addedBackByEmployeeName: json['addedBackByEmployeeName'],
      managerApprovalStatus: json['managerApprovalStatus'],
      approvedByManagerId: json['approvedByManagerId'],
      approvedByManagerName: json['approvedByManagerName'],
      approvalDateTime: json['approvalDateTime'] != null ? DateTime.parse(json['approvalDateTime']) : null,
      approvalNotes: json['approvalNotes'],
      notes: json['notes'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      isActive: json['isActive'] ?? true,
      urgencyLevel: json['urgencyLevel'],
      waitingHours: json['waitingHours'] ?? 0,
      approvalTimeHours: json['approvalTimeHours'],
      isOverdue: json['isOverdue'] ?? false,
      hoursSinceApproval: json['hoursSinceApproval'],
      isUrgentAddBack: json['isUrgentAddBack'] ?? false,
      addBackPriority: json['addBackPriority'],
      canAddBackNow: json['canAddBackNow'] ?? false,
      tankSpaceAvailable: json['tankSpaceAvailable']?.toDouble() ?? 0.0,
      addBackDelayHours: json['addBackDelayHours'],
      isLateAddBack: json['isLateAddBack'] ?? false,
      totalCycleTimeHours: json['totalCycleTimeHours'],
      performanceRating: json['performanceRating'],
    );
  }

  Map<String, dynamic> toJson() {
    // Convert empty strings to null for certain fields
    final String? cleanFuelTankId = fuelTankId == null || fuelTankId!.isEmpty ? null : fuelTankId;
    final String? cleanFuelTypeId = fuelTypeId == null || fuelTypeId!.isEmpty ? null : fuelTypeId;
    
    return {
      'governmentTestingId': governmentTestingId,
      'petrolPumpId': petrolPumpId,
      'petrolPumpName': petrolPumpName,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'shiftId': shiftId,
      'shiftName': shiftName,
      'nozzleId': nozzleId,
      'nozzleNumber': nozzleNumber,
      'dispenserNumber': dispenserNumber,
      'fuelTypeId': cleanFuelTypeId,
      'fuelTypeName': fuelTypeName,
      'fuelTankId': cleanFuelTankId,
      'tankName': tankName,
      'testingLiters': testingLiters,
      'testingDateTime': testingDateTime?.toIso8601String(),
      'isAddedBackToTank': isAddedBackToTank,
      'addedBackDateTime': addedBackDateTime?.toIso8601String(),
      'addedBackByEmployeeId': addedBackByEmployeeId,
      'addedBackByEmployeeName': addedBackByEmployeeName,
      'managerApprovalStatus': managerApprovalStatus,
      'approvedByManagerId': approvedByManagerId,
      'approvedByManagerName': approvedByManagerName,
      'approvalDateTime': approvalDateTime?.toIso8601String(),
      'approvalNotes': approvalNotes,
      'notes': notes,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
      'urgencyLevel': urgencyLevel,
      'waitingHours': waitingHours,
      'approvalTimeHours': approvalTimeHours,
      'isOverdue': isOverdue,
      'hoursSinceApproval': hoursSinceApproval,
      'isUrgentAddBack': isUrgentAddBack,
      'addBackPriority': addBackPriority,
      'canAddBackNow': canAddBackNow,
      'tankSpaceAvailable': tankSpaceAvailable,
      'addBackDelayHours': addBackDelayHours,
      'isLateAddBack': isLateAddBack,
      'totalCycleTimeHours': totalCycleTimeHours,
      'performanceRating': performanceRating,
    };
  }
} 