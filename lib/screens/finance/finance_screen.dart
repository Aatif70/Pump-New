import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

import '../../api/api_constants.dart';
import '../../theme.dart';
import '../../screens/login/login_screen.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({Key? key}) : super(key: key);

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> with TickerProviderStateMixin {
  bool _isLoadingPaymentMethods = false;
  bool _isLoadingDailyRevenue = false;
  String _errorMessage = '';
  
  // Payment methods data
  Map<String, double> _paymentMethodAmounts = {};
  Map<String, double> _paymentMethodPercentages = {};
  String? _topPaymentMethod;
  double? _topPaymentMethodPercentage;
  
  // Daily revenue data
  List<DailyRevenueData> _dailyRevenueData = [];
  
  // Date range for API requests
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  late TabController _tabController;
  
  // Animation controllers
  late AnimationController _animationController;
  bool _isFirstLoad = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _fetchPaymentMethodsData();
    _fetchDailyRevenueData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _fetchPaymentMethodsData() async {
    setState(() {
      _isLoadingPaymentMethods = true;
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
          _isLoadingPaymentMethods = false;
        });
        _redirectToLogin();
        return;
      }
      
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/Dashboard/finance/payment-methods?startDate=$formattedStartDate&endDate=$formattedEndDate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (!mounted) return;
        
        setState(() {
          _paymentMethodAmounts = Map<String, double>.from(
            data['paymentMethodAmounts'].map((key, value) => 
              MapEntry(key, double.parse(value.toString())))
          );
          
          _paymentMethodPercentages = Map<String, double>.from(
            data['paymentMethodPercentages'].map((key, value) => 
              MapEntry(key, double.parse(value.toString())))
          );
          
          _topPaymentMethod = data['topPaymentMethod'] as String?;
          _topPaymentMethodPercentage = data['topPaymentMethodPercentage'] != null
              ? double.parse(data['topPaymentMethodPercentage'].toString())
              : null;
              
          _isLoadingPaymentMethods = false;
        });
        
        // Start animation if this is the first load
        if (_isFirstLoad && mounted) {
          _animationController.forward();
        }
      } else if (response.statusCode == 401) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Authentication expired. Please log in again.';
          _isLoadingPaymentMethods = false;
        });
        _redirectToLogin();
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Failed to load payment methods data: ${response.statusCode}';
          _isLoadingPaymentMethods = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoadingPaymentMethods = false;
      });
    }
  }
  
  Future<void> _fetchDailyRevenueData() async {
    setState(() {
      _isLoadingDailyRevenue = true;
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
          _isLoadingDailyRevenue = false;
        });
        _redirectToLogin();
        return;
      }
      
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/Dashboard/finance/daily-revenue?startDate=$formattedStartDate&endDate=$formattedEndDate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        if (!mounted) return;
        
        setState(() {
          _dailyRevenueData = data.map((item) {
            return DailyRevenueData.fromJson(item);
          }).toList();
          
          // Sort the data by date
          _dailyRevenueData.sort((a, b) => a.date.compareTo(b.date));
          
          _isLoadingDailyRevenue = false;
        });
        
        // Start animation if this is the first load
        if (_isFirstLoad && mounted) {
          _isFirstLoad = false;
          _animationController.reset();
          _animationController.forward();
        }
      } else if (response.statusCode == 401) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Authentication expired. Please log in again.';
          _isLoadingDailyRevenue = false;
        });
        _redirectToLogin();
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Failed to load daily revenue data: ${response.statusCode}';
          _isLoadingDailyRevenue = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoadingDailyRevenue = false;
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
        _isFirstLoad = true; // Reset animation for new data
      });
      
      // Refresh data with new date range
      _fetchPaymentMethodsData();
      _fetchDailyRevenueData();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Finance',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha:0.7),
          tabs: const [
            Tab(text: 'Payment Methods'),
            Tab(text: 'Daily Revenue'),
          ],
        ),
      ),
      body: Column(
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
            
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Payment Methods Tab
                _buildPaymentMethodsTab(),
                
                // Daily Revenue Tab
                _buildDailyRevenueTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPaymentMethodsTab() {
    if (_isLoadingPaymentMethods) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_paymentMethodAmounts.isEmpty) {
      return Center(
        child: Text(
          'No payment methods data available',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    
    final List<Color> colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];
    
    // Start animation if first load
    if (_isFirstLoad && mounted) {
      _isFirstLoad = false;
      _animationController.forward();
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment Methods Overview Card
          Container(
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
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha:0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.payment_rounded,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Methods',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            if (_topPaymentMethod != null)
                              Text(
                                'Most popular: $_topPaymentMethod (${_topPaymentMethodPercentage?.toStringAsFixed(1) ?? "0"}%)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Divider
                Divider(color: Colors.grey[200], height: 1),
                
                // Payment donut chart with animation
                SizedBox(
                  height: 240,
                  child: _buildPaymentMethodsDonutChart(colors),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Payment methods breakdown
          Container(
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
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Payment Methods Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                
                Divider(color: Colors.grey[200], height: 1),
                
                // Payment method list
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _paymentMethodAmounts.length,
                  separatorBuilder: (context, index) => Divider(
                    color: Colors.grey[200],
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                  ),
                  itemBuilder: (context, index) {
                    final entry = _paymentMethodAmounts.entries.elementAt(index);
                    final String method = entry.key;
                    final double amount = entry.value;
                    final double percentage = _paymentMethodPercentages[method] ?? 0;
                    final Color color = colors[index % colors.length];
                    
                    return AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final animatedPercentage = _animationController.value * percentage;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    method,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        NumberFormat.currency(symbol: '₹').format(amount),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${animatedPercentage.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Percentage visualization bar
                              Stack(
                                children: [
                                  // Background bar
                                  Container(
                                    width: double.infinity,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  // Filled bar with animation
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: (MediaQuery.of(context).size.width - 40) * (percentage / 100) * _animationController.value,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withValues(alpha:0.4),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
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
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPaymentMethodsDonutChart(List<Color> colors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight) * 0.8;
        
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animated Donut Chart
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(size, size),
                      painter: DonutChartPainter(
                        percentages: _paymentMethodPercentages.values.toList(),
                        colors: colors.sublist(0, _paymentMethodPercentages.length),
                        animationValue: _animationController.value,
                      ),
                    );
                  }
                ),
                
                // Center content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, _) {
                        // Calculate total amount
                        double total = 0;
                        for (var amount in _paymentMethodAmounts.values) {
                          total += amount;
                        }
                        
                        return Text(
                          NumberFormat.currency(
                            symbol: '₹',
                            decimalDigits: 0,
                          ).format(total * _animationController.value),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    );
  }
  
  Widget _buildGridLines(double height) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: GridPainter(height: height),
      ),
    );
  }

  Widget _buildDailyRevenueTab() {
    if (_isLoadingDailyRevenue) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_dailyRevenueData.isEmpty) {
      return Center(
        child: Text(
          'No revenue data available',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    // Calculate maximum revenue for the chart scale
    double maxRevenue = 0;
    for (var data in _dailyRevenueData) {
      if (data.totalRevenue > maxRevenue) {
        maxRevenue = data.totalRevenue;
      }
    }
    
    // Add 10% padding to the maximum value for better visualization
    maxRevenue = maxRevenue * 1.1;
    
    // Start animation if first load
    if (_isFirstLoad && mounted) {
      _isFirstLoad = false;
      _animationController.forward();
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue overview card
          Container(
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
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha:0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bar_chart_rounded,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Revenue',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            Text(
                              _calculateDateRangeText(),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Total revenue summary
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildRevenueSummary(),
                ),
                
                const SizedBox(height: 16),
                
                // Revenue chart
                SizedBox(
                  height: 250,
                  child: _buildAnimatedRevenueBarChart(maxRevenue),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Daily revenue breakdown
          Container(
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
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Daily Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                
                Divider(color: Colors.grey[200], height: 1),
                
                // Daily revenue items
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _dailyRevenueData.length,
                  separatorBuilder: (context, index) => Divider(
                    color: Colors.grey[200],
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                  ),
                  itemBuilder: (context, index) {
                    // Get data in reverse order (newest to oldest)
                    final data = _dailyRevenueData[_dailyRevenueData.length - 1 - index];
                    
                    // Skip days with zero revenue
                    if (data.totalRevenue == 0) {
                      return const SizedBox.shrink();
                    }
                    
                    return _buildRevenueItem(data);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRevenueSummary() {
    // Calculate total revenue
    double totalRevenue = 0;
    double totalFuelSales = 0;
    double totalOtherSales = 0;
    
    for (var data in _dailyRevenueData) {
      totalRevenue += data.totalRevenue;
      totalFuelSales += data.fuelSalesRevenue;
      totalOtherSales += data.otherRevenue;
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Revenue',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, _) {
                return Text(
                  NumberFormat.currency(
                    symbol: '₹',
                    decimalDigits: 0,
                  ).format(totalRevenue * _animationController.value),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                );
              }
            ),
          ],
        ),
        Row(
          children: [
            _buildRevenueType(
              'Fuel', 
              totalFuelSales, 
              Colors.blue[700]!,
              Icons.local_gas_station,
            ),
            const SizedBox(width: 16),
            _buildRevenueType(
              'Other', 
              totalOtherSales, 
              Colors.amber[700]!,
              Icons.shopping_cart,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildRevenueType(String label, double amount, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, _) {
                return Text(
                  NumberFormat.currency(
                    symbol: '₹',
                    decimalDigits: 0,
                  ).format(amount * _animationController.value),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                );
              }
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildRevenueItem(DailyRevenueData data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header section with date and amount
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Date container
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('dd').format(data.date),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(data.date),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryBlue.withValues(alpha:0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Date details and day name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE').format(data.date),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        DateFormat('yyyy').format(data.date),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Revenue amount
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[100]!),
                  ),
                  child: Text(
                    NumberFormat.currency(
                      symbol: '₹',
                      decimalDigits: 0,
                    ).format(data.totalRevenue),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Revenue breakdown section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Revenue categories
                Row(
                  children: [
                    Expanded(
                      child: _buildBreakdownCard(
                        'Fuel Sales',
                        data.fuelSalesRevenue,
                        Icons.local_gas_station,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBreakdownCard(
                        'Other Sales',
                        data.otherRevenue,
                        Icons.shopping_cart,
                        Colors.amber,
                      ),
                    ),
                  ],
                ),
                
                // Payment methods section (if available)
                if (data.paymentBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.payments_outlined, size: 16, color: Colors.grey[700]),
                      const SizedBox(width: 6),
                      Text(
                        'Payment Methods',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Payment methods cards
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: data.paymentBreakdown.entries.map((entry) {
                      return _buildPaymentMethodChip(
                        entry.key,
                        entry.value,
                        _getPaymentMethodIcon(entry.key),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(String label, double amount, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color[700]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(amount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodChip(String methodName, double amount, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.grey[700],
          ),
          const SizedBox(width: 6),
          Text(
            methodName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(amount),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
        ],
      ),
    );
  }
  
  IconData _getPaymentMethodIcon(String method) {
    final lowercaseMethod = method.toLowerCase();
    if (lowercaseMethod.contains('cash')) {
      return Icons.payments_outlined;
    } else if (lowercaseMethod.contains('card') || lowercaseMethod.contains('credit') || lowercaseMethod.contains('debit')) {
      return Icons.credit_card;
    } else if (lowercaseMethod.contains('upi')) {
      return Icons.phone_android;
    } else if (lowercaseMethod.contains('wallet')) {
      return Icons.account_balance_wallet;
    } else if (lowercaseMethod.contains('bank')) {
      return Icons.account_balance;
    } else {
      return Icons.payment;
    }
  }
  
  Widget _buildAnimatedRevenueBarChart(double maxRevenue) {
    // Limit the number of bars to display to prevent overcrowding
    final int displayCount = math.min(_dailyRevenueData.length, 14);
    
    // Get the most recent data points for display
    final data = _dailyRevenueData.length > displayCount 
        ? _dailyRevenueData.sublist(_dailyRevenueData.length - displayCount)
        : _dailyRevenueData;
    
    // Track which bar is showing a tooltip
    ValueNotifier<int?> activeTooltipIndex = ValueNotifier<int?>(null);
    
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 16, top: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate bar dimensions based on available space
          final barWidth = math.min(
            24.0, // Maximum bar width
            (constraints.maxWidth - 20) / (displayCount * 1.5)
          );
          
          // Calculate spacing between bars
          final totalBarWidth = barWidth * data.length;
          final remainingWidth = constraints.maxWidth - totalBarWidth;
          final spacing = data.length > 1 ? remainingWidth / (data.length + 1) : 20.0;
          
          // Height for the chart area (excluding labels)
          final chartHeight = constraints.maxHeight - 56; 
          
          return Column(
            children: [
              // Y-axis labels (top and bottom values)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹0',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                    Text(
                      '₹${NumberFormat.compact().format(maxRevenue)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Chart area
              Expanded(
                child: Stack(
                  children: [
                    // Grid lines in background
                    _buildGridLines(chartHeight),
                    
                    // Bar chart
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Stack(
                        children: [
                          // Bars
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Initial padding
                              SizedBox(width: spacing / 2),
                              
                              // Generate bars
                              ...List.generate(data.length, (index) {
                                final item = data[index];
                                final barHeightPercentage = item.totalRevenue / maxRevenue;
                                final rawBarHeight = barHeightPercentage * chartHeight;
                                
                                // Ensure minimum height of 2 for visibility even for small values
                                final barHeight = math.max(rawBarHeight, 2.0);
                                
                                return Padding(
                                  padding: EdgeInsets.only(right: spacing),
                                  child: AnimatedBuilder(
                                    animation: _animationController,
                                    builder: (context, child) {
                                      final animatedHeight = barHeight * _animationController.value;
                                      
                                      return _buildBar(
                                        index: index,
                                        width: barWidth,
                                        height: animatedHeight,
                                        color: AppTheme.primaryBlue,
                                        date: item.date,
                                        revenue: item.totalRevenue,
                                        activeTooltipIndex: activeTooltipIndex,
                                      );
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                          
                          // Tooltips layer
                          ValueListenableBuilder<int?>(
                            valueListenable: activeTooltipIndex,
                            builder: (context, activeIndex, _) {
                              if (activeIndex == null) return const SizedBox();
                              
                              final item = data[activeIndex];
                              final formattedDate = DateFormat('MMM d, yyyy').format(item.date);
                              final formattedRevenue = NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(item.totalRevenue);
                              
                              // Calculate position
                              double left = spacing / 2 + (barWidth + spacing) * activeIndex;
                              
                              return Positioned(
                                left: left - 40 + (barWidth / 2),
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha:0.8),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha:0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        formattedDate,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        formattedRevenue,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // X-axis date labels
              SizedBox(
                height: 24,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      // Initial padding to align with bars
                      SizedBox(width: spacing / 2),
                      
                      // Date labels
                      ...List.generate(data.length, (index) {
                        return Container(
                          width: barWidth,
                          margin: EdgeInsets.only(right: spacing),
                          child: Center(
                            child: Text(
                              DateFormat('d').format(data[index].date),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildBar({
    required int index,
    required double width,
    required double height,
    required Color color,
    required DateTime date,
    required double revenue,
    required ValueNotifier<int?> activeTooltipIndex,
  }) {
    return GestureDetector(
      onTap: () {
        // Toggle tooltip visibility
        if (activeTooltipIndex.value == index) {
          activeTooltipIndex.value = null;
        } else {
          activeTooltipIndex.value = index;
          
          // Auto-hide tooltip after a delay
          Future.delayed(const Duration(seconds: 3), () {
            if (activeTooltipIndex.value == index) {
              activeTooltipIndex.value = null;
            }
          });
        }
      },
      child: Container(
        width: width,
        height: math.max(height, 2), // Ensure minimum height for visibility
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha:0.4),
              spreadRadius: 0,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              color,
              color.withValues(alpha:0.7),
            ],
          ),
        ),
      ),
    );
  }
  
  String _calculateDateRangeText() {
    // Calculate difference in days
    final difference = _endDate.difference(_startDate).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference < 7) {
      return 'Last $difference days';
    } else if (difference == 7) {
      return 'Last week';
    } else if (difference < 30) {
      return 'Last ${(difference / 7).floor()} weeks';
    } else if (difference >= 30 && difference < 60) {
      return 'Last month';
    } else {
      return 'Last ${(difference / 30).floor()} months';
    }
  }

  // Redirect to login screen if authentication fails
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
}

// Donut chart custom painter
class DonutChartPainter extends CustomPainter {
  final List<double> percentages;
  final List<Color> colors;
  final double animationValue;
  final double strokeWidth = 30.0;
  
  DonutChartPainter({
    required this.percentages,
    required this.colors,
    required this.animationValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    
    // Draw background circle
    final backgroundPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    
    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);
    
    // Draw segments
    double startAngle = -math.pi / 2; // Start from the top
    
    for (int i = 0; i < percentages.length; i++) {
      final segmentPaint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      
      // Calculate sweep angle based on percentage and animation
      final sweepAngle = 2 * math.pi * (percentages[i] / 100) * animationValue;
      
      // Draw arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        segmentPaint,
      );
      
      // Move start angle for next segment
      startAngle += sweepAngle;
    }
  }
  
  @override
  bool shouldRepaint(DonutChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.percentages != percentages ||
           oldDelegate.colors != colors;
  }
}

// Grid lines painter
class GridPainter extends CustomPainter {
  final double height;
  
  GridPainter({required this.height});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 1;
    
    // Draw 5 horizontal lines
    for (int i = 0; i < 5; i++) {
      final y = height - (i * height / 4);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return oldDelegate.height != height;
  }
}

class DailyRevenueData {
  final DateTime date;
  final double totalRevenue;
  final double fuelSalesRevenue;
  final double otherRevenue;
  final Map<String, double> paymentBreakdown;
  
  DailyRevenueData({
    required this.date,
    required this.totalRevenue,
    required this.fuelSalesRevenue,
    required this.otherRevenue,
    required this.paymentBreakdown,
  });
  
  factory DailyRevenueData.fromJson(Map<String, dynamic> json) {
    // Convert payment breakdown to Map<String, double>
    final Map<String, dynamic> paymentJson = json['paymentBreakdown'] ?? {};
    final Map<String, double> paymentBreakdown = {};
    
    paymentJson.forEach((key, value) {
      paymentBreakdown[key] = double.parse(value.toString());
    });
    
    return DailyRevenueData(
      date: DateTime.parse(json['date']),
      totalRevenue: double.parse(json['totalRevenue'].toString()),
      fuelSalesRevenue: double.parse(json['fuelSalesRevenue'].toString()),
      otherRevenue: double.parse(json['otherRevenue'].toString()),
      paymentBreakdown: paymentBreakdown,
    );
  }
} 