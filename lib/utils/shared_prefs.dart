import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import '../api/api_constants.dart';
import '../utils/jwt_decoder.dart';

class SharedPrefs {
  // Auth token
  static Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      return token;
    } catch (e) {
      developer.log('SharedPrefs: Error getting auth token: $e');
      return null;
    }
  }

  static Future<bool> setAuthToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(ApiConstants.authTokenKey, token);
    } catch (e) {
      developer.log('SharedPrefs: Error setting auth token: $e');
      return false;
    }
  }

  // Pump ID
  static Future<String?> getPumpId() async {
    try {
      print('DEBUG: SharedPrefs - Attempting to get pump ID');
      final prefs = await SharedPreferences.getInstance();
      final pumpId = prefs.getString('pump_id');
      print('DEBUG: SharedPrefs - Retrieved pump_id: $pumpId');
      
      // If pump_id is null, try alternative methods
      if (pumpId == null || pumpId.isEmpty) {
        print('DEBUG: SharedPrefs - pump_id is null or empty, trying petrolPumpId');
        final petrolPumpId = prefs.getString('petrolPumpId');
        print('DEBUG: SharedPrefs - Retrieved petrolPumpId: $petrolPumpId');
        
        if (petrolPumpId != null && petrolPumpId.isNotEmpty) {
          return petrolPumpId;
        }
        
        // Try extracting from token as a last resort
        print('DEBUG: SharedPrefs - Trying to extract from auth token');
        final token = prefs.getString(ApiConstants.authTokenKey);
        if (token != null) {
          try {
            final pumpIdFromToken = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
            print('DEBUG: SharedPrefs - Extracted from token: $pumpIdFromToken');
            return pumpIdFromToken;
          } catch (e) {
            print('DEBUG: SharedPrefs - Failed to extract from token: $e');
          }
        }
      }
      
      return pumpId;
    } catch (e) {
      developer.log('SharedPrefs: Error getting pump ID: $e');
      print('DEBUG: SharedPrefs - Error getting pump ID: $e');
      return null;
    }
  }

  static Future<bool> setPumpId(String pumpId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      print('DEBUG: SharedPrefs - Setting pump ID to: $pumpId');
      // Save to petrolPumpId instead of pump_id to match what's being used elsewhere
      return await prefs.setString('petrolPumpId', pumpId);
    } catch (e) {
      developer.log('SharedPrefs: Error setting pump ID: $e');
      return false;
    }
  }

  // User ID
  static Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      return userId;
    } catch (e) {
      developer.log('SharedPrefs: Error getting user ID: $e');
      return null;
    }
  }

  static Future<bool> setUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString('user_id', userId);
    } catch (e) {
      developer.log('SharedPrefs: Error setting user ID: $e');
      return false;
    }
  }

  // Clear all preferences (used during logout)
  static Future<bool> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.clear();
    } catch (e) {
      developer.log('SharedPrefs: Error clearing preferences: $e');
      return false;
    }
  }
} 