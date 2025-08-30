import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../../api/api_constants.dart';
import '../../theme.dart';
import '../../api/api_service.dart';
import '../../models/api_response.dart';

class StockMovementReportScreen extends StatefulWidget {
  const StockMovementReportScreen({super.key});

  @override
  State<StockMovementReportScreen> createState() => _StockMovementReportScreenState();
}

class _StockMovementReportScreenState extends State<StockMovementReportScreen> {
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;
  bool isGeneratingPdf = false;
  Map<String, dynamic>? reportData;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
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
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _fetchReportData();
    }
  }

  Future<void> _fetchReportData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final url = ApiConstants.getStockMovementReportUrl(selectedDate);
      final token = await ApiConstants.getAuthToken();
      final response = await http.get(
        Uri.parse(url),
        headers: ApiService().getHeaders(token: token),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        setState(() {
          reportData = responseData;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = responseData['message'] ?? 'Failed to load report data';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Stock Movement Report',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (reportData != null && !isLoading)
            isGeneratingPdf
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
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: 25,
              top: 5,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _selectDate(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16),
                      SizedBox(width: 8),
                      Text(
                        DateFormat('dd MMM yyyy').format(selectedDate),
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _fetchReportData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 16),
                      SizedBox(width: 8),
                      Text('Refresh', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildReportContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text(
                errorMessage!,
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchReportData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (reportData == null || reportData!['data'] == null || reportData!['data'].isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: Colors.amber, size: 48),
              SizedBox(height: 16),
              Text(
                'No stock movement data available for selected date',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final report = reportData!['data'][0];
    final summary = report['summary'];
    final tankMovements = report['tankMovements'];

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Summary Card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stock Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                Divider(height: 24),
                _buildSummaryItem('Total Capacity', '${summary['totalCapacity']} L'),
                _buildSummaryItem('Opening Stock', '${summary['totalOpeningStock']} L'),
                _buildSummaryItem('Closing Stock', '${summary['totalClosingStock']} L'),
                _buildSummaryItem('Total Received', '${summary['totalReceived']} L'),
                _buildSummaryItem('Total Dispensed', '${summary['totalDispensed']} L'),
                _buildSummaryItem('Total Adjustments', '${summary['totalAdjustments']} L'),
                _buildSummaryItem('Overall Stock %', '${summary['overallStockPercentage']}%'),
                _buildSummaryItem('Tanks Requiring Attention', '${summary['tanksRequiringAttention']}'),
              ],
            ),
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Tank Movements',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        SizedBox(height: 8),
        
        // Tank Movements List
        ...tankMovements.map<Widget>((tank) {
          final stockPercentage = tank['stockPercentage'] as double;
          Color stockColor;
          
          if (stockPercentage < 20) {
            stockColor = Colors.red;
          } else if (stockPercentage < 40) {
            stockColor = Colors.orange;
          } else {
            stockColor = Colors.green;
          }
          
          return Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          tank['fuelType'],
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: stockColor.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: stockColor),
                        ),
                        child: Text(
                          'Stock: ${tank['stockPercentage']}%',
                          style: TextStyle(
                            color: stockColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: tank['stockPercentage'] / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(stockColor),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTankDetail('Opening', '${tank['openingStock']} L'),
                      _buildTankDetail('Received', '${tank['totalReceived']} L'),
                      _buildTankDetail('Dispensed', '${tank['totalDispensed']} L'),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTankDetail('Adjustments', '${tank['adjustments']} L'),
                      _buildTankDetail('Variance', '${tank['stockVariance']} L'),
                      _buildTankDetail('Closing', '${tank['closingStock']} L'),
                    ],
                  ),
                  if (tank['alertLevel'] != 'Normal') ...[
                    SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Alert: ${tank['alertLevel']}',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),

        // Report Details
        SizedBox(height: 20),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Divider(height: 24),
                _buildReportDetail('Petrol Pump', report['petrolPumpName']),
                _buildReportDetail('Report Period', '${DateFormat('dd MMM yyyy').format(DateTime.parse(report['reportPeriodStart']))} - ${DateFormat('dd MMM yyyy').format(DateTime.parse(report['reportPeriodEnd']))}'),
                _buildReportDetail('Generated At', DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(report['generatedAt']))),
                _buildReportDetail('Generated By', report['generatedBy']),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTankDetail(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // PDF Export functionality
  Future<void> _exportToPdf(BuildContext context) async {
    if (reportData == null || reportData!['data'] == null || reportData!['data'].isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report data available for PDF export')),
      );
      return;
    }
    
    setState(() {
      isGeneratingPdf = true;
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
      final fileName = 'stock_movement_report_${DateFormat('yyyyMMdd').format(selectedDate)}.pdf';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isGeneratingPdf = false;
        });
      }
    }
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    
    if (reportData == null || reportData!['data'] == null || reportData!['data'].isEmpty) {
      throw Exception('No report data available');
    }
    
    final report = reportData!['data'][0];
    final summary = report['summary'];
    final tankMovements = report['tankMovements'];
    
    // Load images for PDF
    final PdfColor headerColor = PdfColor.fromHex('#0066cc'); // AppTheme.primaryBlue equivalent
    
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
                    'Stock Movement Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: headerColor,
                    ),
                  ),
                  pw.Text(
                    DateFormat('dd/MM/yyyy').format(selectedDate),
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Divider(color: headerColor),
              pw.SizedBox(height: 25),
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
          // Stock Summary Section
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Stock Summary',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),

                pw.Divider(color: PdfColors.grey300, height: 24),
                _buildPdfSummaryRow('Total Capacity', '${summary['totalCapacity']} L'),
                _buildPdfSummaryRow('Opening Stock', '${summary['totalOpeningStock']} L'),
                _buildPdfSummaryRow('Closing Stock', '${summary['totalClosingStock']} L'),
                _buildPdfSummaryRow('Total Received', '${summary['totalReceived']} L'),
                _buildPdfSummaryRow('Total Dispensed', '${summary['totalDispensed']} L'),
                _buildPdfSummaryRow('Total Adjustments', '${summary['totalAdjustments']} L'),
                _buildPdfSummaryRow('Overall Stock %', '${summary['overallStockPercentage']}%'),
                _buildPdfSummaryRow('Tanks Requiring Attention', '${summary['tanksRequiringAttention']}'),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),

          // Report Details
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Report Details',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Divider(color: PdfColors.grey300, height: 24),
                _buildPdfReportDetail('Petrol Pump', report['petrolPumpName']),
                _buildPdfReportDetail('Report Period', '${DateFormat('dd MMM yyyy').format(DateTime.parse(report['reportPeriodStart']))} - ${DateFormat('dd MMM yyyy').format(DateTime.parse(report['reportPeriodEnd']))}'),
                _buildPdfReportDetail('Generated At', DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(report['generatedAt']))),
                _buildPdfReportDetail('Generated By', report['generatedBy']),
              ],
            ),
          ),

          pw.NewPage(),
          // Tank Movements Section
          pw.Header(
            level: 1,
            text: 'Tank Movements',
            textStyle: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 10),
          
          ...List<pw.Widget>.generate(tankMovements.length, (index) {
            final tank = tankMovements[index];
            final stockPercentage = tank['stockPercentage'] as double;
            final PdfColor stockColor = stockPercentage < 20 
                ? PdfColors.red 
                : stockPercentage < 40 
                    ? PdfColor.fromHex('#FFA500') // orange 
                    : PdfColors.green;
            
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        tank['fuelType'],
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Stock: ${tank['stockPercentage']}%',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: stockColor,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    height: 10,
                    width: double.infinity,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Container(
                        height: 10,
                        width: (tank['stockPercentage'] as double) / 100 * 500, // approx width
                        decoration: pw.BoxDecoration(
                          color: stockColor,
                          borderRadius: pw.BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPdfTankDetail('Opening', '${tank['openingStock']} L'),
                      _buildPdfTankDetail('Received', '${tank['totalReceived']} L'),
                      _buildPdfTankDetail('Dispensed', '${tank['totalDispensed']} L'),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPdfTankDetail('Adjustments', '${tank['adjustments']} L'),
                      _buildPdfTankDetail('Variance', '${tank['stockVariance']} L'),
                      _buildPdfTankDetail('Closing', '${tank['closingStock']} L'),
                    ],
                  ),
                  if (tank['alertLevel'] != 'Normal') ...[
                    pw.SizedBox(height: 12),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.red100,
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text(
                            'Alert: ${tank['alertLevel']}',
                            style:  pw.TextStyle(
                              color: PdfColors.red,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          
          pw.SizedBox(height: 20),
          

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
  
  pw.Widget _buildPdfTankDetail(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              color: PdfColors.grey600,
              fontSize: 12,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  pw.Widget _buildPdfReportDetail(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5.0),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                color: PdfColors.grey600,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
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
      text: 'Stock Movement Report',
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