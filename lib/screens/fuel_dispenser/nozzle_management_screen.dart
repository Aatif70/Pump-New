import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/fuel_dispenser_repository.dart';
import '../../api/nozzle_repository.dart';
import '../../api/fuel_tank_repository.dart';
import '../../api/employee_repository.dart';
import '../../api/shift_repository.dart';
import '../../api/employee_nozzle_assignment_repository.dart';
import '../../api/api_constants.dart';
import '../../models/fuel_dispenser_model.dart';
import '../../models/nozzle_model.dart';
import '../../models/fuel_tank_model.dart';
import '../../models/employee_model.dart';
import '../../models/shift_model.dart';
import '../../theme.dart';
import 'package:http/http.dart' as http;
import 'widgets/add_nozzle_dialog.dart';
import 'widgets/nozzle_card.dart';
import 'widgets/nozzle_status_summary.dart';
import 'widgets/employee_assignment_screen.dart';

class NozzleManagementScreen extends StatefulWidget {
  final FuelDispenser? dispenser;
  
  const NozzleManagementScreen({
    this.dispenser,
    super.key
  });

  @override
  State<NozzleManagementScreen> createState() => _NozzleManagementScreenState();
}

class _NozzleManagementScreenState extends State<NozzleManagementScreen> {
  final _dispenserRepository = FuelDispenserRepository();
  final _nozzleRepository = NozzleRepository();
  final _fuelTankRepository = FuelTankRepository(); // Add repository for fuel tanks
  final _employeeRepository = EmployeeRepository();
  final _shiftRepository = ShiftRepository();
  final _employeeNozzleAssignmentRepository = EmployeeNozzleAssignmentRepository();
  
  bool _isLoading = true;
  String _errorMessage = '';
  List<FuelDispenser> _dispensers = [];
  Map<String, List<Nozzle>> _nozzlesMap = {};
  List<FuelTank> _fuelTanks = []; // Add property to store fuel tanks
  List<Employee> _employees = []; // Store real employees
  List<Shift> _shifts = []; // Store shifts
  String? _statusFilter; // Status filter for nozzles

