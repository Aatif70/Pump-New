import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../api/reporting_repository.dart';
import '../../api/employee_repository.dart';
import '../../models/daily_sales_report_model.dart';
import '../../models/employee_model.dart';
import '../../theme.dart';
import '../../utils/chart_utils.dart';
import '../../utils/jwt_decoder.dart';
import '../../utils/shared_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/api_constants.dart';
// PDF generation imports
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

class DailySalesReportScreen extends StatefulWidget {
  const DailySalesReportScreen({super.key});

  @override
  State<DailySalesReportScreen> createState() => _DailySalesReportScreenState();
}

class _DailySalesReportScreenState extends State<DailySalesReportScreen> {
  final ReportingRepository _reportingRepository = ReportingRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isPdfGenerating = false;
  
  DailySalesReport? _report;
  DateTime _selectedDate = DateTime.now();
  String? _selectedEmployeeId;
  String? _selectedShiftId;
  
  List<Employee> _employees = [];
  List<dynamic> _shifts = [];
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
      print('DEBUG: DailySalesReport - Initializing screen');
      
      // Get the petrol pump ID - use more robust method
      _petrolPumpId = await _getPetrolPumpIdRobust();
      print('DEBUG: DailySalesReport - Retrieved petrol pump ID: $_petrolPumpId');
      
      if (_petrolPumpId == null) {
        setState(() {
          _errorMessage = 'Failed to get petrol pump ID. Please login again.';
        });
        return;
      }
      
      // Load data in parallel for efficiency
      await Future.wait([
        _loadEmployees(),
        _loadShifts(_petrolPumpId!),
      ]);
      
