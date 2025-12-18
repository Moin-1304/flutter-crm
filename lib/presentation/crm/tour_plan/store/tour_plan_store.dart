import 'package:boilerplate/core/stores/error/error_store.dart';
import 'package:boilerplate/domain/entity/tour_plan/tour_plan.dart';
import 'package:boilerplate/domain/repository/tour_plan/tour_plan_repository.dart';
import 'package:mobx/mobx.dart';

import '../../../../data/network/apis/user/lib/domain/entity/tour_plan/calendar_view_data.dart';
import '../../../../data/network/apis/user/lib/domain/entity/tour_plan/tour_plan_api_models.dart';

part 'tour_plan_store.g.dart';

class TourPlanStore = _TourPlanStore with _$TourPlanStore;

abstract class _TourPlanStore with Store {
  _TourPlanStore(this._repo, this.errorStore);

  final TourPlanRepository _repo;
  final ErrorStore errorStore;

  @observable
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @observable
  ObservableFuture<List<TourPlanEntry>> fetchMonthFuture =
      ObservableFuture<List<TourPlanEntry>>.value(const <TourPlanEntry>[]);

  @observable
  List<TourPlanEntry> entries = <TourPlanEntry>[];

  @observable
  List<CalendarViewData> calendarViewData = <CalendarViewData>[];

  @observable
  ObservableFuture<List<CalendarViewData>> fetchCalendarDataFuture =
      ObservableFuture<List<CalendarViewData>>.value(const <CalendarViewData>[]);

  @observable
  List<TourPlanItem> tourPlanListItems = <TourPlanItem>[];

  @observable
  ObservableFuture<TourPlanGetResponse> fetchTourPlanDetailsFuture =
      ObservableFuture<TourPlanGetResponse>.value(TourPlanGetResponse(items: [], totalRecords: 0, filteredRecords: 0));

  @observable
  List<TourPlanItem> tourPlanDetailsItems = <TourPlanItem>[];

  @observable
  ObservableFuture<TourPlanGetResponse> fetchTourPlanListFuture =
      ObservableFuture<TourPlanGetResponse>.value(TourPlanGetResponse(items: [], totalRecords: 0, filteredRecords: 0));

  @observable
  List<TourPlanItem> calendarItemListData = <TourPlanItem>[];

  @observable
  ObservableFuture<TourPlanGetResponse> fetchCalendarItemListDataFuture =
      ObservableFuture<TourPlanGetResponse>.value(TourPlanGetResponse(items: [], totalRecords: 0, filteredRecords: 0));

  @computed
  bool get loading => fetchMonthFuture.status == FutureStatus.pending;

  @computed
  bool get calendarLoading => fetchCalendarDataFuture.status == FutureStatus.pending;

  @computed
  bool get tourPlanListLoading => fetchTourPlanListFuture.status == FutureStatus.pending;

  @computed
  bool get calendarItemListDataLoading => fetchCalendarItemListDataFuture.status == FutureStatus.pending;

  @computed
  bool get aggregateCountLoading => fetchAggregateCountFuture.status == FutureStatus.pending;

  @computed
  bool get tourPlanSummaryLoading => fetchTourPlanSummaryFuture?.status == FutureStatus.pending;

  @computed
  bool get managerSummaryLoading => fetchManagerSummaryFuture.status == FutureStatus.pending;

  @computed
  bool get employeeListSummaryLoading => fetchEmployeeListSummaryFuture.status == FutureStatus.pending;

  @computed
  bool get mappedCustomersLoading => fetchMappedCustomersFuture.status == FutureStatus.pending;

  @observable
  Map<String, dynamic>? saveResponse;

  @observable
  TourPlanAggregateCountResponse? aggregateCountData;

