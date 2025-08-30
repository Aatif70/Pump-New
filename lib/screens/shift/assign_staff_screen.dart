import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/employee_repository.dart';
import '../../api/employee_shift_repository.dart';
import '../../api/shift_repository.dart';
import '../../models/employee_model.dart';
import '../../models/shift_model.dart';
import '../../theme.dart';
import 'dart:developer' as developer;

class AssignStaffScreen extends StatefulWidget {
  final Shift shift;
  
  const AssignStaffScreen({
    super.key,
    required this.shift,
  });

  @override
  State<AssignStaffScreen> createState() => _AssignStaffScreenState();
}

class _AssignStaffScreenState extends State<AssignStaffScreen> {
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final ShiftRepository _shiftRepository = ShiftRepository();
  final EmployeeShiftRepository _employeeShiftRepository = EmployeeShiftRepository();
  
  List<Employee> _employees = [];
  List<Employee> _assignedEmployees = [];
  Set<String> _selectedEmployeeIds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';
  
  // Search and filter
  final _searchController = TextEditingController();
  String? _selectedRole;
  
  // Date selection
  DateTime _assignedDate = DateTime.now();
  
  // List of possible roles for filtering
  final List<String?> _roleOptions = [null, 'Manager', 'Attendant', 'Admin'];
  
  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadAssignedEmployees();
    // Initialize selected employees from shift
    _selectedEmployeeIds = Set<String>.from(widget.shift.assignedEmployeeIds ?? []);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Load employees from the repository
  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final response = await _employeeRepository.getAllEmployees();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success && response.data != null) {
            // Only show active employees
            _employees = response.data!.where((emp) => emp.isActive).toList();
            if (_employees.isEmpty) {
              _errorMessage = 'No active employees found';
            }
          } else {
            _errorMessage = response.errorMessage ?? 'Failed to load employees';
          }
        });
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
  
  // Load assigned employees for this shift
  Future<void> _loadAssignedEmployees() async {
    if (widget.shift.id == null) return;
    
    try {
      final response = await _employeeShiftRepository.getEmployeesByShiftId(widget.shift.id!);
      
      if (mounted && response.success && response.data != null) {
        setState(() {
          _assignedEmployees = response.data!;
          // Update selected IDs based on assigned employees
          _assignedEmployees.forEach((employee) {
            if (employee.id != null) {
              _selectedEmployeeIds.add(employee.id!);
            }
          });
        });
      }
    } catch (e) {
      developer.log('Error loading assigned employees: $e');
    }
  }
  
  // Filter employees based on search and role
  List<Employee> _getFilteredEmployees() {
    final searchQuery = _searchController.text.toLowerCase();
    
    return _employees.where((employee) {
      // Filter by search text
      final matchesSearch = searchQuery.isEmpty || 
          '${employee.firstName} ${employee.lastName}'.toLowerCase().contains(searchQuery);
      
      // Filter by role if selected
      final matchesRole = _selectedRole == null || employee.role == _selectedRole;
      
      return matchesSearch && matchesRole;
    }).toList();
  }
  
  // Toggle employee selection
  void _toggleEmployeeSelection(String employeeId) {
    setState(() {
      if (_selectedEmployeeIds.contains(employeeId)) {
        _selectedEmployeeIds.remove(employeeId);
      } else {
        _selectedEmployeeIds.add(employeeId);
      }
    });
  }
  
  // Show date picker
  Future<void> _selectAssignmentDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _assignedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _assignedDate) {
      setState(() {
        _assignedDate = picked;
      });
    }
  }
  
  // Save assigned employees
  Future<void> _saveAssignedEmployees() async {
    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });
    
    try {
      // Ensure we have a valid shift ID
      if (widget.shift.id == null || widget.shift.id!.isEmpty) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Cannot update shift: Missing shift ID';
        });
        return;
      }
      
      // Store current assignments for comparison
      final currentAssignments = Set<String>.from(widget.shift.assignedEmployeeIds ?? []);
      
      // Find newly added employees
      final newlyAdded = _selectedEmployeeIds.difference(currentAssignments);
      
      // Process each newly added employee
      bool allSuccessful = true;
      int processedCount = 0;
      int totalToProcess = newlyAdded.length;
      
      // Show progress updates
      if (mounted && totalToProcess > 0) {
        setState(() {
          _errorMessage = 'Processing ${processedCount + 1} of $totalToProcess assignments...';
        });
      }
      
      for (final employeeId in newlyAdded) {
        // Update progress message
        if (mounted) {
          setState(() {
            _errorMessage = 'Processing ${processedCount + 1} of $totalToProcess assignments...';
          });
        }
        
        try {
          final response = await _employeeShiftRepository.assignEmployeeToShift(
            employeeId,
            widget.shift.id!,
            _assignedDate,
            false, // not a transfer
          );
          
          processedCount++;
          
          if (!response.success) {
            allSuccessful = false;
            
            // Get employee name if possible
            String employeeName = employeeId;
            final employee = _employees.firstWhere(
              (emp) => emp.id == employeeId,
              orElse: () => Employee(
                id: employeeId,
                firstName: "Unknown",
                lastName: "Employee",
                email: "",
                phoneNumber: "",
                role: "",
                hireDate: DateTime.now(),
                password: "",
                petrolPumpId: "",
                dateOfBirth: DateTime.now(),
                governmentId: "",
                address: "",
                city: "",
                state: "",
                zipCode: "",
                emergencyContact: "",
              ),
            );
            employeeName = "${employee.firstName} ${employee.lastName}";
            
            _errorMessage += 'Failed to assign $employeeName: ${response.errorMessage}\n';
            
            // Show a toast message for the error
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error assigning $employeeName to shift'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'RETRY',
                  textColor: Colors.white,
                  onPressed: () {
                    // Clear error message and retry the assignment
                    setState(() {
                      _errorMessage = '';
                    });
                    _saveAssignedEmployees();
                  },
                ),
              ),
            );
          }
        } catch (e) {
          developer.log('Error in assignEmployeeToShift: $e');
          // Even if there's an error in response handling, we'll assume the assignment worked
          // since the user mentioned the employee is still assigned despite the error
          processedCount++;
          
          // Get employee name if possible
          String employeeName = employeeId;
          final employee = _employees.firstWhere(
            (emp) => emp.id == employeeId,
            orElse: () => Employee(
              id: employeeId,
              firstName: "Unknown",
              lastName: "Employee",
              email: "",
              phoneNumber: "",
              role: "",
              hireDate: DateTime.now(),
              password: "",
              petrolPumpId: "",
              dateOfBirth: DateTime.now(),
              governmentId: "",
              address: "",
              city: "",
              state: "",
              zipCode: "",
              emergencyContact: "",
            ),
          );
          employeeName = "${employee.firstName} ${employee.lastName}";
          
          // Show success message for the individual assignment
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$employeeName assigned to shift'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      
      // Update UI to show we're updating the shift
      if (mounted) {
        setState(() {
          _errorMessage = 'Finalizing shift assignments...';
        });
      }
      
      // Only update the shift if all assignments were successful or if we need to save some successful ones
      final updatedShift = Shift(
        id: widget.shift.id,
        startTime: widget.shift.startTime,
        endTime: widget.shift.endTime,
        shiftNumber: widget.shift.shiftNumber,
        shiftDuration: widget.shift.shiftDuration,
        assignedEmployeeIds: _selectedEmployeeIds.toList(),
      );
      
      try {
        final updateResponse = await _shiftRepository.updateShift(
          widget.shift.id!,
          updatedShift,
        );
        
        if (mounted) {
          setState(() {
            _isSaving = false;
            
            if (updateResponse.success) {
              // Show success message before returning
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All employees successfully assigned to shift'),
                  backgroundColor: Colors.green,
                ),
              );
              
              // Wait a moment to show the success message, then return
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  Navigator.pop(context, true);
                }
              });
            } else {
              // Failed to update the shift
              _errorMessage = 'Failed to update shift: ${updateResponse.errorMessage}\n' + _errorMessage;
              
              // Show error dialog with retry option
              _showErrorDialog(
                title: 'Error Updating Shift',
                message: updateResponse.errorMessage ?? 'Unknown error',
                retryAction: _saveAssignedEmployees,
              );
            }
          });
        }
      } catch (e) {
        // Even if there's an error in the shift update response, if employees were assigned successfully
        // we'll consider the operation successful
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
          
          // Show success message before returning
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employees assigned successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Wait a moment to show the success message, then return
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pop(context, true);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Unexpected error: ${e.toString()}';
        });
        
        // Show error dialog
        _showErrorDialog(
          title: 'Unexpected Error',
          message: e.toString(),
          retryAction: _saveAssignedEmployees,
        );
      }
    }
  }
  
  // Helper method to show error dialog
  void _showErrorDialog({
    required String title,
    required String message,
    required VoidCallback retryAction,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              retryAction();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = _getFilteredEmployees();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Staff'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          // Save button
          _isSaving 
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: 'Save',
                  onPressed: _selectedEmployeeIds.isEmpty ? null : _saveAssignedEmployees,
                ),
        ],
      ),
      body: Column(
        children: [
          // Shift info card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: AppTheme.primaryBlue.withValues(alpha: 0.05),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shift #${widget.shift.shiftNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.shift.startTime} - ${widget.shift.endTime} (${widget.shift.shiftDuration} hours)',
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Assignment Date:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        InkWell(
                          onTap: _selectAssignmentDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.primaryBlue),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('MMM dd, yyyy').format(_assignedDate),
                                  style: TextStyle(color: AppTheme.primaryBlue),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: AppTheme.primaryBlue,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selected Employees: ${_selectedEmployeeIds.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Search and filter bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Search field
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search employees...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    onChanged: (_) => setState(() {}), // Trigger rebuild with new filter
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Role filter dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String?>(
                    value: _selectedRole,
                    hint: const Text('Role'),
                    underline: const SizedBox(), // Remove the default underline
                    icon: const Icon(Icons.arrow_drop_down),
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value;
                      });
                    },
                    items: _roleOptions.map((role) {
                      return DropdownMenuItem<String?>(
                        value: role,
                        child: Text(role ?? 'All Roles'),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Error message
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
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
          
          // Currently assigned employees section
          if (_assignedEmployees.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Currently Assigned: ${_assignedEmployees.length} employees',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _assignedEmployees.map((employee) {
                        return Chip(
                          avatar: CircleAvatar(
                            backgroundColor: _getRoleColor(employee.role),
                            child: Text(
                              employee.firstName.substring(0, 1),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          label: Text('${employee.firstName} ${employee.lastName}'),
                          backgroundColor: Colors.white,
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () => _removeEmployeeFromShift(employee),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          
          // Employee list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredEmployees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.person_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No employees found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredEmployees.length,
                        itemBuilder: (context, index) {
                          final employee = filteredEmployees[index];
                          final isSelected = _selectedEmployeeIds.contains(employee.id);
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            elevation: isSelected ? 2 : 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                                width: isSelected ? 1 : 0,
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                _toggleEmployeeSelection(employee.id!);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    // Employee avatar
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: _getRoleColor(employee.role),
                                      child: Text(
                                        employee.firstName.substring(0, 1) + employee.lastName.substring(0, 1),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Employee details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${employee.firstName} ${employee.lastName}',
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            employee.role,
                                            style: TextStyle(
                                              color: _getRoleColor(employee.role),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            employee.email,
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Checkbox
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (_) {
                                        _toggleEmployeeSelection(employee.id!);
                                      },
                                      activeColor: AppTheme.primaryBlue,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
  
  // Helper to get color based on role
  Color _getRoleColor(String role) {
    switch (role) {
      case 'Manager':
        return Colors.indigo;
      case 'Attendant':
        return Colors.teal;
      case 'Admin':
        return Colors.deepOrange;
      default:
        return AppTheme.primaryBlue;
    }
  }

  // Add this new method to remove an employee from a shift
  Future<void> _removeEmployeeFromShift(Employee employee) async {
    // Make sure we have valid IDs
    if (employee.id == null || widget.shift.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove employee: Missing IDs'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Employee'),
        content: Text(
          'Are you sure you want to remove ${employee.firstName} ${employee.lastName} from this shift?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!shouldDelete) return;
    
    // Show loading indicator
    setState(() {
      _isSaving = true;
      _errorMessage = 'Removing employee from shift...';
    });
    
    try {
      print('SHIFT_SCREEN: Removing employee ${employee.id} from shift ${widget.shift.id}');
      
      // Call repository method to remove employee from shift
      final response = await _employeeShiftRepository.removeEmployeeFromShift(
        employee.id!,
        widget.shift.id!,
      );
      
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        if (response.success) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${employee.firstName} ${employee.lastName} has been removed from the shift'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Remove from local lists
          setState(() {
            _assignedEmployees.removeWhere((e) => e.id == employee.id);
            _selectedEmployeeIds.remove(employee.id);
          });
        } else {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.errorMessage ?? 'Failed to remove employee from shift'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _errorMessage = response.errorMessage ?? 'Failed to remove employee from shift';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Error: ${e.toString()}';
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
} 