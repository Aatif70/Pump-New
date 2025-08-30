import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance_model.dart';
import 'api_constants.dart';
import 'api_response.dart';




class AttendanceRepository {
  // Method to check-in employee
  Future<ApiResponse<bool>> checkIn({
    required String employeeId,
    required String shiftId,
    required DateTime checkInTime,
    required String checkInLocation,
    String? remarks,
  }) async {
    try {
      log('Checking in employee: $employeeId for shift: $shiftId');
      
      // Get auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        return ApiResponse<bool>(
          success: false,
          data: false,
          errorMessage: 'Authentication token not found',
        );
      }



      // Prepare request
      final url = ApiConstants.getCheckInUrl();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };



      // Prepare body
      final body = jsonEncode({
        'employeeId': employeeId,
        'shiftId': shiftId,
        'checkInTime': checkInTime.toUtc().toIso8601String(),
        'checkInLocation': checkInLocation,
        'remarks': remarks ?? '',
      });
      
      log('Check-in request URL: $url');
      log('Check-in request body: $body');



      // Make request
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );



      
      log('Check-in response status code: ${response.statusCode}');
      log('Check-in response body: ${response.body}');
      
      if (response.statusCode == ApiConstants.statusCreated || 
          response.statusCode == ApiConstants.statusOk) {
        return ApiResponse<bool>(
          success: true,
          data: true,
        );
      } else {
        String errorMessage = 'Failed to check in. Status code: ${response.statusCode}';
        
        try {
          final responseData = json.decode(response.body);
          if (responseData is Map && responseData.containsKey(ApiConstants.errorMessageKey)) {
            errorMessage = responseData[ApiConstants.errorMessageKey];
          }
        } catch (e) {
          log('Error parsing error message: $e');
        }
        
        return ApiResponse<bool>(
          success: false,
          data: false,
          errorMessage: errorMessage,
        );
      }
    } catch (e) {
      log('Exception in check-in: $e');
      return ApiResponse<bool>(
        success: false,
        data: false,
        errorMessage: 'Exception occurred: $e',
      );
    }
  }
  
  // Method to check-out employee
  Future<ApiResponse<bool>> checkOut({
    required String employeeAttendanceId,
    required DateTime checkOutTime,
    required String checkOutLocation,
    String? remarks,
  }) async {
    try {
      log('Checking out employee attendance: $employeeAttendanceId');
      
      // Get auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        return ApiResponse<bool>(
          success: false,
          data: false,
          errorMessage: 'Authentication token not found',
        );
      }
      
      // Prepare request
      final url = ApiConstants.getCheckOutUrl();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      // Prepare body
      final body = jsonEncode({
        'employeeAttendanceId': employeeAttendanceId,
        'checkOutTime': checkOutTime.toUtc().toIso8601String(),
        'checkOutLocation': checkOutLocation,
        'remarks': remarks ?? '',
      });
      
      log('Check-out request URL: $url');
      log('Check-out request body: $body');
      
      // Make request
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      
      log('Check-out response status code: ${response.statusCode}');
      log('Check-out response body: ${response.body}');
      
      if (response.statusCode == ApiConstants.statusCreated || 
          response.statusCode == ApiConstants.statusOk) {
        return ApiResponse<bool>(
          success: true,
          data: true,
        );
      } else {
        String errorMessage = 'Failed to check out. Status code: ${response.statusCode}';
        
        try {
          final responseData = json.decode(response.body);
          if (responseData is Map && responseData.containsKey(ApiConstants.errorMessageKey)) {
            errorMessage = responseData[ApiConstants.errorMessageKey];
          }
        } catch (e) {
          log('Error parsing error message: $e');
        }
        
        return ApiResponse<bool>(
          success: false,
          data: false,
          errorMessage: errorMessage,
        );
      }
    } catch (e) {
      log('Exception in check-out: $e');
      return ApiResponse<bool>(
        success: false,
        data: false,
        errorMessage: 'Exception occurred: $e',
      );
    }
  }
  
  // Method to get employee attendance history
  Future<ApiResponse<List<dynamic>>> getAttendanceHistory(String employeeId) async {
    try {
      log('Getting attendance history for employee: $employeeId');
      
      // Get auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        return ApiResponse<List<dynamic>>(
          success: false,
          data: [],
          errorMessage: 'Authentication token not found',
        );
      }
      
      // Prepare request
      final url = ApiConstants.getAttendanceByEmployeeUrl(employeeId);
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      log('Attendance history request URL: $url');
      
      // Make request
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      log('Attendance history response status code: ${response.statusCode}');
      log('Attendance history response body: ${response.body}');
      
      if (response.statusCode == ApiConstants.statusOk) {
        final responseData = json.decode(response.body);
        
        if (responseData is Map && responseData.containsKey('data') && responseData['data'] is List) {
          return ApiResponse<List<dynamic>>(
            success: true,
            data: responseData['data'],
          );
        } else if (responseData is List) {
          return ApiResponse<List<dynamic>>(
            success: true,
            data: responseData,
          );
        } else {
          return ApiResponse<List<dynamic>>(
            success: false,
            data: [],
            errorMessage: 'Invalid response format',
          );
        }
      } else {
        String errorMessage = 'Failed to get attendance history. Status code: ${response.statusCode}';
        
        try {
          final responseData = json.decode(response.body);
          if (responseData is Map && responseData.containsKey(ApiConstants.errorMessageKey)) {
            errorMessage = responseData[ApiConstants.errorMessageKey];
          }
        } catch (e) {
          log('Error parsing error message: $e');
        }
        
        return ApiResponse<List<dynamic>>(
          success: false,
          data: [],
          errorMessage: errorMessage,
        );
      }
    } catch (e) {
      log('Exception in get attendance history: $e');
      return ApiResponse<List<dynamic>>(
        success: false,
        data: [],
        errorMessage: 'Exception occurred: $e',
      );
    }
  }
  
  // Method to get active attendance record for an employee
  Future<ApiResponse<String?>> getActiveAttendanceId(String employeeId) async {
    try {
      log('Getting active attendance for employee: $employeeId');
      
      // Get auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        return ApiResponse<String?>(
          success: false,
          data: null,
          errorMessage: 'Authentication token not found',
        );
      }
      
      // Prepare request
      final url = ApiConstants.getActiveAttendanceUrl(employeeId);
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      log('Active attendance request URL: $url');
      
      // Make request
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      log('Active attendance response status code: ${response.statusCode}');
      log('Active attendance response body: ${response.body}');
      
      if (response.statusCode == ApiConstants.statusOk) {
        final responseData = json.decode(response.body);
        
        if (responseData is Map && responseData.containsKey('data')) {
          final data = responseData['data'];
          if (data is Map && data.containsKey('employeeAttendanceId')) {
            return ApiResponse<String?>(
              success: true,
              data: data['employeeAttendanceId']?.toString(),
            );
          }
        }
        
        return ApiResponse<String?>(
          success: false,
          data: null,
          errorMessage: 'No active attendance record found',
        );
      } else {
        String errorMessage = 'Failed to get active attendance. Status code: ${response.statusCode}';
        
        try {
          final responseData = json.decode(response.body);
          if (responseData is Map && responseData.containsKey(ApiConstants.errorMessageKey)) {
            errorMessage = responseData[ApiConstants.errorMessageKey];
          }
        } catch (e) {
          log('Error parsing error message: $e');
        }
        
        return ApiResponse<String?>(
          success: false,
          data: null,
          errorMessage: errorMessage,
        );
      }
    } catch (e) {
      log('Exception in get active attendance: $e');
      return ApiResponse<String?>(
        success: false,
        data: null,
        errorMessage: 'Exception occurred: $e',
      );
    }
  }

  // Fetch daily attendance for a specific date
  Future<ApiResponse<List<EmployeeAttendance>>> getDailyAttendance(DateTime date, String petrolPumpId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        return ApiResponse(
          success: false,
          errorMessage: 'No authentication token found',
          data: null,
        );
      }

      final url = ApiConstants.getDailyAttendanceUrl(petrolPumpId, date);
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      log('getDailyAttendance response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == ApiConstants.statusOk) {
        final responseBody = json.decode(response.body);
        if (responseBody['success'] == true) {
          final List<dynamic> attendanceDataList = responseBody['data'] ?? [];
          final attendances = attendanceDataList.map((json) => EmployeeAttendance.fromJson(json)).toList();
          return ApiResponse(
            success: true,
            data: attendances,
          );
        } else {
          return ApiResponse(
            success: false,
            errorMessage: responseBody['message'] ?? 'Failed to get daily attendance',
            data: null,
          );
        }
      } else {
        return _handleHttpError(response);
      }
    } catch (e) {
      log('Error in getDailyAttendance: $e');
      return ApiResponse(
        success: false,
        errorMessage: 'Exception occurred: $e',
        data: null,
      );
    }
  }

  // Fetch daily attendance report for a specific date
  Future<ApiResponse<DailyAttendanceReport>> getDailyAttendanceReport(DateTime date, String petrolPumpId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        return ApiResponse(
          success: false,
          errorMessage: 'No authentication token found',
          data: null,
        );
      }

      final url = ApiConstants.getDailyAttendanceReportUrl(petrolPumpId, date);
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      log('getDailyAttendanceReport response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == ApiConstants.statusOk) {
        final responseBody = json.decode(response.body);
        if (responseBody['success'] == true) {
          final reportData = responseBody['data'];
          if (reportData != null) {
            final report = DailyAttendanceReport.fromJson(reportData);
            return ApiResponse(
              success: true,
              data: report,
            );
          } else {
            return ApiResponse(
              success: false,
              errorMessage: 'No report data found',
              data: null,
            );
          }
        } else {
          return ApiResponse(
            success: false,
            errorMessage: responseBody['message'] ?? 'Failed to get attendance report',
            data: null,
          );
        }
      } else {
        return _handleHttpError(response);
      }
    } catch (e) {
      log('Error in getDailyAttendanceReport: $e');
      return ApiResponse(
        success: false,
        errorMessage: 'Exception occurred: $e',
        data: null,
      );
    }
  }

  // Fetch late arrivals for a specific date
  Future<ApiResponse<List<EmployeeAttendance>>> getLateArrivals(DateTime date, String petrolPumpId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        return ApiResponse(
          success: false,
          errorMessage: 'No authentication token found',
          data: null,
        );
      }

      final url = ApiConstants.getLateArrivalsUrl(petrolPumpId, date);
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      log('getLateArrivals response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == ApiConstants.statusOk) {
        final responseBody = json.decode(response.body);
        if (responseBody['success'] == true) {
          final List<dynamic> lateArrivalsDataList = responseBody['data'] ?? [];
          final lateArrivals = lateArrivalsDataList.map((json) => EmployeeAttendance.fromJson(json)).toList();
          return ApiResponse(
            success: true,
            data: lateArrivals,
          );
        } else {
          return ApiResponse(
            success: false,
            errorMessage: responseBody['message'] ?? 'Failed to get late arrivals',
            data: null,
          );
        }
      } else {
        return _handleHttpError(response);
      }
    } catch (e) {
      log('Error in getLateArrivals: $e');
      return ApiResponse(
        success: false,
        errorMessage: 'Exception occurred: $e',
        data: null,
      );
    }
  }

  // Helper method to handle HTTP errors
  ApiResponse<T> _handleHttpError<T>(http.Response response) {
    switch (response.statusCode) {
      case ApiConstants.statusUnauthorized:
        return ApiResponse(
          success: false,
          errorMessage: ApiConstants.unAuthorized,
          data: null,
        );
      case ApiConstants.statusBadRequest:
        final errorBody = json.decode(response.body);
        final errorMsg = errorBody['message'] ?? 'Bad request';
        return ApiResponse(
          success: false,
          errorMessage: errorMsg,
          data: null,
        );
      case ApiConstants.statusServerError:
        return ApiResponse(
          success: false,
          errorMessage: 'Server error occurred',
          data: null,
        );
      default:
        return ApiResponse(
          success: false,
          errorMessage: 'HTTP error ${response.statusCode}',
          data: null,
        );
    }
  }

  // Helper method to make authenticated requests
  Future<http.Response> makeAuthenticatedRequest(Future<http.Response> Function() requestFunction) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiConstants.authTokenKey);
    
    if (token == null) {
      throw Exception('No authentication token found');
    }
    
    return requestFunction();
  }

  // Get attendance summary for an employee within a date range
  Future<ApiResponse<AttendanceSummary>> getEmployeeAttendanceSummary(
    String employeeId,
    DateTime startDate,
    DateTime endDate
  ) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/api/Attendance/employee/$employeeId/summary'
        '?startDate=${startDate.toIso8601String()}'
        '&endDate=${endDate.toIso8601String()}'
      );
      
      print('🔍 GET request to: $uri');
      
      // Get auth token directly to debug
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        print('❌ Authentication token is null');
        return ApiResponse<AttendanceSummary>(
          success: false,
          errorMessage: 'No authentication token found',
        );
      }
      
      print('🔑 Token found, length: ${token.length}');
      print('🔑 Token first 20 chars: ${token.substring(0, math.min(20, token.length))}...');
      
      // Make request with explicit headers instead of using the helper method
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      print('📊 Response status code: ${response.statusCode}');
      print('📊 Response body length: ${response.body.length}');
      print('📊 Raw response body: ${response.body}');
      
      // Handle authentication error specifically
      if (response.statusCode == 401) {
        print('🔒 Authentication error (401 Unauthorized)');
        return ApiResponse<AttendanceSummary>(
          success: false,
          errorMessage: 'Authentication failed. Please log in again.',
        );
      }
      
      // Handle empty response
      if (response.body.isEmpty) {
        print('⚠️ Empty response body received');
        return ApiResponse<AttendanceSummary>(
          success: false,
          errorMessage: 'Server returned an empty response',
        );
      }
      
      try {
        final responseJson = json.decode(response.body);
        print('📊 Decoded JSON: $responseJson');
        
        if (response.statusCode == 200 && responseJson['success'] == true) {
          final dynamic data = responseJson['data'];
          if (data == null) {
            print('⚠️ Response success is true but data is null');
            return ApiResponse<AttendanceSummary>(
              success: false,
              errorMessage: 'No attendance data available',
            );
          }
          
          print('📊 Attendance data received, parsing...');
          final attendanceSummary = AttendanceSummary.fromJson(data);
          return ApiResponse<AttendanceSummary>(
            success: true,
            data: attendanceSummary,
          );
        } else {
          print('⚠️ API returned error: ${responseJson['message']}');
          return ApiResponse<AttendanceSummary>(
            success: false,
            errorMessage: responseJson['message'] ?? 'Failed to get attendance summary',
          );
        }
      } catch (jsonError) {
        print('❌ JSON parse error: $jsonError');
        print('❌ Response that caused error: ${response.body}');
        return ApiResponse<AttendanceSummary>(
          success: false,
          errorMessage: 'Error parsing server response: $jsonError',
        );
      }
    } catch (e) {
      print('❌ Exception in getEmployeeAttendanceSummary: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return ApiResponse<AttendanceSummary>(
        success: false,
        errorMessage: 'Error getting attendance summary: $e',
      );
    }
  }

  // Get active attendance for an employee
  Future<ApiResponse<AttendanceDetail>> getEmployeeActiveAttendance(
    String employeeId,
  ) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/api/Attendance/employee/$employeeId/active'
      );

      print('🔍 GET active attendance request to: $uri');
      
      // Get auth token directly to debug
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        print('❌ Authentication token is null');
        return ApiResponse<AttendanceDetail>(
          success: false,
          errorMessage: 'No authentication token found',
        );
      }
      
      // Make request with explicit headers
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      print('📊 Active attendance response status code: ${response.statusCode}');
      print('📊 Active attendance response body length: ${response.body.length}');
      
      // Handle authentication error
      if (response.statusCode == 401) {
        print('🔒 Authentication error (401 Unauthorized)');
        return ApiResponse<AttendanceDetail>(
          success: false,
          errorMessage: 'Authentication failed. Please log in again.',
        );
      }
      
      // Handle empty response
      if (response.body.isEmpty) {
        print('⚠️ Empty response body received');
        return ApiResponse<AttendanceDetail>(
          success: false,
          errorMessage: 'Server returned an empty response',
        );
      }

      try {
        final responseJson = json.decode(response.body);

        if (response.statusCode == 200 && responseJson['success'] == true) {
          final dynamic data = responseJson['data'];
          if (data == null) {
            return ApiResponse<AttendanceDetail>(
              success: false,
              errorMessage: 'No active attendance found',
            );
          }
          
          final attendanceDetail = AttendanceDetail.fromJson(data);
          return ApiResponse<AttendanceDetail>(
            success: true,
            data: attendanceDetail,
          );
        } else {
          return ApiResponse<AttendanceDetail>(
            success: false,
            errorMessage: responseJson['message'] ?? 'No active attendance found',
          );
        }
      } catch (jsonError) {
        print('❌ JSON parse error: $jsonError');
        return ApiResponse<AttendanceDetail>(
          success: false,
          errorMessage: 'Error parsing server response: $jsonError',
        );
      }
    } catch (e) {
      print('❌ Exception in getEmployeeActiveAttendance: $e');
      return ApiResponse<AttendanceDetail>(
        success: false,
        errorMessage: 'Error getting active attendance: $e',
      );
    }
  }

  // Method to check if employee is checked in
  Future<ApiResponse<bool>> isEmployeeCheckedIn(String employeeId) async {
    try {
      log('Checking if employee is checked in: $employeeId');
      
      // Get auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        return ApiResponse<bool>(
          success: false,
          data: false,
          errorMessage: 'Authentication token not found',
        );
      }
      
      // Prepare request
      final url = ApiConstants.getIsCheckedInUrl(employeeId);
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      log('Is checked in request URL: $url');
      
      // Make request
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      log('Is checked in response status code: ${response.statusCode}');
      log('Is checked in response body: ${response.body}');
      
      if (response.statusCode == ApiConstants.statusOk) {
        final responseData = json.decode(response.body);
        
        if (responseData is Map && responseData.containsKey('data')) {
          // Extract the boolean value from the response data
          final isCheckedIn = responseData['data'] as bool;
          
          return ApiResponse<bool>(
            success: true,
            data: isCheckedIn,
          );
        } else {
          return ApiResponse<bool>(
            success: false,
            data: false,
            errorMessage: 'Invalid response format',
          );
        }
      } else {
        String errorMessage = 'Failed to check status. Status code: ${response.statusCode}';
        
        try {
          final responseData = json.decode(response.body);
          if (responseData is Map && responseData.containsKey(ApiConstants.errorMessageKey)) {
            errorMessage = responseData[ApiConstants.errorMessageKey];
          }
        } catch (e) {
          log('Error parsing error message: $e');
        }
        
        return ApiResponse<bool>(
          success: false,
          data: false,
          errorMessage: errorMessage,
        );
      }
    } catch (e) {
      log('Exception in isEmployeeCheckedIn: $e');
      return ApiResponse<bool>(
        success: false,
        data: false,
        errorMessage: 'Exception occurred: $e',
      );
    }
  }
}