  @observable
  ObservableFuture<TourPlanAggregateCountResponse> fetchAggregateCountFuture = ObservableFuture.value(TourPlanAggregateCountResponse(
    totalEmployees: 0,
    planned: 0,
    approved: 0,
    pending: 0,
    sendBack: 0,
    notEntered: 0,
    leaveCount: 0,
    totalPlanned: 0,
    totalApproved: 0,
    totalPending: 0,
    totalSentBack: 0,
    totalLeave: 0,
    totalNotEntered: 0,
  ));

  @observable
  TourPlanGetSummaryResponse? tourPlanSummaryData;

  @observable
  ObservableFuture<TourPlanGetSummaryResponse>? fetchTourPlanSummaryFuture;

  @observable
  TourPlanGetManagerSummaryResponse? managerSummaryData;

  @observable
  ObservableFuture<TourPlanGetManagerSummaryResponse> fetchManagerSummaryFuture = ObservableFuture.value(TourPlanGetManagerSummaryResponse(
    totalEmployees: 0,
    notPlannedEmployees: 0,
    approvedDays: 0,
    partiallyApprovedCount: 0,
    fullyApproved: 0,
    partialMixedStatus: 0,
    notPlanned: 0,
    totalPlanned: 0,
    totalApproved: 0,
    totalPending: 0,
    totalSentBack: 0,
    totalLeave: 0,
    totalNotEntered: 0,
  ));

  @observable
  TourPlanGetEmployeeListSummaryResponse? employeeListSummaryData;

  @observable
  ObservableFuture<TourPlanGetEmployeeListSummaryResponse> fetchEmployeeListSummaryFuture = ObservableFuture.value(TourPlanGetEmployeeListSummaryResponse(
    employees: [],
  ));

  @observable
  List<MappedCustomer> mappedCustomers = <MappedCustomer>[];

  @observable
  ObservableFuture<GetMappedCustomersByEmployeeIdResponse> fetchMappedCustomersFuture = ObservableFuture.value(GetMappedCustomersByEmployeeIdResponse(
    customers: [],
    totalRecords: 0,
    filteredRecords: 0,
    pageNumber: 0,
    pageSize: 0,
  ));

  @action
  Future<void> loadMonth({String? employeeId, String? customer, TourPlanEntryStatus? status}) async {
    final Future<List<TourPlanEntry>> f = _repo.listMonth(
      month: month,
      employeeId: employeeId,
      customer: customer,
      status: status,
    );
    fetchMonthFuture = ObservableFuture(f);
    await f.then((data) => entries = data).catchError((e) {
      errorStore.errorMessage = e.toString();
    });
  }

  @action
  Future<void> approve(List<String> ids) async {
    await _repo.approve(ids);
    await loadMonth();
  }

  @action
  Future<void> sendBack(List<String> ids, String comment) async {
    await _repo.sendBack(ids, comment: comment);
    await loadMonth();
  }

  @action
  Future<void> reject(List<String> ids, String comment) async {
    await _repo.reject(ids, comment: comment);
    await loadMonth();
  }

  @action
  Future<void> loadCalendarViewData({
    required int month,
    required int year,
    int? userId,
    int managerId = 0,
    int employeeId = 0,
    int selectedEmployeeId = 0,
  }) async {
    print('TourPlanStore: loadCalendarViewData called for $month/$year');
    
    // Clear existing data for hard refresh
    calendarViewData = <CalendarViewData>[];
    
    // Ensure SelectedEmployeeId equals employeeId as per API requirement
    final int finalSelectedEmployeeId = selectedEmployeeId != 0 ? selectedEmployeeId : employeeId;
    
    final request = CalendarViewRequest(
      month: month,
      year: year,
      userId: userId, // Pass null if not provided, as per API requirement
      managerId: managerId,
      employeeId: employeeId,
      selectedEmployeeId: finalSelectedEmployeeId, // SelectedEmployeeId must equal employeeId
    );
    
    print('TourPlanStore: Created request: ${request.toJson()}');
    
    final Future<List<CalendarViewData>> f = _repo.getCalendarViewData(request);
    fetchCalendarDataFuture = ObservableFuture(f);
    
    try {
      final data = await f;
      calendarViewData = data;
      print('TourPlanStore: Calendar data loaded successfully - ${data.length} entries');
    } catch (e) {
      print('TourPlanStore: Error loading calendar data: $e');
      errorStore.errorMessage = e.toString();
    }
  }

