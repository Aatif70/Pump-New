import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

import '../models/fuel_dispenser_model.dart';
import 'api_constants.dart';
import 'api_service.dart';
import '../utils/jwt_decoder.dart';

class FuelDispenserRepository {
  final ApiService _apiService = ApiService();
  
  // Get all fuel dispensers
  Future<ApiResponse<List<FuelDispenser>>> getFuelDispensers() async {
    developer.log('Getting all fuel dispensers');
    print('FUEL_DISPENSER_REPO: Fetching all fuel dispensers.');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting fuel dispensers');
        print('FUEL_DISPENSER_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      final url = ApiConstants.getFuelDispenserUrl();
      developer.log('Fuel Dispensers GET URL: $url');
      print('FUEL_DISPENSER_REPO: GET URL: $url');
      
      // Make the API call using the generic GET method
      final response = await _apiService.get<List<FuelDispenser>>(
        url,
        token: token,
        fromJson: (json) {
          print('FUEL_DISPENSER_REPO: Parsing response data: $json');
          
          if (json is Map && json.containsKey('data') && json['data'] is List) {
            final dataList = json['data'] as List;
            print('FUEL_DISPENSER_REPO: Found ${dataList.length} fuel dispensers in response data.');
            return dataList.map((item) {
              try {
                if (item is Map<String, dynamic>) {
                  return FuelDispenser.fromJson(item);
                } else {
                  print('FUEL_DISPENSER_REPO: Skipping item because it is not a Map: $item');
                  return null;
                }
              } catch (e) {
                print('FUEL_DISPENSER_REPO: Error parsing individual dispenser: $item, Error: $e');
                return null;
              }
            }).whereType<FuelDispenser>().toList();
          } else if (json is List) {
            // Handle direct list response
            print('FUEL_DISPENSER_REPO: Response data is a direct list. Found ${json.length} items.');
            return json.map((item) {
              try {
                if (item is Map<String, dynamic>) {
                  return FuelDispenser.fromJson(item);
                } else {
                  print('FUEL_DISPENSER_REPO: Skipping item from list because it is not a Map: $item');
                  return null;
                }
              } catch (e) {
                print('FUEL_DISPENSER_REPO: Error parsing individual dispenser from list: $item, Error: $e');
                return null;
              }
            }).whereType<FuelDispenser>().toList();
          }
          
          // If response format is unexpected
          print('FUEL_DISPENSER_REPO: Unexpected response format, returning empty list. Format was: ${json.runtimeType}');
          return <FuelDispenser>[];
        },
      );
      
      if (response.success) {
        developer.log('Fuel dispensers retrieved successfully. Count: ${response.data?.length ?? 0}');
        print('FUEL_DISPENSER_REPO: Successfully retrieved ${response.data?.length ?? 0} fuel dispensers.');
      } else {
        developer.log('Failed to retrieve fuel dispensers: ${response.errorMessage}');
        print('FUEL_DISPENSER_REPO: Failed to retrieve fuel dispensers: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in getFuelDispensers: $e');
      print('FUEL_DISPENSER_REPO: Exception in getFuelDispensers: $e');
      return ApiResponse(
        success: false,
        errorMessage: 'An error occurred while fetching fuel dispensers: $e',
      );
    }
  }
  
  // Get fuel dispensers by petrol pump ID
  Future<ApiResponse<List<FuelDispenser>>> getFuelDispensersByPetrolPumpId(String petrolPumpId) async {
    developer.log('Getting fuel dispensers for petrol pump ID: $petrolPumpId');
    print('FUEL_DISPENSER_REPO: Fetching fuel dispensers for petrol pump ID: $petrolPumpId');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting fuel dispensers by petrol pump ID');
        print('FUEL_DISPENSER_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      final url = ApiConstants.getFuelDispenserByPetrolPumpIdUrl(petrolPumpId);
      print('FUEL_DISPENSER_REPO: GET URL for petrol pump ID $petrolPumpId: $url');
      
      // Make the API call
      final response = await _apiService.get<List<FuelDispenser>>(
        url,
        token: token,
        fromJson: (json) {
          print('FUEL_DISPENSER_REPO: Parsing response data for petrol pump ID $petrolPumpId: $json');
          
          List<FuelDispenser> dispensers = [];
          
          if (json is Map && json.containsKey('data') && json['data'] is List) {
            final dataList = json['data'] as List;
            print('FUEL_DISPENSER_REPO: Found ${dataList.length} fuel dispensers for petrol pump ID $petrolPumpId');
            
            dispensers = dataList.map((item) {
              try {
                return FuelDispenser.fromJson(Map<String, dynamic>.from(item as Map));
              } catch (e) {
                print('FUEL_DISPENSER_REPO: Error parsing dispenser: $e');
                return null;
              }
            }).whereType<FuelDispenser>().toList();
          } else if (json is List) {
            print('FUEL_DISPENSER_REPO: Response is a direct list with ${json.length} items');
            
            dispensers = json.map((item) {
              try {
                return FuelDispenser.fromJson(Map<String, dynamic>.from(item as Map));
              } catch (e) {
                print('FUEL_DISPENSER_REPO: Error parsing dispenser from list: $e');
                return null;
              }
            }).whereType<FuelDispenser>().toList();
          }
          
          return dispensers;
        },
      );
      
      if (response.success) {
        developer.log('Fuel dispensers for petrol pump ID $petrolPumpId retrieved successfully. Count: ${response.data?.length ?? 0}');
        print('FUEL_DISPENSER_REPO: Successfully retrieved ${response.data?.length ?? 0} dispensers for petrol pump ID $petrolPumpId');
      } else {
        developer.log('Failed to retrieve fuel dispensers for petrol pump ID $petrolPumpId: ${response.errorMessage}');
        print('FUEL_DISPENSER_REPO: Failed to retrieve dispensers for petrol pump ID $petrolPumpId: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in getFuelDispensersByPetrolPumpId: $e');
      print('FUEL_DISPENSER_REPO: Exception in getFuelDispensersByPetrolPumpId: $e');
      return ApiResponse(
        success: false,
        errorMessage: 'An error occurred while fetching fuel dispensers by petrol pump ID: $e',
      );
    }
  }
  
  // Get petrol pump ID
  Future<String?> getPetrolPumpId() async {
    print('FUEL_DISPENSER_REPO: Attempting to get Petrol Pump ID.');
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting petrol pump ID');
        print('FUEL_DISPENSER_REPO: No auth token found for getPetrolPumpId.');
        return null;
      }
      
      // Extract petrolPumpId from token
      final petrolPumpId = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
      
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        developer.log('PetrolPumpId not found in JWT token');
        print('FUEL_DISPENSER_REPO: PetrolPumpId not found in JWT. Checking prefs...');
        // Fallback to a stored ID if available
        final storedId = prefs.getString('petrolPumpId');
        print('FUEL_DISPENSER_REPO: Found stored PetrolPumpId: $storedId');
        return storedId;
      }
      
      developer.log('PetrolPumpId extracted from JWT token: $petrolPumpId');
      print('FUEL_DISPENSER_REPO: PetrolPumpId from JWT: $petrolPumpId');
      
      // Store for later use if extracted from JWT
      await prefs.setString('petrolPumpId', petrolPumpId);
      print('FUEL_DISPENSER_REPO: Stored PetrolPumpId in prefs.');
      
      return petrolPumpId;
    } catch (e, stacktrace) {
      developer.log('Error getting petrol pump ID: $e');
      print('FUEL_DISPENSER_REPO: Error in getPetrolPumpId: $e');
      print('FUEL_DISPENSER_REPO: Stacktrace: $stacktrace');
      return null;
    }
  }
  
  // Add a new fuel dispenser
  Future<ApiResponse<FuelDispenser>> addFuelDispenser(FuelDispenser dispenser) async {
    developer.log('Adding fuel dispenser with details: ${dispenser.toJson()}');
    print('FUEL_DISPENSER_REPO: Adding fuel dispenser: ${dispenser.toJson()}');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for adding fuel dispenser');
        print('FUEL_DISPENSER_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      final url = ApiConstants.getFuelDispenserUrl();
      print('FUEL_DISPENSER_REPO: POST URL: $url');
      
      // Create payload according to the API spec - remove fuelType to allow mixed nozzle types
      final payload = {
        'dispenserNumber': dispenser.dispenserNumber.toString(),
        'numberOfNozzles': dispenser.numberOfNozzles.toString(),
        'status': dispenser.status,
        'fuelType': dispenser.fuelType ?? "<string>",
      };
      
      print('FUEL_DISPENSER_REPO: Request body: ${json.encode(payload)}');
      
      // Make the API call with payload
      final response = await _apiService.post<FuelDispenser>(
        url,
        body: payload,
        token: token,
        fromJson: (json) {
          print('FUEL_DISPENSER_REPO: Response from add dispenser: $json');
          return FuelDispenser.fromJson(json);
        },
      );
      
      if (response.success) {
        developer.log('Fuel dispenser added successfully');
        print('FUEL_DISPENSER_REPO: Fuel dispenser added successfully. Response: ${response.data}');
      } else {
        developer.log('Failed to add fuel dispenser: ${response.errorMessage}');
        print('FUEL_DISPENSER_REPO: Failed to add fuel dispenser: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in addFuelDispenser: $e');
      print('FUEL_DISPENSER_REPO: Exception in addFuelDispenser: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Get fuel dispenser by ID
  Future<ApiResponse<FuelDispenser>> getFuelDispenserById(String id) async {
    developer.log('Getting fuel dispenser by ID: $id');
    print('FUEL_DISPENSER_REPO: Fetching fuel dispenser with ID: $id');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting fuel dispenser by ID');
        print('FUEL_DISPENSER_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      final url = ApiConstants.getFuelDispenserByIdUrl(id);
      print('FUEL_DISPENSER_REPO: GET URL for ID $id: $url');
      
      // Make the API call
      final response = await _apiService.get<FuelDispenser>(
        url,
        token: token,
        fromJson: (json) {
          print('FUEL_DISPENSER_REPO: Response for dispenser ID $id: $json');
          
          if (json is Map<String, dynamic>) {
            return FuelDispenser.fromJson(json);
          } else if (json is Map && json.containsKey('data') && json['data'] is Map) {
            return FuelDispenser.fromJson(Map<String, dynamic>.from(json['data'] as Map));
          }
          
          print('FUEL_DISPENSER_REPO: Unexpected response format for dispenser ID $id');
          throw Exception('Unexpected response format when getting fuel dispenser by ID');
        },
      );
      
      if (response.success) {
        developer.log('Fuel dispenser retrieved successfully');
        print('FUEL_DISPENSER_REPO: Fuel dispenser retrieved successfully.');
      } else {
        developer.log('Failed to get fuel dispenser: ${response.errorMessage}');
        print('FUEL_DISPENSER_REPO: Failed to get fuel dispenser: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in getFuelDispenserById: $e');
      print('FUEL_DISPENSER_REPO: Exception in getFuelDispenserById: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Update a fuel dispenser
  Future<ApiResponse<FuelDispenser>> updateFuelDispenser(FuelDispenser dispenser) async {
    if (dispenser.id == null) {
      return ApiResponse(
        success: false,
        errorMessage: 'Dispenser ID cannot be null',
      );
    }

    try {
      final token = await SharedPreferences.getInstance().then((prefs) => prefs.getString(ApiConstants.authTokenKey));
      final petrolPumpId = JwtDecoder.getClaim<String>(token!, 'petrolPumpId');

      // Ensure numberOfNozzles is within valid range (1-6)
      int validNozzleCount = dispenser.numberOfNozzles;
      if (validNozzleCount < 1) {
        print('FUEL_DISPENSER_REPO: Correcting invalid nozzle count (${dispenser.numberOfNozzles}) to 1');
        validNozzleCount = 1;
      } else if (validNozzleCount > 6) {
        print('FUEL_DISPENSER_REPO: Correcting invalid nozzle count (${dispenser.numberOfNozzles}) to 6');
        validNozzleCount = 6;
      }
      
      // Create payload with default fuelType value of <string> for all updates
      final payload = {
        'dispenserNumber': dispenser.dispenserNumber,
        'fuelDispenserUnitId': dispenser.id,
        'numberOfNozzles': validNozzleCount,
        'status': dispenser.status,
        'fuelType': "<string>", // Always use <string> as requested
      };
      
      final url = ApiConstants.getUpdateFuelDispenserUrl();
      
      // Log the URL and request body for debugging
      print('PUT URL: $url');
      print('Request body: ${json.encode(payload)}');

      final response = await _apiService.put<FuelDispenser>(
        url,
        body: payload,
        token: token,
        fromJson: (json) => FuelDispenser.fromJson(json),
      );

      return response;
    } catch (e) {
      developer.log('Exception in updateFuelDispenser: $e');
      print('FUEL_DISPENSER_REPO: Exception in updateFuelDispenser: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Delete a fuel dispenser
  Future<ApiResponse<bool>> deleteFuelDispenser(String id) async {
    developer.log('Deleting fuel dispenser with ID: $id');
    print('FUEL_DISPENSER_REPO: Deleting fuel dispenser ID: $id');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for deleting fuel dispenser');
        print('FUEL_DISPENSER_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      final url = ApiConstants.getFuelDispenserByIdUrl(id);
      print('FUEL_DISPENSER_REPO: DELETE URL: $url');
      
      // Make the API call
      final response = await _apiService.delete<bool>(
        url,
        token: token,
        fromJson: (json) => true, // Just return true for success
      );
      
      if (response.success) {
        developer.log('Fuel dispenser deleted successfully');
        print('FUEL_DISPENSER_REPO: Fuel dispenser deleted successfully.');
      } else {
        developer.log('Failed to delete fuel dispenser: ${response.errorMessage}');
        print('FUEL_DISPENSER_REPO: Failed to delete fuel dispenser: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in deleteFuelDispenser: $e');
      print('FUEL_DISPENSER_REPO: Exception in deleteFuelDispenser: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
} 