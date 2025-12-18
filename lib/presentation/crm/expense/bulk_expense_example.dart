import 'package:flutter/material.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api_models.dart';
import 'package:boilerplate/domain/repository/expense/expense_repository.dart';
import 'package:boilerplate/di/service_locator.dart';

/// Example usage of the new bulk expense APIs
class BulkExpenseExample {
  
  /// Example: Bulk approve expenses
  static Future<void> bulkApproveExpensesExample() async {
    try {
      final ExpenseRepository? expenseRepo = getIt.isRegistered<ExpenseRepository>() 
          ? getIt<ExpenseRepository>() 
          : null;
      
      if (expenseRepo == null) {
        print('ExpenseRepository not available');
        return;
      }

      // Create expense action details for the expenses to approve
      final List<ExpenseActionDetail> expenseActions = [
        ExpenseActionDetail(id: 12),
        ExpenseActionDetail(id: 13),
        ExpenseActionDetail(id: 14),
        ExpenseActionDetail(id: 15),
        ExpenseActionDetail(id: 16),
      ];

      // Create bulk approve request
      final request = ExpenseBulkApproveRequest(
        id: 10, // Manager's ID or DCR ID
        comments: "Approved by Manager",
        userId: 1, // Manager's user ID
        action: 5, // Action 5 for approve
        expenseAction: expenseActions,
      );

      // Call the API
      final response = await expenseRepo.bulkApproveExpenses(request);
      
      if (response.success) {
        print('Successfully approved expenses: ${response.message}');
      } else {
        print('Failed to approve expenses: ${response.message}');
      }
    } catch (e) {
      print('Error bulk approving expenses: $e');
    }
  }

  /// Example: Bulk reject/send back expenses
  static Future<void> bulkRejectExpensesExample() async {
    try {
      final ExpenseRepository? expenseRepo = getIt.isRegistered<ExpenseRepository>() 
          ? getIt<ExpenseRepository>() 
          : null;
      
      if (expenseRepo == null) {
        print('ExpenseRepository not available');
        return;
      }

      // Create expense action details for the expenses to reject
      final List<ExpenseActionDetail> expenseActions = [
        ExpenseActionDetail(id: 12),
        ExpenseActionDetail(id: 13),
        ExpenseActionDetail(id: 14),
        ExpenseActionDetail(id: 15),
        ExpenseActionDetail(id: 16),
      ];

      // Create bulk reject request
      final request = ExpenseBulkRejectRequest(
        id: 10, // Manager's ID or DCR ID
        comments: "Sent back by Manager",
        userId: 1, // Manager's user ID
        action: 4, // Action 4 for reject/send back
        expenseAction: expenseActions,
      );

      // Call the API
      final response = await expenseRepo.bulkRejectExpenses(request);
      
      if (response.success) {
        print('Successfully rejected expenses: ${response.message}');
      } else {
        print('Failed to reject expenses: ${response.message}');
      }
    } catch (e) {
      print('Error bulk rejecting expenses: $e');
    }
  }
}

/// Example widget showing how to use the bulk APIs in a UI
class BulkExpenseExampleWidget extends StatefulWidget {
  const BulkExpenseExampleWidget({super.key});

  @override
  State<BulkExpenseExampleWidget> createState() => _BulkExpenseExampleWidgetState();
}

class _BulkExpenseExampleWidgetState extends State<BulkExpenseExampleWidget> {
  bool _isLoading = false;
  String _lastResult = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Expense API Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Bulk Expense API Examples',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _bulkApproveExample,
              child: const Text('Bulk Approve Expenses'),
            ),
            const SizedBox(height: 10),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _bulkRejectExample,
              child: const Text('Bulk Reject Expenses'),
            ),
            const SizedBox(height: 20),
            
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_lastResult.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_lastResult),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _bulkApproveExample() async {
    setState(() {
      _isLoading = true;
      _lastResult = '';
    });

    try {
      await BulkExpenseExample.bulkApproveExpensesExample();
      setState(() {
        _lastResult = 'Bulk approve example completed. Check console for details.';
      });
    } catch (e) {
      setState(() {
        _lastResult = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _bulkRejectExample() async {
    setState(() {
      _isLoading = true;
      _lastResult = '';
    });

    try {
      await BulkExpenseExample.bulkRejectExpensesExample();
      setState(() {
        _lastResult = 'Bulk reject example completed. Check console for details.';
      });
    } catch (e) {
      setState(() {
        _lastResult = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}





