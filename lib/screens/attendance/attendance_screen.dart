import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petrol_pump/api/attendance_repository.dart';
import 'package:petrol_pump/models/attendance_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/api_response.dart';
import '../../theme.dart';
import '../../utils/shared_prefs.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AttendanceRepository _attendanceRepository = AttendanceRepository();

  DateTime _selectedDate = DateTime.now();
  String _petrolPumpId = '';
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Data
  List<EmployeeAttendance> _dailyAttendances = [];
  List<EmployeeAttendance> _lateArrivals = [];
  DailyAttendanceReport? _dailyReport;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPetrolPumpId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPetrolPumpId() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final pumpId = await SharedPrefs.getPumpId();
      
      if (pumpId != null && pumpId.isNotEmpty) {
        setState(() {
          _petrolPumpId = pumpId;
        });
        _loadData();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to get petrol pump ID. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Load daily attendance
      final dailyResponse = await _attendanceRepository.getDailyAttendance(_selectedDate, _petrolPumpId);
      
      // Load daily report
      final reportResponse = await _attendanceRepository.getDailyAttendanceReport(_selectedDate, _petrolPumpId);
      
      // Load late arrivals
      final lateArrivalsResponse = await _attendanceRepository.getLateArrivals(_selectedDate, _petrolPumpId);
      
      setState(() {
        _isLoading = false;
        
        if (dailyResponse.success) {
          _dailyAttendances = dailyResponse.data ?? [];
        } else {
          _errorMessage = dailyResponse.errorMessage ?? 'Failed to load attendance data';
        }
        
        if (reportResponse.success) {
          _dailyReport = reportResponse.data;
        } else {
          // Only show error if both calls failed
          if (!dailyResponse.success) {
            _errorMessage = reportResponse.errorMessage ?? 'Failed to load attendance report';
          }
        }
        
        if (lateArrivalsResponse.success) {
          _lateArrivals = lateArrivalsResponse.data ?? [];
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
            tooltip: 'Select Date',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Daily Attendance'),
            Tab(text: 'Summary Report'),
            Tab(text: 'Late Comers'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red[800]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDailyAttendanceTab(),
                    _buildSummaryReportTab(),
                    _buildLateComersTab(),
                  ],
                ),
    );
  }

  Widget _buildDailyAttendanceTab() {
    if (_dailyAttendances.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No attendance records found for\n${DateFormat('dd MMM, yyyy').format(_selectedDate)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _dailyAttendances.length,
        padding: const EdgeInsets.all(12.0),
        itemBuilder: (context, index) {
          final attendance = _dailyAttendances[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _getStatusColor(attendance.status).withValues(alpha:0.2),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _getStatusColor(attendance.status).withValues(alpha:0.1),
                        radius: 20,
                        child: Text(
                          attendance.employeeName.isNotEmpty ? attendance.employeeName[0] : '?',
                          style: TextStyle(
                            color: _getStatusColor(attendance.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attendance.employeeName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(attendance.status).withValues(alpha:0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getStatusText(attendance.status),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getStatusColor(attendance.status),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Shift: ${attendance.shiftName}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                                if (attendance.isLate)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Late',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.amber.shade800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTimeInfoColumn(
                        'Check In',
                        attendance.checkInTime,
                        Icons.login,
                        Colors.green,
                      ),
                      _buildTimeInfoColumn(
                        'Check Out',
                        attendance.checkOutTime,
                        Icons.logout, 
                        Colors.red,
                      ),
                      _buildTimeInfoColumn(
                        'Hours',
                        attendance.totalHours != null ? '${attendance.totalHours!.toStringAsFixed(1)} hrs' : null,
                        Icons.access_time,
                        AppTheme.primaryBlue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryReportTab() {
    if (_dailyReport == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.assignment_late,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No attendance report available for\n${DateFormat('dd MMM, yyyy').format(_selectedDate)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    final report = _dailyReport!;
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Summary',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd MMMM, yyyy').format(_selectedDate),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${report.attendancePercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard(
                          'Total',
                          report.totalEmployees.toString(),
                          Colors.grey.shade700,
                          Icons.people,
                        ),
                        _buildStatCard(
                          'Present',
                          report.presentEmployees.toString(),
                          Colors.green.shade600,
                          Icons.check_circle,
                        ),
                        _buildStatCard(
                          'Absent',
                          report.absentEmployees.toString(),
                          Colors.red.shade600,
                          Icons.cancel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Attendance Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            report.attendances.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: const [
                        Icon(
                          Icons.hourglass_empty,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No attendance details available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: report.attendances.length,
                  itemBuilder: (context, index) {
                    final attendance = report.attendances[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(attendance.status).withValues(alpha:0.1),
                          child: Text(
                            attendance.employeeName.isNotEmpty ? attendance.employeeName[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: _getStatusColor(attendance.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          attendance.employeeName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  'Shift: ${attendance.shiftName}',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.login, size: 16, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  attendance.checkInTime != null
                                      ? DateFormat('hh:mm a').format(attendance.checkInTime!)
                                      : 'Not checked in',
                                  style: attendance.checkInTime != null
                                      ? TextStyle(color: Colors.grey.shade700)
                                      : TextStyle(color: Colors.red.shade400, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _getStatusColor(attendance.status).withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(attendance.status),
                            style: TextStyle(
                              color: _getStatusColor(attendance.status),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildLateComersTab() {
    if (_lateArrivals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.access_time,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No late arrivals found for\n${DateFormat('dd MMM, yyyy').format(_selectedDate)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber[700],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Late Arrivals (${_lateArrivals.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _lateArrivals.length,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemBuilder: (context, index) {
                final attendance = _lateArrivals[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.amber.shade300,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.amber.shade100,
                              radius: 20,
                              child: Text(
                                attendance.employeeName.isNotEmpty ? attendance.employeeName[0] : '?',
                                style: TextStyle(
                                  color: Colors.amber.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    attendance.employeeName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Late',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.amber.shade800,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Shift: ${attendance.shiftName}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildTimeInfoColumn(
                              'Check In',
                              attendance.checkInTime,
                              Icons.login,
                              Colors.amber.shade700,
                            ),
                            _buildTimeInfoColumn(
                              'Expected',
                              'On Time',
                              Icons.schedule,
                              Colors.grey.shade600,
                            ),
                            _buildTimeInfoColumn(
                              'Status',
                              attendance.status,
                              Icons.info_outline,
                              _getStatusColor(attendance.status),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfoColumn(String label, dynamic value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value != null
                ? (value is DateTime
                    ? DateFormat('hh:mm a').format(value)
                    : value.toString())
                : '- - -',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: value != null ? Colors.black87 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color.withValues(alpha:0.8),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green.shade600;
      case 'completed':
        return Colors.blue.shade600;
      case 'absent':
        return Colors.red.shade600;
      case 'late':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'On Duty';
      case 'completed':
        return 'Completed';
      case 'absent':
        return 'Absent';
      default:
        return status;
    }
  }
} 