  // Employee filter
  final TextEditingController _employeeSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDispensers();
    _loadFuelTanks(); // Add method call to load fuel tanks
    _loadEmployees(); // Load employees
    _loadShifts(); // Load shifts
    _checkAuthToken();
  }

  // Check if authentication token exists
  Future<void> _checkAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      print('==================== NOZZLE MANAGEMENT ====================');
      print('NozzleManagementScreen: Auth token check: ${token != null ? 'Token exists' : 'No token found'}');
      developer.log('NozzleManagementScreen: Auth token check: ${token != null ? 'Token exists' : 'No token found'}');
      if (token != null) {
        print('NozzleManagementScreen: Token length: ${token.length}');
        print('NozzleManagementScreen: Token preview: ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
        developer.log('NozzleManagementScreen: Token length: ${token.length}');
        developer.log('NozzleManagementScreen: Token preview: ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
      }
    } catch (e) {
      print('NozzleManagementScreen: Error checking auth token: $e');
      developer.log('NozzleManagementScreen: Error checking auth token: $e');
    }
  }

  // Load all dispensers or a specific one
  Future<void> _loadDispensers() async {
    print('NozzleManagementScreen: Loading dispensers');
    developer.log('NozzleManagementScreen: Loading dispensers');
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // If a specific dispenser was passed, only load that one
      if (widget.dispenser != null) {
        print('NozzleManagementScreen: Loading single dispenser #${widget.dispenser!.dispenserNumber}');
        _dispensers = [widget.dispenser!];
        
        // Ensure the dispenser has a valid ID before trying to load nozzles
        final dispenserId = widget.dispenser!.id ?? '';
        
        if (dispenserId.isNotEmpty) {
          await _loadNozzlesForDispenser(dispenserId);
        } else {
          print('NozzleManagementScreen: Warning - dispenser has null/empty ID: ${widget.dispenser!.dispenserNumber}');
          developer.log('NozzleManagementScreen: Warning - dispenser has null/empty ID: ${widget.dispenser!.dispenserNumber}');
          // Initialize with empty list for this dispenser to prevent null errors
          _nozzlesMap[widget.dispenser!.id] = [];
        }
        
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Otherwise load all dispensers
      final response = await _dispenserRepository.getFuelDispensers();
      print('NozzleManagementScreen: Dispenser fetch response success: ${response.success}');
      
      if (!mounted) return;
      
      if (response.success) {
        _dispensers = response.data ?? [];
        print('NozzleManagementScreen: Loaded ${_dispensers.length} dispensers');
        developer.log('NozzleManagementScreen: Loaded ${_dispensers.length} dispensers');
        
        // Initialize empty nozzle lists for each dispenser
        for (var dispenser in _dispensers) {
          print('NozzleManagementScreen: Processing dispenser #${dispenser.dispenserNumber}, ID: ${dispenser.id}');
          
          // Ensure the dispenser has a valid ID before trying to load nozzles
          final dispenserId = dispenser.id ?? '';
          
          if (dispenserId.isNotEmpty) {
            await _loadNozzlesForDispenser(dispenserId);
          } else {
            print('NozzleManagementScreen: Warning - dispenser has null/empty ID: ${dispenser.dispenserNumber}');
            developer.log('NozzleManagementScreen: Warning - dispenser has null/empty ID: ${dispenser.dispenserNumber}');
            // Initialize with empty list for this dispenser to prevent null errors
            _nozzlesMap[dispenser.id] = [];
          }
        }
        
        setState(() {
          _isLoading = false;
        });
        print('NozzleManagementScreen: Finished loading all dispensers and nozzles');
      } else {
        print('NozzleManagementScreen: Error loading dispensers: ${response.errorMessage}');
        developer.log('NozzleManagementScreen: Error loading dispensers: ${response.errorMessage}');
        setState(() {
          _isLoading = false;
          _errorMessage = response.errorMessage ?? 'Failed to load dispensers';
        });
      }
    } catch (e) {
      print('NozzleManagementScreen: Exception when loading dispensers: $e');
      developer.log('NozzleManagementScreen: Exception when loading dispensers: $e');
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  // Load nozzles for a specific dispenser
  Future<void> _loadNozzlesForDispenser(String dispenserId) async {
    if (dispenserId.isEmpty) {
      print('NozzleManagementScreen: Cannot load nozzles - empty dispenser ID provided');
      developer.log('NozzleManagementScreen: Cannot load nozzles - empty dispenser ID provided');
      return;
    }
    
    print('NozzleManagementScreen: Loading nozzles for dispenser: $dispenserId');
    developer.log('NozzleManagementScreen: Loading nozzles for dispenser: $dispenserId');
    try {
      // Get nozzles for this specific dispenser ID instead of all nozzles
      final response = await _nozzleRepository.getNozzlesByDispenserId(dispenserId);
      print('NozzleManagementScreen: Nozzles fetch response success: ${response.success}');
      
      if (!mounted) return;
      
      if (response.success) {
        final nozzles = response.data ?? [];
        print('NozzleManagementScreen: Retrieved ${nozzles.length} nozzles');
        developer.log('NozzleManagementScreen: Retrieved ${nozzles.length} nozzles');
        
        // For each nozzle, fetch the employee assignment
        for (var nozzle in nozzles) {
          if (nozzle.id != null) {
            await _fetchEmployeeAssignmentForNozzle(nozzle);
          }
        }
        
        setState(() {
          _nozzlesMap[dispenserId] = nozzles;
        });
        
        print('NozzleManagementScreen: Loaded ${nozzles.length} nozzles for dispenser: $dispenserId');
        developer.log('NozzleManagementScreen: Loaded ${nozzles.length} nozzles for dispenser: $dispenserId');
        
        // Print details about each nozzle for debugging
        if (nozzles.isNotEmpty) {
          for (var nozzle in nozzles) {
            print('  - Nozzle #${nozzle.nozzleNumber}: ${nozzle.fuelType ?? ''}, Status: ${nozzle.status}');
            if (nozzle.assignedEmployee != null && nozzle.assignedEmployee!.isNotEmpty) {
              print('    - Assigned Employee: ${nozzle.assignedEmployee}');
            } else {
              print('    - No employee assigned');
            }
          }
        } else {
          print('NozzleManagementScreen: No nozzles found for this dispenser');
        }
      } else {
        print('NozzleManagementScreen: Failed to load nozzles: ${response.errorMessage}');
        developer.log('NozzleManagementScreen: Failed to load nozzles: ${response.errorMessage}');
      }
    } catch (e) {
      print('NozzleManagementScreen: Error loading nozzles for dispenser $dispenserId: $e');
      developer.log('NozzleManagementScreen: Error loading nozzles for dispenser $dispenserId: $e');
    }
  }

  // Fetch employee assignment for a specific nozzle
  Future<void> _fetchEmployeeAssignmentForNozzle(Nozzle nozzle) async {
    if (nozzle.id == null) return;
    
    print('NozzleManagementScreen: Fetching employee assignment for nozzle #${nozzle.nozzleNumber}');
    try {
      final response = await _employeeNozzleAssignmentRepository.getNozzleAssignmentsByNozzleId(nozzle.id!);
      
      if (response.success && response.data != null && response.data!.isNotEmpty) {
        final assignmentData = response.data!;
        
        // Find the employee name
        final String employeeId = assignmentData['employeeId'] ?? '';
        final String shiftId = assignmentData['shiftId'] ?? '';
        final String assignmentId = assignmentData['id'] ?? assignmentData['employeeNozzleAssignmentId'] ?? '';
        
        if (employeeId.isNotEmpty) {
          // Find employee in the list
          final matchingEmployees = _employees.where((e) => e.id == employeeId).toList();
          final employeeName = matchingEmployees.isNotEmpty 
              ? '${matchingEmployees.first.firstName} ${matchingEmployees.first.lastName}'
              : 'Unknown Employee';
          
          // Find shift details
          final matchingShifts = _shifts.where((s) => s.id == shiftId).toList();
          final shiftInfo = matchingShifts.isNotEmpty 
              ? 'Shift ${matchingShifts.first.shiftNumber}'
              : '';
              
          // Update the nozzle with the assignment info
          nozzle.assignedEmployee = '$employeeName${shiftInfo.isNotEmpty ? ' - $shiftInfo' : ''}';
          nozzle.assignmentId = assignmentId; // Store the assignment ID for removal
          print('NozzleManagementScreen: Assigned employee for nozzle #${nozzle.nozzleNumber}: ${nozzle.assignedEmployee}, assignmentId: ${nozzle.assignmentId}');
        } else {
          nozzle.assignedEmployee = null;
          nozzle.assignmentId = null;
          print('NozzleManagementScreen: No employee ID found in assignment data for nozzle #${nozzle.nozzleNumber}');
        }
      } else {
        nozzle.assignedEmployee = null;
        nozzle.assignmentId = null;
        print('NozzleManagementScreen: No assignment found for nozzle #${nozzle.nozzleNumber}');
      }
    } catch (e) {
      print('NozzleManagementScreen: Error fetching assignment for nozzle #${nozzle.nozzleNumber}: $e');
      nozzle.assignedEmployee = null;
      nozzle.assignmentId = null;
    }
  }

  // Get nozzles for a dispenser
  List<Nozzle> _getNozzlesForDispenser(String? dispenserId) {
    if (dispenserId == null) return [];
    return _nozzlesMap[dispenserId] ?? [];
  }

  // Add a new nozzle
  Future<void> _addNozzle(String dispenserId, FuelDispenser dispenser, int nozzleNumber) async {
    print('NozzleManagementScreen: Attempting to add nozzle #$nozzleNumber to dispenser: $dispenserId');
    developer.log('NozzleManagementScreen: Attempting to add nozzle #$nozzleNumber to dispenser: $dispenserId');
    
    // Validate dispenser ID format
    if (!_isValidUuid(dispenserId)) {
      print('NozzleManagementScreen: Warning - dispenser ID may not be a valid UUID: $dispenserId');
      developer.log('NozzleManagementScreen: Warning - dispenser ID may not be a valid UUID: $dispenserId');
      // Show warning to user about invalid ID
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Warning: Dispenser ID may not be valid: $dispenserId'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    }
    
    // Check if adding another nozzle would exceed the maximum allowed
    final existingNozzles = _getNozzlesForDispenser(dispenserId);
    final maxAllowedNozzles = dispenser.numberOfNozzles;
    
    if (existingNozzles.length >= maxAllowedNozzles) {
      print('NozzleManagementScreen: Cannot add nozzle - maximum capacity reached (${existingNozzles.length}/$maxAllowedNozzles)');
      developer.log('NozzleManagementScreen: Cannot add nozzle - maximum capacity reached (${existingNozzles.length}/$maxAllowedNozzles)');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot add nozzle - maximum capacity of $maxAllowedNozzles nozzles reached'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Check if nozzle already exists for this position
    final existingNozzle = existingNozzles.where((n) => n.nozzleNumber == nozzleNumber).firstOrNull;
    
    if (existingNozzle != null) {
      print('NozzleManagementScreen: Nozzle already exists at position $nozzleNumber');
      developer.log('NozzleManagementScreen: Nozzle already exists at position $nozzleNumber');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A nozzle already exists in this position'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show dialog to add nozzle
    final newNozzle = await _showAddNozzleDialog(dispenserId, dispenser, nozzleNumber);
    
    if (newNozzle != null) {
      print('NozzleManagementScreen: New nozzle created with data:');
      print('  - Dispenser ID: ${newNozzle.fuelDispenserUnitId}');
      print('  - Nozzle #: ${newNozzle.nozzleNumber}');
      print('  - Status: ${newNozzle.status}');
      print('  - Calibration Date: ${newNozzle.lastCalibrationDate}');
      
      developer.log('NozzleManagementScreen: New nozzle created, sending to API: ${newNozzle.toJson()}');
      try {
        setState(() => _isLoading = true);
        
        // Debug API request details
        print('API Request - Dispenser ID: $dispenserId');
        print('API Request - Nozzle data: ${newNozzle.toJson()}');
        print('API Request - Nozzle details:');
        print('  - Dispenser ID: ${newNozzle.fuelDispenserUnitId}');
        print('  - Nozzle #: ${newNozzle.nozzleNumber}');
        print('  - Fuel Type: ${newNozzle.fuelType}');
        print('  - Fuel Type ID: ${newNozzle.fuelTypeId}');
        print('  - Fuel Tank ID: ${newNozzle.fuelTankId}');
        print('  - Status: ${newNozzle.status}');
        print('  - Petrol Pump ID: ${newNozzle.petrolPumpId}');
        print('  - Last Calibration: ${newNozzle.lastCalibrationDate}');
        print('  - Assigned Employee: ${newNozzle.assignedEmployee}');
        developer.log('API Request - Dispenser ID: $dispenserId');
        developer.log('API Request - Nozzle data: ${newNozzle.toJson()}');
        
        print('Making API call to nozzle repository...');
        final response = await _nozzleRepository.addNozzle(newNozzle);
        print('API call completed.');
        print('API Response - Success: ${response.success}');
        if (!response.success) {
          print('API Response - Error: ${response.errorMessage}');
        } else if (response.data != null) {
          print('API Response - Created Nozzle ID: ${response.data?.id}');
        }
        
        if (!mounted) return;
        
        setState(() => _isLoading = false);
        
        if (response.success) {
          print('NozzleManagementScreen: Nozzle added successfully');
          developer.log('NozzleManagementScreen: Nozzle added successfully');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nozzle added successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Reload nozzles for this dispenser
          print('NozzleManagementScreen: Reloading nozzles after successful addition');
          await _loadNozzlesForDispenser(dispenserId);
        } else {
          print('NozzleManagementScreen: Failed to add nozzle: ${response.errorMessage}');
          developer.log('NozzleManagementScreen: Failed to add nozzle: ${response.errorMessage}');
          
          // Check if it's an auth error
          if (response.errorMessage?.contains('Authentication failed') == true) {
            print('NozzleManagementScreen: Authentication error detected');
            // Show auth error with more info
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Authentication failed. Please log out and log in again.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'OK',
                  onPressed: () {},
                ),
              ),
            );
          } else {
            // Show general error
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to add nozzle: ${response.errorMessage}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print('NozzleManagementScreen: Exception when adding nozzle: $e');
        developer.log('NozzleManagementScreen: Exception when adding nozzle: $e');
        if (!mounted) return;
        
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      print('NozzleManagementScreen: Nozzle dialog was canceled or returned null');
      developer.log('NozzleManagementScreen: Nozzle dialog was canceled or returned null');
    }
  }
  
  // Validate UUID format (basic validation)
  bool _isValidUuid(String str) {
    // This is a simple validation - UUID should be a string with hyphens and the right length
    // A proper UUID is like: 123e4567-e89b-12d3-a456-426614174000
    final uuidPattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
    return uuidPattern.hasMatch(str);
  }

  // Show dialog to add a new nozzle
  Future<Nozzle?> _showAddNozzleDialog(String dispenserId, FuelDispenser dispenser, int nozzleNumber) async {
    print('NozzleManagementScreen: Opening add nozzle dialog for position #$nozzleNumber');
    print('NozzleManagementScreen: Dispenser details - ID: ${dispenser.id}, Number: ${dispenser.dispenserNumber}');
    developer.log('NozzleManagementScreen: Opening add nozzle dialog for position #$nozzleNumber');
    developer.log('NozzleManagementScreen: Dispenser details - ID: ${dispenser.id}, Number: ${dispenser.dispenserNumber}');
    
    // Use the extracted AddNozzleDialog component
    return AddNozzleDialog.show(
      context: context,
      dispenserId: dispenserId,
      dispenser: dispenser,
      nozzleNumber: nozzleNumber,
      fuelTanks: _fuelTanks,
      employees: _employees,
    );
  }

  // Get color for fuel type
  Color _getFuelTypeColor(String? fuelType) {
    if (fuelType == null) return Colors.blueGrey.shade700;
    
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
      default:
        return Colors.blueGrey.shade700;
    }
  }

  // Activate a nozzle
  Future<void> _activateNozzle(Nozzle nozzle) async {
    print('NozzleManagementScreen: Activating nozzle #${nozzle.nozzleNumber}');
    setState(() => _isLoading = true);
    
    try {
      // Create updated nozzle with Active status
      final updatedNozzle = Nozzle(
        id: nozzle.id,
        fuelDispenserUnitId: nozzle.fuelDispenserUnitId,
        fuelType: nozzle.fuelType,
        nozzleNumber: nozzle.nozzleNumber,
        status: 'Active',
        lastCalibrationDate: nozzle.lastCalibrationDate,
        fuelTankId: nozzle.fuelTankId,
        petrolPumpId: nozzle.petrolPumpId,
        assignedEmployee: nozzle.assignedEmployee,
      );
      
      print('NozzleManagementScreen: Activating nozzle #${nozzle.nozzleNumber}');
      print('NozzleManagementScreen: Updated nozzle: ${updatedNozzle.toJson()}');
      developer.log('NozzleManagementScreen: Activating nozzle #${nozzle.nozzleNumber}');
      developer.log('NozzleManagementScreen: Updated nozzle: ${updatedNozzle.toJson()}');
      
      final response = await _nozzleRepository.updateNozzle(updatedNozzle);
      print('API Response - Success: ${response.success}');
      if (!response.success) {
        print('API Response - Error: ${response.errorMessage}');
      }
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      if (response.success) {
        print('NozzleManagementScreen: Nozzle activated successfully');
        developer.log('NozzleManagementScreen: Nozzle activated successfully');
        
        // Reload nozzles for this dispenser and fetch employee assignment
        print('NozzleManagementScreen: Reloading nozzles after activation');
        await _loadNozzlesForDispenser(nozzle.fuelDispenserUnitId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nozzle #${nozzle.nozzleNumber} activated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('NozzleManagementScreen: Failed to activate nozzle: ${response.errorMessage}');
        developer.log('NozzleManagementScreen: Failed to activate nozzle: ${response.errorMessage}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to activate nozzle: ${response.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('NozzleManagementScreen: Exception when activating nozzle: $e');
      developer.log('NozzleManagementScreen: Exception when activating nozzle: $e');
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Deactivate a nozzle
  Future<void> _deactivateNozzle(Nozzle nozzle) async {
    print('NozzleManagementScreen: Deactivating nozzle #${nozzle.nozzleNumber}');
    setState(() => _isLoading = true);
    
    try {
      // Create updated nozzle with Inactive status
      final updatedNozzle = Nozzle(
        id: nozzle.id,
        fuelDispenserUnitId: nozzle.fuelDispenserUnitId,
        fuelType: nozzle.fuelType,
        nozzleNumber: nozzle.nozzleNumber,
        status: 'Inactive',
        lastCalibrationDate: nozzle.lastCalibrationDate,
        fuelTankId: nozzle.fuelTankId,
        petrolPumpId: nozzle.petrolPumpId,
        assignedEmployee: nozzle.assignedEmployee,
      );
      
      print('NozzleManagementScreen: Deactivating nozzle #${nozzle.nozzleNumber}');
      print('NozzleManagementScreen: Updated nozzle: ${updatedNozzle.toJson()}');
      developer.log('NozzleManagementScreen: Deactivating nozzle #${nozzle.nozzleNumber}');
      developer.log('NozzleManagementScreen: Updated nozzle: ${updatedNozzle.toJson()}');
      
      final response = await _nozzleRepository.updateNozzle(updatedNozzle);
      print('API Response - Success: ${response.success}');
      if (!response.success) {
        print('API Response - Error: ${response.errorMessage}');
      }
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      if (response.success) {
        print('NozzleManagementScreen: Nozzle deactivated successfully');
        developer.log('NozzleManagementScreen: Nozzle deactivated successfully');
        
        // Reload nozzles for this dispenser and fetch employee assignment
        print('NozzleManagementScreen: Reloading nozzles after deactivation');
        await _loadNozzlesForDispenser(nozzle.fuelDispenserUnitId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nozzle #${nozzle.nozzleNumber} deactivated successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        print('NozzleManagementScreen: Failed to deactivate nozzle: ${response.errorMessage}');
        developer.log('NozzleManagementScreen: Failed to deactivate nozzle: ${response.errorMessage}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to deactivate nozzle: ${response.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('NozzleManagementScreen: Exception when deactivating nozzle: $e');
      developer.log('NozzleManagementScreen: Exception when deactivating nozzle: $e');
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Set a nozzle to maintenance
  Future<void> _setNozzleToMaintenance(Nozzle nozzle) async {
    print('NozzleManagementScreen: Setting nozzle #${nozzle.nozzleNumber} to maintenance');
    setState(() => _isLoading = true);
    
    try {
      // Create updated nozzle with Maintenance status
      final updatedNozzle = Nozzle(
        id: nozzle.id,
        fuelDispenserUnitId: nozzle.fuelDispenserUnitId,
        fuelType: nozzle.fuelType,
        nozzleNumber: nozzle.nozzleNumber,
        status: 'Maintenance',
        lastCalibrationDate: nozzle.lastCalibrationDate,
        fuelTankId: nozzle.fuelTankId,
        petrolPumpId: nozzle.petrolPumpId,
        assignedEmployee: nozzle.assignedEmployee,
      );
      
      print('NozzleManagementScreen: Setting nozzle #${nozzle.nozzleNumber} to maintenance');
      print('NozzleManagementScreen: Updated nozzle: ${updatedNozzle.toJson()}');
      developer.log('NozzleManagementScreen: Setting nozzle #${nozzle.nozzleNumber} to maintenance');
      developer.log('NozzleManagementScreen: Updated nozzle: ${updatedNozzle.toJson()}');
      
      final response = await _nozzleRepository.updateNozzle(updatedNozzle);
      print('API Response - Success: ${response.success}');
      if (!response.success) {
        print('API Response - Error: ${response.errorMessage}');
      }
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      if (response.success) {
        print('NozzleManagementScreen: Nozzle set to maintenance successfully');
        developer.log('NozzleManagementScreen: Nozzle set to maintenance successfully');
        
        // Reload nozzles for this dispenser and fetch employee assignment
        print('NozzleManagementScreen: Reloading nozzles after setting to maintenance');
        await _loadNozzlesForDispenser(nozzle.fuelDispenserUnitId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nozzle #${nozzle.nozzleNumber} set to maintenance mode'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        print('NozzleManagementScreen: Failed to set nozzle to maintenance: ${response.errorMessage}');
        developer.log('NozzleManagementScreen: Failed to set nozzle to maintenance: ${response.errorMessage}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set nozzle to maintenance: ${response.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('NozzleManagementScreen: Exception when setting nozzle to maintenance: $e');
      developer.log('NozzleManagementScreen: Exception when setting nozzle to maintenance: $e');
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Delete a nozzle
  Future<void> _deleteNozzle(Nozzle nozzle) async {
    print('NozzleManagementScreen: Deleting nozzle #${nozzle.nozzleNumber}');
    developer.log('NozzleManagementScreen: Deleting nozzle #${nozzle.nozzleNumber}');
    
    // Show confirmation dialog before deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Nozzle #${nozzle.nozzleNumber}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this nozzle?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Fuel Type: ${nozzle.fuelType}'),
            Text('Status: ${nozzle.status}'),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: const Text('DELETE'),
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    
    if (confirmed != true) {
      print('NozzleManagementScreen: Delete operation canceled by user');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      if (nozzle.id == null) {
        throw Exception('Nozzle ID is null');
      }
      
      // Use proper API URL from ApiConstants
      final url = ApiConstants.getNozzleByIdUrl(nozzle.id!);
      print('NozzleManagementScreen: Delete URL: $url');
      developer.log('NozzleManagementScreen: Delete URL: $url');
      
      // Get authentication token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConstants.authTokenKey);
      
      // Create headers with authentication token
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );
      
      print('NozzleManagementScreen: Delete response status: ${response.statusCode}');
      developer.log('NozzleManagementScreen: Delete response status: ${response.statusCode}');
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      if (response.statusCode == ApiConstants.statusOk || 
          response.statusCode == ApiConstants.statusNoContent) {
        print('NozzleManagementScreen: Nozzle deleted successfully');
        developer.log('NozzleManagementScreen: Nozzle deleted successfully');
        
        // Reload nozzles for this dispenser
        await _loadNozzlesForDispenser(nozzle.fuelDispenserUnitId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nozzle #${nozzle.nozzleNumber} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('NozzleManagementScreen: Failed to delete nozzle: ${response.statusCode}, ${response.body}');
        developer.log('NozzleManagementScreen: Failed to delete nozzle: ${response.statusCode}, ${response.body}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete nozzle: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('NozzleManagementScreen: Exception when deleting nozzle: $e');
      developer.log('NozzleManagementScreen: Exception when deleting nozzle: $e');
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show employee assignment dialog - improved design
  Future<void> _showEmployeeAssignmentDialog(Nozzle nozzle) async {
    print('NozzleManagementScreen: Showing employee assignment dialog for nozzle #${nozzle.nozzleNumber}');
    developer.log('NozzleManagementScreen: Showing employee assignment dialog for nozzle #${nozzle.nozzleNumber}');
    
    if (_shifts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No shifts available for assignment. Please create shifts first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // We no longer need to exclude employees that are already assigned to other nozzles
    // since an employee can be assigned to multiple nozzles
    
    print('NozzleManagementScreen: All employees are available for assignment');
    
    final assignmentData = await EmployeeAssignmentScreen.navigate(
      context: context,
      nozzle: nozzle,
      availableEmployees: _employees,
      availableShifts: _shifts,
      assignedEmployeeIds: [], // Empty list since we're allowing multiple assignments
    );
    
    if (assignmentData != null) {
      await _assignEmployeeToNozzle(assignmentData);
    }
  }

  // Assign employee to nozzle using the new API
  Future<void> _assignEmployeeToNozzle(Map<String, dynamic> assignmentData) async {
    final String employeeId = assignmentData['employeeId'] ?? '';
    final String? nozzleId = assignmentData['nozzleId'];
    final String shiftId = assignmentData['shiftId'] ?? '';
    final DateTime startDate = assignmentData['startDate'];
    final DateTime? endDate = assignmentData['endDate'];
    
    if (nozzleId == null) {
      print('NozzleManagementScreen: Error - nozzle ID is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Cannot assign to an unsaved nozzle'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    print('NozzleManagementScreen: Assigning employee ID "$employeeId" to nozzle ID "$nozzleId" for shift ID "$shiftId"');
    developer.log('NozzleManagementScreen: Assigning employee to nozzle with data: $assignmentData');
    
    setState(() => _isLoading = true);
    
    try {
      // Find employee name for display
      final matchingEmployees = _employees.where((employee) => employee.id == employeeId).toList();
      final employeeName = matchingEmployees.isNotEmpty 
          ? '${matchingEmployees.first.firstName} ${matchingEmployees.first.lastName}'
          : 'Unknown';
      
      // Find shift for display
      final matchingShifts = _shifts.where((shift) => shift.id == shiftId).toList();
      final shiftDisplay = matchingShifts.isNotEmpty 
          ? 'Shift ${matchingShifts.first.shiftNumber} (${matchingShifts.first.startTime}-${matchingShifts.first.endTime})'
          : 'Unknown shift';
      
      // Make the API call
      final response = await _employeeNozzleAssignmentRepository.assignEmployeeToNozzle(
        employeeId: employeeId,
        nozzleId: nozzleId,
        shiftId: shiftId,
        startDate: startDate,
        endDate: endDate,
      );
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      if (response.success) {
        print('NozzleManagementScreen: Employee assigned successfully');
        developer.log('NozzleManagementScreen: Employee assigned successfully');
        
        // Format dates for display
        final dateFormat = DateFormat('dd MMM yyyy');
        final startDateStr = dateFormat.format(startDate);
        final endDateStr = endDate != null ? dateFormat.format(endDate) : 'Indefinite';
        
        // Find the nozzle to update
        Nozzle? targetNozzle;
        String dispenserId = '';
        
        // Loop through all nozzles to find the one with this ID
        for (var dispId in _nozzlesMap.keys) {
          final nozzles = _nozzlesMap[dispId] ?? [];
          for (var noz in nozzles) {
            if (noz.id == nozzleId) {
              targetNozzle = noz;
              dispenserId = dispId;
              break;
            }
          }
          if (targetNozzle != null) break;
        }
        
        // Reload nozzles for this dispenser with updated assignment info
        if (dispenserId.isNotEmpty) {
          await _loadNozzlesForDispenser(dispenserId);
        } else {
          // If we couldn't find the dispenser ID, do a full reload
          await _loadDispensers();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Employee "$employeeName" assigned successfully'),
                Text(
                  'to $shiftDisplay from $startDateStr to $endDateStr',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        print('NozzleManagementScreen: Failed to assign employee: ${response.errorMessage}');
        developer.log('NozzleManagementScreen: Failed to assign employee: ${response.errorMessage}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign employee: ${response.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('NozzleManagementScreen: Exception when assigning employee: $e');
      developer.log('NozzleManagementScreen: Exception when assigning employee: $e');
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show dialog to select a dispenser and nozzle position
  Future<void> _showAddNozzleSelection() async {
    if (_dispensers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No dispensers available. Please add a dispenser first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show dialog to select dispenser and nozzle number
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Nozzle'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select a dispenser and nozzle position:'),
              const SizedBox(height: 16),
              
              // List of dispensers with nozzle positions
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _dispensers.length,
                  itemBuilder: (context, index) {
                    final dispenser = _dispensers[index];
                    final nozzles = _getNozzlesForDispenser(dispenser.id);
                    
                    // Limit nozzle positions to the number specified when creating the dispenser
                    final maxNozzles = dispenser.numberOfNozzles;
                    print('Dispenser ${dispenser.dispenserNumber} has max nozzles: $maxNozzles');
                    developer.log('Dispenser ${dispenser.dispenserNumber} has max nozzles: $maxNozzles');
                    
                    // Calculate current nozzle count for this dispenser
                    final currentNozzleCount = nozzles.length;
                    print('Dispenser ${dispenser.dispenserNumber} has current nozzle count: $currentNozzleCount');
                    developer.log('Dispenser ${dispenser.dispenserNumber} has current nozzle count: $currentNozzleCount');
                    
                    // If already at max capacity, show as disabled
                    if (currentNozzleCount >= maxNozzles) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.dashboard_outlined,
                                    color: AppTheme.primaryBlue,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Dispenser #${dispenser.dispenserNumber}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: maxNozzles,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${currentNozzleCount}/${maxNozzles}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade100),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.red.shade800,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Maximum capacity reached. This dispenser cannot have more than $maxNozzles nozzles.',
                                        style: TextStyle(
                                          color: Colors.red.shade800,
                                          fontSize: 13,
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
                    
                    // Find available nozzle positions (1 to numberOfNozzles)
                    final availablePositions = <int>[];
                    
                    for (int i = 1; i <= maxNozzles; i++) {
                      if (!nozzles.any((n) => n.nozzleNumber == i)) {
                        availablePositions.add(i);
                      }
                    }
                    
                    if (availablePositions.isEmpty) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('Dispenser #${dispenser.dispenserNumber}'),
                          subtitle: const Text('No available positions'),
                          enabled: false,
                        ),
                      );
                    }
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        title: Text('Dispenser #${dispenser.dispenserNumber}'),
                        subtitle: Text('${availablePositions.length} positions available (${currentNozzleCount}/${maxNozzles} in use)'),
                        children: [
                          Wrap(
                            spacing: 8,
                            children: availablePositions.map((position) {
                              return ActionChip(
                                avatar: const Icon(Icons.add, size: 16),
                                label: Text('Nozzle $position'),
                                onPressed: () {
                                  Navigator.pop(context);
                                  if (dispenser.id != null) {
                                    _addNozzle(dispenser.id!, dispenser, position);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Error: Dispenser ID is missing'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Nozzle Management'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDispensers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryBlue),
                  const SizedBox(height: 16),
                  Text(
                    'Loading nozzles...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? _buildErrorWidget()
              : _dispensers.isEmpty
                  ? _buildEmptyState()
                  : _buildNozzleFocusedView(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNozzleSelection,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        child: const Icon(Icons.add),
        tooltip: 'Add Nozzle',
      ),
    );
  }
  
  // New method to build error widget
  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha:0.1),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDispensers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Previous Screen'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build empty state widget when no dispensers are found
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.api,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'No Dispensers Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Add fuel dispensers first before managing nozzles',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Dispensers'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // New method for nozzle-focused view
  Widget _buildNozzleFocusedView() {
    // Flatten all nozzles across dispensers for a nozzle-focused view
    List<Map<String, dynamic>> allNozzlesWithDispenserInfo = [];
    
    for (var dispenser in _dispensers) {
      final nozzles = _getNozzlesForDispenser(dispenser.id);
      for (var nozzle in nozzles) {
        allNozzlesWithDispenserInfo.add({
          'nozzle': nozzle,
          'dispenser': dispenser,
        });
      }
    }
    
    // Count nozzles by status
    int activeCount = 0;
    int maintenanceCount = 0;
    int inactiveCount = 0;
    
    for (var nozzleInfo in allNozzlesWithDispenserInfo) {
      final nozzle = nozzleInfo['nozzle'] as Nozzle;
      final status = nozzle.status.toLowerCase();
      if (status == 'active') {
        activeCount++;
      } else if (status == 'maintenance') {
        maintenanceCount++;
      } else if (status == 'inactive') {
        inactiveCount++;
      }
    }
    
    return Column(
      children: [
        // Enhanced Summary card
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total count with summary
              Text(
                'Total Nozzles: ${allNozzlesWithDispenserInfo.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', null, 
                      allNozzlesWithDispenserInfo.length, Colors.blueGrey),
                    const SizedBox(width: 8),
                    _buildFilterChip('Active', 'Active', 
                      activeCount, Colors.green),
                    const SizedBox(width: 8),
                    _buildFilterChip('Maintenance', 'Maintenance', 
                      maintenanceCount, Colors.orange),
                    const SizedBox(width: 8),
                    _buildFilterChip('Inactive', 'Inactive', 
                      inactiveCount, Colors.red),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Nozzle List',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // Nozzle list
        Expanded(
          child: allNozzlesWithDispenserInfo.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.api_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Nozzles Added Yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the + button to add nozzles',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: allNozzlesWithDispenserInfo.length,
                  itemBuilder: (context, index) {
                    final nozzleInfo = allNozzlesWithDispenserInfo[index];
                    final nozzle = nozzleInfo['nozzle'] as Nozzle;
                    final dispenser = nozzleInfo['dispenser'] as FuelDispenser;
                    
                    // Skip if filtering is active and nozzle doesn't match
                    if (_statusFilter != null && nozzle.status != _statusFilter) {
                      return const SizedBox.shrink();
                    }
                    
                    return NozzleCard(
                      nozzle: nozzle,
                      dispenser: dispenser,
                      onTap: () => _showNozzleActionsMenu(nozzle, context),
                      onChangeStatus: () => _showNozzleActionsMenu(nozzle, context),
                      onAssignEmployee: () => _showEmployeeAssignmentDialog(nozzle),
                      onDelete: () => _deleteNozzle(nozzle),
                      onRemoveEmployee: nozzle.assignedEmployee != null && nozzle.assignedEmployee!.isNotEmpty
                          ? () => _removeEmployeeFromNozzle(nozzle)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
  
  // Filter chip widget similar to dispenser screen
  Widget _buildFilterChip(String label, String? value, int count, Color color) {
    final isSelected = value == _statusFilter || (value == null && _statusFilter == null);
    
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : color.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? color : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      selectedColor: color.withValues(alpha:0.2),
      checkmarkColor: color,
      side: BorderSide(
        color: isSelected ? color : Colors.grey.shade300,
      ),
      onSelected: (selected) {
        setState(() {
          _statusFilter = selected ? value : null;
        });
      },
    );
  }

  // Show nozzle actions menu - improved design
  void _showNozzleActionsMenu(Nozzle nozzle, BuildContext context) {
    final bool isActive = nozzle.status.toLowerCase() == 'active';
    final bool isMaintenance = nozzle.status.toLowerCase() == 'maintenance';
    final bool isInactive = nozzle.status.toLowerCase() == 'inactive';
    final Color nozzleColor = _getFuelTypeColor(nozzle.fuelType);
    final Color statusColor = isActive 
        ? Colors.green 
        : (isMaintenance ? Colors.orange : Colors.red);
    
    // Find the dispenser for this nozzle
    FuelDispenser? dispenser;
    for (var d in _dispensers) {
      if (d.id == nozzle.fuelDispenserUnitId) {
        dispenser = d;
        break;
      }
    }
    
    final String dispenserNumberText = dispenser != null 
        ? 'Dispenser #${dispenser.dispenserNumber}'
        : 'Dispenser';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle and header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        // Title row with nozzle details
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: nozzleColor.withValues(alpha:0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    nozzle.nozzleNumber.toString(),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: nozzleColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Nozzle #${nozzle.nozzleNumber}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    nozzle.fuelType == null ? const SizedBox.shrink() : Text(
                                      nozzle.fuelType!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: nozzleColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha:0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: statusColor.withValues(alpha:0.5), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isActive ? Icons.check_circle
                                    : (isMaintenance ? Icons.build : Icons.power_off),
                                    color: statusColor,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    nozzle.status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Dispenser info card
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black.withValues(alpha:0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withValues(alpha:0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.dashboard_outlined,
                                    color: AppTheme.primaryBlue,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Connected to',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        dispenserNumberText,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Employee assignment card
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black.withValues(alpha:0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha:0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.blue.shade700,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Employee Assignment',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const Divider(height: 1),
                              
                              // Employee details or assignment button
                              nozzle.assignedEmployee != null && nozzle.assignedEmployee!.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Currently Assigned',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  nozzle.assignedEmployee!,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _removeEmployeeFromNozzle(nozzle);
                                            },
                                            icon: Icon(
                                              Icons.person_remove,
                                              size: 16,
                                              color: Colors.red.shade700,
                                            ),
                                            label: Text(
                                              'Remove',
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: Colors.red.shade700),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'No employee assigned to this nozzle',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _showEmployeeAssignmentDialog(nozzle);
                                          },
                                          icon: const Icon(Icons.person_add, size: 18),
                                          label: const Text('Assign Employee'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Status actions section
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha:0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status Management',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatusButton(
                                      label: 'Active',
                                      icon: Icons.check_circle_outline,
                                      color: Colors.green,
                                      isDisabled: isActive,
                                      onTap: isActive 
                                          ? null
                                          : () {
                                              Navigator.pop(context);
                                              _activateNozzle(nozzle);
                                            },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatusButton(
                                      label: 'Maintenance',
                                      icon: Icons.build,
                                      color: Colors.orange,
                                      isDisabled: isMaintenance,
                                      onTap: isMaintenance 
                                          ? null
                                          : () {
                                              Navigator.pop(context);
                                              _setNozzleToMaintenance(nozzle);
                                            },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatusButton(
                                      label: 'Inactive',
                                      icon: Icons.power_off,
                                      color: Colors.red,
                                      isDisabled: isInactive,
                                      onTap: isInactive 
                                          ? null
                                          : () {
                                              Navigator.pop(context);
                                              _deactivateNozzle(nozzle);
                                            },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Actions section
                        nozzle.assignedEmployee != null && nozzle.assignedEmployee!.isNotEmpty
                        ? ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showEmployeeAssignmentDialog(nozzle);
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Change Employee Assignment'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              minimumSize: const Size(double.infinity, 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                        : const SizedBox(),
                        
                        const SizedBox(height: 12),
                        
                        // Delete button
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteNozzle(nozzle);
                          },
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete Nozzle'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            minimumSize: const Size(double.infinity, 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  // New method to build status action button
  Widget _buildStatusButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDisabled,
    required VoidCallback? onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDisabled ? color.withValues(alpha:0.15) : color.withValues(alpha:0.9),
        foregroundColor: isDisabled ? color.withValues(alpha:0.5) : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: isDisabled ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isDisabled ? FontWeight.w600 : FontWeight.bold,
            ),
          ),
          if (isDisabled)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Current',
                style: TextStyle(fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  // Load fuel tanks for dropdown
  Future<void> _loadFuelTanks() async {
    try {
      print('NozzleManagementScreen: Loading fuel tanks');
      developer.log('NozzleManagementScreen: Loading fuel tanks');
      
      final response = await _fuelTankRepository.getAllFuelTanks();
      
      if (!mounted) return;
      
      if (response.success && response.data != null) {
        print('NozzleManagementScreen: Loaded ${response.data!.length} fuel tanks');
        developer.log('NozzleManagementScreen: Loaded ${response.data!.length} fuel tanks');
        setState(() {
          _fuelTanks = response.data!;
        });
      } else {
        print('NozzleManagementScreen: Failed to load fuel tanks: ${response.errorMessage}');
        developer.log('NozzleManagementScreen: Failed to load fuel tanks: ${response.errorMessage}');
      }
    } catch (e) {
      print('NozzleManagementScreen: Error loading fuel tanks: $e');
      developer.log('NozzleManagementScreen: Error loading fuel tanks: $e');
    }
  }

  // Method to load employees from the repository
  Future<void> _loadEmployees() async {
    print('NozzleManagementScreen: Loading employees');
    
    try {
      final response = await _employeeRepository.getAllEmployees();
      
      if (response.success && response.data != null) {
        setState(() {
          _employees = response.data!
            .where((employee) => employee.isActive)
            .toList();
          print('NozzleManagementScreen: Loaded ${_employees.length} active employees');
        });
      } else {
        print('NozzleManagementScreen: Failed to load employees: ${response.errorMessage}');
      }
    } catch (e) {
      print('NozzleManagementScreen: Error loading employees: $e');
    }
  }

  // Method to load shifts from the repository
  Future<void> _loadShifts() async {
    print('NozzleManagementScreen: Loading shifts');
    
    try {
      final response = await _shiftRepository.getAllShifts();
      
      if (response.success && response.data != null) {
        setState(() {
          _shifts = response.data!;
          print('NozzleManagementScreen: Loaded ${_shifts.length} shifts');
        });
      } else {
        print('NozzleManagementScreen: Failed to load shifts: ${response.errorMessage}');
      }
    } catch (e) {
      print('NozzleManagementScreen: Error loading shifts: $e');
    }
  }

  // Show confirmation dialog for removing employee from nozzle
  Future<bool> _showRemoveEmployeeConfirmation(BuildContext context, Nozzle nozzle) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Employee Assignment'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Are you sure you want to remove ${nozzle.assignedEmployee} from Nozzle #${nozzle.nozzleNumber}?',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This action cannot be undone.',
                  style: TextStyle(
                    fontSize: 14, 
                    color: Colors.red,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text(
                'Remove',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    ) ?? false;
  }

  // Remove employee from nozzle
  Future<void> _removeEmployeeFromNozzle(Nozzle nozzle) async {
    if (nozzle.assignmentId == null || nozzle.assignmentId!.isEmpty) {
      print('NozzleManagementScreen: Cannot remove employee, no assignment ID available');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove employee: Assignment ID not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('NozzleManagementScreen: Removing employee from nozzle #${nozzle.nozzleNumber}, assignmentId: ${nozzle.assignmentId}');
    
    // Show confirmation dialog first
    final confirmed = await _showRemoveEmployeeConfirmation(context, nozzle);
    
    if (!confirmed) {
      print('NozzleManagementScreen: Employee removal cancelled by user');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final response = await _employeeNozzleAssignmentRepository.removeEmployeeNozzleAssignment(nozzle.assignmentId!);
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      if (response.success) {
        print('NozzleManagementScreen: Employee removed successfully from nozzle #${nozzle.nozzleNumber}');
        
        // Update the UI by clearing the assignment
        setState(() {
          nozzle.assignedEmployee = null;
          nozzle.assignmentId = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee removed from nozzle successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('NozzleManagementScreen: Failed to remove employee: ${response.errorMessage}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove employee: ${response.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('NozzleManagementScreen: Exception when removing employee: $e');
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing employee: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Build modern stat card for header
  Widget _buildModernStatCard(String title, String value, IconData icon, Color color, {bool isAlert = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.15),
          borderRadius: BorderRadius.circular(12),
          border: isAlert ? Border.all(color: Colors.amber, width: 1.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha:0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
