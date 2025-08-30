import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/government_testing_repository.dart';
import '../../models/government_testing_model.dart';
import '../../theme.dart';
import '../../utils/shared_prefs.dart';

class GovernmentTestingScreen extends StatefulWidget {
  const GovernmentTestingScreen({super.key});

  @override
  State<GovernmentTestingScreen> createState() => _GovernmentTestingScreenState();
}

class _GovernmentTestingScreenState extends State<GovernmentTestingScreen> {
  final _governmentTestingRepository = GovernmentTestingRepository();
  bool _isLoading = true;
  List<GovernmentTesting> _testings = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadTestings();
  }

  Future<void> _loadTestings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('DEBUG: GovernmentTestingScreen - Getting petrol pump ID');
      final String? petrolPumpId = await SharedPrefs.getPumpId();
      print('DEBUG: GovernmentTestingScreen - Retrieved petrol pump ID: $petrolPumpId');
      
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        print('DEBUG: GovernmentTestingScreen - Petrol pump ID is null or empty');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to get petrol pump ID. Please login again.';
        });
        return;
      }
      
      print('DEBUG: GovernmentTestingScreen - Calling getAllGovernmentTestings');
      final response = await _governmentTestingRepository.getAllGovernmentTestings();
      print('DEBUG: GovernmentTestingScreen - Got response, success: ${response.success}, data: ${response.data != null ? response.data!.length : 0} items');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success && response.data != null) {
            _testings = response.data!;
            print('DEBUG: GovernmentTestingScreen - Total testings before filtering: ${_testings.length}');
            
            // Filter by petrol pump ID if needed
            if (petrolPumpId.isNotEmpty) {
              _testings = _testings.where((testing) => 
                testing.petrolPumpId == petrolPumpId
              ).toList();
              print('DEBUG: GovernmentTestingScreen - After filtering by pump ID: ${_testings.length} testings');
            }
            
            _testings.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
          } else {
            _errorMessage = response.errorMessage ?? 'Failed to load government testings';
            print('DEBUG: GovernmentTestingScreen - Error: $_errorMessage');
          }
        });
      }
    } catch (e) {
      print('DEBUG: GovernmentTestingScreen - Exception: ${e.toString()}');
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Government Testing'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTestings,
            color: Colors.white,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTestings,
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? _buildErrorView()
                : _testings.isEmpty
                    ? _buildEmptyView()
                    : _buildTestingsList(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade700,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadTestings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
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
            'No government testing records found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a new testing record to see it here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestingsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _testings.length,
      itemBuilder: (context, index) {
        final testing = _testings[index];
        return _buildTestingCard(testing);
      },
    );
  }

  Widget _buildTestingCard(GovernmentTesting testing) {
    final testingDate = testing.testingDateTime != null
        ? DateFormat('dd MMM yyyy, HH:mm').format(testing.testingDateTime!)
        : 'N/A';
    
    Color fuelColor = _getFuelTypeColor(testing.fuelTypeName ?? 'Unknown');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha:0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top primary information section
          _buildCardHeader(testing, fuelColor),
          
          // Main content with dispenser and tank details
          _buildDispenserAndTankInfo(testing),
          
          // Secondary information
          _buildSecondaryInfo(testing, testingDate),
          
          // Bottom section with status
          _buildBottomSection(testing),
        ],
      ),
    );
  }

  Widget _buildCardHeader(GovernmentTesting testing, Color fuelColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fuelColor.withValues(alpha:0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Top row with fuel type and volume
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Fuel Type with icon
              Row(
                children: [
                  Icon(
                    Icons.local_gas_station,
                    color: fuelColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    testing.fuelTypeName ?? 'Unknown Fuel Type',
                    style: TextStyle(
                      color: fuelColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              
              // Testing Volume with prominently displayed badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: fuelColor.withValues(alpha:0.2),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.opacity,
                      color: fuelColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${testing.testingLiters.toStringAsFixed(2)} L',
                      style: TextStyle(
                        color: fuelColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Testing date below fuel type
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: fuelColor.withValues(alpha:0.7),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                testing.testingDateTime != null
                  ? DateFormat('dd MMM yyyy, HH:mm').format(testing.testingDateTime!)
                  : 'N/A',
                style: TextStyle(
                  color: fuelColor.withValues(alpha:0.9),
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDispenserAndTankInfo(GovernmentTesting testing) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Highlighted Section Title
          Text(
            "DISPENSER DETAILS",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
              letterSpacing: 1.0,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Nozzle and Dispenser Info - Primary Focus
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nozzle Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Nozzle Icon in Circle
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha:0.2),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.waves,
                          color: Colors.blue.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "NOZZLE",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        testing.nozzleNumber ?? "N/A",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Divider
                Container(
                  height: 80,
                  width: 1,
                  color: Colors.blue.shade200,
                ),
                
                // Dispenser Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha:0.2),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.local_gas_station,
                          color: Colors.blue.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "DISPENSER",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        testing.dispenserNumber ?? "N/A",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Tank Info - Secondary Focus
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                // Tank icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.storage,
                    color: Colors.teal.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Tank details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TANK",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        testing.tankName ?? "N/A",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryInfo(GovernmentTesting testing, String testingDate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Employee and Shift Title
          Text(
            "OPERATION DETAILS",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
              letterSpacing: 1.0,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Two-column layout for Employee and Shift
          Row(
            children: [
              // Employee Info
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.indigo.shade100,
                        radius: 20,
                        child: Icon(
                          Icons.person,
                          color: Colors.indigo.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Employee',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              testing.employeeName ?? "Unknown",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Shift Info
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.purple.shade100,
                        radius: 20,
                        child: Icon(
                          Icons.schedule,
                          color: Colors.purple.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shift',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              testing.shiftName ?? "N/A",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(GovernmentTesting testing) {
    // Determine status color
    Color statusColor = _getStatusColor(testing.managerApprovalStatus ?? 'Pending');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badges row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Approval status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha:0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(testing.managerApprovalStatus ?? 'Pending'),
                      color: statusColor,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      testing.managerApprovalStatus ?? 'Pending',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Add back status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: testing.isAddedBackToTank ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: testing.isAddedBackToTank ? Colors.green.shade300 : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      testing.isAddedBackToTank ? Icons.check_circle : Icons.pending,
                      size: 14,
                      color: testing.isAddedBackToTank ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      testing.isAddedBackToTank ? 'Added Back' : 'Not Added',
                      style: TextStyle(
                        color: testing.isAddedBackToTank ? Colors.green.shade700 : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Notes section if available
          if (testing.notes != null && testing.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Notes',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              testing.notes!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          
          // Testing ID at the bottom
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'ID: ${testing.governmentTestingId?.substring(testing.governmentTestingId!.length - 8)}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Get color based on fuel type
  Color _getFuelTypeColor(String fuelType) {
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
  
  // Get color based on approval status
  Color _getStatusColor(String status) {
    switch(status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      case 'pending':
        return Colors.amber.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
  
  // Get icon based on approval status
  IconData _getStatusIcon(String status) {
    switch(status.toLowerCase()) {
      case 'approved':
        return Icons.verified;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
        return Icons.hourglass_empty;
      default:
        return Icons.help_outline;
    }
  }
} 