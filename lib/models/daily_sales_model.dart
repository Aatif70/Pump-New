
class DailySalesData {
  final DateTime date;
  final double totalSalesVolume;
  final double totalSalesValue;
  final int transactionCount;
  final double averageTransactionValue;
  final Map<String, double> salesByFuelType;
  final Map<String, double> revenueByFuelType;

  DailySalesData({
    required this.date,
    required this.totalSalesVolume,
    required this.totalSalesValue,
    required this.transactionCount,
    required this.averageTransactionValue,
    required this.salesByFuelType,
    required this.revenueByFuelType,
  });

  factory DailySalesData.fromJson(Map<String, dynamic> json) {
    // Parse salesByFuelType and revenueByFuelType
    Map<String, double> parsedSalesByFuelType = {};
    Map<String, double> parsedRevenueByFuelType = {};

    if (json['salesByFuelType'] != null) {
      json['salesByFuelType'].forEach((key, value) {
        parsedSalesByFuelType[key] = value.toDouble();
      });
    }

    if (json['revenueByFuelType'] != null) {
      json['revenueByFuelType'].forEach((key, value) {
        parsedRevenueByFuelType[key] = value.toDouble();
      });
    }

    return DailySalesData(
      date: DateTime.parse(json['date']),
      totalSalesVolume: json['totalSalesVolume']?.toDouble() ?? 0.0,
      totalSalesValue: json['totalSalesValue']?.toDouble() ?? 0.0,
      transactionCount: json['transactionCount'] ?? 0,
      averageTransactionValue: json['averageTransactionValue']?.toDouble() ?? 0.0,
      salesByFuelType: parsedSalesByFuelType,
      revenueByFuelType: parsedRevenueByFuelType,
    );
  }
} 