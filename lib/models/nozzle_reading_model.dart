class NozzleReading {
  final String nozzleReadingId;
  final String nozzleId;
  final String employeeId;
  final String shiftId;
  final String readingType;
  final double meterReading;
  final String? readingImage;
  final DateTime recordedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String employeeName;
  final String nozzleNumber;
  final String fuelType;
  final String fuelTypeId;
  final String dispenserNumber;
  final String? fuelTankId;
  final String? petrolPumpId;

  NozzleReading({
    required this.nozzleReadingId,
    required this.nozzleId,
    required this.employeeId,
    required this.shiftId,
    required this.readingType,
    required this.meterReading,
    this.readingImage,
    required this.recordedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.employeeName,
    required this.nozzleNumber,
    required this.fuelType,
    required this.fuelTypeId,
    required this.dispenserNumber,
    this.fuelTankId,
    this.petrolPumpId,
  });

  factory NozzleReading.fromJson(Map<String, dynamic> json) {
    return NozzleReading(
      nozzleReadingId: json['nozzleReadingId'] ?? '',
      nozzleId: json['nozzleId'] ?? '',
      employeeId: json['employeeId'] ?? '',
      shiftId: json['shiftId'] ?? '',
      readingType: json['readingType'] ?? '',
      meterReading: json['meterReading']?.toDouble() ?? 0.0,
      readingImage: json['readingImage'],
      recordedAt: json['recordedAt'] != null ? DateTime.parse(json['recordedAt']) : DateTime.now(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
      employeeName: json['employeeName'] ?? '',
      nozzleNumber: json['nozzleNumber']?.toString() ?? '',
      fuelType: json['fuelType'] ?? '',
      fuelTypeId: json['fuelTypeId'] ?? '',
      dispenserNumber: json['dispenserNumber']?.toString() ?? '',
      fuelTankId: json['fuelTankId'],
      petrolPumpId: json['petrolPumpId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nozzleReadingId': nozzleReadingId,
      'nozzleId': nozzleId,
      'employeeId': employeeId,
      'shiftId': shiftId,
      'readingType': readingType,
      'meterReading': meterReading,
      'readingImage': readingImage,
      'recordedAt': recordedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'employeeName': employeeName,
      'nozzleNumber': nozzleNumber,
      'fuelType': fuelType,
      'fuelTypeId': fuelTypeId,
      'dispenserNumber': dispenserNumber,
      'fuelTankId': fuelTankId,
      'petrolPumpId': petrolPumpId,
    };
  }
  
  // Compatibility getters for the old model
  String? get id => nozzleReadingId;
  double get startReading => meterReading;
  double? get endReading => readingType.toLowerCase() == 'end' ? meterReading : null;
  DateTime get timestamp => recordedAt;
  String? get status => null;
  String? get fueltankId => fuelTankId;
  String? get fuelDispenserNumber => dispenserNumber;
  
  // Compatibility method for the old model
  NozzleReading copyWith({
    String? id,
    String? nozzleId,
    String? employeeId,
    String? shiftId,
    String? readingType,
    String? fuelType,
    double? startReading,
    double? endReading,
    DateTime? timestamp,
    String? status,
    String? fueltankId,
    String? nozzleNumber,
    String? fuelDispenserNumber,
    String? readingImage,
    String? employeeName,
    String? dispenserNumber,
    String? petrolPumpId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? fuelTypeId,
    double? meterReading,
  }) {
    return NozzleReading(
      nozzleReadingId: id ?? this.nozzleReadingId,
      nozzleId: nozzleId ?? this.nozzleId,
      employeeId: employeeId ?? this.employeeId,
      shiftId: shiftId ?? this.shiftId,
      readingType: readingType ?? this.readingType,
      meterReading: meterReading ?? startReading ?? endReading ?? this.meterReading,
      readingImage: readingImage ?? this.readingImage,
      recordedAt: timestamp ?? this.recordedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      employeeName: employeeName ?? this.employeeName,
      nozzleNumber: nozzleNumber ?? this.nozzleNumber,
      fuelType: fuelType ?? this.fuelType,
      fuelTypeId: fuelTypeId ?? this.fuelTypeId,
      dispenserNumber: dispenserNumber ?? fuelDispenserNumber ?? this.dispenserNumber,
      fuelTankId: fueltankId ?? this.fuelTankId,
      petrolPumpId: petrolPumpId ?? this.petrolPumpId,
    );
  }
}

// Type alias for backwards compatibility
typedef NozzleReadingModel = NozzleReading; 