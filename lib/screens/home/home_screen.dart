import 'package:flutter/material.dart';
import 'package:petrol_pump/screens/employee/employee_list_screen.dart';
import 'package:petrol_pump/screens/fuel_tank/fuel_tank_list_screen.dart';
import '../../api/api_constants.dart';
import '../../api/employee_repository.dart';
import '../../api/fuel_tank_repository.dart';
import '../../api/current_user_repository.dart';
import '../../models/employee_model.dart';
import '../../models/fuel_tank_model.dart';
import '../../models/current_user_model.dart';
import '../../theme.dart';
import '../employee/all_readings_screen.dart';
import '../employee/readings_screen.dart';
import '../fuel/fuel_options_screen.dart';
import '../login/login_screen.dart';
import '../shift/shift_list_screen.dart';
import '../reports/reports_options_screen.dart';
import '../attendance/attendance_screen.dart';
import '../supplier/supplier_list_screen.dart';
import '../fuel_delivery/fuel_delivery_history_screen.dart';
import '../sales/sales_statistics_screen.dart';
import '../profile/profile_screen.dart';
import '../inventory/inventory_screen.dart';
import '../finance/finance_screen.dart';
import '../operations/operations_screen.dart';
import '../customer/customer_list_screen.dart';
import '../voucher/voucher_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final String username = "Admin"; // This would come from your auth system
  
  // Repositories
  final _employeeRepository = EmployeeRepository();
  final _fuelTankRepository = FuelTankRepository();
  final _currentUserRepository = CurrentUserRepository();
  
  // Data for charts
  List<Employee> _employees = [];
  List<FuelTank> _fuelTanks = [];
  CurrentUser? _currentUser;
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  // Load data for charts
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Load employees
      final employeeResponse = await _employeeRepository.getAllEmployees();
      
      // Load fuel tanks
      final fuelTankResponse = await _fuelTankRepository.getAllFuelTanks();
      
      // Load current user
      final currentUserResponse = await _currentUserRepository.getCurrentUser();
      
      // Debug the current user response
      print('Current user response: success=${currentUserResponse.success}, error=${currentUserResponse.errorMessage}');
      if (currentUserResponse.data != null) {
        print('Current user data: name=${currentUserResponse.data!.fullName}, email=${currentUserResponse.data!.email}, role=${currentUserResponse.data!.role}');
      } else {
        print('Current user data is null');
      }
      
      if (!mounted) return;
      
      if (employeeResponse.success && fuelTankResponse.success && currentUserResponse.success) {
        setState(() {
          _employees = employeeResponse.data ?? [];
          _fuelTanks = fuelTankResponse.data ?? [];
          _currentUser = currentUserResponse.data;
          _isLoading = false;
        });
        
        // Restart animation on data load
        _animationController.reset();
        _animationController.forward();
      } else {
        setState(() {
          _errorMessage = 'Failed to load data: ${employeeResponse.errorMessage ?? ''} ${fuelTankResponse.errorMessage ?? ''} ${currentUserResponse.errorMessage ?? ''}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _logout() async {
    // Clear the stored token/session data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.authTokenKey);
    
    // Navigate back to login screen and remove all routes from stack
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false, // This will remove all routes
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Admin Dashboard',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white,
            onPressed: _loadData,
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
                  _currentUser?.fullName.isNotEmpty == true 
                      ? _currentUser!.fullName.substring(0, 1) 
                      : username.substring(0, 1),
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
                  _currentUser?.fullName ?? username,
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
                  _currentUser?.role ?? 'Admin',
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
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
                      
                      // PROFILE
                      _buildDrawerItem(
                        icon: Icons.account_circle_rounded,
                        title: 'Profile',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => const ProfileScreen()),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 8), // Reduced spacing
                      
                      // Menu section: Management
                      _buildDrawerSection('Management'),
                      
                      // SHIFTS
                      _buildDrawerItem(
                        icon: Icons.schedule_rounded,
                        title: 'Shifts',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => const ShiftListScreen()),
                          );
                        },
                      ),
                      
                      // FUEL TANKS
                      _buildDrawerItem(
                        icon: Icons.local_gas_station_rounded,
                        title: 'View Tanks',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const FuelTankListScreen()),
                          );
                        },
                      ),
                      
                      // EMPLOYEES
                      _buildDrawerItem(
                        icon: Icons.people_rounded,
                        title: 'View Employees',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const EmployeeListScreen()),
                          );
                        },
                      ),
                      
                      // SUPPLIERS
                      _buildDrawerItem(
                        icon: Icons.business_rounded,
                        title: 'Suppliers',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SupplierListScreen()),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 8), // Reduced spacing
                      
                      // Menu section: Business
                      _buildDrawerSection('Business'),
                      
                      // FUEL DELIVERIES
                      _buildDrawerItem(
                        icon: Icons.local_shipping_rounded,
                        title: 'Fuel Deliveries',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const FuelDeliveryHistoryScreen()),
                          );
                        },
                      ),
                      
                      // FINANCE
                      _buildDrawerItem(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Finance',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const FinanceScreen()),
                          );
                        },
                      ),
                      
                      // OPERATIONS
                      _buildDrawerItem(
                        icon: Icons.settings_applications_rounded,
                        title: 'Operations',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const OperationsScreen()),
                          );
                        },
                      ),
                      
                      // INVENTORY
                      _buildDrawerItem(
                        icon: Icons.inventory_2_rounded,
                        title: 'Inventory',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const InventoryScreen()),
                          );
                        },
                      ),
                      
                      // SALES STATISTICS
                      _buildDrawerItem(
                        icon: Icons.bar_chart_rounded,
                        title: 'Sales Statistics',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SalesStatisticsScreen()),
                          );
                        },
                      ),
                      
                      // ALL READINGS
                      _buildDrawerItem(
                        icon: Icons.on_device_training_rounded,
                        title: 'All Readings',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AllReadingsScreen()),
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
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header - now fixed at the top outside of the scrollable area
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha:0.3),
                        blurRadius: 15,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha:0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, ${_currentUser?.fullName ?? username}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Dashboard Overview',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha:0.8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Stats cards
                        Row(
                          children: [
                            _buildHeaderStat(
                              'Employees', 
                              _employees.length.toString(),
                              Icons.people_outline,
                            ),
                            const SizedBox(width: 16),
                            _buildHeaderStat(
                              'Fuel Tanks',
                              _fuelTanks.length.toString(),
                              Icons.local_gas_station_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Scrollable content area
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Quick Access
                            _buildHeading('Quick Access'),
                            const SizedBox(height: 12),
                            GridView.count(
                              crossAxisCount: 3,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 0.9,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              children: [
                                _buildQuickAccessItem(
                                  'Operations',
                                  Icons.settings_applications,
                                  AppTheme.primaryBlue,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const OperationsScreen()),
                                    );
                                  },
                                ),
                                
                                _buildQuickAccessItem(
                                  'Shifts',
                                  Icons.schedule,
                                  AppTheme.primaryBlue,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const ShiftListScreen()),
                                    );
                                  },
                                ),
                                _buildQuickAccessItem(
                                  'Fuel',
                                  Icons.local_gas_station,
                                  AppTheme.primaryOrange,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const FuelOptionsScreen()),
                                    );
                                  },
                                ),
                                _buildQuickAccessItem(
                                  'Employees',
                                  Icons.people,
                                  Colors.green.shade600,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const EmployeeListScreen()),
                                    );
                                  },
                                ),
                                _buildQuickAccessItem(
                                  'Suppliers',
                                  Icons.business,
                                  Colors.amber.shade700,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const SupplierListScreen()),
                                    );
                                  },
                                ),


                                _buildQuickAccessItem(
                                  'Attendance',
                                  Icons.people_alt_rounded,
                                  Colors.pinkAccent,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const AttendanceScreen()),
                                    );
                                  },
                                ),



                                _buildQuickAccessItem(
                                  'Finance',
                                  Icons.account_balance_wallet,
                                  Colors.indigo.shade600,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const FinanceScreen()),
                                    );
                                  },
                                ),
                                _buildQuickAccessItem(
                                  'Inventory',
                                  Icons.inventory_2,
                                  Colors.teal.shade600,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const InventoryScreen()),
                                    );
                                  },
                                ),
                                _buildQuickAccessItem(
                                  'Sales',
                                  Icons.bar_chart,
                                  Colors.purple.shade600,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const SalesStatisticsScreen()),
                                    );
                                  },
                                ),

                                _buildQuickAccessItem(
                                  'All Readings',
                                  Icons.on_device_training,
                                  Colors.red.shade600,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const AllReadingsScreen()),
                                    );
                                  },
                                ),

                                _buildQuickAccessItem(
                                  'Reports',
                                  Icons.assessment,
                                  Colors.blue,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const ReportsOptionsScreen()),
                                    );
                                  },
                                ),


                                _buildQuickAccessItem(
                                  'Vouchers',
                                  Icons.book,
                                  Colors.pinkAccent,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const VoucherScreen()),
                                    );
                                  },
                                ),

                                _buildQuickAccessItem(
                                  'Customers',
                                  Icons.people_alt_rounded,
                                  Colors.pinkAccent,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const CustomerListScreen()),
                                    );
                                  },
                                ),





                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Only Fuel Levels Chart


                                
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
  
  // Build header stat
  Widget _buildHeaderStat(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha:0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha:0.85),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Build section heading
  Widget _buildHeading(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
  
  // Build quick access item
  Widget _buildQuickAccessItem(String title, IconData icon, Color color, {required Function() onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha:0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              width: 30,
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build a featured/larger quick access item
  Widget _buildFeaturedQuickAccessItem(String title, IconData icon, Color color, {required Function() onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha:0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha:0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 36,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build empty card
  Widget _buildEmptyCard(String message) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ),
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
}