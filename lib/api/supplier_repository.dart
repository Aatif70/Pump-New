import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

import 'api_constants.dart';
import 'api_service.dart';
import '../models/supplier_model.dart';
import '../utils/jwt_decoder.dart';

class SupplierRepository {
  final ApiService _apiService = ApiService();

  // Add a new supplier
  Future<ApiResponse<Map<String, dynamic>>> addSupplier(Supplier supplier) async {
    developer.log('Adding supplier with details: ${supplier.toJson()}');
    print('SUPPLIER_REPO: Adding supplier: ${supplier.toJson()}');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for adding supplier');
        print('SUPPLIER_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      final url = ApiConstants.getSupplierUrl();
      print('SUPPLIER_REPO: POST URL: $url');
      
      // Make the API call
      final response = await _apiService.post<Map<String, dynamic>>(
        url,
        body: supplier.toJson(),
        token: token,
        fromJson: (json) => json as Map<String, dynamic>,
      );
      
      if (response.success) {
        developer.log('Supplier added successfully');
        print('SUPPLIER_REPO: Supplier added successfully. Response: ${response.data}');
      } else {
        developer.log('Failed to add supplier: ${response.errorMessage}');
        print('SUPPLIER_REPO: Failed to add supplier: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in addSupplier: $e');
      print('SUPPLIER_REPO: Exception in addSupplier: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Get all suppliers for the logged-in petrol pump
  Future<ApiResponse<List<Supplier>>> getAllSuppliers() async {
    developer.log('Getting all suppliers');
    print('SUPPLIER_REPO: Fetching all suppliers.');

    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting suppliers');
        print('SUPPLIER_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      final url = ApiConstants.getSupplierUrl();
      developer.log('Suppliers GET URL: $url');
      print('SUPPLIER_REPO: GET URL: $url');
      
      // Make the API call using the generic GET method
      final response = await _apiService.get<List<Supplier>>(
        url,
        token: token,
        fromJson: (json) {
          print('SUPPLIER_REPO: Parsing response data: $json');
          // Expecting the structure: {"data": [...], "success": true, ...}
          if (json is Map && json.containsKey('data') && json['data'] is List) {
            final dataList = json['data'] as List;
            print('SUPPLIER_REPO: Found ${dataList.length} suppliers in response data.');
            return dataList.map((item) {
              try {
                // Ensure item is a Map before passing to fromJson
                if (item is Map<String, dynamic>) {
                  return Supplier.fromJson(item);
                } else {
                  print('SUPPLIER_REPO: Skipping item because it is not a Map: $item');
                  return null; // Skip non-map items
                }
              } catch (e, stacktrace) {
                 print('SUPPLIER_REPO: Error parsing individual supplier: $item, Error: $e');
                 print('SUPPLIER_REPO: Stacktrace: $stacktrace');
                 return null; // Indicate parsing failure
              }
            }).whereType<Supplier>().toList(); // Filter out nulls from parsing errors or non-maps
          } else if (json is List) {
             // Handle cases where the API might *just* return a list (less common for wrapped responses)
             print('SUPPLIER_REPO: Response data is a direct list. Found ${json.length} items.');
             return json.map((item) {
               try {
                 if (item is Map<String, dynamic>) {
                    return Supplier.fromJson(item);
                 } else {
                   print('SUPPLIER_REPO: Skipping item from list because it is not a Map: $item');
                   return null;
                 }
               } catch (e, stacktrace) {
                 print('SUPPLIER_REPO: Error parsing individual supplier from list: $item, Error: $e');
                 print('SUPPLIER_REPO: Stacktrace: $stacktrace');
                 return null;
               }
             }).whereType<Supplier>().toList();
          }
          // If response format is unexpected
          print('SUPPLIER_REPO: Unexpected response format, returning empty list. Format was: ${json.runtimeType}');
          return <Supplier>[];
        },
      );
      
      if (response.success) {
        developer.log('Suppliers retrieved successfully. Count: ${response.data?.length ?? 0}');
        print('SUPPLIER_REPO: Successfully retrieved ${response.data?.length ?? 0} suppliers.');
      } else {
        developer.log('Failed to retrieve suppliers: ${response.errorMessage}');
        print('SUPPLIER_REPO: Failed to retrieve suppliers: ${response.errorMessage}');
      }
      
      return response;
    } catch (e, stacktrace) {
      developer.log('Exception in getAllSuppliers: $e');
      print('SUPPLIER_REPO: Exception in getAllSuppliers: $e');
      print('SUPPLIER_REPO: Stacktrace: $stacktrace');
      return ApiResponse(
        success: false,
        errorMessage: 'An error occurred while fetching suppliers: $e',
      );
    }
  }

  // Get the petrol pump ID from the JWT token
  Future<String?> getPetrolPumpId() async {
    print('SUPPLIER_REPO: Attempting to get Petrol Pump ID.');
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting petrol pump ID');
        print('SUPPLIER_REPO: No auth token found for getPetrolPumpId.');
        return null;
      }
      
      // Extract petrolPumpId from token
      final petrolPumpId = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
      
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        developer.log('PetrolPumpId not found in JWT token');
        print('SUPPLIER_REPO: PetrolPumpId not found in JWT. Checking prefs...');
        // Fallback to a stored ID if available
        final storedId = prefs.getString('petrolPumpId');
        print('SUPPLIER_REPO: Found stored PetrolPumpId: $storedId');
        return storedId;
      }
      
      developer.log('PetrolPumpId extracted from JWT token: $petrolPumpId');
      print('SUPPLIER_REPO: PetrolPumpId from JWT: $petrolPumpId');
      
      // Store for later use if extracted from JWT
      await prefs.setString('petrolPumpId', petrolPumpId);
      print('SUPPLIER_REPO: Stored PetrolPumpId in prefs.');
      
      return petrolPumpId;
    } catch (e, stacktrace) {
      developer.log('Error getting petrol pump ID: $e');
      print('SUPPLIER_REPO: Error in getPetrolPumpId: $e');
      print('SUPPLIER_REPO: Stacktrace: $stacktrace');
      return null;
    }
  }

  // Update a supplier
  Future<ApiResponse<bool>> updateSupplier(Supplier supplier) async {
    developer.log('Updating supplier: ${supplier.supplierDetailId}');
    try {
      // Get JWT token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for updating supplier');
        print('SUPPLIER_REPO: No auth token found for update.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      if (supplier.supplierDetailId == null) {
        developer.log('No supplier ID provided for update');
        print('SUPPLIER_REPO: No supplier ID provided for update.');
        return ApiResponse(
          success: false,
          errorMessage: 'Supplier ID is required for update.',
        );
      }
      
      final url = ApiConstants.getUpdateSupplierUrl(supplier.supplierDetailId!);
      developer.log('Update supplier URL: $url');
      print('SUPPLIER_REPO: PUT URL: $url');
      
      // Make the API call
      final response = await _apiService.put<bool>(
        url,
        body: supplier.toJson(),
        token: token,
        fromJson: (json) => true, // Assuming success means true
      );
      
      if (response.success) {
        developer.log('Supplier updated successfully');
        print('SUPPLIER_REPO: Supplier updated successfully.');
      } else {
        developer.log('Failed to update supplier: ${response.errorMessage}');
        print('SUPPLIER_REPO: Failed to update supplier: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in updateSupplier: $e');
      print('SUPPLIER_REPO: Exception in updateSupplier: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Delete a supplier
  Future<ApiResponse<bool>> deleteSupplier(String supplierDetailId) async {
    developer.log('Deleting supplier: $supplierDetailId');
    try {
      // Get JWT token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for deleting supplier');
        print('SUPPLIER_REPO: No auth token found for delete.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      final url = ApiConstants.getDeleteSupplierUrl(supplierDetailId);
      developer.log('Delete supplier URL: $url');
      print('SUPPLIER_REPO: DELETE URL: $url');
      
      // Make the API call
      final response = await _apiService.delete<bool>(
        url,
        token: token,
        fromJson: (json) => true, // Assuming success means true
      );
      
      if (response.success) {
        developer.log('Supplier deleted successfully');
        print('SUPPLIER_REPO: Supplier deleted successfully.');
      } else {
        developer.log('Failed to delete supplier: ${response.errorMessage}');
        print('SUPPLIER_REPO: Failed to delete supplier: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in deleteSupplier: $e');
      print('SUPPLIER_REPO: Exception in deleteSupplier: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
} 