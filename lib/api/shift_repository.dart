import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/employee_model.dart';
import 'api_constants.dart';
import 'api_service.dart';
import '../models/shift_model.dart';
import '../utils/jwt_decoder.dart';

class ShiftRepository {
  final ApiService _apiService = ApiService();

  // Add a new shift
  Future<ApiResponse<Map<String, dynamic>>> addShift(Shift shift) async {
    developer.log('Adding shift with details: ${shift.toJson()}');
    print('SHIFT_REPO: Starting shift creation with data: ${shift.toJson()}');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for adding shift');
        print('SHIFT_REPO: Authentication failed - no token found');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }

      // Use the correct URL as specified in the requirements
      final url = '${ApiConstants.baseUrl}/api/Shift';
      developer.log('Using correct Shift URL: $url');
      print('SHIFT_REPO: Using correct URL: $url');
      
      // Log the full request details
      // print('SHIFT_REPO: Request Token Present: ${token != null}');
      print('SHIFT_REPO: Request Body: ${shift.toJson()}');
      
      // Make the API call with the correct URL
      final response = await _apiService.post<Map<String, dynamic>>(
        url,
        body: shift.toJson(),
        token: token,
        fromJson: (json) {
          // Ensure proper typing for the response
          if (json is Map) {
            return Map<String, dynamic>.from(json);
          }
          return <String, dynamic>{};
        },
      );
      
