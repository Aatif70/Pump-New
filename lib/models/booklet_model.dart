class Booklet {
  final String bookletId;
  final String customerId;
  final String petrolPumpId;
  final String bookletNumber;
  final int slipRangeStart;
  final int slipRangeEnd;
  final String bookletType;
  final int totalSlips;
  final int usedSlips;
  final int availableSlips;
  final bool isActive;
  final DateTime issuedDate;
  final DateTime? completedDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String customerName;
  final String customerCode;
  final String petrolPumpName;
  final bool isCompleted;
  final double utilizationPercentage;
  final int daysActive;
  final List<FuelSlip> fuelSlips;

  Booklet({
    required this.bookletId,
    required this.customerId,
    required this.petrolPumpId,
    required this.bookletNumber,
    required this.slipRangeStart,
    required this.slipRangeEnd,
    required this.bookletType,
    required this.totalSlips,
    required this.usedSlips,
    required this.availableSlips,
    required this.isActive,
    required this.issuedDate,
    this.completedDate,
    required this.createdAt,
    required this.updatedAt,
    required this.customerName,
    required this.customerCode,
    required this.petrolPumpName,
    required this.isCompleted,
    required this.utilizationPercentage,
    required this.daysActive,
    required this.fuelSlips,
  });

  factory Booklet.fromJson(Map<String, dynamic> json) {
    return Booklet(
      bookletId: json['bookletId'] ?? '',
      customerId: json['customerId'] ?? '',
      petrolPumpId: json['petrolPumpId'] ?? '',
      bookletNumber: json['bookletNumber'] ?? '',
      slipRangeStart: json['slipRangeStart'] ?? 0,
      slipRangeEnd: json['slipRangeEnd'] ?? 0,
      bookletType: json['bookletType'] ?? '',
      totalSlips: json['totalSlips'] ?? 0,
      usedSlips: json['usedSlips'] ?? 0,
      availableSlips: json['availableSlips'] ?? 0,
      isActive: json['isActive'] ?? false,
      issuedDate: DateTime.parse(json['issuedDate'] ?? DateTime.now().toIso8601String()),
      completedDate: json['completedDate'] != null 
          ? DateTime.parse(json['completedDate']) 
          : null,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      customerName: json['customerName'] ?? '',
      customerCode: json['customerCode'] ?? '',
      petrolPumpName: json['petrolPumpName'] ?? '',
      isCompleted: json['isCompleted'] ?? false,
      utilizationPercentage: (json['utilizationPercentage'] ?? 0).toDouble(),
      daysActive: json['daysActive'] ?? 0,
      fuelSlips: (json['fuelSlips'] as List<dynamic>?)
          ?.map((slip) => FuelSlip.fromJson(slip))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookletId': bookletId,
      'customerId': customerId,
      'petrolPumpId': petrolPumpId,
      'bookletNumber': bookletNumber,
      'slipRangeStart': slipRangeStart,
      'slipRangeEnd': slipRangeEnd,
      'bookletType': bookletType,
      'totalSlips': totalSlips,
      'usedSlips': usedSlips,
      'availableSlips': availableSlips,
      'isActive': isActive,
      'issuedDate': issuedDate.toIso8601String(),
      'completedDate': completedDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'customerName': customerName,
      'customerCode': customerCode,
      'petrolPumpName': petrolPumpName,
      'isCompleted': isCompleted,
      'utilizationPercentage': utilizationPercentage,
      'daysActive': daysActive,
      'fuelSlips': fuelSlips.map((slip) => slip.toJson()).toList(),
    };
  }
}

class FuelSlip {
  final String slipId;
  final int slipNumber;
  final String bookletId;
  final String customerId;
  final String petrolPumpId;
  final String status;
  final DateTime? usedDate;
  final String? vehicleTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String bookletNumber;
  final String customerName;
  final String customerCode;
  final String petrolPumpName;
  final bool isAvailable;
  final bool isUsed;
  final bool isCancelled;
  final bool isLost;
  final String statusDisplayText;
  final bool canBeUsed;
  final dynamic vehicleTransaction;

  FuelSlip({
    required this.slipId,
    required this.slipNumber,
    required this.bookletId,
    required this.customerId,
    required this.petrolPumpId,
    required this.status,
    this.usedDate,
    this.vehicleTransactionId,
    required this.createdAt,
    required this.updatedAt,
    required this.bookletNumber,
    required this.customerName,
    required this.customerCode,
    required this.petrolPumpName,
    required this.isAvailable,
    required this.isUsed,
    required this.isCancelled,
    required this.isLost,
    required this.statusDisplayText,
    required this.canBeUsed,
    this.vehicleTransaction,
  });

  factory FuelSlip.fromJson(Map<String, dynamic> json) {
    return FuelSlip(
      slipId: json['slipId'] ?? '',
      slipNumber: json['slipNumber'] ?? 0,
      bookletId: json['bookletId'] ?? '',
      customerId: json['customerId'] ?? '',
      petrolPumpId: json['petrolPumpId'] ?? '',
      status: json['status'] ?? '',
      usedDate: json['usedDate'] != null 
          ? DateTime.parse(json['usedDate']) 
          : null,
      vehicleTransactionId: json['vehicleTransactionId'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      bookletNumber: json['bookletNumber'] ?? '',
      customerName: json['customerName'] ?? '',
      customerCode: json['customerCode'] ?? '',
      petrolPumpName: json['petrolPumpName'] ?? '',
      isAvailable: json['isAvailable'] ?? false,
      isUsed: json['isUsed'] ?? false,
      isCancelled: json['isCancelled'] ?? false,
      isLost: json['isLost'] ?? false,
      statusDisplayText: json['statusDisplayText'] ?? '',
      canBeUsed: json['canBeUsed'] ?? false,
      vehicleTransaction: json['vehicleTransaction'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slipId': slipId,
      'slipNumber': slipNumber,
      'bookletId': bookletId,
      'customerId': customerId,
      'petrolPumpId': petrolPumpId,
      'status': status,
      'usedDate': usedDate?.toIso8601String(),
      'vehicleTransactionId': vehicleTransactionId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'bookletNumber': bookletNumber,
      'customerName': customerName,
      'customerCode': customerCode,
      'petrolPumpName': petrolPumpName,
      'isAvailable': isAvailable,
      'isUsed': isUsed,
      'isCancelled': isCancelled,
      'isLost': isLost,
      'statusDisplayText': statusDisplayText,
      'canBeUsed': canBeUsed,
      'vehicleTransaction': vehicleTransaction,
    };
  }
}
