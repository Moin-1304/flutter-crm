import 'package:boilerplate/domain/entity/dcr/dcr_api_models.dart';
import 'package:boilerplate/domain/usecase/dcr/save_expense_usecase.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api_models.dart';

/// Helper class for managing expense operations
class ExpenseHelper {
  static final SaveExpenseUseCase _saveExpenseUseCase = SaveExpenseUseCase();

  /// Save or update expense with the provided JSON data
  /// This method automatically determines if it's a create or update based on ID presence
  /// This method accepts dynamic JSON data as specified in the requirements
  static Future<ExpenseSaveResponse> saveExpenseFromJson(Map<String, dynamic> jsonData) async {
    try {
      // Validate the data first
      if (!validateExpenseData(jsonData)) {
        throw Exception('Invalid expense data provided');
      }

      // Check if this is an update (ID present) or create (ID null/0)
      final hasId = jsonData['Id'] != null && jsonData['Id'] != 0;
      final operation = hasId ? 'UPDATE' : 'CREATE';
      
      print('Performing $operation operation for expense...');
      if (hasId) {
        print('Updating existing expense with ID: ${jsonData['Id']}');
      } else {
        print('Creating new expense');
      }

      // Create ExpenseSaveRequest from the provided JSON
      final request = ExpenseSaveRequest.fromJson(jsonData);
      
      // Call the use case to save/update the expense
      return await _saveExpenseUseCase.call(request);
    } catch (e) {
      throw Exception('Failed to save expense from JSON: ${e.toString()}');
    }
  }

  /// Create a new expense (ID should be null or 0)
  static Future<ExpenseSaveResponse> createExpense(Map<String, dynamic> jsonData) async {
    try {
      // Ensure ID is null or 0 for create operation
      if (jsonData['Id'] != null && jsonData['Id'] != 0) {
        throw Exception('Cannot create new expense with existing ID. Use updateExpense() instead.');
      }

      // Set ID to null to ensure it's a create operation
      final createData = Map<String, dynamic>.from(jsonData);
      createData['Id'] = null;
      
      print('Creating new expense...');
      return await saveExpenseFromJson(createData);
    } catch (e) {
      throw Exception('Failed to create expense: ${e.toString()}');
    }
  }

  /// Update an existing expense (ID must be present and valid)
  static Future<ExpenseSaveResponse> updateExpense(Map<String, dynamic> jsonData) async {
    try {
      // Ensure ID is present for update operation
      if (jsonData['Id'] == null || jsonData['Id'] == 0) {
        throw Exception('Cannot update expense without valid ID. Use createExpense() instead.');
      }

      print('Updating existing expense with ID: ${jsonData['Id']}');
      return await saveExpenseFromJson(jsonData);
    } catch (e) {
      throw Exception('Failed to update expense: ${e.toString()}');
    }
  }

  /// Save or update expense with individual parameters
  /// Automatically determines if it's a create or update based on ID presence
  static Future<ExpenseSaveResponse> saveExpense({
    int? id,
    required int dcrId,
    required String dateOfExpense,
    required int employeeId,
    required int cityId,
    int? clusterId,
    required int bizUnit,
    required int expenceType,
    required double expenseAmount,
    required String remarks,
    required int userId,
    required String dcrStatus,
    required int dcrStatusId,
    String? clusterNames,
    required int isGeneric,
    String? employeeName,
    List<ExpenseAttachment> attachments = const [],
  }) async {
    try {
      // Check if this is an update (ID present) or create (ID null/0)
      final hasId = id != null && id != 0;
      final operation = hasId ? 'UPDATE' : 'CREATE';
      
      print('Performing $operation operation for expense...');
      if (hasId) {
        print('Updating existing expense with ID: $id');
      } else {
        print('Creating new expense');
      }

      final request = SaveExpenseUseCase.createRequest(
        id: id,
        dcrId: dcrId,
        dateOfExpense: dateOfExpense,
        employeeId: employeeId,
        cityId: cityId,
        clusterId: clusterId,
        bizUnit: bizUnit,
        expenceType: expenceType,
        expenseAmount: expenseAmount,
        remarks: remarks,
        userId: userId,
        dcrStatus: dcrStatus,
        dcrStatusId: dcrStatusId,
        clusterNames: clusterNames,
        isGeneric: isGeneric,
        employeeName: employeeName,
        attachments: attachments,
      );
      
      return await _saveExpenseUseCase.call(request);
    } catch (e) {
      throw Exception('Failed to save expense: ${e.toString()}');
    }
  }

  /// Create a new expense with individual parameters (ID should be null)
  static Future<ExpenseSaveResponse> createExpenseWithParams({
    required int dcrId,
    required String dateOfExpense,
    required int employeeId,
    required int cityId,
    int? clusterId,
    required int bizUnit,
    required int expenceType,
    required double expenseAmount,
    required String remarks,
    required int userId,
    required String dcrStatus,
    required int dcrStatusId,
    String? clusterNames,
    required int isGeneric,
    String? employeeName,
    List<ExpenseAttachment> attachments = const [],
  }) async {
    try {
      print('Creating new expense with parameters...');
      return await saveExpense(
        id: null, // Explicitly null for create
        dcrId: dcrId,
        dateOfExpense: dateOfExpense,
        employeeId: employeeId,
        cityId: cityId,
        clusterId: clusterId,
        bizUnit: bizUnit,
        expenceType: expenceType,
        expenseAmount: expenseAmount,
        remarks: remarks,
        userId: userId,
        dcrStatus: dcrStatus,
        dcrStatusId: dcrStatusId,
        clusterNames: clusterNames,
        isGeneric: isGeneric,
        employeeName: employeeName,
        attachments: attachments,
      );
    } catch (e) {
      throw Exception('Failed to create expense: ${e.toString()}');
    }
  }

