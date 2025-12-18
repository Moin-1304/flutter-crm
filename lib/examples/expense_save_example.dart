import 'package:boilerplate/domain/entity/dcr/dcr_api_models.dart';
import 'package:boilerplate/utils/expense/expense_helper.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api_models.dart';

/// Example demonstrating how to use the SaveExpenses API
class ExpenseSaveExample {
  
  /// Example 1: Update existing expense using the exact JSON structure provided
  static Future<void> updateExpenseWithProvidedJson() async {
    try {
      // This is the exact JSON structure you provided - WITH ID (UPDATE)
      final expenseJson = {
        "Id": 29, // ID present = UPDATE operation
        "DCRId": 0,
        "DateOfExpense": "2025-10-29",
        "EmployeeId": 61,
        "CityId": 152608,
        "ClusterId": null,
        "BizUnit": 1,
        "ExpenceType": 1,
        "ExpenseAmount": 6000.0,
        "Remarks": "Test data",
        "UserId": 10,
        "DCRStatus": "Draft",
        "DCRStatusId": 1,
        "ClusterNames": null,
        "IsGeneric": 1,
        "EmployeeName": null,
        "Attachments": [
          {
            "FileName": "SaleOrder_API_Documentation_v2.pdf",
            "FileType": "PDF",
            "FilePath": "/Uploads/Attachments/DCR/Expenses//SaleOrder_API_Documentation_v2_20251015_125357_82ee286a.pdf",
            "Type": "pdf"
          }
        ]
      };

      // Check operation type
      if (ExpenseHelper.isUpdateOperation(expenseJson)) {
        print('This is an UPDATE operation (ID present: ${expenseJson['Id']})');
      }

      // Validate the data before saving
      if (ExpenseHelper.validateExpenseData(expenseJson)) {
        print('Expense data is valid, proceeding to update...');
        
        // Update the expense (will automatically detect it's an update due to ID presence)
        final response = await ExpenseHelper.updateExpense(expenseJson);
        
        if (response.success) {
          print('Expense updated successfully!');
          print('Message: ${response.message}');
          if (response.expenseId != null) {
            print('Updated Expense ID: ${response.expenseId}');
          }
        } else {
          print('Failed to update expense: ${response.message}');
        }
      } else {
        print('Expense data validation failed');
      }
    } catch (e) {
      print('Error updating expense: $e');
    }
  }

  /// Example 2: Create new expense (NO ID)
  static Future<void> createNewExpenseWithJson() async {
    try {
      // Create new expense - NO ID (CREATE operation)
      final newExpenseJson = {
        "Id": null, // NO ID = CREATE operation
        "DCRId": 0,
        "DateOfExpense": "2025-10-29",
        "EmployeeId": 61,
        "CityId": 152608,
        "ClusterId": null,
        "BizUnit": 1,
        "ExpenceType": 1,
        "ExpenseAmount": 5000.0,
        "Remarks": "New expense data",
        "UserId": 10,
        "DCRStatus": "Draft",
        "DCRStatusId": 1,
        "ClusterNames": null,
        "IsGeneric": 1,
        "EmployeeName": null,
        "Attachments": [
          {
            "FileName": "new_document.pdf",
            "FileType": "PDF",
            "FilePath": "/Uploads/Attachments/DCR/Expenses/new_document.pdf",
            "Type": "pdf"
          }
        ]
      };

      // Check operation type
      if (ExpenseHelper.isCreateOperation(newExpenseJson)) {
        print('This is a CREATE operation (no ID present)');
      }

      // Validate the data before saving
      if (ExpenseHelper.validateExpenseData(newExpenseJson)) {
        print('Expense data is valid, proceeding to create...');
        
        // Create the expense
        final response = await ExpenseHelper.createExpense(newExpenseJson);
        
        if (response.success) {
          print('New expense created successfully!');
          print('Message: ${response.message}');
          if (response.expenseId != null) {
            print('New Expense ID: ${response.expenseId}');
          }
        } else {
          print('Failed to create expense: ${response.message}');
        }
      } else {
        print('Expense data validation failed');
      }
    } catch (e) {
      print('Error creating expense: $e');
    }
  }

  /// Example 3: Update existing expense with individual parameters
  static Future<void> updateExpenseWithParameters() async {
    try {
      final response = await ExpenseHelper.updateExpenseWithParams(
        id: 29, // Required for update
        dcrId: 0,
        dateOfExpense: "2025-10-29",
        employeeId: 61,
        cityId: 152608,
        clusterId: null,
        bizUnit: 1,
        expenceType: 1,
        expenseAmount: 7000.0, // Updated amount
        remarks: "Updated test data",
        userId: 10,
        dcrStatus: "Draft",
        dcrStatusId: 1,
        clusterNames: null,
        isGeneric: 1,
        employeeName: null,
        attachments: [
          ExpenseAttachment(
            fileName: "updated_document.pdf",
            fileType: "PDF",
            filePath: "/Uploads/Attachments/DCR/Expenses/updated_document.pdf",
            type: "pdf",
          ),
        ],
      );

      if (response.success) {
        print('Expense updated successfully with parameters!');
        print('Message: ${response.message}');
      } else {
        print('Failed to update expense: ${response.message}');
      }
    } catch (e) {
      print('Error updating expense with parameters: $e');
    }
  }

