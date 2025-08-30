import 'package:flutter/foundation.dart';

class InventoryStatus {
  final String fuelInventoryId;
  final String fuelTankId;
  final String tankName;
  final String fuelType;
  final double currentStock;
  final double capacityInLiters;
  final double stockPercentage;
  final DateTime lastUpdatedAt;
  final DateTime lastDeliveryDate;
  final double deadStock;
  final double availableStock;

  InventoryStatus({
    required this.fuelInventoryId,
    required this.fuelTankId,
    required this.tankName, 
    required this.fuelType,
    required this.currentStock,
    required this.capacityInLiters,
    required this.stockPercentage,
    required this.lastUpdatedAt,
    required this.lastDeliveryDate,
    required this.deadStock,
    required this.availableStock,
  });

  factory InventoryStatus.fromJson(Map<String, dynamic> json) {
    return InventoryStatus(
      fuelInventoryId: json['fuelInventoryId'] ?? '',
      fuelTankId: json['fuelTankId'] ?? '',
      tankName: json['tankName'] ?? '',
      fuelType: json['fuelType'] ?? '',
      currentStock: json['currentStock']?.toDouble() ?? 0.0,
      capacityInLiters: json['capacityInLiters']?.toDouble() ?? 0.0,
      stockPercentage: json['stockPercentage']?.toDouble() ?? 0.0,
      lastUpdatedAt: DateTime.parse(json['lastUpdatedAt']),
      lastDeliveryDate: DateTime.parse(json['lastDeliveryDate']),
      deadStock: json['deadStock']?.toDouble() ?? 0.0,
      availableStock: json['availableStock']?.toDouble() ?? 0.0,
    );
  }

  // Calculate how low the stock is
  String get stockStatus {
    if (stockPercentage <= 15) {
      return 'Critical';
    } else if (stockPercentage <= 30) {
      return 'Low';
    } else if (stockPercentage <= 50) {
      return 'Medium';
    } else {
      return 'Good';
    }
  }

  // Get color for the stock status
  int get stockStatusColor {
    if (stockPercentage <= 15) {
      return 0xFFFF3B30; // Red
    } else if (stockPercentage <= 30) {
      return 0xFFFF9500; // Orange
    } else if (stockPercentage <= 50) {
      return 0xFFFFCC00; // Yellow
    } else {
      return 0xFF34C759; // Green
    }
  }
} 