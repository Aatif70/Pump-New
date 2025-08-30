import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/nozzle_model.dart';
import '../../../models/employee_model.dart';
import '../../../models/shift_model.dart';
import '../../../theme.dart';

class EmployeeAssignmentScreen extends StatefulWidget {
  final Nozzle nozzle;
  final List<Employee> availableEmployees;
  final List<Shift> availableShifts;
  final List<String> assignedEmployeeIds;

  const EmployeeAssignmentScreen({
    Key? key,
    required this.nozzle,
    required this.availableEmployees,
    required this.availableShifts,
    this.assignedEmployeeIds = const [],
  }) : super(key: key);

  @override
  _EmployeeAssignmentScreenState createState() => _EmployeeAssignmentScreenState();
  
  // Static method to navigate to this screen
  static Future<Map<String, dynamic>?> navigate({
    required BuildContext context,
    required Nozzle nozzle,
    required List<Employee> availableEmployees,
    required List<Shift> availableShifts,
    List<String> assignedEmployeeIds = const [],
  }) {
    return Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => EmployeeAssignmentScreen(
          nozzle: nozzle,
          availableEmployees: availableEmployees,
          availableShifts: availableShifts,
          assignedEmployeeIds: assignedEmployeeIds,
        ),
      ),
    );
  }
}

class _EmployeeAssignmentScreenState extends State<EmployeeAssignmentScreen> with SingleTickerProviderStateMixin {
  String? selectedEmployeeId;
  String? selectedShiftId;
  DateTime selectedStartDate = DateTime.now();
  DateTime? selectedEndDate;
  
  final TextEditingController _searchController = TextEditingController();
  List<Employee> filteredEmployees = [];
  List<Employee> _unassignedEmployees = []; // Track unassigned employees
  