  @action
  Future<void> loadTourPlanDetails({
    String? searchText,
    int pageNumber = 1,
    int pageSize = 1000,
    int? employeeId,
    int? month,
    int? userId,
    int? bizunit,
    int? year,
    int? selectedEmployeeId,
  }) async {
    print('TourPlanStore: loadTourPlanList called');
    
    // Ensure SelectedEmployeeId equals employeeId as per API requirement
    final int? finalSelectedEmployeeId = selectedEmployeeId ?? employeeId;
    
    final request = TourPlanGetRequest(
      searchText: searchText,
      pageNumber: pageNumber,
      pageSize: pageSize,
      employeeId: employeeId,
      month: month,
      userId: userId,
      bizunit: bizunit,
      year: year,
      selectedEmployeeId: finalSelectedEmployeeId, // SelectedEmployeeId must equal employeeId
    );
    
    print('TourPlanStore: Created request: ${request.toJson()}');
    
    final Future<TourPlanGetResponse> f = _repo.getTourPlanDetail(request);
    fetchTourPlanListFuture = ObservableFuture(f);
    
    try {
      final response = await f;
      tourPlanListItems = response.items;
      print('TourPlanStore: Tour plan list loaded successfully - ${response.items.length} entries');
      print('TourPlanStore: Total records: ${response.totalRecords}, Filtered: ${response.filteredRecords}');
    } catch (e) {
      print('TourPlanStore: Error loading tour plan list: $e');
      errorStore.errorMessage = e.toString();
    }
  }

  @action
  Future<void> loadCalendarItemListData({
    String? searchText,
    int pageNumber = 1,
    int pageSize = 1000,
    required int employeeId,
    required int month,
    required int userId,
    required int bizunit,
    required int year,
    int? selectedEmployeeId,
    int? customerId,
    int? status,
    int? sortOrder,
    int? sortDir,
    String? sortField,
  }) async {
    print('TourPlanStore: loadCalendarItemListData called for month $month, year $year, employeeId $employeeId');
    
    // Clear existing data for hard refresh
    calendarItemListData = <TourPlanItem>[];
    
    final request = TourPlanGetRequest(
      searchText: searchText,
      pageNumber: pageNumber,
      pageSize: pageSize,
      employeeId: employeeId,
      month: month,
      userId: userId,
      bizunit: bizunit,
      year: year,
      customerId: customerId,
      status: status,
      selectedEmployeeId: selectedEmployeeId ?? employeeId, // SelectedEmployeeId must equal employeeId if not provided
      sortOrder: sortOrder,
      sortDir: sortDir,
      sortField: sortField,
    );
    
    print('TourPlanStore: Created calendar item list request: ${request.toJson()}');
    
    final Future<TourPlanGetResponse> f = _repo.getTourPlanListData(request);
    fetchCalendarItemListDataFuture = ObservableFuture(f);
    
    try {
      final response = await f;
      calendarItemListData = response.items;
      print('TourPlanStore: Calendar item list data loaded successfully - ${response.items.length} entries');
      print('TourPlanStore: Total records: ${response.totalRecords}, Filtered: ${response.filteredRecords}');
    } catch (e) {
      print('TourPlanStore: Error loading calendar item list data: $e');
      errorStore.errorMessage = e.toString();
    }
  }

  @action
  Future<void> saveTourPlan(Map<String, dynamic> body) async {
    try {
      final res = await _repo.saveTourPlan(body);
      print("TourPlanStore: Response $res");
      saveResponse = res;
    } catch (e) {
      print("TourPlanStore: Error in saveTourPlan: $e");
      errorStore.errorMessage = e.toString();
      // Set error response so UI can handle it properly
      saveResponse = {
        'status': false,
        'msg': 'Error occurred while saving tour plan',
        'error': e.toString(),
        'errorMessage': e.toString(),
      };
    }
  }

