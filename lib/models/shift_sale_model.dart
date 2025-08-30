class ShiftSale {
  final String? shiftSaleId;
  final DateTime reportedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String employeeName;
  final int shiftNumber;
  final String fuelType;
  final int dispenserNumber;
  final int? nozzleNumber;
  final double totalAmount;    // This is totalSales
  final double litersSold;     // This is totalLiters
  final double? cashAmount;
  final double? creditCardAmount;
  final double? upiAmount;
  final String? employeeId;
  final String? shiftId;
  final String? fuelDispenserId;
  final String? nozzleId;
  final Map<String, dynamic>? fuelTypeSales;

  ShiftSale({
    this.shiftSaleId,
    required this.reportedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.employeeName,
    required this.shiftNumber,
    required this.fuelType,
    required this.dispenserNumber,
    this.nozzleNumber,
    required this.totalAmount,
    required this.litersSold,
    this.cashAmount,
    this.creditCardAmount,
    this.upiAmount,
    this.employeeId,
    this.shiftId,
    this.fuelDispenserId,
    this.nozzleId,
    this.fuelTypeSales,
  });

  factory ShiftSale.fromJson(Map<String, dynamic> json) {
    // Handle the fuelTypeSales which might be a nested object
    Map<String, dynamic>? fuelTypeSalesMap;
    if (json['fuelTypeSales'] != null) {
      fuelTypeSalesMap = Map<String, dynamic>.from(json['fuelTypeSales']);
    }

    // Parse dates safely
    DateTime parseDateTime(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) {
        return DateTime.now();
      }
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        print('Error parsing date: $dateStr, $e');
        return DateTime.now();
      }
    }

    // Handle numeric values safely, converting to appropriate types
    int parseIntSafely(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }
    
    double parseDoubleSafely(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
      return 0.0;
    }

    // Log for debugging
    print('ShiftSale parsing JSON: ${json.toString()}');
    print('totalAmount: ${json['totalAmount']}, litersSold: ${json['litersSold']}');

    try {
      return ShiftSale(
        shiftSaleId: json['shiftSaleId'],
        reportedAt: parseDateTime(json['reportedAt']),
        createdAt: parseDateTime(json['createdAt']),
        updatedAt: parseDateTime(json['updatedAt']),
        employeeName: json['employeeName'] ?? 'Unknown Employee',
        shiftNumber: parseIntSafely(json['shiftNumber']),
        fuelType: json['fuelType'] ?? 'Unknown',
        dispenserNumber: parseIntSafely(json['dispenserNumber']),
        nozzleNumber: parseIntSafely(json['nozzleNumber']),
        totalAmount: parseDoubleSafely(json['totalAmount']),
        litersSold: parseDoubleSafely(json['litersSold']),
        cashAmount: parseDoubleSafely(json['cashAmount']),
        creditCardAmount: parseDoubleSafely(json['creditCardAmount']),
        upiAmount: parseDoubleSafely(json['upiAmount']),
        employeeId: json['employeeId'],
        shiftId: json['shiftId'],
        fuelDispenserId: json['fuelDispenserId'],
        nozzleId: json['nozzleId'],
        fuelTypeSales: fuelTypeSalesMap,
      );
    } catch (e) {
      print('Error creating ShiftSale from JSON: $e');
      print('JSON data: $json');
      
      // Return a default object with minimum valid data to prevent crashes
      return ShiftSale(
        reportedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        employeeName: 'Error',
        shiftNumber: 0,
        fuelType: 'Unknown',
        dispenserNumber: 0,
        totalAmount: 0.0,
        litersSold: 0.0,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'shiftSaleId': shiftSaleId,
      'reportedAt': reportedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'employeeName': employeeName,
      'shiftNumber': shiftNumber,
      'fuelType': fuelType,
      'dispenserNumber': dispenserNumber,
      'nozzleNumber': nozzleNumber,
      'totalAmount': totalAmount,
      'litersSold': litersSold,
      'cashAmount': cashAmount,
      'creditCardAmount': creditCardAmount,
      'upiAmount': upiAmount,
      'employeeId': employeeId,
      'shiftId': shiftId,
      'fuelDispenserId': fuelDispenserId,
      'nozzleId': nozzleId,
      'fuelTypeSales': fuelTypeSales,
    };
  }
} 