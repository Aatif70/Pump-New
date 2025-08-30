class FuelPrice {
  final String? id;
  final double price;
  final String? fuelType;
  final String? fuelTypeId;
  final DateTime? effectiveDate;
  final bool isActive;

  FuelPrice({
    this.id,
    required this.price,
    this.fuelType,
    this.fuelTypeId,
    this.effectiveDate,
    this.isActive = true,
  });

  factory FuelPrice.fromJson(Map<String, dynamic> json) {
    // Handle price with robust parsing
    double parsePrice(dynamic rawPrice) {
      if (rawPrice == null) return 95.0; // Default value
      if (rawPrice is double) return rawPrice;
      if (rawPrice is int) return rawPrice.toDouble();
      if (rawPrice is String) {
        try {
          return double.parse(rawPrice);
        } catch (_) {
          return 95.0; // Default if parsing fails
        }
      }
      return 95.0; // Default for any other case
    }
    
    // Try different field name formats that might be present
    String? tryGetId() {
      if (json['id'] != null) return json['id'].toString();
      if (json['priceId'] != null) return json['priceId'].toString();
      if (json['pricingId'] != null) return json['pricingId'].toString();
      return null;
    }
    
    String? tryGetFuelType() {
      if (json['fuelType'] != null) return json['fuelType'].toString();
      if (json['fuel_type'] != null) return json['fuel_type'].toString();
      if (json['fuelTypeName'] != null) return json['fuelTypeName'].toString();
      return null;
    }
    
    String? tryGetFuelTypeId() {
      if (json['fuelTypeId'] != null) return json['fuelTypeId'].toString();
      if (json['fuel_type_id'] != null) return json['fuel_type_id'].toString();
      return null;
    }
    
    DateTime? tryParseDate(dynamic rawDate) {
      if (rawDate == null) return null;
      if (rawDate is String) {
        try {
          return DateTime.parse(rawDate);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    // Check for available price fields, prioritizing pricePerLiter
    dynamic priceValue = json['pricePerLiter'];
    if (priceValue == null) {
      priceValue = json['price'] ?? 95.0;
    }

    return FuelPrice(
      id: tryGetId(),
      price: parsePrice(priceValue),
      fuelType: tryGetFuelType(),
      fuelTypeId: tryGetFuelTypeId(),
      effectiveDate: tryParseDate(json['effectiveDate'] ?? json['effective_date'] ?? json['effectiveFrom']),
      isActive: json['isActive'] ?? json['is_active'] ?? json['isCurrentlyActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'price': price,
      'fuelType': fuelType,
      'fuelTypeId': fuelTypeId,
      'effectiveDate': effectiveDate?.toIso8601String(),
      'isActive': isActive,
    };
  }
} 