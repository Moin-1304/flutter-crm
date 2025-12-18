import 'dart:async';
import 'package:boilerplate/domain/entity/tour_plan/tour_plan.dart';
import 'package:boilerplate/domain/repository/tour_plan/tour_plan_repository.dart';
import 'package:boilerplate/data/network/apis/user/user_api_client.dart';
import 'package:boilerplate/core/data/network/dio/dio_client.dart';
import 'package:boilerplate/core/data/network/dio/configs/dio_configs.dart';
import 'package:boilerplate/data/network/constants/endpoints.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';

import '../../network/apis/user/lib/domain/entity/tour_plan/calendar_view_data.dart';
import '../../network/apis/user/lib/domain/entity/tour_plan/tour_plan_api_models.dart';

/// In-memory repository implementation for Tour Plan.
/// Replace with API-backed datasource when endpoints are ready.
class TourPlanRepositoryImpl implements TourPlanRepository {
  final List<TourPlanEntry> _entries = <TourPlanEntry>[];
  final UserApiClient? _apiClient;
  final SharedPreferenceHelper _sharedPreferenceHelper;
  
  TourPlanRepositoryImpl({
    UserApiClient? apiClient,
    required SharedPreferenceHelper sharedPreferenceHelper,
  }) : _apiClient = apiClient, _sharedPreferenceHelper = sharedPreferenceHelper {
    _seedDemoData();
  }

  UserApiClient get _apiClientInstance {
    if (_apiClient != null) return _apiClient!;
    
    // Create a default API client if none provided
    final dioConfigs = DioConfigs(
      baseUrl: Endpoints.baseUrl,
      connectionTimeout: Endpoints.connectionTimeout,
      receiveTimeout: Endpoints.receiveTimeout,
    );
    final dioClient = DioClient(dioConfigs: dioConfigs);
    return UserApiClient(dioClient);
  }

  @override
  Future<TourPlanEntry> create(CreateTourPlanParams params) async {
    final DateTime now = DateTime.now();
    TourPlanEntry? last;
    for (final String customer in params.customers) {
      final TourPlanCallDetails details = params.callDetailsByCustomer[customer] ??
          const TourPlanCallDetails(purposes: <String>[]);
      final entry = TourPlanEntry(
        id: _genId(),
        date: DateTime(params.date.year, params.date.month, params.date.day),
        cluster: params.clusters.isNotEmpty ? params.clusters.first : '',
        customer: customer,
        employeeId: params.employeeId,
        employeeName: params.employeeName,
        status: TourPlanEntryStatus.draft,
        callDetails: details,
        createdAt: now,
        updatedAt: now,
      );
      _entries.add(entry);
      last = entry;
    }
    return last!;
  }

  @override
  Future<void> delete(String id) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      // Convert string ID to int
      final int tourPlanId = int.tryParse(id) ?? 0;
      if (tourPlanId == 0) {
        throw Exception('Invalid tour plan ID: $id');
      }
      
      final response = await _apiClientInstance.deleteTourPlan(tourPlanId, token);
      
