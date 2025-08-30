// here we are defining the base URL and API endpoints for the application, makes it much easier.


import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  
  // Local development
  // static const String baseUrl = "http://10.0.2.2:8007"; // For Android emulator
  // static const String baseUrl = "http://127.0.0.1:8007"; // For local iOS simulator
  
  // Development server
  static const String baseUrl = "https://pump360.planet.ninja";
  // static const String baseUrl = "https://pumpbe.pxc.in";


  // App specific constants
  static const String appName = "Petrol Pump Manager";
  static const String someThingWentWrong = "Something went wrong.";
  static const String unAuthorized = "Unauthorized. Please login.";
  static const String internetConnectionMsg =
      "Something went wrong! Please check your internet connection.";
  static const String errorMessageKey = "message";

  // Customer API endpoints
  static const String customerEndpoint = "/api/Customers";

  // Vehicle Transaction API endpoints
  static const String vehicleTransactionEndpoint = "/api/VehicleTransaction";

  // API Endpoints
  static const String loginEndpoint = "/api/Auth/login";
  static const String registerPumpEndpoint = "/api/Pump";
  static const String shiftsEndpoint = "/api/Shift";
  static const String fuelTankEndpoint = "/api/FuelTank";
  static const String employeeEndpoint = "/api/Employee";
  static const String fuelDispenserEndpoint = "/api/FuelDispenser";
  static const String nozzleEndpoint = "/api/Nozzle";
  static const String pricingEndpoint = "/api/Pricing";
  static const String currentPricingEndpoint = "/api/Pricing/current";
  static const String priceByIdEndpoint = "/api/Pricing/"; // Will be appended with ID
  static const String latestPricingEndpoint = "/api/Pricing/latest/"; // Will be appended with fuel type
  static const String pricingHistoryEndpoint = "/api/Pricing/history/"; // Will be appended with fuel type
  static const String employeeShiftEndpoint = "/api/EmployeeShift";
  static const String shiftSalesEndpoint = "/api/ShiftSales";
  static const String supplierEndpoint = "/api/Suppliers/ByPump";
  static const String fuelDeliveryEndpoint = "/api/FuelDelivery";
  static const String stockMovementEndpoint = "/api/Reporting/stock-movement";
  static const String comprehensiveDailyReportEndpoint = "/api/Reporting/comprehensive-daily";
  static const String attendanceEndpoint = "/api/Attendance/";


  // Full API URLs with debug logging
  static String getLoginUrl() {
    final url = baseUrl + loginEndpoint;
    developer.log('Login URL: $url');
    return url;
  }

  // Attendance API URLs
  static String getCheckInUrl() {
    final url = baseUrl + attendanceEndpoint + 'check-in';
    developer.log('Check-in URL: $url');
    print('API_CONSTANTS: Check-in URL: $url');
    return url;
  }

  static String getCheckOutUrl() {
    final url = baseUrl + attendanceEndpoint + 'check-out';
    developer.log('Check-out URL: $url');
    print('API_CONSTANTS: Check-out URL: $url');
    return url;
  }

  static String getAttendanceByEmployeeUrl(String employeeId) {
    final url = baseUrl + attendanceEndpoint + 'employee/' + employeeId;
    developer.log('Attendance By Employee URL: $url');
    print('API_CONSTANTS: Attendance By Employee URL: $url');
    return url;
  }

  static String getActiveAttendanceUrl(String employeeId) {
    final url = baseUrl + attendanceEndpoint + 'employee/' + employeeId + '/active';
    developer.log('Active Attendance URL: $url');
    print('API_CONSTANTS: Active Attendance URL: $url');
    return url;
  }

  static String getIsCheckedInUrl(String employeeId) {
    final url = baseUrl + attendanceEndpoint + 'employee/' + employeeId + '/is-checked-in';
    developer.log('Is Checked In URL: $url');
    print('API_CONSTANTS: Is Checked In URL: $url');
    return url;
  }

  // Daily attendance endpoints
  static String getDailyAttendanceUrl(String petrolPumpId, DateTime date) {
    final formattedDate = Uri.encodeComponent(date.toIso8601String());
    final url = baseUrl + attendanceEndpoint + 'petrol-pump/' + petrolPumpId + '/daily?date=' + formattedDate;
    developer.log('Daily Attendance URL: $url');
    print('API_CONSTANTS: Daily Attendance URL: $url');
    return url;
  }

  static String getDailyAttendanceReportUrl(String petrolPumpId, DateTime date) {
    // Format date as yyyy-MM-dd
    final formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final url = baseUrl + attendanceEndpoint + 'petrol-pump/' + petrolPumpId + '/daily-report?date=' + formattedDate;
    developer.log('Daily Attendance Report URL: $url');
    print('API_CONSTANTS: Daily Attendance Report URL: $url');
    return url;
  }

  static String getLateArrivalsUrl(String petrolPumpId, DateTime date) {
    final formattedDate = Uri.encodeComponent(date.toIso8601String());
    final url = baseUrl + attendanceEndpoint + 'petrol-pump/' + petrolPumpId + '/late-arrivals?date=' + formattedDate;
    developer.log('Late Arrivals URL: $url');
    print('API_CONSTANTS: Late Arrivals URL: $url');
    return url;
  }

  static String getRegisterPumpUrl() {
    final url = baseUrl + registerPumpEndpoint;
    developer.log('Register URL: $url');
    return url;
  }
  
  static String getShiftsUrl() {
    final url = baseUrl + shiftsEndpoint;
    developer.log('Shifts URL: $url');
    return url;
  }

  static String getUpdateShiftUrl(String shiftId) {
    // The API expects the format: /api/Shift/{shiftId}
    final url = baseUrl + shiftsEndpoint + '/' + shiftId;
    developer.log('Update Shift URL: $url');
    print('API_CONSTANTS: Update Shift URL for ID $shiftId: $url');
    return url;
  }

  static String getDeleteShiftUrl(String shiftId) {
    // The API expects the format: /api/Shift/{shiftId}
    final url = baseUrl + shiftsEndpoint + '/' + shiftId;
    developer.log('Delete Shift URL: $url');
    print('API_CONSTANTS: Delete Shift URL for ID $shiftId: $url');
    return url;
  }

  static String getFuelTankUrl() {
    final url = baseUrl + fuelTankEndpoint;
    developer.log('Fuel Tank URL: $url');
    return url;
  }

  static String getEmployeeUrl() {
    final url = baseUrl + employeeEndpoint;
    developer.log('Employee URL: $url');
    return url;
  }
  
  static String getFuelDispenserUrl() {
    final url = baseUrl + fuelDispenserEndpoint;
    developer.log('Fuel Dispenser URL: $url');
    return url;
  }

  static String getFuelDispenserByIdUrl(String id) {
    final url = baseUrl + fuelDispenserEndpoint + '/' + id;
    developer.log('Fuel Dispenser by ID URL: $url');
    print('API_CONSTANTS: Fuel Dispenser by ID URL: $url');
    return url;
  }

  static String getFuelDispenserByPetrolPumpIdUrl(String petrolPumpId) {
    final url = baseUrl + fuelDispenserEndpoint + '/ByPump/' + petrolPumpId;
    developer.log('Fuel Dispenser by Petrol Pump ID URL: $url');
    print('API_CONSTANTS: Fuel Dispenser by Petrol Pump ID URL: $url');
    return url;
  }

  static String getUpdateFuelDispenserUrl() {
    final url = baseUrl + fuelDispenserEndpoint;
    developer.log('Update Fuel Dispenser URL: $url');
    print('API_CONSTANTS: Update Fuel Dispenser URL: $url');
    return url;
  }

  // Nozzle API endpoints
  static String getNozzleUrl() {
    final url = baseUrl + nozzleEndpoint;
    developer.log('Nozzle URL: $url');
    print('API_CONSTANTS: Nozzle URL: $url');
    return url;
  }

  // New method to get nozzle URL with fuel type override
  static String getNozzleUrlWithFuelTypeOverride() {
    final url = baseUrl + nozzleEndpoint + '?allowDifferentFuelType=true';
    developer.log('Nozzle URL with fuel type override: $url');
    print('API_CONSTANTS: Nozzle URL with fuel type override: $url');
    return url;
  }

  static String getNozzleByIdUrl(String id) {
    final url = baseUrl + nozzleEndpoint + '/' + id;
    developer.log('Nozzle by ID URL: $url');
    print('API_CONSTANTS: Nozzle by ID URL: $url');
    return url;
  }

  static String getNozzlesByDispenserUrl(String dispenserId) {
    if (dispenserId.isEmpty) {
      print('API_CONSTANTS: Warning - Empty dispenser ID provided for nozzle URL');
      return baseUrl + nozzleEndpoint; // Return base nozzle endpoint instead
    }
    final url = baseUrl + nozzleEndpoint + '/Dispenser/' + dispenserId;
    developer.log('Nozzles by Dispenser URL: $url');
    print('API_CONSTANTS: Nozzles by Dispenser URL: $url');
    return url;
  }

  // Pricing API endpoints
  static String getSetPriceUrl() {
    final url = baseUrl + pricingEndpoint;
    developer.log('Set Price URL: $url');
    print('DEBUG: Set Fuel Price API URL: $url');
    print('DEBUG: Pricing endpoint: $pricingEndpoint');
    return url;
  }

  static String getCurrentPricesUrl() {
    final url = baseUrl + currentPricingEndpoint;
    developer.log('Current Prices URL: $url');
    print('DEBUG: Current Prices API URL: $url');
    return url;
  }

  static String getCurrentPricesByPetrolPumpUrl(String petrolPumpId) {
    final url = baseUrl + '/api/Pricing/current/' + petrolPumpId;
    developer.log('Current Prices by Petrol Pump URL: $url');
    print('API_CONSTANTS: Current Prices by Petrol Pump URL: $url');
    return url;
  }

  static String getPriceByIdUrl(String priceId) {
    final url = baseUrl + priceByIdEndpoint + priceId;
    developer.log('Get Price By ID URL: $url');
    print('DEBUG: Get Price By ID API URL: $url');
    print('DEBUG: Price ID: $priceId');
    return url;
  }

  static String getDeletePriceUrl(String priceId) {
    final url = baseUrl + pricingEndpoint + '/' + priceId;
    developer.log('Delete Price URL: $url');
    print('DEBUG: Delete Price API URL: $url');
    print('DEBUG: Deleting Price ID: $priceId');
    return url;
  }

  static String getUpdatePriceUrl(String priceId) {
    final url = baseUrl + pricingEndpoint + '/' + priceId;
    developer.log('Update Price URL: $url');
    print('DEBUG: Update Price API URL: $url');
    print('DEBUG: Updating Price ID: $priceId');
    return url;
  }

  static String getLatestPriceByFuelTypeUrl(String fuelType) {
    // URL encode the fuelType to handle spaces and special characters
    final encodedFuelType = Uri.encodeComponent(fuelType);
    final url = baseUrl + latestPricingEndpoint + encodedFuelType;
    developer.log('Latest Price by Fuel Type URL: $url');
    print('API_CONSTANTS: Latest Price by Fuel Type URL: $url');
    return url;
  }
  
  static String getFuelPriceByNozzleUrl(String nozzleId) {
    final url = baseUrl + '/api/Pricing/nozzle/' + nozzleId;
    developer.log('Fuel Price by Nozzle URL: $url');
    print('API_CONSTANTS: Fuel Price by Nozzle URL: $url');
    return url;
  }

  static String getPriceHistoryByFuelTypeUrl(String fuelType, {String? fuelTypeId}) {
    // The user needs to pass fuelTypeId parameter to the API endpoint now
    final String url = baseUrl + '/api/Pricing/history/fuelType' + (fuelTypeId != null ? '?fuelTypeId=$fuelTypeId' : '');
    
    developer.log('Price History by Fuel Type URL: $url');
    print('DEBUG: Price History API URL: $url');
    print('DEBUG: Using fuelTypeId: $fuelTypeId');
    return url;
  }

  static String getPriceHistoryUrl(String petrolPumpId, String fuelTypeId) {
    final url = baseUrl + '/api/Pricing/history/' + petrolPumpId + '/' + fuelTypeId;
    developer.log('Price History URL: $url');
    print('DEBUG: Price History API URL: $url');
    return url;
  }

  // Nozzle Reading API endpoints
  static String getNozzleReadingSubmitUrl() {
    final url = baseUrl + '/api/NozzleReadings';
    developer.log('Nozzle Reading Submit URL: $url');
    print('API_CONSTANTS: Nozzle Reading Submit URL: $url');
    return url;
  }
  
  static String getNozzleReadingsByEmployeeUrl(String employeeId) {
    final url = baseUrl + '/api/NozzleReadings/ByEmployee/' + employeeId;
    developer.log('Nozzle Readings By Employee URL: $url');
    print('API_CONSTANTS: Nozzle Readings By Employee URL: $url');
    return url;
  }

  static String getNozzleReadingsByNozzleIdUrl(String nozzleId) {
    final url = baseUrl + '/api/NozzleReadings/ByNozzle/' + nozzleId;
    developer.log('Nozzle Readings By Nozzle ID URL: $url');
    print('API_CONSTANTS: Nozzle Readings By Nozzle ID URL: $url');
    return url;
  }

  // Employee Shift API endpoints
  static String getEmployeeShiftUrl() {
    final url = baseUrl + employeeShiftEndpoint;
    developer.log('Employee Shift URL: $url');
    print('API_CONSTANTS: Employee Shift URL: $url');
    return url;
  }

  static String getEmployeeShiftByIdUrl(String id) {
    final url = baseUrl + employeeShiftEndpoint + '/' + id;
    developer.log('Employee Shift by ID URL: $url');
    print('API_CONSTANTS: Employee Shift by ID URL: $url');
    return url;
  }

  static String getDeleteEmployeeShiftUrl(String employeeShiftId) {
    final url = baseUrl + '/api/EmployeeShift/' + employeeShiftId;
    developer.log('Delete Employee Shift URL: $url');
    print('API_CONSTANTS: Delete Employee Shift URL: $url');
    return url;
  }

  static String getEmployeesByShiftIdUrl(String shiftId) {
    final url = baseUrl + employeeShiftEndpoint + '/shift/' + shiftId;
    developer.log('Employees by Shift ID URL: $url');
    print('API_CONSTANTS: Employees by Shift ID URL: $url');
    return url;
  }

  static String getEmployeeShiftsByShiftIdUrl(String shiftId) {
    final url = baseUrl + employeeShiftEndpoint + '/shift/' + shiftId;
    developer.log('Employee Shifts by Shift ID URL: $url');
    print('API_CONSTANTS: Employee Shifts by Shift ID URL: $url');
    return url;
  }

  static String getShiftsByEmployeeIdUrl(String employeeId) {
    // Use the employee endpoint to get shifts assigned to an employee
    final url = baseUrl + employeeShiftEndpoint + '/employee/' + employeeId;
    developer.log('Shifts by Employee ID URL: $url');
    print('API_CONSTANTS: Shifts by Employee ID URL: $url');
    return url;
  }

  static String getAssignEmployeeToShiftUrl() {
    final url = baseUrl + employeeShiftEndpoint + '/assign';
    developer.log('Assign Employee to Shift URL: $url');
    print('API_CONSTANTS: Assign Employee to Shift URL: $url');
    return url;
  }

  static String getShiftSalesByEmployeeUrl(String employeeId) {
    final url = baseUrl + shiftSalesEndpoint + '/employee/' + employeeId;
    developer.log('Shift Sales By Employee URL: $url');
    print('API_CONSTANTS: Shift Sales By Employee URL: $url');
    return url;
  }

  // Supplier API endpoints
  static String getSupplierUrl() {
    final url = baseUrl + supplierEndpoint;
    developer.log('Supplier URL: $url');
    print('API_CONSTANTS: Supplier URL: $url');
    return url;
  }

  // static String getSupplierByIdUrl(String supplierId) {
  //   final url = baseUrl + supplierEndpoint + '/' + supplierId;
  //   developer.log('Supplier by ID URL: $url');
  //   print('API_CONSTANTS: Supplier by ID URL: $url');
  //   return url;
  // }

  static String getUpdateSupplierUrl(String supplierDetailId) {
    final url = baseUrl + supplierEndpoint + '/' + supplierDetailId;
    developer.log('Update Supplier URL: $url');
    print('API_CONSTANTS: Update Supplier URL: $url');
    return url;
  }

  static String getDeleteSupplierUrl(String supplierDetailId) {
    final url = baseUrl + supplierEndpoint + '/' + supplierDetailId;
    developer.log('Delete Supplier URL: $url');
    print('API_CONSTANTS: Delete Supplier URL: $url');
    return url;
  }

  // Fuel Delivery API endpoints
  static String getFuelDeliveryUrl() {
    final url = baseUrl + fuelDeliveryEndpoint;
    developer.log('Fuel Delivery URL: $url');
    print('API_CONSTANTS: Fuel Delivery URL: $url');
    return url;
  }
  
  static String getFuelDeliveriesByPumpUrl() {
    final url = baseUrl + fuelDeliveryEndpoint + '/ByPump';
    developer.log('Fuel Deliveries By Pump URL: $url');
    print('API_CONSTANTS: Fuel Deliveries By Pump URL: $url');
    return url;
  }

  static String getFuelDeliveryByIdUrl(String fuelDeliveryId) {
    final url = baseUrl + fuelDeliveryEndpoint + '/' + fuelDeliveryId;
    developer.log('Fuel Delivery by ID URL: $url');
    print('API_CONSTANTS: Fuel Delivery by ID URL: $url');
    return url;
  }

  static String getUpdateFuelDeliveryUrl(String fuelDeliveryId) {
    final url = baseUrl + fuelDeliveryEndpoint + '/' + fuelDeliveryId;
    developer.log('Update Fuel Delivery URL: $url');
    print('API_CONSTANTS: Update Fuel Delivery URL: $url');
    return url;
  }

  static String getDeleteFuelDeliveryUrl(String fuelDeliveryId) {
    final url = baseUrl + fuelDeliveryEndpoint + '/' + fuelDeliveryId;
    developer.log('Delete Fuel Delivery URL: $url');
    print('API_CONSTANTS: Delete Fuel Delivery URL: $url');
    return url;
  }

  // Shift Sales Report endpoint
  static String getShiftSalesReportUrl(DateTime startDate, DateTime endDate) {
    final formattedStartDate = Uri.encodeComponent(startDate.toIso8601String());
    final formattedEndDate = Uri.encodeComponent(endDate.toIso8601String());
    final url = '$baseUrl/api/Reporting/shift-sales?startDate=$formattedStartDate&endDate=$formattedEndDate';
    developer.log('Shift Sales Report URL: $url');
    print('API_CONSTANTS: Shift Sales Report URL: $url');
    return url;
  }
  
  // Employee Performance Report endpoint
  static String getEmployeePerformanceReportUrl(DateTime startDate, DateTime endDate, String employeeId) {
    final formattedStartDate = Uri.encodeComponent(startDate.toIso8601String());
    final formattedEndDate = Uri.encodeComponent(endDate.toIso8601String());
    final url = '$baseUrl/api/Reporting/employee-performance?startDate=$formattedStartDate&endDate=$formattedEndDate&employeeId=$employeeId';
    developer.log('Employee Performance Report URL: $url');
    print('API_CONSTANTS: Employee Performance Report URL: $url');
    return url;
  }

  // Stock Movement Report endpoint
  static String getStockMovementReportUrl(DateTime date) {
    final formattedDate = Uri.encodeComponent(date.toIso8601String());
    final url = '$baseUrl$stockMovementEndpoint?date=$formattedDate';
    developer.log('Stock Movement Report URL: $url');
    print('API_CONSTANTS: Stock Movement Report URL: $url');
    return url;
  }

  // Comprehensive Daily Report endpoint
  static String getComprehensiveDailyReportUrl(DateTime date) {
    final formattedDate = Uri.encodeComponent(date.toIso8601String());
    final url = '$baseUrl$comprehensiveDailyReportEndpoint?date=$formattedDate';
    developer.log('Comprehensive Daily Report URL: $url');
    print('API_CONSTANTS: Comprehensive Daily Report URL: $url');
    return url;
  }

  static String getGovernmentTestingUrl() {
    final url = baseUrl + governmentTestingEndpoint;
    developer.log('Government Testing URL: $url');
    print('API_CONSTANTS: Government Testing URL: $url');
    return url;
  }
  
  static String getGovernmentTestingByPumpUrl(String petrolPumpId) {
    final url = baseUrl + governmentTestingEndpoint + '/petrol-pump/' + petrolPumpId;
    developer.log('Government Testing By Pump URL: $url');
    print('API_CONSTANTS: Government Testing By Pump URL: $url');
    return url;
  }

  // HTTP Status codes
  static const int statusOk = 200;
  static const int statusCreated = 201;
  static const int statusNoContent = 204;  // Added for DELETE operations
  static const int statusBadRequest = 400;
  static const int statusUnauthorized = 401;
  static const int statusForbidden = 403;
  static const int statusNotFound = 404;
  static const int statusServerError = 500;


  // Other constants
  static const String authTokenKey = "auth_token";
  static const String cashReconciliationEndpoint = "/api/Reporting/cash-reconciliation";
  static const String shiftsByPetrolPumpEndpoint = "/api/Shift";
  static const String governmentTestingEndpoint = "/api/GovernmentTesting";

  static String getPumpProfileUrl(String pumpId) {
    final url = baseUrl + "/api/Pump/" + pumpId;
    developer.log('Pump Profile URL: $url');
    print('API_CONSTANTS: Pump Profile URL: $url');
    return url;
  }

  static String getUpdatePumpProfileUrl(String pumpId) {
    final url = baseUrl + "/api/Pump/" + pumpId;
    developer.log('Update Pump Profile URL: $url');
    print('API_CONSTANTS: Update Pump Profile URL: $url');
    return url;
  }
  
  static String getFuelTypesUrl() {
    final url = baseUrl + "/api/FuelType";
    developer.log('Fuel Types URL: $url');
    print('API_CONSTANTS: Fuel Types URL: $url');
    return url;
  }
  
  static String getPumpFuelTypesUrl(String petrolPumpId) {
    final url = baseUrl + "/api/FuelType/petrolpump/" + petrolPumpId;
    developer.log('Pump Fuel Types URL: $url');
    print('API_CONSTANTS: Pump Fuel Types URL: $url');
    return url;
  }

  // New endpoint for fuel types by petrol pump
  static const String fuelTypeByPetrolPumpEndpoint = "/api/FuelType/petrolpump";
  
  static String getFuelTypeByPetrolPumpUrl() {
    final url = baseUrl + fuelTypeByPetrolPumpEndpoint;
    developer.log('API_CONSTANTS: Fuel Type by Petrol Pump URL: $url');
    print('API_CONSTANTS: Fuel Type by Petrol Pump URL: $url');
    return url;
  }

  // Fuel Quality Check API endpoint
  static const String fuelQualityCheckEndpoint = "/api/FuelQualityCheck";
  
  static String getFuelQualityCheckUrl() {
    final url = baseUrl + fuelQualityCheckEndpoint;
    developer.log('Fuel Quality Check URL: $url');
    print('API_CONSTANTS: Fuel Quality Check URL: $url');
    return url;
  }

  static String getFuelQualityCheckByTankUrl(String fuelTankId) {
    final url = baseUrl + fuelQualityCheckEndpoint + '/ByTank/' + fuelTankId;
    developer.log('Fuel Quality Check By Tank URL: $url');
    print('API_CONSTANTS: Fuel Quality Check By Tank URL: $url');
    return url;
  }

  // Cash Reconciliation Report endpoint
  static String getCashReconciliationReportUrl(DateTime date, [String? shiftId]) {
    final formattedDate = Uri.encodeComponent(date.toIso8601String());
    String url;
    
    // Only include shiftId if provided
    if (shiftId != null && shiftId.isNotEmpty) {
      url = '$baseUrl$cashReconciliationEndpoint?date=$formattedDate&shiftId=$shiftId';
    }
    else {
      url = '$baseUrl$cashReconciliationEndpoint?date=$formattedDate&shiftId=$shiftId';
      print('YAHAN GADBAD HAI');
    }
    
    developer.log('Cash Reconciliation Report URL: $url');
    print('API_CONSTANTS: Cash Reconciliation Report URL: $url');
    return url;
  }

  // Shifts by Petrol Pump ID endpoint
  static String getShiftsByPetrolPumpUrl(String petrolPumpId) {
    final url = '$baseUrl$shiftsByPetrolPumpEndpoint/$petrolPumpId/shifts';
    developer.log('Shifts by Petrol Pump URL: $url');
    print('API_CONSTANTS: Shifts by Petrol Pump URL: $url');
    return url;
  }

  // New method for debugging the daily report shifts endpoint
  static String getShiftsByPetrolPumpForReportingUrl(String petrolPumpId) {
    // Try a different format that might be expected by the API
    final url = '$baseUrl$shiftsEndpoint/ByPump/$petrolPumpId';
    developer.log('DEBUG: Daily Report - Shifts by Petrol Pump URL: $url');
    print('DEBUG: Daily Report - Shifts by Petrol Pump URL: $url');
    
    // Also log alternative URL formats for debugging
    final altUrl1 = '$baseUrl$shiftsEndpoint/$petrolPumpId/shifts';
    final altUrl2 = '$baseUrl/api/Shift/ByPetrolPump/$petrolPumpId';
    final altUrl3 = '$baseUrl/api/Shift/ByPump?petrolPumpId=$petrolPumpId';
    print('DEBUG: Alternative URL formats:');
    print('DEBUG: Format 1: $altUrl1');
    print('DEBUG: Format 2: $altUrl2');
    print('DEBUG: Format 3: $altUrl3');
    
    return url;
  }

  // Customer API URL methods
  static String getCustomersUrl() {
    final url = baseUrl + customerEndpoint;
    developer.log('Customers URL: $url');
    print('API_CONSTANTS: Customers URL: $url');
    return url;
  }

  static String getCustomersByPumpUrl(String pumpId) {
    final url = baseUrl + customerEndpoint + '/ByPump/' + pumpId;
    developer.log('Customers By Pump URL: $url');
    print('API_CONSTANTS: Customers By Pump URL: $url');
    return url;
  }

  // Vehicle Transaction API URL methods
  static String getVehicleTransactionUrl() {
    final url = baseUrl + vehicleTransactionEndpoint;
    developer.log('Vehicle Transaction URL: $url');
    print('API_CONSTANTS: Vehicle Transaction URL: $url');
    return url;
  }

  static String getVehicleTransactionsUrl(String petrolPumpId) {
    final url = baseUrl + vehicleTransactionEndpoint + '/petrol-pump/' + petrolPumpId;
    developer.log('Vehicle Transactions By Pump URL: $url');
    print('API_CONSTANTS: Vehicle Transactions By Pump URL: $url');
    return url;
  }

  static String getVehicleTransactionByIdUrl(String transactionId) {
    final url = baseUrl + vehicleTransactionEndpoint + '/' + transactionId;
    developer.log('Vehicle Transaction By ID URL: $url');
    print('API_CONSTANTS: Vehicle Transaction By ID URL: $url');
    return url;
  }

  // Method to get the stored auth token
  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(authTokenKey);
  }
} 