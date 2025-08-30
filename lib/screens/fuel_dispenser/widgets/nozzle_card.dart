import 'package:flutter/material.dart';
import '../../../models/nozzle_model.dart';
import '../../../models/fuel_dispenser_model.dart';
import '../../../theme.dart';

class NozzleCard extends StatelessWidget {
  final Nozzle nozzle;
  final FuelDispenser dispenser;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onAssignEmployee;
  final VoidCallback onChangeStatus;
  final onRemoveEmployee;

  const NozzleCard({
    Key? key,
    required this.nozzle,
    required this.dispenser,
    required this.onTap,
    required this.onDelete,
    required this.onAssignEmployee,
    required this.onChangeStatus,
    this.onRemoveEmployee,
  }) : super(key: key);

  // Get color for fuel type
  Color _getFuelTypeColor(String? fuelType) {
    if (fuelType == null) return Colors.blueGrey.shade700;
    
    switch (fuelType.toLowerCase()) {
      case 'petrol':
        return Colors.green.shade700;
      case 'diesel':
        return Colors.orange.shade800;
      case 'premium':
      case 'premium petrol':
        return Colors.purple.shade700;
      case 'premium diesel':
        return Colors.deepPurple.shade800;
      case 'cng':
        return Colors.teal.shade700;
      case 'lpg':
        return Colors.indigo.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = nozzle.status.toLowerCase() == 'active';
    final bool isMaintenance = nozzle.status.toLowerCase() == 'maintenance';
    final bool isInactive = nozzle.status.toLowerCase() == 'inactive';
    final Color nozzleColor = _getFuelTypeColor(nozzle.fuelType);
    
    // Determine status color
    final Color statusColor = isActive
        ? Colors.green
        : (isMaintenance ? Colors.orange : Colors.red);
    
    // Last calibration text
    final String calibrationText = nozzle.lastCalibrationDate != null
        ? 'Calibrated: ${_formatDate(nozzle.lastCalibrationDate!)}'
        : 'Not yet calibrated';
    
    return SizedBox(
      height: 175, // Fixed height to ensure card fits in its container
      child: Card(
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha:0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: statusColor.withValues(alpha:0.3),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with nozzle number and status
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          nozzleColor.withValues(alpha:0.8),
                          nozzleColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Nozzle number with icon
                        Flexible(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#${nozzle.nozzleNumber}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: nozzleColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (nozzle.fuelType != null)
                                Flexible(
                                  child: Text(
                                    nozzle.fuelType!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(alpha:0.4),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                nozzle.status,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Dispenser info
                        Row(
                          children: [
                            Icon(
                              Icons.dashboard_outlined,
                              size: 12,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Dispenser #${dispenser.dispenserNumber}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 6),
                        
                        // Nozzle and tank connection - simplified
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Nozzle icon - even smaller
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: nozzleColor.withValues(alpha:0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.local_gas_station,
                                    size: 20,
                                    color: nozzleColor,
                                  ),
                                  Positioned(
                                    bottom: 3,
                                    right: 3,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(width: 8),
                            
                            // Nozzle details - simplified
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Tank ID

                                  
                                  // Employee assignment - conditionally displayed
                                  if (nozzle.assignedEmployee != null && nozzle.assignedEmployee!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            size: 10,
                                            color: AppTheme.primaryBlue,
                                          ),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              nozzle.assignedEmployee!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: AppTheme.primaryBlue,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Spacer to push buttons to bottom
                  const Spacer(),
                  
                  // Action buttons - moved to bottom
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          icon: Icons.edit,
                          color: AppTheme.primaryBlue,
                          onTap: onChangeStatus,
                        ),
                        _buildActionButton(
                          icon: nozzle.assignedEmployee != null ? Icons.person_search : Icons.person_add_outlined,
                          color: Colors.green.shade600,
                          onTap: onAssignEmployee,
                        ),
                        if (onRemoveEmployee != null && nozzle.assignedEmployee != null)
                          _buildActionButton(
                            icon: Icons.person_remove_outlined,
                            color: Colors.orange.shade700,
                            onTap: onRemoveEmployee,
                          )
                        else
                          _buildActionButton(
                            icon: Icons.delete_outline,
                            color: Colors.red.shade600,
                            onTap: onDelete,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }
  
  // Simplified action buttons without text, just icons
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
      ),
    );
  }
  
  // Helper method to format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 