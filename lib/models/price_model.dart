class FuelPrice {
  final String? id;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String fuelType;
  final String? fuelTypeId;
  final double pricePerLiter;
  final double? costPerLiter;
  final double? markupPercentage;
  final double? markupAmount;
  final String petrolPumpId;
  final String? lastUpdatedBy;
  final bool? isActive;

  FuelPrice({
    this.id,
    required DateTime effectiveFrom,
    this.effectiveTo,
    required this.fuelType,
    this.fuelTypeId,
    required this.pricePerLiter,
    this.costPerLiter,
    this.markupPercentage,
    this.markupAmount,
    required this.petrolPumpId,
    this.lastUpdatedBy,
    this.isActive,
  }) : this.effectiveFrom = effectiveFrom;

  factory FuelPrice.fromJson(Map<String, dynamic> json) {
    // Try to parse effectiveDate/effectiveFrom based on what's available
    DateTime parseEffectiveDate() {
      if (json.containsKey('effectiveFrom') && json['effectiveFrom'] != null) {
        return DateTime.parse(json['effectiveFrom']);
      } else if (json.containsKey('effectiveDate') && json['effectiveDate'] != null) {
        return DateTime.parse(json['effectiveDate']);
      }
      return DateTime.now(); // Fallback
    }
    
    // Try to parse effectiveTo
    DateTime? parseEffectiveTo() {
      if (json.containsKey('effectiveTo') && json['effectiveTo'] != null) {
        return DateTime.parse(json['effectiveTo']);
      }
      return null;
    }
    
    // Get fuelType from either fuelType or fuelTypeName
    String parseFuelType() {
      if (json.containsKey('fuelTypeName') && json['fuelTypeName'] != null) {
        return json['fuelTypeName'].toString();
      } else if (json.containsKey('fuelType') && json['fuelType'] != null) {
        return json['fuelType'].toString();
      }
      return ''; // Empty string as fallback
    }

    // Handle various id formats
    String? parseId() {
      if (json.containsKey('pricingId') && json['pricingId'] != null) {
        return json['pricingId'].toString();
      } else if (json.containsKey('id') && json['id'] != null) {
        return json['id'].toString();
      }
      return null;
    }

    return FuelPrice(
      id: parseId(),
      effectiveFrom: parseEffectiveDate(),
      effectiveTo: parseEffectiveTo(),
      fuelType: parseFuelType(),
      fuelTypeId: json['fuelTypeId'],
      pricePerLiter: json['pricePerLiter']?.toDouble() ?? 0.0,
      costPerLiter: json['costPerLiter']?.toDouble(),
      markupPercentage: json['markupPercentage']?.toDouble(),
      markupAmount: json['markupAmount']?.toDouble(),
      petrolPumpId: json['petrolPumpId'] ?? '',
      lastUpdatedBy: json['lastUpdatedBy'],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'effectiveFrom': effectiveFrom.toIso8601String(),
      'fuelTypeId': fuelTypeId,
      'pricePerLiter': pricePerLiter,
      'petrolPumpId': petrolPumpId,
      'lastUpdatedBy': lastUpdatedBy,
    };
    
    // Add optional fields only if they have values
    if (id != null) data['pricingId'] = id;
    if (effectiveTo != null) data['effectiveTo'] = effectiveTo!.toIso8601String();
    if (costPerLiter != null) data['costPerLiter'] = costPerLiter;
    if (markupPercentage != null) data['markupPercentage'] = markupPercentage;
    if (markupAmount != null) data['markupAmount'] = markupAmount;
    
    return data;
  }
} 