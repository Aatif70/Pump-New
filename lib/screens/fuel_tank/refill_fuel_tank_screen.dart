import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/fuel_tank_repository.dart';
import '../../models/fuel_tank_model.dart';
import '../../theme.dart';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:intl/intl.dart';

class RefillFuelTankScreen extends StatefulWidget {
  final FuelTank fuelTank;
  
  const RefillFuelTankScreen({
    Key? key,
    required this.fuelTank,
  }) : super(key: key);

  @override
  State<RefillFuelTankScreen> createState() => _RefillFuelTankScreenState();
}

class _RefillFuelTankScreenState extends State<RefillFuelTankScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';
  double _remainingCapacity = 0;
  double _newStockLevel = 0;
  double _newPercentage = 0;
  
  // Animation controllers and values
  late AnimationController _animationController;
  late Animation<double> _fillAnimation;
  double _startPercentage = 0;
  double _targetPercentage = 0;
  bool _isAnimating = false;
  double _lastAnimatedValue = 0; // Track the last animated value
  
  @override
  void initState() {
    super.initState();
    _calculateRemainingCapacity();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _startPercentage = widget.fuelTank.stockPercentage;
    
    // Initialize animation
    _fillAnimation = Tween<double>(
      begin: _startPercentage,
      end: _startPercentage, // Will be updated when refilling
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Add listener to rebuild during animation
    _animationController.addListener(() {
      setState(() {}); // Trigger rebuild on animation tick
    });
  }
  
  void _calculateRemainingCapacity() {
    _remainingCapacity = widget.fuelTank.remainingCapacity;
  }
  
  void _updatePreview(String value) {
    final amount = double.tryParse(value) ?? 0;
    setState(() {
      _newStockLevel = widget.fuelTank.currentStock + amount;
      _newPercentage = (_newStockLevel / widget.fuelTank.capacityInLiters) * 100;
      if (_newPercentage > 100) _newPercentage = 100;
      
      // Update animation target
      _targetPercentage = _newPercentage;
      _fillAnimation = Tween<double>(
        begin: _startPercentage,
        end: _targetPercentage,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ));
    });
  }
  
  @override
  void dispose() {
    _amountController.dispose();
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
    
    // Listen to animation updates to track the current value
    _animationController.addListener(() {
      _lastAnimatedValue = _fillAnimation.value;
    });
    
    // Start animation
    _animationController.forward().then((_) {
      setState(() {
        _isAnimating = false;
        // Keep _lastAnimatedValue at its final value
      });
    });
  }
  
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Start fill animation
    _startFillAnimation();
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final repository = FuelTankRepository();
      final amount = double.parse(_amountController.text);
      
      developer.log('Refilling fuel tank: ${widget.fuelTank.fuelTankId} with amount: $amount liters');
      
      // Wait for animation to complete
      await Future.delayed(const Duration(milliseconds: 1600));
      
      // Call repository to refill fuel tank
      final response = await repository.refillFuelTank(
        widget.fuelTank.fuelTankId!,
        amount,
      );
      
      if (!mounted) return;
      
      if (response.success) {
        developer.log('Fuel tank refilled successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fuel tank refilled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reset tracked value before leaving
        _lastAnimatedValue = 0;
        
        // Wait a bit before leaving to see the final state
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        developer.log('Failed to refill fuel tank: ${response.errorMessage}');
        setState(() {
          _errorMessage = response.errorMessage ?? 'Failed to refill fuel tank';
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
      developer.log('Error refilling tank: $e');
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
    final Color fuelColor = _getFuelColor(widget.fuelTank.fuelType);
    
    // Calculate what value to display based on animation state
    final displayPercentage = _isAnimating ? _fillAnimation.value : _lastAnimatedValue > 0 ? _lastAnimatedValue : widget.fuelTank.stockPercentage;
    final displayStock = _isAnimating || _lastAnimatedValue > 0 
      ? (widget.fuelTank.currentStock + (displayPercentage - _startPercentage) * widget.fuelTank.capacityInLiters / 100)
      : widget.fuelTank.currentStock;
    
    return GestureDetector(
      // Dismiss keyboard when tapping outside
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        // Remove app bar completely
        appBar: null,
        // Prevent resizing when keyboard appears
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Stack(
            children: [
              // Main content
              Column(
                children: [
                  // Custom header with close button
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
                        // Tank info
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.fuelTank.fuelType} Tank Refill',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Capacity: ${widget.fuelTank.capacityInLiters.toStringAsFixed(0)} L',
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
                  
                  // Expanded content area with scrolling
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // Tank visualization section - fixed at the top
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tanks visualization row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Current tank visualization
                                    _buildTankComparisonColumn(
                                      title: 'Current',
                                      percentage: displayPercentage,
                                      liters: displayStock.toStringAsFixed(0),
                                      color: fuelColor,
                                      isAnimating: _isAnimating,
                                    ),
                                    
                                    // Arrow with amount
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
                                                color: _amountController.text.isNotEmpty ? fuelColor : Colors.grey.shade400,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _amountController.text.isNotEmpty && double.tryParse(_amountController.text) != null
                                                  ? '+${double.parse(_amountController.text).toStringAsFixed(0)}L'
                                                  : '+0L',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: _amountController.text.isNotEmpty ? Colors.black87 : Colors.grey.shade400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // After refill visualization
                                    _buildTankComparisonColumn(
                                      title: 'After Refill',
                                      percentage: _amountController.text.isNotEmpty && double.tryParse(_amountController.text) != null
                                        ? _newPercentage
                                        : null,
                                      liters: _amountController.text.isNotEmpty && double.tryParse(_amountController.text) != null
                                        ? _newStockLevel.toStringAsFixed(0)
                                        : null,
                                      color: Colors.green.shade600,
                                      isAnimating: false,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Capacity gauge section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: _buildCapacityGauge(fuelColor),
                          ),

                          const SizedBox(height: 16),
                          
                          // Refill form section 
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha:0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.fromLTRB(
                              20, 
                              32,
                              20, 
                              24 + MediaQuery.of(context).viewInsets.bottom * 0.2, // Add padding when keyboard is open
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Amount input section
                                  Text(
                                    'How much fuel do you want to add?',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  // Amount input field
                                  TextFormField(
                                    controller: _amountController,
                                    decoration: InputDecoration(
                                      labelText: 'Amount to Add',
                                      hintText: 'Enter amount in liters',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                      prefixIcon: Icon(Icons.add_circle_outline, color: fuelColor),
                                      suffixText: 'L',
                                      suffixStyle: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: fuelColor,
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
                                        return 'Please enter an amount';
                                      }
                                      
                                      final amount = double.tryParse(value);
                                      if (amount == null) {
                                        return 'Please enter a valid number';
                                      }
                                      
                                      if (amount <= 0) {
                                        return 'Amount must be greater than zero';
                                      }
                                      
                                      if (amount > _remainingCapacity) {
                                        return 'Amount exceeds remaining capacity (${_remainingCapacity.toStringAsFixed(0)} L)';
                                      }
                                      
                                      return null;
                                    },
                                    onChanged: _updatePreview,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),



                                  if (_amountController.text.isNotEmpty && double.tryParse(_amountController.text) != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 20),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildRefillDetailRow(
                                          'Amount to add',
                                          '${double.parse(_amountController.text).toStringAsFixed(0)} L',
                                          Icons.add_circle_outline,
                                          Colors.blue.shade700,
                                        ),
                                        const Divider(height: 16),
                                        _buildRefillDetailRow(
                                          'New stock level',
                                          '${_newStockLevel.toStringAsFixed(0)} L',
                                          Icons.water_drop_outlined,
                                          Colors.green.shade700,
                                        ),
                                        const Divider(height: 16),
                                        _buildRefillDetailRow(
                                          'Remaining capacity',
                                          '${(widget.fuelTank.capacityInLiters - _newStockLevel).toStringAsFixed(0)} L',
                                          Icons.space_bar,
                                          Colors.amber.shade700,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 32),
                                  
                                  // Error message
                                  if (_errorMessage.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _errorMessage,
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  
                                  // Confirm button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: (_isLoading || _isAnimating) ? null : _submitForm,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: fuelColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.local_gas_station_rounded,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                const Text(
                                                  'Complete Refill',
                                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  
                                  // Extra space to ensure scrollability
                                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 300 : 20),
                                ],
                              ),
                            ),
                          ),
                        ],
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
  
  // Build tank comparison column
  Widget _buildTankComparisonColumn({
    required String title,
    required double? percentage,
    required String? liters,
    required Color color,
    required bool isAnimating,
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
            ? _buildModernFuelTankVisual(percentage, color, isAnimating: isAnimating)
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
  
  // Build improved capacity gauge
  Widget _buildCapacityGauge(Color fuelColor) {
    final double capacityPercentage = (widget.fuelTank.currentStock / widget.fuelTank.capacityInLiters) * 100;
    final double fillAmount = double.tryParse(_amountController.text) ?? 0;
    final double newStockPercentage = fillAmount > 0 
        ? ((widget.fuelTank.currentStock + fillAmount) / widget.fuelTank.capacityInLiters * 100).clamp(0, 100)
        : capacityPercentage;
    
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
              '${widget.fuelTank.capacityInLiters.toStringAsFixed(0)} L',
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
              if (fillAmount > 0)
                Positioned(
                  left: (capacityPercentage / 100 * MediaQuery.of(context).size.width - 40),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: (newStockPercentage - capacityPercentage) / 100 * MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      color: Colors.green.shade400.withValues(alpha:0.6),
                      backgroundBlendMode: BlendMode.lighten,
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
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
                '${widget.fuelTank.currentStock.toStringAsFixed(0)} L',
                _getLevelColor(capacityPercentage),
              ),
              const SizedBox(width: 16),
              if (fillAmount > 0)
                _buildCapacityLegendItem(
                  'To Add',
                  '+${fillAmount.toStringAsFixed(0)} L',
                  Colors.green.shade400,
                ),
              const Spacer(),
              _buildCapacityLegendItem(
                'Remaining',
                '${(widget.fuelTank.capacityInLiters - widget.fuelTank.currentStock).toStringAsFixed(0)} L',
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
  
  // Build refill detail row
  Widget _buildRefillDetailRow(String label, String value, IconData icon, Color color) {
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
  
  // Build modern fuel tank visualization
  Widget _buildModernFuelTankVisual(double percentage, Color color, {bool isAnimating = false}) {
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
            child: Stack(
              children: [
                Container(
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
                if (isAnimating)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            levelColor.withValues(alpha:0.5),
                            levelColor,
                          ],
                        ),
                      ),
                      child: CustomPaint(
                        painter: WavePainter(
                          animationValue: _animationController.value,
                          color: Colors.white.withValues(alpha:0.2),
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
              Icons.add_circle_outline,
              color: Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter\nAmount',
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

// Wave animation painter
class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;
  
  WavePainter({required this.animationValue, required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    final width = size.width;
    final height = size.height;
    
    path.moveTo(0, height * 0.5);
    
    // Create a wavy pattern
    for (int i = 0; i < width; i++) {
      final x = i.toDouble();
      final sinValue = height * 0.06 * 
        (
          math.sin((x / width * 4 * 3.14159) + (animationValue * 2 * 3.14159)) + 
          math.sin((x / width * 6 * 3.14159) + (animationValue * 4 * 3.14159)) * 0.5
        );
      final y = height * 0.5 + sinValue;
      
      path.lineTo(x, y);
    }
    
    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 