  @action
  Future<void> updateTourPlan(Map<String, dynamic> body) async {
    try {
      final res = await _repo.updateTourPlan(body);
      saveResponse = res;
    } catch (e) {
      errorStore.errorMessage = e.toString();
    }
  }

  @action
  Future<void> loadAggregateCountSummary({
    required int employeeId,
    required int month,
    required int year,
  }) async {
    print('TourPlanStore: loadAggregateCountSummary called for employee $employeeId, month $month, year $year');
    
    final request = TourPlanAggregateCountRequest(
      employeeId: employeeId,
      month: month,
      year: year,
    );
    
    print('TourPlanStore: Created aggregate count request: ${request.toJson()}');
    
    final Future<TourPlanAggregateCountResponse> f = _repo.getTourPlanAggregateCountSummary(request);
    fetchAggregateCountFuture = ObservableFuture(f);
    
    try {
      final data = await f;
      aggregateCountData = data;
      print('TourPlanStore: Aggregate count data loaded successfully');
      print('TourPlanStore: Total Employees: ${data.totalEmployees}, Planned: ${data.planned}, Approved: ${data.approved}');
    } catch (e) {
      print('TourPlanStore: Error loading aggregate count data: $e');
      errorStore.errorMessage = e.toString();
    }
  }

  @action
  Future<void> loadTourPlanSummary({
    required int month,
    required int year,
    required int userId,
    required int bizunit,
  }) async {
    print('TourPlanStore: loadTourPlanSummary called for month $month, year $year, userId $userId, bizunit $bizunit');
    
    final request = TourPlanGetSummaryRequest(
      month: month,
      year: year,
      userId: userId,
      bizunit: bizunit,
    );
    
    print('TourPlanStore: Created tour plan summary request: ${request.toJson()}');
    
    final Future<TourPlanGetSummaryResponse> f = _repo.getTourPlanSummary(request);
    fetchTourPlanSummaryFuture = ObservableFuture(f);
    
    try {
      final data = await f;
      tourPlanSummaryData = data;
      print('TourPlanStore: Tour plan summary data loaded successfully');
      print('TourPlanStore: Planned Days: ${data.approvedDays}, Approved Days: ${data.approvedDays}, Pending Days: ${data.pendingDays}, Sent Back Days: ${data.sentBackDays}');
    } catch (e) {
      print('TourPlanStore: Error loading tour plan summary data: $e');
      errorStore.errorMessage = e.toString();
    }
  }

  @action
  Future<void> loadManagerSummary({
    required int employeeId,
    required int month,
    required int year,
  }) async {
    print('TourPlanStore: loadManagerSummary called for employee $employeeId, month $month, year $year');
    
    final request = TourPlanGetManagerSummaryRequest(
      employeeId: employeeId,
      month: month,
      year: year,
    );
    
    print('TourPlanStore: Created manager summary request: ${request.toJson()}');
    
    final Future<TourPlanGetManagerSummaryResponse> f = _repo.getTourPlanManagerSummary(request);
    fetchManagerSummaryFuture = ObservableFuture(f);
    
    try {
      final data = await f;
      managerSummaryData = data;
      print('TourPlanStore: Manager summary data loaded successfully');
      print('TourPlanStore: Total Employees: ${data.totalEmployees}, Not Planned Employees: ${data.notPlannedEmployees}, Fully Approved: ${data.fullyApproved}');
    } catch (e) {
      print('TourPlanStore: Error loading manager summary data: $e');
      errorStore.errorMessage = e.toString();
    }
  }

