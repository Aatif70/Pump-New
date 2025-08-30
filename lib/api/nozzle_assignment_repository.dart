import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/employee_nozzle_assignment_model.dart';
import 'api_constants.dart';
import 'api_response.dart';
import 'dart:developer' as developer;

class NozzleAssignmentRepository {
  // Get auth token from SharedPreferences
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      developer.log('NozzleAssignmentRepository: Retrieved auth token: ${token != null ? 'Token exists' : 'No token found'}');
      return token;
    } catch (e) {
      developer.log('NozzleAssignmentRepository: Error getting auth token: $e');
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
      developer.log('NozzleAssignmentRepository: Added auth token to headers');
    } else {
      developer.log('NozzleAssignmentRepository: Warning - No auth token available');
    }
    
    return headers;
  }

  Future<ApiResponse<List<EmployeeNozzleAssignment>>> getEmployeeNozzleAssignments(String employeeId) async {
    try {
      developer.log('Fetching nozzle assignments for employee: $employeeId');
      
      final url = Uri.parse('${ApiConstants.baseUrl}/api/EmployeeNozzleAssignments/employee/$employeeId');
      
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );
      
      developer.log('Nozzle assignments response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        
        final List<EmployeeNozzleAssignment> assignments = jsonData
            .map((data) => EmployeeNozzleAssignment.fromJson(data))
            .toList();
        
        developer.log('Loaded ${assignments.length} nozzle assignments');
        return ApiResponse<List<EmployeeNozzleAssignment>>(
          success: true,
          data: assignments,
        );
      } else {
        final errorMsg = 'Failed to load nozzle assignments. Status: ${response.statusCode}';
        developer.log(errorMsg);
        return ApiResponse<List<EmployeeNozzleAssignment>>(
          success: false,
          errorMessage: errorMsg,
        );
      }
    } catch (e) {
      developer.log('Exception in getEmployeeNozzleAssignments: $e');
      return ApiResponse<List<EmployeeNozzleAssignment>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }
} 