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
import '../booklet/booklet_list_screen.dart';
import '../voucher/voucher_screen.dart';
import '../vehicle_transaction/vehicle_transaction_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State createState() => _HomeScreenState();
}

class _HomeScreenState extends State with SingleTickerProviderStateMixin {
  final String username = "Admin";

  // Repositories
  final _employeeRepository = EmployeeRepository();
  final _fuelTankRepository = FuelTankRepository();
  final _currentUserRepository = CurrentUserRepository();

  // Data for charts
  List _employees = [];
  List _fuelTanks = [];
  CurrentUser? _currentUser;
  bool _isLoading = true;
  String _errorMessage = '';

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final employeeResponse = await _employeeRepository.getAllEmployees();
      final fuelTankResponse = await _fuelTankRepository.getAllFuelTanks();
      final currentUserResponse = await _currentUserRepository.getCurrentUser();

      if (!mounted) return;

      if (employeeResponse.success && fuelTankResponse.success && currentUserResponse.success) {
        setState(() {
          _employees = employeeResponse.data ?? [];
          _fuelTanks = fuelTankResponse.data ?? [];
          _currentUser = currentUserResponse.data;
          _isLoading = false;
        });

        _animationController.reset();
        _animationController.forward();
      } else {
        setState(() {
          _errorMessage = 'Failed to load data';
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

  Future _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.authTokenKey);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Control Center',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.refresh_rounded, size: 20),
              ),
              color: Colors.white,
              onPressed: _loadData,
              tooltip: 'Refresh data',
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(strokeWidth: 3),
      )
          : FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              // Compact Header with Key Metrics
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    // User Welcome Row
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentUser?.fullName ?? username,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Station Operations',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Online',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Quick Stats Row
                    Row(
                      children: [
                        _buildQuickStat('Tanks', _fuelTanks.length.toString(),
                            Icons.local_gas_station_rounded, Colors.orange.shade600),
                        _buildQuickStat('Staff', _employees.length.toString(),
                            Icons.people_rounded, Colors.green.shade600),

                      ],
                    ),
                  ],
                ),
              ),

              // Main Content Area
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick Actions
                        _buildSectionTitle('Quick Actions', Icons.flash_on_rounded),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                'Daily Ops',
                                Icons.settings_applications_rounded,
                                AppTheme.primaryBlue,
                                    () => Navigator.push(context, MaterialPageRoute(
                                    builder: (context) => const OperationsScreen())),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildActionButton(
                                'Shifts',
                                Icons.access_time_rounded,
                                Colors.indigo.shade600,
                                    () => Navigator.push(context, MaterialPageRoute(
                                    builder: (context) => const ShiftListScreen())),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildActionButton(
                                'Readings',
                                Icons.speed_rounded,
                                Colors.red.shade600,
                                    () => Navigator.push(context, MaterialPageRoute(
                                    builder: (context) => const AllReadingsScreen())),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Fuel Management
                        _buildSectionTitle('Fuel Management', Icons.local_gas_station_rounded),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          children: [
                            _buildCompactCard('Fuel Types', Icons.local_gas_station,
                                AppTheme.primaryOrange, () => Navigator.push(context,
                                    MaterialPageRoute(builder: (context) => const FuelOptionsScreen()))),
                            _buildCompactCard('Inventory', Icons.inventory_2_rounded,
                                Colors.teal.shade600, () => Navigator.push(context,
                                    MaterialPageRoute(builder: (context) => const InventoryScreen()))),
                            _buildCompactCard('Suppliers', Icons.local_shipping_rounded,
                                Colors.amber.shade700, () => Navigator.push(context,
                                    MaterialPageRoute(builder: (context) => const SupplierListScreen()))),
                          ],
                        ),
                        // const SizedBox(height: 12),

                        // Staff & Operations
                        _buildSectionTitle('Staff & Operations', Icons.people_rounded),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          children: [
                            _buildCompactCard('Employees', Icons.badge_rounded,
                                Colors.green.shade600, () => Navigator.push(context,
                                    MaterialPageRoute(builder: (context) => const EmployeeListScreen()))),
                            _buildCompactCard('Attendance', Icons.how_to_reg_rounded,
                                Colors.purple.shade600, () => Navigator.push(context,
                                    MaterialPageRoute(builder: (context) => const AttendanceScreen()))),
                            _buildCompactCard('Customers', Icons.people_alt_rounded,
                                Colors.blue.shade600, () => Navigator.push(context,
                                    MaterialPageRoute(builder: (context) => const CustomerListScreen()))),
                          ],
                        ),


                        // Financial Management
                        _buildSectionTitle('Financial Management', Icons.account_balance_wallet_rounded),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          children: [
                            _buildCompactCard('Finance', Icons.account_balance_rounded,
                                Colors.indigo.shade600, () => Navigator.push(context,
                                    MaterialPageRoute(builder: (context) => const FinanceScreen()))),
                            _buildCompactCard('Sales Data', Icons.analytics_rounded,
                                Colors.purple.shade600, () => Navigator.push(context,
                                    MaterialPageRoute(builder: (context) => const SalesStatisticsScreen()))),
                            _buildCompactCard('Reports', Icons.assessment_rounded,
                                Colors.blue.shade600, () => Navigator.push(context,
                                    MaterialPageRoute(builder: (context) => const ReportsOptionsScreen()))),
                            _buildCompactCard('Vouchers', Icons.confirmation_number_rounded,
                                Colors.pink.shade600, () => Navigator.push(context,
                                    MaterialPageRoute(builder: (context) => const VoucherScreen()))),
                            _buildCompactCard('Booklets', Icons.menu_book_rounded,
                                Colors.orange.shade600, () => Navigator.push(context,
                                    MaterialPageRoute(builder: (context) => const BookletListScreen()))),
                            _buildCompactCard('Vehicle Transactions', Icons.directions_car_rounded,
                                Colors.indigo.shade600, () => Navigator.push(context,
                                    MaterialPageRoute(builder: (context) => const VehicleTransactionListScreen()))),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build quick stat widget
  Widget _buildQuickStat(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build section title
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryBlue,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  // Build action button (larger for priority actions)
  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Build compact card (smaller cards for better space utilization)
  Widget _buildCompactCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Build drawer with compact design to prevent overflow
  Widget _buildDrawer() {
    return Drawer(
      elevation: 2,
      width: MediaQuery.of(context).size.width * 0.75,
      child: Column(
        children: [
          // Compact header
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryBlue,
                  AppTheme.primaryBlue.withValues(alpha: 0.8),
                ],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 24,
                      child: Text(
                        _currentUser?.fullName.isNotEmpty == true
                            ? _currentUser!.fullName.substring(0, 1)
                            : username.substring(0, 1),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentUser?.fullName ?? username,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _currentUser?.role ?? 'Admin',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Online',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Navigation items
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 8),
                  _buildDrawerSection('Navigation'),
                  _buildDrawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    onTap: () => Navigator.pop(context),
                    isSelected: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.account_circle_rounded,
                    title: 'Profile',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const ProfileScreen()));
                    },
                  ),
                  _buildDrawerSection('Management'),
                  _buildDrawerItem(
                    icon: Icons.schedule_rounded,
                    title: 'Shifts',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const ShiftListScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.local_gas_station_rounded,
                    title: 'Fuel Tanks',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const FuelTankListScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.people_rounded,
                    title: 'Employees',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const EmployeeListScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.business_rounded,
                    title: 'Suppliers',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const SupplierListScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.people_alt_rounded,
                    title: 'Customers',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const CustomerListScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.book_rounded,
                    title: 'Booklets',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const BookletListScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.directions_car_rounded,
                    title: 'Vehicle Transactions',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const VehicleTransactionListScreen()));
                    },
                  ),
                  _buildDrawerSection('Operations'),
                  _buildDrawerItem(
                    icon: Icons.settings_applications_rounded,
                    title: 'Daily Operations',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const OperationsScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.local_shipping_rounded,
                    title: 'Fuel Deliveries',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const FuelDeliveryHistoryScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.inventory_2_rounded,
                    title: 'Inventory',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const InventoryScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.on_device_training_rounded,
                    title: 'All Readings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const AllReadingsScreen()));
                    },
                  ),
                  _buildDrawerSection('Finance'),
                  _buildDrawerItem(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Finance',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const FinanceScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.bar_chart_rounded,
                    title: 'Sales Statistics',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const SalesStatisticsScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.assessment_rounded,
                    title: 'Reports',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const ReportsOptionsScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.receipt_long_rounded,
                    title: 'Vouchers',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const VoucherScreen()));
                    },
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildDrawerItem(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    onTap: _logout,
                    color: Colors.red.shade600,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: Colors.grey.shade300,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
    bool isSelected = false,
  }) {
    final itemColor = color ?? (isSelected ? AppTheme.primaryBlue : Colors.grey.shade700);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        horizontalTitleGap: 6,
        minLeadingWidth: 20,
        leading: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isSelected 
                ? AppTheme.primaryBlue.withValues(alpha: 0.15)
                : itemColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon, 
            color: itemColor, 
            size: 16,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: itemColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
    );
  }
}
