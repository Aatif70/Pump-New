import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petrol_pump/api/vehicle_transaction_repository.dart';
import 'package:petrol_pump/models/vehicle_transaction_model.dart';
import 'package:petrol_pump/models/customer_model.dart';
import 'package:petrol_pump/models/fuel_type_model.dart';
import 'package:petrol_pump/theme.dart';
import 'package:petrol_pump/widgets/custom_snackbar.dart' show showCustomSnackBar;
import 'package:intl/intl.dart';

class AddVehicleTransactionScreen extends StatefulWidget {
  final List<Customer> customers;
  final List<FuelType> fuelTypes;
  final String petrolPumpId;

  const AddVehicleTransactionScreen({
    super.key,
    required this.customers,
    required this.fuelTypes,
    required this.petrolPumpId,
  });

  @override
  State<AddVehicleTransactionScreen> createState() => _AddVehicleTransactionScreenState();
}

class _AddVehicleTransactionScreenState extends State<AddVehicleTransactionScreen> {
  final VehicleTransactionRepository _repository = VehicleTransactionRepository();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Form controllers
  final _vehicleNumberController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _litersController = TextEditingController();
  final _pricePerLiterController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _slipNumberController = TextEditingController();
  final _notesController = TextEditingController();

  // Form state
  String? _selectedCustomerId;
  String? _selectedFuelTypeId;
  String _selectedPaymentMode = 'Cash';
  DateTime _selectedDate = DateTime.now();
  bool _validateCreditLimit = false;
  bool _isSubmitting = false;

