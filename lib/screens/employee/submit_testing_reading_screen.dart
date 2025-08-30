import 'package:flutter/material.dart';
import '../../api/government_testing_repository.dart';
import '../../api/employee_repository.dart';
import '../../api/nozzle_assignment_repository.dart';
import '../../api/nozzle_repository.dart';
import '../../models/government_testing_model.dart';
import '../../models/employee_nozzle_assignment_model.dart';
import '../../models/nozzle_model.dart';
import '../../theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../utils/shared_prefs.dart';

class SubmitTestingReadingScreen extends StatefulWidget {
  final String? nozzleId;
  final String? shiftId;
  final String? fuelTankId;
  final String? petrolPumpId;

  const SubmitTestingReadingScreen({
    Key? key, 
    this.nozzleId,
    this.shiftId,
    this.fuelTankId,
    this.petrolPumpId,
  }) : super(key: key);

  @override
  _SubmitTestingReadingScreenState createState() => _SubmitTestingReadingScreenState();
}

class _SubmitTestingReadingScreenState extends State<SubmitTestingReadingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _testingLitersController = TextEditingController();
  final _notesController = TextEditingController();
  
  bool _loading = false;
  String? _error;

  // IDs
  String? _nozzleId;
  String? _shiftId;
  String? _petrolPumpId;
  String? _fuelTankId;
  String? _employeeId;

  bool _fetching = true;
  
  // Nozzle selection dropdown data
  List<EmployeeNozzleAssignment> _nozzleAssignments = [];
  EmployeeNozzleAssignment? _selectedNozzleAssignment;
  bool _loadingNozzleAssignments = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _testingLitersController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() { _fetching = true; });
    
    // First try to use the passed data
    _nozzleId = widget.nozzleId;
    _shiftId = widget.shiftId;
    _petrolPumpId = widget.petrolPumpId;
    _fuelTankId = widget.fuelTankId;
    
    print('INIT_DEBUG: Initial values from widget:');
    print('INIT_DEBUG: nozzleId: $_nozzleId');
    print('INIT_DEBUG: shiftId: $_shiftId');
    print('INIT_DEBUG: petrolPumpId: $_petrolPumpId');
    print('INIT_DEBUG: fuelTankId: $_fuelTankId');
    
    // Get current employee ID
    await _getCurrentEmployeeId();
    
    // Load from SharedPreferences first
    await _loadFromPreferences();
    
    // Fetch petrol pump ID specifically if still null
    if (_petrolPumpId == null || _petrolPumpId!.isEmpty) {
      await _fetchPetrolPumpId();
    }
    
    // Fetch nozzle assignments for dropdown
    await _fetchNozzleAssignments();
    
    setState(() { _fetching = false; });
  }

  Future<void> _getCurrentEmployeeId() async {
    try {
      print('DEBUG_EMPLOYEE: Getting current employee ID');
      final prefs = await SharedPreferences.getInstance();
      _employeeId = prefs.getString('employeeId');
      
      print('DEBUG_EMPLOYEE: From SharedPreferences: $_employeeId');
      
      // If not found in SharedPreferences, try to fetch from API
      if (_employeeId == null) {
        print('DEBUG_EMPLOYEE: Not found in SharedPreferences, fetching from API');
        final empRepo = EmployeeRepository();
        final empResp = await empRepo.getCurrentEmployee();
        
        if (empResp.success && empResp.data != null) {
          _employeeId = empResp.data!.id;
          print('DEBUG_EMPLOYEE: Successfully retrieved from API: $_employeeId');
          
          // Also get the petrol pump ID from the employee data
          if (_petrolPumpId == null && empResp.data!.petrolPumpId != null) {
            _petrolPumpId = empResp.data!.petrolPumpId;
            print('DEBUG_EMPLOYEE: Got petrolPumpId from employee data: $_petrolPumpId');
          }
          
          // Save for future use
          await prefs.setString('employeeId', _employeeId!);
          if (_petrolPumpId != null) {
            await prefs.setString('employee_petrol_pump_id', _petrolPumpId!);
          }
        } else {
          print('DEBUG_EMPLOYEE: Failed to get from API: ${empResp.errorMessage}');
        }
      }
    } catch (e) {
      print('DEBUG_EMPLOYEE: Error getting current employee ID: $e');
      setState(() { _error = 'Failed to get employee data'; });
    }
  }
  
  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Try multiple possible keys for petrol pump ID
      if (_petrolPumpId == null || _petrolPumpId!.isEmpty) {
        _petrolPumpId = prefs.getString('employee_petrol_pump_id');
        print('DEBUG_PREFS: petrolPumpId from employee_petrol_pump_id: $_petrolPumpId');
      }
      
      if (_petrolPumpId == null || _petrolPumpId!.isEmpty) {
        _petrolPumpId = prefs.getString('petrol_pump_id');
        print('DEBUG_PREFS: petrolPumpId from petrol_pump_id: $_petrolPumpId');
      }
      
      if (_petrolPumpId == null || _petrolPumpId!.isEmpty) {
        _petrolPumpId = await SharedPrefs.getPumpId();
        print('DEBUG_PREFS: petrolPumpId from SharedPrefs.getPumpId(): $_petrolPumpId');
      }
      
      // Load other values if not already set
      _nozzleId = _nozzleId ?? prefs.getString('employee_nozzle_id');
      _shiftId = _shiftId ?? prefs.getString('employee_shift_id');
      _fuelTankId = _fuelTankId ?? prefs.getString('employee_fuel_tank_id');
      
      print('DEBUG_PREFS: Loaded from preferences:');
      print('DEBUG_PREFS: nozzleId: $_nozzleId');
      print('DEBUG_PREFS: shiftId: $_shiftId');
      print('DEBUG_PREFS: fuelTankId: $_fuelTankId');
      print('DEBUG_PREFS: petrolPumpId: $_petrolPumpId');
    } catch (e) {
      print('Error loading from preferences: $e');
    }
  }
  
  // Fetch petrol pump ID from API if not found in SharedPreferences
  Future<void> _fetchPetrolPumpId() async {
    try {
      print('DEBUG_PUMP: Fetching petrol pump ID from API');
      
      if (_employeeId != null) {
        final empRepo = EmployeeRepository();
        final empResp = await empRepo.getCurrentEmployee();
        
        if (empResp.success && empResp.data != null && empResp.data!.petrolPumpId != null) {
          setState(() {
            _petrolPumpId = empResp.data!.petrolPumpId;
          });
          print('DEBUG_PUMP: Got petrolPumpId from API: $_petrolPumpId');
          
          // Save for future use
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('employee_petrol_pump_id', _petrolPumpId!);
        } else {
          print('DEBUG_PUMP: Failed to get petrolPumpId from API');
        }
      } else {
        print('DEBUG_PUMP: Cannot fetch petrolPumpId, employeeId is null');
      }
    } catch (e) {
      print('DEBUG_PUMP: Error fetching petrol pump ID: $e');
    }
  }
  
  // Save to preferences for future use
  Future<void> _saveToPreferences() async {
    try {
      if (_nozzleId != null && _shiftId != null && _fuelTankId != null && _petrolPumpId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('employee_nozzle_id', _nozzleId!);
        await prefs.setString('employee_shift_id', _shiftId!);
        await prefs.setString('employee_fuel_tank_id', _fuelTankId!);
        await prefs.setString('employee_petrol_pump_id', _petrolPumpId!);
        print('DEBUG_SAVE: Saved all IDs to preferences');
      } else {
        print('DEBUG_SAVE: Not saving to preferences, some IDs are null:');
        print('DEBUG_SAVE: nozzleId: $_nozzleId');
        print('DEBUG_SAVE: shiftId: $_shiftId');
        print('DEBUG_SAVE: fuelTankId: $_fuelTankId');
        print('DEBUG_SAVE: petrolPumpId: $_petrolPumpId');
      }
    } catch (e) {
      print('Error saving to preferences: $e');
    }
  }

  // Fetch employee nozzle assignments for dropdown
  Future<void> _fetchNozzleAssignments() async {
    if (_employeeId == null) {
      print('DEBUG_NOZZLE: employeeId is null, skipping nozzle assignment fetch');
      return;
    }
    
    setState(() {
      _loadingNozzleAssignments = true;
    });
    
    try {
      print('DEBUG_NOZZLE: Fetching nozzle assignments for employeeId: $_employeeId');
      final response = await NozzleAssignmentRepository()
          .getEmployeeNozzleAssignments(_employeeId!);
      
      setState(() {
        _loadingNozzleAssignments = false;
        
        if (response.success && response.data != null) {
          _nozzleAssignments = response.data!;
          print('DEBUG_NOZZLE: Loaded ${_nozzleAssignments.length} nozzle assignments');
          
          if (_nozzleAssignments.isEmpty) {
            print('DEBUG_NOZZLE: No nozzle assignments found');
          } else {
            // Print some info about each assignment
            for (int i = 0; i < _nozzleAssignments.length; i++) {
              final assignment = _nozzleAssignments[i];
              print('DEBUG_NOZZLE: Assignment $i:');
              print('DEBUG_NOZZLE:   nozzleId: ${assignment.nozzleId}');
              print('DEBUG_NOZZLE:   shiftId: ${assignment.shiftId}');
              print('DEBUG_NOZZLE:   fuelTankId: ${assignment.fuelTankId}');
              print('DEBUG_NOZZLE:   petrolPumpId: ${assignment.petrolPumpId}');
              
              // If we find a valid petrolPumpId and we don't have one yet, use it
              if (_petrolPumpId == null || _petrolPumpId!.isEmpty) {
                if (assignment.petrolPumpId != null && assignment.petrolPumpId!.isNotEmpty) {
                  _petrolPumpId = assignment.petrolPumpId;
                  print('DEBUG_NOZZLE: Using petrolPumpId from assignment: $_petrolPumpId');
                }
              }
            }
          }
          
          // If we already have a nozzle ID, select the matching assignment
          if (_nozzleId != null && _nozzleAssignments.isNotEmpty) {
            print('DEBUG_NOZZLE: Looking for assignment with nozzleId: $_nozzleId');
            _selectedNozzleAssignment = _nozzleAssignments.firstWhere(
              (assignment) => assignment.nozzleId == _nozzleId,
              orElse: () => _nozzleAssignments.first,
            );
            print('DEBUG_NOZZLE: Selected assignment with nozzleId: ${_selectedNozzleAssignment!.nozzleId}');
            _updateSelectedNozzleData();
          } 
          // Otherwise select the first assignment by default
          else if (_nozzleAssignments.isNotEmpty) {
            print('DEBUG_NOZZLE: No nozzleId provided, selecting first assignment');
            _selectedNozzleAssignment = _nozzleAssignments.first;
            print('DEBUG_NOZZLE: Selected first assignment with nozzleId: ${_selectedNozzleAssignment!.nozzleId}');
            _updateSelectedNozzleData();
          }
        } else {
          print('DEBUG_NOZZLE: Error loading nozzle assignments: ${response.errorMessage}');
        }
      });
    } catch (e) {
      setState(() {
        _loadingNozzleAssignments = false;
      });
      print('DEBUG_NOZZLE: Exception in _fetchNozzleAssignments: $e');
    }
  }
  
  // Update the nozzle data based on selected assignment
  void _updateSelectedNozzleData() {
    if (_selectedNozzleAssignment != null) {
      setState(() {
        _nozzleId = _selectedNozzleAssignment!.nozzleId;
        _shiftId = _selectedNozzleAssignment!.shiftId;
        _fuelTankId = _selectedNozzleAssignment!.fuelTankId;
        
        // Only update petrolPumpId if it's not empty in the assignment
        if (_selectedNozzleAssignment!.petrolPumpId != null && 
            _selectedNozzleAssignment!.petrolPumpId!.isNotEmpty) {
          _petrolPumpId = _selectedNozzleAssignment!.petrolPumpId;
        }
      });
      
      // Debug prints
      print('DEBUG_SELECTION: Updated nozzle data:');
      print('DEBUG_SELECTION: nozzleId: $_nozzleId');
      print('DEBUG_SELECTION: shiftId: $_shiftId');
      print('DEBUG_SELECTION: fuelTankId: $_fuelTankId');
      print('DEBUG_SELECTION: petrolPumpId: $_petrolPumpId');
      
      // Save to preferences
      _saveToPreferences();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Check for missing fields and try to fix them
    bool hasMissingFields = false;
    
    if (_employeeId == null || _employeeId!.isEmpty) {
      print('DEBUG_SUBMIT: employeeId is missing, trying to fetch it again');
      await _getCurrentEmployeeId();
      hasMissingFields = _employeeId == null || _employeeId!.isEmpty;
    }
    
    if (_petrolPumpId == null || _petrolPumpId!.isEmpty) {
      print('DEBUG_SUBMIT: petrolPumpId is missing, trying to fetch it again');
      await _fetchPetrolPumpId();
      hasMissingFields = _petrolPumpId == null || _petrolPumpId!.isEmpty;
    }
    
    if (_nozzleId == null || _nozzleId!.isEmpty || 
        _shiftId == null || _shiftId!.isEmpty || 
        _petrolPumpId == null || _petrolPumpId!.isEmpty) {
      
      print('DEBUG_SUBMIT: Missing required fields:');
      print('DEBUG_SUBMIT: employeeId: $_employeeId');
      print('DEBUG_SUBMIT: nozzleId: $_nozzleId');
      print('DEBUG_SUBMIT: shiftId: $_shiftId');
      print('DEBUG_SUBMIT: petrolPumpId: $_petrolPumpId');
      
      if (hasMissingFields) {
        setState(() { 
          _error = 'Missing required data. Please try selecting a nozzle again.'; 
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      print('DEBUG_SUBMIT: Creating GovernmentTesting object with:');
      print('DEBUG_SUBMIT: employeeId: $_employeeId');
      print('DEBUG_SUBMIT: nozzleId: $_nozzleId');
      print('DEBUG_SUBMIT: petrolPumpId: $_petrolPumpId');
      print('DEBUG_SUBMIT: shiftId: $_shiftId');
      print('DEBUG_SUBMIT: testingLiters: ${_testingLitersController.text}');
      
      final testing = GovernmentTesting(
        employeeId: _employeeId!,
        nozzleId: _nozzleId!,
        petrolPumpId: _petrolPumpId!,
        shiftId: _shiftId!,
        testingLiters: double.parse(_testingLitersController.text),
        notes: _notesController.text,
      );

      final repo = GovernmentTestingRepository();
      final response = await repo.submitGovernmentTesting(testing);

      if (response.success) {
        // Clear form and show success message
        _testingLitersController.clear();
        _notesController.clear();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Testing data submitted successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        print('DEBUG_SUBMIT: API response error: ${response.errorMessage}');
        setState(() { 
          _error = response.errorMessage ?? 'Failed to submit testing data'; 
          _loading = false;
        });
      }
    } catch (e) {
      print('DEBUG_SUBMIT: Exception: $e');
      setState(() { 
        _error = e.toString(); 
        _loading = false;
      });
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
            'Government Testing',
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
              // Today's date
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.white.withValues(alpha:0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha:0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _selectedNozzleAssignment != null 
                    ? 'Submit testing data for ${_selectedNozzleAssignment!.fuelType} - Nozzle ${_selectedNozzleAssignment!.nozzleNumber}'
                    : 'Submit testing volumes for compliance',
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
                        
                        // Testing Liters Card
                        _buildTestingLitersCard(),
                        
                        const SizedBox(height: 16),
                        
                        // Notes Card
                        _buildNotesCard(),
                        
                        // Debug info section in development
                        if (_petrolPumpId == null || _petrolPumpId!.isEmpty)
                          _buildDebugInfoCard(),
                        
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
  
  // Testing liters input card
  Widget _buildTestingLitersCard() {
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
                  Icons.water_drop,
                  color: AppTheme.primaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Testing Volume',
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
                controller: _testingLitersController,
                decoration: InputDecoration(
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.opacity,
                      color: AppTheme.primaryBlue,
                      size: 18,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 50),
                  hintText: 'Enter testing volume in liters',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: InputBorder.none,
                  suffixIcon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'L',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter testing volume';
                  }
                  try {
                    double.parse(value);
                  } catch (e) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Notes input card
  Widget _buildNotesCard() {
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
                  Icons.note_alt_outlined,
                  color: AppTheme.primaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Notes (Optional)',
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
                controller: _notesController,
                decoration: InputDecoration(
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.note_add,
                      color: AppTheme.primaryBlue,
                      size: 18,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 50),
                  hintText: 'Add any notes about the testing',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: InputBorder.none,
                ),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                ),
                maxLines: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Debug info card
  Widget _buildDebugInfoCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.yellow.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.yellow.shade700),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.amber.shade800,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Debug Info - Missing petrolPumpId',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'employeeId: ${_employeeId ?? "null"}',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            Text(
              'nozzleId: ${_nozzleId ?? "null"}',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            Text(
              'shiftId: ${_shiftId ?? "null"}',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _fetchPetrolPumpId();
                  setState(() {});
                },
                icon: Icon(Icons.refresh, size: 16),
                label: Text('Try to fetch Pump ID again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Error message widget
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _error!,
                    style: GoogleFonts.poppins(
                      color: Colors.red[700],
                      fontSize: 13,
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
                  'SUBMIT TESTING DATA',
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
          // Title row
          Row(
            children: [
              Icon(
                Icons.local_gas_station,
                color: Colors.grey.shade600,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                widget.nozzleId != null ? 'Nozzle Details' : 'Select Nozzle',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
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
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              assignment.fuelType,
                                              style: GoogleFonts.poppins(
                                                color: AppTheme.textPrimary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'Nozzle ${assignment.nozzleNumber}',
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
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
                  assignment.fuelType,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _getFuelTypeColor(assignment.fuelType),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nozzle ${assignment.nozzleNumber}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade700,
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
} 