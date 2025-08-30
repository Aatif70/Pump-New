class SalesStatistics {
  final double totalLitersSold;
  final double totalAmount;
  final int totalTransactions;
  final String? topPerformingShiftId;
  final String? topPerformingShiftName;
  final double? topPerformingShiftAmount;
  
  // Sales by fuel type
  final Map<String, FuelTypeSales> salesByFuelType;
  
  // Sales by payment method
  final double cashAmount;
  final double creditCardAmount;
  final double upiAmount;
  
  // Sales by shift
  final List<ShiftSales> salesByShift;
  
  // Sales by day
  final List<DailySales> salesByDay;

  SalesStatistics({
    required this.totalLitersSold,
    required this.totalAmount,
    required this.totalTransactions,
    this.topPerformingShiftId,
    this.topPerformingShiftName,
    this.topPerformingShiftAmount,
    required this.salesByFuelType,
    required this.cashAmount,
    required this.creditCardAmount,
    required this.upiAmount,
    required this.salesByShift,
    required this.salesByDay,
  });

  factory SalesStatistics.fromJson(Map<String, dynamic> json) {
    // Parse salesByFuelType
    Map<String, FuelTypeSales> fuelTypeSales = {};
    if (json['salesByFuelType'] != null) {
      json['salesByFuelType'].forEach((key, value) {
        fuelTypeSales[key] = FuelTypeSales.fromJson(value);
      });
    }

    // Parse salesByShift
    List<ShiftSales> shiftSales = [];
    if (json['salesByShift'] != null) {
      json['salesByShift'].forEach((item) {
        shiftSales.add(ShiftSales.fromJson(item));
      });
    }

    // Parse salesByDay
    List<DailySales> dailySales = [];
    if (json['salesByDay'] != null) {
      json['salesByDay'].forEach((item) {
        dailySales.add(DailySales.fromJson(item));
      });
    }

    return SalesStatistics(
      totalLitersSold: json['totalLitersSold']?.toDouble() ?? 0.0,
      totalAmount: json['totalAmount']?.toDouble() ?? 0.0,
      totalTransactions: json['totalTransactions'] ?? 0,
      topPerformingShiftId: json['topPerformingShiftId'],
      topPerformingShiftName: json['topPerformingShiftName'],
      topPerformingShiftAmount: json['topPerformingShiftAmount']?.toDouble(),
      salesByFuelType: fuelTypeSales,
      cashAmount: json['cashAmount']?.toDouble() ?? 0.0,
      creditCardAmount: json['creditCardAmount']?.toDouble() ?? 0.0,
      upiAmount: json['upiAmount']?.toDouble() ?? 0.0,
      salesByShift: shiftSales,
      salesByDay: dailySales,
    );
  }
}

class FuelTypeSales {
  final double litersSold;
  final double amount;

  FuelTypeSales({
    required this.litersSold,
    required this.amount,
  });

  factory FuelTypeSales.fromJson(Map<String, dynamic> json) {
    return FuelTypeSales(
      litersSold: json['litersSold']?.toDouble() ?? 0.0,
      amount: json['amount']?.toDouble() ?? 0.0,
    );
  }
}

class ShiftSales {
  final String shiftId;
  final String shiftName;
  final double litersSold;
  final double amount;

  ShiftSales({
    required this.shiftId,
    required this.shiftName,
    required this.litersSold,
    required this.amount,
  });

  factory ShiftSales.fromJson(Map<String, dynamic> json) {
    return ShiftSales(
      shiftId: json['shiftId'] ?? '',
      shiftName: json['shiftName'] ?? '',
      litersSold: json['litersSold']?.toDouble() ?? 0.0,
      amount: json['amount']?.toDouble() ?? 0.0,
    );
  }
}

class DailySales {
  final DateTime date;
  final double litersSold;
  final double amount;

  DailySales({
    required this.date,
    required this.litersSold,
    required this.amount,
  });

  factory DailySales.fromJson(Map<String, dynamic> json) {
    return DailySales(
      date: DateTime.parse(json['date']),
      litersSold: json['litersSold']?.toDouble() ?? 0.0,
      amount: json['amount']?.toDouble() ?? 0.0,
    );
  }
}

// Hourly sales pattern data model
class HourlySalesPattern {
  final DateTime date;
  final List<HourlyData> hourlyData;
  final int peakHour;
  final double peakHourVolume;
  final int slowHour;
  final double slowHourVolume;

  HourlySalesPattern({
    required this.date,
    required this.hourlyData,
    required this.peakHour,
    required this.peakHourVolume,
    required this.slowHour,
    required this.slowHourVolume,
  });

  factory HourlySalesPattern.fromJson(Map<String, dynamic> json) {
    List<HourlyData> hourlyDataList = [];
    
    if (json['hourlyData'] != null) {
      json['hourlyData'].forEach((item) {
        hourlyDataList.add(HourlyData.fromJson(item));
      });
    }

    return HourlySalesPattern(
      date: DateTime.parse(json['date']),
      hourlyData: hourlyDataList,
      peakHour: json['peakHour'] ?? 0,
      peakHourVolume: json['peakHourVolume']?.toDouble() ?? 0.0,
      slowHour: json['slowHour'] ?? 0,
      slowHourVolume: json['slowHourVolume']?.toDouble() ?? 0.0,
    );
  }
}

class HourlyData {
  final int hour;
  final double salesVolume;
  final double salesValue;
  final int transactionCount;

  HourlyData({
    required this.hour,
    required this.salesVolume,
    required this.salesValue,
    required this.transactionCount,
  });

  factory HourlyData.fromJson(Map<String, dynamic> json) {
    return HourlyData(
      hour: json['hour'] ?? 0,
      salesVolume: json['salesVolume']?.toDouble() ?? 0.0,
      salesValue: json['salesValue']?.toDouble() ?? 0.0,
      transactionCount: json['transactionCount'] ?? 0,
    );
  }
} 