  @action
  Future<void> loadTourPlanEmployeeListSummary({
    required int employeeId,
    required int month,
    required int year,
  }) async {
    print('TourPlanStore: loadEmployeeListSummary called for employee $employeeId, month $month, year $year');
    
    // Clear existing data to prevent type confusion
    employeeListSummaryData = null;
    
    final request = TourPlanGetEmployeeListSummaryRequest(
      employeeId: employeeId,
      month: month,
      year: year,
    );
    
    print('TourPlanStore: Created employee list summary request: ${request.toJson()}');
    
    final Future<TourPlanGetEmployeeListSummaryResponse> f = _repo.getTourPlanEmployeeListSummary(request);
    fetchEmployeeListSummaryFuture = ObservableFuture(f);
    
    try {
      final data = await f;
      // Ensure we're assigning the correct type
      if (data is TourPlanGetEmployeeListSummaryResponse) {
        employeeListSummaryData = data;
        print('TourPlanStore: Employee list summary data loaded successfully');
        print('TourPlanStore: Total Employees: ${data.totalEmployees}, Planned: ${data.totalPlanned}, Approved: ${data.totalApproved}, Pending: ${data.totalPending}, Sent Back: ${data.totalSentBack}, Not Entered: ${data.totalNotEntered}');
      } else {
        print('TourPlanStore: ERROR - Received wrong type: ${data.runtimeType}, expected TourPlanGetEmployeeListSummaryResponse');
        employeeListSummaryData = null;
      }
    } catch (e) {
      print('TourPlanStore: Error loading employee list summary data: $e');
      errorStore.errorMessage = e.toString();
      employeeListSummaryData = null;
    }
  }

  @action
  Future<void> loadMappedCustomersByEmployeeId({
    String? searchText,
    int pageNumber = 0,
    int pageSize = 10,
    int? employeeId,
    int? clusterId,
    int? customerId,
    int? month,
    int? tourPlanId,
    int? userId,
    int? bizunit,
    String? filterExpression,
    int? monthNumber,
    int? year,
    int? id,
    int? action,
    String? comment,
    int? status,
    int? tourPlanAcceptId,
    String? remarks,
    List<ClusterIdModel>? clusterIds,
    int? selectedEmployeeId,
  }) async {
    print('TourPlanStore: loadMappedCustomersByEmployeeId called for employee $selectedEmployeeId');
    
    final request = GetMappedCustomersByEmployeeIdRequest(
      searchText: searchText,
      pageNumber: pageNumber,
      pageSize: pageSize,
      employeeId: employeeId,
      clusterId: clusterId,
      customerId: customerId,
      month: month,
      tourPlanId: tourPlanId,
      userId: userId,
      bizunit: bizunit,
      filterExpression: filterExpression,
      monthNumber: monthNumber,
      year: year,
      id: id,
      action: action,
      comment: comment,
      status: status,
      tourPlanAcceptId: tourPlanAcceptId,
      remarks: remarks,
      clusterIds: clusterIds,
      selectedEmployeeId: selectedEmployeeId,
    );
    
    print('TourPlanStore: Created mapped customers request: ${request.toJson()}');
    
    final Future<GetMappedCustomersByEmployeeIdResponse> f = _repo.getMappedCustomersByEmployeeId(request);
    fetchMappedCustomersFuture = ObservableFuture(f);
    
    try {
      final data = await f;
      mappedCustomers = data.customers;
      print('TourPlanStore: Mapped customers data loaded successfully');
      print('TourPlanStore: Total Customers: ${data.totalRecords}, Filtered: ${data.filteredRecords}, Page: ${data.pageNumber}/${data.pageSize}');
    } catch (e) {
      print('TourPlanStore: Error loading mapped customers data: $e');
      errorStore.errorMessage = e.toString();
    }
  }

  @action
  Future<TourPlanActionResponse> approveSingleTourPlan(TourPlanActionRequest request) async {
    try {
      print('TourPlanStore: approveSingleTourPlan called for ID: ${request.id}');
      final response = await _repo.approveSingleTourPlan(request);
      print('TourPlanStore: Single tour plan approved successfully');
      return response;
    } catch (e) {
      print('TourPlanStore: Error approving single tour plan: $e');
      errorStore.errorMessage = e.toString();
      rethrow;
    }
  }

