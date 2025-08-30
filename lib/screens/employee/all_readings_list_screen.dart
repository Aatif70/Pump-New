import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../utils/api_helper.dart';
import '../../models/nozzle_reading_model.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_message.dart';
import '../../theme.dart';
import '../../api/api_constants.dart';

class AllReadingsListScreen extends StatefulWidget {
  const AllReadingsListScreen({super.key});

  @override
  State<AllReadingsListScreen> createState() => _AllReadingsListScreenState();
}

class _AllReadingsListScreenState extends State<AllReadingsListScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<NozzleReading> _readings = [];
  List<NozzleReading> _filteredReadings = [];
  final ApiHelper _apiHelper = ApiHelper();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Filter options
  bool _showSearchFilters = false;
  bool _filterNozzle = true;
  bool _filterFuelType = true;
  bool _filterEmployee = true;
  bool _filterDate = true;

  @override
  void initState() {
    super.initState();
    _fetchAllReadings();
    _searchController.addListener(_filterReadings);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllReadings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = '${ApiConstants.baseUrl}/api/NozzleReadings';
      final response = await _apiHelper.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final readings = data
            .map((reading) => NozzleReading.fromJson(reading))
            .toList();
        
        // Sort readings by date (most recent first)
        readings.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
        
        setState(() {
          _readings = readings;
          _filteredReadings = readings;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load readings: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }
  
  void _filterReadings() {
    final query = _searchController.text.toLowerCase();
    
    if (query.isEmpty) {
      setState(() {
        _filteredReadings = _readings;
      });
      return;
    }
    
    setState(() {
      _filteredReadings = _readings.where((reading) {
        bool matches = false;
        
        // Filter by nozzle number
        if (_filterNozzle && reading.nozzleNumber.toLowerCase().contains(query)) {
          matches = true;
        }
        
        // Filter by fuel type
        if (_filterFuelType && reading.fuelType.toLowerCase().contains(query)) {
          matches = true;
        }
        
        // Filter by employee name
        if (_filterEmployee && reading.employeeName.toLowerCase().contains(query)) {
          matches = true;
        }
        
        // Filter by date (formatted date)
        if (_filterDate) {
          final formattedDate = _dateFormat.format(reading.recordedAt).toLowerCase();
          if (formattedDate.contains(query)) {
            matches = true;
          }
          
          // Also check just the date part (YYYY-MM-DD)
          final dateOnly = DateFormat('yyyy-MM-dd').format(reading.recordedAt).toLowerCase();
          if (dateOnly.contains(query)) {
            matches = true;
          }
        }
        
        return matches;
      }).toList();
    });
  }
  
  void _toggleFilterOption(String filterType) {
    setState(() {
      switch (filterType) {
        case 'nozzle':
          _filterNozzle = !_filterNozzle;
          break;
        case 'fuelType':
          _filterFuelType = !_filterFuelType;
          break;
        case 'employee':
          _filterEmployee = !_filterEmployee;
          break;
        case 'date':
          _filterDate = !_filterDate;
          break;
      }
      _filterReadings();
    });
  }

  Future<void> _updateMeterReading(String readingId, double newReading) async {
    try {
      final url = '${ApiConstants.baseUrl}/api/NozzleReadings';
      final response = await _apiHelper.put(
        url,
        body: {
          'nozzleReadingId': readingId,
          'meterReading': newReading,
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                const Text('Reading updated successfully'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        // Refresh the readings list
        _fetchAllReadings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Text('Failed to update: ${response.statusCode}'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 10),
              Text('Error updating reading: $e'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _showEditDialog(NozzleReading reading) async {
    final TextEditingController controller = TextEditingController(
      text: reading.meterReading.toString(),
    );

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          elevation: 10,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_note,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Edit Meter Reading'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nozzle ${reading.nozzleNumber}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getColorForFuelType(reading.fuelType).withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      reading.fuelType,
                      style: TextStyle(
                        color: _getColorForFuelType(reading.fuelType),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Meter Reading',
                  labelStyle: TextStyle(color: Colors.grey.shade700),
                  hintText: 'Enter new reading value',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.primaryBlue),
                  ),
                  prefixIcon: Icon(Icons.speed, color: Colors.amber.shade700),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                try {
                  final newReading = double.parse(controller.text);
                  _updateMeterReading(reading.nozzleReadingId, newReading);
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: const [
                          Icon(Icons.error_outline, color: Colors.white),
                          SizedBox(width: 10),
                          Text('Please enter a valid number'),
                        ],
                      ),
                      backgroundColor: Colors.red.shade600,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Dismiss keyboard when tapping outside
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: null,
        body: SafeArea(
          child: _isLoading
              ? _buildCustomLoadingIndicator()
              : Column(
                  children: [
                    // Custom header with back button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back button
                          InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha:0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: const Icon(Icons.arrow_back, size: 22),
                            ),
                          ),
                          // Title
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'All Meter Readings',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'View and manage all nozzle readings',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Refresh button
                          InkWell(
                            onTap: _fetchAllReadings,
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha:0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: const Icon(Icons.refresh, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                    // Rest of the UI
                    Expanded(
                      child: _errorMessage != null
                          ? ErrorMessage(message: _errorMessage!)
                          : Column(
                              children: [
                                _buildSearchBar(),
                                Expanded(
                                  child: _buildReadingsList(),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
  
  Widget _buildCustomLoadingIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha:0.1),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                height: 36,
                width: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading readings...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search readings...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryBlue),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                        },
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.filter_list,
                        color: _showSearchFilters ? AppTheme.primaryBlue : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _showSearchFilters = !_showSearchFilters;
                        });
                      },
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          if (_showSearchFilters) 
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(top: 16),
              child: _buildFilterOptions(),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
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
                      child: const Icon(
                        Icons.list_alt,
                        color: AppTheme.primaryBlue,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Total: ${_filteredReadings.length} readings',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (_filteredReadings.length < _readings.length)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'Filtered from ${_readings.length}',
                      style: const TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
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
  
  Widget _buildFilterOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.filter_list,
              size: 16,
              color: Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              'Search in:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip(
              label: 'Nozzle',
              selected: _filterNozzle,
              onTap: () => _toggleFilterOption('nozzle'),
              icon: Icons.local_gas_station,
            ),
            _buildFilterChip(
              label: 'Fuel Type',
              selected: _filterFuelType,
              onTap: () => _toggleFilterOption('fuelType'),
              icon: Icons.local_fire_department,
            ),
            _buildFilterChip(
              label: 'Employee',
              selected: _filterEmployee,
              onTap: () => _toggleFilterOption('employee'),
              icon: Icons.person,
            ),
            _buildFilterChip(
              label: 'Date',
              selected: _filterDate,
              onTap: () => _toggleFilterOption('date'),
              icon: Icons.calendar_today,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected 
              ? AppTheme.primaryBlue.withValues(alpha:0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppTheme.primaryBlue : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha:0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppTheme.primaryBlue : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.primaryBlue : Colors.grey.shade700,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingsList() {
    if (_filteredReadings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No readings match your search',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      controller: _scrollController,
      itemCount: _filteredReadings.length,
      padding: const EdgeInsets.all(12.0),
      itemBuilder: (context, index) {
        final reading = _filteredReadings[index];
        final bool isStartReading = reading.readingType.toLowerCase() == 'start';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.05),
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onLongPress: () => _showEditDialog(reading),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with colored banner based on fuel type
                    Container(
                      decoration: BoxDecoration(
                        color: _getColorForFuelType(reading.fuelType).withValues(alpha:0.15),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha:0.05),
                                  blurRadius: 4,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.local_gas_station,
                              color: _getColorForFuelType(reading.fuelType),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nozzle ${reading.nozzleNumber} - ${reading.fuelType}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: _getColorForFuelType(reading.fuelType),
                                  ),
                                ),
                                Text(
                                  'Dispenser #${reading.dispenserNumber}',
                                  style: TextStyle(
                                    color: _getColorForFuelType(reading.fuelType).withValues(alpha:0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isStartReading
                                  ? Colors.blue.withValues(alpha:0.1) 
                                  : Colors.green.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isStartReading ? Icons.play_arrow : Icons.stop,
                                  size: 14,
                                  color: isStartReading ? Colors.blue : Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  reading.readingType,
                                  style: TextStyle(
                                    color: isStartReading ? Colors.blue : Colors.green,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Main content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        children: [
                          // Employee and Date row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withValues(alpha:0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      size: 14,
                                      color: Colors.purple,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    reading.employeeName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha:0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _dateFormat.format(reading.recordedAt),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Meter reading section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha:0.05),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.speed,
                                    color: Colors.amber.shade700,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Meter Reading',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        reading.meterReading.toStringAsFixed(2),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 22,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: AppTheme.primaryBlue,
                                  ),
                                  onPressed: () => _showEditDialog(reading),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue.withValues(alpha:0.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Helper method to get color for fuel type
  Color _getColorForFuelType(String fuelType) {
    switch(fuelType.toLowerCase()) {
      case 'petrol':
        return Colors.green.shade700;
      case 'diesel':
        return Colors.blue.shade700;
      case 'premium petrol':
        return Colors.purple.shade700;
      case 'cng':
        return Colors.teal.shade700;
      case 'lpg':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}