  /// Update an existing expense with individual parameters (ID must be present)
  static Future<ExpenseSaveResponse> updateExpenseWithParams({
    required int id, // Required for update
    required int dcrId,
    required String dateOfExpense,
    required int employeeId,
    required int cityId,
    int? clusterId,
    required int bizUnit,
    required int expenceType,
    required double expenseAmount,
    required String remarks,
    required int userId,
    required String dcrStatus,
    required int dcrStatusId,
    String? clusterNames,
    required int isGeneric,
    String? employeeName,
    List<ExpenseAttachment> attachments = const [],
  }) async {
    try {
      print('Updating existing expense with ID: $id');
      return await saveExpense(
        id: id,
        dcrId: dcrId,
        dateOfExpense: dateOfExpense,
        employeeId: employeeId,
        cityId: cityId,
        clusterId: clusterId,
        bizUnit: bizUnit,
        expenceType: expenceType,
        expenseAmount: expenseAmount,
        remarks: remarks,
        userId: userId,
        dcrStatus: dcrStatus,
        dcrStatusId: dcrStatusId,
        clusterNames: clusterNames,
        isGeneric: isGeneric,
        employeeName: employeeName,
        attachments: attachments,
      );
    } catch (e) {
      throw Exception('Failed to update expense: ${e.toString()}');
    }
  }

  /// Create a sample expense JSON for testing
  static Map<String, dynamic> createSampleExpenseJson({
    int? id,
    int dcrId = 0,
    String dateOfExpense = "2025-10-29",
    int employeeId = 61,
    int cityId = 152608,
    int? clusterId,
    int bizUnit = 1,
    int expenceType = 1,
    double expenseAmount = 6000.0,
    String remarks = "Test data",
    int userId = 10,
    String dcrStatus = "Draft",
    int dcrStatusId = 1,
    String? clusterNames,
    int isGeneric = 1,
    String? employeeName,
    List<Map<String, dynamic>>? attachments,
  }) {
    return {
      "Id": id,
      "DCRId": dcrId,
      "DateOfExpense": dateOfExpense,
      "EmployeeId": employeeId,
      "CityId": cityId,
      "ClusterId": clusterId,
      "BizUnit": bizUnit,
      "ExpenceType": expenceType,
      "ExpenseAmount": expenseAmount,
      "Remarks": remarks,
      "UserId": userId,
      "DCRStatus": dcrStatus,
      "DCRStatusId": dcrStatusId,
      "ClusterNames": clusterNames,
      "IsGeneric": isGeneric,
      "EmployeeName": employeeName,
      "Attachments": attachments ?? [
        {
          "FileName": "SaleOrder_API_Documentation_v2.pdf",
          "FileType": "PDF",
          "FilePath": "/Uploads/Attachments/DCR/Expenses//SaleOrder_API_Documentation_v2_20251015_125357_82ee286a.pdf",
          "Type": "pdf"
        }
      ],
    };
  }

  /// Validate expense data before saving
  static bool validateExpenseData(Map<String, dynamic> jsonData) {
    try {
      // Check required fields
      final requiredFields = [
        'DCRId',
        'DateOfExpense',
        'EmployeeId',
        'CityId',
        'BizUnit',
        'ExpenceType',
        'ExpenseAmount',
        'Remarks',
        'UserId',
        'DCRStatus',
        'DCRStatusId',
        'IsGeneric',
      ];

      for (final field in requiredFields) {
        if (!jsonData.containsKey(field) || jsonData[field] == null) {
          print('Missing required field: $field');
          return false;
        }
      }

      // Validate data types
      if (jsonData['ExpenseAmount'] is! num || (jsonData['ExpenseAmount'] as num) <= 0) {
        print('Invalid ExpenseAmount: must be a positive number');
        return false;
      }

      if (jsonData['DateOfExpense'] is! String || 
          DateTime.tryParse(jsonData['DateOfExpense']) == null) {
        print('Invalid DateOfExpense: must be a valid date string');
        return false;
      }

      // Validate ID if present
      if (jsonData.containsKey('Id') && jsonData['Id'] != null) {
        if (jsonData['Id'] is! int || (jsonData['Id'] as int) <= 0) {
          print('Invalid Id: must be a positive integer or null');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Validation error: $e');
      return false;
    }
  }

  /// Check if the expense data represents an update operation (has valid ID)
  static bool isUpdateOperation(Map<String, dynamic> jsonData) {
    return jsonData['Id'] != null && jsonData['Id'] != 0;
  }

  /// Check if the expense data represents a create operation (no ID or ID is 0)
  static bool isCreateOperation(Map<String, dynamic> jsonData) {
    return jsonData['Id'] == null || jsonData['Id'] == 0;
  }
}
