import 'package:intl/intl.dart';

class VehicleTransaction {
  final String? vehicleTransactionId;
  final String? petrolPumpId;
  final String vehicleNumber;
  final String driverName;
  final double litersPurchased;
  final double pricePerLiter;
  final double totalAmount;
  final String paymentMode;
  final DateTime transactionDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String customerId;
  final String fuelTypeId;
  final int slipNumber;
  final String? customerName;
  final String? customerPhone;
  final String? customerType;
  final String? petrolPumpName;
  final String? fuelTypeName;
  final double? outstandingBalance;
  final bool? isWithinCreditLimit;
  final String? transactionSummary;
  final List<CustomerTransaction>? relatedCustomerTransactions;
  final String? notes;
  final bool? validateCreditLimit;

  VehicleTransaction({
    this.vehicleTransactionId,
    this.petrolPumpId,
    required this.vehicleNumber,
    required this.driverName,
    required this.litersPurchased,
    required this.pricePerLiter,
    required this.totalAmount,
    required this.paymentMode,
    required this.transactionDate,
    this.createdAt,
    this.updatedAt,
    required this.customerId,
    required this.fuelTypeId,
    required this.slipNumber,
    this.customerName,
    this.customerPhone,
    this.customerType,
    this.petrolPumpName,
    this.fuelTypeName,
    this.outstandingBalance,
    this.isWithinCreditLimit,
    this.transactionSummary,
    this.relatedCustomerTransactions,
    this.notes,
    this.validateCreditLimit,
  });

  factory VehicleTransaction.fromJson(Map<String, dynamic> json) {
    return VehicleTransaction(
      vehicleTransactionId: json['vehicleTransactionId'],
      petrolPumpId: json['petrolPumpId'],
      vehicleNumber: json['vehicleNumber'] ?? '',
      driverName: json['driverName'] ?? '',
      litersPurchased: (json['litersPurchased'] ?? 0).toDouble(),
      pricePerLiter: (json['pricePerLiter'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      paymentMode: json['paymentMode'] ?? '',
      transactionDate: DateTime.parse(json['transactionDate'] ?? DateTime.now().toIso8601String()),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      customerId: json['customerId'] ?? '',
      fuelTypeId: json['fuelTypeId'] ?? '',
      slipNumber: json['slipNumber'] ?? 0,
      customerName: json['customerName'],
      customerPhone: json['customerPhone'],
      customerType: json['customerType'],
      petrolPumpName: json['petrolPumpName'],
      fuelTypeName: json['fuelTypeName'],
      outstandingBalance: json['outstandingBalance']?.toDouble(),
      isWithinCreditLimit: json['isWithinCreditLimit'],
      transactionSummary: json['transactionSummary'],
      relatedCustomerTransactions: json['relatedCustomerTransactions'] != null
          ? (json['relatedCustomerTransactions'] as List)
              .map((item) => CustomerTransaction.fromJson(item))
              .toList()
          : null,
      notes: json['notes'],
      validateCreditLimit: json['validateCreditLimit'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (vehicleTransactionId != null) 'vehicleTransactionId': vehicleTransactionId,
      if (petrolPumpId != null) 'petrolPumpId': petrolPumpId,
      'vehicleNumber': vehicleNumber,
      'driverName': driverName,
      'litersPurchased': litersPurchased,
      'pricePerLiter': pricePerLiter,
      'totalAmount': totalAmount,
      'paymentMode': paymentMode,
      'transactionDate': transactionDate.toIso8601String(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      'customerId': customerId,
      'fuelTypeId': fuelTypeId,
      'slipNumber': slipNumber,
      if (customerName != null) 'customerName': customerName,
      if (customerPhone != null) 'customerPhone': customerPhone,
      if (customerType != null) 'customerType': customerType,
      if (petrolPumpName != null) 'petrolPumpName': petrolPumpName,
      if (fuelTypeName != null) 'fuelTypeName': fuelTypeName,
      if (outstandingBalance != null) 'outstandingBalance': outstandingBalance,
      if (isWithinCreditLimit != null) 'isWithinCreditLimit': isWithinCreditLimit,
      if (transactionSummary != null) 'transactionSummary': transactionSummary,
      if (relatedCustomerTransactions != null)
        'relatedCustomerTransactions': relatedCustomerTransactions!.map((e) => e.toJson()).toList(),
      if (notes != null) 'notes': notes,
      if (validateCreditLimit != null) 'validateCreditLimit': validateCreditLimit,
    };
  }

  // Helper methods for formatting
  String get formattedTransactionDate => DateFormat('dd MMM yyyy, hh:mm a').format(transactionDate);
  String get formattedCreatedAt => createdAt != null 
      ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt!)
      : 'N/A';
  String get formattedUpdatedAt => updatedAt != null 
      ? DateFormat('dd MMM yyyy, hh:mm a').format(updatedAt!)
      : 'N/A';
  String get formattedTotalAmount => '₹${totalAmount.toStringAsFixed(2)}';
  String get formattedPricePerLiter => '₹${pricePerLiter.toStringAsFixed(2)}';
  String get formattedLitersPurchased => '${litersPurchased.toStringAsFixed(2)}L';
}

class CustomerTransaction {
  final String? customerTransactionId;
  final String? vehicleTransactionId;
  final String? customerPhone;
  final double litersPurchased;
  final double totalAmount;
  final double amountPaid;
  final double balance;
  final String paymentMode;
  final DateTime transactionDate;
  final String? invoiceNumber;
  final String? fuelType;

  CustomerTransaction({
    this.customerTransactionId,
    this.vehicleTransactionId,
    this.customerPhone,
    required this.litersPurchased,
    required this.totalAmount,
    required this.amountPaid,
    required this.balance,
    required this.paymentMode,
    required this.transactionDate,
    this.invoiceNumber,
    this.fuelType,
  });

  factory CustomerTransaction.fromJson(Map<String, dynamic> json) {
    return CustomerTransaction(
      customerTransactionId: json['customerTransactionId'],
      vehicleTransactionId: json['vehicleTransactionId'],
      customerPhone: json['customerPhone'],
      litersPurchased: (json['litersPurchased'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      amountPaid: (json['amountPaid'] ?? 0).toDouble(),
      balance: (json['balance'] ?? 0).toDouble(),
      paymentMode: json['paymentMode'] ?? '',
      transactionDate: DateTime.parse(json['transactionDate'] ?? DateTime.now().toIso8601String()),
      invoiceNumber: json['invoiceNumber'],
      fuelType: json['fuelType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (customerTransactionId != null) 'customerTransactionId': customerTransactionId,
      if (vehicleTransactionId != null) 'vehicleTransactionId': vehicleTransactionId,
      if (customerPhone != null) 'customerPhone': customerPhone,
      'litersPurchased': litersPurchased,
      'totalAmount': totalAmount,
      'amountPaid': amountPaid,
      'balance': balance,
      'paymentMode': paymentMode,
      'transactionDate': transactionDate.toIso8601String(),
      if (invoiceNumber != null) 'invoiceNumber': invoiceNumber,
      if (fuelType != null) 'fuelType': fuelType,
    };
  }

  // Helper methods for formatting
  String get formattedTransactionDate => DateFormat('dd MMM yyyy, hh:mm a').format(transactionDate);
  String get formattedTotalAmount => '₹${totalAmount.toStringAsFixed(2)}';
  String get formattedAmountPaid => '₹${amountPaid.toStringAsFixed(2)}';
  String get formattedBalance => '₹${balance.toStringAsFixed(2)}';
  String get formattedLitersPurchased => '${litersPurchased.toStringAsFixed(2)}L';
}
