import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/shift_repository.dart';
import '../../models/shift_model.dart';
import '../../theme.dart';

import 'dart:developer' as developer;

class AddShiftScreen extends StatefulWidget {
  const AddShiftScreen({super.key});

  @override
  State<AddShiftScreen> createState() => _AddShiftScreenState();
}

class _AddShiftScreenState extends State<AddShiftScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _shiftNumberController = TextEditingController();
  final _shiftDurationController = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  
  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    _shiftNumberController.dispose();
    _shiftDurationController.dispose();
    super.dispose();
  }
  
  // Helper to show time picker and update the text field
  Future<void> _selectTime(BuildContext context, TextEditingController controller, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        
        // Format as HH:mm
        final hour = picked.hour.toString().padLeft(2, '0');
        final minute = picked.minute.toString().padLeft(2, '0');
        controller.text = '$hour:$minute';
        
        // If both times are set, calculate duration
        if (_startTime != null && _endTime != null) {
          _calculateDuration();
        }
      });
    }
  }

  // Calculate shift duration in hours
  void _calculateDuration() {
    if (_startTime == null || _endTime == null) return;
    
    // Convert to minutes
    int startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    int endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    
    // Handle crossing midnight
    if (endMinutes < startMinutes) {
      endMinutes += 24 * 60; // Add 24 hours
    }
    
    // Calculate duration in minutes, then convert to hours
    int durationMinutes = endMinutes - startMinutes;
    int durationHours = (durationMinutes / 60).round(); // Round to nearest hour as an integer
    _shiftDurationController.text = durationHours.toString();
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
      print('ADD_SHIFT: Form validated, preparing to submit');
      
      // Run diagnostic check if we had previous errors
      if (_errorMessage.contains('Method Not Allowed') || _errorMessage.contains('error occurred')) {
        print('ADD_SHIFT: Previous errors detected, running diagnostic check...');
        final repository = ShiftRepository();
        // await repository.checkAllowedMethods();
      }
      
      // Create shift object
      final shift = Shift(
        startTime: _startTimeController.text,
        endTime: _endTimeController.text,
        shiftNumber: int.parse(_shiftNumberController.text),
        shiftDuration: int.parse(_shiftDurationController.text),
      );
      
      developer.log('Submitting shift: ${shift.toJson()}');
      print('ADD_SHIFT: Submitting shift with data: ${shift.toJson()}');
      
      // Call repository to add shift
      final repository = ShiftRepository();
      print('ADD_SHIFT: Calling repository.addShift()');
      final response = await repository.addShift(shift);
      print('ADD_SHIFT: Repository call completed, success=${response.success}');
      
      if (!mounted) return;
      
      if (response.success) {
        developer.log('Shift added successfully: ${response.data}');
        print('ADD_SHIFT: SUCCESS! Shift added successfully');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Shift added successfully'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        
        // Return true to refresh the shifts list screen if navigating back
        Navigator.pop(context, true);
      } else {
        setState(() {
          _errorMessage = response.errorMessage ?? 'Failed to add shift';
        });
        
        developer.log('Failed to add shift: $_errorMessage');
        print('ADD_SHIFT: ERROR: $_errorMessage');
        
        // Show a more detailed error dialog
        _showErrorDialog(_errorMessage);
      }
    } catch (e) {
      developer.log('Exception submitting form: $e');
      print('ADD_SHIFT: EXCEPTION: $e');
      
      setState(() {
        _errorMessage = 'Error: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: $e'),
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
  
  // Show error dialog with details
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error Adding Shift'),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              
              // Update error message with technical suggestion
              setState(() {
                _errorMessage = 'If this problem persists, please check that your login token is valid and try again.';
              });
            },
            child: const Text('MORE INFO'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add New Shift'),
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
                    'New Shift',
                    style: AppTheme.headingStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add details for the new shift assignment',
                    style: AppTheme.subheadingStyle.copyWith(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Shift Details Card
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
                          // Shift Number field
                          Text(
                            'Shift Number',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _shiftNumberController,
                            decoration: InputDecoration(
                              hintText: 'Enter shift number',
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
                              prefixIcon: Icon(Icons.tag, color: AppTheme.primaryBlue),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a shift number';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Start Time field
                          Text(
                            'Start Time',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _selectTime(context, _startTimeController, true),
                            child: AbsorbPointer(
                              child: TextFormField(
                                controller: _startTimeController,
                                decoration: InputDecoration(
                                  hintText: 'Select start time',
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
                                  prefixIcon: Icon(Icons.access_time, color: AppTheme.primaryBlue),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a start time';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // End Time field
                          Text(
                            'End Time',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _selectTime(context, _endTimeController, false),
                            child: AbsorbPointer(
                              child: TextFormField(
                                controller: _endTimeController,
                                decoration: InputDecoration(
                                  hintText: 'Select end time',
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
                                  prefixIcon: Icon(Icons.access_time, color: AppTheme.primaryBlue),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select an end time';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Shift Duration field (auto-calculated)
                          Text(
                            'Shift Duration',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _shiftDurationController,
                            decoration: InputDecoration(
                              hintText: 'Duration in hours',
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
                              prefixIcon: Icon(Icons.timer, color: AppTheme.primaryBlue),
                              suffixText: 'Hours',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              helperText: 'Automatically calculated from start and end times',
                              helperStyle: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter shift duration';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
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
                                  'Add Shift',
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