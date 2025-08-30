import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/nozzle_reading_repository.dart';
import '../../models/nozzle_reading_model.dart';
import '../../theme.dart';
import '../../api/api_constants.dart';
import 'dart:developer' as developer;

class AllReadingsByNozzleScreen extends StatefulWidget {
  const AllReadingsByNozzleScreen({super.key});

  @override
  State<AllReadingsByNozzleScreen> createState() => _AllReadingsByNozzleScreenState();
}

class _AllReadingsByNozzleScreenState extends State<AllReadingsByNozzleScreen> {
  final _nozzleReadingRepository = NozzleReadingRepository();
  
  bool _isLoadingNozzles = true;
  bool _isLoadingReadings = false;
  String _errorMessage = '';
  List<dynamic> _nozzles = [];
  List<NozzleReading> _readings = [];
  
  dynamic _selectedNozzle;

  @override
  void initState() {
    super.initState();
    _loadNozzles();
  }

  Future<void> _loadNozzles() async {
    setState(() {
      _isLoadingNozzles = true;
      _errorMessage = '';
    });

    try {
      final response = await _nozzleReadingRepository.getAllNozzles();
      
      setState(() {
        _isLoadingNozzles = false;
        
        if (response.success && response.data != null) {
          _nozzles = response.data!;
          developer.log('AllReadingsByNozzleScreen: Loaded ${_nozzles.length} nozzles');
          
          // Select the first nozzle by default if available
          if (_nozzles.isNotEmpty) {
            _selectedNozzle = _nozzles.first;
            _loadReadingsByNozzle(_selectedNozzle['nozzleId']);
          }
        } else {
          _errorMessage = response.errorMessage ?? 'Failed to load nozzles';
          developer.log('AllReadingsByNozzleScreen: Error loading nozzles: $_errorMessage');
        }
      });
    } catch (e) {
      developer.log('AllReadingsByNozzleScreen: Exception in _loadNozzles: $e');
      setState(() {
        _isLoadingNozzles = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _loadReadingsByNozzle(String nozzleId) async {
    setState(() {
      _isLoadingReadings = true;
      _errorMessage = '';
    });

    try {
      final response = await _nozzleReadingRepository.getNozzleReadingsByNozzleId(nozzleId);
      
      setState(() {
        _isLoadingReadings = false;
        
        if (response.success && response.data != null) {
          _readings = response.data!;
          developer.log('AllReadingsByNozzleScreen: Loaded ${_readings.length} readings for nozzle $nozzleId');
        } else {
          _errorMessage = response.errorMessage ?? 'Failed to load readings';
          developer.log('AllReadingsByNozzleScreen: Error loading readings: $_errorMessage');
        }
      });
    } catch (e) {
      developer.log('AllReadingsByNozzleScreen: Exception in _loadReadingsByNozzle: $e');
      setState(() {
        _isLoadingReadings = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Readings by Nozzle',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Nozzle selector
          _buildNozzleSelector(),
          
          // Loading indicator or error
          if (_isLoadingReadings)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage.isNotEmpty)
            Expanded(child: _buildErrorView())
          else if (_readings.isEmpty)
            Expanded(child: _buildEmptyView())
          else
            // Readings list
            Expanded(child: _buildReadingsList()),
        ],
      ),
    );
  }

  Widget _buildNozzleSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _isLoadingNozzles 
        ? const Center(
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Nozzle',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              _nozzles.isEmpty
                ? Text(
                    'No nozzles available',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : DropdownButtonFormField<dynamic>(
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.primaryBlue),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    value: _selectedNozzle,
                    items: _nozzles.map((nozzle) {
                      final nozzleNumber = nozzle['nozzleNumber'] ?? 'N/A';
                      final fuelType = nozzle['fuelType'] ?? 'Unknown';
                      final dispenserNumber = nozzle['dispenserNumber'] ?? 'N/A';
                      
                      return DropdownMenuItem<dynamic>(
                        value: nozzle,
                        child: Text(
                          'Nozzle $nozzleNumber ($fuelType, Dispenser $dispenserNumber)',
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (nozzle) {
                      if (nozzle != null && nozzle['nozzleId'] != _selectedNozzle?['nozzleId']) {
                        setState(() {
                          _selectedNozzle = nozzle;
                        });
                        _loadReadingsByNozzle(nozzle['nozzleId']);
                      }
                    },
                  ),
            ],
          ),
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
            if (_selectedNozzle != null)
              ElevatedButton.icon(
                onPressed: () => _loadReadingsByNozzle(_selectedNozzle['nozzleId']),
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
              'There are no readings for this nozzle',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            if (_selectedNozzle != null)
              ElevatedButton.icon(
                onPressed: () => _loadReadingsByNozzle(_selectedNozzle['nozzleId']),
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
    // Group readings by date
    final Map<String, List<NozzleReading>> groupedReadings = {};
    
    for (var reading in _readings) {
      final dateStr = DateFormat('MMM d, yyyy').format(reading.createdAt);
      if (!groupedReadings.containsKey(dateStr)) {
        groupedReadings[dateStr] = [];
      }
      groupedReadings[dateStr]!.add(reading);
    }
    
    // Sort dates in descending order (most recent first)
    final sortedDates = groupedReadings.keys.toList()
      ..sort((a, b) => DateFormat('MMM d, yyyy').parse(b).compareTo(
          DateFormat('MMM d, yyyy').parse(a)));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dateReadings = groupedReadings[date]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha:0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${dateReadings.length} readings',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Readings for this date
            ...dateReadings.map((reading) => _buildReadingCard(reading)).toList(),
            // Add space between date groups
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildReadingCard(NozzleReading reading) {
    final readingType = reading.readingType ?? 'Unknown';
    final hasImage = reading.readingImage != null && reading.readingImage!.isNotEmpty;
    final typeColor = _getReadingTypeColor(readingType);
    
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha:0.1),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with reading type and time
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha:0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: typeColor.withValues(alpha:0.15),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getReadingTypeIcon(readingType),
                      color: typeColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$readingType Reading',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: typeColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM d, h:mm a').format(reading.recordedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
            
            // Reading details - main content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Nozzle and meter details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badges row
                        Row(
                          children: [
                            // Nozzle badge
                            _buildInfoBadge(
                              icon: Icons.local_gas_station,
                              label: 'Nozzle ${reading.nozzleNumber}',
                              color: typeColor,
                            ),
                            const SizedBox(width: 8),
                            // Dispenser badge
                            _buildInfoBadge(
                              icon: Icons.ev_station,
                              label: 'Dispenser ${reading.dispenserNumber}',
                              color: Colors.blueGrey.shade600,
                              lightBg: true,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Meter reading section
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Meter reading
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Meter Reading',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      reading.meterReading.toStringAsFixed(2),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'L',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Employee name
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Recorded by',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 14,
                                      color: AppTheme.primaryBlue.withValues(alpha:0.7),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      reading.employeeName ?? 'Unknown',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Image button - if available
                  if (hasImage)
                    Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: InkWell(
                        onTap: () => _viewImage(reading.readingImage),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha:0.05),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.zoom_in_outlined,
                              color: Colors.blueGrey,
                              size: 24,
                            ),
                          ),
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

  // Helper widget for badges
  Widget _buildInfoBadge({
    required IconData icon,
    required String label,
    required Color color,
    bool lightBg = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: lightBg ? color.withValues(alpha:0.08) : color.withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  // Add view image method
  void _viewImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      _showNoImageDialog();
      return;
    }
    
    // Log the image URL for debugging
    developer.log('AllReadingsByNozzleScreen: Attempting to load image: $imageUrl');
    
    // Construct proper API URL using the same base URL as API calls
    final String fullImageUrl = imageUrl.startsWith('http') 
        ? imageUrl 
        : '${ApiConstants.baseUrl}$imageUrl';
    
    developer.log('AllReadingsByNozzleScreen: Full image URL: $fullImageUrl');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reading Image',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Image container with loading state
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                  maxWidth: MediaQuery.of(context).size.width,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Loading indicator shown by default
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                      // Image
                      Image.network(
                        fullImageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }
                          return Container(
                            height: 300,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(16),
                            child: const CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          developer.log('AllReadingsByNozzleScreen: Error loading image: $error');
                          return Container(
                            height: 200,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 64,
                                  color: Colors.red.shade300,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.red, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Error: ${error.toString()}',
                                  style: TextStyle(
                                    color: Colors.red.shade700, 
                                    fontSize: 12
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Show dialog for no image
  void _showNoImageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('No Image Available'),
          content: const Text('This reading does not have an associated image.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: TextStyle(color: AppTheme.primaryBlue),
              ),
            ),
          ],
        );
      },
    );
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
} 