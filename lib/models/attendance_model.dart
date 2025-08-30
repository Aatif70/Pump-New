class EmployeeAttendance {
  final String employeeAttendanceId;
  final String employeeId;
  final String shiftId;
  final String employeeName;
  final String shiftName;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double? totalHours;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final String? checkInLocation;
  final String? checkOutLocation;
  final String? remarks;
  final bool isLate;
  final double? overtimeHours;

  EmployeeAttendance({
    required this.employeeAttendanceId,
    required this.employeeId,
    required this.shiftId,
    required this.employeeName,
    required this.shiftName,
    this.checkInTime,
    this.checkOutTime,
    this.totalHours,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.checkInLocation,
    this.checkOutLocation,
    this.remarks,
    required this.isLate,
    this.overtimeHours,
  });

  factory EmployeeAttendance.fromJson(Map<String, dynamic> json) {
    return EmployeeAttendance(
      employeeAttendanceId: json['employeeAttendanceId'] ?? '',
      employeeId: json['employeeId'] ?? '',
      shiftId: json['shiftId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      shiftName: json['shiftName'] ?? '',
      checkInTime: json['checkInTime'] != null ? DateTime.parse(json['checkInTime']) : null,
      checkOutTime: json['checkOutTime'] != null ? DateTime.parse(json['checkOutTime']) : null,
      totalHours: json['totalHours']?.toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      status: json['status'] ?? '',
      checkInLocation: json['checkInLocation'],
      checkOutLocation: json['checkOutLocation'],
      remarks: json['remarks'],
      isLate: json['isLate'] ?? false,
      overtimeHours: json['overtimeHours']?.toDouble(),
    );
  }
}

class DailyAttendanceReport {
  final DateTime date;
  final String petrolPumpId;
  final String petrolPumpName;
  final List<EmployeeAttendance> attendances;
  final int totalEmployees;
  final int presentEmployees;
  final int absentEmployees;
  final double attendancePercentage;

  DailyAttendanceReport({
    required this.date,
    required this.petrolPumpId,
    required this.petrolPumpName,
    required this.attendances,
    required this.totalEmployees,
    required this.presentEmployees,
    required this.absentEmployees,
    required this.attendancePercentage,
  });

  factory DailyAttendanceReport.fromJson(Map<String, dynamic> json) {
    var attendancesList = <EmployeeAttendance>[];
    if (json['attendances'] != null) {
      attendancesList = List<EmployeeAttendance>.from(
        (json['attendances'] as List).map((x) => EmployeeAttendance.fromJson(x))
      );
    }

    return DailyAttendanceReport(
      date: DateTime.parse(json['date']),
      petrolPumpId: json['petrolPumpId'] ?? '',
      petrolPumpName: json['petrolPumpName'] ?? '',
      attendances: attendancesList,
      totalEmployees: json['totalEmployees'] ?? 0,
      presentEmployees: json['presentEmployees'] ?? 0,
      absentEmployees: json['absentEmployees'] ?? 0,
      attendancePercentage: (json['attendancePercentage'] ?? 0).toDouble(),
    );
  }
}

class AttendanceSummary {
  final String employeeId;
  final String employeeName;
  final DateTime startDate;
  final DateTime endDate;
  final int totalWorkingDays;
  final int daysPresent;
  final int daysAbsent;
  final int daysLate;
  final double attendancePercentage;
  final double totalHoursWorked;
  final double averageHoursPerDay;
  final double totalOvertimeHours;
  final List<AttendanceDetail> attendanceDetails;

  AttendanceSummary({
    required this.employeeId,
    required this.employeeName,
    required this.startDate,
    required this.endDate,
    required this.totalWorkingDays,
    required this.daysPresent,
    required this.daysAbsent,
    required this.daysLate,
    required this.attendancePercentage,
    required this.totalHoursWorked,
    required this.averageHoursPerDay,
    required this.totalOvertimeHours,
    required this.attendanceDetails,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    List<AttendanceDetail> details = [];
    if (json['attendanceDetails'] != null) {
      details = List<AttendanceDetail>.from(
        json['attendanceDetails'].map((detail) => AttendanceDetail.fromJson(detail))
      );
    }

    return AttendanceSummary(
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : DateTime.now(),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : DateTime.now(),
      totalWorkingDays: json['totalWorkingDays'] ?? 0,
      daysPresent: json['daysPresent'] ?? 0,
      daysAbsent: json['daysAbsent'] ?? 0,
      daysLate: json['daysLate'] ?? 0,
      attendancePercentage: json['attendancePercentage']?.toDouble() ?? 0.0,
      totalHoursWorked: json['totalHoursWorked']?.toDouble() ?? 0.0,
      averageHoursPerDay: json['averageHoursPerDay']?.toDouble() ?? 0.0,
      totalOvertimeHours: json['totalOvertimeHours']?.toDouble() ?? 0.0,
      attendanceDetails: details,
    );
  }
}

class AttendanceDetail {
  final String employeeAttendanceId;
  final String employeeId;
  final String shiftId;
  final String employeeName;
  final String shiftName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final double totalHours;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final String? checkInLocation;
  final String? checkOutLocation;
  final String? remarks;
  final bool isLate;
  final double overtimeHours;

  AttendanceDetail({
    required this.employeeAttendanceId,
    required this.employeeId,
    required this.shiftId,
    required this.employeeName,
    required this.shiftName,
    required this.checkInTime,
    this.checkOutTime,
    required this.totalHours,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.checkInLocation,
    this.checkOutLocation,
    this.remarks,
    required this.isLate,
    required this.overtimeHours,
  });

  factory AttendanceDetail.fromJson(Map<String, dynamic> json) {
    return AttendanceDetail(
      employeeAttendanceId: json['employeeAttendanceId'] ?? '',
      employeeId: json['employeeId'] ?? '',
      shiftId: json['shiftId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      shiftName: json['shiftName'] ?? '',
      checkInTime: json['checkInTime'] != null ? DateTime.parse(json['checkInTime']) : DateTime.now(),
      checkOutTime: json['checkOutTime'] != null ? DateTime.parse(json['checkOutTime']) : null,
      totalHours: json['totalHours']?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
      status: json['status'] ?? '',
      checkInLocation: json['checkInLocation'],
      checkOutLocation: json['checkOutLocation'],
      remarks: json['remarks'],
      isLate: json['isLate'] ?? false,
      overtimeHours: json['overtimeHours']?.toDouble() ?? 0.0,
    );
  }
} 