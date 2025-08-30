import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/employee_repository.dart';
import '../../models/employee_model.dart';
import '../../theme.dart';
import 'dart:developer' as developer;
import 'edit_employee_screen.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final String employeeId;
  
  const EmployeeDetailScreen({
    super.key, 
    required this.employeeId,
  });

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  final EmployeeRepository _repository = EmployeeRepository();
  Employee? _employee;
  bool _isLoading = true;
  bool _isDeleting = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadEmployeeDetails();
  }

  Future<void> _loadEmployeeDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      developer.log('Loading employee details for ID: ${widget.employeeId}');
      final response = await _repository.getEmployeeById(widget.employeeId);

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success && response.data != null) {
            _employee = response.data;
            developer.log('Loaded employee details: ${_employee?.firstName} ${_employee?.lastName}, ID: ${_employee?.id}');
            
            // Log if ID is null or different from expected
            if (_employee?.id == null) {
              developer.log('WARNING: Employee ID is null after loading from API', error: 'NULL_ID');
            } else if (_employee!.id != widget.employeeId) {
              developer.log('WARNING: Loaded employee ID (${_employee!.id}) does not match requested ID (${widget.employeeId})', error: 'ID_MISMATCH');
            }
          } else {
            _errorMessage = response.errorMessage ?? 'Failed to load employee details';
            developer.log('Error loading employee details: $_errorMessage');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
          developer.log('Exception while loading employee details: $e');
        });
      }
    }
  }

  // Navigate to edit employee screen
  void _navigateToEditScreen() {
    if (_employee == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEmployeeScreen(employee: _employee!),
      ),
    ).then((updated) {
      if (updated == true) {
        // Reload employee details if updated
        _loadEmployeeDetails();
        
        // Signal parent screen to refresh
        Navigator.pop(context, 'edited');
      }
    });
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text(
          'Are you sure you want to delete ${_employee?.firstName} ${_employee?.lastName}? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: _deleteEmployee,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  // Delete employee
  Future<void> _deleteEmployee() async {
    Navigator.pop(context); // Close dialog
    
    // Check if employee is null or id is null
    if (_employee == null || _employee!.id == null) {
      print('ERROR: Cannot delete employee - Invalid employee ID');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete employee: Invalid employee ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    print('DELETING EMPLOYEE: ID=${_employee!.id!}, Name=${_employee!.firstName} ${_employee!.lastName}');
    
    setState(() {
      _isDeleting = true;
    });

    try {
      print('Calling repository.deleteEmployee for ID: ${_employee!.id!}');
      final response = await _repository.deleteEmployee(_employee!.id!);
      
      print('DELETE RESPONSE: success=${response.success}, error=${response.errorMessage}');
      
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        
        if (response.success) {
          // Show success message
          print('DELETE SUCCESS: Employee has been deleted successfully');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employee has been deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Go back to employee list with delete flag
          print('Navigating back to employee list with delete flag');
          Navigator.of(context).pop('deleted');
        } else {
          // Show error message
          print('DELETE ERROR: ${response.errorMessage}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.errorMessage ?? 'Failed to delete employee'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('DELETE EXCEPTION: $e');
      if (mounted) {
        setState(() {
          _isDeleting = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _employee != null 
            ? Text('${_employee!.firstName} ${_employee!.lastName}')
            : const Text('Employee Details'),
        actions: [
          if (_employee != null && !_isLoading && !_isDeleting)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: _navigateToEditScreen,
            ),
          if (_employee != null && !_isLoading && !_isDeleting)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _showDeleteConfirmation,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isDeleting
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Deleting employee...'),
                    ],
                  ),
                )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadEmployeeDetails,
                          style: AppTheme.primaryButtonStyle,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _employee == null
                  ? const Center(child: Text('Employee not found'))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Employee Header with colored background
                          _buildEmployeeHeader(_employee!),
                          
                          // Information sections
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoSection('Personal Information', [
                                  _buildInfoRow('Full Name', '${_employee!.firstName} ${_employee!.lastName}'),
                                  _buildInfoRow('Date of Birth', DateFormat('MMMM dd, yyyy').format(_employee!.dateOfBirth)),
                                  _buildInfoRow('Government ID', _employee!.governmentId.isEmpty ? 'Not provided' : _employee!.governmentId),
                                ]),
                                
                                const SizedBox(height: 24),
                                _buildInfoSection('Contact Information', [
                                  _buildInfoRow('Email', _employee!.email),
                                  _buildInfoRow('Phone', _employee!.phoneNumber),
                                  _buildInfoRow('Emergency Contact', 
                                    _employee!.emergencyContact.isEmpty ? 'Not provided' : _employee!.emergencyContact),
                                ]),
                                
                                const SizedBox(height: 24),
                                _buildInfoSection('Address', [
                                  _buildInfoRow('Street', _employee!.address.isEmpty ? 'Not provided' : _employee!.address),
                                  _buildInfoRow('City', _employee!.city.isEmpty ? 'Not provided' : _employee!.city),
                                  _buildInfoRow('State', _employee!.state.isEmpty ? 'Not provided' : _employee!.state),
                                  _buildInfoRow('Zip Code', _employee!.zipCode.isEmpty ? 'Not provided' : _employee!.zipCode),
                                ]),
                                
                                const SizedBox(height: 20),
                                _buildInfoSection('Employment Details', [
                                  _buildInfoRow('Role', _employee!.role),
                                  _buildInfoRow('Hire Date', DateFormat('MMMM dd, yyyy').format(_employee!.hireDate)),
                                  // _buildInfoRow('Employee ID', _employee!.id ?? 'N/A'),
                                ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildEmployeeHeader(Employee employee) {
    return Container(
      width: double.infinity,
      color: _getRoleColor(employee.role).withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Column(
        children: [
          // Large avatar
          CircleAvatar(
            radius: 48,
            backgroundColor: _getRoleColor(employee.role),
            child: Text(
              '${employee.firstName[0]}${employee.lastName[0]}',
              style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Name
          Text(
            '${employee.firstName} ${employee.lastName}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Role with pill background
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _getRoleColor(employee.role),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              employee.role,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Status indicator - now more prominent
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: employee.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: employee.isActive ? Colors.green : Colors.red,
                width: 0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  employee.isActive ? Icons.check_circle : Icons.cancel,
                  size: 20,
                  color: employee.isActive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  employee.isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    color: employee.isActive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Email
          Text(
            employee.email,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        
        const Divider(thickness: 1),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ),
          
          // Value
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Get color based on role
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'manager':
        return Colors.purple;
      case 'admin':
        return Colors.indigo.shade200;
      case 'attendant':
        return Colors.teal;
      default:
        return AppTheme.primaryBlue;
    }
  }
} 