import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class QualityCheck {
  final String? id;
  final String? fuelQualityCheckId;
  final String? petrolPumpId;
  final String? fuelTankId;
  final String tankName;
  final String fuelType;
  final double density;
  final double temperature;
  final double waterContent;
  final double depth;
  final String qualityStatus;
  final String status;
  final String checkedBy;
  final String? checkedByName;
  final DateTime? checkedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? approvedBy;
  final String? approvedByName;
  final bool isApproved;
  final String? notes;

  QualityCheck({
    this.id,
    this.fuelQualityCheckId,
    this.petrolPumpId,
    this.fuelTankId,
    required this.tankName,
    required this.fuelType,
    required this.density,
    required this.temperature,
    required this.waterContent,
    required this.depth,
    required this.qualityStatus,
    this.status = 'Start',
    required this.checkedBy,
    this.checkedByName,
    this.checkedAt,
    this.createdAt,
    this.updatedAt,
    this.approvedBy,
    this.approvedByName,
    this.isApproved = false,
    this.notes,
  });

  factory QualityCheck.fromJson(Map<String, dynamic> json) {
    // Handle if the data is wrapped in a data field
    final dataJson = json.containsKey('data') ? json['data'] : json;
    
    return QualityCheck(
      id: dataJson['id'] ?? dataJson['fuelQualityCheckId'],
      fuelQualityCheckId: dataJson['fuelQualityCheckId'],
      petrolPumpId: dataJson['petrolPumpId'],
      fuelTankId: dataJson['fuelTankId'],
      tankName: dataJson['fuelTankName'] ?? dataJson['tankName'] ?? 'Unknown Tank',
      fuelType: dataJson['fuelType'] ?? 'Unknown',
      density: (dataJson['density'] is num) ? (dataJson['density'] as num).toDouble() : 0.0,
      temperature: (dataJson['temperature'] is num) ? (dataJson['temperature'] as num).toDouble() : 0.0,
      waterContent: (dataJson['waterContent'] is num) ? (dataJson['waterContent'] as num).toDouble() : 0.0,
      depth: (dataJson['depth'] is num) ? (dataJson['depth'] as num).toDouble() : 0.0,
      qualityStatus: dataJson['qualityStatus'] ?? 'Unknown',
      status: dataJson['status'] ?? 'Start',
      checkedBy: dataJson['checkedBy'] ?? 'Unknown',
      checkedByName: dataJson['checkedByName'],
      checkedAt: dataJson['checkedAt'] != null 
          ? DateTime.parse(dataJson['checkedAt']) 
          : null,
      createdAt: dataJson['createdAt'] != null 
          ? DateTime.parse(dataJson['createdAt']) 
          : null,
      updatedAt: dataJson['updatedAt'] != null 
          ? DateTime.parse(dataJson['updatedAt']) 
          : null,
      approvedBy: dataJson['approvedBy'],
      approvedByName: dataJson['approvedByName'],
      isApproved: dataJson['isApproved'] ?? false,
      notes: dataJson['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fuelQualityCheckId': fuelQualityCheckId,
      'petrolPumpId': petrolPumpId,
      'fuelTankId': fuelTankId,
      'fuelTankName': tankName,
      'fuelType': fuelType,
      'density': density,
      'temperature': temperature,
      'waterContent': waterContent,
      'depth': depth,
      'qualityStatus': qualityStatus,
      'status': status,
      'checkedBy': checkedBy,
      'checkedByName': checkedByName,
      'checkedAt': checkedAt?.toIso8601String(),
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'isApproved': isApproved,
      'notes': notes,
    };
  }

  // Get formatted date
  String get formattedCheckedDate {
    if (checkedAt == null) return 'Not recorded';
    return DateFormat('dd/MM/yyyy').format(checkedAt!);
  }

  // Get formatted date and time
  String get formattedCheckedAt {
    if (checkedAt == null) return 'Not recorded';
    return DateFormat('dd/MM/yyyy HH:mm').format(checkedAt!);
  }

  // Get quality status icon
  IconData getQualityStatusIcon() {
    switch (qualityStatus.toLowerCase()) {
      case 'excellent':
        return Icons.verified;
      case 'good':
        return Icons.check_circle;
      case 'average':
        return Icons.thumbs_up_down;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'poor':
        return Icons.error;
      case 'critical':
        return Icons.dangerous;
      default:
        return Icons.help_outline;
    }
  }

  // Get quality status color
  Color getQualityStatusColor() {
    switch (qualityStatus.toLowerCase()) {
      case 'excellent':
        return Colors.green.shade700;
      case 'good':
        return Colors.lightGreen.shade700;
      case 'average':
        return Colors.amber.shade700;
      case 'warning':
        return Colors.orange;
      case 'poor':
        return Colors.orange.shade700;
      case 'critical':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
} 