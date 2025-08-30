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

  // Get all fuel types for a specific petrol pump
  Future<ApiResponse<List<FuelType>>> getFuelTypesByPetrolPump(String petrolPumpId) async {
    developer.log('FuelTypeRepository: Getting fuel types for petrol pump: $petrolPumpId');
    try {
      final url = ApiConstants.getPumpFuelTypesUrl(petrolPumpId);
      developer.log('FuelTypeRepository: API URL: $url');
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      developer.log('FuelTypeRepository: Response status code:  [32m${response.statusCode} [0m');
      developer.log('FuelTypeRepository: Response body: ${response.body}');
      if (response.statusCode == ApiConstants.statusOk) {
        final responseData = json.decode(response.body);
        List<dynamic> fuelTypesJson = [];
        if (responseData is Map<String, dynamic> && responseData.containsKey('data')) {
          fuelTypesJson = responseData['data'] as List;
        } else if (responseData is List) {
          fuelTypesJson = responseData;
        }
        final fuelTypes = fuelTypesJson.map((json) => FuelType.fromJson(json)).toList();
        return ApiResponse<List<FuelType>>(
          success: true,
          data: fuelTypes,
        );
      } else {
        return ApiResponse<List<FuelType>>(
          success: false,
          errorMessage: 'Failed to fetch fuel types: ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse<List<FuelType>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get all fuel types for the current petrol pump (auto-detect pumpId)
  Future<ApiResponse<List<FuelType>>> getAllFuelTypes() async {
    final token = await ApiConstants.getAuthToken();
    if (token == null) {
      return ApiResponse<List<FuelType>>(
        success: false,
        errorMessage: 'Authentication token not found',
      );
    }
    final pumpId = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
    if (pumpId == null || pumpId.isEmpty) {
      return ApiResponse<List<FuelType>>(
        success: false,
        errorMessage: 'Petrol pump ID not found. Please login again.',
      );
    }
    return await getFuelTypesByPetrolPump(pumpId);
  }
} 