  final _dateFormat = DateFormat('dd MMM yyyy');
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _filterOutAssignedEmployees();
    _searchController.addListener(_filterEmployees);
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }
  
  // Filter out employees that are already assigned to other nozzles
  void _filterOutAssignedEmployees() {
    // Extract current nozzle's assigned employee ID if any
    String? currentNozzleEmployeeId;
    if (widget.nozzle.assignedEmployee != null && widget.nozzle.assignedEmployee!.isNotEmpty) {
      // Try to find the employee ID by matching name with currently assigned employee
      for (var employee in widget.availableEmployees) {
        final fullName = '${employee.firstName} ${employee.lastName}';
        if (widget.nozzle.assignedEmployee!.contains(fullName)) {
          currentNozzleEmployeeId = employee.id;
          break;
        }
      }
    }
    
    // Keep employees that are either not assigned or assigned to this nozzle
    _unassignedEmployees = widget.availableEmployees.where((employee) {
      // If this employee is assigned to the current nozzle, include them
      if (currentNozzleEmployeeId != null && employee.id == currentNozzleEmployeeId) {
        return true;
      }
      // Otherwise only include if not assigned elsewhere
      return !widget.assignedEmployeeIds.contains(employee.id);
    }).toList();
    
    print('Employee Assignment: Filtered to ${_unassignedEmployees.length} unassigned employees');
    // Set for the UI
    filteredEmployees = _unassignedEmployees;
    
    // If the current nozzle has an assigned employee, preselect them
    if (currentNozzleEmployeeId != null) {
      selectedEmployeeId = currentNozzleEmployeeId;
    }
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_filterEmployees);
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  void _filterEmployees() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredEmployees = _unassignedEmployees;
      } else {
        filteredEmployees = _unassignedEmployees
            .where((employee) => 
                employee.firstName.toLowerCase().contains(query) ||
                employee.lastName.toLowerCase().contains(query) ||
                '${employee.firstName} ${employee.lastName}'.toLowerCase().contains(query) ||
                employee.role.toLowerCase().contains(query))
            .toList();
      }
    });
  }
  
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? selectedStartDate : (selectedEndDate ?? DateTime.now().add(const Duration(days: 7)));
    final firstDate = isStartDate ? DateTime.now() : selectedStartDate;
    final lastDate = DateTime.now().add(const Duration(days: 365));
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          selectedStartDate = pickedDate;
          if (selectedEndDate != null && selectedEndDate!.isBefore(selectedStartDate)) {
            selectedEndDate = null;
          }
        } else {
          selectedEndDate = pickedDate;
        }
      });
    }
  }
  
  bool _isFormValid() {
    return selectedEmployeeId != null && 
           selectedShiftId != null && 
           selectedStartDate != null;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_gas_station, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '#${widget.nozzle.nozzleNumber}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Assign Employee',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.nozzle.fuelType != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Chip(
                backgroundColor: Colors.white24,
                label: Text(
                  widget.nozzle.fuelType!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha:0.1),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
            children: [
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Employee Selection
                      const _SectionTitle(title: 'Select Employee', icon: Icons.person),
                      const SizedBox(height: 16),
                      
                      // Search field
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search Employee',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'Search by name or role',
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Employee list
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha:0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: filteredEmployees.isEmpty
                            ? _buildEmptyState('No employees found', Icons.person_off_outlined)
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredEmployees.length,
                                separatorBuilder: (context, index) => Divider(
                                  height: 1,
                                  indent: 72,
                                  endIndent: 16,
                                  color: Colors.grey.shade200,
                                ),
                                itemBuilder: (context, index) {
                                  final employee = filteredEmployees[index];
                                  final isSelected = selectedEmployeeId == employee.id;
                                  
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          selectedEmployeeId = employee.id;
                                        });
                                      },
                                      splashColor: AppTheme.primaryBlue.withValues(alpha:0.1),
                                      highlightColor: AppTheme.primaryBlue.withValues(alpha:0.05),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: isSelected
                                                ? AppTheme.primaryBlue
                                                : Colors.grey.shade200,
                                            radius: 20,
                                            child: Text(
                                              '${employee.firstName[0]}${employee.lastName.isNotEmpty ? employee.lastName[0] : ''}',
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : Colors.grey.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            '${employee.firstName} ${employee.lastName}',
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                              color: isSelected ? AppTheme.primaryBlue : Colors.black87,
                                            ),
                                          ),
                                          subtitle: Text(
                                            employee.role,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          trailing: isSelected
                                              ? Icon(
                                                  Icons.check_circle,
                                                  color: AppTheme.primaryBlue,
                                                )
                                              : null,
                                          dense: true,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Shift Selection
                      const _SectionTitle(title: 'Select Shift', icon: Icons.schedule),
                      const SizedBox(height: 16),
                      
                      if (widget.availableShifts.isEmpty)
                        _buildEmptyState('No shifts available', Icons.schedule_outlined)
                      else
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha:0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: widget.availableShifts.asMap().map((index, shift) {
                              final isSelected = selectedShiftId == shift.id;
                              final isLast = index == widget.availableShifts.length - 1;
                              
                              return MapEntry(
                                index,
                                Column(
                                  children: [
                                    Material(
                                      color: isSelected ? AppTheme.primaryBlue.withValues(alpha:0.05) : Colors.white,
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            selectedShiftId = shift.id;
                                          });
                                        },
                                        splashColor: AppTheme.primaryBlue.withValues(alpha:0.1),
                                        highlightColor: AppTheme.primaryBlue.withValues(alpha:0.05),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          child: ListTile(
                                            leading: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected
                                                    ? AppTheme.primaryBlue
                                                    : Colors.amber.withValues(alpha:0.1),
                                                border: isSelected
                                                    ? null
                                                    : Border.all(color: Colors.amber, width: 1.5),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${shift.shiftNumber}',
                                                  style: TextStyle(
                                                    color: isSelected ? Colors.white : Colors.amber,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              'Shift ${shift.shiftNumber}',
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                color: isSelected ? AppTheme.primaryBlue : Colors.black87,
                                              ),
                                            ),
                                            subtitle: Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 14,
                                                  color: Colors.grey.shade500,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${shift.startTime} - ${shift.endTime}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            trailing: isSelected
                                                ? Icon(
                                                    Icons.check_circle,
                                                    color: AppTheme.primaryBlue,
                                                  )
                                                : null,
                                            dense: true,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (!isLast)
                                      Divider(
                                        height: 1,
                                        indent: 72,
                                        endIndent: 16,
                                        color: Colors.grey.shade200,
                                      ),
                                  ],
                                ),
                              );
                            }).values.toList(),
                          ),
                        ),
                      
                      const SizedBox(height: 32),
                      
                      // Assignment Dates
                      const _SectionTitle(title: 'Assignment Period', icon: Icons.date_range),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          // Start Date
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, true),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 16,
                                          color: AppTheme.primaryBlue,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Start Date',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _dateFormat.format(selectedStartDate),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // End Date (Optional)
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, false),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.event_available,
                                              size: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'End Date',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (selectedEndDate != null)
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                selectedEndDate = null;
                                              });
                                            },
                                            child: Icon(
                                              Icons.clear,
                                              size: 16,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      selectedEndDate != null
                                          ? _dateFormat.format(selectedEndDate!)
                                          : 'No end date',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: selectedEndDate != null ? Colors.black87 : Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Info text
                      if (selectedEndDate == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0, left: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'If no end date is specified, the assignment will continue indefinitely.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // Footer with actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha:0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('CANCEL'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isFormValid()
                              ? () {
                                  Navigator.pop(context, {
                                    'employeeId': selectedEmployeeId,
                                    'nozzleId': widget.nozzle.id,
                                    'shiftId': selectedShiftId,
                                    'startDate': selectedStartDate,
                                    'endDate': selectedEndDate,
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.check),
                          label: const Text(
                            'ASSIGN EMPLOYEE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState(String message, IconData icon) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  
  const _SectionTitle({
    required this.title,
    this.icon,
    Key? key,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        if (icon != null) ...[
          Icon(
            icon,
            size: 18,
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
} 