import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';

import 'api_constants.dart';
import 'api_service.dart';

class EmployeeNozzleAssignmentRepository {
  final ApiService _apiService = ApiService();

  // Assign employee to nozzle
  Future<ApiResponse<Map<String, dynamic>>> assignEmployeeToNozzle({
    required String employeeId,
    required String nozzleId,
    required String shiftId,
    required DateTime startDate,
    required DateTime? endDate,
  }) async {
    developer.log('Assigning employee $employeeId to nozzle $nozzleId for shift $shiftId');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('No auth token found for employee-nozzle assignment');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Create the request body
      final body = {
        'employeeId': employeeId,
        'nozzleId': nozzleId,
        'shiftId': shiftId,
        'startDate': DateFormat('yyyy-MM-dd').format(startDate),
        if (endDate != null) 'endDate': DateFormat('yyyy-MM-dd').format(endDate),
      };
      
      developer.log('Assignment request body: $body');
      
      // Make the API call
      final response = await _apiService.post<Map<String, dynamic>>(
        '${ApiConstants.baseUrl}/api/EmployeeNozzleAssignments',
        body: body,
        token: token,
        fromJson: (json) => json as Map<String, dynamic>,
      );
      
      if (response.success) {
        developer.log('Employee assigned to nozzle successfully');
      } else {
        developer.log('Failed to assign employee to nozzle: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('Exception in assignEmployeeToNozzle: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Get nozzle assignments by nozzle ID
  Future<ApiResponse<Map<String, dynamic>>> getNozzleAssignmentsByNozzleId(String nozzleId) async {
    developer.log('EmployeeNozzleAssignmentRepository: Getting assignments for nozzle ID: $nozzleId');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('EmployeeNozzleAssignmentRepository: No auth token found');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Make the API call
      final response = await _apiService.get<Map<String, dynamic>>(
        '${ApiConstants.baseUrl}/api/EmployeeNozzleAssignments/nozzle/$nozzleId',
        token: token,
        fromJson: (json) {
          if (json is Map<String, dynamic>) {
            return json;
          } else if (json is List && json.isNotEmpty) {
            // If we get an array but need a map, return the first item
            return json.first as Map<String, dynamic>;
          } else if (json is List && json.isEmpty) {
            // Empty list means no assignments
            return <String, dynamic>{};
          }
          // Return an empty map for any other case
          return <String, dynamic>{};
        },
      );
      
      if (response.success) {
        developer.log('EmployeeNozzleAssignmentRepository: Successfully retrieved assignment');
      } else {
        developer.log('EmployeeNozzleAssignmentRepository: Failed to get assignment: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('EmployeeNozzleAssignmentRepository: Exception when getting assignment: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  // Remove employee from nozzle assignment
  Future<ApiResponse<bool>> removeEmployeeNozzleAssignment(String assignmentId) async {
    developer.log('EmployeeNozzleAssignmentRepository: Removing employee from nozzle assignment: $assignmentId');
    
    try {
      // Get the authentication token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token == null) {
        developer.log('EmployeeNozzleAssignmentRepository: No auth token found for removing assignment');
        return ApiResponse(
          success: false,
          errorMessage: 'You are not logged in. Please login to continue.',
        );
      }
      
      // Make the API call to DELETE the assignment
      final url = '${ApiConstants.baseUrl}/api/EmployeeNozzleAssignments/$assignmentId';
      developer.log('EmployeeNozzleAssignmentRepository: Making DELETE request to: $url');
      
      final response = await _apiService.delete<bool>(
        url,
        token: token,
        fromJson: (json) {
          // For DELETE operations with 204 responses, 
          // we'll get an empty JSON or the ApiService will handle it
          // Just return true to indicate success
          developer.log('EmployeeNozzleAssignmentRepository: Assignment removal completed');
          return true;
        },
      );
      
      if (response.success) {
        developer.log('EmployeeNozzleAssignmentRepository: Assignment removed successfully');
      } else {
        developer.log('EmployeeNozzleAssignmentRepository: Failed to remove assignment: ${response.errorMessage}');
      }
      
      return response;
    } catch (e) {
      developer.log('EmployeeNozzleAssignmentRepository: Exception in removeEmployeeNozzleAssignment: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
} 