import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/booklet_model.dart';
import '../utils/shared_prefs.dart';
import 'api_constants.dart';
import 'api_response.dart';

class BookletRepository {
  Future<ApiResponse<List<Booklet>>> getAllBooklets(String pumpId) async {
    try {
      final token = await SharedPrefs.getAuthToken();
      if (token == null) {
        return ApiResponse<List<Booklet>>(
          success: false,
          errorMessage: 'Authentication token not found',
        );
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/api/Booklets/pump/$pumpId');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['data'] ?? [];
          final List<Booklet> booklets = data
              .map((json) => Booklet.fromJson(json))
              .toList();
          
          return ApiResponse<List<Booklet>>(
            success: true,
            data: booklets,
          );
        } else {
          return ApiResponse<List<Booklet>>(
            success: false,
            errorMessage: responseData['message'] ?? 'Failed to load booklets',
          );
        }
      } else {
        return ApiResponse<List<Booklet>>(
          success: false,
          errorMessage: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      return ApiResponse<List<Booklet>>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }

  Future<ApiResponse<Booklet>> addBooklet(Map<String, dynamic> bookletData) async {
    try {
      final token = await SharedPrefs.getAuthToken();
      if (token == null) {
        return ApiResponse<Booklet>(
          success: false,
          errorMessage: 'Authentication token not found',
        );
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/api/Booklets');
      
      // Debug prints for HTTP request
      print('=== HTTP REQUEST DEBUG ===');
      print('URL: $url');
      print('Headers: ${{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }}');
      print('Request body: ${json.encode(bookletData)}');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(bookletData),
      );
      
      // Debug prints for HTTP response
      print('=== HTTP RESPONSE DEBUG ===');
      print('Status code: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        if (responseData['success'] == true) {
          final Booklet booklet = Booklet.fromJson(responseData['data']);
          
          return ApiResponse<Booklet>(
            success: true,
            data: booklet,
          );
        } else {
          return ApiResponse<Booklet>(
            success: false,
            errorMessage: responseData['message'] ?? 'Failed to add booklet',
          );
        }
      } else {
        return ApiResponse<Booklet>(
          success: false,
          errorMessage: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      return ApiResponse<Booklet>(
        success: false,
        errorMessage: 'Error: $e',
      );
    }
  }
}
