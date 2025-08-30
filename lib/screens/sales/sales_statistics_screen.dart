import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/api_constants.dart';
import '../../api/shift_sales_repository.dart';
import '../../models/sales_statistics_model.dart';
import '../../theme.dart';
import 'employee_sales_screen.dart';
import '../../api/employee_repository.dart';
import '../../models/employee_model.dart';
import '../../api/dashboard_repository.dart';
import '../../models/daily_sales_model.dart';
import '../../models/sales_by_fuel_type_model.dart';
import '../../models/fuel_type_model.dart';

class SalesStatisticsScreen extends StatefulWidget {
  const SalesStatisticsScreen({Key? key}) : super(key: key);

  @override
  State<SalesStatisticsScreen> createState() => _SalesStatisticsScreenState();
}

class _SalesStatisticsScreenState extends State<SalesStatisticsScreen> with SingleTickerProviderStateMixin {
  final ShiftSalesRepository _salesRepository = ShiftSalesRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final DashboardRepository _dashboardRepository = DashboardRepository();
  late AnimationController _animationController;
  
  // State variables
  SalesStatistics? _salesStatistics;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Date range for filtering
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  // NEW: Selected date for daily sales
  DateTime _dailySalesDate = DateTime.now();
  
  // NEW: State variables for new features
  bool _isLoadingDailySales = false;
  bool _isLoadingSalesByFuelType = false;
  bool _isLoadingFuelTypes = false;
  DailySalesData? _dailySales;
  SalesByFuelType? _salesByFuelType;
  String? _dailySalesError;
  String? _salesByFuelTypeError;
  List<FuelType> _fuelTypes = [];
  Map<String, String> _fuelTypeIdToName = {};
  Map<String, Color> _fuelTypeColors = {};
  
  // Color scheme
  final Color _primaryColor = AppTheme.primaryBlue;
  final Color _secondaryColor = Color(0xFF34C759);
  final Color _accentColor = Color(0xFFFF9500);
  final Color _neutralColor = Color(0xFF8E8E93);
  
