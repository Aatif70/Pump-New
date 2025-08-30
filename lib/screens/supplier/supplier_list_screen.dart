import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petrol_pump/models/supplier_model.dart';
import 'package:petrol_pump/api/supplier_repository.dart';
import 'package:petrol_pump/theme.dart';
import 'add_supplier_screen.dart';
import 'edit_supplier_screen.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> with SingleTickerProviderStateMixin {
  final _supplierRepository = SupplierRepository();
  bool _isLoading = true;
  List<Supplier> _suppliers = [];
  String _errorMessage = '';
  
  // Animation controller for stats cards
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _loadSuppliers();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _supplierRepository.getAllSuppliers();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success && response.data != null) {
            _suppliers = response.data!;
            _animationController.reset();
            _animationController.forward();
          } else {
            _errorMessage = response.errorMessage ?? 'Failed to load suppliers';
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

  void _navigateToEditSupplier(Supplier supplier) async {
    print('SUPPLIER_LIST: Navigating to Edit Supplier screen for ${supplier.supplierName}');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditSupplierScreen(supplier: supplier),
      ),
    );
    
    // Refresh the list if successful edit
    if (result == true) {
      _loadSuppliers();
    }
  }
  
  void _deleteSupplier(Supplier supplier) async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete ${supplier.supplierName}?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. All data related to this supplier will be permanently deleted.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!shouldDelete) return;
    
    // Check if supplier has a valid ID
    if (supplier.supplierDetailId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete supplier: Missing supplier ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await _supplierRepository.deleteSupplier(supplier.supplierDetailId!);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Supplier deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadSuppliers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete supplier: ${response.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
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
  }
  
  void _showSupplierDetails(Supplier supplier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle and header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        // Title with status badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.business,
                                  color: AppTheme.primaryBlue,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  supplier.supplierName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: supplier.isActive ? Colors.green.shade100 : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: supplier.isActive ? Colors.green.shade300 : Colors.red.shade300,
                                ),
                              ),
                              child: Text(
                                supplier.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  color: supplier.isActive ? Colors.green.shade700 : Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Business Information Card
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black.withValues(alpha:0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(alpha:0.1),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.business_center,
                                      color: AppTheme.primaryBlue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Business Information',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Content
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    _buildDetailRow('GST Number', supplier.gstNumber, Icons.receipt_long),
                                    const Divider(height: 24),
                                    _buildDetailRow('Contact Person', supplier.contactPerson, Icons.person),
                                    const Divider(height: 24),
                                    _buildDetailRow('Phone', supplier.phoneNumber, Icons.phone),
                                    const Divider(height: 24),
                                    _buildDetailRow('Email', supplier.email, Icons.email),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Location Information Card
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black.withValues(alpha:0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha:0.1),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: Colors.amber.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Location Details',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Content
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    _buildDetailRow('Address', supplier.address, Icons.home),
                                    const Divider(height: 24),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDetailRow('City', supplier.city, Icons.location_city),
                                        ),
                                        Expanded(
                                          child: _buildDetailRow('State', supplier.state, Icons.map),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    _buildDetailRow('ZIP Code', supplier.zipCode, Icons.pin),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _navigateToEditSupplier(supplier);
                                },
                                icon: const Icon(Icons.edit),
                                label: const Text('EDIT'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryBlue,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: AppTheme.primaryBlue),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _deleteSupplier(supplier);
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('DELETE'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: Colors.grey.shade700),
        ),
        const SizedBox(width: 16),
        Expanded(
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
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Build modern stat card for header
  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool isAlert = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.15),
          borderRadius: BorderRadius.circular(12),
          border: isAlert ? Border.all(color: Colors.amber, width: 1.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha:0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyView() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No suppliers found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add a supplier',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddSupplierScreen(),
            ),
          ).then((_) => _loadSuppliers());
        },
              icon: const Icon(Icons.add),
              label: const Text('Add Supplier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorView() {
    return Expanded(
      child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade700,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _loadSuppliers,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Suppliers'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSuppliers,
            color: Colors.white,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryBlue,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddSupplierScreen(),
            ),
          ).then((_) => _loadSuppliers());
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSuppliers,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Header section with stats
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                    child: FadeTransition(
                      opacity: _fadeInAnimation,
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats cards in a row
                          Row(
                          children: [
                              _buildStatCard(
                                'Total',
                                _suppliers.length.toString(),
                                Icons.business_center,
                                Colors.white,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                'Active',
                                _suppliers.where((s) => s.isActive).length.toString(),
                                Icons.check_circle_outline,
                                Colors.greenAccent.shade100,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                'Inactive',
                                _suppliers.where((s) => !s.isActive).length.toString(),
                                Icons.cancel_outlined,
                                Colors.redAccent.shade100,
                              ),
                            ],
                            ),
                          ],
                        ),
                    ),
                  ),
                  
                  // Error, empty view, or list
                  _errorMessage.isNotEmpty
                      ? _buildErrorView()
                      : _suppliers.isEmpty
                          ? _buildEmptyView()
                          : Expanded(
                              child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _suppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = _suppliers[index];
                                  return _buildSupplierCard(supplier, index);
                        },
                              ),
                            ),
                ],
                      ),
      ),
    );
  }

  Widget _buildSupplierCard(Supplier supplier, int index) {
    // Add staggered animation based on index
    final delay = Duration(milliseconds: 100 * index);
    
    return FutureBuilder(
      future: Future.delayed(delay),
      builder: (context, snapshot) {
        return AnimatedOpacity(
          opacity: snapshot.connectionState == ConnectionState.done ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          child: AnimatedPadding(
            padding: snapshot.connectionState == ConnectionState.done 
                ? EdgeInsets.zero
                : const EdgeInsets.only(top: 20),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            child: Dismissible(
              key: Key(supplier.supplierDetailId ?? UniqueKey().toString()),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Supplier'),
                    content: Text('Are you sure you want to delete ${supplier.supplierName}?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ) ?? false;
              },
              onDismissed: (direction) {
                _deleteSupplier(supplier);
              },
              child: Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
                shadowColor: Colors.black.withValues(alpha:0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
                child: InkWell(
                  onTap: () => _showSupplierDetails(supplier),
                  borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                                color: AppTheme.primaryOrange.withValues(alpha:0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.business,
                                color: AppTheme.primaryOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.supplierName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'GST: ${supplier.gstNumber}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: supplier.isActive ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: supplier.isActive ? Colors.green.shade300 : Colors.red.shade300,
                                ),
                  ),
                  child: Text(
                    supplier.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: supplier.isActive ? Colors.green.shade700 : Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
                        
                        const SizedBox(height: 12),
                        
                        // Contact info box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildContactInfo(
                                      Icons.person,
                                      supplier.contactPerson,
                                      AppTheme.primaryBlue,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildContactInfo(
                                      Icons.phone,
                                      supplier.phoneNumber,
                                      Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildContactInfo(
                                Icons.email,
                                supplier.email,
                                Colors.orange.shade700,
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Location info
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${supplier.address}, ${supplier.city}, ${supplier.state} - ${supplier.zipCode}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
            
            // Actions
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                              onPressed: () => _navigateToEditSupplier(supplier),
                              icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    side: BorderSide(color: AppTheme.primaryBlue),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
                            const SizedBox(width: 8),
                //             OutlinedButton.icon(
                //               onPressed: () => _deleteSupplier(supplier),
                //               icon: const Icon(Icons.delete_outline, size: 16),
                //               label: const Text('Delete'),
                //               style: OutlinedButton.styleFrom(
                //                 foregroundColor: Colors.red,
                //                 side: const BorderSide(color: Colors.red),
                //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                //   ),
                // ),
              ],
            ),
          ],
        ),
      ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactInfo(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
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
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 