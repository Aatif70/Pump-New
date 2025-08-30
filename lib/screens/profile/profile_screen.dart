import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/pump_repository.dart';
import '../../models/pump_model.dart';
import '../../models/fuel_type_model.dart';
import '../../theme.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _pumpRepository = PumpRepository();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoadingFuelTypes = false;
  String _errorMessage = '';
  PumpProfile? _profile;
  bool _isEditMode = false;
  List<FuelType> _fuelTypes = [];
  List<FuelType> _pumpFuelTypes = []; // Selected fuel types for this pump
  List<String> _selectedFuelTypeIds = [];
  
  // Form controllers - only for the allowed editable fields
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _gstNumberController = TextEditingController();
  final TextEditingController _taxIdController = TextEditingController();
  final TextEditingController _sapNoController = TextEditingController();
  
  // Status options
  final List<String> _statusOptions = ['Active', 'Inactive', 'Maintenance'];
  String _selectedStatus = 'Inactive';  // Default value

  @override
  void initState() {
    super.initState();
    _loadPumpProfile();
  }
  
  @override
  void dispose() {
    // Dispose controllers
    _contactNumberController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _gstNumberController.dispose();
    _taxIdController.dispose();
    _sapNoController.dispose();
    super.dispose();
  }

  Future<void> _loadPumpProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _pumpRepository.getPumpProfile();
      
      if (!mounted) return;
      
      if (response.success && response.data != null) {
        setState(() {
          _profile = response.data;
          _isLoading = false;
        });
        
        // Set form values
        _setFormValues();
        
        print('PROFILE_SCREEN: Profile loaded successfully: ${_profile!.toJson()}');
      } else {
        setState(() {
          _errorMessage = response.errorMessage ?? 'Failed to load profile data';
          _isLoading = false;
        });
        print('PROFILE_SCREEN: Failed to load profile: $_errorMessage');
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
      print('PROFILE_SCREEN: Exception loading profile: $e');
    }
  }
  
  // Load fuel types from API
  Future<void> _loadFuelTypes() async {
    if (_fuelTypes.isNotEmpty) {
      return; // Already loaded
    }
    
    setState(() {
      _isLoadingFuelTypes = true;
    });
    
    try {
      // First, get all available fuel types
      final allFuelTypesResponse = await _pumpRepository.getFuelTypes();
      
      if (!mounted) return;
      
      if (allFuelTypesResponse.success && allFuelTypesResponse.data != null) {
        setState(() {
          _fuelTypes = allFuelTypesResponse.data!;
        });
        
        print('PROFILE_SCREEN: Loaded ${_fuelTypes.length} available fuel types');
        // Debug log to help diagnose issues
        for (var fuelType in _fuelTypes) {
          print('PROFILE_SCREEN: Fuel Type - ID: ${fuelType.fuelTypeId}, Name: ${fuelType.name}');
        }
      } else {
        print('PROFILE_SCREEN: Failed to load all fuel types: ${allFuelTypesResponse.errorMessage}');
      }
      
      // Parse selected fuel types from profile
      if (_profile != null && _profile!.fuelTypesAvailable.isNotEmpty) {
        print('PROFILE_SCREEN: Profile has fuel types: ${_profile!.fuelTypesAvailable}');
        _selectedFuelTypeIds = _profile!.fuelTypesAvailable.split(',');
        print('PROFILE_SCREEN: Selected fuel type IDs: $_selectedFuelTypeIds');
        
        // Now try to get pump-specific fuel types if we have a petrol pump ID
        if (_profile!.petrolPumpId != null && _profile!.petrolPumpId!.isNotEmpty) {
          final pumpFuelTypesResponse = await _pumpRepository.getPumpFuelTypes(_profile!.petrolPumpId!);
          
          if (pumpFuelTypesResponse.success && pumpFuelTypesResponse.data != null) {
            setState(() {
              _pumpFuelTypes = pumpFuelTypesResponse.data!;
            });
            
            print('PROFILE_SCREEN: Loaded ${_pumpFuelTypes.length} pump-specific fuel types');
            // Debug log for pump-specific fuel types
            for (var fuelType in _pumpFuelTypes) {
              print('PROFILE_SCREEN: Pump Fuel Type - ID: ${fuelType.fuelTypeId}, Name: ${fuelType.name}');
            }
          } else {
            print('PROFILE_SCREEN: Failed to load pump fuel types: ${pumpFuelTypesResponse.errorMessage}');
          }
        }
      }
      
      setState(() {
        _isLoadingFuelTypes = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoadingFuelTypes = false;
      });
      print('PROFILE_SCREEN: Exception loading fuel types: $e');
    }
  }
  
  // Set initial form values from profile
  void _setFormValues() {
    if (_profile != null) {
      _contactNumberController.text = _profile!.contactNumber;
      _emailController.text = _profile!.email;
      _websiteController.text = _profile!.website;
      _gstNumberController.text = _profile!.gstNumber;
      _taxIdController.text = _profile!.taxId;
      _sapNoController.text = _profile!.sapNo;
      _selectedStatus = _profile!.isActive ? 'Active' : 'Inactive';
      
      // Parse selected fuel types
      if (_profile!.fuelTypesAvailable.isNotEmpty) {
        _selectedFuelTypeIds = _profile!.fuelTypesAvailable.split(',');
      } else {
        _selectedFuelTypeIds = [];
      }
    }
  }
  
  // Toggle edit mode
  void _toggleEditMode() async {
    if (!_isEditMode) {
      // If entering edit mode, load fuel types first
      await _loadFuelTypes();
    }
    
    setState(() {
      _isEditMode = !_isEditMode;
      
      // Reset form values if canceling edit
      if (!_isEditMode) {
        _setFormValues();
      }
    });
  }
  
  // Save profile changes
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Format the fuel types list properly 
      // Some APIs expect a comma-separated list without spaces
      final formattedFuelTypes = _selectedFuelTypeIds.join(',');
      
      print('PROFILE_SCREEN: Preparing to save with fuel types: $formattedFuelTypes');
      print('PROFILE_SCREEN: Number of selected fuel types: ${_selectedFuelTypeIds.length}');
      
      // Create updated profile object with only the editable fields changed
      final updatedProfile = PumpProfile(
        petrolPumpId: _profile!.petrolPumpId,
        name: _profile!.name,
        addressId: _profile!.addressId,
        licenseNumber: _profile!.licenseNumber,
        taxId: _taxIdController.text,
        openingTime: _profile!.openingTime,
        closingTime: _profile!.closingTime,
        isActive: _selectedStatus == 'Active',
        createdAt: _profile!.createdAt,
        updatedAt: DateTime.now(),
        companyName: _profile!.companyName,
        numberOfDispensers: _profile!.numberOfDispensers,
        fuelTypesAvailable: formattedFuelTypes,
        contactNumber: _contactNumberController.text,
        email: _emailController.text,
        website: _websiteController.text,
        gstNumber: _gstNumberController.text,
        licenseExpiryDate: _profile!.licenseExpiryDate,
        sapNo: _sapNoController.text,
      );
      
      print('PROFILE_SCREEN: Saving updated profile: ${updatedProfile.toJson()}');
      
      // The API may have limitations on the number of fuel types or other validation rules
      // Try sending the update with the maximum allowed fuel types
      final response = await _pumpRepository.updatePumpProfile(updatedProfile);
      
      if (!mounted) return;
      
      if (response.success) {
        // Reload profile data to ensure we have the latest
        await _loadPumpProfile();
        
        setState(() {
          _isSaving = false;
          _isEditMode = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isSaving = false;
          _errorMessage = response.errorMessage ?? 'Failed to update profile';
        });
        
        // Check for specific error messages that indicate limitations on fuel types
        if (_errorMessage.toLowerCase().contains('fuel') || 
            _selectedFuelTypeIds.length > 3) {
          // Try again with a limited number of fuel types (maximum 3)
          _showFuelTypeWarningDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isSaving = false;
        _errorMessage = 'Error: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Show warning dialog about fuel type limitations
  void _showFuelTypeWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Too Many Fuel Types'),
        content: const Text(
          'The API may have limitations on the number of fuel types that can be selected. '
          'Try selecting fewer fuel types (maximum 3) and save again.'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Petrol Pump Profile'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isLoading && _errorMessage.isEmpty && _profile != null)
            IconButton(
              icon: Icon(_isEditMode ? Icons.cancel : Icons.edit),
              color: Colors.white,
              onPressed: _toggleEditMode,
              tooltip: _isEditMode ? 'Cancel' : 'Edit profile',
            ),
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.save),
              color: Colors.white,
              onPressed: _isSaving ? null : _saveProfile,
              tooltip: 'Save changes',
            ),
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.refresh),
              color: Colors.white,
              onPressed: _loadPumpProfile,
              tooltip: 'Refresh profile',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : _profile == null
                  ? const Center(child: Text('Profile data is null'))
                  : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    // Debug information - verify that we have data
    final debugInfo = _profile!.name.isEmpty 
        ? Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠️ Profile data appears to be empty!', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 4),
                  Text('petrolPumpId: ${_profile!.petrolPumpId ?? 'null'}'),
                  Text('name: "${_profile!.name}"'),
                  Text('contactNumber: "${_profile!.contactNumber}"'),
                  Text('email: "${_profile!.email}"'),
                ],
              ),
            ),
          )
        : const SizedBox.shrink();

    return Form(
      key: _formKey,
      child: RefreshIndicator(
        onRefresh: _loadPumpProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Debug info box if name is empty
              debugInfo,
              
              // Header with logo and company name
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha:0.3),
                      blurRadius: 15,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo or placeholder
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha:0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_gas_station,
                        size: 50,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Pump name
                    Text(
                      _isEditMode ? 'Editing Profile' : _profile!.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    // Company name if different from pump name
                    // if (!_isEditMode && _profile!.companyName.isNotEmpty)
                    //   Text(
                    //     _profile!.companyName,
                    //     style: TextStyle(
                    //       fontSize: 18,
                    //       fontWeight: FontWeight.w500,
                    //       color: Colors.white.withValues(alpha:0.9),
                    //     ),
                    //     textAlign: TextAlign.center,
                    //   ),
                    const SizedBox(height: 8),
                    // Operational hours
                    if (!_isEditMode)
                      Text(
                        'Hours: ${_formatTime(_profile!.openingTime)} - ${_formatTime(_profile!.closingTime)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha:0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    // Edit mode indicator
                    if (_isEditMode)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha:0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Edit Mode', 
                          style: TextStyle(
                            color: Colors.white.withValues(alpha:0.9),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Profile details
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildProfileDetailsSection(),
              ),

              if (_isEditMode)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProfileDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic Information Section
        const Text(
          'Basic Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        
        // Contact Number - Editable
        _buildInfoCard(
          icon: Icons.phone,
          title: 'Contact Number',
          value: _profile!.contactNumber,
          color: Colors.green,
          isEditable: true,
          controller: _contactNumberController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 16),
        
        // Email - Editable
        _buildInfoCard(
          icon: Icons.email,
          title: 'Email Address',
          value: _profile!.email,
          color: Colors.orange,
          isEditable: true,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter email address';
            }
            if (!value.contains('@') || !value.contains('.')) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        // Website - Editable
        _buildInfoCard(
          icon: Icons.web,
          title: 'Website',
          value: _profile!.website,
          color: Colors.blue,
          isEditable: true,
          controller: _websiteController,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        
        // Number of dispensers - Non-editable
        _buildInfoCard(
          icon: Icons.local_gas_station,
          title: 'Number of Dispensers',
          value: _profile!.numberOfDispensers.toString(),
          color: AppTheme.primaryOrange,
        ),
        
        const SizedBox(height: 30),
        
        // Business Information Section
        const Text(
          'Business Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        
        // GST Number - Editable
        _buildInfoCard(
          icon: Icons.receipt_long,
          title: 'GST Number',
          value: _profile!.gstNumber.isEmpty ? 'Not Available' : _profile!.gstNumber,
          color: Colors.purple,
          isEditable: true,
          controller: _gstNumberController,
        ),
        const SizedBox(height: 16),
        
        // Tax ID - Editable
        _buildInfoCard(
          icon: Icons.account_balance,
          title: 'Tax ID',
          value: _profile!.taxId,
          color: Colors.teal,
          isEditable: true,
          controller: _taxIdController,
        ),
        const SizedBox(height: 16),
        
        // License Number - Non-editable
        _buildInfoCard(
          icon: Icons.card_membership,
          title: 'License Number',
          value: _profile!.licenseNumber,
          color: Colors.indigo,
        ),
        const SizedBox(height: 16),
        
        // License Expiry - Non-editable
        _buildInfoCard(
          icon: Icons.event,
          title: 'License Expiry Date',
          value: _profile!.licenseExpiryDate ?? 'Not Available',
          color: Colors.red,
        ),
        const SizedBox(height: 16),
          
        // SAP Number - Editable
        _buildInfoCard(
          icon: Icons.numbers,
          title: 'SAP Number',
          value: _profile!.sapNo,
          color: Colors.blueGrey,
          isEditable: true,
          controller: _sapNoController,
        ),
        
        const SizedBox(height: 30),
        
        // System Information Section
        const Text(
          'System Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        
        // Created & Updated dates - Non-editable
        _buildInfoCard(
          icon: Icons.calendar_today,
          title: 'Registered On',
          value: _profile!.createdAt != null ? _formatDate(_profile!.createdAt!) : 'Not Available',
          color: Colors.cyan,
        ),
        const SizedBox(height: 16),
        
        _buildInfoCard(
          icon: Icons.update,
          title: 'Last Updated On',
          value: _profile!.updatedAt != null ? _formatDate(_profile!.updatedAt!) : 'Not Available',
          color: Colors.amber,
        ),
        const SizedBox(height: 16),
        
        // Status - Editable with dropdown
        _buildStatusCard(),
        const SizedBox(height: 16),
        
        // Fuel Types - Editable
        _buildFuelTypesCard(),
        const SizedBox(height: 16),
        
        // ID info - Non-editable
        // _buildInfoCard(
        //   icon: Icons.tag,
        //   title: 'Petrol Pump ID',
        //   value: _profile!.petrolPumpId ?? 'Not Available',
        //   color: Colors.grey,
        // ),
      ],
    );
  }
  
  // Build status card with dropdown when in edit mode
  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.1),
            blurRadius: 5,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_profile!.isActive ? Colors.green : Colors.red).withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.info,
              color: _profile!.isActive ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                _isEditMode
                    ? DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          border: OutlineInputBorder(),
                        ),
                        items: _statusOptions.map((String status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedStatus = newValue ?? 'Inactive';
                          });
                        },
                      )
                    : Text(
                        _profile!.isActive ? 'Active' : 'Inactive',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Build fuel types card with dropdown in edit mode
  Widget _buildFuelTypesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.1),
            blurRadius: 5,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.deepOrange.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_gas_station,
              color: Colors.deepOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fuel Types Available',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (!_isEditMode && _fuelTypes.isEmpty)
                      InkWell(
                        onTap: () async {
                          if (_profile != null && _profile!.fuelTypesAvailable.isNotEmpty) {
                            final ids = _profile!.fuelTypesAvailable.split(',');
                            await _loadFuelTypesForDisplay(ids);
                          }
                        },
                        child: Icon(
                          Icons.refresh,
                          size: 18,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_isEditMode && _isLoadingFuelTypes)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_isEditMode)
                  _buildFuelTypeDropdown()
                else if (_fuelTypes.isEmpty && _profile!.fuelTypesAvailable.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Text(
                          _formatFuelTypes(_profile!.fuelTypesAvailable),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (_formatFuelTypes(_profile!.fuelTypesAvailable).contains('Loading'))
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  Text(
                    _formatFuelTypes(_profile!.fuelTypesAvailable),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Build multi-select dropdown for fuel types
  Widget _buildFuelTypeDropdown() {
    if (_fuelTypes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('No fuel types available'),
      );
    }

    // Calculate if we're near API limit (showing warnings)
    final int selectedCount = _selectedFuelTypeIds.length;
    final bool isNearLimit = selectedCount >= 3;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show warning if selecting many fuel types
        if (isNearLimit)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  size: 16,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The API appears to have limitations on the number of fuel types that can be selected. '
                    'For best results, limit your selection to 6 primary fuel types.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
        // Display currently selected fuel types
        if (_selectedFuelTypeIds.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show counter for selected types
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected Fuel Types',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '$selectedCount selected',
                      style: TextStyle(
                        fontSize: 12,
                        color: isNearLimit ? Colors.amber.shade700 : Colors.grey.shade600,
                        fontWeight: isNearLimit ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _selectedFuelTypeIds.map((id) {
                    // Find fuel type by ID
                    var fuelTypeName = 'Unknown';
                    var fuelTypeColor = '#CCCCCC';
                    
                    // Look in main fuel types list
                    final fuelType = _fuelTypes.firstWhereOrNull((ft) => ft.fuelTypeId == id);
                    if (fuelType != null) {
                      fuelTypeName = fuelType.name;
                      fuelTypeColor = fuelType.color ?? '#CCCCCC';
                    } else {
                      // Check in pump fuel types
                      final pumpFuelType = _pumpFuelTypes.firstWhereOrNull((ft) => ft.fuelTypeId == id);
                      if (pumpFuelType != null) {
                        fuelTypeName = pumpFuelType.name;
                        fuelTypeColor = pumpFuelType.color ?? '#CCCCCC';
                      } else {
                        // Debug log
                        print('PROFILE_SCREEN: Could not find details for fuel type ID: $id');
                      }
                    }
                    
                    // Try to determine a color for common fuel types if not provided
                    if (fuelTypeColor == '#CCCCCC') {
                      if (fuelTypeName.toLowerCase().contains('diesel')) {
                        fuelTypeColor = '#3366CC'; // Blue for diesel
                      } else if (fuelTypeName.toLowerCase().contains('petrol')) {
                        fuelTypeColor = '#33CC33'; // Green for petrol
                      } else if (fuelTypeName.toLowerCase().contains('cng')) {
                        fuelTypeColor = '#009999'; // Teal for CNG
                      } else if (fuelTypeName.toLowerCase().contains('lpg')) {
                        fuelTypeColor = '#FF9900'; // Orange for LPG
                      } else if (fuelTypeName.toLowerCase().contains('electric')) {
                        fuelTypeColor = '#6600CC'; // Purple for electric
                      }
                    }
                    
                    return Chip(
                      label: Text(fuelTypeName),
                      backgroundColor: _hexToColor(fuelTypeColor).withValues(alpha:0.1),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _selectedFuelTypeIds.remove(id);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),
        
        // List of available fuel types to select from
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Available Fuel Types',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              ..._fuelTypes
                .where((fuelType) => !_selectedFuelTypeIds.contains(fuelType.fuelTypeId))
                .map((fuelType) {
                  Color fuelColor = Colors.grey;
                  if (fuelType.color != null && fuelType.color!.isNotEmpty) {
                    fuelColor = _hexToColor(fuelType.color!);
                  } else {
                    // Assign standard colors for common fuel types
                    if (fuelType.name.toLowerCase().contains('diesel')) {
                      fuelColor = Colors.blue;
                    } else if (fuelType.name.toLowerCase().contains('petrol')) {
                      fuelColor = Colors.green;
                    } else if (fuelType.name.toLowerCase().contains('cng')) {
                      fuelColor = Colors.teal;
                    } else if (fuelType.name.toLowerCase().contains('lpg')) {
                      fuelColor = Colors.orange;
                    } else if (fuelType.name.toLowerCase().contains('electric')) {
                      fuelColor = Colors.purple;
                    }
                  }
                  
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (!_selectedFuelTypeIds.contains(fuelType.fuelTypeId)) {
                          _selectedFuelTypeIds.add(fuelType.fuelTypeId);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Row(
                        children: [
                          Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color: fuelColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(fuelType.name),
                          const Spacer(),
                          Icon(
                            Icons.add_circle_outline,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              if (_fuelTypes.where((fuelType) => !_selectedFuelTypeIds.contains(fuelType.fuelTypeId)).isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'All fuel types selected',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    bool isEditable = false,
    TextEditingController? controller,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.1),
            blurRadius: 5,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
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
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                if (_isEditMode && isEditable)
                  TextFormField(
                    controller: controller,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: keyboardType,
                    inputFormatters: inputFormatters,
                    validator: validator,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  )
                else
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
              ],
            ),
          ),
          if (_isEditMode && isEditable)
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Icon(
                Icons.edit,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  String _formatTime(String time) {
    // Handle time formats like "00:00:00"
    if (time.length >= 5) {
      final parts = time.split(':');
      if (parts.length >= 2) {
        int hour = int.tryParse(parts[0]) ?? 0;
        final minutes = parts[1];
        final period = hour >= 12 ? 'PM' : 'AM';
        
        if (hour > 12) {
          hour -= 12;
        } else if (hour == 0) {
          hour = 12;
        }
        
        return '$hour:$minutes $period';
      }
    }
    return time;
  }
  
  String _formatFuelTypes(String fuelTypesIds) {
    if (fuelTypesIds.isEmpty) {
      return 'None available';
    }
    
    // Parse the list of IDs
    final ids = fuelTypesIds.split(',');
    
    // If we have loaded fuel types, try to display their names
    if (_fuelTypes.isNotEmpty) {
      final fuelTypeNames = ids.map((id) {
        // Look for the fuel type in our loaded list
        final fuelType = _fuelTypes.firstWhereOrNull((ft) => ft.fuelTypeId == id);
        if (fuelType != null) {
          return fuelType.name;
        }
        
        // If not found in regular fuel types, check pump fuel types
        final pumpFuelType = _pumpFuelTypes.firstWhereOrNull((ft) => ft.fuelTypeId == id);
        if (pumpFuelType != null) {
          return pumpFuelType.name;
        }
        
        // If still not found, try to directly check if this ID matches one from the API data
        for (var type in [
          'Diesel', 
          'Petrol', 
          'Premium Petrol', 
          'CNG', 
          'LPG',
          'Bio-Diesel',
          'Electric'
        ]) {
          if (id.toLowerCase().contains(type.toLowerCase())) {
            return type;
          }
        }
        
        // Log the ID we couldn't resolve for debugging
        print('PROFILE_SCREEN: Could not find fuel type name for ID: $id');
        
        return 'Unknown';
      }).toList();
      
      return fuelTypeNames.join(', ');
    } else {
      // If fuel types aren't loaded yet, try to load them now
      _loadFuelTypesForDisplay(ids);
      
      // Return a temporary placeholder while loading
      return 'Loading fuel types...';
    }
  }
  
  // Load fuel types specifically for display purposes
  Future<void> _loadFuelTypesForDisplay(List<String> fuelTypeIds) async {
    try {
      // Get all available fuel types
      final allFuelTypesResponse = await _pumpRepository.getFuelTypes();
      
      if (!mounted) return;
      
      if (allFuelTypesResponse.success && allFuelTypesResponse.data != null) {
        setState(() {
          _fuelTypes = allFuelTypesResponse.data!;
        });
        
        print('PROFILE_SCREEN: Dynamically loaded ${_fuelTypes.length} fuel types for display');
      } else {
        print('PROFILE_SCREEN: Failed to dynamically load fuel types: ${allFuelTypesResponse.errorMessage}');
      }
    } catch (e) {
      print('PROFILE_SCREEN: Exception dynamically loading fuel types: $e');
    }
  }
  
  // Helper to convert hex color string to Color
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
} 