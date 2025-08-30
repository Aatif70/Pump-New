class ShiftSales {
  String? id;
  double cashAmount;
  double creditCardAmount;
  double litersSold;
  double totalAmount;
  double upiAmount;
  String employeeId;
  String shiftId;
  String fuelDispenserId;
  String nozzleId;
  double pricePerLiter;
  String? petrolPumpId;
  String? fuelTypeId;

  ShiftSales({
    this.id,
    required this.cashAmount,
    required this.creditCardAmount,
    required this.litersSold,
    required this.totalAmount,
    required this.upiAmount,
    required this.employeeId,
    required this.shiftId,
    required this.fuelDispenserId,
    required this.nozzleId,
    required this.pricePerLiter,
    this.petrolPumpId,
    this.fuelTypeId,
  });

  factory ShiftSales.fromJson(Map<String, dynamic> json) {
    return ShiftSales(
      id: json['id'],
      cashAmount: json['cashAmount']?.toDouble() ?? 0.0,
      creditCardAmount: json['creditCardAmount']?.toDouble() ?? 0.0,
      litersSold: json['litersSold']?.toDouble() ?? 0.0,
      totalAmount: json['totalAmount']?.toDouble() ?? 0.0,
      upiAmount: json['upiAmount']?.toDouble() ?? 0.0,
      employeeId: json['employeeId'],
      shiftId: json['shiftId'],
      fuelDispenserId: json['fuelDispenserId'],
      nozzleId: json['nozzleId'],
      pricePerLiter: json['pricePerLiter']?.toDouble() ?? 0.0,
      petrolPumpId: json['petrolPumpId'],
      fuelTypeId: json['fuelTypeId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'cashAmount': cashAmount,
      'creditCardAmount': creditCardAmount,
      'litersSold': litersSold,
      'totalAmount': totalAmount,
      'upiAmount': upiAmount,
      'employeeId': employeeId,
      'shiftId': shiftId,
      'fuelDispenserId': fuelDispenserId,
      'nozzleId': nozzleId,
      'pricePerLiter': pricePerLiter,
      if (petrolPumpId != null) 'petrolPumpId': petrolPumpId,
      if (fuelTypeId != null) 'fuelTypeId': fuelTypeId,
    };
  }
} 