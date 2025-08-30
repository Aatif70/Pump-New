import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/shift_sales_repository.dart';
import '../../models/shift_sale_model.dart';
import '../../theme.dart';

class ShiftSalesHistoryScreen extends StatefulWidget {
  final String employeeId;

  const ShiftSalesHistoryScreen({
    Key? key,
    required this.employeeId,
  }) : super(key: key);

  @override
  State<ShiftSalesHistoryScreen> createState() => _ShiftSalesHistoryScreenState();
}

class _ShiftSalesHistoryScreenState extends State<ShiftSalesHistoryScreen> {
  final ShiftSalesRepository _repository = ShiftSalesRepository();
  List<ShiftSale> _shiftSales = [];
  List<ShiftSale> _filteredSales = [];
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Date range filter
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  
  // Summary data
  double _totalSales = 0;
  double _totalLiters = 0;
  Map<String, double> _salesByFuelType = {};
  Map<String, double> _litersByFuelType = {};

  @override
  void initState() {
    super.initState();
    _fetchShiftSales();
  }
  
  Future<void> _fetchShiftSales() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final response = await _repository.getShiftSalesByEmployee(widget.employeeId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          
          if (response.success && response.data != null) {
            _shiftSales = response.data!;
            
            // Sort by date, newest first
            _shiftSales.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
            
            // Apply date filter
            _applyDateFilter();
            
            developer.log('Loaded ${_shiftSales.length} shift sales');
          } else {
            _errorMessage = response.errorMessage ?? 'Failed to load shift sales';
            developer.log('Error loading shift sales: $_errorMessage');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: $e';
          developer.log('Exception in _fetchShiftSales: $e');
        });
      }
    }
  }
  
  void _applyDateFilter() {
    // Filter sales based on selected date range
    _filteredSales = _shiftSales.where((sale) {
      // Set time to start of day for start date and end of day for end date for accurate comparison
      final startDateWithTime = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final endDateWithTime = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      
      return sale.reportedAt.isAfter(startDateWithTime) && 
             sale.reportedAt.isBefore(endDateWithTime.add(const Duration(seconds: 1)));
    }).toList();
    
    // Recalculate summary based on filtered data
    _calculateSummary();
  }
  
  void _calculateSummary() {
    double totalSales = 0;
    double totalLiters = 0;
    Map<String, double> salesByFuelType = {};
    Map<String, double> litersByFuelType = {};
    
    // Use filtered sales for calculations
    for (var sale in _filteredSales) {
      totalSales += sale.totalAmount;
      totalLiters += sale.litersSold;
      
      // Track by fuel type (keeping for data purposes, but not showing in UI)
      if (sale.fuelType.isNotEmpty) {
        salesByFuelType[sale.fuelType] = (salesByFuelType[sale.fuelType] ?? 0) + sale.totalAmount;
        litersByFuelType[sale.fuelType] = (litersByFuelType[sale.fuelType] ?? 0) + sale.litersSold;
      }
    }
    
    setState(() {
      _totalSales = totalSales;
      _totalLiters = totalLiters;
      _salesByFuelType = salesByFuelType;
      _litersByFuelType = litersByFuelType;
    });
  }
  
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2021),
      lastDate: _endDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
      _applyDateFilter(); // Apply filter when date changes
    }
  }
  
  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
      _applyDateFilter(); // Apply filter when date changes
    }
  }

  void _showDateFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.date_range, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Select Date Range',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Date',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _selectStartDate(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: AppTheme.primaryBlue),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('MMM d, yyyy').format(_startDate),
                                  style: const TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End Date',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _selectEndDate(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: AppTheme.primaryBlue),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('MMM d, yyyy').format(_endDate),
                                  style: const TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Quick filter buttons
                  _buildQuickFilterChip('Last 7 days', () {
                    setState(() {
                      _endDate = DateTime.now();
                      _startDate = _endDate.subtract(const Duration(days: 7));
                    });
                    _applyDateFilter();
                    Navigator.pop(context);
                  }),
                  const SizedBox(width: 8),
                  _buildQuickFilterChip('Last 30 days', () {
                    setState(() {
                      _endDate = DateTime.now();
                      _startDate = _endDate.subtract(const Duration(days: 30));
                    });
                    _applyDateFilter();
                    Navigator.pop(context);
                  }),
                  const SizedBox(width: 8),
                  _buildQuickFilterChip('This month', () {
                    final now = DateTime.now();
                    setState(() {
                      _endDate = now;
                      _startDate = DateTime(now.year, now.month, 1);
                    });
                    _applyDateFilter();
                    Navigator.pop(context);
                  }),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _applyDateFilter();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Apply Filter'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildQuickFilterChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryBlue.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppTheme.primaryBlue,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Sales History'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Change Date Range',
            onPressed: () => _showDateFilterBottomSheet(context),
            color: Colors.white,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchShiftSales,
            color: Colors.white,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d').format(_endDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filteredSales.length} Records',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchShiftSales,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary section with date filter
                  _buildSummarySection(),
                  
                  // Sales list
                  Expanded(
                    child: _errorMessage.isNotEmpty
                        ? _buildErrorMessage()
                        : _shiftSales.isEmpty
                            ? _buildEmptyState()
                            : _buildSalesList(),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildSummarySection() {
    // Currency formatter
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date range selectors
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Icon(Icons.insights, color: Colors.white.withOpacity(0.9), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Sales Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectStartDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today, 
                            size: 14, 
                            color: Colors.white.withOpacity(0.9)
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'From',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                              Text(
                                DateFormat('MMM d, yyyy').format(_startDate),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectEndDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today, 
                            size: 14, 
                            color: Colors.white.withOpacity(0.9)
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'To',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                              Text(
                                DateFormat('MMM d, yyyy').format(_endDate),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Summary cards
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
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
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.currency_rupee, 
                                color: Colors.green.shade700, 
                                size: 14
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Total Sales',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormat.format(_totalSales),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
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
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.local_gas_station, 
                                color: Colors.orange.shade700, 
                                size: 14
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Total Volume',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _totalLiters.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 1),
                              child: Text(
                                'Liters',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
  
  Widget _buildSalesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSales.length,
      itemBuilder: (context, index) {
        final sale = _filteredSales[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          surfaceTintColor: Colors.white,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                // Header with date
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.06),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 16,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('EEEE, d MMM yyyy • h:mm a').format(sale.reportedAt),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getFuelTypeColor(sale.fuelType).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          sale.fuelType,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _getFuelTypeColor(sale.fuelType),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Employee, Shift, and Dispenser info
                      Row(
                        children: [
                          _buildInfoChip(
                            label: 'Employee',
                            value: sale.employeeName,
                            icon: Icons.person,
                            color: Colors.indigo,
                          ),
                          _buildInfoChip(
                            label: 'Shift',
                            value: '#${sale.shiftNumber}',
                            icon: Icons.access_time_filled,
                            color: Colors.teal,
                          ),
                          _buildInfoChip(
                            label: 'Dispenser',
                            value: '#${sale.dispenserNumber}',
                            icon: Icons.ev_station,
                            color: Colors.amber,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Sales amounts
                      Row(
                        children: [
                          Expanded(
                            child: _buildAmountCard(
                              label: 'Total Sales',
                              amount: '₹ ${sale.totalAmount.toStringAsFixed(2)}',
                              icon: Icons.currency_rupee,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildAmountCard(
                              label: 'Volume Sold',
                              amount: '${sale.litersSold.toStringAsFixed(2)} L',
                              icon: Icons.local_gas_station,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      
                      // Payment breakdown
                      if (sale.cashAmount != null || sale.creditCardAmount != null || sale.upiAmount != null) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Payment Breakdown',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (sale.cashAmount != null && sale.cashAmount! > 0)
                              Expanded(
                                child: _buildPaymentMethod(
                                  label: 'Cash',
                                  amount: '₹ ${sale.cashAmount!.toStringAsFixed(2)}',
                                  icon: Icons.money,
                                  color: Colors.green,
                                ),
                              ),
                            if (sale.creditCardAmount != null && sale.creditCardAmount! > 0)
                              Expanded(
                                child: _buildPaymentMethod(
                                  label: 'Card',
                                  amount: '₹ ${sale.creditCardAmount!.toStringAsFixed(2)}',
                                  icon: Icons.credit_card,
                                  color: Colors.blue,
                                ),
                              ),
                            if (sale.upiAmount != null && sale.upiAmount! > 0)
                              Expanded(
                                child: _buildPaymentMethod(
                                  label: 'UPI',
                                  amount: '₹ ${sale.upiAmount!.toStringAsFixed(2)}',
                                  icon: Icons.phone_android,
                                  color: Colors.purple,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip({
    required String label,
    required String value,
    required IconData icon,
    required MaterialColor color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.shade50.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.shade100.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: color.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(icon, size: 12, color: color.shade600),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard({
    required String label,
    required String amount,
    required IconData icon,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade100),
        boxShadow: [
          BoxShadow(
            color: color.shade100.withOpacity(0.5),
            blurRadius: 4,
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
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color.shade600),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod({
    required String label,
    required String amount,
    required IconData icon,
    required MaterialColor color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: color.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 10, color: color.shade600),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long,
                size: 72,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Sales Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Try changing the date range to find more sales records.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _selectStartDate(context),
              icon: const Icon(Icons.date_range),
              label: const Text('Change Date Range'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchShiftSales,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getFuelTypeColor(String fuelType) {
    switch (fuelType.toLowerCase()) {
      case 'petrol':
      case 'premium petrol':
        return Colors.green.shade600;
      case 'diesel':
      case 'premium diesel':
        return Colors.blue.shade600;
      case 'cng':
        return Colors.teal.shade600;
      case 'lpg':
        return Colors.purple.shade600;
      default:
        return Colors.orange.shade600;
    }
  }
} 