  // Payment modes
  final List<String> _paymentModes = ['Cash', 'Credit', 'UPI', 'Card'];

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    // Auto-calculate total amount when liters or price changes
    _litersController.addListener(_calculateTotal);
    _pricePerLiterController.addListener(_calculateTotal);
  }

  void _calculateTotal() {
    if (_litersController.text.isNotEmpty && _pricePerLiterController.text.isNotEmpty) {
      try {
        final liters = double.parse(_litersController.text);
        final price = double.parse(_pricePerLiterController.text);
        final total = liters * price;
        _totalAmountController.text = total.toStringAsFixed(2);
      } catch (e) {
        // Ignore parsing errors
      }
    }
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _driverNameController.dispose();
    _litersController.dispose();
    _pricePerLiterController.dispose();
    _totalAmountController.dispose();
    _slipNumberController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCustomerId == null) {
      showCustomSnackBar(context: context, message: 'Please select a customer', isError: true);
      return;
    }

    if (_selectedFuelTypeId == null) {
      showCustomSnackBar(context: context, message: 'Please select a fuel type', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final transaction = VehicleTransaction(
        petrolPumpId: widget.petrolPumpId,
        vehicleNumber: _vehicleNumberController.text.trim(),
        driverName: _driverNameController.text.trim(),
        litersPurchased: double.parse(_litersController.text),
        pricePerLiter: double.parse(_pricePerLiterController.text),
        totalAmount: double.parse(_totalAmountController.text),
        paymentMode: _selectedPaymentMode,
        transactionDate: _selectedDate,
        customerId: _selectedCustomerId!,
        fuelTypeId: _selectedFuelTypeId!,
        slipNumber: int.parse(_slipNumberController.text),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        validateCreditLimit: _validateCreditLimit,
      );

      final response = await _repository.addVehicleTransaction(transaction);

      if (!mounted) return;

      if (response.success) {
        showCustomSnackBar(context: context, message: 'Vehicle transaction added successfully!', isError: false);
        Navigator.pop(context, true);
      } else {
        showCustomSnackBar(
          context: context,
          message: response.errorMessage ?? 'Failed to add vehicle transaction',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showCustomSnackBar(context: context, message: 'Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Color _getFuelTypeColor(String name) {
    switch (name.toLowerCase()) {
      case 'petrol':
        return Colors.green.shade700;
      case 'diesel':
        return Colors.blue.shade700;
      case 'premium petrol':
        return Colors.purple.shade700;
      case 'cng':
        return Colors.teal.shade700;
      case 'lpg':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Add Vehicle Transaction',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(0),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.directions_car_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'New Vehicle Transaction',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter vehicle transaction details',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Form
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vehicle Details Section
                      _buildSectionTitle('Vehicle Details', Icons.directions_car_rounded),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _vehicleNumberController,
                              label: 'Vehicle Number',
                              hint: 'e.g., KL09PL7789',
                              icon: Icons.confirmation_number_rounded,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Vehicle number is required';
                                }
                                return null;
                              },
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _driverNameController,
                              label: 'Driver Name',
                              hint: 'e.g., John Doe',
                              icon: Icons.person_rounded,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Driver name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Customer & Fuel Type Section
                      _buildSectionTitle('Customer & Fuel Details', Icons.person_outline_rounded),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        label: 'Customer',
                        value: _selectedCustomerId,
                        items: widget.customers.map((customer) {
                          return DropdownMenuItem(
                            value: customer.customerId,
                            child: Text(
                              '${customer.customerName} (${customer.customerCode})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCustomerId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a customer';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownField(
                        label: 'Fuel Type',
                        value: _selectedFuelTypeId,
                        items: widget.fuelTypes.map((fuelType) {
                          return DropdownMenuItem(
                            value: fuelType.fuelTypeId,
                            child: Row(
                              children: [
                                Icon(Icons.local_gas_station_rounded, color: _getFuelTypeColor(fuelType.name), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  fuelType.name,
                                  style: TextStyle(
                                    color: _getFuelTypeColor(fuelType.name),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFuelTypeId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a fuel type';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Transaction Details Section
                      _buildSectionTitle('Transaction Details', Icons.receipt_rounded),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _litersController,
                              label: 'Liters',
                              hint: '0.00',
                              icon: Icons.water_drop_rounded,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Liters is required';
                                }
                                final liters = double.tryParse(value);
                                if (liters == null || liters <= 0) {
                                  return 'Please enter a valid amount';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _pricePerLiterController,
                              label: 'Price/Liter (₹)',
                              hint: '0.00',
                              icon: Icons.currency_rupee_rounded,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Price per liter is required';
                                }
                                final price = double.tryParse(value);
                                if (price == null || price <= 0) {
                                  return 'Please enter a valid price';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _totalAmountController,
                              label: 'Total Amount (₹)',
                              hint: '0.00',
                              icon: Icons.calculate_rounded,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Total amount is required';
                                }
                                final amount = double.tryParse(value);
                                if (amount == null || amount <= 0) {
                                  return 'Please enter a valid amount';
                                }
                                return null;
                              },
                              enabled: false, // Auto-calculated
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _slipNumberController,
                              label: 'Slip Number',
                              hint: 'e.g., 5001',
                              icon: Icons.receipt_long_rounded,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Slip number is required';
                                }
                                final slipNumber = int.tryParse(value);
                                if (slipNumber == null || slipNumber <= 0) {
                                  return 'Please enter a valid slip number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownField(
                              label: 'Payment Mode',
                              value: _selectedPaymentMode,
                              items: _paymentModes.map((mode) {
                                return DropdownMenuItem(
                                  value: mode,
                                  child: Text(mode),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedPaymentMode = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateField(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Additional Details Section
                      _buildSectionTitle('Additional Details', Icons.note_rounded),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _notesController,
                        label: 'Notes (Optional)',
                        hint: 'Enter any additional notes...',
                        icon: Icons.note_rounded,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      _buildCheckboxField(
                        label: 'Validate Credit Limit',
                        value: _validateCreditLimit,
                        onChanged: (value) {
                          setState(() {
                            _validateCreditLimit = value ?? false;
                          });
                        },
                      ),
                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Add Transaction',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryBlue,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      enabled: enabled,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red[300]!),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red[300]!),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      dropdownColor: Colors.white,
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectDate,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Transaction Date',
          prefixIcon: Icon(Icons.calendar_today_rounded, color: Colors.grey[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Text(
          DateFormat('dd MMM yyyy').format(_selectedDate),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildCheckboxField({
    required String label,
    required bool value,
    required void Function(bool?) onChanged,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primaryBlue,
        ),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
