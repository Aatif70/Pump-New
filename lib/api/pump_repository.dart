import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

import 'api_constants.dart';
import 'api_service.dart';
import '../models/pump_model.dart';
import '../models/fuel_type_model.dart';
import '../utils/jwt_decoder.dart';

class PumpRepository {
  final ApiService _apiService = ApiService();

  // Get the profile for the logged-in petrol pump
  Future<ApiResponse<PumpProfile>> getPumpProfile() async {
    developer.log('Getting pump profile');
    print('PUMP_REPO: Fetching pump profile.');

    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting pump profile');
        print('PUMP_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Extract petrolPumpId from token
      final petrolPumpId = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
      
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        developer.log('PetrolPumpId not found in JWT token');
        print('PUMP_REPO: PetrolPumpId not found in JWT token');
        return ApiResponse(
          success: false,
          errorMessage: 'Petrol pump ID not found. Please login again.',
        );
      }
      
      final url = ApiConstants.getPumpProfileUrl(petrolPumpId);
      developer.log('Pump Profile GET URL: $url');
      print('PUMP_REPO: GET URL: $url');
      
      // Make the API call
      final response = await _apiService.get<PumpProfile>(
        url,
        token: token,
        fromJson: (dynamic json) {
          print('PUMP_REPO: Raw response data: $json');
          
          // First check if we have a data field
          if (json is Map && json.containsKey('data')) {
            final dataJson = json['data'];
            if (dataJson is Map<String, dynamic>) {
              print('PUMP_REPO: Found data object, parsing PumpProfile');
              return PumpProfile.fromJson(dataJson);
            }
          }
          
          // If the API returns the object directly (less likely based on logs)
          if (json is Map<String, dynamic>) {
            print('PUMP_REPO: Direct object format, parsing PumpProfile');
            return PumpProfile.fromJson(json);
          }
          
          // If response format is unexpected
          print('PUMP_REPO: Unexpected response format: ${json.runtimeType}');
          throw Exception('Unexpected response format');
        },
      );
      
      if (response.success) {
        developer.log('Pump profile retrieved successfully');
        print('PUMP_REPO: Successfully retrieved pump profile: ${response.data?.toJson()}');
      } else {
        developer.log('Failed to retrieve pump profile: ${response.errorMessage}');
        print('PUMP_REPO: Failed to retrieve pump profile: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in getPumpProfile: $e');
      print('PUMP_REPO: Exception in getPumpProfile: $e');
      return ApiResponse(
        success: false,
        errorMessage: 'An error occurred while fetching pump profile: $e',
      );
    }
  }