      if (!response.status) {
        throw Exception(response.message);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Delete tour plan using API (alternative method that returns response)
  @override
  Future<TourPlanActionResponse> deleteTourPlan(int id) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      final response = await _apiClientInstance.deleteTourPlan(id, token);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<TourPlanEntry>> listMonth({
    required DateTime month,
    String? employeeId,
    String? customer,
    TourPlanEntryStatus? status,
  }) async {
    final DateTime first = DateTime(month.year, month.month, 1);
    final DateTime last = DateTime(month.year, month.month + 1, 0);
    return _entries.where((e) {
      final bool inMonth = !e.date.isBefore(first) && !e.date.isAfter(last);
      final bool byEmp = employeeId == null || e.employeeId == employeeId;
      final bool byCustomer = customer == null || e.customer == customer;
      final bool byStatus = status == null || e.status == status;
      return inMonth && byEmp && byCustomer && byStatus;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<TourPlanMonthSummary> monthSummary({
    required DateTime month,
    required String employeeId,
  }) async {
    final List<TourPlanEntry> items = await listMonth(month: month, employeeId: employeeId);
    final Map<TourPlanMonthlyStatusBucket, int> counts = {
      TourPlanMonthlyStatusBucket.planned: 0,
      TourPlanMonthlyStatusBucket.pending: 0,
      TourPlanMonthlyStatusBucket.approved: 0,
      TourPlanMonthlyStatusBucket.leaveDays: 0,
      TourPlanMonthlyStatusBucket.notEntered: 0,
    };
    for (final e in items) {
      counts[TourPlanMonthlyStatusBucket.planned] =
          (counts[TourPlanMonthlyStatusBucket.planned] ?? 0) + 1;
      switch (e.status) {
        case TourPlanEntryStatus.draft:
          counts[TourPlanMonthlyStatusBucket.notEntered] =
              (counts[TourPlanMonthlyStatusBucket.notEntered] ?? 0) + 1;
          break;
        case TourPlanEntryStatus.pending:
          counts[TourPlanMonthlyStatusBucket.pending] =
              (counts[TourPlanMonthlyStatusBucket.pending] ?? 0) + 1;
          break;
        case TourPlanEntryStatus.approved:
          counts[TourPlanMonthlyStatusBucket.approved] =
              (counts[TourPlanMonthlyStatusBucket.approved] ?? 0) + 1;
          break;
        case TourPlanEntryStatus.sentBack:
          counts[TourPlanMonthlyStatusBucket.pending] =
              (counts[TourPlanMonthlyStatusBucket.pending] ?? 0) + 1;
          break;
        case TourPlanEntryStatus.rejected:
          // rejected not shown in screenshot buckets; count under notEntered
          counts[TourPlanMonthlyStatusBucket.notEntered] =
              (counts[TourPlanMonthlyStatusBucket.notEntered] ?? 0) + 1;
          break;
      }
    }
    return TourPlanMonthSummary(month: DateTime(month.year, month.month, 1), counts: counts);
  }

  @override
  Future<void> approve(List<String> ids) async {
    _bulkUpdate(ids, TourPlanEntryStatus.approved);
  }

  @override
  Future<void> reject(List<String> ids, {required String comment}) async {
    _bulkUpdate(ids, TourPlanEntryStatus.rejected);
  }

  @override
  Future<void> sendBack(List<String> ids, {required String comment}) async {
    _bulkUpdate(ids, TourPlanEntryStatus.sentBack);
  }

  @override
  Future<void> submitForApproval(List<String> ids) async {
    _bulkUpdate(ids, TourPlanEntryStatus.pending);
  }

  @override
  Future<TourPlanEntry> update(TourPlanEntry entry) async {
    final int i = _entries.indexWhere((e) => e.id == entry.id);
    if (i >= 0) {
      _entries[i] = entry.copyWith(updatedAt: DateTime.now());
      return _entries[i];
    }
    _entries.add(entry);
    return entry;
  }

  @override
  Future<List<CalendarViewData>> getCalendarViewData(CalendarViewRequest request) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      // Call the actual API
      final apiData = await _apiClientInstance.getTourPlanCalendarViewData(request, token);
      
      return apiData;
    } catch (e) {
      // Fallback to mock data if API fails
      final mockData = _generateMockCalendarData(request);
      return mockData;
    }
  }

  @override
  Future<TourPlanGetResponse> getTourPlanDetail(TourPlanGetRequest request) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      // Call the actual API
      final apiResponse = await _apiClientInstance.getTourPlanDetail(request, token);
      
      return apiResponse;
    } catch (e) {
      return TourPlanGetResponse(items: [], totalRecords: 0, filteredRecords: 0);
    }
  }

  @override
  Future<TourPlanGetResponse> getTourPlanListData(TourPlanGetRequest request) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      // Call the actual API using /List endpoint
      final apiResponse = await _apiClientInstance.getTourPlanListData(request, token);
      
