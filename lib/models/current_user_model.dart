class CurrentUser {
  final int id;
  final String fullName;
  final String email;
  final String role;
  final String? phoneNumber;
  final bool isActive;

  CurrentUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.phoneNumber,
    required this.isActive,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'] ?? 0,
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      phoneNumber: json['phoneNumber'],
      isActive: json['isActive'] ?? false,
    );
  }
} 