import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/fuel_tank_repository.dart';
import '../../models/fuel_tank_model.dart';
import '../../models/fuel_quality_check_model.dart';
import '../../theme.dart';
import '../../screens/quality_check/quality_check_list_screen.dart';
import '../fuel_delivery/add_fuel_delivery_screen.dart';
import 'add_fuel_tank_screen.dart';
import 'edit_fuel_tank_screen.dart';
import 'refill_fuel_tank_screen.dart';


class FuelTankListScreen extends StatefulWidget {
  const FuelTankListScreen({super.key});

  @override
  State<FuelTankListScreen> createState() => _FuelTankListScreenState();
}

class _FuelTankListScreenState extends State<FuelTankListScreen> with TickerProviderStateMixin {
  final FuelTankRepository _repository = FuelTankRepository();
  List<FuelTank> _fuelTanks = [];
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Animation controller for fuel tank filling
  late AnimationController _fillAnimationController;
  late Animation<double> _fillAnimation;
  bool _isAnimatingFill = false;
  
  // Filters
  String? _selectedFuelType;
  String? _selectedStatus;
  final List<String?> _fuelTypeOptions = [null, 'Petrol', 'Diesel', 'CNG', 'Premium Petrol', 'Premium Diesel', 'LPG'];
  final List<String?> _statusOptions = [null, 'Active', 'Maintenance', 'Inactive'];
  
  int get _activeFilterCount => 
      (_selectedFuelType != null ? 1 : 0) + 
      (_selectedStatus != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    print('FUEL_TANK_LIST: Initializing Fuel Tank List Screen');
    
    // Initialize animation controller
    _fillAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _fillAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fillAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _fillAnimationController.addListener(() {
      setState(() {}); // Rebuild on animation tick
    });
    
    _loadFuelTanks();
  }
  
