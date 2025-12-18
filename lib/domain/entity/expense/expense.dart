import 'package:flutter/foundation.dart';
import '../../../data/network/apis/expense/expense_api_models.dart';

enum ExpenseStatus { draft, submitted, approved, rejected, sentBack }

@immutable
class ExpenseEntry {
  const ExpenseEntry({
    required this.id,
    required this.date,
    required this.cluster,
    required this.expenseHead,
    required this.amount,
    required this.remarks,
    this.proofFilePath,
    this.linkedDcrId,
    required this.status,
    required this.employeeId,
    required this.employeeName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final DateTime date;
  final String cluster;
  final String expenseHead;
  final double amount;
  final String remarks;
  final String? proofFilePath;
  final String? linkedDcrId;
  final ExpenseStatus status;
  final String employeeId;
  final String employeeName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ExpenseEntry copyWith({
    String? id,
    DateTime? date,
    String? cluster,
    String? expenseHead,
    double? amount,
    String? remarks,
    String? proofFilePath,
    String? linkedDcrId,
    ExpenseStatus? status,
    String? employeeId,
    String? employeeName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      cluster: cluster ?? this.cluster,
      expenseHead: expenseHead ?? this.expenseHead,
      amount: amount ?? this.amount,
      remarks: remarks ?? this.remarks,
      proofFilePath: proofFilePath ?? this.proofFilePath,
      linkedDcrId: linkedDcrId ?? this.linkedDcrId,
      status: status ?? this.status,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CreateExpenseParams {
  const CreateExpenseParams({
    required this.date,
    required this.cluster,
    required this.expenseHead,
    required this.amount,
    required this.remarks,
    this.proofFilePath,
    this.linkedDcrId,
    required this.employeeId,
    required this.employeeName,
    this.submit = false,
  });

  final DateTime date;
  final String cluster;
  final String expenseHead;
  final double amount;
  final String remarks;
  final String? proofFilePath;
  final String? linkedDcrId;
  final String employeeId;
  final String employeeName;
  final bool submit;
}

class SaveExpenseApiParams {
  const SaveExpenseApiParams({
    this.id,
    this.dcrId,
    required this.dateOfExpense,
    required this.employeeId,
    required this.cityId,
    this.clusterId,
    required this.bizUnit,
    required this.expenceType,
    required this.expenseAmount,
    required this.remarks,
    required this.userId,
    required this.dcrStatus,
    required this.dcrStatusId,
    this.clusterNames,
    required this.isGeneric,
    this.employeeName,
    this.attachments,
  });

  final int? id;
  final int? dcrId;
  final String dateOfExpense;
  final int employeeId;
  final int cityId;
  final int? clusterId;
  final int bizUnit;
  final int expenceType;
  final double expenseAmount;
  final String remarks;
  final int userId;
  final String dcrStatus;
  final int dcrStatusId;
  final String? clusterNames;
  final int isGeneric;
  final String? employeeName;
  final List<ExpenseAttachment>? attachments;
}

// Note: ExpenseDetailResponse and ExpenseAttachment are defined in expense_api_models.dart


