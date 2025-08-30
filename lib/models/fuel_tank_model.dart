import 'package:intl/intl.dart'; // For date formatting if needed later

class FuelTank {
  final String? fuelTankId; // Made optional for creation
  final String petrolPumpId;
  final String fuelType;
  final double capacityInLiters;
  final double currentStock;
  final DateTime? lastRefilledAt;
  final DateTime? createdAt; // Made optional for creation
  final DateTime? updatedAt; // Made optional for creation
  final String status;
  final double stockPercentage; // Made optional but with default calculation
  final bool isLowStock; // Made optional with default
  final double remainingCapacity; // Made optional but with default calculation
  final String? fuelTypeId; // ID of the related fuel type

  FuelTank({
    this.fuelTankId,
    required this.petrolPumpId,
    required this.fuelType,
    required this.capacityInLiters,
    required this.currentStock,
    this.lastRefilledAt,
    this.createdAt,
    this.updatedAt,
    required this.status,
    double? stockPercentage, // Optional with default calculation
    bool? isLowStock, // Optional with default
    double? remainingCapacity, // Optional with default calculation
    this.fuelTypeId, // Optional fuel type ID
  }) : 
    // Calculate these values if not provided
    stockPercentage = stockPercentage ?? (capacityInLiters > 0 ? (currentStock / capacityInLiters * 100) : 0),

  // If the stock of fuel is less than 20% percent, make it LOW STOCK
    isLowStock = isLowStock ?? (capacityInLiters > 0 ? (currentStock / capacityInLiters * 100) < 20 : false),

    remainingCapacity = remainingCapacity ?? (capacityInLiters - currentStock);

  factory FuelTank.fromJson(Map<String, dynamic> json) {
    // Helper function for safe double parsing
    double parseDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    final capacityInLiters = parseDouble(json['capacityInLiters']);
    final currentStock = parseDouble(json['currentStock']);
    
    // Calculate derived values if not present in the JSON
    final stockPercentage = json['stockPercentage'] != null
        ? parseDouble(json['stockPercentage']) 
        : (capacityInLiters > 0.00 ? (currentStock / capacityInLiters * 100) : 0.00);
        
    final isLowStock = json['isLowStock'] != null 
        ? json['isLowStock'] as bool? ?? false 
        : stockPercentage < 20;
        
    final remainingCapacity = json['remainingCapacity'] != null 
        ? parseDouble(json['remainingCapacity']) 
        : capacityInLiters - currentStock;

    return FuelTank(
      fuelTankId: json['fuelTankId'] as String?,
      petrolPumpId: json['petrolPumpId'] as String? ?? '',
      fuelType: json['fuelType'] as String? ?? 'Unknown',
      capacityInLiters: capacityInLiters,
      currentStock: currentStock,
      lastRefilledAt: json['lastRefilledAt'] != null && json['lastRefilledAt'].toString().isNotEmpty
          ? DateTime.tryParse(json['lastRefilledAt'].toString())
          : null,
      createdAt: json['createdAt'] != null && json['createdAt'].toString().isNotEmpty
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null && json['updatedAt'].toString().isNotEmpty
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      status: json['status'] as String? ?? 'Inactive',
      stockPercentage: stockPercentage,
      isLowStock: isLowStock,
      remainingCapacity: remainingCapacity,
      fuelTypeId: json['fuelTypeId'] as String?,
    );
  }

  // toJson is used for sending data (e.g., adding a tank)
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      // Only include fields needed for creation/update
      'petrolPumpId': petrolPumpId,
      'fuelType': fuelType,
      'capacityInLiters': capacityInLiters,
      'currentStock': currentStock,
      'status': status,
    };
    
    // Add fuelTypeId if it exists
    if (fuelTypeId != null && fuelTypeId!.isNotEmpty) {
      data['fuelTypeId'] = fuelTypeId;
    }
    
    return data;
  }

  // Helper for formatting dates nicely
  String get formattedLastRefilled => lastRefilledAt != null
      ? DateFormat('dd MMM yyyy, hh:mm a').format(lastRefilledAt!)
      : 'Never';

  String get formattedCreatedAt => createdAt != null
      ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt!)
      : 'N/A';
      
  String get formattedUpdatedAt => updatedAt != null
      ? DateFormat('dd MMM yyyy, hh:mm a').format(updatedAt!)
      : 'N/A';
} 