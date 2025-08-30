import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/nozzle_reading_repository.dart';
import '../../models/employee_nozzle_assignment_model.dart';
import '../../theme.dart';

import 'dart:developer' as developer;
import 'nozzle_readings_detail_screen.dart';

class EmployeeNozzleReadingsScreen extends StatefulWidget {
  final String employeeId;

  const EmployeeNozzleReadingsScreen({
    Key? key,
    required this.employeeId,
  }) : super(key: key);

  @override
  State<EmployeeNozzleReadingsScreen> createState() => _EmployeeNozzleReadingsScreenState();
}

class _EmployeeNozzleReadingsScreenState extends State<EmployeeNozzleReadingsScreen> {
  final NozzleReadingRepository _nozzleReadingRepository = NozzleReadingRepository();
  
  bool _isLoading = true;
  String _errorMessage = '';
  List<EmployeeNozzleAssignment> _nozzleAssignments = [];
  
  @override
  void initState() {
    super.initState();
    _fetchNozzleAssignments();
  }
  
  Future<void> _fetchNozzleAssignments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      developer.log('Fetching nozzle assignments for employee ID: ${widget.employeeId}');
      
      final response = await _nozzleReadingRepository.getEmployeeNozzleAssignments(widget.employeeId);
      
      setState(() {
        _isLoading = false;
        
        if (response.success && response.data != null) {
          _nozzleAssignments = response.data!;
          developer.log('Successfully loaded ${_nozzleAssignments.length} nozzle assignments');
        } else {
          _errorMessage = response.errorMessage ?? 'Failed to load nozzle assignments';
          developer.log('Error loading nozzle assignments: $_errorMessage');
        }
      });
    } catch (e) {
      developer.log('Exception in _fetchNozzleAssignments: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Nozzle Assignments', 
          style: TextStyle(
            fontWeight: FontWeight.w600, 
            fontSize: 18,
          ),
        ),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNozzleAssignments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading assignments...',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchNozzleAssignments,
              color: AppTheme.primaryBlue,
              child: _buildBody(),
            ),
    );
  }
  
  Widget _buildBody() {
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppTheme.primaryOrange,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to Load Assignments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchNozzleAssignments,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_nozzleAssignments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.gas_meter_outlined,
                  color: AppTheme.primaryBlue,
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Nozzle Assignments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'You currently have no assigned nozzles for this shift',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _fetchNozzleAssignments,
                icon: Icon(Icons.refresh, color: AppTheme.primaryBlue),
                label: Text(
                  'Refresh',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  side: BorderSide(color: AppTheme.primaryBlue),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: _nozzleAssignments.length + 1, // +1 for the header
      itemBuilder: (context, index) {
        if (index == 0) {
          // Header section
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Assigned Nozzles',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage and record readings for your assigned nozzles',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Total: ${_nozzleAssignments.length} nozzles',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        
        final nozzle = _nozzleAssignments[index - 1]; // Adjust for header
        return _buildNozzleCard(nozzle);
      },
    );
  }
  
  Widget _buildNozzleCard(EmployeeNozzleAssignment nozzle) {
    // Format date
    DateTime startDate = DateTime.tryParse(nozzle.startDate) ?? DateTime.now();
    String formattedDate = DateFormat('MMM d, yyyy').format(startDate);
    
    // Get nozzle status indicator color
    Color statusColor = nozzle.isActive ? AppTheme.primaryBlue : Colors.grey;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToNozzleReadingsDetail(nozzle),
        splashColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
        highlightColor: AppTheme.primaryBlue.withValues(alpha: 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with fuel type
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                      const SizedBox(width: 8),
                      Text(
                        'Nozzle #${nozzle.nozzleNumber}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      nozzle.fuelType,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Body content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shift info row
                  Row(
                    children: [
                      Icon(Icons.schedule_outlined, size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Shift #${nozzle.shiftNumber}',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Shift times row
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      '${nozzle.shiftStartTime} - ${nozzle.shiftEndTime}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Assignment date row
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Assigned: $formattedDate',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // View readings button
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () => _navigateToNozzleReadingsDetail(nozzle),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Readings',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 16),
                        ],
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
  
  void _navigateToNozzleReadingsDetail(EmployeeNozzleAssignment nozzle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NozzleReadingsDetailScreen(
          employeeId: widget.employeeId,
          nozzleId: nozzle.nozzleId,
          nozzleNumber: nozzle.nozzleNumber.toString(),
          fuelType: nozzle.fuelType,
          employeeName: nozzle.employeeName,
        ),
      ),
    );
  }
} 