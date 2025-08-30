import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/api_constants.dart';
import '../../api/nozzle_reading_repository.dart';
import '../../models/nozzle_reading_model.dart';
import '../../theme.dart';
import 'dart:developer' as developer;

class NozzleReadingsDetailScreen extends StatefulWidget {
  final String employeeId;
  final String nozzleId;
  final String nozzleNumber;
  final String fuelType;
  final String employeeName;

  const NozzleReadingsDetailScreen({
    Key? key,
    required this.employeeId,
    required this.nozzleId,
    required this.nozzleNumber,
    required this.fuelType,
    required this.employeeName,
  }) : super(key: key);

  @override
  State<NozzleReadingsDetailScreen> createState() => _NozzleReadingsDetailScreenState();
}

class _NozzleReadingsDetailScreenState extends State<NozzleReadingsDetailScreen> {
  final NozzleReadingRepository _nozzleReadingRepository = NozzleReadingRepository();
  
  bool _isLoading = true;
  String _errorMessage = '';
  List<NozzleReading> _nozzleReadings = [];
  List<NozzleReading> _filteredReadings = [];
  
  // Date range filter
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _fetchNozzleReadings();
  }
  
  Future<void> _fetchNozzleReadings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      developer.log('Fetching nozzle readings for nozzle ID: ${widget.nozzleId}');
      
      final response = await _nozzleReadingRepository.getNozzleReadingsByNozzleId(widget.nozzleId);
      
      setState(() {
        _isLoading = false;
        
        if (response.success && response.data != null) {
          _nozzleReadings = response.data!;
          
          // Sort readings by timestamp (newest first)
          _nozzleReadings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          
          // Apply date filter
          _applyDateFilter();
          
          developer.log('Loaded ${_nozzleReadings.length} readings for nozzle ${widget.nozzleNumber}');
        } else {
          _errorMessage = response.errorMessage ?? 'Failed to load nozzle readings';
          developer.log('Error loading nozzle readings: $_errorMessage');
        }
      });
    } catch (e) {
      developer.log('Exception in _fetchNozzleReadings: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }
  
  void _applyDateFilter() {
    // Filter readings based on date range
    _filteredReadings = _nozzleReadings.where((reading) {
      return reading.timestamp.isAfter(_startDate.subtract(const Duration(days: 1))) && 
             reading.timestamp.isBefore(_endDate.add(const Duration(days: 1)));
    }).toList();
  }
  
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2021),
      lastDate: _endDate,
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
    
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        _applyDateFilter();
      });
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
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
        _applyDateFilter();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Nozzle ${widget.nozzleNumber} Readings',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Date Range',
            onPressed: () => _showDateFilterBottomSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNozzleReadings,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading 
          ? _buildLoadingView()
          : RefreshIndicator(
              onRefresh: _fetchNozzleReadings,
              color: AppTheme.primaryBlue,
              child: _buildBody(),
            ),
    );
  }
  
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading readings...',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBody() {
    if (_errorMessage.isNotEmpty) {
      return _buildErrorView();
    }
    
    if (_filteredReadings.isEmpty) {
      return _buildEmptyView();
    }

    return _buildReadingsView();
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: AppTheme.primaryOrange,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Readings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _fetchNozzleReadings,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCompactInfoHeader(),
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.gas_meter,
                color: AppTheme.primaryBlue,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Readings Found',
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
                'No meter readings have been recorded for this nozzle yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _fetchNozzleReadings,
              icon: Icon(Icons.refresh, color: AppTheme.primaryBlue),
              label: Text(
                'Refresh',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
                side: BorderSide(color: AppTheme.primaryBlue),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  Widget _buildReadingsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact Info Header
        _buildCompactInfoHeader(),
        
        // Readings Table
        Expanded(
          child: _buildReadingsTable(),
        ),
      ],
    );
  }
  
  Widget _buildCompactInfoHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Date range filter display
          Row(
            children: [
              Icon(Icons.filter_list, color: Colors.grey.shade600, size: 16),
              const SizedBox(width: 8),
              Text(
                'Date Filter:',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showDateFilterBottomSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d').format(_endDate)}',
                        style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Nozzle info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left column - Nozzle & Employee info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.grey.shade600, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Employee: ${widget.employeeName}',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.local_gas_station, color: Colors.grey.shade600, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Nozzle: ${widget.nozzleNumber}',
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Right column - Fuel type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primaryOrange.withValues(alpha:0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.fuelType,
                  style: TextStyle(
                    color: AppTheme.primaryOrange,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildReadingsTable() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                _buildTableHeaderCell('Type', 1),
                _buildTableHeaderCell('Reading', 1),
                _buildTableHeaderCell('Volume', 1),
                _buildTableHeaderCell('Date/Time', 2),
                const SizedBox(width: 20), // Space for view button
              ],
            ),
          ),
          
          // Table body
          Expanded(
            child: ListView.builder(
              itemCount: _filteredReadings.length,
              itemBuilder: (context, index) {
                final reading = _filteredReadings[index];
                return _buildReadingRow(reading, index);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTableHeaderCell(String title, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }
  
  Widget _buildReadingRow(NozzleReading reading, int index) {
    // Format date
    DateTime readingDate = reading.timestamp;
    String formattedDate = DateFormat('MMM d').format(readingDate);
    String formattedTime = DateFormat('h:mm a').format(readingDate);
    
    // Calculate volume dispensed if possible
    double? volumeDispensed;
    String volumeText = 'N/A';
    if (index < _filteredReadings.length - 1) {
      final previousReading = _filteredReadings[index + 1];
      if (previousReading.startReading != null && reading.startReading != null) {
        volumeDispensed = reading.startReading - previousReading.startReading;
        volumeText = volumeDispensed.toStringAsFixed(2) + ' L';
      }
    }
    
    // Determine reading type
    final readingType = reading.readingType?.toLowerCase() ?? '';
    final isStartReading = readingType == 'start';
    final isEndReading = readingType == 'end';
    
    // Set colors based on reading type
    Color typeColor = Colors.grey;
    if (isStartReading) {
      typeColor = Colors.blue;
    } else if (isEndReading) {
      typeColor = Colors.green;
    }
    
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: InkWell(
        onTap: () => _showReadingDetails(reading),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Type
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: typeColor.withValues(alpha:0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        reading.readingType?.toUpperCase() ?? 'READ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Reading
              Expanded(
                child: Text(
                  reading.startReading.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              
              // Volume
              Expanded(
                child: Text(
                  volumeText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: volumeDispensed != null 
                        ? AppTheme.primaryOrange 
                        : Colors.grey.shade500,
                  ),
                ),
              ),
              
              // Date/Time
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // View details button
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.visibility,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
                onPressed: () => _showReadingDetails(reading),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showReadingDetails(NozzleReading reading) {
    // Format date
    DateTime readingDate = reading.timestamp;
    String formattedDate = DateFormat('MMM d, yyyy').format(readingDate);
    String formattedTime = DateFormat('h:mm a').format(readingDate);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.gas_meter,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reading Details',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type and Time row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.label_outline,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Type: ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            reading.readingType?.toUpperCase() ?? 'READING',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$formattedDate at \n'
                                '$formattedTime',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Meter Reading row
                  Row(
                    children: [
                      Icon(
                        Icons.speed,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Meter Reading: ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${reading.startReading.toStringAsFixed(2)} L',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  
                  // Reading image if available
                  if (reading.readingImage != null && reading.readingImage!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reading Image:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                              color: Colors.grey.shade50,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                ApiConstants.baseUrl + reading.readingImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.grey.shade400,
                                          size: 36,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Unable to load image',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w500,
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

  void _showDateFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.date_range, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Select Date Range',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Date',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _selectStartDate(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: AppTheme.primaryBlue),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('MMM d, yyyy').format(_startDate),
                                  style: const TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End Date',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _selectEndDate(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: AppTheme.primaryBlue),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('MMM d, yyyy').format(_endDate),
                                  style: const TextStyle(
                                    fontSize: 16,
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
              const SizedBox(height: 20),
              Row(
                children: [
                  // Quick filter buttons
                  _buildQuickFilterChip('Last 7 days', () {
                    setState(() {
                      _endDate = DateTime.now();
                      _startDate = _endDate.subtract(const Duration(days: 7));
                      _applyDateFilter();
                    });
                    Navigator.pop(context);
                  }),
                  const SizedBox(width: 8),
                  _buildQuickFilterChip('Last 30 days', () {
                    setState(() {
                      _endDate = DateTime.now();
                      _startDate = _endDate.subtract(const Duration(days: 30));
                      _applyDateFilter();
                    });
                    Navigator.pop(context);
                  }),
                  const SizedBox(width: 8),
                  _buildQuickFilterChip('This month', () {
                    final now = DateTime.now();
                    setState(() {
                      _endDate = now;
                      _startDate = DateTime(now.year, now.month, 1);
                      _applyDateFilter();
                    });
                    Navigator.pop(context);
                  }),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _applyDateFilter();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Apply Filter'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickFilterChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppTheme.primaryBlue,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
} 