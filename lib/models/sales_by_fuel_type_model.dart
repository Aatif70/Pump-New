import 'package:flutter/foundation.dart';

class FuelTypeSale {
  final String fuelTypeId;
  final String fuelType;
  final double volume;
  final double value;
  final double percentageOfTotalVolume;
  final double percentageOfTotalValue;
  final double averagePricePerLiter;

  FuelTypeSale({
    required this.fuelTypeId,
    required this.fuelType,
    required this.volume,
    required this.value,
    required this.percentageOfTotalVolume,
    required this.percentageOfTotalValue,
    required this.averagePricePerLiter,
  });

  factory FuelTypeSale.fromJson(Map<String, dynamic> json) {
    return FuelTypeSale(
      fuelTypeId: json['fuelTypeId'] ?? '',
      fuelType: json['fuelType'] ?? '',
      volume: json['volume']?.toDouble() ?? 0.0,
      value: json['value']?.toDouble() ?? 0.0,
      percentageOfTotalVolume: json['percentageOfTotalVolume']?.toDouble() ?? 0.0,
      percentageOfTotalValue: json['percentageOfTotalValue']?.toDouble() ?? 0.0,
      averagePricePerLiter: json['averagePricePerLiter']?.toDouble() ?? 0.0,
    );
  }
}

class SalesByFuelType {
  final String petrolPumpId;
  final DateTime startDate;
  final DateTime endDate;
  final List<FuelTypeSale> fuelTypes;
  final double totalSalesVolume;
  final double totalSalesValue;

  SalesByFuelType({
    required this.petrolPumpId,
    required this.startDate,
    required this.endDate,
    required this.fuelTypes,
    required this.totalSalesVolume,
    required this.totalSalesValue,
  });

  factory SalesByFuelType.fromJson(Map<String, dynamic> json) {
    List<FuelTypeSale> fuelTypesList = [];
    
    if (json['fuelTypes'] != null) {
      fuelTypesList = List<FuelTypeSale>.from(
        (json['fuelTypes'] as List).map(
          (item) => FuelTypeSale.fromJson(item),
        ),
      );
    }

    return SalesByFuelType(
      petrolPumpId: json['petrolPumpId'] ?? '',
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      fuelTypes: fuelTypesList,
      totalSalesVolume: json['totalSalesVolume']?.toDouble() ?? 0.0,
      totalSalesValue: json['totalSalesValue']?.toDouble() ?? 0.0,
    );
  }
} 