  // Update pump profile
  Future<ApiResponse<bool>> updatePumpProfile(PumpProfile profile) async {
    developer.log('Updating pump profile');
    print('PUMP_REPO: Updating pump profile.');

    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for updating pump profile');
        print('PUMP_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Ensure we have a pump ID
      if (profile.petrolPumpId == null || profile.petrolPumpId!.isEmpty) {
        developer.log('PetrolPumpId not provided for update');
        print('PUMP_REPO: PetrolPumpId not provided for update');
        return ApiResponse(
          success: false,
          errorMessage: 'Petrol pump ID not found. Cannot update profile.',
        );
      }
      
      // Check if we need to limit the number of fuel types (some APIs have limitations)
      if (profile.fuelTypesAvailable.split(',').length > 3) {
        print('PUMP_REPO: Warning - more than 3 fuel types selected, API may reject.');
      }
      
      final url = ApiConstants.getUpdatePumpProfileUrl(profile.petrolPumpId!);
      developer.log('Update Pump Profile URL: $url');
      print('PUMP_REPO: PUT URL: $url');
      
      // Convert the profile to JSON
      final profileJson = profile.toJson();
      print('PUMP_REPO: Profile data for update: $profileJson');
      
      // Make the API call
      final response = await _apiService.put<bool>(
        url,
        body: profileJson,
        token: token,
        fromJson: (dynamic json) {
          print('PUMP_REPO: Update response: $json');
          return true; // If we reach here, it's a success
        },
      );
      
      if (response.success) {
        developer.log('Pump profile updated successfully');
        print('PUMP_REPO: Successfully updated pump profile');
      } else {
        developer.log('Failed to update pump profile: ${response.errorMessage}');
        print('PUMP_REPO: Failed to update pump profile: ${response.errorMessage}');
        
        // If there's an issue with fuel types, try fallback approach
        if (!response.success && 
            profile.fuelTypesAvailable.split(',').length > 1) {
          print('PUMP_REPO: Initial update failed. Trying with just the primary fuel type.');
          
          // Try again with just one fuel type
          final primaryFuelType = profile.fuelTypesAvailable.split(',').first;
          final fallbackProfile = PumpProfile(
            petrolPumpId: profile.petrolPumpId,
            name: profile.name,
            addressId: profile.addressId,
            licenseNumber: profile.licenseNumber,
            taxId: profile.taxId,
            openingTime: profile.openingTime,
            closingTime: profile.closingTime,
            isActive: profile.isActive,
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt,
            companyName: profile.companyName,
            numberOfDispensers: profile.numberOfDispensers,
            fuelTypesAvailable: primaryFuelType, // Just the first fuel type
            contactNumber: profile.contactNumber,
            email: profile.email,
            website: profile.website,
            gstNumber: profile.gstNumber,
            licenseExpiryDate: profile.licenseExpiryDate,
            sapNo: profile.sapNo,
          );
          
          final url = ApiConstants.getUpdatePumpProfileUrl(fallbackProfile.petrolPumpId!);
          final fallbackJson = fallbackProfile.toJson();
          print('PUMP_REPO: Fallback profile data: $fallbackJson');
          
          final fallbackResponse = await _apiService.put<bool>(
            url,
            body: fallbackJson,
            token: token,
            fromJson: (dynamic json) => true,
          );
          
          if (fallbackResponse.success) {
            print('PUMP_REPO: Fallback approach with single fuel type successful');
            return fallbackResponse;
          } else {
            print('PUMP_REPO: Fallback approach also failed: ${fallbackResponse.errorMessage}');
            // Return original response since fallback also failed
          }
        }
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in updatePumpProfile: $e');
      print('PUMP_REPO: Exception in updatePumpProfile: $e');
      return ApiResponse(
        success: false,
        errorMessage: 'An error occurred while updating pump profile: $e',
      );
    }
  }

  // Get all fuel types
  Future<ApiResponse<List<FuelType>>> getFuelTypes() async {
    developer.log('Getting fuel types');
    print('PUMP_REPO: Fetching fuel types.');

    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting fuel types');
        print('PUMP_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      final url = ApiConstants.getFuelTypesUrl();
      developer.log('Fuel Types GET URL: $url');
      print('PUMP_REPO: GET URL for fuel types: $url');
      
      // Make the API call
      final response = await _apiService.get<List<FuelType>>(
        url,
        token: token,
        fromJson: (dynamic json) {
          print('PUMP_REPO: Raw fuel types data: $json');
          
          List<FuelType> fuelTypes = [];
          
          // Check if we have a data field containing a list
          if (json is Map && json.containsKey('data') && json['data'] is List) {
            final dataList = json['data'] as List;
            print('PUMP_REPO: Found ${dataList.length} fuel types in data list');
            
            fuelTypes = dataList
              .map((item) => item is Map<String, dynamic> ? FuelType.fromJson(item) : null)
              .where((item) => item != null)
              .cast<FuelType>()
              .toList();
          }
          // If the response is directly a list
          else if (json is List) {
            print('PUMP_REPO: Found ${json.length} fuel types in direct list');
            
            fuelTypes = json
              .map((item) => item is Map<String, dynamic> ? FuelType.fromJson(item) : null)
              .where((item) => item != null)
              .cast<FuelType>()
              .toList();
          }
          
          print('PUMP_REPO: Parsed ${fuelTypes.length} fuel types');
          return fuelTypes;
        },
      );
      
      if (response.success) {
        developer.log('Fuel types retrieved successfully');
        print('PUMP_REPO: Successfully retrieved ${response.data?.length ?? 0} fuel types');
      } else {
        developer.log('Failed to retrieve fuel types: ${response.errorMessage}');
        print('PUMP_REPO: Failed to retrieve fuel types: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in getFuelTypes: $e');
      print('PUMP_REPO: Exception in getFuelTypes: $e');
      return ApiResponse(
        success: false,
        errorMessage: 'An error occurred while fetching fuel types: $e',
        data: [],
      );
    }
  }
  
  // Get fuel types for a specific petrol pump
  Future<ApiResponse<List<FuelType>>> getPumpFuelTypes(String petrolPumpId) async {
    developer.log('Getting fuel types for pump: $petrolPumpId');
    print('PUMP_REPO: Fetching fuel types for petrol pump: $petrolPumpId');

    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting pump fuel types');
        print('PUMP_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      final url = ApiConstants.getPumpFuelTypesUrl(petrolPumpId);
      developer.log('Pump Fuel Types GET URL: $url');
      print('PUMP_REPO: GET URL for pump fuel types: $url');
      
      // Make the API call
      final response = await _apiService.get<List<FuelType>>(
        url,
        token: token,
        fromJson: (dynamic json) {
          print('PUMP_REPO: Raw pump fuel types data: $json');
          
          List<FuelType> fuelTypes = [];
          
          // Check if we have a data field containing a list
          if (json is Map && json.containsKey('data') && json['data'] is List) {
            final dataList = json['data'] as List;
            print('PUMP_REPO: Found ${dataList.length} pump fuel types in data list');
            
            fuelTypes = dataList
              .map((item) => item is Map<String, dynamic> ? FuelType.fromJson(item) : null)
              .where((item) => item != null)
              .cast<FuelType>()
              .toList();
          }
          // If the response is directly a list
          else if (json is List) {
            print('PUMP_REPO: Found ${json.length} pump fuel types in direct list');
            
            fuelTypes = json
              .map((item) => item is Map<String, dynamic> ? FuelType.fromJson(item) : null)
              .where((item) => item != null)
              .cast<FuelType>()
              .toList();
          }
          
          print('PUMP_REPO: Parsed ${fuelTypes.length} pump fuel types');
          return fuelTypes;
        },
      );
      
      if (response.success) {
        developer.log('Pump fuel types retrieved successfully');
        print('PUMP_REPO: Successfully retrieved ${response.data?.length ?? 0} pump fuel types');
      } else {
        developer.log('Failed to retrieve pump fuel types: ${response.errorMessage}');
        print('PUMP_REPO: Failed to retrieve pump fuel types: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in getPumpFuelTypes: $e');
      print('PUMP_REPO: Exception in getPumpFuelTypes: $e');
      return ApiResponse(
        success: false,
        errorMessage: 'An error occurred while fetching pump fuel types: $e',
        data: [],
      );
    }
  }
} 