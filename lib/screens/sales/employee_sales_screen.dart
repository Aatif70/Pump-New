import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import '../../api/shift_sales_repository.dart';
import '../../theme.dart';

class EmployeeSalesScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const EmployeeSalesScreen({
    Key? key,
    required this.employeeId,
    required this.employeeName,
  }) : super(key: key);

  @override
  State<EmployeeSalesScreen> createState() => _EmployeeSalesScreenState();
}

class _EmployeeSalesScreenState extends State<EmployeeSalesScreen> with SingleTickerProviderStateMixin {
  final ShiftSalesRepository _repository = ShiftSalesRepository();
  List<dynamic>? _salesData;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Animation controller for staggered list animations
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fetchEmployeeSales();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _fetchEmployeeSales() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final response = await _repository.getEmployeeSales(widget.employeeId);
      
      if (mounted) {
        if (response.success && response.data != null) {
          setState(() {
            _salesData = response.data;
            _isLoading = false;
          });
          
          // Start animation after data is loaded
          _animationController.forward();
          
          developer.log('EmployeeSalesScreen: Successfully fetched sales data');
        } else {
          setState(() {
            _errorMessage = response.errorMessage ?? 'Failed to load employee sales data';
            _isLoading = false;
          });
          
          developer.log('EmployeeSalesScreen: Error getting sales data: $_errorMessage');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
      
      developer.log('EmployeeSalesScreen: Exception: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          '${widget.employeeName}\'s Sales',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEmployeeSales,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryBlue),
                  SizedBox(height: 16),
                  Text(
                    'Loading sales data...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorView()
              : _buildSalesContent(),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[300],
            ),
            SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchEmployeeSales,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSalesContent() {
    if (_salesData == null || _salesData!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No sales data available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }
    
    // Calculate summary metrics
    double totalAmount = 0.0;
    double totalLiters = 0.0;
    int totalTransactions = _salesData!.length;
    Map<String, double> fuelTypeVolumes = {};
    Map<String, double> fuelTypeAmounts = {};
    
    for (var sale in _salesData!) {
      double saleAmount = sale['totalAmount']?.toDouble() ?? 0.0;
      double saleLiters = sale['litersSold']?.toDouble() ?? 0.0;
      String fuelType = sale['fuelType'] ?? 'Unknown';
      
      totalAmount += saleAmount;
      totalLiters += saleLiters;
      
      // Track fuel type totals
      if (!fuelTypeVolumes.containsKey(fuelType)) {
        fuelTypeVolumes[fuelType] = 0.0;
        fuelTypeAmounts[fuelType] = 0.0;
      }
      
      fuelTypeVolumes[fuelType] = (fuelTypeVolumes[fuelType] ?? 0.0) + saleLiters;
      fuelTypeAmounts[fuelType] = (fuelTypeAmounts[fuelType] ?? 0.0) + saleAmount;
    }
    
    return Column(
      children: [
        _buildSummarySection(totalAmount, totalLiters, totalTransactions),
        
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sales History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        
        Expanded(
          child: _buildSalesList(),
        ),
      ],
    );
  }
  
  Widget _buildSummarySection(double totalAmount, double totalLiters, int totalTransactions) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildEmployeeHeader(),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Sales',
                    '₹${totalAmount.toStringAsFixed(0)}',
                    Icons.currency_rupee,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Volume Sold',
                    '${totalLiters.toStringAsFixed(0)} L',
                    Icons.local_gas_station,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Transactions',
                    '$totalTransactions',
                    Icons.receipt_long,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmployeeHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(
              widget.employeeName.isNotEmpty ? widget.employeeName[0].toUpperCase() : '?',
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.employeeName,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),

            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryItem(String title, String value, IconData icon, MaterialColor color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color.shade600, size: 24),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color.shade700,
          ),
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildSalesList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: _salesData!.length,
      itemBuilder: (context, index) {
        final sale = _salesData![index];
        
        // Create staggered animation for each item
        final Animation<double> animation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index / _salesData!.length * 0.5, // Stagger across first half of animation
            0.5 + index / _salesData!.length * 0.5, // End during second half
            curve: Curves.easeOut,
          ),
        );
        
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0.2, 0),
              end: Offset.zero,
            ).animate(animation),
            child: _buildSaleCard(sale),
          ),
        );
      },
    );
  }
  
  Widget _buildSaleCard(Map<String, dynamic> sale) {
    final DateTime saleDate = sale['reportedAt'] != null
        ? DateTime.parse(sale['reportedAt'])
        : DateTime.now();
    final String formattedDate = DateFormat('MMM dd, yyyy').format(saleDate);
    final String formattedTime = DateFormat('hh:mm a').format(saleDate);
    
    final double amount = sale['totalAmount']?.toDouble() ?? 0.0;
    final double liters = sale['litersSold']?.toDouble() ?? 0.0;
    final String fuelType = sale['fuelType'] ?? 'Unknown';
    final int? dispenserNumber = sale['dispenserNumber'];
    final int? nozzleNumber = sale['nozzleNumber'];
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fuelType,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      if (dispenserNumber != null && nozzleNumber != null)
                        Text(
                          'Dispenser #$dispenserNumber, Nozzle #$nozzleNumber',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      SizedBox(height: 8),
                      Text(
                        '${liters.toStringAsFixed(2)} liters',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
            
            // Payment breakdown if available
            if (sale['cashAmount'] != null || sale['creditCardAmount'] != null || sale['upiAmount'] != null) ...[
              SizedBox(height: 16),
              Divider(height: 1),
              SizedBox(height: 12),
              Text(
                'Payment Breakdown',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (sale['cashAmount'] != null && sale['cashAmount'] > 0)
                    _buildPaymentChip(
                      'Cash',
                      sale['cashAmount'].toDouble(),
                      Icons.money,
                      Colors.green,
                    ),
                  if (sale['creditCardAmount'] != null && sale['creditCardAmount'] > 0)
                    _buildPaymentChip(
                      'Card',
                      sale['creditCardAmount'].toDouble(),
                      Icons.credit_card,
                      Colors.blue,
                    ),
                  if (sale['upiAmount'] != null && sale['upiAmount'] > 0)
                    _buildPaymentChip(
                      'UPI',
                      sale['upiAmount'].toDouble(),
                      Icons.phone_android,
                      Colors.purple,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildPaymentChip(String label, double amount, IconData icon, MaterialColor color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.shade700),
          SizedBox(width: 4),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }
} 