import 'package:boilerplate/domain/entity/dcr/dcr_api_models.dart';
import 'package:boilerplate/domain/repository/dcr/dcr_repository.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api_models.dart';
import 'package:boilerplate/di/service_locator.dart';

class SaveExpenseUseCase {
  final DcrRepository _dcrRepository;

  SaveExpenseUseCase() : _dcrRepository = getIt<DcrRepository>();

  /// Save expense using the SaveExpenses API endpoint
  Future<ExpenseSaveResponse> call(ExpenseSaveRequest request) async {
    try {
      return await _dcrRepository.saveExpense(request);
    } catch (e) {
      throw Exception('Failed to save expense: ${e.toString()}');
    }
  }

  /// Create ExpenseSaveRequest from individual parameters
  static ExpenseSaveRequest createRequest({
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
    List<AttachmentApiItem> attachments = const [],
  }) {
    return ExpenseSaveRequest(
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
  }

  /// Create ExpenseSaveRequest from JSON data (for dynamic updates)
  static ExpenseSaveRequest fromJson(Map<String, dynamic> json) {
    return ExpenseSaveRequest.fromJson(json);
  }
}
