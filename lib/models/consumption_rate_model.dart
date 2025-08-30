import 'package:intl/intl.dart';

class ConsumptionRate {
  final String fuelTypeId;
  final String fuelType;
  final double averageDailyConsumption;
  final double weekdayAverage;
  final double weekendAverage;
  final double peakDayConsumption;
  final String peakDay;
  final DateTime peakDate;

  ConsumptionRate({
    required this.fuelTypeId,
    required this.fuelType,
    required this.averageDailyConsumption,
    required this.weekdayAverage,
    required this.weekendAverage,
    required this.peakDayConsumption,
    required this.peakDay,
    required this.peakDate,
  });

  factory ConsumptionRate.fromJson(Map<String, dynamic> json) {
    return ConsumptionRate(
      fuelTypeId: json['fuelTypeId'] ?? '',
      fuelType: json['fuelType'] ?? 'Unknown',
      averageDailyConsumption: json['averageDailyConsumption']?.toDouble() ?? 0.0,
      weekdayAverage: json['weekdayAverage']?.toDouble() ?? 0.0,
      weekendAverage: json['weekendAverage']?.toDouble() ?? 0.0,
      peakDayConsumption: json['peakDayConsumption']?.toDouble() ?? 0.0,
      peakDay: json['peakDay'] ?? '',
      peakDate: json['peakDate'] != null 
        ? DateTime.parse(json['peakDate']) 
        : DateTime.now(),
    );
  }

  // Format peak date for display
  String get formattedPeakDate => DateFormat('dd MMM, yyyy').format(peakDate);
} 