  @override
  void dispose() {
    _fillAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadFuelTanks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    print('FUEL_TANK_LIST: Loading fuel tanks from repository');
    try {
      final response = await _repository.getAllFuelTanks();

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success && response.data != null) {
            _fuelTanks = response.data!;
            print('FUEL_TANK_LIST: Successfully loaded ${_fuelTanks.length} fuel tanks');
            
            // Start fill animation when data is loaded
            _startFillAnimation();
          } else {
            _errorMessage = response.errorMessage ?? 'Failed to load fuel tanks';
            print('FUEL_TANK_LIST: Error loading fuel tanks: $_errorMessage');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
          print('FUEL_TANK_LIST: Exception loading fuel tanks: $e');
        });
      }
    }
  }
  
  void _startFillAnimation() {
    setState(() {
      _isAnimatingFill = true;
    });
    
    // Reset animation controller
    _fillAnimationController.reset();
    
    // Start animation
    _fillAnimationController.forward().then((_) {
      setState(() {
        _isAnimatingFill = false;
      });
    });
  }

  void _navigateToAddFuelTank() async {
    print('FUEL_TANK_LIST: Navigating to Add Fuel Tank screen');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddFuelTankScreen()),
    );
    
    // Refresh the list regardless of the result to ensure we have the latest data
    _loadFuelTanks();
  }
  
  void _navigateToEditFuelTank(FuelTank tank) async {
    print('FUEL_TANK_LIST: Navigating to Edit Fuel Tank screen for ID=${tank.fuelTankId}');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditFuelTankScreen(fuelTank: tank)),
    );
    
    // Refresh the list if successful edit
    if (result == true) {
      _loadFuelTanks();
    }
  }

  void _navigateToRefillFuelTank(FuelTank tank) async {
    print('FUEL_TANK_LIST: Navigating to Refill Fuel Tank screen for ID=${tank.fuelTankId}');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RefillFuelTankScreen(fuelTank: tank)),
    );
    
    // Refresh the list if successful refill
    if (result == true) {
      _loadFuelTanks();
    }
  }
  
  void _navigateToAddFuelDelivery(FuelTank tank) async {
    print('FUEL_TANK_LIST: Navigating to Add Fuel Delivery screen for ID=${tank.fuelTankId}');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddFuelDeliveryScreen(fuelTank: tank)),
    );
    
    // Refresh the list if successful fuel delivery added
    if (result == true) {
      _loadFuelTanks();
    }
  }
  
  void _navigateToQualityCheck(FuelTank tank) async {
    print('FUEL_TANK_LIST: Navigating to Quality Check List screen');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QualityCheckListScreen()),
    );
  }
  
  void _deleteFuelTank(FuelTank tank) async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Fuel Tank'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete the ${tank.fuelType} tank?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. All data related to this tank will be permanently deleted.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!shouldDelete) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await _repository.deleteFuelTank(tank.fuelTankId!);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fuel tank deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadFuelTanks();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete fuel tank: ${response.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Filter the fuel tanks based on selected criteria
  List<FuelTank> get _filteredFuelTanks {
    return _fuelTanks.where((tank) {
      final matchesFuelType = _selectedFuelType == null || tank.fuelType == _selectedFuelType;
      final matchesStatus = _selectedStatus == null || tank.status == _selectedStatus;
      return matchesFuelType && matchesStatus;
    }).toList();
  }
  
  // Show filter dialog
  void _showFilterDialog() {
    // Store temp values for filters
    String? tempFuelType = _selectedFuelType;
    String? tempStatus = _selectedStatus;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter Fuel Tanks'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fuel type filter
                  const Text(
                    'Fuel Type',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _fuelTypeOptions.map((type) {
                      final isSelected = tempFuelType == type;
                      final displayText = type ?? 'All';
                      
                      return ChoiceChip(
                        label: Text(displayText),
                        selected: isSelected,
                        onSelected: (_) {
                          setDialogState(() {
                            tempFuelType = (type == tempFuelType) ? null : type;
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: AppTheme.primaryBlue.withValues(alpha:0.7),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Status filter
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _statusOptions.map((status) {
                      final isSelected = tempStatus == status;
                      final displayText = status ?? 'All';
                      
                      // Determine color based on status
                      Color statusColor;
                      if (status == 'Active') {
                        statusColor = Colors.green;
                      } else if (status == 'Maintenance') {
                        statusColor = Colors.orange;
                      } else if (status == 'Inactive') {
                        statusColor = Colors.red;
                      } else {
                        statusColor = AppTheme.primaryBlue;
                      }
                      
                      return ChoiceChip(
                        label: Text(displayText),
                        selected: isSelected,
                        onSelected: (_) {
                          setDialogState(() {
                            tempStatus = (status == tempStatus) ? null : status;
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: isSelected ? statusColor.withValues(alpha:0.7) : null,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              // Reset filters button
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    tempFuelType = null;
                    tempStatus = null;
                  });
                },
                child: const Text('Reset'),
              ),
              // Cancel button
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              // Apply button
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedFuelType = tempFuelType;
                    _selectedStatus = tempStatus;
                  });
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTanks = _filteredFuelTanks;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Fuel Tanks'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          // Filter button
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter',
                onPressed: _showFilterDialog,
                color: Colors.white,
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _activeFilterCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadFuelTanks,
            color: Colors.white,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFuelTanks,
              child: Column(
                children: [
                  // Header section with stats - modern card-based design
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
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
                        // Title
                        // Stats cards in a row
                        Row(
                          children: [
                            _buildModernStatCard(
                              'Total Tanks',
                              _fuelTanks.length.toString(),
                              Icons.storage_rounded,
                              Colors.white,
                            ),
                            const SizedBox(width: 12),
                            _buildModernStatCard(
                              'Active',
                              _fuelTanks.where((t) => t.status == 'Active').length.toString(),
                              Icons.check_circle_outline,
                              Colors.greenAccent.shade100,
                            ),
                            const SizedBox(width: 12),
                            _buildModernStatCard(
                              'Low Stock',
                              _fuelTanks.where((t) => t.isLowStock).length.toString(),
                              Icons.warning_amber_rounded,
                              Colors.amberAccent.shade100,
                              isAlert: _fuelTanks.where((t) => t.isLowStock).isNotEmpty,


                            ),
                          ],

                        ),
                      ],
                    ),
                  ),
                  
                  // Active filters display with improved styling
                  if (_activeFilterCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      margin: const EdgeInsets.only(top: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha:0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.filter_alt_outlined,
                            color: Colors.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Filters: ',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (_selectedFuelType != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Chip(
                                label: Text(_selectedFuelType!),
                                labelStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                                backgroundColor: _getColorForFuelType(_selectedFuelType!),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                deleteIcon: const Icon(Icons.clear, size: 14, color: Colors.white),
                                onDeleted: () {
                                  setState(() {
                                    _selectedFuelType = null;
                                  });
                                },
                              ),
                            ),
                          if (_selectedStatus != null)
                            Chip(
                              label: Text(_selectedStatus!),
                              labelStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                              backgroundColor: _getStatusColor(_selectedStatus!),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              deleteIcon: const Icon(Icons.clear, size: 14, color: Colors.white),
                              onDeleted: () {
                                setState(() {
                                  _selectedStatus = null;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  
                  // Filter info text with improved styling
                  if (_fuelTanks.isNotEmpty && filteredTanks.length != _fuelTanks.length)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueGrey.shade100),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.blueGrey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Showing ${filteredTanks.length} of ${_fuelTanks.length} fuel tanks',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blueGrey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Error, empty view, or fuel tanks list
                  _errorMessage.isNotEmpty && filteredTanks.isEmpty
                      ? _buildErrorView()
                      : filteredTanks.isEmpty
                          ? _buildEmptyView()
                          : Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16.0),
                                itemCount: filteredTanks.length,
                                itemBuilder: (context, index) {
                                  final fuelTank = filteredTanks[index];
                                  return _buildFuelTankCard(fuelTank);
                                },
                              ),
                            ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddFuelTank,
        backgroundColor: AppTheme.primaryBlue,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
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

  Widget _buildErrorView() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadFuelTanks,
                style: AppTheme.primaryButtonStyle,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_gas_station,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _fuelTanks.isEmpty
                  ? 'No fuel tanks available'
                  : 'No fuel tanks match your filters',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _fuelTanks.isEmpty
                  ? 'Add your first fuel tank by clicking the + button'
                  : 'Try changing or clearing your filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            if (_fuelTanks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: ElevatedButton.icon(
                  onPressed: _navigateToAddFuelTank,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Fuel Tank'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelTankCard(FuelTank tank) {
    // Determine color based on fuel type
    final color = _getColorForFuelType(tank.fuelType);
    
    // Determine icon and color for status
    final statusIcon = _getStatusIcon(tank.status);
    final statusColor = _getStatusColor(tank.status);
    
    return Dismissible(
      key: Key(tank.fuelTankId ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Fuel Tank'),
            content: Text('Are you sure you want to delete the ${tank.fuelType} tank?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        _deleteFuelTank(tank);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16.0),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha:0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () => _showFuelTankDetails(tank),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tank header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha:0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha:0.2),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.local_gas_station,
                            color: color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          tank.fuelType,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    // Status indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            statusIcon,
                            color: statusColor,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tank.status,
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
              ),
              
              // Tank body with improved layout
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stock visualization with improved styling
                    Column(
                      children: [
                        _buildModernFuelTankVisual(tank),
                        if (tank.isLowStock)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.amber,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Low',
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    
                    // Redesigned metrics section for better scanability
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Critical metrics displayed in grid format
                          Row(
                            children: [
                              // Capacity metric
                              Expanded(
                                child: _buildMetricBox(
                                  'Capacity',
                                  '${tank.capacityInLiters.toStringAsFixed(0)}',
                                  'L',
                                  Icons.straighten,
                                  Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Current stock metric
                              Expanded(
                                child: _buildMetricBox(
                                  'Current',
                                  '${tank.currentStock.toStringAsFixed(0)}',
                                  'L',
                                  Icons.opacity,
                                  tank.isLowStock ? Colors.red : Colors.green.shade700,
                                  isAlert: tank.isLowStock,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Stock percentage with progress bar
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.percent,
                                          size: 14,
                                          color: _getColorForPercentage(tank.stockPercentage),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Stock Level',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${tank.stockPercentage.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: _getColorForPercentage(tank.stockPercentage),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: tank.stockPercentage / 100,
                                    backgroundColor: Colors.grey.shade200,
                                    color: _getColorForPercentage(tank.stockPercentage),
                                    minHeight: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Last refill info - less prominence but still visible
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Last Refill:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  tank.formattedLastRefilled,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
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
              
              // Card actions with improved styling
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // const SizedBox(width: 8),
                    // _buildActionButton(
                    //   Icons.add,
                    //   'Refill',
                    //   Colors.green,
                    //   () => _navigateToRefillFuelTank(tank),
                    // ),
                    // const SizedBox(width: 8),
                    // _buildActionButton(
                    //   Icons.edit,
                    //   'Edit',
                    //   AppTheme.primaryBlue,
                    //   () => _navigateToEditFuelTank(tank),
                    // ),

                    // const SizedBox(width: 8),
                    // _buildActionButton(
                    //   Icons.add,
                    //   'Refill',
                    //   Colors.green,
                    //       () => _navigateToRefillFuelTank(tank),
                    // ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      Icons.edit,
                      'Update status',
                      AppTheme.primaryBlue,
                          () => _navigateToEditFuelTank(tank),
                    ),
                    const SizedBox(width: 8),
                    // _buildActionButton(
                    //   Icons.local_shipping,
                    //   'Fuel Delivery',
                    //   Colors.amber.shade700,
                    //       () => _navigateToAddFuelDelivery(tank),
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Build modern action button
  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return TextButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: onPressed,
    );
  }
  
  // Build modern fuel tank visualization
  Widget _buildModernFuelTankVisual(FuelTank tank) {
    // Animated percentage - starting from 0 and going to the actual percentage
    final animatedPercentage = _isAnimatingFill 
        ? tank.stockPercentage * _fillAnimation.value 
        : tank.stockPercentage;
    
    final fillColor = _getColorForPercentage(animatedPercentage);
    final emptyPercentage = 100 - animatedPercentage;
    
    return Container(
      width: 50,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.1),
            blurRadius: 2,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Empty space
          Expanded(
            flex: emptyPercentage.round(),
            child: Container(
              width: double.infinity,
              color: Colors.transparent,
            ),
          ),
          // Filled space
          Expanded(
            flex: animatedPercentage.round() == 0 ? 1 : animatedPercentage.round(),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.vertical(
                  bottom: const Radius.circular(10),
                  top: emptyPercentage <= 0
                      ? const Radius.circular(10)
                      : Radius.zero,
                ),
                boxShadow: [
                  BoxShadow(
                    color: fillColor.withValues(alpha:0.3),
                    blurRadius: 4,
                    spreadRadius: 0,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // New helper method to build metric boxes with improved scanability
  Widget _buildMetricBox(String label, String value, String unit, IconData icon, Color color, {bool isAlert = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAlert ? color.withValues(alpha:0.5) : color.withValues(alpha:0.2),
          width: isAlert ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label with icon
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Value with unit
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Fetch quality checks for a specific tank
  Future<List<FuelQualityCheck>> _loadQualityChecks(String fuelTankId) async {
    try {
      final response = await _repository.getFuelQualityChecksByTank(fuelTankId);
      if (response.success && response.data != null) {
        return response.data!;
      } else {
        print('FUEL_TANK_LIST: Failed to load quality checks: ${response.errorMessage}');
        return [];
      }
    } catch (e) {
      print('FUEL_TANK_LIST: Error loading quality checks: $e');
      return [];
    }
  }

  // Completely redesign the tank details drawer for better UX
  void _showFuelTankDetails(FuelTank tank) async {
    print('FUEL_TANK_LIST: Showing fuel tank details for ID=${tank.fuelTankId}');
    final fuelColor = _getColorForFuelType(tank.fuelType);
    final levelColor = _getColorForPercentage(tank.stockPercentage);
    final statusColor = _getStatusColor(tank.status);
    
    // Start loading quality checks
    final qualityChecksFuture = _loadQualityChecks(tank.fuelTankId!);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7, // Increased to show more content
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
                        // Title with status badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.local_gas_station,
                                  color: fuelColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${tank.fuelType} Tank',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                                    _getStatusIcon(tank.status),
                                    color: statusColor,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tank.status,
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
                        // Tank visualization card
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black.withValues(alpha:0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tank visualization
                                _buildDetailFuelTankVisual(tank),
                                
                                const SizedBox(width: 20),
                                
                                // Key stats
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current Level',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Progress bar
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: tank.stockPercentage / 100,
                                          backgroundColor: Colors.grey.shade200,
                                          color: levelColor,
                                          minHeight: 8,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${tank.stockPercentage.toStringAsFixed(1)}%',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: levelColor,
                                            ),
                                          ),
                                          if (tank.isLowStock)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.red.shade200),
                                              ),
                                              child: Text(
                                                'LOW STOCK',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red.shade800,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 16),
                                      
                                      // Stats grid
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildStatBox(
                                              'Current',
                                              '${tank.currentStock.toStringAsFixed(0)} L',
                                              fuelColor,
                                              Icons.opacity,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildStatBox(
                                              'Capacity',
                                              '${tank.capacityInLiters.toStringAsFixed(0)} L',
                                              Colors.blue.shade700,
                                              Icons.straighten,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildStatBox(
                                              'Left',
                                              '${tank.remainingCapacity.toStringAsFixed(0)} L',
                                              Colors.teal.shade700,
                                              Icons.ac_unit_sharp,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildStatBox(
                                              'Last Refill',
                                              tank.lastRefilledAt != null
                                                  ? DateFormat('dd/MM/yy').format(tank.lastRefilledAt!)
                                                  : 'Never',
                                              Colors.purple.shade700,
                                              Icons.event,
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
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Quality Check Section
                        FutureBuilder<List<FuelQualityCheck>>(
                          future: qualityChecksFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Card(
                                elevation: 2,
                                shadowColor: Colors.black.withValues(alpha:0.1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              );
                            }
                            
                            final qualityChecks = snapshot.data ?? [];
                            
                            if (qualityChecks.isEmpty) {
                              return Card(
                                elevation: 2,
                                shadowColor: Colors.black.withValues(alpha:0.1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.science,
                                            color: Colors.purple.shade700,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Quality Check',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Center(
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.science_outlined,
                                              color: Colors.grey.shade400,
                                              size: 48,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Tap the Quality Check button to perform the first check',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
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
                            
                            // Sort checks by date, most recent first
                            qualityChecks.sort((a, b) => 
                              (b.checkedAt ?? DateTime(1900)).compareTo(a.checkedAt ?? DateTime(1900))
                            );
                            
                            // Most recent quality check
                            final latestCheck = qualityChecks.first;
                            final qualityColor = latestCheck.getQualityStatusColor();
                            
                            return Card(
                              elevation: 2,
                              shadowColor: Colors.black.withValues(alpha:0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header with latest check status
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: qualityColor.withValues(alpha:0.1),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: qualityColor.withValues(alpha:0.2),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            latestCheck.getQualityStatusIcon(),
                                            color: qualityColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Quality: ${latestCheck.qualityStatus}',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: qualityColor,
                                                    ),
                                                  ),
                                                  Text(
                                                    latestCheck.formattedCheckedDate,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Checked by: ${latestCheck.checkedByName}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Quality parameters
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.science,
                                              color: Colors.purple.shade700,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Quality Parameters',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        
                                        // Parameters grid
                                        Row(
                                          children: [
                                            _buildQualityParameterBox(
                                              'Density',
                                              '${latestCheck.density.toStringAsFixed(3)} kg/m³',
                                              Icons.science_outlined,
                                              Colors.indigo,
                                            ),
                                            const SizedBox(width: 12),
                                            _buildQualityParameterBox(
                                              'Temperature',
                                              '${latestCheck.temperature.toStringAsFixed(1)} °C',
                                              Icons.thermostat,
                                              Colors.orange,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            _buildQualityParameterBox(
                                              'Water Content',
                                              '${latestCheck.waterContent.toStringAsFixed(1)}%',
                                              Icons.opacity,
                                              Colors.blue,
                                            ),
                                            const SizedBox(width: 12),
                                            _buildQualityParameterBox(
                                              'Last Check',
                                              latestCheck.formattedCheckedAt,
                                              Icons.update,
                                              Colors.teal,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // History button
                                  if (qualityChecks.length > 1)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      child: OutlinedButton(
                                        onPressed: () {
                                          // Show history dialog
                                          _showQualityCheckHistory(context, qualityChecks);
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.purple.shade700,
                                          side: BorderSide(color: Colors.purple.shade700),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.history, size: 16, color: Colors.purple.shade700),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Quality Check History (${qualityChecks.length})',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Tank details section
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black.withValues(alpha:0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tank Information',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                _buildDetailInfoRow(
                                  'Fuel Type',
                                  tank.fuelType,
                                  Icons.local_gas_station,
                                  fuelColor,
                                ),
                                const Divider(height: 24),
                                _buildDetailInfoRow(
                                  'Status',
                                  tank.status,
                                  _getStatusIcon(tank.status),
                                  statusColor,
                                ),
                                const Divider(height: 24),
                                _buildDetailInfoRow(
                                  'Last Refilled',
                                  tank.formattedLastRefilled,
                                  Icons.history,
                                  Colors.indigo.shade700,
                                ),
                                const Divider(height: 24),
                                _buildDetailInfoRow(
                                  'Created At',
                                  tank.formattedCreatedAt,
                                  Icons.date_range,
                                  Colors.brown.shade700,
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // // Action buttons
                        // Row(
                        //   children: [
                        //     Expanded(
                        //       child: OutlinedButton.icon(
                        //         onPressed: () {
                        //           Navigator.pop(context);
                        //           _navigateToEditFuelTank(tank);
                        //         },
                        //         icon: const Icon(Icons.edit),
                        //         label: const Text('EDIT'),
                        //         style: OutlinedButton.styleFrom(
                        //           foregroundColor: AppTheme.primaryBlue,
                        //           padding: const EdgeInsets.symmetric(vertical: 14),
                        //           side: const BorderSide(color: AppTheme.primaryBlue),
                        //           shape: RoundedRectangleBorder(
                        //             borderRadius: BorderRadius.circular(12),
                        //           ),
                        //         ),
                        //       ),
                        //     ),
                        //     const SizedBox(width: 12),
                        //
                        //   ],
                        // ),
                        //
                        //
                        // const SizedBox(height: 12),
                        //
                        // Delete button
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteFuelTank(tank);
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('DELETE TANK'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
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
  
  // Shows quality check history dialog
  void _showQualityCheckHistory(BuildContext context, List<FuelQualityCheck> checks) {
    // Sort checks by date, most recent first
    checks.sort((a, b) => 
      (b.checkedAt ?? DateTime(1900)).compareTo(a.checkedAt ?? DateTime(1900))
    );
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, color: Colors.purple.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Quality  History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${checks.length} records',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: checks.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) => _buildHistoryItem(checks[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build history item
  Widget _buildHistoryItem(FuelQualityCheck check) {
    final statusColor = check.getQualityStatusColor();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha:0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  check.getQualityStatusIcon(),
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              check.qualityStatus,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status badge (Start/End)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: check.status == "Start" 
                                    ? Colors.blue.shade50
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: check.status == "Start"
                                      ? Colors.blue.shade200
                                      : Colors.green.shade200,
                                ),
                              ),
                              child: Text(
                                check.status ?? "",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: check.status == "Start"
                                      ? Colors.blue.shade700
                                      : Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              check.formattedCheckedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              check.formattedCheckedTime,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Checked by: ${check.checkedByName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    if (check.approvedByName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Approved by: ${check.approvedByName}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
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
          const SizedBox(height: 12),
          // Measurements grid
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildMetricItem('Density', '${check.density.toStringAsFixed(3)} kg/m³'),
                    const SizedBox(width: 12),
                    _buildMetricItem('Temperature', '${check.temperature.toStringAsFixed(1)} °C'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMetricItem('Water Content', '${check.waterContent.toStringAsFixed(1)}%'),
                    const SizedBox(width: 12),
                    _buildMetricItem('Depth', '${check.depth.toStringAsFixed(1)} cm'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Build metric item
  Widget _buildMetricItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
  
  // Quality parameter box widget
  Widget _buildQualityParameterBox(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
  
  Color _getStatusColor(String status) {
    switch(status) {
      case 'Active':
        return Colors.green;
      case 'Maintenance':
        return Colors.orange;
      case 'Inactive':
      default:
        return Colors.red;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch(status) {
      case 'Active':
        return Icons.check_circle;
      case 'Maintenance':
        return Icons.build;
      case 'Inactive':
      default:
        return Icons.pause_circle_filled;
    }
  }

  // Update the color interpolation function for smooth transitions
  Color _getColorForPercentage(double percentage) {
    // Define our color stops
    const List<double> stops = [0.0, 20.0, 40.0, 60.0, 80.0, 100.0];
    final List<Color> colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow.shade700,
      Colors.lightGreen,
      Colors.green,
      Colors.green,
    ];
    
    // Find which segment the percentage falls into
    int index = 0;
    for (int i = 0; i < stops.length - 1; i++) {
      if (percentage >= stops[i] && percentage <= stops[i + 1]) {
        index = i;
        break;
      }
    }
    
    // Calculate how far along this segment we are (0.0 - 1.0)
    final double segmentLength = stops[index + 1] - stops[index];
    final double segmentProgress = (percentage - stops[index]) / segmentLength;
    
    // Interpolate the color
    return Color.lerp(colors[index], colors[index + 1], segmentProgress) ?? colors[index];
  }

  // New helper function for stat boxes in details drawer
  Widget _buildStatBox(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // New helper function for detail info rows with icons
  Widget _buildDetailInfoRow(String label, String value, IconData icon, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha:0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Update the detail fuel tank visual for smoother transitions
  Widget _buildDetailFuelTankVisual(FuelTank tank) {
    // Animated percentage for detail view
    final animatedPercentage = _isAnimatingFill 
        ? tank.stockPercentage * _fillAnimation.value 
        : tank.stockPercentage;
    
    final fillColor = _getColorForPercentage(animatedPercentage);
    
    return Container(
      width: 80,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.2),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias, // Add clipping to prevent overflow
      child: Column(
        children: [
          // Empty space
          Expanded(
            flex: (100 - animatedPercentage).round(),
            child: Container(),
          ),
          // Filled space
          Expanded(
            flex: animatedPercentage.round() == 0 ? 1 : animatedPercentage.round(),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.vertical(
                  bottom: const Radius.circular(14),
                  top: animatedPercentage >= 99 ? const Radius.circular(14) : Radius.zero,
                ),
                boxShadow: [
                  BoxShadow(
                    color: fillColor.withValues(alpha:0.3),
                    blurRadius: 4,
                    spreadRadius: 0,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 