import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_response.dart';
import '../models/fuel_price_model.dart';
import 'api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/shared_prefs.dart';
import '../api/nozzle_repository.dart' hide ApiResponse;

class FuelPriceRepository {
  final String baseUrl = ApiConstants.baseUrl;

  // Get fuel price for the selected nozzle
  Future<ApiResponse<FuelPrice>> getFuelPrice(String nozzleId) async {
    try {
      print('DEBUG: Fetching fuel price for nozzle ID: $nozzleId');
      
      // Get auth token from shared preferences
      final token = await ApiConstants.getAuthToken();
      
      // Get petrol pump ID using SharedPrefs helper
      final petrolPumpId = await SharedPrefs.getPumpId();
      
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        print('DEBUG: No petrol pump ID found in shared preferences');
        return ApiResponse<FuelPrice>(
          success: false,
          errorMessage: 'Petrol pump ID not found',
          data: FuelPrice(price: 95.0), // Default price as fallback
        );
      }
      
      print('DEBUG: Using petrol pump ID: $petrolPumpId');
      
      // First, get the nozzle details to get the fuel type
      final nozzleRepo = NozzleRepository();
      final nozzleResponse = await nozzleRepo.getNozzleById(nozzleId);
      
      String? fuelTypeId;
      String? fuelTypeName;
      if (nozzleResponse.success && nozzleResponse.data != null) {
        fuelTypeId = nozzleResponse.data!.fuelTypeId;
        fuelTypeName = nozzleResponse.data!.fuelType;
        print('DEBUG: Got fuel type ID for nozzle: $fuelTypeId, Fuel type name: $fuelTypeName');
      } else {
        print('DEBUG: Could not get fuel type for nozzle. Will use default price.');
      }
      
      // Use the API constants to get the proper URL format
      final url = Uri.parse(ApiConstants.getCurrentPricesByPetrolPumpUrl(petrolPumpId));
      print('DEBUG: Fuel price API URL: $url');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('DEBUG: Fuel price response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        print('DEBUG: Fuel price response data: $responseBody');
        
        // Extract data list from response
        List<dynamic> pricesList = [];
        if (responseBody is Map && responseBody.containsKey('data')) {
          if (responseBody['data'] is List) {
            pricesList = responseBody['data'];
          }
        } else if (responseBody is List) {
          pricesList = responseBody;
        }
        
        if (pricesList.isEmpty) {
          print('DEBUG: No prices found in response');
          return ApiResponse<FuelPrice>(
            success: false,
            errorMessage: 'No fuel prices found',
            data: FuelPrice(price: 95.0), // Default price as fallback
          );
        }
        
        // If we have a fuel type ID, try to find the matching price
        FuelPrice? matchedPrice;
        
        // Print all available fuel types and prices for debugging
        print('DEBUG: Available fuel types and prices:');
        for (var priceData in pricesList) {
          if (priceData is Map) {
            print('DEBUG: FuelTypeId: ${priceData['fuelTypeId']}, FuelTypeName: ${priceData['fuelTypeName']}, Price: ${priceData['pricePerLiter']}');
          }
        }
        
        if (fuelTypeId != null && fuelTypeId.isNotEmpty) {
          // First try to match by fuel type ID
          for (var priceData in pricesList) {
            if (priceData is Map && 
                priceData.containsKey('fuelTypeId') && 
                priceData['fuelTypeId'] == fuelTypeId) {
              matchedPrice = FuelPrice.fromJson(Map<String, dynamic>.from(priceData));
              print('DEBUG: Found matching price by fuel type ID: ${matchedPrice.price}');
            }
          }
          
          // If not found by ID, try to match by fuel type name
          if (matchedPrice == null && fuelTypeName != null && fuelTypeName.isNotEmpty) {
            for (var priceData in pricesList) {
              if (priceData is Map && 
                  priceData.containsKey('fuelTypeName') &&
                  priceData['fuelTypeName'].toString().toLowerCase() == fuelTypeName.toLowerCase()) {
                matchedPrice = FuelPrice.fromJson(Map<String, dynamic>.from(priceData));
                print('DEBUG: Found matching price by fuel type name: ${matchedPrice.price}');
              }
            }
          }
        }
        
        // If no match found, use the first price in the list
        if (matchedPrice == null && pricesList.isNotEmpty) {
          matchedPrice = FuelPrice.fromJson(Map<String, dynamic>.from(pricesList[0]));
          print('DEBUG: No match found. Using first price in list: ${matchedPrice.price}');
        }
        
        if (matchedPrice != null) {
          return ApiResponse<FuelPrice>(
            success: true,
            data: matchedPrice,
          );
        } else {
          // Fallback to default price if no prices found
          print('DEBUG: Using default price as fallback');
          return ApiResponse<FuelPrice>(
            success: true,
            data: FuelPrice(price: 95.0), // Default price
            errorMessage: 'Using default price (could not find any prices)',
          );
        }
      } else {
        print('DEBUG: Failed to load fuel price. Status code: ${response.statusCode}, Response: ${response.body}');
        return ApiResponse<FuelPrice>(
          success: false,
          errorMessage: 'Failed to load fuel price (Status: ${response.statusCode})',
          data: FuelPrice(price: 95.0), // Default price as fallback
        );
      }
    } catch (e) {
      print('ERROR in getFuelPrice: $e');
      // Return a default price in case of error to prevent app crash
      return ApiResponse<FuelPrice>(
        success: true, // Mark as success to allow app to continue
        data: FuelPrice(price: 95.0), // Default price
        errorMessage: 'Using default price due to error: $e',
      );
    }
  }

  // Get all active fuel prices
  Future<ApiResponse<List<FuelPrice>>> getAllFuelPrices() async {
    try {
      // Get petrol pump ID using SharedPrefs helper
      final petrolPumpId = await SharedPrefs.getPumpId();
      
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        print('DEBUG: No petrol pump ID found for getAllFuelPrices');
        return ApiResponse<List<FuelPrice>>(
          success: false,
          errorMessage: 'Petrol pump ID not found',
          data: [], // Empty list as fallback
        );
      }
      
      final url = Uri.parse(ApiConstants.getCurrentPricesByPetrolPumpUrl(petrolPumpId));
      print('DEBUG: Getting all fuel prices from: $url');
      
      // Get auth token from shared preferences
      final token = await ApiConstants.getAuthToken();
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('DEBUG: All prices response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        List<dynamic> pricesJson = [];
        
        // Handle different response formats
        if (responseData is List) {
          pricesJson = responseData;
        } else if (responseData is Map && responseData.containsKey('data')) {
          if (responseData['data'] is List) {
            pricesJson = responseData['data'];
          }
        }
        
        print('DEBUG: Parsed ${pricesJson.length} prices from API');
        
        final List<FuelPrice> prices = pricesJson
            .map((json) => FuelPrice.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        
        return ApiResponse<List<FuelPrice>>(
          success: true,
          data: prices,
        );
      } else {
        print('DEBUG: Failed to load all fuel prices. Status: ${response.statusCode}');
        return ApiResponse<List<FuelPrice>>(
          success: false,
          errorMessage: 'Failed to load fuel prices (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      print('ERROR in getAllFuelPrices: $e');
      return ApiResponse<List<FuelPrice>>(
        success: false,
        errorMessage: 'An error occurred: $e',
      );
    }
  }
} 