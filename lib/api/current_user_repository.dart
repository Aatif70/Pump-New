import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/current_user_model.dart';
import 'api_constants.dart';
import 'api_response.dart';

class CurrentUserRepository {
  // Get current user data
  Future<ApiResponse<CurrentUser>> getCurrentUser() async {
    try {
      // First get the auth token - await it properly
      final token = await ApiConstants.getAuthToken();
      if (token == null || token.isEmpty) {
        return ApiResponse<CurrentUser>(
          success: false,
          data: null,
          errorMessage: 'Auth token is null or empty. Please login again.',
        );
      }
      
      final url = Uri.parse('${ApiConstants.baseUrl}/api/Employee/Current');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        print('Current user API response: ${response.body}');
        final jsonResponse = json.decode(response.body);
        
        // Check if the response has a 'data' field containing employee info
        if (jsonResponse['data'] != null) {
          final userData = jsonResponse['data'];
          final currentUser = CurrentUser(
            id: 0, // Not using ID in the UI, so default to 0
            fullName: userData['fullName'] ?? '',
            email: userData['email'] ?? '',
            role: userData['role'] ?? '',
            phoneNumber: userData['phoneNumber'],
            isActive: userData['isActive'] ?? false,
          );
          
          return ApiResponse<CurrentUser>(
            success: true,
            data: currentUser,
            errorMessage: null,
          );
        } else {
          print('Current user API response missing data field');
          return ApiResponse<CurrentUser>(
            success: false,
            data: null,
            errorMessage: 'Response missing data field',
          );
        }
      } else {
        print('Current user API failed. Status code: ${response.statusCode}, Response: ${response.body}');
        return ApiResponse<CurrentUser>(
          success: false,
          data: null,
          errorMessage: 'Failed to load current user data. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Exception in getCurrentUser: $e');
      return ApiResponse<CurrentUser>(
        success: false,
        data: null,
        errorMessage: 'Error: $e',
      );
    }
  }
} 