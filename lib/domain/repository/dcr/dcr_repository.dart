import 'package:boilerplate/domain/entity/dcr/dcr.dart';
import 'package:boilerplate/domain/entity/dcr/dcr_api_models.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api_models.dart';

abstract class DcrRepository {
  Future<DcrEntry> create(CreateDcrParams params);
  Future<DcrEntry> update(DcrEntry entry);
  Future<void> delete(String id);
  Future<List<DcrEntry>> listByDateRange({
    required DateTime start,
    required DateTime end,
    String? employeeId,
    String? customer,
    int? statusId,
  });
  Future<List<DcrApiItem>> getDcrListUnified({
    required DateTime start,
    required DateTime end,
    String? employeeId,
    int? statusId,
    String? transactionType,
  });
  Future<DcrEntry?> getById(String id, {String? dcrId});
  Future<void> submitForApproval(List<String> ids);
  Future<void> approve(List<String> ids);
  Future<void> reject(List<String> ids, {required String comment});
  Future<void> sendBack(List<String> ids, {required String comment});
  
  // Bulk operations for manager review
  Future<void> bulkApprove(List<String> ids, {required String comment});
  Future<void> bulkSendBack(List<String> ids, {required String comment});
  Future<void> bulkReject(List<String> ids, {required String comment});
  
  // Expense operations
  Future<ExpenseSaveResponse> saveExpense(ExpenseSaveRequest request);
}


