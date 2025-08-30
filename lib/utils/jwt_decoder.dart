import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

class JwtDecoder {
  /// Decode a JWT token and return the payload (claims) as a Map
  static Map<String, dynamic>? decode(String token) {
    try {
      // Split the token into parts
      final parts = token.split('.');
      if (parts.length != 3) {
        developer.log('Invalid JWT token format');
        return null;
      }

      // Take the middle part (payload)
      final payload = parts[1];
      
      // Normalize the base64 string
      final normalized = base64Normalize(payload);
      
      // Decode the base64 string
      final decoded = utf8.decode(base64Decode(normalized));
      
      // Parse the JSON
      final Map<String, dynamic> claims = json.decode(decoded);
      developer.log('JWT claims decoded successfully: $claims');
      
      // Log all available claims for debugging
      developer.log('Available JWT claims:');
      claims.forEach((key, value) {
        developer.log('  $key: $value');
      });
      
      // Extract employee ID if present (important for shift assignments)
      if (claims.containsKey('employeeId')) {
        developer.log('JWT contains employeeId: ${claims['employeeId']}');
        // Store it for later access
        storeEmployeeId(claims['employeeId'].toString());
      } else {
        developer.log('JWT does not contain employeeId claim');
      }
      
      // Extract user role
      String? userRole;
      // Check common role claim keys
      for (var roleClaim in ['role', 'roles', 'http://schemas.microsoft.com/ws/2008/06/identity/claims/role', 'userRole']) {
        if (claims.containsKey(roleClaim)) {
          // Handle both string and array formats
          if (claims[roleClaim] is String) {
            userRole = claims[roleClaim];
          } else if (claims[roleClaim] is List) {
            // If it's a list, get the first role
            if ((claims[roleClaim] as List).isNotEmpty) {
              userRole = (claims[roleClaim] as List).first.toString();
            }
          }
          developer.log("JwtDecoder: Extracted userRole from claim '$roleClaim': $userRole");
          break;
        }
      }

      // You can use this role information for authorization checks
      if (userRole != null) {
        developer.log("JwtDecoder: User has role: $userRole");
        // Example: Check if user is admin or manager
        final bool isAdminOrManager = userRole.toLowerCase() == 'admin' || 
                                     userRole.toLowerCase() == 'manager';
        
        // Store the role but don't await here
        storeUserRole(userRole);
      }
      
      return claims;
    } catch (e) {
      developer.log('Error decoding JWT token: $e');
      return null;
    }
  }

  /// Store user role in SharedPreferences
  static Future<void> storeUserRole(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', role);
      developer.log('User role stored in SharedPreferences: $role');
    } catch (e) {
      developer.log('Error storing user role: $e');
    }
  }
  
  /// Store employee ID in SharedPreferences
  static Future<void> storeEmployeeId(String employeeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('employeeId', employeeId);
      developer.log('EmployeeId stored in SharedPreferences: $employeeId');
    } catch (e) {
      developer.log('Error storing employeeId: $e');
    }
  }

  /// Get a specific claim from a JWT token
  static T? getClaim<T>(String token, String claimName) {
    final claims = decode(token);
    if (claims == null) return null;
    
    if (claims.containsKey(claimName)) {
      developer.log('Found claim $claimName with value: ${claims[claimName]}');
      return claims[claimName] as T?;
    } else {
      // Check case-insensitive or common variations
      final alternatives = [
        claimName.toLowerCase(),
        claimName.toUpperCase(),
        claimName.replaceAll('Id', 'ID'),
        'pump_id',
        'pumpId',
        'pump_ID',
        'petrolPump_id',
        // Add common variations for employeeId
        'employee_id',
        'employeeID',
        'empId',
        'staffId',
      ];
      
      for (final alt in alternatives) {
        if (claims.containsKey(alt)) {
          developer.log('Found alternative claim $alt with value: ${claims[alt]}');
          return claims[alt] as T?;
        }
      }
      
      developer.log('Claim $claimName not found in token');
      return null;
    }
  }

  /// Fix the base64 string to make it decodable
  static String base64Normalize(String input) {
    // Add padding if needed
    final modulus = input.length % 4;
    if (modulus > 0) {
      input = input.padRight(input.length + (4 - modulus), '=');
    }
    
    // Replace URL-safe characters
    input = input.replaceAll('-', '+').replaceAll('_', '/');
    
    return input;
  }
} 