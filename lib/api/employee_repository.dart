import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

import 'api_constants.dart';
import 'api_service.dart';
import '../models/employee_model.dart';
import '../utils/jwt_decoder.dart';

class EmployeeRepository {
  final ApiService _apiService = ApiService();

  // // Flag to use mock data for testing
  // final bool _useMockData = false; // Always set to false for production

  // Add a new employee
  Future<ApiResponse<Map<String, dynamic>>> addEmployee(Employee employee) async {
    developer.log('Adding employee with details: ${employee.toJson()}');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for adding employee');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Make the API call
      final response = await _apiService.post<Map<String, dynamic>>(
        ApiConstants.getEmployeeUrl(),
        body: employee.toJson(),
        token: token,
        fromJson: (json) => json as Map<String, dynamic>,
      );
      
      if (response.success) {
        developer.log('Employee added successfully');
      } else {
        developer.log('Failed to add employee: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in addEmployee: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Get all employees - simplified to directly fetch from the endpoint
  Future<ApiResponse<List<Employee>>> getAllEmployees({bool forceRefresh = false}) async {
    print('REPOSITORY: Getting all employees');
    
    try {
      // Get token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      // Check if token exists
      if (token == null) {
        print('REPOSITORY: No auth token found for getting employees');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Add timestamp to prevent caching issues
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = '${ApiConstants.getEmployeeUrl()}?t=$timestamp';
      print('REPOSITORY: Requesting employees from: $url with timestamp to prevent caching');
      
      final response = await _apiService.get<List<Employee>>(
        url,
        token: token, // Pass token for authentication
        fromJson: (json) {
          developer.log('Response data type: ${json.runtimeType}');
          
          // Handle different response formats
          List<dynamic> employeeList = [];
          
          if (json is Map && json.containsKey('data') && json['data'] is List) {
            // Format: {"data": [...employees...], "success": true, "message": "..."}
            employeeList = json['data'] as List;
            developer.log('Found employees in data field, count: ${employeeList.length}');
            print('Processing ${employeeList.length} employees from "data" field');
          } else if (json is List) {
            // Format: [...employees...]
            employeeList = json;
            developer.log('Got direct list of employees, count: ${employeeList.length}');
            print('Processing ${employeeList.length} employees from direct list');
          } else {
            developer.log('Unexpected response format: $json');
            print('Unexpected response format: $json');
            return <Employee>[];
          }
          
          // Convert JSON to Employee objects
          try {
            final employees = employeeList
                .map((item) {

                  
                  // Map API field names to our Employee model field names
                  final mappedItem = {
                    'id': item['employeeId'],
                    'firstName': item['firstName'],
                    'lastName': item['lastName'],
                    'email': item['email'],
                    'phoneNumber': item['phoneNumber'],
                    'role': item['role'],
                    'hireDate': item['hireDate'],
                    'dateOfBirth': item['dateOfBirth'] ?? '2000-01-01T00:00:00',
                    'governmentId': item['governmentId'] ?? '',
                    'address': item['address'] ?? '',
                    'city': item['city'] ?? '',
                    'state': item['state'] ?? '',
                    'zipCode': item['zipCode'] ?? '',
                    'emergencyContact': item['emergencyContact'] ?? '',
                    'petrolPumpId': item['petrolPumpId'],
                    'password': '', // Not returned by API
                    'isActive': item['isActive'] ?? true, // Add explicit mapping for isActive
                  };
                  
                  return Employee.fromJson(mappedItem);
                })
                .toList();
            
            developer.log('Successfully processed ${employees.length} employees');
            print('Successfully mapped ${employees.length} employees to model objects');
            return employees;
          } catch (e) {
            developer.log('Error converting JSON to Employee objects: $e');
            print('Error converting JSON to Employee objects: $e');
            return <Employee>[];
          }
        },
      );
      
      // Log results for debugging
      if (response.success) {
        final count = response.data?.length ?? 0;
        developer.log('Successfully got $count employees');
        print('Successfully got $count employees from API');
      } else {
        developer.log('Failed to get employees: ${response.errorMessage}');
        print('Failed to get employees: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in getAllEmployees: $e');
      print('Exception in getAllEmployees: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Get employee by ID
  Future<ApiResponse<Employee>> getEmployeeById(String id) async {
    print('REPOSITORY: Getting employee with ID: $id');
    
    try {
      // Get token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      // Check if token exists
      if (token == null) {
        print('REPOSITORY: No auth token found for getting employee details');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Direct API call to get employee by ID
      final url = '${ApiConstants.getEmployeeUrl()}/$id';
      print('REPOSITORY: Requesting employee details from: $url');
      
      final response = await _apiService.get<Employee>(
        url,
        token: token,
        fromJson: (json) {
          print('REPOSITORY: Response data for employee: $json');
          
          // Handle different response formats
          Map<String, dynamic> employeeData = {};
          
          if (json is Map && json.containsKey('data')) {
            // Format: {"data": {...employee data...}}
            print('REPOSITORY: Found employee in data field');
            employeeData = (json['data'] as Map).cast<String, dynamic>();
          } else if (json is Map) {
            // Format: {...employee data...}
            employeeData = (json).cast<String, dynamic>();
          } else {
            print('REPOSITORY: Unexpected response format for employee: $json');
            return Employee(
              id: id, // Use requested ID as fallback
              firstName: '',
              lastName: '',
              email: '',
              phoneNumber: '',
              role: '',
              hireDate: DateTime.now(),
              password: '',
              petrolPumpId: '',
              dateOfBirth: DateTime.now(),
              governmentId: '',
              address: '',
              city: '',
              state: '',
              zipCode: '',
              emergencyContact: '',
              isActive: true,
            );
          }
          
          // Debug log to check if isActive is present in the data
          print('REPOSITORY: Employee data contains isActive? ${employeeData.containsKey('isActive')}');
          if (employeeData.containsKey('isActive')) {
            print('REPOSITORY: isActive value is: ${employeeData['isActive']}');
          }
          
          // Ensure we map employeeId to id
          if (employeeData.containsKey('employeeId') && !employeeData.containsKey('id')) {
            employeeData['id'] = employeeData['employeeId'];
            print('REPOSITORY: Mapped employeeId to id: ${employeeData['id']}');
          }
          
          // If id is still missing, use the requested id
          if (!employeeData.containsKey('id') || employeeData['id'] == null) {
            employeeData['id'] = id;
            print('REPOSITORY: Using requested ID as fallback: $id');
          }
          
          // Make sure isActive is properly included
          if (!employeeData.containsKey('isActive')) {
            employeeData['isActive'] = true; // Default to active if not provided
            print('REPOSITORY: Setting default isActive: true');
          }
          
          try {
            return Employee.fromJson(employeeData);
          } catch (e) {
            print('REPOSITORY: Error parsing employee data: $e');
            return Employee(
              id: id,
              firstName: '',
              lastName: '',
              email: '',
              phoneNumber: '',
              role: '',
              hireDate: DateTime.now(),
              password: '',
              petrolPumpId: '',
              dateOfBirth: DateTime.now(),
              governmentId: '',
              address: '',
              city: '',
              state: '',
              zipCode: '',
              emergencyContact: '',
              isActive: true,
            );
          }
        },
      );
      
      return response;
    } catch (e) {
      print('REPOSITORY: Exception in getEmployeeById: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Get current employee using the Current endpoint
  Future<ApiResponse<Employee>> getCurrentEmployee() async {
    print('REPOSITORY: Getting current employee details');
    
    try {
      // Get token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      // Check if token exists
      if (token == null) {
        print('REPOSITORY: No auth token found for getting employee details');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Direct API call to get current employee
      final url = '${ApiConstants.getEmployeeUrl()}/Current';
      print('REPOSITORY: Requesting current employee details from: $url');
      
      final response = await _apiService.get<Employee>(
        url,
        token: token,
        fromJson: (json) {
          print('REPOSITORY: Response data for current employee: $json');
          
          // Handle different response formats
          Map<String, dynamic> employeeData = {};
          
          if (json is Map && json.containsKey('data')) {
            // Format: {"data": {...employee data...}}
            print('REPOSITORY: Found employee in data field');
            employeeData = (json['data'] as Map).cast<String, dynamic>();
          } else if (json is Map) {
            // Format: {...employee data...}
            employeeData = (json).cast<String, dynamic>();
          } else {
            print('REPOSITORY: Unexpected response format for employee: $json');
            return Employee(
              id: '',
              firstName: '',
              lastName: '',
              email: '',
              phoneNumber: '',
              role: '',
              hireDate: DateTime.now(),
              password: '',
              petrolPumpId: '',
              dateOfBirth: DateTime.now(),
              governmentId: '',
              address: '',
              city: '',
              state: '',
              zipCode: '',
              emergencyContact: '',
              isActive: true,
            );
          }
          
          // Ensure we map employeeId to id
          if (employeeData.containsKey('employeeId') && !employeeData.containsKey('id')) {
            employeeData['id'] = employeeData['employeeId'];
            print('REPOSITORY: Mapped employeeId to id: ${employeeData['id']}');
          }
          
          // Make sure isActive is properly included
          if (!employeeData.containsKey('isActive')) {
            employeeData['isActive'] = true; // Default to active if not provided
            print('REPOSITORY: Setting default isActive: true');
          }
          
          try {
            return Employee.fromJson(employeeData);
          } catch (e) {
            print('REPOSITORY: Error parsing employee data: $e');
            return Employee(
              id: '',
              firstName: '',
              lastName: '',
              email: '',
              phoneNumber: '',
              role: '',
              hireDate: DateTime.now(),
              password: '',
              petrolPumpId: '',
              dateOfBirth: DateTime.now(),
              governmentId: '',
              address: '',
              city: '',
              state: '',
              zipCode: '',
              emergencyContact: '',
              isActive: true,
            );
          }
        },
      );
      
      return response;
    } catch (e) {
      print('REPOSITORY: Exception in getCurrentEmployee: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Update employee details
  Future<ApiResponse<Map<String, dynamic>>> updateEmployee(String employeeId, Employee employee) async {
    developer.log('Updating employee with ID: $employeeId, isActive: ${employee.isActive}');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for updating employee');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Create payload for update - include employeeId in the payload
      final payload = employee.toJson();
      payload['employeeId'] = employeeId; // Add employeeId to match API expectation
      
      // Explicitly ensure isActive is included in the payload
      payload['isActive'] = employee.isActive;
      
      developer.log('Update payload includes isActive=${payload['isActive']}');
      
      // Make the API call to update employee
      final url = '${ApiConstants.getEmployeeUrl()}/$employeeId';
      developer.log('Making PUT request to: $url with payload: $payload');
      
      final response = await _apiService.put<Map<String, dynamic>>(
        url,
        body: payload,
        token: token,
        fromJson: (json) => json as Map<String, dynamic>,
      );
      
      if (response.success) {
        developer.log('Employee updated successfully');
        
        // Force refresh of employee data cache by getting it again
        await getAllEmployees(forceRefresh: true);
      } else {
        developer.log('Failed to update employee: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in updateEmployee: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Delete employee
  Future<ApiResponse<bool>> deleteEmployee(String employeeId) async {
    print('REPOSITORY: Deleting employee with ID: $employeeId');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        print('REPOSITORY: No auth token found for deleting employee');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Make the API call to DELETE employee
      final url = '${ApiConstants.getEmployeeUrl()}/$employeeId';
      print('REPOSITORY: Making DELETE request to: $url');
      
      final response = await _apiService.delete<bool>(
        url,
        token: token,
        fromJson: (json) {
          // For DELETE operations with 204 responses, 
          // we'll get an empty JSON or the ApiService will handle it
          // Just return true to indicate success
          print('REPOSITORY: Delete operation completed, received response');
          return true;
        },
      );
      
      if (response.success) {
        print('REPOSITORY: Employee deleted successfully, server confirmed');
      } else {
        print('REPOSITORY: Failed to delete employee: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      print('REPOSITORY EXCEPTION in deleteEmployee: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Helper method to get petrolPumpId from token if needed
  Future<String?> getPetrolPumpId() async {
    try {
      // Get token from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for getting petrol pump ID');
        return null;
      }
      
      // Extract petrolPumpId from token claims
      final petrolPumpId = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
      
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        developer.log('PetrolPumpId not found in JWT token');
        // Fallback to stored value if available
        return prefs.getString('petrolPumpId');
      }
      
      developer.log('PetrolPumpId from token: $petrolPumpId');
      
      // Cache the petrolPumpId for later use
      await prefs.setString('petrolPumpId', petrolPumpId);
      
      return petrolPumpId;
    } catch (e) {
      developer.log('Error getting petrol pump ID: $e');
      return null;
    }
  }
} 