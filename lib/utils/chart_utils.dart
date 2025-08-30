import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/daily_sales_report_model.dart';

class ChartUtils {
  // Convert hourly sales to bar chart data
  static List<BarChartGroupData> getHourlySalesBarGroups(List<HourlySale> hourlySales) {
    // Find the maximum value for scaling
    double maxValue = 0;
    for (var sale in hourlySales) {
      if (sale.value > maxValue) maxValue = sale.value;
    }
    
    // If all values are zero, set a default maximum
    if (maxValue <= 0) maxValue = 100;
    
    return List.generate(hourlySales.length, (index) {
      final sale = hourlySales[index];
      return BarChartGroupData(
        x: sale.hour,
        barRods: [
          BarChartRodData(
            toY: sale.value,
            color: Colors.blue.shade700,
            width: 12,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    });
  }
  
  // Convert payment breakdown to pie chart data
  static List<PieChartSectionData> getPaymentBreakdownSections(PaymentBreakdown paymentBreakdown) {
    final totalValue = paymentBreakdown.cashAmount +
        paymentBreakdown.creditCardAmount +
        paymentBreakdown.upiAmount;
    
    // If there's no data, return an empty chart with placeholder
    if (totalValue <= 0) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 100,
          title: 'No data',
          radius: 50,
          titleStyle: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ];
    }
    
    return [
      if (paymentBreakdown.cashAmount > 0)
        PieChartSectionData(
          color: Colors.green.shade600,
          value: paymentBreakdown.cashAmount,
          title: '${(paymentBreakdown.cashPercentage).toStringAsFixed(1)}%',
          radius: 50,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      if (paymentBreakdown.creditCardAmount > 0)
        PieChartSectionData(
          color: Colors.blue.shade600,
          value: paymentBreakdown.creditCardAmount,
          title: '${(paymentBreakdown.creditCardPercentage).toStringAsFixed(1)}%',
          radius: 50,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      if (paymentBreakdown.upiAmount > 0)
        PieChartSectionData(
          color: Colors.purple.shade600,
          value: paymentBreakdown.upiAmount,
          title: '${(paymentBreakdown.upiPercentage).toStringAsFixed(1)}%',
          radius: 50,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
    ];
  }
  
  // Format currency values
  static String formatCurrency(double value) {
    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)}L';
    } else if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(2)}K';
    } else {
      return '₹${value.toStringAsFixed(2)}';
    }
  }
  
  // Format volume values
  static String formatVolume(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)}K L';
    } else {
      return '${value.toStringAsFixed(2)} L';
    }
  }
  
  // Helper method to get time string from hour
  static String getTimeString(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour $period';
  }
} 