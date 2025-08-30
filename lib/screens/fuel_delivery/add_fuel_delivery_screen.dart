import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:petrol_pump/api/fuel_delivery_repository.dart';
import 'package:petrol_pump/api/fuel_tank_repository.dart';
import 'package:petrol_pump/api/supplier_repository.dart';
import 'package:petrol_pump/models/fuel_delivery_model.dart';
import 'package:petrol_pump/models/fuel_tank_model.dart';
import 'package:petrol_pump/models/supplier_model.dart';
import 'package:petrol_pump/theme.dart';

class AddFuelDeliveryScreen extends StatefulWidget {
  final FuelTank? fuelTank;
  
  const AddFuelDeliveryScreen({
    super.key,
    this.fuelTank,
  });

  @override
  State<AddFuelDeliveryScreen> createState() => _AddFuelDeliveryScreenState();
}

class _AddFuelDeliveryScreenState extends State<AddFuelDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fuelDeliveryRepository = FuelDeliveryRepository();
  final _fuelTankRepository = FuelTankRepository();
  final _supplierRepository = SupplierRepository();
  
  bool _isLoading = false;
  bool _isInitializing = true;
  String _errorMessage = '';
  
  List<FuelTank> _fuelTanks = [];
  List<Supplier> _suppliers = [];
  
  // Form fields
  final _invoiceNumberController = TextEditingController();
  final _quantityController = TextEditingController();
  final _densityController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime _deliveryDate = DateTime.now();
  FuelTank? _selectedFuelTank;
  Supplier? _selectedSupplier;
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
    
    // Add listener for quantity updates
    _quantityController.addListener(() {
      _updatePreview(_quantityController.text);
    });
  }
  
  Future<void> _loadInitialData() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = '';
    });
    
    try {
      // Load fuel tanks
      final fuelTankResponse = await _fuelTankRepository.getAllFuelTanks();
      // Load suppliers
      final supplierResponse = await _supplierRepository.getAllSuppliers();
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
          
          if (fuelTankResponse.success && fuelTankResponse.data != null) {
            _fuelTanks = fuelTankResponse.data!;
            
            // If a fuel tank was passed, select it
            if (widget.fuelTank != null) {
              _selectedFuelTank = _fuelTanks.firstWhere(
                (tank) => tank.fuelTankId == widget.fuelTank!.fuelTankId,
                orElse: () => _fuelTanks.first,
              );
            }
          }
          
          if (supplierResponse.success && supplierResponse.data != null) {
            _suppliers = supplierResponse.data!;
          }
          
          // if (!fuelTankResponse.success || !supplierResponse.success) {
          //   _errorMessage = 'Failed to load initial data. Please try again.';
          // }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Error loading data: $e';
        });
      }
    }
  }
  
  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _quantityController.dispose();
    _densityController.dispose();
    _temperatureController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  // Dismiss keyboard when tapping outside text fields
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _deliveryDate) {
      setState(() {
        _deliveryDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _deliveryDate.hour,
          _deliveryDate.minute,
        );
      });
    }
  }
  
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deliveryDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _deliveryDate = DateTime(
          _deliveryDate.year,
          _deliveryDate.month,
          _deliveryDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }
  
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedFuelTank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a fuel tank'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a supplier'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Create fuel delivery model
      final fuelDelivery = FuelDelivery(
        deliveryDate: _deliveryDate,
        fuelTankId: _selectedFuelTank!.fuelTankId!,
        invoiceNumber: _invoiceNumberController.text.trim(),
        quantityReceived: double.tryParse(_quantityController.text.trim()) ?? 0.0,
        supplierId: _selectedSupplier!.supplierDetailId!,
        density: double.tryParse(_densityController.text.trim()) ?? 0.0,
        temperature: double.tryParse(_temperatureController.text.trim()) ?? 0.0,
        notes: _notesController.text.trim(),
      );
      
      // Log the data being sent
      print('FUEL DELIVERY - SENDING DATA:');
      print('Delivery Date: ${fuelDelivery.deliveryDate}');
      print('Fuel Tank ID: ${fuelDelivery.fuelTankId}');
      print('Invoice Number: ${fuelDelivery.invoiceNumber}');
      print('Quantity Received: ${fuelDelivery.quantityReceived}');
      print('Supplier ID: ${fuelDelivery.supplierId}');
      print('Density: ${fuelDelivery.density}');
      print('Temperature: ${fuelDelivery.temperature}');

      // Call API
      final response = await _fuelDeliveryRepository.addFuelDelivery(fuelDelivery);
      
      if (mounted) {
        if (response.success) {
          // Show success message and pop back
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Fuel delivery recorded successfully'),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          Navigator.pop(context);
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = response.errorMessage ?? 'Failed to record fuel delivery';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }
  
  Widget _buildSectionHeader(String title) {
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
  
  Widget _buildStyledFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    String? suffixText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            suffixText: suffixText,
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
            prefixIcon: Icon(icon, color: AppTheme.primaryBlue),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          keyboardType: keyboardType,
          validator: validator,
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              helperText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
  
  // Add these methods for tank visualization
  
  // Get fuel color based on fuel type
  Color _getFuelColor(String? fuelType) {
    if (fuelType == null) return Colors.grey.shade700;
    
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
  
  // Get color based on tank level percentage
  Color _getLevelColor(double percentage) {
    // Define our color stops
    const List<double> stops = [0.0, 20.0, 40.0, 60.0, 80.0, 100.0];
    final List<Color> colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow.shade700,
      Colors.lightGreen,
      Colors.green,
      Colors.green,
    ];
    
    // Find which segment the percentage falls into
    int index = 0;
    for (int i = 0; i < stops.length - 1; i++) {
      if (percentage >= stops[i] && percentage <= stops[i + 1]) {
        index = i;
        break;
      }
    }
    
    // Calculate how far along this segment we are (0.0 - 1.0)
    final double segmentLength = stops[index + 1] - stops[index];
    final double segmentProgress = (percentage - stops[index]) / segmentLength;
    
    // Interpolate the color
    return Color.lerp(colors[index], colors[index + 1], segmentProgress) ?? colors[index];
  }
  
  // Build tank visualization column
  Widget _buildTankVisualizationColumn({
    required String title,
    required double? percentage,
    required String? liters,
    required Color color,
  }) {
    final levelColor = percentage != null ? _getLevelColor(percentage) : Colors.grey.shade300;
    
    return Container(
      width: 80,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: percentage != null ? color : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 12),
          
          // Tank visualization
          percentage != null
            ? _buildModernFuelTankVisual(percentage, color)
            : _buildEmptyFuelTankVisual(),
            
          const SizedBox(height: 8),
          
          // Level percentage
          Text(
            percentage != null ? '${percentage.toStringAsFixed(1)}%' : '---%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: percentage != null ? levelColor : Colors.grey.shade400,
            ),
          ),
          
          // Liters
          Text(
            liters != null ? '$liters L' : '--- L',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
  
  // Build modern fuel tank visualization
  Widget _buildModernFuelTankVisual(double percentage, Color color) {
    final levelColor = _getLevelColor(percentage);
    return Container(
      width: 50,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.1),
            blurRadius: 2,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Empty space
          Expanded(
            flex: (100 - percentage).round(),
            child: Container(
              width: double.infinity,
              color: Colors.transparent,
            ),
          ),
          // Filled space
          Expanded(
            flex: percentage.round() == 0 ? 1 : percentage.round(),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: levelColor,
                borderRadius: BorderRadius.vertical(
                  bottom: const Radius.circular(10),
                  top: percentage >= 99
                      ? const Radius.circular(10)
                      : Radius.zero,
                ),
                boxShadow: [
                  BoxShadow(
                    color: levelColor.withValues(alpha:0.3),
                    blurRadius: 4,
                    spreadRadius: 0,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Empty tank visual
  Widget _buildEmptyFuelTankVisual() {
    return Container(
      width: 50,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_gas_station,
              color: Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              'Select\nTank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build capacity gauge for the selected tank
  Widget _buildCapacityGauge(Color fuelColor) {
    if (_selectedFuelTank == null) {
      return Container(); // Return empty container if no tank is selected
    }
    
    final double capacityPercentage = _selectedFuelTank!.stockPercentage;
    final double quantityToAdd = double.tryParse(_quantityController.text) ?? 0;
    final double newFillPercentage = (((_selectedFuelTank!.currentStock + quantityToAdd) / _selectedFuelTank!.capacityInLiters) * 100).clamp(0, 100);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tank Capacity',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            Text(
              '${_selectedFuelTank!.capacityInLiters.toStringAsFixed(0)} L',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Gauge container
        Container(
          height: 24,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Current stock
              FractionallySizedBox(
                widthFactor: capacityPercentage / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: _getLevelColor(capacityPercentage),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              // New stock preview (if amount entered)
              if (quantityToAdd > 0)
                Positioned(
                  left: (capacityPercentage / 100 * MediaQuery.of(context).size.width - 40),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: (newFillPercentage - capacityPercentage) / 100 * MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      color: Colors.green.shade400.withValues(alpha:0.6),
                      backgroundBlendMode: BlendMode.lighten,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                    ),
                    child: ClipRRect(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              Colors.green.shade400,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
              // Divider lines for better visual progression
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) {
                  return Container(
                    width: 1,
                    height: 24,
                    color: Colors.white.withValues(alpha:0.5),
                  );
                }),
              ),
            ],
          ),
        ),
        
        // Legend
        Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Row(
            children: [
              _buildCapacityLegendItem(
                'Current',
                '${_selectedFuelTank!.currentStock.toStringAsFixed(0)} L',
                _getLevelColor(capacityPercentage),
              ),
              const SizedBox(width: 16),
              if (quantityToAdd > 0)
                _buildCapacityLegendItem(
                  'To Add',
                  '+${quantityToAdd.toStringAsFixed(0)} L',
                  Colors.green.shade400,
                ),
              const Spacer(),
              _buildCapacityLegendItem(
                'Remaining',
                '${_selectedFuelTank!.remainingCapacity.toStringAsFixed(0)} L',
                Colors.grey.shade300,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Build capacity legend item
  Widget _buildCapacityLegendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Build delivery detail row
  Widget _buildDeliveryDetailRow(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 14,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
  
  // Update the preview when quantity changes
  void _updatePreview(String value) {
    if (_selectedFuelTank == null) return;
    
    setState(() {
      // Quantity value updated - UI will refresh
    });
  }
  
  // Enable updates to text field formatters
  TextFormField _buildQuantityField() {
    return TextFormField(
      controller: _quantityController,
      decoration: InputDecoration(
        labelText: 'Quantity Received',
        hintText: 'Enter quantity in liters',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        prefixIcon: Icon(Icons.local_gas_station, 
          color: _selectedFuelTank != null 
            ? _getFuelColor(_selectedFuelTank!.fuelType) 
            : AppTheme.primaryBlue),
        suffixText: 'L',
        suffixStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: _selectedFuelTank != null 
            ? _getFuelColor(_selectedFuelTank!.fuelType) 
            : AppTheme.primaryBlue,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        floatingLabelBehavior: FloatingLabelBehavior.never,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter quantity';
        }
        
        final amount = double.tryParse(value);
        if (amount == null) {
          return 'Please enter a valid number';
        }
        
        if (amount <= 0) {
          return 'Quantity must be greater than zero';
        }
        
        if (_selectedFuelTank != null && amount > _selectedFuelTank!.remainingCapacity) {
          return 'Amount exceeds remaining capacity (${_selectedFuelTank!.remainingCapacity.toStringAsFixed(0)} L)';
        }
        
        return null;
      },
      onChanged: _updatePreview,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Get fuel color if a tank is selected
    final Color fuelColor = _selectedFuelTank != null 
        ? _getFuelColor(_selectedFuelTank!.fuelType)
        : AppTheme.primaryBlue;
        
    // Calculate preview values for visualization
    final double quantityToAdd = double.tryParse(_quantityController.text) ?? 0;
    final double currentStock = _selectedFuelTank?.currentStock ?? 0;
    final double newStockLevel = currentStock + quantityToAdd;
    final double currentPercentage = _selectedFuelTank?.stockPercentage ?? 0;
    final double capacityInLiters = _selectedFuelTank?.capacityInLiters ?? 0;
    final double newPercentage = capacityInLiters > 0 
        ? ((newStockLevel / capacityInLiters) * 100).clamp(0, 100)
        : 0;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        // Remove app bar completely
        appBar: null,
        // Prevent resizing when keyboard appears
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: _isInitializing
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  // Main content
                  Column(
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
                            // Delivery info
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Add Fuel Delivery',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Record new delivery details',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Expanded content area
                      Expanded(
                        child: Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Error message
                                if (_errorMessage.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
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
                                
                                // Tank visualization section
                                if (_selectedFuelTank != null)
                                  Column(
                                    children: [
                                      // Tanks visualization row
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Current tank visualization
                                            _buildTankVisualizationColumn(
                                              title: 'Current',
                                              percentage: currentPercentage,
                                              liters: currentStock.toStringAsFixed(0),
                                              color: fuelColor,
                                            ),
                                            
                                            // Arrow with amount
                                            if (quantityToAdd > 0)
                                              Column(
                                                children: [
                                                  const SizedBox(height: 40),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(20),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha:0.06),
                                                          blurRadius: 10,
                                                          spreadRadius: 0,
                                                          offset: const Offset(0, 4),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.arrow_forward,
                                                          color: _quantityController.text.isNotEmpty ? fuelColor : Colors.grey.shade400,
                                                          size: 18,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          '+${quantityToAdd.toStringAsFixed(0)}L',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.black87,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              )
                                            else
                                              const SizedBox(width: 80),
                                            
                                            // After delivery visualization
                                            _buildTankVisualizationColumn(
                                              title: 'After Delivery',
                                              percentage: quantityToAdd > 0 ? newPercentage : currentPercentage,
                                              liters: quantityToAdd > 0 ? newStockLevel.toStringAsFixed(0) : currentStock.toStringAsFixed(0),
                                              color: Colors.green.shade600,
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Capacity gauge
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 16.0),
                                        child: _buildCapacityGauge(fuelColor),
                                      ),
                                      
                                      const Divider(height: 32),
                                    ],
                                  ),
                                
                                // Basic Information
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
                                          'Delivery Information',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 16),
                                        
                                        // Date selector
                                        Text(
                                          'Delivery Date',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () => _selectDate(context),
                                          child: InputDecorator(
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide.none,
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey.shade100,
                                              prefixIcon: Icon(Icons.calendar_today, color: fuelColor, size: 20),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                            ),
                                            child: Text(
                                              DateFormat('yyyy-MM-dd').format(_deliveryDate),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        
                                        // Time selector
                                        Text(
                                          'Delivery Time',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () => _selectTime(context),
                                          child: InputDecorator(
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide.none,
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey.shade100,
                                              prefixIcon: Icon(Icons.access_time, color: fuelColor, size: 20),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                            ),
                                            child: Text(
                                              DateFormat('HH:mm').format(_deliveryDate),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 16),
                                        
                                        // Invoice Number
                                        Text(
                                          'Invoice Number',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _invoiceNumberController,
                                          decoration: InputDecoration(
                                            hintText: 'Enter invoice number',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade100,
                                            prefixIcon: Icon(Icons.receipt, color: fuelColor),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.trim().isEmpty) {
                                              return 'Please enter invoice number';
                                            }
                                            return null;
                                          },
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Source Information
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
                                          'Source Information',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 16),
                                        
                                        // Supplier Dropdown
                                        Text(
                                          'Supplier',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<Supplier>(
                                          decoration: InputDecoration(
                                            hintText: 'Select supplier',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade100,
                                            prefixIcon: Icon(Icons.business, color: fuelColor, size: 20),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                          ),
                                          value: _selectedSupplier,
                                          hint: const Text('Select Supplier'),
                                          items: _suppliers.map((supplier) {
                                            return DropdownMenuItem<Supplier>(
                                              value: supplier,
                                              child: Text(
                                                supplier.supplierName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (Supplier? newValue) {
                                            setState(() {
                                              _selectedSupplier = newValue;
                                            });
                                          },
                                          isExpanded: true,
                                        ),
                                        
                                        const SizedBox(height: 16),
                                        
                                        // Fuel Tank Dropdown
                                        Text(
                                          'Fuel Tank',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<FuelTank>(
                                          decoration: InputDecoration(
                                            hintText: 'Select fuel tank',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade100,
                                            prefixIcon: Icon(Icons.storage, color: fuelColor, size: 20),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                          ),
                                          value: _selectedFuelTank,
                                          hint: const Text('Select Fuel Tank'),
                                          items: _fuelTanks.map((tank) {
                                            return DropdownMenuItem<FuelTank>(
                                              value: tank,
                                              child: Text(
                                                '${tank.fuelType} - ${tank.stockPercentage.toStringAsFixed(1)}% full',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (FuelTank? newValue) {
                                            setState(() {
                                              _selectedFuelTank = newValue;
                                              _quantityController.clear();
                                            });
                                          },
                                          isExpanded: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Quantity Information
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
                                          'Delivery Quantity',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 16),
                                        
                                        // Quantity
                                        Text(
                                          'Quantity to Add',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildQuantityField(),
                                        
                                        const SizedBox(height: 16),
                                        
                                        // Density
                                        Text(
                                          'Density',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _densityController,
                                          decoration: InputDecoration(
                                            hintText: 'Enter density value',
                                            suffixText: 'g/cm³',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade100,
                                            prefixIcon: Icon(Icons.science, color: fuelColor),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                          ),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          validator: (value) {
                                            if (value == null || value.trim().isEmpty) {
                                              return 'Please enter density';
                                            }
                                            final number = double.tryParse(value);
                                            if (number == null || number <= 0) {
                                              return 'Please enter a valid density';
                                            }
                                            return null;
                                          },
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4, left: 4),
                                          child: Text(
                                            'Standard density measurement at ambient temperature',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 16),
                                        
                                        // Temperature
                                        Text(
                                          'Temperature',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _temperatureController,
                                          decoration: InputDecoration(
                                            hintText: 'Enter temperature',
                                            suffixText: '°C',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade100,
                                            prefixIcon: Icon(Icons.thermostat, color: fuelColor),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                          ),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          validator: (value) {
                                            if (value == null || value.trim().isEmpty) {
                                              return 'Please enter temperature';
                                            }
                                            final number = double.tryParse(value);
                                            if (number == null) {
                                              return 'Please enter a valid temperature';
                                            }
                                            return null;
                                          },
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'^-?\d+\.?\d{0,1}')),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 20),

                                // Additional Information
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
                                          'Additional Information',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 16),
                                        
                                        TextFormField(
                                          controller: _notesController,
                                          maxLines: 3,
                                          decoration: InputDecoration(
                                            hintText: 'Add any additional notes',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade100,
                                            prefixIcon: Icon(Icons.note, color: fuelColor),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                            alignLabelWithHint: true,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4, left: 4),
                                          child: Text(
                                            'Include any special comments about this delivery',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                // If quantity is entered, show delivery summary
                                if (_quantityController.text.isNotEmpty && double.tryParse(_quantityController.text) != null && _selectedFuelTank != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 20),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Delivery Summary',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: fuelColor,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildDeliveryDetailRow(
                                        'Amount to add',
                                        '${quantityToAdd.toStringAsFixed(0)} L',
                                        Icons.add_circle_outline,
                                        Colors.blue.shade700,
                                      ),
                                      const Divider(height: 16),
                                      _buildDeliveryDetailRow(
                                        'New stock level',
                                        '${newStockLevel.toStringAsFixed(0)} L',
                                        Icons.water_drop_outlined,
                                        Colors.green.shade700,
                                      ),
                                      const Divider(height: 16),
                                      _buildDeliveryDetailRow(
                                        'Remaining capacity',
                                        '${(_selectedFuelTank!.capacityInLiters - newStockLevel).toStringAsFixed(0)} L',
                                        Icons.space_bar,
                                        Colors.amber.shade700,
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 32),
                                
                                // Submit Button
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _submitForm,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: fuelColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.local_gas_station_rounded, size: 20),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Record Delivery',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                
                                // Extra space at bottom for better scrolling
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        ),
      ),
    );
  }
} 