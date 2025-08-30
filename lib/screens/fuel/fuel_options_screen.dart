import 'package:flutter/material.dart';
import '../../theme.dart';
import '../fuel_dispenser/nozzle_management_screen.dart';
import '../fuel_tank/fuel_tank_list_screen.dart';
import '../fuel_tank/add_fuel_tank_screen.dart';
import '../fuel_dispenser/fuel_dispenser_list_screen.dart';
import 'set_fuel_price_screen.dart';
import '../../api/fuel_tank_repository.dart';
import '../../models/fuel_tank_model.dart';
import 'package:fl_chart/fl_chart.dart';
import '../supplier/supplier_list_screen.dart';
import '../fuel_delivery/add_fuel_delivery_screen.dart';
import '../fuel_delivery/fuel_delivery_history_screen.dart';
import '../fuel_delivery/fuel_delivery_order_screen.dart';
import '../quality_check/quality_check_list_screen.dart';
import '../government_testing/government_testing_screen.dart';

class FuelOptionsScreen extends StatefulWidget {
  const FuelOptionsScreen({super.key});

  @override
  State<FuelOptionsScreen> createState() => _FuelOptionsScreenState();
}

class _FuelOptionsScreenState extends State<FuelOptionsScreen> {
  final _fuelTankRepository = FuelTankRepository();
  bool _isLoading = true;
  List<FuelTank> _fuelTanks = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadFuelTanks();
  }

  Future<void> _loadFuelTanks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _fuelTankRepository.getAllFuelTanks();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success && response.data != null) {
            _fuelTanks = response.data!;
          } else {
            _errorMessage = response.errorMessage ?? 'Failed to load fuel tanks';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Fuel Management'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFuelTanks,
            color: Colors.white,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section - fixed at the top
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
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
                      const Text(
                        'Fuel Dashboard',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Monitor and manage your fuel inventory',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Stats cards
                      if (!_isLoading && _fuelTanks.isNotEmpty)
                        Row(
                          children: [
                            _buildHeaderStat(
                              'Total Tanks', 
                              _fuelTanks.length.toString(),
                              Icons.storage_outlined,
                            ),
                            const SizedBox(width: 16),
                            _buildHeaderStat(
                              'Low Stock', 
                              _fuelTanks.where((tank) => tank.isLowStock).length.toString(),
                              Icons.warning_amber_outlined,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                
                // Scrollable content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadFuelTanks,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Chart section
                            if (!_isLoading && _fuelTanks.isNotEmpty) ...[

                              const SizedBox(height: 12),
                              Container(
                                height: 220,
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
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: _buildFuelStockChart(),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // // Fuel types distribution pie chart
                              // _buildSectionHeader('Fuel Types Distribution'),
                              // const SizedBox(height: 12),
                              // Container(
                              //   height: 220,
                              //   decoration: BoxDecoration(
                              //     color: Colors.white,
                              //     borderRadius: BorderRadius.circular(16),
                              //     boxShadow: [
                              //       BoxShadow(
                              //         color: Colors.black.withValues(alpha:0.05),
                              //         blurRadius: 10,
                              //         spreadRadius: 0,
                              //         offset: const Offset(0, 2),
                              //       ),
                              //     ],
                              //   ),
                              //   child: Padding(
                              //     padding: const EdgeInsets.all(16.0),
                              //     child: _buildFuelTypeDistributionChart(),
                              //   ),
                              // ),
                              
                              // const SizedBox(height: 12),
                            ],
                            
                            // Loading or error message
                            if (_errorMessage.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.red.shade700),
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
                            
                            // Tank Management section
                            _buildSectionHeader('Tank Management'),
                            const SizedBox(height: 12),
                            
                            // Convert horizontal scrollable cards to a grid layout
                            GridView.count(
                              crossAxisCount: 3,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 0.9,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              children: [
                                _buildGridActionCard(
                                  'View Tanks',
                                  Icons.inventory,
                                  AppTheme.primaryBlue,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const FuelTankListScreen()),
                                  ),
                                ),

                                _buildGridActionCard(
                                  'Quality Check',
                                  Icons.science,
                                  Colors.deepPurple.shade600,
                                      () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const QualityCheckListScreen()),
                                  ),
                                ),

                                _buildGridActionCard(
                                  'Add Tank',
                                  Icons.add_circle,
                                  Colors.green.shade600,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const AddFuelTankScreen()),
                                  ),
                                ),
                                _buildGridActionCard(
                                  'Dispensers',
                                  Icons.local_gas_station,
                                  Colors.purple.shade700,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const FuelDispenserListScreen()),
                                  ),
                                ),
                                _buildGridActionCard(
                                  'Nozzles',
                                  Icons.local_gas_station_outlined,
                                  AppTheme.primaryOrange,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const NozzleManagementScreen()),
                                  ),
                                ),
                                _buildGridActionCard(
                                  'Set Prices',
                                  Icons.attach_money,
                                  Colors.indigo.shade600,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SetFuelPriceScreen()),
                                  ),
                                ),

                                                                _buildGridActionCard(
                                  'Govt.Testing',
                                  Icons.pan_tool_alt_sharp,
                                  Colors.indigo.shade600,
                                      () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const GovernmentTestingScreen()),
                                  ),
                                ),


                                _buildGridActionCard(
                                  'Suppliers',
                                  Icons.business,
                                  Colors.amber.shade700,
                                      () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SupplierListScreen()),
                                  ),
                                ),


                              ],
                            ),
                            
                            const SizedBox(height: 24),

                            // Delivery Management section
                            _buildSectionHeader('Delivery Management'),
                            const SizedBox(height: 12),

                            GridView.count(
                              crossAxisCount: 3,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 0.9,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              children: [

                                _buildGridActionCard(
                                  'Delivery Order',
                                  Icons.receipt_long,
                                  Colors.teal.shade600,
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const FuelDeliveryOrderScreen()),
                                  ),
                                ),

                                _buildGridActionCard(
                                  'Delivery History',
                                  Icons.history,
                                  Colors.teal.shade600,
                                      () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const FuelDeliveryHistoryScreen()),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
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
  
  // Build section header
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
  
  // Build header stat card
  Widget _buildHeaderStat(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Add the new grid action card builder
  Widget _buildGridActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha:0.1),
              blurRadius: 5,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Fuel stock bar chart
  Widget _buildFuelStockChart() {
    if (_fuelTanks.isEmpty) {
      return const Center(child: Text('No fuel tank data available'));
    }
    
    // Sort tanks by fuel type
    final sortedTanks = List<FuelTank>.from(_fuelTanks)
      ..sort((a, b) => a.fuelType.compareTo(b.fuelType));
    
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100, // Percentage scale
                gridData: const FlGridData(
                  show: true,
                  horizontalInterval: 20,
                  drawVerticalLine: false,
                ),
                titlesData: const FlTitlesData(
                  show: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  sortedTanks.length > 5 ? 5 : sortedTanks.length, // Limit to 5 tanks for readability
                  (index) {
                    final tank = sortedTanks[index];
                    final color = _getColorForFuelType(tank.fuelType);
                    
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: tank.stockPercentage,
                          color: color,
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: 100,
                            color: color.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                      barsSpace: 4,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        
        // Fuel type labels
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: sortedTanks.take(5).map((tank) {
            final color = _getColorForFuelType(tank.fuelType);
            return Row(
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
                const SizedBox(width: 4),
                Text(
                  '${tank.fuelType}: ${tank.stockPercentage.toInt()}%',
                  style: const TextStyle(fontSize: 10),
                ),
                const SizedBox(width: 8),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
  

  
  // Helper method to get color for fuel type
  Color _getColorForFuelType(String fuelType) {
    switch(fuelType.toLowerCase()) {
      case 'petrol':
        return Colors.green.shade700;
      case 'diesel':
        return Colors.blue.shade700;
      case 'premium petrol':
        return Colors.purple.shade700;
      case 'cng':
        return Colors.teal.shade700;
      case 'lpg':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}


