import 'package:flutter/material.dart';
import '../../api/employee_repository.dart';
import '../../models/employee_model.dart';
import '../../theme.dart';
import 'add_new_employee_screen.dart';
import 'employee_detail_screen.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final EmployeeRepository _repository = EmployeeRepository();
  List<Employee> _employees = [];
  List<Employee> _filteredEmployees = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedRole;
  final Set<String> _recentlyDeletedIds = {};
  bool? _activeFilter;
  
  final List<String?> _roleOptions = [null, 'Manager', 'Attendant', 'Admin'];
  int get _activeFilterCount => 
      (_selectedRole != null ? 1 : 0) + 
      (_activeFilter != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _loadDeletedIds().then((_) => _loadEmployees());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    print('LOADING: Starting to load employees from API');
    setState(() {
      _isLoading = true;
      _isError = false;
      _errorMessage = '';
    });

    try {
      print('LOADING: Calling repository.getAllEmployees()');
      final response = await _repository.getAllEmployees();
      print('LOADING: Got response from getAllEmployees, success=${response.success}, count=${response.data?.length ?? 0}');

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success && response.data != null) {
            _employees = response.data!
                .where((emp) => emp.id != null && !_recentlyDeletedIds.contains(emp.id))
                .toList();
                
            print('LOADING SUCCESS: Loaded ${_employees.length} employees (after filtering deleted)');
            
            _saveDeletedIds();
            
            if (_employees.isNotEmpty) {
              print('EMPLOYEE SAMPLE:');
              for (var i = 0; i < ((_employees.length > 3) ? 3 : _employees.length); i++) {
                print('  - [${i+1}] ID=${_employees[i].id}, Name=${_employees[i].firstName} ${_employees[i].lastName}, Active=${_employees[i].isActive}');
              }
            }
            
            _applyFilters();
            
            if (_employees.isEmpty) {
              _errorMessage = 'No employees found. Add one to get started!';
            }
          } else {
            _isError = true;
            _errorMessage = response.errorMessage ?? 'Failed to load employees';
            print('LOADING ERROR: $_errorMessage');
          }
        });
      }
    } catch (e) {
      print('LOADING EXCEPTION: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _saveDeletedIds() async {
    try {
      print('SAVE: Would save ${_recentlyDeletedIds.length} deleted IDs');
    } catch (e) {
      print('ERROR: Failed to save deleted IDs: $e');
    }
  }

  Future<void> _loadDeletedIds() async {
    try {
      print('LOAD: Would load deleted IDs');
    } catch (e) {
      print('ERROR: Failed to load deleted IDs: $e');
    }
  }

  void _applyFilters() {
    final searchQuery = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredEmployees = _employees.where((employee) {
        final matchesSearch = searchQuery.isEmpty || 
            '${employee.firstName} ${employee.lastName}'.toLowerCase().contains(searchQuery);
        
        final matchesRole = _selectedRole == null || employee.role == _selectedRole;
        
        final matchesStatus = _activeFilter == null || employee.isActive == _activeFilter;
        
        return matchesSearch && matchesRole && matchesStatus && !_recentlyDeletedIds.contains(employee.id);
      }).toList();
    });
  }

  void _showFilterDialog() {
    String? tempRole = _selectedRole;
    bool? tempActiveStatus = _activeFilter;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter Employees'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Role',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _roleOptions.map((role) {
                      final isSelected = tempRole == role;
                      final displayText = role ?? 'All Roles';
                      
                      return ChoiceChip(
                        label: Text(displayText),
                        selected: isSelected,
                        onSelected: (_) {
                          setDialogState(() {
                            tempRole = (role == tempRole) ? null : role;
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: AppTheme.primaryBlue.withAlpha(180),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: tempActiveStatus == null,
                        onSelected: (_) {
                          setDialogState(() {
                            tempActiveStatus = null;
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: AppTheme.primaryBlue.withAlpha(180),
                        labelStyle: TextStyle(
                          color: tempActiveStatus == null ? Colors.white : Colors.black,
                          fontWeight: tempActiveStatus == null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      
                      ChoiceChip(
                        label: const Text('Active'),
                        selected: tempActiveStatus == true,
                        onSelected: (_) {
                          setDialogState(() {
                            tempActiveStatus = (tempActiveStatus == true) ? null : true;
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: Colors.green.withAlpha(180),
                        labelStyle: TextStyle(
                          color: tempActiveStatus == true ? Colors.white : Colors.black,
                          fontWeight: tempActiveStatus == true ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      
                      ChoiceChip(
                        label: const Text('Inactive'),
                        selected: tempActiveStatus == false,
                        onSelected: (_) {
                          setDialogState(() {
                            tempActiveStatus = (tempActiveStatus == false) ? null : false;
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: Colors.red.withAlpha(180),
                        labelStyle: TextStyle(
                          color: tempActiveStatus == false ? Colors.white : Colors.black,
                          fontWeight: tempActiveStatus == false ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    tempRole = null;
                    tempActiveStatus = null;
                  });
                },
                child: const Text('Reset'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedRole = tempRole;
                    _activeFilter = tempActiveStatus;
                    _applyFilters();
                  });
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _viewEmployeeDetails(Employee employee) {
    print('NAVIGATE: Viewing details for employee ID=${employee.id}, Name=${employee.firstName} ${employee.lastName}, isActive=${employee.isActive}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeDetailScreen(employeeId: employee.id!),
      ),
    ).then((result) {
      print('RETURNED from EmployeeDetailScreen with result: $result');
      
      // Check if employee was deleted or just edited
      if (result == 'deleted') {
        // For deletion, add ID to deleted list
        if (employee.id != null) {
          _recentlyDeletedIds.add(employee.id!);
          print('Added ${employee.id} to recently deleted list to filter out');
          _saveDeletedIds();
        }
        _loadEmployees();
      } else if (result == 'edited') {
        // For editing, just refresh the list
        print('Refreshing employee list after updates');
        _loadEmployees();
      }
    });
  }

  void _addNewEmployee() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddNewEmployeeScreen(),
      ),
    ).then((_) => _loadEmployees());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Employees'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filter',
                  onPressed: _showFilterDialog,
                  color: Colors.white,
                ),
                if (_activeFilterCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _activeFilterCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              color: Colors.white,
              onPressed: _loadEmployees,
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadEmployees,
                child: Column(
                  children: [
                    // Search bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search employees...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _applyFilters();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => _applyFilters(),
                      ),
                    ),
                    
                    // Stats row (simplified)
                    if (_employees.isNotEmpty && _filteredEmployees.length != _employees.length)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: [
                            Text(
                              'Showing ${_filteredEmployees.length} of ${_employees.length} employees',
                              style: const TextStyle(
                                color: Colors.grey, 
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Active filters display
                    if (_activeFilterCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (_selectedRole != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Chip(
                                    label: Text(_selectedRole!),
                                    labelStyle: const TextStyle(fontSize: 12, color: Colors.white),
                                    backgroundColor: AppTheme.primaryBlue,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    deleteIcon: const Icon(Icons.clear, size: 14, color: Colors.white),
                                    onDeleted: () {
                                      setState(() {
                                        _selectedRole = null;
                                        _applyFilters();
                                      });
                                    },
                                  ),
                                ),
                              if (_activeFilter != null)
                                Chip(
                                  label: Text(_activeFilter! ? 'Active' : 'Inactive'),
                                  labelStyle: const TextStyle(fontSize: 12, color: Colors.white),
                                  backgroundColor: _activeFilter! ? Colors.green : Colors.red,
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  deleteIcon: const Icon(Icons.clear, size: 14, color: Colors.white),
                                  onDeleted: () {
                                    setState(() {
                                      _activeFilter = null;
                                      _applyFilters();
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),

                    // Error message
                    if (_errorMessage.isNotEmpty && _isError)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Employee list
                    Expanded(
                      child: _filteredEmployees.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.person_off,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _employees.isEmpty
                                        ? 'No employees found. Add one to get started!'
                                        : 'No employees match your filters.',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_employees.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 24),
                                      child: ElevatedButton.icon(
                                        onPressed: _addNewEmployee,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add Employee'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryBlue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _filteredEmployees.length,
                              itemBuilder: (context, index) {
                                final employee = _filteredEmployees[index];
                                return _buildEmployeeListItem(employee);
                              },
                            ),
                    ),
                  ],
                ),
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addNewEmployee,
          backgroundColor: AppTheme.primaryBlue,
          elevation: 2,
          child: const Icon(Icons.person_add, color: Colors.white),
        ),
      ),
    );
  }
  
  // Redesigned employee list item
  Widget _buildEmployeeListItem(Employee employee) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewEmployeeDetails(employee),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              // Employee avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getRoleColor(employee.role),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${employee.firstName[0]}${employee.lastName[0]}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Employee details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${employee.firstName} ${employee.lastName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      employee.role,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Status indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: employee.isActive ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              
              // Chevron icon
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to get color based on role
  Color _getRoleColor(String role) {
    switch (role) {
      case 'Manager':
        return Colors.indigo;
      case 'Attendant':
        return Colors.teal;
      case 'Admin':
        return Colors.deepOrange;
      default:
        return AppTheme.primaryBlue;
    }
  }
}
