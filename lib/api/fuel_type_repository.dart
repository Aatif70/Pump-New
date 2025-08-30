import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:petrol_pump/api/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import '../models/fuel_type_model.dart';
import '../utils/jwt_decoder.dart';
import 'api_response.dart';

class FuelTypeRepository {
  // Get auth token from SharedPreferences
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      developer.log('FuelTypeRepository: Retrieved auth token: ${token != null ? 'Token exists' : 'No token found'}');
      return token;
    } catch (e) {
      developer.log('FuelTypeRepository: Error getting auth token: $e');
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
      developer.log('FuelTypeRepository: Added auth token to headers');
    } else {
      developer.log('FuelTypeRepository: Warning - No auth token available');
    }
    
    return headers;
  }

  // Get all fuel types for the current petrol pump
  Future<ApiResponse<List<FuelType>>> getFuelTypesByPetrolPump() async {
    developer.log('FuelTypeRepository: Getting fuel types for petrol pump');
    
    try {
      final url = ApiConstants.getFuelTypeByPetrolPumpUrl();
      developer.log('FuelTypeRepository: API URL: $url');
      
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      developer.log('FuelTypeRepository: Response status code: ${response.statusCode}');
      developer.log('FuelTypeRepository: Response body: ${response.body}');

      if (response.statusCode == ApiConstants.statusOk) {
        // Handle different response formats
        final responseData = json.decode(response.body);
        List<dynamic> fuelTypesJson = [];
        
        // Check if response follows the standard API format with data field
        if (responseData is Map<String, dynamic> && responseData.containsKey('data')) {
          developer.log('FuelTypeRepository: Response contains data field');
          fuelTypesJson = responseData['data'] as List;
        } else if (responseData is List) {
          // Direct list response
          developer.log('FuelTypeRepository: Response is a direct list');
          fuelTypesJson = responseData;
        }
        
        developer.log('FuelTypeRepository: Parsed ${fuelTypesJson.length} fuel types');
        
        final fuelTypes = fuelTypesJson
            .map((json) => FuelType.fromJson(json))
            .toList();
        
        // Debug: Check parsed data
        for (var fuelType in fuelTypes) {
          developer.log('FuelTypeRepository: Parsed fuel type - ID: ${fuelType.fuelTypeId}, Name: ${fuelType.name}');
        }
        
        return ApiResponse<List<FuelType>>(
          success: true,
          data: fuelTypes,
        );
      } else {
        developer.log('FuelTypeRepository: Error fetching fuel types: ${response.statusCode}');
        return ApiResponse<List<FuelType>>(
          success: false,
          errorMessage: 'Failed to fetch fuel types: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('FuelTypeRepository: Exception when fetching fuel types: $e');
      return ApiResponse<List<FuelType>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }
} 