import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/daily_sales_report_model.dart';
import '../utils/shared_prefs.dart';
import '../api/api_constants.dart';
import '../api/api_response.dart';
import 'dart:developer' as developer;

class ReportingRepository {
  // Method to get daily sales report
  Future<ApiResponse<DailySalesReport>> getDailySalesReport({
    required DateTime date,
    String? employeeId,
    String? shiftId,
  }) async {
    try {
      developer.log('ReportingRepository: Fetching daily sales report');
      
      // Format the date to ISO string
      String formattedDate = date.toUtc().toIso8601String();
      
      // Build URL with query parameters
      String url = '${ApiConstants.baseUrl}/api/Reporting/daily-sales';
      
      // Create URI with query parameters
      Uri uri = Uri.parse(url).replace(queryParameters: {
        'date': formattedDate,
        if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
        if (shiftId != null && shiftId.isNotEmpty) 'shiftId': shiftId,
      });
      
      developer.log('ReportingRepository: Request URL: $uri');
      
      // Get auth token
      final token = await SharedPrefs.getAuthToken();
      if (token == null) {
        developer.log('ReportingRepository: No auth token found');
        return ApiResponse<DailySalesReport>(
          success: false,
          errorMessage: 'Authentication required',
        );
      }
      
      // Make the API request
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      developer.log('ReportingRepository: Response status: ${response.statusCode}');
      
      // Check response status
      if (response.statusCode == ApiConstants.statusOk) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        // Check for success flag in the response
        if (responseData['success'] == true && responseData['data'] != null) {
          final dailySalesReport = DailySalesReport.fromJson(responseData['data']);
          return ApiResponse<DailySalesReport>(
            success: true,
            data: dailySalesReport,
          );
        } else {
          return ApiResponse<DailySalesReport>(
            success: false,
            errorMessage: responseData['message'] ?? 'Failed to get report data',
          );
        }
      } else if (response.statusCode == ApiConstants.statusUnauthorized) {
        return ApiResponse<DailySalesReport>(
          success: false,
          errorMessage: 'Unauthorized access',
        );
      } else {
        return ApiResponse<DailySalesReport>(
          success: false,
          errorMessage: 'Failed to get report. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('ReportingRepository: Exception: $e');
      return ApiResponse<DailySalesReport>(
        success: false,
        errorMessage: 'Exception: $e',
      );
    }
  }
  
  // Method to get shifts by petrol pump ID with fallback URL formats
  Future<ApiResponse<List<dynamic>>> getShiftsByPetrolPumpId(String petrolPumpId) async {
    try {
      developer.log('ReportingRepository: Fetching shifts for petrol pump: $petrolPumpId');
      print('DEBUG: ReportingRepository - Fetching shifts for petrol pump ID: $petrolPumpId');
      
      // Get auth token
      final token = await SharedPrefs.getAuthToken();
      if (token == null) {
        print('DEBUG: ReportingRepository - Authentication token is null');
        return ApiResponse<List<dynamic>>(
          success: false,
          errorMessage: 'Authentication required',
        );
      }

      // Try multiple URL formats (the API endpoint might have changed)
      final List<String> urlFormats = [
        '${ApiConstants.baseUrl}/api/Shift/ByPump/$petrolPumpId',
        '${ApiConstants.baseUrl}/api/Shift/$petrolPumpId/shifts',
        '${ApiConstants.baseUrl}/api/Shift/ByPetrolPump/$petrolPumpId',
        '${ApiConstants.baseUrl}/api/Shift/ByPump?petrolPumpId=$petrolPumpId'
      ];
      
      // Common headers for all requests
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      // Try each URL format
      for (int i = 0; i < urlFormats.length; i++) {
        final url = urlFormats[i];
        print('DEBUG: ReportingRepository - Trying URL format ${i+1}: $url');
        
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: headers,
          );
          
          print('DEBUG: ReportingRepository - Format ${i+1} response status: ${response.statusCode}');
          
          if (response.statusCode == ApiConstants.statusOk) {
            try {
              final Map<String, dynamic> responseData = json.decode(response.body);
              print('DEBUG: ReportingRepository - Format ${i+1} response body: ${response.body}');
              
              if (responseData['success'] == true && responseData['data'] != null) {
                print('DEBUG: ReportingRepository - Format ${i+1} SUCCESS! Shifts count: ${responseData['data'].length}');
                return ApiResponse<List<dynamic>>(
                  success: true,
                  data: responseData['data'],
                );
              } else {
                print('DEBUG: ReportingRepository - Format ${i+1} had success=false or null data');
              }
            } catch (e) {
              print('DEBUG: ReportingRepository - Format ${i+1} JSON parsing error: $e');
            }
          }
        } catch (e) {
          print('DEBUG: ReportingRepository - Format ${i+1} request error: $e');
        }
      }
      
      // If we reach here, all URL formats failed
      print('DEBUG: ReportingRepository - All URL formats failed');
      return ApiResponse<List<dynamic>>(
        success: false,
        errorMessage: 'Failed to get shifts with all URL formats',
      );
    } catch (e) {
      developer.log('ReportingRepository: Exception getting shifts: $e');
      print('DEBUG: ReportingRepository - Exception getting shifts: $e');
      return ApiResponse<List<dynamic>>(
        success: false,
        errorMessage: 'Exception: $e',
      );
    }
  }
} 