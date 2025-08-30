import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FuelQualityCheck {
  final String? fuelQualityCheckId;
  final String? fuelTankId;
  final String fuelType;
  final String? fuelTankName;
  final String? petrolPumpId;
  final double density;
  final double temperature;
  final double waterContent;
  final double depth;
  final String qualityStatus;
  final String checkedBy;
  final DateTime? checkedAt;
  final String checkedByName;
  final String? approvedBy;
  final String? approvedByName;
  final String? status;
  final bool isApproved;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  FuelQualityCheck({
    this.fuelQualityCheckId,
    this.fuelTankId,
    required this.fuelType,
    this.fuelTankName,
    this.petrolPumpId,
    required this.density,
    required this.temperature,
    required this.waterContent,
    required this.depth,
    required this.qualityStatus,
    required this.checkedBy,
    required this.checkedByName,
    this.checkedAt,
    this.approvedBy,
    this.approvedByName,
    this.status,
    this.isApproved = false,
    this.createdAt,
    this.updatedAt,
  });
  
  factory FuelQualityCheck.fromJson(Map<String, dynamic> json) {
    return FuelQualityCheck(
      fuelQualityCheckId: json['fuelQualityCheckId'],
      fuelTankId: json['fuelTankId'],
      fuelType: json['fuelType'] ?? 'Unknown',
      fuelTankName: json['fuelTankName'],
      petrolPumpId: json['petrolPumpId'],
      density: (json['density'] is num) ? (json['density'] as num).toDouble() : 0.0,
      temperature: (json['temperature'] is num) ? (json['temperature'] as num).toDouble() : 0.0,
      waterContent: (json['waterContent'] is num) ? (json['waterContent'] as num).toDouble() : 0.0,
      depth: (json['depth'] is num) ? (json['depth'] as num).toDouble() : 0.0,
      qualityStatus: json['qualityStatus'] ?? 'Unknown',
      checkedBy: json['checkedBy'] ?? 'Unknown',
      checkedByName: json['checkedByName'] ?? 'Unknown',
      checkedAt: json['checkedAt'] != null ? DateTime.parse(json['checkedAt']) : null,
      approvedBy: json['approvedBy'],
      approvedByName: json['approvedByName'],
      status: json['status'],
      isApproved: json['isApproved'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'fuelQualityCheckId': fuelQualityCheckId,
      'fuelTankId': fuelTankId,
      'fuelType': fuelType,
      'fuelTankName': fuelTankName,
      'petrolPumpId': petrolPumpId,
      'density': density,
      'temperature': temperature,
      'waterContent': waterContent,
      'depth': depth,
      'qualityStatus': qualityStatus,
      'checkedBy': checkedBy,
      'checkedByName': checkedByName,
      'checkedAt': checkedAt?.toIso8601String(),
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'status': status,
      'isApproved': isApproved,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
  
  String get formattedCheckedAt {
    if (checkedAt == null) return 'Not checked';
    return DateFormat('dd MMM yyyy, HH:mm').format(checkedAt!);
  }
  
  String get formattedCheckedDate {
    if (checkedAt == null) return 'N/A';
    return DateFormat('dd MMM yyyy').format(checkedAt!);
  }
  
  String get formattedCheckedTime {
    if (checkedAt == null) return '';
    return DateFormat('HH:mm').format(checkedAt!);
  }


  
  Color getQualityStatusColor() {
    switch(qualityStatus.toLowerCase()) {
      case 'excellent':
        return Colors.green.shade700;
      case 'good':
        return Colors.lightGreen.shade700;
      case 'average':
        return Colors.amber.shade700;
      case 'poor':
        return Colors.orange.shade700;
      case 'critical':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
  
  IconData getQualityStatusIcon() {
    switch(qualityStatus.toLowerCase()) {
      case 'excellent':
        return Icons.verified;
      case 'good':
        return Icons.thumb_up;
      case 'average':
        return Icons.thumbs_up_down;
      case 'poor':
        return Icons.thumb_down;
      case 'critical':
        return Icons.dangerous;
      default:
        return Icons.question_mark;
    }
  }
} 