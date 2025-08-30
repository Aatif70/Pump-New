import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/employee_repository.dart';
import '../../models/employee_model.dart';
import '../../theme.dart';

class EditEmployeeScreen extends StatefulWidget {
  final Employee employee;
  
  const EditEmployeeScreen({super.key, required this.employee});

  @override
  State<EditEmployeeScreen> createState() => _EditEmployeeScreenState();
}

class _EditEmployeeScreenState extends State<EditEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = EmployeeRepository();
  bool _isLoading = false;
  bool _isActive = true;
  
  // Form controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _governmentIdController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  
  // Date fields
  DateTime _hireDateValue = DateTime.now();
  DateTime _dobValue = DateTime.now();
  
  // Role selection
  String _roleValue = 'Attendant';
  final List<String> _roles = ['Attendant'];

  @override
  void initState() {
    super.initState();
    _populateFormFields();
  }

  @override
  void dispose() {
    // Dispose all controllers
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _governmentIdController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  // Pre-populate form fields with employee data
  void _populateFormFields() {
    final employee = widget.employee;
    
    _firstNameController.text = employee.firstName;
    _lastNameController.text = employee.lastName;
    _emailController.text = employee.email;
    _phoneController.text = employee.phoneNumber;
    _addressController.text = employee.address;
    _cityController.text = employee.city;
    _stateController.text = employee.state;
    _zipCodeController.text = employee.zipCode;
    _governmentIdController.text = employee.governmentId;
    _emergencyContactController.text = employee.emergencyContact;
    
    _hireDateValue = employee.hireDate;
    _dobValue = employee.dateOfBirth;
    _roleValue = employee.role;
    _isActive = employee.isActive;
  }

  // Save updated employee
  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Check if the employee ID is null
    if (widget.employee.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot update employee: Invalid employee ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Log changes to active status for debugging
    if (_isActive != widget.employee.isActive) {
      print('IMPORTANT: Changing employee active status from ${widget.employee.isActive} to $_isActive');
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Create updated employee object
      final updatedEmployee = Employee(
        id: widget.employee.id,  // Keep the original ID
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        phoneNumber: _phoneController.text,
        address: _addressController.text,
        city: _cityController.text,
        state: _stateController.text,
        zipCode: _zipCodeController.text,
        governmentId: _governmentIdController.text,
        emergencyContact: _emergencyContactController.text,
        hireDate: _hireDateValue,
        dateOfBirth: _dobValue,
        role: _roleValue,
        isActive: _isActive,
        password: widget.employee.password,  // Keep the existing password
        petrolPumpId: widget.employee.petrolPumpId,  // Keep petrol pump ID
      );
      
      print('Saving employee update: ID=${updatedEmployee.id}, isActive=${updatedEmployee.isActive}');
      
      // Call API to update employee
      final response = await _repository.updateEmployee(widget.employee.id!, updatedEmployee);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (response.success) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employee updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          print('EMPLOYEE UPDATE SUCCESS: isActive=${updatedEmployee.isActive}');
          
          // Go back and signal that employee was updated
          Navigator.pop(context, true);
        } else {
          // Show error message
          print('EMPLOYEE UPDATE FAILED: ${response.errorMessage}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.errorMessage ?? 'Failed to update employee'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('EMPLOYEE UPDATE EXCEPTION: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show date picker for birth date and hire date
  Future<void> _selectDate(BuildContext context, bool isHireDate) async {
    final DateTime initialDate = isHireDate ? _hireDateValue : _dobValue;
    final DateTime firstDate = DateTime(1940);
    final DateTime lastDate = DateTime.now();
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
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
    
    if (picked != null) {
      setState(() {
        if (isHireDate) {
          _hireDateValue = picked;
        } else {
          _dobValue = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Employee'),
          actions: [
            if (!_isLoading)
              TextButton.icon(
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text('SAVE', style: TextStyle(color: Colors.white)),
                onPressed: _saveEmployee,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Active status toggle
                        SwitchListTile(
                          title: const Text('Active Status'),
                          subtitle: Text(_isActive ? 'Employee is active' : 'Employee is inactive'),
                          value: _isActive,
                          activeColor: AppTheme.primaryBlue,
                          onChanged: (value) {
                            setState(() {
                              _isActive = value;
                            });
                          },
                        ),
                        
                        const Divider(),
                        
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
                          onTap: () => _selectDate(context, false),
                          child: InputDecorator(
                            decoration: AppTheme.inputDecoration('Date of Birth'),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('MMMM dd, yyyy').format(_dobValue),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const Icon(Icons.calendar_today, size: 20),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Government ID
                        TextFormField(
                          controller: _governmentIdController,
                          decoration: AppTheme.inputDecoration('Government ID (Optional)'),
                        ),
                        
                        const Divider(height: 32),
                        
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
                          decoration: AppTheme.inputDecoration('Emergency Contact (Optional)'),
                          keyboardType: TextInputType.phone,
                        ),
                        
                        const Divider(height: 32),
                        
                        // Address Section
                        _buildSectionHeader('Address'),
                        
                        // Street
                        TextFormField(
                          controller: _addressController,
                          decoration: AppTheme.inputDecoration('Street Address'),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // City
                        TextFormField(
                          controller: _cityController,
                          decoration: AppTheme.inputDecoration('City'),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // State
                        TextFormField(
                          controller: _stateController,
                          decoration: AppTheme.inputDecoration('State/Province'),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Zip Code
                        TextFormField(
                          controller: _zipCodeController,
                          decoration: AppTheme.inputDecoration('Zip/Postal Code'),
                          keyboardType: TextInputType.number,
                        ),
                        
                        const Divider(height: 32),
                        
                        // Employment Details Section
                        _buildSectionHeader('Employment Details'),
                        
                        // Role
                        DropdownButtonFormField<String>(
                          value: _roleValue,
                          decoration: AppTheme.inputDecoration('Role'),
                          items: _roles.map((role) {
                            return DropdownMenuItem<String>(
                              value: role,
                              child: Text(role),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            if (newValue != null) {
                              setState(() {
                                _roleValue = newValue;
                              });
                            }
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Hire Date
                        InkWell(
                          onTap: () => _selectDate(context, true),
                          child: InputDecorator(
                            decoration: AppTheme.inputDecoration('Hire Date'),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('MMMM dd, yyyy').format(_hireDateValue),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const Icon(Icons.calendar_today, size: 20),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Save button
                        Container(
                          width: double.infinity,
                          height: 48,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ElevatedButton(
                            onPressed: _saveEmployee,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text('SAVE CHANGES'),
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
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryBlue,
        ),
      ),
    );
  }
} 