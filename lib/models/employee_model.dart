class Employee {
  final String? id;
  final String email;
  final String firstName;
  final String lastName;
  final DateTime hireDate;
  final String password;
  final String petrolPumpId;
  final String phoneNumber;
  final String role;
  final DateTime dateOfBirth;
  final String governmentId;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String emergencyContact;


  
  final bool isActive;

  Employee({
    this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.hireDate,
    required this.password,
    required this.petrolPumpId,
    required this.phoneNumber,
    required this.role,
    required this.dateOfBirth,
    required this.governmentId,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.emergencyContact,
    this.isActive = true,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['employeeId'] ?? json['id'],
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      hireDate: json['hireDate'] != null ? DateTime.parse(json['hireDate']) : DateTime.now(),
      password: json['password'] ?? '',
      petrolPumpId: json['petrolPumpId'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      role: json['role'] ?? '',
      dateOfBirth: json['dateOfBirth'] != null ? DateTime.parse(json['dateOfBirth']) : DateTime.now(),
      governmentId: json['governmentId'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      zipCode: json['zipCode'] ?? '',
      emergencyContact: json['emergencyContact'] ?? '',
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'hireDate': hireDate.toIso8601String(),
      'password': password,
      'petrolPumpId': petrolPumpId,
      'phoneNumber': phoneNumber,
      'role': role,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'governmentId': governmentId,
      'address': address,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'emergencyContact': emergencyContact,
      'isActive': isActive,
    };
  }

  @override
  String toString() {
    return 'Employee{id: $id, firstName: $firstName, lastName: $lastName, email: $email}';
  }
} 