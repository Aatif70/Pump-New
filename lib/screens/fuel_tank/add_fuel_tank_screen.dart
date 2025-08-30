import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/api_constants.dart';
import '../../api/fuel_tank_repository.dart';
import '../../models/fuel_tank_model.dart';
import '../../models/fuel_type_model.dart';
import '../../theme.dart';
import 'dart:developer' as developer;

class AddFuelTankScreen extends StatefulWidget {
  const AddFuelTankScreen({super.key});

  @override
  State<AddFuelTankScreen> createState() => _AddFuelTankScreenState();
}

class _AddFuelTankScreenState extends State<AddFuelTankScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _capacityController = TextEditingController();
  final _fuelTypeController = TextEditingController();
  final _currentStockController = TextEditingController();

  String _selectedStatus = 'Inactive'; // Default status
  
  bool _isLoading = false;
  bool _isLoadingFuelTypes = true;
  String _errorMessage = '';
  String? _selectedFuelTypeId;
  
  // Fuel types from API
  List<FuelType> _fuelTypes = [];
  
  // Status options
  final List<String> _statusOptions = [
    'Active',
    'Inactive',
    'Maintenance'
  ];
  
  @override
  void initState() {
    super.initState();
    _loadFuelTypes();
  }
  
  // Load fuel types from API
  Future<void> _loadFuelTypes() async {
    setState(() {
      _isLoadingFuelTypes = true;
    });
    
    try {
      final repository = FuelTankRepository();
      final petrolPumpId = await repository.getPetrolPumpId();
      
      if (petrolPumpId == null) {
        setState(() {
          _errorMessage = 'Petrol pump ID not found. Please login again.';
          _isLoadingFuelTypes = false;
        });
        return;
      }
      
      developer.log('Fetching fuel types for petrol pump ID: $petrolPumpId');
      final response = await repository.getFuelTypes();
      
      if (!mounted) return;
      
      if (response.success && response.data != null) {
        setState(() {
          _fuelTypes = response.data!;
          _isLoadingFuelTypes = false;
        });
        developer.log('Loaded ${_fuelTypes.length} fuel types');
      } else {
        setState(() {
          _errorMessage = response.errorMessage ?? 'Failed to load fuel types';
          _isLoadingFuelTypes = false;
        });
        developer.log('Failed to load fuel types: $_errorMessage');
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'Error loading fuel types: $e';
        _isLoadingFuelTypes = false;
      });
      developer.log('Exception loading fuel types: $e');
    }
  }
  
  // Dismiss keyboard when tapping outside text fields
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryBlue,
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _capacityController.dispose();
    _fuelTypeController.dispose();
    _currentStockController.dispose();
    super.dispose();
  }
  
  // Submit the form
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedFuelTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a fuel type'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final repository = FuelTankRepository();
      
      // Get the petrol pump ID (this would come from session/storage in a real app)
      final petrolPumpId = await repository.getPetrolPumpId();
      
      if (petrolPumpId == null) {
        setState(() {
          _errorMessage = 'Petrol pump ID not found. Please login again.';
          _isLoading = false;
        });
        return;
      }
      
      // Create fuel tank object
      final fuelTank = FuelTank(
        capacityInLiters: double.parse(_capacityController.text),
        fuelType: _fuelTypeController.text,
        petrolPumpId: petrolPumpId,
        currentStock: double.parse(_currentStockController.text),
        status: _selectedStatus,
        fuelTypeId: _selectedFuelTypeId,
      );
      
      // Log the request details
      developer.log('Sending POST request to ${ApiConstants.getFuelTankUrl()}');
      developer.log('Request body: ${fuelTank.toJson()}');
      
      // Call repository to add fuel tank
      final response = await repository.addFuelTank(fuelTank);
      
      if (!mounted) return;
      
      if (response.success) {
        developer.log('Fuel tank created successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Fuel tank added successfully'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        
        // Clear form
        _capacityController.clear();
        _fuelTypeController.clear();
        _currentStockController.clear();
        setState(() {
          _selectedStatus = 'Inactive';
          _selectedFuelTypeId = null;
        });
      } else {
        developer.log('Failed to create fuel tank: ${response.errorMessage}');
        setState(() {
          _errorMessage = response.errorMessage ?? 'Failed to add fuel tank';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      developer.log('Error submitting form: $e');
      setState(() {
        _errorMessage = e.toString();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add New Fuel Tank'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'New Fuel Tank',
                    style: AppTheme.headingStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add details for the new fuel storage tank',
                    style: AppTheme.subheadingStyle.copyWith(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Tank Details Card
                  _buildSectionTitle('Tank Details'),
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha:0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fuel Type field
                          Text(
                            'Fuel Type',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _fuelTypeController,
                            readOnly: true,
                            decoration: InputDecoration(
                              hintText: _isLoadingFuelTypes 
                                  ? 'Loading fuel types...' 
                                  : 'Select fuel type',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                              ),
                              prefixIcon: Icon(Icons.local_gas_station, color: AppTheme.primaryBlue),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              suffixIcon: _isLoadingFuelTypes 
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
                                        ),
                                      ),
                                    )
                                  : PopupMenuButton<String>(
                                      icon: const Icon(Icons.arrow_drop_down),
                                      enabled: !_isLoadingFuelTypes && _fuelTypes.isNotEmpty,
                                      onSelected: (String value) {
                                        // Find the selected fuel type object
                                        final selectedFuelType = _fuelTypes.firstWhere(
                                          (fuelType) => fuelType.name == value,
                                          orElse: () => FuelType(fuelTypeId: '', name: value, color: '#CCCCCC'),
                                        );
                                        
                                        setState(() {
                                          _fuelTypeController.text = value;
                                          _selectedFuelTypeId = selectedFuelType.fuelTypeId;
                                        });
                                        
                                        developer.log('Selected fuel type: ${selectedFuelType.name} (ID: ${selectedFuelType.fuelTypeId})');
                                      },
                                      itemBuilder: (BuildContext context) {
                                        if (_fuelTypes.isEmpty) {
                                          return [
                                            const PopupMenuItem<String>(
                                              value: '',
                                              enabled: false,
                                              child: Text('No fuel types available'),
                                            ),
                                          ];
                                        }
                                        
                                        return _fuelTypes.map<PopupMenuItem<String>>((FuelType fuelType) {
                                          return PopupMenuItem(
                                            value: fuelType.name,
                                            child: Text(fuelType.name),
                                          );
                                        }).toList();
                                      },
                                    ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a fuel type';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Capacity field
                          Text(
                            'Tank Capacity',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _capacityController,
                            decoration: InputDecoration(
                              hintText: 'Enter capacity in liters',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                              ),
                              prefixIcon: Icon(Icons.straighten, color: AppTheme.primaryBlue),
                              suffixText: 'Liters',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter capacity';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              if (double.parse(value) <= 0) {
                                return 'Capacity must be greater than zero';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Current Stock field
                          Text(
                            'Current Stock',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _currentStockController,
                            decoration: InputDecoration(
                              hintText: 'Enter current stock in liters',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                              ),
                              prefixIcon: Icon(Icons.opacity, color: AppTheme.primaryBlue),
                              suffixText: 'Liters',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter current stock';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              if (double.parse(value) < 0) {
                                return 'Current stock cannot be negative';
                              }
                              if (_capacityController.text.isNotEmpty && 
                                  double.parse(value) > double.parse(_capacityController.text)) {
                                return 'Current stock cannot exceed capacity';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Status Card
                  _buildSectionTitle('Tank Status'),
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha:0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Operating Status',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                              ),
                              prefixIcon: Icon(Icons.settings, color: AppTheme.primaryBlue),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            value: _selectedStatus,
                            items: _statusOptions.map((String status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedStatus = newValue;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          // Status helper text
                          Text(
                            _selectedStatus == 'Active'
                                ? 'Tank is ready for use and operational'
                                : _selectedStatus == 'Inactive'
                                    ? 'Tank is not currently in service'
                                    : 'Tank is undergoing maintenance',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Error message display
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  
                  // Submit Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
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
                                const Icon(Icons.add_circle_outline),
                                const SizedBox(width: 8),
                                Text(
                                  'Add Fuel Tank',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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
} 