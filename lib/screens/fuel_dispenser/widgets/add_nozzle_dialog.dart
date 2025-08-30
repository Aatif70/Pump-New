import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import '../../../models/fuel_dispenser_model.dart';
import '../../../models/nozzle_model.dart';
import '../../../models/fuel_tank_model.dart';
import '../../../models/employee_model.dart';
import '../../../models/fuel_type_model.dart';
import '../../../api/fuel_tank_repository.dart';
import '../../../theme.dart';
import 'dart:math' as math;

class AddNozzleDialog extends StatefulWidget {
  final String dispenserId;
  final FuelDispenser dispenser;
  final int nozzleNumber;
  final List<FuelTank> fuelTanks;
  final List<Employee> employees;

  const AddNozzleDialog({
    Key? key,
    required this.dispenserId,
    required this.dispenser,
    required this.nozzleNumber,
    required this.fuelTanks,
    required this.employees,
  }) : super(key: key);

  @override
  _AddNozzleDialogState createState() => _AddNozzleDialogState();
  
  // Static method to show the dialog
  static Future<Nozzle?> show({
    required BuildContext context,
    required String dispenserId,
    required FuelDispenser dispenser,
    required int nozzleNumber,
    required List<FuelTank> fuelTanks,
    required List<Employee> employees,
  }) {
    return showDialog<Nozzle>(
      context: context,
      builder: (BuildContext context) {
        return AddNozzleDialog(
          dispenserId: dispenserId,
          dispenser: dispenser,
          nozzleNumber: nozzleNumber,
          fuelTanks: fuelTanks,
          employees: employees,
        );
      },
    );
  }
}

class _AddNozzleDialogState extends State<AddNozzleDialog> with SingleTickerProviderStateMixin {
  final formKey = GlobalKey<FormState>();
  String selectedFuelType = "Petrol"; // Default fuel type
  String selectedStatus = "Inactive"; // Default status
  DateTime? selectedCalibrationDate;
  FuelTank? selectedFuelTank;
  Employee? selectedEmployee;
  int selectedNozzleNumber = 0; // Add missing field
  
  // Fuel type loading state
  bool _isLoadingFuelTypes = true;
  String _errorMessage = '';
  List<FuelType> _fuelTypes = [];
  
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Form controllers - keep this for functionality but hide from UI
  final petrolPumpIdController = TextEditingController();
  
  // Hardcoded fuel type options with colors (used as fallback if API fails)
  final fuelTypeOptions = [
    {'label': 'Petrol', 'value': 'Petrol', 'color': Colors.green.shade700},
    {'label': 'Diesel', 'value': 'Diesel', 'color': Colors.orange.shade800},
    {'label': 'Premium Petrol', 'value': 'Premium Petrol', 'color': Colors.purple.shade700},
    {'label': 'Premium Diesel', 'value': 'Premium Diesel', 'color': Colors.deepPurple.shade800},
    {'label': 'CNG', 'value': 'CNG', 'color': Colors.teal.shade700},
    {'label': 'LPG', 'value': 'LPG', 'color': Colors.indigo.shade700},
  ];
  
  // Status options
  final statusOptions = [
    {'label': 'Active', 'value': 'Active', 'color': Colors.green},
    {'label': 'Inactive', 'value': 'Inactive', 'color': Colors.grey},
    {'label': 'Maintenance', 'value': 'Maintenance', 'color': Colors.orange},
  ];
  
  @override
  void initState() {
    super.initState();
    
    // Initialize nozzle number to the one passed in props
    selectedNozzleNumber = widget.nozzleNumber;
    
    // Pre-fill petrol pump ID if available from dispenser
    if (widget.dispenser.petrolPumpId != null && widget.dispenser.petrolPumpId.isNotEmpty) {
      petrolPumpIdController.text = widget.dispenser.petrolPumpId;
    }
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    // Create animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Start animation
    _animationController.forward();
    
    // Fetch fuel types
    _loadFuelTypes();
    
    // Check if we have any available fuel tanks
    if (widget.fuelTanks.isNotEmpty) {
      // Default to the first fuel tank's fuel type
      selectedFuelType = widget.fuelTanks.first.fuelType ?? "Petrol";
      
      // Auto-select the first fuel tank with this fuel type
      final matchingTanks = widget.fuelTanks
        .where((tank) => tank.fuelType == selectedFuelType)
        .toList();
        
      if (matchingTanks.isNotEmpty) {
        selectedFuelTank = matchingTanks.first;
        print("INIT: Auto-selected fuel tank: ${selectedFuelTank?.fuelTankId}");
      }
    }
  }
  
