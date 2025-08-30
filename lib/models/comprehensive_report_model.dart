class ComprehensiveReportResponse {
  final ComprehensiveReportData data;
  final bool success;
  final String message;
  final List<String>? validationErrors;

  ComprehensiveReportResponse({
    required this.data,
    required this.success,
    required this.message,
    this.validationErrors,
  });

  factory ComprehensiveReportResponse.fromJson(Map<String, dynamic> json) {
    return ComprehensiveReportResponse(
      data: ComprehensiveReportData.fromJson(json['data']),
      success: json['success'],
      message: json['message'],
      validationErrors: json['validationErrors'] != null
          ? List<String>.from(json['validationErrors'])
          : null,
    );
  }
}

class ComprehensiveReportData {
  final String stationName;
  final DateTime reportDate;
  final SalesDetails salesDetails;
  final NozzleDetails nozzleDetails;
  final ProductDetails productDetails;
  final PaymentDetails paymentDetails;
  final String petrolPumpId;
  final String petrolPumpName;
  final DateTime generatedAt;
  final String generatedBy;
  final DateTime reportPeriodStart;
  final DateTime reportPeriodEnd;

  ComprehensiveReportData({
    required this.stationName,
    required this.reportDate,
    required this.salesDetails,
    required this.nozzleDetails,
    required this.productDetails,
    required this.paymentDetails,
    required this.petrolPumpId,
    required this.petrolPumpName,
    required this.generatedAt,
    required this.generatedBy,
    required this.reportPeriodStart,
    required this.reportPeriodEnd,
  });

  factory ComprehensiveReportData.fromJson(Map<String, dynamic> json) {
    return ComprehensiveReportData(
      stationName: json['stationName'],
      reportDate: DateTime.parse(json['reportDate']),
      salesDetails: SalesDetails.fromJson(json['salesDetails']),
      nozzleDetails: NozzleDetails.fromJson(json['nozzleDetails']),
      productDetails: ProductDetails.fromJson(json['productDetails']),
      paymentDetails: PaymentDetails.fromJson(json['paymentDetails']),
      petrolPumpId: json['petrolPumpId'],
      petrolPumpName: json['petrolPumpName'],
      generatedAt: DateTime.parse(json['generatedAt']),
      generatedBy: json['generatedBy'],
      reportPeriodStart: DateTime.parse(json['reportPeriodStart']),
      reportPeriodEnd: DateTime.parse(json['reportPeriodEnd']),
    );
  }
}

class SalesDetails {
  final List<TankSalesDetail> tankSalesDetails;

  SalesDetails({
    required this.tankSalesDetails,
  });

  factory SalesDetails.fromJson(Map<String, dynamic> json) {
    return SalesDetails(
      tankSalesDetails: List<TankSalesDetail>.from(
          json['tankSalesDetails'].map((x) => TankSalesDetail.fromJson(x))),
    );
  }
}

class TankSalesDetail {
  final String product;
  final String tank;
  final double dip;
  final double openingStockVol;
  final double openingStockDensity;
  final double loadVol;
  final double loadDensity;
  final double totalStockVol;
  final double totalStockDensity;
  final double closingDip;
  final double closingStockVol;
  final double closingStockDensity;
  final double dipSales;
  final double meterSales;
  final double variation;

  TankSalesDetail({
    required this.product,
    required this.tank,
    required this.dip,
    required this.openingStockVol,
    required this.openingStockDensity,
    required this.loadVol,
    required this.loadDensity,
    required this.totalStockVol,
    required this.totalStockDensity,
    required this.closingDip,
    required this.closingStockVol,
    required this.closingStockDensity,
    required this.dipSales,
    required this.meterSales,
    required this.variation,
  });

  factory TankSalesDetail.fromJson(Map<String, dynamic> json) {
    return TankSalesDetail(
      product: json['product'],
      tank: json['tank'],
      dip: json['dip']?.toDouble() ?? 0.0,
      openingStockVol: json['openingStockVol']?.toDouble() ?? 0.0,
      openingStockDensity: json['openingStockDensity']?.toDouble() ?? 0.0,
      loadVol: json['loadVol']?.toDouble() ?? 0.0,
      loadDensity: json['loadDensity']?.toDouble() ?? 0.0,
      totalStockVol: json['totalStockVol']?.toDouble() ?? 0.0,
      totalStockDensity: json['totalStockDensity']?.toDouble() ?? 0.0,
      closingDip: json['closingDip']?.toDouble() ?? 0.0,
      closingStockVol: json['closingStockVol']?.toDouble() ?? 0.0,
      closingStockDensity: json['closingStockDensity']?.toDouble() ?? 0.0,
      dipSales: json['dipSales']?.toDouble() ?? 0.0,
      meterSales: json['meterSales']?.toDouble() ?? 0.0,
      variation: json['variation']?.toDouble() ?? 0.0,
    );
  }
}

class NozzleDetails {
  final List<NozzleDetail> nozzleDetails;

  NozzleDetails({
    required this.nozzleDetails,
  });

  factory NozzleDetails.fromJson(Map<String, dynamic> json) {
    return NozzleDetails(
      nozzleDetails: List<NozzleDetail>.from(
          json['nozzleDetails'].map((x) => NozzleDetail.fromJson(x))),
    );
  }
}

class NozzleDetail {
  final String dispenserUnit;
  final String nozzle;
  final String product;
  final String tank;
  final double opening;
  final double closing;
  final double testingLtrs;
  final double meterSalesLtrs;

  NozzleDetail({
    required this.dispenserUnit,
    required this.nozzle,
    required this.product,
    required this.tank,
    required this.opening,
    required this.closing,
    required this.testingLtrs,
    required this.meterSalesLtrs,
  });

  factory NozzleDetail.fromJson(Map<String, dynamic> json) {
    return NozzleDetail(
      dispenserUnit: json['dispenserUnit'] ?? '',
      nozzle: json['nozzle'] ?? '',
      product: json['product'] ?? '',
      tank: json['tank'] ?? '',
      opening: json['opening']?.toDouble() ?? 0.0,
      closing: json['closing']?.toDouble() ?? 0.0,
      testingLtrs: json['testingLtrs']?.toDouble() ?? 0.0,
      meterSalesLtrs: json['meterSalesLtrs']?.toDouble() ?? 0.0,
    );
  }
}

class ProductDetails {
  final List<dynamic> productDetails;
  final ProductTotal total;

  ProductDetails({
    required this.productDetails,
    required this.total,
  });

  factory ProductDetails.fromJson(Map<String, dynamic> json) {
    return ProductDetails(
      productDetails: List<dynamic>.from(json['productDetails']),
      total: ProductTotal.fromJson(json['total']),
    );
  }
}

class ProductTotal {
  final double totalVolumeLtrs;
  final double totalAmountRs;

  ProductTotal({
    required this.totalVolumeLtrs,
    required this.totalAmountRs,
  });

  factory ProductTotal.fromJson(Map<String, dynamic> json) {
    return ProductTotal(
      totalVolumeLtrs: json['totalVolumeLtrs']?.toDouble() ?? 0.0,
      totalAmountRs: json['totalAmountRs']?.toDouble() ?? 0.0,
    );
  }
}

class PaymentDetails {
  final List<dynamic> paymentModes;
  final double totalAmount;

  PaymentDetails({
    required this.paymentModes,
    required this.totalAmount,
  });

  factory PaymentDetails.fromJson(Map<String, dynamic> json) {
    return PaymentDetails(
      paymentModes: List<dynamic>.from(json['paymentModes'] ?? []),
      totalAmount: json['totalAmount']?.toDouble() ?? 0.0,
    );
  }
} 