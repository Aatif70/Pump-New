import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../api/nozzle_reading_repository.dart';
import '../../api/nozzle_assignment_repository.dart';
import '../../api/nozzle_repository.dart';
import '../../api/employee_repository.dart';
import '../../models/nozzle_model.dart';
import '../../models/nozzle_reading_model.dart';
import '../../models/employee_nozzle_assignment_model.dart';
import '../../theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class SubmitStartReadingScreen extends StatefulWidget {
  final String? nozzleId;
  final String? shiftId;
  final String? fuelTankId;
  final String? petrolPumpId;

  const SubmitStartReadingScreen({
    Key? key,
    this.nozzleId,
    this.shiftId,
    this.fuelTankId,
    this.petrolPumpId,
  }) : super(key: key);

  @override
  _SubmitStartReadingScreenState createState() => _SubmitStartReadingScreenState();
}

class _SubmitStartReadingScreenState extends State<SubmitStartReadingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _meterReadingController = TextEditingController();
  DateTime? _recordedAt;
  File? _imageFile;
  bool _loading = false;
  String? _error;

  // IDs to be fetched
  String? _nozzleId;
  String? _shiftId;
  String? _fuelTankId;
  String? _petrolPumpId;
  String? _employeeId;

  bool _fetching = true;
  
  // Previous readings
  NozzleReading? _previousEndReading;
  NozzleReading? _previousStartReading;
  bool _fetchingPreviousReadings = false;
  
  // Nozzle selection dropdown data
  List<EmployeeNozzleAssignment> _nozzleAssignments = [];
  EmployeeNozzleAssignment? _selectedNozzleAssignment;
  bool _loadingNozzleAssignments = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    // Set date to current time - will be non-editable
    _recordedAt = DateTime.now();
  }

  Future<void> _initializeData() async {
    setState(() { _fetching = true; });
    
    // First try to use the passed data
    _nozzleId = widget.nozzleId;
    _shiftId = widget.shiftId;
    _fuelTankId = widget.fuelTankId;
    _petrolPumpId = widget.petrolPumpId;
    
    // Get current employee ID
    await _getCurrentEmployeeId();
    
    // Fetch nozzle assignments for dropdown
    await _fetchNozzleAssignments();
    
    // If any data is missing, try to get from SharedPreferences
    if (_nozzleId == null || _shiftId == null || _fuelTankId == null || _petrolPumpId == null) {
      await _loadFromPreferences();
    }
    
    // If still missing data, fetch from API
    if (_nozzleId == null || _shiftId == null || _fuelTankId == null || _petrolPumpId == null) {
      await _fetchAssignmentAndNozzle();
    } else {
      setState(() { _fetching = false; });
    }

    // Fetch previous end reading if we have a nozzle ID
    if (_nozzleId != null) {
      await _fetchPreviousEndReading();
    }
  }
  
  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _nozzleId = _nozzleId ?? prefs.getString('employee_nozzle_id');
      _shiftId = _shiftId ?? prefs.getString('employee_shift_id');
      _fuelTankId = _fuelTankId ?? prefs.getString('employee_fuel_tank_id');
      _petrolPumpId = _petrolPumpId ?? prefs.getString('employee_petrol_pump_id');
    } catch (e) {
      print('Error loading from preferences: $e');
    }
  }
  
  Future<void> _saveToPreferences() async {
    try {
      if (_nozzleId != null && _shiftId != null && _fuelTankId != null && _petrolPumpId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('employee_nozzle_id', _nozzleId!);
        await prefs.setString('employee_shift_id', _shiftId!);
        await prefs.setString('employee_fuel_tank_id', _fuelTankId!);
        await prefs.setString('employee_petrol_pump_id', _petrolPumpId!);
      }
    } catch (e) {
      print('Error saving to preferences: $e');
    }
  }

  Future<void> _fetchAssignmentAndNozzle() async {
    setState(() { _fetching = true; });
    try {
      // Get current employee
      final empResp = await EmployeeRepository().getCurrentEmployee();
      final employeeId = empResp.data?.id;
      if (employeeId == null) throw Exception('Employee not found');
      
      // Get nozzle assignment
      final assignResp = await NozzleAssignmentRepository().getEmployeeNozzleAssignments(employeeId);
      if (assignResp.data == null || assignResp.data!.isEmpty) throw Exception('No nozzle assignment found');
      final assignment = assignResp.data!.first;
      _nozzleId = assignment.nozzleId;
      _shiftId = assignment.shiftId;
      
      // Get nozzle details
      final nozzleResp = await NozzleRepository().getAllNozzles();
      
      // Check if we have nozzle data
      if (nozzleResp.data == null || nozzleResp.data!.isEmpty) {
        // No nozzles returned - handle this gracefully
        print('No nozzles returned from API');
        
        // Use default values as a fallback
        _fuelTankId = 'default_fuel_tank_id';
        _petrolPumpId = 'default_petrol_pump_id';
      } else {
        // Try to find the matching nozzle
        Nozzle? matchingNozzle;
        
        try {
          matchingNozzle = nozzleResp.data!.firstWhere(
            (n) => n.id == _nozzleId,
            orElse: () => Nozzle(
              id: '',
              fuelDispenserUnitId: 'default_dispenser',
              nozzleNumber: 0,
              status: 'inactive',
              fuelTankId: 'default_fuel_tank_id',
              petrolPumpId: 'default_petrol_pump_id',
            ),
          );
        } catch (e) {
          print('Error finding nozzle: $e');
          matchingNozzle = null;
        }
        
        if (matchingNozzle != null) {
          // Found matching nozzle
          _fuelTankId = matchingNozzle.fuelTankId ?? 'default_fuel_tank_id';
          _petrolPumpId = matchingNozzle.petrolPumpId ?? 'default_petrol_pump_id';
        } else {
          // Use the first nozzle as fallback
          print('Using first available nozzle as fallback');
          _fuelTankId = nozzleResp.data!.first.fuelTankId ?? 'default_fuel_tank_id';
          _petrolPumpId = nozzleResp.data!.first.petrolPumpId ?? 'default_petrol_pump_id';
        }
      }
      
      // Save to preferences for future use
      await _saveToPreferences();
    } catch (e) {
      print('Error in _fetchAssignmentAndNozzle: $e');
      // Set default values to prevent further errors
      _fuelTankId = _fuelTankId ?? 'default_fuel_tank_id';
      _petrolPumpId = _petrolPumpId ?? 'default_petrol_pump_id';
      setState(() { _error = e.toString(); });
    }
    setState(() { _fetching = false; });
  }

  // Fetch the previous end reading
  Future<void> _fetchPreviousEndReading() async {
    if (_nozzleId == null) return;

    setState(() { _fetchingPreviousReadings = true; });
    try {
      final repo = NozzleReadingRepository();
      
      // Fetch last end reading
      final endResponse = await repo.getLatestReading(_nozzleId!, 'End');
      if (endResponse.success && endResponse.data != null) {
        setState(() { 
          _previousEndReading = endResponse.data;
        });
        print('Previous end reading: ${_previousEndReading?.meterReading}');
      } else {
        print('No previous end reading found: ${endResponse.errorMessage}');
      }
      
      // Fetch last start reading
      final startResponse = await repo.getLatestReading(_nozzleId!, 'Start');
      if (startResponse.success && startResponse.data != null) {
        setState(() { 
          _previousStartReading = startResponse.data;
        });
        print('Previous start reading: ${_previousStartReading?.meterReading}');
      } else {
        print('No previous start reading found: ${startResponse.errorMessage}');
      }
      
      setState(() { _fetchingPreviousReadings = false; });
    } catch (e) {
      setState(() { _fetchingPreviousReadings = false; });
      print('Error fetching previous readings: $e');
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _imageFile == null || _recordedAt == null) {
      // Show specific error messages
      if (_imageFile == null) {
        setState(() {
          _error = 'Please take a photo of the meter reading';
        });
      } else if (_recordedAt == null) {
        setState(() {
          _error = 'Please select date and time';
        });
      }
      return;
    }
    
    setState(() { _loading = true; _error = null; });
    final repo = NozzleReadingRepository();
    
    try {
      final res = await repo.submitStartNozzleReading(
        nozzleId: _nozzleId!,
        shiftId: _shiftId!,
        meterReading: double.tryParse(_meterReadingController.text) ?? 0,
        recordedAt: _recordedAt!,
        petrolPumpId: _petrolPumpId!,
        fuelTankId: _fuelTankId!,
        imageFile: _imageFile!,
      );
      
      setState(() { _loading = false; });
      
      if (res.success) {
        // Show success snackbar before popping
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Start reading submitted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        print('DEBUG: Error submitting reading: ${res.errorMessage}');
        setState(() { _error = res.errorMessage; });
        
        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: ${res.errorMessage}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Exception in _submit: $e');
      setState(() { 
        _loading = false;
        _error = 'An unexpected error occurred. Please try again.';
      });
      
      // Show a snackbar for exceptions
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside of text fields
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            'Start Reading',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          elevation: 0,
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          actions: [
            // Refresh button
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh nozzle data',
              onPressed: _fetching 
                ? null // Disable when already fetching
                : () async {
                    // Clear the error state if any
                    setState(() {
                      _error = null;
                    });
                    
                    // Show loading indicator and refetch data
                    await _initializeData();
                    
                    // Show success message
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Data refreshed'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
            ),
          ],
        ),
        body: _fetching
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading your data...',
                      style: GoogleFonts.poppins(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : _buildBody(),
      ),
    );
  }

  // Extract body content to a separate method for better organization
  Widget _buildBody() {
    return Column(
      children: [
        // Header section with summary
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.1),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedNozzleAssignment != null 
                    ? 'Record start reading for ${_selectedNozzleAssignment!.fuelType} - Nozzle ${_selectedNozzleAssignment!.nozzleNumber}'
                    : 'Capture the current meter reading to start your shift',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha:0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        // Form with a slight shadow
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
            ),
            child: RefreshIndicator(
              onRefresh: () async {
                await _initializeData();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Nozzle Selection Dropdown
                        _buildNozzleSelectionDropdown(),
                        
                        const SizedBox(height: 16),
                        
                        // Previous End Reading Card
                        _buildPreviousReadingsCard(),
                        
                        const SizedBox(height: 16),
                        
                        // Meter reading inputs
                        _buildMeterReadingCard(),
                        
                        const SizedBox(height: 16),
                        
                        // Date and Time Card
                        _buildDateTimePicker(),
                        
                        const SizedBox(height: 16),
                        
                        // Image Selection Card
                        _buildImageSelector(),
                        
                        // Error Message
                        if (_error != null)
                          _buildErrorMessage(),
                        
                        const SizedBox(height: 24),
                        
                        // Submit Button
                        _buildSubmitButton(),
                        
                        // Bottom padding for scrolling
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildMeterReadingCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.speed,
                  color: AppTheme.primaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Meter Reading',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextFormField(
                controller: _meterReadingController,
                decoration: InputDecoration(
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.speed_outlined,
                      color: AppTheme.primaryBlue,
                      size: 18,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 50),
                  hintText: 'Enter the current reading on meter',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: InputBorder.none,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
                validator: (v) => v!.isEmpty ? 'Meter reading is required' : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget for error message
  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[700],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: GoogleFonts.poppins(
                  color: Colors.red[700],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Submit button
  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha:0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      height: 54,
      child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          disabledBackgroundColor: AppTheme.primaryBlue.withValues(alpha:0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
        ),
        child: _loading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  'SUBMIT READING',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
      ),
    );
  }

  // Get current employee ID
  Future<void> _getCurrentEmployeeId() async {
    try {
      final empResp = await EmployeeRepository().getCurrentEmployee();
      if (empResp.success && empResp.data != null) {
        setState(() {
          _employeeId = empResp.data!.id;
        });
        print('Current employee ID: $_employeeId');
      } else {
        print('Failed to get current employee: ${empResp.errorMessage}');
      }
    } catch (e) {
      print('Error getting current employee: $e');
    }
  }
  
  // Fetch employee nozzle assignments for dropdown
  Future<void> _fetchNozzleAssignments() async {
    if (_employeeId == null) return;
    
    setState(() {
      _loadingNozzleAssignments = true;
    });
    
    try {
      final response = await NozzleAssignmentRepository()
          .getEmployeeNozzleAssignments(_employeeId!);
      
      setState(() {
        _loadingNozzleAssignments = false;
        
        if (response.success && response.data != null) {
          _nozzleAssignments = response.data!;
          print('Loaded ${_nozzleAssignments.length} nozzle assignments');
          
          // If we already have a nozzle ID, select the matching assignment
          if (_nozzleId != null && _nozzleAssignments.isNotEmpty) {
            _selectedNozzleAssignment = _nozzleAssignments.firstWhere(
              (assignment) => assignment.nozzleId == _nozzleId,
              orElse: () => _nozzleAssignments.first,
            );
          } 
          // Otherwise select the first assignment by default
          else if (_nozzleAssignments.isNotEmpty) {
            _selectedNozzleAssignment = _nozzleAssignments.first;
            _updateSelectedNozzleData();
          }
        } else {
          print('Error loading nozzle assignments: ${response.errorMessage}');
        }
      });
    } catch (e) {
      setState(() {
        _loadingNozzleAssignments = false;
      });
      print('Exception in _fetchNozzleAssignments: $e');
    }
  }
  
  // Update the nozzle data based on selected assignment
  void _updateSelectedNozzleData() {
    if (_selectedNozzleAssignment != null) {
      setState(() {
        _nozzleId = _selectedNozzleAssignment!.nozzleId;
        _shiftId = _selectedNozzleAssignment!.shiftId;
        _fuelTankId = _selectedNozzleAssignment!.fuelTankId;
        _petrolPumpId = _selectedNozzleAssignment!.petrolPumpId;
      });
      
      // Fetch previous reading for the selected nozzle
      _fetchPreviousEndReading();
      
      // Save to preferences
      _saveToPreferences();
    }
  }

  // Build nozzle selection dropdown
  Widget _buildNozzleSelectionDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.nozzleId != null ? 'Nozzle Details' : 'Select Nozzle',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          
          _loadingNozzleAssignments
              ? Center(
                  child: SizedBox(
                    height: 30,
                    width: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                )
              : _nozzleAssignments.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red[700],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No nozzle assignments found',
                              style: GoogleFonts.poppins(
                                color: Colors.red[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : widget.nozzleId != null && _selectedNozzleAssignment != null
                      ? _buildSelectedNozzleView(_selectedNozzleAssignment!)
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                        child: DropdownButton<EmployeeNozzleAssignment>(
                          isExpanded: true,
                          value: _selectedNozzleAssignment,
                          hint: Text(
                            'Select a nozzle',
                            style: GoogleFonts.poppins(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: AppTheme.primaryBlue,
                          ),
                          items: _nozzleAssignments.map((assignment) {
                            return DropdownMenuItem<EmployeeNozzleAssignment>(
                              value: assignment,
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _getFuelTypeColor(assignment.fuelType),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        assignment.nozzleNumber.toString(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Nozzle ${assignment.nozzleNumber} - ${assignment.fuelType}',
                                    style: GoogleFonts.poppins(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (assignment) {
                            if (assignment != null) {
                              setState(() {
                                _selectedNozzleAssignment = assignment;
                              });
                              _updateSelectedNozzleData();
                            }
                          },
                        ),
                      ),
                    ),
        ],
      ),
    );
  }
  
  // Helper to display selected nozzle view without dropdown
  Widget _buildSelectedNozzleView(EmployeeNozzleAssignment assignment) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getFuelTypeColor(assignment.fuelType).withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getFuelTypeColor(assignment.fuelType).withValues(alpha:0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getFuelTypeColor(assignment.fuelType),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                assignment.nozzleNumber.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nozzle ${assignment.nozzleNumber}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  assignment.fuelType,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getFuelTypeColor(assignment.fuelType),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: assignment.isActive 
                          ? Colors.green.shade300
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    assignment.isActive ? 'Active' : 'Inactive',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: assignment.isActive 
                          ? Colors.green.shade600
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to get color for fuel type
  Color _getFuelTypeColor(String fuelType) {
    switch (fuelType.toLowerCase()) {
      case 'petrol':
        return Colors.green.shade700;
      case 'diesel':
        return Colors.orange.shade800;
      case 'premium':
      case 'premium petrol':
        return Colors.purple.shade700;
      case 'premium diesel':
        return Colors.deepPurple.shade800;
      case 'cng':
        return Colors.teal.shade700;
      case 'lpg':
        return Colors.indigo.shade700;
      case 'bio-diesel':
        return Colors.amber.shade800;
      case 'electric':
        return Colors.cyan.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  // Widget to display previous readings
  Widget _buildPreviousReadingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: AppTheme.primaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Previous Readings',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_fetchingPreviousReadings)
              Center(
                child: SizedBox(
                  height: 30,
                  width: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              )
            else
              Column(
                children: [
                  // End reading
                  _buildReadingRow(
                    icon: Icons.stop_circle_outlined,
                    title: 'Last End Reading',
                    reading: _previousEndReading,
                    iconColor: Colors.red.shade700,
                  ),
                  
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  
                  // Start reading
                  _buildReadingRow(
                    icon: Icons.play_circle_outline,
                    title: 'Last Start Reading',
                    reading: _previousStartReading,
                    iconColor: Colors.green.shade700,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build a reading row
  Widget _buildReadingRow({
    required IconData icon,
    required String title,
    required NozzleReading? reading,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              if (reading != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${reading.meterReading.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Recorded on ${DateFormat('dd MMM yyyy, hh:mm a').format(reading.recordedAt)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'No reading found',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimePicker() {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: AppTheme.primaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Date & Time',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                // Add a locked indicator
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 12,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Auto-set',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.event,
                      color: AppTheme.primaryBlue,
                      size: 18,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _recordedAt != null
                          ? '${dateFormat.format(_recordedAt!)} at ${timeFormat.format(_recordedAt!)}'
                          : 'Current date and time',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Add explanatory note
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 12,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Date and time are automatically set to when you opened this screen',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.camera_alt,
                  color: AppTheme.primaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Meter Photo',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Image Preview or Placeholder with rounded corners
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _pickImage,
                child: _imageFile != null
                  ? Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(_imageFile!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(alpha:0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt_outlined,
                              size: 32,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Take a photo of the meter',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to capture',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
            
            // Camera Button
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: TextButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(
                    _imageFile != null ? Icons.refresh : Icons.camera_alt,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                  label: Text(
                    _imageFile != null ? 'Retake Photo' : 'Take Photo',
                    style: GoogleFonts.poppins(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: AppTheme.primaryBlue.withValues(alpha:0.3),
                        width: 1,
                      ),
                    ),
                    backgroundColor: AppTheme.primaryBlue.withValues(alpha:0.05),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}