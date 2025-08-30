import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:petrol_pump/models/comprehensive_report_model.dart';
import 'package:petrol_pump/api/api_constants.dart';
import 'package:petrol_pump/theme.dart';
// PDF generation imports
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

class ComprehensiveReportScreen extends StatefulWidget {
  const ComprehensiveReportScreen({super.key});

  @override
  State<ComprehensiveReportScreen> createState() => _ComprehensiveReportScreenState();
}

class _ComprehensiveReportScreenState extends State<ComprehensiveReportScreen> {
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;
  String? errorMessage;
  ComprehensiveReportResponse? reportData;
  bool isPdfGenerating = false;

  @override
  void initState() {
    super.initState();
    // Fetch report data when screen is first loaded
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final url = ApiConstants.getComprehensiveDailyReportUrl(selectedDate);
      final token = await ApiConstants.getAuthToken();
      
      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Authentication token not found. Please login again.';
        });
        return;
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == ApiConstants.statusOk) {
        final jsonData = json.decode(response.body);
        setState(() {
          reportData = ComprehensiveReportResponse.fromJson(jsonData);
          isLoading = false;
        });
      } else {
        final jsonData = json.decode(response.body);
        setState(() {
          isLoading = false;
          errorMessage = jsonData['message'] ?? 'Failed to load report data';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'An error occurred: ${e.toString()}';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryBlue,
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

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  // Build a styled table for PDF
  pw.Widget _buildStyledTable({
    required List<String> headers,
    required List<List<String>> data,
    required PdfColor headerColor,
    bool stripedRows = false,
    Map<int, pw.TableColumnWidth>? columnWidths,
  }) {
    final cellAlignments = <int, pw.Alignment>{};
    
    // Set text alignments for cells (numbers right-aligned)
    for (int i = 0; i < headers.length; i++) {
      // Make numeric columns right-aligned
      if (data.isNotEmpty && data[0].length > i) {
        // Check if this column contains numeric values
        final isNumeric = double.tryParse(data[0][i]) != null;
        if (isNumeric) {
          cellAlignments[i] = pw.Alignment.centerRight;
        } else {
          cellAlignments[i] = pw.Alignment.centerLeft;
        }
      }
    }
  
    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(
        color: headerColor,
        borderRadius: pw.BorderRadius.only(
          topLeft: pw.Radius.circular(4),
          topRight: pw.Radius.circular(4),
        ),
      ),
      cellAlignments: cellAlignments,
      cellHeight: 25,
      columnWidths: columnWidths,
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(
          color: PdfColors.grey300,
          width: 0.5,
        ),
      ),
      rowDecoration: stripedRows 
        ? const pw.BoxDecoration(color: PdfColors.grey100)
        : null,
      cellStyle: const pw.TextStyle(fontSize: 9),
    );
  }

  // Generate PDF document
  Future<pw.Document> _createPdf() async {
    final data = reportData!.data;
    final pdf = pw.Document();
    
    // Define colors
    final PdfColor primaryBlue = PdfColor.fromHex('#1D3557'); // AppTheme.primaryBlue
    final PdfColor headerColor = PdfColor.fromHex('#0066cc');
    
    // Try to load logo if available
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Logo not available, continue without it
      print('Logo not available: $e');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Comprehensive Daily Report',
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
              pw.SizedBox(height: 20),
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
          // Station Information
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
                  'Station Information',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                pw.Divider(color: PdfColors.grey300, height: 24),
                _buildPdfInfoRow('Station Name', data.stationName),
                _buildPdfInfoRow('Report Date', _formatDate(data.reportDate)),
                _buildPdfInfoRow('Generated At', DateFormat('dd MMM yyyy, HH:mm').format(data.generatedAt)),
                _buildPdfInfoRow('Generated By', data.generatedBy),
                _buildPdfInfoRow('Report Period', 
                  '${DateFormat('dd MMM yyyy, HH:mm').format(data.reportPeriodStart)} - ${DateFormat('HH:mm').format(data.reportPeriodEnd)}'),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),


          // Product Totals and Payment Details in a row
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Product Totals
              pw.Expanded(
                flex: 1,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Product Totals',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Divider(color: PdfColors.grey300, height: 24),
                      _buildPdfInfoRow('Total Volume (Ltrs)', data.productDetails.total.totalVolumeLtrs.toStringAsFixed(2)),
                      _buildPdfInfoRow('Total Amount (Rs)', 'Rs. ${data.productDetails.total.totalAmountRs.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(width: 16),

              // Payment Details
              pw.Expanded(
                flex: 1,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Payment Details',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Divider(color: PdfColors.grey300, height: 24),
                      data.paymentDetails.paymentModes.isEmpty
                          ? pw.Text('No payment details available')
                          : pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          ...data.paymentDetails.paymentModes.map((payment) {
                            // Skip showing modes with zero amount
                            final mode = payment['mode'] as String;
                            final amount = payment['amountRs'] as num;
                            
                            if (amount == 0) return pw.SizedBox();
                            
                            return pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 8.0),
                              child: pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    mode,
                                    style: const pw.TextStyle(
                                      fontSize: 12,
                                    ),
                                  ),
                                  pw.Text(
                                    'Rs. ${amount.toStringAsFixed(2)}',
                                    style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          pw.Divider(color: PdfColors.grey300),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Total Amount:',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              ),
                              pw.Text(
                                'Rs. ${data.paymentDetails.totalAmount.toStringAsFixed(2)}',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          
          pw.SizedBox(height: 20),


          pw.NewPage(),
          
          // Nozzle Details
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
                  'Nozzle Details',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3), // Dispenser
                    1: const pw.FlexColumnWidth(2), // Nozzle
                    2: const pw.FlexColumnWidth(3), // Product
                    3: const pw.FlexColumnWidth(2), // Tank
                    4: const pw.FlexColumnWidth(3), // Opening
                    5: const pw.FlexColumnWidth(3), // Closing
                    6: const pw.FlexColumnWidth(3), // Testing
                    7: const pw.FlexColumnWidth(3), // Sales
                  },
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: headerColor),
                      children: [
                        _buildPdfTableCell('Dispenser', isHeader: true),
                        _buildPdfTableCell('Nozzle', isHeader: true),
                        _buildPdfTableCell('Product', isHeader: true),
                        _buildPdfTableCell('Tank', isHeader: true),
                        _buildPdfTableCell('Opening', isHeader: true),
                        _buildPdfTableCell('Closing', isHeader: true),
                        _buildPdfTableCell('Testing (L)', isHeader: true),
                        _buildPdfTableCell('Sales (L)', isHeader: true),
                      ],
                    ),
                    // Data rows
                    ...data.nozzleDetails.nozzleDetails.map((nozzle) {
                      final sales = nozzle.meterSalesLtrs;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                        ),
                        children: [
                          _buildPdfTableCell(nozzle.dispenserUnit),
                          _buildPdfTableCell(nozzle.nozzle),
                          _buildPdfTableCell(nozzle.product),
                          _buildPdfTableCell(nozzle.tank),
                          _buildPdfTableCell(nozzle.opening.toStringAsFixed(2)),
                          _buildPdfTableCell(nozzle.closing.toStringAsFixed(2)),
                          _buildPdfTableCell(nozzle.testingLtrs.toStringAsFixed(2)),
                          _buildPdfTableCell(
                            sales.toStringAsFixed(2),
                            textColor: sales < 0 
                              ? PdfColors.red 
                              : (sales > 0 ? PdfColors.green : null),
                            isBold: true,
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),


          // Tank Sales Details
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
                  'Tank Sales Details',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3), // Product
                    1: const pw.FlexColumnWidth(3), // Tank
                    2: const pw.FlexColumnWidth(2), // Dip
                    3: const pw.FlexColumnWidth(4), // Opening Stock
                    // 4: const pw.FlexColumnWidth(3), // Opening Density
                    4: const pw.FlexColumnWidth(2), // Load Vol
                    5: const pw.FlexColumnWidth(4), // Load Density
                    6: const pw.FlexColumnWidth(3), // Total Stock
                    7: const pw.FlexColumnWidth(3), // Total Density
                    8: const pw.FlexColumnWidth(3), // Closing Dip
                    9: const pw.FlexColumnWidth(3), // Closing Stock
                    // 11: const pw.FlexColumnWidth(3), // Closing Density
                    10: const pw.FlexColumnWidth(3), // Dip Sales
                    11: const pw.FlexColumnWidth(2.5), // Meter Sales
                    12: const pw.FlexColumnWidth(3.2), // Variation
                  },
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: headerColor),
                      children: [
                        _buildPdfTableCell('Product', isHeader: true),
                        _buildPdfTableCell('Tank', isHeader: true),
                        _buildPdfTableCell('Dip', isHeader: true),
                        _buildPdfTableCell('Opening Stock', isHeader: true),
                        // _buildPdfTableCell('Opening Density', isHeader: true),
                        _buildPdfTableCell('Load Vol', isHeader: true),
                        _buildPdfTableCell('Load Density', isHeader: true),
                        _buildPdfTableCell('Total Stock', isHeader: true),
                        _buildPdfTableCell('Total Density', isHeader: true),
                        _buildPdfTableCell('Closing Dip', isHeader: true),
                        _buildPdfTableCell('Closing Stock', isHeader: true),
                        // _buildPdfTableCell('Closing Density', isHeader: true),
                        _buildPdfTableCell('Dip Sales', isHeader: true),
                        _buildPdfTableCell('Meter Sales', isHeader: true),
                        _buildPdfTableCell('Variation', isHeader: true),
                      ],
                    ),
                    // Data rows
                    ...data.salesDetails.tankSalesDetails.map((tank) {
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                        ),
                        children: [
                          _buildPdfTableCell(tank.product),
                          _buildPdfTableCell(tank.tank),
                          _buildPdfTableCell(tank.dip.toString()),
                          _buildPdfTableCell('${tank.openingStockVol.toStringAsFixed(2)} L'),
                          // _buildPdfTableCell(tank.openingStockDensity.toStringAsFixed(2)),
                          _buildPdfTableCell(tank.loadVol.toStringAsFixed(2)),
                          _buildPdfTableCell(tank.loadDensity.toStringAsFixed(2)),
                          _buildPdfTableCell(tank.totalStockVol.toStringAsFixed(2)),
                          _buildPdfTableCell(tank.totalStockDensity.toStringAsFixed(2)),
                          _buildPdfTableCell(tank.closingDip.toString()),
                          _buildPdfTableCell('${tank.closingStockVol.toStringAsFixed(2)} L'),
                          // _buildPdfTableCell(tank.closingStockDensity.toStringAsFixed(2)),
                          _buildPdfTableCell(tank.dipSales.toStringAsFixed(2)),
                          _buildPdfTableCell(tank.meterSales.toStringAsFixed(2)),
                          _buildPdfTableCell(
                            tank.variation.toStringAsFixed(2),
                            textColor: tank.variation < 0
                                ? PdfColors.red
                                : (tank.variation > 0 ? PdfColors.green : null),
                            isBold: true,
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
          ),
          

        ],
      ),
    );
    
    return pdf;
  }
  
  // Helper methods for PDF generation
  pw.Widget _buildPdfInfoRow(String label, String value) {
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
  
  pw.Widget _buildPdfTableCell(
    String text, {
    bool isHeader = false,
    PdfColor? textColor,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: isHeader ? PdfColors.white : (textColor ?? PdfColors.black),
          fontSize: 9,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : null,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  // Generate and preview PDF report
  Future<void> _generatePdfReport() async {
    if (reportData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report data available for PDF export')),
      );
      return;
    }

    setState(() {
      isPdfGenerating = true;
    });

    try {
      final pdf = await _createPdf();
      
      // Show the PDF document in the preview
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: '${reportData!.data.stationName}_Report_${_formatDate(reportData!.data.reportDate)}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: ${e.toString()}')),
      );
    } finally {
      setState(() {
        isPdfGenerating = false;
      });
    }
  }
  
  // Share PDF report
  Future<void> _sharePdfReport() async {
    if (reportData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report data available to share')),
      );
      return;
    }

    setState(() {
      isPdfGenerating = true;
    });

    try {
      final pdf = await _createPdf();
      final bytes = await pdf.save();
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${reportData!.data.stationName}_Report_${_formatDate(selectedDate).replaceAll(' ', '_')}.pdf';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsBytes(bytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Comprehensive Daily Report - ${_formatDate(selectedDate)}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share PDF: ${e.toString()}')),
      );
    } finally {
      setState(() {
        isPdfGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Comprehensive Report',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          if (reportData != null) ...[
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: isPdfGenerating ? null : _sharePdfReport,
              tooltip: 'Share Report',
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              onPressed: isPdfGenerating ? null : _generatePdfReport,
              tooltip: 'Export to PDF',
            ),
          ],
          if (isPdfGenerating)
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
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Header with date selector
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Report Date',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withValues(alpha:0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.calendar_month, color: AppTheme.primaryBlue),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              _formatDate(selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.primaryBlue,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Report content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : reportData == null
                        ? const Center(
                            child: Text('No report data available'),
                          )
                        : _buildReportContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    final data = reportData!.data;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          _buildSummaryCards(data),
          
          const SizedBox(height: 16),
          
          // Station info card
          _buildSectionCard(
            title: 'Station Information',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Station Name', data.stationName),
                _buildInfoRow('Report Date', _formatDate(data.reportDate)),
                _buildInfoRow('Generated At', DateFormat('dd MMM yyyy, HH:mm').format(data.generatedAt)),
                _buildInfoRow('Generated By', data.generatedBy),
                _buildInfoRow('Report Period', 
                    '${DateFormat('dd MMM yyyy, HH:mm').format(data.reportPeriodStart)} - ${DateFormat('HH:mm').format(data.reportPeriodEnd)}'),
              ],
            ),
          ),



          
          // Tank Sales Details section
          _buildSectionCard(
            title: 'Tank Sales Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.swipe, size: 16, color: Colors.grey),
                      SizedBox(width: 6),
                      Text(
                        'Swipe horizontally to view all data', 
                        style: TextStyle(
                          fontSize: 12, 
                          color: Colors.grey, 
                          fontStyle: FontStyle.italic
                        ),
                      ),
                    ],
                  ),
                ),
                // Table header
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width - 64,
                    ),
                    child: Column(
                      children: [
                        _buildTableHeader([
                          'Product',
                          'Tank',
                          'Dip',
                          'Opening Stock (L)',
                          'Opening Density',
                          'Load Volume',
                          'Load Density',
                          'Total Stock (L)',
                          'Total Density',
                          'Closing Dip',
                          'Closing Stock (L)',
                          'Closing Density',
                          'Dip Sales',
                          'Meter Sales',
                          'Variation'
                        ]),
                        
                        // Table rows
                        ...data.salesDetails.tankSalesDetails.map((tank) => _buildExpandedTankSalesRow(tank)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Nozzle Details section
          _buildNozzleDetailsSection(data),
          
          // Product Totals section
          _buildSectionCard(
            title: 'Product Totals',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Total Volume (Ltrs)', data.productDetails.total.totalVolumeLtrs.toStringAsFixed(2)),
                _buildInfoRow('Total Amount (Rs)', data.productDetails.total.totalAmountRs.toStringAsFixed(2)),
              ],
            ),
          ),
          
          // Payment Details section
          _buildSectionCard(
            title: 'Payment Details',
            child: data.paymentDetails.paymentModes.isEmpty
                ? const Text('No payment details available')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...data.paymentDetails.paymentModes.map((payment) {
                        // Skip showing modes with zero amount
                        final mode = payment['mode'] as String;
                        final amount = payment['amountRs'] as num;
                        
                        if (amount == 0) return const SizedBox.shrink();
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  _getPaymentModeIcon(mode),
                                  const SizedBox(width: 12),
                                  Text(
                                    mode,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Rs. ${amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(thickness: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Rs. ${data.paymentDetails.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
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

  Widget _buildSummaryCards(ComprehensiveReportData data) {
    // Calculate total products and total tanks
    final uniqueProducts = data.salesDetails.tankSalesDetails.map((tank) => tank.product).toSet();
    final uniqueTanks = data.salesDetails.tankSalesDetails.map((tank) => tank.tank).toSet();
    final totalNozzles = data.nozzleDetails.nozzleDetails.length;
    
    return Row(
      children: [
        _buildSummaryCard(
          title: 'Products',
          value: uniqueProducts.length.toString(),

          color: Colors.blue,
        ),
        const SizedBox(width: 12),
        _buildSummaryCard(
          title: 'Tanks',
          value: uniqueTanks.length.toString(),

          color: Colors.green,
        ),
        const SizedBox(width: 12),
        _buildSummaryCard(
          title: 'Nozzles',
          value: totalNozzles.toString(),

          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withValues(alpha:0.1),
        ),
        child: Row(
          children: [

            const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color.withValues(alpha:0.8),
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

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 140,
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTableHeader(List<String> columns) {
    const double cellWidth = 120.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: columns.map((columnName) {
          return Container(
            width: cellWidth,
            child: Text(
              columnName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppTheme.primaryBlue,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExpandedTankSalesRow(TankSalesDetail tank) {
    const double cellWidth = 120.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: cellWidth,
            child: Text(
              tank.product,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              tank.tank,
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              tank.dip.toString(),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              tank.openingStockVol.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              tank.openingStockDensity.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              tank.loadVol.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              tank.loadDensity.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              tank.totalStockVol.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              tank.totalStockDensity.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              tank.closingDip.toString(),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              tank.closingStockVol.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              tank.closingStockDensity.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              tank.dipSales.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              tank.meterSales.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              tank.variation.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tank.variation < 0 ? Colors.red : (tank.variation > 0 ? Colors.green : Colors.black),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNozzleDetailsSection(ComprehensiveReportData data) {
    return _buildSectionCard(
      title: 'Nozzle Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Icon(Icons.swipe, size: 16, color: Colors.grey),
                SizedBox(width: 6),
                Text(
                  'Swipe horizontally to view all data', 
                  style: TextStyle(
                    fontSize: 12, 
                    color: Colors.grey, 
                    fontStyle: FontStyle.italic
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 64,
              ),
              child: Column(
                children: [
                  // Table header
                  _buildTableHeader([
                    'Dispenser',
                    'Nozzle',
                    'Product',
                    'Tank',
                    'Opening',
                    'Closing',
                    'Testing (L)',
                    'Sales (L)'
                  ]),
                  
                  // Table rows
                  ...data.nozzleDetails.nozzleDetails.map((nozzle) => _buildExpandedNozzleRow(nozzle)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedNozzleRow(NozzleDetail nozzle) {
    const double cellWidth = 120.0;
    final actualSales = nozzle.meterSalesLtrs;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: cellWidth,
            child: Text(
              nozzle.dispenserUnit,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              nozzle.nozzle,
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              nozzle.product,
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              nozzle.tank,
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              nozzle.opening.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              nozzle.closing.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              nozzle.testingLtrs.toStringAsFixed(2),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: cellWidth,
            child: Text(
              actualSales.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: actualSales < 0 ? Colors.red : (actualSales > 0 ? Colors.green : Colors.black),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get the appropriate icon for payment mode
  Widget _getPaymentModeIcon(String mode) {
    IconData iconData;
    Color iconColor;
    
    if (mode.toLowerCase().contains('cash')) {
      iconData = Icons.money;
      iconColor = Colors.green.shade700;
    } else if (mode.toLowerCase().contains('upi')) {
      iconData = Icons.phone_android;
      iconColor = Colors.purple.shade700;
    } else if (mode.toLowerCase().contains('card') || mode.toLowerCase().contains('credit')) {
      iconData = Icons.credit_card;
      iconColor = Colors.blue.shade700;
    } else {
      iconData = Icons.payment;
      iconColor = Colors.orange.shade700;
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        size: 16,
        color: iconColor,
      ),
    );
  }
} 