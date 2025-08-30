import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import '../../api/shift_sales_repository.dart';
import '../../theme.dart';

class ShiftDetailScreen extends StatefulWidget {
  final String shiftId;
  final String shiftName;

  const ShiftDetailScreen({
    Key? key,
    required this.shiftId,
    required this.shiftName,
  }) : super(key: key);

  @override
  State<ShiftDetailScreen> createState() => _ShiftDetailScreenState();
}

class _ShiftDetailScreenState extends State<ShiftDetailScreen> with SingleTickerProviderStateMixin {
  final ShiftSalesRepository _repository = ShiftSalesRepository();
  Map<String, dynamic>? _shiftData;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Animation controller for fade in effects
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _fetchShiftDetails();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _fetchShiftDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final response = await _repository.getShiftSummary(widget.shiftId);
      
      if (mounted) {
        if (response.success && response.data != null) {
          setState(() {
            _shiftData = response.data;
            _isLoading = false;
          });
          
          // Start fade-in animation when data is loaded
          _animationController.forward();
          
          developer.log('ShiftDetailScreen: Successfully fetched shift details');
        } else {
          setState(() {
            _errorMessage = response.errorMessage ?? 'Failed to load shift details';
            _isLoading = false;
          });
          
          developer.log('ShiftDetailScreen: Error getting shift details: $_errorMessage');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
      
      developer.log('ShiftDetailScreen: Exception: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.shiftName,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchShiftDetails,
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
                    'Loading shift details...',
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
              : _buildShiftDetailContent(),
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
              onPressed: _fetchShiftDetails,
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
  
  Widget _buildShiftDetailContent() {
    if (_shiftData == null) {
      return Center(child: Text('No data available'));
    }
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            _buildSummaryCard(),
            
            SizedBox(height: 24),
            
            // Sales by Fuel Type
            _buildSectionHeader('Sales by Fuel Type', Icons.local_gas_station),
            SizedBox(height: 12),
            _buildFuelTypeList(),
            
            SizedBox(height: 24),
            
            // Payment Methods
            _buildSectionHeader('Payment Methods', Icons.payment),
            SizedBox(height: 12),
            _buildPaymentMethodsList(),
            
            SizedBox(height: 24),
            
            // Employee Performance
            _buildSectionHeader('Employee Performance', Icons.people),
            SizedBox(height: 12),
            _buildEmployeeList(),
            
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryCard() {
    final totalSales = _shiftData!['totalAmount']?.toDouble() ?? 0.0;
    final totalLiters = _shiftData!['totalLitersSold']?.toDouble() ?? 0.0;
    final totalTransactions = _shiftData!['totalTransactions'] ?? 0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shift Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Sales',
                    '₹${totalSales.toStringAsFixed(2)}',
                    Icons.currency_rupee,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Volume Sold',
                    '${totalLiters.toStringAsFixed(2)} L',
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
          ],
        ),
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
  
  Widget _buildFuelTypeList() {
    final fuelTypes = _shiftData!['salesByFuelType'];
    
    if (fuelTypes == null || (fuelTypes is List && fuelTypes.isEmpty) || (fuelTypes is Map && fuelTypes.isEmpty)) {
      return Card(
        elevation: 0,
        color: Colors.grey[100],
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No fuel type data available'),
        ),
      );
    }
    
    List<Widget> fuelTypeWidgets = [];
    
    if (fuelTypes is List) {
      for (var fuelType in fuelTypes) {
        fuelTypeWidgets.add(
          _buildFuelTypeCard(
            fuelType['fuelType'] ?? 'Unknown',
            fuelType['litersSold']?.toDouble() ?? 0.0,
            fuelType['totalAmount']?.toDouble() ?? 0.0,
          ),
        );
      }
    } else if (fuelTypes is Map) {
      fuelTypes.forEach((key, value) {
        fuelTypeWidgets.add(
          _buildFuelTypeCard(
            key.toString(),
            value['litersSold']?.toDouble() ?? 0.0,
            value['amount']?.toDouble() ?? 0.0,
          ),
        );
      });
    }
    
    return Column(
      children: fuelTypeWidgets.isEmpty
          ? [
              Card(
                elevation: 0,
                color: Colors.grey[100],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No fuel type data available'),
                ),
              )
            ]
          : fuelTypeWidgets,
    );
  }
  
  Widget _buildFuelTypeCard(String fuelType, double litersSold, double amount) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.local_gas_station, color: Colors.amber.shade700),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fuelType,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${litersSold.toStringAsFixed(2)} liters',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPaymentMethodsList() {
    final cashAmount = _shiftData!['cashAmount']?.toDouble() ?? 
                      (_shiftData!['salesByPaymentMethod']?['cash']?.toDouble() ?? 0.0);
    
    final cardAmount = _shiftData!['creditCardAmount']?.toDouble() ?? 
                      (_shiftData!['salesByPaymentMethod']?['creditCard']?.toDouble() ?? 0.0);
    
    final upiAmount = _shiftData!['upiAmount']?.toDouble() ?? 
                     (_shiftData!['salesByPaymentMethod']?['upi']?.toDouble() ?? 0.0);
    
    final totalAmount = cashAmount + cardAmount + upiAmount;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildPaymentProgressBar(
              'Cash',
              cashAmount,
              totalAmount,
              Colors.blue,
            ),
            SizedBox(height: 16),
            _buildPaymentProgressBar(
              'Credit Card',
              cardAmount,
              totalAmount,
              Colors.green,
            ),
            SizedBox(height: 16),
            _buildPaymentProgressBar(
              'UPI',
              upiAmount,
              totalAmount,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPaymentProgressBar(String label, double amount, double total, MaterialColor color) {
    final percentage = total > 0 ? (amount / total * 100) : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '₹${amount.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color.shade700,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            color: color.shade500,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmployeeList() {
    final employees = _shiftData!['salesByEmployee'];
    
    if (employees == null || (employees is List && employees.isEmpty)) {
      return Card(
        elevation: 0,
        color: Colors.grey[100],
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No employee data available'),
        ),
      );
    }
    
    List<Widget> employeeWidgets = [];
    
    if (employees is List) {
      for (var employee in employees) {
        employeeWidgets.add(
          _buildEmployeeCard(
            employee['employeeName'] ?? 'Unknown',
            employee['employeeId'] ?? '',
            employee['litersSold']?.toDouble() ?? 0.0,
            employee['totalAmount']?.toDouble() ?? 0.0,
          ),
        );
      }
    }
    
    return Column(
      children: employeeWidgets.isEmpty
          ? [
              Card(
                elevation: 0,
                color: Colors.grey[100],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No employee data available'),
                ),
              )
            ]
          : employeeWidgets,
    );
  }
  
  Widget _buildEmployeeCard(String name, String id, double litersSold, double amount) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.purple.shade100,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.purple.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${litersSold.toStringAsFixed(2)} liters',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
} 