import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/fuel_tank_repository.dart';
import '../../models/fuel_tank_model.dart';
import '../../theme.dart';
import 'dart:developer' as developer;

class EditFuelTankScreen extends StatefulWidget {
  final FuelTank fuelTank;
  
  const EditFuelTankScreen({
    Key? key,
    required this.fuelTank,
  }) : super(key: key);

  @override
  State<EditFuelTankScreen> createState() => _EditFuelTankScreenState();
}

class _EditFuelTankScreenState extends State<EditFuelTankScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  late final TextEditingController _capacityController;
  late final TextEditingController _fuelTypeController;
  late final TextEditingController _currentStockController;
  late String _selectedStatus;
  
  bool _isLoading = false;
  String _errorMessage = '';

  // Animation controllers and values
  late AnimationController _animationController;
  late Animation<double> _fillAnimation;
  double _startPercentage = 0;
  double _targetPercentage = 0;
  bool _isAnimating = false;
  double _lastAnimatedValue = 0; // Track the last animated value
  
  // Preview values
  double _previewStockPercentage = 0;
  double _previewCurrentStock = 0;
  
  // Fuel type options
  final List<String> _fuelTypes = [
    'Petrol',
    'Diesel',
    'Premium Petrol',
    'Premium Diesel',
    'CNG',
    'LPG'
  ];
  
  // Status options
  final List<String> _statusOptions = [
    'Active',
    'Inactive',
    'Maintenance'
  ];
  
  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with existing tank data
    _capacityController = TextEditingController(text: widget.fuelTank.capacityInLiters.toString());
    _fuelTypeController = TextEditingController(text: widget.fuelTank.fuelType);
    _currentStockController = TextEditingController(text: widget.fuelTank.currentStock.toString());
    _selectedStatus = widget.fuelTank.status;
    
    // Initial preview values
    _previewStockPercentage = widget.fuelTank.stockPercentage;
    _previewCurrentStock = widget.fuelTank.currentStock;
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _startPercentage = widget.fuelTank.stockPercentage;
    
    // Initialize animation
    _fillAnimation = Tween<double>(
      begin: _startPercentage,
      end: _startPercentage, // Will be updated when editing
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Add listener to rebuild during animation
    _animationController.addListener(() {
      setState(() {
        _lastAnimatedValue = _fillAnimation.value;
      }); // Trigger rebuild on animation tick
    });
    
    // Listen for field changes to update preview
    _capacityController.addListener(_updatePreview);
    _currentStockController.addListener(_updatePreview);
  }
  
  void _updatePreview() {
    if (_capacityController.text.isEmpty || _currentStockController.text.isEmpty) {
      return;
    }

    final capacity = double.tryParse(_capacityController.text) ?? widget.fuelTank.capacityInLiters;
    final currentStock = double.tryParse(_currentStockController.text) ?? widget.fuelTank.currentStock;

    if (capacity <= 0) return;

    setState(() {
      _previewCurrentStock = currentStock;
      _previewStockPercentage = (currentStock / capacity) * 100;
      if (_previewStockPercentage > 100) _previewStockPercentage = 100;
      
      // Update animation target
      _targetPercentage = _previewStockPercentage;
    });
  }
  
  @override
  void dispose() {
    _capacityController.removeListener(_updatePreview);
    _currentStockController.removeListener(_updatePreview);
    _capacityController.dispose();
    _fuelTypeController.dispose();
    _currentStockController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  void _startFillAnimation() {
    setState(() {
      _isAnimating = true;
      _lastAnimatedValue = _startPercentage; // Initialize with start value
    });
    
    // Reset animation controller
    _animationController.reset();
    
    // Set up animation
    _fillAnimation = Tween<double>(
      begin: _startPercentage,
      end: _targetPercentage,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Start animation
    _animationController.forward().then((_) {
      setState(() {
        _isAnimating = false;
        // Keep _lastAnimatedValue at its final value
      });
    });
  }
  
  // Submit the form
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Start animation if values have changed
    if (_previewStockPercentage != _startPercentage) {
      _startFillAnimation();
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final repository = FuelTankRepository();
      
      // Update fuel tank object
      final updatedFuelTank = FuelTank(
        fuelTankId: widget.fuelTank.fuelTankId,
        capacityInLiters: double.parse(_capacityController.text),
        fuelType: _fuelTypeController.text,
        petrolPumpId: widget.fuelTank.petrolPumpId,
        currentStock: double.parse(_currentStockController.text),
        status: _selectedStatus,
        lastRefilledAt: widget.fuelTank.lastRefilledAt,
      );
      
      // Log the request details
      developer.log('Updating fuel tank with ID: ${updatedFuelTank.fuelTankId}');
      developer.log('Request body: ${updatedFuelTank.toJson()}');
      
      // Wait for animation if it's running
      if (_isAnimating) {
        await Future.delayed(const Duration(milliseconds: 1600));
      }
      
      // Call repository to update fuel tank
      final response = await repository.updateFuelTank(updatedFuelTank);
      
      if (!mounted) return;
      
      if (response.success) {
        developer.log('Fuel tank updated successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fuel tank updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reset tracked value before leaving
        _lastAnimatedValue = 0;
        
        // Wait a bit before leaving to see the final state
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        developer.log('Failed to update fuel tank: ${response.errorMessage}');
        setState(() {
          _errorMessage = response.errorMessage ?? 'Failed to update fuel tank';
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      developer.log('Error submitting form: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color fuelColor = _getFuelColor(_fuelTypeController.text);
    
    // Calculate what value to display based on animation state
    final displayPercentage = _isAnimating ? _fillAnimation.value : _lastAnimatedValue > 0 ? _lastAnimatedValue : _previewStockPercentage;
    final displayStock = _isAnimating || _lastAnimatedValue > 0 
      ? (_previewCurrentStock + (displayPercentage - _startPercentage) * widget.fuelTank.capacityInLiters / 100)
      : _previewCurrentStock;
      
    final double remainingCapacity = double.tryParse(_capacityController.text) != null 
        ? double.parse(_capacityController.text) - double.parse(_currentStockController.text)
        : widget.fuelTank.remainingCapacity;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Edit Fuel Tank'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header with tank info
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
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
                  Text(
                    'Edit ${_fuelTypeController.text} Tank',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Tank Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: _previewStockPercentage < 20
                          ? Border.all(color: Colors.amber, width: 1.5)
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Tank visualization with level
                        _buildHeaderFuelTankVisual(
                          displayPercentage,
                          fuelColor,
                        ),
                        const SizedBox(width: 16),
                        // Tank details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeaderStat(
                                'Current Stock',
                                '${displayStock.toStringAsFixed(0)} L',
                                fuelColor,
                              ),
                              const SizedBox(height: 6),
                              _buildHeaderStat(
                                'Level',
                                '${displayPercentage.toStringAsFixed(1)}%',
                                _getLevelColor(displayPercentage),
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
            
            // Form and cards
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tank Details card with improved styling
                      _buildSectionTitle('Tank Details'),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha:0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Fuel Type
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
                                enabled: false,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  prefixIcon: Icon(Icons.local_gas_station, color: fuelColor),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                ),
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
                                readOnly: true,
                                enabled: false,
                                decoration: InputDecoration(
                                  labelText: 'Capacity (Liters)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: fuelColor, width: 2),
                                  ),
                                  prefixIcon: Icon(Icons.straighten, color: fuelColor),
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
                                  if (_currentStockController.text.isNotEmpty && 
                                      double.parse(value) < double.parse(_currentStockController.text)) {
                                    return 'Capacity cannot be less than current stock';
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
                                readOnly: true,
                                enabled: false,
                                decoration: InputDecoration(
                                  labelText: 'Current Stock (Liters)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: fuelColor, width: 2),
                                  ),
                                  prefixIcon: Icon(Icons.opacity, color: fuelColor),
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
                              
                              const SizedBox(height: 16),
                              
                              // Status field
                              Text(
                                'Tank Status',
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
                                    borderSide: BorderSide(color: fuelColor, width: 2),
                                  ),
                                  prefixIcon: Icon(Icons.toggle_on_outlined, color: fuelColor),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                value: _selectedStatus,
                                items: _statusOptions.map((String status) {
                                  Color statusColor;
                                  IconData statusIcon;
                                  if (status == 'Active') {
                                    statusColor = Colors.green;
                                    statusIcon = Icons.check_circle;
                                  } else if (status == 'Maintenance') {
                                    statusColor = Colors.orange;
                                    statusIcon = Icons.build;
                                  } else {
                                    statusColor = Colors.red;
                                    statusIcon = Icons.cancel;
                                  }
                                  
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Row(
                                      children: [
                                        Icon(statusIcon, color: statusColor, size: 16),
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
                              
                              const SizedBox(height: 8),
                              
                              // Capacity indicator
                              _buildCapacityIndicator(
                                currentStock: double.tryParse(_currentStockController.text) ?? widget.fuelTank.currentStock,
                                capacity: double.tryParse(_capacityController.text) ?? widget.fuelTank.capacityInLiters,
                                fuelColor: fuelColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      if (_errorMessage.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 16.0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 24),
                      
                      // Save button
                      ElevatedButton(
                        onPressed: (_isLoading || _isAnimating) ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: fuelColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
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
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.save,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Save Changes',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Header fuel tank visual
  Widget _buildHeaderFuelTankVisual(double percentage, Color color) {
    final emptyPercentage = 100 - percentage;
    final levelColor = _getLevelColor(percentage);
    
    return Container(
      width: 40,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha:0.3), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias, // Ensure contents are clipped to the container's border
      child: Column(
        children: [
          // Empty space
          Expanded(
            flex: emptyPercentage.round(),
            child: Container(
              width: double.infinity,
              color: Colors.transparent,
            ),
          ),
          // Filled space with shimmering effect when animating
          Expanded(
            flex: percentage.round() == 0 ? 1 : percentage.round(),
            child: ClipRect( // Add additional clipping for the filled area
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: levelColor.withValues(alpha:0.8),
                      borderRadius: BorderRadius.vertical(
                        bottom: const Radius.circular(6),
                        top: emptyPercentage <= 0
                            ? const Radius.circular(6)
                            : Radius.zero,
                      ),
                    ),
                  ),
                  // Add shimmering effect when animating
                  if (_isAnimating)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          bottom: const Radius.circular(6),
                          top: emptyPercentage <= 0
                              ? const Radius.circular(6)
                              : Radius.zero,
                        ),
                        child: ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha:0.0),
                                Colors.white.withValues(alpha:0.5),
                                Colors.white.withValues(alpha:0.0),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                              tileMode: TileMode.clamp,
                              transform: GradientRotation(_animationController.value * 2 * 3.14159),
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.srcIn,
                          child: Container(
                            color: Colors.white.withValues(alpha:0.3),
                          ),
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
  
  // Capacity indicator with remaining space
  Widget _buildCapacityIndicator({
    required double currentStock,
    required double capacity,
    required Color fuelColor,
  }) {
    final capacityPercentage = (currentStock / capacity) * 100;
    final remainingPercentage = 100 - capacityPercentage;
    final levelColor = _getLevelColor(capacityPercentage);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tank Capacity Visualization',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${capacity.toStringAsFixed(0)} L',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias, // Add clipping
          child: Row(
            children: [
              // Current stock
              Flexible(
                flex: capacityPercentage.round(),
                child: Container(
                  decoration: BoxDecoration(
                    color: levelColor,
                    borderRadius: BorderRadius.horizontal(
                      left: const Radius.circular(7),
                      right: remainingPercentage < 1 ? const Radius.circular(7) : Radius.zero,
                    ),
                  ),
                ),
              ),
              // Remaining capacity
              Flexible(
                flex: remainingPercentage.round() == 0 ? 1 : remainingPercentage.round(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.horizontal(
                      right: const Radius.circular(7),
                      left: capacityPercentage < 1 ? const Radius.circular(7) : Radius.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: levelColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Current: ${currentStock.toStringAsFixed(0)} L',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Remaining: ${(capacity - currentStock).toStringAsFixed(0)} L',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
  
  // Header stat 
  Widget _buildHeaderStat(String label, String value, Color valueColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: valueColor.withValues(alpha:0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            label.contains('Level') ? Icons.water_drop_outlined : Icons.local_gas_station_outlined,
            color: valueColor,
            size: 12,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha:0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Modern styled section title
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
  
  Color _getFuelColor(String fuelType) {
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
} 