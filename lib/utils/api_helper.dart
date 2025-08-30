import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_constants.dart';
import 'dart:developer' as developer;

class ApiHelper {
  // Get auth token from SharedPreferences
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      developer.log('ApiHelper: Retrieved auth token: ${token != null ? 'Token exists' : 'No token found'}');
      return token;
    } catch (e) {
      developer.log('ApiHelper: Error getting auth token: $e');
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
      developer.log('ApiHelper: Added auth token to headers');
    } else {
      developer.log('ApiHelper: Warning - No auth token available');
    }
    
    return headers;
  }

  // GET request
  Future<http.Response> get(String url) async {
    try {
      final headers = await _getHeaders();
      developer.log('ApiHelper: GET request to $url');
      final response = await http.get(Uri.parse(url), headers: headers);
      developer.log('ApiHelper: Response status code: ${response.statusCode}');
      return response;
    } catch (e) {
      developer.log('ApiHelper: Error in GET request: $e');
      rethrow;
    }
  }

  // POST request with JSON body
  Future<http.Response> post(String url, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _getHeaders();
      developer.log('ApiHelper: POST request to $url');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );
      developer.log('ApiHelper: Response status code: ${response.statusCode}');
      return response;
    } catch (e) {
      developer.log('ApiHelper: Error in POST request: $e');
      rethrow;
    }
  }

  // PUT request with JSON body
  Future<http.Response> put(String url, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _getHeaders();
      developer.log('ApiHelper: PUT request to $url');
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );
      developer.log('ApiHelper: Response status code: ${response.statusCode}');
      return response;
    } catch (e) {
      developer.log('ApiHelper: Error in PUT request: $e');
      rethrow;
    }
  }

  // DELETE request
  Future<http.Response> delete(String url) async {
    try {
      final headers = await _getHeaders();
      developer.log('ApiHelper: DELETE request to $url');
      final response = await http.delete(Uri.parse(url), headers: headers);
      developer.log('ApiHelper: Response status code: ${response.statusCode}');
      return response;
    } catch (e) {
      developer.log('ApiHelper: Error in DELETE request: $e');
      rethrow;
    }
  }
} 