import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import '../../api/shift_sales_repository.dart';
import '../../models/fuel_price_model.dart';
import '../../models/shift_sales_model.dart';
import '../../api/nozzle_assignment_repository.dart';
import '../../api/nozzle_repository.dart';
import '../../api/employee_repository.dart';
import '../../api/meter_reading_repository.dart';
import '../../api/fuel_price_repository.dart';
import '../../api/government_testing_repository.dart';
import '../../models/nozzle_model.dart';
import '../../models/meter_reading_model.dart';
import '../../models/employee_nozzle_assignment_model.dart';
import '../../models/government_testing_model.dart';
import '../../theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api/nozzle_reading_repository.dart';
import '../../models/nozzle_reading_model.dart';

class SubmitSalesScreen extends StatefulWidget {
  final String? nozzleId;
  final String? shiftId;
  final String? fuelDispenserId;

  const SubmitSalesScreen({
    Key? key,
    this.nozzleId,
    this.shiftId,
    this.fuelDispenserId,
  }) : super(key: key);

  @override
  _SubmitSalesScreenState createState() => _SubmitSalesScreenState();
}

class _SubmitSalesScreenState extends State<SubmitSalesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cashAmountController = TextEditingController();
  final _creditCardAmountController = TextEditingController();
  final _litersSoldController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _upiAmountController = TextEditingController();
  
  // Testing-related controllers and state variables
  final _testingLitersController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isTestingEnabled = false;
  
  bool _loading = false;
  String? _error;

  // IDs to be fetched
  String? _employeeId;
  String? _shiftId;
  String? _fuelDispenserId;
  String? _nozzleId;

  bool _fetching = true;
  
  // Add properties for variance calculation
  double _startReading = 0;
  double _endReading = 0;
  double _fuelPrice = 0;
  double _expectedAmount = 0;
  double _variance = 0;
  bool _hasVariance = false;
  bool _isVarianceHigh = false;
  
  // Threshold for flagging high variance (in percentage)
  final double _varianceThreshold = 5.0; // 2%
  
  // Nozzle selection dropdown data
  List<EmployeeNozzleAssignment> _nozzleAssignments = [];
  EmployeeNozzleAssignment? _selectedNozzleAssignment;
  bool _loadingNozzleAssignments = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    
    // Set up listeners for automatic calculation
    _cashAmountController.addListener(_calculateTotal);
    _creditCardAmountController.addListener(_calculateTotal);
    _upiAmountController.addListener(_calculateTotal);
    _totalAmountController.addListener(_calculateVariance);
    
    // Add listener for real-time calculation when fuel volume changes
    _litersSoldController.addListener(_calculateExpectedAmount);
  }
  
  @override
  void dispose() {
    // Clean up listeners
    _cashAmountController.removeListener(_calculateTotal);
    _creditCardAmountController.removeListener(_calculateTotal);
    _upiAmountController.removeListener(_calculateTotal);
    _totalAmountController.removeListener(_calculateVariance);
    _litersSoldController.removeListener(_calculateExpectedAmount);
    
    _cashAmountController.dispose();
    _creditCardAmountController.dispose();
    _litersSoldController.dispose();
    _totalAmountController.dispose();
    _upiAmountController.dispose();
    _testingLitersController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() { _fetching = true; });
    
    // First try to use the passed data
    _nozzleId = widget.nozzleId;
    _shiftId = widget.shiftId;
    _fuelDispenserId = widget.fuelDispenserId;
    
    // Get current employee ID
    await _getCurrentEmployeeId();
    
    // Fetch nozzle assignments for dropdown
    await _fetchNozzleAssignments();
    
    // If any data is missing, try to get from SharedPreferences
    if (_nozzleId == null || _shiftId == null) {
      await _loadFromPreferences();
    }
    
    // If still missing data, fetch from API
    if (_nozzleId == null || _shiftId == null || _fuelDispenserId == null) {
      await _fetchAssignmentAndNozzle();
    } else {
      // Get employee ID if not already set
      if (_employeeId == null) {
        final empResp = await EmployeeRepository().getCurrentEmployee();
        _employeeId = empResp.data?.id;
      }
      
      // If nozzle ID was passed directly but price is 0, fetch the price explicitly
      if (widget.nozzleId != null && _fuelPrice <= 0) {
        print('DEBUG: Direct nozzle passed, fetching fuel price explicitly');
        await _fetchCurrentFuelPrice();
      }
    }
    
    // Fetch meter readings and fuel price
    if (_nozzleId != null && _shiftId != null) {
      await _fetchMeterReadingsAndPrice();
    }
    
    setState(() { _fetching = false; });
  }
  
  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _nozzleId = _nozzleId ?? prefs.getString('employee_nozzle_id');
      _shiftId = _shiftId ?? prefs.getString('employee_shift_id');
    } catch (e) {
      print('Error loading from preferences: $e');
    }
  }
  
  Future<void> _saveToPreferences() async {
    try {
      if (_nozzleId != null && _shiftId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('employee_nozzle_id', _nozzleId!);
        await prefs.setString('employee_shift_id', _shiftId!);
      }
    } catch (e) {
      print('Error saving to preferences: $e');
    }
  }

  Future<void> _fetchAssignmentAndNozzle() async {
    setState(() { _fetching = true; });
    try {
      // Get current employee
      final empResp = await EmployeeRepository().getCurrentEmployee();
      _employeeId = empResp.data?.id;
      if (_employeeId == null) throw Exception('Employee not found');
      
      // Get nozzle assignment
      final assignResp = await NozzleAssignmentRepository().getEmployeeNozzleAssignments(_employeeId!);
      if (assignResp.data == null || assignResp.data!.isEmpty) throw Exception('No nozzle assignment found');
      final assignment = assignResp.data!.first;
      _nozzleId = assignment.nozzleId;
      _shiftId = assignment.shiftId;
      
      // Get nozzle details - We need this to get the fuelDispenserId
      if (_nozzleId == null || _nozzleId!.isEmpty) {
        throw Exception('Invalid nozzle ID from assignment');
      }
      
      print('Fetching details for nozzle ID: $_nozzleId');
      final nozzleResp = await NozzleRepository().getNozzleById(_nozzleId!);
      
      if (nozzleResp.data != null) {
        print('Got nozzle data: ${nozzleResp.data!.toString()}');
        _fuelDispenserId = nozzleResp.data!.fuelDispenserUnitId;
        print('Set fuel dispenser ID: $_fuelDispenserId');
      } else {
        print('Failed to get nozzle data, trying alternate method');
        // Fallback to getting all nozzles and finding the matching one
        final allNozzlesResp = await NozzleRepository().getAllNozzles();
        if (allNozzlesResp.data != null && allNozzlesResp.data!.isNotEmpty) {
          final matchingNozzle = allNozzlesResp.data!.firstWhere(
            (n) => n.id == _nozzleId,
            orElse: () => Nozzle(
              id: '',
              fuelDispenserUnitId: '',
              nozzleNumber: 0,
              status: 'inactive',
            ),
          );
          
          if (matchingNozzle.id!.isNotEmpty) {
            _fuelDispenserId = matchingNozzle.fuelDispenserUnitId;
            print('Found matching nozzle, fuel dispenser ID: $_fuelDispenserId');
          } else {
            throw Exception('Could not find matching nozzle');
          }
        } else {
          throw Exception('No nozzles found');
        }
      }
      
      if (_fuelDispenserId == null || _fuelDispenserId!.isEmpty) {
        throw Exception('Failed to get fuel dispenser ID for nozzle');
      }
      
      // Save to preferences for future use
      await _saveToPreferences();
    } catch (e) {
      print('Error in _fetchAssignmentAndNozzle: $e');
      // Set default values to prevent further errors
      _fuelDispenserId = '00000000-0000-0000-0000-000000000000';
      setState(() { _error = e.toString(); });
    }
    setState(() { _fetching = false; });
  }

  Future<void> _fetchMeterReadingsAndPrice() async {
    try {
      print("DEBUG: Starting _fetchMeterReadingsAndPrice");
      
      // First, check if we have the employee ID
      if (_employeeId == null) {
        print("DEBUG: No employee ID available, can't fetch readings");
        return;
      }
      
      print("DEBUG: Fetching nozzle readings for employee ID: $_employeeId");
      
      // Fetch readings from the new API endpoint
      final nozzleReadingRepo = NozzleReadingRepository();
      final readingsResp = await nozzleReadingRepo.getNozzleReadingsForEmployee(_employeeId!);
      
      if (readingsResp.success && readingsResp.data != null && readingsResp.data!.isNotEmpty) {
        print("DEBUG: Received ${readingsResp.data!.length} nozzle readings");
        
        final readings = readingsResp.data!;
        
        // Filter readings to only include today's readings
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);
        final todayEnd = todayStart.add(Duration(days: 1));
        
        print("DEBUG: Filtering for today's readings between $todayStart and $todayEnd");
        print("DEBUG: Current nozzle ID: $_nozzleId");
        
        // Print all readings for debugging
        print("DEBUG: All readings received:");
        for (int i = 0; i < readings.length; i++) {
          final reading = readings[i];
          print("DEBUG: Reading #$i: " +
                "ID: ${reading.nozzleReadingId}, " +
                "NozzleID: ${reading.nozzleId}, " +
                "Type: ${reading.readingType}, " +
                "Value: ${reading.meterReading}, " +
                "Date: ${reading.recordedAt}, " +
                "FuelType: ${reading.fuelType}");
        }
        
        final todayReadings = readings.where((reading) {
          final recordedDate = reading.recordedAt;
          final isToday = recordedDate.isAfter(todayStart) && recordedDate.isBefore(todayEnd);
          
          print("DEBUG: Reading date: ${reading.recordedAt}, isToday: $isToday");
          
          // Also check if this reading is for the selected nozzle
          final isMatchingNozzle = reading.nozzleId == _nozzleId;
          
          print("DEBUG: Reading nozzleId: ${reading.nozzleId}, expected: $_nozzleId, isMatchingNozzle: $isMatchingNozzle");
          
          return isToday && isMatchingNozzle;
        }).toList();
        
        print("DEBUG: Found ${todayReadings.length} readings for today and the selected nozzle");
        
        // Print today's filtered readings for debugging
        if (todayReadings.isNotEmpty) {
          print("DEBUG: Today's filtered readings:");
          for (int i = 0; i < todayReadings.length; i++) {
            final reading = todayReadings[i];
            print("DEBUG: Today's Reading #$i: " +
                  "Type: ${reading.readingType}, " +
                  "Value: ${reading.meterReading}, " +
                  "Time: ${reading.recordedAt.hour}:${reading.recordedAt.minute}");
          }
        }
        
        if (todayReadings.isNotEmpty) {
          // Find start reading - handle potential case differences and variations
          print("DEBUG: Looking for START reading among ${todayReadings.length} readings");
          
          // Print all reading types for debugging
          for (int i = 0; i < todayReadings.length; i++) {
            print("DEBUG: Reading #$i type: '${todayReadings[i].readingType}' (lowercase: '${todayReadings[i].readingType.toLowerCase()}')");
          }
          
          // Try to find start reading with flexible matching
          final startReadingCandidates = todayReadings.where(
            (reading) => reading.readingType.toLowerCase().contains('start') ||
                        reading.readingType.toLowerCase() == 'start' ||
                        reading.readingType.toLowerCase() == 'begin'
          ).toList();
          
          print("DEBUG: Found ${startReadingCandidates.length} potential start readings");
          
          final startReading = startReadingCandidates.isNotEmpty
            ? startReadingCandidates.first
            : NozzleReading(
                nozzleReadingId: '',
                nozzleId: '',
                employeeId: '',
                shiftId: '',
                readingType: 'start',
                meterReading: 0,
                recordedAt: DateTime.now(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                employeeName: '',
                nozzleNumber: '',
                fuelType: '',
                fuelTypeId: '',
                dispenserNumber: '',
              );
          
          // Find end reading with flexible matching
          print("DEBUG: Looking for END reading");
          final endReadingCandidates = todayReadings.where(
            (reading) => reading.readingType.toLowerCase().contains('end') ||
                        reading.readingType.toLowerCase() == 'end' ||
                        reading.readingType.toLowerCase() == 'final' ||
                        reading.readingType.toLowerCase() == 'finish'
          ).toList();
          
          print("DEBUG: Found ${endReadingCandidates.length} potential end readings");
          
          final endReading = endReadingCandidates.isNotEmpty
            ? endReadingCandidates.first
            : NozzleReading(
                nozzleReadingId: '',
                nozzleId: '',
                employeeId: '',
                shiftId: '',
                readingType: 'end',
                meterReading: 0,
                recordedAt: DateTime.now(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                employeeName: '',
                nozzleNumber: '',
                fuelType: '',
                fuelTypeId: '',
                dispenserNumber: '',
              );
          
          print("DEBUG: Selected Start reading: ID=${startReading.nozzleReadingId}, Type=${startReading.readingType}, Value=${startReading.meterReading}");
          print("DEBUG: Selected End reading: ID=${endReading.nozzleReadingId}, Type=${endReading.readingType}, Value=${endReading.meterReading}");
          
          setState(() {
            _startReading = startReading.meterReading;
            _endReading = endReading.meterReading;
            
            // Calculate liters sold and update the controller
            double litersSold = _endReading - _startReading;
            print("DEBUG: Calculated liters sold: $litersSold from $_endReading - $_startReading");
            
            if (litersSold > 0) {
              // Update the controller - this will automatically trigger the listener
              // which will calculate the expected amount in real-time
              _litersSoldController.text = litersSold.toStringAsFixed(2);
              print("DEBUG: Updated liters sold text field to: ${_litersSoldController.text}");
            } else {
              print("DEBUG: Liters sold is not positive, not updating field: $litersSold");
            }
          });
          
          // Show a snackbar indicating meter readings loaded successfully
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Meter readings loaded: Start ${_startReading.toStringAsFixed(2)} - End ${_endReading.toStringAsFixed(2)}'),
                backgroundColor: Colors.blue.shade700,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          print("DEBUG: No readings found for today and the selected nozzle");
          
          // No readings found for today
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No meter readings found for today. Please enter values manually.'),
                backgroundColor: Colors.orange.shade700,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        print("DEBUG: No readings found or API error: ${readingsResp.errorMessage}");
        
        // No readings found
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No meter readings found for this nozzle and shift. Please enter values manually.'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      
      // Fetch fuel price if not already fetched
      if (_fuelPrice <= 0) {
        await _fetchCurrentFuelPrice();
      } else {
        // Calculate expected amount since we already have the fuel price
        _calculateExpectedAmount();
        
        // Update the total amount field to match the expected amount initially
        if (_totalAmountController.text.isEmpty || double.tryParse(_totalAmountController.text) == 0) {
          _totalAmountController.text = _expectedAmount.toStringAsFixed(2);
          _calculateVariance();
        }
      }
    } catch (e) {
      print('Error fetching readings or price: $e');
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load meter readings: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Calculate expected amount based on entered liters
  void _calculateExpectedAmount() {
    try {
      double liters = double.tryParse(_litersSoldController.text) ?? 0;
      if (_fuelPrice > 0 && liters > 0) {
        setState(() {
          _expectedAmount = liters * _fuelPrice;
          print('DEBUG: Real-time calculation - Liters: $liters × Price: ₹${_fuelPrice.toStringAsFixed(2)} = Expected: ₹${_expectedAmount.toStringAsFixed(2)}');
          
          // If total amount field is empty or zero, auto-populate with expected amount
          if (_totalAmountController.text.isEmpty || (double.tryParse(_totalAmountController.text) ?? 0) == 0) {
            _totalAmountController.text = _expectedAmount.toStringAsFixed(2);
          }
        });
        
        // Calculate variance after updating expected amount
        _calculateVariance();
      }
    } catch (e) {
      print('Error calculating expected amount: $e');
    }
  }

  void _calculateVariance() {
    try {
      double enteredTotal = double.tryParse(_totalAmountController.text) ?? 0;
      if (_expectedAmount > 0) {
        _variance = enteredTotal - _expectedAmount;
        double variancePercentage = _expectedAmount > 0 ? (_variance / _expectedAmount) * 100 : 0;
        
        print('DEBUG: Expected: $_expectedAmount, Entered: $enteredTotal, Variance: $_variance, Percentage: ${variancePercentage.toStringAsFixed(2)}%');
        
        setState(() {
          // Consider very small differences (less than ₹1) as not having variance
          _hasVariance = _variance.abs() >= 1;
          _isVarianceHigh = variancePercentage.abs() > _varianceThreshold;
        });
      } else {
        setState(() {
          _hasVariance = false;
          _isVarianceHigh = false;
        });
      }
    } catch (e) {
      print('Error calculating variance: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Additional validation for required IDs
    if (_employeeId == null || _employeeId!.isEmpty ||
        _shiftId == null || _shiftId!.isEmpty ||
        _nozzleId == null || _nozzleId!.isEmpty) {
      
      setState(() {
        _error = 'Missing required data. Please try refreshing the page.';
      });
      
      return;
    }
    
    setState(() { _loading = true; _error = null; });
    final repo = ShiftSalesRepository();
    
    try {
      print("SUBMIT_DEBUG: Starting submission process");
      
      // Get petrol pump ID and fuel type ID from selected nozzle assignment
      String? petrolPumpId;
      String? fuelTypeId;
      String? fuelTankId;
      
      if (_selectedNozzleAssignment != null) {
        print("SUBMIT_DEBUG: Using selected nozzle assignment");
        fuelTypeId = _selectedNozzleAssignment!.fuelTypeId;
        petrolPumpId = _selectedNozzleAssignment!.petrolPumpId;
        fuelTankId = _selectedNozzleAssignment!.fuelTankId;
        print("SUBMIT_DEBUG: Fuel Type ID from nozzle assignment: $fuelTypeId");
        print("SUBMIT_DEBUG: Petrol Pump ID from nozzle assignment: $petrolPumpId");
        print("SUBMIT_DEBUG: Fuel Tank ID from nozzle assignment: $fuelTankId");
      }
      
      // Try to get petrol pump ID from repository if still null
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        try {
          print("SUBMIT_DEBUG: Attempting to get Petrol Pump ID from repository");
          petrolPumpId = await repo.getPetrolPumpId();
          print("SUBMIT_DEBUG: Petrol Pump ID from repository: $petrolPumpId");
        } catch (e) {
          print("SUBMIT_DEBUG: Error getting Petrol Pump ID from repository: $e");
        }
      }
      
      // Fallback to preferences if still null
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        print("SUBMIT_DEBUG: Petrol Pump ID not found in repository, checking SharedPreferences");
        final prefs = await SharedPreferences.getInstance();
        petrolPumpId = prefs.getString('petrol_pump_id') ?? prefs.getString('petrolPumpId');
        print("SUBMIT_DEBUG: Petrol Pump ID from SharedPreferences: $petrolPumpId");
      }
      
      // Hardcoded fallback if still null
      if (petrolPumpId == null || petrolPumpId.isEmpty) {
        print("SUBMIT_DEBUG: Using hardcoded Petrol Pump ID");
        petrolPumpId = "c185d2dc-adfe-202b-5246-d1103ce7af4f";
      }
      
      print("SUBMIT_DEBUG: Final Petrol Pump ID: $petrolPumpId");
      print("SUBMIT_DEBUG: Final Fuel Type ID: $fuelTypeId");
      
      // Get all the payment values as doubles
      final double cashAmount = double.tryParse(_cashAmountController.text) ?? 0;
      final double creditCardAmount = double.tryParse(_creditCardAmountController.text) ?? 0;
      final double upiAmount = double.tryParse(_upiAmountController.text) ?? 0;
      final double litersSold = double.tryParse(_litersSoldController.text) ?? 0;
      
      // Calculate the total from payment methods
      final double calculatedTotal = cashAmount + creditCardAmount + upiAmount;
      final double submittedTotal = double.tryParse(_totalAmountController.text) ?? 0;
      
      // Check if there's a mismatch between payment methods total and the total amount entered
      if ((calculatedTotal - submittedTotal).abs() > 0.01) {
        print("SUBMIT_DEBUG: WARNING - Total amount (${submittedTotal.toStringAsFixed(2)}) does not match" +
              " sum of payment methods (${calculatedTotal.toStringAsFixed(2)})");
        
        // In case of mismatch, use the sum of payment methods as the total
        print("SUBMIT_DEBUG: Adjusting total amount to match payment methods total");
        _totalAmountController.text = calculatedTotal.toStringAsFixed(2);
      }
      
      // Ensure fuel price is set
      if (_fuelPrice <= 0) {
        print("SUBMIT_DEBUG: Warning - Fuel price is not set, using default value");
        _fuelPrice = 1.0; // Fallback to prevent division by zero
      }
      
      // Submit with corrected values
      final sales = ShiftSales(
        cashAmount: cashAmount,
        creditCardAmount: creditCardAmount,
        litersSold: litersSold,
        totalAmount: calculatedTotal, // Use the calculated total for consistency
        upiAmount: upiAmount,
        employeeId: _employeeId!,
        shiftId: _shiftId!,
        fuelDispenserId: (_fuelDispenserId == null || _fuelDispenserId!.isEmpty) ? "da01cb29-8ecd-3958-afee-a046ece64cbf" : _fuelDispenserId!, 
        nozzleId: _nozzleId!,
        pricePerLiter: _fuelPrice,
        petrolPumpId: petrolPumpId,
        fuelTypeId: fuelTypeId,
      );
      
      // Log the JSON that will be sent
      print('SUBMIT_DEBUG: JSON payload: ${jsonEncode(sales.toJson())}');
      
      final res = await repo.submitShiftSales(sales);
      
      print('SUBMIT_DEBUG: Response success: ${res.success}');
      print('SUBMIT_DEBUG: Response error message: ${res.errorMessage}');
      
      // If sales submission was successful and testing is enabled, submit testing data
      bool testingSubmissionSuccess = true;
      if (res.success && _isTestingEnabled) {
        try {
          print('SUBMIT_DEBUG: Submitting government testing data');
          
          // Make sure we have a valid testing volume
          final testingLiters = double.tryParse(_testingLitersController.text);
          if (testingLiters == null || testingLiters <= 0) {
            throw Exception('Invalid testing volume');
          }
          
          // Ensure fuelTypeId is set properly - try to get from selected nozzle assignment
          String? finalFuelTypeId = fuelTypeId;
          if ((finalFuelTypeId == null || finalFuelTypeId.isEmpty) && _selectedNozzleAssignment != null) {
            finalFuelTypeId = _selectedNozzleAssignment!.fuelTypeId;
            print('SUBMIT_DEBUG: Using fuelTypeId from nozzle assignment: $finalFuelTypeId');
          }
          
          // Ensure fuelTankId is properly formatted - null instead of empty string
          String? finalFuelTankId = null;
          if (fuelTankId != null && fuelTankId.isNotEmpty) {
            finalFuelTankId = fuelTankId;
            print('SUBMIT_DEBUG: Using fuelTankId: $finalFuelTankId');
          } else if (_selectedNozzleAssignment != null && _selectedNozzleAssignment!.fuelTankId != null) {
            finalFuelTankId = _selectedNozzleAssignment!.fuelTankId;
            print('SUBMIT_DEBUG: Using fuelTankId from nozzle assignment: $finalFuelTankId');
          }
          
          final testing = GovernmentTesting(
            employeeId: _employeeId!,
            nozzleId: _nozzleId!,
            petrolPumpId: petrolPumpId,
            shiftId: _shiftId!,
            testingLiters: testingLiters,
            notes: _notesController.text,
            fuelTankId: finalFuelTankId,
            fuelTypeId: finalFuelTypeId,
          );
          
          final testingRepo = GovernmentTestingRepository();
          final testingResponse = await testingRepo.submitGovernmentTesting(testing);
          
          print('SUBMIT_DEBUG: Testing submission result: ${testingResponse.success}');
          if (!testingResponse.success) {
            print('SUBMIT_DEBUG: Testing submission error: ${testingResponse.errorMessage}');
            testingSubmissionSuccess = false;
            
            // Show more specific error message for testing failure
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Testing data submission failed: ${testingResponse.errorMessage}'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          }
        } catch (e) {
          print('SUBMIT_DEBUG: Error submitting testing data: $e');
          testingSubmissionSuccess = false;
          
          // Show error for exception during testing submission
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Testing data error: ${e.toString()}'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
      
      setState(() { _loading = false; });
      
      if (res.success) {
        // Show success snackbar before popping
        print('SUBMIT_DEBUG: Submission successful');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isTestingEnabled 
                ? (testingSubmissionSuccess 
                    ? 'Sales and testing data submitted successfully' 
                    : 'Sales submitted, but testing data failed')
                : 'Sales data submitted successfully'
            ),
            backgroundColor: _isTestingEnabled && !testingSubmissionSuccess ? Colors.orange : Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        print('SUBMIT_DEBUG: Submission failed: ${res.errorMessage}');
        setState(() { 
          _error = res.errorMessage ?? 'Unknown error occurred';
        });
        
        // Show a more user-friendly error message for specific error scenarios
        if (res.errorMessage != null && res.errorMessage!.contains('500')) {
          setState(() {
            _error = 'Server error: The sales data could not be processed. Please check your entries and try again.';
          });
        }
      }
    } catch (e) {
      print('SUBMIT_DEBUG: Exception: $e');
      if (e is Error) {
        print('SUBMIT_DEBUG: Stack trace: ${e.stackTrace}');
      }
      setState(() { 
        _loading = false;
        _error = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  // Helper to calculate the total automatically
  void _calculateTotal() {
    try {
      double cash = double.tryParse(_cashAmountController.text) ?? 0;
      double card = double.tryParse(_creditCardAmountController.text) ?? 0;
      double upi = double.tryParse(_upiAmountController.text) ?? 0;
      double total = cash + card + upi;
      
      // Update total field
      _totalAmountController.text = total.toStringAsFixed(2);
      
      // Recalculate variance when total changes
      _calculateVariance();
      
      // Force UI update to reflect new colors
      setState(() {});
    } catch (e) {
      // Just ignore calculation errors
      print('Error calculating total: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside of text fields
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            'Submit Sales',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          elevation: 0,
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          actions: [
            // Refresh button
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh nozzle data',
              onPressed: _fetching 
                ? null // Disable when already fetching
                : () async {
                    // Clear the error state if any
                    setState(() {
                      _error = null;
                    });
                    
                    // Show loading indicator and refetch data
                    await _initializeData();
                    
                    // Show success message
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Data refreshed'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
            ),
          ],
        ),
        body: _fetching
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading your data...',
                      style: GoogleFonts.poppins(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : _buildBody(),
      ),
    );
  }

  // Extract body content to a separate method for better organization
  Widget _buildBody() {
    return Column(
      children: [
        // Header section with summary
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User guidance text
              Text(
                _selectedNozzleAssignment != null 
                    ? 'Submit sales for ${_selectedNozzleAssignment!.fuelType} - Nozzle ${_selectedNozzleAssignment!.nozzleNumber}'
                    : 'Select a nozzle to submit sales',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha:0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        // Form with a slight shadow
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
            ),
            child: RefreshIndicator(
              onRefresh: () async {
                await _initializeData();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Nozzle Selection Dropdown
                        _buildNozzleSelectionDropdown(),
                        
                        const SizedBox(height: 16),



                        // Fuel details card
                        _buildFuelDetailsCard(),

                        const SizedBox(height: 16),
                        // Meter readings card
                        _buildMeterReadingsCard(),
                        
                        const SizedBox(height: 16),
                        
                        // Payment details card
                        _buildPaymentDetailsCard(),
                        

                        
                        // Variance indicator
                        if (_hasVariance && _expectedAmount > 0)
                          _buildVarianceIndicator(),
                        
                        // Error Message
                        if (_error != null)
                          _buildErrorMessage(),
                        
                        const SizedBox(height: 20),
                        
                        // Collection Summary
                        _buildCollectionSummary(),
                        
                        const SizedBox(height: 24),
                        
                        // Submit Button
                        _buildSubmitButton(),
                        
                        // Bottom padding for scrolling
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Update the UI when the fuel price changes
  void _updateFuelPriceUI() {
    // This allows us to update the UI elements that show fuel price
    setState(() {});
  }

  // Helper widget to create consistent amount input fields 
  Widget _buildAmountField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          decoration: AppTheme.inputDecoration(
            label,
            hint: hint,
          ).copyWith(
            prefixIcon: Icon(
              icon,
              color: color.withValues(alpha:0.8),
            ),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.poppins(),
          validator: (v) => v!.isEmpty ? '$label is required' : null,
        ),
      ],
    );
  }

  // Helper widget for meter reading info cards
  Widget _buildInfoCard(String label, String value, {required IconData icon, required Color color}) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha:0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color.withValues(alpha:0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper widget for variance details
  Widget _buildVarianceDetail(String label, String value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  // Get current employee ID
  Future<void> _getCurrentEmployeeId() async {
    try {
      final empResp = await EmployeeRepository().getCurrentEmployee();
      if (empResp.success && empResp.data != null) {
        setState(() {
          _employeeId = empResp.data!.id;
        });
        print('Current employee ID: $_employeeId');
      } else {
        print('Failed to get current employee: ${empResp.errorMessage}');
      }
    } catch (e) {
      print('Error getting current employee: $e');
    }
  }
  
  // Fetch employee nozzle assignments for dropdown
  Future<void> _fetchNozzleAssignments() async {
    if (_employeeId == null) return;
    
    setState(() {
      _loadingNozzleAssignments = true;
    });
    
    try {
      final response = await NozzleAssignmentRepository()
          .getEmployeeNozzleAssignments(_employeeId!);
      
      setState(() {
        _loadingNozzleAssignments = false;
        
        if (response.success && response.data != null) {
          _nozzleAssignments = response.data!;
          print('Loaded ${_nozzleAssignments.length} nozzle assignments');
          
          // If we already have a nozzle ID, select the matching assignment
          if (_nozzleId != null && _nozzleAssignments.isNotEmpty) {
            _selectedNozzleAssignment = _nozzleAssignments.firstWhere(
              (assignment) => assignment.nozzleId == _nozzleId,
              orElse: () => _nozzleAssignments.first,
            );
          } 
          // Otherwise select the first assignment by default
          else if (_nozzleAssignments.isNotEmpty) {
            _selectedNozzleAssignment = _nozzleAssignments.first;
            _updateSelectedNozzleData();
          }
        } else {
          print('Error loading nozzle assignments: ${response.errorMessage}');
        }
      });
    } catch (e) {
      setState(() {
        _loadingNozzleAssignments = false;
      });
      print('Exception in _fetchNozzleAssignments: $e');
    }
  }
  
  // Update the nozzle data based on selected assignment
  void _updateSelectedNozzleData() async {
    if (_selectedNozzleAssignment != null) {
      setState(() {
        _nozzleId = _selectedNozzleAssignment!.nozzleId;
        _shiftId = _selectedNozzleAssignment!.shiftId;
        _loading = true; // Show loading state while fetching data
      });
      
      // First get the current fuel price immediately
      await _fetchCurrentFuelPrice();
      
      // Get the fuel dispenser ID from the nozzle repository
      try {
        final nozzleResp = await NozzleRepository().getNozzleById(_nozzleId!);
        if (nozzleResp.success && nozzleResp.data != null) {
          setState(() {
            _fuelDispenserId = nozzleResp.data!.fuelDispenserUnitId;
          });
        }
      } catch (e) {
        print('Error getting nozzle details: $e');
      }
      
      // Fetch meter readings and price for the selected nozzle
      await _fetchMeterReadingsAndPrice();
      
      // Save to preferences
      await _saveToPreferences();
      
      // Update loading state
      setState(() {
        _loading = false;
      });
      
      // Calculate expected amount if we have both fuel price and liters
      if (_fuelPrice > 0 && _litersSoldController.text.isNotEmpty) {
        _calculateExpectedAmount();
      }
    }
  }
  
  // Fetch current fuel price for the selected nozzle
  Future<void> _fetchCurrentFuelPrice() async {
    if (_nozzleId == null) return;
    
    try {
      print('DEBUG: Fetching current fuel price for nozzle ID: $_nozzleId');
      
      // Add this section to directly get fuel type info from selectedNozzleAssignment
      if (_selectedNozzleAssignment != null) {
        // Override the FuelPriceRepository method to use fuel type from assignment
        print('DEBUG: Using fuel type from selected nozzle assignment: ${_selectedNozzleAssignment!.fuelType}');
        print('DEBUG: Using fuel type ID from selected nozzle assignment: ${_selectedNozzleAssignment!.fuelTypeId}');
        
        // Modified approach: Get all fuel prices and find the matching one
        final allPricesResp = await FuelPriceRepository().getAllFuelPrices();
        
        if (allPricesResp.success && allPricesResp.data != null && allPricesResp.data!.isNotEmpty) {
          final allPrices = allPricesResp.data!;
          
          // First try to match by fuel type ID
          FuelPrice? matchingPriceById;
          FuelPrice? matchingPriceByName;
          
          // Log all available prices for debugging
          print('DEBUG: All available fuel prices:');
          for (var price in allPrices) {
            print('DEBUG: Fuel Type: ${price.fuelType}, ID: ${price.fuelTypeId}, Price: ${price.price}');
            
            // Try to match by fuelTypeId
            if (price.fuelTypeId == _selectedNozzleAssignment!.fuelTypeId) {
              matchingPriceById = price;
              print('DEBUG: Found matching price by ID: ${price.price} for ${price.fuelType}');
            }
            
            // Also check for name match in the same loop
            if (price.fuelType?.toLowerCase() == _selectedNozzleAssignment!.fuelType.toLowerCase()) {
              matchingPriceByName = price;
              print('DEBUG: Found matching price by name: ${price.price} for ${price.fuelType}');
            }
          }
          
          // Prioritize ID matches, then name matches
          FuelPrice? matchingPrice = matchingPriceById ?? matchingPriceByName;
          
          // Check if we have both ID and name matches but with different fuel types
          if (matchingPriceById != null && matchingPriceByName != null) {
            // If ID match's fuel type doesn't match the selected nozzle's fuel type,
            // but name match does, prefer the name match
            if (matchingPriceById.fuelType?.toLowerCase() != _selectedNozzleAssignment!.fuelType.toLowerCase() &&
                matchingPriceByName.fuelType?.toLowerCase() == _selectedNozzleAssignment!.fuelType.toLowerCase()) {
              matchingPrice = matchingPriceByName;
              print('DEBUG: Overriding ID match with name match because fuel types match better.');
            }
          }
          
          // Use the matching price if found
          if (matchingPrice != null) {
            setState(() {
              _fuelPrice = matchingPrice!.price;
              print('DEBUG: Using matched fuel price: ₹${_fuelPrice.toStringAsFixed(2)}');
              
              // If liters already entered, calculate expected amount
              if (_litersSoldController.text.isNotEmpty) {
                _calculateExpectedAmount();
              }
            });
            
            // Show the current fuel price in a snackbar
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Current ${_selectedNozzleAssignment?.fuelType ?? "fuel"} price: ₹${_fuelPrice.toStringAsFixed(2)}',
                  ),
                  backgroundColor: Colors.blue.shade700,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            }
            
            // We found the matching price, so return early
            return;
          }
        }
      }
      
      // Fallback to the original method if the direct approach failed
      final priceResp = await FuelPriceRepository().getFuelPrice(_nozzleId!);
      if (priceResp.success && priceResp.data != null) {
        setState(() {
          _fuelPrice = priceResp.data!.price;
          print('DEBUG: Fetched current fuel price: ₹${_fuelPrice.toStringAsFixed(2)} for nozzle ID: $_nozzleId');
          
          // If liters already entered, calculate expected amount
          if (_litersSoldController.text.isNotEmpty) {
            _calculateExpectedAmount();
          }
        });
        
        // Show the current fuel price in a snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Current ${_selectedNozzleAssignment != null ? _selectedNozzleAssignment!.fuelType : "fuel"} price: ₹${_fuelPrice.toStringAsFixed(2)}',
              ),
              backgroundColor: Colors.blue.shade700,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('DEBUG: Failed to get fuel price. Response status: ${priceResp.success}, Error: ${priceResp.errorMessage}');
      }
    } catch (e) {
      print('Error fetching fuel price: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not fetch current fuel price: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Helper widget for nozzle selection dropdown
  Widget _buildNozzleSelectionDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.offline_bolt,
                color: AppTheme.primaryOrange,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                widget.nozzleId != null ? 'Nozzle Details' : 'Select Nozzle',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          _loadingNozzleAssignments
              ? Center(
                  child: SizedBox(
                    height: 30,
                    width: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                )
              : _nozzleAssignments.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red[700],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No nozzle assignments found',
                              style: GoogleFonts.poppins(
                                color: Colors.red[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : widget.nozzleId != null && _selectedNozzleAssignment != null
                    ? _buildSelectedNozzleView(_selectedNozzleAssignment!)
                    : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                        color: Colors.grey.shade50,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<EmployeeNozzleAssignment>(
                          isExpanded: true,
                          value: _selectedNozzleAssignment,
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          borderRadius: BorderRadius.circular(12),
                          hint: Text(
                            'Select a nozzle',
                            style: GoogleFonts.poppins(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: AppTheme.primaryBlue,
                            size: 30,
                          ),
                          items: _nozzleAssignments.map((assignment) {
                            return DropdownMenuItem<EmployeeNozzleAssignment>(
                              value: assignment,
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _getFuelTypeColor(assignment.fuelType),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        assignment.nozzleNumber.toString(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Nozzle ${assignment.nozzleNumber}',
                                          style: GoogleFonts.poppins(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          assignment.fuelType,
                                          style: GoogleFonts.poppins(
                                            color: _getFuelTypeColor(assignment.fuelType),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (assignment) {
                            if (assignment != null) {
                              setState(() {
                                _selectedNozzleAssignment = assignment;
                              });
                              _updateSelectedNozzleData();
                            }
                          },
                        ),
                      ),
                    ),
                    
          if (_selectedNozzleAssignment != null && widget.nozzleId == null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _getFuelTypeColor(_selectedNozzleAssignment!.fuelType).withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: _getFuelTypeColor(_selectedNozzleAssignment!.fuelType),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Selected: ${_selectedNozzleAssignment!.fuelType} (₹${_fuelPrice.toStringAsFixed(2)}/liter)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  // Helper to display selected nozzle view without dropdown
  Widget _buildSelectedNozzleView(EmployeeNozzleAssignment assignment) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getFuelTypeColor(assignment.fuelType).withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getFuelTypeColor(assignment.fuelType).withValues(alpha:0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getFuelTypeColor(assignment.fuelType),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                assignment.nozzleNumber.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Nozzle ${assignment.nozzleNumber}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getFuelTypeColor(assignment.fuelType).withValues(alpha:0.3),
                        ),
                      ),
                      child: Text(
                        assignment.isActive ? 'Active' : 'Inactive',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: assignment.isActive 
                              ? Colors.green.shade600
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  assignment.fuelType,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getFuelTypeColor(assignment.fuelType),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.local_gas_station,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '₹${_fuelPrice.toStringAsFixed(2)}/liter',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
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
  
  // Helper function to get color for fuel type
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

  // Meter readings card
  Widget _buildMeterReadingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.speed_outlined,
                  color: Colors.grey.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Meter Readings',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),

          // Current reading details in visual format
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                // Reading visualization
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                  child: Row(
                    children: [
                      // Start reading marker
                      Container(
                        width: 10,
                        height: 10,
                        transform: Matrix4.translationValues(0, -2.5, 0),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade600,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                      
                      // Progress bar - filled part
                      Expanded(
                        flex: (_endReading - _startReading).round(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(2.5),
                              bottomRight: Radius.circular(2.5),
                            ),
                          ),
                        ),
                      ),
                      
                      // End reading marker
                      Container(
                        width: 10,
                        height: 10,
                        transform: Matrix4.translationValues(0, -2.5, 0),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Reading values
                Row(
                  children: [
                    Expanded(
                      child: _buildReadingValueBox(
                        label: 'Start Reading',
                        value: _startReading.toStringAsFixed(2),
                        icon: Icons.play_circle_outline,
                        color: Colors.grey.shade600,
                        backgroundOpacity: 0.05,
                      ),
                    ),
                    
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Icon(
                            Icons.arrow_right_alt,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              (_endReading - _startReading).toStringAsFixed(2),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Expanded(
                      child: _buildReadingValueBox(
                        label: 'End Reading',
                        value: _endReading.toStringAsFixed(2),
                        icon: Icons.stop_circle_outlined,
                        color: AppTheme.primaryBlue,
                        backgroundOpacity: 0.05,
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
  
  // Helper for building reading value boxes
  Widget _buildReadingValueBox({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    double backgroundOpacity = 0.1,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:backgroundOpacity),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha:0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  // Payment details card
  Widget _buildPaymentDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  color: AppTheme.primaryBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Payment Details',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Payment methods intro
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Enter the amount received through each payment method',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Cash Amount
                _buildPaymentMethodInput(
                  controller: _cashAmountController,
                  label: 'Cash Collection',
                  hint: 'Enter amount received in cash',
                  icon: Icons.money,
                  color: Colors.green.shade600,
                ),
                const SizedBox(height: 12),
                
                // Card Amount
                _buildPaymentMethodInput(
                  controller: _creditCardAmountController,
                  label: 'Card Collection',
                  hint: 'Enter amount received via card',
                  icon: Icons.credit_card,
                  color: Colors.blue.shade600,
                ),
                const SizedBox(height: 12),
                
                // UPI Amount
                _buildPaymentMethodInput(
                  controller: _upiAmountController,
                  label: 'UPI Collection',
                  hint: 'Enter amount received via UPI',
                  icon: Icons.smartphone,
                  color: Colors.purple.shade600,
                ),
                
                // Subtotal summary
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SUBTOTAL',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '₹ ',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                  Text(
                                    ((double.tryParse(_cashAmountController.text) ?? 0) +
                                     (double.tryParse(_creditCardAmountController.text) ?? 0) +
                                     (double.tryParse(_upiAmountController.text) ?? 0)).toStringAsFixed(2),
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildPaymentMethodAmount(
                              'Cash:', 
                              double.tryParse(_cashAmountController.text) ?? 0,
                              Colors.green.shade600
                            ),
                            _buildPaymentMethodAmount(
                              'Card:', 
                              double.tryParse(_creditCardAmountController.text) ?? 0,
                              Colors.blue.shade600
                            ),
                            _buildPaymentMethodAmount(
                              'UPI:', 
                              double.tryParse(_upiAmountController.text) ?? 0,
                              Colors.purple.shade600
                            ),
                          ],
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
    );
  }
  
  // Helper to build payment method input
  Widget _buildPaymentMethodInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              prefixIcon: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 50),
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade800,
            ),
            validator: (v) => v!.isEmpty ? '$label is required' : null,
          ),
        ),
      ],
    );
  }
  
  // Helper to build payment method amount display
  Widget _buildPaymentMethodAmount(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '₹ ${amount.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fuel details card
  Widget _buildFuelDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.local_gas_station,
                  color: Colors.grey.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Fuel Details',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                Spacer(),
                if (_fuelPrice > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.currency_rupee, size: 10, color: AppTheme.primaryBlue),
                        Text(
                          '${_fuelPrice.toStringAsFixed(2)}/L',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Liters Sold - with real-time calculation indication
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            'Liters Sold',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (_endReading > _startReading)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 10,
                                    color: AppTheme.primaryBlue,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'From meter: ${(_endReading - _startReading).toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextFormField(
                        controller: _litersSoldController,
                        decoration: InputDecoration(
                          hintText: 'Auto-calculated from meter readings',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.opacity,
                            color: AppTheme.primaryBlue,
                            size: 18,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue.shade100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome,
                                      size: 10,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Auto',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.grey.shade100,
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Text(
                                  'L',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        readOnly: true, // Make field read-only since it's calculated
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                        validator: (v) => v!.isEmpty ? 'Liters sold is required' : null,
                        onChanged: (val) {
                          // This will trigger the listener which calculates the expected amount
                          if (val.isNotEmpty && _fuelPrice > 0) {
                            _calculateExpectedAmount();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Total Amount - with auto-calculation note
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with auto-calculation indicator
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            'Total Amount',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _hasVariance 
                                ? (_isVarianceHigh ? Colors.red.shade50 : Colors.orange.shade50)
                                : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _hasVariance 
                                    ? (_isVarianceHigh ? Icons.error_outline : Icons.warning_amber)
                                    : Icons.check_circle,
                                  size: 10,
                                  color: _hasVariance 
                                    ? (_isVarianceHigh ? Colors.red.shade700 : Colors.orange.shade700)
                                    : AppTheme.primaryBlue,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  _hasVariance 
                                    ? (_isVarianceHigh ? 'High variance' : 'Moderate variance')
                                    : 'Matches expected',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: _hasVariance 
                                      ? (_isVarianceHigh ? Colors.red.shade700 : Colors.orange.shade700)
                                      : AppTheme.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Total amount field with dynamic styling based on match
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: _hasVariance 
                          ? (_isVarianceHigh ? Colors.red.shade50 : Colors.orange.shade50)
                          : Colors.grey.shade50,
                        border: Border.all(
                          color: _hasVariance 
                            ? (_isVarianceHigh ? Colors.red.shade200 : Colors.orange.shade200)
                            : Colors.grey.shade200,
                        ),
                      ),
                      child: TextFormField(
                        controller: _totalAmountController,
                        decoration: InputDecoration(
                          hintText: 'Auto-calculated from liters sold',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            _hasVariance 
                              ? (_isVarianceHigh ? Icons.warning_amber : Icons.info_outline)
                              : Icons.check_circle_outline,
                            color: _hasVariance 
                              ? (_isVarianceHigh ? Colors.red.shade700 : Colors.orange.shade700)
                              : AppTheme.primaryBlue,
                            size: 18,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue.shade100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome,
                                      size: 10,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Auto',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.grey.shade100,
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Text(
                                  '₹',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        readOnly: true, // Make field read-only since it's calculated from meter readings
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _hasVariance 
                            ? (_isVarianceHigh ? Colors.red.shade700 : Colors.orange.shade700)
                            : Colors.grey.shade800,
                        ),
                        validator: (v) => v!.isEmpty ? 'Total amount is required' : null,
                        onChanged: (_) => _calculateVariance(),
                      ),
                    ),
                    
                    // Real-time variance display
                    if (_expectedAmount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Row(
                          children: [
                            Icon(
                              _hasVariance
                                ? (_isVarianceHigh
                                    ? Icons.error_outline
                                    : Icons.info_outline)
                                : Icons.check_circle_outline,
                              size: 12,
                              color: _hasVariance
                                ? (_isVarianceHigh
                                    ? Colors.red.shade700
                                    : Colors.orange.shade700)
                                : AppTheme.primaryBlue,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _hasVariance
                                  ? 'Expected: ₹${_expectedAmount.toStringAsFixed(2)}, Variance: ₹${_variance.toStringAsFixed(2)} (${(_variance > 0 ? '+' : '')}${(_variance / _expectedAmount * 100).toStringAsFixed(1)}%)'
                                  : 'Collection matches expected amount of ₹${_expectedAmount.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: _hasVariance
                                    ? (_isVarianceHigh
                                        ? Colors.red.shade700
                                        : Colors.orange.shade700)
                                    : AppTheme.primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                
                // Government Testing Section
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.science_outlined,
                        size: 16,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Government Testing',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const Spacer(),
                      // Toggle switch for testing
                      Switch(
                        value: _isTestingEnabled,
                        onChanged: (value) {
                          setState(() {
                            _isTestingEnabled = value;
                            if (!value) {
                              // Clear testing values when disabled
                              _testingLitersController.clear();
                              _notesController.clear();
                            }
                          });
                        },
                        activeColor: AppTheme.primaryBlue,
                        activeTrackColor: Colors.blue.shade100,
                      ),
                    ],
                  ),
                ),

                // Info note about government testing
                if (!_isTestingEnabled)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Toggle this switch if you need to record government testing volumes for this nozzle',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Testing inputs - only show when enabled
                if (_isTestingEnabled) ...[
                  // Testing volume input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              'Testing Volume',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextFormField(
                          controller: _testingLitersController,
                          decoration: InputDecoration(
                            hintText: 'Enter testing volume in liters',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.opacity,
                              color: AppTheme.primaryBlue,
                              size: 18,
                            ),
                            suffixIcon: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.grey.shade100,
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                'L',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                          validator: _isTestingEnabled 
                              ? (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter testing volume';
                                  }
                                  try {
                                    double.parse(value);
                                  } catch (e) {
                                    return 'Please enter a valid number';
                                  }
                                  return null;
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Notes input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              'Notes (Optional)',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextFormField(
                          controller: _notesController,
                          decoration: InputDecoration(
                            hintText: 'Add any notes about the testing',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.note_add,
                              color: AppTheme.primaryBlue,
                              size: 18,
                            ),
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                          maxLines: 3,
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 12,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Government testing will be submitted along with your sales data',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Variance indicator
  Widget _buildVarianceIndicator() {
    // Determine colors based on variance severity
    final Color bgColor = _isVarianceHigh ? Colors.red.shade50 : Colors.orange.shade50;
    final Color borderColor = _isVarianceHigh ? Colors.red.shade200 : Colors.orange.shade200;
    final Color textColor = _isVarianceHigh ? Colors.red.shade700 : Colors.orange.shade700;
    final Color iconColor = _isVarianceHigh ? Colors.red.shade600 : Colors.orange.shade600;
    
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha:0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isVarianceHigh 
                      ? Icons.warning_amber_rounded 
                      : Icons.info_outline,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isVarianceHigh
                          ? 'High Variance Detected'
                          : 'Collection Variance',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Text(
                        _isVarianceHigh
                          ? 'Please verify your entries carefully'
                          : 'There is a small difference in the expected amount',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: textColor.withValues(alpha:0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: borderColor),
            ),
            
            // Variance details
            Row(
              children: [
                Expanded(
                  child: _buildVarianceDetailColumn(
                    'Expected',
                    '₹${_expectedAmount.toStringAsFixed(2)}',
                    Colors.grey.shade700,
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: borderColor,
                ),
                Expanded(
                  child: _buildVarianceDetailColumn(
                    'Actual',
                    '₹${_totalAmountController.text}',
                    Colors.grey.shade700,
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: borderColor,
                ),
                Expanded(
                  child: _buildVarianceDetailColumn(
                    'Variance',
                    '₹${_variance.toStringAsFixed(2)}',
                    _variance < 0 ? Colors.red.shade700 : Colors.green.shade700,
                    subtitle: '${(_variance > 0 ? '+' : '')}${(_variance / _expectedAmount * 100).toStringAsFixed(1)}%',
                  ),
                ),
              ],
            ),
            
            if (_isVarianceHigh) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 14,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The difference between expected and actual collection exceeds ${_varianceThreshold.toStringAsFixed(1)}%. Please check your entries or consult your manager.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
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
  }
  
  // Helper widget for variance details
  Widget _buildVarianceDetailColumn(String label, String value, Color textColor, {String? subtitle}) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: textColor,
            ),
          ),
        ]
      ],
    );
  }

  // Error message
  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[700],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: GoogleFonts.poppins(
                  color: Colors.red[700],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Collection Summary
  Widget _buildCollectionSummary() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.summarize_rounded,
                  color: Colors.grey.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Collection Summary',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Collection amounts
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      // Expected collection row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EXPECTED AMOUNT',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '₹',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    _expectedAmount.toStringAsFixed(2),
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          // Calculation formula
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  (double.tryParse(_litersSoldController.text) ?? 0).toStringAsFixed(2),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Text(
                                    '×',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '₹${_fuelPrice.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: Colors.grey.shade200),
                      ),
                      
                      // Actual collection row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ACTUAL COLLECTION',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    _hasVariance 
                                      ? (_isVarianceHigh ? Icons.warning_amber : Icons.info_outline)
                                      : Icons.check_circle_outline,
                                    size: 14,
                                    color: _hasVariance 
                                      ? (_isVarianceHigh ? Colors.red.shade700 : Colors.orange.shade700)
                                      : AppTheme.primaryBlue,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '₹${double.tryParse(_totalAmountController.text)?.toStringAsFixed(2) ?? '0.00'}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _hasVariance 
                                        ? (_isVarianceHigh ? Colors.red.shade700 : Colors.orange.shade700)
                                        : AppTheme.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          // Variance indicator
                          if (_hasVariance && _expectedAmount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isVarianceHigh ? Colors.red.shade50 : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _isVarianceHigh ? Colors.red.shade200 : Colors.orange.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isVarianceHigh ? Icons.error_outline : Icons.info_outline,
                                    size: 12,
                                    color: _isVarianceHigh ? Colors.red.shade700 : Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(_variance > 0 ? '+' : '')}${(_variance / _expectedAmount * 100).toStringAsFixed(1)}%',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _isVarianceHigh ? Colors.red.shade700 : Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 12,
                                    color: AppTheme.primaryBlue,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Match',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryBlue,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Submit button
  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha:0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      height: 50,
      child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          disabledBackgroundColor: AppTheme.primaryBlue.withValues(alpha:0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.zero,
        ),
        child: _loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isTestingEnabled ? Icons.science_outlined : Icons.check_circle_outline,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _isTestingEnabled ? 'Submit Sales & Testing' : 'Submit Sales',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