      return apiResponse;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TourPlanGetResponse> getTourPlanDetails({
    required int tourPlanId,
    int? id,
    int? userId,
  }) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      final res = await _apiClientInstance.getTourPlanDetails(
        tourPlanId: tourPlanId,
        id: id,
        token: token,
        userId: userId,
      );
      return res;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TourPlanCommentSaveResponse> saveTourPlanComment(TourPlanCommentSaveRequest request) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      final res = await _apiClientInstance.saveTourPlanComment(request, token);
      return res;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<TourPlanCommentItem>> getTourPlanCommentsList(TourPlanCommentGetListRequest request) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      final res = await _apiClientInstance.getTourPlanCommentsList(request, token);
      return res;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> saveTourPlan(Map<String, dynamic> requestBody) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      final res = await _apiClientInstance.saveTourPlan(requestBody, token);
      return res;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> updateTourPlan(Map<String, dynamic> body) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      final Map<String, dynamic> requestBody = body;
      final res = await _apiClientInstance.updateTourPlan(requestBody, token);
      return {
        'msg': res['msg'] ?? 'Updated',
        'status': res['status'] ?? true,
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TourPlanAggregateCountResponse> getTourPlanAggregateCountSummary(TourPlanAggregateCountRequest request) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      final res = await _apiClientInstance.getTourPlanAggregateCountSummary(request, token);
      return res;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TourPlanGetSummaryResponse> getTourPlanSummary(TourPlanGetSummaryRequest request) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      final res = await _apiClientInstance.getTourPlanSummary(request, token);
      return res;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TourPlanGetManagerSummaryResponse> getTourPlanManagerSummary(TourPlanGetManagerSummaryRequest request) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      final res = await _apiClientInstance.getTourPlanManagerSummary(request, token);
      return res;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TourPlanGetEmployeeListSummaryResponse> getTourPlanEmployeeListSummary(TourPlanGetEmployeeListSummaryRequest request) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      final res = await _apiClientInstance.getTourPlanEmployeeListSummary(request, token);
      return res;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TourPlanActionResponse> approveSingleTourPlan(TourPlanActionRequest request) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      final res = await _apiClientInstance.approveSingleTourPlan(request, token);
      return res;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TourPlanActionResponse> rejectSingleTourPlan(TourPlanActionRequest request) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      final res = await _apiClientInstance.rejectSingleTourPlan(request, token);
      return res;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TourPlanActionResponse> bulkApproveTourPlans(TourPlanBulkActionRequest request) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      final res = await _apiClientInstance.bulkApproveTourPlans(request, token);
      return res;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TourPlanActionResponse> bulkSendBackTourPlans(TourPlanBulkActionRequest request) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      final res = await _apiClientInstance.bulkSendBackTourPlans(request, token);
      return res;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<GetMappedCustomersByEmployeeIdResponse> getMappedCustomersByEmployeeId(GetMappedCustomersByEmployeeIdRequest request) async {
    try {
      // Get auth token from SharedPreferenceHelper
      final String? token = await _sharedPreferenceHelper.authToken;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      final res = await _apiClientInstance.getMappedCustomersByEmployeeId(request, token);
      return res;
    } catch (e) {
      rethrow;
    }
  }


  List<CalendarViewData> _generateMockCalendarData(CalendarViewRequest request) {
    final List<CalendarViewData> mockData = [];
    final DateTime firstDay = DateTime(request.year, request.month, 1);
    final DateTime lastDay = DateTime(request.year, request.month + 1, 0);
    
    for (int day = firstDay.day; day <= lastDay.day; day++) {
      final DateTime currentDate = DateTime(request.year, request.month, day);
      final bool isWeekend = currentDate.weekday == DateTime.saturday || currentDate.weekday == DateTime.sunday;
      
      mockData.add(CalendarViewData(
        planDate: currentDate,
        plannedCount: _entries.where((e) => 
          e.date.year == request.year && 
          e.date.month == request.month && 
          e.date.day == day
        ).length,
        weekend: isWeekend ? 1 : 0,
        isHoliday: 0, // Mock: no holidays for now
        plannedCalls: null,
        isWeekend: isWeekend,
        isHolidayDay: false,
      ));
    }
    
    return mockData;
  }

  void _bulkUpdate(List<String> ids, TourPlanEntryStatus status) {
    final DateTime now = DateTime.now();
    for (int i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      if (ids.contains(e.id)) {
        _entries[i] = e.copyWith(status: status, updatedAt: now);
      }
    }
  }

  String _genId() => DateTime.now().microsecondsSinceEpoch.toString();

  void _seedDemoData() {
    if (_entries.isNotEmpty) return;
    final DateTime now = DateTime.now();
    final DateTime month = DateTime(now.year, now.month, 1);
    final List<_SeedItem> seeds = <_SeedItem>[
      _SeedItem(day: 1, customer: 'Apollo Hospital', status: TourPlanEntryStatus.approved, purposes: ['Product Detailing']),
      _SeedItem(day: 2, customer: 'Fortis Healthcare', status: TourPlanEntryStatus.pending, purposes: ['Field Visit']),
      _SeedItem(day: 5, customer: 'Global Care', status: TourPlanEntryStatus.draft, purposes: ['Onboarding']),
      _SeedItem(day: 6, customer: 'Medanta Clinic', status: TourPlanEntryStatus.draft, purposes: ['Follow-up']),
      _SeedItem(day: 9, customer: 'LifeLine Hospital', status: TourPlanEntryStatus.pending, purposes: ['Device Trial']),
      _SeedItem(day: 12, customer: 'Prime Health', status: TourPlanEntryStatus.rejected, purposes: ['Adhoc Visit']),
      _SeedItem(day: 15, customer: 'City Pharma', status: TourPlanEntryStatus.sentBack, purposes: ['Sample Collection']),
      _SeedItem(day: 18, customer: 'Care & Cure Center', status: TourPlanEntryStatus.pending, purposes: ['Prescription Follow-up']),
      _SeedItem(day: 21, customer: 'Sunrise Clinic', status: TourPlanEntryStatus.approved, purposes: ['Sample Collection']),
      _SeedItem(day: 24, customer: 'Hiranandani Hospital', status: TourPlanEntryStatus.pending, purposes: ['Product Detailing']),
    ];
    for (final s in seeds) {
      _entries.add(TourPlanEntry(
        id: _genId(),
        date: DateTime(month.year, month.month, s.day),
        cluster: 'Andheri East',
        customer: s.customer,
        employeeId: 'me',
        employeeName: 'John Doe',
        status: s.status,
        callDetails: TourPlanCallDetails(
          purposes: s.purposes,
          productsToDiscuss: 'Device X, Device Y',
          samplesToDistribute: 'Sample A',
          remarks: 'Planned call',
        ),
        createdAt: now,
        updatedAt: now,
      ));
    }
  }

}

class _SeedItem {
  _SeedItem({required this.day, required this.customer, required this.status, required this.purposes});
  final int day;
  final String customer;
  final TourPlanEntryStatus status;
  final List<String> purposes;
}


