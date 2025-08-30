import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:petrol_pump/api/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nozzle_model.dart';
import 'dart:developer' as developer;

class NozzleRepository {
  // Use API constants for base URL
  final String baseUrl = ApiConstants.baseUrl;

  // Get auth token from SharedPreferences
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      developer.log('NozzleRepository: Retrieved auth token: ${token != null ? 'Token exists' : 'No token found'}');
      return token;
    } catch (e) {
      developer.log('NozzleRepository: Error getting auth token: $e');
      return null;
    }
  }

  // Get headers with auth token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getAuthToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      developer.log('NozzleRepository: Added auth token to headers');
    } else {
      developer.log('NozzleRepository: Warning - No auth token available');
    }
    
    return headers;
  }

  // Get all nozzles 
  Future<ApiResponse<List<Nozzle>>> getAllNozzles() async {
    developer.log('NozzleRepository: Getting all nozzles');
    try {
      final url = ApiConstants.getNozzleUrl();
      developer.log('NozzleRepository: API URL: $url');
      
      final headers = await _getHeaders();
      developer.log('NozzleRepository: Request headers: $headers');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      developer.log('NozzleRepository: Response status code: ${response.statusCode}');
      developer.log('NozzleRepository: Response body: ${response.body}');

      if (response.statusCode == ApiConstants.statusOk) {
        final List<dynamic> jsonData = json.decode(response.body);
        developer.log('NozzleRepository: Successfully parsed JSON data, count: ${jsonData.length}');
        
        final nozzles = jsonData
            .map((data) => Nozzle.fromJson(data))
            .toList();
        
        developer.log('NozzleRepository: Returning ${nozzles.length} nozzles');
        return ApiResponse<List<Nozzle>>(
          success: true,
          data: nozzles,
        );
      } else {
        developer.log('NozzleRepository: Error fetching all nozzles: ${response.statusCode}');
        developer.log('NozzleRepository: Error response: ${response.body}');
        return ApiResponse<List<Nozzle>>(
          success: false,
          errorMessage: 'Failed to fetch all nozzles: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('NozzleRepository: Exception when fetching all nozzles: $e');
      return ApiResponse<List<Nozzle>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get all nozzles for a specific dispenser
  Future<ApiResponse<List<Nozzle>>> getNozzlesByDispenserId(String dispenserId) async {
    if (dispenserId.isEmpty) {
      developer.log('NozzleRepository: Cannot get nozzles - empty dispenser ID provided');
      print('NozzleRepository: Cannot get nozzles - empty dispenser ID provided');
      return ApiResponse<List<Nozzle>>(
        success: false,
        errorMessage: 'Dispenser ID cannot be empty',
        data: [],
      );
    }
    
    developer.log('NozzleRepository: Getting nozzles for dispenser ID: $dispenserId');
    print('NozzleRepository: Getting nozzles for dispenser ID: $dispenserId');
    
    try {
      final url = ApiConstants.getNozzlesByDispenserUrl(dispenserId);
      developer.log('NozzleRepository: API URL: $url');
      print('NozzleRepository: API URL: $url');
      
      final headers = await _getHeaders();
      developer.log('NozzleRepository: Request headers: $headers');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      developer.log('NozzleRepository: Response status code: ${response.statusCode}');
      print('NozzleRepository: Response status code: ${response.statusCode}');
      print('NozzleRepository: Raw response body: ${response.body}');

      if (response.statusCode == ApiConstants.statusOk) {
        // Check if response body is empty
        if (response.body.isEmpty) {
          print('NozzleRepository: Empty response body received');
          return ApiResponse<List<Nozzle>>(
            success: true,
            data: [],
          );
        }
        
        try {
          final List<dynamic> jsonData = json.decode(response.body);
          developer.log('NozzleRepository: Successfully parsed JSON data, count: ${jsonData.length}');
          print('NozzleRepository: Successfully parsed JSON data, count: ${jsonData.length}');
          
          if (jsonData.isEmpty) {
            print('NozzleRepository: Empty nozzle array returned from API');
            return ApiResponse<List<Nozzle>>(
              success: true,
              data: [],
            );
          }
          
          final nozzles = jsonData
              .map((data) => Nozzle.fromJson(data))
              .toList();
          
          developer.log('NozzleRepository: Returning ${nozzles.length} nozzles');
          print('NozzleRepository: Returning ${nozzles.length} nozzles');
          
          // Log some details about the nozzles
          for (var nozzle in nozzles) {
            print('NozzleRepository: Nozzle #${nozzle.nozzleNumber}, Status: ${nozzle.status}, FuelType: ${nozzle.fuelType ?? ''}');
          }
          
          return ApiResponse<List<Nozzle>>(
            success: true,
            data: nozzles,
          );
        } catch (e) {
          print('NozzleRepository: JSON parsing error: $e');
          return ApiResponse<List<Nozzle>>(
            success: false,
            errorMessage: 'Error parsing response: $e',
            data: [],
          );
        }
      } else {
        developer.log('NozzleRepository: Error fetching nozzles: ${response.statusCode}');
        developer.log('NozzleRepository: Error response: ${response.body}');
        print('NozzleRepository: Error fetching nozzles: ${response.statusCode}');
        print('NozzleRepository: Error response: ${response.body}');
        return ApiResponse<List<Nozzle>>(
          success: false,
          errorMessage: 'Failed to fetch nozzles: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('NozzleRepository: Exception when fetching nozzles: $e');
      print('NozzleRepository: Exception when fetching nozzles: $e');
      return ApiResponse<List<Nozzle>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Add a new nozzle
  Future<ApiResponse<Nozzle>> addNozzle(Nozzle nozzle) async {
    developer.log('NozzleRepository: Adding new nozzle for dispenser: ${nozzle.fuelDispenserUnitId}');
    developer.log('NozzleRepository: Nozzle details: ${nozzle.toJson()}');
    print('ADD_NOZZLE_API: Starting API call to add nozzle');
    print('ADD_NOZZLE_API: Nozzle details: ${nozzle.toJson()}');
    
    try {
      // Validate input data before sending request
      if (nozzle.fuelDispenserUnitId.isEmpty) {
        print('ADD_NOZZLE_API: Error - Dispenser ID is empty');
        return ApiResponse<Nozzle>(
          success: false,
          errorMessage: 'Error: Dispenser ID cannot be empty',
        );
      }
      
      if (nozzle.nozzleNumber <= 0 || nozzle.nozzleNumber > 8) {
        print('ADD_NOZZLE_API: Error - Invalid nozzle number: ${nozzle.nozzleNumber}');
        return ApiResponse<Nozzle>(
          success: false,
          errorMessage: 'Error: Nozzle number must be between 1 and 8',
        );
      }
      
      if (nozzle.fuelTankId == null || nozzle.fuelTankId!.isEmpty) {
        print('ADD_NOZZLE_API: Error - Fuel tank ID is empty');
        return ApiResponse<Nozzle>(
          success: false,
          errorMessage: 'Error: Fuel tank must be selected',
        );
      }
      
      final url = ApiConstants.getNozzleUrl();
      print('ADD_NOZZLE_API: API URL: $url');
      developer.log('NozzleRepository: API URL: $url');
      
      // Create payload according to the specified API format
      final payload = {
        'fuelDispenserUnitId': nozzle.fuelDispenserUnitId,
        'nozzleNumber': nozzle.nozzleNumber,
        'status': nozzle.status,
        'lastCalibrationDate': nozzle.lastCalibrationDate?.toIso8601String(),
        'fuelTankId': nozzle.fuelTankId,
        'petrolPumpId': nozzle.petrolPumpId,
      };
      
      final body = json.encode(payload);
      print('ADD_NOZZLE_API: Request payload: $body');
      developer.log('NozzleRepository: Request body: $body');
      
      final headers = await _getHeaders();      
      print('ADD_NOZZLE_API: Request headers: $headers');
      developer.log('NozzleRepository: Headers: $headers');
      
      // Using POST method as specified in the API requirements
      print('ADD_NOZZLE_API: Sending POST request');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      print('ADD_NOZZLE_API: Response status code: ${response.statusCode}');
      print('ADD_NOZZLE_API: Response body: ${response.body}');
      developer.log('NozzleRepository: Response status code: ${response.statusCode}');
      developer.log('NozzleRepository: Response body: ${response.body}');

      if (response.statusCode == ApiConstants.statusCreated || response.statusCode == ApiConstants.statusOk) {
        print('ADD_NOZZLE_API: Success - Nozzle created');
        final jsonData = json.decode(response.body);
        developer.log('NozzleRepository: Successfully created nozzle');
        return ApiResponse<Nozzle>(
          success: true,
          data: Nozzle.fromJson(jsonData),
        );
      } else {
        print('ADD_NOZZLE_API: Error - Failed with status code: ${response.statusCode}');
        developer.log('NozzleRepository: Error adding nozzle: ${response.statusCode}');
        String errorBody = 'No response body';
        try {
          if (response.body.isNotEmpty) {
            errorBody = response.body;
            print('ADD_NOZZLE_API: Error response body: $errorBody');
            // Try to parse as JSON for better error details
            final errorJson = json.decode(response.body);
            if (errorJson.containsKey('message')) {
              errorBody = errorJson['message'];
              print('ADD_NOZZLE_API: Error message from response: $errorBody');
            }
          }
        } catch (e) {
          print('ADD_NOZZLE_API: Could not parse error response: $e');
          developer.log('NozzleRepository: Could not parse error response: $e');
        }
        
        developer.log('NozzleRepository: Error response: $errorBody');
        return ApiResponse<Nozzle>(
          success: false,
          errorMessage: 'Failed to add nozzle: ${response.statusCode} - $errorBody',
        );
      }
    } catch (e) {
      print('ADD_NOZZLE_API: Exception occurred: $e');
      developer.log('NozzleRepository: Exception when adding nozzle: $e');
      return ApiResponse<Nozzle>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Update a nozzle
  Future<ApiResponse<Nozzle>> updateNozzle(Nozzle nozzle) async {
    developer.log('NozzleRepository: Updating nozzle with ID: ${nozzle.id}');
    developer.log('NozzleRepository: Nozzle details: ${nozzle.toJson()}');
    
    try {
      final url = ApiConstants.getNozzleUrl();
      developer.log('NozzleRepository: API URL: $url');
      
      // Create payload according to the specified API format
      final payload = {
        'nozzleId': nozzle.id,
        'nozzleNumber': nozzle.nozzleNumber,
        'status': nozzle.status,
        'lastCalibrationDate': nozzle.lastCalibrationDate?.toIso8601String(),
        'fuelTankId': nozzle.fuelTankId,
        'petrolPumpId': nozzle.petrolPumpId
      };
      
      final body = json.encode(payload);
      developer.log('NozzleRepository: Request body: $body');
      
      final headers = await _getHeaders();
      
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      developer.log('NozzleRepository: Response status code: ${response.statusCode}');
      developer.log('NozzleRepository: Response body: ${response.body}');

      if (response.statusCode == ApiConstants.statusOk) {
        final jsonData = json.decode(response.body);
        developer.log('NozzleRepository: Successfully updated nozzle');
        return ApiResponse<Nozzle>(
          success: true,
          data: Nozzle.fromJson(jsonData),
        );
      } else {
        developer.log('NozzleRepository: Error updating nozzle: ${response.statusCode}');
        developer.log('NozzleRepository: Error response: ${response.body}');
        return ApiResponse<Nozzle>(
          success: false,
          errorMessage: 'Failed to update nozzle: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      developer.log('NozzleRepository: Exception when updating nozzle: $e');
      return ApiResponse<Nozzle>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Delete a nozzle
  Future<ApiResponse<void>> deleteNozzle(String id) async {
    developer.log('NozzleRepository: Deleting nozzle with ID: $id');
    
    try {
      final url = ApiConstants.getNozzleByIdUrl(id);
      developer.log('NozzleRepository: API URL: $url');
      
      final headers = await _getHeaders();
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );

      developer.log('NozzleRepository: Response status code: ${response.statusCode}');

      if (response.statusCode == ApiConstants.statusNoContent) {
        developer.log('NozzleRepository: Successfully deleted nozzle');
        return ApiResponse<void>(
          success: true,
        );
      } else {
        developer.log('NozzleRepository: Error deleting nozzle: ${response.statusCode}');
        developer.log('NozzleRepository: Error response: ${response.body}');
        return ApiResponse<void>(
          success: false,
          errorMessage: 'Failed to delete nozzle: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      developer.log('NozzleRepository: Exception when deleting nozzle: $e');
      return ApiResponse<void>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get nozzle by ID
  Future<ApiResponse<Nozzle>> getNozzleById(String nozzleId) async {
    developer.log('NozzleRepository: Getting nozzle by ID: $nozzleId');
    try {
      final url = ApiConstants.getNozzleByIdUrl(nozzleId);
      developer.log('NozzleRepository: API URL: $url');
      
      final headers = await _getHeaders();
      developer.log('NozzleRepository: Request headers: $headers');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      developer.log('NozzleRepository: Response status code: ${response.statusCode}');
      developer.log('NozzleRepository: Response body: ${response.body}');

      if (response.statusCode == ApiConstants.statusOk) {
        final jsonData = json.decode(response.body);
        developer.log('NozzleRepository: Successfully parsed JSON data');
        
        final nozzle = Nozzle.fromJson(jsonData);
        developer.log('NozzleRepository: Returning nozzle with ID: ${nozzle.id}');
        
        return ApiResponse<Nozzle>(
          success: true,
          data: nozzle,
        );
      } else {
        developer.log('NozzleRepository: Error fetching nozzle: ${response.statusCode}');
        developer.log('NozzleRepository: Error response: ${response.body}');
        return ApiResponse<Nozzle>(
          success: false,
          errorMessage: 'Failed to fetch nozzle: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('NozzleRepository: Exception when fetching nozzle: $e');
      return ApiResponse<Nozzle>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }
}

// API response class
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? errorMessage;

  ApiResponse({
    required this.success,
    this.data,
    this.errorMessage,
  });
} 