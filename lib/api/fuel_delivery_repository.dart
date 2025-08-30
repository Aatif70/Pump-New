import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

import 'api_constants.dart';
import 'api_service.dart';
import '../models/fuel_delivery_model.dart';
import '../utils/jwt_decoder.dart';

class FuelDeliveryRepository {
  final ApiService _apiService = ApiService();

  // Add a new fuel delivery
  Future<ApiResponse<Map<String, dynamic>>> addFuelDelivery(FuelDelivery fuelDelivery) async {
    developer.log('Adding fuel delivery with details: ${fuelDelivery.toJson()}');
    print('FUEL_DELIVERY_REPO: Adding fuel delivery: ${fuelDelivery.toJson()}');
    print('REQUEST PAYLOAD:');
    print('---------------');
    print('deliveryDate: ${fuelDelivery.deliveryDate.toIso8601String()}');
    print('fuelTankId: ${fuelDelivery.fuelTankId}');
    print('invoiceNumber: ${fuelDelivery.invoiceNumber}');
    print('quantityReceived: ${fuelDelivery.quantityReceived}');
    print('supplierId: ${fuelDelivery.supplierId}');
    print('density: ${fuelDelivery.density}');
    print('temperature: ${fuelDelivery.temperature}');
    print('notes: ${fuelDelivery.notes ?? "EMPTY"}');
    print('---------------');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for adding fuel delivery');
        print('FUEL_DELIVERY_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      final url = ApiConstants.getFuelDeliveryUrl();
      print('FUEL_DELIVERY_REPO: POST URL: $url');
      
      // Make the API call
      final response = await _apiService.post<Map<String, dynamic>>(
        url,
        body: fuelDelivery.toJson(),
        token: token,
        fromJson: (json) => json as Map<String, dynamic>,
      );
      
      print('RESPONSE:');
      print('---------------');
      print('Success: ${response.success}');
      print('Data: ${response.data}');
      print('Error Message: ${response.errorMessage ?? "NONE"}');
      print('---------------');
      
      if (response.success) {
        developer.log('Fuel delivery added successfully');
        print('FUEL_DELIVERY_REPO: Fuel delivery added successfully. Response: ${response.data}');
      } else {
        developer.log('Failed to add fuel delivery: ${response.errorMessage}');
        print('FUEL_DELIVERY_REPO: Failed to add fuel delivery: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in addFuelDelivery: $e');
      print('FUEL_DELIVERY_REPO: Exception in addFuelDelivery: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Get all fuel deliveries for the logged-in petrol pump
  Future<ApiResponse<List<FuelDelivery>>> getAllFuelDeliveries() async {
    developer.log('Getting all fuel deliveries');
    print('FUEL_DELIVERY_REPO: Fetching all fuel deliveries.');

    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting fuel deliveries');
        print('FUEL_DELIVERY_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Get petrol pump ID for logging purposes
      final petrolPumpId = await getPetrolPumpId();
      developer.log('Fetching fuel deliveries for petrol pump ID: $petrolPumpId');
      
      final url = ApiConstants.getFuelDeliveriesByPumpUrl();
      developer.log('Fuel Deliveries GET URL: $url');
      print('FUEL_DELIVERY_REPO: GET URL: $url');
      
      // Make the API call using the generic GET method
      final response = await _apiService.get<List<FuelDelivery>>(
        url,
        token: token,
        fromJson: (json) {
          print('FUEL_DELIVERY_REPO: Parsing response data: $json');
          // Expecting the structure: {"data": [...], "success": true, ...}
          if (json is Map && json.containsKey('data') && json['data'] is List) {
            final dataList = json['data'] as List;
            print('FUEL_DELIVERY_REPO: Found ${dataList.length} fuel deliveries in response data.');
            return dataList.map((item) {
              try {
                // Ensure item is a Map before passing to fromJson
                if (item is Map<String, dynamic>) {
                  return FuelDelivery.fromJson(item);
                } else {
                  print('FUEL_DELIVERY_REPO: Skipping item because it is not a Map: $item');
                  return null; // Skip non-map items
                }
              } catch (e, stacktrace) {
                 print('FUEL_DELIVERY_REPO: Error parsing individual fuel delivery: $item, Error: $e');
                 print('FUEL_DELIVERY_REPO: Stacktrace: $stacktrace');
                 return null; // Indicate parsing failure
              }
            }).whereType<FuelDelivery>().toList(); // Filter out nulls from parsing errors or non-maps
          } else if (json is List) {
             // Handle cases where the API might *just* return a list (less common for wrapped responses)
             print('FUEL_DELIVERY_REPO: Response data is a direct list. Found ${json.length} items.');
             return json.map((item) {
               try {
                 if (item is Map<String, dynamic>) {
                    return FuelDelivery.fromJson(item);
                 } else {
                   print('FUEL_DELIVERY_REPO: Skipping item from list because it is not a Map: $item');
                   return null;
                 }
               } catch (e, stacktrace) {
                 print('FUEL_DELIVERY_REPO: Error parsing individual fuel delivery from list: $item, Error: $e');
                 print('FUEL_DELIVERY_REPO: Stacktrace: $stacktrace');
                 return null;
               }
             }).whereType<FuelDelivery>().toList();
          }
          // If response format is unexpected
          print('FUEL_DELIVERY_REPO: Unexpected response format, returning empty list. Format was: ${json.runtimeType}');
          return <FuelDelivery>[];
        },
      );
      
      if (response.success) {
        developer.log('Fuel deliveries retrieved successfully. Count: ${response.data?.length ?? 0}');
        print('FUEL_DELIVERY_REPO: Successfully retrieved ${response.data?.length ?? 0} fuel deliveries.');
      } else {
        developer.log('Failed to retrieve fuel deliveries: ${response.errorMessage}');
        print('FUEL_DELIVERY_REPO: Failed to retrieve fuel deliveries: ${response.errorMessage}');
      }
      
      return response;
    } catch (e, stacktrace) {
      developer.log('Exception in getAllFuelDeliveries: $e');
      print('FUEL_DELIVERY_REPO: Exception in getAllFuelDeliveries: $e');
      print('FUEL_DELIVERY_REPO: Stacktrace: $stacktrace');
      return ApiResponse(
        success: false,
        errorMessage: 'An error occurred while fetching fuel deliveries: $e',
      );
    }
  }

  // New method to get all fuel delivery orders for the logged-in petrol pump
  Future<ApiResponse<List<FuelDeliveryOrder>>> getAllFuelDeliveryOrders() async {
    developer.log('Getting all fuel delivery orders');
    print('FUEL_DELIVERY_REPO: Fetching all fuel delivery orders.');

    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting fuel delivery orders');
        print('FUEL_DELIVERY_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Get petrol pump ID
      final petrolPumpId = await getPetrolPumpId();
      if (petrolPumpId == null) {
        developer.log('Petrol pump ID not found');
        print('FUEL_DELIVERY_REPO: Petrol pump ID not found.');
        return ApiResponse(
          success: false,
          errorMessage: 'Petrol pump ID not found. Please login again.',
        );
      }
      
      // Construct the URL with the petrol pump ID
      final url = '${ApiConstants.baseUrl}/api/FuelDeliveryOrder/petrol-pump/$petrolPumpId';
      developer.log('Fuel Delivery Orders GET URL: $url');
      print('FUEL_DELIVERY_REPO: GET URL: $url');
      
      // Make the API call using the generic GET method
      final response = await _apiService.get<List<FuelDeliveryOrder>>(
        url,
        token: token,
        fromJson: (json) {
          print('FUEL_DELIVERY_REPO: Parsing response data: $json');
          
          // Handle direct list response format
          if (json is List) {
            print('FUEL_DELIVERY_REPO: Processing direct list response with ${json.length} items');
            return json.map((item) {
              try {
                if (item is Map<String, dynamic>) {
                  return FuelDeliveryOrder.fromJson(item);
                } else {
                  print('FUEL_DELIVERY_REPO: Skipping item from list because it is not a Map: $item');
                  return null;
                }
              } catch (e, stacktrace) {
                print('FUEL_DELIVERY_REPO: Error parsing individual fuel delivery order: $item, Error: $e');
                print('FUEL_DELIVERY_REPO: Stacktrace: $stacktrace');
                return null;
              }
            }).whereType<FuelDeliveryOrder>().toList();
          }
          // Handle wrapped response format with data field
          else if (json is Map && json.containsKey('data') && json['data'] is List) {
            final dataList = json['data'] as List;
            print('FUEL_DELIVERY_REPO: Found ${dataList.length} fuel delivery orders in wrapped response data.');
            return dataList.map((item) {
              try {
                if (item is Map<String, dynamic>) {
                  return FuelDeliveryOrder.fromJson(item);
                } else {
                  print('FUEL_DELIVERY_REPO: Skipping item because it is not a Map: $item');
                  return null;
                }
              } catch (e, stacktrace) {
                print('FUEL_DELIVERY_REPO: Error parsing individual fuel delivery order: $item, Error: $e');
                print('FUEL_DELIVERY_REPO: Stacktrace: $stacktrace');
                return null;
              }
            }).whereType<FuelDeliveryOrder>().toList();
          }
          
          // If response format is unexpected
          print('FUEL_DELIVERY_REPO: Unexpected response format, returning empty list. Format was: ${json.runtimeType}');
          return <FuelDeliveryOrder>[];
        },
      );
      
      if (response.success) {
        developer.log('Fuel delivery orders retrieved successfully. Count: ${response.data?.length ?? 0}');
        print('FUEL_DELIVERY_REPO: Successfully retrieved ${response.data?.length ?? 0} fuel delivery orders.');
      } else {
        developer.log('Failed to retrieve fuel delivery orders: ${response.errorMessage}');
        print('FUEL_DELIVERY_REPO: Failed to retrieve fuel delivery orders: ${response.errorMessage}');
      }
      
      return response;
    } catch (e, stacktrace) {
      developer.log('Exception in getAllFuelDeliveryOrders: $e');
      print('FUEL_DELIVERY_REPO: Exception in getAllFuelDeliveryOrders: $e');
      print('FUEL_DELIVERY_REPO: Stacktrace: $stacktrace');
      return ApiResponse(
        success: false,
        errorMessage: 'An error occurred while fetching fuel delivery orders: $e',
      );
    }
  }

  // Get the petrol pump ID from the JWT token
  Future<String?> getPetrolPumpId() async {
    print('FUEL_DELIVERY_REPO: Attempting to get Petrol Pump ID.');
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting petrol pump ID');
        print('FUEL_DELIVERY_REPO: No auth token found for getPetrolPumpId.');
        return null;
      }
      
      // Extract petrolPumpId from token
      final petrolPumpId = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
      
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        developer.log('PetrolPumpId not found in JWT token');
        print('FUEL_DELIVERY_REPO: PetrolPumpId not found in JWT. Checking prefs...');
        // Fallback to a stored ID if available
        final storedId = prefs.getString('petrolPumpId');
        print('FUEL_DELIVERY_REPO: Found stored PetrolPumpId: $storedId');
        return storedId;
      }
      
      developer.log('PetrolPumpId extracted from JWT token: $petrolPumpId');
      print('FUEL_DELIVERY_REPO: PetrolPumpId from JWT: $petrolPumpId');
      
      // Store for later use if extracted from JWT
      await prefs.setString('petrolPumpId', petrolPumpId);
      print('FUEL_DELIVERY_REPO: Stored PetrolPumpId in prefs.');
      
      return petrolPumpId;
    } catch (e, stacktrace) {
      developer.log('Error getting petrol pump ID: $e');
      print('FUEL_DELIVERY_REPO: Error in getPetrolPumpId: $e');
      print('FUEL_DELIVERY_REPO: Stacktrace: $stacktrace');
      return null;
    }
  }
} 