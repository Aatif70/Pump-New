import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../api/shift_sales_repository.dart';
import '../../models/shift_sales_model.dart';
import '../../theme.dart';

class ShiftSalesScreen extends StatefulWidget {
  final String employeeId;

  const ShiftSalesScreen({
    Key? key,
    required this.employeeId,
  }) : super(key: key);

  @override
  State<ShiftSalesScreen> createState() => _ShiftSalesScreenState();
}

class _ShiftSalesScreenState extends State<ShiftSalesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cashAmountController = TextEditingController();
  final _creditCardAmountController = TextEditingController();
  final _upiAmountController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _litersSoldController = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';
  bool _autoCalculateTotal = true;
  
  // For debugging
  final List<String> _debugLog = [];
  bool _showDebugInfo = false;

  @override
  void initState() {
    super.initState();
    _addDebugLog('Screen initialized');
    _addDebugLog('Employee ID: ${widget.employeeId}');
  }
  
  void _addDebugLog(String message) {
    setState(() {
      _debugLog.add('[${DateTime.now().toIso8601String()}] $message');
      developer.log('DEBUG: $message');
    });
  }

  @override
  void dispose() {
    _cashAmountController.dispose();
    _creditCardAmountController.dispose();
    _upiAmountController.dispose();
    _totalAmountController.dispose();
    _litersSoldController.dispose();
    super.dispose();
  }

  void _updateTotal() {
    if (!_autoCalculateTotal) return;
    
    double cash = double.tryParse(_cashAmountController.text) ?? 0;
    double card = double.tryParse(_creditCardAmountController.text) ?? 0;
    double upi = double.tryParse(_upiAmountController.text) ?? 0;
    
    double total = cash + card + upi;
    _totalAmountController.text = total.toStringAsFixed(2);
    _addDebugLog('Updated total amount: $total');
  }

  Future<void> _submitShiftSales() async {
    if (!_formKey.currentState!.validate()) {
      _addDebugLog('Form validation failed');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    _addDebugLog('Starting submission process');
    
    try {
      final shiftSales = ShiftSales(
        cashAmount: double.parse(_cashAmountController.text),
        creditCardAmount: double.parse(_creditCardAmountController.text),
        upiAmount: double.parse(_upiAmountController.text),
        totalAmount: double.parse(_totalAmountController.text),
        litersSold: double.parse(_litersSoldController.text),
        employeeId: widget.employeeId,
        shiftId: 'MISSING!',
        fuelDispenserId: 'MISSING!',
        nozzleId: 'MISSING!',
        pricePerLiter: 0.0,
        petrolPumpId: null,
        fuelTypeId: null,
      );
      
      _addDebugLog('Created ShiftSales object: ${shiftSales.toJson()}');
      
      final repository = ShiftSalesRepository();
      final response = await repository.submitShiftSales(shiftSales);
      
      setState(() {
        _isLoading = false;
      });
      
      if (response.success) {
        _addDebugLog('Submission successful');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shift sales submitted successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Navigate back to dashboard (pop twice - once for this screen, once for nozzle reading screen)
          Navigator.of(context).pop(true); // Return success to nozzle reading screen
          Navigator.of(context).pop(true); // Return to dashboard or previous screen
        }
      } else {
        _addDebugLog('Submission failed: ${response.errorMessage}');
        setState(() {
          _errorMessage = response.errorMessage ?? 'Failed to submit shift sales';
        });
        _showErrorDialog(_errorMessage);
      }
    } catch (e) {
      _addDebugLog('Exception during submission: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
      _showErrorDialog(_errorMessage);
    }
  }



  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Failed to Submit. Please Try Again.'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                errorMessage,
                style: TextStyle(color: Colors.red.shade800, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Sales Summary'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Debug menu button
          IconButton(
            icon: Icon(Icons.bug_report),
            onPressed: () {
              setState(() {
                _showDebugInfo = !_showDebugInfo;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_showDebugInfo ? 'Debug mode enabled' : 'Debug mode disabled'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Toggle Debug Info',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Submitting shift sales...',
                    style: TextStyle(color: AppTheme.primaryBlue),
                  ),
                ],
              ))
          : SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blue.shade50, Colors.white],
                    stops: [0.0, 0.3],
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header card
                        _buildHeaderCard(),
                        
                        const SizedBox(height: 20),
                        
                        // Information Section
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: AppTheme.primaryBlue),
                                  SizedBox(width: 8),
                                  Text(
                                    'Sales Summary Submission',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Please enter the sales details for your shift. The total amount will be calculated automatically, '
                                'but you can adjust it if needed.',
                                style: TextStyle(color: Colors.grey.shade800),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Main Form Container
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha:0.05),
                                blurRadius: 10,
                                spreadRadius: 0,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Liters Sold
                              Text(
                                'LITERS SOLD',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              SizedBox(height: 8),
                              TextFormField(
                                controller: _litersSoldController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                ],
                                style: TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'Enter liters sold',
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: AppTheme.primaryBlue),
                                  ),
                                  prefixIcon: Icon(Icons.local_gas_station, color: AppTheme.primaryBlue),
                                  suffixText: 'liters',
                                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter liters sold';
                                  }
                                  
                                  final number = double.tryParse(value);
                                  if (number == null) {
                                    return 'Please enter a valid number';
                                  }
                                  
                                  if (number < 0) {
                                    return 'Value must be positive';
                                  }
                                  
                                  return null;
                                },
                              ),
                              
                              SizedBox(height: 20),
                              
                              // Payment Amounts Section Header
                              Text(
                                'PAYMENT AMOUNTS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              SizedBox(height: 8),
                              
                              // Cash Amount
                              TextFormField(
                                controller: _cashAmountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                ],
                                style: TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'Enter cash amount',
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: AppTheme.primaryBlue),
                                  ),
                                  prefixIcon: Icon(Icons.money, color: Colors.green.shade700),
                                  prefixText: '₹ ',
                                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                ),
                                onChanged: (_) => _updateTotal(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter cash amount';
                                  }
                                  
                                  final number = double.tryParse(value);
                                  if (number == null) {
                                    return 'Please enter a valid number';
                                  }
                                  
                                  if (number < 0) {
                                    return 'Amount must be positive';
                                  }
                                  
                                  return null;
                                },
                              ),
                              
                              SizedBox(height: 16),
                              
                              // Credit Card Amount
                              TextFormField(
                                controller: _creditCardAmountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                ],
                                style: TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'Enter credit card amount',
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: AppTheme.primaryBlue),
                                  ),
                                  prefixIcon: Icon(Icons.credit_card, color: Colors.blue.shade700),
                                  prefixText: '₹ ',
                                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                ),
                                onChanged: (_) => _updateTotal(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter credit card amount';
                                  }
                                  
                                  final number = double.tryParse(value);
                                  if (number == null) {
                                    return 'Please enter a valid number';
                                  }
                                  
                                  if (number < 0) {
                                    return 'Amount must be positive';
                                  }
                                  
                                  return null;
                                },
                              ),
                              
                              SizedBox(height: 16),
                              
                              // UPI Amount
                              TextFormField(
                                controller: _upiAmountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                ],
                                style: TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'Enter UPI amount',
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: AppTheme.primaryBlue),
                                  ),
                                  prefixIcon: Icon(Icons.phone_android, color: Colors.purple.shade700),
                                  prefixText: '₹ ',
                                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                ),
                                onChanged: (_) => _updateTotal(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter UPI amount';
                                  }
                                  
                                  final number = double.tryParse(value);
                                  if (number == null) {
                                    return 'Please enter a valid number';
                                  }
                                  
                                  if (number < 0) {
                                    return 'Amount must be positive';
                                  }
                                  
                                  return null;
                                },
                              ),
                              
                              SizedBox(height: 24),
                              
                              // Auto calculate total switch
                              Row(
                                children: [
                                  Switch(
                                    value: _autoCalculateTotal,
                                    onChanged: (value) {
                                      setState(() {
                                        _autoCalculateTotal = value;
                                        if (value) {
                                          _updateTotal();
                                        }
                                      });
                                    },
                                    activeColor: AppTheme.primaryBlue,
                                  ),
                                  Text(
                                    'Auto-calculate total',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: 16),
                              
                              // Total Amount
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha:0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TOTAL AMOUNT',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    TextFormField(
                                      controller: _totalAmountController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                      ],
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: AppTheme.primaryBlue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Total amount',
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: AppTheme.primaryBlue),
                                        ),
                                        prefixIcon: Icon(Icons.calculate, color: AppTheme.primaryBlue),
                                        prefixText: '₹ ',
                                        prefixStyle: TextStyle(
                                          color: AppTheme.primaryBlue,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                      ),
                                      enabled: !_autoCalculateTotal,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter total amount';
                                        }
                                        
                                        final number = double.tryParse(value);
                                        if (number == null) {
                                          return 'Please enter a valid number';
                                        }
                                        
                                        if (number < 0) {
                                          return 'Amount must be positive';
                                        }
                                        
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Debug info section
                        if (_showDebugInfo)
                          _buildDebugSection(),
                          
                        SizedBox(height: 24),
                        
                        // Submit Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withValues(alpha:0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _submitShiftSales,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'SUBMIT SHIFT SALES',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                        
                        if (_errorMessage.isNotEmpty)
                          _buildErrorMessage(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    // Format date for display
    String formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue.withValues(alpha:0.8),
              AppTheme.primaryBlue,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monetization_on,
                  color: Colors.white.withValues(alpha:0.9),
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'End of Shift Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildHeaderInfoItem(
              title: 'DATE',
              value: formattedDate,
            ),
            SizedBox(height: 8),
            _buildHeaderInfoItem(
              title: 'NOZZLE',
              value: '#${'-'} (${'Unknown'})',
            ),
            if ('MISSING!' != null)
              _buildHeaderInfoItem(
                title: 'DISPENSER',
                value: '#${'MISSING!'}',
              ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildHeaderInfoItem(
                    title: 'START READING',
                    value: '${'-'} L',
                  ),
                ),
                Expanded(
                  child: _buildHeaderInfoItem(
                    title: 'END READING',
                    value: '${'-'} L',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfoItem({required String title, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha:0.7),
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build debug info section
  Widget _buildDebugSection() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Debug Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    // Refresh debug info
                    _addDebugLog('Debug info refreshed');
                  });
                },
                tooltip: 'Refresh debug info',
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'API Endpoint: ${ShiftSalesRepository().baseUrl}/api/ShiftSales',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          Text(
            'Request Type: POST',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          Divider(),
          Text(
            'Required fields:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            '• employeeId: ${widget.employeeId}',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          Text(
            '• shiftId: ${'MISSING!'}',
            style: TextStyle(
              fontFamily: 'monospace', 
              fontSize: 12,
              color: 'MISSING!' == null ? Colors.red : null,
            ),
          ),
          Text(
            '• nozzleId: ${'MISSING!'}',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          Text(
            '• fuelDispenserId: ${'MISSING!'}',
            style: TextStyle(
              fontFamily: 'monospace', 
              fontSize: 12,
              color: 'MISSING!' == null ? Colors.red : null,
            ),
          ),
          Divider(),
          Text(
            'Form values:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            '• litersSold: ${_litersSoldController.text}',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          Text(
            '• cashAmount: ${_cashAmountController.text}',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          Text(
            '• creditCardAmount: ${_creditCardAmountController.text}',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          Text(
            '• upiAmount: ${_upiAmountController.text}',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          Text(
            '• totalAmount: ${_totalAmountController.text}',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          Divider(),
          Text(
            'Debug Log:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Container(
            height: 150,
            margin: EdgeInsets.only(top: 8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: _debugLog.length,
              reverse: true,
              itemBuilder: (context, index) {
                final logEntry = _debugLog[_debugLog.length - 1 - index];
                return Text(
                  logEntry,
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 