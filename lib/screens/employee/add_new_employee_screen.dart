import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/api_constants.dart';
import '../../api/employee_repository.dart';
import '../../models/employee_model.dart';
import '../../theme.dart';
import 'dart:developer' as developer;

class AddNewEmployeeScreen extends StatefulWidget {
  const AddNewEmployeeScreen({super.key});

  @override
  State<AddNewEmployeeScreen> createState() => _AddNewEmployeeScreenState();
}

class _AddNewEmployeeScreenState extends State<AddNewEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _governmentIdController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  
  // Dates
  DateTime _dateOfBirth = DateTime.now().subtract(const Duration(days: 365 * 18)); // Default 18 years ago
  DateTime _hireDate = DateTime.now(); // Default today
  
  String _selectedRole = 'Attendant'; // Default role

  bool _isLoading = false;
  String _errorMessage = '';

  // Role options
  final List<String> _roleOptions = [
    'Attendant',
    // 'Manager'
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _governmentIdController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  // Date picker for date of birth
  Future<void> _selectDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  // Date picker for hire date
  Future<void> _selectHireDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _hireDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 30)), // Allow scheduling up to 30 days in the future
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _hireDate) {
      setState(() {
        _hireDate = picked;
      });
    }
  }

  // Submit the form
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final repository = EmployeeRepository();

      // Get the petrol pump ID
      final petrolPumpId = await repository.getPetrolPumpId();

      if (petrolPumpId == null) {
        setState(() {
          _errorMessage = 'Petrol pump ID not found. Please login again.';
          _isLoading = false;
        });
        return;
      }

      // Create employee object
      final employee = Employee(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        phoneNumber: _phoneController.text,
        hireDate: _hireDate,
        dateOfBirth: _dateOfBirth,
        petrolPumpId: petrolPumpId,
        role: _selectedRole,
        governmentId: _governmentIdController.text,
        address: _addressController.text,
        city: _cityController.text,
        state: _stateController.text,
        zipCode: _zipCodeController.text,
        emergencyContact: _emergencyContactController.text,
      );

      // Log the request details
      developer.log('Sending POST request to ${ApiConstants.getEmployeeUrl()}');
      developer.log('Request body: ${employee.toJson()}');

      // Call repository to add employee
      final response = await repository.addEmployee(employee);

      if (!mounted) return;

      if (response.success) {
        developer.log('Employee created successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee added successfully')),
        );

        // Clear form
        _formKey.currentState!.reset();
        _firstNameController.clear();
        _lastNameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _phoneController.clear();
        _governmentIdController.clear();
        _addressController.clear();
        _cityController.clear();
        _stateController.clear();
        _zipCodeController.clear();
        _emergencyContactController.clear();
        setState(() {
          _selectedRole = 'Attendant';
          _dateOfBirth = DateTime.now().subtract(const Duration(days: 365 * 18));
          _hireDate = DateTime.now();
        });
      } else {
        developer.log('Failed to create employee: ${response.errorMessage}');
        setState(() {
          _errorMessage = response.errorMessage ?? 'Failed to add employee';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage)),
        );
      }
    } catch (e) {
      developer.log('Error submitting form: $e');
      setState(() {
        _errorMessage = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $_errorMessage')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add New Employee'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Employee Details',
                    style: AppTheme.headingStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please enter the new employee details',
                    style: AppTheme.subheadingStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Personal Information Section
                  _buildSectionHeader('Personal Information'),
                  
                  // First Name
                  TextFormField(
                    controller: _firstNameController,
                    decoration: AppTheme.inputDecoration('First Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter first name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Last Name
                  TextFormField(
                    controller: _lastNameController,
                    decoration: AppTheme.inputDecoration('Last Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter last name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date of Birth
                  InkWell(
                    onTap: () => _selectDateOfBirth(context),
                    child: InputDecorator(
                      decoration: AppTheme.inputDecoration('Date of Birth'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(dateFormat.format(_dateOfBirth)),
                          const Icon(Icons.calendar_month),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Government ID
                  TextFormField(
                    controller: _governmentIdController,
                    decoration: AppTheme.inputDecoration('Government ID'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter government ID';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Contact Information Section
                  _buildSectionHeader('Contact Information'),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: AppTheme.inputDecoration('Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  TextFormField(
                    controller: _phoneController,
                    decoration: AppTheme.inputDecoration('Phone Number'),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Emergency Contact
                  TextFormField(
                    controller: _emergencyContactController,
                    decoration: AppTheme.inputDecoration('Emergency Contact'),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter emergency contact';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Address Section
                  _buildSectionHeader('Address'),

                  // Address
                  TextFormField(
                    controller: _addressController,
                    decoration: AppTheme.inputDecoration('Street Address'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // City
                  TextFormField(
                    controller: _cityController,
                    decoration: AppTheme.inputDecoration('City'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter city';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // State and Zip Code (Row)
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _stateController,
                          decoration: AppTheme.inputDecoration('State/Province'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter state';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _zipCodeController,
                          decoration: AppTheme.inputDecoration('Zip Code'),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter zip code';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Employment Information Section
                  _buildSectionHeader('Employment Information'),

                  // Role Dropdown
                  DropdownButtonFormField<String>(
                    decoration: AppTheme.inputDecoration('Role'),
                    value: _selectedRole,
                    items: _roleOptions.map((String role) {
                      return DropdownMenuItem<String>(
                        value: role,

                        child: Text(role),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedRole = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Hire Date
                  InkWell(
                    onTap: () => _selectHireDate(context),
                    child: InputDecorator(
                      decoration: AppTheme.inputDecoration('Hire Date'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(dateFormat.format(_hireDate)),
                          const Icon(Icons.calendar_month),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account Information Section
                  _buildSectionHeader('Account Information'),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    decoration: AppTheme.inputDecoration('Password'),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Error message display
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: AppTheme.primaryButtonStyle,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Add Employee',
                            style: AppTheme.bodyStyle.copyWith(
                              color: AppTheme.textLight,
                              fontWeight: FontWeight.bold,
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.subheadingStyle.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Divider(thickness: 1),
        ],
      ),
    );
  }
}