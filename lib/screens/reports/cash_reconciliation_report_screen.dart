import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:petrol_pump/utils/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../../api/api_constants.dart';
import '../../models/cash_reconciliation_model.dart';
import '../../theme.dart';
import '../../widgets/loading_indicator.dart';

class CashReconciliationReportScreen extends StatefulWidget {
  const CashReconciliationReportScreen({super.key});

  @override
  State<CashReconciliationReportScreen> createState() => _CashReconciliationReportScreenState();
}

class _CashReconciliationReportScreenState extends State<CashReconciliationReportScreen> {
  bool isLoading = true;
  bool hasError = false;
  bool _generatingPdf = false;
  String errorMessage = '';
  
  DateTime selectedDate = DateTime.now();
  List<Shift> shifts = [];
  Shift? selectedShift;
  
  CashReconciliationResponse? cashReconciliationData;
  String petrolPumpId = '';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _getPetrolPumpId();
    
    if (petrolPumpId.isNotEmpty) {
      // First fetch available shifts
      await _fetchShifts();
      
      // Only fetch data if shifts were successfully loaded
      if (shifts.isNotEmpty && selectedShift != null) {
        print('Initializing with shift filter. Selected shift ID: ${selectedShift!.id}');
        await _fetchCashReconciliationData(useShiftFilter: true);
      } else {
        print('No shifts available or selected. Showing error state.');
        setState(() {
          isLoading = false;
          if (shifts.isEmpty) {
            hasError = true;
            errorMessage = 'No shifts available for this date. Please select a different date.';
          }
        });
      }
    }
  }

  Future<void> _getPetrolPumpId() async {
    try {
      // First try to get the token
      final token = await ApiConstants.getAuthToken();
      
      if (token != null) {
        // Use JwtDecoder to get petrolPumpId from token
        final petrolPumpIdFromToken = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
        
        if (petrolPumpIdFromToken != null && petrolPumpIdFromToken.isNotEmpty) {
          setState(() {
            petrolPumpId = petrolPumpIdFromToken;
            print('PetrolPumpId from token: $petrolPumpId');
          });
          return;
        }
      }
      
      // If token approach fails, try getting from SharedPreferences directly
      final prefs = await SharedPreferences.getInstance();
      
      // Try from pump_id key
      String? pumpId = prefs.getString('pump_id');
      if (pumpId != null && pumpId.isNotEmpty) {
        setState(() {
          petrolPumpId = pumpId;
          print('PetrolPumpId from pump_id preference: $petrolPumpId');
        });
        return;
      }
      
      // As a last resort, try from user_data
      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        final userData = json.decode(userDataString);
        final pumpIdFromUserData = userData['petrolPumpId'];
        if (pumpIdFromUserData != null && pumpIdFromUserData.isNotEmpty) {
          setState(() {
            petrolPumpId = pumpIdFromUserData;
            print('PetrolPumpId from user_data: $petrolPumpId');
          });
          return;
        }
      }
      
      // If we get here, no petrolPumpId was found
      throw Exception('PetrolPumpId not found in any storage location');
      
    } catch (e) {
      print('Error fetching petrolPumpId: $e');
      setState(() {
        hasError = true;
        errorMessage = 'Failed to fetch petrol pump ID. Please log in again.';
        print('Error details: $e');
      });
    }
  }

  Future<void> _fetchShifts() async {
    if (petrolPumpId.isEmpty) {
      setState(() {
        hasError = true;
        errorMessage = 'Petrol pump ID not found. Please log in again.';
        print('petrol pump id : $petrolPumpId');
      });
      return;
    }

    try {
      // Using the new API endpoint format: GET {{baseUrl}}/api/Shift/{petrolPumpId}/shifts
      final url = '${ApiConstants.baseUrl}/api/Shift/$petrolPumpId/shifts';
      final token = await ApiConstants.getAuthToken();

      if (token == null) {
        throw Exception('Authentication token not found');
      }
      
      print('Fetching shifts from URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print('Shifts API response: ${response.body}');
        
                  if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          // Debug the raw shifts data
          print('Raw shifts data: ${jsonResponse['data']}');
            
          final shiftsList = (jsonResponse['data'] as List)
              .map((item) => Shift.fromJson(item))
              .toList();
              
          // Print the parsed shifts for debugging
          for (var shift in shiftsList) {
            print('Parsed shift: id=${shift.id}, number=${shift.shiftNumber}, startTime=${shift.startTime}, endTime=${shift.endTime}');
          }
          
          setState(() {
            shifts = shiftsList;
            // Set default to shift number 1 if available, or first shift if no shift with number 1
            if (shifts.isNotEmpty) {
              try {
                selectedShift = shifts.firstWhere(
                  (shift) => shift.shiftNumber == 1,
                );
                // Debug the selected shift
                print('Selected shift: id=${selectedShift?.id}, number=${selectedShift?.shiftNumber}');
              } catch (e) {
                // If no shift with number 1, use the first shift
                selectedShift = shifts.first;
                print('Selected first shift: id=${selectedShift?.id}, number=${selectedShift?.shiftNumber}');
              }
            } else {
              print('No shifts available for selection');
              // Don't set selectedShift to null, keep it undefined if no shifts
              // selectedShift = null;
            }
          });
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to load shifts');
        }
      } else {
        print('Failed to fetch shifts: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load shifts. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching shifts: $e');
      setState(() {
        hasError = true;
        errorMessage = 'Failed to fetch shifts. Please try again.';
      });
    }
  }

  Future<void> _fetchCashReconciliationData({bool useShiftFilter = true}) async {
    if (petrolPumpId.isEmpty) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Petrol pump ID not found. Please log in again.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      // Format the date in the required format (yyyy-MM-dd)
      final formattedDate = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
      
      // Build the URL using the new API format
      String url = '${ApiConstants.baseUrl}/api/Reporting/cash-reconciliation?date=$formattedDate';
      
      // Only include shiftId if we're using shift filter and shift is selected with a valid ID
      if (useShiftFilter && selectedShift != null && selectedShift!.id.isNotEmpty) {
        url += '&shiftId=${selectedShift!.id}';
        print('Using shift filter with ID: ${selectedShift!.id}');
      } else {
        print('Not using shift filter or no valid shift ID available');
      }
      
      final token = await ApiConstants.getAuthToken();
      
      if (token == null) {
        throw Exception('Authentication token not found');
      }
      
      // Print the URL for debugging
      print('Fetching cash reconciliation data from URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print('Cash Reconciliation API Response: ${response.body}');
        
        if (jsonResponse['success'] == true) {
          // Log the data for debugging
          print('SUCCESS: ${jsonResponse['success']}');
          print('RECEIVED RAW DATA: ${jsonResponse['data']}');
          
          setState(() {
            cashReconciliationData = CashReconciliationResponse.fromJson(jsonResponse);
            isLoading = false;
          });
          
          // Debug logging to check the parsed data
          print("DATA RECEIVED: ${jsonResponse['data']}");
          print("PARSED DAILY SUMMARY: ${cashReconciliationData!.data.dailySummary.totalOpeningCash}");
          print("SHIFT RECONCILIATIONS COUNT: ${cashReconciliationData!.data.shiftReconciliations.length}");
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to load reconciliation data');
        }
      } else {
        print('ERROR RESPONSE: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load reconciliation data. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching reconciliation data: $e');
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Failed to fetch reconciliation data. Please try again.';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      
      // When date changes, we fetch new data
      await _fetchCashReconciliationData(useShiftFilter: selectedShift != null);
      
      // We might also need to fetch new shifts for this date
      // (only if shifts are date-specific, otherwise remove this line)
      await _fetchShifts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Cash Reconciliation Reports',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh data',
            onPressed: isLoading 
              ? null 
              : () {
                // Refresh both shifts and data
                _fetchShifts().then((_) {
                  _fetchCashReconciliationData(useShiftFilter: selectedShift != null);
                });
              },
          ),
          if (cashReconciliationData != null && !isLoading)
            _generatingPdf 
              ? Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  width: 24,
                  height: 24,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.0,
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'Export to PDF',
                  onPressed: () => _exportToPdf(context),
                ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with filters
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 25,
                top: 5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 15,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      color: AppTheme.primaryBlue,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('MMM dd, yyyy').format(selectedDate),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Shift?>(
                                  isExpanded: true,
                                  value: selectedShift,
                                  hint: const Text('Select Shift'),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: AppTheme.primaryBlue,
                                  ),
                                  items: shifts.map((Shift shift) {
                                    return DropdownMenuItem<Shift?>(
                                      value: shift,
                                      child: Text('Shift ${shift.shiftNumber}'),
                                    );
                                  }).toList(),
                                  onChanged: (Shift? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        selectedShift = newValue;
                                      });
                                      
                                      // Debug the selected shift
                                      print('User selected shift: id=${newValue.id}, number=${newValue.shiftNumber}');
                                      if (newValue.id.isEmpty) {
                                        print('WARNING: Selected shift has empty ID!');
                                      }
                                      print('Requesting data with shift filter');
                                      _fetchCashReconciliationData(useShiftFilter: true);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (shifts.isEmpty && !isLoading) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'No shifts available for this date',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.amber,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Body content
            Expanded(
              child: _buildReportContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent() {
    if (isLoading) {
      return const Center(child: LoadingIndicator());
    }
    
    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
                          Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      // Show loading indicator during retry
                      setState(() {
                        isLoading = true;
                        hasError = false;
                      });
                      
                      // First try to fetch shifts
                      await _fetchShifts();
                      
                      // Then try to fetch reconciliation data
                      await _fetchCashReconciliationData(useShiftFilter: selectedShift != null);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
          ],
        ),
      );
    }
    
    if (cashReconciliationData == null) {
      return const Center(
        child: Text(
          'No reconciliation data available',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report header information
          _buildReportHeaderInfo(),
          const SizedBox(height: 20),
          _buildDailySummaryCard(),
          const SizedBox(height: 20),
          _buildShiftReconciliationsSection(),
        ],
      ),
    );
  }

  Widget _buildReportHeaderInfo() {
    final data = cashReconciliationData!.data;
    final startDate = DateFormat('MMM dd, yyyy').format(data.reportPeriodStart);
    final endDate = DateFormat('MMM dd, yyyy').format(data.reportPeriodEnd);
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_gas_station,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  data.petrolPumpName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.calendar_month,
                    label: 'Report Period',
                    value: startDate == endDate ? startDate : '$startDate - $endDate',
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.person,
                    label: 'Generated By',
                    value: data.generatedBy,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.access_time,
                    label: 'Generated At',
                    value: DateFormat('MMM dd, yyyy HH:mm').format(data.generatedAt.toLocal()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummaryCard() {
    final dailySummary = cashReconciliationData!.data.dailySummary;
    final formatter = NumberFormat('#,##0.00', 'en_US');
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: dailySummary.totalCashVariance == 0
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Accuracy: ${dailySummary.accuracyPercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: dailySummary.totalCashVariance == 0
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Cash Flow Section
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cash Flow',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryItem(
                              label: 'Opening Cash',
                              value: formatter.format(dailySummary.totalOpeningCash),
                              icon: Icons.login,
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryItem(
                              label: 'Cash Sales',
                              value: formatter.format(dailySummary.totalCashSales),
                              icon: Icons.point_of_sale,
                              valueColor: Colors.green.shade700,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryItem(
                              label: 'Cash Expenses',
                              value: formatter.format(dailySummary.totalCashExpenses),
                              icon: Icons.money_off,
                              valueColor: dailySummary.totalCashExpenses > 0 
                                  ? Colors.orange.shade700 
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryItem(
                              label: 'Cash Deposited',
                              value: formatter.format(dailySummary.totalCashDeposited),
                              icon: Icons.savings,
                              valueColor: dailySummary.totalCashDeposited > 0 
                                  ? Colors.blue.shade700 
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Expected vs Actual Section
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reconciliation',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryBox(
                          label: 'Expected Closing',
                          value: formatter.format(dailySummary.totalExpectedCash),
                          color: Colors.blue.shade50,
                          textColor: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryBox(
                          label: 'Actual Closing',
                          value: formatter.format(dailySummary.totalActualCash),
                          color: Colors.purple.shade50,
                          textColor: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // Variance
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dailySummary.totalCashVariance == 0
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: dailySummary.totalCashVariance == 0
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              dailySummary.totalCashVariance == 0
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: dailySummary.totalCashVariance == 0
                                  ? Colors.green
                                  : Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Cash Variance',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: dailySummary.totalCashVariance == 0
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          formatter.format(dailySummary.totalCashVariance),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: dailySummary.totalCashVariance == 0
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Stats section
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatBox(
                      value: dailySummary.totalShifts.toString(),
                      label: 'Total Shifts',
                      icon: Icons.access_time_filled,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(horizontal: 15),
                  ),
                  Expanded(
                    child: _buildStatBox(
                      value: dailySummary.shiftsWithVariance.toString(),
                      label: 'Shifts with Variance',
                      icon: Icons.warning_amber,
                      color: dailySummary.shiftsWithVariance > 0
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryBlue,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBox({
    required String label,
    required String value,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShiftReconciliationsSection() {
    final shiftReconciliations = cashReconciliationData!.data.shiftReconciliations;
    
    if (shiftReconciliations.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'No shift reconciliation data available',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Shift Reconciliations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${shiftReconciliations.length} Shifts',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...shiftReconciliations.map((shift) {
          return _buildShiftReconciliationCard(shift);
        }).toList(),
      ],
    );
  }

  Widget _buildShiftReconciliationCard(ShiftReconciliation shift) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    final bool hasVariance = shift.cashVariance != 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasVariance ? Colors.red.withOpacity(0.3) : Colors.transparent,
          width: hasVariance ? 1 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Shift Number & Time
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${shift.shiftNumber}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shift ${shift.shiftNumber}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 12,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${shift.startTime} - ${shift.endTime}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: shift.reconciliationStatus == 'Balanced'
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: shift.reconciliationStatus == 'Balanced'
                          ? Colors.green.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    shift.reconciliationStatus,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: shift.reconciliationStatus == 'Balanced'
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            
            // Cashier if available
            if (shift.cashierName.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Cashier: ${shift.cashierName}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            
            // Cash flow grid
            Row(
              children: [
                // Left column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShiftDetailItem(
                        label: 'Opening Cash',
                        value: formatter.format(shift.openingCash),
                        icon: Icons.login,
                      ),
                      const SizedBox(height: 12),
                      _buildShiftDetailItem(
                        label: 'Cash Sales',
                        value: formatter.format(shift.cashSales),
                        icon: Icons.point_of_sale,
                        valueColor: shift.cashSales > 0 ? Colors.green.shade700 : null,
                      ),
                      const SizedBox(height: 12),
                      _buildShiftDetailItem(
                        label: 'Cash Expenses',
                        value: formatter.format(shift.cashExpenses),
                        icon: Icons.money_off,
                        valueColor: shift.cashExpenses > 0 ? Colors.orange.shade700 : null,
                      ),
                    ],
                  ),
                ),
                // Right column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShiftDetailItem(
                        label: 'Expected Closing',
                        value: formatter.format(shift.expectedClosingCash),
                        icon: Icons.account_balance_wallet,
                        isBold: true,
                      ),
                      const SizedBox(height: 12),
                      _buildShiftDetailItem(
                        label: 'Actual Closing',
                        value: formatter.format(shift.actualClosingCash),
                        icon: Icons.paid,
                        isBold: true,
                      ),
                      const SizedBox(height: 12),
                      _buildShiftDetailItem(
                        label: 'Cash Deposited',
                        value: formatter.format(shift.cashDeposited),
                        icon: Icons.savings,
                        valueColor: shift.cashDeposited > 0 ? Colors.blue.shade700 : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Variance
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasVariance ? Colors.red.withOpacity(0.05) : Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasVariance ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        hasVariance ? Icons.warning_amber : Icons.check_circle,
                        color: hasVariance ? Colors.red : Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Variance',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: hasVariance ? Colors.red.shade700 : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    formatter.format(shift.cashVariance),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasVariance ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            
            // Remarks if any
            if (shift.remarks.isNotEmpty && shift.remarks != "No variance") ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.comment,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Remarks',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      shift.remarks,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShiftDetailItem({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryBlue,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // PDF Export functionality
  Future<void> _exportToPdf(BuildContext context) async {
    if (cashReconciliationData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report data available to export')),
      );
      return;
    }
    
    setState(() {
      _generatingPdf = true;
    });
    
    // Show a notification that PDF generation has started
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF report...'),
          duration: Duration(seconds: 1),
        ),
      );
    }
    
    try {
      final pdfBytes = await _generatePdf();
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'cash_reconciliation_report_${DateFormat('yyyyMMdd').format(selectedDate)}.pdf';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsBytes(pdfBytes);
      
      // Show a dialog with options to view or share
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('PDF Generated'),
            content: const Text('Report has been generated successfully. What would you like to do with it?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _viewPdf(pdfBytes);
                },
                child: const Text('View'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _sharePdf(file);
                },
                child: const Text('Share'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generatingPdf = false;
        });
      }
    }
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    final report = cashReconciliationData!.data;
    final dailySummary = report.dailySummary;
    final shiftReconciliations = report.shiftReconciliations;
    final formatter = NumberFormat('#,##0.00', 'en_US');
    
    // Define colors
    final PdfColor headerColor = PdfColor.fromHex('#0066cc'); // AppTheme.primaryBlue equivalent
    final PdfColor greenColor = PdfColor.fromHex('#4CAF50');
    final PdfColor redColor = PdfColor.fromHex('#F44336');
    final PdfColor borderColor = PdfColor.fromHex('#EEEEEE');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        report.petrolPumpName,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: headerColor,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Cash Reconciliation Report',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: borderColor),
                    ),
                    child: pw.Text(
                      DateFormat('dd MMM yyyy').format(selectedDate),
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Divider(color: headerColor),
              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5))
            ),
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated on ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())} by ${report.generatedBy}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          // Report Overview
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: borderColor),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Report Overview',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: headerColor,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfInfoRow('Date', DateFormat('dd MMM yyyy').format(selectedDate)),
                          _buildPdfInfoRow('Total Shifts', '${dailySummary.totalShifts}'),
                          _buildPdfInfoRow('Report Period', '${DateFormat('dd MMM yyyy').format(report.reportPeriodStart)} - ${DateFormat('dd MMM yyyy').format(report.reportPeriodEnd)}'),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfInfoRow('Accuracy', '${dailySummary.accuracyPercentage.toStringAsFixed(1)}%'),
                          _buildPdfInfoRow('Shifts with Variance', '${dailySummary.shiftsWithVariance}'),
                          _buildPdfInfoRow('Generated At', DateFormat('dd MMM yyyy, HH:mm').format(report.generatedAt.toLocal())),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Daily Summary Section
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderColor),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: headerColor,
                    borderRadius: pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(8),
                      topRight: pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text(
                        'Daily Summary',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Spacer(),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: dailySummary.totalCashVariance == 0
                              ? greenColor
                              : redColor,
                          borderRadius: pw.BorderRadius.circular(12),
                        ),
                        child: pw.Text(
                          'Accuracy: ${dailySummary.accuracyPercentage.toStringAsFixed(1)}%',
                          style:  pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  child: pw.Column(
                    children: [
                      // Cash Flow Section
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey50,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Cash Flow',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 14,
                                color: headerColor,
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            pw.Row(
                              children: [
                                pw.Expanded(
                                  child: pw.Column(
                                    children: [
                                      _buildPdfSummaryRow('Opening Cash', formatter.format(dailySummary.totalOpeningCash)),
                                      _buildPdfSummaryRow('Cash Sales', formatter.format(dailySummary.totalCashSales)),
                                      _buildPdfSummaryRow('Cash Expenses', formatter.format(dailySummary.totalCashExpenses)),
                                    ],
                                  ),
                                ),
                                pw.SizedBox(width: 20),
                                pw.Expanded(
                                  child: pw.Column(
                                    children: [
                                      _buildPdfSummaryRow('Expected Closing', formatter.format(dailySummary.totalExpectedCash), isBold: true),
                                      _buildPdfSummaryRow('Actual Closing', formatter.format(dailySummary.totalActualCash), isBold: true),
                                      _buildPdfSummaryRow('Cash Deposited', formatter.format(dailySummary.totalCashDeposited)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      pw.SizedBox(height: 16),
                      
                      // Variance Section - Minimal Design
                      pw.Divider(color: PdfColors.grey300),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 8),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Cash Variance',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 14,
                                color: dailySummary.totalCashVariance != 0 
                                    ? redColor 
                                    : PdfColors.grey800,
                              ),
                            ),
                            pw.Text(
                              formatter.format(dailySummary.totalCashVariance),
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 14,
                                color: dailySummary.totalCashVariance != 0 
                                    ? redColor 
                                    : PdfColors.grey800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Shift Reconciliations Section
          if (shiftReconciliations.isNotEmpty) ...[
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderColor),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: headerColor,
                      borderRadius: pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(8),
                        topRight: pw.Radius.circular(8),
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Text(
                          'Shift Reconciliations',
                          style:  pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Spacer(),
                        pw.Text(
                          'Total: ${shiftReconciliations.length}',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Shift list
                  ...List<pw.Widget>.generate(shiftReconciliations.length, (index) {
                    final shift = shiftReconciliations[index];
                    final bool hasVariance = shift.cashVariance != 0;
                    
                    return pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          top: index > 0 ? pw.BorderSide(color: borderColor) : pw.BorderSide.none,
                        ),
                      ),
                      padding: const pw.EdgeInsets.all(16),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Shift header
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Row(
                                children: [
                                  pw.Container(
                                    width: 30,
                                    height: 30,
                                    decoration: pw.BoxDecoration(
                                      color: headerColor.shade(50),
                                      shape: pw.BoxShape.circle,
                                    ),
                                    alignment: pw.Alignment.center,
                                    child: pw.Text(
                                      '${shift.shiftNumber}',
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        color: headerColor,
                                      ),
                                    ),
                                  ),
                                  pw.SizedBox(width: 10),
                                  pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        'Shift ${shift.shiftNumber}',
                                        style: pw.TextStyle(
                                          fontSize: 14,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                      pw.SizedBox(height: 2),
                                      pw.Text(
                                        '${shift.startTime} - ${shift.endTime}',
                                        style: const pw.TextStyle(
                                          fontSize: 10,
                                          color: PdfColors.grey700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: pw.BoxDecoration(
                                  color: shift.reconciliationStatus == 'Balanced'
                                      ? greenColor.shade(50)
                                      : redColor.shade(50),
                                  borderRadius: pw.BorderRadius.circular(16),
                                  border: pw.Border.all(
                                    color: shift.reconciliationStatus == 'Balanced'
                                        ? greenColor
                                        : redColor,
                                    width: 0.5,
                                  ),
                                ),
                                child: pw.Text(
                                  shift.reconciliationStatus,
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: shift.reconciliationStatus == 'Balanced'
                                        ? greenColor
                                        : redColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          if (shift.cashierName.trim().isNotEmpty) ...[
                            pw.SizedBox(height: 8),
                            pw.Text(
                              'Cashier: ${shift.cashierName}',
                              style: const pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                          
                          pw.SizedBox(height: 12),
                          pw.Divider(color: borderColor),
                          pw.SizedBox(height: 12),
                          
                          // Shift details in a table-like layout with better styling
                          pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey50,
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Row(
                              children: [
                                pw.Expanded(
                                  child: pw.Column(
                                    children: [
                                      _buildPdfShiftDetailRow('Opening Cash', formatter.format(shift.openingCash)),
                                      _buildPdfShiftDetailRow('Cash Sales', formatter.format(shift.cashSales)),
                                      _buildPdfShiftDetailRow('Cash Expenses', formatter.format(shift.cashExpenses)),
                                    ],
                                  ),
                                ),
                                pw.SizedBox(width: 20),
                                pw.Expanded(
                                  child: pw.Column(
                                    children: [
                                      _buildPdfShiftDetailRow('Expected Closing', formatter.format(shift.expectedClosingCash), isBold: true),
                                      _buildPdfShiftDetailRow('Actual Closing', formatter.format(shift.actualClosingCash), isBold: true),
                                      _buildPdfShiftDetailRow('Cash Deposited', formatter.format(shift.cashDeposited)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          pw.SizedBox(height: 12),
                          
                          // Variance box
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: pw.BoxDecoration(
                              color: shift.cashVariance != 0 
                                  ? redColor.shade(50) 
                                  : greenColor.shade(50),
                              borderRadius: pw.BorderRadius.circular(4),
                              border: pw.Border.all(
                                color: shift.cashVariance != 0 
                                    ? redColor 
                                    : greenColor,
                                width: 0.5,
                              ),
                            ),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  'Variance',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 12,
                                    color: shift.cashVariance != 0 
                                        ? redColor 
                                        : greenColor,
                                  ),
                                ),
                                pw.Text(
                                  formatter.format(shift.cashVariance),
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 12,
                                    color: shift.cashVariance != 0 
                                        ? redColor 
                                        : greenColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Remarks section if available
                          if (shift.remarks.isNotEmpty && shift.remarks != "No variance") ...[
                            pw.SizedBox(height: 12),
                            pw.Container(
                              width: double.infinity,
                              padding: const pw.EdgeInsets.all(10),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey100,
                                borderRadius: pw.BorderRadius.circular(4),
                                border: pw.Border.all(color: PdfColors.grey300),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'Remarks:',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  pw.SizedBox(height: 4),
                                  pw.Text(
                                    shift.remarks,
                                    style: const pw.TextStyle(
                                      fontSize: 10,
                                      color: PdfColors.grey800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ] else ...[
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'No shift reconciliation data available',
                      style: const pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'There are no shifts recorded for the selected date',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
    
    return pdf.save();
  }
  
  pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 80,
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Text(
            ': ',
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey700,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  pw.Widget _buildPdfSummaryRow(
    String label, 
    String value, {
    bool isHighlighted = false,
    bool isNegative = false,
    bool isBold = false,
    PdfColor? redColor,
    PdfColor? orangeColor,
  }) {
    final textColor = isHighlighted
        ? isNegative
            ? redColor ?? PdfColors.red
            : orangeColor ?? PdfColor.fromHex('#FF9800')
        : isNegative
            ? PdfColors.red
            : PdfColors.black;
    
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 15,
              color: isHighlighted ? textColor : PdfColors.grey700,
              fontWeight: isBold ? pw.FontWeight.bold : null,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 15,
              color: isHighlighted ? textColor : PdfColors.black,
              fontWeight: isBold || isHighlighted ? pw.FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }
  
  pw.Widget _buildPdfShiftDetailRow(
    String label, 
    String value, {
    bool isHighlighted = false,
    bool isNegative = false,
    bool isBold = false,
    PdfColor? redColor,
    PdfColor? orangeColor,
  }) {
    final textColor = isHighlighted
        ? isNegative
            ? redColor ?? PdfColors.red
            : orangeColor ?? PdfColor.fromHex('#FF9800')
        : isNegative
            ? PdfColors.red
            : PdfColors.black;
    
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 14,
              color: isHighlighted ? textColor : PdfColors.grey700,
              fontWeight: isBold ? pw.FontWeight.bold : null,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              color: isHighlighted ? textColor : PdfColors.black,
              fontWeight: isBold || isHighlighted ? pw.FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _viewPdf(Uint8List pdfBytes) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }
  
  Future<void> _sharePdf(File file) async {
    final result = await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Cash Reconciliation Report',
    );
    
    if (result.status != ShareResultStatus.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share the PDF file')),
        );
      }
    }
  }
} 