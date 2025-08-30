class Customer {
  final String? customerId;
  final String customerType;
  final String customerName;
  final String contactPerson;
  final String phoneNumber;
  final String email;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String gstNumber;
  final double creditLimit;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String customerCode;
  final double totalDueAmount;
  final int loyaltyPoints;

  Customer({
    this.customerId,
    required this.customerType,
    required this.customerName,
    required this.contactPerson,
    required this.phoneNumber,
    required this.email,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.gstNumber,
    required this.creditLimit,
    this.createdAt,
    this.updatedAt,
    required this.customerCode,
    required this.totalDueAmount,
    required this.loyaltyPoints,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      customerId: json['customerId'] as String?,
      customerType: json['customerType'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      contactPerson: json['contactPerson'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      email: json['email'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      zipCode: json['zipCode'] as String? ?? '',
      gstNumber: json['gstNumber'] as String? ?? '',
      creditLimit: (json['creditLimit'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null && json['createdAt'].toString().isNotEmpty
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null && json['updatedAt'].toString().isNotEmpty
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      customerCode: json['customerCode'] as String? ?? '',
      totalDueAmount: (json['totalDueAmount'] as num?)?.toDouble() ?? 0.0,
      loyaltyPoints: json['loyaltyPoints'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerType': customerType,
      'customerName': customerName,
      'contactPerson': contactPerson,
      'phoneNumber': phoneNumber,
      'email': email,
      'address': address,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'gstNumber': gstNumber,
      'creditLimit': creditLimit,
      'customerCode': customerCode,
    };
  }

  @override
  String toString() {
    return 'Customer{customerId: $customerId, customerName: $customerName, customerCode: $customerCode}';
  }
}
