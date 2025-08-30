import 'package:flutter/material.dart';
import '../../../models/nozzle_model.dart';

class NozzleStatusSummary extends StatelessWidget {
  final List<Map<String, dynamic>> nozzlesWithDispenserInfo;

  const NozzleStatusSummary({
    Key? key,
    required this.nozzlesWithDispenserInfo,
  }) : super(key: key);

  // Status count indicator for summary
  Widget _buildStatusCountItem(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha:0.8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Status counts for summary
    Map<String, int> statusCounts = {
      'Active': 0,
      'Maintenance': 0,
      'Inactive': 0,
    };
    
    // Calculate status counts
    for (var nozzleInfo in nozzlesWithDispenserInfo) {
      final nozzle = nozzleInfo['nozzle'] as Nozzle;
      if (statusCounts.containsKey(nozzle.status)) {
        statusCounts[nozzle.status] = (statusCounts[nozzle.status] ?? 0) + 1;
      }
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total count with summary
          Row(
            children: [
              Icon(Icons.api, color: Theme.of(context).primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Total Nozzles: ${nozzlesWithDispenserInfo.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Status indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatusCountItem('Active', statusCounts['Active'] ?? 0, Colors.green),
              _buildStatusCountItem('Maintenance', statusCounts['Maintenance'] ?? 0, Colors.orange),
              _buildStatusCountItem('Inactive', statusCounts['Inactive'] ?? 0, Colors.red),
            ],
          ),
        ],
      ),
    );
  }
} 