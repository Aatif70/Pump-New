import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'dart:convert';

import '../models/shift_model.dart';
import 'api_constants.dart';
import 'api_service.dart';
import '../models/employee_model.dart';
import '../models/employee_shift_model.dart';

class EmployeeShiftRepository {
  final ApiService _apiService = ApiService();

  // Assign employee to shift with retry logic
  Future<ApiResponse<dynamic>> assignEmployeeToShift(
      String employeeId, String shiftId, DateTime assignedDate, bool isTransfer) async
  {
    developer.log('Assigning employee $employeeId to shift $shiftId');
    developer.log('Assignment date: ${assignedDate.toIso8601String()}, isTransfer: $isTransfer');
    
    // Retry parameters
    int maxRetries = 3;
    int retryCount = 0;
    Duration retryDelay = const Duration(seconds: 2);
    
    while (retryCount < maxRetries) {
      try {
        // Get the authentication token
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(ApiConstants.authTokenKey);
        
        if (token == null) {
          developer.log('No auth token found for assigning employee to shift');
          return ApiResponse(
            success: false,
            errorMessage: 'You are not logged in. Please login to continue.',
          );
        }
        
        // Create a proper EmployeeShift model and use its toJson method
        // This ensures we follow the same structure used throughout the app
        final employeeShift = EmployeeShift(
          employeeId: employeeId.trim(),
          shiftId: shiftId.trim(),
          assignedDate: assignedDate,
          isTransfer: isTransfer,
        );
        
        final requestBody = employeeShift.toJson();
        
        // Log the request details for debugging
        developer.log('Sending assignment request with data: $requestBody');
        developer.log('ASSIGN_REQUEST_BODY: ${jsonEncode(requestBody)}');
        
        // API endpoint for employee shift assignment
        final url = ApiConstants.getAssignEmployeeToShiftUrl();
        developer.log('ASSIGN_URL: $url');
        
        // Make the API call - accept any type for the response data
        final response = await _apiService.post<dynamic>(
          url,
          body: requestBody,
          token: token,
          fromJson: (json) {
            // Handle both string and map responses
            if (json is String) {
              developer.log('Received string data response: $json');
              return json;
            } else if (json is Map<String, dynamic>) {
              developer.log('Received map data response: $json');
              return json;
            } else {
              developer.log('Received other data type: ${json.runtimeType}');
              return json;
            }
          },
        );
        
        // Log response details
        developer.log('ASSIGN_RESPONSE: ${response.success ? 'Success' : 'Failed'} - ${response.errorMessage ?? ''}');
        
        if (response.success) {
          developer.log('Employee successfully assigned to shift');
          return response;
        } else {
          // More detailed error handling for server errors
          if (response.errorMessage?.toLowerCase().contains('server error') == true) {
            developer.log('SERVER ERROR detected in employee assignment');
            
            // If we haven't reached max retries, wait and try again with a different format
            if (retryCount < maxRetries - 1) {
              developer.log('Server error encountered, retrying with alternative format (${retryCount + 1}/$maxRetries)...');
              retryCount++;
              
              // Try with a slightly different format that some APIs might expect
              final alternativeBody = {
                'employeeId': employeeId.trim(),
                'shiftId': shiftId.trim(),
                'assignedDate': assignedDate.toIso8601String().split('T')[0], // Just the date part
                'isTransfer': isTransfer,
              };
              
              developer.log('Alternative request body: ${jsonEncode(alternativeBody)}');
              
              final alternativeResponse = await _apiService.post<dynamic>(
                url,
                body: alternativeBody,
                token: token,
                fromJson: (json) {
                  // Handle both string and map responses
                  if (json is String) {
                    developer.log('Received string data response: $json');
                    return json;
                  } else if (json is Map<String, dynamic>) {
                    developer.log('Received map data response: $json');
                    return json;
                  } else {
                    developer.log('Received other data type: ${json.runtimeType}');
                    return json;
                  }
                },
              );
              
              if (alternativeResponse.success) {
                developer.log('Employee successfully assigned to shift with alternative format');
                return alternativeResponse;
              }
              
              await Future.delayed(retryDelay * retryCount);
              continue; // Try again with original data after delay
            }
          }
          
          developer.log('Failed to assign employee to shift: ${response.errorMessage}');
          return response;
        }
      } catch (e) {
        // For network or other exceptions, also retry
        if (retryCount < maxRetries - 1) {
          developer.log('Exception encountered, retrying (${retryCount + 1}/$maxRetries): $e');
          retryCount++;
          await Future.delayed(retryDelay * retryCount);
          continue; // Try again
        }
        
        developer.log('Exception in assignEmployeeToShift after $maxRetries attempts: $e');
        return ApiResponse(
          success: false,
          errorMessage: 'Failed to assign employee after multiple attempts. Please try again later.',
        );
      }
    }
    
    // This should not be reached, but just in case
    return ApiResponse(
      success: false,
      errorMessage: 'Failed to assign employee after maximum retry attempts.',
    );
  }
  
