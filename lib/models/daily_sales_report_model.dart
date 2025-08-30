class DailySalesReport {
  final String reportDate;
  final double totalSalesVolume;
  final double totalSalesValue;
  final int totalTransactions;
  final double averageTransactionValue;
  final List<FuelTypeSale> fuelTypeSales;
  final List<ShiftSummary> shiftSummaries;
  final List<HourlySale> hourlySales;
  final PaymentBreakdown paymentBreakdown;
  final List<EmployeeSale> employeeSales;
  final List<NozzleSale> nozzleSales;
  final String petrolPumpId;
  final String petrolPumpName;
  final String generatedAt;
  final String generatedBy;
  final String reportPeriodStart;
  final String reportPeriodEnd;

  DailySalesReport({
    required this.reportDate,
    required this.totalSalesVolume,
    required this.totalSalesValue,
    required this.totalTransactions,
    required this.averageTransactionValue,
    required this.fuelTypeSales,
    required this.shiftSummaries,
    required this.hourlySales,
    required this.paymentBreakdown,
    required this.employeeSales,
    required this.nozzleSales,
    required this.petrolPumpId,
    required this.petrolPumpName,
    required this.generatedAt,
    required this.generatedBy,
    required this.reportPeriodStart,
    required this.reportPeriodEnd,
  });

  factory DailySalesReport.fromJson(Map<String, dynamic> json) {
    return DailySalesReport(
      reportDate: json['reportDate'] ?? '',
      totalSalesVolume: (json['totalSalesVolume'] ?? 0).toDouble(),
      totalSalesValue: (json['totalSalesValue'] ?? 0).toDouble(),
      totalTransactions: json['totalTransactions'] ?? 0,
      averageTransactionValue: (json['averageTransactionValue'] ?? 0).toDouble(),
      fuelTypeSales: json['fuelTypeSales'] != null
          ? List<FuelTypeSale>.from(
              json['fuelTypeSales'].map((x) => FuelTypeSale.fromJson(x)))
          : [],
      shiftSummaries: json['shiftSummaries'] != null
          ? List<ShiftSummary>.from(
              json['shiftSummaries'].map((x) => ShiftSummary.fromJson(x)))
          : [],
      hourlySales: json['hourlySales'] != null
          ? List<HourlySale>.from(
              json['hourlySales'].map((x) => HourlySale.fromJson(x)))
          : [],
      paymentBreakdown: json['paymentBreakdown'] != null
          ? PaymentBreakdown.fromJson(json['paymentBreakdown'])
          : PaymentBreakdown.empty(),
      employeeSales: json['employeeSales'] != null
          ? List<EmployeeSale>.from(
              json['employeeSales'].map((x) => EmployeeSale.fromJson(x)))
          : [],
      nozzleSales: json['nozzleSales'] != null
          ? List<NozzleSale>.from(
              json['nozzleSales'].map((x) => NozzleSale.fromJson(x)))
          : [],
      petrolPumpId: json['petrolPumpId'] ?? '',
      petrolPumpName: json['petrolPumpName'] ?? '',
      generatedAt: json['generatedAt'] ?? '',
      generatedBy: json['generatedBy'] ?? '',
      reportPeriodStart: json['reportPeriodStart'] ?? '',
      reportPeriodEnd: json['reportPeriodEnd'] ?? '',
    );
  }
}

class FuelTypeSale {
  final String fuelTypeId;
  final String fuelTypeName;
  final double volume;
  final double value;
  final double percentage;

  FuelTypeSale({
    required this.fuelTypeId,
    required this.fuelTypeName,
    required this.volume,
    required this.value,
    required this.percentage,
  });

