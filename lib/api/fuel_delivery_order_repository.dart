import 'dart:convert';
import '../models/fuel_delivery_order_model.dart';
import 'api_service.dart';
import 'api_response.dart' as api_response_model;
import '../utils/shared_prefs.dart';
import 'api_constants.dart';

class FuelDeliveryOrderRepository {
  final ApiService _apiService = ApiService();
  final SharedPrefs _prefs = SharedPrefs();

  Future<api_response_model.ApiResponse<String>> createFuelDeliveryOrder(FuelDeliveryOrder order) async {
    try {
      final petrolPumpId = await SharedPrefs.getPumpId();
      
      if (petrolPumpId == null) {
        return api_response_model.ApiResponse<String>(
          success: false,
          errorMessage: 'Petrol pump ID not found',
        );
      }
      
      // Get the auth token - using correct method name
      final token = await SharedPrefs.getAuthToken();
      if (token == null || token.isEmpty) {
        print('===== AUTH ERROR =====');
        print('Authentication token is null or empty');
        return api_response_model.ApiResponse<String>(
          success: false,
          errorMessage: 'Authentication token not found. Please login again.',
        );
      }
      
      print('===== AUTH INFO =====');
      print('Token exists: ${token.isNotEmpty}');
      print('Token length: ${token.length}');
      
      // Convert order to JSON map
      final Map<String, dynamic> jsonMap = order.toJson();
      
      // Create a full URL with base URL and endpoint
      final String url = '${ApiConstants.baseUrl}/api/FuelDeliveryOrder/petrol-pump/$petrolPumpId';
      
      // Print the JSON data for debugging
      print('===== DEBUGGING API REQUEST =====');
      print('API Endpoint: $url');
      
      // Print the JSON as a formatted string to better see the structure
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonMap);
      print('Request Payload:');
      print(jsonString);
      
      final response = await _apiService.post<dynamic>(
        url,
        body: jsonMap,
        token: token, // Pass the token to the API service
        fromJson: (json) => json,
      );
      
      // Print the API response
      print('===== API RESPONSE =====');
      print('Success: ${response.success}');
      print('Error: ${response.errorMessage}');
      print('Data: ${response.data}');
      
      if (response.success) {
        return api_response_model.ApiResponse<String>(
          success: true,
          data: 'Fuel delivery order created successfully',
        );
      } else {
        return api_response_model.ApiResponse<String>(
          success: false,
          errorMessage: 'Failed to create fuel delivery order: ${response.errorMessage}',
        );
      }
    } catch (e) {
      print('===== REPOSITORY ERROR =====');
      print(e.toString());
      print(e.runtimeType);
      if (e is FormatException) {
        print('Format Exception Details: ${e.message}');
        print('Source: ${e.source}');
        print('Offset: ${e.offset}');
      }
      
      return api_response_model.ApiResponse<String>(
        success: false,
        errorMessage: 'Error creating fuel delivery order: ${e.toString()}',
      );
    }
  }
} 