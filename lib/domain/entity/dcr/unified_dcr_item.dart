import 'package:flutter/foundation.dart';
import 'dcr_api_models.dart';

/// Unified model to handle both DCR and Expense items from the API response
@immutable
class UnifiedDcrItem {
  const UnifiedDcrItem({
    required this.id,
    required this.transactionType,
    required this.employeeName,
    required this.designation,
    required this.clusterNames,
    required this.statusText,
    required this.dcrDate,
    required this.remarks,
    required this.customerName,
    required this.typeOfWork,
    required this.customerId,
    required this.cityId,
    required this.employeeId,
    required this.dcrId,
    required this.tourPlanId,
    required this.dcrStatusId,
    required this.typeOfWorkId,
    required this.isGeneric,
    this.customerLatitude,
    this.customerLongitude,
    this.samplesToDistribute,
    this.productsToDiscuss,
    this.expenses,
  });

  final int id;
  final String transactionType; // "DCR" or "Expense"
  final String employeeName;
  final String designation;
  final String clusterNames;
  final String statusText;
  final String dcrDate;
  final String remarks;
  final String customerName;
  final String typeOfWork;
  final int customerId;
  final int cityId;
  final int employeeId;
  final int dcrId;
  final int tourPlanId;
  final int dcrStatusId;
  final int typeOfWorkId;
  final int isGeneric;
  final double? customerLatitude;
  final double? customerLongitude;
  final String? samplesToDistribute;
  final String? productsToDiscuss;
  final List<ExpenseApiItem>? expenses;

  /// Factory constructor to create from DcrApiItem
  factory UnifiedDcrItem.fromDcrApiItem(DcrApiItem item) {
    // Try to get coordinates from tourPlanDCRDetails first, then fallback to direct fields
    double? latitude = item.customerLatitude;
    double? longitude = item.customerLongitude;
    
    // If direct coordinates are null, try to get from tourPlanDCRDetails
    if (latitude == null || longitude == null) {
      for (final detail in item.tourPlanDCRDetails) {
        if (detail.latitude != 0.0 && detail.longitude != 0.0) {
          latitude = detail.latitude;
          longitude = detail.longitude;
          break; // Use the first valid coordinate set
        }
      }
    }
    
    return UnifiedDcrItem(
      id: item.id,
      transactionType: item.transactionType,
      employeeName: item.employeeName,
      designation: item.designation,
      clusterNames: item.clusterNames,
      statusText: item.statusText,
      dcrDate: item.dcrDate,
      remarks: item.remarks,
      customerName: item.customerName,
      typeOfWork: item.typeOfWork,
      customerId: item.customerId,
      cityId: item.cityId,
      employeeId: item.employeeId,
      dcrId: item.dcrId,
      tourPlanId: item.tourPlanId,
      dcrStatusId: item.dcrStatusId,
      typeOfWorkId: item.typeOfWorkId,
      isGeneric: item.isGeneric,
      customerLatitude: latitude,
      customerLongitude: longitude,
      samplesToDistribute: item.samplesToDistribute,
      productsToDiscuss: item.productsToDiscuss,
      expenses: item.expenses,
    );
  }

  /// Check if this is a DCR item
  bool get isDcr => transactionType == 'DCR';

  /// Check if this is an Expense item
  bool get isExpense => transactionType == 'Expense';

  /// Get the display title for the item
  String get displayTitle {
    if (isDcr) {
      return customerName;
    } else {
      return customerName; // For expenses, customerName contains the expense description
    }
  }

  /// Get the display subtitle for the item
  String get displaySubtitle {
    if (isDcr) {
      return typeOfWork;
    } else {
      return typeOfWork; // For expenses, typeOfWork contains the amount
    }
  }

  /// Get the cluster name for display
  String get clusterDisplayName {
    return clusterNames.trim().isNotEmpty ? clusterNames.trim() : 'Unknown';
  }

  /// Parse the DCR date to DateTime
  DateTime? get parsedDate {
    try {
      return DateTime.parse(dcrDate);
    } catch (e) {
      return null;
    }
  }

  /// Get the amount for expense items
  double? get expenseAmount {
    if (isExpense && typeOfWork.contains('Amount:')) {
      try {
        final amountStr = typeOfWork.replaceAll('Amount:', '').replaceAll('Rs.', '').trim();
        return double.parse(amountStr);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Get the expense type for expense items
  String? get expenseType {
    if (isExpense && customerName.contains('Expense:')) {
      return customerName.replaceAll('Expense:', '').trim();
    }
    return null;
  }

  UnifiedDcrItem copyWith({
    int? id,
    String? transactionType,
    String? employeeName,
    String? designation,
    String? clusterNames,
    String? statusText,
    String? dcrDate,
    String? remarks,
    String? customerName,
    String? typeOfWork,
    int? customerId,
    int? cityId,
    int? employeeId,
    int? dcrId,
    int? tourPlanId,
    int? dcrStatusId,
    int? typeOfWorkId,
    int? isGeneric,
    double? customerLatitude,
    double? customerLongitude,
    String? samplesToDistribute,
    String? productsToDiscuss,
    List<ExpenseApiItem>? expenses,
  }) {
    return UnifiedDcrItem(
      id: id ?? this.id,
      transactionType: transactionType ?? this.transactionType,
      employeeName: employeeName ?? this.employeeName,
      designation: designation ?? this.designation,
      clusterNames: clusterNames ?? this.clusterNames,
      statusText: statusText ?? this.statusText,
      dcrDate: dcrDate ?? this.dcrDate,
      remarks: remarks ?? this.remarks,
      customerName: customerName ?? this.customerName,
      typeOfWork: typeOfWork ?? this.typeOfWork,
      customerId: customerId ?? this.customerId,
      cityId: cityId ?? this.cityId,
      employeeId: employeeId ?? this.employeeId,
      dcrId: dcrId ?? this.dcrId,
      tourPlanId: tourPlanId ?? this.tourPlanId,
      dcrStatusId: dcrStatusId ?? this.dcrStatusId,
      typeOfWorkId: typeOfWorkId ?? this.typeOfWorkId,
      isGeneric: isGeneric ?? this.isGeneric,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      samplesToDistribute: samplesToDistribute ?? this.samplesToDistribute,
      productsToDiscuss: productsToDiscuss ?? this.productsToDiscuss,
      expenses: expenses ?? this.expenses,
    );
  }
}
