import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'api_response.dart';
import '../models/quality_check_model.dart';
import 'api_constants.dart';

class QualityCheckRepository {
  final String baseUrl = ApiConstants.baseUrl;

  // Get authentication token from shared preferences
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      developer.log('QualityCheckRepository: Retrieved auth token: ${token != null ? 'Token exists' : 'No token found'}');
      return token;
    } catch (e) {
      developer.log('QualityCheckRepository: Error getting auth token: $e');
      return null;
    }
  }

  // Get all quality checks
  Future<ApiResponse<List<QualityCheck>>> getAllQualityChecks() async {
    try {
      // Get the authentication token
      final token = await _getAuthToken();
      
      if (token == null) {
        developer.log('QualityCheckRepository: No auth token found for getting quality checks');
        return ApiResponse<List<QualityCheck>>(
          success: false,
          errorMessage: 'Authentication token not found. Please login again.',
        );
      }

      final url = ApiConstants.getFuelQualityCheckUrl();
      developer.log('QualityCheckRepository: GET request to: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      );

      developer.log('QualityCheckRepository: Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        developer.log('QualityCheckRepository: Response body: ${response.body.substring(0, min(100, response.body.length))}...');
        
        // Check if response has a data field or is a direct list
        List<dynamic> jsonData;
        
        if (jsonResponse is Map && jsonResponse.containsKey('data')) {
          jsonData = jsonResponse['data'] as List<dynamic>;
          developer.log('QualityCheckRepository: Found ${jsonData.length} quality checks in data field');
        } else if (jsonResponse is List) {
          jsonData = jsonResponse;
          developer.log('QualityCheckRepository: Found ${jsonData.length} quality checks in direct list');
        } else {
          return ApiResponse<List<QualityCheck>>(
            success: false,
            errorMessage: 'Unexpected response format',
          );
        }
        
        final List<QualityCheck> qualityChecks = jsonData
            .map((json) => QualityCheck.fromJson(json))
            .toList();
        
        return ApiResponse<List<QualityCheck>>(
          success: true, 
          data: qualityChecks,
        );
      } else if (response.statusCode == 401) {
        developer.log('QualityCheckRepository: Unauthorized - token may be invalid or expired');
        return ApiResponse<List<QualityCheck>>(
          success: false,
          errorMessage: 'Your session has expired. Please login again.',
        );
      } else {
        developer.log('QualityCheckRepository: Failed with status code ${response.statusCode}');
        return ApiResponse<List<QualityCheck>>(
          success: false,
          errorMessage: 'Failed to load quality checks: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('QualityCheckRepository: Exception in getAllQualityChecks: $e');
      return ApiResponse<List<QualityCheck>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get quality checks by fuel tank ID
  Future<ApiResponse<List<QualityCheck>>> getQualityChecksByTank(String fuelTankId) async {
    try {
      // Get the authentication token
      final token = await _getAuthToken();
      
      if (token == null) {
        return ApiResponse<List<QualityCheck>>(
          success: false,
          errorMessage: 'Authentication token not found. Please login again.',
        );
      }
      
      final url = '${ApiConstants.getFuelQualityCheckUrl()}/tank/$fuelTankId';
      developer.log('QualityCheckRepository: GET request to: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        // Check if response has a data field or is a direct list
        List<dynamic> jsonData;
        
        if (jsonResponse is Map && jsonResponse.containsKey('data')) {
          jsonData = jsonResponse['data'] as List<dynamic>;
        } else if (jsonResponse is List) {
          jsonData = jsonResponse;
        } else {
          return ApiResponse<List<QualityCheck>>(
            success: false,
            errorMessage: 'Unexpected response format',
          );
        }
        
        final List<QualityCheck> qualityChecks = jsonData
            .map((json) => QualityCheck.fromJson(json))
            .toList();
        
        return ApiResponse<List<QualityCheck>>(
          success: true, 
          data: qualityChecks,
        );
      } else if (response.statusCode == 401) {
        return ApiResponse<List<QualityCheck>>(
          success: false,
          errorMessage: 'Your session has expired. Please login again.',
        );
      } else {
        return ApiResponse<List<QualityCheck>>(
          success: false,
          errorMessage: 'Failed to load quality checks: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse<List<QualityCheck>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Add new quality check
  Future<ApiResponse<QualityCheck>> addQualityCheck(QualityCheck qualityCheck) async {
    try {
      // Get the authentication token
      final token = await _getAuthToken();
      
      if (token == null) {
        developer.log('QualityCheckRepository: No auth token found for adding quality check');
        return ApiResponse<QualityCheck>(
          success: false,
          errorMessage: 'Authentication token not found. Please login again.',
        );
      }

      final url = '$baseUrl/api/FuelQualityCheck';
      developer.log('QualityCheckRepository: POST request to: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: json.encode(qualityCheck.toJson()),
      );

      developer.log('QualityCheckRepository: Response status code: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        developer.log('QualityCheckRepository: Quality check added successfully');
        return ApiResponse<QualityCheck>(
          success: true,
          data: QualityCheck.fromJson(jsonData),
        );
      } else if (response.statusCode == 401) {
        developer.log('QualityCheckRepository: Unauthorized - token may be invalid or expired');
        return ApiResponse<QualityCheck>(
          success: false,
          errorMessage: 'Your session has expired. Please login again.',
        );
      } else {
        developer.log('QualityCheckRepository: Failed with status code ${response.statusCode}');
        try {
          final errorResponse = json.decode(response.body);
          final errorMessage = errorResponse['message'] ?? 'Failed to add quality check';
          return ApiResponse<QualityCheck>(
            success: false,
            errorMessage: '$errorMessage (Status: ${response.statusCode})',
          );
        } catch (e) {
          return ApiResponse<QualityCheck>(
            success: false,
            errorMessage: 'Failed to add quality check: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      developer.log('QualityCheckRepository: Exception in addQualityCheck: $e');
      return ApiResponse<QualityCheck>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Delete quality check
  Future<ApiResponse<bool>> deleteQualityCheck(String id) async {
    try {
      // Get the authentication token
      final token = await _getAuthToken();
      
      if (token == null) {
        return ApiResponse<bool>(
          success: false,
          errorMessage: 'Authentication token not found. Please login again.',
        );
      }
      
      final response = await http.delete(
        Uri.parse('$baseUrl/api/FuelQualityCheck/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse<bool>(
          success: true,
          data: true,
        );
      } else if (response.statusCode == 401) {
        return ApiResponse<bool>(
          success: false,
          errorMessage: 'Your session has expired. Please login again.',
        );
      } else {
        return ApiResponse<bool>(
          success: false,
          errorMessage: 'Failed to delete quality check: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse<bool>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }
}

// Helper function to get the minimum of two integers
int min(int a, int b) {
  return a < b ? a : b;
} 