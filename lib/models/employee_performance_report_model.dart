import 'dart:convert';

class EmployeePerformanceReport {
  final String employeeId;
  final String employeeName;
  final String role;
  final double totalVolume;
  final double totalValue;
  final int totalTransactions;
  final double averageTransactionValue;
  final double totalHoursWorked;
  final double volumePerHour;
  final double revenuePerHour;
  final List<DailyPerformance> dailyPerformance;
  final List<FuelTypeExpertise> fuelTypeExpertise;
  final EmployeeRanking ranking;
  final String petrolPumpId;
  final String? petrolPumpName;
  final String generatedAt;
  final String generatedBy;
  final String reportPeriodStart;
  final String reportPeriodEnd;

  EmployeePerformanceReport({
    required this.employeeId,
    required this.employeeName,
    required this.role,
    required this.totalVolume,
    required this.totalValue,
    required this.totalTransactions,
    required this.averageTransactionValue,
    required this.totalHoursWorked,
    required this.volumePerHour,
    required this.revenuePerHour,
    required this.dailyPerformance,
    required this.fuelTypeExpertise,
    required this.ranking,
    required this.petrolPumpId,
    this.petrolPumpName,
    required this.generatedAt,
    required this.generatedBy,
    required this.reportPeriodStart,
    required this.reportPeriodEnd,
  });

  factory EmployeePerformanceReport.fromJson(Map<String, dynamic> json) {
    return EmployeePerformanceReport(
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      role: json['role'] ?? '',
      totalVolume: json['totalVolume']?.toDouble() ?? 0.0,
      totalValue: json['totalValue']?.toDouble() ?? 0.0,
      totalTransactions: json['totalTransactions'] ?? 0,
      averageTransactionValue: json['averageTransactionValue']?.toDouble() ?? 0.0,
      totalHoursWorked: json['totalHoursWorked']?.toDouble() ?? 0.0,
      volumePerHour: json['volumePerHour']?.toDouble() ?? 0.0,
      revenuePerHour: json['revenuePerHour']?.toDouble() ?? 0.0,
      dailyPerformance: json['dailyPerformance'] != null
          ? List<DailyPerformance>.from(
              json['dailyPerformance'].map((x) => DailyPerformance.fromJson(x)))
          : [],
      fuelTypeExpertise: json['fuelTypeExpertise'] != null
          ? List<FuelTypeExpertise>.from(
              json['fuelTypeExpertise'].map((x) => FuelTypeExpertise.fromJson(x)))
          : [],
      ranking: EmployeeRanking.fromJson(json['ranking'] ?? {}),
      petrolPumpId: json['petrolPumpId'] ?? '',
      petrolPumpName: json['petrolPumpName'],
      generatedAt: json['generatedAt'] ?? '',
      generatedBy: json['generatedBy'] ?? '',
      reportPeriodStart: json['reportPeriodStart'] ?? '',
      reportPeriodEnd: json['reportPeriodEnd'] ?? '',
    );
  }

  static List<EmployeePerformanceReport> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((json) => EmployeePerformanceReport.fromJson(json)).toList();
  }
}

class DailyPerformance {
  final String date;
  final double volume;
  final double value;
  final int transactionCount;
  final double hoursWorked;
  final double efficiency;

  DailyPerformance({
    required this.date,
    required this.volume,
    required this.value,
    required this.transactionCount,
    required this.hoursWorked,
    required this.efficiency,
  });

  factory DailyPerformance.fromJson(Map<String, dynamic> json) {
    return DailyPerformance(
      date: json['date'] ?? '',
      volume: json['volume']?.toDouble() ?? 0.0,
      value: json['value']?.toDouble() ?? 0.0,
      transactionCount: json['transactionCount'] ?? 0,
      hoursWorked: json['hoursWorked']?.toDouble() ?? 0.0,
      efficiency: json['efficiency']?.toDouble() ?? 0.0,
    );
  }
}

class FuelTypeExpertise {
  final String? fuelTypeId;
  final String? fuelType;
  final double volume;
  final double value;
  final int transactionCount;
  final double averagePrice;
  final double percentageOfTotalVolume;
  final double percentageOfTotalValue;

  FuelTypeExpertise({
    this.fuelTypeId,
    this.fuelType,
    required this.volume,
    required this.value,
    required this.transactionCount,
    required this.averagePrice,
    required this.percentageOfTotalVolume,
    required this.percentageOfTotalValue,
  });

  factory FuelTypeExpertise.fromJson(Map<String, dynamic> json) {
    return FuelTypeExpertise(
      fuelTypeId: json['fuelTypeId'],
      fuelType: json['fuelType'],
      volume: json['volume']?.toDouble() ?? 0.0,
      value: json['value']?.toDouble() ?? 0.0,
      transactionCount: json['transactionCount'] ?? 0,
      averagePrice: json['averagePrice']?.toDouble() ?? 0.0,
      percentageOfTotalVolume: json['percentageOfTotalVolume']?.toDouble() ?? 0.0,
      percentageOfTotalValue: json['percentageOfTotalValue']?.toDouble() ?? 0.0,
    );
  }
}

class EmployeeRanking {
  final int volumeRank;
  final int revenueRank;
  final int efficiencyRank;
  final int overallRank;
  final int totalEmployees;

  EmployeeRanking({
    required this.volumeRank,
    required this.revenueRank,
    required this.efficiencyRank,
    required this.overallRank,
    required this.totalEmployees,
  });

  factory EmployeeRanking.fromJson(Map<String, dynamic> json) {
    return EmployeeRanking(
      volumeRank: json['volumeRank'] ?? 0,
      revenueRank: json['revenueRank'] ?? 0,
      efficiencyRank: json['efficiencyRank'] ?? 0,
      overallRank: json['overallRank'] ?? 0,
      totalEmployees: json['totalEmployees'] ?? 0,
    );
  }
}

class EmployeePerformanceResponse {
  final List<EmployeePerformanceReport> data;
  final bool success;
  final String message;
  final List<String>? validationErrors;

  EmployeePerformanceResponse({
    required this.data,
    required this.success,
    required this.message,
    this.validationErrors,
  });

  factory EmployeePerformanceResponse.fromJson(Map<String, dynamic> json) {
    return EmployeePerformanceResponse(
      data: json['data'] != null
          ? List<EmployeePerformanceReport>.from(
              json['data'].map((x) => EmployeePerformanceReport.fromJson(x)))
          : [],
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      validationErrors: json['validationErrors'] != null
          ? List<String>.from(json['validationErrors'])
          : null,
    );
  }

  factory EmployeePerformanceResponse.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return EmployeePerformanceResponse.fromJson(json);
  }
} 