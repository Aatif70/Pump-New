import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import '../../api/shift_sales_repository.dart';
import '../../theme.dart';
import 'shift_detail_screen.dart';

class AllShiftsScreen extends StatefulWidget {
  const AllShiftsScreen({Key? key}) : super(key: key);

  @override
  State<AllShiftsScreen> createState() => _AllShiftsScreenState();
}

class _AllShiftsScreenState extends State<AllShiftsScreen> with SingleTickerProviderStateMixin {
  final ShiftSalesRepository _repository = ShiftSalesRepository();
  List<dynamic>? _shiftsData;
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
    
    _fetchAllShifts();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _fetchAllShifts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // For now, use a sample shift ID to get shift data
      // This should be replaced with an endpoint that returns all shifts
      final response = await _repository.getShiftSales("all");
      
      if (mounted) {
        if (response.success && response.data != null) {
          setState(() {
            _shiftsData = response.data;
            _isLoading = false;
          });
          
          // Start fade-in animation when data is loaded
          _animationController.forward();
          
          developer.log('AllShiftsScreen: Successfully fetched shifts data');
        } else {
          setState(() {
            _errorMessage = response.errorMessage ?? 'Failed to load shifts data';
            _isLoading = false;
          });
          
          developer.log('AllShiftsScreen: Error getting shifts data: $_errorMessage');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
      
      developer.log('AllShiftsScreen: Exception: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'All Shifts',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAllShifts,
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
                    'Loading shifts data...',
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
              : _buildShiftsContent(),
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
              onPressed: _fetchAllShifts,
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
  
  Widget _buildShiftsContent() {
    if (_shiftsData == null || _shiftsData!.isEmpty) {
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
              'No shifts data available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }
    
    // Group shifts by number
    Map<int, List<dynamic>> shiftGroups = {};
    for (var shift in _shiftsData!) {
      final int shiftNumber = shift['shiftNumber'] ?? 0;
      
      if (!shiftGroups.containsKey(shiftNumber)) {
        shiftGroups[shiftNumber] = [];
      }
      
      shiftGroups[shiftNumber]!.add(shift);
    }
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Text(
            'Shift Performance',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          ...shiftGroups.entries.map((entry) {
            final shiftNumber = entry.key;
            final shifts = entry.value;
            
            // Calculate totals for this shift number
            double totalAmount = 0.0;
            double totalLiters = 0.0;
            
            for (var shift in shifts) {
              totalAmount += shift['totalAmount']?.toDouble() ?? 0.0;
              totalLiters += shift['litersSold']?.toDouble() ?? 0.0;
            }
            
            return _buildShiftCard(
              shiftNumber, 
              shifts.length, 
              totalAmount, 
              totalLiters,
              shifts.first['shiftId'] ?? '',
            );
          }).toList(),
        ],
      ),
    );
  }
  
  Widget _buildShiftCard(int shiftNumber, int count, double totalAmount, double totalLiters, String shiftId) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          if (shiftId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ShiftDetailScreen(
                  shiftId: shiftId,
                  shiftName: 'Shift $shiftNumber',
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$shiftNumber',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shift $shiftNumber',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '$count transactions',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Total Sales',
                      '₹${totalAmount.toStringAsFixed(0)}',
                      Icons.currency_rupee,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Volume Sold',
                      '${totalLiters.toStringAsFixed(0)} L',
                      Icons.local_gas_station,
                      Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Avg Price',
                      totalLiters > 0 
                          ? '₹${(totalAmount / totalLiters).toStringAsFixed(2)}'
                          : '₹0.00',
                      Icons.calculate,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMetricItem(String label, String value, IconData icon, MaterialColor color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color.shade700),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color.shade700,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
} 