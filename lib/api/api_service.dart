import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_constants.dart';
import 'dart:developer' as developer;
import 'dart:async';

class ApiResponse<T> {
  bool success;
  T? data;
  String? errorMessage;

  ApiResponse({
    required this.success,
    this.data,
    this.errorMessage,
  });
}

class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Headers for API calls
  Map<String, String> getHeaders({String? token}) {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };

    // UNCOMMENT the below code to see the authorization token in the console
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
      developer.log('Added authorization token to request headers');
      // print('AUTHORIZATION HEADER: Bearer $token');
    }

    developer.log('Request headers: $headers');
    // print('FULL HEADERS: $headers');
    return headers;
  }

  // Generic GET method
  Future<ApiResponse<T>> get<T>(
    String url, {
    Map<String, String>? queryParams,
    String? token,
    required T Function(dynamic json) fromJson,
  }) async {
    developer.log('GET request to: $url');
    try {
      final Uri uri = queryParams != null
          ? Uri.parse(url).replace(queryParameters: queryParams)
          : Uri.parse(url);

      developer.log('Sending GET request to: $uri');
      final response = await http.get(
        uri,
        headers: getHeaders(token: token),
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        developer.log('GET request timed out: $uri');
        throw TimeoutException('The connection has timed out, please try again!');
      });

      print('RESPONSE STATUS CODE: ${response.statusCode}');
      print('RESPONSE URL: $uri');
      print('RESPONSE METHOD: GET');
      print('RESPONSE HEADERS: ${response.headers}');
      
      // if (response.body.isNotEmpty) {
      //   print('SUCCESS RESPONSE BODY: ${response.body}');
      // } else {
      //   print('RESPONSE BODY IS EMPTY');
      // }

      developer.log('GET response received from: $uri, status code: ${response.statusCode}');
      return _processResponse(response, fromJson);
    } on SocketException {
      developer.log('SocketException in GET request to: $url');
      return ApiResponse(
        success: false,
        errorMessage: ApiConstants.internetConnectionMsg,
      );
    } catch (e) {
      developer.log('Exception in GET request to: $url, error: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Generic POST method with exponential backoff retry
  Future<ApiResponse<T>> post<T>(
    String url, {
    dynamic body,
    String? token,
    required T Function(dynamic json) fromJson,
    int maxRetries = 2, // Default retry count
  }) async {
    developer.log('POST request to: $url with body: $body');
    
    int attempts = 0;
    Duration backoffDuration = const Duration(seconds: 1);
    
    while (attempts <= maxRetries) {
      try {
        if (attempts > 0) {
          developer.log('Retry attempt $attempts for POST request to: $url');
          // Wait with exponential backoff before retrying
          await Future.delayed(backoffDuration);
          // Double the backoff time for next retry
          backoffDuration *= 2;
        }
        
        final uri = Uri.parse(url);
        developer.log('Sending POST request to: $uri (attempt ${attempts + 1}/${maxRetries + 1})');
        
        final encodedBody = json.encode(body);
        developer.log('POST request encoded body: $encodedBody');
        print('API_SERVICE: POST request to: $uri');
        print('API_SERVICE: Request body: $encodedBody');
        print('API_SERVICE: Request headers: ${getHeaders(token: token)}');
        
        final response = await http.post(
          uri,
          headers: getHeaders(token: token),
          body: encodedBody,
        ).timeout(const Duration(seconds: 20), onTimeout: () {
          developer.log('POST request timed out: $uri');
          throw TimeoutException('The connection has timed out, please try again!');
        });

        developer.log('POST response received from: $uri, status: ${response.statusCode}, body length: ${response.body.length}');
        print('API_SERVICE: POST response status: ${response.statusCode}');
        print('API_SERVICE: POST response headers: ${response.headers}');
        
        if (response.body.isNotEmpty) {
          developer.log('POST response body preview: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}...');
          print('API_SERVICE: POST response body: ${response.body}');
        } else {
          developer.log('POST response body is empty');
          print('API_SERVICE: POST response body is empty');
        }
        
        // If server error (500) and not the last attempt, retry
        if (response.statusCode == ApiConstants.statusServerError && attempts < maxRetries) {
          developer.log('Server error (500) received, will retry. Attempt ${attempts + 1}/${maxRetries + 1}');
          attempts++;
          continue;
        }
        
        // Process the response
        return _processResponse(response, fromJson);
      } on SocketException {
        // Network error - retry if not the last attempt
        if (attempts < maxRetries) {
          developer.log('SocketException in POST request, will retry. Attempt ${attempts + 1}/${maxRetries + 1}');
          attempts++;
          continue;
        }
        developer.log('SocketException in POST request to: $url (final attempt)');
        return ApiResponse(
          success: false,
          errorMessage: ApiConstants.internetConnectionMsg,
        );
      } on TimeoutException {
        // Timeout - retry if not the last attempt
        if (attempts < maxRetries) {
          developer.log('TimeoutException in POST request, will retry. Attempt ${attempts + 1}/${maxRetries + 1}');
          attempts++;
          continue;
        }
        developer.log('TimeoutException in POST request to: $url (final attempt)');
        return ApiResponse(
          success: false,
          errorMessage: 'Request timed out after multiple attempts. Please check your internet connection and try again.',
        );
      } catch (e) {
        // Other errors - retry if not the last attempt
        if (attempts < maxRetries) {
          developer.log('Exception in POST request, will retry. Attempt ${attempts + 1}/${maxRetries + 1}: $e');
          attempts++;
          continue;
        }
        developer.log('Exception in POST request to: $url (final attempt), error: $e');
        return ApiResponse(
          success: false,
          errorMessage: e.toString(),
        );
      }
    }
    
    // This should not be reached due to the return statements above,
    // but added for code completeness
    return ApiResponse(
      success: false,
      errorMessage: 'Failed after maximum retry attempts.',
    );
  }

  // Generic PUT method
  Future<ApiResponse<T>> put<T>(
    String url, {
    dynamic body,
    String? token,
    required T Function(dynamic json) fromJson,
  }) async {
    developer.log('PUT request to: $url');
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: getHeaders(token: token),
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        developer.log('PUT request timed out: $url');
        throw TimeoutException('The connection has timed out, please try again!');
      });

      developer.log('PUT response received from: $url, status: ${response.statusCode}');
      return _processResponse(response, fromJson);
    } on SocketException {
      developer.log('SocketException in PUT request to: $url');
      return ApiResponse(
        success: false,
        errorMessage: ApiConstants.internetConnectionMsg,
      );
    } catch (e) {
      developer.log('Exception in PUT request to: $url, error: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Generic DELETE method
  Future<ApiResponse<T>> delete<T>(
    String url, {
    String? token,
    required T Function(dynamic json) fromJson,
  }) async {
    print('API_SERVICE: DELETE request to: $url');
    try {
      print('API_SERVICE: Preparing DELETE request with auth token: ${token != null ? 'present' : 'missing'}');
      final response = await http.delete(
        Uri.parse(url),
        headers: getHeaders(token: token),
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        print('API_SERVICE: DELETE request timed out: $url');
        throw TimeoutException('The connection has timed out, please try again!');
      });

      // Check 
      print('API_SERVICE: DELETE response received from: $url, status: ${response.statusCode}');
      print('API_SERVICE: DELETE response headers: ${response.headers}');
      if (response.body.isNotEmpty) {
        print('API_SERVICE: DELETE response body: ${response.body}');
      } else {
        print('API_SERVICE: DELETE response body is empty (expected for 204)');
      }
      
      return _processResponse(response, fromJson);
    } on SocketException {
      print('API_SERVICE: SocketException in DELETE request to: $url');
      return ApiResponse(
        success: false,
        errorMessage: ApiConstants.internetConnectionMsg,
      );
    } catch (e) {
      print('API_SERVICE: Exception in DELETE request to: $url, error: $e');
      return ApiResponse(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Process HTTP response and convert to ApiResponse
  ApiResponse<T> _processResponse<T>(http.Response response, T Function(dynamic json) fromJson) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        if (response.body.isEmpty) {
          developer.log('Empty body in successful response');
          return ApiResponse(
            success: true,
          );
        }
        
        final jsonDecoded = json.decode(response.body);
        dynamic jsonData = jsonDecoded;
        
        // Check if the response has a data field (common pattern)
        if (jsonDecoded is Map && jsonDecoded.containsKey('data')) {
          print('API_SERVICE: Found data field in response, extracting...');
          jsonData = jsonDecoded['data'];
          if (jsonData == null) {
            print('API_SERVICE: Warning - data field is null');
          }
        }
        
        // Check for direct list
        if (jsonData is List) {
          developer.log('Found direct list with ${jsonData.length} items');
          print('FOUND ${jsonData.length} ITEMS IN DIRECT LIST');
        }
        
        try {
          // print('API_SERVICE: Passing to fromJson for parsing: $jsonData');
          final data = fromJson(jsonData);
          developer.log('Response transformed using fromJson function');
          
          return ApiResponse(
            success: true,
            data: data,
          );
        } catch (e, stack) {
          // If type casting fails but we have a success response,
          // return success with the original data
          if (e.toString().contains('type \'String\' is not a subtype of type \'Map<String, dynamic>\'') ||
              e.toString().contains('type cast')) {
            print('API_SERVICE: Type casting issue in fromJson, using original success response');
            
            // For string data, try to adapt it to the expected type
            if (jsonData is String) {
              // If T is a String type, we can cast directly
              if (T.toString() == 'String' || T.toString() == 'dynamic') {
                return ApiResponse(
                  success: true,
                  data: jsonData as T,
                );
              }
              
              // Otherwise, use an empty placeholder
              try {
                return ApiResponse(
                  success: true,
                  // Try to create an empty instance of the expected type
                  data: {} as T,
                );
              } catch (castError) {
                // If that fails too, return success with null data
                print('API_SERVICE: Could not cast to expected type: $castError');
                return ApiResponse(
                  success: true,
                  // No data, but still successful
                );
              }
            }
          }
          
          // For other exceptions, rethrow to be caught by the outer catch
          throw e;
        }
      } catch (e, stack) {
        developer.log('Error processing successful response: $e');
        print('ERROR PROCESSING RESPONSE: $e');
        print('STACK TRACE: $stack');
        return ApiResponse(
          success: false,
          errorMessage: 'Error processing response: $e',
        );
      }
    } else if (response.statusCode == ApiConstants.statusNoContent) {
      // 204 No Content - successful response with no body (common for DELETE)
      print('API_SERVICE: No Content response (204) - Successful deletion');
      print('API_SERVICE: Request URL: ${response.request?.url}');
      print('API_SERVICE: Request method: ${response.request?.method}');
      
      try {
        // Create a default successful response without attempting to parse JSON
        // Pass an empty object to the fromJson function
        print('API_SERVICE: Creating success response for 204 No Content');
        T data;
        try {
          data = fromJson({});
          print('API_SERVICE: Successfully created data object from empty JSON');
        } catch (e) {
          // If fromJson can't handle empty object, try using null or dynamic workaround
          // This is a workaround for generic type constraints
          print('API_SERVICE: Using fallback for 204 response data creation: $e');
          data = {} as T;
        }
        
        return ApiResponse(
          success: true,
          data: data,
        );
      } catch (e) {
        print('API_SERVICE: Error handling 204 response: $e');
        // Still return success even if data mapping fails
        return ApiResponse(
          success: true,
        );
      }
    } else if (response.statusCode == ApiConstants.statusUnauthorized) {
      // Unauthorized
      developer.log('Unauthorized response (401)');
      print('UNAUTHORIZED (401) - RESPONSE BODY: ${response.body}');
      return ApiResponse(
        success: false,
        errorMessage: ApiConstants.unAuthorized,
      );
    } else if (response.statusCode == 405) {
      // Method Not Allowed (405)
      print('METHOD NOT ALLOWED (405) ERROR');
      print('REQUESTED URL: ${response.request?.url}');
      print('USED METHOD: ${response.request?.method}');
      print('ALLOWED METHODS: ${response.headers['allow'] ?? 'Not specified'}');
      
      // Detailed error message with suggestion
      return ApiResponse(
        success: false,
        errorMessage: 'The API does not support this operation (Method Not Allowed). The endpoint might require a different HTTP method.',
      );
    } else {
      // Other errors
      try {
        developer.log('Error response with status: ${response.statusCode}, body: ${response.body}');
        print('ERROR RESPONSE CODE: ${response.statusCode}');
        print('ERROR RESPONSE BODY: ${response.body}');
        print('ERROR REQUEST METHOD: ${response.request?.method}');
        print('ERROR REQUEST URL: ${response.request?.url}');
        
        if (response.statusCode == ApiConstants.statusServerError) {
          developer.log('SERVER ERROR 500 DETAILS: Body: ${response.body}, Headers: ${response.headers}');
          print('SERVER ERROR 500 DETAILS: Request URL: ${response.request?.url}');
          print('SERVER ERROR 500 DETAILS: Request method: ${response.request?.method}');
          print('SERVER ERROR 500 DETAILS: Request headers: ${response.request?.headers}');
          
          // Attempt to parse the error response if available
          String detailedError = 'Server error occurred.';
          try {
            if (response.body.isNotEmpty) {
              final errorData = json.decode(response.body);
              if (errorData is Map && errorData.containsKey('message')) {
                detailedError = 'Server error: ${errorData['message']}';
              } else if (errorData is Map && errorData.containsKey('error')) {
                detailedError = 'Server error: ${errorData['error']}';
              }
            }
          } catch (e) {
            // Fallback to generic message if error response cannot be parsed
            detailedError = 'Server error: The server encountered a problem processing your request.';
          }
          
          // Return specific message for server errors
          return ApiResponse(
            success: false,
            errorMessage: '$detailedError Please try again later or contact support.',
          );
        }
        
        if (response.body.isEmpty) {
          developer.log('Error response body is empty');
          print('ERROR RESPONSE BODY IS EMPTY');
          return ApiResponse(
            success: false,
            errorMessage: 'Server returned empty response with status code ${response.statusCode}',
          );
        }
        
        final jsonData = json.decode(response.body);
        developer.log('Error response decoded: $jsonData');
        print('ERROR RESPONSE DECODED: $jsonData');
        
        final errorMessage = jsonData[ApiConstants.errorMessageKey] ?? ApiConstants.someThingWentWrong;
        developer.log('Error message from response: $errorMessage');
        print('ERROR MESSAGE FROM RESPONSE: $errorMessage');
        
        return ApiResponse(
          success: false,
          errorMessage: errorMessage.toString(),
        );
      } catch (e) {
        developer.log('Error processing error response: $e');
        print('ERROR PROCESSING ERROR RESPONSE: $e');
        return ApiResponse(
          success: false,
          errorMessage: 'Status code: ${response.statusCode}, Message: ${response.reasonPhrase}',
        );
      }
    }
  }
} 