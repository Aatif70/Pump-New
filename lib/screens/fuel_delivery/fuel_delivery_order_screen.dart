import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/fuel_delivery_order_model.dart';
import '../../api/fuel_delivery_order_repository.dart';
import '../../api/fuel_tank_repository.dart';
import '../../api/supplier_repository.dart';
import '../../models/fuel_tank_model.dart';
import '../../models/supplier_model.dart';
import '../../theme.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/loading_indicator.dart';

class FuelDeliveryOrderScreen extends StatefulWidget {
  const FuelDeliveryOrderScreen({super.key});

  @override
  State<FuelDeliveryOrderScreen> createState() => _FuelDeliveryOrderScreenState();
}

class _FuelDeliveryOrderScreenState extends State<FuelDeliveryOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = FuelDeliveryOrderRepository();
  final _fuelTankRepository = FuelTankRepository();
  final _supplierRepository = SupplierRepository();
  
  DateTime _deliveryDate = DateTime.now();
  final List<CompartmentDetail> _compartments = [];
  List<FuelTank> _fuelTanks = [];
  List<Supplier> _suppliers = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Form controllers
  final _invoiceNumberController = TextEditingController();
  String? _selectedSupplierId;
  final _truckNumberController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _driverContactController = TextEditingController();
  final _totalCompartmentsController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _addCompartment(); // Add initial compartment
    
    // Initialize total compartments controller with "1"
    _totalCompartmentsController.text = "1";
  }
  
  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _truckNumberController.dispose();
    _driverNameController.dispose();
    _driverContactController.dispose();
    _totalCompartmentsController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Load fuel tanks
      final tanksResponse = await _fuelTankRepository.getAllFuelTanks();
      if (!tanksResponse.success) {
        setState(() {
          _errorMessage = 'Failed to load fuel tanks: ${tanksResponse.errorMessage}';
          _isLoading = false;
        });
        return;
      }
      
      // Load suppliers
      final suppliersResponse = await _supplierRepository.getAllSuppliers();
      if (!suppliersResponse.success) {
        setState(() {
          _errorMessage = 'Failed to load suppliers: ${suppliersResponse.errorMessage}';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _fuelTanks = tanksResponse.data ?? [];
        _suppliers = suppliersResponse.data ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  void _addCompartment() {
    setState(() {
      _compartments.add(
        CompartmentDetail(
          compartmentNumber: _compartments.length + 1,
          fuelTankId: '',
          quantityInCompartment: 0,
          density: 0,
          temperature: 0,
          deliverySequence: _compartments.length + 1,
          notes: '',
        ),
      );
    });
  }
  
  void _removeCompartment(int index) {
    if (_compartments.length > 1) {
      setState(() {
        _compartments.removeAt(index);
        
        // Update compartment numbers and delivery sequence
        for (int i = 0; i < _compartments.length; i++) {
          _compartments[i].compartmentNumber = i + 1;
          _compartments[i].deliverySequence = i + 1;
        }
      });
    } else {
      showCustomSnackBar(
        context: context, 
        message: 'At least one compartment is required',
        isError: true,
      );
    }
  }
  
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_compartments.isEmpty) {
        showCustomSnackBar(
          context: context, 
          message: 'At least one compartment is required',
          isError: true,
        );
        return;
      }
      
      // Check if all fuel tank IDs are selected
      for (var compartment in _compartments) {
        if (compartment.fuelTankId.isEmpty) {
          showCustomSnackBar(
            context: context, 
            message: 'Please select fuel tank for all compartments',
            isError: true,
          );
          return;
        }
      }
      
      setState(() {
        _isLoading = true;
      });
      
      try {
        // Use total compartments from the actual compartments list if not manually set
        final totalCompartments = _totalCompartmentsController.text.isEmpty ? 
          _compartments.length : int.parse(_totalCompartmentsController.text);
            
        final order = FuelDeliveryOrder(
          compartmentDetails: _compartments,
          deliveryDate: _deliveryDate,
          invoiceNumber: _invoiceNumberController.text,
          supplierId: _selectedSupplierId!,
          truckNumber: _truckNumberController.text,
          driverName: _driverNameController.text,
          driverContactNumber: _driverContactController.text,
          totalCompartments: totalCompartments,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        );
        
        // Debug print statements
        print('===== DEBUGGING FUEL DELIVERY ORDER =====');
        print('Invoice Number: ${order.invoiceNumber}');
        print('Delivery Date: ${order.deliveryDate}');
        print('Supplier ID: ${order.supplierId}');
        print('Truck Number: ${order.truckNumber}');
        print('Driver Name: ${order.driverName}');
        print('Driver Contact: ${order.driverContactNumber}');
        print('Total Compartments: ${order.totalCompartments}');
        print('Notes: ${order.notes}');
        print('Compartment Details:');
        for (var i = 0; i < order.compartmentDetails.length; i++) {
          final comp = order.compartmentDetails[i];
          print('  Compartment #${i+1}:');
          print('    Compartment Number: ${comp.compartmentNumber}');
          print('    Fuel Tank ID: ${comp.fuelTankId}');
          print('    Quantity: ${comp.quantityInCompartment}');
          print('    Density: ${comp.density}');
          print('    Temperature: ${comp.temperature}');
          print('    Delivery Sequence: ${comp.deliverySequence}');
          print('    Notes: ${comp.notes}');
        }
        
        final response = await _repository.createFuelDeliveryOrder(order);
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          if (response.success) {
            showCustomSnackBar(
              context: context, 
              message: response.data ?? 'Order created successfully',
              isError: false,
            );
            Navigator.pop(context, true); // Return success to previous screen
          } else {
            showCustomSnackBar(
              context: context, 
              message: response.errorMessage ?? 'Failed to create order',
              isError: true,
            );
          }
        }
      } catch (e) {
        print('===== ERROR IN SUBMIT FORM =====');
        print(e.toString());
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          showCustomSnackBar(
            context: context, 
            message: 'Error creating order: ${e.toString()}',
            isError: true,
          );
        }
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
        appBar: null, // Remove app bar completely
        resizeToAvoidBottomInset: false, // Prevent resizing when keyboard appears
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
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: const Icon(Icons.arrow_back, size: 22),
                          ),
                        ),
                        // Order info
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Create Delivery Order',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Fill in delivery details below',
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
                  
                  // Form content
                  Expanded(
                    child: _buildForm(),
                  ),
                  
                  // Submit button
                  Padding(
                    padding: const EdgeInsets.all(26.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all( 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _submitForm,
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
                                const Icon(Icons.local_shipping_rounded, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Submit Order',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
  
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null)
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
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Section card for delivery details
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.local_shipping_rounded,
                          color: AppTheme.primaryBlue,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Delivery Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
            
            // Invoice Number
            TextFormField(
              controller: _invoiceNumberController,
              decoration: InputDecoration(
                labelText: 'Invoice Number',
                hintText: 'Enter invoice number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                prefixIcon: Icon(Icons.receipt_outlined, color: AppTheme.primaryBlue),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                floatingLabelBehavior: FloatingLabelBehavior.never,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter invoice number';
                }
                return null;
              },
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            
            // Delivery Date
            InkWell(
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _deliveryDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: AppTheme.primaryBlue,
                          onPrimary: Colors.white,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (pickedDate != null) {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_deliveryDate),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: AppTheme.primaryBlue,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (pickedTime != null) {
                    setState(() {
                      _deliveryDate = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                    });
                  }
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Delivery Date & Time',
                  hintText: 'Select date and time',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  prefixIcon: Icon(Icons.calendar_today, color: AppTheme.primaryBlue),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                ),
                child: Text(
                  DateFormat('MMM dd, yyyy - HH:mm').format(_deliveryDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Supplier
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Supplier',
                hintText: 'Select a supplier',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                prefixIcon: Icon(Icons.business, color: AppTheme.primaryBlue),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                floatingLabelBehavior: FloatingLabelBehavior.never,
              ),
              value: _selectedSupplierId,
              items: _suppliers.map((supplier) {
                return DropdownMenuItem<String>(
                  value: supplier.supplierDetailId,
                  child: Text(
                    supplier.supplierName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSupplierId = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a supplier';
                }
                return null;
              },
              icon: const Icon(Icons.arrow_drop_down_circle_outlined),
              isExpanded: true,
              dropdownColor: Colors.white,
            ),
            const SizedBox(height: 16),
            
            // Truck Number
            TextFormField(
              controller: _truckNumberController,
              decoration: InputDecoration(
                labelText: 'Truck Number',
                hintText: 'Enter truck number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                prefixIcon: Icon(Icons.local_shipping, color: AppTheme.primaryBlue),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                floatingLabelBehavior: FloatingLabelBehavior.never,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter truck number';
                }
                return null;
              },
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            
            // Driver Name
            TextFormField(
              controller: _driverNameController,
              decoration: InputDecoration(
                labelText: 'Driver Name',
                hintText: 'Enter driver name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryBlue),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                floatingLabelBehavior: FloatingLabelBehavior.never,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter driver name';
                }
                return null;
              },
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            
            // Driver Contact Number
            TextFormField(

              keyboardType: TextInputType.phone,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly
              ],

              controller: _driverContactController,
              decoration: InputDecoration(
                labelText: 'Driver Contact Number',
                hintText: 'Driver Contact Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.primaryBlue),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                floatingLabelBehavior: FloatingLabelBehavior.never,
              ),


              // keyboardType: TextInputType.phone,
              // validator: (value) {
              //   if (value == null || value.isEmpty) {
              //     return 'Please enter driver contact number';
              //   }
              //   return null;
              // },


              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            
            // Total Compartments
            // TextFormField(
            //   controller: _totalCompartmentsController,
            //   decoration: InputDecoration(
            //     labelText: 'Total Compartments',
            //     hintText: 'Enter number of compartments',
            //     border: OutlineInputBorder(
            //       borderRadius: BorderRadius.circular(16),
            //       borderSide: BorderSide.none,
            //     ),
            //     filled: true,
            //     fillColor: Colors.grey.shade100,
            //     prefixIcon: Icon(Icons.storage_outlined, color: AppTheme.primaryBlue),
            //     contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            //     floatingLabelBehavior: FloatingLabelBehavior.never,
            //   ),
            //   keyboardType: TextInputType.number,
            //   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            //   validator: (value) {
            //     if (value == null || value.isEmpty) {
            //       return 'Please enter total compartments';
            //     }
            //     return null;
            //   },
            //   style: const TextStyle(
            //     fontSize: 16,
            //     fontWeight: FontWeight.w500,
            //   ),
            // ),
            // const SizedBox(height: 16),
            
            // Notes
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Enter any additional notes',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                prefixIcon: Icon(Icons.note_outlined, color: AppTheme.primaryBlue),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                floatingLabelBehavior: FloatingLabelBehavior.never,
              ),
              maxLines: 3,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            ],
          ),
        ),
        const SizedBox(height: 24),
            
            // Compartment Details Section
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.water_drop_outlined,
                          color: Colors.green,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Compartment Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Compartments list
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _compartments.length,
                    itemBuilder: (context, index) {
                      return _buildCompartmentCard(index);
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Add Compartment Button
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _addCompartment,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(
                        'Add Compartment',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCompartmentCard(int index) {
    final compartment = _compartments[index];
    
    // Get color based on compartment number
    final List<Color> compartmentColors = [
      Colors.blue.shade700,
      Colors.green.shade700,
      Colors.orange.shade700,
      Colors.purple.shade700,
      Colors.teal.shade700,
    ];
    final Color compartmentColor = compartmentColors[index % compartmentColors.length];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: compartmentColor.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: compartmentColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: compartmentColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.water_drop_outlined,
                        color: compartmentColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Compartment #${index + 1}',
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: compartmentColor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade600, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(8),
                  ),
                  onPressed: () => _removeCompartment(index),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section label
                Container(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    "Select Tank",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: compartmentColor,
                    ),
                  ),
                ),
                
                // Fuel Tank Dropdown
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Fuel Tank',
                    hintText: 'Select a fuel tank',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    prefixIcon: Icon(Icons.propane_tank_outlined, color: compartmentColor),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  value: compartment.fuelTankId.isNotEmpty ? compartment.fuelTankId : null,
                  items: _fuelTanks.map((tank) {
                    return DropdownMenuItem<String>(
                      value: tank.fuelTankId,
                      child: Text(
                        'Tank: ${tank.fuelType}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _compartments[index].fuelTankId = value ?? '';
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a fuel tank';
                    }
                    return null;
                  },
                  icon: const Icon(Icons.arrow_drop_down_circle_outlined, size: 20),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                ),
                
                const SizedBox(height: 20),
                
                // Section label
                Container(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    "Quantity Information",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: compartmentColor,
                    ),
                  ),
                ),
                
                // Quantity field with better styling
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 4,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quantity
                      Text(
                        "Quantity in Liters",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: compartment.quantityInCompartment.toString(),
                        decoration: InputDecoration(
                          hintText: 'Enter fuel quantity',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          prefixIcon: Icon(Icons.water_drop_outlined, color: compartmentColor),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixText: 'L',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          _compartments[index].quantityInCompartment = double.tryParse(value) ?? 0;
                        },
                      ),
                      
                      const SizedBox(height: 4),
                      Text(
                        "Enter the exact quantity in liters for this compartment",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Section label for physical properties
                Container(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    "Physical Properties",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: compartmentColor,
                    ),
                  ),
                ),
                
                // Density and temperature fields in a card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 4,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row layout for density and temperature
                      Row(
                        children: [
                          // Density column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Density",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: compartment.density.toString(),
                                  decoration: InputDecoration(
                                    hintText: 'Enter density',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    prefixIcon: Icon(Icons.opacity_outlined, color: compartmentColor),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    suffixText: 'g/cm³',
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Invalid number';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    _compartments[index].density = double.tryParse(value) ?? 0;
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // Temperature column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Temperature (Optional)",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: compartment.temperature.toString(),
                                  decoration: InputDecoration(
                                    hintText: 'Enter temperature (optional)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    prefixIcon: Icon(Icons.device_thermostat_outlined, color: compartmentColor),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    suffixText: '°C',
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  // No validator since this field is optional
                                  onChanged: (value) {
                                    _compartments[index].temperature = double.tryParse(value) ?? 0;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      Text(
                        "Record density and temperature values for accurate measurements",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Section label for delivery sequence
                Container(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    "Delivery Information",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: compartmentColor,
                    ),
                  ),
                ),
                
                // Delivery sequence in a card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 4,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Delivery Sequence Number",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: compartment.deliverySequence.toString(),
                        decoration: InputDecoration(
                          hintText: 'Enter sequence number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          prefixIcon: Icon(Icons.format_list_numbered_outlined, color: compartmentColor),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          _compartments[index].deliverySequence = int.tryParse(value) ?? (index + 1);
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Order in which this compartment should be delivered/discharged",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Summary section
                const SizedBox(height: 20),
                if (compartment.quantityInCompartment > 0) 
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Compartment #${index + 1} Summary",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: compartmentColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Quantity:", style: TextStyle(fontWeight: FontWeight.w500)),
                            Text("${compartment.quantityInCompartment.toStringAsFixed(2)} L", 
                                 style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Divider(height: 16, color: Colors.grey.shade300),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Density:", style: TextStyle(fontWeight: FontWeight.w500)),
                            Text("${compartment.density.toStringAsFixed(4)} g/cm³",
                                 style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Divider(height: 16, color: Colors.grey.shade300),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Temperature:", style: TextStyle(fontWeight: FontWeight.w500)),
                            Text("${compartment.temperature.toStringAsFixed(2)} °C", 
                                 style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Divider(height: 16, color: Colors.grey.shade300),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Delivery sequence:", style: TextStyle(fontWeight: FontWeight.w500)),
                            Text("#${compartment.deliverySequence}", 
                                 style: TextStyle(fontWeight: FontWeight.bold)),
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
  
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