  // Load fuel types from API
  Future<void> _loadFuelTypes() async {
    setState(() {
      _isLoadingFuelTypes = true;
      _errorMessage = '';
    });
    
    try {
      final repository = FuelTankRepository();
      final response = await repository.getFuelTypes();
      
      if (!mounted) return;
      
      if (response.success && response.data != null) {
        setState(() {
          _fuelTypes = response.data!;
          _isLoadingFuelTypes = false;
        });
        
        developer.log('ADD_NOZZLE: Loaded ${_fuelTypes.length} fuel types');
        
        // If we have fuel types and none selected yet, select the first one
        if (_fuelTypes.isNotEmpty) {
          final firstType = _fuelTypes.first;
          setState(() {
            selectedFuelType = firstType.name;
          });
        }
      } else {
        developer.log('ADD_NOZZLE: Failed to load fuel types: ${response.errorMessage}');
        setState(() {
          _errorMessage = response.errorMessage ?? 'Failed to load fuel types';
          _isLoadingFuelTypes = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      developer.log('ADD_NOZZLE: Exception loading fuel types: $e');
      setState(() {
        _errorMessage = 'Error loading fuel types: $e';
        _isLoadingFuelTypes = false;
      });
    }
  }
  
  // Get color for a fuel type
  Color getFuelTypeColor(String fuelTypeName) {
    // First check in API-loaded fuel types
    final apiType = _fuelTypes.where((type) => type.name == fuelTypeName).toList();
    if (apiType.isNotEmpty && apiType.first.color != null && apiType.first.color!.isNotEmpty) {
      try {
        return _hexToColor(apiType.first.color!);
      } catch (e) {
        // If invalid color format, fall back to hardcoded colors
      }
    }
    
    // Fall back to hardcoded colors
    final hardcodedType = fuelTypeOptions.firstWhere(
      (option) => option['value'] == fuelTypeName,
      orElse: () => {'value': fuelTypeName, 'color': Colors.blue.shade700},
    );
    
    return hardcodedType['color'] as Color;
  }
  
  // Helper to convert hex colors
  Color _hexToColor(String hexString) {
    try {
      hexString = hexString.replaceAll('#', '');
      if (hexString.length == 6) {
        hexString = 'FF$hexString';
      }
      return Color(int.parse('0x$hexString'));
    } catch (e) {
      return Colors.grey;
    }
  }
  
  // Helper method to get fuel type ID by name
  String? getFuelTypeIdByName(String name) {
    try {
      final matchingTypes = _fuelTypes.where((type) => type.name == name).toList();
      if (matchingTypes.isNotEmpty) {
        return matchingTypes.first.fuelTypeId;
      }
    } catch (e) {
      developer.log('ERROR getting fuel type ID: $e');
    }
    return null;
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    petrolPumpIdController.dispose();
    super.dispose();
  }

  // Helper method to build section titles
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }
  
  // Helper to check if selected tank ID exists in current filtered list
  bool isFuelTankInCurrentList(String? tankId) {
    if (tankId == null) return false;
    return widget.fuelTanks
        .where((tank) => tank.fuelType == selectedFuelType)
        .any((tank) => tank.fuelTankId == tankId);
  }

  
  @override
  Widget build(BuildContext context) {
    final dispenserColor = AppTheme.primaryBlue;
    
    // Get color for selected fuel type
    final selectedFuelTypeColor = getFuelTypeColor(selectedFuelType);
        
    // Get color for selected status
    final selectedStatusColor = statusOptions
        .firstWhere((option) => option['value'] == selectedStatus)['color'] as Color;
    
    // Reset selected tank if not in current filtered list
    if (selectedFuelTank != null && 
        selectedFuelTank!.fuelType != selectedFuelType) {
      // If tank type doesn't match current fuel type, reset it
      selectedFuelTank = null;
    }
    
    // Get filtered list of tanks for the current fuel type
    final filteredTanks = widget.fuelTanks
        .where((tank) => tank.fuelType == selectedFuelType)
        .toList();
        
    // Get current selected tank ID
    final currentTankId = selectedFuelTank?.fuelTankId;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 560),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.1),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4)
            )
          ]
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modern header with dispenser info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Nozzle number badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.local_gas_station,
                                    size: 16,
                                    color: AppTheme.primaryBlue,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Nozzle #${widget.nozzleNumber}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                        // Close button
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 22),
                          onPressed: () => Navigator.pop(context),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.dashboard_outlined,
                          size: 14,
                          color: Colors.white.withValues(alpha:0.9),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Dispenser #${widget.dispenser.dispenserNumber}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha:0.9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Configure Nozzle Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Form Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fuel Type field
                        _buildSectionTitle('Fuel Type'),
                        _isLoadingFuelTypes
                        ? InputDecorator(
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              prefixIcon: SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
                                  ),
                                ),
                              ),
                            ),
                            child: Text(
                              'Loading fuel types...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: selectedFuelType,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                                    borderSide: BorderSide(color: selectedFuelTypeColor, width: 1.5),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: selectedFuelTypeColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_drop_down),
                                elevation: 2,
                                isExpanded: true,
                                borderRadius: BorderRadius.circular(8),
                                isDense: true,
                                items: widget.fuelTanks.map((tank) {
                                  final color = getFuelTypeColor(tank.fuelType);
                                  return DropdownMenuItem<String>(
                                    value: tank.fuelType,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            tank.fuelType,
                                            style: const TextStyle(fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      // Store previous value to check if it changed
                                      final previousFuelType = selectedFuelType;
                                      selectedFuelType = value;
                                      
                                      // Reset selected fuel tank if fuel type changed
                                      if (previousFuelType != value) {
                                        selectedFuelTank = null;
                                        
                                        // Try to find a matching tank of the new fuel type
                                        final matchingTanks = widget.fuelTanks
                                            .where((tank) => 
                                              tank.fuelType == value && 
                                              tank.fuelTankId != null)
                                            .toList();
                                            
                                        if (matchingTanks.isNotEmpty) {
                                          // Automatically select the first matching tank
                                          selectedFuelTank = matchingTanks.first;
                                          print('Auto-selected matching tank: ${selectedFuelTank!.fuelTankId}');
                                        }
                                      }
                                    });
                                  }
                                },
                              ),
                              if (_errorMessage.isNotEmpty && _fuelTypes.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Using default values: $_errorMessage',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                        const SizedBox(height: 16),
                        
                        // Status field
                        _buildSectionTitle('Status'),
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                              borderSide: BorderSide(color: selectedStatusColor, width: 1.5),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: selectedStatusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          isExpanded: true,
                          elevation: 2,
                          borderRadius: BorderRadius.circular(8),
                          isDense: true,
                          items: statusOptions.map((option) {
                            return DropdownMenuItem<String>(
                              value: option['value'] as String,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: option['color'] as Color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      option['label'] as String,
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedStatus = value;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 16),
                        
                        // Last Calibration Date
                        _buildSectionTitle('Last Calibration Date'),
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedCalibrationDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 30)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: AppTheme.primaryBlue,
                                      onPrimary: Colors.white,
                                      surface: Colors.white,
                                    ),
                                    dialogBackgroundColor: Colors.white,
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (date != null) {
                              setState(() {
                                selectedCalibrationDate = date;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 20,
                                  color: AppTheme.primaryBlue,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  selectedCalibrationDate != null
                                      ? DateFormat('dd MMM yyyy').format(selectedCalibrationDate!)
                                      : 'Select date',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: selectedCalibrationDate != null
                                        ? Colors.black87
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                        
                        // Fuel Tank field
                        _buildSectionTitle('Fuel Tank (Required)'),
                        if (filteredTanks.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red.shade800,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'No fuel tanks available',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Add a fuel tank with ${selectedFuelType} fuel type before adding a nozzle',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          DropdownButtonFormField<String>(
                            value: currentTankId,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                                borderSide: BorderSide(color: selectedFuelTypeColor, width: 1.5),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: Icon(Icons.water_drop_outlined, color: selectedFuelTypeColor, size: 20),
                              hintText: 'Select a fuel tank (Required)',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                              suffixIcon: currentTankId == null ? Icon(Icons.error_outline, color: Colors.red.shade400, size: 20) : null,
                            ),
                            isExpanded: true,
                            elevation: 2,
                            borderRadius: BorderRadius.circular(8),
                            isDense: true,
                            items: filteredTanks.map((tank) {
                              return DropdownMenuItem<String>(
                                value: tank.fuelTankId,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.water_drop_outlined, 
                                      size: 16, 
                                      color: getFuelTypeColor(tank.fuelType),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Tank ${tank.fuelTankId?.substring(0, math.min(4, tank.fuelTankId?.length ?? 0)) ?? ""} - ${tank.fuelType}',
                                        style: const TextStyle(fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${tank.capacityInLiters.toStringAsFixed(0)} L)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            validator: (value) {
                              print("VALIDATE TANK: $value");
                              if (value == null || value.isEmpty) {
                                return 'Please select a fuel tank';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              print("TANK CHANGED: Selected tank ID: $value");
                              if (value != null) {
                                setState(() {
                                  final selectedTank = filteredTanks.firstWhere(
                                    (tank) => tank.fuelTankId == value,
                                    orElse: () => filteredTanks.first,
                                  );
                                  selectedFuelTank = selectedTank;
                                  
                                  // Also update the fuel type to match the tank
                                  if (selectedTank.fuelType != null && selectedTank.fuelType!.isNotEmpty) {
                                    selectedFuelType = selectedTank.fuelType!;
                                    print("TANK CHANGED: Updated fuel type to: $selectedFuelType");
                                  }
                                });
                              }
                            },
                          ),

                        const SizedBox(height: 16),
                        
                        // Assigned Employee section
                        _buildSectionTitle('Assigned Employee (Optional)'),
                        DropdownButtonFormField<String?>(
                          value: selectedEmployee?.id,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                              borderSide: BorderSide(color: AppTheme.primaryBlue, width: 1.5),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: AppTheme.primaryBlue,
                              size: 20,
                            ),
                            hintText: 'Select Employee (Optional)',
                          ),
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(8),
                          elevation: 2,
                          isDense: true,
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person_off_outlined,
                                      size: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'No employee assigned',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...widget.employees
                              .where((employee) => employee.id != null && employee.isActive) // Only active employees with valid IDs
                              .map((employee) {
                                return DropdownMenuItem<String?>(
                                  value: employee.id,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryBlue.withValues(alpha:0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${employee.firstName[0]}${employee.lastName.isNotEmpty ? employee.lastName[0] : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryBlue,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${employee.firstName} ${employee.lastName}',
                                              style: const TextStyle(fontSize: 14),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (employee.role != null && employee.role!.isNotEmpty)
                                              Text(
                                                employee.role!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                          ],
                          onChanged: (String? newValue) {
                            setState(() {
                              if (newValue == null) {
                                selectedEmployee = null;
                              } else {
                                try {
                                  // Find the matching employee by ID
                                  final matchingEmployees = widget.employees.where(
                                    (employee) => employee.id == newValue
                                  ).toList();
                                  
                                  if (matchingEmployees.isNotEmpty) {
                                    selectedEmployee = matchingEmployees.first;
                                  } else {
                                    selectedEmployee = null;
                                  }
                                } catch (e) {
                                  selectedEmployee = null;
                                }
                              }
                            });
                          },
                        ),

                        // Nozzle Number Selection
                        _buildSectionTitle('Nozzle Number'),
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.local_gas_station,
                                  color: AppTheme.primaryBlue,
                                  size: 20,
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: List.generate(8, (index) {
                                    final nozzleNumber = index + 1;
                                    // Check if this number is already taken - always false in the add scenario
                                    // since we're given an available nozzle number
                                    final isUsed = nozzleNumber != widget.nozzleNumber;
                                    final isSelected = selectedNozzleNumber == nozzleNumber;

                                    return GestureDetector(
                                      onTap: isUsed
                                          ? null
                                          : () {
                                              setState(() {
                                                selectedNozzleNumber = nozzleNumber;
                                              });
                                            },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppTheme.primaryBlue
                                              : isUsed
                                                  ? Colors.grey.shade200
                                                  : Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(15),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppTheme.primaryBlue
                                                : isUsed
                                                    ? Colors.grey.shade300
                                                    : Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$nozzleNumber',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected
                                                ? Colors.white
                                                : isUsed
                                                    ? Colors.grey.shade500
                                                    : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
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
              
              // Action buttons
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha:0.05),
                      blurRadius: 3,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: _createNozzle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Add Nozzle',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
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
    );
  }

  void _createNozzle() {
    print("CREATE_NOZZLE: Starting nozzle creation process");
    
    // Print the current state of critical fields
    print("CREATE_NOZZLE: Current state of fields:");
    print("  - Selected Fuel Type: $selectedFuelType");
    print("  - Selected Fuel Tank: ${selectedFuelTank?.fuelTankId}");
    print("  - Selected Nozzle Number: $selectedNozzleNumber");
    print("  - Selected Status: $selectedStatus");
    
    // Do validation before calling validate() to identify specific issues
    if (selectedFuelTank == null) {
      print("CREATE_NOZZLE: Validation would fail - No fuel tank selected");
    }
    
    print("CREATE_NOZZLE: Calling form validation...");
    print("CREATE_NOZZLE: Form validation state: ${formKey.currentState?.validate()}");
    
    if (formKey.currentState!.validate()) {
      // Double-check that a fuel tank is selected
      if (selectedFuelTank == null) {
        print("CREATE_NOZZLE: Error - No fuel tank selected");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error: A fuel tank must be selected'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        return;
      }

      final sanitizedDispenserId = widget.dispenserId.trim();
      print("CREATE_NOZZLE: Dispenser ID: $sanitizedDispenserId");
      
      // Get the fuel type ID if available
      final fuelTypeId = getFuelTypeIdByName(selectedFuelType);
      print("CREATE_NOZZLE: Fuel Type: $selectedFuelType, FuelTypeId: $fuelTypeId");
      print("CREATE_NOZZLE: Selected Fuel Tank ID: ${selectedFuelTank?.fuelTankId}");
      print("CREATE_NOZZLE: Selected Status: $selectedStatus");
      print("CREATE_NOZZLE: Selected Nozzle Number: $selectedNozzleNumber");
      print("CREATE_NOZZLE: Last Calibration Date: $selectedCalibrationDate");
      
      final newNozzle = Nozzle(
        fuelDispenserUnitId: sanitizedDispenserId,
        fuelType: selectedFuelType,
        fuelTypeId: fuelTypeId,
        nozzleNumber: selectedNozzleNumber,
        status: selectedStatus,
        lastCalibrationDate: selectedCalibrationDate,
        fuelTankId: selectedFuelTank?.fuelTankId,
        petrolPumpId: petrolPumpIdController.text.isEmpty ? null : petrolPumpIdController.text,
        assignedEmployee: selectedEmployee?.id,
      );
      
      print("CREATE_NOZZLE: Created nozzle object: ${newNozzle.toJson()}");
      print("CREATE_NOZZLE: Returning nozzle to caller");
      
      Navigator.pop(context, newNozzle);
    } else {
      print("CREATE_NOZZLE: Form validation failed");
      
      // Show a more descriptive error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete all required fields before creating the nozzle'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
} 