import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:petrol_pump/api/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import '../models/price_model.dart';
import '../utils/jwt_decoder.dart';
import 'api_response.dart';

class PricingRepository {
  // Get auth token from SharedPreferences
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      developer.log('PricingRepository: Retrieved auth token: ${token != null ? 'Token exists' : 'No token found'}');
      return token;
    } catch (e) {
      developer.log('PricingRepository: Error getting auth token: $e');
      return null;
    }
  }

  // Get petrol pump ID from JWT token and SharedPreferences
  Future<String?> getPumpId() async {
    developer.log('PricingRepository: Attempting to get Petrol Pump ID');
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('PricingRepository: No auth token found for getting petrol pump ID');
        developer.log('PricingRepository: Checking if petrolPumpId is stored directly');
        // Check if we stored the petrolPumpId directly
        final storedId = prefs.getString('petrolPumpId');
        if (storedId != null && storedId.isNotEmpty) {
          developer.log('PricingRepository: Found stored petrolPumpId: $storedId');
          return storedId;
        }
        return null;
      }
      
      // Extract petrolPumpId from token
      final petrolPumpId = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
      developer.log('PricingRepository: Extracted petrolPumpId from token: $petrolPumpId');
      
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        developer.log('PricingRepository: petrolPumpId not found in JWT token. Checking for stored value.');
        // Try the direct storage if not in token
        final storedId = prefs.getString('petrolPumpId');
        developer.log('PricingRepository: Found stored petrolPumpId: $storedId');
        return storedId;
      }
      
      // Store for later use if extracted from JWT
      await prefs.setString('petrolPumpId', petrolPumpId);
      developer.log('PricingRepository: Stored petrolPumpId in preferences: $petrolPumpId');
      
      return petrolPumpId;
    } catch (e) {
      developer.log('PricingRepository: Error getting petrol pump ID: $e');
      return null;
    }
  }

  // Get user ID from JWT token and SharedPreferences
  Future<String?> getUserId() async {
    developer.log('PricingRepository: Attempting to get User ID');
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('PricingRepository: No auth token found for getting user ID');
        // Check if we stored the userId directly
        final storedId = prefs.getString('userId');
        if (storedId != null && storedId.isNotEmpty) {
          developer.log('PricingRepository: Found stored userId: $storedId');
          return storedId;
        }
        return null;
      }
      
      // Try common claim names for user ID
      final userClaims = ['userId', 'sub', 'jti', 'id', 'user_id', 'nameId'];
      String? userId;
      
      for (final claim in userClaims) {
        userId = JwtDecoder.getClaim<String>(token, claim);
        if (userId != null && userId.isNotEmpty) {
          developer.log('PricingRepository: Found userId in JWT token under claim "$claim": $userId');
          break;
        }
      }
      
      if (userId == null || userId.isEmpty) {
        developer.log('PricingRepository: userId not found in JWT token claims. Checking for stored value.');
        // Try the direct storage if not in token
        final storedId = prefs.getString('userId');
        developer.log('PricingRepository: Found stored userId: $storedId');
        return storedId;
      }
      
      // Store for later use
      await prefs.setString('userId', userId);
      developer.log('PricingRepository: Stored userId in preferences: $userId');
      
      return userId;
    } catch (e) {
      developer.log('PricingRepository: Error getting user ID: $e');
      return null;
    }
  }

  // Get employee ID for the current user
  Future<String?> getEmployeeId() async {
    developer.log('PricingRepository: Attempting to get Employee ID');
    try {
      // First check if we have a stored employee ID in preferences
      final prefs = await SharedPreferences.getInstance();
      final storedEmployeeId = prefs.getString('employeeId');
      
      if (storedEmployeeId != null && storedEmployeeId.isNotEmpty) {
        developer.log('PricingRepository: Found stored employeeId: $storedEmployeeId');
        return storedEmployeeId;
      }
      
      // If no stored ID, try to get it from the JWT token
      final token = prefs.getString(ApiConstants.authTokenKey);
      if (token != null) {
        final employeeId = JwtDecoder.getClaim<String>(token, 'employeeId');
        if (employeeId != null && employeeId.isNotEmpty) {
          // Store for later use
          await prefs.setString('employeeId', employeeId);
          developer.log('PricingRepository: Extracted and stored employeeId from token: $employeeId');
          return employeeId;
        }
      }
      
      // If we get here, we couldn't find the employee ID
      // In a real app, we might want to fetch it from the server using the user ID
      final userId = await getUserId();
      if (userId != null) {
        developer.log('PricingRepository: Could not find employeeId, using userId as fallback: $userId');
        return userId; // Fallback to user ID for now
      }
      
      return null;
    } catch (e) {
      developer.log('PricingRepository: Error getting employee ID: $e');
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
      developer.log('PricingRepository: Added auth token to headers');
    } else {
      developer.log('PricingRepository: Warning - No auth token available');
    }
    
    return headers;
  }

  // Set a new fuel price
  Future<ApiResponse<FuelPrice>> setFuelPrice(FuelPrice price) async {
    developer.log('PricingRepository: Setting new price for ${price.fuelType}');
    print('DEBUG: Setting new fuel price for ${price.fuelType}');
    
    try {
      final url = ApiConstants.getSetPriceUrl();
      developer.log('PricingRepository: API URL: $url');
      print('DEBUG: API URL: $url');
      
      // Prepare the payload according to the specified API format
      final Map<String, dynamic> payload = {
        'effectiveFrom': price.effectiveFrom.toIso8601String(),
        'pricePerLiter': price.pricePerLiter,
        'petrolPumpId': price.petrolPumpId,
        'fuelTypeId': price.fuelTypeId,
        'lastUpdatedBy': price.lastUpdatedBy,
      };
      
      // Add optional fields if they exist
      if (price.effectiveTo != null) {
        payload['effectiveTo'] = price.effectiveTo!.toIso8601String();
      }
      if (price.costPerLiter != null) {
        payload['costPerLiter'] = price.costPerLiter;
      }
      if (price.markupPercentage != null) {
        payload['markupPercentage'] = price.markupPercentage;
      }
      if (price.markupAmount != null) {
        payload['markupAmount'] = price.markupAmount;
      }
      
      print('DEBUG: Full payload before encoding:');
      payload.forEach((key, value) {
        print('DEBUG: $key = $value');
      });
      
      final body = json.encode(payload);
      print('DEBUG: Request JSON body: $body');
      developer.log('PricingRepository: Request body: $body');
      
      final headers = await _getHeaders();
      print('DEBUG: Request headers:');
      headers.forEach((key, value) {
        print('DEBUG: $key = $value');
      });
      
      print('DEBUG: Sending POST request to $url');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      print('DEBUG: Response status code: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');
      developer.log('PricingRepository: Response status code: ${response.statusCode}');
      developer.log('PricingRepository: Response body: ${response.body}');

      if (response.statusCode == ApiConstants.statusCreated) {
        final responseData = json.decode(response.body);
        print('DEBUG: Response status code: ${response.statusCode}');
        print('DEBUG: Response body: ${response.body}');
        print('DEBUG: Successfully set price');
        
        try {
          final fuelPrice = FuelPrice.fromJson(responseData);
          return ApiResponse<FuelPrice>(
            success: true,
            data: fuelPrice,
          );
        } catch (e) {
          // Even if parsing fails, the price was set successfully
          print('DEBUG: Exception when parsing the response: $e');
          print('DEBUG: Returning success response anyway since price was set');
          
          // Create a minimal FuelPrice object with the ID and fuelTypeId
          final String? pricingId = responseData['pricingId'];
          final String? fuelTypeId = responseData['fuelTypeId'];
          
          // Try to build a minimally valid FuelPrice object
          return ApiResponse<FuelPrice>(
            success: true,
            data: FuelPrice(
              id: pricingId,
              effectiveFrom: DateTime.parse(responseData['effectiveFrom'] ?? DateTime.now().toIso8601String()),
              effectiveTo: responseData['effectiveTo'] != null ? DateTime.parse(responseData['effectiveTo']) : null,
              fuelType: '', // Empty string as default
              fuelTypeId: fuelTypeId,
              pricePerLiter: double.parse(responseData['pricePerLiter'].toString()),
              costPerLiter: responseData['costPerLiter'] != null ? double.parse(responseData['costPerLiter'].toString()) : null,
              markupPercentage: responseData['markupPercentage'] != null ? double.parse(responseData['markupPercentage'].toString()) : null,
              markupAmount: responseData['markupAmount'] != null ? double.parse(responseData['markupAmount'].toString()) : null,
              petrolPumpId: responseData['petrolPumpId'],
              lastUpdatedBy: responseData['lastUpdatedBy'],
            ),
          );
        }
      } else {
        print('DEBUG: Error setting price. Status code: ${response.statusCode}');
        print('DEBUG: Response body: ${response.body}');
        return ApiResponse<FuelPrice>(
          success: false,
          errorMessage: 'Failed to set price. Server returned: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('DEBUG: Exception when setting price: $e');
      developer.log('PricingRepository: Exception when setting price: $e');
      return ApiResponse<FuelPrice>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get current fuel prices
  Future<ApiResponse<List<FuelPrice>>> getCurrentPrices() async {
    developer.log('PricingRepository: Getting current fuel prices');
    
    try {
      // Get the petrol pump ID first
      final petrolPumpId = await getPumpId();
      
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        developer.log('PricingRepository: No petrol pump ID available for getting current prices');
        return ApiResponse<List<FuelPrice>>(
          success: false,
          errorMessage: 'No petrol pump ID available',
          data: [],
        );
      }
      
      // Use the new endpoint with petrol pump ID
      final url = ApiConstants.getCurrentPricesByPetrolPumpUrl(petrolPumpId);
      developer.log('PricingRepository: Using URL for current prices: $url');
      
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      developer.log('PricingRepository: Current prices response status: ${response.statusCode}');
      developer.log('PricingRepository: Current prices response body: ${response.body}');
      
      if (response.statusCode == ApiConstants.statusOk) {
        final responseData = json.decode(response.body);
        
        // Check if the response contains a data field with the prices
        if (responseData.containsKey('data') && responseData['data'] is List) {
          final List<dynamic> pricesJson = responseData['data'];
          final prices = pricesJson.map((json) {
            try {
              // Try to map using the new response format
              return FuelPrice(
                id: json['pricingId'],
                petrolPumpId: json['petrolPumpId'],
                fuelTypeId: json['fuelTypeId'],
                fuelType: json['fuelTypeName'] ?? '',
                pricePerLiter: json['pricePerLiter']?.toDouble() ?? 0.0,
                effectiveFrom: json['effectiveFrom'] != null 
                  ? DateTime.parse(json['effectiveFrom']) 
                  : DateTime.now(),
                isActive: json['isActive'] == true || json['isCurrentlyActive'] == true,
                lastUpdatedBy: json['lastUpdatedBy'] ?? '',
              );
            } catch (e) {
              developer.log('PricingRepository: Error parsing price: $e');
              return null;
            }
          }).where((price) => price != null).cast<FuelPrice>().toList();
          
          return ApiResponse<List<FuelPrice>>(
            success: true,
            data: prices,
          );
        } else {
          developer.log('PricingRepository: Invalid response format for current prices');
          return ApiResponse<List<FuelPrice>>(
            success: false,
            errorMessage: 'Invalid response format',
            data: [],
          );
        }
      } else {
        developer.log('PricingRepository: Failed to get current prices. Status: ${response.statusCode}');
        return ApiResponse<List<FuelPrice>>(
          success: false,
          errorMessage: 'Failed to get current prices. Status: ${response.statusCode}',
          data: [],
        );
      }
    } catch (e) {
      developer.log('PricingRepository: Exception getting current prices: $e');
      return ApiResponse<List<FuelPrice>>(
        success: false,
        errorMessage: 'Exception: $e',
        data: [],
      );
    }
  }

  // Get fuel price by ID
  Future<ApiResponse<FuelPrice>> getPriceById(String priceId) async {
    developer.log('PricingRepository: Getting fuel price with ID: $priceId');
    
    try {
      final url = ApiConstants.getPriceByIdUrl(priceId);
      developer.log('PricingRepository: API URL: $url');
      
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      developer.log('PricingRepository: Response status code: ${response.statusCode}');
      developer.log('PricingRepository: Response body: ${response.body}');

      if (response.statusCode == ApiConstants.statusOk) {
        final jsonData = json.decode(response.body);
        developer.log('PricingRepository: Successfully fetched price by ID');
        return ApiResponse<FuelPrice>(
          success: true,
          data: FuelPrice.fromJson(jsonData),
        );
      } else {
        developer.log('PricingRepository: Error fetching price by ID: ${response.statusCode}');
        return ApiResponse<FuelPrice>(
          success: false,
          errorMessage: 'Failed to fetch price: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('PricingRepository: Exception when fetching price by ID: $e');
      return ApiResponse<FuelPrice>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get latest price for a specific fuel type
  Future<ApiResponse<FuelPrice>> getLatestPriceByFuelType(String fuelType) async {
    developer.log('PricingRepository: Getting latest price for fuel type: $fuelType');
    
    try {
      final url = ApiConstants.getLatestPriceByFuelTypeUrl(fuelType);
      developer.log('PricingRepository: API URL: $url');
      
      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      developer.log('PricingRepository: Response status code: ${response.statusCode}');
      developer.log('PricingRepository: Response body: ${response.body}');

      if (response.statusCode == ApiConstants.statusOk) {
        final jsonData = json.decode(response.body);
        developer.log('PricingRepository: Successfully fetched latest price for $fuelType');
        return ApiResponse<FuelPrice>(
          success: true,
          data: FuelPrice.fromJson(jsonData),
        );
      } else {
        developer.log('PricingRepository: Error fetching latest price: ${response.statusCode}');
        return ApiResponse<FuelPrice>(
          success: false,
          errorMessage: 'Failed to fetch latest price: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('PricingRepository: Exception when fetching latest price: $e');
      return ApiResponse<FuelPrice>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get price history for a specific fuel type
  Future<ApiResponse<List<FuelPrice>>> getPriceHistoryByFuelType(String fuelType, {String? fuelTypeId}) async {
    developer.log('PricingRepository: Getting price history for fuel type: $fuelType');
    print('DEBUG: Getting price history for fuel type: $fuelType, fuelTypeId: $fuelTypeId');

    try {
      // We need both petrolPumpId and fuelTypeId for the new endpoint
      final petrolPumpId = await getPumpId();
      
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        developer.log('PricingRepository: No petrol pump ID available for getting price history');
        return ApiResponse<List<FuelPrice>>(
          success: false,
          errorMessage: 'No petrol pump ID available',
          data: [],
        );
      }
      
      if (fuelTypeId == null || fuelTypeId.isEmpty) {
        developer.log('PricingRepository: No fuel type ID provided for getting price history');
        return ApiResponse<List<FuelPrice>>(
          success: false,
          errorMessage: 'No fuel type ID provided',
          data: [],
        );
      }
      
      // Use the new endpoint with petrolPumpId and fuelTypeId
      final url = ApiConstants.getPriceHistoryUrl(petrolPumpId, fuelTypeId);
      developer.log('PricingRepository: API URL: $url');
      print('DEBUG: Fuel price history API URL: $url');

      final headers = await _getHeaders();
      developer.log('PricingRepository: Request headers: ${headers.keys.join(', ')}');
      print('DEBUG: Request headers: ${headers.keys.join(', ')}');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      developer.log('PricingRepository: Response status code: ${response.statusCode}');
      developer.log('PricingRepository: Response body: ${response.body}');
      print('DEBUG: Fuel price history response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == ApiConstants.statusOk) {
        final responseData = json.decode(response.body);
        
        // Check if the response contains a data field with the prices
        if (responseData.containsKey('data') && responseData['data'] is List) {
          final List<dynamic> pricesJson = responseData['data'];
          developer.log('PricingRepository: Successfully parsed price history data, count: ${pricesJson.length}');
          print('DEBUG: Received ${pricesJson.length} price history records');

          final prices = pricesJson.map((json) {
            try {
              // Try to map using the new response format 
              return FuelPrice(
                id: json['pricingId'],
                petrolPumpId: petrolPumpId,
                fuelTypeId: fuelTypeId,
                fuelType: fuelType,
                pricePerLiter: json['pricePerLiter']?.toDouble() ?? 0.0,
                effectiveFrom: json['effectiveFrom'] != null 
                  ? DateTime.parse(json['effectiveFrom']) 
                  : DateTime.now(),
                isActive: json['isActive'] == true,
                lastUpdatedBy: json['lastUpdatedByName'] ?? '',
              );
            } catch (e) {
              developer.log('PricingRepository: Error parsing price history: $e');
              print('DEBUG: Error parsing price history: $e');
              return null;
            }
          }).where((price) => price != null).cast<FuelPrice>().toList();

          developer.log('PricingRepository: Returning ${prices.length} historical prices');
          return ApiResponse<List<FuelPrice>>(
            success: true,
            data: prices,
          );
        } else {
          developer.log('PricingRepository: Invalid response format for price history');
          return ApiResponse<List<FuelPrice>>(
            success: false,
            errorMessage: 'Invalid response format',
            data: [],
          );
        }
      } else {
        developer.log('PricingRepository: Error fetching price history: ${response.statusCode}');
        print('DEBUG: Error fetching price history: ${response.statusCode}, body: ${response.body}');
        return ApiResponse<List<FuelPrice>>(
          success: false,
          errorMessage: 'Failed to fetch price history: ${response.statusCode}',
          data: [],
        );
      }
    } catch (e) {
      developer.log('PricingRepository: Exception when fetching price history: $e');
      print('DEBUG: Exception in price history: $e');
      return ApiResponse<List<FuelPrice>>(
        success: false,
        errorMessage: 'Error: $e',
        data: [],
      );
    }
  }

  // Delete a fuel price by ID
  Future<ApiResponse<bool>> deleteFuelPrice(String priceId) async {
    developer.log('PricingRepository: Deleting fuel price with ID: $priceId');
    
    try {
      final url = ApiConstants.getDeletePriceUrl(priceId);
      developer.log('PricingRepository: Delete API URL: $url');
      
      final headers = await _getHeaders();
      developer.log('PricingRepository: Delete request headers: ${headers.keys.join(', ')}');
      
      // Log token info for debugging
      final token = await _getAuthToken();
      if (token != null) {
        developer.log('PricingRepository: Auth token present for delete operation');
      } else {
        developer.log('PricingRepository: WARNING - No auth token for delete operation');
      }
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );

      developer.log('PricingRepository: Delete response status code: ${response.statusCode}');
      developer.log('PricingRepository: Delete response body: ${response.body}');
      
      if (response.statusCode == ApiConstants.statusOk || 
          response.statusCode == ApiConstants.statusNoContent) {
        developer.log('PricingRepository: Successfully deleted price');
        return ApiResponse<bool>(
          success: true,
          data: true,
        );
      } else {
        developer.log('PricingRepository: Error deleting price: ${response.statusCode}');
        String errorMessage = 'Failed to delete price: ${response.statusCode}';
        
        try {
          if (response.body.isNotEmpty) {
            final errorJson = json.decode(response.body);
            if (errorJson.containsKey('message')) {
              errorMessage = errorJson['message'];
            }
          }
        } catch (e) {
          developer.log('PricingRepository: Could not parse error response: $e');
        }
        
        return ApiResponse<bool>(
          success: false,
          errorMessage: errorMessage,
        );
      }
    } catch (e) {
      developer.log('PricingRepository: Exception when deleting price: $e');
      return ApiResponse<bool>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Update an existing fuel price
  Future<ApiResponse<FuelPrice>> updateFuelPrice(String priceId, FuelPrice price) async {
    developer.log('PricingRepository: Updating price with ID: $priceId');
    print('DEBUG: Updating fuel price with ID: $priceId');
    
    try {
      final url = ApiConstants.getUpdatePriceUrl(priceId);
      developer.log('PricingRepository: Update API URL: $url');
      print('DEBUG: Update API URL: $url');
      
      // Create the PUT request payload according to API requirements
      final Map<String, dynamic> payload = {
        'pricingId': priceId,
        'effectiveFrom': price.effectiveFrom.toIso8601String(),
        'pricePerLiter': price.pricePerLiter,
        'petrolPumpId': price.petrolPumpId,
        'fuelTypeId': price.fuelTypeId,
        'lastUpdatedBy': price.lastUpdatedBy,
      };
      
      // Add optional fields if they exist
      if (price.effectiveTo != null) {
        payload['effectiveTo'] = price.effectiveTo!.toIso8601String();
      }
      if (price.costPerLiter != null) {
        payload['costPerLiter'] = price.costPerLiter;
      }
      if (price.markupPercentage != null) {
        payload['markupPercentage'] = price.markupPercentage;
      }
      if (price.markupAmount != null) {
        payload['markupAmount'] = price.markupAmount;
      }
      
      print('DEBUG: Full update payload before encoding:');
      payload.forEach((key, value) {
        print('DEBUG: $key = $value');
      });
      
      developer.log('PricingRepository: Update payload structure: ${payload.keys.join(', ')}');
      
      final body = json.encode(payload);
      print('DEBUG: Update request JSON body: $body');
      developer.log('PricingRepository: Update request body: $body');
      
      final headers = await _getHeaders();
      // Ensure proper content type for JSON
      headers['Content-Type'] = 'application/json';
      
      print('DEBUG: Update request headers:');
      headers.forEach((key, value) {
        print('DEBUG: $key = $value');
      });
      
      // Print full request for debugging
      developer.log('PricingRepository: FULL UPDATE REQUEST: \nURL: $url\nHeaders: $headers\nBody: $body');
      print('DEBUG: Sending PUT request to $url');
      
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      print('DEBUG: Update response status code: ${response.statusCode}');
      print('DEBUG: Update response body: ${response.body}');
      developer.log('PricingRepository: Update response status code: ${response.statusCode}');
      developer.log('PricingRepository: Update response body: ${response.body}');

      if (response.statusCode == ApiConstants.statusOk || 
          response.statusCode == ApiConstants.statusNoContent) {
        print('DEBUG: Successfully updated price');
        developer.log('PricingRepository: Successfully updated price');
        
        // If the response has a body, parse it. Otherwise, return the original price.
        if (response.body.isNotEmpty) {
          final jsonData = json.decode(response.body);
          return ApiResponse<FuelPrice>(
            success: true,
            data: FuelPrice.fromJson(jsonData),
          );
        } else {
          return ApiResponse<FuelPrice>(
            success: true,
            data: price,
          );
        }
      } else {
        print('DEBUG: Error updating price: ${response.statusCode}');
        print('DEBUG: Error body: ${response.body}');
        developer.log('PricingRepository: Error updating price: ${response.statusCode}');
        String errorMessage = 'Failed to update price: ${response.statusCode}';
        try {
          if (response.body.isNotEmpty) {
            developer.log('PricingRepository: Error response body: ${response.body}');
            final errorJson = json.decode(response.body);
            print('DEBUG: Error JSON: $errorJson');
            developer.log('PricingRepository: Error response JSON: $errorJson');
            
            if (errorJson.containsKey('message')) {
              errorMessage = errorJson['message'];
              print('DEBUG: Error message: $errorMessage');
            } else if (errorJson.containsKey('error')) {
              errorMessage = errorJson['error'];
              print('DEBUG: Error message (error field): $errorMessage');
            } else if (errorJson.containsKey('errors')) {
              // Handle validation errors
              final errors = errorJson['errors'];
              print('DEBUG: Validation errors: $errors');
              if (errors is Map) {
                errorMessage = 'Validation errors: ${errors.values.join(', ')}';
              } else if (errors is List && errors.isNotEmpty) {
                errorMessage = 'Validation errors: ${errors.join(', ')}';
              }
            }
            
            // Print error details for debugging
            developer.log('PricingRepository: FAILED UPDATE REQUEST DETAILS:\nPayload: $payload\nResponse: ${response.body}');
          }
        } catch (e) {
          print('DEBUG: Could not parse error response: $e');
          developer.log('PricingRepository: Could not parse error response: $e');
        }
        
        return ApiResponse<FuelPrice>(
          success: false,
          errorMessage: errorMessage,
        );
      }
    } catch (e) {
      print('DEBUG: Exception when updating price: $e');
      developer.log('PricingRepository: Exception when updating price: $e');
      return ApiResponse<FuelPrice>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }
} 