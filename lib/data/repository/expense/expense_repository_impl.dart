import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:boilerplate/domain/entity/expense/expense.dart';
import 'package:boilerplate/domain/repository/expense/expense_repository.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api_models.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final List<ExpenseEntry> _items = <ExpenseEntry>[];
  final ExpenseApi _expenseApi;

  ExpenseRepositoryImpl(this._expenseApi) {
  }


  @override
  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
  }

  @override
  Future<ExpenseEntry?> getById(String id) async {
    try {
      // Try to get from local items first
      final localItem = _items.firstWhere((e) => e.id == id);
      return localItem;
    } catch (e) {
      // If not found locally, try to get from API
      try {
        final expenseId = int.tryParse(id);
        if (expenseId != null) {
          // Get expense details from API
          final response = await _expenseApi.getExpense(expenseId);
          
          // Convert API response to ExpenseEntry
          // This would need to be implemented based on the API response structure
          // For now, return null as we don't have the conversion logic
          return null; // Placeholder - would need proper conversion from ExpenseDetailResponse
        }
      } catch (apiError) {
        // Error getting expense from API
      }
      return null;
    }
  }

  @override
  Future<List<ExpenseEntry>> listByDateRange({
    required DateTime start,
    required DateTime end,
    String? employeeId,
    String? linkedDcrId,
    ExpenseStatus? status,
  }) async {
    return _items.where((e) {
      final bool inRange = !e.date.isBefore(start) && !e.date.isAfter(end);
      final bool byEmp = employeeId == null || e.employeeId == employeeId;
      final bool byDcr = linkedDcrId == null || e.linkedDcrId == linkedDcrId;
      final bool byStatus = status == null || e.status == status;
      return inRange && byEmp && byDcr && byStatus;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<void> approve(List<String> ids) async {
    _bulkUpdate(ids, ExpenseStatus.approved);
  }

  @override
  Future<void> reject(List<String> ids, {required String comment}) async {
    _bulkUpdate(ids, ExpenseStatus.rejected);
  }

  @override
  Future<void> sendBack(List<String> ids, {required String comment}) async {
    _bulkUpdate(ids, ExpenseStatus.sentBack);
  }

  @override
  Future<void> submitForApproval(List<String> ids) async {
    _bulkUpdate(ids, ExpenseStatus.submitted);
  }

  @override
  Future<ExpenseEntry> update(ExpenseEntry entry) async {
    final int i = _items.indexWhere((e) => e.id == entry.id);
    final DateTime now = DateTime.now();
    if (i >= 0) {
      _items[i] = entry.copyWith(updatedAt: now);
      return _items[i];
    }
    _items.add(entry.copyWith(updatedAt: now));
    return entry;
  }

  void _bulkUpdate(List<String> ids, ExpenseStatus status) {
    final DateTime now = DateTime.now();
    for (int i = 0; i < _items.length; i++) {
      final e = _items[i];
      if (ids.contains(e.id)) {
        _items[i] = e.copyWith(status: status, updatedAt: now);
      }
    }
  }

  String _genId() => DateTime.now().microsecondsSinceEpoch.toString();

  @override
  Future<Map<String, dynamic>> saveExpenseToApi(SaveExpenseApiParams params, {List<PlatformFile>? files}) async {
    final request = ExpenseSaveRequest(
      id: params.id,
      dcrId: params.dcrId ?? 0, // Handle nullable dcrId
      dateOfExpense: params.dateOfExpense,
      employeeId: params.employeeId,
      cityId: params.cityId,
      clusterId: params.clusterId,
      bizUnit: params.bizUnit,
      expenceType: params.expenceType,
      expenseAmount: params.expenseAmount,
      remarks: params.remarks,
      userId: params.userId,
      dcrStatus: params.dcrStatus,
      dcrStatusId: params.dcrStatusId,
      clusterNames: params.clusterNames,
      isGeneric: params.isGeneric,
      employeeName: params.employeeName,
      attachments: params.attachments ?? [], // Handle nullable attachments
    );
    
    return await _expenseApi.saveExpense(request, files: files);
  }

  @override
  Future<ExpenseDetailResponse> getExpenseFromApi(int expenseId) async {
    return await _expenseApi.getExpense(expenseId);
  }

  @override
  Future<Map<String, dynamic>> approveExpenseSingle(int expenseId, {String comment = ''}) async {
    final request = ExpenseActionRequest(
      id: expenseId,
      action: 5, // Approve action
      comment: comment,
    );
    
    final response = await _expenseApi.approveExpenseSingle(request);
    return {
      'success': response.success,
      'message': response.message,
    };
  }

  @override
  Future<Map<String, dynamic>> sendBackExpenseSingle(int expenseId, {String comment = ''}) async {
    final request = ExpenseActionRequest(
      id: expenseId,
      action: 4, // Send back action
      comment: comment,
    );
    
    final response = await _expenseApi.sendBackExpenseSingle(request);
    return {
      'success': response.success,
      'message': response.message,
    };
  }

  @override
  Future<ExpenseActionResponse> bulkApproveExpenses(ExpenseBulkApproveRequest request) async {
    return await _expenseApi.bulkApproveExpenses(request);
  }

  @override
  Future<ExpenseActionResponse> bulkRejectExpenses(ExpenseBulkRejectRequest request) async {
    return await _expenseApi.bulkRejectExpenses(request);
  }
}


