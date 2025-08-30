import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_constants.dart';
import '../../theme.dart';
import '../../screens/login/login_screen.dart';

class ShiftPerformanceScreen extends StatefulWidget {
  const ShiftPerformanceScreen({Key? key}) : super(key: key);

  @override
  State<ShiftPerformanceScreen> createState() => _ShiftPerformanceScreenState();
}

class _ShiftPerformanceScreenState extends State<ShiftPerformanceScreen> {
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Date range for API requests
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  // Shift performance data
  List<ShiftMetric> _shiftMetrics = [];
  String? _topPerformingShift;
  double? _topPerformingShiftVolume;
  
  @override
  void initState() {
    super.initState();
    _fetchShiftPerformanceData();
  }
  
  Future<void> _fetchShiftPerformanceData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final DateFormat formatter = DateFormat('yyyy-MM-dd');
      final String formattedStartDate = formatter.format(_startDate);
      final String formattedEndDate = formatter.format(_endDate);
      
      // Get token and verify it's available
      final String? authToken = await ApiConstants.getAuthToken();
      if (authToken == null || authToken.isEmpty) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Authentication error: No valid token found. Please log in again.';
          _isLoading = false;
        });
        _redirectToLogin();
        return;
      }
      
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/Dashboard/operations/shift-performance?startDate=${_startDate.toIso8601String()}&endDate=${_endDate.toIso8601String()}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (!mounted) return;
        
        setState(() {
          // Parse shift metrics
          _shiftMetrics = (data['shiftMetrics'] as List<dynamic>?)?.map((metric) => 
            ShiftMetric.fromJson(metric)).toList() ?? [];
          
          _topPerformingShift = data['topPerformingShift'] as String?;
          _topPerformingShiftVolume = data['topPerformingShiftVolume'] != null 
              ? double.parse(data['topPerformingShiftVolume'].toString()) 
              : null;
              
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Authentication expired. Please log in again.';
          _isLoading = false;
        });
        _redirectToLogin();
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Failed to load shift performance data: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: AppTheme.primaryBlue,
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
            ),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != DateTimeRange(start: _startDate, end: _endDate)) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      
      // Refresh data with new date range
      _fetchShiftPerformanceData();
    }
  }
  
  void _redirectToLogin() async {
    // Clear the stored token
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.authTokenKey);
    
    if (!mounted) return;
    
    // Show a snackbar before redirecting
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session expired. Please log in again.'),
        backgroundColor: Colors.red,
      ),
    );
    
    // Delay briefly to allow snackbar to be seen
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      
      // Navigate to login screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shift Performance',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchShiftPerformanceData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date range selector
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha:0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.date_range,
                              size: 20,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Date Range',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '${DateFormat('MMM d, yyyy').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _selectDateRange(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                  
                    // Error message if any
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        width: double.infinity,
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(color: Colors.red[800]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                    // Main content
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_shiftMetrics.isNotEmpty) ...[
                            // Top Performing Shift
                            if (_topPerformingShift != null) 
                              _buildTopPerformingShiftCard(),
                              
                            const SizedBox(height: 24),
                            
                            // Shift Performance Cards
                            const Text(
                              'Shift Performance',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // List of shift cards
                            ...List.generate(_shiftMetrics.length, (index) {
                              final shift = _shiftMetrics[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: _buildShiftCard(shift, index),
                              );
                            }),
                          ] else if (_errorMessage.isEmpty) ...[
                            // No data available
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 40),
                                  Icon(
                                    Icons.bar_chart,
                                    size: 80,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No shift performance data available',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try selecting a different date range',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildTopPerformingShiftCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha:0.15),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Top Performing Shift',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _topPerformingShift ?? 'N/A',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha:0.1),
                      blurRadius: 4,
                      spreadRadius: 0,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_gas_station,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${NumberFormat.decimalPattern().format(_topPerformingShiftVolume ?? 0)} L',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildShiftCard(ShiftMetric shift, int index) {
    final List<Color> cardColors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];
    
    final color = cardColors[index % cardColors.length];
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withValues(alpha:0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(color: color.withValues(alpha:0.2)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha:0.2),
                        blurRadius: 4,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${shift.shiftNumber}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shift.shiftName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.store,
                            size: 14,
                            color: color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${shift.transactionCount} transactions',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(shift.totalRevenue),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Card body with stats
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sales metrics
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        'Avg. Daily Sales',
                        NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(shift.averageDailySales),
                        Icons.trending_up,
                        color,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricItem(
                        'Avg. Transaction',
                        NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(shift.averageTransactionValue),
                        Icons.receipt,
                        color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        'Sales Volume',
                        '${NumberFormat.decimalPattern().format(shift.totalSalesVolume)} L',
                        Icons.local_gas_station,
                        color,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricItem(
                        'Total Revenue',
                        NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(shift.totalRevenue),
                        Icons.account_balance_wallet,
                        color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetricItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha:0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class ShiftMetric {
  final int shiftNumber;
  final String shiftName;
  final double averageDailySales;
  final double totalSalesVolume;
  final double totalRevenue;
  final int transactionCount;
  final double averageTransactionValue;
  
  ShiftMetric({
    required this.shiftNumber,
    required this.shiftName,
    required this.averageDailySales,
    required this.totalSalesVolume,
    required this.totalRevenue,
    required this.transactionCount,
    required this.averageTransactionValue,
  });
  
  factory ShiftMetric.fromJson(Map<String, dynamic> json) {
    return ShiftMetric(
      shiftNumber: json['shiftNumber'] as int,
      shiftName: json['shiftName'] as String,
      averageDailySales: double.parse(json['averageDailySales'].toString()),
      totalSalesVolume: double.parse(json['totalSalesVolume'].toString()),
      totalRevenue: double.parse(json['totalRevenue'].toString()),
      transactionCount: json['transactionCount'] as int,
      averageTransactionValue: double.parse(json['averageTransactionValue'].toString()),
    );
  }
} 