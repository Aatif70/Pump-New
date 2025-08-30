import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petrol_pump/api/attendance_repository.dart';
import 'package:petrol_pump/theme.dart';
import 'package:petrol_pump/widgets/custom_snackbar.dart';
import 'dart:developer' as developer;

class EmployeeCheckOutScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final String shiftId;
  final String shiftNumber;

  const EmployeeCheckOutScreen({
    Key? key,
    required this.employeeId,
    required this.employeeName,
    required this.shiftId,
    required this.shiftNumber,
  }) : super(key: key);

  @override
  State<EmployeeCheckOutScreen> createState() => _EmployeeCheckOutScreenState();
}

class _EmployeeCheckOutScreenState extends State<EmployeeCheckOutScreen> with SingleTickerProviderStateMixin {
  final AttendanceRepository _attendanceRepository = AttendanceRepository();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  
  bool _isLoading = false;
  bool _isFetchingAttendance = false;
  bool _hasActiveAttendance = false;
  String _employeeAttendanceId = '';
  DateTime _checkOutTime = DateTime.now();
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuint,
    );
    _animationController.forward();
    _fetchActiveAttendance();
  }
  
  @override
  void dispose() {
    _locationController.dispose();
    _remarksController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchActiveAttendance() async {
    setState(() {
      _isFetchingAttendance = true;
    });

    try {
      final response = await _attendanceRepository.getActiveAttendanceId(widget.employeeId);
      
      if (response.success && response.data != null ) {
        setState(() {
          _employeeAttendanceId = response.data ?? '';
          _hasActiveAttendance = true;
        });
        developer.log('Found active attendance ID: $_employeeAttendanceId');
      } else {
        setState(() {
          _hasActiveAttendance = false;
        });
        _showMessage('No active check-in found. Please check-in first.', isError: true);
        developer.log('No active attendance found: ${response.errorMessage}');
        
        // Wait a moment to show the message before popping
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      developer.log('Error fetching active attendance: $e');
      _showMessage('Error: $e', isError: true);
      setState(() {
        _hasActiveAttendance = false;
      });
      
      // Wait a moment to show the message before popping
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingAttendance = false;
        });
      }
    }
  }

  Future<void> _submitCheckOut() async {
    if (_locationController.text.isEmpty) {
      _showMessage('Please enter your location', isError: true);
      return;
    }

    if (_employeeAttendanceId.isEmpty) {
      _showMessage('No active check-in found. Please check-in first.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _attendanceRepository.checkOut(
        employeeAttendanceId: _employeeAttendanceId,
        checkOutTime: _checkOutTime,
        checkOutLocation: _locationController.text,
        remarks: _remarksController.text,
      );
      
      if (response.success) {
        if (mounted) {
          _showMessage('Check-out successful!', isError: false);
          // Wait a moment for the user to see the success message
          await Future.delayed(const Duration(seconds: 1));
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          _showMessage('Check-out failed: ${response.errorMessage}', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    
    showCustomSnackBar(
      context: context,
      message: message,
      isError: isError,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Check-Out',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
      ),
      body: _isFetchingAttendance
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Fetching your active check-in...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Stack(
                children: [
                  // Background design elements
                  Positioned(
                    top: -50,
                    right: -50,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha:0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -80,
                    left: -80,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha:0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  
                  // Main content
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: FadeTransition(
                        opacity: _animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.1),
                            end: Offset.zero,
                          ).animate(_animation),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              
                              // Greeting and info
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryBlue,
                                      AppTheme.primaryBlue.withValues(alpha:0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryBlue.withValues(alpha:0.2),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Avatar
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha:0.2),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white.withValues(alpha:0.5), width: 2),
                                      ),
                                      child: Center(
                                        child: Text(
                                          widget.employeeName.isNotEmpty ? widget.employeeName[0].toUpperCase() : "E",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Name and shift info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Hello, ${widget.employeeName}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha:0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.access_time_rounded,
                                                      color: Colors.white,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      "Shift #${widget.shiftNumber}",
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                DateFormat('EEEE, MMM d').format(DateTime.now()),
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha:0.9),
                                                  fontSize: 12,
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
                              
                              const SizedBox(height: 30),
                              
                              // Check-out title
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha:0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.logout_rounded,
                                      color: Colors.red.shade700,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Record Check-Out",
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 5),
                              Padding(
                                padding: const EdgeInsets.only(left: 42),
                                child: Text(
                                  "Please enter the required details below",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Current Time Card
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha:0.04),
                                      blurRadius: 10,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                  border: Border.all(color: Colors.grey.shade100),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          color: AppTheme.primaryBlue,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Check-Out Time",
                                          style: TextStyle(
                                            color: Colors.grey.shade800,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.red.shade700.withValues(alpha:0.05),
                                            Colors.red.shade700.withValues(alpha:0.1),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.red.shade700.withValues(alpha:0.2),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.calendar_today_rounded,
                                                size: 16,
                                                color: Colors.red.shade700,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                DateFormat('EEEE, MMMM d, yyyy').format(_checkOutTime),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            DateFormat('hh:mm a').format(_checkOutTime),
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Center(
                                      child: Text(
                                        "Current time will be recorded as your check-out time",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Location field
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha:0.04),
                                      blurRadius: 10,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                  border: Border.all(color: Colors.grey.shade100),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          color: Colors.orange.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Your Location",
                                          style: TextStyle(
                                            color: Colors.grey.shade800,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          " *",
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _locationController,
                                      decoration: InputDecoration(
                                        hintText: "Enter your current location",
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.orange.shade300,
                                            width: 1.5,
                                          ),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.pin_drop_rounded,
                                          color: Colors.orange.shade400,
                                          size: 18,
                                        ),
                                      ),
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontSize: 14,
                                      ),
                                      minLines: 1,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Remarks field
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(bottom: 30),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha:0.04),
                                      blurRadius: 10,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                  border: Border.all(color: Colors.grey.shade100),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.note_alt_rounded,
                                          color: Colors.purple.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Remarks",
                                          style: TextStyle(
                                            color: Colors.grey.shade800,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          " (Optional)",
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _remarksController,
                                      decoration: InputDecoration(
                                        hintText: "Any comments about your check-out?",
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.purple.shade300,
                                            width: 1.5,
                                          ),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.edit_note_rounded,
                                          color: Colors.purple.shade400,
                                          size: 20,
                                        ),
                                      ),
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontSize: 14,
                                      ),
                                      minLines: 2,
                                      maxLines: 4,
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Submit Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: (_isLoading || !_hasActiveAttendance) ? null : _submitCheckOut,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.grey.shade300,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                    shadowColor: Colors.red.shade600.withValues(alpha:0.4),
                                  ),
                                  child: _isLoading
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              "Processing...",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.logout_rounded,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              "Confirm Check-Out",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 