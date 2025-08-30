import 'package:flutter/material.dart';
import '../../api/shift_repository.dart';
import '../../models/shift_model.dart';
import '../../theme.dart';
import 'dart:developer' as developer;
import '../../api/employee_shift_repository.dart';

class EditShiftScreen extends StatefulWidget {
  final Shift shift;
  
  const EditShiftScreen({
    super.key,
    required this.shift,
  });

  @override
  State<EditShiftScreen> createState() => _EditShiftScreenState();
}

class _EditShiftScreenState extends State<EditShiftScreen> {
  final _formKey = GlobalKey<FormState>();
  final ShiftRepository _repository = ShiftRepository();
  final EmployeeShiftRepository _employeeShiftRepository = EmployeeShiftRepository();
  
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late int _shiftDuration;
  
  bool _isSaving = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Initialize time values from the shift
    _startTime = _parseTimeString(widget.shift.startTime);
    _endTime = _parseTimeString(widget.shift.endTime);
    _shiftDuration = widget.shift.shiftDuration;
    
    developer.log('Editing shift: ID=${widget.shift.id}, Start=${widget.shift.startTime}, End=${widget.shift.endTime}');
  }
  
  // Helper method to parse time strings like "08:00" to TimeOfDay
  TimeOfDay _parseTimeString(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
  
  // Helper method to format TimeOfDay to string like "08:00"
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  
  // Calculate shift duration in hours
  void _calculateShiftDuration() {
    final startHours = _startTime.hour + (_startTime.minute / 60);
    final endHours = _endTime.hour + (_endTime.minute / 60);
    
    // Handle cases where shift crosses midnight
    double durationHours;
    if (endHours < startHours) {
      durationHours = (24 - startHours) + endHours;
    } else {
      durationHours = endHours - startHours;
    }
    
    setState(() {
      _shiftDuration = durationHours.round();
    });
    
    developer.log('Calculated shift duration: $_shiftDuration hours');
  }
  
  // Show time picker dialog
  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );
    
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
      
      // Recalculate shift duration
      _calculateShiftDuration();
    }
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
  
  // Save updated shift
  Future<void> _saveShift() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });
    
    try {
      // Check if the shift ID exists and is valid
      if (widget.shift.id == null || widget.shift.id!.isEmpty) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Cannot update shift: Missing or invalid shift ID';
        });
        developer.log('Failed to update shift: Missing or invalid shift ID');
        return;
      }

      if (widget.shift.id!.contains('mock')) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Cannot update demo shifts';
        });
        developer.log('Failed to update shift: Attempt to update demo shift');
        return;
      }
      
      // Create updated shift object
      final updatedShift = Shift(
        id: widget.shift.id,
        startTime: _formatTimeOfDay(_startTime),
        endTime: _formatTimeOfDay(_endTime),
        shiftNumber: widget.shift.shiftNumber,
        shiftDuration: _shiftDuration,
      );
      
      developer.log('Saving updated shift with ID: ${widget.shift.id}');
      developer.log('Shift data: ${updatedShift.toJson()}');
      
      // Call repository to update the shift
      final response = await _repository.updateShift(
        widget.shift.id!,
        updatedShift,
      );
      
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        if (response.success) {
          developer.log('Shift updated successfully');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Shift updated successfully'),
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
          setState(() {
            _errorMessage = response.errorMessage ?? 'Failed to update shift';
          });
          developer.log('Failed to update shift: $_errorMessage');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString();
        });
      }
      developer.log('Exception in _saveShift: $e');
    }
  }
  
  // Update the delete method to handle assigned employees
  Future<void> _confirmDeleteShift() async {
    // Check if the shift ID exists and is valid
    if (widget.shift.id == null || widget.shift.id!.isEmpty) {
      setState(() {
        _errorMessage = 'Cannot delete shift: Missing or invalid shift ID';
      });
      developer.log('Failed to delete shift: Missing or invalid shift ID');
      return;
    }

    if (widget.shift.id!.contains('mock')) {
      setState(() {
        _errorMessage = 'Cannot delete demo shifts';
      });
      developer.log('Failed to delete shift: Attempt to delete demo shift');
      return;
    }
    
    // Check if there are employees assigned to this shift
    bool hasAssignedEmployees = widget.shift.assignedEmployeeIds.isNotEmpty;
    
    // Show confirmation dialog with appropriate message
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shift'),
        content: Text(
          hasAssignedEmployees
            ? 'This shift has assigned employees. All employee assignments will be removed before deleting the shift.\n\nAre you sure you want to delete Shift #${widget.shift.shiftNumber}?\nThis action cannot be undone.'
            : 'Are you sure you want to delete Shift #${widget.shift.shiftNumber}?\nThis action cannot be undone.'
        ),
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
    
    if (confirm != true) return;
    
    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });
    
    try {
      developer.log('Deleting shift with ID: ${widget.shift.id}');
      
      // If there are employees assigned, we need to get their details first
      if (hasAssignedEmployees) {
        // Get assigned employees
        final employeesResponse = await _repository.getEmployeeDetailsForShift(widget.shift.id!);
        
        if (!employeesResponse.success || employeesResponse.data == null) {
          developer.log('Failed to get employee details for shift: ${employeesResponse.errorMessage}');
          setState(() {
            _isSaving = false;
            _errorMessage = 'Failed to get employee details for shift: ${employeesResponse.errorMessage}';
          });
          return;
        }
        
        final employees = employeesResponse.data!;
        developer.log('Found ${employees.length} employees assigned to this shift');
        
        // For each employee, we need to get the employee shift ID and delete it
        for (final employee in employees) {
          if (employee.id != null) {
            // Get the employee shift ID
            final idResponse = await _employeeShiftRepository.getEmployeeShiftId(
              employee.id!,
              widget.shift.id!
            );
            
            if (idResponse.success && idResponse.data != null) {
              final employeeShiftId = idResponse.data!;
              
              // Delete the employee shift
              developer.log('Deleting employee shift: $employeeShiftId');
              final deleteResponse = await _employeeShiftRepository.deleteEmployeeShift(employeeShiftId);
              
              if (!deleteResponse.success) {
                developer.log('Failed to delete employee shift: ${deleteResponse.errorMessage}');
                // Continue with other employees even if one fails
              }
            }
          }
        }
      }
      
      // Now try to delete the shift
      final response = await _repository.deleteShift(widget.shift.id!);
      
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        if (response.success) {
          developer.log('Shift deleted successfully');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Shift deleted successfully'),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          
          // Return true to indicate success and refresh the list
          Navigator.pop(context, true);
        } else {
          setState(() {
            _errorMessage = response.errorMessage ?? 'Failed to delete shift';
          });
          developer.log('Failed to delete shift: $_errorMessage');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString();
        });
        developer.log('Exception in _confirmDeleteShift: $e');
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Shift'),
          centerTitle: true,
          actions: [
            // Add delete button in app bar

          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Edit Shift',
                    style: AppTheme.headingStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Modify shift details and assignments',
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
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16.0),
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
                  
                  // Shift details card
                  _buildSectionTitle('Shift Details'),
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
                          // Header with shift number
                          Row(
                            children: [
                              Icon(Icons.assignment, color: AppTheme.primaryBlue),
                              const SizedBox(width: 8),
                              Text(
                                'Shift #${widget.shift.shiftNumber}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          
                          // Start Time
                          Text(
                            'Start Time',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _selectTime(context, true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                                color: Colors.grey.shade50,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time, color: AppTheme.primaryBlue),
                                  const SizedBox(width: 12),
                                  Text(
                                    _formatTimeOfDay(_startTime),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // End Time
                          Text(
                            'End Time',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _selectTime(context, false),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                                color: Colors.grey.shade50,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time, color: AppTheme.primaryBlue),
                                  const SizedBox(width: 12),
                                  Text(
                                    _formatTimeOfDay(_endTime),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Shift Duration
                          Text(
                            'Shift Duration',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                              color: Colors.grey.shade50,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.timer, color: AppTheme.primaryBlue),
                                const SizedBox(width: 12),
                                Text(
                                  '$_shiftDuration hours',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          Text(
                            'Automatically calculated from start and end times',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  _buildSectionTitle('Actions'),
                  
                  // Save Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveShift,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.save),
                                const SizedBox(width: 8),
                                const Text(
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
                  
                  const SizedBox(height: 16),
                  
                  // Delete Button
                  // SizedBox(
                  //   height: 52,
                  //   child: OutlinedButton.icon(
                  //     onPressed: _isSaving ? null : _confirmDeleteShift,
                  //     icon: const Icon(Icons.delete, color: Colors.red),
                  //     label: const Text(
                  //       'Delete Shift',
                  //       style: TextStyle(
                  //         fontSize: 16,
                  //         fontWeight: FontWeight.bold,
                  //       ),
                  //     ),
                  //     style: OutlinedButton.styleFrom(
                  //       foregroundColor: Colors.red,
                  //       side: BorderSide(color: Colors.red.shade300),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(16),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 