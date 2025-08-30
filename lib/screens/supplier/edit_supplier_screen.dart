import 'package:flutter/material.dart';
import 'package:petrol_pump/api/supplier_repository.dart';
import 'package:petrol_pump/models/supplier_model.dart';
import 'package:petrol_pump/theme.dart';

class EditSupplierScreen extends StatefulWidget {
  final Supplier supplier;
  
  const EditSupplierScreen({super.key, required this.supplier});

  @override
  State<EditSupplierScreen> createState() => _EditSupplierScreenState();
}

class _EditSupplierScreenState extends State<EditSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supplierRepository = SupplierRepository();
  
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Form fields
  late final TextEditingController _supplierNameController;
  late final TextEditingController _contactPersonController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _zipCodeController;
  late final TextEditingController _gstNumberController;
  late bool _isActive;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with existing supplier data
    _supplierNameController = TextEditingController(text: widget.supplier.supplierName);
    _contactPersonController = TextEditingController(text: widget.supplier.contactPerson);
    _phoneController = TextEditingController(text: widget.supplier.phoneNumber);
    _emailController = TextEditingController(text: widget.supplier.email);
    _addressController = TextEditingController(text: widget.supplier.address);
    _cityController = TextEditingController(text: widget.supplier.city);
    _stateController = TextEditingController(text: widget.supplier.state);
    _zipCodeController = TextEditingController(text: widget.supplier.zipCode);
    _gstNumberController = TextEditingController(text: widget.supplier.gstNumber);
    _isActive = widget.supplier.isActive;
  }
  
  @override
  void dispose() {
    _supplierNameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _gstNumberController.dispose();
    super.dispose();
  }
  
  // Dismiss keyboard when tapping outside text fields
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }
  
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Create updated supplier model
      final updatedSupplier = Supplier(
        supplierDetailId: widget.supplier.supplierDetailId,
        supplierName: _supplierNameController.text.trim(),
        contactPerson: _contactPersonController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        zipCode: _zipCodeController.text.trim(),
        gstNumber: _gstNumberController.text.trim(),
        petrolPumpId: widget.supplier.petrolPumpId,
        isActive: _isActive,
      );
      
      // Call API
      final response = await _supplierRepository.updateSupplier(updatedSupplier);
      
      if (mounted) {
        if (response.success) {
          // Show success message and pop back with result
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Supplier updated successfully'),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          Navigator.pop(context, true);
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = response.errorMessage ?? 'Failed to update supplier';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }
  
  Widget _buildSectionHeader(String title) {
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
  
  Widget _buildStyledFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
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
            prefixIcon: Icon(icon, color: AppTheme.primaryBlue),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          keyboardType: keyboardType,
          validator: validator,
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              helperText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Edit Supplier'),
          backgroundColor: AppTheme.primaryBlue,
          elevation: 0,
          foregroundColor: Colors.white,
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
                    'Edit Supplier Details',
                    style: AppTheme.headingStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Update information for ${widget.supplier.supplierName}',
                    style: AppTheme.subheadingStyle.copyWith(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Error message
                  if (_errorMessage.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
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
                  
                  // Basic Information
                  _buildSectionHeader('Business Information'),
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
                          _buildStyledFormField(
                            controller: _supplierNameController,
                            label: 'Company Name',
                            icon: Icons.business,
                            hintText: 'Enter the supplier\'s company name',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter supplier name';
                              }
                              return null;
                            },
                          ),
                          _buildStyledFormField(
                            controller: _contactPersonController,
                            label: 'Contact Person',
                            icon: Icons.person,
                            hintText: 'Enter the name of your primary contact',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter contact person name';
                              }
                              return null;
                            },
                          ),
                          _buildStyledFormField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            icon: Icons.phone,
                            hintText: 'Enter contact phone number',
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter phone number';
                              }
                              return null;
                            },
                          ),
                          _buildStyledFormField(
                            controller: _emailController,
                            label: 'Email Address',
                            icon: Icons.email,
                            hintText: 'Enter business email address',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter email';
                              }
                              // Basic email validation
                              final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (!emailRegExp.hasMatch(value.trim())) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                            helperText: 'Business communications will be sent to this email',
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Address Information
                  _buildSectionHeader('Location Details'),
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
                          _buildStyledFormField(
                            controller: _addressController,
                            label: 'Street Address',
                            icon: Icons.location_on,
                            hintText: 'Enter complete street address',
                            maxLines: 2,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter address';
                              }
                              return null;
                            },
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'City',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _cityController,
                                      decoration: InputDecoration(
                                        hintText: 'City',
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
                                        prefixIcon: Icon(Icons.location_city, color: AppTheme.primaryBlue),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Required';
                                        }
                                        return null;
                                      },
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
                                      'State',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _stateController,
                                      decoration: InputDecoration(
                                        hintText: 'State',
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
                                        prefixIcon: Icon(Icons.map, color: AppTheme.primaryBlue),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildStyledFormField(
                            controller: _zipCodeController,
                            label: 'ZIP Code',
                            icon: Icons.pin,
                            hintText: 'Enter postal code',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter ZIP code';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Tax Information
                  _buildSectionHeader('Tax Information'),
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha:0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildStyledFormField(
                        controller: _gstNumberController,
                        label: 'GST Number',
                        icon: Icons.receipt_long,
                        hintText: 'Enter company GST registration number',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter GST number';
                          }
                          return null;
                        },
                        helperText: 'Required for tax documentation and invoicing',
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Status
                  _buildSectionHeader('Supplier Status'),
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
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Supplier Status',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Set to active if this supplier is currently available for deliveries',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: Switch(
                              value: _isActive,
                              onChanged: (bool value) {
                                setState(() {
                                  _isActive = value;
                                });
                              },
                              activeColor: Colors.white,
                              activeTrackColor: AppTheme.primaryBlue,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: Colors.grey.shade400,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              _isActive ? 'Active - Ready for business' : 'Inactive - Not available for orders',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: _isActive ? Colors.green.shade600 : Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
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
                                const Icon(Icons.save),
                                const SizedBox(width: 8),
                                Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 