import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/attendance_repository.dart';
import '../../api/api_constants.dart';
import '../../models/attendance_model.dart';
import '../../theme.dart';
import '../login/login_screen.dart';

class EmployeeAttendanceScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const EmployeeAttendanceScreen({
    Key? key, 
    required this.employeeId,
    required this.employeeName,
  }) : super(key: key);

  @override
  State<EmployeeAttendanceScreen> createState() => _EmployeeAttendanceScreenState();
}

class _EmployeeAttendanceScreenState extends State<EmployeeAttendanceScreen> {
  final AttendanceRepository _attendanceRepository = AttendanceRepository();
  
  // Selected date range
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  // Active attendance
  bool _loadingActiveAttendance = false;
  AttendanceDetail? _activeAttendance;
  String _activeAttendanceError = '';
  
  // Attendance summary
  bool _loadingSummary = false;
  AttendanceSummary? _attendanceSummary;
  String _summaryError = '';
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    await Future.wait([
      _fetchActiveAttendance(),
      _fetchAttendanceSummary(),
    ]);
  }
  
  Future<void> _fetchActiveAttendance() async {
    if (mounted) {
      setState(() {
        _loadingActiveAttendance = true;
        _activeAttendanceError = '';
      });
    }
    
    try {
      final response = await _attendanceRepository.getEmployeeActiveAttendance(widget.employeeId);
      
      // Check for authentication error
      if (response.errorMessage != null && 
          (response.errorMessage!.contains('Authentication failed') || 
           response.errorMessage!.contains('No authentication token found'))) {
        _handleAuthError();
        return;
      }
      
      if (mounted) {
        setState(() {
          _loadingActiveAttendance = false;
          
          if (response.success && response.data != null) {
            _activeAttendance = response.data;
          } else {
            _activeAttendanceError = response.errorMessage ?? 'Failed to load active attendance';
            _activeAttendance = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingActiveAttendance = false;
          _activeAttendanceError = 'Error: $e';
        });
      }
    }
  }
  
  Future<void> _fetchAttendanceSummary() async {
    if (mounted) {
      setState(() {
        _loadingSummary = true;
        _summaryError = '';
      });
    }
    
    try {
      print('⏳ Fetching attendance summary for employeeId: ${widget.employeeId}');
      print('⏳ Date range: ${_startDate.toIso8601String()} to ${_endDate.toIso8601String()}');
      
      final response = await _attendanceRepository.getEmployeeAttendanceSummary(
        widget.employeeId,
        _startDate,
        _endDate,
      );
      
      print('✅ API Response received: ${response.success}');
      if (response.errorMessage != null) {
        print('⚠️ API Error message: ${response.errorMessage}');
        
        // Check for authentication error
        if (response.errorMessage!.contains('Authentication failed') || 
            response.errorMessage!.contains('No authentication token found')) {
          _handleAuthError();
          return;
        }
      }
      
      if (response.data != null) {
        print('📊 Attendance Summary Data:');
        print('   - Employee: ${response.data!.employeeName}');
        print('   - Date Range: ${response.data!.startDate} to ${response.data!.endDate}');
        print('   - Working Days: ${response.data!.totalWorkingDays}');
        print('   - Present: ${response.data!.daysPresent}');
        print('   - Absent: ${response.data!.daysAbsent}');
        print('   - Late: ${response.data!.daysLate}');
        print('   - Attendance %: ${response.data!.attendancePercentage}');
        print('   - Total Hours: ${response.data!.totalHoursWorked}');
        print('   - Avg Hours/Day: ${response.data!.averageHoursPerDay}');
        print('   - Details count: ${response.data!.attendanceDetails.length}');
        
        // Check for negative hours which might indicate a data issue
        if (response.data!.totalHoursWorked < 0) {
          print('⚠️ WARNING: Negative total hours detected: ${response.data!.totalHoursWorked}');
        }
        
        // Print first attendance detail if available
        if (response.data!.attendanceDetails.isNotEmpty) {
          final detail = response.data!.attendanceDetails.first;
          print('   - First attendance detail:');
          print('     * ID: ${detail.employeeAttendanceId}');
          print('     * CheckIn: ${detail.checkInTime}');
          print('     * CheckOut: ${detail.checkOutTime}');
          print('     * Total Hours: ${detail.totalHours}');
          print('     * Status: ${detail.status}');
          print('     * Is Late: ${detail.isLate}');
          
          // Check for time inconsistency
          if (detail.checkOutTime != null && detail.checkInTime.isAfter(detail.checkOutTime!)) {
            print('⚠️ WARNING: CheckIn time is after CheckOut time!');
            print('     * CheckIn: ${detail.checkInTime}');
            print('     * CheckOut: ${detail.checkOutTime}');
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _loadingSummary = false;
          
          if (response.success && response.data != null) {
            _attendanceSummary = response.data;
          } else {
            // If the API response contains "Unexpected end of input", create a default summary
            if (response.errorMessage != null && 
                response.errorMessage!.contains("Unexpected end of input")) {
              print('⚠️ Creating default attendance summary due to API error');
              _attendanceSummary = _createDefaultAttendanceSummary();
              _summaryError = 'Using default data due to server response issue';
            } else {
              _summaryError = response.errorMessage ?? 'Failed to load attendance summary';
              _attendanceSummary = null;
            }
          }
        });
      }
    } catch (e) {
      print('❌ Error in fetchAttendanceSummary: $e');
      print('❌ Error stack trace: ${StackTrace.current}');
      
      if (mounted) {
        setState(() {
          _loadingSummary = false;
          // Create a more user-friendly error message
          _summaryError = 'Unable to load attendance data. Please try again later.';
        });
      }
    }
  }
  
  // Create a default attendance summary when the API fails
  AttendanceSummary _createDefaultAttendanceSummary() {
    return AttendanceSummary(
      employeeId: widget.employeeId,
      employeeName: widget.employeeName,
      startDate: _startDate,
      endDate: _endDate,
      totalWorkingDays: 0,
      daysPresent: 0,
      daysAbsent: 0,
      daysLate: 0,
      attendancePercentage: 0,
      totalHoursWorked: 0,
      averageHoursPerDay: 0,
      totalOvertimeHours: 0,
      attendanceDetails: [],
    );
  }
  
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked.start != _startDate || picked?.end != _endDate) {
      setState(() {
        _startDate = picked!.start;
        _endDate = picked.end;
      });
      
      // Reload attendance data
      _fetchAttendanceSummary();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Check if there's a time inconsistency in the data
    bool hasTimeInconsistency = false;
    if (_attendanceSummary != null) {
      if (_attendanceSummary!.totalHoursWorked < 0 || 
          _attendanceSummary!.averageHoursPerDay < 0) {
        hasTimeInconsistency = true;
      }
      
      // Check attendance details
      for (var detail in _attendanceSummary!.attendanceDetails) {
        if (detail.checkOutTime != null && 
            detail.checkInTime.isAfter(detail.checkOutTime!)) {
          hasTimeInconsistency = true;
          break;
        }
      }
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Attendance',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Employee name header
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Attendance for ${widget.employeeName}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                
                // Warning banner for time inconsistency
                if (hasTimeInconsistency)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber.shade800,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Time Inconsistency Detected',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Some check-in/out times appear incorrect. This may affect hour calculations.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Date range selector
                _buildDateRangeSelector(),
                
                const SizedBox(height: 16),
                
                // Active Attendance Card
                _buildActiveAttendanceCard(),
                
                const SizedBox(height: 16),
                
                // Attendance Summary Card
                _buildAttendanceSummaryCard(),
                
                const SizedBox(height: 16),
                
                // Attendance Details
                if (_attendanceSummary != null && 
                    _attendanceSummary!.attendanceDetails.isNotEmpty)
                  _buildAttendanceDetailsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildDateRangeSelector() {
    return Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.date_range,
                  color: AppTheme.primaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Date Range',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _selectDateRange(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${DateFormat('MMM d, yyyy').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Icon(
                      Icons.calendar_today,
                      color: AppTheme.primaryBlue,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActiveAttendanceCard() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_filled_rounded,
                  color: AppTheme.primaryOrange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Active Attendance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          
          // Show loading indicator
          if (_loadingActiveAttendance)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryOrange),
                  ),
                ),
              ),
            ),
            
          // Show error if any
          if (_activeAttendanceError.isNotEmpty && !_loadingActiveAttendance)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No active attendance found',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
          // Show active attendance details
          if (_activeAttendance != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.shade50,
                      Colors.green.shade100.withValues(alpha:0.5),
                    ],
                  ),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Currently Checked In',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      icon: Icons.schedule_rounded,
                      label: 'Check-in Time',
                      value: DateFormat('MMM d, yyyy - hh:mm a').format(_activeAttendance!.checkInTime),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      icon: Icons.business_center_rounded,
                      label: 'Shift',
                      value: 'Shift #${_activeAttendance!.shiftName}',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      icon: Icons.timelapse_rounded,
                      label: 'Duration',
                      value: _getActiveDuration(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildAttendanceSummaryCard() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.assessment_rounded,
                  color: AppTheme.primaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Attendance Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          
          // Show loading indicator
          if (_loadingSummary)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                  ),
                ),
              ),
            ),
            
          // Show error if any
          if (_summaryError.isNotEmpty && !_loadingSummary)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _summaryError,
                        style: TextStyle(
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
          // Show attendance summary
          if (_attendanceSummary != null && !_loadingSummary)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date period info
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
                          'Period: ${DateFormat('dd MMM').format(_attendanceSummary!.startDate)} - ${DateFormat('dd MMM yyyy').format(_attendanceSummary!.endDate)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Attendance percentage
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getAttendanceColor(_attendanceSummary!.attendancePercentage).withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${_attendanceSummary!.attendancePercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _getAttendanceColor(_attendanceSummary!.attendancePercentage),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Attendance Rate',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Statistics grid
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStatCard(
                        title: 'Total Working Days',
                        value: '${_attendanceSummary!.totalWorkingDays}',
                        icon: Icons.calendar_month_rounded,
                        color: AppTheme.primaryBlue,
                      ),
                      _buildStatCard(
                        title: 'Days Present',
                        value: '${_attendanceSummary!.daysPresent}',
                        icon: Icons.check_circle_rounded,
                        color: Colors.green.shade700,
                      ),
                      _buildStatCard(
                        title: 'Days Absent',
                        value: '${_attendanceSummary!.daysAbsent}',
                        icon: Icons.cancel_rounded,
                        color: Colors.red.shade700,
                      ),
                      _buildStatCard(
                        title: 'Late Days',
                        value: '${_attendanceSummary!.daysLate}',
                        icon: Icons.watch_later_rounded,
                        color: Colors.orange.shade700,
                      ),
                      _buildStatCard(
                        title: 'Total Hours',
                        value: _formatHours(_attendanceSummary!.totalHoursWorked),
                        icon: Icons.access_time_rounded,
                        color: Colors.teal.shade700,
                      ),
                      _buildStatCard(
                        title: 'Avg. Hours/Day',
                        value: _formatHours(_attendanceSummary!.averageHoursPerDay),
                        icon: Icons.bar_chart_rounded,
                        color: Colors.purple.shade700,
                      ),
                    ],
                  ),
                  
                  // Show note for negative hours if needed
                  if (_attendanceSummary!.totalHoursWorked < 0 || _attendanceSummary!.averageHoursPerDay < 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.amber.shade800),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '* Values with asterisk indicate time inconsistency in check-in/out records.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildAttendanceDetailsList() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.list_alt_rounded,
                  color: AppTheme.primaryOrange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Attendance Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_attendanceSummary!.attendanceDetails.length} Records',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Period info
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
                    'Period: ${DateFormat('dd MMM').format(_attendanceSummary!.startDate)} - ${DateFormat('dd MMM yyyy').format(_attendanceSummary!.endDate)}',
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
          
          // Divider
          Divider(color: Colors.grey.shade200, height: 1),
          
          // Attendance items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _attendanceSummary!.attendanceDetails.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.grey.shade200,
              height: 1,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final attendance = _attendanceSummary!.attendanceDetails[index];
              return _buildAttendanceItem(attendance);
            },
          ),
          
          // Bottom padding
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Widget _buildAttendanceItem(AttendanceDetail attendance) {
    // Format dates
    final checkInDate = DateFormat('MMM d').format(attendance.checkInTime);
    final checkInTime = DateFormat('h:mm a').format(attendance.checkInTime);
    final checkOutTime = attendance.checkOutTime != null
        ? DateFormat('h:mm a').format(attendance.checkOutTime!)
        : '--:--';
    
    // Check for time inconsistency
    bool hasTimeInconsistency = attendance.checkOutTime != null && 
        attendance.checkInTime.isAfter(attendance.checkOutTime!);
    
    // Status color
    Color statusColor;
    String statusText;
    
    if (attendance.status == 'Completed') {
      statusColor = Colors.green.shade700;
      statusText = 'Completed';
    } else if (attendance.status == 'InProgress') {
      statusColor = Colors.blue.shade700;
      statusText = 'In Progress';
    } else {
      statusColor = Colors.grey.shade700;
      statusText = attendance.status;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with date and status
          Row(
            children: [
              // Date badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      checkInDate,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Shift info
              Text(
                'Shift #${attendance.shiftName}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Time and hours info in a card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                // Check-in and check-out times
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CHECK-IN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha:0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.login_rounded,
                                  color: Colors.green.shade600,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                checkInTime,
                                style: TextStyle(
                                  fontSize: 14,
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
                      height: 24,
                      width: 1,
                      color: Colors.grey.shade300,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              'CHECK-OUT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha:0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.logout_rounded,
                                    color: Colors.red.shade600,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  checkOutTime,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
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
                
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                // Hours and indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Hours worked
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.timelapse_rounded,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HOURS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              hasTimeInconsistency 
                                  ? '${attendance.totalHours.abs().toStringAsFixed(1)}*'
                                  : attendance.totalHours.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: hasTimeInconsistency 
                                    ? Colors.amber.shade800
                                    : Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    // Indicators
                    Row(
                      children: [
                        if (attendance.isLate)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.watch_later_rounded,
                                  size: 12,
                                  color: Colors.orange.shade800,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Late',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (hasTimeInconsistency)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  size: 12,
                                  color: Colors.amber.shade800,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Time Issue',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (attendance.overtimeHours > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.more_time_rounded,
                                  size: 12,
                                  color: Colors.purple.shade800,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'OT: ${attendance.overtimeHours.toStringAsFixed(1)}h',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.purple.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade800,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha:0.1),
            blurRadius: 5,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to get active attendance duration
  String _getActiveDuration() {
    if (_activeAttendance == null) return '0h 0m';
    
    final now = DateTime.now();
    final checkIn = _activeAttendance!.checkInTime;
    final difference = now.difference(checkIn);
    
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    
    return '${hours}h ${minutes}m';
  }
  
  // Helper method to get color based on attendance percentage
  Color _getAttendanceColor(double percentage) {
    if (percentage >= 90) {
      return Colors.green.shade700;
    } else if (percentage >= 75) {
      return Colors.lightGreen.shade700;
    } else if (percentage >= 50) {
      return Colors.orange.shade700;
    } else {
      return Colors.red.shade700;
    }
  }
  
  // Helper method to format hours - handles negative values
  String _formatHours(double hours) {
    // Handle negative hours (time inconsistency)
    if (hours < 0) {
      return '${hours.abs().toStringAsFixed(1)}*';
    }
    return hours.toStringAsFixed(1);
  }
  
  // Handle authentication error by redirecting to login
  void _handleAuthError() {
    print('🔒 Authentication error detected, redirecting to login');
    
    // Clear the auth token
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(ApiConstants.authTokenKey);
      
      // Redirect to login screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
        
        // Show a snackbar on the login screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please log in again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }
} 