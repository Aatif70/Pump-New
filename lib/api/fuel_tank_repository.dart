import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

import 'api_constants.dart';
import 'api_service.dart';
import '../models/fuel_tank_model.dart';
import '../models/fuel_type_model.dart';
import '../models/fuel_quality_check_model.dart';
import '../utils/jwt_decoder.dart';

class FuelTankRepository {
  final ApiService _apiService = ApiService();

  // Add a new fuel tank
  Future<ApiResponse<Map<String, dynamic>>> addFuelTank(FuelTank fuelTank) async {
    developer.log('Adding fuel tank with details: ${fuelTank.toJson()}');
    print('FUEL_TANK_REPO: Adding fuel tank: ${fuelTank.toJson()}');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for adding fuel tank');
        print('FUEL_TANK_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      final url = ApiConstants.getFuelTankUrl();
      print('FUEL_TANK_REPO: POST URL: $url');
      
      // Make the API call
      final response = await _apiService.post<Map<String, dynamic>>(
        url,
        body: fuelTank.toJson(),
        token: token,
        fromJson: (json) => json as Map<String, dynamic>,
      );
      
      if (response.success) {
        developer.log('Fuel tank added successfully');
        print('FUEL_TANK_REPO: Fuel tank added successfully. Response: ${response.data}');
      } else {
        developer.log('Failed to add fuel tank: ${response.errorMessage}');
        print('FUEL_TANK_REPO: Failed to add fuel tank: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in addFuelTank: $e');
      print('FUEL_TANK_REPO: Exception in addFuelTank: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Get all fuel tanks for the logged-in petrol pump
  Future<ApiResponse<List<FuelTank>>> getAllFuelTanks() async {
    developer.log('Getting all fuel tanks');
    print('FUEL_TANK_REPO: Fetching all fuel tanks.');

    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting fuel tanks');
        print('FUEL_TANK_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // The endpoint for getting all tanks is typically the base fuel tank URL
      // This assumes your ApiConstants.getFuelTankUrl() returns "{{baseUrl}}/api/FuelTank"
      final url = ApiConstants.getFuelTankUrl();
      developer.log('Fuel Tanks GET URL: $url');
      print('FUEL_TANK_REPO: GET URL: $url');
      
      // Make the API call using the generic GET method
      final response = await _apiService.get<List<FuelTank>>(
        url,
        token: token,
        fromJson: (json) {
          // print('FUEL_TANK_REPO: Parsing response data: $json');
          // Expecting the structure: {"data": [...], "success": true, ...}
          if (json is Map && json.containsKey('data') && json['data'] is List) {
            final dataList = json['data'] as List;
            print('FUEL_TANK_REPO: Found ${dataList.length} fuel tanks in response data.');
            return dataList.map((item) {
              try {
                // Ensure item is a Map before passing to fromJson
                if (item is Map<String, dynamic>) {
                  return FuelTank.fromJson(item);
                } else {
                  print('FUEL_TANK_REPO: Skipping item because it is not a Map: $item');
                  return null; // Skip non-map items
                }
              } catch (e, stacktrace) {
                 print('FUEL_TANK_REPO: Error parsing individual tank: $item, Error: $e');
                 print('FUEL_TANK_REPO: Stacktrace: $stacktrace');
                 return null; // Indicate parsing failure
              }
            }).whereType<FuelTank>().toList(); // Filter out nulls from parsing errors or non-maps
          } else if (json is List) {
             // Handle cases where the API might *just* return a list (less common for wrapped responses)
             print('FUEL_TANK_REPO: Response data is a direct list. Found ${json.length} items.');
             return json.map((item) {
               try {
                 if (item is Map<String, dynamic>) {
                    return FuelTank.fromJson(item);
                 } else {
                   print('FUEL_TANK_REPO: Skipping item from list because it is not a Map: $item');
                   return null;
                 }
               } catch (e, stacktrace) {
                 print('FUEL_TANK_REPO: Error parsing individual tank from list: $item, Error: $e');
                 print('FUEL_TANK_REPO: Stacktrace: $stacktrace');
                 return null;
               }
             }).whereType<FuelTank>().toList();
          }
          // If response format is unexpected
          print('FUEL_TANK_REPO: Unexpected response format, returning empty list. Format was: ${json.runtimeType}');
          return <FuelTank>[];
        },
      );
      
      if (response.success) {
        developer.log('Fuel tanks retrieved successfully. Count: ${response.data?.length ?? 0}');
        print('FUEL_TANK_REPO: Successfully retrieved ${response.data?.length ?? 0} fuel tanks.');
      } else {
        developer.log('Failed to retrieve fuel tanks: ${response.errorMessage}');
        print('FUEL_TANK_REPO: Failed to retrieve fuel tanks: ${response.errorMessage}');
      }
      
      return response;
    } catch (e, stacktrace) {
      developer.log('Exception in getAllFuelTanks: $e');
      print('FUEL_TANK_REPO: Exception in getAllFuelTanks: $e');
      print('FUEL_TANK_REPO: Stacktrace: $stacktrace');
      return ApiResponse(
        success: false,
        errorMessage: 'An error occurred while fetching fuel tanks: $e', // More user-friendly message potentially
      );
    }
  }

  // Get the petrol pump ID from the JWT token
  Future<String?> getPetrolPumpId() async {
    print('FUEL_TANK_REPO: Attempting to get Petrol Pump ID.');
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting petrol pump ID');
        print('FUEL_TANK_REPO: No auth token found for getPetrolPumpId.');
        return null;
      }
      
      // Extract petrolPumpId from token
      final petrolPumpId = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
      
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        developer.log('PetrolPumpId not found in JWT token');
        print('FUEL_TANK_REPO: PetrolPumpId not found in JWT. Checking prefs...');
        // Fallback to a stored ID if available
        final storedId = prefs.getString('petrolPumpId');
        print('FUEL_TANK_REPO: Found stored PetrolPumpId: $storedId');
        return storedId;
      }
      
      developer.log('PetrolPumpId extracted from JWT token: $petrolPumpId');
      print('FUEL_TANK_REPO: PetrolPumpId from JWT: $petrolPumpId');
      
      // Store for later use if extracted from JWT
      await prefs.setString('petrolPumpId', petrolPumpId);
      print('FUEL_TANK_REPO: Stored PetrolPumpId in prefs.');
      
      return petrolPumpId;
    } catch (e, stacktrace) {
      developer.log('Error getting petrol pump ID: $e');
      print('FUEL_TANK_REPO: Error in getPetrolPumpId: $e');
      print('FUEL_TANK_REPO: Stacktrace: $stacktrace');
      return null;
    }
  }

  Future<ApiResponse<bool>> updateFuelTank(FuelTank fuelTank) async {
    developer.log('Updating fuel tank: ${fuelTank.fuelTankId}');
    try {
      // Get JWT token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);

      if (token == null) {
        developer.log('JWT token not found in shared preferences');
        return ApiResponse(
          success: false,
          errorMessage: 'Authentication token not found. Please login again.',
        );
      }

      final url = ApiConstants.getFuelTankUrl() + '/' + fuelTank.fuelTankId!;
      developer.log('PUT request to: $url');
      
      // Create the payload according to the expected format
      final payload = {
        "fuelTankId": fuelTank.fuelTankId,
        "fuelType": fuelTank.fuelType,
        "capacityInLiters": fuelTank.capacityInLiters,
        "currentStock": fuelTank.currentStock,
        "status": fuelTank.status
      };

      final response = await _apiService.put<bool>(
        url,
        body: payload,
        token: token,
        fromJson: (json) => true,
      );

      if (response.success) {
        developer.log('Successfully updated fuel tank with ID: ${fuelTank.fuelTankId}');
      } else {
        developer.log('Failed to update fuel tank: ${response.errorMessage}');
      }

      return response;
    } catch (e) {
      developer.log('Exception in updateFuelTank: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<ApiResponse<bool>> refillFuelTank(String fuelTankId, double amountAdded) async {
    developer.log('Refilling fuel tank: $fuelTankId with amount: $amountAdded');
    try {
      // Get JWT token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);

      if (token == null) {
        developer.log('JWT token not found in shared preferences');
        return ApiResponse(
          success: false,
          errorMessage: 'Authentication token not found. Please login again.',
        );
      }
      
      // Use the AdjustStock endpoint for refilling
      final url = ApiConstants.getFuelTankUrl() + '/AdjustStock';
      developer.log('POST request to: $url');

      // Create the payload according to the expected format
      final payload = {
        "adjustmentAmount": amountAdded,
        "adjustmentReason": "Refill",
        "fuelTankId": fuelTankId,
        "notes": "Refill performed on ${DateTime.now().toString()}"
      };

      final response = await _apiService.post<bool>(
        url,
        body: payload,
        token: token,
        fromJson: (json) => true,
      );

      if (response.success) {
        developer.log('Successfully refilled fuel tank with ID: $fuelTankId');
      } else {
        developer.log('Failed to refill fuel tank: ${response.errorMessage}');
      }

      return response;
    } catch (e) {
      developer.log('Exception in refillFuelTank: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  Future<ApiResponse<FuelTank>> getFuelTankById(String fuelTankId, String token) async {
    developer.log('Getting fuel tank by ID: $fuelTankId');
    try {
      final url = ApiConstants.getFuelTankUrl() + '/' + fuelTankId;
      developer.log('GET request to: $url');

      final response = await _apiService.get<FuelTank>(
        url,
        token: token,
        fromJson: (json) => FuelTank.fromJson(json),
      );

      if (response.success) {
        developer.log('Successfully retrieved fuel tank with ID: $fuelTankId');
      } else {
        developer.log('Failed to get fuel tank: ${response.errorMessage}');
      }

      return response;
    } catch (e) {
      developer.log('Exception in getFuelTankById: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Method to delete a fuel tank
  Future<ApiResponse<bool>> deleteFuelTank(String fuelTankId) async {
    developer.log('Deleting fuel tank with ID: $fuelTankId');
    try {
      // Get JWT token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);

      if (token == null) {
        developer.log('JWT token not found in shared preferences');
        return ApiResponse(
          success: false,
          errorMessage: 'Authentication token not found. Please login again.',
        );
      }

      final url = ApiConstants.getFuelTankUrl() + '/' + fuelTankId;
      developer.log('DELETE request to: $url');

      final response = await _apiService.delete<bool>(
        url,
        token: token,
        fromJson: (_) => true, // Simply return true on success
      );

      if (response.success) {
        developer.log('Successfully deleted fuel tank with ID: $fuelTankId');
      } else {
        developer.log('Failed to delete fuel tank: ${response.errorMessage}');
      }

      return response;
    } catch (e) {
      developer.log('Exception in deleteFuelTank: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Get all fuel types
  Future<ApiResponse<List<FuelType>>> getFuelTypes() async {
    developer.log('Getting fuel types');
    print('FUEL_TANK_REPO: Fetching fuel types.');

    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting fuel types');
        print('FUEL_TANK_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Get petrol pump ID
      final petrolPumpId = await getPetrolPumpId();
      
      if (petrolPumpId == null) {
        developer.log('PetrolPumpId not found for getting fuel types');
        print('FUEL_TANK_REPO: PetrolPumpId not found.');
        return ApiResponse(
          success: false,
          errorMessage: 'Petrol pump ID not found. Please login again.',
        );
      }
      
      // Use the specific API endpoint for petrol pump fuel types
      final url = ApiConstants.getPumpFuelTypesUrl(petrolPumpId);
      developer.log('Fuel Types GET URL: $url');
      print('FUEL_TANK_REPO: GET URL for fuel types: $url');
      
      // Make the API call
      final response = await _apiService.get<List<FuelType>>(
        url,
        token: token,
        fromJson: (dynamic json) {
          print('FUEL_TANK_REPO: Raw fuel types data: $json');
          
          List<FuelType> fuelTypes = [];
          
          // Check if we have a data field containing a list
          if (json is Map && json.containsKey('data') && json['data'] is List) {
            final dataList = json['data'] as List;
            print('FUEL_TANK_REPO: Found ${dataList.length} fuel types in data list');
            
            fuelTypes = dataList
              .map((item) => item is Map<String, dynamic> ? FuelType.fromJson(item) : null)
              .where((item) => item != null)
              .cast<FuelType>()
              .toList();
          }
          // If the response is directly a list
          else if (json is List) {
            print('FUEL_TANK_REPO: Found ${json.length} fuel types in direct list');
            
            fuelTypes = json
              .map((item) => item is Map<String, dynamic> ? FuelType.fromJson(item) : null)
              .where((item) => item != null)
              .cast<FuelType>()
              .toList();
          }
          
          print('FUEL_TANK_REPO: Parsed ${fuelTypes.length} fuel types');
          return fuelTypes;
        },
      );
      
      if (response.success) {
        developer.log('Fuel types retrieved successfully');
        print('FUEL_TANK_REPO: Successfully retrieved ${response.data?.length ?? 0} fuel types');
      } else {
        developer.log('Failed to retrieve fuel types: ${response.errorMessage}');
        print('FUEL_TANK_REPO: Failed to retrieve fuel types: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in getFuelTypes: $e');
      print('FUEL_TANK_REPO: Exception in getFuelTypes: $e');
      return ApiResponse(
        success: false,
        errorMessage: 'An error occurred while fetching fuel types: $e',
        data: [],
      );
    }
  }

  // Submit fuel quality check
  Future<ApiResponse<bool>> submitFuelQualityCheck({
    required String fuelTankId,
    required String fuelType,
    required double density,
    required double temperature,
    required double waterContent,
    required String qualityStatus,
    required String checkedBy,
    required DateTime checkedAt,
  }) async {
    developer.log('Submitting quality check for fuel tank: $fuelTankId');
    try {
      // Get JWT token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);

      if (token == null) {
        developer.log('JWT token not found in shared preferences');
        return ApiResponse(
          success: false,
          errorMessage: 'Authentication token not found. Please login again.',
        );
      }

      // Get petrol pump ID
      final petrolPumpId = await getPetrolPumpId();
      
      if (petrolPumpId == null) {
        developer.log('PetrolPumpId not found for quality check');
        return ApiResponse(
          success: false,
          errorMessage: 'Petrol pump ID not found. Please login again.',
        );
      }
      
      final url = ApiConstants.getFuelQualityCheckUrl();
      developer.log('POST request to: $url');

      // Create the payload according to the expected format
      final payload = {
        "density": density,
        "fuelTankId": fuelTankId,
        "fuelType": fuelType,
        "petrolPumpId": petrolPumpId,
        "qualityStatus": qualityStatus,
        "temperature": temperature,
        "waterContent": waterContent,
        "checkedBy": checkedBy,
        "checkedAt": checkedAt.toIso8601String(),
      };

      final response = await _apiService.post<bool>(
        url,
        body: payload,
        token: token,
        fromJson: (json) => true,
      );

      if (response.success) {
        developer.log('Successfully submitted quality check for tank ID: $fuelTankId');
      } else {
        developer.log('Failed to submit quality check: ${response.errorMessage}');
      }

      return response;
    } catch (e) {
      developer.log('Exception in submitFuelQualityCheck: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Get quality checks for a specific fuel tank
  Future<ApiResponse<List<FuelQualityCheck>>> getFuelQualityChecksByTank(String fuelTankId) async {
    developer.log('Getting quality checks for fuel tank: $fuelTankId');
    try {
      // Get JWT token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);

      if (token == null) {
        developer.log('JWT token not found in shared preferences');
        return ApiResponse(
          success: false,
          errorMessage: 'Authentication token not found. Please login again.',
        );
      }

      final url = ApiConstants.getFuelQualityCheckByTankUrl(fuelTankId);
      developer.log('GET request to: $url');

      final response = await _apiService.get<List<FuelQualityCheck>>(
        url,
        token: token,
        fromJson: (json) {
          print('FUEL_TANK_REPO: Parsing quality check response data: $json');
          
          // Handle response based on format (direct list or wrapped in data field)
          if (json is Map && json.containsKey('data') && json['data'] is List) {
            final dataList = json['data'] as List;
            print('FUEL_TANK_REPO: Found ${dataList.length} quality checks in response data.');
            return dataList
                .map((item) => item is Map<String, dynamic> ? FuelQualityCheck.fromJson(item) : null)
                .whereType<FuelQualityCheck>()
                .toList();
          } else if (json is List) {
            print('FUEL_TANK_REPO: Response is direct list with ${json.length} items.');
            return json
                .map((item) => item is Map<String, dynamic> ? FuelQualityCheck.fromJson(item) : null)
                .whereType<FuelQualityCheck>()
                .toList();
          }
          
          // Default empty list if format unexpected
          print('FUEL_TANK_REPO: Unexpected response format, returning empty list.');
          return <FuelQualityCheck>[];
        },
      );

      if (response.success) {
        developer.log('Successfully retrieved quality checks for tank: $fuelTankId');
      } else {
        developer.log('Failed to get quality checks: ${response.errorMessage}');
      }

      return response;
    } catch (e) {
      developer.log('Exception in getFuelQualityChecksByTank: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
        data: [],
      );
    }
  }
}