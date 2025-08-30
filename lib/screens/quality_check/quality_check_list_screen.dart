import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/quality_check_repository.dart';
import '../../models/quality_check_model.dart';
import '../../theme.dart';
import 'add_quality_check_screen.dart';

class QualityCheckListScreen extends StatefulWidget {
  const QualityCheckListScreen({Key? key}) : super(key: key);

  @override
  State<QualityCheckListScreen> createState() => _QualityCheckListScreenState();
}

class _QualityCheckListScreenState extends State<QualityCheckListScreen> {
  final QualityCheckRepository _repository = QualityCheckRepository();
  List<QualityCheck> _qualityChecks = [];
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Filters
  String? _selectedFuelType;
  String? _selectedStatus;
  final List<String?> _fuelTypeOptions = [null, 'Petrol', 'Diesel', 'CNG', 'Premium Petrol', 'Premium Diesel', 'LPG'];
  final List<String?> _statusOptions = [null, 'Excellent', 'Good', 'Average', 'Poor', 'Critical'];
  
  int get _activeFilterCount => 
      (_selectedFuelType != null ? 1 : 0) + 
      (_selectedStatus != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _loadQualityChecks();
  }

  Future<void> _loadQualityChecks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _repository.getAllQualityChecks();

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success && response.data != null) {
            _qualityChecks = response.data!;
            print('Loaded ${_qualityChecks.length} quality checks');
          } else {
            _errorMessage = response.errorMessage ?? 'Failed to load quality checks';
            print('Error loading quality checks: $_errorMessage');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
          print('Exception loading quality checks: $e');
        });
      }
    }
  }
  
  // Delete quality check
  void _deleteQualityCheck(QualityCheck check) async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quality Check'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this quality check for ${check.tankName}?'),
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
                      'This action cannot be undone.',
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
      // Use the correct ID for deletion
      final checkId = check.fuelQualityCheckId ?? check.id;
      
      if (checkId == null) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete: Quality check ID is missing'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final response = await _repository.deleteQualityCheck(checkId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quality check deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadQualityChecks();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete quality check: ${response.errorMessage}'),
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
  
  // Filter the quality checks based on selected criteria
  List<QualityCheck> get _filteredQualityChecks {
    return _qualityChecks.where((check) {
      final matchesFuelType = _selectedFuelType == null || check.fuelType == _selectedFuelType;
      final matchesStatus = _selectedStatus == null || check.qualityStatus == _selectedStatus;
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
            title: const Text('Filter Quality Checks'),
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
                    'Quality Status',
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
                      if (status == 'Good') {
                        statusColor = Colors.green;
                      } else if (status == 'Warning') {
                        statusColor = Colors.orange;
                      } else if (status == 'Poor') {
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

  void _navigateToAddQualityCheck() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddQualityCheckScreen()),
    );
    
    // Refresh the list if a new quality check was added
    if (result == true) {
      _loadQualityChecks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredChecks = _filteredQualityChecks;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Quality Checks'),
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
            onPressed: _loadQualityChecks,
            color: Colors.white,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadQualityChecks,
              child: Column(
                children: [
                  // Header section with stats
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
                        // Stats cards in a row
                        Row(
                          children: [
                            _buildStatCard(
                              'Total Checks',
                              _qualityChecks.length.toString(),
                              Icons.science_outlined,
                              Colors.white,
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              'Good',
                              _qualityChecks.where((c) => c.qualityStatus.toLowerCase() == 'good').length.toString(),
                              Icons.check_circle_outline,
                              Colors.greenAccent.shade100,
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              'Poor',
                              _qualityChecks.where((c) => c.qualityStatus.toLowerCase() == 'poor').length.toString(),
                              Icons.error_outline,
                              Colors.redAccent.shade100,
                              isAlert: _qualityChecks.where((c) => c.qualityStatus.toLowerCase() == 'poor').isNotEmpty,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Active filters display
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
                  
                  // Filter info text
                  if (_qualityChecks.isNotEmpty && filteredChecks.length != _qualityChecks.length)
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
                          Flexible(
                            child: Text(
                              'Showing ${filteredChecks.length} of ${_qualityChecks.length} quality checks',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey[700],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Error, empty view, or quality checks list
                  _errorMessage.isNotEmpty && filteredChecks.isEmpty
                      ? _buildErrorView()
                      : filteredChecks.isEmpty
                          ? _buildEmptyView()
                          : Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16.0),
                                itemCount: filteredChecks.length,
                                itemBuilder: (context, index) {
                                  final qualityCheck = filteredChecks[index];
                                  return _buildQualityCheckCard(qualityCheck);
                                },
                              ),
                            ),
                ],
              ),
            ),
      // Add floating action button for adding new quality checks
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddQualityCheck,
        backgroundColor: AppTheme.primaryBlue,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add Quality Check',
      ),
    );
  }


  // Build stat card for header
  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool isAlert = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.15),
          borderRadius: BorderRadius.circular(12),
          border: isAlert ? Border.all(color: Colors.red, width: 1.5) : null,
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
                onPressed: _loadQualityChecks,
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
              Icons.science,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _qualityChecks.isEmpty
                  ? 'No quality checks available'
                  : 'No quality checks match your filters',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _qualityChecks.isEmpty
                  ? 'Quality checks will appear here after they are performed'
                  : 'Try changing or clearing your filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityCheckCard(QualityCheck check) {
    // Determine colors based on the quality check
    final fuelColor = _getColorForFuelType(check.fuelType);
    final statusColor = check.getQualityStatusColor();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha:0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Dismissible(
        key: Key(check.fuelQualityCheckId ?? check.id ?? UniqueKey().toString()),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Quality Check'),
              content: Text('Are you sure you want to delete this quality check?'),
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
          _deleteQualityCheck(check);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha:0.1),
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
                          color: statusColor.withValues(alpha:0.2),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
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
                        Text(
                          check.tankName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.local_gas_station,
                              color: fuelColor,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                check.fuelType,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: fuelColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          check.getQualityStatusIcon(),
                          color: statusColor,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          check.qualityStatus,
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
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Check status (Start/End) badge
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getCheckStatusColor(check.status).withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getCheckStatusColor(check.status), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getCheckStatusIcon(check.status),
                          color: _getCheckStatusColor(check.status),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Check ${check.status}',
                          style: TextStyle(
                            color: _getCheckStatusColor(check.status),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Parameters grid - updated to use a GridView for 4 parameters
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children: [
                      _buildParameterBox(
                        'Density',
                        '${check.density.toStringAsFixed(3)}',
                        'kg/m³',
                        Icons.science,
                        Colors.blue.shade700,
                      ),
                      _buildParameterBox(
                        'Temperature',
                        '${check.temperature.toStringAsFixed(1)}',
                        '°C',
                        Icons.thermostat,
                        Colors.orange.shade700,
                      ),
                      _buildParameterBox(
                        'Water Content',
                        '${check.waterContent.toStringAsFixed(1)}',
                        '%',
                        Icons.opacity,
                        Colors.teal.shade700,
                      ),
                      _buildParameterBox(
                        'Depth',
                        '${check.depth.toStringAsFixed(0)}',
                        'mm',
                        Icons.straighten,
                        Colors.purple.shade700,
                      ),
                    ],
                  ),
                  
                  // Checked info
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.person,
                                color: Colors.grey.shade600,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Checked by: ${check.checkedByName ?? check.checkedBy}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.grey.shade600,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              check.formattedCheckedDate,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Approval status if applicable
                  if (check.isApproved || check.approvedBy != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_user,
                            color: Colors.green.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              check.isApproved
                                ? 'Approved by: ${check.approvedByName ?? check.approvedBy}'
                                : 'Pending approval',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Notes (if any)
                  if (check.notes != null && check.notes!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.yellow.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.note,
                                color: Colors.amber.shade700,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Notes:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            check.notes!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                            // Add overflow to handle long notes
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
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
  
  // Build parameter box for quality check card
  Widget _buildParameterBox(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha:0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    switch(status.toLowerCase()) {
      case 'good':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'poor':
      default:
        return Colors.red;
    }
  }
  
  // Helper methods for check status (Start/End)
  Color _getCheckStatusColor(String status) {
    switch(status.toLowerCase()) {
      case 'start':
        return Colors.blue.shade600;
      case 'end':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
  
  IconData _getCheckStatusIcon(String status) {
    switch(status.toLowerCase()) {
      case 'start':
        return Icons.play_arrow_rounded;
      case 'end':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }
} 