  // Get employees by shift ID
  Future<ApiResponse<List<Employee>>> getEmployeesByShiftId(String shiftId) async {
    developer.log('Getting employees for shift ID: $shiftId');
    
    try {
      // Get token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      // Check if token exists
      if (token == null) {
        developer.log('No auth token found for getting employees by shift ID');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // API endpoint for getting employees by shift
      final url = ApiConstants.getEmployeesByShiftIdUrl(shiftId);
      
      final response = await _apiService.get<List<Employee>>(
        url,
        token: token,
        fromJson: (json) {
          developer.log('Response data type: ${json.runtimeType}');
          
          // Handle different response formats
          List<dynamic> employeeList = [];
          
          if (json is Map && json.containsKey('data') && json['data'] is List) {
            employeeList = json['data'] as List;
            developer.log('Found employees in data field, count: ${employeeList.length}');
          } else if (json is List) {
            employeeList = json;
            developer.log('Got direct list of employees, count: ${employeeList.length}');
          } else {
            developer.log('Unexpected response format: $json');
            return <Employee>[];
          }
          
          // Convert JSON to Employee objects
          try {
            final employees = employeeList
                .map((item) {
                  // Log the API response item
                  developer.log('Employee shift API response item: $item');
                  
                  // Check if employeeName exists and split it to get first and last name
                  String firstName = '';
                  String lastName = '';
                  
                  if (item['employeeName'] != null) {
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
                  final mappedItem = {
                    'id': item['employeeId'],
                    'firstName': item['firstName'] ?? firstName, // Use extracted firstName if direct field not available
                    'lastName': item['lastName'] ?? lastName, // Use extracted lastName if direct field not available
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
                  
                  return Employee.fromJson(mappedItem);
                })
                .toList();
            
            developer.log('Successfully processed ${employees.length} employees for shift');
            return employees;
          } catch (e) {
            developer.log('Error converting JSON to Employee objects: $e');
            return <Employee>[];
          }
        },
      );
      
      // Log results for debugging
      if (response.success) {
        final count = response.data?.length ?? 0;
        developer.log('Successfully got $count employees for shift');
      } else {
        developer.log('Failed to get employees for shift: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in getEmployeesByShiftId: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Delete an employee shift assignment
  Future<ApiResponse<bool>> deleteEmployeeShift(String employeeShiftId) async {
    print('REPOSITORY: Deleting employee shift with ID: $employeeShiftId');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        print('REPOSITORY: No auth token found for deleting employee shift');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // API endpoint for employee shift deletion
      final url = ApiConstants.getDeleteEmployeeShiftUrl(employeeShiftId);
      print('REPOSITORY: DELETE URL: $url');
      
      // Make the API call
      final response = await _apiService.delete<bool>(
        url,
        token: token,
        fromJson: (json) => true, // Just return true for success
      );
      
      // Log response details
      print('REPOSITORY: DELETE_RESPONSE: ${response.success ? 'Success' : 'Failed'} - ${response.errorMessage ?? ''}');
      
      if (response.success) {
        print('REPOSITORY: Employee shift deleted successfully');
      }
      
      return response;
    } catch (e) {
      print('REPOSITORY: Exception in deleteEmployeeShift: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Get employee shift details for a specific employee and shift
  Future<ApiResponse<String>> getEmployeeShiftId(String employeeId, String shiftId) async {
    developer.log('Getting employee shift ID for employee $employeeId and shift $shiftId');
    
    try {
      // Get token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      // Check if token exists
      if (token == null) {
        developer.log('No auth token found for getting employee shift ID');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // API endpoint for getting employee shifts by shift ID
      final url = ApiConstants.getEmployeeShiftsByShiftIdUrl(shiftId);
      print('REPOSITORY: Getting employee shifts URL: $url');
      
      final response = await _apiService.get<List<Map<String, dynamic>>>(
        url,
        token: token,
        fromJson: (json) {
          print('REPOSITORY: Employee shifts response: $json');
          
          // Handle the API response which contains a data array
          List<dynamic> shiftList = [];
          
          if (json is Map && json.containsKey('data') && json['data'] is List) {
            shiftList = json['data'] as List;
            print('REPOSITORY: Found ${shiftList.length} employee shifts in the data array');
          } else if (json is List) {
            shiftList = json;
            print('REPOSITORY: Found ${shiftList.length} employee shifts in direct list');
          } else {
            print('REPOSITORY: Unexpected response format: $json');
            return <Map<String, dynamic>>[];
          }
          
          // Convert to List<Map<String, dynamic>>
          return List<Map<String, dynamic>>.from(
            shiftList.map((e) => Map<String, dynamic>.from(e))
          );
        },
      );
      
      if (!response.success || response.data == null) {
        print('REPOSITORY: Failed to get employee shifts: ${response.errorMessage}');
        return ApiResponse(
          success: false,
          errorMessage: response.errorMessage ?? 'Failed to get employee shifts',
        );
      }
      
      // Find the specific employee shift
      final shifts = response.data!;
      print('REPOSITORY: Processing ${shifts.length} employee shifts to find match');
      
      // Debug - print all shifts
      for (var shift in shifts) {
        print('REPOSITORY: Shift record - employeeId: ${shift['employeeId']}, shiftId: ${shift['shiftId']}, employeeShiftId: ${shift['employeeShiftId']}');
      }
      
      final employeeShift = shifts.firstWhere(
        (shift) => shift['employeeId'] == employeeId,
        orElse: () => {},
      );
      
      if (employeeShift.isEmpty || employeeShift['employeeShiftId'] == null) {
        print('REPOSITORY: Employee shift not found for employee $employeeId and shift $shiftId');
        return ApiResponse(
          success: false,
          errorMessage: 'Employee shift not found',
        );
      }
      
      // Use employeeShiftId instead of id
      print('REPOSITORY: Found employeeShiftId: ${employeeShift['employeeShiftId']}');
      return ApiResponse(
        success: true,
        data: employeeShift['employeeShiftId'].toString(),
      );
    } catch (e) {
      print('REPOSITORY: Exception in getEmployeeShiftId: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Remove an employee from a shift by finding the employee shift ID first
  Future<ApiResponse<bool>> removeEmployeeFromShift(String employeeId, String shiftId) async {
    print('REPOSITORY: Removing employee $employeeId from shift $shiftId');
    
    try {
      // First, get the employee shift ID
      print('REPOSITORY: Getting employee shift ID for employee $employeeId in shift $shiftId');
      final idResponse = await getEmployeeShiftId(employeeId, shiftId);
      
      if (!idResponse.success || idResponse.data == null) {
        print('REPOSITORY: Failed to get employee shift ID: ${idResponse.errorMessage}');
        return ApiResponse(
          success: false,
          errorMessage: 'Failed to get employee shift ID: ${idResponse.errorMessage}',
        );
      }
      
      // Get the employee shift ID
      final employeeShiftId = idResponse.data!;
      print('REPOSITORY: Found employee shift ID: $employeeShiftId - Proceeding with deletion');
      
      // Delete the employee shift
      return await deleteEmployeeShift(employeeShiftId);
    } catch (e) {
      print('REPOSITORY: Exception in removeEmployeeFromShift: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Get shifts assigned to a specific employee
  Future<ApiResponse<List<Shift>>> getShiftsByEmployeeId(String employeeId) async {
    print('DEBUG_REPO: Getting shifts for employee ID: $employeeId');
    
    try {
      // Get token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      // Check if token exists
      if (token == null) {
        print('DEBUG_REPO: No auth token found for getting employee shifts');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // API endpoint for getting shifts by employee
      final url = ApiConstants.getShiftsByEmployeeIdUrl(employeeId);
      print('DEBUG_REPO: Requesting shifts from URL: $url');
      
      final response = await _apiService.get<List<Shift>>(
        url,
        token: token,
        fromJson: (json) {
          print('DEBUG_REPO: Raw response from API: $json');
          
          // Handle different response formats
          List<dynamic> employeeShiftList = [];
          
          if (json is Map && json.containsKey('data') && json['data'] is List) {
            employeeShiftList = json['data'] as List;
            print('DEBUG_REPO: Found employee shifts in data field, count: ${employeeShiftList.length}');
          } else if (json is List) {
            employeeShiftList = json;
            print('DEBUG_REPO: Got direct list of employee shifts, count: ${employeeShiftList.length}');
          } else {
            print('DEBUG_REPO: Unexpected response format for employee shifts: $json');
            return <Shift>[];
          }
          
          // Extract shift details from employee shifts
          List<Shift> shifts = [];
          try {
            for (var employeeShift in employeeShiftList) {
              print('DEBUG_REPO: Processing employee shift: $employeeShift');
              
              // Check if the employee shift contains a direct shift object
              if (employeeShift is Map && employeeShift.containsKey('shift')) {
                var shiftData = employeeShift['shift'];
                print('DEBUG_REPO: Found shift data in employee shift: $shiftData');
                
                if (shiftData != null) {
                  try {
                    shifts.add(Shift.fromJson(shiftData));
                  } catch (e) {
                    print('DEBUG_REPO: Error parsing shift from employee shift: $e');
                  }
                }
              }
              // If shift ID is available but not the full shift object
              else if (employeeShift is Map && employeeShift.containsKey('shiftId')) {
                String? shiftId = employeeShift['shiftId']?.toString();
                print('DEBUG_REPO: Found shiftId $shiftId, need to fetch shift details');
                
                // Here you would ideally fetch the shift details
                // But for simplicity, create a minimal shift object
                if (shiftId != null) {
                  // Extract simple shift data from the employee shift assignment
                  shifts.add(Shift(
                    id: shiftId,
                    startTime: employeeShift['shiftStartTime'] ?? "00:00",
                    endTime: employeeShift['shiftEndTime'] ?? "00:00",
                    shiftNumber: int.tryParse(employeeShift['shiftNumber']?.toString() ?? '0') ?? 0,
                    shiftDuration: 8, // Default to 8 hours if not specified
                  ));
                }
              }
            }
            
            print('DEBUG_REPO: Successfully processed ${shifts.length} shifts for employee');
            return shifts;
          } catch (e) {
            print('DEBUG_REPO: Error processing employee shifts: $e');
            return <Shift>[];
          }
        },
      );
      
      // Log results for debugging
      if (response.success) {
        final count = response.data?.length ?? 0;
        print('DEBUG_REPO: Successfully got $count shifts for employee');
      } else {
        print('DEBUG_REPO: Failed to get shifts for employee: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      print('DEBUG_REPO: Exception in getShiftsByEmployeeId: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Remove all employees from a shift (used when deleting a shift)
  Future<ApiResponse<bool>> removeAllEmployeesFromShift(String shiftId) async {
    print('REPOSITORY: Removing all employees from shift $shiftId');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        print('REPOSITORY: No auth token found for removing employees from shift');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // First, get all employees for this shift
      print('REPOSITORY: Getting all employees for shift $shiftId');
      final employeesResponse = await getEmployeesByShiftId(shiftId);
      
      if (!employeesResponse.success) {
        print('REPOSITORY: Failed to get employees for shift: ${employeesResponse.errorMessage}');
        return ApiResponse(
          success: false,
          errorMessage: 'Failed to get employees for shift: ${employeesResponse.errorMessage}',
        );
      }
      
      final employees = employeesResponse.data ?? [];
      print('REPOSITORY: Found ${employees.length} employees to remove from shift');
      
      if (employees.isEmpty) {
        // No employees to remove, return success
        print('REPOSITORY: No employees found for shift $shiftId');
        return ApiResponse(
          success: true,
          data: true,
        );
      }
      
      // Track overall success
      bool allSucceeded = true;
      List<String> failedEmployees = [];
      
      // Remove each employee from the shift
      for (final employee in employees) {
        if (employee.id == null || employee.id!.isEmpty) {
          print('REPOSITORY: Skipping employee with missing ID');
          continue;
        }
        
        print('REPOSITORY: Removing employee ${employee.id} (${employee.firstName} ${employee.lastName}) from shift');
        final removeResponse = await removeEmployeeFromShift(employee.id!, shiftId);
        
        if (!removeResponse.success) {
          print('REPOSITORY: Failed to remove employee ${employee.id}: ${removeResponse.errorMessage}');
          allSucceeded = false;
          failedEmployees.add('${employee.firstName} ${employee.lastName}');
        }
      }
      
      if (allSucceeded) {
        print('REPOSITORY: Successfully removed all employees from shift $shiftId');
        return ApiResponse(
          success: true,
          data: true,
        );
      } else {
        print('REPOSITORY: Failed to remove some employees from shift');
        return ApiResponse(
          success: false,
          errorMessage: 'Failed to remove the following employees from the shift: ${failedEmployees.join(", ")}',
        );
      }
    } catch (e) {
      print('REPOSITORY: Exception in removeAllEmployeesFromShift: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
} 