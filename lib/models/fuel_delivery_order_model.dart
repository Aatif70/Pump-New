class CompartmentDetail {
  int compartmentNumber;
  String fuelTankId;
  double quantityInCompartment;
  double density;
  double temperature;
  int deliverySequence;
  String? notes;

  CompartmentDetail({
    required this.compartmentNumber,
    required this.fuelTankId,
    required this.quantityInCompartment,
    required this.density,
    required this.temperature,
    required this.deliverySequence,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'compartmentNumber': compartmentNumber,
    'fuelTankId': fuelTankId,
    'quantityInCompartment': quantityInCompartment,
    'density': density,
    'temperature': temperature,
    'deliverySequence': deliverySequence,
    'notes': notes,
  };

  factory CompartmentDetail.fromJson(Map<String, dynamic> json) {
    return CompartmentDetail(
      compartmentNumber: json['compartmentNumber'],
      fuelTankId: json['fuelTankId'],
      quantityInCompartment: json['quantityInCompartment'].toDouble(),
      density: json['density'].toDouble(),
      temperature: json['temperature'].toDouble(),
      deliverySequence: json['deliverySequence'],
      notes: json['notes'],
    );
  }
}

class FuelDeliveryOrder {
  List<CompartmentDetail> compartmentDetails;
  DateTime deliveryDate;
  String invoiceNumber;
  String supplierId;
  String truckNumber;
  String driverName;
  String driverContactNumber;
  int totalCompartments;
  String? notes;

  FuelDeliveryOrder({
    required this.compartmentDetails,
    required this.deliveryDate,
    required this.invoiceNumber,
    required this.supplierId,
    required this.truckNumber,
    required this.driverName,
    required this.driverContactNumber,
    required this.totalCompartments,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'compartmentDetails': compartmentDetails.map((detail) => detail.toJson()).toList(),
    'deliveryDate': deliveryDate.toIso8601String(),
    'invoiceNumber': invoiceNumber,
    'supplierId': supplierId,
    'truckNumber': truckNumber,
    'driverName': driverName,
    'driverContactNumber': driverContactNumber,
    'totalCompartments': totalCompartments,
    'notes': notes,
  };

  factory FuelDeliveryOrder.fromJson(Map<String, dynamic> json) {
    return FuelDeliveryOrder(
      compartmentDetails: (json['compartmentDetails'] as List)
          .map((detail) => CompartmentDetail.fromJson(detail))
          .toList(),
      deliveryDate: DateTime.parse(json['deliveryDate']),
      invoiceNumber: json['invoiceNumber'],
      supplierId: json['supplierId'],
      truckNumber: json['truckNumber'],
      driverName: json['driverName'],
      driverContactNumber: json['driverContactNumber'],
      totalCompartments: json['totalCompartments'],
      notes: json['notes'],
    );
  }
} 