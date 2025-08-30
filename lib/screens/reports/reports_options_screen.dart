import 'package:flutter/material.dart';
import 'package:petrol_pump/screens/reports/stock_movement_report_screen.dart';
import '../../theme.dart';
import 'cash_reconciliation_report_screen.dart';
import 'comprehensive_report_screen.dart';
import 'daily_sales_report_screen.dart';
import 'shift_sales_report_screen.dart';
import 'employee_performance_report_screen.dart';

class ReportsOptionsScreen extends StatefulWidget {
  const ReportsOptionsScreen({super.key});

  @override
  State<ReportsOptionsScreen> createState() => _ReportsOptionsScreenState();
}

class _ReportsOptionsScreenState extends State<ReportsOptionsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header section with gradient
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 25,
                top: 5,
              ),
            ),
            
            // Report options
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  _buildReportOption(
                    title: 'Daily Sales',
                    description: 'View daily sales data',
                    icon: Icons.calendar_today,
                    color: Colors.blue.shade600,
                    onTap: () {
                      // Navigate to Daily Sales Report Screen
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => const DailySalesReportScreen(),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildReportOption(
                    title: 'Shift Sales',
                    description: 'View sales data by Shift',
                    icon: Icons.filter_tilt_shift,
                    color: Colors.red.shade600,
                    onTap: () {
                      // Navigate to Shift Sales Report Screen
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => const ShiftSalesReportScreen(),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildReportOption(
                    title: 'Employee Performance',
                    description: 'Performance metrics',
                    icon: Icons.trending_up,
                    color: Colors.purple.shade600,
                    onTap: () {
                      // Navigate to Employee Performance Screen
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => const EmployeePerformanceReportScreen(),
                        ),
                      );
                    },
                  ),

                  // const SizedBox(height: 16),

                  // NOT WORKING
                  // _buildReportOption(
                  //   title: 'Fuel Type Performance',
                  //   description: 'View sales and performance by fuel type',
                  //   icon: Icons.local_drink,
                  //   color: Colors.teal.shade600,
                  //   onTap: () {
                  //     // Navigate to Fuel Type Performance Screen
                  //   },
                  // ),
                  
                  // const SizedBox(height: 16),
                  // NOT WORKING
                  // _buildReportOption(
                  //   title: 'Nozzle Performance',
                  //   description: 'View performance data for each nozzle',
                  //   icon: Icons.local_gas_station,
                  //   color: Colors.orange.shade600,
                  //   onTap: () {
                  //     // Navigate to Nozzle Performance Screen
                  //   },
                  // ),
                  

                  
                  // const SizedBox(height: 16),

                  // NOT WORKING
                  // _buildReportOption(
                  //   title: 'Payment Method Analysis',
                  //   description: 'View breakdown of payment methods used',
                  //   icon: Icons.payment,
                  //   color: Colors.indigo.shade600,
                  //   onTap: () {
                  //     // Navigate to Payment Method Analysis Screen
                  //   },
                  // ),
                  
                  // const SizedBox(height: 16),
                  // NOT WORKING
                  // _buildReportOption(
                  //   title: 'Shift Handover',
                  //   description: 'View shift handover reports',
                  //   icon: Icons.swap_horiz,
                  //   color: Colors.deepOrange.shade600,
                  //   onTap: () {
                  //     // Navigate to Shift Handover Screen
                  //   },
                  // ),
                  
                  // const SizedBox(height: 16),
                  //
                  // _buildReportOption(
                  //   title: 'Employee Attendance',
                  //   description: 'View employee attendance records',
                  //   icon: Icons.access_time,
                  //   color: Colors.blueGrey.shade600,
                  //   onTap: () {
                  //     // Navigate to Employee Attendance Screen
                  //   },
                  // ),
                  //
                  const SizedBox(height: 16),
                  
                  _buildReportOption(
                    title: 'Stock Movement',
                    description: 'View stock movement ',
                    icon: Icons.swap_vert,
                    color: Colors.amber.shade700,
                    onTap: () {
                      // Navigate to Stock Movement Screen
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => const StockMovementReportScreen(),
                        ),
                      );
                    },
                  ),
                  
                  // const SizedBox(height: 16),
                  //
                  // _buildReportOption(
                  //   title: 'Delivery Reconciliation',
                  //   description: 'Reconcile fuel deliveries with inventory',
                  //   icon: Icons.local_shipping,
                  //   color: Colors.cyan.shade700,
                  //   onTap: () {
                  //     // Navigate to Delivery Reconciliation Screen
                  //   },
                  // ),
                  
                  // const SizedBox(height: 16),
                  //
                  // _buildReportOption(
                  //   title: 'Inventory Turnover',
                  //   description: 'View inventory turnover metrics',
                  //   icon: Icons.autorenew,
                  //   color: Colors.lightGreen.shade700,
                  //   onTap: () {
                  //     // Navigate to Inventory Turnover Screen
                  //   },
                  // ),
                  //
                  // const SizedBox(height: 16),
                  //
                  // _buildReportOption(
                  //   title: 'Stock Discrepancies',
                  //   description: 'View and analyze stock discrepancies',
                  //   icon: Icons.warning,
                  //   color: Colors.red.shade600,
                  //   onTap: () {
                  //     // Navigate to Stock Discrepancies Screen
                  //   },
                  // ),
                  //


                  const SizedBox(height: 16),
                  
                  _buildReportOption(
                    title: 'Cash Reconciliation',
                    description: 'Reconcile cash transactions',
                    icon: Icons.account_balance_wallet,
                    color: Colors.brown.shade600,
                    onTap: () {
                      // Navigate to Cash Reconciliation Screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CashReconciliationReportScreen(),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildReportOption(
                    title: 'Comprehensive Report',
                    description: 'View detailed daily reports',
                    icon: Icons.assessment,
                    color: Colors.deepPurple.shade600,
                    onTap: () {
                      // Navigate to Comprehensive Report Screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ComprehensiveReportScreen(),
                        ),
                      );
                    },
                  ),
                  
                  // const SizedBox(height: 16),
                  //
                  // _buildReportOption(
                  //   title: 'Tax Compliance',
                  //   description: 'Monitor and ensure tax compliance',
                  //   icon: Icons.receipt_long,
                  //   color: Colors.grey.shade700,
                  //   onTap: () {
                  //     // Navigate to Tax Compliance Screen
                  //   },
                  // ),
                  //
                  // const SizedBox(height: 16),
                  //
                  // _buildReportOption(
                  //   title: 'Executive Summary',
                  //   description: 'Comprehensive overview for management',
                  //   icon: Icons.summarize,
                  //   color: Colors.blue.shade800,
                  //   onTap: () {
                  //     // Navigate to Executive Summary Screen
                  //   },
                  // ),
                  //
                  // const SizedBox(height: 16),
                  //
                  // _buildReportOption(
                  //   title: 'Exceptions',
                  //   description: 'View anomalies and exception reports',
                  //   icon: Icons.error_outline,
                  //   color: Colors.orange.shade800,
                  //   onTap: () {
                  //     // Navigate to Exceptions Screen
                  //   },
                  // ),
                  //
                  // const SizedBox(height: 16),
                  //
                  // _buildReportOption(
                  //   title: 'Comparative Performance',
                  //   description: 'Compare performance across time periods',
                  //   icon: Icons.compare_arrows,
                  //   color: Colors.teal.shade800,
                  //   onTap: () {
                  //     // Navigate to Comparative Performance Screen
                  //   },
                  // ),
                  //
                  // const SizedBox(height: 16),
                  //
                  // _buildReportOption(
                  //   title: 'Sales Trend Analysis',
                  //   description: 'Analyze sales patterns over time',
                  //   icon: Icons.trending_up,
                  //   color: Colors.green.shade800,
                  //   onTap: () {
                  //     // Navigate to Sales Trend Analysis Screen
                  //   },
                  // ),
                  //
                  // const SizedBox(height: 16),
                  //
                  // _buildReportOption(
                  //   title: 'Customer Behavior Analysis',
                  //   description: 'Analyze customer purchasing patterns',
                  //   icon: Icons.people_outline,
                  //   color: Colors.indigo.shade800,
                  //   onTap: () {
                  //     // Navigate to Customer Behavior Analysis Screen
                  //   },
                  // ),
                  //
                  // const SizedBox(height: 16),
                  //
                  // _buildReportOption(
                  //   title: 'Profitability Analysis',
                  //   description: 'Detailed analysis of profit margins',
                  //   icon: Icons.money,
                  //   color: Colors.purple.shade800,
                  //   onTap: () {
                  //     // Navigate to Profitability Analysis Screen
                  //   },
                  // ),
                  //
                  // const SizedBox(height: 16),
                  //
                  // _buildReportOption(
                  //   title: 'Maintenance Schedule',
                  //   description: 'View and manage equipment maintenance',
                  //   icon: Icons.build,
                  //   color: Colors.brown.shade800,
                  //   onTap: () {
                  //     // Navigate to Maintenance Schedule Screen
                  //   },
                  // ),
                  //
                  // const SizedBox(height: 16),
                  //
                  // _buildReportOption(
                  //   title: 'Fuel Quality',
                  //   description: 'Monitor fuel quality metrics',
                  //   icon: Icons.water_drop,
                  //   color: Colors.amber.shade800,
                  //   onTap: () {
                  //     // Navigate to Fuel Quality Screen
                  //   },
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportOption({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha:0.08),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha:0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: color,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 