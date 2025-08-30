import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/api_constants.dart';
import '../../api/booklet_repository.dart';
import '../../api/customer_repository.dart';
import '../../models/booklet_model.dart';
import '../../models/customer_model.dart';
import '../../theme.dart';
import 'dart:developer' as developer;

class AddBookletScreen extends StatefulWidget {
  const AddBookletScreen({super.key});

  @override
  State<AddBookletScreen> createState() => _AddBookletScreenState();
}

class _AddBookletScreenState extends State<AddBookletScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _bookletNumberController = TextEditingController();
  final _bookletTypeController = TextEditingController();
  final _customerIdController = TextEditingController();
  final _slipRangeStartController = TextEditingController();
  final _slipRangeEndController = TextEditingController();
  final _totalSlipsController = TextEditingController();
  final _issuedDateController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingCustomers = false;
  String _errorMessage = '';
  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  DateTime _selectedDate = DateTime.now();
  
  // Booklet type options
  final List<String> _bookletTypeOptions = [
    '100-Slip',
    '200-Slip'
  ];

  // TODO: This should come from user session or settings
  final String _pumpId = "9d35666c-852f-4117-9b7e-c62df337feeb";
  
  @override
  void initState() {
    super.initState();
    _bookletTypeController.text = '100-Slip'; // Default value
    _issuedDateController.text = _formatDate(_selectedDate);
    _loadCustomers();
  }
  
  // Dismiss keyboard when tapping outside text fields
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryBlue,
        ),
      ),
    );
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoadingCustomers = true;
    });

    try {
      final repository = CustomerRepository();
      final response = await repository.getAllCustomers();
      
      // Debug print for customer loading
      print('Customer loading response: success=${response.success}, error=${response.errorMessage}');
      if (response.data != null) {
        print('Loaded ${response.data!.length} customers');
        response.data!.forEach((customer) {
          print('Customer: ${customer.customerName} (${customer.customerCode}) - ID: ${customer.customerId}');
        });
      }
      
      if (response.success) {
        setState(() {
          _customers = response.data ?? [];
          _isLoadingCustomers = false;
        });
      } else {
        setState(() {
          _errorMessage = response.errorMessage ?? 'Failed to load customers';
          _isLoadingCustomers = false;
        });
      }
    } catch (e) {
      print('Error loading customers: $e');
      setState(() {
        _errorMessage = 'Error loading customers: $e';
        _isLoadingCustomers = false;
      });
    }
  }
  
  @override
  void dispose() {
    _bookletNumberController.dispose();
    _bookletTypeController.dispose();
    _customerIdController.dispose();
    _slipRangeStartController.dispose();
    _slipRangeEndController.dispose();
    _totalSlipsController.dispose();
    _issuedDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _issuedDateController.text = _formatDate(picked);
      });
    }
  }
  
  // Submit the form
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a customer'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    
    // Recalculate total slips to ensure accuracy before submission
    _calculateTotalSlips();
    
    // Validate that slip range matches total slips
    final start = int.tryParse(_slipRangeStartController.text);
    final end = int.tryParse(_slipRangeEndController.text);
    final total = int.tryParse(_totalSlipsController.text);
    
    if (start != null && end != null && total != null) {
      final expectedTotal = end - start + 1;
      if (total != expectedTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Slip range mismatch: Range $start-$end should have $expectedTotal slips, not $total'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final repository = BookletRepository();
      
      // Create booklet data object
      final bookletData = {
        'bookletNumber': _bookletNumberController.text,
        'bookletType': _bookletTypeController.text,
        'customerId': _selectedCustomer!.customerId,
        'petrolPumpId': _pumpId,
        'slipRangeStart': int.parse(_slipRangeStartController.text),
        'slipRangeEnd': int.parse(_slipRangeEndController.text),
        'totalSlips': int.parse(_totalSlipsController.text),
        'issuedDate': _selectedDate.toIso8601String(),
      };
      
      // Debug prints for form submission
      print('=== BOOKLET FORM SUBMISSION DEBUG ===');
      print('Selected customer: ${_selectedCustomer!.customerName} (${_selectedCustomer!.customerCode})');
      print('Customer ID: ${_selectedCustomer!.customerId}');
      print('Booklet number: ${_bookletNumberController.text}');
      print('Booklet type: ${_bookletTypeController.text}');
      print('Slip range start: ${_slipRangeStartController.text}');
      print('Slip range end: ${_slipRangeEndController.text}');
      print('Total slips: ${_totalSlipsController.text}');
      print('Issued date: ${_selectedDate.toIso8601String()}');
      print('Pump ID: $_pumpId');
      print('Full request body: $bookletData');
      print('Sending POST request to ${ApiConstants.baseUrl}/api/Booklets');
      
      // Call repository to add booklet
      final response = await repository.addBooklet(bookletData);
      
      // Debug print for response
      print('=== BOOKLET API RESPONSE DEBUG ===');
      print('Response success: ${response.success}');
      print('Response error message: ${response.errorMessage}');
      print('Response data: ${response.data}');
      
      if (!mounted) return;
      
      if (response.success) {
        print('Booklet created successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Booklet added successfully'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        
        // Return true to indicate success
        Navigator.pop(context, true);
      } else {
        print('Failed to create booklet: ${response.errorMessage}');
        setState(() {
          _errorMessage = response.errorMessage ?? 'Failed to add booklet';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error submitting form: $e');
      setState(() {
        _errorMessage = e.toString();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _calculateTotalSlips() {
    final startText = _slipRangeStartController.text;
    final endText = _slipRangeEndController.text;
    
    if (startText.isNotEmpty && endText.isNotEmpty) {
      final start = int.tryParse(startText);
      final end = int.tryParse(endText);
      
      if (start != null && end != null && end >= start) {
        final calculatedTotal = end - start + 1;
        _totalSlipsController.text = calculatedTotal.toString();
        print('Auto-calculated total slips: $calculatedTotal (range: $start to $end)');
        
        // Also update the booklet type if it doesn't match
        if (calculatedTotal == 100 && _bookletTypeController.text != '100-Slip') {
          _bookletTypeController.text = '100-Slip';
        } else if (calculatedTotal == 50 && _bookletTypeController.text != '50-Slip') {
          _bookletTypeController.text = '50-Slip';
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add New Booklet'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'New Booklet',
                    style: AppTheme.headingStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add details for the new booklet',
                    style: AppTheme.subheadingStyle.copyWith(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Basic Information Card
                  _buildSectionTitle('Basic Information'),
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha:0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Booklet Number field
                          Text(
                            'Booklet Number',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _bookletNumberController,
                            decoration: InputDecoration(
                              hintText: 'Enter booklet number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                              ),
                              prefixIcon: Icon(Icons.qr_code, color: AppTheme.primaryBlue),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter booklet number';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Booklet Type field
                          Text(
                            'Booklet Type',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                              ),
                              prefixIcon: Icon(Icons.category, color: AppTheme.primaryBlue),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            value: _bookletTypeController.text,
                            items: _bookletTypeOptions.map((String type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _bookletTypeController.text = newValue;
                                  // Auto-calculate total slips based on type
                                  if (newValue == '100-Slip') {
                                    _totalSlipsController.text = '100';
                                  } else if (newValue == '50-Slip') {
                                    _totalSlipsController.text = '50';
                                  }
                                  // Also auto-calculate based on slip range if available
                                  _calculateTotalSlips();
                                });
                              }
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Customer field
                          Text(
                            'Customer',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _isLoadingCustomers
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Loading customers...'),
                                    ],
                                  ),
                                )
                              : DropdownButtonFormField<Customer>(
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                                    ),
                                    prefixIcon: Icon(Icons.person, color: AppTheme.primaryBlue),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  value: _selectedCustomer,
                                  hint: const Text('Select a customer'),
                                  isExpanded: true,
                                  menuMaxHeight: 200,
                                  items: _customers.map((Customer customer) {
                                    return DropdownMenuItem<Customer>(
                                      value: customer,
                                      child: Container(
                                        width: double.infinity,
                                        child: Text(
                                          '${customer.customerName} (${customer.customerCode})',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (Customer? newValue) {
                                    setState(() {
                                      _selectedCustomer = newValue;
                                      if (newValue != null) {
                                        _customerIdController.text = newValue.customerId!;
                                      }
                                    });
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Slip Information Card
                  _buildSectionTitle('Slip Information'),
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha:0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Slip Range Start field
                          Text(
                            'Slip Range Start',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _slipRangeStartController,
                            decoration: InputDecoration(
                              hintText: 'Enter start slip number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                              ),
                              prefixIcon: Icon(Icons.start, color: AppTheme.primaryBlue),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              _calculateTotalSlips();
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter start slip number';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Slip Range End field
                          Text(
                            'Slip Range End',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _slipRangeEndController,
                            decoration: InputDecoration(
                              hintText: 'Enter end slip number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                              ),
                              prefixIcon: Icon(Icons.stop, color: AppTheme.primaryBlue),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              _calculateTotalSlips();
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter end slip number';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              final start = int.tryParse(_slipRangeStartController.text);
                              final end = int.parse(value);
                              if (start != null && end <= start) {
                                return 'End number must be greater than start number';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Total Slips field
                          Text(
                            'Total Slips',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _totalSlipsController,
                            decoration: InputDecoration(
                              hintText: 'Enter total number of slips',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                              ),
                              prefixIcon: Icon(Icons.list_alt, color: AppTheme.primaryBlue),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter total slips';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              if (int.parse(value) <= 0) {
                                return 'Total slips must be greater than 0';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Date Information Card
                  _buildSectionTitle('Date Information'),
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha:0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Issued Date field
                          Text(
                            'Issued Date',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _issuedDateController,
                            decoration: InputDecoration(
                              hintText: 'Select issued date',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                              ),
                              prefixIcon: Icon(Icons.calendar_today, color: AppTheme.primaryBlue),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.date_range),
                                onPressed: () => _selectDate(context),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            readOnly: true,
                            onTap: () => _selectDate(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Error message display
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  
                  // Submit Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_circle_outline),
                                const SizedBox(width: 8),
                                Text(
                                  'Add Booklet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
