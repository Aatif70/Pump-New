import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../api/pricing_repository.dart';
import '../../api/api_response.dart';
import '../../models/price_model.dart';
import '../../theme.dart';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/fuel_tank_repository.dart';
import '../../api/fuel_type_repository.dart';
import '../../models/fuel_type_model.dart';
import 'fuel_price_history_screen.dart';

class SetFuelPriceScreen extends StatefulWidget {
  const SetFuelPriceScreen({super.key});

  @override
  State<SetFuelPriceScreen> createState() => _SetFuelPriceScreenState();
}

class _SetFuelPriceScreenState extends State<SetFuelPriceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _markupPercentageController = TextEditingController();
  final _markupAmountController = TextEditingController();
  final _pricingRepository = PricingRepository();
  final _fuelTypeRepository = FuelTypeRepository();

  String _selectedFuelType = 'Petrol';
  String? _selectedFuelTypeId;
  List<String> _fuelTypes = ['Petrol', 'Diesel', 'Premium Petrol', 'Premium Diesel', 'CNG'];
  
  // Map to store fuelTypeId to fuel type name mapping
  Map<String, String> _fuelTypeIdToName = {};
  // Map to store fuel type name to fuelTypeId mapping (reverse lookup)
  Map<String, String> _fuelTypeNameToId = {};
  
  // Store the available fuel tanks and their types
  List<Map<String, dynamic>> _availableFuelTanks = [];
  
  DateTime _selectedEffectiveFrom = DateTime.now();
  DateTime _selectedEffectiveTo = DateTime.now().add(const Duration(days: 30));

  // FUEL TYPES AND THEIR COLORS
  final Map<String, Color> _fuelColors = {
    'Petrol': Colors.green.shade600,
    'Diesel': Colors.blue.shade700,
    'Premium Petrol': Colors.orange.shade600,
    'Premium Diesel': Colors.purple.shade600,
    'CNG': Colors.teal.shade600,
  };

  // Map fuel types to their icons
  final Map<String, IconData> _fuelIcons = {
    'Petrol': Icons.local_gas_station,
    'Diesel': Icons.local_gas_station,
    'Premium Petrol': Icons.auto_awesome,
    'Premium Diesel': Icons.auto_awesome,
    'CNG': Icons.compress,
  };

  bool _isLoading = false;
  bool _isLoadingCurrentPrices = true;
  String? _errorMessage;
  List<FuelPrice> _currentPrices = [];
  bool _showPriceForm = false;
  
  @override
  void initState() {
    super.initState();
    _fetchFuelTypes();
    _fetchAvailableFuelTypes();
    _fetchCurrentPrices();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _costController.dispose();
    _markupPercentageController.dispose();
    _markupAmountController.dispose();
    super.dispose();
  }

  // Fetch fuel types from the API
  Future<void> _fetchFuelTypes() async {
    try {
      developer.log('SetFuelPriceScreen: Fetching fuel types from API');
      final pumpId = await _pricingRepository.getPumpId();
      final response = await _fuelTypeRepository.getFuelTypesByPetrolPump(pumpId ?? '');
      
      if (response.success && response.data != null) {
        setState(() {
          // Create mappings
          _fuelTypeIdToName = {
            for (var fuelType in response.data!)
              fuelType.fuelTypeId: fuelType.name
          };
          
          _fuelTypeNameToId = {
            for (var fuelType in response.data!)
              fuelType.name: fuelType.fuelTypeId
          };
          
          developer.log('SetFuelPriceScreen: Created mapping with ${_fuelTypeIdToName.length} fuel types');
          
          // Debug the mappings
          _fuelTypeIdToName.forEach((id, name) {
            developer.log('SetFuelPriceScreen: Fuel Type ID: $id -> Name: $name');
          });
        });
      } else {
        developer.log('SetFuelPriceScreen: Failed to fetch fuel types: ${response.errorMessage}');
      }
    } catch (e) {
      developer.log('SetFuelPriceScreen: Error fetching fuel types: $e');
    }
  }
  
  // Update fuel type display names in the current prices list
  void _updateFuelTypeDisplayNames() {
    if (_currentPrices.isEmpty) return;
    
    for (int i = 0; i < _currentPrices.length; i++) {
      final price = _currentPrices[i];
      
      // Use the API's fuelType value directly as it's already correct
      // Only map if fuelType is empty but fuelTypeId exists
      if (price.fuelType.isEmpty && price.fuelTypeId != null && 
          _fuelTypeIdToName.containsKey(price.fuelTypeId)) {
        
        final displayName = _fuelTypeIdToName[price.fuelTypeId]!;
        
        // Create a new price object with the updated fuel type name
        final updatedPrice = FuelPrice(
          id: price.id,
          effectiveFrom: price.effectiveFrom,
          fuelType: displayName,
          fuelTypeId: price.fuelTypeId,
          pricePerLiter: price.pricePerLiter,
          petrolPumpId: price.petrolPumpId,
          lastUpdatedBy: price.lastUpdatedBy,
        );
        
        _currentPrices[i] = updatedPrice;
        developer.log('SetFuelPriceScreen: Updated empty fuel type: ${price.fuelTypeId} -> $displayName');
      }
    }
  }

  Future<void> _fetchCurrentPrices() async {
    setState(() {
      _isLoadingCurrentPrices = true;
      _errorMessage = null;
    });

    try {
      // Make sure we have fuel type mappings before fetching prices
      if (_fuelTypeIdToName.isEmpty) {
        await _fetchFuelTypes();
        await _fetchAvailableFuelTypes();
      }
      
      final response = await _pricingRepository.getCurrentPrices();

      setState(() {
        if (response.success && response.data != null) {
          _currentPrices = response.data!;
          
          // Log the received data
          developer.log("SetFuelPriceScreen: Received ${_currentPrices.length} prices from API");
          for (var price in _currentPrices) {
            developer.log("SetFuelPriceScreen: Price id=${price.id}, fuelType=${price.fuelType}, fuelTypeId=${price.fuelTypeId}, price=${price.pricePerLiter}");
          }
          
          // Only update fuel type names if the field is empty
          _updateFuelTypeDisplayNames();
          
          _prefillCurrentPrice();
        } else {
          _errorMessage = response.errorMessage ?? 'Failed to load current prices';
        }
        _isLoadingCurrentPrices = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoadingCurrentPrices = false;
      });
    }
  }

  // Fetch the latest price for a specific fuel type
  Future<void> _fetchLatestPrice(String fuelType) async {
    try {
      final response = await _pricingRepository.getLatestPriceByFuelType(fuelType);

      if (response.success && response.data != null) {
        setState(() {
          // Update the selected fuel type's current price
          final index = _currentPrices.indexWhere((price) => price.fuelType == fuelType);
          if (index != -1) {
            _currentPrices[index] = response.data!;
          } else {
            _currentPrices.add(response.data!);
          }
          
          if (_selectedFuelType == fuelType) {
            _prefillCurrentPrice();
          }
        });
      } else {
        developer.log('SetFuelPriceScreen: Failed to fetch latest price for $fuelType: ${response.errorMessage}');
      }
    } catch (e) {
      developer.log('SetFuelPriceScreen: Error fetching latest price: $e');
    }
  }

  void _prefillCurrentPrice() {
    // Find either by fuel type name or ID
    FuelPrice? currentPrice;
    
    // First try to find by selected fuel type name directly
    try {
      currentPrice = _currentPrices.firstWhere(
        (price) => price.fuelType == _selectedFuelType,
        orElse: () => FuelPrice(
          effectiveFrom: DateTime.now(),
          fuelType: '',
          pricePerLiter: 0,
          petrolPumpId: '',
          lastUpdatedBy: null,
        ),
      );
    } catch (e) {
      developer.log('SetFuelPriceScreen: Error finding price by name: $e');
    }
    
    // If we couldn't find by name and we have a fuel type ID mapping, try to find by ID
    if (currentPrice?.fuelType.isEmpty == true && _fuelTypeNameToId.containsKey(_selectedFuelType)) {
      final fuelTypeId = _fuelTypeNameToId[_selectedFuelType];
      try {
        currentPrice = _currentPrices.firstWhere(
          (price) => price.fuelTypeId == fuelTypeId,
          orElse: () => currentPrice ?? FuelPrice(
            effectiveFrom: DateTime.now(),
            fuelType: '',
            pricePerLiter: 0,
            petrolPumpId: '',
            lastUpdatedBy: null,
          ),
        );
        
        developer.log('SetFuelPriceScreen: Found price by fuelTypeId: $fuelTypeId');
      } catch (e) {
        developer.log('SetFuelPriceScreen: Error finding price by ID: $e');
      }
    }
    
    if (currentPrice != null && currentPrice.fuelType.isNotEmpty) {
      _priceController.text = currentPrice.pricePerLiter.toString();
      
      // Also fill in the new fields if they exist
      if (currentPrice.costPerLiter != null) {
        _costController.text = currentPrice.costPerLiter!.toString();
      } else {
        _costController.clear();
      }
      
      if (currentPrice.markupPercentage != null) {
        _markupPercentageController.text = currentPrice.markupPercentage!.toString();
      } else {
        _markupPercentageController.clear();
      }
      
      if (currentPrice.markupAmount != null) {
        _markupAmountController.text = currentPrice.markupAmount!.toString();
      } else {
        _markupAmountController.clear();
      }
      
      // If we're prefilling an existing price, also set the effective dates
      if (currentPrice.id != null) {
        setState(() {
          _selectedEffectiveFrom = currentPrice!.effectiveFrom;
          _selectedEffectiveTo = currentPrice.effectiveTo ?? DateTime.now().add(const Duration(days: 30));
        });
        developer.log('SetFuelPriceScreen: Prefilled effective dates: From ${DateFormat('yyyy-MM-dd').format(_selectedEffectiveFrom)} to ${DateFormat('yyyy-MM-dd').format(_selectedEffectiveTo)}');
      }
    } else {
      _priceController.clear();
      _costController.clear();
      _markupPercentageController.clear();
      _markupAmountController.clear();
      // Reset to current date if no existing price
      setState(() {
        _selectedEffectiveFrom = DateTime.now();
        _selectedEffectiveTo = DateTime.now().add(const Duration(days: 30));
      });
    }
  }

  Future<void> _setFuelPrice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pricePerLiter = double.parse(_priceController.text);
      
      // Parse new fields if provided
      double? costPerLiter;
      if (_costController.text.isNotEmpty) {
        costPerLiter = double.parse(_costController.text);
      }
      
      double? markupPercentage;
      if (_markupPercentageController.text.isNotEmpty) {
        markupPercentage = double.parse(_markupPercentageController.text);
      }
      
      double? markupAmount;
      if (_markupAmountController.text.isNotEmpty) {
        markupAmount = double.parse(_markupAmountController.text);
      }
      
      // Get pump ID and employee ID for lastUpdatedBy
      final pumpId = await _pricingRepository.getPumpId() ?? 'default_pump_id';
      final employeeId = await _pricingRepository.getEmployeeId() ?? 'default_employee_id';
      
      developer.log("SetFuelPriceScreen: Using pumpId='$pumpId', employeeId='$employeeId'");
      print("DEBUG: Setting fuel price with pumpId='$pumpId', employeeId='$employeeId'");
      
      // Check if IDs are available
      if (pumpId.isEmpty) {
        setState(() {
          _errorMessage = 'Petrol pump information is missing. Using default values.';
          _isLoading = false;
        });
        return;
      }

      // Check if we're updating an existing price or creating a new one
      final existingPrice = _currentPrices.firstWhere(
        (price) => price.fuelType == _selectedFuelType && price.id != null,
        orElse: () => FuelPrice(
          effectiveFrom: DateTime.now(),
          fuelType: _selectedFuelType,
          pricePerLiter: 0,
          petrolPumpId: '',
          lastUpdatedBy: null,
        ),
      );

      final bool isUpdating = existingPrice.id != null;
      developer.log("SetFuelPriceScreen: ${isUpdating ? 'Updating' : 'Creating new'} price for ${_selectedFuelType}, existing ID: ${existingPrice.id ?? 'None'}");
      print("DEBUG: ${isUpdating ? 'Updating' : 'Creating new'} price for ${_selectedFuelType}, existing ID: ${existingPrice.id ?? 'None'}");

      // Get the fuelTypeId for the selected fuel type
      String? fuelTypeId;
      
      // First try to get it from the existing price
      if (existingPrice.fuelTypeId != null) {
        fuelTypeId = existingPrice.fuelTypeId;
        developer.log("SetFuelPriceScreen: Using existing fuelTypeId: $fuelTypeId");
        print("DEBUG: Using existing fuelTypeId: $fuelTypeId");
      } 
      // If not available from existing price, use our selected ID
      else if (_selectedFuelTypeId != null) {
        fuelTypeId = _selectedFuelTypeId;
        developer.log("SetFuelPriceScreen: Using selected fuelTypeId: $fuelTypeId");
        print("DEBUG: Using selected fuelTypeId: $fuelTypeId");
      }
      // If still not available, try from our mapping
      else if (_fuelTypeNameToId.containsKey(_selectedFuelType)) {
        fuelTypeId = _fuelTypeNameToId[_selectedFuelType];
        developer.log("SetFuelPriceScreen: Found fuelTypeId from mapping: $fuelTypeId");
        print("DEBUG: Found fuelTypeId from mapping: $fuelTypeId");
      } else {
        developer.log("SetFuelPriceScreen: No fuelTypeId available for $_selectedFuelType, will use fuelType instead");
        print("DEBUG: WARNING - No fuelTypeId available for $_selectedFuelType");
      }

      print("DEBUG: Selected fuel type: $_selectedFuelType");
      print("DEBUG: Effective from date: ${_selectedEffectiveFrom.toIso8601String()}");
      print("DEBUG: Effective to date: ${_selectedEffectiveTo.toIso8601String()}");
      print("DEBUG: Price per liter: $pricePerLiter");
      print("DEBUG: Cost per liter: $costPerLiter");
      print("DEBUG: Markup percentage: $markupPercentage");
      print("DEBUG: Markup amount: $markupAmount");
      print("DEBUG: FuelTypeId: $fuelTypeId");
      
      ApiResponse<FuelPrice> response;
      
      if (isUpdating) {
        // Update existing price
        final updatedPrice = FuelPrice(
          id: existingPrice.id,
          effectiveFrom: _selectedEffectiveFrom,
          effectiveTo: _selectedEffectiveTo,
          fuelType: _selectedFuelType,
          fuelTypeId: fuelTypeId,
          pricePerLiter: pricePerLiter,
          costPerLiter: costPerLiter,
          markupPercentage: markupPercentage,
          markupAmount: markupAmount,
          petrolPumpId: pumpId,
          lastUpdatedBy: employeeId,
        );

        developer.log("SetFuelPriceScreen: Updating price with ID: ${existingPrice.id}, last updated by employee: $employeeId");
        print("DEBUG: Updating price with ID: ${existingPrice.id}, last updated by employee: $employeeId");
        print("DEBUG: Update price object: ${updatedPrice.toJson()}");
        response = await _pricingRepository.updateFuelPrice(existingPrice.id!, updatedPrice);
      } else {
        // Create new price
        final newPrice = FuelPrice(
          effectiveFrom: _selectedEffectiveFrom,
          effectiveTo: _selectedEffectiveTo,
          fuelType: _selectedFuelType,
          fuelTypeId: fuelTypeId,
          pricePerLiter: pricePerLiter,
          costPerLiter: costPerLiter,
          markupPercentage: markupPercentage,
          markupAmount: markupAmount,
          petrolPumpId: pumpId,
          lastUpdatedBy: employeeId,
        );

        developer.log("SetFuelPriceScreen: Creating new price, updated by employee: $employeeId");
        print("DEBUG: Creating new price, updated by employee: $employeeId");
        print("DEBUG: New price object: ${newPrice.toJson()}");
        response = await _pricingRepository.setFuelPrice(newPrice);
      }

      if (response.success) {
        print("DEBUG: API response success: ${response.success}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fuel price ${isUpdating ? 'updated' : 'set'} successfully')),
        );
        _priceController.clear();
        _costController.clear();
        _markupPercentageController.clear();
        _markupAmountController.clear();
        _fetchCurrentPrices();
        setState(() {
          _showPriceForm = false;
        });
      } else {
        final errorMsg = response.errorMessage ?? 'Failed to ${isUpdating ? 'update' : 'set'} price';
        developer.log("SetFuelPriceScreen: API error: $errorMsg");
        print("DEBUG: API error response: $errorMsg");
        
        setState(() {
          _errorMessage = errorMsg;
        });
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Operation Failed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMsg),
                SizedBox(height: 16),
                Text('Please check the price and try again.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('DISMISS'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
      developer.log("SetFuelPriceScreen: Exception in _setFuelPrice: $e");
      print("DEBUG: Exception in _setFuelPrice: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Show options for a price
  void _showPriceOptions(FuelPrice price) {
    // Check if the price has an ID
    if (price.id == null) {
      developer.log('SetFuelPriceScreen: WARNING - Missing ID in _showPriceOptions for ${price.fuelType}');
      
      // Try to find a matching price with an ID
      final matchingPrice = _currentPrices.firstWhere(
        (p) => p.fuelType == price.fuelType && p.id != null,
        orElse: () => price,
      );
      
      if (matchingPrice.id != null) {
        developer.log('SetFuelPriceScreen: Found matching price with ID: ${matchingPrice.id}');
        price = matchingPrice;
      }
    }
    
    // Get display fuel type name using helper method
    String displayFuelType = _getDisplayFuelType(price);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Price'),
              onTap: () {
                Navigator.pop(context);
                _showEditPriceDialog(price);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('View Price History'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to dedicated history screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FuelPriceHistoryScreen(
                      fuelType: displayFuelType,
                      fuelTypeId: price.fuelTypeId,
                    ),
                  ),
                );
              },
            ),
            // Price details - removed ID display
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Fuel Type: $displayFuelType'),
                  Text('Effective Date: ${DateFormat('MMM dd, yyyy HH:mm').format(price.effectiveFrom)}'),
                  // if (price.lastUpdatedBy != null)
                  //   Text('Last Updated By: ${price.lastUpdatedBy}'),
                  // if (price.fuelTypeId != null)
                  //   Text('Fuel Type ID: ${price.fuelTypeId}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fetch available fuel types from the API
  Future<void> _fetchAvailableFuelTypes() async {
    try {
      developer.log('SetFuelPriceScreen: Fetching available fuel types');
      
      // First, ensure we have the fuel type mapping loaded
      if (_fuelTypeIdToName.isEmpty) {
        await _fetchFuelTypes();
      }
      
      // Get available fuel types from the actual fuel tanks
      final fuelTankRepository = FuelTankRepository();
      final response = await fuelTankRepository.getAllFuelTanks();
      
      if (response.success && response.data != null) {
        // Extract unique fuel types from tanks
        final Set<String> availableFuelTypes = {};
        _availableFuelTanks = []; // Clear existing tank data
        
        // Only include active tanks
        for (final tank in response.data!) {
          if (tank.status.toLowerCase() == 'active') {
            String? fuelTypeId = tank.fuelTypeId;
            
            // Skip if no fuel type ID
            if (fuelTypeId == null || fuelTypeId.isEmpty) {
              developer.log('SetFuelPriceScreen: Skipping tank with missing fuelTypeId: ${tank.fuelTankId}');
              continue;
            }
            
            // Get the fuel type name from our mapping or use the tank's fuel type
            String fuelTypeName;
            if (_fuelTypeIdToName.containsKey(fuelTypeId)) {
              fuelTypeName = _fuelTypeIdToName[fuelTypeId]!;
              developer.log('SetFuelPriceScreen: Using name from mapping for fuel tank type ID $fuelTypeId: $fuelTypeName');
            } else {
              fuelTypeName = tank.fuelType;
              developer.log('SetFuelPriceScreen: Using tank\'s fuel type name for ID $fuelTypeId: $fuelTypeName');
              
              // Add to our mapping for future reference
              _fuelTypeIdToName[fuelTypeId] = fuelTypeName;
            }
            
            // Only add if we have a valid name
            if (fuelTypeName.isNotEmpty) {
              availableFuelTypes.add(fuelTypeName);
              
              // Store tank info with both name and ID
              _availableFuelTanks.add({
                'name': fuelTypeName,
                'id': fuelTypeId,
                'tankId': tank.fuelTankId
              });
              
              // Update our name-to-id mapping
              _fuelTypeNameToId[fuelTypeName] = fuelTypeId;
              developer.log('SetFuelPriceScreen: Added fuel type mapping: $fuelTypeName -> $fuelTypeId');
            } else {
              developer.log('SetFuelPriceScreen: Skipping tank with empty fuel type name: ${tank.fuelTankId}');
            }
          }
        }
        
        setState(() {
          // Convert Set to List
          _fuelTypes = availableFuelTypes.toList();
          _fuelTypes.sort(); // Sort alphabetically
        });
        
        developer.log('SetFuelPriceScreen: Available fuel types from tanks: $_fuelTypes');
        developer.log('SetFuelPriceScreen: Available fuel tanks with IDs: $_availableFuelTanks');
        developer.log('SetFuelPriceScreen: FuelType to ID mapping: $_fuelTypeNameToId');
        
        // If we have no fuel types, we have no tanks
        if (_fuelTypes.isEmpty) {
          setState(() {
            _showPriceForm = false;
          });
        } else if (_fuelTypes.isNotEmpty) {
          // If we have fuel types available, set the first one as selected
          setState(() {
            _selectedFuelType = _fuelTypes.first;
            // Set the corresponding ID
            _selectedFuelTypeId = _getFuelTypeIdByName(_selectedFuelType);
            developer.log('SetFuelPriceScreen: Selected fuel type: $_selectedFuelType with ID: $_selectedFuelTypeId');
          });
          _prefillCurrentPrice();
        }
      } else {
        developer.log('SetFuelPriceScreen: Error fetching fuel tanks: ${response.errorMessage}');
        setState(() {
          _fuelTypes = [];
          _showPriceForm = false;
        });
      }
    } catch (e) {
      developer.log('SetFuelPriceScreen: Error fetching fuel types: $e');
      setState(() {
        _fuelTypes = [];
        _showPriceForm = false;
      });
    }
  }

  // Helper method to get fuel type ID by name
  String? _getFuelTypeIdByName(String name) {
    // First check in our direct mapping
    if (_fuelTypeNameToId.containsKey(name)) {
      return _fuelTypeNameToId[name];
    }
    
    // Then check in available fuel tanks
    for (final tank in _availableFuelTanks) {
      if (tank['name'] == name && tank['id'] != null) {
        return tank['id'];
      }
    }
    
    return null;
  }

  // Method to show edit price dialog
  void _showEditPriceDialog(FuelPrice price) {
    final TextEditingController priceController = TextEditingController(text: price.pricePerLiter.toString());
    final TextEditingController costController = TextEditingController(
      text: price.costPerLiter != null ? price.costPerLiter.toString() : ''
    );
    final TextEditingController markupPercentageController = TextEditingController(
      text: price.markupPercentage != null ? price.markupPercentage.toString() : ''
    );
    final TextEditingController markupAmountController = TextEditingController(
      text: price.markupAmount != null ? price.markupAmount.toString() : ''
    );
    
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    DateTime effectiveFrom = price.effectiveFrom;
    DateTime effectiveTo = price.effectiveTo ?? price.effectiveFrom.add(const Duration(days: 30));
    
    // Get display fuel type name using helper method
    String displayFuelType = _getDisplayFuelType(price);
    final color = _fuelColors[displayFuelType] ?? Colors.grey.shade700;
    
    // Debug the price details including fuelTypeId
    developer.log('SetFuelPriceScreen: Edit dialog for price - ID: ${price.id}, Type: ${displayFuelType}, TypeId: ${price.fuelTypeId}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _fuelIcons[displayFuelType] ?? Icons.local_gas_station,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Edit ${displayFuelType} Price'),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current price info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: color.withValues(alpha:0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Price: ₹${price.pricePerLiter}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        'Last Updated: ${DateFormat('MMM dd, yyyy HH:mm').format(price.effectiveFrom)}',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Date range pickers (effective from and to)
                Text('Effective Period:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                // From date
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactDatePicker(
                        label: 'From',
                        selectedDate: effectiveFrom,
                        color: color,
                        context: context,
                        onDateSelected: (date) {
                          effectiveFrom = date;
                          // If effectiveTo is before effectiveFrom, update it
                          if (effectiveTo.isBefore(effectiveFrom)) {
                            effectiveTo = effectiveFrom.add(const Duration(days: 1));
                          }
                        }
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // To date
                    Expanded(
                      child: _buildCompactDatePicker(
                        label: 'To',
                        selectedDate: effectiveTo,
                        color: color,
                        context: context,
                        onDateSelected: (date) {
                          effectiveTo = date;
                        }
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Price field
                TextFormField(
                  controller: priceController,
                  decoration: InputDecoration(
                    labelText: 'Price per liter (₹)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.currency_rupee),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: color),
                    ),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a price';
                    }
                    
                    try {
                      final price = double.parse(value);
                      if (price <= 0) {
                        return 'Price must be greater than zero';
                      }
                    } catch (e) {
                      return 'Please enter a valid number';
                    }
                    
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Cost per liter field
                TextFormField(
                  controller: costController,
                  decoration: InputDecoration(
                    labelText: 'Cost per liter (₹)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.receipt),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: color),
                    ),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                
                const SizedBox(height: 16),
                
                // Markup fields (percentage and amount)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: markupPercentageController,
                        decoration: InputDecoration(
                          labelText: 'Markup %',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.percent),
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          // Calculate markup amount if both cost and percentage are entered
                          if (value.isNotEmpty && costController.text.isNotEmpty) {
                            try {
                              final cost = double.parse(costController.text);
                              final percentage = double.parse(value);
                              final markupAmount = cost * (percentage / 100);
                              markupAmountController.text = markupAmount.toStringAsFixed(2);
                            } catch (e) {
                              // Ignore errors
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: markupAmountController,
                        decoration: InputDecoration(
                          labelText: 'Markup ₹',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.currency_rupee),
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          // Calculate percentage if both cost and amount are entered
                          if (value.isNotEmpty && costController.text.isNotEmpty) {
                            try {
                              final cost = double.parse(costController.text);
                              if (cost > 0) {
                                final amount = double.parse(value);
                                final percentage = (amount / cost) * 100;
                                markupPercentageController.text = percentage.toStringAsFixed(2);
                              }
                            } catch (e) {
                              // Ignore errors
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                
                setState(() {
                  _isLoading = true;
                });
                
                try {
                  final pricePerLiter = double.parse(priceController.text);
                  
                  // Parse optional fields
                  double? costPerLiter;
                  if (costController.text.isNotEmpty) {
                    costPerLiter = double.parse(costController.text);
                  }
                  
                  double? markupPercentage;
                  if (markupPercentageController.text.isNotEmpty) {
                    markupPercentage = double.parse(markupPercentageController.text);
                  }
                  
                  double? markupAmount;
                  if (markupAmountController.text.isNotEmpty) {
                    markupAmount = double.parse(markupAmountController.text);
                  }
                  
                  // Get pump ID and employee ID for lastUpdatedBy
                  final pumpId = await _pricingRepository.getPumpId() ?? 'default_pump_id';
                  final employeeId = await _pricingRepository.getEmployeeId() ?? 'default_employee_id';
                  
                  // Get the fuelTypeId from the existing price if available
                  String? fuelTypeId = price.fuelTypeId;
                  
                  // If fuelTypeId is not available in the price object, try to get it from our mapping
                  if (fuelTypeId == null && _fuelTypeNameToId.containsKey(price.fuelType)) {
                    fuelTypeId = _fuelTypeNameToId[price.fuelType];
                    developer.log("SetFuelPriceScreen: Found fuelTypeId from mapping: $fuelTypeId");
                  }
                  
                  developer.log("SetFuelPriceScreen: Edit dialog using fuelTypeId: ${fuelTypeId ?? 'Not available'}");
                  
                  final updatedPrice = FuelPrice(
                    id: price.id,
                    effectiveFrom: effectiveFrom,
                    effectiveTo: effectiveTo,
                    fuelType: price.fuelType,
                    fuelTypeId: fuelTypeId,
                    pricePerLiter: pricePerLiter,
                    costPerLiter: costPerLiter,
                    markupPercentage: markupPercentage,
                    markupAmount: markupAmount,
                    petrolPumpId: pumpId,
                    lastUpdatedBy: employeeId,
                  );
                  
                  if (price.id != null) {
                    final response = await _pricingRepository.updateFuelPrice(price.id!, updatedPrice);
                    
                    if (response.success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fuel price updated successfully')),
                      );
                      _fetchCurrentPrices();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(response.errorMessage ?? 'Failed to update price')),
                      );
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                } finally {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: color,
            ),
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }
  
  // Helper method for compact date picker in the edit dialog
  Widget _buildCompactDatePicker({
    required String label,
    required DateTime selectedDate,
    required Color color,
    required BuildContext context,
    required Function(DateTime) onDateSelected,
  }) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(primary: color),
              ),
              child: child!,
            );
          },
        );
        
        if (picked != null) {
          onDateSelected(DateTime(
            picked.year,
            picked.month,
            picked.day,
            selectedDate.hour,
            selectedDate.minute,
          ));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(selectedDate),
                  style: TextStyle(fontSize: 14),
                ),
                Icon(Icons.calendar_today, size: 16, color: color),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get display fuel type name
  String _getDisplayFuelType(FuelPrice price) {
    // If the fuel type is already populated from API, use it
    if (price.fuelType.isNotEmpty) {
      return price.fuelType;
    }
    
    // Otherwise, try to get from mapping
    if (price.fuelTypeId != null && _fuelTypeIdToName.containsKey(price.fuelTypeId)) {
      return _fuelTypeIdToName[price.fuelTypeId]!;
    }
    
    // Fallback
    return "Unknown Fuel";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fuel Price Dashboard'),
        elevation: 0,
        actions: [
          // Add button

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCurrentPrices,
            tooltip: 'Refresh Prices',
          ),
        ],
      ),
      body: _isLoadingCurrentPrices
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildMainContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchCurrentPrices,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return _showPriceForm
        ? _buildAddEditPriceForm()
        : _buildPriceListView();
  }

  Widget _buildPriceListView() {
    return RefreshIndicator(
      onRefresh: _fetchCurrentPrices,
      child: CustomScrollView(
        slivers: [
          // Header section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    'Last updated: ${_currentPrices.isNotEmpty ? DateFormat('dd MMM yyyy, HH:mm').format(_currentPrices.first.effectiveFrom) : 'N/A'}',
                    style: AppTheme.subheadingStyle,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // Empty state
          if (_currentPrices.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                      _fuelTypes.isEmpty
                          ? 'No fuel tanks found.\nAdd a fuel tank before setting prices.'
                          : 'No current prices available.\nTap the + button to set prices.',
                      style: AppTheme.subheadingStyle,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_fuelTypes.isEmpty) {
                          // Navigate to fuel tank screen or show dialog explaining the need to add tanks
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please add a fuel tank first')),
                          );
                        } else {
                          setState(() {
                            _selectedFuelType = _fuelTypes.first;
                            _selectedEffectiveFrom = DateTime.now();
                            _selectedEffectiveTo = DateTime.now().add(const Duration(days: 30));
                            _priceController.clear();
                            _showPriceForm = true;
                          });
                        }
                      },
                      icon: Icon(_fuelTypes.isEmpty ? Icons.storage : Icons.add),
                      label: Text(_fuelTypes.isEmpty ? 'Add Fuel Tank' : 'Add Your First Price'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Price list
          if (_currentPrices.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final price = _currentPrices[index];
                    final color = _fuelColors[price.fuelType] ?? Colors.grey.shade700;
                    final icon = _fuelIcons[price.fuelType] ?? Icons.local_gas_station;
                    
                    return _buildPriceListItem(price, color, icon);
                  },
                  childCount: _currentPrices.length,
                ),
              ),
            ),
          
          // Add another price button at the bottom - REDESIGNED
          if (_currentPrices.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Container(
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
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _selectedFuelType = _fuelTypes.first;
                          _selectedEffectiveFrom = DateTime.now();
                          _selectedEffectiveTo = DateTime.now().add(const Duration(days: 30));
                          _priceController.clear();
                          _costController.clear();
                          _markupPercentageController.clear();
                          _markupAmountController.clear();
                          _showPriceForm = true;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withValues(alpha:0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add_circle_outline,
                                color: AppTheme.primaryBlue,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add Another Fuel Price',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Set price for a different fuel type',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddEditPriceForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _showPriceForm = false;
                    });
                  },
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
                const SizedBox(width: 16),
                Text(
                  'Set Fuel Price',
                  style: AppTheme.headingStyle,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // The price form
          _buildPriceForm(),
          
          // Extra space at bottom to prevent overflow
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPriceForm() {
    // Find the current price for the selected fuel type (if any)
    final currentPrice = _currentPrices.firstWhere(
      (price) => price.fuelType == _selectedFuelType && price.id != null,
      orElse: () {
        // If we couldn't find one with an ID, try without ID filter
        final noIdPrice = _currentPrices.firstWhere(
          (price) => price.fuelType == _selectedFuelType,
          orElse: () => FuelPrice(
            effectiveFrom: DateTime.now(),
            fuelType: _selectedFuelType,
            pricePerLiter: 0,
            petrolPumpId: '',
            lastUpdatedBy: null,
          ),
        );
        
        developer.log('SetFuelPriceScreen: In _buildPriceForm - Found price without ID check: ${noIdPrice.fuelType}, ID: ${noIdPrice.id ?? 'NULL'}');
        return noIdPrice;
      },
    );
    
    developer.log('SetFuelPriceScreen: Current price in form: ${currentPrice.fuelType}, ID: ${currentPrice.id ?? 'NULL'}');
    
    // Check if this is an existing price (has an ID) or a new one
    final isExistingPrice = currentPrice.id != null;
    final color = _fuelColors[_selectedFuelType] ?? Colors.grey.shade700;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha:0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form title with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha:0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _fuelIcons[_selectedFuelType] ?? Icons.local_gas_station,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isExistingPrice ? 'Edit ${_selectedFuelType} Price' : 'Add New ${_selectedFuelType} Price',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Text(
                          isExistingPrice ? 'Update existing price details' : 'Set price for this fuel type',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Fuel type dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Fuel Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  prefixIcon: Icon(Icons.local_gas_station, color: color),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                ),
                value: _selectedFuelType,
                items: _fuelTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedFuelType = newValue;
                      // Update the selected fuel type ID when fuel type changes
                      _selectedFuelTypeId = _getFuelTypeIdByName(newValue);
                      developer.log('SetFuelPriceScreen: Selected fuel type changed to: $newValue with ID: $_selectedFuelTypeId');
                    });
                    _prefillCurrentPrice();
                  }
                },
              ),
              
              const SizedBox(height: 24),
              
              // Date pickers
              Text(
                'Effective Period:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildCompactDatePicker(
                      label: 'From',
                      selectedDate: _selectedEffectiveFrom,
                      color: color,
                      context: context,
                      onDateSelected: (date) {
                        setState(() {
                          _selectedEffectiveFrom = date;
                          // If effectiveTo is before the new effectiveFrom, update it
                          if (_selectedEffectiveTo.isBefore(_selectedEffectiveFrom)) {
                            _selectedEffectiveTo = _selectedEffectiveFrom.add(const Duration(days: 1));
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCompactDatePicker(
                      label: 'To',
                      selectedDate: _selectedEffectiveTo,
                      color: color,
                      context: context,
                      onDateSelected: (date) {
                        setState(() {
                          _selectedEffectiveTo = date;
                        });
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Price section header
              Text(
                'Price Details:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              
              // Price and cost fields
              Row(
                children: [
                  // Price per liter field
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: 'Price per Liter (₹)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        prefixIcon: Icon(Icons.currency_rupee, color: color),
                        suffixText: '₹',
                        suffixStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a price';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        if (double.parse(value) <= 0) {
                          return 'Price must be greater than zero';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Cost per liter field
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      decoration: InputDecoration(
                        labelText: 'Cost per Liter (₹)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        prefixIcon: Icon(Icons.receipt, color: color),
                        suffixText: '₹',
                        suffixStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      // Not required
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          if (double.parse(value) <= 0) {
                            return 'Cost must be greater than zero';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Markup fields
              Row(
                children: [
                  // Markup percentage field
                  Expanded(
                    child: TextFormField(
                      controller: _markupPercentageController,
                      decoration: InputDecoration(
                        labelText: 'Markup Percentage (%)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        prefixIcon: Icon(Icons.percent, color: color),
                        suffixText: '%',
                        suffixStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      // Not required
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          if (double.parse(value) < 0) {
                            return 'Markup % cannot be negative';
                          }
                        }
                        return null;
                      },
                      onChanged: (value) {
                        // Optionally: Calculate markup amount if both cost and percentage are entered
                        if (value.isNotEmpty && _costController.text.isNotEmpty) {
                          try {
                            final cost = double.parse(_costController.text);
                            final percentage = double.parse(value);
                            final markupAmount = cost * (percentage / 100);
                            _markupAmountController.text = markupAmount.toStringAsFixed(2);
                          } catch (e) {
                            // Ignore errors
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Markup amount field
                  Expanded(
                    child: TextFormField(
                      controller: _markupAmountController,
                      decoration: InputDecoration(
                        labelText: 'Markup Amount (₹)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        prefixIcon: Icon(Icons.currency_rupee, color: color),
                        suffixText: '₹',
                        suffixStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      // Not required
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          if (double.parse(value) < 0) {
                            return 'Markup amount cannot be negative';
                          }
                        }
                        return null;
                      },
                      onChanged: (value) {
                        // Optionally: Calculate percentage if both cost and amount are entered
                        if (value.isNotEmpty && _costController.text.isNotEmpty) {
                          try {
                            final cost = double.parse(_costController.text);
                            if (cost > 0) {
                              final amount = double.parse(value);
                              final percentage = (amount / cost) * 100;
                              _markupPercentageController.text = percentage.toStringAsFixed(2);
                            }
                          } catch (e) {
                            // Ignore errors
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Help text for markup calculation
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Formula: Price = Cost + Markup Amount',
                        style: TextStyle(
                          color: Colors.amber.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  // Save button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _setFuelPrice,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(isExistingPrice ? Icons.update : Icons.save),
                      label: Text(
                        isExistingPrice ? 'Update Price' : 'Save Price',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  
                  // Cancel button for all prices (not just new ones)
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showPriceForm = false;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.grey.shade600,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
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
  
  // Helper method to build date picker fields
  Widget _buildDatePicker({
    required String label,
    required DateTime selectedDate,
    required Color color,
    required Function(DateTime) onDateSelected,
  }) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: color,
                ),
              ),
              child: child!,
            );
          },
        );
        
        if (picked != null) {
          final TimeOfDay? pickedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(selectedDate),
          );
          
          if (pickedTime != null) {
            onDateSelected(DateTime(
              picked.year,
              picked.month,
              picked.day,
              pickedTime.hour,
              pickedTime.minute,
            ));
          } else {
            onDateSelected(DateTime(
              picked.year,
              picked.month,
              picked.day,
              selectedDate.hour,
              selectedDate.minute,
            ));
          }
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_today),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: color),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('dd MMM yyyy').format(selectedDate),
              style: const TextStyle(fontSize: 16),
            ),
            Icon(Icons.arrow_drop_down, color: color),
          ],
        ),
      ),
    );
  }

  // New horizontal price list item widget
  Widget _buildPriceListItem(FuelPrice price, Color color, IconData icon) {
    final lastUpdated = DateFormat('dd MMM HH:mm').format(price.effectiveFrom);
    
    // Get display fuel type name using helper method
    String displayFuelType = _getDisplayFuelType(price);
    
    // Get the appropriate color and icon for this fuel type
    final displayColor = _fuelColors[displayFuelType] ?? color;
    final displayIcon = _fuelIcons[displayFuelType] ?? icon;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showEditPriceDialog(price),
          onLongPress: () => _showPriceOptions(price),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  displayColor.withValues(alpha:0.9),
                  displayColor,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Fuel type icon section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(displayIcon, color: displayColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  
                  // Price and details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayFuelType,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Updated: $lastUpdated',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Price display
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${price.pricePerLiter.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          // Navigate to dedicated history screen instead of showing in-page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FuelPriceHistoryScreen(
                                fuelType: displayFuelType,
                                fuelTypeId: price.fuelTypeId,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha:0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha:0.5), width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.history,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'History',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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
        ),
      ),
    );
  }
}