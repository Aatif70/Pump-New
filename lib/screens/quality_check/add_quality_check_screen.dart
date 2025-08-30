import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/fuel_tank_repository.dart';
import '../../api/quality_check_repository.dart';
import '../../models/fuel_tank_model.dart';
import '../../models/quality_check_model.dart';
import '../../theme.dart';
import '../../utils/shared_prefs.dart';
import '../../api/api_constants.dart';

class AddQualityCheckScreen extends StatefulWidget {
  const AddQualityCheckScreen({Key? key}) : super(key: key);

  @override
  State<AddQualityCheckScreen> createState() => _AddQualityCheckScreenState();
}

class _AddQualityCheckScreenState extends State<AddQualityCheckScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final FuelTankRepository _fuelTankRepository = FuelTankRepository();
  final QualityCheckRepository _qualityCheckRepository = QualityCheckRepository();
  
  // Form fields
  String? _selectedFuelTankId;
  String? _selectedFuelType;
  final TextEditingController _densityController = TextEditingController(text: '');
  final TextEditingController _temperatureController = TextEditingController(text: '');
  final TextEditingController _waterContentController = TextEditingController(text: '');
  final TextEditingController _depthController = TextEditingController(text: '');
  String _qualityStatus = 'Average'; // Default value
  String _status = 'Start'; // Default status value
  
  // Status options
  final List<String> _statusOptions = ['Start', 'End'];
  
  // State variables
  List<FuelTank> _fuelTanks = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';
  
  // Quality status options
  final List<String> _qualityStatusOptions = [
    'Excellent', 'Good', 'Average', 'Warning', 'Poor', 'Critical'
  ];
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadFuelTanks();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    // Fade in animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Start the animation
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _densityController.dispose();
    _temperatureController.dispose();
    _waterContentController.dispose();
    _depthController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Load all fuel tanks to populate the dropdown
  Future<void> _loadFuelTanks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _fuelTankRepository.getAllFuelTanks();

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success && response.data != null) {
            _fuelTanks = response.data!;
            // If there are fuel tanks, select the first one by default
            if (_fuelTanks.isNotEmpty) {
              _selectedFuelTankId = _fuelTanks.first.fuelTankId;
              _selectedFuelType = _fuelTanks.first.fuelType;
            }
          } else {
            _errorMessage = response.errorMessage ?? 'Failed to load fuel tanks';
          }
        });
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
  
  // Handle tank selection change
  void _onFuelTankChanged(String? tankId) {
    if (tankId == null) return;
    
    setState(() {
      _selectedFuelTankId = tankId;
      // Update fuel type based on selected tank
      final selectedTank = _fuelTanks.firstWhere((tank) => tank.fuelTankId == tankId);
      _selectedFuelType = selectedTank.fuelType;
    });
  }
  
  // Validate and submit the form
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedFuelTankId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a fuel tank')),
      );
      return;
    }
    
    // Parse form values
    final double density = double.parse(_densityController.text);
    final double temperature = double.parse(_temperatureController.text);
    final double waterContent = double.parse(_waterContentController.text);
    final double depth = double.parse(_depthController.text);
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Get the current user's ID - try multiple possible sources
      String? userId = await SharedPrefs.getUserId();
      
      if (userId == null) {
        // The problem might be that different keys are used in different places
        final prefs = await SharedPreferences.getInstance();
        
        // Try all possible keys where user ID might be stored
        userId = prefs.getString('user_id') ?? 
                 prefs.getString('userId');
      }
      
      // Use a fallback value if userId is still null
      final checkedBy = userId ?? "app_user";
      
      final selectedTank = _fuelTanks.firstWhere((tank) => tank.fuelTankId == _selectedFuelTankId);
      
      // Create quality check object - only include required fields
      final qualityCheck = QualityCheck(
        fuelTankId: _selectedFuelTankId,
        petrolPumpId: selectedTank.petrolPumpId,
        fuelType: _selectedFuelType ?? selectedTank.fuelType,
        tankName: 'Tank (${selectedTank.fuelType})',
        density: density,
        temperature: temperature,
        waterContent: waterContent,
        depth: depth,
        qualityStatus: _qualityStatus,
        status: _status,
        checkedBy: checkedBy,
        checkedAt: DateTime.now(),
      );
      
      // Send to API
      final response = await _qualityCheckRepository.addQualityCheck(qualityCheck);
      
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quality check added successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Return to previous screen with success indicator
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add quality check: ${response.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty && _fuelTanks.isEmpty
                  ? _buildErrorView()
                  : _fuelTanks.isEmpty
                      ? _buildNoTanksView()
                      : _buildMainContent(),
        ),
      ),
    );
  }
  
  Widget _buildMainContent() {
    final Color primaryColor = Colors.purple;
    
    return Stack(
      children: [
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
                  // Title
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fuel Quality Check',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Record tank quality parameters',
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
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Tank selection visualization
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                          child: _buildTankSelectionSection(),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Quality parameters section
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Parameters section
                              Text(
                                'Quality Parameters',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Parameters grid
                              _buildParametersGrid(primaryColor),
                              
                              const SizedBox(height: 24),
                              
                              // Quality status section
                              Text(
                                'Quality Assessment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Quality status chips
                              _buildQualityStatusSelection(),
                              
                              // Quality status description
                              if (_qualityStatus.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getIconForQualityStatus(_qualityStatus),
                                        color: _getColorForQualityStatus(_qualityStatus),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _qualityStatus,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: _getColorForQualityStatus(_qualityStatus),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _getQualityStatusDescription(_qualityStatus),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
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
                              
                              // Submit button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _submitForm,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isSaving
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
                                            const Icon(
                                              Icons.science_rounded,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Submit Quality Check',
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildTankSelectionSection() {
    if (_selectedFuelTankId == null || _fuelTanks.isEmpty) return const SizedBox();
    
    final selectedTank = _fuelTanks.firstWhere((tank) => tank.fuelTankId == _selectedFuelTankId);
    final fuelColor = _getColorForFuelType(selectedTank.fuelType);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Fuel Tank',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(16),
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
              // Tank dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  prefixIcon: Icon(Icons.local_gas_station, color: fuelColor),
                  hintText: 'Select a fuel tank',
                  isCollapsed: false,
                ),
                value: _selectedFuelTankId,
                onChanged: _onFuelTankChanged,
                isExpanded: true, // Make dropdown take full width
                items: _fuelTanks.map((FuelTank tank) {
                  final String tankLabel = 'Tank (${tank.fuelType})';
                  final String tankInfo = '${tank.currentStock.toStringAsFixed(0)}L / ${tank.capacityInLiters.toStringAsFixed(0)}L';
                  
                  return DropdownMenuItem<String>(
                    value: tank.fuelTankId,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getColorForFuelType(tank.fuelType),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$tankLabel ($tankInfo)',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a fuel tank';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Tank visual and info row
              Row(
                children: [
                  // Tank visual
                  _buildTankVisual(selectedTank),
                  
                  const SizedBox(width: 20),
                  
                  // Tank info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fuel type
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: fuelColor.withValues(alpha:0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.local_gas_station,
                                size: 14,
                                color: fuelColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              selectedTank.fuelType,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: fuelColor,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Capacity row
                        _buildInfoRow(
                          'Capacity',
                          '${selectedTank.capacityInLiters.toStringAsFixed(0)} L',
                          Icons.straighten,
                          Colors.blue.shade700,
                        ),
                        
                        const SizedBox(height: 6),
                        
                        // Current stock row
                        _buildInfoRow(
                          'Current Stock',
                          '${selectedTank.currentStock.toStringAsFixed(0)} L',
                          Icons.opacity,
                          _getLevelColor(selectedTank.stockPercentage),
                        ),
                        
                        const SizedBox(height: 6),
                        
                        // Stock percentage row
                        _buildInfoRow(
                          'Fill Level',
                          '${selectedTank.stockPercentage.toStringAsFixed(1)}%',
                          Icons.show_chart,
                          _getLevelColor(selectedTank.stockPercentage),
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
    );
  }
  
  Widget _buildTankVisual(FuelTank tank) {
    final double percentage = tank.stockPercentage;
    final levelColor = _getLevelColor(percentage);
    
    return Container(
      width: 60,
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
  
  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
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
                fontSize: 13,
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
  
  Widget _buildParametersGrid(Color primaryColor) {
    return Column(
      children: [
        // Density field
        _buildParameterField(
          controller: _densityController,
          label: 'Density (kg/m³)',
          hint: 'Enter density value',
          icon: Icons.science_outlined,
          color: Colors.indigo.shade700,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Required';
            }
            if (double.tryParse(value) == null) {
              return 'Invalid number';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // Temperature field
        _buildParameterField(
          controller: _temperatureController,
          label: 'Temperature (°C)',
          hint: 'Enter temperature value',
          icon: Icons.thermostat,
          color: Colors.orange.shade700,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Required';
            }
            if (double.tryParse(value) == null) {
              return 'Invalid number';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // Water content field
        _buildParameterField(
          controller: _waterContentController,
          label: 'Water Content (%)',
          hint: 'Enter percentage',
          icon: Icons.opacity,
          color: Colors.blue.shade700,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Required';
            }
            if (double.tryParse(value) == null) {
              return 'Invalid number';
            }
            final double waterContent = double.parse(value);
            if (waterContent < 0 || waterContent > 100) {
              return 'Must be 0-100%';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // Depth field
        _buildParameterField(
          controller: _depthController,
          label: 'Depth (mm)',
          hint: 'Enter depth value',
          icon: Icons.straighten,
          color: Colors.purple.shade700,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Required';
            }
            if (double.tryParse(value) == null) {
              return 'Invalid number';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // Status dropdown
        _buildStatusDropdown(),
      ],
    );
  }
  
  Widget _buildParameterField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        prefixIcon: Icon(icon, color: color),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        floatingLabelBehavior: FloatingLabelBehavior.never,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      validator: validator,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color.withAlpha(220),
      ),
    );
  }
  
  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Check Status',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: Icon(Icons.timer_outlined, color: Colors.teal.shade700),
            ),
            value: _status,
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _status = newValue;
                });
              }
            },
            items: _statusOptions.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildQualityStatusSelection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _qualityStatusOptions.map((status) {
        final isSelected = _qualityStatus == status;
        final statusColor = _getColorForQualityStatus(status);
        
        return GestureDetector(
          onTap: () => setState(() => _qualityStatus = status),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected ? statusColor : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected ? Colors.transparent : statusColor.withValues(alpha:0.3),
                width: 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: statusColor.withValues(alpha:0.3),
                  blurRadius: 4,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getIconForQualityStatus(status),
                  color: isSelected ? Colors.white : statusColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadFuelTanks,
              style: AppTheme.primaryButtonStyle,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoTanksView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_gas_station,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No fuel tanks available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add fuel tanks before performing quality checks',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper methods
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
  
  Color _getColorForQualityStatus(String status) {
    switch(status.toLowerCase()) {
      case 'excellent':
        return Colors.green.shade700;
      case 'good':
        return Colors.lightGreen.shade700;
      case 'average':
        return Colors.amber.shade700;
      case 'warning':
        return Colors.orange;
      case 'poor':
        return Colors.orange.shade700;
      case 'critical':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
  
  IconData _getIconForQualityStatus(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
        return Icons.verified;
      case 'good':
        return Icons.check_circle;
      case 'average':
        return Icons.thumbs_up_down;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'poor':
        return Icons.error;
      case 'critical':
        return Icons.dangerous;
      default:
        return Icons.help_outline;
    }
  }
  
  String _getQualityStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
        return 'Fuel quality is exceptional and exceeds standards.';
      case 'good':
        return 'Fuel quality meets all standards with no issues.';
      case 'average':
        return 'Fuel quality is acceptable but could be improved.';
      case 'warning':
        return 'Some quality issues detected. Monitor closely.';
      case 'poor':
        return 'Significant quality issues. Action recommended.';
      case 'critical':
        return 'Serious quality problems. Immediate action required.';
      default:
        return 'Status unknown.';
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