import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/nozzle_reading_repository.dart';
import '../../models/nozzle_reading_model.dart';
import '../../theme.dart';
import 'dart:developer' as developer;
import 'dart:convert';

class AllReadingsByEmployeeScreen extends StatefulWidget {
  const AllReadingsByEmployeeScreen({super.key});

  @override
  State<AllReadingsByEmployeeScreen> createState() => _AllReadingsByEmployeeScreenState();
}

class _AllReadingsByEmployeeScreenState extends State<AllReadingsByEmployeeScreen> {
  final _nozzleReadingRepository = NozzleReadingRepository();
  
  bool _isLoadingEmployees = true;
  bool _isLoadingReadings = false;
  String _errorMessage = '';
  List<dynamic> _employees = [];
  List<NozzleReading> _readings = [];
  
  dynamic _selectedEmployee;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoadingEmployees = true;
      _errorMessage = '';
    });

    try {
      final response = await _nozzleReadingRepository.getAllEmployees();
      
      // Add detailed debugging
      print('Employee response success: ${response.success}');
      print('Employee response data type: ${response.data.runtimeType}');
      print('Employee response data: ${jsonEncode(response.data)}');
      
      setState(() {
        _isLoadingEmployees = false;
        
        if (response.success && response.data != null) {
          // Handle both cases: when data is a Map or a List
          if (response.data is List) {
            print('Processing employees as List');
            _employees = response.data!;
          } else if (response.data is Map<String, dynamic>) {
            print('Processing employees as Map');
            // Try to extract employees list from the Map
            final map = response.data as Map<String, dynamic>;
            print('Employees data is a Map. Keys: ${map.keys.join(", ")}');
            
            if (map.containsKey('employees')) {
              _employees = map['employees'] as List;
            } else if (map.containsKey('data')) {
              _employees = map['data'] as List;
            } else {
              // Try to find the first list in the map
              try {
                final listEntry = map.entries.firstWhere(
                  (entry) => entry.value is List,
                  orElse: () => MapEntry('', []),
                );
                
                if (listEntry.value is List) {
                  print('Using employees list found with key: ${listEntry.key}');
                  _employees = listEntry.value as List;
                } else {
                  print('Could not find employees list in response');
                  // Use a mock employee as a fallback
                  _useMockEmployee();
                }
              } catch (e) {
                print('Error finding list in map: $e');
                // Use a mock employee as a fallback
                _useMockEmployee();
              }
            }
          } else {
            print('Unexpected employees data type: ${response.data.runtimeType}');
            // Use a mock employee as a fallback
            _useMockEmployee();
          }
          
          // If we still have no employees after all attempts, use a mock
          if (_employees.isEmpty) {
            _useMockEmployee();
          } else {
            developer.log('AllReadingsByEmployeeScreen: Loaded ${_employees.length} employees');
            print('Employees data: ${jsonEncode(_employees)}');
            
            // Select the first employee by default if available
            _selectedEmployee = _employees.first;
            _loadReadingsByEmployee(_selectedEmployee['employeeId']);
          }
        } else {
          _errorMessage = response.errorMessage ?? 'Failed to load employees';
          developer.log('AllReadingsByEmployeeScreen: Error loading employees: $_errorMessage');
          print('Error loading employees: $_errorMessage');
          
          // Use a mock employee as a fallback
          _useMockEmployee();
        }
      });
    } catch (e) {
      developer.log('AllReadingsByEmployeeScreen: Exception in _loadEmployees: $e');
      print('Exception in _loadEmployees: $e');
      setState(() {
        _isLoadingEmployees = false;
        _errorMessage = 'Error: $e';
        
        // Use a mock employee as a fallback
        _useMockEmployee();
      });
    }
  }

  Future<void> _loadReadingsByEmployee(String employeeId) async {
    setState(() {
      _isLoadingReadings = true;
      _errorMessage = '';
    });

    try {
      final response = await _nozzleReadingRepository.getNozzleReadingsForEmployee(employeeId);
      
      // Fix the print statement to avoid encoding the entire ApiResponse object
      print('API Response success for employee $employeeId: ${response.success}');
      print('Response data available: ${response.data != null}');
      if (response.data != null) {
        print('Response data count: ${response.data!.length}');
      }
      
      setState(() {
        _isLoadingReadings = false;
        
        if (response.success && response.data != null) {
          // Handle both cases: when data is a Map or a List
          if (response.data is List) {
            print('Parsing response data as List');
            final dataList = response.data as List;
            _readings = dataList.map((item) {
              // Check if item is already a NozzleReading or needs to be converted
              if (item is NozzleReading) {
                return item;
              } else if (item is Map<String, dynamic>) {
                return NozzleReading.fromJson(item);
              } else {
                throw Exception('Unexpected item type in response: ${item.runtimeType}');
              }
            }).toList();
          } else if (response.data is Map) {
            print('Parsing response data as Map');
            // Check if the map contains a 'readings' key or similar that holds the actual list
            final map = response.data as Map<String, dynamic>;
            
            if (map.containsKey('readings')) {
              final readingsList = map['readings'] as List;
              _readings = readingsList.map((item) {
                if (item is NozzleReading) {
                  return item;
                } else if (item is Map<String, dynamic>) {
                  return NozzleReading.fromJson(item);
                } else {
                  throw Exception('Unexpected item type in readings: ${item.runtimeType}');
                }
              }).toList();
            } else if (map.containsKey('data')) {
              final readingsList = map['data'] as List;
              _readings = readingsList.map((item) {
                if (item is NozzleReading) {
                  return item;
                } else if (item is Map<String, dynamic>) {
                  return NozzleReading.fromJson(item);
                } else {
                  throw Exception('Unexpected item type in data: ${item.runtimeType}');
                }
              }).toList();
            } else {
              // Try to extract the first list found in the map
              final listEntry = map.entries.firstWhere(
                (entry) => entry.value is List,
                orElse: () => MapEntry('', []),
              );
              
              if (listEntry.value is List) {
                print('Using list found with key: ${listEntry.key}');
                final readingsList = listEntry.value as List;
                _readings = readingsList.map((item) {
                  if (item is NozzleReading) {
                    return item;
                  } else if (item is Map<String, dynamic>) {
                    return NozzleReading.fromJson(item);
                  } else {
                    throw Exception('Unexpected item type in ${listEntry.key}: ${item.runtimeType}');
                  }
                }).toList();
              } else {
                throw Exception('Could not find readings list in response');
              }
            }
            
            print('Successfully parsed ${_readings.length} readings');
            developer.log('AllReadingsByEmployeeScreen: Loaded ${_readings.length} readings for employee $employeeId');
          } else {
            _errorMessage = response.errorMessage ?? 'Failed to load readings';
            print('Error loading readings: $_errorMessage');
            developer.log('AllReadingsByEmployeeScreen: Error loading readings: $_errorMessage');
          }
        } else {
          _errorMessage = response.errorMessage ?? 'Failed to load readings';
          print('Error loading readings: $_errorMessage');
          developer.log('AllReadingsByEmployeeScreen: Error loading readings: $_errorMessage');
        }
      });
    } catch (e) {
      print('Exception in _loadReadingsByEmployee: $e');
      developer.log('AllReadingsByEmployeeScreen: Exception in _loadReadingsByEmployee: $e');
      setState(() {
        _isLoadingReadings = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  // Helper method to use a mock employee when API fails
  void _useMockEmployee() {
    print('Using mock employee as fallback');
    _employees = [
      {
        'employeeId': 'mock-employee-1',
        'fullName': 'Demo Employee',
        'role': 'Attendant'
      }
    ];
    _selectedEmployee = _employees.first;
    _loadReadingsByEmployee(_selectedEmployee['employeeId']);
  }

  // Open image preview dialog
  void _viewImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      _showNoImageDialog();
      return;
    }
    
    // Log the image URL for debugging
    developer.log('AllReadingsByEmployeeScreen: Attempting to load image: $imageUrl');
    
    // Construct proper API URL using the same base URL as API calls
    final String fullImageUrl = imageUrl.startsWith('http') 
        ? imageUrl 
        : 'https://pump360.planet.ninja$imageUrl';
    
    developer.log('AllReadingsByEmployeeScreen: Full image URL: $fullImageUrl');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
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
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
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
                            developer.log('AllReadingsByEmployeeScreen: Error loading image: $error');
                            return Container(
                              height: 200,
                              width: double.infinity,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(16),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
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
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
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
          'Readings by Employee',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Employee selector
          _buildEmployeeSelector(),
          
          // Stats bar - showing count of readings
          if (!_isLoadingReadings && _readings.isNotEmpty)
            _buildStatsBar(),
          
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

  Widget _buildEmployeeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _isLoadingEmployees 
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
                'Select Employee',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              _employees.isEmpty
                ? Text(
                    'No employees available',
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
                    value: _selectedEmployee,
                    items: _employees.map((employee) {
                      final name = employee['fullName'] ?? employee['firstName'] ?? 'Unknown';
                      final role = employee['role'] ?? 'Employee';
                      
                      return DropdownMenuItem<dynamic>(
                        value: employee,
                        child: Text(
                          '$name ($role)',
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (employee) {
                      if (employee != null && employee['employeeId'] != _selectedEmployee?['employeeId']) {
                        setState(() {
                          _selectedEmployee = employee;
                        });
                        _loadReadingsByEmployee(employee['employeeId']);
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
            if (_selectedEmployee != null)
              ElevatedButton.icon(
                onPressed: () => _loadReadingsByEmployee(_selectedEmployee['employeeId']),
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
              'There are no readings for this employee',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            if (_selectedEmployee != null)
              ElevatedButton.icon(
                onPressed: () => _loadReadingsByEmployee(_selectedEmployee['employeeId']),
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
      final dateStr = DateFormat('MMM d, yyyy').format(reading.recordedAt);
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
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withOpacity(0.3),
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
    final fuelColor = _getFuelTypeColor(reading.fuelType ?? 'Unknown');
    final baseImageUrl = 'https://pumpbe.pxc.in';
    final imageUrl = hasImage ? '$baseImageUrl${reading.readingImage}' : null;
    
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with reading type and time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: typeColor.withOpacity(0.15),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getReadingTypeIcon(readingType),
                    color: typeColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
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
                ),
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
                      // Badges row - wrap in SingleChildScrollView to avoid overflow
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
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
                              color: Colors.black.withOpacity(0.05),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.zoom_in_rounded,
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
        color: lightBg ? color.withOpacity(0.08) : color.withOpacity(0.15),
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

  Widget _buildStatsBar() {
    // Count start and end readings
    int startReadings = 0;
    int endReadings = 0;
    
    for (var reading in _readings) {
      if (reading.readingType?.toLowerCase() == 'start') {
        startReadings++;
      } else if (reading.readingType?.toLowerCase() == 'end') {
        endReadings++;
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            title: 'Total',
            value: _readings.length.toString(),
            icon: Icons.analytics_outlined,
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(width: 8),
          _buildStatItem(
            title: 'Start',
            value: startReadings.toString(),
            icon: Icons.play_arrow,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 8),
          _buildStatItem(
            title: 'End',
            value: endReadings.toString(),
            icon: Icons.stop,
            color: Colors.red.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String title, 
    required String value, 
    required IconData icon,
    required Color color
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 