  factory FuelTypeSale.fromJson(Map<String, dynamic> json) {
    return FuelTypeSale(
      fuelTypeId: json['fuelTypeId'] ?? '',
      fuelTypeName: json['fuelTypeName'] ?? '',
      volume: (json['volume'] ?? 0).toDouble(),
      value: (json['value'] ?? 0).toDouble(),
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}

class ShiftSummary {
  final String shiftId;
  final int shiftNumber;
  final String startTime;
  final String endTime;
  final double volume;
  final double value;
  final int transactionCount;

  ShiftSummary({
    required this.shiftId,
    required this.shiftNumber,
    required this.startTime,
    required this.endTime,
    required this.volume,
    required this.value,
    required this.transactionCount,
  });

  factory ShiftSummary.fromJson(Map<String, dynamic> json) {
    return ShiftSummary(
      shiftId: json['shiftId'] ?? '',
      shiftNumber: json['shiftNumber'] ?? 0,
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      volume: (json['volume'] ?? 0).toDouble(),
      value: (json['value'] ?? 0).toDouble(),
      transactionCount: json['transactionCount'] ?? 0,
    );
  }
}

class HourlySale {
  final int hour;
  final double volume;
  final double value;
  final int transactionCount;

  HourlySale({
    required this.hour,
    required this.volume,
    required this.value,
    required this.transactionCount,
  });

  factory HourlySale.fromJson(Map<String, dynamic> json) {
    return HourlySale(
      hour: json['hour'] ?? 0,
      volume: (json['volume'] ?? 0).toDouble(),
      value: (json['value'] ?? 0).toDouble(),
      transactionCount: json['transactionCount'] ?? 0,
    );
  }
}

class PaymentBreakdown {
  final double cashAmount;
  final double creditCardAmount;
  final double upiAmount;
  final double cashPercentage;
  final double creditCardPercentage;
  final double upiPercentage;
  final int cashTransactions;
  final int creditCardTransactions;
  final int upiTransactions;

  PaymentBreakdown({
    required this.cashAmount,
    required this.creditCardAmount,
    required this.upiAmount,
    required this.cashPercentage,
    required this.creditCardPercentage,
    required this.upiPercentage,
    required this.cashTransactions,
    required this.creditCardTransactions,
    required this.upiTransactions,
  });

  factory PaymentBreakdown.fromJson(Map<String, dynamic> json) {
    return PaymentBreakdown(
      cashAmount: (json['cashAmount'] ?? 0).toDouble(),
      creditCardAmount: (json['creditCardAmount'] ?? 0).toDouble(),
      upiAmount: (json['upiAmount'] ?? 0).toDouble(),
      cashPercentage: (json['cashPercentage'] ?? 0).toDouble(),
      creditCardPercentage: (json['creditCardPercentage'] ?? 0).toDouble(),
      upiPercentage: (json['upiPercentage'] ?? 0).toDouble(),
      cashTransactions: json['cashTransactions'] ?? 0,
      creditCardTransactions: json['creditCardTransactions'] ?? 0,
      upiTransactions: json['upiTransactions'] ?? 0,
    );
  }

  factory PaymentBreakdown.empty() {
    return PaymentBreakdown(
      cashAmount: 0,
      creditCardAmount: 0,
      upiAmount: 0,
      cashPercentage: 0,
      creditCardPercentage: 0,
      upiPercentage: 0,
      cashTransactions: 0,
      creditCardTransactions: 0,
      upiTransactions: 0,
    );
  }
}

class EmployeeSale {
  final String employeeId;
  final String employeeName;
  final double volume;
  final double value;
  final int transactionCount;
  final double percentage;

  EmployeeSale({
    required this.employeeId,
    required this.employeeName,
    required this.volume,
    required this.value,
    required this.transactionCount,
    required this.percentage,
  });

  factory EmployeeSale.fromJson(Map<String, dynamic> json) {
    return EmployeeSale(
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      volume: (json['volume'] ?? 0).toDouble(),
      value: (json['value'] ?? 0).toDouble(),
      transactionCount: json['transactionCount'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}

class NozzleSale {
  final String nozzleId;
  final String nozzleName;
  final String dispenserId;
  final String dispenserName;
  final double volume;
  final double value;
  final int transactionCount;
  final double percentage;

  NozzleSale({
    required this.nozzleId,
    required this.nozzleName,
    required this.dispenserId,
    required this.dispenserName,
    required this.volume,
    required this.value,
    required this.transactionCount,
    required this.percentage,
  });

  factory NozzleSale.fromJson(Map<String, dynamic> json) {
    return NozzleSale(
      nozzleId: json['nozzleId'] ?? '',
      nozzleName: json['nozzleName'] ?? '',
      dispenserId: json['dispenserId'] ?? '',
      dispenserName: json['dispenserName'] ?? '',
      volume: (json['volume'] ?? 0).toDouble(),
      value: (json['value'] ?? 0).toDouble(),
      transactionCount: json['transactionCount'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
} 