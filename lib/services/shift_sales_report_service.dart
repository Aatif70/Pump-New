import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/api_constants.dart';
import '../models/shift_sales_report.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShiftSalesReportService {
  Future<ShiftSalesReportResponse> fetchShiftSalesReport(
      DateTime startDate, DateTime endDate) async {
    try {
      final url = ApiConstants.getShiftSalesReportUrl(startDate, endDate);
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(ApiConstants.authTokenKey);

      if (authToken == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == ApiConstants.statusOk) {
        return ShiftSalesReportResponse.fromJson(
            json.decode(response.body) as Map<String, dynamic>);
      } else {
        throw Exception('Failed to load shift sales report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching shift sales report: $e');
    }
  }
} 