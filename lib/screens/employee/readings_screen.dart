import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme.dart';
import '../../models/nozzle_reading_model.dart';
import '../../api/nozzle_reading_repository.dart';
import 'dart:developer' as developer;

class ReadingsScreen extends StatefulWidget {
  const ReadingsScreen({super.key});

  @override
  State<ReadingsScreen> createState() => _ReadingsScreenState();
}

class _ReadingsScreenState extends State<ReadingsScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<NozzleReading> _readings = [];
  final _nozzleReadingRepository = NozzleReadingRepository();

  @override
  void initState() {
    super.initState();
    _fetchReadings();
  }

  Future<void> _fetchReadings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Use mock data for initial UI development
      final response = await _nozzleReadingRepository.getMockNozzleReadings();
      
      setState(() {
        _isLoading = false;
        
        if (response.success && response.data != null) {
          _readings = response.data!;
          developer.log('Loaded ${_readings.length} nozzle readings');
        } else {
          _errorMessage = response.errorMessage ?? 'Failed to load readings';
          developer.log('Error loading readings: $_errorMessage');
        }
      });
    } catch (e) {
      developer.log('Exception in _fetchReadings: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  // Helper method to get color based on fuel type
  Color _getFuelTypeColor(String fuelType) {
    switch (fuelType.toLowerCase()) {
      case 'petrol':
        return Colors.green.shade700;
      case 'diesel':
        return Colors.orange.shade800;
      case 'premium':
      case 'premium petrol':
        return Colors.purple.shade700;
      case 'premium diesel':
        return Colors.deepPurple.shade800;
      case 'cng':
        return Colors.teal.shade700;
      case 'lpg':
        return Colors.indigo.shade700;
      case 'bio-diesel':
        return Colors.amber.shade800;
      case 'electric':
        return Colors.cyan.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  // Helper method to get icon based on reading type
  IconData _getReadingTypeIcon(String readingType) {
    switch (readingType.toLowerCase()) {
      case 'start':
        return Icons.play_circle_outline;
      case 'end':
        return Icons.stop_circle_outlined;
      default:
        return Icons.access_time;
    }
  }

  // Helper method to get color based on reading type
  Color _getReadingTypeColor(String readingType) {
    switch (readingType.toLowerCase()) {
      case 'start':
        return Colors.green.shade600;
      case 'end':
        return Colors.red.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Nozzle Readings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReadings,
            tooltip: 'Refresh readings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _readings.isEmpty
                  ? _buildEmptyView()
                  : _buildReadingsList(),
    );
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
              size: 60,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Readings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchReadings,
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
            Icon(
              Icons.history,
              size: 60,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No Readings Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no nozzle readings to display',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchReadings,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
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

  Widget _buildReadingsList() {
    // Group readings by date for better organization
    Map<String, List<NozzleReading>> groupedReadings = {};
    
    for (var reading in _readings) {
      final dateStr = DateFormat('yyyy-MM-dd').format(reading.recordedAt);
      if (!groupedReadings.containsKey(dateStr)) {
        groupedReadings[dateStr] = [];
      }
      groupedReadings[dateStr]!.add(reading);
    }
    
    // Sort dates in descending order (most recent first)
    final sortedDates = groupedReadings.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    
    return RefreshIndicator(
      onRefresh: _fetchReadings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final date = sortedDates[index];
          final dateReadings = groupedReadings[date]!;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateHeader(date),
              const SizedBox(height: 8),
              ...dateReadings.map((reading) => _buildReadingCard(reading)).toList(),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    
    String displayDate;
    if (DateFormat('yyyy-MM-dd').format(now) == dateStr) {
      displayDate = 'Today';
    } else if (DateFormat('yyyy-MM-dd').format(yesterday) == dateStr) {
      displayDate = 'Yesterday';
    } else {
      displayDate = DateFormat('EEEE, MMMM d, yyyy').format(date);
    }
    
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 16, bottom: 8),
      child: Text(
        displayDate,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildReadingCard(NozzleReading reading) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with reading type and time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _getReadingTypeColor(reading.readingType).withValues(alpha:0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: _getReadingTypeColor(reading.readingType).withValues(alpha:0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getReadingTypeColor(reading.readingType).withValues(alpha:0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getReadingTypeIcon(reading.readingType),
                    color: _getReadingTypeColor(reading.readingType),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${reading.readingType} Reading',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _getReadingTypeColor(reading.readingType),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            DateFormat('h:mm a').format(reading.recordedAt),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
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
          ),
          
          // Reading details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nozzle and fuel info
                Row(
                  children: [
                    // Nozzle number badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getFuelTypeColor(reading.fuelType),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_gas_station,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Nozzle ${reading.nozzleNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Fuel type badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getFuelTypeColor(reading.fuelType),
                        ),
                      ),
                      child: Text(
                        reading.fuelType,
                        style: TextStyle(
                          color: _getFuelTypeColor(reading.fuelType),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Dispenser number
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.ev_station,
                            size: 12,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Dispenser ${reading.dispenserNumber}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Meter reading
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meter Reading',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.speed,
                                size: 20,
                                color: AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                reading.meterReading.toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Liters',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (reading.readingImage != null && reading.readingImage!.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () {
                            // Show image in dialog
                            _showReadingImage(context, reading.readingImage!);
                          },
                          icon: const Icon(Icons.image, size: 16),
                          label: const Text('View Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Employee info and timestamp
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Recorded by: ${reading.employeeName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.update,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, yyyy').format(reading.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
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

  void _showReadingImage(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Reading Image'),
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  'https://yourapi.com$imagePath',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Image not available',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      color: Colors.grey.shade100,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Mock data for testing
List<NozzleReading> getMockReadings() {
  return [
    NozzleReading(
      nozzleReadingId: "8b324890-3ee6-4f2a-816a-880925717d74",
      nozzleId: "5bf6555c-af93-450e-a649-b473297340c0",
      employeeId: "40c60ab3-f5e3-47d8-8ae4-07d58b0b3ad9",
      shiftId: "07af608f-485f-437e-a6bb-37a4eff7081f",
      readingType: "End",
      meterReading: 2610.00,
      readingImage: "/images//2025/5/a6db4aec-a35a-44d7-9716-bdff8bc96ab4_scaled_3b3d05f1-16ac-495a-87ff-6f9a451380043266111453305340816.jpg",
      recordedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      employeeName: "Paul Smith",
      nozzleNumber: "1",
      fuelType: "Diesel",
      fuelTypeId: "e7e7b1b2-e7ff-4d59-a22d-64bff68ccbf6",
      dispenserNumber: "1",
      fuelTankId: null,
      petrolPumpId: null,
    ),
    NozzleReading(
      nozzleReadingId: "96979008-1c3b-40a9-9758-158673a6d492",
      nozzleId: "5bf6555c-af93-450e-a649-b473297340c0",
      employeeId: "40c60ab3-f5e3-47d8-8ae4-07d58b0b3ad9",
      shiftId: "07af608f-485f-437e-a6bb-37a4eff7081f",
      readingType: "Start",
      meterReading: 2510.00,
      readingImage: "/images//2025/5/96341438-5858-4fa1-8d7b-490a64c5d966_scaled_c386a0c8-aa24-4f1f-a1ee-ca058ff89f5f7784420209478091301.jpg",
      recordedAt: DateTime.now().subtract(const Duration(hours: 8)),
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 8)),
      employeeName: "Paul Smith",
      nozzleNumber: "1",
      fuelType: "Diesel",
      fuelTypeId: "e7e7b1b2-e7ff-4d59-a22d-64bff68ccbf6",
      dispenserNumber: "1",
      fuelTankId: null,
      petrolPumpId: null,
    ),
    NozzleReading(
      nozzleReadingId: "a1b2c3d4-e5f6-4f2a-816a-880925717d74",
      nozzleId: "5bf6555c-af93-450e-a649-b473297340c0",
      employeeId: "40c60ab3-f5e3-47d8-8ae4-07d58b0b3ad9",
      shiftId: "07af608f-485f-437e-a6bb-37a4eff7081f",
      readingType: "End",
      meterReading: 1850.75,
      readingImage: "/images//2025/5/sample_image.jpg",
      recordedAt: DateTime.now().subtract(const Duration(days: 1)),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      employeeName: "Paul Smith",
      nozzleNumber: "2",
      fuelType: "Petrol",
      fuelTypeId: "f8e7b1b2-e7ff-4d59-a22d-64bff68ccbf6",
      dispenserNumber: "2",
      fuelTankId: null,
      petrolPumpId: null,
    ),
    NozzleReading(
      nozzleReadingId: "b2c3d4e5-f6g7-40a9-9758-158673a6d492",
      nozzleId: "5bf6555c-af93-450e-a649-b473297340c0",
      employeeId: "40c60ab3-f5e3-47d8-8ae4-07d58b0b3ad9",
      shiftId: "07af608f-485f-437e-a6bb-37a4eff7081f",
      readingType: "Start",
      meterReading: 1800.50,
      readingImage: "/images//2025/5/another_sample.jpg",
      recordedAt: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
      employeeName: "Paul Smith",
      nozzleNumber: "2",
      fuelType: "Petrol",
      fuelTypeId: "f8e7b1b2-e7ff-4d59-a22d-64bff68ccbf6",
      dispenserNumber: "2",
      fuelTankId: null,
      petrolPumpId: null,
    ),
  ];
} 