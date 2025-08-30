import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/shift_sales_report.dart';
import '../../services/shift_sales_report_service.dart';
import '../../theme.dart';
import '../../widgets/error_message.dart';
import '../../widgets/loading_indicator.dart';
// PDF generation imports
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

class ShiftSalesReportScreen extends StatefulWidget {
  const ShiftSalesReportScreen({super.key});

  @override
  State<ShiftSalesReportScreen> createState() => _ShiftSalesReportScreenState();
}

class _ShiftSalesReportScreenState extends State<ShiftSalesReportScreen> {
  final ShiftSalesReportService _reportService = ShiftSalesReportService();
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  bool _isLoading = false;
  bool _isPdfGenerating = false;
  String? _errorMessage;
  ShiftSalesReportResponse? _reportResponse;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final response = await _reportService.fetchShiftSalesReport(_startDate, _endDate);
      setState(() {
        _reportResponse = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
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
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Shift Sales Report',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
            tooltip: 'Refresh Report',
          ),
          IconButton(
            icon: _isPdfGenerating 
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf),
            onPressed: _isPdfGenerating ? null : _generatePdfReport,
            tooltip: 'Export as PDF',
            onLongPress: _isPdfGenerating ? null : () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (BuildContext context) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ListTile(
                          leading: const Icon(Icons.picture_as_pdf),
                          title: const Text('Generate PDF'),
                          onTap: () {
                            Navigator.pop(context);
                            _generatePdfReport();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.share),
                          title: const Text('Share PDF'),
                          onTap: () {
                            Navigator.pop(context);
                            _sharePdfReport();
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : _errorMessage != null
              ? ErrorMessage(message: _errorMessage!, onRetry: _loadReport)
              : _reportResponse == null || _reportResponse!.data.isEmpty
                  ? _buildEmptyState()
                  : _buildReportContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.info_outline,
            size: 50,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No shift sales data available',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Try changing the date range or check back later',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    final report = _reportResponse!.data[0];
    return CustomScrollView(
      slivers: [
        // Date Range Selector
        SliverToBoxAdapter(
          child: _buildDateRangeSelector(),
        ),
        
        // Summary Card
        SliverToBoxAdapter(
          child: _buildSummaryCard(report),
        ),
        
        // Chart
        if (report.shiftPerformances.length > 1) 
          SliverToBoxAdapter(
            child: _buildChartCard(report),
          ),
        
        // Section Title - Shift Details
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              children: [
                Text(
                  'Shift Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${report.shiftPerformances.length} Shifts',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Shift Cards List
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildShiftCard(report.shiftPerformances[index]),
                );
              },
              childCount: report.shiftPerformances.length,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDateRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            offset: const Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: InkWell(
        onTap: _selectDateRange,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Period',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_endDate.difference(_startDate).inDays + 1} days',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSummaryCard(ShiftSalesReport report) {
    final comparison = report.shiftComparison;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
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
                  Text(
                    report.petrolPumpName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Generated: ${DateFormat('dd MMM, HH:mm').format(report.generatedAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      title: 'Best Shift',
                      value: comparison.bestPerformingShift,
                      subtitle: '${NumberFormat.decimalPattern().format(comparison.bestShiftVolume)} L',
                      iconData: Icons.arrow_upward,
                      iconColor: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      title: 'Average Volume',
                      value: '${NumberFormat.decimalPattern().format(comparison.averageShiftVolume)} L',
                      subtitle: 'Per Shift',
                      iconData: Icons.bar_chart,
                      iconColor: AppTheme.primaryBlue,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      title: 'Worst Shift',
                      value: comparison.worstPerformingShift,
                      subtitle: '${NumberFormat.decimalPattern().format(comparison.worstShiftVolume)} L',
                      iconData: Icons.arrow_downward,
                      iconColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSummaryItem({
    required String title,
    required String value,
    required String subtitle,
    required IconData iconData,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha:0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            iconData,
            color: iconColor,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildChartCard(ShiftSalesReport report) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Volume Trend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 250,
                child: _buildVolumeChart(report.shiftPerformances),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildVolumeChart(List<ShiftPerformance> performances) {
    final volumeSpots = performances
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.totalVolume))
        .toList();
    
    // Get min and max values for better Y axis scaling
    final volumes = performances.map((p) => p.totalVolume).toList();
    final double minY = volumes.reduce((a, b) => a < b ? a : b) * 0.9;
    final double maxY = volumes.reduce((a, b) => a > b ? a : b) * 1.1;
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha:0.2),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha:0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                final length = performances.length;
                
                bool shouldShow = false;
                
                if (length <= 5) {
                  shouldShow = true;
                } else if (index == 0 || index == length - 1) {
                  shouldShow = true;
                } else if (length > 10 && index % (length ~/ 5) == 0) {
                  shouldShow = true;
                } else if (length <= 10 && index % 2 == 0) {
                  shouldShow = true;
                }
                
                if (!shouldShow || index >= performances.length) {
                  return const SizedBox.shrink();
                }
                
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('dd/MM').format(performances[index].date),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    NumberFormat.compact().format(value),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withValues(alpha:0.2)),
        ),
        minX: 0,
        maxX: (performances.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => AppTheme.primaryBlue,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                final index = touchedSpot.x.toInt();
                if (index >= 0 && index < performances.length) {
                  final performance = performances[index];
                  return LineTooltipItem(
                    '${NumberFormat.decimalPattern().format(touchedSpot.y)} L',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: '\n${DateFormat('dd MMM').format(performance.date)} - Shift ${performance.shiftNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.normal,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  );
                }
                return null;
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
        lineBarsData: [
          LineChartBarData(
            spots: volumeSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppTheme.primaryBlue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppTheme.primaryBlue,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryBlue.withValues(alpha:0.3),
                  AppTheme.primaryBlue.withValues(alpha:0.05),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildShiftCard(ShiftPerformance shift) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(shift.date),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Shift ${shift.shiftNumber} (${shift.startTime} - ${shift.endTime})',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${shift.employeeCount}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Key metrics
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        title: 'Volume',
                        value: '${NumberFormat.decimalPattern().format(shift.totalVolume)} L',
                        iconData: Icons.local_gas_station,
                        iconColor: Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        title: 'Sales',
                        value: '₹${NumberFormat.decimalPattern().format(shift.totalValue)}',
                        iconData: Icons.payments,
                        iconColor: Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        title: 'Transactions',
                        value: shift.transactionCount.toString(),
                        iconData: Icons.receipt_long,
                        iconColor: Colors.purple,
                      ),
                    ),
                  ],
                ),
                
                // Fuel breakdown if available
                if (shift.fuelTypeBreakdown.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(
                      'Fuel Breakdown',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...shift.fuelTypeBreakdown.map((fuel) => _buildFuelRow(fuel)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetricItem({
    required String title,
    required String value,
    required IconData iconData,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha:0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            iconData,
            color: iconColor,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildFuelRow(FuelTypeBreakdown fuel) {
    final fuelName = fuel.fuelType ?? 'Unknown';
    final fuelColor = _getFuelColor(fuelName);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: fuelColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              fuelName,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${NumberFormat.decimalPattern().format(fuel.volume)} L',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '₹${NumberFormat.decimalPattern().format(fuel.value)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getFuelColor(String fuelType) {
    if (fuelType.toLowerCase().contains('petrol')) return Colors.green;
    if (fuelType.toLowerCase().contains('diesel')) return Colors.blue;
    if (fuelType.toLowerCase().contains('premium')) return Colors.purple;
    if (fuelType.toLowerCase().contains('cng')) return Colors.teal;
    return Colors.orange;
  }

  // PDF Generation methods
  Future<pw.Document> _createPdf() async {
    final pdf = pw.Document();
    
    try {
      if (_reportResponse == null || _reportResponse!.data.isEmpty) {
        throw Exception('No report data available');
      }
      
      final report = _reportResponse!.data[0];
      
      // Add logo from assets if available
      pw.MemoryImage? logoImage;
      try {
        final byteData = await rootBundle.load('assets/images/logo.png');
        final bytes = byteData.buffer.asUint8List();
        logoImage = pw.MemoryImage(bytes);
      } catch (e) {
        // Logo not available, continue without it
      }
      
      // Add header page with summary
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with logo if available
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Shift Sales Report',
                          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          report.petrolPumpName,
                          style: pw.TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    if (logoImage != null)
                      pw.SizedBox(
                        width: 60,
                        child: pw.Image(logoImage),
                      ),
                  ],
                ),
                
                pw.SizedBox(height: 20),
                
                // Report information
                _buildPdfInfoRow('Report Period', 
                  '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}'),
                _buildPdfInfoRow('Total Days', 
                  '${_endDate.difference(_startDate).inDays + 1} days'),
                _buildPdfInfoRow('Generated On', 
                  DateFormat('dd MMM yyyy, HH:mm').format(report.generatedAt)),
                
                pw.Divider(height: 30),
                
                // Summary section
                pw.Text('Performance Summary', 
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 15),
                
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildPdfTableCell('Metric', isHeader: true),
                        _buildPdfTableCell('Value', isHeader: true),
                      ],
                    ),
                    pw.TableRow(children: [
                      _buildPdfTableCell('Best Performing Shift'),
                      _buildPdfTableCell(report.shiftComparison.bestPerformingShift),
                    ]),
                    pw.TableRow(children: [
                      _buildPdfTableCell('Best Shift Volume'),
                      _buildPdfTableCell('${NumberFormat.decimalPattern().format(report.shiftComparison.bestShiftVolume)} L'),
                    ]),
                    pw.TableRow(children: [
                      _buildPdfTableCell('Average Shift Volume'),
                      _buildPdfTableCell('${NumberFormat.decimalPattern().format(report.shiftComparison.averageShiftVolume)} L'),
                    ]),
                    pw.TableRow(children: [
                      _buildPdfTableCell('Worst Performing Shift'),
                      _buildPdfTableCell(report.shiftComparison.worstPerformingShift),
                    ]),
                    pw.TableRow(children: [
                      _buildPdfTableCell('Worst Shift Volume'),
                      _buildPdfTableCell('${NumberFormat.decimalPattern().format(report.shiftComparison.worstShiftVolume)} L'),
                    ]),
                    pw.TableRow(children: [
                      _buildPdfTableCell('Total Shifts'),
                      _buildPdfTableCell('${report.shiftPerformances.length}'),
                    ]),
                  ],
                ),
              ],
            );
          },
        ),
      );
      
      // Add shift performance details page
      // Group shifts in pages of 4 to avoid overcrowding
      final shiftsPerPage = 4;
      for (var i = 0; i < report.shiftPerformances.length; i += shiftsPerPage) {
        final pageShifts = report.shiftPerformances.skip(i).take(shiftsPerPage).toList();
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Shift Performance Details',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Page ${(i ~/ shiftsPerPage) + 1} of ${(report.shiftPerformances.length / shiftsPerPage).ceil()}',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 15),
                  
                  // Shift details in table form
                  pw.Expanded(
                    child: pw.ListView.builder(
                      itemCount: pageShifts.length,
                      itemBuilder: (context, index) {
                        final shift = pageShifts[index];
                        return pw.Container(
                          margin: const pw.EdgeInsets.only(bottom: 20),
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey300),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              // Shift header
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                color: PdfColors.grey200,
                                child: pw.Row(
                                  children: [
                                    pw.Expanded(
                                      child: pw.Text(
                                        '${DateFormat('dd MMM yyyy').format(shift.date)} - Shift ${shift.shiftNumber}',
                                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                                      ),
                                    ),
                                    pw.Text(
                                      '${shift.startTime} - ${shift.endTime}',
                                    ),
                                  ],
                                ),
                              ),
                              
                              pw.SizedBox(height: 10),
                              
                              // Shift metrics
                              pw.Row(
                                children: [
                                  pw.Expanded(
                                    child: _buildPdfMetricItem('Volume', 
                                      '${NumberFormat.decimalPattern().format(shift.totalVolume)} L'),
                                  ),
                                  pw.Expanded(
                                    child: _buildPdfMetricItem('Sales', 
                                      'Rs.${NumberFormat.decimalPattern().format(shift.totalValue)}'),
                                  ),
                                  pw.Expanded(
                                    child: _buildPdfMetricItem('Transactions', 
                                      shift.transactionCount.toString()),
                                  ),
                                ],
                              ),
                              
                              // Fuel breakdown if available
                              if (shift.fuelTypeBreakdown.isNotEmpty) ...[
                                pw.SizedBox(height: 12),
                                pw.Text('Fuel Breakdown:', 
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                                pw.SizedBox(height: 6),
                                
                                pw.Table(
                                  border: pw.TableBorder.all(color: PdfColors.grey300),
                                  columnWidths: {
                                    0: const pw.FlexColumnWidth(2),
                                    1: const pw.FlexColumnWidth(1),
                                    2: const pw.FlexColumnWidth(1),
                                  },
                                  children: [
                                    pw.TableRow(
                                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                                      children: [
                                        _buildPdfTableCell('Fuel Type', isHeader: true, padding: 4),
                                        _buildPdfTableCell('Volume', isHeader: true, padding: 4),
                                        _buildPdfTableCell('Value', isHeader: true, padding: 4),
                                      ],
                                    ),
                                    ...shift.fuelTypeBreakdown.map((fuel) => pw.TableRow(
                                      children: [
                                        _buildPdfTableCell(fuel.fuelType ?? 'Unknown', padding: 4),
                                        _buildPdfTableCell(
                                          '${NumberFormat.decimalPattern().format(fuel.volume)} L', 
                                          padding: 4,
                                        ),
                                        _buildPdfTableCell(
                                          'Rs.${NumberFormat.decimalPattern().format(fuel.value)}',
                                          padding: 4,
                                        ),
                                      ],
                                    )).toList(),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
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

  // Helper methods for PDF generation
  pw.Widget _buildPdfTableCell(String text, {bool isHeader = false, double padding = 8}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(padding),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }
  
  pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
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
  
  pw.Widget _buildPdfMetricItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }
  
  // Generate and preview PDF report
  Future<void> _generatePdfReport() async {
    if (_reportResponse == null || _reportResponse!.data.isEmpty) {
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
        name: 'Shift_Sales_Report_${DateFormat('yyyy-MM-dd').format(_startDate)}_to_${DateFormat('yyyy-MM-dd').format(_endDate)}',
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
    if (_reportResponse == null || _reportResponse!.data.isEmpty) {
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
      final fileName = 'Shift_Sales_Report_${DateFormat('yyyy-MM-dd').format(_startDate)}_to_${DateFormat('yyyy-MM-dd').format(_endDate)}.pdf';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsBytes(bytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Shift Sales Report - ${DateFormat('dd MMM yyyy').format(_startDate)} to ${DateFormat('dd MMM yyyy').format(_endDate)}',
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