  /// Example 4: Create new expense with individual parameters
  static Future<void> createExpenseWithParameters() async {
    try {
      final response = await ExpenseHelper.createExpenseWithParams(
        dcrId: 0,
        dateOfExpense: "2025-10-29",
        employeeId: 61,
        cityId: 152608,
        clusterId: null,
        bizUnit: 1,
        expenceType: 1,
        expenseAmount: 3000.0,
        remarks: "New expense with parameters",
        userId: 10,
        dcrStatus: "Draft",
        dcrStatusId: 1,
        clusterNames: null,
        isGeneric: 1,
        employeeName: null,
        attachments: [
          ExpenseAttachment(
            fileName: "new_receipt.pdf",
            fileType: "PDF",
            filePath: "/Uploads/Attachments/DCR/Expenses/new_receipt.pdf",
            type: "pdf",
          ),
        ],
      );

      if (response.success) {
        print('New expense created successfully with parameters!');
        print('Message: ${response.message}');
        if (response.expenseId != null) {
          print('New Expense ID: ${response.expenseId}');
        }
      } else {
        print('Failed to create expense: ${response.message}');
      }
    } catch (e) {
      print('Error creating expense with parameters: $e');
    }
  }

  /// Example 5: Demonstrate automatic detection of create vs update
  static Future<void> demonstrateAutoDetection() async {
    try {
      print('=== Demonstrating Automatic Create vs Update Detection ===\n');
      
      // Example 1: JSON with ID (should be UPDATE)
      final updateJson = {
        "Id": 29, // ID present = UPDATE
        "DCRId": 0,
        "DateOfExpense": "2025-10-29",
        "EmployeeId": 61,
        "CityId": 152608,
        "BizUnit": 1,
        "ExpenceType": 1,
        "ExpenseAmount": 8000.0,
        "Remarks": "Auto-detected update",
        "UserId": 10,
        "DCRStatus": "Draft",
        "DCRStatusId": 1,
        "IsGeneric": 1,
      };

      print('JSON with ID: ${updateJson['Id']}');
      print('Is Update Operation: ${ExpenseHelper.isUpdateOperation(updateJson)}');
      print('Is Create Operation: ${ExpenseHelper.isCreateOperation(updateJson)}');
      
      // Example 2: JSON without ID (should be CREATE)
      final createJson = {
        "Id": null, // No ID = CREATE
        "DCRId": 0,
        "DateOfExpense": "2025-10-29",
        "EmployeeId": 61,
        "CityId": 152608,
        "BizUnit": 1,
        "ExpenceType": 1,
        "ExpenseAmount": 4000.0,
        "Remarks": "Auto-detected create",
        "UserId": 10,
        "DCRStatus": "Draft",
        "DCRStatusId": 1,
        "IsGeneric": 1,
      };

      print('\nJSON without ID: ${createJson['Id']}');
      print('Is Update Operation: ${ExpenseHelper.isUpdateOperation(createJson)}');
      print('Is Create Operation: ${ExpenseHelper.isCreateOperation(createJson)}');
      
      // Example 3: Using the general saveExpenseFromJson method
      print('\n--- Using saveExpenseFromJson (auto-detects operation) ---');
      
      // This will automatically detect it's an update
      print('Saving with ID (UPDATE):');
      final updateResponse = await ExpenseHelper.saveExpenseFromJson(updateJson);
      print('Update result: ${updateResponse.success ? "Success" : "Failed"}');
      
      // This will automatically detect it's a create
      print('Saving without ID (CREATE):');
      final createResponse = await ExpenseHelper.saveExpenseFromJson(createJson);
      print('Create result: ${createResponse.success ? "Success" : "Failed"}');
      
    } catch (e) {
      print('Error in auto-detection demo: $e');
    }
  }

  /// Example 6: Error handling for wrong operation types
  static Future<void> demonstrateErrorHandling() async {
    try {
      print('=== Demonstrating Error Handling ===\n');
      
      // Try to create with existing ID (should fail)
      print('1. Trying to create with existing ID (should fail):');
      try {
        final jsonWithId = {"Id": 29, "DCRId": 0, "DateOfExpense": "2025-10-29", "EmployeeId": 61, "CityId": 152608, "BizUnit": 1, "ExpenceType": 1, "ExpenseAmount": 1000.0, "Remarks": "Test", "UserId": 10, "DCRStatus": "Draft", "DCRStatusId": 1, "IsGeneric": 1};
        await ExpenseHelper.createExpense(jsonWithId);
      } catch (e) {
        print('Expected error: $e');
      }
      
      // Try to update without ID (should fail)
      print('\n2. Trying to update without ID (should fail):');
      try {
        final jsonWithoutId = {"Id": null, "DCRId": 0, "DateOfExpense": "2025-10-29", "EmployeeId": 61, "CityId": 152608, "BizUnit": 1, "ExpenceType": 1, "ExpenseAmount": 1000.0, "Remarks": "Test", "UserId": 10, "DCRStatus": "Draft", "DCRStatusId": 1, "IsGeneric": 1};
        await ExpenseHelper.updateExpense(jsonWithoutId);
      } catch (e) {
        print('Expected error: $e');
      }
      
    } catch (e) {
      print('Error in error handling demo: $e');
    }
  }

  /// Run all examples
  static Future<void> runAllExamples() async {
    print('=== Expense Save/Update Examples ===\n');
    
    print('1. Update existing expense with provided JSON (ID present):');
    await updateExpenseWithProvidedJson();
    print('');
    
    print('2. Create new expense with JSON (no ID):');
    await createNewExpenseWithJson();
    print('');
    
    print('3. Update existing expense with parameters:');
    await updateExpenseWithParameters();
    print('');
    
    print('4. Create new expense with parameters:');
    await createExpenseWithParameters();
    print('');
    
    print('5. Demonstrate automatic detection:');
    await demonstrateAutoDetection();
    print('');
    
    print('6. Demonstrate error handling:');
    await demonstrateErrorHandling();
    print('');
    
    print('=== All examples completed ===');
  }
}
