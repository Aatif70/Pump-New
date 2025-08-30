import 'package:intl/intl.dart';

class Supplier {
  final String? supplierDetailId; // ID field from API
  final String supplierName;
  final String contactPerson;
  final String phoneNumber;
  final String email;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String gstNumber;
  final String petrolPumpId;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Supplier({
    this.supplierDetailId,
    required this.supplierName,
    required this.contactPerson,
    required this.phoneNumber,
    required this.email,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.gstNumber,
    required this.petrolPumpId,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      supplierDetailId: json['supplierDetailId'] as String?,
      supplierName: json['supplierName'] as String? ?? '',
      contactPerson: json['contactPerson'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      email: json['email'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      zipCode: json['zipCode'] as String? ?? '',
      gstNumber: json['gstNumber'] as String? ?? '',
      petrolPumpId: json['petrolPumpId'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null && json['createdAt'].toString().isNotEmpty
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null && json['updatedAt'].toString().isNotEmpty
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contactPerson': contactPerson,
      'phoneNumber': phoneNumber,
      'supplierDetailId': supplierDetailId,
      'supplierName': supplierName,
      'email': email,
      'address': address,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'gstNumber': gstNumber,
      'petrolPumpId': petrolPumpId,
      'isActive': isActive,
    };
  }

  // Helper for formatting dates nicely
  String get formattedCreatedAt => createdAt != null
      ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt!)
      : 'N/A';
      
  String get formattedUpdatedAt => updatedAt != null
      ? DateFormat('dd MMM yyyy, hh:mm a').format(updatedAt!)
      : 'N/A';
} 