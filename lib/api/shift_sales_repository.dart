import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shift_sale_model.dart';
import '../models/shift_sales_model.dart' as shift_model;
import '../models/sales_statistics_model.dart';
import 'api_constants.dart';
import '../utils/jwt_decoder.dart';

class ShiftSalesRepository {
  // Use API constants for base URL
  final String baseUrl = ApiConstants.baseUrl;

  // Get auth token from SharedPreferences
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      developer.log('ShiftSalesRepository: Retrieved auth token: ${token != null ? 'Token exists' : 'No token found'}');
      return token;
    } catch (e) {
      developer.log('ShiftSalesRepository: Error getting auth token: $e');
      return null;
    }
  }

  // Get petrol pump ID from JWT token
  Future<String?> getPetrolPumpId() async {
    try {
      developer.log('ShiftSalesRepository: Attempting to get Petrol Pump ID from JWT token');
      
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('ShiftSalesRepository: No auth token found for getting petrol pump ID');
        return null;
      }
      
      // Extract petrolPumpId from token
      final petrolPumpId = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
      
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        developer.log('ShiftSalesRepository: PetrolPumpId not found in JWT token');
        // Fallback to stored value if available
        return prefs.getString('petrolPumpId');
      }
      
      developer.log('ShiftSalesRepository: PetrolPumpId from token: $petrolPumpId');
      
      // Cache the petrolPumpId for later use
      await prefs.setString('petrolPumpId', petrolPumpId);
      
      return petrolPumpId;
    } catch (e) {
      developer.log('ShiftSalesRepository: Error getting petrol pump ID: $e');
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
      developer.log('ShiftSalesRepository: Added auth token to headers');
    } else {
      developer.log('ShiftSalesRepository: Warning - No auth token available');
    }
    
    return headers;
  }

  // Submit shift sales
  Future<ApiResponse<shift_model.ShiftSales>> submitShiftSales(shift_model.ShiftSales shiftSales) async {
    print('SHIFT_SALES_DEBUG: ----- BEGIN SHIFT SALES SUBMISSION -----');
    print('SHIFT_SALES_DEBUG: Preparing to submit shift sales data');
    
    // Pre-submission validation
    if (shiftSales.nozzleId == null || shiftSales.nozzleId!.isEmpty) {
      print('SHIFT_SALES_DEBUG: Validation error - Missing nozzleId');
      return ApiResponse<shift_model.ShiftSales>(
        success: false,
        errorMessage: 'Missing nozzleId in sales data',
      );
    }
    
    if (shiftSales.shiftId == null || shiftSales.shiftId!.isEmpty) {
      print('SHIFT_SALES_DEBUG: Validation error - Missing shiftId');
      return ApiResponse<shift_model.ShiftSales>(
        success: false,
        errorMessage: 'Missing shiftId in sales data',
      );
    }
    
    if (shiftSales.employeeId == null || shiftSales.employeeId!.isEmpty) {
      print('SHIFT_SALES_DEBUG: Validation error - Missing employeeId');
      return ApiResponse<shift_model.ShiftSales>(
        success: false,
        errorMessage: 'Missing employeeId in sales data',
      );
    }
    
    if (shiftSales.petrolPumpId == null || shiftSales.petrolPumpId!.isEmpty) {
      print('SHIFT_SALES_DEBUG: Validation error - Missing petrolPumpId');
      return ApiResponse<shift_model.ShiftSales>(
        success: false,
        errorMessage: 'Missing petrolPumpId in sales data',
      );
    }
    
    if (shiftSales.litersSold <= 0) {
      print('SHIFT_SALES_DEBUG: Validation warning - litersSold is zero or negative: ${shiftSales.litersSold}');
      // Just a warning, not returning error
    }
    
    if (shiftSales.totalAmount <= 0) {
      print('SHIFT_SALES_DEBUG: Validation warning - totalAmount is zero or negative: ${shiftSales.totalAmount}');
      // Just a warning, not returning error
    }
    
    try {
      final url = '$baseUrl/api/ShiftSales';
      print('SHIFT_SALES_DEBUG: API URL: $url');
      
      final headers = await _getHeaders();
      print('SHIFT_SALES_DEBUG: Request headers: $headers');
      
      // Ensure petrolPumpId is correct
      if (shiftSales.petrolPumpId == null || shiftSales.petrolPumpId!.isEmpty) {
        final pumpId = await getPetrolPumpId();
        if (pumpId != null && pumpId.isNotEmpty) {
          shiftSales.petrolPumpId = pumpId;
          print('SHIFT_SALES_DEBUG: Updated petrolPumpId from token: $pumpId');
        }
      }
      
      final body = json.encode(shiftSales.toJson());
      print('SHIFT_SALES_DEBUG: Request body: $body');
      
      print('SHIFT_SALES_DEBUG: Sending HTTP POST request...');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      print('SHIFT_SALES_DEBUG: Response status code: ${response.statusCode}');
      print('SHIFT_SALES_DEBUG: Response headers: ${response.headers}');
      print('SHIFT_SALES_DEBUG: Response body: ${response.body}');

      if (response.statusCode == ApiConstants.statusOk || 
          response.statusCode == ApiConstants.statusCreated) {
        final jsonData = json.decode(response.body);
        print('SHIFT_SALES_DEBUG: Successfully submitted shift sales');
        print('SHIFT_SALES_DEBUG: ----- END SHIFT SALES SUBMISSION (SUCCESS) -----');
        return ApiResponse<shift_model.ShiftSales>(
          success: true,
          data: shift_model.ShiftSales.fromJson(jsonData),
        );
      } else {
        String errorDetail = 'Unknown error';
        
        // Special handling for 500 errors (server errors)
        if (response.statusCode == 500) {
          print('SHIFT_SALES_DEBUG: Server error detected (500)');
          errorDetail = 'Server error occurred. The server may be experiencing issues or the data may be invalid.';
          
          // Try to get additional context about what might have gone wrong
          print('SHIFT_SALES_DEBUG: Data that caused server error:');
          print('SHIFT_SALES_DEBUG: - Cash Amount: ${shiftSales.cashAmount}');
          print('SHIFT_SALES_DEBUG: - Credit Card Amount: ${shiftSales.creditCardAmount}');
          print('SHIFT_SALES_DEBUG: - UPI Amount: ${shiftSales.upiAmount}');
          print('SHIFT_SALES_DEBUG: - Liters Sold: ${shiftSales.litersSold}');
          print('SHIFT_SALES_DEBUG: - Total Amount: ${shiftSales.totalAmount}');
          print('SHIFT_SALES_DEBUG: - Price Per Liter: ${shiftSales.pricePerLiter}');
          
          // Verify that calculations are correct
          final double expectedTotal = shiftSales.litersSold * shiftSales.pricePerLiter;
          final double submittedTotal = shiftSales.totalAmount;
          final double paymentTotal = shiftSales.cashAmount + shiftSales.creditCardAmount + shiftSales.upiAmount;
          
          print('SHIFT_SALES_DEBUG: - Expected Total: $expectedTotal');
          print('SHIFT_SALES_DEBUG: - Submitted Total: $submittedTotal');
          print('SHIFT_SALES_DEBUG: - Total Payments: $paymentTotal');
          
          if (paymentTotal != submittedTotal) {
            errorDetail += ' Payment total (${paymentTotal.toStringAsFixed(2)}) does not match submitted total (${submittedTotal.toStringAsFixed(2)}).';
          }
          
          if ((expectedTotal - submittedTotal).abs() > 1.0) {
            errorDetail += ' Expected amount (${expectedTotal.toStringAsFixed(2)}) significantly differs from submitted total (${submittedTotal.toStringAsFixed(2)}).';
          }
        } else {
          // For non-500 errors, try to parse error details from response
          try {
            if (response.body.isNotEmpty) {
              Map<String, dynamic> errorData = json.decode(response.body);
              print('SHIFT_SALES_DEBUG: Parsed error data: $errorData');
              
              if (errorData.containsKey('message')) {
                errorDetail = errorData['message'];
              } else if (errorData.containsKey('error')) {
                errorDetail = errorData['error'];
              } else if (errorData.containsKey('errors')) {
                // Handle validation errors which often come in an 'errors' object
                errorDetail = errorData['errors'].toString();
              } else if (errorData.containsKey('title')) {
                // ASP.NET Core often returns error info in 'title'
                errorDetail = errorData['title'];
                if (errorData.containsKey('detail')) {
                  errorDetail += ': ${errorData['detail']}';
                }
              } else {
                errorDetail = response.body;
              }
            } else {
              errorDetail = 'No response body provided';
            }
          } catch (e) {
            print('SHIFT_SALES_DEBUG: Could not parse error response as JSON: $e');
            errorDetail = response.body.isNotEmpty ? response.body : 'Empty response body';
          }
        }
        
        print('SHIFT_SALES_DEBUG: Error submitting shift sales: ${response.statusCode} - $errorDetail');
        print('SHIFT_SALES_DEBUG: ----- END SHIFT SALES SUBMISSION (FAILURE) -----');
        return ApiResponse<shift_model.ShiftSales>(
          success: false,
          errorMessage: 'Failed to submit shift sales: ${response.statusCode} - $errorDetail',
        );
      }
    } catch (e) {
      print('SHIFT_SALES_DEBUG: Exception when submitting shift sales: $e');
      print('SHIFT_SALES_DEBUG: Stack trace: ${e is Error ? e.stackTrace : "Not available"}');
      print('SHIFT_SALES_DEBUG: ----- END SHIFT SALES SUBMISSION (EXCEPTION) -----');
      return ApiResponse<shift_model.ShiftSales>(
        success: false,
        errorMessage: 'Connection error: $e',
      );
    }
  }

  Future<ApiResponse<List<ShiftSale>>> getShiftSalesByDateRange(String petrolPumpId, DateTime startDate, DateTime endDate) async {
    try {
      developer.log('ShiftSalesRepository: Fetching shift sales for date range: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
      
      // Get stored auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null || token.isEmpty) {
        developer.log('ShiftSalesRepository: No auth token found');
        return ApiResponse(
          success: false,
          errorMessage: 'Authentication required. Please log in again.',
        );
      }
      
      // Format dates as ISO 8601 strings for the API
      final formattedStartDate = startDate.toIso8601String();
      final formattedEndDate = endDate.toIso8601String();
      
      final url = '$baseUrl/api/ShiftSales/date-range?petrolPumpId=$petrolPumpId&startDate=$formattedStartDate&endDate=$formattedEndDate';
      developer.log('ShiftSalesRepository: API URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      developer.log('ShiftSalesRepository: Response status: ${response.statusCode}');
      
      if (response.statusCode == ApiConstants.statusOk) {
        // Log the raw response for debugging
        developer.log('ShiftSalesRepository: Raw response: ${response.body}');
        
        try {
          final responseData = json.decode(response.body);
          
          if (responseData is List) {
            List<ShiftSale> shiftSales = [];
            
            // Parse each item with detailed error handling
            for (var i = 0; i < responseData.length; i++) {
              try {
                final item = responseData[i];
                
                // Add fields if they're missing to avoid null errors
                final Map<String, dynamic> processedItem = Map<String, dynamic>.from(item);
                if (!processedItem.containsKey('totalAmount')) {
                  processedItem['totalAmount'] = 0.0;
                }
                if (!processedItem.containsKey('litersSold')) {
                  processedItem['litersSold'] = 0.0;
                }
                
                shiftSales.add(ShiftSale.fromJson(processedItem));
              } catch (e) {
                developer.log('ShiftSalesRepository: Error parsing item $i: $e');
                // Continue with other items instead of failing completely
              }
            }
            
            developer.log('ShiftSalesRepository: Successfully parsed ${shiftSales.length} shift sales');
            return ApiResponse(
              success: true,
              data: shiftSales,
            );
          } else {
            developer.log('ShiftSalesRepository: Unexpected response format, expected List but got: ${responseData.runtimeType}');
            return ApiResponse(
              success: false,
              errorMessage: 'Unexpected response format: expected List',
            );
          }
        } catch (e) {
          developer.log('ShiftSalesRepository: Error parsing response: $e');
          developer.log('ShiftSalesRepository: Response body that caused error: ${response.body}');
          return ApiResponse(
            success: false,
            errorMessage: 'Error parsing response: $e',
          );
        }
      } else {
        developer.log('ShiftSalesRepository: Error response - ${response.statusCode}: ${response.body}');
        return ApiResponse(
          success: false,
          errorMessage: 'Failed to fetch shift sales: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('ShiftSalesRepository: Exception - $e');
      return ApiResponse(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  Future<ApiResponse<List<ShiftSale>>> getShiftSalesByEmployee(String employeeId) async {
    try {
      developer.log('ShiftSalesRepository: Fetching shift sales for employee: $employeeId');
      
      // Get stored auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null || token.isEmpty) {
        developer.log('ShiftSalesRepository: No auth token found');
        return ApiResponse(
          success: false,
          errorMessage: 'Authentication required. Please log in again.',
        );
      }
      
      final url = ApiConstants.getShiftSalesByEmployeeUrl(employeeId);
      developer.log('ShiftSalesRepository: API URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      developer.log('ShiftSalesRepository: Response status: ${response.statusCode}');
      
      if (response.statusCode == ApiConstants.statusOk) {
        // Log the raw response for debugging
        developer.log('ShiftSalesRepository: Raw response: ${response.body}');
        
        try {
          final responseData = json.decode(response.body);
          
          // Check if the response is wrapped in a data field
          final List<dynamic> salesData;
          if (responseData is Map<String, dynamic> && responseData.containsKey('data')) {
            // New format: { "data": [...], "success": true, ... }
            salesData = responseData['data'] as List<dynamic>;
            developer.log('ShiftSalesRepository: Found data wrapper in response');
          } else if (responseData is List) {
            // Old format: direct array
            salesData = responseData;
            developer.log('ShiftSalesRepository: Response is a direct array');
          } else {
            developer.log('ShiftSalesRepository: Unexpected response format: ${responseData.runtimeType}');
            return ApiResponse(
              success: false,
              errorMessage: 'Unexpected response format: Expected List or data wrapper',
            );
          }
          
          List<ShiftSale> shiftSales = [];
          
          // Parse each item with detailed error handling
          for (var i = 0; i < salesData.length; i++) {
            try {
              final item = salesData[i];
              
              // Add fields if they're missing to avoid null errors
              final Map<String, dynamic> processedItem = Map<String, dynamic>.from(item);
              if (!processedItem.containsKey('totalAmount')) {
                processedItem['totalAmount'] = 0.0;
              }
              if (!processedItem.containsKey('litersSold')) {
                processedItem['litersSold'] = 0.0;
              }
              
              shiftSales.add(ShiftSale.fromJson(processedItem));
            } catch (e) {
              developer.log('ShiftSalesRepository: Error parsing item $i: $e');
              // Continue with other items instead of failing completely
            }
          }
          
          developer.log('ShiftSalesRepository: Successfully parsed ${shiftSales.length} shift sales for employee');
          return ApiResponse(
            success: true,
            data: shiftSales,
          );
        } catch (e) {
          developer.log('ShiftSalesRepository: Error parsing response: $e');
          developer.log('ShiftSalesRepository: Response body that caused error: ${response.body}');
          return ApiResponse(
            success: false,
            errorMessage: 'Error parsing response: $e',
          );
        }
      } else {
        developer.log('ShiftSalesRepository: Error response - ${response.statusCode}: ${response.body}');
        return ApiResponse(
          success: false,
          errorMessage: 'Failed to fetch shift sales for employee: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('ShiftSalesRepository: Exception - $e');
      return ApiResponse(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get sales statistics for a date range
  Future<ApiResponse<SalesStatistics>> getSalesStatistics(DateTime startDate, DateTime endDate) async {
    try {
      developer.log('ShiftSalesRepository: Fetching sales statistics for date range: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
      
      // Get petrol pump ID from JWT token
      final petrolPumpId = await getPetrolPumpId();
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        developer.log('ShiftSalesRepository: Failed to get petrol pump ID for sales statistics');
        return ApiResponse<SalesStatistics>(
          success: false,
          errorMessage: 'Petrol pump ID not found. Please login again.',
        );
      }
      
      // Get headers with auth token
      final headers = await _getHeaders();
      
      // Format dates as ISO 8601 strings for the API
      final formattedStartDate = startDate.toIso8601String();
      final formattedEndDate = endDate.toIso8601String();
      
      // First try to fetch from statistics endpoint
      var url = '$baseUrl/api/ShiftSales/statistics?petrolPumpId=$petrolPumpId&startDate=$formattedStartDate&endDate=$formattedEndDate';
      developer.log('ShiftSalesRepository: API URL: $url');
      
      var response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      // If statistics endpoint fails or returns no data, fetch from recent sales endpoint
      if (response.statusCode != ApiConstants.statusOk || response.body.isEmpty || response.body == '{}' || response.body == '[]') {
        // Fetch from recent sales endpoint and build statistics manually
        url = '$baseUrl/api/ShiftSales/recent/$petrolPumpId?count=30';
        developer.log('ShiftSalesRepository: Falling back to recent sales API URL: $url');
        
        response = await http.get(
          Uri.parse(url),
          headers: headers,
        );
        
        if (response.statusCode == ApiConstants.statusOk) {
          try {
            developer.log('ShiftSalesRepository: Raw response from recent sales: ${response.body}');
            
            final List<dynamic> recentSales = json.decode(response.body);
            
            if (recentSales.isEmpty) {
              return ApiResponse(
                success: false,
                errorMessage: 'No sales data available',
              );
            }
            
            // Manually calculate statistics from recent sales data
            double totalLitersSold = 0.0;
            double totalAmount = 0.0;
            double cashAmount = 0.0;
            double creditCardAmount = 0.0;
            double upiAmount = 0.0;
            int totalTransactions = recentSales.length;
            
            // For tracking top performing shift
            Map<String, double> shiftPerformance = {};
            Map<String, String> shiftNames = {};
            
            // For tracking sales by fuel type
            Map<String, Map<String, double>> salesByFuelType = {};
            
            // For tracking sales by day
            Map<String, Map<String, dynamic>> salesByDay = {};
            
            // For tracking sales by shift
            Map<String, Map<String, dynamic>> salesByShift = {};
            
            for (var sale in recentSales) {
              // Ensure each sale is a Map
              if (sale is Map<String, dynamic>) {
                // Add to total
                double currentLiters = sale['litersSold']?.toDouble() ?? 0.0;
                double currentAmount = sale['totalAmount']?.toDouble() ?? 0.0;
                
                totalLitersSold += currentLiters;
                totalAmount += currentAmount;
                
                // Add to payment methods
                cashAmount += sale['cashAmount']?.toDouble() ?? 0.0;
                creditCardAmount += sale['creditCardAmount']?.toDouble() ?? 0.0;
                upiAmount += sale['upiAmount']?.toDouble() ?? 0.0;
                
                // Track performance by shift
                String shiftId = sale['shiftId']?.toString() ?? '';
                String shiftName = 'Shift ${sale['shiftNumber']?.toString() ?? ''}';
                
                if (shiftId.isNotEmpty) {
                  if (!shiftPerformance.containsKey(shiftId)) {
                    shiftPerformance[shiftId] = 0.0;
                    shiftNames[shiftId] = shiftName;
                  }
                  shiftPerformance[shiftId] = (shiftPerformance[shiftId] ?? 0.0) + currentAmount;
                  
                  // Add to sales by shift
                  if (!salesByShift.containsKey(shiftId)) {
                    salesByShift[shiftId] = {
                      'litersSold': 0.0,
                      'amount': 0.0,
                      'shiftName': shiftName,
                    };
                  }
                  salesByShift[shiftId]!['litersSold'] = (salesByShift[shiftId]!['litersSold'] ?? 0.0) + currentLiters;
                  salesByShift[shiftId]!['amount'] = (salesByShift[shiftId]!['amount'] ?? 0.0) + currentAmount;
                }
                
                // Track sales by fuel type
                String fuelType = sale['fuelType']?.toString() ?? 'Unknown';
                if (fuelType.isNotEmpty) {
                  if (!salesByFuelType.containsKey(fuelType)) {
                    salesByFuelType[fuelType] = {
                      'litersSold': 0.0,
                      'amount': 0.0,
                    };
                  }
                  salesByFuelType[fuelType]!['litersSold'] = (salesByFuelType[fuelType]!['litersSold'] ?? 0.0) + currentLiters;
                  salesByFuelType[fuelType]!['amount'] = (salesByFuelType[fuelType]!['amount'] ?? 0.0) + currentAmount;
                }
                
                // Track sales by day
                if (sale['reportedAt'] != null) {
                  DateTime reportDate = DateTime.parse(sale['reportedAt'].toString());
                  String dateKey = '${reportDate.year}-${reportDate.month.toString().padLeft(2, '0')}-${reportDate.day.toString().padLeft(2, '0')}';
                  
                  if (!salesByDay.containsKey(dateKey)) {
                    salesByDay[dateKey] = {
                      'litersSold': 0.0,
                      'amount': 0.0,
                      'date': reportDate.toIso8601String(),
                    };
                  }
                  salesByDay[dateKey]!['litersSold'] = (salesByDay[dateKey]!['litersSold'] ?? 0.0) + currentLiters;
                  salesByDay[dateKey]!['amount'] = (salesByDay[dateKey]!['amount'] ?? 0.0) + currentAmount;
                }
              }
            }
            
            // Find top performing shift
            String topShiftId = '';
            double topAmount = 0.0;
            shiftPerformance.forEach((shiftId, amount) {
              if (amount > topAmount) {
                topAmount = amount;
                topShiftId = shiftId;
              }
            });
            
            // Prepare data for SalesStatistics model
            Map<String, dynamic> statsData = {
              'totalLitersSold': totalLitersSold,
              'totalAmount': totalAmount,
              'totalTransactions': totalTransactions,
              'cashAmount': cashAmount,
              'creditCardAmount': creditCardAmount,
              'upiAmount': upiAmount,
              'topPerformingShiftId': topShiftId,
              'topPerformingShiftName': shiftNames[topShiftId] ?? '',
              'topPerformingShiftAmount': topShiftId.isNotEmpty ? shiftPerformance[topShiftId] : null,
              'salesByFuelType': {},
              'salesByShift': [],
              'salesByDay': [],
            };
            
            // Add sales by fuel type to the stats data
            salesByFuelType.forEach((fuelType, data) {
              statsData['salesByFuelType'][fuelType] = {
                'litersSold': data['litersSold'],
                'amount': data['amount'],
              };
            });
            
            // Add sales by shift to the stats data
            salesByShift.forEach((shiftId, data) {
              statsData['salesByShift'].add({
                'shiftId': shiftId,
                'shiftName': data['shiftName'],
                'litersSold': data['litersSold'],
                'amount': data['amount'],
              });
            });
            
            // Add sales by day to the stats data
            salesByDay.forEach((dateKey, data) {
              statsData['salesByDay'].add({
                'date': data['date'],
                'litersSold': data['litersSold'],
                'amount': data['amount'],
              });
            });
            
            // Create the sales statistics object
            final salesStatistics = SalesStatistics.fromJson(statsData);
            
            developer.log('ShiftSalesRepository: Successfully created sales statistics from recent sales');
            return ApiResponse(
              success: true,
              data: salesStatistics,
            );
          } catch (e) {
            developer.log('ShiftSalesRepository: Error parsing recent sales: $e');
            return ApiResponse(
              success: false,
              errorMessage: 'Error parsing recent sales: $e',
            );
          }
        } else {
          developer.log('ShiftSalesRepository: Error from recent sales - ${response.statusCode}: ${response.body}');
          return ApiResponse(
            success: false,
            errorMessage: 'Failed to fetch recent sales: ${response.statusCode}',
          );
        }
      } else {
        // Original statistics endpoint was successful
        try {
          // Log raw response for debugging
          developer.log('ShiftSalesRepository: Raw response from statistics endpoint: ${response.body}');
          
          final responseData = json.decode(response.body);
          
          // Handle potential null or empty response
          if (responseData == null) {
            return ApiResponse(
              success: false,
              errorMessage: 'Empty response from server',
            );
          }
          
          // Create a sanitized version of the response data with default values
          Map<String, dynamic> sanitizedData = {
            'totalLitersSold': 0.0,
            'totalAmount': 0.0,
            'totalTransactions': 0,
            'cashAmount': 0.0,
            'creditCardAmount': 0.0,
            'upiAmount': 0.0,
            'salesByFuelType': <String, dynamic>{},
            'salesByShift': <dynamic>[],
            'salesByDay': <dynamic>[],
          };
          
          // Copy all fields from responseData to sanitizedData, if they exist
          if (responseData is Map<String, dynamic>) {
            // Copy basic fields
            if (responseData.containsKey('totalLitersSold')) {
              sanitizedData['totalLitersSold'] = responseData['totalLitersSold']?.toDouble() ?? 0.0;
            }
            
            if (responseData.containsKey('totalAmount')) {
              sanitizedData['totalAmount'] = responseData['totalAmount']?.toDouble() ?? 0.0;
            }
            
            if (responseData.containsKey('totalTransactions')) {
              sanitizedData['totalTransactions'] = responseData['totalTransactions'] ?? 0;
            }
            
            // Handle payment methods - NEW CODE
            if (responseData.containsKey('salesByPaymentMethod') && responseData['salesByPaymentMethod'] is Map) {
              final paymentMethods = responseData['salesByPaymentMethod'];
              sanitizedData['cashAmount'] = paymentMethods['cash']?.toDouble() ?? 0.0;
              sanitizedData['creditCardAmount'] = paymentMethods['creditCard']?.toDouble() ?? 0.0;
              sanitizedData['upiAmount'] = paymentMethods['upi']?.toDouble() ?? 0.0;
              
              developer.log('ShiftSalesRepository: Payment methods parsed - Cash: ${sanitizedData['cashAmount']}, Credit: ${sanitizedData['creditCardAmount']}, UPI: ${sanitizedData['upiAmount']}');
            } else {
              // Legacy code for backward compatibility
              if (responseData.containsKey('cashAmount')) {
                sanitizedData['cashAmount'] = responseData['cashAmount']?.toDouble() ?? 0.0;
              }
              
              if (responseData.containsKey('creditCardAmount')) {
                sanitizedData['creditCardAmount'] = responseData['creditCardAmount']?.toDouble() ?? 0.0;
              }
              
              if (responseData.containsKey('upiAmount')) {
                sanitizedData['upiAmount'] = responseData['upiAmount']?.toDouble() ?? 0.0;
              }
            }
            
            if (responseData.containsKey('topPerformingShiftId')) {
              sanitizedData['topPerformingShiftId'] = responseData['topPerformingShiftId'];
            }
            
            if (responseData.containsKey('topPerformingShiftName')) {
              sanitizedData['topPerformingShiftName'] = responseData['topPerformingShiftName'];
            }
            
            // Handle top performing shift - look for shiftNumber
            if (responseData.containsKey('salesByShift') && responseData['salesByShift'] is List && responseData['salesByShift'].isNotEmpty) {
              var highestAmount = 0.0;
              String? topShiftName;
              String? topShiftId;
              
              for (var shift in responseData['salesByShift']) {
                double shiftAmount = shift['totalAmount']?.toDouble() ?? 0.0;
                if (shiftAmount > highestAmount) {
                  highestAmount = shiftAmount;
                  topShiftName = 'Shift ${shift['shiftNumber']}';
                  topShiftId = shift['shiftId'] ?? '';
                }
              }
              
              if (topShiftName != null) {
                sanitizedData['topPerformingShiftName'] = topShiftName;
                sanitizedData['topPerformingShiftId'] = topShiftId;
                sanitizedData['topPerformingShiftAmount'] = highestAmount;
              }
            }
            
            if (responseData.containsKey('topPerformingShiftAmount')) {
              sanitizedData['topPerformingShiftAmount'] = responseData['topPerformingShiftAmount']?.toDouble();
            }
            
            // Handle salesByFuelType - check for array format first, then convert
            if (responseData.containsKey('salesByFuelType')) {
              try {
                Map<String, dynamic> fuelTypeMap = {};
                
                if (responseData['salesByFuelType'] is List) {
                  // Handle array format
                  for (var fuelSale in responseData['salesByFuelType']) {
                    if (fuelSale is Map && fuelSale.containsKey('fuelType')) {
                      String fuelType = fuelSale['fuelType'] ?? 'Unknown';
                      fuelTypeMap[fuelType] = {
                        'litersSold': fuelSale['litersSold']?.toDouble() ?? 0.0,
                        'amount': fuelSale['totalAmount']?.toDouble() ?? 0.0,
                      };
                    }
                  }
                } else if (responseData['salesByFuelType'] is Map) {
                  // Handle object format
                  (responseData['salesByFuelType'] as Map).forEach((key, value) {
                    if (value is Map) {
                      fuelTypeMap[key.toString()] = {
                        'litersSold': value['litersSold']?.toDouble() ?? 0.0,
                        'amount': value['amount']?.toDouble() ?? 0.0,
                      };
                    }
                  });
                }
                
                sanitizedData['salesByFuelType'] = fuelTypeMap;
              } catch (e) {
                developer.log('ShiftSalesRepository: Error parsing salesByFuelType: $e');
                sanitizedData['salesByFuelType'] = {};
              }
            }
            
            // Handle salesByShift
            if (responseData.containsKey('salesByShift') && responseData['salesByShift'] is List) {
              try {
                List<Map<String, dynamic>> shiftList = [];
                
                for (var item in responseData['salesByShift']) {
                  if (item is Map) {
                    shiftList.add({
                      'shiftId': item['shiftId'] ?? '',
                      'shiftName': 'Shift ${item['shiftNumber'] ?? '?'}',
                      'litersSold': item['litersSold']?.toDouble() ?? 0.0,
                      'amount': item['totalAmount']?.toDouble() ?? 0.0,
                    });
                  }
                }
                
                sanitizedData['salesByShift'] = shiftList;
              } catch (e) {
                developer.log('ShiftSalesRepository: Error parsing salesByShift: $e');
                sanitizedData['salesByShift'] = [];
              }
            }
            
            // Handle salesByDay
            if (responseData.containsKey('salesByDay') && responseData['salesByDay'] is List) {
              try {
                List<Map<String, dynamic>> daysList = [];
                
                for (var item in responseData['salesByDay']) {
                  if (item is Map) {
                    // Ensure date is in valid ISO format
                    String dateStr = item['date']?.toString() ?? DateTime.now().toIso8601String();
                    
                    daysList.add({
                      'date': dateStr,
                      'litersSold': item['litersSold']?.toDouble() ?? 0.0,
                      'amount': item['totalAmount']?.toDouble() ?? 0.0,
                    });
                  }
                }
                
                sanitizedData['salesByDay'] = daysList;
              } catch (e) {
                developer.log('ShiftSalesRepository: Error parsing salesByDay: $e');
                sanitizedData['salesByDay'] = [];
              }
            }
          }
          
          // Create the sales statistics object from the sanitized data
          final salesStatistics = SalesStatistics.fromJson(sanitizedData);
          
          developer.log('ShiftSalesRepository: Successfully parsed sales statistics');
          return ApiResponse(
            success: true,
            data: salesStatistics,
          );
        } catch (e) {
          developer.log('ShiftSalesRepository: Error parsing response: $e');
          developer.log('ShiftSalesRepository: Response body that caused error: ${response.body}');
          return ApiResponse(
            success: false,
            errorMessage: 'Error parsing response: $e',
          );
        }
      }
    } catch (e) {
      developer.log('ShiftSalesRepository: Exception - $e');
      return ApiResponse(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get shift summary data
  Future<ApiResponse<Map<String, dynamic>>> getShiftSummary(String shiftId) async {
    try {
      developer.log('ShiftSalesRepository: Fetching shift summary for shift: $shiftId');
      
      // Get headers with auth token
      final headers = await _getHeaders();
      
      final url = '$baseUrl/api/ShiftSales/summary/$shiftId';
      developer.log('ShiftSalesRepository: API URL: $url');
      
      var response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      if (response.statusCode == ApiConstants.statusOk) {
        developer.log('ShiftSalesRepository: Raw response from shift summary: ${response.body}');
        
        final responseData = json.decode(response.body);
        
        return ApiResponse(
          success: true,
          data: responseData,
        );
      } else {
        developer.log('ShiftSalesRepository: Error response - ${response.statusCode}: ${response.body}');
        return ApiResponse(
          success: false,
          errorMessage: 'Failed to fetch shift summary: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('ShiftSalesRepository: Exception when fetching shift summary: $e');
      return ApiResponse(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }
  
  // Get employee sales data
  Future<ApiResponse<List<dynamic>>> getEmployeeSales(String employeeId) async {
    try {
      developer.log('ShiftSalesRepository: Fetching sales for employee: $employeeId');
      
      // Get headers with auth token
      final headers = await _getHeaders();
      
      final url = '$baseUrl/api/ShiftSales/employee/$employeeId';
      developer.log('ShiftSalesRepository: API URL: $url');
      
      var response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      if (response.statusCode == ApiConstants.statusOk) {
        developer.log('ShiftSalesRepository: Raw response from employee sales: ${response.body}');
        
        final responseData = json.decode(response.body);
        
        // Check if response is wrapped in a data property
        if (responseData is Map<String, dynamic> && responseData.containsKey('data')) {
          final data = responseData['data'];
          if (data is List) {
            return ApiResponse(
              success: true,
              data: data,
            );
          } else {
            return ApiResponse(
              success: false,
              errorMessage: 'Unexpected response format: data property is not a List',
            );
          }
        } else if (responseData is List) {
          // Handle direct list response (old format)
          return ApiResponse(
            success: true,
            data: responseData,
          );
        } else {
          return ApiResponse(
            success: false,
            errorMessage: 'Unexpected response format: expected List or object with data property',
          );
        }
      } else {
        developer.log('ShiftSalesRepository: Error response - ${response.statusCode}: ${response.body}');
        return ApiResponse(
          success: false,
          errorMessage: 'Failed to fetch employee sales: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('ShiftSalesRepository: Exception when fetching employee sales: $e');
      return ApiResponse(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }
  
  // Get shift sales data
  Future<ApiResponse<List<dynamic>>> getShiftSales(String shiftId) async {
    try {
      developer.log('ShiftSalesRepository: Fetching sales for shift: $shiftId');
      
      // Get headers with auth token
      final headers = await _getHeaders();
      
      final url = '$baseUrl/api/ShiftSales/shift/$shiftId';
      developer.log('ShiftSalesRepository: API URL: $url');
      
      var response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      if (response.statusCode == ApiConstants.statusOk) {
        developer.log('ShiftSalesRepository: Raw response from shift sales: ${response.body}');
        
        final responseData = json.decode(response.body);
        
        // Check if response is wrapped in a data property
        if (responseData is Map<String, dynamic> && responseData.containsKey('data')) {
          final data = responseData['data'];
          if (data is List) {
            return ApiResponse(
              success: true,
              data: data,
            );
          } else {
            return ApiResponse(
              success: false,
              errorMessage: 'Unexpected response format: data property is not a List',
            );
          }
        } else if (responseData is List) {
          // Handle direct list response (old format)
          return ApiResponse(
            success: true,
            data: responseData,
          );
        } else {
          return ApiResponse(
            success: false,
            errorMessage: 'Unexpected response format: expected List or object with data property',
          );
        }
      } else {
        developer.log('ShiftSalesRepository: Error response - ${response.statusCode}: ${response.body}');
        return ApiResponse(
          success: false,
          errorMessage: 'Failed to fetch shift sales: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('ShiftSalesRepository: Exception when fetching shift sales: $e');
      return ApiResponse(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }
  
  // Get hourly sales pattern for a specific date
  Future<ApiResponse<HourlySalesPattern>> getHourlySalesPattern(DateTime date) async {
    try {
      developer.log('ShiftSalesRepository: Fetching hourly sales pattern for date: ${date.toString()}');
      
      // Get headers with auth token
      final headers = await _getHeaders();
      
      // Format date as YYYY-MM-DD
      final formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final url = '$baseUrl/api/Dashboard/sales/hourly-pattern?date=$formattedDate';
      developer.log('ShiftSalesRepository: API URL: $url');
      
      var response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      if (response.statusCode == ApiConstants.statusOk) {
        developer.log('ShiftSalesRepository: Raw response from hourly sales pattern: ${response.body}');
        
        final responseData = json.decode(response.body);
        
        return ApiResponse(
          success: true,
          data: HourlySalesPattern.fromJson(responseData),
        );
      } else {
        developer.log('ShiftSalesRepository: Error response - ${response.statusCode}: ${response.body}');
        return ApiResponse(
          success: false,
          errorMessage: 'Failed to fetch hourly sales pattern: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('ShiftSalesRepository: Exception when fetching hourly sales pattern: $e');
      return ApiResponse(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }
}

// API response class
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? errorMessage;

  ApiResponse({
    required this.success,
    this.data,
    this.errorMessage,
  });
} 