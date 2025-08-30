import 'package:flutter/material.dart';
import 'dart:math' as Math;
import '../../api/shift_repository.dart';
import '../../api/employee_shift_repository.dart';
import '../../api/employee_repository.dart';
import '../../models/employee_model.dart';
import '../../models/shift_model.dart';
import '../../theme.dart';
import 'add_shift_screen.dart';
import 'edit_shift_screen.dart';
import 'dart:developer' as developer;
import 'package:google_fonts/google_fonts.dart';


class ShiftListScreen extends StatefulWidget {
  const ShiftListScreen({super.key});

  @override
  State<ShiftListScreen> createState() => _ShiftListScreenState();
}

class _ShiftListScreenState extends State<ShiftListScreen> {
  final ShiftRepository _repository = ShiftRepository();
  final EmployeeShiftRepository _employeeShiftRepository = EmployeeShiftRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  List<Shift> _shifts = [];
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Add this variable to the class to cache employee data
  final Map<String, List<Employee>> _cachedEmployeeData = {};
  
  @override
  void initState() {
    super.initState();
    print('SHIFT_LIST: Initializing Shift List Screen');
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    print('SHIFT_LIST: Loading shifts from repository');
    try {
      developer.log('Loading all shifts');
      final response = await _repository.getAllShifts();

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success && response.data != null) {
            // Add real shifts from the API
            _shifts = response.data!;
            print('SHIFT_LIST: Successfully loaded ${_shifts.length} shifts from API');
            developer.log('Loaded ${_shifts.length} shifts');
            
            // Check if any shifts have assigned employees
            int shiftsWithEmployees = _shifts.where((shift) => 
              shift.assignedEmployeeIds.isNotEmpty).length;
            print('SHIFT_LIST: $shiftsWithEmployees shifts have assigned employees');
            
            // Log details about each shift's assignments for debugging
            for (var i = 0; i < _shifts.length; i++) {
              final shift = _shifts[i];
              final employeeCount = shift.assignedEmployeeIds?.length ?? 0;
              print('SHIFT_LIST: Shift #${shift.shiftNumber} (ID: ${shift.id}) has $employeeCount assigned employees');
              if (employeeCount > 0) {
                print('SHIFT_LIST: Employee IDs for Shift #${shift.shiftNumber}: ${shift.assignedEmployeeIds}');
              }
            }
            
            // Pre-load employee details for each shift to ensure accurate counts
            _preloadEmployeeData();
          } else {
            _errorMessage = response.errorMessage ?? 'Failed to load shifts';
            _shifts = [];
            print('SHIFT_LIST: Error loading shifts: $_errorMessage');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
          _shifts = [];
          print('SHIFT_LIST: Exception loading shifts: $e');
        });
      }
    }
  }

  // New method to preload employee data for all shifts
  Future<void> _preloadEmployeeData() async {
    // Only clear cached data for shifts that need updating
    print('SHIFT_LIST: Preloading employee data for shifts that need it');
    
    // Track which shifts actually need a refresh
    bool needsStateUpdate = false;
    
    for (var shift in _shifts) {
      if (shift.id != null && shift.id!.isNotEmpty) {
        // Skip if we already have data for this shift and it hasn't changed
        if (_cachedEmployeeData.containsKey(shift.id!) && 
            _cachedEmployeeData[shift.id!]?.length == shift.assignedEmployeeIds.length) {
          print('SHIFT_LIST: Skipping preload for shift ${shift.id} - data already cached');
          continue;
        }
        
        try {
          // Process shifts sequentially to avoid overwhelming the API
          final employees = await _forceReloadEmployeeData(shift.id!);
          print('SHIFT_LIST: Preloaded ${employees.length} employees for shift ${shift.id}');
          
          // If the shift shown on UI doesn't match actual employee count, mark for UI update
          if ((shift.assignedEmployeeIds?.length ?? 0) != employees.length) {
            print('SHIFT_LIST: Detected mismatch in employee count for shift ${shift.id}');
            
            // Update the shift's assignedEmployeeIds to match actual data
            final index = _shifts.indexWhere((s) => s.id == shift.id);
            if (index >= 0) {
              _shifts[index].assignedEmployeeIds = employees.map((e) => e.id!).toList();
              needsStateUpdate = true;
            }
          }
        } catch (e) {
          print('SHIFT_LIST: Failed to preload employee data for shift ${shift.id}: $e');
        }
      }
    }
    
    // Only trigger a state update if something actually changed
    if (needsStateUpdate && mounted) {
      setState(() {
        // This will refresh the UI with the updated shift data
      });
    }
  }

  void _navigateToAddShift() async {
    print('SHIFT_LIST: Navigating to Add Shift screen');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddShiftScreen()),
    );
    
    if (result == true) {
      print('SHIFT_LIST: Returned from Add Shift with success, refreshing list');
      // Refresh shifts list
      _loadShifts();
    } else {
      print('SHIFT_LIST: Returned from Add Shift without changes');
    }
  }

  // Add these methods for edit and delete functionality
  Future<void> _navigateToEditShift(Shift shift) async {
    print('SHIFT_LIST: Navigating to Edit Shift screen for shift ID: ${shift.id}');
    
    // Check if shift has a valid ID
    if (shift.id == null || shift.id!.isEmpty) {
      print('SHIFT_LIST: Cannot edit shift with missing ID');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot edit this shift: Missing shift ID. This may be due to an API response issue.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditShiftScreen(shift: shift)),
    );
    
    if (result == true) {
      print('SHIFT_LIST: Returned from Edit Shift with success, refreshing list');
      // Refresh shifts list
      _loadShifts();
    } else {
      print('SHIFT_LIST: Returned from Edit Shift without changes');
    }
  }
  
  Future<void> _confirmDeleteShift(Shift shift) async {
    // Validate shift ID
    if (shift.id == null || shift.id!.isEmpty) {
      print('SHIFT_LIST: Cannot delete shift with missing ID');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete shift: Missing shift ID')),
      );
      return;
    }
    
    print('SHIFT_LIST: Confirming deletion of shift ID: ${shift.id}');
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shift'),
        content: Text('Are you sure you want to delete Shift #${shift.shiftNumber}?\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      print('SHIFT_LIST: User confirmed deletion, deleting shift ID: ${shift.id}');
      setState(() {
        _isLoading = true;
      });
      
      try {
        // First check if there are employees assigned to this shift
        print('SHIFT_LIST: Checking for employees assigned to shift before deletion');
        // Check if the shift has assigned employees in the shift object
        if (shift.assignedEmployeeIds.isNotEmpty) {
          print('SHIFT_LIST: Shift has ${shift.assignedEmployeeIds.length} assigned employees, need to remove them first');
          
          // Show a dialog asking if the user wants to remove all employees first
          final bool? removeEmployees = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Remove Employees'),
              content: Text('This shift has ${shift.assignedEmployeeIds.length} employees assigned to it. Would you like to remove all employees and then delete the shift?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('REMOVE & DELETE'),
                ),
              ],
            ),
          );
          
          if (removeEmployees != true) {
            // User cancelled the operation
            setState(() {
              _isLoading = false;
            });
            print('SHIFT_LIST: User cancelled removing employees and deleting shift');
            return;
          }
          
          // Show a progress dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Removing Employees'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Removing employees from shift...'),
                ],
              ),
            ),
          );
          
          // Use the new repository method to remove all employees
          print('SHIFT_LIST: Calling repository to remove all employees from shift ${shift.id}');
          final removeResponse = await _employeeShiftRepository.removeAllEmployeesFromShift(shift.id!);
          
          // Close the progress dialog
          if (mounted) Navigator.of(context).pop();
          
          if (!removeResponse.success) {
            setState(() {
              _isLoading = false;
            });
            
            print('SHIFT_LIST: Failed to remove employees: ${removeResponse.errorMessage}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to remove employees: ${removeResponse.errorMessage}')),
            );
            return;
          }
          
          print('SHIFT_LIST: Successfully removed all employees from shift');
        }
        
        // Now try deleting the shift
        print('SHIFT_LIST: Attempting to delete shift with ID: ${shift.id}');
        final response = await _repository.deleteShift(shift.id!);
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          if (response.success) {
            print('SHIFT_LIST: Shift deleted successfully');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Shift deleted successfully')),
            );
            // Refresh shifts list
            _loadShifts();
          } else {
            print('SHIFT_LIST: Failed to delete shift: ${response.errorMessage}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete shift: ${response.errorMessage}')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          print('SHIFT_LIST: Exception deleting shift: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      print('SHIFT_LIST: User cancelled deletion');
    }
  }

  // New method to directly assign an employee to a shift
  Future<bool> _assignEmployeeToShift(String employeeId, String shiftId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Create API request with required parameters
      final DateTime assignedDate = DateTime.now();
      final bool isTransfer = false;
      
      print('SHIFT_LIST: Assigning employee $employeeId to shift $shiftId');
      
      // Make API call
      final response = await _employeeShiftRepository.assignEmployeeToShift(
        employeeId,
        shiftId,
        assignedDate,
        isTransfer,
      );
      
      setState(() {
        _isLoading = false;
      });
      
      if (response.success) {
        print('SHIFT_LIST: Employee assigned successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee assigned to shift successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear all cached employee data to force fresh load
        setState(() {
          _cachedEmployeeData.clear();
        });
        
        // Refresh shifts list immediately
        await _loadShifts();
        
        return true;
      } else {
        print('SHIFT_LIST: Failed to assign employee: ${response.errorMessage}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign employee: ${response.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      print('SHIFT_LIST: Exception assigning employee: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  // Load all employees for assignment
  Future<List<Employee>> _loadEmployeesForAssignment() async {
    try {
      final response = await _employeeRepository.getAllEmployees();
      if (response.success && response.data != null) {
        // Only show active employees
        return response.data!.where((emp) => emp.isActive).toList();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load employees: ${response.errorMessage ?? "Unknown error"}')),
        );
        return [];
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading employees: $e')),
      );
      return [];
    }
  }
  
  // Show dialog to select an employee to assign
  Future<bool> _showAssignEmployeeDialog(Shift shift) async {
    if (shift.id == null || shift.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot assign to shift: Missing shift ID')),
      );
      return false;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    // Load employees
    final employees = await _loadEmployeesForAssignment();
    
    setState(() {
      _isLoading = false;
    });
    
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No employees available for assignment')),
      );
      return false;
    }
    
    // Show dialog to select an employee
    if (!mounted) return false;
    
    String? selectedEmployeeId;
    
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(
            maxHeight: 500,
            maxWidth: 400,
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha:0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_add_alt_1,
                            color: AppTheme.primaryBlue,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Assign Staff to Shift',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select an employee to assign to this shift',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              const Divider(height: 1),
              
              // Employee list
              Flexible(
                child: ListView.separated(
            shrinkWrap: true,
                  padding: EdgeInsets.zero,
            itemCount: employees.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final employee = employees[index];
              return ListTile(
                      dense: false,
                leading: CircleAvatar(
                        backgroundColor: _getEmployeeRoleColor(employee.role).withValues(alpha:0.2),
                  child: Text(
                    '${employee.firstName.isNotEmpty ? employee.firstName[0] : ""}${employee.lastName.isNotEmpty ? employee.lastName[0] : ""}',
                          style: TextStyle(
                            color: _getEmployeeRoleColor(employee.role),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        '${employee.firstName} ${employee.lastName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        employee.role,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.black54,
                        ),
                      ),
                onTap: () {
                  selectedEmployeeId = employee.id;
                  Navigator.pop(context);
                },
              );
            },
          ),
          ),
        ],
          ),
        ),
      ),
    );
    
    // If an employee was selected, assign them to the shift
    if (selectedEmployeeId != null) {
      final success = await _assignEmployeeToShift(selectedEmployeeId!, shift.id!);
      return success; // Return whether assignment was successful
    }
    
    return false;
  }
  
  // Navigate to assign staff screen or show dialog
  void _navigateToAssignStaff(Shift shift) async {
    print('SHIFT_LIST: Showing assign staff dialog for shift ${shift.id}');
    final wasAssigned = await _showAssignEmployeeDialog(shift);
    
    // If an employee was assigned, refresh the shift details view
    if (wasAssigned == true) {
      print('SHIFT_LIST: Employee was assigned, refreshing shift details');
      // Force refresh of shift data by clearing cache and reloading data
      await _refreshShifts();
      
      // If we're in the shift details view, close and reopen it with fresh data
      if (mounted) {
        // Get the updated shift data
        final updatedShiftIndex = _shifts.indexWhere((s) => s.id == shift.id);
        if (updatedShiftIndex >= 0) {
          _showShiftDetails(_shifts[updatedShiftIndex]);
        }
      }
    }
  }

  // Update the method to remove an employee from a shift
  Future<void> _removeEmployeeFromShift(String employeeId, String shiftId, String employeeName) async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Employee'),
        content: Text('Are you sure you want to remove $employeeName from this shift?\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('SHIFT_LIST: Removing employee $employeeId from shift $shiftId');
      final response = await _employeeShiftRepository.removeEmployeeFromShift(employeeId, shiftId);
      
      setState(() {
        _isLoading = false;
      });
      
      if (response.success) {
        print('SHIFT_LIST: Employee removed successfully');
    ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$employeeName has been removed from the shift'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh shifts list to update UI
        _loadShifts();
      } else {
        print('SHIFT_LIST: Failed to remove employee: ${response.errorMessage}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove employee: ${response.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      print('SHIFT_LIST: Exception removing employee: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Get refresh status of shifts and employee assignments
  Future<void> _refreshShifts() async {
    print('SHIFT_LIST: Refreshing shifts and staff assignments');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing shifts...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    // Clear the employee cache to force fresh data
    setState(() {
      _cachedEmployeeData.clear();
    });
    
    // Reload shifts
    await _loadShifts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light gray background color
      appBar: AppBar(
        title: const Text('Shift Schedule'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh, 
              color: Colors.white,
            ),
            tooltip: 'Refresh',
            onPressed: _refreshShifts,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Background decoration
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primaryBlue.withValues(alpha:0.05),
                      Colors.white.withValues(alpha:0.5),
                      Colors.white,
                    ],
                    stops: const [0.0, 0.2, 0.4],
                  ),
                ),
              ),
            ),
            
            // Main content
            _errorMessage.isNotEmpty && _shifts.isEmpty
                ? _buildErrorView()
                : _buildShiftsList(),
            
            // Loading overlay - only show during initial load or explicit refresh
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha:0.1),
                child: Center(
                  child: Card(
                    elevation: 4,
                    shadowColor: AppTheme.primaryBlue.withValues(alpha:0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Loading...',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddShift,
        backgroundColor: AppTheme.primaryBlue,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        label: Text(
          'Add Shift',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha:0.15),
              spreadRadius: 0,
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha:0.12),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha:0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Failed to Load Shifts',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: GoogleFonts.poppins(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              height: 48,
              child: FilledButton.icon(
                onPressed: _loadShifts,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  'Try Again',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                style: AppTheme.primaryButtonStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftsList() {
    print('SHIFT_LIST: Building shifts list with ${_shifts.length} shifts');
    return Column(
      children: [
        // Error banner if there's an error but we have mock data
        if (_errorMessage.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            color: Colors.red.shade100,
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade800, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to load shifts: $_errorMessage',
                    style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        
        // Updated header with app theme styling
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Active Shifts',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_shifts.length} shifts',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Shifts list with improved padding and physics
        Expanded(
          child: _shifts.isEmpty
              ? _buildEmptyState(
                  'No Shifts Found',
                  'Add a new shift by tapping the + button',
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80), // Reduced padding
                  itemCount: _shifts.length,
                  itemBuilder: (context, index) {
                    final shift = _shifts[index];
                    print('SHIFT_LIST: Rendering shift ${index + 1}: ID=${shift.id}, Number=${shift.shiftNumber}');
                    return _buildShiftCard(shift, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha:0.15),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha:0.12),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha:0.12),
                    blurRadius: 15,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                size: 54,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 180,
              height: 48,
              child: FilledButton.icon(
                onPressed: _navigateToAddShift,
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                label: Text(
                  'Add Shift',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                style: AppTheme.primaryButtonStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCard(Shift shift, int index) {
    // Improved color scheme based on shift number
    final List<Map<String, dynamic>> shiftStyles = [
      {
        'color': AppTheme.primaryBlue,
        'gradient': [AppTheme.primaryBlue.withValues(alpha:0.8), AppTheme.primaryBlue],
        'label': 'Morning Shift',
        'icon': Icons.wb_twilight_rounded,
      },
      {
        'color': AppTheme.primaryOrange,
        'gradient': [AppTheme.primaryOrange.withValues(alpha:0.8), AppTheme.primaryOrange],
        'label': 'Afternoon Shift',
        'icon': Icons.sunny,
      },
      {
        'color': AppTheme.primaryBlue,
        'gradient': [AppTheme.primaryBlue.withValues(alpha:0.8), AppTheme.primaryBlue],
        'label': 'Evening Shift',
        'icon': Icons.nights_stay,
      },
      {
        'color': Colors.indigo,
        'gradient': [Colors.indigo.withValues(alpha:0.8), Colors.indigo],
        'label': 'Night Shift',
        'icon': Icons.nightlight_round,
      },
    ];
    
    final shiftStyle = shiftStyles[(shift.shiftNumber - 1) % shiftStyles.length];
    final color = shiftStyle['color'] as Color;
    final gradient = shiftStyle['gradient'] as List<Color>;
    final label = shiftStyle['label'] as String;
    final icon = shiftStyle['icon'] as IconData;
    
    // Check if shift has missing ID
    final bool hasMissingId = shift.id == null || shift.id!.isEmpty;
    
    // Get assigned employee count
    final int assignedCount = shift.assignedEmployeeIds?.length ?? 0;
    
    // Format the shift date - assume current date if not available
    final DateTime shiftDate = shift.shiftDate ?? DateTime.now();
    final String formattedDate = 
        '${shiftDate.day}/${shiftDate.month}/${shiftDate.year}';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shadowColor: color.withValues(alpha:0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha:0.2)),
      ),
      child: InkWell(
        onTap: () => _showShiftDetails(shift),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient background - improved layout to prevent overflow
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row with shift number and date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Shift number with icon
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha:0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              icon,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Shift #${shift.shiftNumber}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      
                      // Date
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha:0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedDate,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Time info
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded, 
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${shift.startTime} - ${shift.endTime}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha:0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${shift.shiftDuration}h',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Staff info and actions - with improved layout to prevent overflow
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Staff info
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: assignedCount > 0 
                                ? Colors.green.withValues(alpha:0.1) 
                                : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            assignedCount > 0 ? Icons.people : Icons.people_outline,
                            size: 16,
                            color: assignedCount > 0 ? Colors.green : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            assignedCount > 0 
                                ? '$assignedCount Staff Assigned' 
                                : 'No Staff Assigned',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: assignedCount > 0 ? Colors.green : Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 4),
                  
                  // Action buttons
                  if (!hasMissingId) 
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Assign staff button
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: IconButton(
                            onPressed: () => _navigateToAssignStaff(shift),
                            icon: Icon(
                              assignedCount > 0 ? Icons.group : Icons.person_add_alt_outlined,
                              size: 18,
                              color: Colors.white,
                            ),
                            tooltip: assignedCount > 0 ? 'Manage Staff' : 'Assign Staff',
                            style: IconButton.styleFrom(
                              backgroundColor: color,
                              padding: const EdgeInsets.all(0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // Edit button
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: IconButton(
                            onPressed: () => _navigateToEditShift(shift),
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: Colors.white,
                            ),
                            tooltip: 'Edit Shift',
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.secondaryGray,
                              padding: const EdgeInsets.all(0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShiftDetails(Shift shift) {
    // Show bottom sheet with shift details
    print('SHIFT_LIST: Showing details for shift ID: ${shift.id}');
    
    // Always clear cached data for this shift to get fresh data
    if (shift.id != null && shift.id!.isNotEmpty) {
      // Remove this shift from cache to force reload
      _cachedEmployeeData.remove(shift.id!);
      print('SHIFT_LIST: Cleared cached employee data for shift ${shift.id} to ensure fresh data');
    }
    
    // Check if shift has missing ID
    final bool hasMissingId = shift.id == null || shift.id!.isEmpty;
    
    // Simplified color scheme for shift styles
    final List<Map<String, dynamic>> shiftStyles = [
      {
        'color': AppTheme.primaryBlue,
        'label': 'Morning Shift',
        'icon': Icons.wb_twilight_rounded,
      },
      {
        'color': AppTheme.primaryBlue,
        'label': 'Afternoon Shift',
        'icon': Icons.sunny,
      },
      {
        'color': AppTheme.primaryBlue,
        'label': 'Evening Shift',
        'icon': Icons.nights_stay,
      },
      {
        'color': AppTheme.primaryBlue,
        'label': 'Night Shift',
        'icon': Icons.nightlight_round,
      },
    ];
    
    final shiftStyle = shiftStyles[(shift.shiftNumber - 1) % shiftStyles.length];
    final color = shiftStyle['color'] as Color;
    final label = shiftStyle['label'] as String;
    final icon = shiftStyle['icon'] as IconData;
    
    // Pre-load the employee data right away
    if (!hasMissingId && shift.id != null) {
      print('SHIFT_LIST: Pre-loading employee data for shift ${shift.id}');
      _forceReloadEmployeeData(shift.id!);
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Use a StatefulBuilder to manage local state for the bottom sheet
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              snap: true,
              snapSizes: const [0.7, 0.95],
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag handle at top
                        Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 10),
                          height: 5,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                        
                        // Header
                        Container(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha:0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Top row with icon and shift info
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left icon
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha:0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      icon,
                                      color: color,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  
                                  // Shift details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Shift #${shift.shiftNumber}',
                                              style: TextStyle(
                                                color: Colors.grey.shade800,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),

                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time_rounded,
                                              color: Colors.grey.shade700,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${shift.startTime} - ${shift.endTime}',
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha:0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: color.withValues(alpha:0.2), width: 1),
                                              ),
                                              child: Text(
                                                '${shift.shiftDuration}h',
                                                style: TextStyle(
                                                  color: color,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Missing ID warning
                        if (hasMissingId)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                            color: Colors.red.withValues(alpha:0.1),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Missing ID - Cannot edit or manage staff',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Content area with employees
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            // Disable pull-to-refresh behavior
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                            children: [
                              // Employee section header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryBlue,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Assigned Staff',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),

                                ],
                              ),

                              const SizedBox(height: 16),

                              // Employee list - ALWAYS FETCH FRESH DATA
                              if (hasMissingId)
                                _buildErrorCard(
                                  'Cannot load employee details for a shift with missing ID.',
                                  icon: Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                )
                              else
                                FutureBuilder<List<Employee>>(
                                  // Use cached data if available
                                  future: _cachedEmployeeData.containsKey(shift.id!) 
                                      ? Future.value(_cachedEmployeeData[shift.id!]) 
                                      : _forceReloadEmployeeData(shift.id!),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(vertical: 32.0),
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }

                                    if (snapshot.hasError) {
                                      print('SHIFT_LIST: Error loading employees: ${snapshot.error}');
                                      return _buildErrorCard(
                                        'Failed to load employee details: ${snapshot.error}',
                                        icon: Icons.error_outline,
                                        color: Colors.red,
                                      );
                                    }

                                    final employees = snapshot.data ?? [];
                                    print('SHIFT_LIST: Displaying ${employees.length} employees for shift ${shift.id}');

                                    return _buildEmployeeListContent(employees, shift, color);
                                  },
                                ),
                            ],
                          ),
                        ),
                        
                        // Bottom action bar
                        if (!hasMissingId) _buildBottomActionBar(shift, color)
                      ],
                    ),
                  ),
                );
              },
            );
          }
        );
      },
    );
  }
  
  // Helper method to build employee list content
  Widget _buildEmployeeListContent(List<Employee> employees, Shift shift, Color accentColor) {
    print('SHIFT_LIST: Building employee list content with ${employees.length} employees');
    
    if (employees.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 40,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No employees assigned yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Assign" to add staff members',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    // Print detailed info about each employee for debugging
    for (var employee in employees) {
      print('SHIFT_LIST: Employee Name: "${employee.firstName} ${employee.lastName}"');
      print('SHIFT_LIST: Employee Role: "${employee.role}"');
      // Look for "Pump Manager" specifically
      if (employee.firstName.contains('Pump') || employee.lastName.contains('Manager')) {
        print('SHIFT_LIST: Found Pump Manager! Detailed info:');
        print('SHIFT_LIST: firstName: "${employee.firstName}"');
        print('SHIFT_LIST: lastName: "${employee.lastName}"');
        print('SHIFT_LIST: role: "${employee.role}"');
        print('SHIFT_LIST: id: "${employee.id}"');
      }
    }

    // Use the sorting utility to group employees by role
    final roleGroups = _sortEmployeesByRole(employees);
    final managers = roleGroups[0];
    final attendants = roleGroups[1];
    final admins = roleGroups[2];
    final others = roleGroups[3];
    
    // Build the staff summary card
    final Widget staffSummaryCard = Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Staff count icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha:0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.groups_rounded,
              size: 24,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 16),
          
          // Staff count and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employees.length == 1 
                      ? '1 Staff Member' 
                      : '${employees.length} Staff Members',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (managers.isNotEmpty)
                      _buildRolePill('${managers.length} Manager${managers.length > 1 ? 's' : ''}', Colors.indigo),
                    if (attendants.isNotEmpty)
                      _buildRolePill('${attendants.length} Attendant${attendants.length > 1 ? 's' : ''}', Colors.teal),
                    if (admins.isNotEmpty)
                      _buildRolePill('${admins.length} Admin${admins.length > 1 ? 's' : ''}', Colors.deepOrange),
                    if (others.isNotEmpty)
                      _buildRolePill('${others.length} Other', Colors.blueGrey),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    
    // Build employee listings by role group
    final Widget employeeListings = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (managers.isNotEmpty) ...[
          _buildRoleHeader('Managers', Colors.indigo, Icons.admin_panel_settings),
          const SizedBox(height: 4),
          ...managers.map((employee) => _buildEmployeeCard(employee, shift, accentColor)),
          const SizedBox(height: 24),
        ],
        
        if (attendants.isNotEmpty) ...[
          _buildRoleHeader('Attendants', Colors.teal, Icons.person),
          const SizedBox(height: 4),
          ...attendants.map((employee) => _buildEmployeeCard(employee, shift, accentColor)),
          const SizedBox(height: 24),
        ],
        
        if (admins.isNotEmpty) ...[
          _buildRoleHeader('Admins', Colors.deepOrange, Icons.security),
          const SizedBox(height: 4),
          ...admins.map((employee) => _buildEmployeeCard(employee, shift, accentColor)),
          const SizedBox(height: 24),
        ],
        
        if (others.isNotEmpty) ...[
          _buildRoleHeader('Other Staff', Colors.blueGrey, Icons.person_outline),
          const SizedBox(height: 4),
          ...others.map((employee) => _buildEmployeeCard(employee, shift, accentColor)),
        ],
      ],
    );
    
    return Column(
      children: [
        // Refresh button
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _refreshShiftEmployeeData(shift),
              tooltip: 'Refresh staff data',
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text(
                'Assign',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () => _navigateToAssignStaff(shift),
            ),
          ],
        ),
        const SizedBox(height: 8),
        staffSummaryCard,
        employeeListings,
      ],
    );
  }
  
  // Helper to refresh employee data for a specific shift
  Future<void> _refreshShiftEmployeeData(Shift shift) async {
    if (shift.id == null || shift.id!.isEmpty) return;
    
    // Clear cached data for this shift to force reload
    _cachedEmployeeData.remove(shift.id!);
    
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing staff data...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    // Force reload employee data
    await _forceReloadEmployeeData(shift.id!);
    
    // Force refresh of UI
    setState(() {});
  }
  
  // Helper to build role pills for the summary card
  Widget _buildRolePill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha:0.2), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
  
  // Helper to show error messages
  Widget _buildErrorCard(String message, {required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha:0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade700),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build bottom action bar
  Widget _buildBottomActionBar(Shift shift, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Assign Staff button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _navigateToAssignStaff(shift);
              },
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text(
                'Assign Staff',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Edit button
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _navigateToEditShift(shift);
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text(
              'Edit',
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade400),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Delete button
          IconButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteShift(shift);
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Shift',
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha:0.1),
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to build role section headers
  Widget _buildRoleHeader(String title, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4, top: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: color.withValues(alpha:0.2),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  // Sort and group employees by their roles
  List<List<Employee>> _sortEmployeesByRole(List<Employee> employees) {
    final managers = <Employee>[];
    final attendants = <Employee>[];
    final admins = <Employee>[];
    final others = <Employee>[];

    for (var employee in employees) {
      if (_isManager(employee)) {
        managers.add(employee);
      } else if (employee.role.trim().toLowerCase().contains('admin')) {
        admins.add(employee);
      } else if (employee.role.trim().toLowerCase().contains('attendant')) {
        attendants.add(employee);
      } else {
        others.add(employee);
      }
    }

    return [managers, attendants, admins, others];
  }

  // Helper to get color based on employee role
  Color _getEmployeeRoleColor(String role) {
    final normalizedRole = role.trim().toLowerCase();
    
    if (normalizedRole.contains('manager')) {
      return Colors.indigo;
    } else if (normalizedRole.contains('attendant')) {
      return Colors.teal;
    } else if (normalizedRole.contains('admin')) {
      return Colors.deepOrange;
    } else {
      return AppTheme.primaryBlue;
    }
  }

  // Helper to determine if an employee is a manager based on role or name
  bool _isManager(Employee employee) {
    // Check if role contains manager
    if (employee.role.trim().toLowerCase().contains('manager')) {
      return true;
    }
    
    // Check if name contains pump manager
    if (employee.firstName.toLowerCase().contains('pump') && 
        employee.lastName.toLowerCase().contains('manager')) {
      return true;
    }
    
    // Check if first name is "Pump Manager"
    if (employee.firstName.toLowerCase() == 'pump manager') {
      return true;
    }
    
    return false;
  }

  // Force reload employee data for a specific shift
  Future<List<Employee>> _forceReloadEmployeeData(String shiftId) async {
    print('SHIFT_LIST: Loading employee data for shift $shiftId');
    try {
      final response = await _repository.getEmployeeDetailsForShift(shiftId);
      if (response.success && response.data != null) {
        // Update the cache with fresh data
        _cachedEmployeeData[shiftId] = response.data!;
        print('SHIFT_LIST: Successfully loaded ${response.data!.length} employees for shift $shiftId');
        
        // Add debug info for roles
        for (var employee in response.data!) {
          developer.log('Employee role data: ${employee.firstName} ${employee.lastName} - Role: "${employee.role}"');
        }
        
        return response.data!;
      } else {
        print('SHIFT_LIST: Failed to load employee data: ${response.errorMessage}');
        return [];
      }
    } catch (e) {
      print('SHIFT_LIST: Exception loading employee data: $e');
      return [];
    }
  }

  Widget _buildEmployeeCard(Employee employee, Shift shift, Color accentColor) {
    // Determine if this is a manager (either by role or by name)
    final bool isManager = _isManager(employee);
    
    // Set the effective role for display purposes
    final String displayRole = isManager ? 'Manager' : employee.role;
    final Color roleColor = isManager ? Colors.indigo : _getEmployeeRoleColor(employee.role);
    final IconData roleIcon = isManager ? Icons.admin_panel_settings : _getRoleIcon(employee.role);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: roleColor.withValues(alpha:0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: roleColor.withValues(alpha:0.1),
              child: Text(
                '${employee.firstName.isNotEmpty ? employee.firstName[0] : ""}${employee.lastName.isNotEmpty ? employee.lastName[0] : ""}',
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            
            // Employee info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${employee.firstName} ${employee.lastName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          roleIcon,
                          size: 14,
                          color: roleColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          displayRole, // Use effective role
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600, // Made bolder for better visibility
                            color: roleColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Remove button
            IconButton(
              onPressed: () {
                if (employee.id != null) {
                  Navigator.pop(context);
                  _removeEmployeeFromShift(
                    employee.id!,
                    shift.id!,
                    '${employee.firstName} ${employee.lastName}'
                  );
                }
              },
              icon: const Icon(
                Icons.person_remove,
                color: Colors.red,
                size: 18,
              ),
              tooltip: 'Remove from shift',
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha:0.1),
                padding: const EdgeInsets.all(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper to get icon based on employee role
  IconData _getRoleIcon(String role) {
    final normalizedRole = role.trim().toLowerCase();
    
    if (normalizedRole.contains('manager')) {
      return Icons.admin_panel_settings;
    } else if (normalizedRole.contains('attendant')) {
      return Icons.person;
    } else if (normalizedRole.contains('admin')) {
      return Icons.security;
    } else {
      return Icons.person;
    }
  }
} 