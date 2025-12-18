import 'dart:async';

import 'package:boilerplate/domain/entity/tour_plan/tour_plan.dart';

import '../../../data/network/apis/user/lib/domain/entity/tour_plan/calendar_view_data.dart';
import '../../../data/network/apis/user/lib/domain/entity/tour_plan/tour_plan_api_models.dart';

class CreateTourPlanParams {
  CreateTourPlanParams({
    required this.date,
    required this.clusters,
    required this.customers,
    required this.employeeId,
    required this.employeeName,
    required this.callDetailsByCustomer,
  });

  final DateTime date;
  final List<String> clusters; // multi-select
  final List<String> customers; // multi-select; one record per customer
  final String employeeId;
  final String employeeName;
  final Map<String, TourPlanCallDetails> callDetailsByCustomer;
}

abstract class TourPlanRepository {
  Future<List<TourPlanEntry>> listMonth({
    required DateTime month,
    String? employeeId,
    String? customer,
    TourPlanEntryStatus? status,
  });

  Future<TourPlanMonthSummary> monthSummary({
    required DateTime month,
    required String employeeId,
  });

  Future<TourPlanEntry> create(CreateTourPlanParams params);

  Future<TourPlanEntry> update(TourPlanEntry entry);

  Future<void> delete(String id);

  Future<void> submitForApproval(List<String> ids);

  Future<void> approve(List<String> ids);

  Future<void> sendBack(List<String> ids, {required String comment});

  Future<void> reject(List<String> ids, {required String comment});

  Future<List<CalendarViewData>> getCalendarViewData(CalendarViewRequest request);

  Future<TourPlanGetResponse> getTourPlanDetail(TourPlanGetRequest request);

  /// Get tour plan list data using /List endpoint (calendar item list data)
  Future<TourPlanGetResponse> getTourPlanListData(TourPlanGetRequest request);

  /// Save tour plan with provided body; returns {msg, status}
  Future<Map<String, dynamic>> saveTourPlan(Map<String, dynamic> body);

  /// Update tour plan with provided body; returns {msg, status}
  Future<Map<String, dynamic>> updateTourPlan(Map<String, dynamic> body);

  /// Get tour plan aggregate count summary
  Future<TourPlanAggregateCountResponse> getTourPlanAggregateCountSummary(TourPlanAggregateCountRequest request);

  /// Approve a single tour plan entry
  Future<TourPlanActionResponse> approveSingleTourPlan(TourPlanActionRequest request);

  /// Reject a single tour plan entry
  Future<TourPlanActionResponse> rejectSingleTourPlan(TourPlanActionRequest request);

  /// Bulk approve multiple tour plan entries
  Future<TourPlanActionResponse> bulkApproveTourPlans(TourPlanBulkActionRequest request);

  /// Bulk send back multiple tour plan entries
  Future<TourPlanActionResponse> bulkSendBackTourPlans(TourPlanBulkActionRequest request);

  /// Get mapped customers by employee ID
  Future<GetMappedCustomersByEmployeeIdResponse> getMappedCustomersByEmployeeId(GetMappedCustomersByEmployeeIdRequest request);

  /// Get tour plan summary
  Future<TourPlanGetSummaryResponse> getTourPlanSummary(TourPlanGetSummaryRequest request);

  /// Get tour plan manager summary
  Future<TourPlanGetManagerSummaryResponse> getTourPlanManagerSummary(TourPlanGetManagerSummaryRequest request);

  /// Get tour plan employee list summary
  Future<TourPlanGetEmployeeListSummaryResponse> getTourPlanEmployeeListSummary(TourPlanGetEmployeeListSummaryRequest request);

  /// Get specific tour plan details; returns list response shape
  Future<TourPlanGetResponse> getTourPlanDetails({
    required int tourPlanId,
    int? id,
    int? userId,
  });

  /// Save tour plan comment
  Future<TourPlanCommentSaveResponse> saveTourPlanComment(TourPlanCommentSaveRequest request);

  /// Get tour plan comments list
  Future<List<TourPlanCommentItem>> getTourPlanCommentsList(TourPlanCommentGetListRequest request);

  /// Delete tour plan by ID (returns action response)
  Future<TourPlanActionResponse> deleteTourPlan(int id);
}


