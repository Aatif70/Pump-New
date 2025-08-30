import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/services.dart';

import '../../api/api_constants.dart';
import '../../models/employee_model.dart';
import '../../models/employee_performance_report_model.dart';
import '../../theme.dart';
import '../../utils/shared_prefs.dart';

class EmployeePerformanceReportScreen extends StatefulWidget {
  const EmployeePerformanceReportScreen({super.key});

  @override
  State<EmployeePerformanceReportScreen> createState() => _EmployeePerformanceReportScreenState();
}

class _EmployeePerformanceReportScreenState extends State<EmployeePerformanceReportScreen> {
  bool _isLoading = false;
  bool _generatingPdf = false;
  String _errorMessage = '';
  
  EmployeePerformanceReport? _report;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _selectedEmployeeId;
  
  List<Employee> _employees = [];
  String? _petrolPumpId;
  
  @override
  void initState() {
    super.initState();
    _initScreen();
  }
  
  Future<void> _initScreen() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get the petrol pump ID
      _petrolPumpId = await SharedPrefs.getPumpId();
      
      // Load employees
      await _loadEmployees();
      
      // No need to load report initially, wait for user to select an employee
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize screen: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadEmployees() async {
    try {
      final authToken = await SharedPrefs.getAuthToken();
      if (authToken == null) {
        setState(() {
          _errorMessage = 'Authentication token not found';
        });
        return;
      }
      
      final response = await http.get(
        Uri.parse(ApiConstants.getEmployeeUrl()),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          print('Employee API Response: ${response.body}');
          
          if (responseData['success'] == true && responseData['data'] != null) {
            final employeesList = List<Map<String, dynamic>>.from(responseData['data']);
            
            List<Employee> employees = [];
            for (var employeeJson in employeesList) {
              try {
                employees.add(Employee.fromJson(employeeJson));
              } catch (e) {
                print('Error parsing employee: $e');
                print('Employee data: $employeeJson');
                // Continue with next employee
              }
            }
            
            setState(() {
              _employees = employees;
              if (_employees.isEmpty) {
                _errorMessage = 'No employees found';
              }
            });
          } else {
            setState(() {
              _errorMessage = responseData['message'] ?? 'Failed to load employees';
            });
          }
        } catch (e) {
          setState(() {
            _errorMessage = 'Error parsing employee data: $e';
          });
          print('JSON parse error: $e');
          print('Response body: ${response.body}');
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load employees: ${response.statusCode}';
        });
        print('HTTP Error: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading employees: $e';
      });
      print('Exception in _loadEmployees: $e');
    }
  }
  
  // Update selected employee ID and automatically load report
  void _updateSelectedEmployee(String? employeeId) {
    if (employeeId != null && employeeId != _selectedEmployeeId) {
      setState(() {
        _selectedEmployeeId = employeeId;
      });
      _loadReport();
    }
  }
  
  Future<void> _loadReport() async {
    if (_selectedEmployeeId == null) {
      setState(() {
        _errorMessage = 'Please select an employee first';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _report = null;
    });
    
    try {
      final authToken = await SharedPrefs.getAuthToken();
      if (authToken == null) {
        setState(() {
          _errorMessage = 'Authentication token not found';
          _isLoading = false;
        });
        return;
      }
      
      final url = ApiConstants.getEmployeePerformanceReportUrl(
        _startDate, 
        _endDate, 
        _selectedEmployeeId!
      );
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final performanceResponse = EmployeePerformanceResponse.fromJson(responseData);
        
        setState(() {
          _isLoading = false;
          if (performanceResponse.success && performanceResponse.data.isNotEmpty) {
            _report = performanceResponse.data.first;
          } else {
            _errorMessage = performanceResponse.message;
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load report: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }
  
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
      if (_selectedEmployeeId != null) {
        _loadReport();
      }
    }
  }
  
  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
      if (_selectedEmployeeId != null) {
        _loadReport();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Employee Performance'),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          if (_report != null) // Only show export button when report is available
            _generatingPdf 
              ? Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  width: 24,
                  height: 24,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.0,
                  ),
                )
              : IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'Export to PDF',
                onPressed: () => _exportToPdf(context),
              ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: _isLoading 
                ? _buildLoadingIndicator()
                : _errorMessage.isNotEmpty 
                  ? _buildErrorDisplay()
                  : _report == null
                    ? _buildNoDataDisplay()
                    : _buildReport(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEmployeeDropdown(),
          const SizedBox(height: 16),
          Text(
            'Select Date Range',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectStartDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd MMM yyyy').format(_startDate),
                          style: const TextStyle(fontSize: 14),
                        ),
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _selectEndDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd MMM yyyy').format(_endDate),
                          style: const TextStyle(fontSize: 14),
                        ),
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmployeeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Employee',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedEmployeeId,
              isExpanded: true,
              hint: Text(
                'Select Employee', 
                style: TextStyle(color: Colors.grey.shade600),
              ),
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
              items: _employees.map((employee) {
                return DropdownMenuItem<String>(
                  value: employee.id,
                  child: Text(
                    '${employee.firstName} ${employee.lastName}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                    ),
                  ),
                );
              }).toList(),
              onChanged: _updateSelectedEmployee,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading report data...',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorDisplay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load report',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _selectedEmployeeId != null ? _loadReport : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNoDataDisplay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Performance Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Select an employee and date range to view performance data.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReport() {
    if (_report == null) return const SizedBox.shrink();
    
    final report = _report!;
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final volumeFormat = NumberFormat('#,##0.00');
    
    return RefreshIndicator(
      onRefresh: _loadReport,
      color: AppTheme.primaryBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReportHeader(report),
            const SizedBox(height: 24),
            _buildPerformanceSummary(report),
            // const SizedBox(height: 24),
            // _buildRankingSection(report),
            const SizedBox(height: 24),
            _buildDailyPerformanceSection(report),
            // const SizedBox(height: 24),
            // _buildFuelTypeExpertiseSection(report),
          ],
        ),
      ),
    );
  }
  
  Widget _buildReportHeader(EmployeePerformanceReport report) {
    final startDate = DateFormat('d MMM yyyy').format(
      DateTime.tryParse(report.reportPeriodStart) ?? _startDate
    );
    
    final endDate = DateFormat('d MMM yyyy').format(
      DateTime.tryParse(report.reportPeriodEnd) ?? _endDate
    );
    
    final generatedAt = DateFormat('d MMM yyyy, h:mm a').format(
      DateTime.tryParse(report.generatedAt) ?? DateTime.now()
    );
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person,
                    color: AppTheme.primaryBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.employeeName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          report.role,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generated',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Text(
                            generatedAt,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPerformanceSummary(EmployeePerformanceReport report) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final volumeFormat = NumberFormat('#,##0.00');
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  'Performance Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(
              'Total Volume Dispensed',
              '${volumeFormat.format(report.totalVolume)} L',
              Icons.local_gas_station,
              Colors.blue.shade700,
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              'Total Sales',
              currencyFormat.format(report.totalValue),
              Icons.attach_money,
              Colors.green.shade700,
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              'Total Transactions',
              report.totalTransactions.toString(),
              Icons.receipt_long,
              Colors.purple.shade700,
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              'Avg. Transaction Value',
              currencyFormat.format(report.averageTransactionValue),
              Icons.trending_up,
              Colors.orange.shade700,
            ),
            if (report.totalHoursWorked > 0) ...[
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Hours Worked',
                '${report.totalHoursWorked} hrs',
                Icons.access_time,
                Colors.indigo.shade700,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
  
  // Widget _buildRankingSection(EmployeePerformanceReport report) {
  //   return Card(
  //     elevation: 1,
  //     shape: RoundedRectangleBorder(
  //       borderRadius: BorderRadius.circular(12),
  //     ),
  //     child: Padding(
  //       padding: const EdgeInsets.all(16),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Row(
  //             children: [
  //               Icon(Icons.leaderboard, color: AppTheme.primaryBlue),
  //               const SizedBox(width: 8),
  //               Text(
  //                 'Rankings (out of ${report.ranking.totalEmployees})',
  //                 style: TextStyle(
  //                   fontSize: 16,
  //                   fontWeight: FontWeight.bold,
  //                   color: Colors.grey.shade800,
  //                 ),
  //               ),
  //             ],
  //           ),
  //           const SizedBox(height: 20),
  //           _buildRankingRow('Overall Performance', report.ranking.overallRank, Colors.blue),
  //           const SizedBox(height: 16),
  //           _buildRankingRow('Volume Dispensed', report.ranking.volumeRank, Colors.green),
  //           const SizedBox(height: 16),
  //           _buildRankingRow('Revenue Generated', report.ranking.revenueRank, Colors.purple),
  //           const SizedBox(height: 16),
  //           _buildRankingRow('Efficiency Rating', report.ranking.efficiencyRank, Colors.orange),
  //         ],
  //       ),
  //     ),
  //   );
  // }
  //
  Widget _buildRankingRow(String label, int rank, MaterialColor color) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color.shade700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
              if (rank <= 3)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: rank == 1 ? Colors.amber.withValues(alpha:0.2) : 
                           rank == 2 ? Colors.blueGrey.withValues(alpha:0.2) : 
                           Colors.brown.withValues(alpha:0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    rank == 1 ? 'Top Performer' : 
                    rank == 2 ? 'Outstanding' : 
                    'Excellent',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: rank == 1 ? Colors.amber.shade800 : 
                             rank == 2 ? Colors.blueGrey.shade800 : 
                             Colors.brown.shade800,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Icon(
          rank <= 3 ? Icons.emoji_events : Icons.arrow_forward_ios,
          color: rank <= 3 ? Colors.amber.shade700 : Colors.grey.shade400,
          size: rank <= 3 ? 22 : 16,
        ),
      ],
    );
  }
  
  Widget _buildDailyPerformanceSection(EmployeePerformanceReport report) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final volumeFormat = NumberFormat('#,##0');
    
    // Sort daily performance by date
    final sortedDailyPerformance = List<DailyPerformance>.from(report.dailyPerformance)
      ..sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  'Daily Performance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (sortedDailyPerformance.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No daily performance data available',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              Container(
                height: 220,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildDailyPerformanceChart(sortedDailyPerformance),
              ),
            const SizedBox(height: 16),
            if (sortedDailyPerformance.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateColor.resolveWith(
                      (states) => Colors.grey.shade100,
                    ),
                    headingTextStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                      fontSize: 13,
                    ),
                    dataTextStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                    columnSpacing: 24,
                    horizontalMargin: 16,
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Volume')),
                      DataColumn(label: Text('Value')),
                      DataColumn(label: Text('Transactions')),
                      // DataColumn(label: Text('Efficiency')),
                    ],
                    rows: sortedDailyPerformance.map((daily) {
                      final date = DateTime.parse(daily.date);
                      final formattedDate = DateFormat('dd MMM').format(date);
                      
                      return DataRow(
                        cells: [
                          DataCell(Text(formattedDate)),
                          DataCell(Text('${volumeFormat.format(daily.volume)} L')),
                          DataCell(Text(currencyFormat.format(daily.value))),
                          DataCell(Text('${daily.transactionCount}')),
                          // DataCell(
                          //   Row(
                          //     children: [
                          //       Text('${daily.efficiency.toStringAsFixed(2)}'),
                          //       const SizedBox(width: 4),
                          //       Icon(
                          //         daily.efficiency >= 1.0 ? Icons.trending_up : Icons.trending_down,
                          //         color: daily.efficiency >= 1.0 ? Colors.green : Colors.red,
                          //         size: 16,
                          //       )
                          //     ],
                          //   ),
                          // ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildDailyPerformanceChart(List<DailyPerformance> performances) {
    if (performances.isEmpty) return const SizedBox.shrink();
    
    final maxValue = performances
        .map((e) => e.value)
        .reduce((value, element) => value > element ? value : element);
    
    final maxVolume = performances
        .map((e) => e.volume)
        .reduce((value, element) => value > element ? value : element);
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < performances.length) {
                  final date = DateTime.parse(performances[value.toInt()].date);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('dd/MM').format(date),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxValue / 4,
              getTitlesWidget: (value, meta) {
                return Text(
                  NumberFormat.compact().format(value),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300, width: 1),
            left: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        minX: 0,
        maxX: performances.length - 1,
        minY: 0,
        maxY: maxValue * 1.2,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                final isVolume = spot.barIndex == 1;
                final performance = performances[index];
                final date = DateFormat('dd MMM').format(DateTime.parse(performance.date));
                
                if (isVolume) {
                  return LineTooltipItem(
                    '$date\n${NumberFormat('#,##0.0').format(performance.volume)} L',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                } else {
                  return LineTooltipItem(
                    '$date\n₹${NumberFormat('#,##0').format(performance.value)}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }
              }).toList();
            }
          ),
        ),
        lineBarsData: [
          // Value line
          LineChartBarData(
            spots: List.generate(performances.length, (index) {
              return FlSpot(index.toDouble(), performances[index].value);
            }),
            isCurved: true,
            color: Colors.blue.shade600,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => 
                FlDotCirclePainter(
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                  color: Colors.blue.shade600,
                ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.shade200.withValues(alpha:0.3),
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade200.withValues(alpha:0.3),
                  Colors.blue.shade200.withValues(alpha:0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Volume line
          LineChartBarData(
            spots: List.generate(performances.length, (index) {
              return FlSpot(index.toDouble(), performances[index].volume / maxVolume * maxValue);
            }),
            isCurved: true,
            color: Colors.green.shade600,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => 
                FlDotCirclePainter(
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                  color: Colors.green.shade600,
                ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.shade200.withValues(alpha:0.3),
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade200.withValues(alpha:0.3),
                  Colors.green.shade200.withValues(alpha:0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Widget _buildFuelTypeExpertiseSection(EmployeePerformanceReport report) {
  //   final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  //   final volumeFormat = NumberFormat('#,##0.00');
  //
  //   return Card(
  //     elevation: 2,
  //     shape: RoundedRectangleBorder(
  //       borderRadius: BorderRadius.circular(12),
  //     ),
  //     child: Padding(
  //       padding: const EdgeInsets.all(16),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           // Title with gradient background
  //           Container(
  //             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  //             decoration: BoxDecoration(
  //               gradient: LinearGradient(
  //                 colors: [
  //                   AppTheme.primaryBlue.withValues(alpha:0.8),
  //                   AppTheme.primaryBlue.withValues(alpha:0.6),
  //                 ],
  //               ),
  //               borderRadius: BorderRadius.circular(8),
  //             ),
  //             child: Row(
  //               children: [
  //                 Container(
  //                   padding: const EdgeInsets.all(8),
  //                   decoration: BoxDecoration(
  //                     color: Colors.white.withValues(alpha:0.2),
  //                     borderRadius: BorderRadius.circular(8),
  //                   ),
  //                   child: const Icon(
  //                     Icons.local_gas_station,
  //                     color: Colors.white,
  //                     size: 20,
  //                   ),
  //                 ),
  //                 // const SizedBox(width: 12),
  //                 // const Text(
  //                 //   'Fuel Type Expertise',
  //                 //   style: TextStyle(
  //                 //     fontSize: 16,
  //                 //     fontWeight: FontWeight.bold,
  //                 //     color: Colors.white,
  //                 //   ),
  //                 // ),
  //               ],
  //             ),
  //           ),
  //           const SizedBox(height: 20),
  //           if (report.fuelTypeExpertise.isEmpty)
  //             Center(
  //               child: Padding(
  //                 padding: const EdgeInsets.all(16.0),
  //                 child: Text(
  //                   'No fuel type data available',
  //                   style: TextStyle(color: Colors.grey.shade600),
  //                 ),
  //               ),
  //             )
  //           else
  //             _buildFuelTypeDetailCards(report.fuelTypeExpertise),
  //         ],
  //       ),
  //     ),
  //   );
  // }
  //
  Widget _buildFuelTypeDetailCards(List<FuelTypeExpertise> fuelTypes) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final volumeFormat = NumberFormat('#,##0.00');
    final percentFormat = NumberFormat.percentPattern();
    
    // Sort fuel types by volume in descending order
    final sortedFuelTypes = List<FuelTypeExpertise>.from(fuelTypes)
      ..sort((a, b) => b.volume.compareTo(a.volume));
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedFuelTypes.length,
      itemBuilder: (context, index) {
        final item = sortedFuelTypes[index];
        final color = _getFuelTypeColor(item.fuelType ?? 'Unknown');
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha:0.1),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha:0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.local_gas_station,
                        color: color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.fuelType ?? 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          Text(
                            '${percentFormat.format(item.percentageOfTotalVolume)} of total volume',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Progress bar showing percentage of total
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.percentageOfTotalVolume,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 16),
                // Stats grid
                Row(
                  children: [
                    _buildStatItem(
                      'Volume',
                      '${volumeFormat.format(item.volume)} L',
                      Icons.speed,
                      color,
                    ),
                    const SizedBox(width: 12),
                    _buildStatItem(
                      'Value',
                      currencyFormat.format(item.value),
                      Icons.currency_rupee,
                      color,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatItem(
                      'Transaction',
                      '${item.transactionCount}',
                      Icons.receipt,
                      color,
                    ),
                    const SizedBox(width: 12),
                    _buildStatItem(
                      'Avg. Price',
                      currencyFormat.format(item.averagePrice),
                      Icons.trending_up,
                      color,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
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
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getFuelTypeColor(String fuelType) {
    // Map common fuel types to distinct colors
    switch (fuelType.toLowerCase()) {
      case 'petrol':
      case 'gasoline':
        return Colors.green.shade500;
      case 'diesel':
        return Colors.orange.shade500;
      case 'kerosene':
        return Colors.blue.shade500;
      case 'cng':
      case 'natural gas':
        return Colors.purple.shade500;
      case 'lpg':
        return Colors.red.shade500;
      case 'premium petrol':
      case 'premium gasoline':
        return Colors.green.shade700;
      case 'premium diesel':
        return Colors.orange.shade700;
      case 'biofuel':
      case 'ethanol':
        return Colors.teal.shade500;
      default:
        // Generate a color based on the string hash value for unknown types
        final hash = fuelType.hashCode;
        return Color(0xFF000000 + (hash % 0xFFFFFF));
    }
  }

  // PDF Export functionality
  Future<void> _exportToPdf(BuildContext context) async {
    if (_report == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report data available to export')),
      );
      return;
    }
    
    setState(() {
      _generatingPdf = true;
    });
    
    // Show a notification that PDF generation has started
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF report...'),
          duration: Duration(seconds: 1),
        ),
      );
    }
    
    try {
      final pdfBytes = await _generatePdf();
      final directory = await getApplicationDocumentsDirectory();
      final employeeName = _report!.employeeName.replaceAll(' ', '_');
      final fileName = 'performance_report_${employeeName}_${DateFormat('yyyyMMdd').format(_startDate)}_${DateFormat('yyyyMMdd').format(_endDate)}.pdf';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsBytes(pdfBytes);
      
      // Show a dialog with options to view or share
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('PDF Generated'),
            content: const Text('Report has been generated successfully. What would you like to do with it?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _viewPdf(pdfBytes);
                },
                child: const Text('View'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _sharePdf(file);
                },
                child: const Text('Share'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generatingPdf = false;
        });
      }
    }
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    final report = _report!;
    
    // Load images for PDF
    final PdfColor headerColor = PdfColor.fromHex('#0066cc'); // AppTheme.primaryBlue equivalent
    final currencyFormat = NumberFormat.currency(symbol: 'Rs.', decimalDigits: 2);
    final volumeFormat = NumberFormat('#,##0.00');

    // Try to load placeholder image if available
    pw.MemoryImage? employeeImage;
    try {
      employeeImage = pw.MemoryImage(
        (await rootBundle.load('assets/images/user_placeholder.png')).buffer.asUint8List(),
      );
    } catch (e) {
      // Silently handle image loading failure
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Employee Performance Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: headerColor,
                    ),
                  ),
                  pw.Text(
                    DateFormat('dd/MM/yyyy').format(DateTime.now()),
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Divider(color: PdfColors.black),
              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          );
        },
        build: (pw.Context context) => [
          // Employee Details Section
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [

                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        report.employeeName,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        report.role,
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Report Period: ',
                            style:  pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Performance Summary Section
          pw.Header(
            level: 1,
            text: 'Performance Summary',
            textStyle: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              children: [
                _buildPdfSummaryRow('Total Volume Dispensed:', '${volumeFormat.format(report.totalVolume)} L'),
                _buildPdfSummaryRow('Total Sales:', currencyFormat.format(report.totalValue)),
                _buildPdfSummaryRow('Total Transactions:', report.totalTransactions.toString()),
                // _buildPdfSummaryRow('Avg. Transaction Value:', currencyFormat.format(report.averageTransactionValue)),
                if (report.totalHoursWorked > 0) ...[
                  _buildPdfSummaryRow('Hours Worked:', '${report.totalHoursWorked} hrs'),
                  // _buildPdfSummaryRow('Volume Per Hour:', '${volumeFormat.format(report.volumePerHour)} L/hr'),
                  // _buildPdfSummaryRow('Revenue Per Hour:', currencyFormat.format(report.revenuePerHour)),
                ],
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Rankings Section
          // pw.Header(
          //   level: 1,
          //   text: 'Rankings',
          //   textStyle: pw.TextStyle(
          //     fontSize: 18,
          //     fontWeight: pw.FontWeight.bold,
          //     color: PdfColors.black,
          //   ),
          // ),
          // pw.SizedBox(height: 10),
          // pw.Container(
          //   padding: const pw.EdgeInsets.all(16),
          //   decoration: pw.BoxDecoration(
          //     border: pw.Border.all(color: PdfColors.grey300),
          //     borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          //   ),
          //   child: pw.Column(
          //     children: [
          //       _buildPdfRankingRow('Overall Performance', report.ranking.overallRank, report.ranking.totalEmployees),
          //       _buildPdfRankingRow('Volume Dispensed', report.ranking.volumeRank, report.ranking.totalEmployees),
          //       _buildPdfRankingRow('Revenue Generated', report.ranking.revenueRank, report.ranking.totalEmployees),
          //       // _buildPdfRankingRow('Efficiency Rating', report.ranking.efficiencyRank, report.ranking.totalEmployees),
          //     ],
          //   ),
          // ),

          // Add a page break here to start Daily Performance on a new page
          // pw.NewPage(),

          // Daily Performance Section
          pw.Header(
            level: 1,
            text: 'Daily Performance',
            textStyle: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 10),

          if (report.dailyPerformance.isEmpty)
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(16),
              child: pw.Text('No daily performance data available'),
            )
          else
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Table(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey300),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(3),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Table header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildPdfTableCell('Date', isHeader: true),
                      _buildPdfTableCell('Volume', isHeader: true),
                      _buildPdfTableCell('Value', isHeader: true),
                      _buildPdfTableCell('Trans.', isHeader: true),
                      // _buildPdfTableCell('Efficiency', isHeader: true),
                    ],
                  ),
                  // Table rows
                  ...List<pw.TableRow>.generate(report.dailyPerformance.length, (index) {
                    final daily = report.dailyPerformance[index];
                    final date = DateTime.parse(daily.date);
                    final formattedDate = DateFormat('dd MMM').format(date);

                    return pw.TableRow(
                      children: [
                        _buildPdfTableCell(formattedDate),
                        _buildPdfTableCell('${volumeFormat.format(daily.volume)} L'),
                        _buildPdfTableCell(currencyFormat.format(daily.value)),
                        _buildPdfTableCell('${daily.transactionCount}'),
                        // _buildPdfTableCell('${daily.efficiency.toStringAsFixed(2)}'),
                      ],
                    );
                  }),
                ],
              ),
            ),

          pw.SizedBox(height: 20),

          // Add a page break here to start Fuel Type Expertise on a new page
          // pw.NewPage(),

          // Fuel Type Expertise Section
          // pw.Header(
          //   level: 1,
          //   text: 'Fuel Type Expertise',
          //   textStyle: pw.TextStyle(
          //     fontSize: 18,
          //     fontWeight: pw.FontWeight.bold,
          //     color: PdfColors.black,
          //   ),
          // ),
          // pw.SizedBox(height: 10),
          
          // if (report.fuelTypeExpertise.isEmpty)
          //   pw.Container(
          //     alignment: pw.Alignment.center,
          //     padding: const pw.EdgeInsets.all(16),
          //     child: pw.Text('No fuel type data available'),
          //   )
          // else
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Table(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey300),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(3),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Table header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildPdfTableCell('Fuel Type', isHeader: true),
                      _buildPdfTableCell('Volume', isHeader: true),
                      _buildPdfTableCell('Value', isHeader: true),
                      _buildPdfTableCell('Trans.', isHeader: true),
                      // _buildPdfTableCell('Avg. Price', isHeader: true),
                    ],
                  ),
                  // Table rows
                  ...List<pw.TableRow>.generate(report.fuelTypeExpertise.length, (index) {
                    final fuel = report.fuelTypeExpertise[index];
                    return pw.TableRow(
                      children: [
                        _buildPdfTableCell(fuel.fuelType ?? 'Unknown'),
                        _buildPdfTableCell('${volumeFormat.format(fuel.volume)} L'),
                        _buildPdfTableCell(currencyFormat.format(fuel.value)),
                        _buildPdfTableCell('${fuel.transactionCount}'),
                        _buildPdfTableCell(currencyFormat.format(fuel.averagePrice)),
                      ],
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
    
    return pdf.save();
  }
  
  pw.Widget _buildPdfSummaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(value),
        ],
      ),
    );
  }
  
  pw.Widget _buildPdfRankingRow(String label, int rank, int totalEmployees) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        children: [
          pw.Container(
            width: 32,
            height: 32,
            decoration: pw.BoxDecoration(
              color: rank <= 3 ? PdfColor.fromHex('#ffd700') : PdfColors.grey300,
              shape: pw.BoxShape.circle,
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              '#$rank',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: rank <= 3 ? PdfColors.black : PdfColors.grey700,
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Text(label),
          ),
          pw.Text(
            '$rank of $totalEmployees',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  pw.Widget _buildPdfTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : null,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }
  
  Future<void> _viewPdf(Uint8List pdfBytes) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }
  
  Future<void> _sharePdf(File file) async {
    final result = await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Employee Performance Report',
    );
    
    if (result.status != ShareResultStatus.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share the PDF file')),
        );
      }
    }
  }
} 