import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_constants.dart';
import 'api_response.dart';
import '../models/daily_sales_model.dart';
import '../models/sales_by_fuel_type_model.dart';
import '../models/inventory_status_model.dart';
import '../models/consumption_rate_model.dart';
import '../models/fuel_type_model.dart';
import '../utils/jwt_decoder.dart';

class DashboardRepository {
  // Get auth token from SharedPreferences
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      developer.log('DashboardRepository: Retrieved auth token: ${token != null ? 'Token exists' : 'No token found'}');
      return token;
    } catch (e) {
      developer.log('DashboardRepository: Error getting auth token: $e');
      return null;
    }
  }

  // Get petrol pump ID from JWT token
  Future<String?> getPetrolPumpId() async {
    try {
      developer.log('DashboardRepository: Attempting to get Petrol Pump ID from JWT token');
      
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('DashboardRepository: No auth token found for getting petrol pump ID');
        return null;
      }
      
      // Extract petrolPumpId from token
      final petrolPumpId = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
      
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        developer.log('DashboardRepository: PetrolPumpId not found in JWT token');
        // Fallback to stored value if available
        return prefs.getString('petrolPumpId');
      }
      
      developer.log('DashboardRepository: PetrolPumpId from token: $petrolPumpId');
      
      // Cache the petrolPumpId for later use
      await prefs.setString('petrolPumpId', petrolPumpId);
      
      return petrolPumpId;
    } catch (e) {
      developer.log('DashboardRepository: Error getting petrol pump ID: $e');
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
      developer.log('DashboardRepository: Added auth token to headers');
    } else {
      developer.log('DashboardRepository: Warning - No auth token available');
    }
    
    return headers;
  }
  
  // Get daily sales for a specific date
  Future<ApiResponse<DailySalesData>> getDailySales(DateTime date) async {
    try {
      final formattedDate = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").format(date);
      
      // Get petrol pump ID from JWT token
      final petrolPumpId = await getPetrolPumpId();
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        developer.log('DashboardRepository: Failed to get petrol pump ID for daily sales');
        return ApiResponse<DailySalesData>(
          success: false,
          errorMessage: 'Petrol pump ID not found. Please login again.',
        );
      }
      
      final url = '${ApiConstants.baseUrl}/api/Dashboard/sales/daily?date=$formattedDate&petrolPumpId=$petrolPumpId';
      
      developer.log('DashboardRepository: Getting daily sales for date: $formattedDate, petrolPumpId: $petrolPumpId');
      
      // Use authentication headers
      final headers = await _getHeaders();
      
      // Use http package directly to avoid ApiResponse conflicts
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        developer.log('DashboardRepository: Successfully fetched daily sales');
        return ApiResponse<DailySalesData>(
          success: true,
          data: DailySalesData.fromJson(jsonData),
        );
      } else {
        developer.log('DashboardRepository: Failed to fetch daily sales: ${response.statusCode} - ${response.body}');
        return ApiResponse<DailySalesData>(
          success: false,
          errorMessage: 'Failed to load daily sales. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('DashboardRepository: Exception getting daily sales: $e');
      return ApiResponse<DailySalesData>(
        success: false,
        errorMessage: 'Exception occurred: $e',
      );
    }
  }
  
  // Get sales by fuel type for a date range
  Future<ApiResponse<SalesByFuelType>> getSalesByFuelType(DateTime startDate, DateTime endDate) async {
    try {
      final formattedStartDate = DateFormat('yyyy-MM-dd').format(startDate);
      final formattedEndDate = DateFormat('yyyy-MM-dd').format(endDate);
      
      // Get petrol pump ID from JWT token
      final petrolPumpId = await getPetrolPumpId();
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        developer.log('DashboardRepository: Failed to get petrol pump ID for sales by fuel type');
        return ApiResponse<SalesByFuelType>(
          success: false,
          errorMessage: 'Petrol pump ID not found. Please login again.',
        );
      }
      
      final url = '${ApiConstants.baseUrl}/api/Dashboard/sales/by-fuel-type?startDate=$formattedStartDate&endDate=$formattedEndDate&petrolPumpId=$petrolPumpId';
      
      developer.log('DashboardRepository: Getting sales by fuel type from $formattedStartDate to $formattedEndDate for petrolPumpId: $petrolPumpId');
      
      // Use authentication headers
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        developer.log('DashboardRepository: Successfully fetched sales by fuel type');
        return ApiResponse<SalesByFuelType>(
          success: true,
          data: SalesByFuelType.fromJson(jsonData),
        );
      } else {
        developer.log('DashboardRepository: Failed to fetch sales by fuel type: ${response.statusCode} - ${response.body}');
        return ApiResponse<SalesByFuelType>(
          success: false,
          errorMessage: 'Failed to load sales by fuel type. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('DashboardRepository: Exception getting sales by fuel type: $e');
      return ApiResponse<SalesByFuelType>(
        success: false,
        errorMessage: 'Exception occurred: $e',
      );
    }
  }
  
  // Get inventory status
  Future<ApiResponse<List<InventoryStatus>>> getInventoryStatus() async {
    try {
      final url = '${ApiConstants.baseUrl}/api/Dashboard/inventory/status';
      
      developer.log('DashboardRepository: Getting inventory status');
      
      // Use authentication headers
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        // Check if the response is a list or a single object
        List<InventoryStatus> inventoryList = [];
        
        if (jsonData is List) {
          inventoryList = jsonData.map((item) => InventoryStatus.fromJson(item)).toList();
        } else {
          // If it's a single object, add it to the list
          inventoryList.add(InventoryStatus.fromJson(jsonData));
        }
        
        developer.log('DashboardRepository: Successfully fetched inventory status');
        return ApiResponse<List<InventoryStatus>>(
          success: true,
          data: inventoryList,
        );
      } else {
        developer.log('DashboardRepository: Failed to fetch inventory status: ${response.statusCode} - ${response.body}');
        return ApiResponse<List<InventoryStatus>>(
          success: false,
          errorMessage: 'Failed to load inventory status. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('DashboardRepository: Exception getting inventory status: $e');
      return ApiResponse<List<InventoryStatus>>(
        success: false,
        errorMessage: 'Exception occurred: $e',
      );
    }
  }
  
  // Get consumption rates
  Future<ApiResponse<List<ConsumptionRate>>> getConsumptionRates(int days) async {
    try {
      final url = '${ApiConstants.baseUrl}/api/Dashboard/inventory/consumption-rates?days=$days';
      
      developer.log('DashboardRepository: Getting consumption rates for $days days');
      
      // Use authentication headers
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        final List<ConsumptionRate> consumptionRates = (jsonData as List)
            .map((item) => ConsumptionRate.fromJson(item))
            .toList();
        
        developer.log('DashboardRepository: Successfully fetched consumption rates');
        return ApiResponse<List<ConsumptionRate>>(
          success: true,
          data: consumptionRates,
        );
      } else {
        developer.log('DashboardRepository: Failed to fetch consumption rates: ${response.statusCode} - ${response.body}');
        return ApiResponse<List<ConsumptionRate>>(
          success: false,
          errorMessage: 'Failed to load consumption rates. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('DashboardRepository: Exception getting consumption rates: $e');
      return ApiResponse<List<ConsumptionRate>>(
        success: false,
        errorMessage: 'Exception occurred: $e',
      );
    }
  }

  // Get fuel types for the petrol pump
  Future<ApiResponse<List<FuelType>>> getFuelTypes() async {
    try {
      // Get petrol pump ID from JWT token
      final petrolPumpId = await getPetrolPumpId();
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        developer.log('DashboardRepository: Failed to get petrol pump ID for fuel types');
        return ApiResponse<List<FuelType>>(
          success: false,
          errorMessage: 'Petrol pump ID not found. Please login again.',
        );
      }
      
      final url = '${ApiConstants.baseUrl}/api/FuelType/petrolpump/$petrolPumpId';
      
      developer.log('DashboardRepository: Getting fuel types for petrol pump ID: $petrolPumpId');
      
      // Use authentication headers
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        // Handle response structure where fuel types are in a "data" field
        List<dynamic> fuelTypesList;
        if (jsonData is Map && jsonData.containsKey('data')) {
          fuelTypesList = jsonData['data'] as List;
          developer.log('DashboardRepository: Found fuel types in data field, count: ${fuelTypesList.length}');
        } else if (jsonData is List) {
          fuelTypesList = jsonData;
          developer.log('DashboardRepository: Found fuel types in direct list, count: ${fuelTypesList.length}');
        } else {
          developer.log('DashboardRepository: Unexpected response format: ${jsonData.runtimeType}');
          return ApiResponse<List<FuelType>>(
            success: false,
            errorMessage: 'Unexpected response format for fuel types',
          );
        }
        
        final List<FuelType> fuelTypes = fuelTypesList
            .map((item) => FuelType.fromJson(item as Map<String, dynamic>))
            .toList();
        
        developer.log('DashboardRepository: Successfully fetched ${fuelTypes.length} fuel types');
        return ApiResponse<List<FuelType>>(
          success: true,
          data: fuelTypes,
        );
      } else {
        developer.log('DashboardRepository: Failed to fetch fuel types: ${response.statusCode} - ${response.body}');
        return ApiResponse<List<FuelType>>(
          success: false,
          errorMessage: 'Failed to load fuel types. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('DashboardRepository: Exception getting fuel types: $e');
      return ApiResponse<List<FuelType>>(
        success: false,
        errorMessage: 'Exception occurred: $e',
      );
    }
  }
}