class PumpProfile {
  final String? petrolPumpId;
  final String name;
  final String? addressId;
  final String licenseNumber;
  final String taxId;
  final String openingTime;
  final String closingTime;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String companyName;
  final int numberOfDispensers;
  final String fuelTypesAvailable;
  final String contactNumber;
  final String email;
  final String website;
  final String gstNumber;
  final String? licenseExpiryDate;
  final String sapNo;
  final String? logoUrl;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? pincode;

  PumpProfile({
    this.petrolPumpId,
    required this.name,
    this.addressId,
    required this.licenseNumber,
    required this.taxId,
    required this.openingTime,
    required this.closingTime,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    required this.companyName,
    required this.numberOfDispensers,
    required this.fuelTypesAvailable,
    required this.contactNumber,
    required this.email,
    required this.website,
    required this.gstNumber,
    this.licenseExpiryDate,
    required this.sapNo,
    this.logoUrl,
    this.address = '',
    this.city = '',
    this.state = '',
    this.country = '',
    this.pincode = '',
  });

  factory PumpProfile.fromJson(Map<String, dynamic> json) {
    return PumpProfile(
      petrolPumpId: json['petrolPumpId'],
      name: json['name'] ?? '',
      addressId: json['addressId'],
      licenseNumber: json['licenseNumber'] ?? '',
      taxId: json['taxId'] ?? '',
      openingTime: json['openingTime'] ?? '',
      closingTime: json['closingTime'] ?? '',
      isActive: json['isActive'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      companyName: json['companyName'] ?? '',
      numberOfDispensers: json['numberOfDispensers'] ?? 0,
      fuelTypesAvailable: json['fuelTypesAvailable'] ?? '',
      contactNumber: json['contactNumber'] ?? '',
      email: json['email'] ?? '',
      website: json['website'] ?? '',
      gstNumber: json['gstNumber'] ?? '',
      licenseExpiryDate: json['licenseExpiryDate'],
      sapNo: json['sapNo'] ?? '',
      logoUrl: json['logoUrl'],
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? '',
      pincode: json['pincode'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'petrolPumpId': petrolPumpId,
      'name': name,
      'addressId': addressId,
      'licenseNumber': licenseNumber,
      'taxId': taxId,
      'openingTime': openingTime,
      'closingTime': closingTime,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'companyName': companyName,
      'numberOfDispensers': numberOfDispensers,
      'fuelTypesAvailable': fuelTypesAvailable,
      'contactNumber': contactNumber,
      'email': email,
      'website': website,
      'gstNumber': gstNumber,
      'licenseExpiryDate': licenseExpiryDate,
      'sapNo': sapNo,
      'logoUrl': logoUrl,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'pincode': pincode,
    };
  }
} 