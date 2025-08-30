import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_constants.dart';
import 'api_response.dart';
import '../models/customer_model.dart';
import '../utils/jwt_decoder.dart';

class CustomerRepository {
  
  // Get petrol pump ID from JWT token and SharedPreferences
  Future<String?> getPetrolPumpId() async {
    print('CUSTOMER_REPO: Attempting to get Petrol Pump ID.');
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting petrol pump ID');
        print('CUSTOMER_REPO: No auth token found for getPetrolPumpId.');
        return null;
      }
      
      // Extract petrolPumpId from token
      final petrolPumpId = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
      
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        developer.log('PetrolPumpId not found in JWT token');
        print('CUSTOMER_REPO: PetrolPumpId not found in JWT. Checking prefs...');
        // Fallback to a stored ID if available
        final storedId = prefs.getString('petrolPumpId');
        print('CUSTOMER_REPO: Found stored PetrolPumpId: $storedId');
        return storedId;
      }
      
      developer.log('PetrolPumpId extracted from JWT token: $petrolPumpId');
      print('CUSTOMER_REPO: PetrolPumpId from JWT: $petrolPumpId');
      
      // Store for later use if extracted from JWT
      await prefs.setString('petrolPumpId', petrolPumpId);
      print('CUSTOMER_REPO: Stored PetrolPumpId in prefs.');
      
      return petrolPumpId;
    } catch (e, stacktrace) {
      developer.log('Error getting petrol pump ID: $e');
      print('CUSTOMER_REPO: Error in getPetrolPumpId: $e');
      print('CUSTOMER_REPO: Stacktrace: $stacktrace');
      return null;
    }
  }

  // Get all customers for a specific petrol pump
  Future<ApiResponse<List<Customer>>> getCustomersByPump(String pumpId) async {
    try {
      final token = await ApiConstants.getAuthToken();
      if (token == null) {
        return ApiResponse<List<Customer>>(
          success: false,
          errorMessage: 'Authentication token not found',
        );
      }

      final url = ApiConstants.getCustomersByPumpUrl(pumpId);
      developer.log('Fetching customers for pump ID: $pumpId');
      developer.log('Request URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      developer.log('Response status: ${response.statusCode}');
      developer.log('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final List<dynamic> customersJson = jsonResponse['data'];
          final customers = customersJson
              .map((json) => Customer.fromJson(json))
              .toList();
          
          return ApiResponse<List<Customer>>(
            success: true,
            data: customers,
          );
        } else {
          return ApiResponse<List<Customer>>(
            success: false,
            errorMessage: jsonResponse['message'] ?? 'Failed to retrieve customers',
          );
        }
      } else if (response.statusCode == 401) {
        return ApiResponse<List<Customer>>(
          success: false,
          errorMessage: 'Unauthorized. Please login again.',
        );
      } else {
        return ApiResponse<List<Customer>>(
          success: false,
          errorMessage: 'Failed to retrieve customers. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('Error fetching customers: $e');
      return ApiResponse<List<Customer>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Add a new customer
  Future<ApiResponse<Customer>> addCustomer(Customer customer) async {
    try {
      final token = await ApiConstants.getAuthToken();
      if (token == null) {
        return ApiResponse<Customer>(
          success: false,
          errorMessage: 'Authentication token not found',
        );
      }

      final url = ApiConstants.getCustomersUrl();
      developer.log('Adding new customer');
      developer.log('Request URL: $url');
      developer.log('Request body: ${customer.toJson()}');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(customer.toJson()),
      );

      developer.log('Response status: ${response.statusCode}');
      developer.log('Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final customerData = Customer.fromJson(jsonResponse['data']);
          
          return ApiResponse<Customer>(
            success: true,
            data: customerData,
          );
        } else {
          return ApiResponse<Customer>(
            success: false,
            errorMessage: jsonResponse['message'] ?? 'Failed to add customer',
          );
        }
      } else if (response.statusCode == 401) {
        return ApiResponse<Customer>(
          success: false,
          errorMessage: 'Unauthorized. Please login again.',
        );
      } else if (response.statusCode == 400) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<Customer>(
          success: false,
          errorMessage: jsonResponse['message'] ?? 'Invalid request data',
        );
      } else {
        return ApiResponse<Customer>(
          success: false,
          errorMessage: 'Failed to add customer. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('Error adding customer: $e');
      return ApiResponse<Customer>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get all customers (using the current petrol pump ID)
  Future<ApiResponse<List<Customer>>> getAllCustomers() async {
    final pumpId = await getPetrolPumpId();
    if (pumpId == null) {
      return ApiResponse<List<Customer>>(
        success: false,
        errorMessage: 'Petrol pump ID not found. Please login again.',
      );
    }
    
    return await getCustomersByPump(pumpId);
  }
}
