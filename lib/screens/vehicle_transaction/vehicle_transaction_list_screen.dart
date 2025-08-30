import 'package:flutter/material.dart';
import 'package:petrol_pump/api/vehicle_transaction_repository.dart';
import 'package:petrol_pump/api/customer_repository.dart';
import 'package:petrol_pump/api/fuel_type_repository.dart';
import 'package:petrol_pump/models/vehicle_transaction_model.dart';
import 'package:petrol_pump/models/customer_model.dart';
import 'package:petrol_pump/models/fuel_type_model.dart';
import 'package:petrol_pump/theme.dart';
import 'package:petrol_pump/utils/shared_prefs.dart';
import 'package:petrol_pump/utils/jwt_decoder.dart';

import 'package:petrol_pump/widgets/error_message.dart';

import 'package:intl/intl.dart';
import 'add_vehicle_transaction_screen.dart';

class VehicleTransactionListScreen extends StatefulWidget {
  const VehicleTransactionListScreen({super.key});

  @override
  State<VehicleTransactionListScreen> createState() => _VehicleTransactionListScreenState();
}

class _VehicleTransactionListScreenState extends State<VehicleTransactionListScreen> {
  final VehicleTransactionRepository _repository = VehicleTransactionRepository();
  final CustomerRepository _customerRepository = CustomerRepository();
  final FuelTypeRepository _fuelTypeRepository = FuelTypeRepository();

  List<VehicleTransaction> _transactions = [];
  List<Customer> _customers = [];
  List<FuelType> _fuelTypes = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String? _petrolPumpId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get petrol pump ID from JWT token
      final token = await SharedPrefs.getAuthToken();
      if (token != null) {
        _petrolPumpId = JwtDecoder.getClaim<String>(token, 'petrolPumpId');
      }

      if (_petrolPumpId == null || _petrolPumpId!.isEmpty) {
        setState(() {
          _errorMessage = 'Petrol pump ID not found. Please login again.';
          _isLoading = false;
        });
        return;
      }

      // Load vehicle transactions
      final transactionResponse = await _repository.getVehicleTransactions(_petrolPumpId!);
      
      // Load customers for dropdown
      final customerResponse = await _customerRepository.getAllCustomers();
      
      // Load fuel types for dropdown
      final fuelTypeResponse = await _fuelTypeRepository.getAllFuelTypes();

      if (!mounted) return;

      if (transactionResponse.success) {
        setState(() {
          _transactions = transactionResponse.data ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = transactionResponse.errorMessage ?? 'Failed to load vehicle transactions';
          _isLoading = false;
        });
      }

      // Store customers and fuel types for add transaction screen
      if (customerResponse.success) {
        _customers = customerResponse.data ?? [];
      }
      
      if (fuelTypeResponse.success) {
        _fuelTypes = fuelTypeResponse.data ?? [];
      }

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _showAddTransactionScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddVehicleTransactionScreen(
          customers: _customers,
          fuelTypes: _fuelTypes,
          petrolPumpId: _petrolPumpId!,
        ),
      ),
    ).then((_) {
      // Refresh data when returning from add screen
      _loadData();
    });
  }

  void _showTransactionDetails(VehicleTransaction transaction) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Transaction Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Vehicle Number', transaction.vehicleNumber),
                _buildDetailRow('Driver Name', transaction.driverName),
                _buildDetailRow('Customer', transaction.customerName ?? 'N/A'),
                _buildDetailRow('Fuel Type', transaction.fuelTypeName ?? 'N/A'),
                _buildDetailRow('Liters', transaction.formattedLitersPurchased),
                _buildDetailRow('Price/Liter', transaction.formattedPricePerLiter),
                _buildDetailRow('Total Amount', transaction.formattedTotalAmount),
                _buildDetailRow('Payment Mode', transaction.paymentMode),
                _buildDetailRow('Slip Number', transaction.slipNumber.toString()),
                _buildDetailRow('Transaction Date', transaction.formattedTransactionDate),
                if (transaction.outstandingBalance != null)
                  _buildDetailRow('Outstanding Balance', '₹${transaction.outstandingBalance!.toStringAsFixed(2)}'),
                if (transaction.notes != null && transaction.notes!.isNotEmpty)
                  _buildDetailRow('Notes', transaction.notes!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPaymentModeColor(String paymentMode) {
    switch (paymentMode.toLowerCase()) {
      case 'cash':
        return Colors.green;
      case 'credit':
        return Colors.orange;
      case 'upi':
        return Colors.blue;
      case 'card':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getFuelTypeColor(String name) {
    switch (name.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Vehicle Transactions',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.refresh_rounded, size: 20),
              ),
              color: Colors.white,
              onPressed: _loadData,
              tooltip: 'Refresh data',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
          : _errorMessage.isNotEmpty
              ? ErrorMessage(
                  message: _errorMessage,
                  onRetry: _loadData,
                )
              : _transactions.isEmpty
                  ? _buildEmptyState()
                  : _buildTransactionList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTransactionScreen,
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add Vehicle Transaction',
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Vehicle Transactions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by adding your first vehicle transaction',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddTransactionScreen,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Transaction'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final transaction = _transactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildTransactionCard(VehicleTransaction transaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () => _showTransactionDetails(transaction),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getFuelTypeColor(transaction.fuelTypeName ?? '').withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.local_gas_station_rounded,
                      color: _getFuelTypeColor(transaction.fuelTypeName ?? ''),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.vehicleNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          transaction.driverName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getPaymentModeColor(transaction.paymentMode).withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.payments_rounded,
                          color: _getPaymentModeColor(transaction.paymentMode),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          transaction.paymentMode,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getPaymentModeColor(transaction.paymentMode),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Customer',
                      transaction.customerName ?? 'N/A',
                      Icons.person_outline,
                      Colors.indigo.shade600,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      'Fuel Type',
                      transaction.fuelTypeName ?? 'N/A',
                      Icons.local_gas_station_outlined,
                      _getFuelTypeColor(transaction.fuelTypeName ?? ''),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Liters',
                      transaction.formattedLitersPurchased,
                      Icons.water_drop_outlined,
                      Colors.blue.shade700,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      'Amount',
                      transaction.formattedTotalAmount,
                      Icons.currency_rupee,
                      Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Slip #',
                      transaction.slipNumber.toString(),
                      Icons.receipt_outlined,
                      Colors.orange.shade700,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      'Date',
                      DateFormat('dd MMM yyyy').format(transaction.transactionDate),
                      Icons.calendar_today_outlined,
                      Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              if (transaction.outstandingBalance != null && transaction.outstandingBalance! > 0)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Outstanding: ₹${transaction.outstandingBalance!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
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

  Widget _buildInfoItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
