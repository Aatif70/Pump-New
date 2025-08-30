import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:developer' as developer;
import 'dart:math';
import '../../api/dashboard_repository.dart';
import '../../models/inventory_status_model.dart';
import '../../models/consumption_rate_model.dart';
import '../../models/fuel_type_model.dart';
import '../../theme.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  final DashboardRepository _dashboardRepository = DashboardRepository();
  late AnimationController _animationController;
  
  // State variables
  List<InventoryStatus> _inventoryStatus = [];
  List<ConsumptionRate> _consumptionRates = [];
  List<FuelType> _fuelTypes = [];
  Map<String, String> _fuelTypeIdToName = {};
  bool _isLoadingInventory = true;
  bool _isLoadingConsumption = true;
  bool _isLoadingFuelTypes = true;
  String? _inventoryErrorMessage;
  String? _consumptionErrorMessage;
  int _consumptionDays = 30; // Default to 30 days
  
  // Colors
  final Color _primaryColor = AppTheme.primaryBlue;
  final Color _accentColor = AppTheme.primaryOrange;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fetchFuelTypes();
    _fetchInventoryStatus();
    _fetchConsumptionRates();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  // Fetch fuel types
  Future<void> _fetchFuelTypes() async {
    setState(() {
      _isLoadingFuelTypes = true;
    });
    
    try {
      final response = await _dashboardRepository.getFuelTypes();
      
      if (mounted) {
        setState(() {
          _isLoadingFuelTypes = false;
          
          if (response.success && response.data != null) {
            _fuelTypes = response.data!;
            
            // Create a map from fuel type ID to name for quick lookup
            for (var fuelType in _fuelTypes) {
              _fuelTypeIdToName[fuelType.fuelTypeId] = fuelType.name;
            }
            
            developer.log('InventoryScreen: Successfully loaded ${_fuelTypes.length} fuel types');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFuelTypes = false;
        });
        developer.log('InventoryScreen: Error loading fuel types: $e');
      }
    }
  }
  
  // Get fuel type name from ID
  String getFuelTypeName(String fuelTypeId) {
    return _fuelTypeIdToName[fuelTypeId] ?? fuelTypeId;
  }
  
  // Fetch inventory status
  Future<void> _fetchInventoryStatus() async {
    setState(() {
      _isLoadingInventory = true;
      _inventoryErrorMessage = null;
    });
    
    try {
      final response = await _dashboardRepository.getInventoryStatus();
      
      if (mounted) {
        setState(() {
          if (response.success && response.data != null) {
            _inventoryStatus = response.data!;
            _isLoadingInventory = false;
            _animationController.forward(from: 0);
          } else {
            _inventoryErrorMessage = response.errorMessage ?? 'Failed to load inventory status';
            _isLoadingInventory = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _inventoryErrorMessage = 'Error: $e';
          _isLoadingInventory = false;
        });
      }
    }
  }
  
  // Fetch consumption rates
  Future<void> _fetchConsumptionRates() async {
    setState(() {
      _isLoadingConsumption = true;
      _consumptionErrorMessage = null;
    });
    
    try {
      final response = await _dashboardRepository.getConsumptionRates(_consumptionDays);
      
      if (mounted) {
        setState(() {
          if (response.success && response.data != null) {
            _consumptionRates = response.data!;
            _isLoadingConsumption = false;
          } else {
            _consumptionErrorMessage = response.errorMessage ?? 'Failed to load consumption rates';
            _isLoadingConsumption = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _consumptionErrorMessage = 'Error: $e';
          _isLoadingConsumption = false;
        });
      }
    }
  }
  
  Future<void> _changePeriod(int days) async {
    if (_consumptionDays != days) {
      setState(() {
        _consumptionDays = days;
      });
      _fetchConsumptionRates();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Inventory Management',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white,
            onPressed: () {
              _fetchInventoryStatus();
              _fetchConsumptionRates();
            },
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: Column(
        children: [
          // Fixed header section
          _buildHeaderSection(),
          
          // Scrollable content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _fetchInventoryStatus(),
                  _fetchConsumptionRates(),
                ]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Inventory Status', Icons.storage),
                      const SizedBox(height: 12),
                      _isLoadingInventory 
                        ? const Center(child: CircularProgressIndicator())
                        : _inventoryErrorMessage != null 
                          ? _buildErrorWidget(_inventoryErrorMessage!)
                          : _inventoryStatus.isEmpty
                            ? _buildEmptyStateWidget('No inventory data available')
                            : _buildInventoryStatusSection(),
                            
                      const SizedBox(height: 24),
                      
                      // Consumption Rates Section
                      _buildSectionHeader('Consumption Rates', Icons.trending_down),
                      _buildPeriodSelector(),
                      const SizedBox(height: 12),
                      _isLoadingConsumption
                        ? const Center(child: CircularProgressIndicator())
                        : _consumptionErrorMessage != null
                          ? _buildErrorWidget(_consumptionErrorMessage!)
                          : _consumptionRates.isEmpty
                            ? _buildEmptyStateWidget('No consumption data available')
                            : _buildConsumptionRatesSection(),
                            
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
  
  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha:0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Text(
                'Inventory Overview',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Monitor stock levels and consumption patterns',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha:0.9),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.white.withValues(alpha:0.8)),
              const SizedBox(width: 8),
              Text(
                'Last updated: ${DateFormat('dd MMM, yyyy HH:mm').format(DateTime.now())}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha:0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: _primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
  
  Widget _buildErrorWidget(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade800),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyStateWidget(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory, color: Colors.grey, size: 50),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'Period: ',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 8),
            _buildPeriodChip(7, 'Last 7 days'),
            const SizedBox(width: 8),
            _buildPeriodChip(30, 'Last 30 days'),
            const SizedBox(width: 8),
            _buildPeriodChip(90, 'Last 3 months'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPeriodChip(int days, String label) {
    final bool isSelected = _consumptionDays == days;
    
    return GestureDetector(
      onTap: () => _changePeriod(days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey.shade300,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: _primaryColor.withValues(alpha:0.2),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade800,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
  
  Widget _buildInventoryStatusSection() {
    return Column(
      children: [
        for (var inventory in _inventoryStatus)
          _buildInventoryCard(inventory),
      ],
    );
  }
  
  Widget _buildInventoryCard(InventoryStatus inventory) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tank header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(inventory.stockStatusColor).withValues(alpha:0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inventory.tankName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Fuel Type: ${inventory.fuelType}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(inventory.stockStatusColor),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    inventory.stockStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Tank fuel level
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Stock level indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: inventory.stockPercentage / 100,
                    minHeight: 20,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(inventory.stockStatusColor),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Stock stats
                Row(
                  children: [
                    _buildInventoryStatItem(
                      '${NumberFormat.compact().format(inventory.currentStock)} L',
                      'Current Stock',
                      Icons.opacity,
                      Color(inventory.stockStatusColor),
                    ),
                    _buildInventoryStatItem(
                      '${NumberFormat.compact().format(inventory.availableStock)} L',
                      'Available Stock',
                      Icons.local_gas_station,
                      _primaryColor,
                    ),
                    _buildInventoryStatItem(
                      '${NumberFormat.compact().format(inventory.capacityInLiters)} L',
                      'Capacity',
                      Icons.inventory_2,
                      Colors.grey.shade700,
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                
                // Last update info
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 350) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last updated: ${DateFormat('dd MMM, HH:mm').format(inventory.lastUpdatedAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Last delivery: ${DateFormat('dd MMM, yyyy').format(inventory.lastDeliveryDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    } else {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Last updated: ${DateFormat('dd MMM, HH:mm').format(inventory.lastUpdatedAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Last delivery: ${DateFormat('dd MMM, yyyy').format(inventory.lastDeliveryDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    }
                  }
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInventoryStatItem(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildConsumptionRatesSection() {
    return Column(
      children: [
        for (var consumption in _consumptionRates)
          _buildConsumptionCard(consumption),
      ],
    );
  }
  
  Widget _buildConsumptionCard(ConsumptionRate consumption) {
    // Get the fuel type name from the ID
    final fuelTypeName = getFuelTypeName(consumption.fuelTypeId);
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fuel type header with improved UI
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha:0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_gas_station, color: _primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fuel Type: ${consumption.fuelType}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Consumption stats - more responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 320) {
                  // Extremely small screens - stack vertically
                  return Column(
                    children: [
                      _buildConsumptionStatVertical(
                        'Daily Average',
                        '${NumberFormat.compact().format(consumption.averageDailyConsumption)} L',
                        _primaryColor,
                      ),
                      SizedBox(height: 8),
                      _buildConsumptionStatVertical(
                        'Weekday Average',
                        '${NumberFormat.compact().format(consumption.weekdayAverage)} L',
                        Colors.blue.shade700,
                      ),
                      SizedBox(height: 8),
                      _buildConsumptionStatVertical(
                        'Weekend Average',
                        '${NumberFormat.compact().format(consumption.weekendAverage)} L',
                        Colors.purple.shade700,
                      ),
                    ],
                  );
                } else {
                  // Normal layout
                  return Row(
                    children: [
                      _buildConsumptionStat(
                        'Daily Avg',
                        '${NumberFormat.compact().format(consumption.averageDailyConsumption)} L',
                        _primaryColor,
                      ),
                      _buildConsumptionStat(
                        'Weekday',
                        '${NumberFormat.compact().format(consumption.weekdayAverage)} L',
                        Colors.blue.shade700,
                      ),
                      _buildConsumptionStat(
                        'Weekend',
                        '${NumberFormat.compact().format(consumption.weekendAverage)} L',
                        Colors.purple.shade700,
                      ),
                    ],
                  );
                }
              }
            ),
            
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            
            // Peak consumption
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha:0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentColor.withValues(alpha:0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.trending_up,
                    color: _accentColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Peak Consumption',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // For very small screens, show in multiple lines
                            if (constraints.maxWidth < 220) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${NumberFormat.compact().format(consumption.peakDayConsumption)} L',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _accentColor,
                                    ),
                                  ),
                                  Text(
                                    'on ${consumption.peakDay}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    '${consumption.formattedPeakDate}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              return Text(
                                '${NumberFormat.compact().format(consumption.peakDayConsumption)} L on ${consumption.peakDay}, ${consumption.formattedPeakDate}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              );
                            }
                          }
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
    );
  }
  
  // Vertical consumption stat for very small screens
  Widget _buildConsumptionStatVertical(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConsumptionStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
} 