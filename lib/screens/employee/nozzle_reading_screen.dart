import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../api/api_constants.dart';
import '../../api/fuel_type_repository.dart';
import '../../api/nozzle_reading_repository.dart';
import '../../models/fuel_type_model.dart';
import '../../models/nozzle_reading_model.dart';
import '../../theme.dart';
import '../../utils/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../screens/employee/shift_sales_screen.dart';
import 'dart:developer' as developer;

class NozzleReadingScreen extends StatefulWidget {
  final NozzleReading nozzleAssignment;
  final String? shiftDetails;
  final String initialReadingType; // Now required

  const NozzleReadingScreen({
    Key? key,
    required this.nozzleAssignment,
    this.shiftDetails,
    required this.initialReadingType, // Make this required
  }) : super(key: key);

  @override
  State<NozzleReadingScreen> createState() => _NozzleReadingScreenState();
}

class _NozzleReadingScreenState extends State<NozzleReadingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _meterReadingController = TextEditingController();
  final _readingFocusNode = FocusNode();
  final _nozzleReadingRepository = NozzleReadingRepository();
  final _fuelTypeRepository = FuelTypeRepository();
  
  late String _readingType;
  File? _imageFile;
  bool _isLoading = false;
  String _errorMessage = '';
  DateTime _recordedAt = DateTime.now();
  String? _petrolPumpId;
  bool _showDebugInfo = false;
  
  // Local mutable copy of the nozzle assignment
  late NozzleReading _nozzleData;

  // Debug section data
  final List<String> _debugLog = [];
  
  // Fuel type data
  List<FuelType> _fuelTypes = [];
  bool _loadingFuelTypes = false;
  Map<String, String> _fuelTypeIdToName = {};

  @override
  void initState() {
    super.initState();
    
    // Create a local copy of the nozzle assignment
    _nozzleData = widget.nozzleAssignment;
    
    // Simply use the initialReadingType passed from the dashboard
    _readingType = widget.initialReadingType;
    _addDebugLog('Reading type set from initialReadingType: $_readingType');
    
    // Check if a reading of this type already exists today
    _checkForExistingReading();
    
    // Fetch the latest reading from API if this is a Start reading
    if (_readingType == 'Start') {
      _fetchLatestReading();
    } else if (_readingType == 'End') {
      // For End reading, check if we have a start reading
      if (_nozzleData.startReading > 0) {
        // Pre-populate with a value higher than the start reading
        _meterReadingController.text = (_nozzleData.startReading + 0.01).toStringAsFixed(2);
        _addDebugLog('Pre-filled end reading with value: ${_meterReadingController.text}');
      } else {
        // No local start reading, fetch from API
        _fetchStartReadingForEnd();
      }
      
      // If this is an End reading, check for existing end readings as well
      _checkForExistingEndReading();
    }
    
    // Get the petrol pump ID from stored JWT token
    _getPetrolPumpIdFromToken();
    
    // Fetch fuel types for name mapping
    _fetchFuelTypes();
    
    // Add initial debug info
    _addDebugLog('Screen initialized with reading type: $_readingType');
    _addDebugLog('Nozzle ID: ${_nozzleData.nozzleId}');
    _addDebugLog('Shift ID: ${_nozzleData.shiftId ?? 'Not set'}');
    _addDebugLog('Fuel Tank ID: ${_nozzleData.fueltankId ?? 'Not set'}');
    _addDebugLog('Start Reading: ${_nozzleData.startReading}');
    _addDebugLog('End Reading: ${_nozzleData.endReading}');
  }
  
  void _addDebugLog(String message) {
    setState(() {
      _debugLog.add('[${DateTime.now().toIso8601String()}] $message');
      print('DEBUG: $message');
    });
  }
  
  // Method to extract petrol pump ID from JWT token
  Future<void> _getPetrolPumpIdFromToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString(ApiConstants.authTokenKey);
      
      if (token != null) {
        Map<String, dynamic>? decodedToken = JwtDecoder.decode(token);
        if (decodedToken != null) {
          String? pumpId = decodedToken['petrolPumpId'] ?? 
                         decodedToken['pumpId'] ?? 
                         decodedToken['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/petrolPumpId'];
          
          if (pumpId != null && pumpId.isNotEmpty) {
            setState(() {
              _petrolPumpId = pumpId;
            });
            _addDebugLog('Extracted petrol pump ID from token: $_petrolPumpId');
          } else {
            _addDebugLog('No petrol pump ID found in token. Claims: ${decodedToken.keys.join(', ')}');
          }
        }
      }
    } catch (e) {
      _addDebugLog('Error extracting petrol pump ID from token: $e');
    }
  }

  // Fetch fuel types to map IDs to names
  Future<void> _fetchFuelTypes() async {
    setState(() {
      _loadingFuelTypes = true;
    });
    
    try {
      final response = await _fuelTypeRepository.getFuelTypesByPetrolPump(_petrolPumpId ?? '');
      
      if (response.success && response.data != null) {
        setState(() {
          _fuelTypes = response.data!;
          
          // Create a mapping of fuel type IDs to their names
          _fuelTypeIdToName = {};
          for (var fuelType in _fuelTypes) {
            _fuelTypeIdToName[fuelType.fuelTypeId] = fuelType.name;
          }
        });
      }
    } catch (e) {
      _addDebugLog('Exception in _fetchFuelTypes: $e');
    } finally {
      setState(() {
        _loadingFuelTypes = false;
      });
    }
  }
  
  // Get fuel type name from ID
  String _getFuelTypeName(String? fuelTypeId) {
    if (fuelTypeId == null || fuelTypeId.isEmpty) {
      return 'Unknown';
    }
    
    return _fuelTypeIdToName[fuelTypeId] ?? 'Unknown';
  }

  @override
  void dispose() {
    _meterReadingController.dispose();
    _readingFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      _addDebugLog('Starting image picker...');
      
      final ImagePicker picker = ImagePicker();
      
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
          _addDebugLog('Image file set to path: ${image.path}');
        });
      }
    } catch (e) {
      _addDebugLog('Error capturing image: $e');
      
      // Show a helpful error message
      if (e.toString().contains('MissingPluginException')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera plugin not available. Try restarting the app or using a physical device.'),
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
        );
      }
    }
  }

  Future<void> _submitReading() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      _addDebugLog('Form validation failed');
      return;
    }
    
    // Validate image is captured
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please take a photo of the meter reading'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Validate petrol pump ID is available
    if (_petrolPumpId == null || _petrolPumpId!.isEmpty) {
      _addDebugLog('Petrol pump ID not available');
      setState(() {
        _errorMessage = 'Petrol pump ID is required but not available.';
      });
      return;
    }
    
    // Validate shift ID is available
    if (_nozzleData.shiftId == null || _nozzleData.shiftId!.isEmpty) {
      _addDebugLog('Shift ID not available');
      setState(() {
        _errorMessage = 'Shift ID is required but not available.';
      });
      return;
    }
    
    // For End readings, verify with latest API data that an end reading doesn't exist
    if (_readingType == 'End') {
      setState(() {
        _isLoading = true;
      });
      
      try {
        _addDebugLog('Verifying no existing End reading via API');
        final response = await _nozzleReadingRepository.getLatestReading(
          _nozzleData.nozzleId,
          'End'
        );
        
        if (response.success && response.data != null) {
          final latestReading = response.data!;
          _addDebugLog('Latest reading response: ${latestReading.toString()}');
          
          // Check if the reading is from today
          final today = DateTime.now();
          final todayString = DateFormat('yyyy-MM-dd').format(today);
          final readingDate = DateFormat('yyyy-MM-dd').format(latestReading.timestamp);
          
          if (latestReading.endReading != null && 
              latestReading.endReading! > 0 && 
              readingDate == todayString) {
            _addDebugLog('Found existing end reading for today with value: ${latestReading.endReading}');
            setState(() {
              _isLoading = false;
              _errorMessage = 'An end reading has already been submitted for this nozzle today.';
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('An end reading already exists for this nozzle today'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          } else {
            _addDebugLog('No end reading found for today. Date check: reading date=$readingDate, today=$todayString');
          }
        } else {
          _addDebugLog('No end reading found or API error: ${response.errorMessage}');
        }
      } catch (e) {
        _addDebugLog('Error verifying existing End reading: $e');
        // Continue with submission, as we don't want network errors to block valid submissions
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
    
    // For Start readings, verify with latest API data that no reading exists
    if (_readingType == 'Start') {
      setState(() {
        _isLoading = true;
      });
      
      try {
        _addDebugLog('Verifying no existing Start reading via API');
        final response = await _nozzleReadingRepository.getLatestReading(
          _nozzleData.nozzleId,
          'Start'
        );
        
        if (response.success && response.data != null) {
          final latestReading = response.data!;
          
          if (latestReading.startReading > 0) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'A start reading has already been submitted for this nozzle.';
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('A start reading already exists for this nozzle'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      } catch (e) {
        _addDebugLog('Error verifying existing Start reading: $e');
        // Continue with submission, as we don't want network errors to block valid submissions
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
    
    // Additional check for Start readings using local data
    if (_readingType == 'Start' && _nozzleData.startReading > 0) {
      _addDebugLog('Preventing duplicate start reading submission (local check)');
      setState(() {
        _errorMessage = 'A start reading has already been submitted for this nozzle.';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A start reading already exists for this nozzle'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    _addDebugLog('Starting submission process');
    
    try {
      // Parse meter reading to double
      final meterReading = double.tryParse(_meterReadingController.text) ?? 0.0;
      _addDebugLog('Parsed meter reading: $meterReading');
      
      // Call submitNozzleReadingMultipart
      _addDebugLog('Submitting reading to API - Type: $_readingType, Value: $meterReading');
      final response = await _nozzleReadingRepository.submitNozzleReadingMultipart(
        nozzleId: _nozzleData.nozzleId,
        shiftId: _nozzleData.shiftId!,
        readingType: _readingType,
        meterReading: meterReading,
        recordedAt: _recordedAt,
        petrolPumpId: _petrolPumpId!,
        imageFile: _imageFile!,
      );
      
      setState(() {
        _isLoading = false;
      });
      
      if (response.success) {
        _addDebugLog('Submission successful');
        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_readingType == 'Start' 
                ? 'Start reading submitted successfully' 
                : 'End reading submitted successfully'),
              backgroundColor: _readingType == 'Start' ? Colors.green : Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          
          // If this was an End reading, navigate to the shift sales screen
          if (_readingType == 'End') {
            _addDebugLog('End reading submitted, navigating to shift sales screen');
            // Create an updated nozzle reading object with end reading using the compatibility copyWith method
            final updatedNozzleReading = _nozzleData.copyWith(
              readingType: 'End',
              meterReading: meterReading,
            );
            
            // ... continue with existing code

          } else {
            // Return to previous screen with success for Start readings
            // Use true to indicate success and trigger refresh
            _addDebugLog('Start reading submitted, returning to dashboard with refresh signal');
            
            // To ensure immediate UI update, we can create an updated nozzle object here
            final updatedNozzle = _nozzleData.copyWith(
              readingType: 'Start',
              meterReading: meterReading,
            );
            
            // Pop and return both success flag and updated nozzle
            Navigator.of(context).pop({
              'success': true,
              'updatedNozzle': updatedNozzle,
            });
          }
        }
      } else {
        _addDebugLog('Submission failed: ${response.errorMessage}');
        setState(() {
          _errorMessage = response.errorMessage ?? 'Failed to submit reading';
        });
        
        // Check if the error is about an existing reading (check with our new specific error messages)
        if (_errorMessage.contains('has already been submitted for this nozzle today') || 
            _errorMessage.toLowerCase().contains('already exists') || 
            _errorMessage.toLowerCase().contains('duplicate')) {
          _addDebugLog('Error indicates duplicate reading: $_errorMessage');
          
          // Show a more user-friendly error dialog for duplicate readings
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Text('Reading Already Exists'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You have already submitted a ${_readingType.toLowerCase()} reading for this nozzle today.',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Each nozzle can only have one start reading and one end reading per day.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Go back to the dashboard
                    Navigator.of(context).pop(false);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    'RETURN TO DASHBOARD',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          _showErrorDialog(_errorMessage);
        }
      }
    } catch (e) {
      _addDebugLog('Exception during submission: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
      _showErrorDialog(_errorMessage);
    }
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Failed to Submit Reading',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error Message:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: Colors.red.shade800,
                      fontSize: 14
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    errorMessage,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 14),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Possible Solutions:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• Check if a reading already exists for today\n• Verify network connection\n• Try again in a few moments\n• Contact support if the problem persists',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            if (_showDebugInfo)
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug Info:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Nozzle ID: ${_nozzleData.nozzleId}\nReading Type: $_readingType\nTime: ${DateTime.now().toString()}',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Also go back to the dashboard to retry
              Future.delayed(Duration(milliseconds: 500), () {
                if (mounted) Navigator.of(context).pop(false);
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'BACK TO DASHBOARD',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'STAY HERE',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDateTimePicker() async {
    final currentTime = _recordedAt;
    final now = DateTime.now();
    
    try {
      final date = await showDatePicker(
        context: context,
        initialDate: currentTime,
        firstDate: DateTime(now.year, now.month - 1, now.day),
        lastDate: now,
      );
      
      if (date != null) {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(currentTime),
        );
        
        if (time != null) {
          setState(() {
            _recordedAt = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
          });
        }
      }
    } catch (e) {
      _addDebugLog('Error showing date/time picker: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEndReading = _readingType == 'End';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEndReading ? 'Submit End Reading' : 'Submit Start Reading',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isEndReading ? Colors.orange : Colors.blue,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (_showDebugInfo)
            IconButton(
              icon: Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Debug Info'),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ..._debugLog.map((log) => Text(
                            log,
                            style: TextStyle(fontSize: 12),
                          )).toList(),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SafeArea(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top banner with reading type
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isEndReading ? Colors.orange.shade50 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isEndReading ? Colors.orange.shade200 : Colors.blue.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isEndReading ? Icons.stop_circle : Icons.play_circle,
                                color: isEndReading ? Colors.orange : Colors.blue,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEndReading ? 'End Reading' : 'Start Reading',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isEndReading ? Colors.orange.shade800 : Colors.blue.shade800,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      isEndReading 
                                          ? 'Record the final meter reading'
                                          : 'Record the initial meter reading',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isEndReading ? Colors.orange.shade700 : Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Nozzle information card
                        _buildNozzleInfoCard(),
                        
                        SizedBox(height: 24),
                        
                        // Reading input section
                        _buildSectionLabel('METER READING'),
                        SizedBox(height: 8),
                        _buildMeterReadingInput(isEndReading),
                        
                        SizedBox(height: 24),
                        
                        // Image capture section
                        _buildSectionLabel('PHOTO EVIDENCE'),
                        SizedBox(height: 8),
                        _buildImageCapture(),
                        
                        SizedBox(height: 24),
                        
                        // Date time picker
                        _buildSectionLabel('DATE & TIME'),
                        SizedBox(height: 8),
                        _buildDateTimePicker(),
                        
                        SizedBox(height: 32),
                        
                        // Submit button
                        Container(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitReading,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEndReading ? Colors.orange : Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isEndReading ? 'SUBMIT END READING' : 'SUBMIT START READING',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        
                        // Error message if any
                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _errorMessage,
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                ),
                              ),
                            ),
                          ),
                        
                        SizedBox(height: 24),
                        
                        // Debug toggle
                        Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _showDebugInfo = !_showDebugInfo;
                              });
                            },
                            child: Text(
                              _showDebugInfo ? 'Hide Debug Info' : 'Show Debug Info',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
  
  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
        letterSpacing: 0.5,
      ),
    );
  }
  
  Widget _buildNozzleInfoCard() {
    // Get proper fuel type name if we have a fueltankId
    final String displayFuelType = _nozzleData.fueltankId != null && 
                                  _nozzleData.fueltankId!.isNotEmpty
        ? _getFuelTypeName(_nozzleData.fueltankId)
        : _nozzleData.fuelType ?? 'Unknown Fuel Type';
        
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _readingType == 'End' 
                        ? Colors.orange.shade100 
                        : Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_gas_station,
                    color: _readingType == 'End' 
                        ? Colors.orange.shade800 
                        : Colors.blue.shade800,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nozzle #${_nozzleData.nozzleNumber ?? "-"}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        displayFuelType,
                        style: TextStyle(
                          fontSize: 14,
                          color: _readingType == 'End' 
                              ? Colors.orange.shade800 
                              : Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.shiftDetails != null && widget.shiftDetails!.isNotEmpty) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.shiftDetails!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_readingType == 'End' && _nozzleData.startReading > 0) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'START READING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${_nozzleData.startReading.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Liters',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildMeterReadingInput(bool isEndReading) {
    final themeColor = isEndReading ? Colors.orange : Colors.blue;
    final labelColor = isEndReading ? Colors.orange.shade700 : Colors.blue.shade700;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _meterReadingController,
          focusNode: _readingFocusNode,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: themeColor, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            labelText: isEndReading ? 'End Reading' : 'Start Reading',
            labelStyle: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.w500,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: 'Enter meter reading value',
            suffixText: 'Liters',
            suffixStyle: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a meter reading';
            }
            
            final number = double.tryParse(value);
            if (number == null) {
              return 'Please enter a valid number';
            }
            
            if (number <= 0) {
              return 'Reading must be greater than 0';
            }
            
            // For end readings, validate against start reading
            if (_readingType == 'End' && 
                _nozzleData.startReading > 0 &&
                number <= _nozzleData.startReading) {
              return 'End reading must be greater than start reading (${_nozzleData.startReading})';
            }
            
            return null;
          },
        ),
      ],
    );
  }
  
  Widget _buildImageCapture() {
    final isEndReading = _readingType == 'End';
    final themeColor = isEndReading ? Colors.orange : Colors.blue;
    
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _imageFile == null 
              ? Colors.grey.shade300 
              : themeColor.shade300,
        ),
      ),
      child: Column(
        children: [
          if (_imageFile == null)
            InkWell(
              onTap: _pickImage,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: themeColor.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 32,
                        color: themeColor.shade700,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Take a photo of the meter reading',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Ensure the numbers are clearly visible',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.file(
                    _imageFile!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha:0.6),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.refresh, color: Colors.white, size: 20),
                      onPressed: _pickImage,
                      tooltip: 'Retake photo',
                      padding: EdgeInsets.all(8),
                      constraints: BoxConstraints(),
                    ),
                  ),
                ),
              ],
            ),
          TextButton.icon(
            onPressed: _pickImage,
            icon: Icon(
              _imageFile == null ? Icons.camera_alt : Icons.refresh, 
              size: 18,
              color: themeColor.shade600,
            ),
            label: Text(
              _imageFile == null ? 'CAPTURE IMAGE' : 'RETAKE PHOTO',
              style: TextStyle(
                color: themeColor.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              backgroundColor: themeColor.shade50,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDateTimePicker() {
    final isEndReading = _readingType == 'End';
    final themeColor = isEndReading ? Colors.orange : Colors.blue;
    
    return InkWell(
      onTap: _showDateTimePicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recording Date & Time',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: themeColor.shade700,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: themeColor.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.event,
                    color: themeColor.shade700,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(_recordedAt),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      DateFormat('h:mm a').format(_recordedAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Fetch the latest reading to check if a start reading already exists
  Future<void> _fetchLatestReading() async {
    try {
      _addDebugLog('Fetching latest Start reading for nozzle: ${_nozzleData.nozzleId}');
      
      final response = await _nozzleReadingRepository.getLatestReading(
        _nozzleData.nozzleId,
        'Start'
      );
      
      if (response.success && response.data != null) {
        final latestReading = response.data!;
        _addDebugLog('Found latest Start reading with value: ${latestReading.startReading}');
        
        // If a start reading already exists with a non-zero value, show warning and go back
        if (latestReading.startReading > 0) {
          _addDebugLog('WARNING: Start reading already exists with value: ${latestReading.startReading}');
          
          // Delay the warning to ensure UI is built
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Show warning and pop back to dashboard
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('This nozzle already has a start reading recorded'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
              
              // Return to previous screen after delay
              Future.delayed(Duration(seconds: 1), () {
                if (mounted) Navigator.of(context).pop(false);
              });
            }
          });
        }
      } else {
        _addDebugLog('No latest Start reading found or error: ${response.errorMessage}');
        
        // Check if our local data has a start reading value
        if (_nozzleData.startReading > 0) {
          _addDebugLog('Local data shows start reading exists with value: ${_nozzleData.startReading}');
          
          // Delay the warning to ensure UI is built
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Show warning and pop back to dashboard
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('This nozzle already has a start reading recorded'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
              
              // Return to previous screen after delay
              Future.delayed(Duration(seconds: 1), () {
                if (mounted) Navigator.of(context).pop(false);
              });
            }
          });
        }
      }
    } catch (e) {
      _addDebugLog('Error fetching latest Start reading: $e');
    }
  }

  // Fetch start reading when showing end reading screen
  Future<void> _fetchStartReadingForEnd() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      _addDebugLog('Fetching start reading from API for nozzle: ${_nozzleData.nozzleId}');
      
      final response = await _nozzleReadingRepository.getLatestReading(
        _nozzleData.nozzleId,
        'Start'
      );
      
      setState(() {
        _isLoading = false;
      });
      
      if (response.success && response.data != null) {
        final latestReading = response.data!;
        _addDebugLog('Found start reading with value: ${latestReading.startReading}');
        
        // If a start reading exists, update our local model and pre-populate end reading field
        if (latestReading.startReading > 0) {
          setState(() {
            // Update the local nozzle data to include the start reading
            _nozzleData = _nozzleData.copyWith(
              startReading: latestReading.startReading
            );
            
            // Pre-populate with a value slightly higher than the start reading
            _meterReadingController.text = (latestReading.startReading + 0.01).toStringAsFixed(2);
            _addDebugLog('Pre-filled end reading based on API start reading: ${_meterReadingController.text}');
          });
        } else {
          _addDebugLog('No valid start reading value found in API response');
          _showStartReadingRequiredError();
        }
      } else {
        _addDebugLog('No start reading found via API: ${response.errorMessage}');
        _showStartReadingRequiredError();
      }
    } catch (e) {
      _addDebugLog('Error fetching start reading: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching start reading: $e';
      });
      _showStartReadingRequiredError();
    }
  }
  
  // Show error when no start reading is found
  void _showStartReadingRequiredError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No start reading found for this nozzle. Please submit a start reading first.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Return to previous screen after delay
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop(false);
        });
      }
    });
  }

  // Helper method to check if an end reading already exists for today
  Future<void> _checkForExistingEndReading() async {
    try {
      _addDebugLog('DEBUG: Checking if end reading already exists for today...');
      final response = await _nozzleReadingRepository.getLatestReading(
        _nozzleData.nozzleId,
        'End'
      );
      
      if (response.success && response.data != null) {
        final latestReading = response.data!;
        
        // Check if the reading is from today
        final today = DateTime.now();
        final todayString = DateFormat('yyyy-MM-dd').format(today);
        final readingDate = DateFormat('yyyy-MM-dd').format(latestReading.timestamp);
        
        _addDebugLog('Latest end reading details:');
        _addDebugLog('- Reading date: $readingDate');
        _addDebugLog('- Today\'s date: $todayString');
        _addDebugLog('- Reading value: ${latestReading.endReading ?? "null"}');
        _addDebugLog('- Is today\'s reading: ${readingDate == todayString}');
        
        if (latestReading.endReading != null && 
            latestReading.endReading! > 0 && 
            readingDate == todayString) {
          _addDebugLog('IMPORTANT: Found existing end reading for today with value: ${latestReading.endReading}');
        } else {
          _addDebugLog('No end reading found for today in pre-check.');
        }
      } else {
        _addDebugLog('No end reading found or API error in pre-check: ${response.errorMessage}');
      }
    } catch (e) {
      _addDebugLog('Error checking for existing end reading: $e');
    }
  }

  // Check if a reading of this type already exists for today
  Future<void> _checkForExistingReading() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      _addDebugLog('Checking if a $_readingType reading already exists for today');
      final response = await _nozzleReadingRepository.checkReadingExistsForToday(
        _nozzleData.nozzleId, 
        _readingType
      );
      
      if (response.success && response.data == true) {
        _addDebugLog('A $_readingType reading already exists for today');
        
        // Show dialog and go back to dashboard
        if (mounted) {
          // Wait for build to complete before showing dialog
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 28),
                    SizedBox(width: 8),
                    Text('Reading Already Exists'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You have already submitted a ${_readingType.toLowerCase()} reading for this nozzle today.',
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Each nozzle can only have one start reading and one end reading per day.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Go back to the dashboard
                      Navigator.of(context).pop(false);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      'RETURN TO DASHBOARD',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          });
        }
      } else {
        _addDebugLog('No $_readingType reading exists for today, can proceed');
      }
    } catch (e) {
      _addDebugLog('Error checking for existing reading: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}