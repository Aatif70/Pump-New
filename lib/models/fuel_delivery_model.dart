import 'package:intl/intl.dart';

class FuelDelivery {
  final String? fuelDeliveryId; // Optional for creation
  final String? fuelDeliveryLogId; // The ID used in the API response
  final String? petrolPumpId;
  final DateTime deliveryDate;
  final String fuelTankId;
  final String? fuelTankName;
  final String invoiceNumber;
  final double quantityReceived;
  final String supplierId;
  final String? supplierName;
  final double density;
  final double temperature;
  final String? receivedBy;
  final String? receivedByName;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Additional fields that might be included in responses
  final String? fuelType;
  final double currentTankCapacity;
  final double currentTankLevel;

  FuelDelivery({
    this.fuelDeliveryId,
    this.fuelDeliveryLogId,
    this.petrolPumpId,
    required this.deliveryDate,
    required this.fuelTankId,
    this.fuelTankName,
    required this.invoiceNumber,
    required this.quantityReceived,
    required this.supplierId,
    this.supplierName,
    required this.density,
    required this.temperature,
    this.receivedBy,
    this.receivedByName,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.fuelType,
    this.currentTankCapacity = 0.0,
    this.currentTankLevel = 0.0,
  });

  factory FuelDelivery.fromJson(Map<String, dynamic> json) {
    // Helper function for safe double parsing
    double parseDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return FuelDelivery(
      fuelDeliveryId: json['fuelDeliveryId'] as String?,
      fuelDeliveryLogId: json['fuelDeliveryLogId'] as String?,
      petrolPumpId: json['petrolPumpId'] as String?,
      deliveryDate: json['deliveryDate'] != null
          ? DateTime.tryParse(json['deliveryDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      fuelTankId: json['fuelTankId'] as String? ?? '',
      fuelTankName: json['fuelTankName'] as String?,
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      quantityReceived: parseDouble(json['quantityReceived']),
      supplierId: json['supplierId'] as String? ?? '',
      supplierName: json['supplierName'] as String?,
      density: parseDouble(json['density']),
      temperature: parseDouble(json['temperature']),
      receivedBy: json['receivedBy'] as String?,
      receivedByName: json['receivedByName'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      fuelType: json['fuelType'] as String?,
      currentTankCapacity: parseDouble(json['currentTankCapacity']),
      currentTankLevel: parseDouble(json['currentTankLevel']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deliveryDate': deliveryDate.toIso8601String(),
      'fuelTankId': fuelTankId,
      'invoiceNumber': invoiceNumber,
      'quantityReceived': quantityReceived,
      'supplierId': supplierId,
      'density': density,
      'temperature': temperature,
      'notes': notes,
    };
  }

  // Helper for formatting dates nicely
  String get formattedDeliveryDate => 
      DateFormat('dd MMM yyyy, hh:mm a').format(deliveryDate);
      
  String get formattedCreatedAt => createdAt != null
      ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt!)
      : 'N/A';
      
  String get formattedUpdatedAt => updatedAt != null
      ? DateFormat('dd MMM yyyy, hh:mm a').format(updatedAt!)
      : 'N/A';
}

// New model for Fuel Delivery Order Detail
class FuelDeliveryOrderDetail {
  final String fuelDeliveryOrderDetailId;
  final String fuelDeliveryOrderId;
  final int compartmentNumber;
  final String fuelTankId;
  final String fuelTankName;
  final String fuelType;
  final String fuelTypeId;
  final double quantityInCompartment;
  final double quantityDelivered;
  final double density;
  final double temperature;
  final int deliverySequence;
  final String deliveryStatus;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double tankCapacity;
  final double tankCurrentStock;
  final double tankRemainingCapacity;
  final bool canAcceptQuantity;
  final double remainingQuantity;
  final bool isCompleted;
  final int deliveryPercentage;

  FuelDeliveryOrderDetail({
    required this.fuelDeliveryOrderDetailId,
    required this.fuelDeliveryOrderId,
    required this.compartmentNumber,
    required this.fuelTankId,
    required this.fuelTankName,
    required this.fuelType,
    required this.fuelTypeId,
    required this.quantityInCompartment,
    required this.quantityDelivered,
    required this.density,
    required this.temperature,
    required this.deliverySequence,
    required this.deliveryStatus,
    this.startedAt,
    this.completedAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.tankCapacity,
    required this.tankCurrentStock,
    required this.tankRemainingCapacity,
    required this.canAcceptQuantity,
    required this.remainingQuantity,
    required this.isCompleted,
    required this.deliveryPercentage,
  });

  factory FuelDeliveryOrderDetail.fromJson(Map<String, dynamic> json) {
    // Helper function for safe double parsing
    double parseDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return FuelDeliveryOrderDetail(
      fuelDeliveryOrderDetailId: json['fuelDeliveryOrderDetailId'] as String? ?? '',
      fuelDeliveryOrderId: json['fuelDeliveryOrderId'] as String? ?? '',
      compartmentNumber: json['compartmentNumber'] as int? ?? 0,
      fuelTankId: json['fuelTankId'] as String? ?? '',
      fuelTankName: json['fuelTankName'] as String? ?? '',
      fuelType: json['fuelType'] as String? ?? '',
      fuelTypeId: json['fuelTypeId'] as String? ?? '',
      quantityInCompartment: parseDouble(json['quantityInCompartment']),
      quantityDelivered: parseDouble(json['quantityDelivered']),
      density: parseDouble(json['density']),
      temperature: parseDouble(json['temperature']),
      deliverySequence: json['deliverySequence'] as int? ?? 0,
      deliveryStatus: json['deliveryStatus'] as String? ?? 'Pending',
      startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt'].toString()) : null,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'].toString()) : null,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      tankCapacity: parseDouble(json['tankCapacity']),
      tankCurrentStock: parseDouble(json['tankCurrentStock']),
      tankRemainingCapacity: parseDouble(json['tankRemainingCapacity']),
      canAcceptQuantity: json['canAcceptQuantity'] as bool? ?? false,
      remainingQuantity: parseDouble(json['remainingQuantity']),
      isCompleted: json['isCompleted'] as bool? ?? false,
      deliveryPercentage: json['deliveryPercentage'] as int? ?? 0,
    );
  }

  String get formattedStartedAt => startedAt != null
      ? DateFormat('dd MMM yyyy, hh:mm a').format(startedAt!)
      : 'Not started';
      
  String get formattedCompletedAt => completedAt != null
      ? DateFormat('dd MMM yyyy, hh:mm a').format(completedAt!)
      : 'Not completed';
}

// New model for Fuel Delivery Order
class FuelDeliveryOrder {
  final String fuelDeliveryOrderId;
  final String petrolPumpId;
  final String supplierId;
  final String supplierName;
  final String invoiceNumber;
  final DateTime deliveryDate;
  final String truckNumber;
  final String driverName;
  final String driverContactNumber;
  final int totalCompartments;
  final String deliveryStatus;
  final String? receivedBy;
  final String? receivedByName;
  final String? notes;
  final double totalQuantityDelivered;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<FuelDeliveryOrderDetail> orderDetails;
  final double totalCompartmentQuantity;
  final bool isCompleted;
  final int completedCompartments;
  final int completionPercentage;

