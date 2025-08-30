class FuelDispenser {
  final String id;
  final int dispenserNumber;
  final String petrolPumpId;
  final String status;
  final int numberOfNozzles;
  final String? fuelType;
  
  FuelDispenser({
    required this.id,
    required this.dispenserNumber,
    required this.petrolPumpId,
    required this.status,
    int? numberOfNozzles,
    this.fuelType,
  }) : this.numberOfNozzles = _validateNozzleCount(numberOfNozzles ?? 1);
  
  static int _validateNozzleCount(int count) {
    if (count < 1) return 1;
    if (count > 6) return 6;
    return count;
  }
  
  factory FuelDispenser.fromJson(Map<String, dynamic> json) {
    return FuelDispenser(
      id: json['id'] ?? json['fuelDispenserUnitId'],
      dispenserNumber: json['dispenserNumber'],
      petrolPumpId: json['petrolPumpId'],
      status: json['status'],
      numberOfNozzles: _validateNozzleCount(json['numberOfNozzles'] ?? 1),
      fuelType: json['fuelType'],
    );
  }
  
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      if (id != null) 'fuelDispenserUnitId': id,
      'dispenserNumber': dispenserNumber,
      'petrolPumpId': petrolPumpId,
      'status': status,
      'numberOfNozzles': numberOfNozzles,
      'fuelType': fuelType ?? "<string>",
    };
    
    return data;
  }
  
  /// Validates all constraints for the model and returns a map of validation errors
  Map<String, List<String>> validate() {
    final errors = <String, List<String>>{};
    
    if (dispenserNumber <= 0) {
      errors['DispenserNumber'] = ['Dispenser number must be positive'];
    }
    
    if (numberOfNozzles < 1 || numberOfNozzles > 6) {
      errors['NumberOfNozzles'] = ['Number of nozzles must be between 1 and 6'];
    }
    
    if (petrolPumpId.isEmpty) {
      errors['PetrolPumpId'] = ['Petrol pump ID is required'];
    }
    
    if (!['Active', 'Inactive', 'Maintenance'].contains(status)) {
      errors['Status'] = ['Status must be Active, Inactive, or Maintenance'];
    }
    
    return errors;
  }
} 