import 'package:intl/intl.dart';

class ShiftSalesReportResponse {
  final List<ShiftSalesReport> data;
  final bool success;
  final String message;
  final dynamic validationErrors;

  ShiftSalesReportResponse({
    required this.data,
    required this.success,
    required this.message,
    this.validationErrors,
  });

  factory ShiftSalesReportResponse.fromJson(Map<String, dynamic> json) {
    return ShiftSalesReportResponse(
      data: (json['data'] as List)
          .map((e) => ShiftSalesReport.fromJson(e as Map<String, dynamic>))
          .toList(),
      success: json['success'],
      message: json['message'],
      validationErrors: json['validationErrors'],
    );
  }
}

class ShiftSalesReport {
  final List<ShiftPerformance> shiftPerformances;
  final ShiftComparison shiftComparison;
  final String petrolPumpId;
  final String petrolPumpName;
  final DateTime generatedAt;
  final String generatedBy;
  final DateTime reportPeriodStart;
  final DateTime reportPeriodEnd;

  ShiftSalesReport({
    required this.shiftPerformances,
    required this.shiftComparison,
    required this.petrolPumpId,
    required this.petrolPumpName,
    required this.generatedAt,
    required this.generatedBy,
    required this.reportPeriodStart,
    required this.reportPeriodEnd,
  });

  factory ShiftSalesReport.fromJson(Map<String, dynamic> json) {
    return ShiftSalesReport(
      shiftPerformances: (json['shiftPerformances'] as List)
          .map((e) => ShiftPerformance.fromJson(e as Map<String, dynamic>))
          .toList(),
      shiftComparison: ShiftComparison.fromJson(json['shiftComparison'] as Map<String, dynamic>),
      petrolPumpId: json['petrolPumpId'],
      petrolPumpName: json['petrolPumpName'],
      generatedAt: DateTime.parse(json['generatedAt']),
      generatedBy: json['generatedBy'],
      reportPeriodStart: DateTime.parse(json['reportPeriodStart']),
      reportPeriodEnd: DateTime.parse(json['reportPeriodEnd']),
    );
  }
}

class ShiftPerformance {
  final DateTime date;
  final int shiftNumber;
  final String startTime;
  final String endTime;
  final double totalVolume;
  final double totalValue;
  final int transactionCount;
  final int employeeCount;
  final double averageTransactionValue;
  final double volumePerHour;
  final List<FuelTypeBreakdown> fuelTypeBreakdown;

  ShiftPerformance({
    required this.date,
    required this.shiftNumber,
    required this.startTime,
    required this.endTime,
    required this.totalVolume,
    required this.totalValue,
    required this.transactionCount,
    required this.employeeCount,
    required this.averageTransactionValue,
    required this.volumePerHour,
    required this.fuelTypeBreakdown,
  });

  String get formattedDate => DateFormat('dd MMM yyyy').format(date);

  factory ShiftPerformance.fromJson(Map<String, dynamic> json) {
    return ShiftPerformance(
      date: DateTime.parse(json['date']),
      shiftNumber: json['shiftNumber'],
      startTime: json['startTime'],
      endTime: json['endTime'],
      totalVolume: json['totalVolume'].toDouble(),
      totalValue: json['totalValue'].toDouble(),
      transactionCount: json['transactionCount'],
      employeeCount: json['employeeCount'],
      averageTransactionValue: json['averageTransactionValue'].toDouble(),
      volumePerHour: json['volumePerHour'].toDouble(),
      fuelTypeBreakdown: (json['fuelTypeBreakdown'] as List)
          .map((e) => FuelTypeBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FuelTypeBreakdown {
  final String? fuelTypeId;
  final String? fuelType;
  final double volume;
  final double value;
  final int transactionCount;
  final double averagePrice;
  final double percentageOfTotalVolume;
  final double percentageOfTotalValue;

  FuelTypeBreakdown({
    this.fuelTypeId,
    this.fuelType,
    required this.volume,
    required this.value,
    required this.transactionCount,
    required this.averagePrice,
    required this.percentageOfTotalVolume,
    required this.percentageOfTotalValue,
  });

  factory FuelTypeBreakdown.fromJson(Map<String, dynamic> json) {
    return FuelTypeBreakdown(
      fuelTypeId: json['fuelTypeId'],
      fuelType: json['fuelType'],
      volume: json['volume'].toDouble(),
      value: json['value'].toDouble(),
      transactionCount: json['transactionCount'],
      averagePrice: json['averagePrice'].toDouble(),
      percentageOfTotalVolume: json['percentageOfTotalVolume'].toDouble(),
      percentageOfTotalValue: json['percentageOfTotalValue'].toDouble(),
    );
  }
}

class ShiftComparison {
  final String bestPerformingShift;
  final double bestShiftVolume;
  final String worstPerformingShift;
  final double worstShiftVolume;
  final double averageShiftVolume;
  final double shiftVolumeVariance;

  ShiftComparison({
    required this.bestPerformingShift,
    required this.bestShiftVolume,
    required this.worstPerformingShift,
    required this.worstShiftVolume,
    required this.averageShiftVolume,
    required this.shiftVolumeVariance,
  });

  factory ShiftComparison.fromJson(Map<String, dynamic> json) {
    return ShiftComparison(
      bestPerformingShift: json['bestPerformingShift'],
      bestShiftVolume: json['bestShiftVolume'].toDouble(),
      worstPerformingShift: json['worstPerformingShift'],
      worstShiftVolume: json['worstShiftVolume'].toDouble(),
      averageShiftVolume: json['averageShiftVolume'].toDouble(),
      shiftVolumeVariance: json['shiftVolumeVariance'].toDouble(),
    );
  }
} 