  FuelDeliveryOrder({
    required this.fuelDeliveryOrderId,
    required this.petrolPumpId,
    required this.supplierId,
    required this.supplierName,
    required this.invoiceNumber,
    required this.deliveryDate,
    required this.truckNumber,
    required this.driverName,
    required this.driverContactNumber,
    required this.totalCompartments,
    required this.deliveryStatus,
    this.receivedBy,
    this.receivedByName,
    this.notes,
    required this.totalQuantityDelivered,
    required this.createdAt,
    required this.updatedAt,
    required this.orderDetails,
    required this.totalCompartmentQuantity,
    required this.isCompleted,
    required this.completedCompartments,
    required this.completionPercentage,
  });

  factory FuelDeliveryOrder.fromJson(Map<String, dynamic> json) {
    // Helper function for safe double parsing
    double parseDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Parse order details
    List<FuelDeliveryOrderDetail> details = [];
    if (json['orderDetails'] != null && json['orderDetails'] is List) {
      details = (json['orderDetails'] as List)
          .map((item) => FuelDeliveryOrderDetail.fromJson(item))
          .toList();
    }

    return FuelDeliveryOrder(
      fuelDeliveryOrderId: json['fuelDeliveryOrderId'] as String? ?? '',
      petrolPumpId: json['petrolPumpId'] as String? ?? '',
      supplierId: json['supplierId'] as String? ?? '',
      supplierName: json['supplierName'] as String? ?? '',
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      deliveryDate: json['deliveryDate'] != null
          ? DateTime.tryParse(json['deliveryDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      truckNumber: json['truckNumber'] as String? ?? '',
      driverName: json['driverName'] as String? ?? '',
      driverContactNumber: json['driverContactNumber'] as String? ?? '',
      totalCompartments: json['totalCompartments'] as int? ?? 0,
      deliveryStatus: json['deliveryStatus'] as String? ?? 'Pending',
      receivedBy: json['receivedBy'] as String?,
      receivedByName: json['receivedByName'] as String?,
      notes: json['notes'] as String?,
      totalQuantityDelivered: parseDouble(json['totalQuantityDelivered']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      orderDetails: details,
      totalCompartmentQuantity: parseDouble(json['totalCompartmentQuantity']),
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedCompartments: json['completedCompartments'] as int? ?? 0,
      completionPercentage: json['completionPercentage'] as int? ?? 0,
    );
  }

  // Helper for formatting dates nicely
  String get formattedDeliveryDate => 
      DateFormat('dd MMM yyyy, hh:mm a').format(deliveryDate);
      
  String get formattedCreatedAt => 
      DateFormat('dd MMM yyyy, hh:mm a').format(createdAt);
} 