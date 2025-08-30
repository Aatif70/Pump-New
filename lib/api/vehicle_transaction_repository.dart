import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

import 'api_constants.dart';
import 'api_service.dart';
import '../models/vehicle_transaction_model.dart';
import '../utils/jwt_decoder.dart';

class VehicleTransactionRepository {
  final ApiService _apiService = ApiService();

  // Get all vehicle transactions for a petrol pump
  Future<ApiResponse<List<VehicleTransaction>>> getVehicleTransactions(String petrolPumpId) async {
    developer.log('Getting vehicle transactions for petrol pump: $petrolPumpId');
    print('VEHICLE_TRANSACTION_REPO: Fetching vehicle transactions for petrol pump: $petrolPumpId');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting vehicle transactions');
        print('VEHICLE_TRANSACTION_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      final url = ApiConstants.getVehicleTransactionsUrl(petrolPumpId);
      developer.log('Vehicle Transactions GET URL: $url');
      print('VEHICLE_TRANSACTION_REPO: GET URL: $url');
      
      // Make the API call using the generic GET method
      final response = await _apiService.get<List<VehicleTransaction>>(
        url,
        token: token,
        fromJson: (json) {
          print('VEHICLE_TRANSACTION_REPO: Parsing response data: $json');
          // Expecting the structure: {"data": [...], "success": true, ...}
          if (json is Map && json.containsKey('data') && json['data'] is List) {
            final dataList = json['data'] as List;
            print('VEHICLE_TRANSACTION_REPO: Found ${dataList.length} vehicle transactions in response data.');
            return dataList.map((item) {
              try {
                // Ensure item is a Map before passing to fromJson
                if (item is Map<String, dynamic>) {
                  return VehicleTransaction.fromJson(item);
                } else {
                  print('VEHICLE_TRANSACTION_REPO: Skipping item because it is not a Map: $item');
                  return null; // Skip non-map items
                }
              } catch (e, stacktrace) {
                 print('VEHICLE_TRANSACTION_REPO: Error parsing individual vehicle transaction: $item, Error: $e');
                 print('VEHICLE_TRANSACTION_REPO: Stacktrace: $stacktrace');
                 return null; // Indicate parsing failure
              }
            }).whereType<VehicleTransaction>().toList(); // Filter out nulls from parsing errors or non-maps
          } else if (json is List) {
            print('VEHICLE_TRANSACTION_REPO: Found direct list with ${json.length} items');
            return json.map((item) {
              try {
                if (item is Map<String, dynamic>) {
                  return VehicleTransaction.fromJson(item);
                } else {
                  print('VEHICLE_TRANSACTION_REPO: Skipping item because it is not a Map: $item');
                  return null;
                }
              } catch (e) {
                print('VEHICLE_TRANSACTION_REPO: Error parsing individual vehicle transaction: $item, Error: $e');
                return null;
              }
            }).whereType<VehicleTransaction>().toList();
          } else {
            print('VEHICLE_TRANSACTION_REPO: Unexpected response format: $json');
            return <VehicleTransaction>[];
          }
        },
      );
      
      if (response.success) {
        developer.log('Vehicle transactions fetched successfully');
        print('VEHICLE_TRANSACTION_REPO: Vehicle transactions fetched successfully. Count: ${response.data?.length ?? 0}');
      } else {
        developer.log('Failed to fetch vehicle transactions: ${response.errorMessage}');
        print('VEHICLE_TRANSACTION_REPO: Failed to fetch vehicle transactions: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in getVehicleTransactions: $e');
      print('VEHICLE_TRANSACTION_REPO: Exception in getVehicleTransactions: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Add a new vehicle transaction
  Future<ApiResponse<Map<String, dynamic>>> addVehicleTransaction(VehicleTransaction transaction) async {
    developer.log('Adding vehicle transaction with details: ${transaction.toJson()}');
    print('VEHICLE_TRANSACTION_REPO: Adding vehicle transaction: ${transaction.toJson()}');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for adding vehicle transaction');
        print('VEHICLE_TRANSACTION_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      final url = ApiConstants.getVehicleTransactionUrl();
      print('VEHICLE_TRANSACTION_REPO: POST URL: $url');
      
      // Make the API call
      final response = await _apiService.post<Map<String, dynamic>>(
        url,
        body: transaction.toJson(),
        token: token,
        fromJson: (json) => json as Map<String, dynamic>,
      );
      
      if (response.success) {
        developer.log('Vehicle transaction added successfully');
        print('VEHICLE_TRANSACTION_REPO: Vehicle transaction added successfully. Response: ${response.data}');
      } else {
        developer.log('Failed to add vehicle transaction: ${response.errorMessage}');
        print('VEHICLE_TRANSACTION_REPO: Failed to add vehicle transaction: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in addVehicleTransaction: $e');
      print('VEHICLE_TRANSACTION_REPO: Exception in addVehicleTransaction: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Get vehicle transaction by ID
  Future<ApiResponse<VehicleTransaction>> getVehicleTransactionById(String transactionId) async {
    developer.log('Getting vehicle transaction by ID: $transactionId');
    print('VEHICLE_TRANSACTION_REPO: Getting vehicle transaction by ID: $transactionId');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting vehicle transaction');
        print('VEHICLE_TRANSACTION_REPO: No auth token found.');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      final url = ApiConstants.getVehicleTransactionByIdUrl(transactionId);
      developer.log('Vehicle Transaction by ID GET URL: $url');
      print('VEHICLE_TRANSACTION_REPO: GET URL: $url');
      
      // Make the API call
      final response = await _apiService.get<VehicleTransaction>(
        url,
        token: token,
        fromJson: (json) => VehicleTransaction.fromJson(json),
      );
      
      if (response.success) {
        developer.log('Vehicle transaction fetched successfully');
        print('VEHICLE_TRANSACTION_REPO: Vehicle transaction fetched successfully.');
      } else {
        developer.log('Failed to fetch vehicle transaction: ${response.errorMessage}');
        print('VEHICLE_TRANSACTION_REPO: Failed to fetch vehicle transaction: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in getVehicleTransactionById: $e');
      print('VEHICLE_TRANSACTION_REPO: Exception in getVehicleTransactionById: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
}
