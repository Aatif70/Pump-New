import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nozzle_reading_model.dart';
import '../utils/jwt_decoder.dart';
import 'api_constants.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import '../models/employee_nozzle_assignment_model.dart';

import '../utils/api_helper.dart';

class NozzleReadingRepository {
  final ApiHelper _apiHelper = ApiHelper();

  // Use API constants for base URL
  final String baseUrl = ApiConstants.baseUrl;

  // Get auth token from SharedPreferences
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      developer.log('NozzleReadingRepository: Retrieved auth token: ${token != null ? 'Token exists' : 'No token found'}');
      return token;
    } catch (e) {
      developer.log('NozzleReadingRepository: Error getting auth token: $e');
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
      developer.log('NozzleReadingRepository: Added auth token to headers');
    } else {
      developer.log('NozzleReadingRepository: Warning - No auth token available');
    }
    
    return headers;
  }

  // Get nozzle readings by employee
  Future<ApiResponse<List<NozzleReading>>> getNozzleReadingsByEmployee(String employeeId) async {
    developer.log('NozzleReadingRepository: Getting nozzle assignments for employee ID: $employeeId');
    try {
      final url = '$baseUrl/api/EmployeeNozzleAssignments/employee/$employeeId';
      developer.log('NozzleReadingRepository: API URL: $url');
      
      final headers = await _getHeaders();
      developer.log('NozzleReadingRepository: Request headers: $headers');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      developer.log('NozzleReadingRepository: Response status code: ${response.statusCode}');
      developer.log('NozzleReadingRepository: Response body: ${response.body}');

      if (response.statusCode == ApiConstants.statusOk) {
        final List<dynamic> jsonData = json.decode(response.body);
        developer.log('NozzleReadingRepository: Successfully parsed JSON data, count: ${jsonData.length}');
        
        final nozzleReadings = jsonData
            .map((data) => NozzleReading.fromJson(data))
            .toList();
        
        developer.log('NozzleReadingRepository: Returning ${nozzleReadings.length} nozzle assignments');
        return ApiResponse<List<NozzleReading>>(
          success: true,
          data: nozzleReadings,
        );
      } else {
        developer.log('NozzleReadingRepository: Error fetching nozzle assignments: ${response.statusCode}');
        developer.log('NozzleReadingRepository: Error response: ${response.body}');
        return ApiResponse<List<NozzleReading>>(
          success: false,
          errorMessage: 'Failed to fetch nozzle assignments: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('NozzleReadingRepository: Exception when fetching nozzle assignments: $e');
      return ApiResponse<List<NozzleReading>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }
  
  // Get nozzle readings by employee from the dedicated endpoint
  Future<ApiResponse<List<NozzleReading>>> getNozzleReadingsForEmployee(String employeeId) async {
    developer.log('NozzleReadingRepository: Getting nozzle readings for employee ID: $employeeId');
    print('NozzleReadingRepository: Getting nozzle readings for employee ID: $employeeId');
    
    try {
      final url = ApiConstants.getNozzleReadingsByEmployeeUrl(employeeId);
      developer.log('NozzleReadingRepository: API URL: $url');
      print('NozzleReadingRepository: API URL: $url');
      
      final headers = await _getHeaders();
      developer.log('NozzleReadingRepository: Request headers: $headers');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      developer.log('NozzleReadingRepository: Response status code: ${response.statusCode}');
      developer.log('NozzleReadingRepository: Response body: ${response.body}');
      print('NozzleReadingRepository: Response status code: ${response.statusCode}');
      print('NozzleReadingRepository: Response body length: ${response.body.length}');
      
      if (response.statusCode == ApiConstants.statusOk) {
        final List<dynamic> jsonData = json.decode(response.body);
        developer.log('NozzleReadingRepository: Successfully parsed JSON data, count: ${jsonData.length}');
        print('NozzleReadingRepository: Successfully parsed JSON data, count: ${jsonData.length}');
        
        final nozzleReadings = jsonData
            .map((data) => NozzleReading.fromJson(data))
            .toList();
        
        developer.log('NozzleReadingRepository: Returning ${nozzleReadings.length} nozzle readings');
        print('NozzleReadingRepository: Returning ${nozzleReadings.length} nozzle readings');
        
        return ApiResponse<List<NozzleReading>>(
          success: true,
          data: nozzleReadings,
        );
      } else {
        developer.log('NozzleReadingRepository: Error fetching nozzle readings: ${response.statusCode}');
        developer.log('NozzleReadingRepository: Error response: ${response.body}');
        print('NozzleReadingRepository: Error fetching nozzle readings: ${response.statusCode}');
        print('NozzleReadingRepository: Error response: ${response.body}');
        
        return ApiResponse<List<NozzleReading>>(
          success: false,
          errorMessage: 'Failed to fetch nozzle readings: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('NozzleReadingRepository: Exception when fetching nozzle readings: $e');
      print('NozzleReadingRepository: Exception when fetching nozzle readings: $e');
      
      return ApiResponse<List<NozzleReading>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Submit nozzle reading with image - Logic removed
  Future<ApiResponse<Map<String, dynamic>>> submitNozzleReading({
    required String meterReading,
    required String nozzleId,
    required String readingType,
    required File imageFile,
    String? shiftId,
    required DateTime recordedAt,
  }) async {
    developer.log('NozzleReadingRepository: Simulating nozzle reading submission - actual logic removed');
    // Simply return a success response with empty data
    return ApiResponse<Map<String, dynamic>>(
      success: true,
      data: {},
    );
  }

  // Submit nozzle reading with multipart/form-data
  Future<ApiResponse<Map<String, dynamic>>> submitNozzleReadingMultipart({
    required String nozzleId,
    required String shiftId,
    required String readingType,
    required double meterReading,
    required DateTime recordedAt,
    required String petrolPumpId,
    required File imageFile,
  }) async {
    developer.log('NozzleReadingRepository: Submitting nozzle reading using multipart/form-data');
    try {
      // Get the auth token for the request
      final token = await _getAuthToken();
      if (token == null) {
        print('DEBUG: Authentication token not found');
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          errorMessage: 'Authentication token not found',
        );
      }
      
      // Create multipart request
      final url = ApiConstants.getNozzleReadingSubmitUrl();
      print('DEBUG: Sending request to: $url');
      print('DEBUG: Request parameters:');
      print('DEBUG: nozzleId: $nozzleId');
      print('DEBUG: shiftId: $shiftId');
      print('DEBUG: readingType: $readingType');
      print('DEBUG: meterReading: $meterReading');
      print('DEBUG: recordedAt: ${recordedAt.toIso8601String()}');
      print('DEBUG: petrolPumpId: $petrolPumpId');
      print('DEBUG: imageFile: ${imageFile.path}');
      
      final request = http.MultipartRequest('POST', Uri.parse(url));
      
      // Add auth header - ensure token format is correct
      // Strip any 'Bearer ' prefix that might already be there to avoid "Bearer Bearer token"
      final bareToken = token.startsWith('Bearer ') ? token.substring(7) : token;
      request.headers['Authorization'] = 'Bearer $bareToken';
      
      // Add content type to header (some servers require this explicitly)
      // For multipart requests, don't set Content-Type as it will be set automatically with boundary
      
      // Print headers for debugging
      print('DEBUG: Request headers:');
      request.headers.forEach((key, value) {
        print('DEBUG: $key: ${key.toLowerCase() == 'authorization' ? 'Bearer [token hidden]' : value}');
      });
      
      // Add text fields to the request
      request.fields['nozzleId'] = nozzleId;
      request.fields['shiftId'] = shiftId;
      request.fields['readingType'] = readingType;
      request.fields['meterReading'] = meterReading.toString();
      request.fields['recordedAt'] = recordedAt.toIso8601String();
      request.fields['petrolPumpId'] = petrolPumpId;
      
      // Add the image file if it exists
      if (imageFile.existsSync()) {
        // Read file as bytes
        final bytes = await imageFile.readAsBytes();
        print('DEBUG: Image size: ${bytes.length} bytes');
        final filename = imageFile.path.split('/').last;
        
        // Create a multipart file with correct MIME type
        final imageUpload = http.MultipartFile.fromBytes(
          'readingImage',
          bytes,
          filename: filename,
          contentType: MediaType('image', 'jpeg'),
        );
        
        // Add file to the request
        request.files.add(imageUpload);
        print('DEBUG: Image added to request: ${imageFile.path}');
      } else {
        print('DEBUG: ERROR - Image file does not exist: ${imageFile.path}');
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          errorMessage: 'Image file not found or inaccessible',
        );
      }
      
      // Send the request
      print('DEBUG: Sending multipart request...');
      final streamedResponse = await request.send();
      
      // Get response
      final response = await http.Response.fromStream(streamedResponse);
      print('DEBUG: Response status code: ${response.statusCode}');
      // print('DEBUG: Response headers: ${response.headers}');
      print('DEBUG: Response body: ${response.body}');
      
      // Process response
      if (response.statusCode == ApiConstants.statusOk || 
          response.statusCode == ApiConstants.statusCreated) {
        final jsonData = json.decode(response.body);
        print('DEBUG: Successfully submitted reading');
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: jsonData,
        );
      } else if (response.statusCode == ApiConstants.statusForbidden) {
        print('DEBUG: ERROR - Access forbidden (403). This usually indicates an authentication or permission issue.');
        print('DEBUG: Check if token is valid and has correct permissions.');
        
        // Try to decode token to check expiration
        try {
          final decodedToken = JwtDecoder.decode(token);
          if (decodedToken != null) {
            print('DEBUG: Token contains claims: ${decodedToken.keys.toList()}');
            if (decodedToken.containsKey('exp')) {
              final expTimestamp = decodedToken['exp'] as int;
              final expDate = DateTime.fromMillisecondsSinceEpoch(expTimestamp * 1000);
              final now = DateTime.now();
              print('DEBUG: Token expires at: $expDate, Current time: $now');
              if (expDate.isBefore(now)) {
                print('DEBUG: Token is expired. Please login again.');
                return ApiResponse<Map<String, dynamic>>(
                  success: false,
                  errorMessage: 'Your session has expired. Please login again.',
                );
              }
            }
          }
        } catch (e) {
          print('DEBUG: Error examining token: $e');
        }
        
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          errorMessage: 'Access denied. Please check your permissions or login again.',
        );
      } else {
        String errorDetail;
        try {
          // Try to parse error details from response
          final errorData = json.decode(response.body);
          errorDetail = errorData['message'] ?? errorData['error'] ?? response.body;
        } catch (e) {
          errorDetail = response.body;
        }
        
        print('DEBUG: ERROR - Failed to submit reading: ${response.statusCode} - $errorDetail');
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          errorMessage: 'Failed to submit reading: ${response.statusCode} - $errorDetail',
        );
      }
    } catch (e, stackTrace) {
      print('DEBUG: EXCEPTION when submitting nozzle reading: $e');
      print('DEBUG: Stack trace: $stackTrace');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get employee nozzle assignments
  Future<ApiResponse<List<EmployeeNozzleAssignment>>> getEmployeeNozzleAssignments(String employeeId) async {
    developer.log('NozzleReadingRepository: Getting employee nozzle assignments for employee ID: $employeeId');
    try {
      final url = '$baseUrl/api/EmployeeNozzleAssignments/employee/$employeeId';
      developer.log('NozzleReadingRepository: API URL: $url');
      print('NozzleReadingRepository: API URL: $url');
      
      final headers = await _getHeaders();
      developer.log('NozzleReadingRepository: Request headers: $headers');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      developer.log('NozzleReadingRepository: Response status code: ${response.statusCode}');
      developer.log('NozzleReadingRepository: Response body: ${response.body}');
      print('NozzleReadingRepository: Response status code: ${response.statusCode}');
      print('NozzleReadingRepository: Response body length: ${response.body.length}');
      
      if (response.statusCode == ApiConstants.statusOk) {
        final List<dynamic> jsonData = json.decode(response.body);
        developer.log('NozzleReadingRepository: Successfully parsed JSON data, count: ${jsonData.length}');
        print('NozzleReadingRepository: Successfully parsed JSON data, count: ${jsonData.length}');
        
        final assignments = jsonData
            .map((data) => EmployeeNozzleAssignment.fromJson(data))
            .toList();
        
        developer.log('NozzleReadingRepository: Returning ${assignments.length} employee nozzle assignments');
        print('NozzleReadingRepository: Returning ${assignments.length} employee nozzle assignments');
        
        return ApiResponse<List<EmployeeNozzleAssignment>>(
          success: true,
          data: assignments,
        );
      } else {
        developer.log('NozzleReadingRepository: Error fetching employee nozzle assignments: ${response.statusCode}');
        developer.log('NozzleReadingRepository: Error response: ${response.body}');
        print('NozzleReadingRepository: Error fetching employee nozzle assignments: ${response.statusCode}');
        print('NozzleReadingRepository: Error response: ${response.body}');
        
        return ApiResponse<List<EmployeeNozzleAssignment>>(
          success: false,
          errorMessage: 'Failed to fetch employee nozzle assignments: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('NozzleReadingRepository: Exception when fetching employee nozzle assignments: $e');
      print('NozzleReadingRepository: Exception when fetching employee nozzle assignments: $e');
      
      return ApiResponse<List<EmployeeNozzleAssignment>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get nozzle readings by nozzle ID
  Future<ApiResponse<List<NozzleReading>>> getNozzleReadingsByNozzleId(String nozzleId) async {
    developer.log('NozzleReadingRepository: Getting nozzle readings for nozzle ID: $nozzleId');
    print('NozzleReadingRepository: Getting nozzle readings for nozzle ID: $nozzleId');
    
    try {
      final url = ApiConstants.getNozzleReadingsByNozzleIdUrl(nozzleId);
      developer.log('NozzleReadingRepository: API URL: $url');
      print('NozzleReadingRepository: API URL: $url');
      
      final headers = await _getHeaders();
      developer.log('NozzleReadingRepository: Request headers: $headers');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      developer.log('NozzleReadingRepository: Response status code: ${response.statusCode}');
      developer.log('NozzleReadingRepository: Response body: ${response.body}');
      print('NozzleReadingRepository: Response status code: ${response.statusCode}');
      print('NozzleReadingRepository: Response body length: ${response.body.length}');
      
      if (response.statusCode == ApiConstants.statusOk) {
        final List<dynamic> jsonData = json.decode(response.body);
        developer.log('NozzleReadingRepository: Successfully parsed JSON data, count: ${jsonData.length}');
        print('NozzleReadingRepository: Successfully parsed JSON data, count: ${jsonData.length}');
        
        final nozzleReadings = jsonData
            .map((data) => NozzleReading.fromJson(data))
            .toList();
        
        developer.log('NozzleReadingRepository: Returning ${nozzleReadings.length} nozzle readings');
        print('NozzleReadingRepository: Returning ${nozzleReadings.length} nozzle readings');
        
        return ApiResponse<List<NozzleReading>>(
          success: true,
          data: nozzleReadings,
        );
      } else {
        developer.log('NozzleReadingRepository: Error fetching nozzle readings: ${response.statusCode}');
        developer.log('NozzleReadingRepository: Error response: ${response.body}');
        print('NozzleReadingRepository: Error fetching nozzle readings: ${response.statusCode}');
        print('NozzleReadingRepository: Error response: ${response.body}');
        
        return ApiResponse<List<NozzleReading>>(
          success: false,
          errorMessage: 'Failed to fetch nozzle readings: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('NozzleReadingRepository: Exception when fetching nozzle readings: $e');
      print('NozzleReadingRepository: Exception when fetching nozzle readings: $e');
      
      return ApiResponse<List<NozzleReading>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get nozzle readings by shift ID
  Future<ApiResponse<List<NozzleReading>>> getNozzleReadingsByShiftId(String shiftId) async {
    developer.log('NozzleReadingRepository: Getting nozzle readings for shift ID: $shiftId');
    print('NozzleReadingRepository: Getting nozzle readings for shift ID: $shiftId');
    
    try {
      final url = '${ApiConstants.baseUrl}/api/NozzleReadings/ByShift/$shiftId';
      developer.log('NozzleReadingRepository: API URL: $url');
      print('NozzleReadingRepository: API URL: $url');
      
      final headers = await _getHeaders();
      developer.log('NozzleReadingRepository: Request headers: $headers');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      developer.log('NozzleReadingRepository: Response status code: ${response.statusCode}');
      developer.log('NozzleReadingRepository: Response body: ${response.body}');
      print('NozzleReadingRepository: Response status code: ${response.statusCode}');
      print('NozzleReadingRepository: Response body length: ${response.body.length}');
      
      if (response.statusCode == ApiConstants.statusOk) {
        final List<dynamic> jsonData = json.decode(response.body);
        developer.log('NozzleReadingRepository: Successfully parsed JSON data, count: ${jsonData.length}');
        print('NozzleReadingRepository: Successfully parsed JSON data, count: ${jsonData.length}');
        
        final nozzleReadings = jsonData
            .map((data) => NozzleReading.fromJson(data))
            .toList();
        
        developer.log('NozzleReadingRepository: Returning ${nozzleReadings.length} nozzle readings by shift');
        print('NozzleReadingRepository: Returning ${nozzleReadings.length} nozzle readings by shift');
        
        return ApiResponse<List<NozzleReading>>(
          success: true,
          data: nozzleReadings,
        );
      } else {
        developer.log('NozzleReadingRepository: Error fetching nozzle readings by shift: ${response.statusCode}');
        developer.log('NozzleReadingRepository: Error response: ${response.body}');
        print('NozzleReadingRepository: Error fetching nozzle readings by shift: ${response.statusCode}');
        print('NozzleReadingRepository: Error response: ${response.body}');
        
        return ApiResponse<List<NozzleReading>>(
          success: false,
          errorMessage: 'Failed to fetch nozzle readings by shift: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('NozzleReadingRepository: Exception when fetching nozzle readings by shift: $e');
      print('NozzleReadingRepository: Exception when fetching nozzle readings by shift: $e');
      
      return ApiResponse<List<NozzleReading>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  Future<ApiResponse<bool>> submitSimpleNozzleReading({
    required String nozzleId,
    required String employeeId,
    required double meterReading,
    String? comments,
  }) async {
    try {
      final url = '${ApiConstants.baseUrl}/nozzle-readings';
      final token = await _getAuthToken();
      
      if (token == null) {
        return ApiResponse(
          success: false,
          errorMessage: 'Authentication required',
        );
      }
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'nozzleId': nozzleId,
          'employeeId': employeeId,
          'meterReading': meterReading,
          if (comments != null && comments.isNotEmpty) 'comments': comments,
        }),
      );
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: true,
        );
      } else {
        return ApiResponse(
          success: false,
          errorMessage: responseData['message'] ?? 'Failed to submit reading',
        );
      }
    } catch (e) {
      print('Error submitting reading: $e');
      return ApiResponse(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get all nozzle readings
  Future<ApiResponse<List<NozzleReading>>> getNozzleReadings() async {
    try {
      final response = await _apiHelper.get('${ApiConstants.baseUrl}/api/NozzleReadings');
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final readings = jsonData.map((json) => NozzleReading.fromJson(json)).toList();
        
        return ApiResponse<List<NozzleReading>>(
          success: true,
          data: readings,
        );
      } else {
        developer.log('Error fetching nozzle readings: ${response.statusCode} - ${response.body}');
        return ApiResponse<List<NozzleReading>>(
          success: false,
          errorMessage: 'Failed to load nozzle readings. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('Exception in getNozzleReadings: $e');
      return ApiResponse<List<NozzleReading>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }
  
  // Get nozzle readings by specific nozzle and verify start/end readings
  Future<ApiResponse<Map<String, dynamic>>> verifyNozzleReadings(String nozzleId) async {
    developer.log('NozzleReadingRepository: Verifying readings for nozzle ID: $nozzleId');
    
    try {
      final url = ApiConstants.baseUrl + '/api/NozzleReadings/ByNozzle/' + nozzleId;
      developer.log('NozzleReadingRepository: API URL: $url');
      
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      developer.log('NozzleReadingRepository: Response status code: ${response.statusCode}');
      
      if (response.statusCode == ApiConstants.statusOk) {
        final List<dynamic> jsonData = json.decode(response.body);
        developer.log('NozzleReadingRepository: Successfully parsed JSON data, count: ${jsonData.length}');
        
        final nozzleReadings = jsonData
            .map((data) => NozzleReading.fromJson(data))
            .toList();
        
        // Get today's readings
        final today = DateTime.now();
        final todayString = DateTime(today.year, today.month, today.day).toIso8601String().split('T')[0];
        
        final todayReadings = nozzleReadings.where((reading) {
          final readingDate = reading.timestamp.toIso8601String().split('T')[0];
          return readingDate == todayString;
        }).toList();
        
        // Check for start and end readings
        bool hasStartReading = false;
        bool hasEndReading = false;
        NozzleReading? startReading;
        NozzleReading? endReading;
        
        for (var reading in todayReadings) {
          if (reading.readingType?.toLowerCase() == 'start' || 
              (reading.startReading > 0 && reading.endReading == null)) {
            hasStartReading = true;
            startReading = reading;
          }
          
          if (reading.readingType?.toLowerCase() == 'end' || 
              (reading.startReading > 0 && reading.endReading != null)) {
            hasEndReading = true;
            endReading = reading;
          }
        }
        
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: {
            'hasStartReading': hasStartReading,
            'hasEndReading': hasEndReading,
            'startReading': startReading,
            'endReading': endReading,
            'allReadings': todayReadings,
          },
        );
      } else {
        developer.log('NozzleReadingRepository: Error verifying nozzle readings: ${response.statusCode}');
        
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          errorMessage: 'Failed to verify nozzle readings: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('NozzleReadingRepository: Exception when verifying nozzle readings: $e');
      
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get the latest reading for a specific nozzle and reading type
  Future<ApiResponse<NozzleReading>> getLatestReading(String nozzleId, String readingType) async {
    developer.log('NozzleReadingRepository: Getting latest $readingType reading for nozzle ID: $nozzleId');
    print('DEBUG: Getting latest $readingType reading for nozzle ID: $nozzleId');
    
    try {
      final url = '$baseUrl/api/NozzleReadings/Latest/$nozzleId/$readingType';
      developer.log('NozzleReadingRepository: API URL: $url');
      print('DEBUG: API URL: $url');
      
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      developer.log('NozzleReadingRepository: Response status code: ${response.statusCode}');
      developer.log('NozzleReadingRepository: Response body: ${response.body}');
      print('DEBUG: Response status code: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');
      
      if (response.statusCode == ApiConstants.statusOk) {
        final jsonData = json.decode(response.body);
        developer.log('NozzleReadingRepository: Successfully parsed JSON data');
        
        // Check if response is null or empty
        if (jsonData == null || (jsonData is Map && jsonData.isEmpty)) {
          return ApiResponse<NozzleReading>(
            success: false,
            errorMessage: 'No reading found',
          );
        }
        
        final nozzleReading = NozzleReading.fromJson(jsonData);
        developer.log('NozzleReadingRepository: Returning latest reading with value: ${nozzleReading.startReading}');
        print('DEBUG: Returning latest reading with value: ${nozzleReading.startReading}');
        
        return ApiResponse<NozzleReading>(
          success: true,
          data: nozzleReading,
        );
      } else if (response.statusCode == ApiConstants.statusNotFound) {
        // 404 means no reading found, which is a valid response
        developer.log('NozzleReadingRepository: No reading found (404)');
        print('DEBUG: No reading found (404)');
        
        return ApiResponse<NozzleReading>(
          success: false,
          errorMessage: 'No reading found',
        );
      } else {
        developer.log('NozzleReadingRepository: Error fetching latest reading: ${response.statusCode}');
        developer.log('NozzleReadingRepository: Error response: ${response.body}');
        print('DEBUG: Error fetching latest reading: ${response.statusCode}');
        print('DEBUG: Error response: ${response.body}');
        
        return ApiResponse<NozzleReading>(
          success: false,
          errorMessage: 'Failed to fetch latest reading: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('NozzleReadingRepository: Exception when fetching latest reading: $e');
      print('DEBUG: Exception when fetching latest reading: $e');
      
      return ApiResponse<NozzleReading>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Add a new method to check if a reading of specific type exists for the current day
  Future<ApiResponse<bool>> checkReadingExistsForToday(String nozzleId, String readingType) async {
    developer.log('NozzleReadingRepository: Checking if $readingType reading exists for nozzle $nozzleId today');
    print('DEBUG: Checking if $readingType reading exists for nozzle $nozzleId today');
    
    try {
      final url = '$baseUrl/api/NozzleReadings/ByNozzle/$nozzleId';
      developer.log('NozzleReadingRepository: API URL: $url');
      
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == ApiConstants.statusOk) {
        final List<dynamic> jsonData = json.decode(response.body);
        developer.log('NozzleReadingRepository: Successfully parsed JSON data, count: ${jsonData.length}');
        
        // Convert to nozzle readings
        final nozzleReadings = jsonData
            .map((data) => NozzleReading.fromJson(data))
            .toList();
        
        // Get today's date in YYYY-MM-DD format
        final today = DateTime.now();
        final todayString = DateTime(today.year, today.month, today.day).toIso8601String().split('T')[0];
        
        // Filter readings for today and the specified reading type
        final existingReadings = nozzleReadings.where((reading) {
          // Convert reading timestamp to YYYY-MM-DD format for comparison
          final readingDate = reading.timestamp.toIso8601String().split('T')[0];
          // Check if date matches and reading type matches
          return readingDate == todayString && 
              (reading.readingType?.toLowerCase() == readingType.toLowerCase());
        }).toList();
        
        final exists = existingReadings.isNotEmpty;
        developer.log('NozzleReadingRepository: $readingType reading for today exists: $exists');
        print('DEBUG: $readingType reading for today exists: $exists');
        
        return ApiResponse<bool>(
          success: true,
          data: exists,
        );
      } else {
        developer.log('NozzleReadingRepository: Error checking readings: ${response.statusCode}');
        print('DEBUG: Error checking readings: ${response.statusCode}');
        
        return ApiResponse<bool>(
          success: false,
          errorMessage: 'Failed to check readings: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('NozzleReadingRepository: Exception when checking readings: $e');
      print('DEBUG: Exception when checking readings: $e');
      
      return ApiResponse<bool>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Submit start nozzle reading - direct implementation that exactly mimics Postman
  Future<ApiResponse<Map<String, dynamic>>> submitStartNozzleReading({
    required String nozzleId,
    required String shiftId,
    required double meterReading,
    required DateTime recordedAt,
    required String petrolPumpId,
    required String fuelTankId,
    required File imageFile,
  }) async {
    print('DEBUG: Submitting start reading directly - exact Postman implementation');
    
    final token = await _getAuthToken();
    if (token == null) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        errorMessage: 'Authentication token not found',
      );
    }
    
    // Use exactly the endpoint that works in Postman
    final url = '$baseUrl/api/NozzleReadings/start';
    print('DEBUG: Sending request to: $url');
    
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      
      // Add authorization header exactly as Postman would
      final bareToken = token.startsWith('Bearer ') ? token.substring(7) : token;
      request.headers['Authorization'] = 'Bearer $bareToken';
      
      // Add fields exactly as they would be in Postman, with exact same casing
      request.fields['NozzleId'] = nozzleId;
      request.fields['ShiftId'] = shiftId;
      request.fields['ReadingType'] = 'Start';
      request.fields['MeterReading'] = meterReading.toString();
      request.fields['RecordedAt'] = recordedAt.toIso8601String();
      request.fields['FuelTankId'] = fuelTankId;
      request.fields['PetrolPumpId'] = petrolPumpId;
      
      // Debug information
      print('DEBUG: Request headers:');
      request.headers.forEach((key, value) {
        if (key.toLowerCase() == 'authorization') {
          print('DEBUG: $key: Bearer [token hidden]');
        } else {
          print('DEBUG: $key: $value');
        }
      });
      
      print('DEBUG: Request fields:');
      request.fields.forEach((key, value) {
        print('DEBUG: $key: $value');
      });
      
      // Add image exactly as Postman would
      if (imageFile.existsSync()) {
        final bytes = await imageFile.readAsBytes();
        final filename = imageFile.path.split('/').last;
        final imageUpload = http.MultipartFile.fromBytes(
          'ReadingImage',
          bytes,
          filename: filename,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(imageUpload);
        print('DEBUG: Added image: ${imageFile.path}');
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          errorMessage: 'Image file not found or inaccessible',
        );
      }
      
      // Send the request directly
      print('DEBUG: Sending request...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        Map<String, dynamic> jsonData = {};
        try {
          jsonData = json.decode(response.body);
          print('DEBUG: Successfully parsed JSON response');
        } catch (e) {
          print('DEBUG: Error parsing JSON response: $e');
        }
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          data: jsonData,
        );
      } else {
        String errorDetail;
        try {
          final errorData = json.decode(response.body);
          errorDetail = errorData['message'] ?? errorData['error'] ?? response.body;
        } catch (e) {
          errorDetail = response.body;
        }
        
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          errorMessage: 'Server error: ${response.statusCode} - $errorDetail',
        );
      }
    } catch (e, stackTrace) {
      print('DEBUG: Exception during request: $e');
      print('DEBUG: Stack trace: $stackTrace');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        errorMessage: 'Network error: $e',
      );
    }
  }

  // Submit end nozzle reading with multipart/form-data
  Future<ApiResponse<Map<String, dynamic>>> submitEndNozzleReading({
    required String nozzleId,
    required String shiftId,
    required double meterReading,
    required DateTime recordedAt,
    required String petrolPumpId,
    required String fuelTankId,
    required File imageFile,
  }) async {
    // First check if an end reading already exists for today
    final checkResponse = await checkReadingExistsForToday(nozzleId, 'End');
    
    // If check failed, return the error
    if (!checkResponse.success) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        errorMessage: checkResponse.errorMessage ?? 'Failed to check existing readings',
      );
    }
    
    // If an end reading already exists, return an error
    if (checkResponse.data == true) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        errorMessage: 'An end reading has already been submitted for this nozzle today',
      );
    }
    
    // If no reading exists, proceed with submission
    return _submitNozzleReadingWithEndpoint(
      endpoint: '/api/NozzleReadings/end',
      nozzleId: nozzleId,
      shiftId: shiftId,
      meterReading: meterReading,
      recordedAt: recordedAt,
      petrolPumpId: petrolPumpId,
      fuelTankId: fuelTankId,
      imageFile: imageFile,
      readingType: 'End',
      bypassValidation: false, // For end readings, we still want validation
    );
  }

  // Helper for both start/end
  Future<ApiResponse<Map<String, dynamic>>> _submitNozzleReadingWithEndpoint({
    required String endpoint,
    required String nozzleId,
    required String shiftId,
    required double meterReading,
    required DateTime recordedAt,
    required String petrolPumpId,
    required String fuelTankId,
    required File imageFile,
    required String readingType,
    bool bypassValidation = false,
  }) async {
    final token = await _getAuthToken();
    if (token == null) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        errorMessage: 'Authentication token not found',
      );
    }
    final url = baseUrl + endpoint;
    final request = http.MultipartRequest('POST', Uri.parse(url));
    final bareToken = token.startsWith('Bearer ') ? token.substring(7) : token;
    request.headers['Authorization'] = 'Bearer $bareToken';
    request.fields['NozzleId'] = nozzleId;
    request.fields['ShiftId'] = shiftId;
    request.fields['ReadingType'] = readingType;
    request.fields['MeterReading'] = meterReading.toString();
    request.fields['RecordedAt'] = recordedAt.toIso8601String();
    request.fields['FuelTankId'] = fuelTankId;
    request.fields['PetrolPumpId'] = petrolPumpId;
    
    // Add bypass validation parameter
    if (bypassValidation) {
      request.fields['BypassValidation'] = 'true';
    }
    
    if (imageFile.existsSync()) {
      final bytes = await imageFile.readAsBytes();
      final filename = imageFile.path.split('/').last;
      final imageUpload = http.MultipartFile.fromBytes(
        'ReadingImage',
        bytes,
        filename: filename,
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(imageUpload);
    } else {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        errorMessage: 'Image file not found or inaccessible',
      );
    }
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonData = json.decode(response.body);
      return ApiResponse<Map<String, dynamic>>(
        success: true,
        data: jsonData,
      );
    } else {
      String errorDetail;
      try {
        final errorData = json.decode(response.body);
        errorDetail = errorData['message'] ?? errorData['error'] ?? response.body;
      } catch (e) {
        errorDetail = response.body;
      }
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        errorMessage: 'Failed to submit reading: ${response.statusCode} - $errorDetail',
      );
    }
  }

  // Get all nozzles
  Future<ApiResponse<List<dynamic>>> getAllNozzles() async {
    try {
      final url = '${ApiConstants.baseUrl}/api/Nozzle';
      developer.log('NozzleReadingRepository: Getting all nozzles');
      
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == ApiConstants.statusOk) {
        final List<dynamic> jsonData = json.decode(response.body);
        developer.log('NozzleReadingRepository: Loaded ${jsonData.length} nozzles');
        
        return ApiResponse<List<dynamic>>(
          success: true,
          data: jsonData,
        );
      } else {
        developer.log('NozzleReadingRepository: Error fetching nozzles: ${response.statusCode}');
        return ApiResponse<List<dynamic>>(
          success: false,
          errorMessage: 'Failed to fetch nozzles: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('NozzleReadingRepository: Exception when fetching all nozzles: $e');
      return ApiResponse<List<dynamic>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get all employees
  Future<ApiResponse<dynamic>> getAllEmployees() async {
    try {
      final url = '${ApiConstants.baseUrl}/api/Employee';
      developer.log('NozzleReadingRepository: Getting all employees');
      print('NozzleReadingRepository: Getting all employees from URL: $url');
      
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('NozzleReadingRepository: Employee response status: ${response.statusCode}');
      print('NozzleReadingRepository: Employee response body length: ${response.body.length}');
      
      if (response.statusCode == ApiConstants.statusOk) {
        try {
          // First try to parse as a List
          final dynamic jsonData = json.decode(response.body);
          print('NozzleReadingRepository: Employee response parsed type: ${jsonData.runtimeType}');
          
          if (jsonData is List) {
            print('NozzleReadingRepository: Loaded ${jsonData.length} employees as List');
            return ApiResponse<dynamic>(
              success: true,
              data: jsonData,
            );
          } else if (jsonData is Map<String, dynamic>) {
            print('NozzleReadingRepository: Loaded employees as Map with keys: ${jsonData.keys.join(", ")}');
            // Return the Map directly - we'll handle extraction in the UI
            return ApiResponse<dynamic>(
              success: true,
              data: jsonData,
            );
          } else {
            print('NozzleReadingRepository: Unexpected employee data type: ${jsonData.runtimeType}');
            return ApiResponse<dynamic>(
              success: false,
              errorMessage: 'Unexpected response format',
            );
          }
        } catch (e) {
          print('NozzleReadingRepository: Error parsing employee response: $e');
          developer.log('NozzleReadingRepository: Error parsing employee response: $e');
          return ApiResponse<dynamic>(
            success: false,
            errorMessage: 'Failed to parse response: $e',
          );
        }
      } else {
        developer.log('NozzleReadingRepository: Error fetching employees: ${response.statusCode}');
        print('NozzleReadingRepository: Error fetching employees: ${response.statusCode}');
        return ApiResponse<dynamic>(
          success: false,
          errorMessage: 'Failed to fetch employees: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('NozzleReadingRepository: Exception when fetching all employees: $e');
      print('NozzleReadingRepository: Exception when fetching all employees: $e');
      return ApiResponse<dynamic>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // Get nozzle readings by nozzle ID
  Future<ApiResponse<List<NozzleReading>>> getNozzleReadingsByNozzle(String nozzleId) async {
    try {
      final response = await _apiHelper.get('${ApiConstants.baseUrl}/api/NozzleReadings/nozzle/$nozzleId');
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final readings = jsonData.map((json) => NozzleReading.fromJson(json)).toList();
        
        return ApiResponse<List<NozzleReading>>(
          success: true,
          data: readings,
        );
      } else {
        developer.log('Error fetching nozzle readings by nozzle: ${response.statusCode} - ${response.body}');
        return ApiResponse<List<NozzleReading>>(
          success: false,
          errorMessage: 'Failed to load nozzle readings. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('Exception in getNozzleReadingsByNozzle: $e');
      return ApiResponse<List<NozzleReading>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  // For demonstration purposes, this method returns mock data
  Future<ApiResponse<List<NozzleReading>>> getMockNozzleReadings() async {
    try {
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 800));
      
      return ApiResponse<List<NozzleReading>>(
        success: true,
        data: [
          NozzleReading(
            nozzleReadingId: "8b324890-3ee6-4f2a-816a-880925717d74",
            nozzleId: "5bf6555c-af93-450e-a649-b473297340c0",
            employeeId: "40c60ab3-f5e3-47d8-8ae4-07d58b0b3ad9",
            shiftId: "07af608f-485f-437e-a6bb-37a4eff7081f",
            readingType: "End",
            meterReading: 2610.00,
            readingImage: "/images//2025/5/a6db4aec-a35a-44d7-9716-bdff8bc96ab4_scaled_3b3d05f1-16ac-495a-87ff-6f9a451380043266111453305340816.jpg",
            recordedAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            employeeName: "Paul Smith",
            nozzleNumber: "1",
            fuelType: "Diesel",
            fuelTypeId: "e7e7b1b2-e7ff-4d59-a22d-64bff68ccbf6",
            dispenserNumber: "1",
            fuelTankId: null,
            petrolPumpId: null,
          ),
          NozzleReading(
            nozzleReadingId: "96979008-1c3b-40a9-9758-158673a6d492",
            nozzleId: "5bf6555c-af93-450e-a649-b473297340c0",
            employeeId: "40c60ab3-f5e3-47d8-8ae4-07d58b0b3ad9",
            shiftId: "07af608f-485f-437e-a6bb-37a4eff7081f",
            readingType: "Start",
            meterReading: 2510.00,
            readingImage: "/images//2025/5/96341438-5858-4fa1-8d7b-490a64c5d966_scaled_c386a0c8-aa24-4f1f-a1ee-ca058ff89f5f7784420209478091301.jpg",
            recordedAt: DateTime.now().subtract(const Duration(hours: 8)),
            createdAt: DateTime.now().subtract(const Duration(hours: 8)),
            updatedAt: DateTime.now().subtract(const Duration(hours: 8)),
            employeeName: "Paul Smith",
            nozzleNumber: "1",
            fuelType: "Diesel",
            fuelTypeId: "e7e7b1b2-e7ff-4d59-a22d-64bff68ccbf6",
            dispenserNumber: "1",
            fuelTankId: null,
            petrolPumpId: null,
          ),
          NozzleReading(
            nozzleReadingId: "a1b2c3d4-e5f6-4f2a-816a-880925717d74",
            nozzleId: "5bf6555c-af93-450e-a649-b473297340c0",
            employeeId: "40c60ab3-f5e3-47d8-8ae4-07d58b0b3ad9",
            shiftId: "07af608f-485f-437e-a6bb-37a4eff7081f",
            readingType: "End",
            meterReading: 1850.75,
            readingImage: "/images//2025/5/sample_image.jpg",
            recordedAt: DateTime.now().subtract(const Duration(days: 1)),
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            updatedAt: DateTime.now().subtract(const Duration(days: 1)),
            employeeName: "Paul Smith",
            nozzleNumber: "2",
            fuelType: "Petrol",
            fuelTypeId: "f8e7b1b2-e7ff-4d59-a22d-64bff68ccbf6",
            dispenserNumber: "2",
            fuelTankId: null,
            petrolPumpId: null,
          ),
          NozzleReading(
            nozzleReadingId: "b2c3d4e5-f6g7-40a9-9758-158673a6d492",
            nozzleId: "5bf6555c-af93-450e-a649-b473297340c0",
            employeeId: "40c60ab3-f5e3-47d8-8ae4-07d58b0b3ad9",
            shiftId: "07af608f-485f-437e-a6bb-37a4eff7081f",
            readingType: "Start",
            meterReading: 1800.50,
            readingImage: "/images//2025/5/another_sample.jpg",
            recordedAt: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
            createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
            updatedAt: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
            employeeName: "Paul Smith",
            nozzleNumber: "2",
            fuelType: "Petrol",
            fuelTypeId: "f8e7b1b2-e7ff-4d59-a22d-64bff68ccbf6",
            dispenserNumber: "2",
            fuelTankId: null,
            petrolPumpId: null,
          ),
        ],
      );
    } catch (e) {
      developer.log('Exception in getMockNozzleReadings: $e');
      return ApiResponse<List<NozzleReading>>(
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