      // Load report data with default parameters
      await _loadReport();
    } catch (e) {
      print('DEBUG: DailySalesReport - Error during initialization: $e');
      setState(() {
        _errorMessage = 'Failed to initialize screen: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // More robust method to get petrol pump ID
  Future<String?> _getPetrolPumpIdRobust() async {
    // Try SharedPrefs first
    String? pumpId = await SharedPrefs.getPumpId();
    
    // If not found, try to get from JWT token directly
    if (pumpId == null || pumpId.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(ApiConstants.authTokenKey);
        
        if (token != null) {
          pumpId = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
          
          // If found, save it for future use
          if (pumpId != null && pumpId.isNotEmpty) {
            await prefs.setString('petrolPumpId', pumpId);
            print('DEBUG: DailySalesReport - Saved petrolPumpId to SharedPreferences: $pumpId');
          }
        }
      } catch (e) {
        print('DEBUG: DailySalesReport - Error extracting petrol pump ID from token: $e');
      }
    }
    
    return pumpId;
  }
  
  Future<void> _loadEmployees() async {
    try {
      final response = await _employeeRepository.getAllEmployees();
      if (response.success && response.data != null) {
        setState(() {
          _employees = response.data!;
        });
      } else {
        print('Failed to load employees: ${response.errorMessage}');
      }
    } catch (e) {
      print('Error loading employees: $e');
    }
  }
  
  Future<void> _loadShifts(String petrolPumpId) async {
    try {
      print('DEBUG: DailySalesReport - Loading shifts for petrol pump ID: $petrolPumpId');
      final response = await _reportingRepository.getShiftsByPetrolPumpId(petrolPumpId);
      if (response.success && response.data != null) {
        print('DEBUG: DailySalesReport - Shifts loaded successfully. Count: ${response.data!.length}');
        print('DEBUG: DailySalesReport - Shifts data: ${response.data}');
        setState(() {
          _shifts = response.data!;
        });
        print('DEBUG: DailySalesReport - _shifts state updated with ${_shifts.length} items');
      } else {
        print('DEBUG: DailySalesReport - Failed to load shifts: ${response.errorMessage}');
        print('Failed to load shifts: ${response.errorMessage}');
      }
    } catch (e) {
      print('DEBUG: DailySalesReport - Error loading shifts: $e');
      print('Error loading shifts: $e');
    }
  }
  
  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final response = await _reportingRepository.getDailySalesReport(
        date: _selectedDate,
        employeeId: _selectedEmployeeId,
        shiftId: _selectedShiftId,
      );
      
      setState(() {
        _isLoading = false;
        if (response.success && response.data != null) {
          _report = response.data;
        } else {
          _errorMessage = response.errorMessage ?? 'Failed to load report data';
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
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadReport();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Daily Sales Report'),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          if (_report != null) ...[
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: _isPdfGenerating ? null : _sharePdfReport,
              tooltip: 'Share Report',
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              onPressed: _isPdfGenerating ? null : _generatePdfReport,
              tooltip: 'Export to PDF',
            ),
          ],
          if (_isPdfGenerating)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                height: 16, 
                width: 16, 
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () => _selectDate(context),
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
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: const TextStyle(fontSize: 15),
                        ),
                        Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _loadReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Refresh',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildEmployeeDropdown(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildShiftDropdown(),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmployeeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedEmployeeId,
          isExpanded: true,
          hint: const Text('All Employees'),
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All Employees'),
            ),
            ..._employees.map((employee) {
              return DropdownMenuItem<String>(
                value: employee.id,
                child: Text(
                  '${employee.firstName} ${employee.lastName}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ],
          onChanged: (String? newValue) {
            setState(() {
              _selectedEmployeeId = newValue;
            });
            _loadReport();
          },
        ),
      ),
    );
  }
  
  Widget _buildShiftDropdown() {
    print('DEBUG: DailySalesReport - Building shifts dropdown with ${_shifts.length} items');
    if (_shifts.isNotEmpty) {
      print('DEBUG: DailySalesReport - First shift item: ${_shifts[0]}');
    }
    
    // Create a safe list of dropdown items
    final List<DropdownMenuItem<String>> dropdownItems = [
      const DropdownMenuItem<String>(
        value: null,
        child: Text('All Shifts'),
      ),
    ];
    
    // Only add shift items if we have shifts data
    if (_shifts.isNotEmpty) {
      dropdownItems.addAll(_shifts.map((shift) {
        // Use shiftId instead of id
        final shiftId = shift['shiftId'] as String?;
        final shiftNumber = shift['shiftNumber'];
        print('DEBUG: DailySalesReport - Adding shift to dropdown: $shiftId - $shiftNumber');
        return DropdownMenuItem<String>(
          value: shiftId,
          child: Text(
            'Shift #${shift['shiftNumber']}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList());
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedShiftId,
          isExpanded: true,
          hint: const Text('All Shifts'),
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          items: dropdownItems,
          onChanged: (String? newValue) {
            print('DEBUG: DailySalesReport - Selected shift changed to: $newValue');
            setState(() {
              _selectedShiftId = newValue;
            });
            _loadReport();
          },
        ),
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
          ElevatedButton(
            onPressed: _loadReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
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
            Icons.bar_chart,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Report Data',
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
              'Select parameters and tap Refresh to generate a report.',
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
    
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildReportHeader(report),
          const SizedBox(height: 24),
          _buildSalesSummarySection(report),
          const SizedBox(height: 24),
          _buildHourlySalesSection(report),
          const SizedBox(height: 24),
          _buildPaymentBreakdownSection(report),
          const SizedBox(height: 24),
          if (report.fuelTypeSales.isNotEmpty)
            _buildFuelTypeSalesSection(report),
        ],
      ),
    );
  }
  
  Widget _buildReportHeader(DailySalesReport report) {
    final formattedReportDate = DateFormat('d MMMM, yyyy').format(
      DateTime.tryParse(report.reportDate) ?? DateTime.now()
    );
    
    final formattedGeneratedAt = DateFormat('d MMM yyyy, h:mm a').format(
      DateTime.tryParse(report.generatedAt) ?? DateTime.now()
    );
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Sales Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedReportDate,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generated By',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.generatedBy,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generated At',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedGeneratedAt,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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
    );
  }
  
  Widget _buildSalesSummarySection(DailySalesReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Sales Summary', Icons.summarize),
        const SizedBox(height: 16),
        
        // Card Grid for summary metrics
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildSummaryCard(
              'Total Sales',
              ChartUtils.formatCurrency(report.totalSalesValue),
              Icons.attach_money,
              Colors.green,
            ),
            _buildSummaryCard(
              'Total Volume',
              ChartUtils.formatVolume(report.totalSalesVolume),
              Icons.local_gas_station,
              Colors.blue,
            ),
            _buildSummaryCard(
              'Transactions',
              report.totalTransactions.toString(),
              Icons.receipt_long,
              Colors.purple,
            ),
            _buildSummaryCard(
              'Avg. Transaction',
              ChartUtils.formatCurrency(report.averageTransactionValue),
              Icons.trending_up,
              Colors.orange,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildHourlySalesSection(DailySalesReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Peak hours insight
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getPeakHourInsight(report.hourlySales),
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPaymentBreakdownSection(DailySalesReport report) {
    final payment = report.paymentBreakdown;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Payment Breakdown', Icons.payment),
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha:0.1),
                blurRadius: 4,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Pie chart
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: ChartUtils.getPaymentBreakdownSections(payment),
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Payment method breakdown
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentMethodItem(
                      'Cash',
                      payment.cashAmount,
                      payment.cashPercentage,
                      payment.cashTransactions,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildPaymentMethodItem(
                      'Credit Card',
                      payment.creditCardAmount,
                      payment.creditCardPercentage,
                      payment.creditCardTransactions,
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildPaymentMethodItem(
                      'UPI',
                      payment.upiAmount,
                      payment.upiPercentage,
                      payment.upiTransactions,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildFuelTypeSalesSection(DailySalesReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Fuel Type Breakdown', Icons.local_gas_station),
        const SizedBox(height: 16),
        
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: report.fuelTypeSales.length,
          itemBuilder: (context, index) {
            final fuelType = report.fuelTypeSales[index];
            return _buildFuelTypeCard(fuelType);
          },
        ),
      ],
    );
  }
  
  Widget _buildFuelTypeCard(FuelTypeSale fuelType) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.local_gas_station,
                color: Colors.amber.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fuelType.fuelTypeName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFuelTypeStat(
                          'Volume',
                          ChartUtils.formatVolume(fuelType.volume),
                        ),
                      ),
                      Expanded(
                        child: _buildFuelTypeStat(
                          'Value',
                          ChartUtils.formatCurrency(fuelType.value),
                        ),
                      ),
                      Expanded(
                        child: _buildFuelTypeStat(
                          'Share',
                          '${fuelType.percentage.toStringAsFixed(1)}%',
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
    );
  }
  
  Widget _buildFuelTypeStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPaymentMethodItem(
    String method, 
    double amount, 
    double percentage, 
    int transactions,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          method,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          ChartUtils.formatCurrency(amount),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$transactions txns',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppTheme.primaryBlue,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.1),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  size: 16,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_upward,
                color: Colors.green,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '0%',  // This would be calculated from historical data
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getPeakHourInsight(List<HourlySale> hourlySales) {
    if (hourlySales.isEmpty) return 'No hourly sales data available.';
    
    // Find peak hour
    HourlySale peakSale = hourlySales.first;
    for (var sale in hourlySales) {
      if (sale.value > peakSale.value) {
        peakSale = sale;
      }
    }
    
    if (peakSale.value <= 0) return 'No significant sales recorded during the day.';
    
    final peakTimeString = ChartUtils.getTimeString(peakSale.hour);
    return 'Peak sales occur at $peakTimeString with ${ChartUtils.formatCurrency(peakSale.value)} in sales and ${peakSale.transactionCount} transactions.';
  }

  // Generate PDF document
  Future<pw.Document> _createPdf() async {
    if (_report == null) {
      throw Exception('No report data available');
    }

    final report = _report!;
    final pdf = pw.Document();

    // Use all hourly sales data instead of limiting to 12
    final allHourlySales = report.hourlySales;
    final limitedFuelTypes = report.fuelTypeSales.take(5).toList();

    try {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          maxPages: 10, // Strict limit on maximum pages
          header: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Daily Sales Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(
                  DateFormat('dd MMM yyyy').format(
                    DateTime.tryParse(report.reportDate) ?? DateTime.now()
                  ),
                  style: pw.TextStyle(fontSize: 14)
                ),
                pw.SizedBox(height: 8),
                pw.Divider(),
              ],
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 10),
              ),
            );
          },
          build: (pw.Context context) {
            return [
              // Report information
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Report Information', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  _buildPdfInfoRow('Report Date', DateFormat('dd MMM yyyy').format(
                    DateTime.tryParse(report.reportDate) ?? DateTime.now()
                  )),
                  _buildPdfInfoRow('Generated By', report.generatedBy),
                  _buildPdfInfoRow('Generated At', DateFormat('dd MMM yyyy, HH:mm').format(
                    DateTime.tryParse(report.generatedAt) ?? DateTime.now()
                  )),
                  pw.SizedBox(height: 15),
                ],
              ),
              
              pw.SizedBox(height: 10),
              
              // Sales Summary
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Sales Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _buildPdfTableCell('Metric', isHeader: true),
                          _buildPdfTableCell('Value', isHeader: true),
                        ],
                      ),
                      pw.TableRow(children: [
                        _buildPdfTableCell('Total Sales'),
                        _buildPdfTableCell('Rs. ${report.totalSalesValue.toStringAsFixed(2)}'),
                      ]),
                      pw.TableRow(children: [
                        _buildPdfTableCell('Total Volume'),
                        _buildPdfTableCell('${report.totalSalesVolume.toStringAsFixed(2)} L'),
                      ]),
                      pw.TableRow(children: [
                        _buildPdfTableCell('Total Transactions'),
                        _buildPdfTableCell(report.totalTransactions.toString()),
                      ]),
                      pw.TableRow(children: [
                        _buildPdfTableCell('Average Transaction Value'),
                        _buildPdfTableCell('Rs. ${report.averageTransactionValue.toStringAsFixed(2)}'),
                      ]),
                    ],
                  ),
                  pw.SizedBox(height: 15),
                ],
              ),
              
              pw.SizedBox(height: 10),
              
              // Payment Breakdown
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Payment Breakdown', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _buildPdfTableCell('Payment Method', isHeader: true),
                          _buildPdfTableCell('Amount', isHeader: true),
                          _buildPdfTableCell('Percentage', isHeader: true),
                          _buildPdfTableCell('Transactions', isHeader: true),
                        ],
                      ),
                      pw.TableRow(children: [
                        _buildPdfTableCell('Cash'),
                        _buildPdfTableCell('Rs. ${report.paymentBreakdown.cashAmount.toStringAsFixed(2)}'),
                        _buildPdfTableCell('${report.paymentBreakdown.cashPercentage.toStringAsFixed(1)}%'),
                        _buildPdfTableCell(report.paymentBreakdown.cashTransactions.toString()),
                      ]),
                      pw.TableRow(children: [
                        _buildPdfTableCell('Credit Card'),
                        _buildPdfTableCell('Rs. ${report.paymentBreakdown.creditCardAmount.toStringAsFixed(2)}'),
                        _buildPdfTableCell('${report.paymentBreakdown.creditCardPercentage.toStringAsFixed(1)}%'),
                        _buildPdfTableCell(report.paymentBreakdown.creditCardTransactions.toString()),
                      ]),
                      pw.TableRow(children: [
                        _buildPdfTableCell('UPI'),
                        _buildPdfTableCell('Rs. ${report.paymentBreakdown.upiAmount.toStringAsFixed(2)}'),
                        _buildPdfTableCell('${report.paymentBreakdown.upiPercentage.toStringAsFixed(1)}%'),
                        _buildPdfTableCell(report.paymentBreakdown.upiTransactions.toString()),
                      ]),
                    ],
                  ),
                  pw.SizedBox(height: 15),
                ],
              ),
            ];
          },
        ),
      );


      // Add fuel types on a new page if there's data
      if (limitedFuelTypes.isNotEmpty) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Fuel Type Breakdown', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Report Date: ${DateFormat('dd MMM yyyy').format(DateTime.tryParse(report.reportDate) ?? DateTime.now())}',
                    style: pw.TextStyle(fontSize: 12)
                  ),
                  pw.SizedBox(height: 15),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _buildPdfTableCell('Fuel Type', isHeader: true),
                          _buildPdfTableCell('Volume', isHeader: true),
                          _buildPdfTableCell('Value', isHeader: true),
                          _buildPdfTableCell('Percentage', isHeader: true),
                        ],
                      ),
                      ...limitedFuelTypes.map((fuel) => pw.TableRow(children: [
                        _buildPdfTableCell(fuel.fuelTypeName),
                        _buildPdfTableCell('${fuel.volume.toStringAsFixed(2)} L'),
                        _buildPdfTableCell('Rs. ${fuel.value.toStringAsFixed(2)}'),
                        _buildPdfTableCell('${fuel.percentage.toStringAsFixed(1)}%'),
                      ])).toList(),
                    ],
                  ),
                  if (limitedFuelTypes.length < report.fuelTypeSales.length)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 10),
                      child: pw.Text(
                        'Note: Showing ${limitedFuelTypes.length} of ${report.fuelTypeSales.length} fuel types due to space constraints.',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      }
    } catch (e) {
      print('Error generating PDF: $e');
      rethrow;
    }
    
    return pdf;
  }

  // Helper method to build PDF table cell
  pw.Widget _buildPdfTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }
  
  // Helper method to build PDF info rows
  pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }

  // Generate and preview PDF report
  Future<void> _generatePdfReport() async {
    if (_report == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report data available for PDF export')),
      );
      return;
    }

    setState(() {
      _isPdfGenerating = true;
    });

    try {
      final pdf = await _createPdf();
      
      // Show the PDF document in the preview
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Daily_Sales_Report_${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isPdfGenerating = false;
      });
    }
  }
  
  // Share PDF report
  Future<void> _sharePdfReport() async {
    if (_report == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report data available to share')),
      );
      return;
    }

    setState(() {
      _isPdfGenerating = true;
    });

    try {
      final pdf = await _createPdf();
      final bytes = await pdf.save();
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Daily_Sales_Report_${DateFormat('yyyy-MM-dd').format(_selectedDate)}.pdf';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsBytes(bytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Daily Sales Report - ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share PDF: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isPdfGenerating = false;
      });
    }
  }
} 