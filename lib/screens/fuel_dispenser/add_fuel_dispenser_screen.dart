import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/fuel_dispenser_repository.dart';
import '../../models/fuel_dispenser_model.dart';
import '../../theme.dart';
import 'dart:developer' as developer;

class AddFuelDispenserScreen extends StatefulWidget {
  const AddFuelDispenserScreen({super.key});

  @override
  State<AddFuelDispenserScreen> createState() => _AddFuelDispenserScreenState();
}

class _AddFuelDispenserScreenState extends State<AddFuelDispenserScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _dispenserNumberController = TextEditingController();
  final _numberOfNozzlesController = TextEditingController(text: '1');
  
  // Repository
  final _dispenserRepository = FuelDispenserRepository();
  
  // State variables
  bool _isLoading = false;
  String _errorMessage = '';
  String? _petrolPumpId;
  
  // Selected values
  String _selectedStatus = 'Maintenance'; // Default changed to Maintenance
  
  // Status options
  final List<String> _statusOptions = ['Active', 'Maintenance', 'Inactive'];
  
  @override
  void initState() {
    super.initState();
    _getPetrolPumpId();
    // Auto-generate dispenser number
    _dispenserNumberController.text = '1';
  }
  
  @override
  void dispose() {
    _dispenserNumberController.dispose();
    _numberOfNozzlesController.dispose();
    super.dispose();
  }
  
  // Get petrol pump ID
  Future<void> _getPetrolPumpId() async {
    try {
      final pumpId = await _dispenserRepository.getPetrolPumpId();
      
      if (!mounted) return;
      
      setState(() {
        _petrolPumpId = pumpId;
        if (pumpId == null) {
          _errorMessage = 'Could not retrieve petrol pump ID. Please login again.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'Error retrieving petrol pump ID: $e';
      });
    }
  }
  
  // Submit the form to add dispenser
  Future<void> _submitForm() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      if (_dispenserNumberController.text.isEmpty ||
          _numberOfNozzlesController.text.isEmpty) {
        setState(() {
          _errorMessage = 'Please fill in all fields';
          _isLoading = false;
        });
        return;
      }

      final dispenser = FuelDispenser(
        dispenserNumber: int.parse(_dispenserNumberController.text),
        petrolPumpId: _petrolPumpId!,
        status: _selectedStatus,
        numberOfNozzles: int.parse(_numberOfNozzlesController.text),
        fuelType: "<string>", id: '', // Use "<string>" as fuelType
      );

      final validationErrors = dispenser.validate();
      if (validationErrors.isNotEmpty) {
        setState(() {
          _errorMessage = validationErrors.values.first.join(', ');
          _isLoading = false;
        });
        return;
      }
      
      developer.log('Submitting dispenser: ${dispenser.toJson()}');
      
      // Call repository to add dispenser
      final response = await _dispenserRepository.addFuelDispenser(dispenser);
      
      if (!mounted) return;
      
      if (response.success) {
        developer.log('Fuel dispenser added successfully');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fuel dispenser added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Return true to refresh the dispensers list screen if navigating back
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = response.errorMessage ?? 'Failed to add fuel dispenser';
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }
  
  // Get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      case 'inactive':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Fuel Dispenser'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Simple header
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.grey.shade50,
                child: const Text(
                  'Enter fuel dispenser details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              // Error message
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ),
              
              // Input fields
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Dispenser Number
                    const Text('Dispenser Number'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _dispenserNumberController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Number of Nozzles
                    const Text('Number of Nozzles'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _numberOfNozzlesController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null || int.parse(value) <= 0) {
                          return 'Must be a positive number';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Status selection
                    const Text('Initial Status'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      value: _selectedStatus,
                      items: _statusOptions.map((status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(status),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedStatus = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              
              // Submit button
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('ADD DISPENSER'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 