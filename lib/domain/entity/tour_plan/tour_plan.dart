import 'package:flutter/foundation.dart';

/// Status of an individual tour plan entry in its approval lifecycle
enum TourPlanEntryStatus {
  draft,
  pending,
  approved,
  sentBack,
  rejected,
}

/// Aggregate status buckets used for monthly summaries and calendar coloring
enum TourPlanMonthlyStatusBucket {
  planned, // created entries regardless of approval state
  pending,
  approved,
  leaveDays,
  notEntered,
}

@immutable
class TourPlanCallDetails {
  const TourPlanCallDetails({
    required this.purposes,
    this.productsToDiscuss,
    this.samplesToDistribute,
    this.remarks,
  });

  final List<String> purposes;
  final String? productsToDiscuss;
  final String? samplesToDistribute;
  final String? remarks;
}

@immutable
class TourPlanEntry {
  const TourPlanEntry({
    required this.id,
    required this.date,
    required this.cluster,
    required this.customer,
    required this.employeeId,
    required this.employeeName,
    required this.status,
    required this.callDetails,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final DateTime date;
  final String cluster; // city/locality/cluster
  final String customer; // customer name or id depending on integration
  final String employeeId;
  final String employeeName;
  final TourPlanEntryStatus status;
  final TourPlanCallDetails callDetails;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TourPlanEntry copyWith({
    DateTime? date,
    String? cluster,
    String? customer,
    String? employeeId,
    String? employeeName,
    TourPlanEntryStatus? status,
    TourPlanCallDetails? callDetails,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TourPlanEntry(
      id: id,
      date: date ?? this.date,
      cluster: cluster ?? this.cluster,
      customer: customer ?? this.customer,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      status: status ?? this.status,
      callDetails: callDetails ?? this.callDetails,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class TourPlanMonthSummary {
  const TourPlanMonthSummary({
    required this.month,
    required this.counts,
  });

  final DateTime month; // first day of month
  final Map<TourPlanMonthlyStatusBucket, int> counts;
}


