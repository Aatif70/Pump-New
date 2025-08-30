import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petrol_pump/api/fuel_delivery_repository.dart';
import 'package:petrol_pump/models/fuel_delivery_model.dart';
import 'package:petrol_pump/theme.dart';

class FuelDeliveryHistoryScreen extends StatefulWidget {
  const FuelDeliveryHistoryScreen({super.key});

  @override
  State<FuelDeliveryHistoryScreen> createState() => _FuelDeliveryHistoryScreenState();
}

class _FuelDeliveryHistoryScreenState extends State<FuelDeliveryHistoryScreen> {
  final _fuelDeliveryRepository = FuelDeliveryRepository();
  bool _isLoading = true;
  List<FuelDeliveryOrder> _deliveryOrders = [];
  List<FuelDeliveryOrder> _filteredDeliveryOrders = [];
  String _errorMessage = '';
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDeliveryOrders();
    
    // Add listener to search controller
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    _filterDeliveryOrders(_searchController.text);
  }
  
  void _filterDeliveryOrders(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      
      if (_searchQuery.isEmpty) {
        // If search is empty, show all orders
        _filteredDeliveryOrders = List.from(_deliveryOrders);
      } else {
        // Filter orders based on search query
        _filteredDeliveryOrders = _deliveryOrders.where((order) {
          return order.invoiceNumber.toLowerCase().contains(_searchQuery) ||
                 order.supplierName.toLowerCase().contains(_searchQuery) ||
                 order.truckNumber.toLowerCase().contains(_searchQuery) ||
                 order.driverName.toLowerCase().contains(_searchQuery) ||
                 order.deliveryStatus.toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }
  
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filterDeliveryOrders('');
      }
    });
  }

  Future<void> _loadDeliveryOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _fuelDeliveryRepository.getAllFuelDeliveryOrders();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success && response.data != null) {
            _deliveryOrders = response.data!;
            // Sort by delivery date, newest first
            _deliveryOrders.sort((a, b) => b.deliveryDate.compareTo(a.deliveryDate));
            // Initialize filtered list with all orders
            _filteredDeliveryOrders = List.from(_deliveryOrders);
          } else {
            _errorMessage = response.errorMessage ?? 'Failed to load fuel delivery orders';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: _isSearching 
          ? _buildSearchField() 
          : const Text('Fuel Delivery Orders'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          // Search button
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
            color: Colors.white,
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeliveryOrders,
            color: Colors.white,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDeliveryOrders,
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
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
                            onPressed: _loadDeliveryOrders,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildDeliveryOrdersList(),
      ),
    );
  }
  
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: "Search by invoice, supplier, truck, driver...",
        hintStyle: const TextStyle(color: Colors.white70),
        border: InputBorder.none,
        prefixIcon: const Icon(Icons.search, color: Colors.white70),
        suffixIcon: _searchController.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear, color: Colors.white70),
              onPressed: () {
                _searchController.clear();
                _filterDeliveryOrders('');
              },
            )
          : null,
      ),
      style: const TextStyle(color: Colors.white, fontSize: 16),
      cursorColor: Colors.white,
    );
  }
  
  Widget _buildDeliveryOrdersList() {
    if (_filteredDeliveryOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.local_shipping,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No matching delivery orders found'
                  : 'No fuel delivery orders found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Add a new delivery order to see it here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredDeliveryOrders.length,
      itemBuilder: (context, index) {
        final order = _filteredDeliveryOrders[index];
        return _buildDeliveryOrderCard(order);
      },
    );
  }

  Widget _buildDeliveryOrderCard(FuelDeliveryOrder order) {
    // Status color based on the delivery status
    Color statusColor = _getStatusColor(order.deliveryStatus);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha:0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section with delivery status and invoice number
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha:0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha:0.2),
                            blurRadius: 5,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        _getStatusIcon(order.deliveryStatus),
                        color: statusColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      order.invoiceNumber,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha:0.1),
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: statusColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.deliveryStatus,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Card body with improved layout
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order details in a grid format with modern styling
                Row(
                  children: [
                    // Supplier metric
                    Expanded(
                      child: _buildMetricBox(
                        'Supplier',
                        order.supplierName,
                        Icons.business,
                        Colors.purple.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Date metric
                    Expanded(
                      child: _buildMetricBox(
                        'Delivery Date',
                        DateFormat('dd MMM yyyy').format(order.deliveryDate),
                        Icons.calendar_today,
                        Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    // Driver metric
                    Expanded(
                      child: _buildMetricBox(
                        'Driver',
                        order.driverName,
                        Icons.person,
                        Colors.indigo.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Truck number metric
                    Expanded(
                      child: _buildMetricBox(
                        'Truck Number',
                        order.truckNumber,
                        Icons.local_shipping,
                        Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Compartment completion status with progress bar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Delivery Progress', Icons.bar_chart),
                      const SizedBox(height: 12),
                      
                      // Compartment metrics
                      Row(
                        children: [
                          // Completed compartments
                          Expanded(
                            child: _buildSpecItem(
                              'Completed',
                              '${order.completedCompartments} / ${order.totalCompartments}',
                              Icons.check_circle,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Total quantity
                          Expanded(
                            child: _buildSpecItem(
                              'Total Quantity',
                              '${order.totalCompartmentQuantity.toStringAsFixed(0)} L',
                              Icons.water_drop,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Completion percentage with modern styling
                      Row(
                        children: [
                          Icon(
                            Icons.percent,
                            size: 14,
                            color: _getCompletionColor(order.completionPercentage),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Completion',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${order.completionPercentage}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _getCompletionColor(order.completionPercentage),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: order.completionPercentage / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getCompletionColor(order.completionPercentage),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Compartments list
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Compartments', Icons.view_list),
                      const SizedBox(height: 8),
                      
                      // List of compartments
                      ...order.orderDetails.map((detail) => _buildCompartmentItem(detail)).toList(),
                    ],
                  ),
                ),
                
                // Notes section (if available)
                if (order.notes != null && order.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Notes', Icons.note),
                        const SizedBox(height: 8),
                        Text(
                          order.notes!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompartmentItem(FuelDeliveryOrderDetail detail) {
    Color fuelColor = _getFuelTypeColor(detail.fuelType);
    Color statusColor = _getStatusColor(detail.deliveryStatus);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Compartment number and fuel type
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: fuelColor.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'C${detail.compartmentNumber}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: fuelColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    detail.fuelType,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: fuelColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  detail.deliveryStatus,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Quantity and tank info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.water_drop, size: 14, color: Colors.grey.shade700),
                  const SizedBox(width: 4),
                  Text(
                    '${detail.quantityInCompartment.toStringAsFixed(0)} L',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.store, size: 14, color: Colors.grey.shade700),
                  const SizedBox(width: 4),
                  Text(
                    detail.fuelTankName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              
              // Delivery percentage if started
              if (detail.deliveryPercentage > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getCompletionColor(detail.deliveryPercentage).withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${detail.deliveryPercentage}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getCompletionColor(detail.deliveryPercentage),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppTheme.primaryBlue,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  // Modern metric box similar to fuel tank screen
  Widget _buildMetricBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha:0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label with icon
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Value
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  // Specification item with simple styling
  Widget _buildSpecItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade700,
        ),
        const SizedBox(width: 8),
        Column(
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getFuelTypeColor(String fuelType) {
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
  
  // Get color based on delivery status
  Color _getStatusColor(String status) {
    switch(status.toLowerCase()) {
      case 'completed':
        return Colors.green.shade600;
      case 'in-progress':
      case 'in progress':
        return Colors.blue.shade600;
      case 'pending':
        return Colors.orange.shade600;
      case 'cancelled':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
  
  // Get icon based on delivery status
  IconData _getStatusIcon(String status) {
    switch(status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'in-progress':
      case 'in progress':
        return Icons.timelapse;
      case 'pending':
        return Icons.pending;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
  
  // Get color based on completion percentage
  Color _getCompletionColor(int percentage) {
    if (percentage <= 20) {
      return Colors.red;
    } else if (percentage <= 40) {
      return Colors.orange;
    } else if (percentage <= 60) {
      return Colors.yellow.shade700;
    } else if (percentage <= 80) {
      return Colors.lightGreen;
    } else {
      return Colors.green;
    }
  }
} 