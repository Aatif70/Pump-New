import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';
import '../models/api_response.dart';
import '../models/meter_reading_model.dart';

class MeterReadingRepository {
  final String baseUrl = ApiConstants.baseUrl;

  // Get meter readings for a specific nozzle and shift
  Future<ApiResponse<List<MeterReading>>> getMeterReadings(String nozzleId, String shiftId) async {
    try {
      final url = Uri.parse('$baseUrl/meter-readings?nozzle_id=$nozzleId&shift_id=$shiftId');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> readingsJson = data['data'] ?? [];
        final List<MeterReading> readings = readingsJson
            .map((json) => MeterReading.fromJson(json))
            .toList();
        
        return ApiResponse<List<MeterReading>>(
          success: true,
          data: readings,
        );
      } else {
        return ApiResponse<List<MeterReading>>(
          success: false,
          errorMessage: 'Failed to load meter readings',
        );
      }
    } catch (e) {
      print('Error in getMeterReadings: $e');
      return ApiResponse<List<MeterReading>>(
        success: false,
        errorMessage: 'An error occurred: $e',
      );
    }
  }

  // Submit a new meter reading
  Future<ApiResponse<MeterReading>> submitMeterReading(MeterReading reading) async {
    try {
      final url = Uri.parse('$baseUrl/meter-readings');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(reading.toJson()),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final newReading = MeterReading.fromJson(data['data']);
        
        return ApiResponse<MeterReading>(
          success: true,
          data: newReading,
        );
      } else {
        return ApiResponse<MeterReading>(
          success: false,
          errorMessage: 'Failed to submit meter reading',
        );
      }
    } catch (e) {
      return ApiResponse<MeterReading>(
        success: false,
        errorMessage: 'An error occurred: $e',
      );
    }
  }
} 