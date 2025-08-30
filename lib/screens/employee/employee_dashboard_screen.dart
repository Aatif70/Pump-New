import 'package:flutter/material.dart';
import 'package:petrol_pump/screens/employee/shift_sales_screen.dart';
import '../../api/api_constants.dart';
import '../../api/attendance_repository.dart';
import '../../api/employee_shift_repository.dart';
import '../../api/fuel_type_repository.dart';
import '../../api/nozzle_assignment_repository.dart';
import '../../api/nozzle_repository.dart';
import '../../api/pricing_repository.dart';
import '../../models/employee_nozzle_assignment_model.dart';
import '../../models/fuel_type_model.dart';
import '../../models/price_model.dart';
import '../../models/shift_model.dart';
import '../../theme.dart';
import '../../utils/jwt_decoder.dart';
import '../login/login_screen.dart';
import 'employee_profile_screen.dart';
import 'nozzle_readings_detail_screen.dart';
import 'shift_sales_history_screen.dart';
import 'enter_nozzle_readings_screen.dart';
import 'readings_screen.dart';
import 'all_readings_screen.dart';
import 'employee_check_in_screen.dart';
import 'employee_check_out_screen.dart';
import 'employee_attendance_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  // User data
  late String _username = "";
  late String _role = "";
  late String _employeeId = "";
  late String _petrolPumpId = "";
  bool _isLoading = true;
  String _errorMessage = '';
  Shift? _currentShift;
  
  // Repositories
  final _employeeShiftRepository = EmployeeShiftRepository();
  final _pricingRepository = PricingRepository();
  final _fuelTypeRepository = FuelTypeRepository();
  final _nozzleAssignmentRepository = NozzleAssignmentRepository();
  final _nozzleRepository = NozzleRepository();
  final _attendanceRepository = AttendanceRepository();
  
  // Fuel price data
  List<FuelPrice> _currentPrices = [];
  bool _loadingPrices = false;
  String _priceErrorMessage = '';
  
  // Fuel type mapping data
  List<FuelType> _fuelTypes = [];
  bool _loadingFuelTypes = false;
  String _fuelTypeErrorMessage = '';
  Map<String, String> _fuelTypeIdToName = {};

  // Nozzle assignment data
  List<EmployeeNozzleAssignment> _nozzleAssignments = [];
  bool _loadingNozzleAssignments = false;
  String _nozzleAssignmentErrorMessage = '';

  // Check-in status
  bool _isCheckedIn = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  // Load user data from JWT token
  void _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token != null) {
        Map<String, dynamic>? decodedToken = JwtDecoder.decode(token);

        if (decodedToken != null) {
          developer.log('JWT Token contains - userId: ${decodedToken['userId']}, employeeId: ${decodedToken['employeeId']}');
          
          setState(() {
            _username = decodedToken['employeeName'] ?? decodedToken['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'] ?? 'Employee';
            _role = decodedToken['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ?? 'Attendant';
            _employeeId = decodedToken['employeeId'] ?? '';
            _petrolPumpId = decodedToken['petrolPumpId'] ?? '';
          });
          
          // Load data with our streamlined sequence
          await _loadDataInSequence();
        }
      } else {
        // No token - redirect to login
        _logout();
      }
    } catch (e) {
      developer.log('Error loading user data: $e');
      setState(() {
        _errorMessage = 'Error loading user data: $e';
        _isLoading = false;
      });
    }
  }
  
  // Simplified data loading sequence focused on key data
  Future<void> _loadDataInSequence() async {
    try {
      // Set loading state at the start
      setState(() {
        _isLoading = true;
        _loadingPrices = true;
        _loadingFuelTypes = true;
        _loadingNozzleAssignments = true;
      });
      
      _addDebugLog('Starting data load sequence');
      
      // Load dependencies in parallel for better performance
      List<Future> dataLoadingTasks = [];
      
      // 1. Load fuel types for proper display names
      dataLoadingTasks.add(_fetchFuelTypes().catchError((e) {
        _addDebugLog('Error loading fuel types: $e');
        setState(() {
          _fuelTypeErrorMessage = 'Error: $e';
          _loadingFuelTypes = false;
        });
      }));
      
      // 2. Load current prices in parallel
      dataLoadingTasks.add(_fetchCurrentPrices().catchError((e) {
        _addDebugLog('Error loading prices: $e');
        setState(() {
          _priceErrorMessage = 'Error: $e';
          _loadingPrices = false;
        });
      }));
      
      // 3. Load shift data
      dataLoadingTasks.add(_fetchCurrentShift().catchError((e) {
        _addDebugLog('Error loading current shift: $e');
        setState(() {
          _errorMessage = 'Error loading shift data: $e';
        });
      }));
      
      // 4. Load nozzle assignments
      dataLoadingTasks.add(_fetchNozzleAssignments().catchError((e) {
        _addDebugLog('Error loading nozzle assignments: $e');
        setState(() {
          _nozzleAssignmentErrorMessage = 'Error: $e';
          _loadingNozzleAssignments = false;
        });
      }));
      
      // 5. Fetch check-in status
      dataLoadingTasks.add(_fetchCheckInStatus().catchError((e) {
        _addDebugLog('Error fetching check-in status: $e');
      }));
      
      // Wait for parallel data loading to complete
      await Future.wait(dataLoadingTasks);
      
      _addDebugLog('Data loading sequence completed');
    } catch (e) {
      _addDebugLog('Error in data loading sequence: $e');
      setState(() {
        _errorMessage = 'Error loading data: $e';
      });
    } finally {
      // Ensure loading state is reset regardless of success or failure
      setState(() {
        _isLoading = false;
        _loadingPrices = false;
        _loadingFuelTypes = false;
        _loadingNozzleAssignments = false;
      });
    }
  }
  
  // Improved method to check and automatically reset for a new day

  // Helper to get time-appropriate greeting
  String _getTimeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'morning';
    } else if (hour < 17) {
      return 'afternoon';
    } else {
      return 'evening';
    }
  }
  
  // Fetch fuel types to map IDs to names
  Future<void> _fetchFuelTypes() async {
    setState(() {
      _loadingFuelTypes = true;
      _fuelTypeErrorMessage = '';
    });
    
    try {
      developer.log('Fetching fuel types for petrol pump');
      final response = await _fuelTypeRepository.getFuelTypesByPetrolPump();
      
      if (response.success && response.data != null) {
        setState(() {
          _fuelTypes = response.data!;
          
          // Create a mapping of fuel type IDs to their names
          _fuelTypeIdToName = {};
          for (var fuelType in _fuelTypes) {
            _fuelTypeIdToName[fuelType.fuelTypeId] = fuelType.name;
            developer.log('Mapped fuel type: ${fuelType.fuelTypeId} -> ${fuelType.name}');
          }
          
          developer.log('Loaded ${_fuelTypes.length} fuel types');
        });
      } else {
        setState(() {
          _fuelTypeErrorMessage = response.errorMessage ?? 'Failed to load fuel types';
          developer.log('Error loading fuel types: $_fuelTypeErrorMessage');
        });
      }
    } catch (e) {
      developer.log('Exception in _fetchFuelTypes: $e');
      setState(() {
        _fuelTypeErrorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _loadingFuelTypes = false;
      });
    }
  }
  
  // Get fuel type name from ID
  String _getFuelTypeName(String? fuelTypeId) {
    if (fuelTypeId == null || fuelTypeId.isEmpty) {
      return 'Unknown';
    }
    
    return _fuelTypeIdToName[fuelTypeId] ?? 'Unknown';
  }
  
  // Show prompt to complete sales entry
  void _showCompleteSalesPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Complete Shift'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Would you like to enter sales data for your shift?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToShiftSalesScreen(_employeeId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: Text('Enter Sales Now'),
          ),
        ],
      ),
    );
  }
  
  // Fetch current fuel prices
  Future<void> _fetchCurrentPrices() async {
    setState(() {
      _loadingPrices = true;
      _priceErrorMessage = '';
    });
    
    try {
      developer.log('Fetching current fuel prices');
      
      final response = await _pricingRepository.getCurrentPrices();
      
      setState(() {
        _loadingPrices = false;
        
        if (response.success && response.data != null) {
          _currentPrices = response.data!;
          developer.log('Loaded ${_currentPrices.length} fuel prices');
        } else {
          _priceErrorMessage = response.errorMessage ?? 'Failed to load fuel prices';
          developer.log('Error loading fuel prices: $_priceErrorMessage');
        }
      });
    } catch (e) {
      developer.log('Exception in _fetchCurrentPrices: $e');
      setState(() {
        _loadingPrices = false;
        _priceErrorMessage = 'Error: $e';
      });
    }
  }
  
  Future<void> _fetchCurrentShift() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      if (_employeeId.isEmpty) {
        setState(() {
          _errorMessage = 'Employee ID not found in token';
        });
        return;
      }
      
      developer.log('Fetching shifts for employee ID: $_employeeId using the getShiftsByEmployeeId endpoint');
      print('DEBUG: Fetching shifts for employee ID: $_employeeId');
      final response = await _employeeShiftRepository.getShiftsByEmployeeId(_employeeId);
      
      if (response.success && response.data != null && response.data!.isNotEmpty) {
        developer.log('Found ${response.data!.length} shifts for employeeId: $_employeeId');
        print('DEBUG: Found ${response.data!.length} shifts');
        
        // Find the current active shift
        final now = DateTime.now();
        final shifts = response.data!;
        
        // Try to find a shift that the employee is currently working
        try {
          _currentShift = shifts.firstWhere(
            (shift) {
              // Parse start and end times to determine if current time is within shift
              final shiftDate = DateFormat('yyyy-MM-dd').format(now);
              final startDateTime = DateFormat('yyyy-MM-dd HH:mm').parse('$shiftDate ${shift.startTime}');
              
              // Create a local variable for endDateTime that can be modified
              var endDateTime = DateFormat('yyyy-MM-dd HH:mm').parse('$shiftDate ${shift.endTime}');
              
              // Adjust for overnight shifts
              if (endDateTime.isBefore(startDateTime)) {
                endDateTime = endDateTime.add(const Duration(days: 1));
              }
              
              final isWithinShift = now.isAfter(startDateTime) && now.isBefore(endDateTime);
              print('DEBUG: Checking shift ${shift.shiftNumber}: start=$startDateTime, end=$endDateTime, isWithinShift=$isWithinShift');
              return isWithinShift;
            },
            orElse: () => shifts.first, // Default to first shift if no active shift found
          );
          
          developer.log('Selected shift: ${_currentShift!.shiftNumber} with ID: ${_currentShift!.id}');
          print('DEBUG: Selected shift: ${_currentShift!.shiftNumber}');
        } catch (e) {
          developer.log('Error finding current shift: $e');
          print('DEBUG: Error finding current shift: $e');
          // If there's an error finding the current shift, just use the first one
          if (shifts.isNotEmpty) {
            _currentShift = shifts.first;
          }
        }
      } else {
        developer.log('No shifts found or error for employeeId: $_employeeId. Error: ${response.errorMessage}');
        setState(() {
          _errorMessage = response.errorMessage ?? 'No shifts assigned to you';
        });
        print('DEBUG: No shifts found or error: ${response.errorMessage}');
      }
    } catch (e) {
      developer.log('Exception in _fetchCurrentShift: $e');
      print('DEBUG: Exception in _fetchCurrentShift: $e');
      setState(() {
        _errorMessage = 'Error fetching shifts: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Fetch nozzle assignments for the current employee
  Future<void> _fetchNozzleAssignments() async {
    setState(() {
      _loadingNozzleAssignments = true;
      _nozzleAssignmentErrorMessage = '';
    });
    
    try {
      if (_employeeId.isEmpty) {
        setState(() {
          _nozzleAssignmentErrorMessage = 'Employee ID not available';
          _loadingNozzleAssignments = false;
        });
        return;
      }
      
      developer.log('Fetching nozzle assignments for employee: $_employeeId');
      final response = await _nozzleAssignmentRepository.getEmployeeNozzleAssignments(_employeeId);
      
      setState(() {
        _loadingNozzleAssignments = false;
        
        if (response.success && response.data != null) {
          _nozzleAssignments = response.data!;
          developer.log('Loaded ${_nozzleAssignments.length} nozzle assignments');
        } else {
          _nozzleAssignmentErrorMessage = response.errorMessage ?? 'Failed to load nozzle assignments';
          developer.log('Error loading nozzle assignments: $_nozzleAssignmentErrorMessage');
        }
      });
    } catch (e) {
      developer.log('Exception in _fetchNozzleAssignments: $e');
      setState(() {
        _loadingNozzleAssignments = false;
        _nozzleAssignmentErrorMessage = 'Error: $e';
      });
    }
  }
  
  // Navigate to shift sales screen directly
  Future<void> _navigateToShiftSalesScreen(String employeeId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShiftSalesScreen(
          employeeId: employeeId,
        ),
      )
    );
    
    if (result == true) {
      await _refreshData();
    }
  }
  
  // Helper method for debug logging
  void _addDebugLog(String message) {
    developer.log('DEBUG: $message');
    print('DEBUG: $message');
  }

  // Map fuel types to their colors
  final Map<String, Color> _fuelColors = {
    'Petrol': Colors.green.shade700,
    'Diesel': Colors.blue.shade800,
    'Premium Petrol': Colors.orange.shade700,
    'Premium Diesel': Colors.purple.shade700,
    'CNG': Colors.teal.shade700,
    'LPG': Colors.indigo.shade700,
    'Bio-Diesel': Colors.amber.shade800,
    'Electric': Colors.cyan.shade700,
    // Fallback for any other fuel types
    'Unknown': Colors.grey.shade700,
  };

  get initialReadingType => null;

  // Get color for fuel type
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Employee Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      drawer: Drawer(
        elevation: 3,
        width: MediaQuery.of(context).size.width * 0.85,
        child: Column(
          children: [
            // Redesigned drawer header to prevent overflow
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlue.withValues(alpha:0.8),
                  ],
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 40,
                child: Text(
                  _username.isNotEmpty ? _username.substring(0, 1) : "E",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              accountName: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _username,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              accountEmail: Container(
                margin: const EdgeInsets.only(top: 4.0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _role,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            
            // Menu items section
            Expanded(
              child: Container(
                color: Colors.grey[50],
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    const SizedBox(height: 8), // Reduced spacing
                    
                    // Menu section: Main
                    _buildDrawerSection('Main'),
                    
                    // DASHBOARD
                    _buildDrawerItem(
                      icon: Icons.dashboard_rounded,
                      title: 'Dashboard',
                      onTap: () {
                        Navigator.pop(context); // Close the drawer
                      },
                      isSelected: true,
                    ),

                    // MY PROFILE
                    _buildDrawerItem(
                      icon: Icons.account_circle_rounded,
                      title: 'My Profile',
                      onTap: () {
                        Navigator.pop(context);
                        // Navigate to profile screen with updated endpoint
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EmployeeProfileScreen(),
                          ),
                        );
                      },
                    ),

                    // Menu section: Operations
                    _buildDrawerSection('Operations'),

                    // SHIFT SALES
                    _buildDrawerItem(
                      icon: Icons.attach_money_rounded,
                      title: 'Shift Sales',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ShiftSalesHistoryScreen(employeeId: _employeeId),
                          ),
                        );
                      },
                    ),



                    // ATTENDANCE
                    _buildDrawerItem(
                      icon: Icons.event_available_rounded,
                      title: 'Attendance',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EmployeeAttendanceScreen(
                              employeeId: _employeeId,
                              employeeName: _username,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    
                    Divider(
                      color: Colors.grey[300],
                      thickness: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                    
                    // LOGOUT
                    _buildDrawerItem(
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      onTap: _logout,
                      color: Colors.red[700],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome header
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 20, 10, 20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 35,
                                backgroundColor: Colors.white24,
                                child: Icon(
                                  Icons.person,
                                  size: 30,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _username,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          _role,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Check-in status badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _isCheckedIn 
                                                ? Colors.green.withValues(alpha:0.3) 
                                                : Colors.red.withValues(alpha:0.3),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _isCheckedIn ? Icons.check_circle : Icons.cancel,
                                                size: 12,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _isCheckedIn ? 'Checked In' : 'Not Checked In',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
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
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Error message if any
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Shift Assignment Issue',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Current Fuel Prices
                    _buildCurrentPricesCard(),
                    
                    // Current Shift Card
                    if (_currentShift != null)
                      _buildCurrentShiftCard(_currentShift!)
                    else if (_errorMessage.isEmpty)
                      _buildNoShiftCard(),

                    // Add Check-in Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha:0.03),
                              blurRadius: 6,
                              spreadRadius: 0,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title row
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    color: Colors.grey.shade600,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Attendance',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Check-in section
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: InkWell(
                                onTap: _navigateToCheckInScreen,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.green.shade50,
                                    border: Border.all(
                                      color: Colors.green.shade100,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Check-in icon
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.login_rounded,
                                            color: Colors.green.shade600,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      // Check-in details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'Check-In',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey.shade800,
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (_isCheckedIn)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.shade100,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      'Active',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w500,
                                                        color: Colors.green.shade700,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Record your arrival',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey.shade400,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            // Check-out section
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: InkWell(
                                onTap: _navigateToCheckOutScreen,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.red.shade50,
                                    border: Border.all(
                                      color: Colors.red.shade100,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Check-out icon
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.logout_rounded,
                                            color: Colors.red.shade600,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      // Check-out details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'Check-Out',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey.shade800,
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (!_isCheckedIn)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.shade100,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      'Pending',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w500,
                                                        color: Colors.red.shade700,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Record your departure',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey.shade400,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Nozzle Assignment Card
                    _buildNozzleAssignmentCard(),
                    

                    // View Reading History Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha:0.03),
                              blurRadius: 6,
                              spreadRadius: 0,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title row
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    color: Colors.grey.shade600,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'History',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // View history section
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: InkWell(
                                onTap: () {
                                  if (_nozzleAssignments.isNotEmpty) {
                                    _showHistorySelectionDialog();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('No nozzle assignment found'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey.shade50,
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // History icon
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.history,
                                            color: Colors.grey.shade600,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      // History details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'View History',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey.shade800,
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (_nozzleAssignments.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade200,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      '${_nozzleAssignments.length} Nozzles',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w500,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'View nozzle reading history',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey.shade400,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
  
  // New method: Build shift progress tracker
  Widget _buildShiftProgressTracker() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)
            )
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checklist_rounded,
                  color: AppTheme.primaryOrange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Today\'s Shift Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            

            // Progress divider
            _buildProgressDivider(),
            

            
            // Progress divider
            _buildProgressDivider(),
            

            // Progress divider
            _buildProgressDivider(),
            

          ],
        ),
      ),
    );
  }
  
  // Helper to build a single progress item
  Widget _buildProgressItem({
    required String title,
    required bool isCompleted,
    required bool isActive,
    required IconData icon,
  }) {
    return Row(
      children: [
        // Status indicator
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isCompleted 
                ? Colors.green.shade500 
                : isActive 
                  ? AppTheme.primaryOrange
                  : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, color: Colors.white, size: 16)
                : Icon(icon, color: Colors.white, size: 16),
          ),
        ),
        const SizedBox(width: 16),
        // Label
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive || isCompleted ? FontWeight.w600 : FontWeight.normal,
              color: isActive 
                  ? AppTheme.primaryOrange
                  : isCompleted 
                    ? Colors.green.shade700
                    : Colors.grey.shade500,
            ),
          ),
        ),
        // Status badge
        if (isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Current Step',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryOrange,
              ),
            ),
          )
        else if (isCompleted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Completed',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Pending',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
      ],
    );
  }
  
  // Helper to build a vertical progress divider
  Widget _buildProgressDivider() {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.only(left: 14),
          width: 2,
          height: 16,
          color: Colors.grey.shade300,
        ),
        const Expanded(child: SizedBox()),
      ],
    );
  }

  // Improved refresh method to use our enhanced data loading sequence
  Future<void> _refreshData() async {
    if (!mounted) return;
    
    // Show loading indicator
    setState(() {
      _isLoading = true;
      _loadingPrices = true;
      _loadingNozzleAssignments = true;
    });
    
    try {
      // Run the data loading sequence
      await _loadDataInSequence();
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data refreshed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _addDebugLog('Error refreshing data: $e');
      
      if (mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing data: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingPrices = false;
          _loadingNozzleAssignments = false;
        });
      }
    }
  }

  // Card for displaying current shift information
  Widget _buildCurrentShiftCard(Shift shift) {
    // Get shift status
    final now = DateTime.now();
    final shiftDate = DateFormat('yyyy-MM-dd').format(now);
    final startDateTime = DateFormat('yyyy-MM-dd HH:mm').parse('$shiftDate ${shift.startTime}');
    var endDateTime = DateFormat('yyyy-MM-dd HH:mm').parse('$shiftDate ${shift.endTime}');
    
    // Adjust for overnight shifts
    if (endDateTime.isBefore(startDateTime)) {
      endDateTime = endDateTime.add(const Duration(days: 1));
    }
    
    // Determine shift status
    String shiftStatus = 'Upcoming';
    Color statusColor = Colors.orange;
    
    if (now.isAfter(startDateTime) && now.isBefore(endDateTime)) {
      shiftStatus = 'Active';
      statusColor = Colors.green;
    } else if (now.isAfter(endDateTime)) {
      shiftStatus = 'Completed';
      statusColor = Colors.blue;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_filled,
                    color: AppTheme.primaryBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Current Shift Assignment',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
            
            // Shift period
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.date_range,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Today, ${DateFormat('dd MMMM yyyy').format(now)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Shift Info Card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryBlue.withValues(alpha:0.05),
                      AppTheme.primaryBlue.withValues(alpha:0.1),
                    ],
                  ),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha:0.2),
                  ),
                ),
                child: Column(
                  children: [
                    // Top row with shift number and status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Shift number badge
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '#${shift.shiftNumber}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Shift details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Shift ID and status
                              Row(
                                children: [
                                  Icon(
                                    Icons.verified_outlined,
                                    size: 14,
                                    color: AppTheme.primaryBlue,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Shift Number: ${shift.shiftNumber ?? 'N/A'}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha:0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      shiftStatus,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              
                              // Shift duration
                              Row(
                                children: [
                                  Icon(
                                    Icons.timelapse,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Duration: ${shift.shiftDuration} hours',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Shift timings
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha:0.03),
                            blurRadius: 4,
                            spreadRadius: 0,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Start time
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'START TIME',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.green.shade700,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      shift.startTime,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Divider
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.grey.shade200,
                          ),
                          
                          // End time
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'END TIME',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.stop_rounded,
                                        color: Colors.red.shade700,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      shift.endTime,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
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
                    
                    // Progress indicator
                    if (shiftStatus == 'Active') ...[
                      const SizedBox(height: 12),
                      _buildShiftProgressIndicator(startDateTime, endDateTime),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to build shift progress indicator
  Widget _buildShiftProgressIndicator(DateTime startTime, DateTime endTime) {
    final now = DateTime.now();
    final totalDuration = endTime.difference(startTime).inMinutes;
    final elapsedDuration = now.difference(startTime).inMinutes;
    
    // Calculate progress percentage (capped between 0-100%)
    final progressPercent = (elapsedDuration / totalDuration).clamp(0.0, 1.0);
    
    // Format remaining time
    final remainingMinutes = totalDuration - elapsedDuration;
    final remainingHours = remainingMinutes ~/ 60;
    final remainingMins = remainingMinutes % 60;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Shift Progress',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              '${(progressPercent * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            // Background
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Progress
            Container(
              height: 6,
              width: MediaQuery.of(context).size.width * 0.7 * progressPercent,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withValues(alpha:0.7)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 12,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              'Remaining: ${remainingHours}h ${remainingMins}m',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Card for when no shift is assigned
  Widget _buildNoShiftCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.schedule_outlined,
                  size: 24,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No Active Shift',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You are not currently assigned to any shift',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _refreshData,
                child: Text('Check'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size(60, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Card for displaying employee nozzle assignment
  Widget _buildNozzleAssignmentCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.offline_bolt,
                    color: AppTheme.primaryOrange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Your Nozzle Assignments',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_nozzleAssignments.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_nozzleAssignments.length}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Display error message if any
            if (_nozzleAssignmentErrorMessage.isNotEmpty && _nozzleAssignments.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Unable to load nozzle assignment: $_nozzleAssignmentErrorMessage',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
            
            // Display no assignments message if no error but empty list
            if (_nozzleAssignmentErrorMessage.isEmpty && _nozzleAssignments.isEmpty && !_loadingNozzleAssignments)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.gesture_outlined,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No nozzle assignment available',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Display nozzle assignments
            if (_nozzleAssignments.isNotEmpty)
              Column(
                children: _nozzleAssignments.map((assignment) => 
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Assignment period
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.date_range,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Assignment: ${DateFormat('dd MMM').format(DateTime.parse(assignment.startDate))} - ${DateFormat('dd MMM yyyy').format(DateTime.parse(assignment.endDate))}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Nozzle Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _getFuelTypeColor(assignment.fuelType).withValues(alpha:0.05),
                                _getFuelTypeColor(assignment.fuelType).withValues(alpha:0.1),
                              ],
                            ),
                            border: Border.all(
                              color: _getFuelTypeColor(assignment.fuelType).withValues(alpha:0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nozzle number badge
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: _getFuelTypeColor(assignment.fuelType),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    assignment.nozzleNumber.toString(),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              
                              // Nozzle details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Fuel type
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.local_gas_station,
                                          size: 14,
                                          color: _getFuelTypeColor(assignment.fuelType),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          assignment.fuelType,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: _getFuelTypeColor(assignment.fuelType),
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: assignment.isActive 
                                                ? Colors.green.shade100
                                                : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            assignment.isActive ? 'Active' : 'Inactive',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: assignment.isActive
                                                  ? Colors.green.shade700
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    
                                    // Dispenser information
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.ev_station_rounded,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Dispenser #${assignment.fuelDispenserNo ?? 'N/A'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    // Shift info
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Shift #${assignment.shiftNumber}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey.shade800,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.schedule,
                                                      size: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${assignment.shiftStartTime.substring(0, 5)} - ${assignment.shiftEndTime.substring(0, 5)}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              // Save to SharedPreferences
                                              _saveNozzleDataToPreferences(assignment);
                                              
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => EnterNozzleReadingsScreen(
                                                    nozzleId: assignment.nozzleId,
                                                    shiftId: assignment.shiftId,
                                                    fuelTankId: assignment.fuelTankId,
                                                    petrolPumpId: assignment.petrolPumpId,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryBlue.withValues(alpha:0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Enter Readings',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryBlue,
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
                            ],
                          ),
                        ),
                        if (_nozzleAssignments.last != assignment)
                          Divider(height: 24, color: Colors.grey.shade200),
                      ],
                    ),
                  )
                ).toList(),
              ),
            
            // Loading indicator
            if (_loadingNozzleAssignments)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryOrange),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Card for displaying current fuel prices
  Widget _buildCurrentPricesCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with refresh button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_gas_station,
                        color: AppTheme.primaryOrange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Today\'s Fuel Prices',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            
            // Display error message if any
            if (_priceErrorMessage.isNotEmpty && _currentPrices.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Unable to load prices: $_priceErrorMessage',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
            
            // Display no prices message if no error but empty list
            if (_priceErrorMessage.isEmpty && _currentPrices.isEmpty && !_loadingPrices)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'No fuel prices available',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            
            // Display fuel prices
            if (_currentPrices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentPrices.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Updated: ${DateFormat('dd MMM, HH:mm').format(_currentPrices.first.effectiveFrom)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _currentPrices.map((price) => _buildPriceChip(price)).toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper to build a price chip
  Widget _buildPriceChip(FuelPrice price) {
    // Use the fuelType directly from the API response instead of trying to map from ID
    final String displayFuelType = price.fuelType.isNotEmpty 
        ? price.fuelType 
        : _getFuelTypeName(price.fuelTypeId);
    
    final Color color = _fuelColors[displayFuelType] ?? Colors.grey.shade700;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            displayFuelType,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha:0.2),
                  blurRadius: 2,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Text(
              '₹${price.pricePerLiter.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build action buttons with consistent styling
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDisabled,
    required VoidCallback onPressed,
    String disabledText = "Not Available",
    bool isFullWidth = false,
  }) {
    return ElevatedButton.icon(
      onPressed: isDisabled ? null : onPressed,
      icon: Icon(
        icon,
        size: 20,
      ),
      label: Text(
        isDisabled ? disabledText : label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDisabled ? Colors.grey.shade200 : color,
        foregroundColor: isDisabled ? Colors.grey.shade700 : Colors.white,
        minimumSize: Size(isFullWidth ? double.infinity : 100, 44),
        elevation: isDisabled ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  // Save nozzle data to SharedPreferences
  Future<void> _saveNozzleDataToPreferences(EmployeeNozzleAssignment assignment) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('employee_nozzle_id', assignment.nozzleId);
      await prefs.setString('employee_shift_id', assignment.shiftId);
      
      // Get nozzle details to save fuel tank ID and petrol pump ID
      final nozzleResp = await _nozzleRepository.getNozzleById(assignment.nozzleId);
      if (nozzleResp.success && nozzleResp.data != null) {
        final nozzle = nozzleResp.data!;
        await prefs.setString('employee_fuel_tank_id', nozzle.fuelTankId ?? '');
        await prefs.setString('employee_petrol_pump_id', nozzle.petrolPumpId ?? '');
      }
    } catch (e) {
      print('Error saving nozzle data to preferences: $e');
    }
  }

  // Clear nozzle data from SharedPreferences
  Future<void> _clearNozzleDataOnLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('employee_nozzle_id');
      await prefs.remove('employee_shift_id');
      await prefs.remove('employee_fuel_tank_id');
      await prefs.remove('employee_petrol_pump_id');
    } catch (e) {
      print('Error clearing nozzle data from preferences: $e');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.authTokenKey);
    await _clearNozzleDataOnLogout();
    
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // Build drawer section heading
  Widget _buildDrawerSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 2, top: 2),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Divider(
              color: Colors.grey[300],
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  // Build drawer item
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required Function() onTap,
    Color? color,
    bool isSelected = false,
  }) {
    final itemColor = color ?? (isSelected ? AppTheme.primaryOrange : Colors.grey.shade700);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryOrange.withValues(alpha:0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        horizontalTitleGap: 8,
        minLeadingWidth: 24,
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isSelected
              ? AppTheme.primaryOrange.withValues(alpha:0.2)
              : itemColor.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: itemColor,
            size: 18,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: itemColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: isSelected
          ? Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: BorderRadius.circular(8),
              ),
            )
          : null,
        onTap: onTap,
        dense: true,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      ),
    );
  }

  // Add this function to navigate to check-in screen
  void _navigateToCheckInScreen() {
    if (_currentShift != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmployeeCheckInScreen(
            employeeId: _employeeId,
            employeeName: _username,
            shiftId: _currentShift!.id ?? '',
            shiftNumber: _currentShift!.shiftNumber.toString(),
          ),
        ),
      ).then((value) {
        if (value == true) {
          // Refresh data if check-in was successful
          _refreshData();
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No active shift found. Please contact your manager.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add this function to navigate to check-out screen
  void _navigateToCheckOutScreen() {
    if (_currentShift != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmployeeCheckOutScreen(
            employeeId: _employeeId,
            employeeName: _username,
            shiftId: _currentShift!.id ?? '',
            shiftNumber: _currentShift!.shiftNumber.toString(),
          ),
        ),
      ).then((value) {
        if (value == true) {
          // Refresh data if check-out was successful
          _refreshData();
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No active shift found. Please contact your manager.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fetch check-in status
  Future<void> _fetchCheckInStatus() async {
    try {
      if (_employeeId.isEmpty) {
        setState(() {
          _errorMessage = 'Employee ID not found in token';
        });
        return;
      }
      
      developer.log('Fetching check-in status for employee ID: $_employeeId');
      final response = await _attendanceRepository.isEmployeeCheckedIn(_employeeId);
      
      if (response.success && response.data != null) {
        setState(() {
          _isCheckedIn = response.data!;
          developer.log('Check-in status: $_isCheckedIn');
        });
      } else {
        developer.log('Error fetching check-in status: ${response.errorMessage}');
      }
    } catch (e) {
      developer.log('Exception in _fetchCheckInStatus: $e');
    }
  }

  // Show dialog to select which nozzle to enter readings for
  void _showNozzleSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select Nozzle',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        content: Container(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _nozzleAssignments.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              final assignment = _nozzleAssignments[index];
              return ListTile(
                onTap: () {
                  Navigator.pop(context);
                  // Save to SharedPreferences
                  _saveNozzleDataToPreferences(assignment);
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EnterNozzleReadingsScreen(
                        nozzleId: assignment.nozzleId,
                        shiftId: assignment.shiftId,
                        fuelTankId: assignment.fuelTankId,
                        petrolPumpId: assignment.petrolPumpId,
                      ),
                    ),
                  );
                },
                contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getFuelTypeColor(assignment.fuelType),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      assignment.nozzleNumber.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        assignment.fuelType,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Dispenser #${assignment.fuelDispenserNo ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  'Nozzle #${assignment.nozzleNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: assignment.isActive 
                        ? Colors.green.shade100 
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    assignment.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: assignment.isActive 
                          ? Colors.green.shade700 
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show dialog to select which nozzle's history to view
  void _showHistorySelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select Nozzle History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        content: Container(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _nozzleAssignments.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              final assignment = _nozzleAssignments[index];
              return ListTile(
                onTap: () {
                  Navigator.pop(context);
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NozzleReadingsDetailScreen(
                        employeeId: _employeeId,
                        nozzleId: assignment.nozzleId,
                        nozzleNumber: assignment.nozzleNumber.toString(),
                        fuelType: assignment.fuelType,
                        employeeName: _username,
                      ),
                    ),
                  );
                },
                contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getFuelTypeColor(assignment.fuelType),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      assignment.nozzleNumber.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        assignment.fuelType,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Dispenser #${assignment.fuelDispenserNo ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  'Nozzle #${assignment.nozzleNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                trailing: Icon(
                  Icons.history,
                  color: Colors.grey.shade500,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