  @action
  Future<TourPlanActionResponse> rejectSingleTourPlan(TourPlanActionRequest request) async {
    try {
      print('TourPlanStore: rejectSingleTourPlan called for ID: ${request.id}');
      final response = await _repo.rejectSingleTourPlan(request);
      print('TourPlanStore: Single tour plan rejected successfully');
      return response;
    } catch (e) {
      print('TourPlanStore: Error rejecting single tour plan: $e');
      errorStore.errorMessage = e.toString();
      rethrow;
    }
  }

  @action
  Future<TourPlanActionResponse> bulkApproveTourPlans(TourPlanBulkActionRequest request) async {
    try {
      print('TourPlanStore: bulkApproveTourPlans called for ID: ${request.id}');
      final response = await _repo.bulkApproveTourPlans(request);
      print('TourPlanStore: Tour plans bulk approved successfully');
      
      // Force clear the data to ensure fresh reload
      // This ensures the UI will show updated status after approval
      calendarItemListData = <TourPlanItem>[];
      calendarViewData = <CalendarViewData>[];
      print('TourPlanStore: Cleared calendar data to force refresh');
      
      return response;
    } catch (e) {
      print('TourPlanStore: Error bulk approving tour plans: $e');
      errorStore.errorMessage = e.toString();
      rethrow;
    }
  }

  @action
  Future<TourPlanActionResponse> bulkSendBackTourPlans(TourPlanBulkActionRequest request) async {
    try {
      print('TourPlanStore: bulkSendBackTourPlans called for ID: ${request.id}, Action: ${request.action}');
      final response = await _repo.bulkSendBackTourPlans(request);
      print('TourPlanStore: Tour plans bulk action completed successfully (Action: ${request.action})');
      
      // Force clear the data to ensure fresh reload
      // This ensures the UI will show updated status after send back/reject
      calendarItemListData = <TourPlanItem>[];
      calendarViewData = <CalendarViewData>[];
      print('TourPlanStore: Cleared calendar data to force refresh');
      
      return response;
    } catch (e) {
      print('TourPlanStore: Error bulk action (Action: ${request.action}): $e');
      errorStore.errorMessage = e.toString();
      rethrow;
    }
  }

  @action
  Future<TourPlanCommentSaveResponse> saveTourPlanComment(TourPlanCommentSaveRequest request) async {
    try {
      print('TourPlanStore: saveTourPlanComment called for TourPlanId: ${request.tourPlanId}');
      final response = await _repo.saveTourPlanComment(request);
      print('TourPlanStore: Tour plan comment saved successfully');
      return response;
    } catch (e) {
      print('TourPlanStore: Error saving tour plan comment: $e');
      errorStore.errorMessage = e.toString();
      rethrow;
    }
  }

  @action
  Future<List<TourPlanCommentItem>> getTourPlanCommentsList(TourPlanCommentGetListRequest request) async {
    try {
      print('TourPlanStore: getTourPlanCommentsList called for id: ${request.id}');
      final response = await _repo.getTourPlanCommentsList(request);
      print('TourPlanStore: Tour plan comments list retrieved successfully - ${response.length} comments');
      return response;
    } catch (e) {
      print('TourPlanStore: Error getting tour plan comments list: $e');
      errorStore.errorMessage = e.toString();
      rethrow;
    }
  }

  @action
  Future<TourPlanActionResponse> deleteTourPlan(int id) async {
    try {
      print('TourPlanStore: deleteTourPlan called for ID: $id');
      final response = await _repo.deleteTourPlan(id);
      print('TourPlanStore: Tour plan deleted successfully');
      
      // Force clear the data to ensure fresh reload
      calendarItemListData = <TourPlanItem>[];
      calendarViewData = <CalendarViewData>[];
      print('TourPlanStore: Cleared calendar data to force refresh');
      
      return response;
    } catch (e) {
      print('TourPlanStore: Error deleting tour plan: $e');
      errorStore.errorMessage = e.toString();
      rethrow;
    }
  }
}