      if (response.success) {
        developer.log('Shift added successfully');
        print('SHIFT_REPO: Shift added successfully! Response data: ${response.data}');
        
        // Log the shift ID received from the server
        final responseData = response.data;
        String? shiftId;
        if (responseData != null) {
          if (responseData.containsKey('data') && responseData['data'] is Map<String, dynamic>) {
            shiftId = responseData['data']['shiftId'];
          } else if (responseData.containsKey('shiftId')) {
            shiftId = responseData['shiftId'];
          }
          
          if (shiftId != null) {
            print('SHIFT_REPO: Received shift ID from server: $shiftId');
          } else {
            print('SHIFT_REPO: WARNING: No shift ID found in the response');
          }
        }
      } else {
        developer.log('Failed to add shift: ${response.errorMessage}');
        print('SHIFT_REPO: Failed to add shift: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in addShift: $e');
      print('SHIFT_REPO: Exception in addShift: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Get all shifts for a petrol pump
  Future<ApiResponse<List<Shift>>> getAllShifts() async {
    developer.log('Getting all shifts');
    print('SHIFT_REPO: Fetching all shifts');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting shifts');
        print('SHIFT_REPO: Authentication failed - no token found');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Extract petrol pump ID from token
      final petrolPumpId = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
      
      if (petrolPumpId == null) {
        developer.log('Failed to extract petrol pump ID from token');
        print('SHIFT_REPO: Failed to extract petrol pump ID from token');
        return ApiResponse(
          success: false,
          errorMessage: 'Could not determine your petrol pump. Please login again.',
        );
      }
      
      developer.log('Getting shifts for petrol pump ID: $petrolPumpId');
      print('SHIFT_REPO: Getting shifts for petrol pump ID: $petrolPumpId');
      
      // Make the API call
      final url = '${ApiConstants.baseUrl}/api/Shift/$petrolPumpId/shifts';
      developer.log('Shifts URL: $url');
      print('SHIFT_REPO: Using URL for fetching shifts: $url');
      
      final response = await _apiService.get<List<Shift>>(
        url,
        token: token,
        fromJson: (json) {
          print('SHIFT_REPO: Parsing response data: $json');
          List<Shift> shifts = [];
          
          if (json is List) {
            print('SHIFT_REPO: Response is a direct list with ${json.length} items');
            shifts = json.map((item) {
              // Ensure each item is properly cast to Map<String, dynamic>
              final Map<String, dynamic> typedItem = Map<String, dynamic>.from(item as Map);
              return Shift.fromJson(typedItem);
            }).toList();
          } else if (json is Map) {
            // Cast to Map<String, dynamic> for type safety
            final Map<String, dynamic> typedJson = Map<String, dynamic>.from(json);
            
            // Handle response format where shifts are in a data array
            if (typedJson.containsKey('data') && typedJson['data'] is List) {
              final List<dynamic> dataList = typedJson['data'] as List;
              print('SHIFT_REPO: Found ${dataList.length} shifts in response data array');
              shifts = dataList.map((item) {
                // Ensure each item is properly cast to Map<String, dynamic>
                final Map<String, dynamic> typedItem = Map<String, dynamic>.from(item as Map);
                return Shift.fromJson(typedItem);
              }).toList();
            } 
            // Handle case where the entire response is a single shift object
            else if (typedJson.containsKey('shiftId') || typedJson.containsKey('id')) {
              print('SHIFT_REPO: Response contains a single shift object');
              shifts = [Shift.fromJson(typedJson)];
            }
          }
          
          // Debug log all shift IDs to verify they're captured correctly
          for (var i = 0; i < shifts.length; i++) {
            print('SHIFT_REPO: Shift $i ID: ${shifts[i].id}');
          }
          
          return shifts;
        },
      );
      
      if (response.success) {
        developer.log('Shifts retrieved successfully. Count: ${response.data?.length ?? 0}');
        print('SHIFT_REPO: Successfully retrieved ${response.data?.length ?? 0} shifts');
        
        if (response.data != null && response.data!.isNotEmpty) {
          // Verify if any shifts are missing IDs
          int missingIdCount = response.data!.where((shift) => shift.id == null).length;
          if (missingIdCount > 0) {
            print('SHIFT_REPO: WARNING: $missingIdCount shifts are missing IDs');
          }
        }
      } else {
        developer.log('Failed to retrieve shifts: ${response.errorMessage}');
        print('SHIFT_REPO: Failed to retrieve shifts: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in getAllShifts: $e');
      print('SHIFT_REPO: Exception in getAllShifts: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Update an existing shift
  Future<ApiResponse<Map<String, dynamic>>> updateShift(String shiftId, Shift shift) async {
    developer.log('Updating shift with ID: $shiftId and details: ${shift.toJson()}');
    print('SHIFT_REPO: Starting shift update with ID: $shiftId and data: ${shift.toJson()}');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for updating shift');
        print('SHIFT_REPO: Authentication failed - no token found');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Validate shift ID
      if (shiftId.isEmpty) {
        developer.log('Cannot update shift: Empty shift ID');
        print('SHIFT_REPO: Cannot update shift: Empty shift ID');
        return ApiResponse(
          success: false,
          errorMessage: 'Cannot update shift: Missing shift ID',
        );
      }

      // Use the update shift URL
      final url = ApiConstants.getUpdateShiftUrl(shiftId);
      developer.log('Using shift update URL: $url');
      print('SHIFT_REPO: Using URL for update: $url');
      
      // Create the request body that the API expects
      // Make sure to use shiftId as the key as expected by the backend
      final requestBody = {
        'shiftId': shiftId,
        'startTime': shift.startTime,
        'endTime': shift.endTime,
        'shiftDuration': shift.shiftDuration,
        'shiftNumber': shift.shiftNumber,
      };
      
      print('SHIFT_REPO: Update request body: $requestBody');
      
      // Make the API call
      final response = await _apiService.put<Map<String, dynamic>>(
        url,
        body: requestBody,
        token: token,
        fromJson: (json) {
          print('SHIFT_REPO: Update response: $json');
          // Ensure proper typing for the response
          if (json is Map) {
            return Map<String, dynamic>.from(json);
          }
          return <String, dynamic>{};
        },
      );
      
      if (response.success) {
        developer.log('Shift updated successfully');
        print('SHIFT_REPO: Shift updated successfully! Response data: ${response.data}');
      } else {
        developer.log('Failed to update shift: ${response.errorMessage}');
        print('SHIFT_REPO: Failed to update shift: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in updateShift: $e');
      print('SHIFT_REPO: Exception in updateShift: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Delete a shift
  Future<ApiResponse<bool>> deleteShift(String shiftId) async {
    developer.log('Deleting shift with ID: $shiftId');
    print('SHIFT_REPO: Starting shift deletion with ID: $shiftId');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for deleting shift');
        print('SHIFT_REPO: Authentication failed - no token found');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Validate shift ID
      if (shiftId.isEmpty) {
        developer.log('Cannot delete shift: Empty shift ID');
        print('SHIFT_REPO: Cannot delete shift: Empty shift ID');
        return ApiResponse(
          success: false,
          errorMessage: 'Cannot delete shift: Missing shift ID',
        );
      }
      
      // Check if it's a mock shift
      if (shiftId.contains('mock')) {
        developer.log('Cannot delete mock shift with ID: $shiftId');
        print('SHIFT_REPO: Cannot delete mock shift with ID: $shiftId');
        return ApiResponse(
          success: false,
          errorMessage: 'This is a demo shift and cannot be deleted.',
        );
      }

      // First check if shift has assigned employees
      print('SHIFT_REPO: Checking if shift has assigned employees before deletion...');
      try {
        final employeesResponse = await getEmployeeDetailsForShift(shiftId);
        if (employeesResponse.success && employeesResponse.data != null && employeesResponse.data!.isNotEmpty) {
          print('SHIFT_REPO: Found ${employeesResponse.data!.length} employees assigned to this shift');
          return ApiResponse(
            success: false,
            errorMessage: 'Cannot delete shift: There are employees assigned to this shift. Please remove all employees first.',
          );
        }
      } catch (e) {
        print('SHIFT_REPO: Error checking assigned employees: $e');
        // Continue with deletion attempt even if we couldn't check employees
      }

      // Use the delete shift URL
      final url = ApiConstants.getDeleteShiftUrl(shiftId);
      developer.log('Using shift delete URL: $url');
      print('SHIFT_REPO: Using URL for deletion: $url');
      
      // Make the API call
      print('SHIFT_REPO: Sending DELETE request to $url with auth token');
      final response = await _apiService.delete<bool>(
        url,
        token: token,
        fromJson: (json) {
          // For DELETE operations, we might not get a response body
          print('SHIFT_REPO: Delete response received: $json');
          
          // Just return true if the status code indicates success
          return true;
        },
      );
      
      if (response.success) {
        developer.log('Shift deleted successfully');
        print('SHIFT_REPO: Shift deleted successfully!');
      } else {
        developer.log('Failed to delete shift: ${response.errorMessage}');
        print('SHIFT_REPO: Failed to delete shift: ${response.errorMessage}');
        
        // Add more useful error messages for common scenarios
        if (response.errorMessage?.contains('saving the entity changes') == true) {
          return ApiResponse(
            success: false,
            errorMessage: 'Failed to delete shift: This shift may have employees or records associated with it. Please remove all assignments first.',
          );
        }
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in deleteShift: $e');
      print('SHIFT_REPO: Exception in deleteShift: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Utility method to check which HTTP methods are allowed for an endpoint
  Future<void> checkAllowedMethods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        print('CHECK_METHODS: No auth token available');
        return;
      }
      
      final petrolPumpId = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
      if (petrolPumpId == null) {
        print('CHECK_METHODS: No petrol pump ID available');
        return;
      }
      
      print('CHECK_METHODS: Running check for shift endpoints...');
      
      // Check endpoints with HEAD request (which doesn't return a body)
      final urls = [
        '${ApiConstants.baseUrl}/api/Shift',
        '${ApiConstants.baseUrl}/api/Shift/$petrolPumpId',
        '${ApiConstants.baseUrl}/api/Shift/$petrolPumpId/shifts',
      ];
      
      for (final url in urls) {
        print('CHECK_METHODS: Checking endpoint: $url');

        try {
          // Try different methods to see which ones work
          print('CHECK_METHODS: Trying GET for $url');
          final getResponse = await http.get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer $token'},
          );
          print('CHECK_METHODS: GET status for $url: ${getResponse.statusCode}');

          // Optional: Try POST with empty data
          print('CHECK_METHODS: Trying POST for $url');
          final postResponse = await http.post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: '{}',
          );
          print('CHECK_METHODS: POST status for $url: ${postResponse.statusCode}');

          // Try PUT with empty data
          print('CHECK_METHODS: Trying PUT for $url');
          final putResponse = await http.put(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: '{}',
          );
          print('CHECK_METHODS: PUT status for $url: ${putResponse.statusCode}');

          // Summary
          print('CHECK_METHODS: Summary for $url:');
          print('  GET: ${getResponse.statusCode == 200 ? "✅" : "❌"} (${getResponse.statusCode})');
          print('  POST: ${postResponse.statusCode == 200 || postResponse.statusCode == 201 ? "✅" : "❌"} (${postResponse.statusCode})');
          print('  PUT: ${putResponse.statusCode == 200 || putResponse.statusCode == 201 ? "✅" : "❌"} (${putResponse.statusCode})');

        } catch (e) {
          print('CHECK_METHODS: Error checking $url: $e');
        }
      }
      
      // Try the correct URL directly with the correct approach
      final correctUrl = '${ApiConstants.baseUrl}/api/Shift/$petrolPumpId/shifts';
      print('CHECK_METHODS: Specifically testing correct endpoint: $correctUrl');
      
      try {
        final response = await http.post(
          Uri.parse(correctUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'startTime': '08:00',
            'endTime': '16:00',
            'shiftNumber': 1,
            'shiftDuration': 8
          }),
        );
        
        print('CHECK_METHODS: POST to correct endpoint status: ${response.statusCode}');
        print('CHECK_METHODS: POST to correct endpoint body: ${response.body}');
      } catch (e) {
        print('CHECK_METHODS: Error testing correct endpoint: $e');
      }
    } catch (e) {
      print('CHECK_METHODS: Exception: $e');
    }
  }

  // Get employee details for a specific shift
  Future<ApiResponse<List<Employee>>> getEmployeeDetailsForShift(String shiftId) async {
    developer.log('Getting employee details for shift ID: $shiftId');
    print('SHIFT_REPO: Getting employee details for shift ID: $shiftId');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        print('SHIFT_REPO: No auth token found for getting employee details');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Use the endpoint for getting employees by shift
      final url = ApiConstants.getEmployeesByShiftIdUrl(shiftId);
      
      final response = await _apiService.get<List<Employee>>(
        url,
        token: token,
        fromJson: (json) {
          print('SHIFT_REPO: Employee details response: $json');
          List<dynamic> employeeList = [];
          
          if (json is Map && json.containsKey('data') && json['data'] is List) {
            employeeList = json['data'] as List;
            print('SHIFT_REPO: Found employees in data field, count: ${employeeList.length}');
          } else if (json is List) {
            employeeList = json;
            print('SHIFT_REPO: Got direct list of employees, count: ${employeeList.length}');
          } else {
            print('SHIFT_REPO: Unexpected response format: $json');
            return <Employee>[];
          }
          
          List<Employee> employees = [];
          
          try {
            employees = employeeList.map((item) {
              print('SHIFT_REPO: Processing employee item: $item');
              
              // Extract first and last name from employeeName if available
              String firstName = '';
              String lastName = '';
              
              if (item['employeeName'] != null) {
                print('SHIFT_REPO: Found employeeName: ${item['employeeName']}');
                final nameParts = (item['employeeName'] as String).split(' ');
                if (nameParts.isNotEmpty) {
                  firstName = nameParts[0];
                  // If there are multiple parts, join all remaining parts as last name
                  if (nameParts.length > 1) {
                    lastName = nameParts.sublist(1).join(' ');
                  }
                }
              }
              
              // Map API field names to our Employee model field names
              Map<String, dynamic> mappedItem = {
                'id': item['employeeId'] ?? item['id'],
                'firstName': item['firstName'] ?? firstName,
                'lastName': item['lastName'] ?? lastName,
                'email': item['email'] ?? '',
                'phoneNumber': item['phoneNumber'] ?? '',
                'role': item['role'] ?? 'Attendant',
                'hireDate': item['hireDate'] ?? DateTime.now().toIso8601String(),
                'dateOfBirth': item['dateOfBirth'] ?? '2000-01-01T00:00:00',
                'governmentId': item['governmentId'] ?? '',
                'address': item['address'] ?? '',
                'city': item['city'] ?? '',
                'state': item['state'] ?? '',
                'zipCode': item['zipCode'] ?? '',
                'emergencyContact': item['emergencyContact'] ?? '',
                'petrolPumpId': item['petrolPumpId'] ?? '',
                'password': '', // Not returned by API
                'isActive': item['isActive'] ?? true,
              };
              
              print('SHIFT_REPO: Mapped employee data: $mappedItem');
              return Employee.fromJson(mappedItem);
            }).toList();
            
            print('SHIFT_REPO: Successfully processed ${employees.length} employees for the shift');
          } catch (e) {
            print('SHIFT_REPO: Error converting JSON to Employee objects: $e');
            return <Employee>[];
          }
          
          return employees;
        },
      );
      
      if (response.success) {
        developer.log('Employee details for shift retrieved successfully. Count: ${response.data?.length ?? 0}');
        print('SHIFT_REPO: Successfully retrieved ${response.data?.length ?? 0} employees for the shift');
      } else {
        developer.log('Failed to retrieve employee details for shift: ${response.errorMessage}');
        print('SHIFT_REPO: Failed to retrieve employee details for shift: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in getEmployeeDetailsForShift: $e');
      print('SHIFT_REPO: Exception in getEmployeeDetailsForShift: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
} 