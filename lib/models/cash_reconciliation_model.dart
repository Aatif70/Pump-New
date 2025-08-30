class CashReconciliationResponse {
  final CashReconciliationData data;
  final bool success;
  final String message;
  final List<String>? validationErrors;

  CashReconciliationResponse({
    required this.data,
    required this.success,
    required this.message,
    this.validationErrors,
  });

  factory CashReconciliationResponse.fromJson(Map<String, dynamic> json) {
    return CashReconciliationResponse(
      data: CashReconciliationData.fromJson(json['data']),
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      validationErrors: json['validationErrors'] != null
          ? List<String>.from(json['validationErrors'])
          : null,
    );
  }
}

class CashReconciliationData {
  final DateTime reconciliationDate;
  final List<ShiftReconciliation> shiftReconciliations;
  final DailySummary dailySummary;
  final List<dynamic> variances;
  final String petrolPumpId;
  final String petrolPumpName;
  final DateTime generatedAt;
  final String generatedBy;
  final DateTime reportPeriodStart;
  final DateTime reportPeriodEnd;

  CashReconciliationData({
    required this.reconciliationDate,
    required this.shiftReconciliations,
    required this.dailySummary,
    required this.variances,
    required this.petrolPumpId,
    required this.petrolPumpName,
    required this.generatedAt,
    required this.generatedBy,
    required this.reportPeriodStart,
    required this.reportPeriodEnd,
  });

  factory CashReconciliationData.fromJson(Map<String, dynamic> json) {
    return CashReconciliationData(
      reconciliationDate: DateTime.parse(json['reconciliationDate']),
      shiftReconciliations: (json['shiftReconciliations'] as List)
          .map((item) => ShiftReconciliation.fromJson(item))
          .toList(),
      dailySummary: DailySummary.fromJson(json['dailySummary']),
      variances: json['variances'] ?? [],
      petrolPumpId: json['petrolPumpId'] ?? '',
      petrolPumpName: json['petrolPumpName'] ?? '',
      generatedAt: DateTime.parse(json['generatedAt']),
      generatedBy: json['generatedBy'] ?? '',
      reportPeriodStart: DateTime.parse(json['reportPeriodStart']),
      reportPeriodEnd: DateTime.parse(json['reportPeriodEnd']),
    );
  }
}

class ShiftReconciliation {
  final String shiftId;
  final int shiftNumber;
  final String startTime;
  final String endTime;
  final double openingCash;
  final double cashSales;
  final double cashExpenses;
  final double expectedClosingCash;
  final double actualClosingCash;
  final double cashVariance;
  final double cashDeposited;
  final String cashierName;
  final Map<String, dynamic> denominationCount;
  final String reconciliationStatus;
  final String remarks;

  ShiftReconciliation({
    required this.shiftId,
    required this.shiftNumber,
    required this.startTime,
    required this.endTime,
    required this.openingCash,
    required this.cashSales,
    required this.cashExpenses,
    required this.expectedClosingCash,
    required this.actualClosingCash,
    required this.cashVariance,
    required this.cashDeposited,
    required this.cashierName,
    required this.denominationCount,
    required this.reconciliationStatus,
    required this.remarks,
  });

  factory ShiftReconciliation.fromJson(Map<String, dynamic> json) {
    return ShiftReconciliation(
      shiftId: json['shiftId'] ?? '',
      shiftNumber: json['shiftNumber'] ?? 0,
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      openingCash: json['openingCash']?.toDouble() ?? 0.0,
      cashSales: json['cashSales']?.toDouble() ?? 0.0,
      cashExpenses: json['cashExpenses']?.toDouble() ?? 0.0,
      expectedClosingCash: json['expectedClosingCash']?.toDouble() ?? 0.0,
      actualClosingCash: json['actualClosingCash']?.toDouble() ?? 0.0,
      cashVariance: json['cashVariance']?.toDouble() ?? 0.0,
      cashDeposited: json['cashDeposited']?.toDouble() ?? 0.0,
      cashierName: json['cashierName'] ?? '',
      denominationCount: json['denominationCount'] ?? {},
      reconciliationStatus: json['reconciliationStatus'] ?? '',
      remarks: json['remarks'] ?? '',
    );
  }
}

class DailySummary {
  final double totalOpeningCash;
  final double totalCashSales;
  final double totalCashExpenses;
  final double totalExpectedCash;
  final double totalActualCash;
  final double totalCashVariance;
  final double totalCashDeposited;
  final double accuracyPercentage;
  final int shiftsWithVariance;
  final int totalShifts;

  DailySummary({
    required this.totalOpeningCash,
    required this.totalCashSales,
    required this.totalCashExpenses,
    required this.totalExpectedCash,
    required this.totalActualCash,
    required this.totalCashVariance,
    required this.totalCashDeposited,
    required this.accuracyPercentage,
    required this.shiftsWithVariance,
    required this.totalShifts,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    // Debug print to see what's coming in
    print("DAILY SUMMARY JSON: $json");
    
    return DailySummary(
      totalOpeningCash: _parseDouble(json['totalOpeningCash']),
      totalCashSales: _parseDouble(json['totalCashSales']),
      totalCashExpenses: _parseDouble(json['totalCashExpenses']),
      totalExpectedCash: _parseDouble(json['totalExpectedCash']),
      totalActualCash: _parseDouble(json['totalActualCash']),
      totalCashVariance: _parseDouble(json['totalCashVariance']),
      totalCashDeposited: _parseDouble(json['totalCashDeposited']),
      accuracyPercentage: _parseDouble(json['accuracyPercentage']),
      shiftsWithVariance: json['shiftsWithVariance'] ?? 0,
      totalShifts: json['totalShifts'] ?? 0,
    );
  }
}

// Helper function to parse doubles safely
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is String) {
    try {
      return double.parse(value);
    } catch (_) {
      return 0.0;
    }
  }
  return 0.0;
}

class Shift {
  final String id;
  final int shiftNumber;
  final String startTime;
  final String endTime;
  final String petrolPumpId;
  
  Shift({
    required this.id,
    required this.shiftNumber,
    required this.startTime,
    required this.endTime,
    required this.petrolPumpId,
  });
  
  factory Shift.fromJson(Map<String, dynamic> json) {
    // Print the incoming JSON for debugging
    print('Shift.fromJson received: $json');
    
    // Check for both 'id' and 'shiftId' fields
    String shiftId = '';
    if (json.containsKey('id') && json['id'] != null) {
      shiftId = json['id'].toString();
    } else if (json.containsKey('shiftId') && json['shiftId'] != null) {
      shiftId = json['shiftId'].toString();
    }
    
    return Shift(
      id: shiftId,
      shiftNumber: json['shiftNumber'] ?? 0,
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      petrolPumpId: json['petrolPumpId'] ?? '',
    );
  }
} 