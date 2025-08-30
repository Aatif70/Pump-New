class FuelType {
  final String fuelTypeId;
  final String name;
  final String? description;
  final String? color;
  final bool isActive;

  FuelType({
    required this.fuelTypeId,
    required this.name,
    this.description,
    this.color,
    this.isActive = true,
  });

  factory FuelType.fromJson(Map<String, dynamic> json) {
    return FuelType(
      fuelTypeId: json['fuelTypeId'] ?? json['id'] ?? '',
      name: json['name'] ?? json['text'] ?? '',
      description: json['description'],
      color: json['color'],
      isActive: json['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fuelTypeId': fuelTypeId,
      'name': name,
      'description': description,
      'color': color,
      'isActive': isActive,
    };
  }
} 