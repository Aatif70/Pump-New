class Shift {
  final String? id;
  final String startTime;
  final String endTime;
  final int shiftNumber;
  final int shiftDuration;
  final DateTime? shiftDate;
  List<String> assignedEmployeeIds;
  final List<Map<String, dynamic>>? assignedEmployees;

  Shift({
    this.id,
    required this.startTime,
    required this.endTime,
    required this.shiftNumber,
    required this.shiftDuration,
    this.shiftDate,
    this.assignedEmployeeIds = const [],
    this.assignedEmployees,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    // Make a copy of the json map to ensure it's a Map<String, dynamic>
    Map<String, dynamic> data = Map<String, dynamic>.from(json);
    
    // Handle both direct API responses and nested data responses
    if (data.containsKey('data') && data['data'] is Map) {
      data = Map<String, dynamic>.from(data['data'] as Map);
    }
    
    // The API uses "shiftId" instead of "id"
    String? shiftId = data['shiftId']?.toString() ?? data['id']?.toString();
    
    // Parse time fields
    String startTime = data['startTime']?.toString() ?? '';
    // Remove seconds if present (convert "08:00:00" to "08:00")
    if (startTime.length > 5) {
      startTime = startTime.substring(0, 5);
    }
    
    String endTime = data['endTime']?.toString() ?? '';
    // Remove seconds if present
    if (endTime.length > 5) {
      endTime = endTime.substring(0, 5);
    }
    
    // Parse number fields safely
    int shiftNumber = 0;
    if (data['shiftNumber'] != null) {
      shiftNumber = int.tryParse(data['shiftNumber'].toString()) ?? 0;
    }
    
    int shiftDuration = 0;
    if (data['shiftDuration'] != null) {
      shiftDuration = int.tryParse(data['shiftDuration'].toString()) ?? 0;
    }
    
    // Parse shift date if available
    DateTime? shiftDate;
    if (data['shiftDate'] != null) {
      try {
        shiftDate = DateTime.parse(data['shiftDate'].toString());
      } catch (e) {
        print('Error parsing shift date: ${data['shiftDate']}');
      }
    }
    
    // Parse assigned employee IDs
    List<String> assignedEmployeeIds = [];
    if (data['assignedEmployeeIds'] != null && data['assignedEmployeeIds'] is List) {
      assignedEmployeeIds = List<String>.from(data['assignedEmployeeIds']);
    }
    // Also check for "employees" or similar keys
    else if (data['employees'] != null && data['employees'] is List) {
      final employeesList = data['employees'] as List;
      if (employeesList.isNotEmpty) {
        if (employeesList.first is Map) {
          // Extract IDs from employee objects
          assignedEmployeeIds = employeesList
              .map((e) => (e['employeeId'] ?? e['id'])?.toString())
              .where((id) => id != null)
              .cast<String>()
              .toList();
        } else if (employeesList.first is String) {
          // Direct list of IDs
          assignedEmployeeIds = List<String>.from(employeesList);
        }
      }
    }
    
    // Parse assigned employees details if available
    List<Map<String, dynamic>>? assignedEmployees;
    if (data['assignedEmployees'] != null && data['assignedEmployees'] is List) {
      assignedEmployees = List<Map<String, dynamic>>.from(
        (data['assignedEmployees'] as List).map((e) => Map<String, dynamic>.from(e))
      );
    }
    
    return Shift(
      id: shiftId,
      startTime: startTime,
      endTime: endTime,
      shiftNumber: shiftNumber,
      shiftDuration: shiftDuration,
      shiftDate: shiftDate,
      assignedEmployeeIds: assignedEmployeeIds,
      assignedEmployees: assignedEmployees,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      if (id != null) 'shiftId': id,  // Use shiftId for API compatibility
      'startTime': startTime,
      'endTime': endTime,
      'shiftNumber': shiftNumber,
      'shiftDuration': shiftDuration,
      if (shiftDate != null) 'shiftDate': shiftDate!.toIso8601String(),
    };
    
    // Only include assigned employees if there are any
    if (assignedEmployeeIds.isNotEmpty) {
      map['assignedEmployeeIds'] = assignedEmployeeIds;
    }
    
    return map;
  }
} 