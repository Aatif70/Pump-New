import 'api_service.dart';
import 'api_constants.dart';
import 'dart:developer' as developer;
import 'dart:async';

class AuthRepository {
  final ApiService _apiService = ApiService();
  
  // Flag to use mock login instead of real API
  final bool _useMockLogin = false;  // false in production

  // Login method
  Future<ApiResponse<Map<String, dynamic>>> login(String email, String password, String sap) async {
    developer.log('AuthRepository: login method called with email=$email, password length=${password.length}, sap=$sap');
    
    // Use mock login for testing if flag is set
    if (_useMockLogin) {
      developer.log('AuthRepository: Using mock login instead of real API call');
      return _mockLogin(email, password, sap);
    }
    
    final url = ApiConstants.getLoginUrl();
    developer.log('AuthRepository: login URL: $url');
    
    final body = {
      'email': email,
      'password': password,
      'sapNo': sap,
    };
    
    // Only add SAP if it's not empty
    if (sap.isNotEmpty) {
      developer.log('AuthRepository: Including SAP in login request');
    } else {
      developer.log('AuthRepository: SAP is empty, not including in request');
      body.remove('sapNo');
    }
    
    developer.log('AuthRepository: Making login API call with body: $body');
    
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        url,
        body: body,
        fromJson: (json) => json as Map<String, dynamic>,
      );
      
      developer.log('AuthRepository: login API call completed, success=${response.success}');
      
      if (response.success) {
        developer.log('AuthRepository: login successful, data=${response.data}');
      } else {
        developer.log('AuthRepository: login failed, error=${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('AuthRepository: Exception during login: $e');
      rethrow; // Rethrow to let the UI layer handle it
    }
  }





  
  // Mock login for testing
  Future<ApiResponse<Map<String, dynamic>>> _mockLogin(String email, String password, String sap) async {
    developer.log('AuthRepository: Mock login with email=$email, password=$password, sap=$sap');
    
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Check credentials
    if (email == 'test@gmail.com' && password == '123456') {
      developer.log('AuthRepository: Mock login successful');
      
      // Return a successful response
      return ApiResponse<Map<String, dynamic>>(
        success: true,
        data: {
          'token': 'mock_token_123456789',
          'user': {
            'email': email,
            'name': 'Test User',
            'role': 'admin'
          }
        },
      );
    } else {
      developer.log('AuthRepository: Mock login failed - invalid credentials');
      
      // Return an error response
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        errorMessage: 'Invalid email or password',
      );
    }
  }







  // Register pump method
  Future<ApiResponse<Map<String, dynamic>>> registerPump({
    required String name,
    required String contactNumber,
    required String email,
    required String password,
    required String sapNo,
    String? licenseNumber,
    String? companyName,
  }) async {
    developer.log('AuthRepository: registerPump method called');
    
    final url = ApiConstants.getRegisterPumpUrl();
    developer.log('AuthRepository: register URL: $url');
    
    final body = {
      'name': name,
      'contactNumber': contactNumber,
      'email': email,
      'password': password,
      'sapNo': sapNo,
      if (licenseNumber != null && licenseNumber.isNotEmpty)
        'licenseNumber': licenseNumber,
      if (companyName != null && companyName.isNotEmpty)
        'companyName': companyName,
    };
    
    developer.log('AuthRepository: Making register API call with body: $body');
    
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        url,
        body: body,
        fromJson: (json) => json as Map<String, dynamic>,
      );
      
      developer.log('AuthRepository: register API call completed, success=${response.success}');
      
      if (response.success) {
        developer.log('AuthRepository: registration successful');
      } else {
        developer.log('AuthRepository: registration failed, error=${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('AuthRepository: Exception during registration: $e');
      rethrow; // Rethrow to let the UI layer handle it
    }
  }
} 