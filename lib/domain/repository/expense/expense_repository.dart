import 'package:file_picker/file_picker.dart';
import 'package:boilerplate/domain/entity/expense/expense.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api_models.dart';

abstract class ExpenseRepository {
  Future<void> delete(String id);
  Future<ExpenseEntry?> getById(String id);
  Future<List<ExpenseEntry>> listByDateRange({
    required DateTime start,
    required DateTime end,
    String? employeeId,
    String? linkedDcrId,
    ExpenseStatus? status,
  });
  Future<void> submitForApproval(List<String> ids);
  Future<void> approve(List<String> ids);
  Future<void> reject(List<String> ids, {required String comment});
  Future<void> sendBack(List<String> ids, {required String comment});
  
  // New API methods
  Future<Map<String, dynamic>> saveExpenseToApi(SaveExpenseApiParams params, {List<PlatformFile>? files});
  Future<ExpenseDetailResponse> getExpenseFromApi(int expenseId);
  Future<Map<String, dynamic>> approveExpenseSingle(int expenseId, {String comment = ''});
  Future<Map<String, dynamic>> sendBackExpenseSingle(int expenseId, {String comment = ''});
  
  // Bulk expense action methods
  Future<ExpenseActionResponse> bulkApproveExpenses(ExpenseBulkApproveRequest request);
  Future<ExpenseActionResponse> bulkRejectExpenses(ExpenseBulkRejectRequest request);
}