  // Chart colors
  final List<Color> _chartColors = [
    Color(0xFF007AFF), // Blue
    Color(0xFF34C759), // Green
    Color(0xFFFF9500), // Orange
    Color(0xFF5856D6), // Purple
    Color(0xFFFF2D55), // Pink
    Color(0xFF00C7BE), // Teal
    Color(0xFFAF52DE), // Purple
    Color(0xFFFFCC00), // Yellow
  ];
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _loadSalesData();
    _fetchFuelTypes();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSalesData() async {
    try {
      // Initialize data loading
      _fetchSalesStatistics();
      _fetchDailySales();
      _fetchSalesByFuelType();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading data: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _fetchSalesStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      developer.log('SalesStatisticsScreen: Fetching sales statistics');
      
      final response = await _salesRepository.getSalesStatistics(
        _startDate, 
        _endDate
      );
      
      if (mounted) {
        if (response.success && response.data != null) {
          setState(() {
            _salesStatistics = response.data;
            _isLoading = false;
          });
          _animationController.forward(from: 0.0);
          
          developer.log('SalesStatisticsScreen: Successfully fetched sales statistics');
        } else {
          setState(() {
            _errorMessage = response.errorMessage ?? 'Failed to load sales statistics';
            _isLoading = false;
          });
          
          developer.log('SalesStatisticsScreen: Error getting sales statistics: $_errorMessage');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
      
      developer.log('SalesStatisticsScreen: Exception: $e');
    }
  }
  
  Future<void> _fetchDailySales() async {
    setState(() {
      _isLoadingDailySales = true;
      _dailySalesError = null;
    });
    
    try {
      developer.log('SalesStatisticsScreen: Fetching daily sales for date: $_dailySalesDate');
      
      final response = await _dashboardRepository.getDailySales(_dailySalesDate);
      
      if (mounted) {
        setState(() {
          if (response.success && response.data != null) {
            _dailySales = response.data;
            _isLoadingDailySales = false;
            
            developer.log('SalesStatisticsScreen: Successfully fetched daily sales');
          } else {
            _dailySalesError = response.errorMessage ?? 'Failed to load daily sales';
            _isLoadingDailySales = false;
            
            developer.log('SalesStatisticsScreen: Error getting daily sales: $_dailySalesError');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dailySalesError = 'Error: $e';
          _isLoadingDailySales = false;
        });
      }
      
      developer.log('SalesStatisticsScreen: Exception when fetching daily sales: $e');
    }
  }
  
  Future<void> _fetchSalesByFuelType() async {
    setState(() {
      _isLoadingSalesByFuelType = true;
      _salesByFuelTypeError = null;
    });
    
    try {
      developer.log('SalesStatisticsScreen: Fetching sales by fuel type for range: $_startDate to $_endDate');
      
      final response = await _dashboardRepository.getSalesByFuelType(_startDate, _endDate);
      
      if (mounted) {
        setState(() {
          if (response.success && response.data != null) {
            _salesByFuelType = response.data;
            _isLoadingSalesByFuelType = false;
            
            developer.log('SalesStatisticsScreen: Successfully fetched sales by fuel type');
          } else {
            _salesByFuelTypeError = response.errorMessage ?? 'Failed to load sales by fuel type';
            _isLoadingSalesByFuelType = false;
            
            developer.log('SalesStatisticsScreen: Error getting sales by fuel type: $_salesByFuelTypeError');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _salesByFuelTypeError = 'Error: $e';
          _isLoadingSalesByFuelType = false;
        });
      }
      
      developer.log('SalesStatisticsScreen: Exception when fetching sales by fuel type: $e');
    }
  }
  
  Future<void> _fetchFuelTypes() async {
    setState(() {
      _isLoadingFuelTypes = true;
    });
    
    try {
      final response = await _dashboardRepository.getFuelTypes();
      
      if (mounted) {
        setState(() {
          _isLoadingFuelTypes = false;
          
          if (response.success && response.data != null) {
            _fuelTypes = response.data!;
            
            // Create maps from fuel type ID to name and colors for quick lookup
            for (var fuelType in _fuelTypes) {
              _fuelTypeIdToName[fuelType.fuelTypeId] = fuelType.name;
              
              // Create a color from the fuel type's color code or use a default from the chart colors
              if (fuelType.color != null && fuelType.color!.isNotEmpty) {
                try {
                  final colorString = fuelType.color!.replaceAll("#", "");
                  final colorValue = int.parse("0xFF$colorString");
                  _fuelTypeColors[fuelType.fuelTypeId] = Color(colorValue);
                } catch (e) {
                  // If there's an error parsing the color, use a default color
                  _fuelTypeColors[fuelType.fuelTypeId] = _chartColors[_fuelTypes.indexOf(fuelType) % _chartColors.length];
                }
              } else {
                // If no color is specified, use a default color from the chart colors
                _fuelTypeColors[fuelType.fuelTypeId] = _chartColors[_fuelTypes.indexOf(fuelType) % _chartColors.length];
              }
            }
            
            developer.log('SalesStatisticsScreen: Successfully loaded ${_fuelTypes.length} fuel types');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFuelTypes = false;
        });
        developer.log('SalesStatisticsScreen: Error loading fuel types: $e');
      }
    }
  }
  
  // Get fuel type name from ID
  String getFuelTypeName(String fuelTypeId) {
    return _fuelTypeIdToName[fuelTypeId] ?? fuelTypeId;
  }
  
  // Get color for fuel type
  Color getFuelTypeColor(String fuelTypeId, int defaultIndex) {
    return _fuelTypeColors[fuelTypeId] ?? _chartColors[defaultIndex % _chartColors.length];
  }
  
  // Restore date selection methods
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      
      _fetchSalesStatistics();
      _fetchSalesByFuelType();
    }
  }
  
  // NEW: Select date for daily sales
  Future<void> _selectDailyDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dailySalesDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _dailySalesDate) {
      setState(() {
        _dailySalesDate = picked;
      });
      
      _fetchDailySales();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Sales Statistics',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadSalesData();
              _fetchFuelTypes();
            },
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _primaryColor),
                  SizedBox(height: 16),
                  Text(
                    'Loading sales data...',
                    style: TextStyle(
                      color: _neutralColor,
                      fontSize: 16
                    ),
                  )
                ],
              ),
            )
          : _errorMessage != null
            ? _buildErrorView()
            : _salesStatistics == null
              ? _buildNoDataView()
              : _buildStatisticsContent(),
      ),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 48, color: Colors.red),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchSalesStatistics,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNoDataView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.analytics_outlined, size: 48, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Text(
              'No sales data available for the selected period',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Implement date range selection
              },
              icon: Icon(Icons.date_range),
              label: Text('Change Date Range'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatisticsContent() {
    return RefreshIndicator(
      onRefresh: _loadSalesData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date range
            _buildDateRangeHeader(),
            
            // NEW: Daily sales section
            // _buildDailySalesSection(),
            
            // NEW: Sales by fuel type section
            _buildSalesByFuelTypeSection(),
            
            // Summary metrics section
            _buildSummarySection(),
            
            // Payment methods section
            _buildPaymentSection(),
            
            // Employee performance section
            _buildEmployeePerformanceCard(),
            
            // Trends section
            _buildTrendsSection(),
            
            // Add bottom padding
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDateRangeHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: Colors.white70),
              SizedBox(width: 12),
              Text(
                '${DateFormat('dd MMM, yyyy').format(_startDate)} - ${DateFormat('dd MMM, yyyy').format(_endDate)}',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Change'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha:0.15),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummarySection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSectionHeader('Summary', Icons.dashboard_outlined),
          SizedBox(height: 16),
          Row(
            children: [
              Flexible(
                flex: 1,
                child: _buildMetricCard(
                  'Total Sales',
                  '₹${NumberFormat('#,##,###').format(_salesStatistics!.totalAmount)}',
                  Icons.currency_rupee,
                  _primaryColor,
                  '${_salesStatistics!.totalTransactions} transactions',
                ),
              ),
              SizedBox(width: 12),
              Flexible(
                flex: 1,
                child: _buildMetricCard(
                  'Total Volume',
                  '${NumberFormat('#,##,###').format(_salesStatistics!.totalLitersSold)} L',
                  Icons.local_gas_station,
                  _secondaryColor,
                  'All fuel types',
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildMetricCard(
            'Top Performing Shift',
            _salesStatistics!.topPerformingShiftName ?? 'N/A',
            Icons.star,
            _accentColor,
            _salesStatistics!.topPerformingShiftAmount != null
                ? '₹${NumberFormat('#,##,###').format(_salesStatistics!.topPerformingShiftAmount!)}'
                : '',
            isFullWidth: true,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetricCard(
    String title, 
    String value, 
    IconData icon, 
    Color color,
    String subtitle, {
    bool isFullWidth = false,
    bool isAlert = false,
  }) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      margin: EdgeInsets.only(bottom: isFullWidth ? 0 : 8.0),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: isAlert 
            ? Border.all(color: Colors.amber, width: 1.5)
            : Border.all(color: Colors.grey.withValues(alpha:0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPaymentSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSectionHeader('Payment Methods', Icons.payment_outlined),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPaymentProgressBar(
                  'Cash',
                  _salesStatistics!.cashAmount,
                  _salesStatistics!.totalAmount,
                  _chartColors[0],
                ),
                SizedBox(height: 20),
                _buildPaymentProgressBar(
                  'Credit Card',
                  _salesStatistics!.creditCardAmount,
                  _salesStatistics!.totalAmount,
                  _chartColors[1],
                ),
                SizedBox(height: 20),
                _buildPaymentProgressBar(
                  'UPI',
                  _salesStatistics!.upiAmount,
                  _salesStatistics!.totalAmount,
                  _chartColors[2],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmployeePerformanceCard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSectionHeader('Employee Performance', Icons.people_alt_outlined),
          SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header section
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View detailed sales data by employee',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'See which employees contributed to your sales during this period. View individual performance metrics to identify top performers.',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action button
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border(top: BorderSide(color: Colors.grey.withValues(alpha:0.2))),
                  ),
                  child: TextButton.icon(
                    onPressed: _navigateToEmployeeList,
                    icon: Icon(Icons.people, size: 18),
                    label: Text('View All Employees'),
                    style: TextButton.styleFrom(
                      backgroundColor: _primaryColor.withValues(alpha:0.1),
                      foregroundColor: _primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPaymentProgressBar(String label, double amount, double total, Color color) {
    final percentage = total > 0 ? (amount / total * 100) : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              '₹${NumberFormat('#,##,###').format(amount)} (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            color: color,
            minHeight: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTrendsSection() {
    if (_salesStatistics!.salesByDay.isEmpty) {
      return SizedBox.shrink();
    }
    
    // Sort by date
    final sortedDays = List<DailySales>.from(_salesStatistics!.salesByDay)
      ..sort((a, b) => a.date.compareTo(b.date));
    
    // Take only the last 7 days or less
    final last7Days = sortedDays.length > 7 
      ? sortedDays.sublist(sortedDays.length - 7) 
      : sortedDays;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSectionHeader('Last 7 Days Trend', Icons.trending_up_outlined),
          SizedBox(height: 16),
          Container(
            height: 250,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: _buildLineChart(last7Days),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLineChart(List<DailySales> dailySales) {
    // Create data points
    final spots = dailySales.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.amount);
    }).toList();
    
    // Find min and max values for y-axis
    double maxY = 0;
    if (dailySales.isNotEmpty) {
      maxY = dailySales.map((day) => day.amount).reduce((a, b) => a > b ? a : b) * 1.1;
    }
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 5 : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[200]!,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < dailySales.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('dd/MM').format(dailySales[value.toInt()].date),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return SizedBox.shrink();
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                return Text(
                  '₹${value.toInt()}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: dailySales.length - 1.0,
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _primaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 5,
                color: _primaryColor,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: _primaryColor.withValues(alpha:0.2),
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withValues(alpha:0.4),
                  _primaryColor.withValues(alpha:0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.black.withValues(alpha:0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.spotIndex;
                if (index >= 0 && index < dailySales.length) {
                  final day = dailySales[index];
                  return LineTooltipItem(
                    '${DateFormat('MMM dd').format(day.date)}\n₹${NumberFormat('#,##,###').format(day.amount)}',
                    TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: _primaryColor),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
  
  void _navigateToEmployeeList() {
    // Navigate to employee list using a full screen instead of bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalesEmployeeListScreen(
          startDate: _startDate,
          endDate: _endDate,
        ),
      ),
    );
  }

  // Added methods for the new UI components
  Widget _buildDailySalesSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Sales',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _selectDailyDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    DateFormat('dd MMM, yyyy').format(_dailySalesDate),
                    style: TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Daily sales content
            _isLoadingDailySales
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _dailySalesError != null
                ? _buildErrorCard(_dailySalesError!)
                : _dailySales == null
                  ? _buildNoDataCard('No daily sales data available for this date')
                  : _buildDailySalesContent(_dailySales!),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDailySalesContent(DailySalesData dailySales) {
    final bool hasFuelData = dailySales.salesByFuelType.isNotEmpty || dailySales.revenueByFuelType.isNotEmpty;
    
    return Column(
      children: [
        // Daily sales metrics
        Row(
          children: [
            _buildDailySalesMetricCard(
              'Sales Volume',
              '${dailySales.totalSalesVolume.toStringAsFixed(2)} L',
              Icons.local_gas_station,
              _chartColors[0],
            ),
            const SizedBox(width: 12),
            _buildDailySalesMetricCard(
              'Sales Value',
              '₹${NumberFormat.compact().format(dailySales.totalSalesValue)}',
              Icons.attach_money,
              _chartColors[1],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildDailySalesMetricCard(
              'Transactions',
              '${dailySales.transactionCount}',
              Icons.receipt_long,
              _chartColors[2],
            ),
            const SizedBox(width: 12),
            _buildDailySalesMetricCard(
              'Avg. Transaction',
              '₹${NumberFormat.compact().format(dailySales.averageTransactionValue)}',
              Icons.pending_actions,
              _chartColors[3],
            ),
          ],
        ),
        
        // Sales by fuel type breakdown
        if (hasFuelData) ...[
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Sales by Fuel Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildSalesByFuelTypeChart(dailySales),
        ],
      ],
    );
  }
  
  Widget _buildDailySalesMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha:0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha:0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSalesByFuelTypeChart(DailySalesData dailySales) {
    final List<MapEntry<String, double>> salesEntries = dailySales.salesByFuelType.entries.toList();
    final List<MapEntry<String, double>> revenueEntries = dailySales.revenueByFuelType.entries.toList();
    
    if (salesEntries.isEmpty && revenueEntries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Text(
          'No fuel type breakdown available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    
    // Pick which data to show (prefer sales volume)
    final entries = salesEntries.isNotEmpty ? salesEntries : revenueEntries;
    final isVolume = salesEntries.isNotEmpty;
    
    // Limit the number of entries to avoid overflow
    final displayEntries = entries.length > 5 ? entries.sublist(0, 5) : entries;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 300,
          width: constraints.maxWidth,
          padding: const EdgeInsets.all(8),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: displayEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.blueGrey.shade800,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final idx = group.x.toInt();
                    if (idx >= 0 && idx < displayEntries.length) {
                      final fuelType = displayEntries[idx].key;
                      return BarTooltipItem(
                        '$fuelType\n${isVolume ? '${rod.toY.toStringAsFixed(2)} L' : '₹${rod.toY.toStringAsFixed(2)}'}',
                        const TextStyle(color: Colors.white),
                      );
                    }
                    return null;
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      if (value >= 0 && value < displayEntries.length) {
                        final fuelTypeValue = displayEntries[value.toInt()].key;
                        final shortName = fuelTypeValue.length > 8 ? fuelTypeValue.substring(0, 7) + '...' : fuelTypeValue;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            shortName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(0),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11,
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 1,
                ),
              ),
              barGroups: List.generate(
                displayEntries.length, 
                (index) => BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: displayEntries[index].value,
                      color: getFuelTypeColor(displayEntries[index].key, index),
                      width: min(22, (constraints.maxWidth / displayEntries.length) * 0.6),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: displayEntries.map((e) => e.value).reduce((a, b) => max(a, b)) * 1.1,
                        color: Colors.grey.shade200,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }
  
  // Helper for chart grid interval
  double _calculateGridInterval(SalesByFuelType data) {
    final maxVolume = data.fuelTypes.map((e) => e.volume).reduce((a, b) => a > b ? a : b);
    return maxVolume / 5;
  }
  
  Widget _buildSalesByFuelTypeSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sales by Fuel Type',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM').format(_endDate)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Sales by fuel type content
            _isLoadingSalesByFuelType
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _salesByFuelTypeError != null
                ? _buildErrorCard(_salesByFuelTypeError!)
                : _salesByFuelType == null || _salesByFuelType!.fuelTypes.isEmpty
                  ? _buildNoDataCard('No fuel type sales data available for this period')
                  : _buildSalesByFuelTypeContent(_salesByFuelType!),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSalesByFuelTypeContent(SalesByFuelType data) {
    return Column(
      children: [
        // Summary metrics
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Volume',
                '${data.totalSalesVolume.toStringAsFixed(2)} L',
                Icons.local_gas_station,
                _chartColors[0],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Total Revenue',
                '₹${NumberFormat.compact().format(data.totalSalesValue)}',
                Icons.attach_money,
                _chartColors[1],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Fuel types comparison
        _buildFuelTypeComparisonChart(data),
        
        const SizedBox(height: 24),
        
        // Fuel types breakdown in table
        Text(
          'Detailed Breakdown',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _buildFuelTypeTable(data),
      ],
    );
  }
  
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFuelTypeComparisonChart(SalesByFuelType data) {
    if (data.fuelTypes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: Text(
          'No fuel type data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    
    // Limit display to 8 fuel types to avoid overcrowding
    final displayData = data.fuelTypes.length > 8 
        ? data.fuelTypes.sublist(0, 8) 
        : data.fuelTypes;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = min(20.0, (constraints.maxWidth / displayData.length) * 0.6);
        
        return Container(
          height: 300,
          width: constraints.maxWidth,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: BarChart(
            BarChartData(
              barGroups: List.generate(
                displayData.length,
                (index) => BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: displayData[index].volume,
                      color: getFuelTypeColor(displayData[index].fuelTypeId, index),
                      width: barWidth,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: data.fuelTypes.map((e) => e.volume).reduce((a, b) => max(a, b)) * 1.1,
                        color: Colors.grey.shade200,
                      ),
                    ),
                  ],
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      if (value >= 0 && value < displayData.length) {
                        final fuelTypeValue = displayData[value.toInt()].fuelType;
                        final shortName = fuelTypeValue.length > 8 ? fuelTypeValue.substring(0, 7) + '...' : fuelTypeValue;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            shortName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(0),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11,
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                horizontalInterval: _calculateGridInterval(data),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 1,
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.blueGrey.shade800,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final fuelType = displayData[group.x.toInt()];
                    return BarTooltipItem(
                      '${fuelType.fuelType}\n',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: 'Volume: ${fuelType.volume.toStringAsFixed(2)} L\n',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        TextSpan(
                          text: 'Value: ₹${NumberFormat.compact().format(fuelType.value)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }
    );
  }
  
  Widget _buildFuelTypeTable(SalesByFuelType data) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            horizontalMargin: 16,
            headingRowHeight: 50,
            dataRowMinHeight: 50,
            dataRowMaxHeight: 60,
            headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
            headingTextStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: _primaryColor,
              fontSize: 13,
            ),
            dataTextStyle: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 13,
            ),
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey.shade200),
            ),
            columns: const [
              DataColumn(label: Text('Fuel Type')),
              DataColumn(
                label: Text('Volume (L)'),
                numeric: true,
              ),
              DataColumn(
                label: Text('Value (₹)'),
                numeric: true,
              ),
              DataColumn(
                label: Text('% of Total'),
                numeric: true,
              ),
              DataColumn(
                label: Text('Price/L'),
                numeric: true,
              ),
            ],
            rows: data.fuelTypes.map((fuelType) {
              final color = getFuelTypeColor(fuelType.fuelTypeId, data.fuelTypes.indexOf(fuelType));

              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            fuelType.fuelType,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(
                    NumberFormat("#,###.00").format(fuelType.volume),
                    style: TextStyle(fontWeight: FontWeight.w500),
                  )),
                  DataCell(Text(
                    NumberFormat("₹#,###.00").format(fuelType.value),
                  )),
                  DataCell(Text(
                    '${fuelType.percentageOfTotalVolume.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  )),
                  DataCell(Text(
                    '₹${fuelType.averagePricePerLiter.toStringAsFixed(2)}',
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
  
  // Helper: Error card
  Widget _buildErrorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade800),
          ),
        ],
      ),
    );
  }
  
  // Helper: No data card
  Widget _buildNoDataCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart_outlined, color: Colors.grey, size: 40),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

// New class for Employee List Screen
class SalesEmployeeListScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  
  const SalesEmployeeListScreen({
    Key? key,
    required this.startDate,
    required this.endDate,
  }) : super(key: key);

  @override
  State<SalesEmployeeListScreen> createState() => _SalesEmployeeListScreenState();
}

class _SalesEmployeeListScreenState extends State<SalesEmployeeListScreen> {
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final Color _primaryColor = AppTheme.primaryBlue;
  
  List<Employee> _employees = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _employeeRepository.getAllEmployees();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          
          if (response.success && response.data != null) {
            _employees = response.data!;
          } else {
            _errorMessage = response.errorMessage ?? 'Failed to load employees';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Employee Performance',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEmployees,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _primaryColor),
                  SizedBox(height: 16),
                  Text(
                    'Loading employees...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16
                    ),
                  )
                ],
              ),
            )
          : _errorMessage != null
            ? _buildErrorView()
            : _employees.isEmpty
              ? _buildNoEmployeesView()
              : _buildEmployeeList(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 48, color: Colors.red),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchEmployees,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoEmployeesView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              'No employees found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'No employee data is currently available',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchEmployees,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date range info
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          color: _primaryColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Date Range',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '${DateFormat('dd MMM, yyyy').format(widget.startDate)} - ${DateFormat('dd MMM, yyyy').format(widget.endDate)}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Select an employee to view their sales performance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        
        // Employee list
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(vertical: 8),
            itemCount: _employees.length,
            separatorBuilder: (context, index) => Divider(height: 1, indent: 70),
            itemBuilder: (context, index) {
              final employee = _employees[index];
              return ListTile(
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                leading: CircleAvatar(
                  backgroundColor: _primaryColor.withValues(alpha:0.2),
                  radius: 24,
                  child: Text(
                    employee.firstName.isNotEmpty ? employee.firstName[0] : '?',
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                title: Text(
                  '${employee.firstName} ${employee.lastName}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Text(
                      employee.role,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                trailing: Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  _navigateToEmployeeSalesScreen(
                    employeeId: employee.id!,
                    employeeName: '${employee.firstName} ${employee.lastName}',
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _navigateToEmployeeSalesScreen({required String employeeId, required String employeeName}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeSalesScreen(
          employeeId: employeeId,
          employeeName: employeeName,
        ),
      ),
    );
  }
} 