import 'package:flutter/material.dart';
import '../../api/fuel_dispenser_repository.dart';
import '../../models/fuel_dispenser_model.dart';
import '../../theme.dart';
import 'add_fuel_dispenser_screen.dart';
import 'nozzle_management_screen.dart';
import 'dart:developer' as developer;
import '../../models/nozzle_model.dart';
import '../../api/nozzle_repository.dart';

class FuelDispenserListScreen extends StatefulWidget {
  const FuelDispenserListScreen({super.key});

  @override
  State<FuelDispenserListScreen> createState() => _FuelDispenserListScreenState();
}

class _FuelDispenserListScreenState extends State<FuelDispenserListScreen> {
  final _repository = FuelDispenserRepository();
  final _nozzleRepository = NozzleRepository();
  List<FuelDispenser> _dispensers = [];
  Map<String, List<Nozzle>> _dispenserNozzles = {};
  bool _isLoading = true;
  String _errorMessage = '';

  // Filter options
  String? _statusFilter;
  final List<String> _statusOptions = ['All', 'Active', 'Maintenance', 'Inactive'];

  @override
  void initState() {
    super.initState();
    _loadDispensers();
  }

  Future<void> _loadDispensers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _repository.getFuelDispensers();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (response.success) {
          _dispensers = response.data ?? [];
          for (var dispenser in _dispensers) {
            developer.log('Loaded dispenser #${dispenser.dispenserNumber} with tank ID: ${dispenser.petrolPumpId}');
          }
          // After loading dispensers, load their nozzles
          _loadAllNozzles();
        } else {
          _errorMessage = response.errorMessage ?? 'Failed to load fuel dispensers';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  // Load nozzles for all dispensers
  Future<void> _loadAllNozzles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Clear previous nozzle data
      _dispenserNozzles = {};
      
      print('Starting to load nozzles for ${_dispensers.length} dispensers');
      developer.log('Starting to load nozzles for ${_dispensers.length} dispensers');
      
      // Load nozzles for each dispenser
      for (var dispenser in _dispensers) {
        if (dispenser.id != null) {
          print('Loading nozzles for dispenser #${dispenser.dispenserNumber} (ID: ${dispenser.id})');
          final nozzles = await _loadNozzlesForDispenser(dispenser.id!);
          print('Loaded ${nozzles.length} nozzles for dispenser #${dispenser.dispenserNumber}');
          
          if (nozzles.isNotEmpty) {
            _dispenserNozzles[dispenser.id] = nozzles;
            print('Added ${nozzles.length} nozzles to cache for dispenser #${dispenser.dispenserNumber}');
          } else {
            print('No nozzles found for dispenser #${dispenser.dispenserNumber}');
          }
        }
      }

      print('Finished loading nozzles. Nozzle data cache has ${_dispenserNozzles.length} dispensers with nozzles');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error while loading all nozzles: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading nozzles: $e';
        });
      }
    }
  }

  // Load nozzles for a specific dispenser
  Future<List<Nozzle>> _loadNozzlesForDispenser(String dispenserId) async {
    try {
      print('Requesting nozzles for dispenser ID: $dispenserId');
      final response = await _nozzleRepository.getNozzlesByDispenserId(dispenserId);
      
      print('Nozzle API response success: ${response.success}');
      if (response.success) {
        print('Nozzle API data: ${response.data != null ? response.data!.length : 'null'} nozzles');
      } else {
        print('Nozzle API error: ${response.errorMessage}');
      }
      
      if (response.success && response.data != null) {
        return response.data!;
      }
    } catch (e) {
      print('Exception when loading nozzles for dispenser $dispenserId: $e');
      developer.log('Error loading nozzles for dispenser $dispenserId: $e');
    }
    return [];
  }

  // Get nozzles for a specific dispenser from cached data
  List<Nozzle> _getNozzlesForDispenser(String? dispenserId) {
    if (dispenserId == null) return [];
    
    final nozzles = _dispenserNozzles[dispenserId] ?? [];
    print('Retrieved ${nozzles.length} nozzles from cache for dispenser ID: $dispenserId');
    return nozzles;
  }

  // Filter dispensers by status
  List<FuelDispenser> _getFilteredDispensers() {
    if (_statusFilter == null || _statusFilter == 'All') {
      return _dispensers;
    }
    return _dispensers.where((dispenser) =>
        dispenser.status.toLowerCase() == _statusFilter!.toLowerCase()
    ).toList();
  }

  // Delete a fuel dispenser
  Future<void> _deleteDispenser(String id) async {
    try {
      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this dispenser?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('DELETE'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() => _isLoading = true);

      final response = await _repository.deleteFuelDispenser(id);

      if (!mounted) return;

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dispenser deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        _loadDispensers();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = response.errorMessage ?? 'Failed to delete dispenser';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $_errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      case 'inactive':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Update dispenser status with immediate UI update
  Future<void> _updateDispenserStatus(String dispenserId, String newStatus) async {
    try {
      // Find the dispenser by ID
      final dispenser = _dispensers.firstWhere((d) => d.id == dispenserId);

      if (dispenser.id == null) {
        _showSnackBar('Could not update dispenser: Dispenser ID is missing');
        return;
      }

      // Validate numberOfNozzles is within required range and log values
      print('DISPENSER_UPDATE: Original numberOfNozzles: ${dispenser.numberOfNozzles}');
      
      int safeNumberOfNozzles = dispenser.numberOfNozzles;
      if (safeNumberOfNozzles < 1) {
        print('DISPENSER_UPDATE: Correcting invalid nozzle count to 1');
        safeNumberOfNozzles = 1;
      } else if (safeNumberOfNozzles > 6) {
        print('DISPENSER_UPDATE: Correcting invalid nozzle count to 6');
        safeNumberOfNozzles = 6;
      }
      
      // Create updated dispenser with the new status
      // Important: Just pass the fuelType as is, without any modification
      final updatedDispenser = FuelDispenser(
        id: dispenser.id,
        dispenserNumber: dispenser.dispenserNumber,
        petrolPumpId: dispenser.petrolPumpId,
        status: newStatus,
        numberOfNozzles: safeNumberOfNozzles,
        fuelType: dispenser.fuelType, // Keep original value without modifying
      );

      print('DISPENSER_UPDATE: Status change from ${dispenser.status} to $newStatus');
      print('DISPENSER_UPDATE: Updated numberOfNozzles: ${updatedDispenser.numberOfNozzles}');
      print('DISPENSER_UPDATE: Using original fuelType: ${dispenser.fuelType}');

      // Show loading indicator
      _showSnackBar('Updating dispenser status...');

      // Optimistically update UI
      setState(() {
        final index = _dispensers.indexWhere((d) => d.id == dispenserId);
        if (index != -1) {
          _dispensers[index] = updatedDispenser;
        }
      });

      // Call API to update dispenser
      final response = await _repository.updateFuelDispenser(updatedDispenser);

      // If not mounted, return
      if (!mounted) return;

      if (response.success && response.data != null) {
        _showSnackBar('Dispenser status updated successfully');
        
        // Refresh dispensers to ensure UI is updated with latest data from server
        _loadDispensers();
      } else {
        // Revert optimistic update if API call fails
        setState(() {
          final index = _dispensers.indexWhere((d) => d.id == dispenserId);
          if (index != -1) {
            _dispensers[index] = dispenser;
          }
        });
        _showSnackBar('Failed to update dispenser status: ${response.errorMessage}');
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
    }
  }

  // Go to add dispenser screen
  void _addFuelDispenser() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddFuelDispenserScreen(),
      ),
    ).then((_) => _loadDispensers());
  }

  // Go to nozzle management screen
  void _manageNozzles(FuelDispenser dispenser) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NozzleManagementScreen(dispenser: dispenser),
      ),
    );
  }

  // Get color for fuel type
  Color _getFuelTypeColor(String? fuelType) {
    if (fuelType == null) {
      return Colors.blueGrey.shade700; // Default color when fuel type is null
    }
    
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

  @override
  Widget build(BuildContext context) {
    final filteredDispensers = _getFilteredDispensers();
    final Map<String, int> statusCounts = {
      'Active': 0,
      'Maintenance': 0,
      'Inactive': 0,
    };
    
    // Calculate status counts
    for (var dispenser in _dispensers) {
      if (statusCounts.containsKey(dispenser.status)) {
        statusCounts[dispenser.status] = (statusCounts[dispenser.status] ?? 0) + 1;
      }
    }

    // Check if any dispensers have nozzles
    final bool anyNozzlesLoaded = _dispenserNozzles.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Fuel Dispensers'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.api),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NozzleManagementScreen(),
                ),
              );
            },
            tooltip: 'Manage All Nozzles',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDispensers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Status filter chips and count summary
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total count with summary
                      Text(
                        'Total Dispensers: ${_dispensers.length}',
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
                              _dispensers.length, Colors.blueGrey),
                            const SizedBox(width: 8),
                            ...statusCounts.entries.map((entry) => 
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildFilterChip(
                                  entry.key, 
                                  entry.key, 
                                  entry.value, 
                                  _getStatusColor(entry.key)
                                ),
                              )
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Error message if any
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
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

                // List of dispensers or empty state
                Expanded(
                  child: filteredDispensers.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredDispensers.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final dispenser = filteredDispensers[index];
                            return _buildDispenserCard(dispenser);
                          },
                        ),
                ),
              ],
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: _addFuelDispenser,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Add Dispenser',
      ),
    );
  }

  // Filter chip widget
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

  // Build a dispenser card with visualization on the left and details on the right
  Widget _buildDispenserCard(FuelDispenser dispenser) {
    final statusColor = _getStatusColor(dispenser.status);
    final fuelTypeColor = _getFuelTypeColor(dispenser.fuelType);
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha:0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showDispenserActionSheet(dispenser),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - Dispenser visualization
              _buildDispenserVisualization(dispenser),
              
              const SizedBox(width: 16),
              
              // Right side - Dispenser details (simplified)
              Expanded(
                child: Container(
                  height: 180, // Increased to match taller dispenser
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with dispenser number and status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Dispenser title
                          Flexible(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '#${dispenser.dispenserNumber}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Dispenser',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Status indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: statusColor, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  dispenser.status,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),

                      const Spacer(),
                      
                      // Action buttons - Added wrapping and made buttons smaller
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _manageNozzles(dispenser),
                            icon: const Icon(Icons.api_rounded, size: 14),
                            label: const Text('NOZZLES'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              foregroundColor: AppTheme.primaryBlue,
                              textStyle: const TextStyle(fontSize: 10),
                              minimumSize: const Size(70, 28),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _showDispenserActionSheet(dispenser),
                            icon: const Icon(Icons.settings, size: 14),
                            label: const Text('MANAGE'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              foregroundColor: AppTheme.primaryBlue,
                              textStyle: const TextStyle(fontSize: 10),
                              minimumSize: const Size(70, 28),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to generate nozzle statuses based on real nozzle data
  List<Map<String, dynamic>> _getRealNozzleStatuses(FuelDispenser dispenser) {
    // Return empty list if no dispenser ID
    if (dispenser.id == null) {
      print('Cannot get nozzle statuses: dispenser ID is null');
      return [];
    }
    
    // Get real nozzles for this dispenser
    final nozzles = _getNozzlesForDispenser(dispenser.id);
    print('Getting nozzle statuses for dispenser #${dispenser.dispenserNumber}: found ${nozzles.length} nozzles');
    
    // Convert to the format we need for display
    final statuses = nozzles.map((nozzle) => {
      'position': nozzle.nozzleNumber,
      'status': nozzle.status,
      'fuelType': nozzle.fuelType,
    }).toList();
    
    // Sort by position (nozzle number) in ascending order with null safety
    statuses.sort((a, b) {
      // Handle null positions - put nulls at the end
      final posA = a['position'] as int?;
      final posB = b['position'] as int?;
      
      if (posA == null && posB == null) return 0;
      if (posA == null) return 1;
      if (posB == null) return -1;
      
      return posA.compareTo(posB);
    });
    
    print('Returning ${statuses.length} nozzle statuses for dispenser #${dispenser.dispenserNumber}');
    return statuses;
  }

  // Build dispenser visualization (similar to nozzle management screen)
  Widget _buildDispenserVisualization(FuelDispenser dispenser) {
    final bool isActive = dispenser.status.toLowerCase() == 'active';
    final bool isMaintenance = dispenser.status.toLowerCase() == 'maintenance';
    final dispenserColor = AppTheme.primaryBlue;
    final statusColor = _getStatusColor(dispenser.status);
    final fuelTypeColor = _getFuelTypeColor(dispenser.fuelType);
    
    // Get real nozzle data
    final nozzleData = _getRealNozzleStatuses(dispenser);
    
    return Container(
      width: 100, // Reduced width to be slimmer
      height: 180, // Increased height to be taller
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dispenser header with number
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: dispenserColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#${dispenser.dispenserNumber}',
                    style: TextStyle(
                      color: dispenserColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Status indicator strip
          Container(
            height: 5,
            color: statusColor,
          ),
          
          // Fuel type indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: fuelTypeColor.withValues(alpha:0.1),
            // child: Text(
            //   dispenser.fuelType ?? 'Mixed',
            //   textAlign: TextAlign.center,
            //   style: TextStyle(
            //     color: fuelTypeColor,
            //     fontWeight: FontWeight.bold,
            //     fontSize: 12,
            //   ),
            // ),
          ),
          
          // Add some stretching space
          const SizedBox(height: 10),
          
          // Nozzles grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: nozzleData.isEmpty 
                  ? Center(child: Text('No nozzles', style: TextStyle(color: Colors.grey, fontSize: 12)))
                  : _buildNozzleGrid(dispenser.numberOfNozzles, nozzleData),
            ),
          ),
          
          // Add a bit more space at the bottom
          const SizedBox(height: 5),
        ],
      ),
    );
  }

  // Build a grid of nozzles
  Widget _buildNozzleGrid(int numberOfNozzles, List<Map<String, dynamic>> nozzleData) {
    // Already sorted in _getRealNozzleStatuses
    
    // Create a wrapped grid of nozzles
    return Wrap(
      spacing: 6, // Reduced spacing
      runSpacing: 6, // Reduced spacing
      alignment: WrapAlignment.center,
      children: List.generate(
        nozzleData.length, // Only show actual nozzles present
        (index) => _buildNozzleIndicator(
          nozzleData[index]['position'],
          nozzleData[index]['status']
        ),
      ),
    );
  }
  
  // Build individual nozzle indicator
  Widget _buildNozzleIndicator(int position, String status) {
    // Status colors
    final Map<String, Color> statusColors = {
      'Active': Colors.green,
      'Inactive': Colors.grey,
      'Maintenance': Colors.orange,
    };
    
    final color = statusColors[status] ?? Colors.grey;
    
    return Container(
      width: 30, // Slightly smaller
      height: 30, // Slightly smaller
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Position number
          Text(
            '$position',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          
          // Status indicator (bottom border)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(4)
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Empty state widget
  Widget _buildEmptyState() {
    return Center(
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
            'No Dispensers Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              _statusFilter != null
                  ? 'No dispensers with $_statusFilter status'
                  : 'Add your first dispenser to get started',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addFuelDispenser,
            icon: const Icon(Icons.add),
            label: const Text('Add New Dispenser'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Action sheet for managing dispenser
  void _showDispenserActionSheet(FuelDispenser dispenser) {
    final statusColor = _getStatusColor(dispenser.status);
    final fuelTypeColor = _getFuelTypeColor(dispenser.fuelType);
    
    // Get real nozzle data (already sorted in _getRealNozzleStatuses)
    final nozzleData = _getRealNozzleStatuses(dispenser);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Local state for the drawer to track the current status
            String currentStatus = dispenser.status;
            
            // Function to update status from within the drawer
            void updateStatus(String newStatus) async {
              // Only proceed if status is different
              if (newStatus != currentStatus) {
                // Close the drawer first
                Navigator.pop(context);
                
                // Update the dispenser status
                await _updateDispenserStatus(dispenser.id, newStatus);
                
                // Refresh the dispenser list to show updated statuses
                _loadDispensers();
              }
            }
            
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Make the content scrollable
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header with dispenser info
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Dispenser visual preview (miniature)
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha:0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Mini header
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryBlue,
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(7),
                                          ),
                                        ),
                                        child: Text(
                                          '#${dispenser.dispenserNumber}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      
                                      // Status indicator
                                      Container(
                                        height: 3,
                                        color: statusColor,
                                      ),
                                      
                                      // Fuel type
                                      Expanded(
                                        child: Container(
                                          width: double.infinity,
                                          color: fuelTypeColor.withValues(alpha:0.1),
                                          alignment: Alignment.center,
                                          child: Text(
                                            dispenser.fuelType ?? 'Mixed',
                                            style: TextStyle(
                                              color: fuelTypeColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(width: 16),
                                
                                // Dispenser details - Wrap in Expanded to prevent overflow
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Dispenser #${dispenser.dispenserNumber}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: statusColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              dispenser.status,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: statusColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.api,
                                            size: 14,
                                            color: Colors.grey.shade700,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${dispenser.numberOfNozzles} Nozzle${dispenser.numberOfNozzles != 1 ? 's' : ''}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade700,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                          
                          const Divider(height: 1),
                          
                          // Status buttons
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DISPENSER STATUS',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildStatusButton('Active', Colors.green, dispenser.status == 'Active',
                                      onTap: () => updateStatus('Active')),
                                    const SizedBox(width: 8),
                                    _buildStatusButton('Maintenance', Colors.orange, dispenser.status == 'Maintenance',
                                      onTap: () => updateStatus('Maintenance')),
                                    const SizedBox(width: 8),
                                    _buildStatusButton('Inactive', Colors.red, dispenser.status == 'Inactive',
                                      onTap: () => updateStatus('Inactive')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Nozzle management section
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NOZZLE MANAGEMENT',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Nozzle grid preview
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    children: [
                                      // Nozzle status indicators - show actual nozzles
                                      nozzleData.isEmpty
                                      ? Text(
                                          'No nozzles configured',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        )
                                      : Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          alignment: WrapAlignment.center,
                                          children: nozzleData.map((nozzle) => 
                                            _buildNozzlePreview(
                                              nozzle['position'], 
                                              nozzle['status']
                                            )
                                          ).toList(),
                                        ),
                                      
                                      const SizedBox(height: 12),
                                      
                                      // Manage nozzles button
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _manageNozzles(dispenser);
                                          },
                                          icon: const Icon(Icons.settings, size: 16),
                                          label: const Text('MANAGE NOZZLES'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryBlue,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
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
                          
                          // Delete button
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                if (dispenser.id != null) {
                                  _deleteDispenser(dispenser.id);
                                }
                              },
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red.shade700,
                                size: 18,
                              ),
                              label: Text(
                                'DELETE DISPENSER',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }
  
  // Status button for bottom sheet
  Widget _buildStatusButton(String label, Color color, bool isSelected, {required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha:0.15) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
  
  // Nozzle preview for the bottom sheet
  Widget _buildNozzlePreview(int position, String status) {
    // Status colors
    final Map<String, Color> statusColors = {
      'Active': Colors.green,
      'Inactive': Colors.grey,
      'Maintenance': Colors.orange,
    };
    
    final color = statusColors[status] ?? Colors.grey;
    
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: Text(
          '$position',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
