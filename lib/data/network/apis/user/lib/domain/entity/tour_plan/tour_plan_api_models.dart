class TourPlanGetRequest {
  final String? searchText;
  final int pageNumber;
  final int pageSize;
  final int? employeeId;
  final int? month;
  final int? userId;
  final int? bizunit;
  final int? year;
  final int? customerId;
  final int? status;
  final int? sortOrder;
  final int? sortDir;
  final String? sortField;
  final int? clusterId;
  final int? tourPlanId;
  final String? filterExpression;
  final int? monthNumber;
  final int? id;
  final int? action;
  final String? comment;
  final int? tourPlanAcceptId;
  final String? remarks;
  final List<ClusterIdModel>? clusterIds;
  final int? selectedEmployeeId;
  final String? date;

  TourPlanGetRequest({
    this.searchText,
    this.pageNumber = 1,
    this.pageSize = 1000,
    this.employeeId,
    this.month,
    this.userId,
    this.bizunit,
    this.year,
    this.customerId,
    this.status,
    this.sortOrder,
    this.sortDir,
    this.sortField,
    this.clusterId,
    this.tourPlanId,
    this.filterExpression,
    this.monthNumber,
    this.id,
    this.action,
    this.comment,
    this.tourPlanAcceptId,
    this.remarks,
    this.clusterIds,
    this.selectedEmployeeId,
    this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'SearchText': searchText,
      'PageNumber': pageNumber,
      'PageSize': pageSize,
      'EmployeeId': employeeId,
      'Month': month,
      'UserId': userId,
      'Bizunit': bizunit,
      'Year': year,
      // Additional filters (use PascalCase only to avoid duplicates)
      'CustomerId': customerId,
      'Status': status,
      'SortOrder': sortOrder,
      'SortDir': sortDir,
      'SortField': sortField,
      'ClusterId': clusterId,
      'TourPlanId': tourPlanId,
      'FilterExpression': filterExpression,
      'MonthNumber': monthNumber,
      'Id': id,
      'Action': action,
      'Comment': comment,
      'TourPlanAcceptId': tourPlanAcceptId,
      'Remarks': remarks,
      'ClusterIds': clusterIds?.map((e) => e.toJson()).toList(),
      'SelectedEmployeeId': selectedEmployeeId,
      'Date': date,
    };
  }
}

class ClusterIdModel {
  final int clusterId;

  ClusterIdModel({required this.clusterId});

  Map<String, dynamic> toJson() {
    return {
      'ClusterId': clusterId,
    };
  }
}

class TourPlanGetResponse {
  final List<TourPlanItem> items;
  final int totalRecords;
  final int filteredRecords;

  TourPlanGetResponse({
    required this.items,
    required this.totalRecords,
    required this.filteredRecords,
  });

  factory TourPlanGetResponse.fromJson(Map<String, dynamic> json) {
    return TourPlanGetResponse(
      items: (json['items'] as List?)
          ?.map((e) => TourPlanItem.fromJson(e))
          .toList() ?? [],
      totalRecords: json['totalRecords'] ?? 0,
      filteredRecords: json['filteredRecords'] ?? 0,
    );
  }
}

class TourPlanItem {
  final DateTime createdDate;
  final int modifiedBy;
  final DateTime? modifiedDate;
  final int id;
  final int tourPlanId;
  final int? createdBy;
  final int status;
  final int sbuId;
  final int employee;
  final int month;
  final int year;
  final int statusId;
  final DateTime? submittedDate;
  final String? remarks;
  final bool active;
  final int userId;
  final int employeeId;
  final DateTime? date;
  final String? territory;
  final String? cluster;
  final int? clusterId;
  final String? tourPlanType;
  final String? objective;
  final String? tourPlanStatus;
  final String? tourPlanHeaderStatus;
  final String? summary;
  final List<TourPlanDetail>? tourPlanDetails;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final String? managerComments;
  final String? actionComments;
  final List<Comment>? comments;
  final int bizunit;
  final bool isSelected;
  final String? employeeName;
  final String? designation;
  final String? statusText;
  final DateTime planDate;
  final int customerId;
  final String? customerName;
  final String? clusters;
  final String? samplesToDistribute;
  final String? productsToDiscuss;
  final String? notes;
  final int fromDeviation;

  TourPlanItem({
    required this.createdDate,
    required this.modifiedBy,
    this.modifiedDate,
    required this.id,
    required this.tourPlanId,
    this.createdBy,
    required this.status,
    required this.sbuId,
    required this.employee,
    required this.month,
    required this.year,
    required this.statusId,
    this.submittedDate,
    this.remarks,
    required this.active,
    required this.userId,
    required this.employeeId,
    this.date,
    this.territory,
    this.cluster,
    this.clusterId,
    this.tourPlanType,
    this.objective,
    this.tourPlanStatus,
    this.tourPlanHeaderStatus,
    this.summary,
    this.tourPlanDetails,
    this.createdAt,
    this.updatedAt,
    this.submittedAt,
    this.approvedAt,
    this.rejectedAt,
    this.rejectionReason,
    this.managerComments,
    this.actionComments,
    this.comments,
    required this.bizunit,
    required this.isSelected,
    this.employeeName,
    this.designation,
    this.statusText,
    required this.planDate,
    required this.customerId,
    this.customerName,
    this.clusters,
    this.samplesToDistribute,
    this.productsToDiscuss,
    this.notes,
    required this.fromDeviation,
  });

  factory TourPlanItem.fromJson(Map<String, dynamic> json) {
    return TourPlanItem(
      createdDate: DateTime.parse(json['createdDate'] ?? '0001-01-01T00:00:00'),
      modifiedBy: json['modifiedBy'] ?? 0,
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate']) : null,
      id: json['id'] ?? 0,
      tourPlanId: json['tourPlanId'] ?? 0,
      createdBy: json['createdBy'],
      status: json['status'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      employee: json['employee'] ?? 0,
      month: json['month'] ?? 0,
      year: json['year'] ?? 0,
      statusId: json['statusId'] ?? 0,
      submittedDate: json['submittedDate'] != null ? DateTime.parse(json['submittedDate']) : null,
      remarks: json['remarks'],
      active: json['active'] ?? false,
      userId: json['userId'] ?? 0,
      employeeId: json['employeeId'] ?? 0,
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      territory: json['territory'],
      cluster: json['cluster'],
      clusterId: json['clusterId'],
      tourPlanType: json['tourPlanType'],
      objective: json['objective'],
      tourPlanStatus: json['tourPlanStatus'],
      tourPlanHeaderStatus: json['tourPlanHeaderStatus'],
      summary: json['summary'],
      tourPlanDetails: json['tourPlanDetails'] != null 
          ? (json['tourPlanDetails'] as List)
              .map((e) => TourPlanDetail.fromJson(e))
              .toList()
          : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      submittedAt: json['submittedAt'] != null ? DateTime.parse(json['submittedAt']) : null,
      approvedAt: json['approvedAt'] != null ? DateTime.parse(json['approvedAt']) : null,
      rejectedAt: json['rejectedAt'] != null ? DateTime.parse(json['rejectedAt']) : null,
      rejectionReason: json['rejectionReason'],
      managerComments: json['managerComments'],
      actionComments: json['actionComments'],
      comments: json['comments'] != null 
          ? (json['comments'] as List)
              .map((e) => Comment.fromJson(e))
              .toList()
          : null,
      bizunit: json['bizunit'] ?? 0,
      isSelected: json['isSelected'] ?? false,
      employeeName: json['employeeName'],
      designation: json['designation'],
      statusText: json['statusText'],
      planDate: DateTime.parse(json['planDate'] ?? '0001-01-01T00:00:00'),
      customerId: json['customerId'] ?? 0,
      customerName: json['customerName'],
      clusters: json['clusters'],
      samplesToDistribute: json['samplesToDistribute'],
      productsToDiscuss: json['productsToDiscuss'],
      notes: json['notes'],
      fromDeviation: json['fromDeviation'] ?? 0,
    );
  }
}

class TourPlanDetail {
  final int id;
  final DateTime planDate;
  final int typeOfWorkId;
  final int clusterId;
  final int customerId;
  final int status;
  final String? remarks;
  final String? location;
  final double latitude;
  final double longitude;
  final String? samplesToDistribute;
  final String? productsToDiscuss;
  final String? clusterNames;
  final List<Customer> customers;

  TourPlanDetail({
    required this.id,
    required this.planDate,
    required this.typeOfWorkId,
    required this.clusterId,
    required this.customerId,
    required this.status,
    this.remarks,
    this.location,
    required this.latitude,
    required this.longitude,
    this.samplesToDistribute,
    this.productsToDiscuss,
    this.clusterNames,
    required this.customers,
  });

  factory TourPlanDetail.fromJson(Map<String, dynamic> json) {
    return TourPlanDetail(
      id: json['id'] ?? 0,
      planDate: DateTime.parse(json['planDate']),
      typeOfWorkId: json['typeOfWorkId'] ?? 0,
      clusterId: json['clusterId'] ?? 0,
      customerId: json['customerId'] ?? 0,
      status: json['status'] ?? 0,
      remarks: json['remarks'],
      location: json['location'],
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      samplesToDistribute: json['samplesToDistribute'],
      productsToDiscuss: json['productsToDiscuss'],
      clusterNames: json['clusterNames'],
      customers: (json['customers'] as List?)
          ?.map((e) => Customer.fromJson(e))
          .toList() ?? [],
    );
  }
}

class Customer {
  final int customerId;
  final int clusterId;

  Customer({
    required this.customerId,
    required this.clusterId,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      customerId: json['customerId'] ?? 0,
      clusterId: json['clusterId'] ?? 0,
    );
  }
}

class Comment {
  final String id;
  final String userId;
  final String userName;
  final String comment;
  final DateTime createdAt;
  final String? userRole;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.comment,
    required this.createdAt,
    this.userRole,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      comment: json['comment'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      userRole: json['userRole'],
    );
  }
}

class TourPlanAggregateCountRequest {
  final int employeeId;
  final int month;
  final int year;

  TourPlanAggregateCountRequest({
    required this.employeeId,
    required this.month,
    required this.year,
  });

  Map<String, dynamic> toJson() {
    return {
      'EmployeeId': employeeId,
      'Month': month,
      'Year': year,
    };
  }
}

class TourPlanAggregateCountResponse {
  final int totalEmployees;
  final int planned;
  final int approved;
  final int pending;
  final int sendBack;
  final int notEntered;
  final int leaveCount;
  final int totalPlanned;
  final int totalApproved;
  final int totalPending;
  final int totalSentBack;
  final int totalLeave;
  final int totalNotEntered;

  TourPlanAggregateCountResponse({
    required this.totalEmployees,
    required this.planned,
    required this.approved,
    required this.pending,
    required this.sendBack,
    required this.notEntered,
    required this.leaveCount,
    required this.totalPlanned,
    required this.totalApproved,
    required this.totalPending,
    required this.totalSentBack,
    required this.totalLeave,
    required this.totalNotEntered,
  });

  factory TourPlanAggregateCountResponse.fromJson(Map<String, dynamic> json) {
    return TourPlanAggregateCountResponse(
      totalEmployees: json['totalEmployees'] ?? 0,
      planned: json['planned'] ?? 0,
      approved: json['approved'] ?? 0,
      pending: json['pending'] ?? 0,
      sendBack: json['sendBack'] ?? 0,
      notEntered: json['notEntered'] ?? 0,
      leaveCount: json['leaveCount'] ?? 0,
      totalPlanned: json['totalPlanned'] ?? 0,
      totalApproved: json['totalApproved'] ?? 0,
      totalPending: json['totalPending'] ?? 0,
      totalSentBack: json['totalSentBack'] ?? 0,
      totalLeave: json['totalLeave'] ?? 0,
      totalNotEntered: json['totalNotEntered'] ?? 0,
    );
  }
}

class TourPlanGetSummaryRequest {
  final int month;
  final int year;
  final int userId;
  final int bizunit;

  TourPlanGetSummaryRequest({
    required this.month,
    required this.year,
    required this.userId,
    required this.bizunit,
  });

  Map<String, dynamic> toJson() {
    return {
      'Month': month,
      'Year': year,
      'UserId': userId,
      'Bizunit': bizunit,
    };
  }
}

class TourPlanGetSummaryResponse {
  final int planedDays;
  final int approvedDays;
  final int pendingDays;
  final int sentBackDays;

  TourPlanGetSummaryResponse({
    required this.planedDays,
    required this.approvedDays,
    required this.pendingDays,
    required this.sentBackDays,
  });

  factory TourPlanGetSummaryResponse.fromJson(Map<String, dynamic> json) {
    return TourPlanGetSummaryResponse(
      planedDays: json['planedDays'] ?? 0,
      approvedDays: json['approvedDays'] ?? 0,
      pendingDays: json['pendingDays'] ?? 0,
      sentBackDays: json['sentBackDays'] ?? 0,
    );
  }
}

class TourPlanGetManagerSummaryRequest {
  final int employeeId;
  final int month;
  final int year;

  TourPlanGetManagerSummaryRequest({
    required this.employeeId,
    required this.month,
    required this.year,
  });

  Map<String, dynamic> toJson() {
    return {
      'EmployeeId': employeeId,
      'Month': month,
      'Year': year,
    };
  }
}

class TourPlanGetManagerSummaryResponse {
  final int totalEmployees;
  final int notPlannedEmployees;
  final int approvedDays;
  final int partiallyApprovedCount;
  final int fullyApproved;
  final int partialMixedStatus;
  final int notPlanned;
  final int totalPlanned;
  final int totalApproved;
  final int totalPending;
  final int totalSentBack;
  final int totalLeave;
  final int totalNotEntered;

  TourPlanGetManagerSummaryResponse({
    required this.totalEmployees,
    required this.notPlannedEmployees,
    required this.approvedDays,
    required this.partiallyApprovedCount,
    required this.fullyApproved,
    required this.partialMixedStatus,
    required this.notPlanned,
    required this.totalPlanned,
    required this.totalApproved,
    required this.totalPending,
    required this.totalSentBack,
    required this.totalLeave,
    required this.totalNotEntered,
  });

  factory TourPlanGetManagerSummaryResponse.fromJson(dynamic json) {
    // Handle case where API returns a List directly (return empty response)
    if (json is List) {
      return TourPlanGetManagerSummaryResponse(
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
      );
    }
    
    // Handle case where API returns a Map
    if (json is Map<String, dynamic>) {
      return TourPlanGetManagerSummaryResponse(
        totalEmployees: json['totalEmployees'] ?? 0,
        notPlannedEmployees: json['notPlannedEmployees'] ?? 0,
        approvedDays: json['approvedDays'] ?? 0,
        partiallyApprovedCount: json['partiallyApprovedCount'] ?? 0,
        fullyApproved: json['fullyApproved'] ?? 0,
        partialMixedStatus: json['partialMixedStatus'] ?? 0,
        notPlanned: json['notPlanned'] ?? 0,
        totalPlanned: json['totalPlanned'] ?? 0,
        totalApproved: json['totalApproved'] ?? 0,
        totalPending: json['totalPending'] ?? 0,
        totalSentBack: json['totalSentBack'] ?? 0,
        totalLeave: json['totalLeave'] ?? 0,
        totalNotEntered: json['totalNotEntered'] ?? 0,
      );
    }
    
    // Fallback for unexpected response format
    return TourPlanGetManagerSummaryResponse(
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
    );
  }
}

class TourPlanGetEmployeeListSummaryRequest {
  final int employeeId;
  final int month;
  final int year;

  TourPlanGetEmployeeListSummaryRequest({
    required this.employeeId,
    required this.month,
    required this.year,
  });

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'month': month,
      'year': year,
    };
  }
}

// Individual employee summary item from the API response
class EmployeeSummaryItem {
  final int employeeId;
  final String employeeName;
  final int planned;
  final int approved;
  final int pending;
  final int sentBack;
  final int notEntered;
  final int leaveCount;
  final String category;
  final int leave;

  EmployeeSummaryItem({
    required this.employeeId,
    required this.employeeName,
    required this.planned,
    required this.approved,
    required this.pending,
    required this.sentBack,
    required this.notEntered,
    required this.leaveCount,
    required this.category,
    required this.leave,
  });

  factory EmployeeSummaryItem.fromJson(Map<String, dynamic> json) {
    return EmployeeSummaryItem(
      employeeId: json['employeeId'] ?? 0,
      employeeName: json['employeeName'] ?? '',
      planned: json['planned'] ?? 0,
      approved: json['approved'] ?? 0,
      pending: json['pending'] ?? 0,
      sentBack: json['sentBack'] ?? 0,
      notEntered: json['notEntered'] ?? 0,
      leaveCount: json['leaveCount'] ?? 0,
      category: json['category'] ?? '',
      leave: json['leave'] ?? 0,
    );
  }
}

// Response model for employee list summary - contains array of employee items
class TourPlanGetEmployeeListSummaryResponse {
  final List<EmployeeSummaryItem> employees;

  TourPlanGetEmployeeListSummaryResponse({
    required this.employees,
  });

  factory TourPlanGetEmployeeListSummaryResponse.fromJson(dynamic json) {
    // Handle case where API returns a List directly
    if (json is List) {
      return TourPlanGetEmployeeListSummaryResponse(
        employees: json.map((e) => EmployeeSummaryItem.fromJson(e)).toList(),
      );
    }
    
    // Handle case where API returns a Map with employees array
    if (json is Map<String, dynamic>) {
      if (json['employees'] is List) {
        return TourPlanGetEmployeeListSummaryResponse(
          employees: (json['employees'] as List)
              .map((e) => EmployeeSummaryItem.fromJson(e))
              .toList(),
        );
      }
    }
    
    // Fallback for unexpected response format
    return TourPlanGetEmployeeListSummaryResponse(employees: []);
  }

  // Aggregated totals for UI display
  int get totalEmployees => employees.length;
  int get totalPlanned => employees.fold(0, (sum, e) => sum + e.planned);
  int get totalApproved => employees.fold(0, (sum, e) => sum + e.approved);
  int get totalPending => employees.fold(0, (sum, e) => sum + e.pending);
  int get totalSentBack => employees.fold(0, (sum, e) => sum + e.sentBack);
  int get totalNotEntered => employees.fold(0, (sum, e) => sum + e.notEntered);
  int get totalLeave => employees.fold(0, (sum, e) => sum + e.leave);
  
  // Additional computed properties for tour_plan_screen.dart compatibility
  int get notPlannedEmployees => employees.where((e) => e.planned == 0).length;
  int get fullyApproved => employees.where((e) => e.approved > 0 && e.pending == 0 && e.sentBack == 0).length;
  int get partiallyApprovedCount => employees.where((e) => e.approved > 0 && (e.pending > 0 || e.sentBack > 0)).length;
  int get approvedDays => totalApproved; // Same as totalApproved
  int get partialMixedStatus => employees.where((e) => e.approved > 0 && (e.pending > 0 || e.sentBack > 0 || e.notEntered > 0)).length;
  int get notPlanned => employees.where((e) => e.planned == 0).length; // Same as notPlannedEmployees
}

// Tour Plan Action Request Models
class TourPlanActionRequest {
  final int id;
  final int action;
  final String? comment;

  TourPlanActionRequest({
    required this.id,
    required this.action,
    this.comment,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Action': action,
      if (comment != null) 'Comment': comment,
    };
  }
}

class TourPlanBulkActionRequest {
  final int id;
  final int action;
  final List<TourPlanDetailItem> tourPlanDetails;

  TourPlanBulkActionRequest({
    required this.id,
    required this.action,
    required this.tourPlanDetails,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Action': action,
      'TourPlanDetails': tourPlanDetails.map((e) => e.toJson()).toList(),
    };
  }
}

class TourPlanDetailItem {
  final int id;

  TourPlanDetailItem({required this.id});

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
    };
  }
}

// Tour Plan Action Response Models
class TourPlanActionResponse {
  final bool status;
  final String message;

  TourPlanActionResponse({
    required this.status,
    required this.message,
  });

  factory TourPlanActionResponse.fromJson(Map<String, dynamic> json) {
    bool parseStatus(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final v = value.toLowerCase().trim();
        return v == 'true' || v == '1' || v == 'success' || v == 'ok';
      }
      return false;
    }
    String parseMessage(Map<String, dynamic> j) {
      final dynamic m = j['message'] ?? j['Message'] ?? j['msg'] ?? j['Msg'] ?? j['errorMessage'] ?? j['error'] ?? j['Error'];
      if (m == null) return 'Success';
      final s = '$m'.trim();
      return s.isEmpty ? 'Success' : s;
    }
    return TourPlanActionResponse(
      status: parseStatus(
        json['status'] ??
        json['Status'] ??
        json['success'] ??
        json['Success'] ??
        json['isSuccess'] ??
        json['IsSuccess'] ??
        // Fallbacks where 0 often denotes success in this API payload
        (json.containsKey('errorNumber') ? (json['errorNumber'] == 0) : null) ??
        (json.containsKey('retVal') ? (json['retVal'] == 0) : null)
      ),
      message: parseMessage(json),
    );
  }
}

// Get Mapped Customers Request Model
class GetMappedCustomersByEmployeeIdRequest {
  final String? searchText;
  final int pageNumber;
  final int pageSize;
  final int sortOrder;
  final int sortDir;
  final String? sortField;
  final int? employeeId;
  final int? clusterId;
  final int? customerId;
  final int? month;
  final int? tourPlanId;
  final int? userId;
  final int? bizunit;
  final String? filterExpression;
  final int? monthNumber;
  final int? year;
  final int? id;
  final int? action;
  final String? comment;
  final int? status;
  final int? tourPlanAcceptId;
  final String? remarks;
  final List<ClusterIdModel>? clusterIds;
  final int? selectedEmployeeId;
  final String? date; // ISO date string or null

  GetMappedCustomersByEmployeeIdRequest({
    this.searchText,
    this.pageNumber = 0,
    this.pageSize = 0,
    this.sortOrder = 0,
    this.sortDir = 0,
    this.sortField,
    this.employeeId,
    this.clusterId,
    this.customerId,
    this.month,
    this.tourPlanId,
    this.userId,
    this.bizunit,
    this.filterExpression,
    this.monthNumber,
    this.year,
    this.id,
    this.action,
    this.comment,
    this.status,
    this.tourPlanAcceptId,
    this.remarks,
    this.clusterIds,
    this.selectedEmployeeId,
    this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'SearchText': searchText,
      'PageNumber': pageNumber,
      'PageSize': pageSize,
      'SortOrder': sortOrder,
      'SortDir': sortDir,
      'SortField': sortField,
      'EmployeeId': employeeId,
      'ClusterId': clusterId,
      'CustomerId': customerId,
      'Month': month,
      'TourPlanId': tourPlanId,
      'UserId': userId,
      'Bizunit': bizunit,
      'FilterExpression': filterExpression,
      'MonthNumber': monthNumber,
      'Year': year,
      'Id': id,
      'Action': action,
      'Comment': comment,
      'Status': status,
      'TourPlanAcceptId': tourPlanAcceptId,
      'Remarks': remarks,
      'ClusterIds': clusterIds?.map((e) => e.toJson()).toList(),
      'SelectedEmployeeId': selectedEmployeeId,
      'Date': date,
    };
  }
}

// Mapped Customer Model
class MappedCustomer {
  final int customerId;
  final String customerName;
  final int clusterId;
  final String clusterName;
  final int employeeId;
  final String employeeName;
  final bool isActive;
  final DateTime? lastVisitDate;
  final String? territory;
  final String? address;
  final String? contactNumber;
  final String? email;

  MappedCustomer({
    required this.customerId,
    required this.customerName,
    required this.clusterId,
    required this.clusterName,
    required this.employeeId,
    required this.employeeName,
    required this.isActive,
    this.lastVisitDate,
    this.territory,
    this.address,
    this.contactNumber,
    this.email,
  });

  factory MappedCustomer.fromJson(Map<String, dynamic> json) {
    return MappedCustomer(
      // Use API "id" strictly as the identifier
      customerId: json['id'] ?? json['CustomerId'] ?? json['customerId'] ?? 0,
      // Use API "text" strictly as the display name
      customerName: json['text'] ?? '',
      clusterId: json['clusterId'] ?? json['ClusterId'] ?? 0,
      clusterName: json['clusterName'] ?? json['ClusterName'] ?? '',
      employeeId: json['employeeId'] ?? json['EmployeeId'] ?? 0,
      employeeName: json['employeeName'] ?? json['EmployeeName'] ?? '',
      isActive: json['isActive'] ?? json['IsActive'] ?? json['active'] ?? false,
      lastVisitDate: _parseDateTime(json['lastVisitDate'] ?? json['LastVisitDate']),
      territory: json['territory'] ?? json['Territory'],
      address: json['address'] ?? json['Address'],
      contactNumber: json['contactNumber'] ?? json['ContactNumber'] ?? json['phone'],
      email: json['email'] ?? json['Email'],
    );
  }

  static DateTime? _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return null;
    try {
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

// Get Mapped Customers Response Model
class GetMappedCustomersByEmployeeIdResponse {
  final List<MappedCustomer> customers;
  final int totalRecords;
  final int filteredRecords;
  final int pageNumber;
  final int pageSize;

  GetMappedCustomersByEmployeeIdResponse({
    required this.customers,
    required this.totalRecords,
    required this.filteredRecords,
    required this.pageNumber,
    required this.pageSize,
  });

  factory GetMappedCustomersByEmployeeIdResponse.fromJson(dynamic json) {
    // Handle case where API returns a List directly
    if (json is List) {
      return GetMappedCustomersByEmployeeIdResponse(
        customers: json.map((e) => MappedCustomer.fromJson(e)).toList(),
        totalRecords: json.length,
        filteredRecords: json.length,
        pageNumber: 0,
        pageSize: json.length,
      );
    }
    
    // Handle case where API returns a Map with wrapped data
    if (json is Map<String, dynamic>) {
      return GetMappedCustomersByEmployeeIdResponse(
        customers: (json['customers'] as List?)
            ?.map((e) => MappedCustomer.fromJson(e))
            .toList() ?? [],
        totalRecords: json['totalRecords'] ?? 0,
        filteredRecords: json['filteredRecords'] ?? 0,
        pageNumber: json['pageNumber'] ?? 0,
        pageSize: json['pageSize'] ?? 0,
      );
    }
    
    // Fallback for unexpected response format
    return GetMappedCustomersByEmployeeIdResponse(
      customers: [],
      totalRecords: 0,
      filteredRecords: 0,
      pageNumber: 0,
      pageSize: 0,
    );
  }
}

// Tour Plan Comment API Models

/// Request model for saving a tour plan comment
class TourPlanCommentSaveRequest {
  final int createdBy;
  final int tourPlanId;
  final String comment;
  final String commentDate;
  final int isSystemGenerated;
  final String? tourPlanType; // Optional field - not required by API
  final int userId;
  final int active;

  TourPlanCommentSaveRequest({
    required this.createdBy,
    required this.tourPlanId,
    required this.comment,
    required this.commentDate,
    required this.isSystemGenerated,
    this.tourPlanType, // Made optional
    required this.userId,
    required this.active,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'CreatedBy': createdBy,
      'TourPlanId': tourPlanId,
      'Comment': comment,
      'CommentDate': commentDate,
      'IsSystemGenerated': isSystemGenerated,
      'UserId': userId,
      'Active': active,
    };
    // Only include TourPlanType if provided (for backward compatibility)
    if (tourPlanType != null) {
      json['TourPlanType'] = tourPlanType;
    }
    return json;
  }
}

/// Response model for saving a tour plan comment
class TourPlanCommentSaveResponse {
  final int id;
  final int createdBy;
  final int status;
  final int sbuId;
  final int tourPlanId;
  final String comment;
  final DateTime commentDate;
  final int isSystemGenerated;
  final String tourPlanType;
  final int userId;
  final int active;
  final DateTime createdDate;
  final DateTime modifiedDate;
  final int modifiedBy;
  final bool isDeleted;
  final String userName;
  final String userRole;

  TourPlanCommentSaveResponse({
    required this.id,
    required this.createdBy,
    required this.status,
    required this.sbuId,
    required this.tourPlanId,
    required this.comment,
    required this.commentDate,
    required this.isSystemGenerated,
    required this.tourPlanType,
    required this.userId,
    required this.active,
    required this.createdDate,
    required this.modifiedDate,
    required this.modifiedBy,
    required this.isDeleted,
    required this.userName,
    required this.userRole,
  });

  factory TourPlanCommentSaveResponse.fromJson(Map<String, dynamic> json) {
    return TourPlanCommentSaveResponse(
      id: json['id'] ?? 0,
      createdBy: json['createdBy'] ?? 0,
      status: json['status'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      tourPlanId: json['tourPlanId'] ?? 0,
      comment: json['comment'] ?? '',
      commentDate: DateTime.parse(json['commentDate'] ?? DateTime.now().toIso8601String()),
      isSystemGenerated: json['isSystemGenerated'] ?? 0,
      tourPlanType: json['tourPlanType'] ?? '',
      userId: json['userId'] ?? 0,
      active: json['active'] ?? 0,
      createdDate: DateTime.parse(json['createdDate'] ?? DateTime.now().toIso8601String()),
      modifiedDate: DateTime.parse(json['modifiedDate'] ?? DateTime.now().toIso8601String()),
      modifiedBy: json['modifiedBy'] ?? 0,
      isDeleted: json['isDeleted'] ?? false,
      userName: json['userName'] ?? '',
      userRole: json['userRole'] ?? '',
    );
  }
}

/// Request model for getting tour plan comments list
class TourPlanCommentGetListRequest {
  final int id;

  TourPlanCommentGetListRequest({
    required this.id,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}

/// Model for individual tour plan comment
class TourPlanCommentItem {
  final int id;
  final int tourPlanId;
  final int? dcrId;
  final int? deviationId;
  final String? tourPlanType;
  final String comment;
  final int isSystemGenerated;
  final int userId;
  final String userName;
  final DateTime commentDate;
  final int? bizUnit;
  final DateTime createdDate;
  final DateTime modifiedDate;

  TourPlanCommentItem({
    required this.id,
    required this.tourPlanId,
    this.dcrId,
    this.deviationId,
    this.tourPlanType,
    required this.comment,
    required this.isSystemGenerated,
    required this.userId,
    required this.userName,
    required this.commentDate,
    this.bizUnit,
    required this.createdDate,
    required this.modifiedDate,
  });

  factory TourPlanCommentItem.fromJson(Map<String, dynamic> json) {
    // Helper function to parse date strings that may or may not have Z suffix
    DateTime parseDate(String? dateString) {
      if (dateString == null || dateString.isEmpty) {
        return DateTime.now();
      }
      try {
        // Try parsing as-is first
        return DateTime.parse(dateString);
      } catch (e) {
        // If parsing fails, try adding Z if it's missing
        try {
          if (!dateString.endsWith('Z') && !dateString.contains('+') && !dateString.contains('-', 10)) {
            return DateTime.parse('${dateString}Z');
          }
          return DateTime.parse(dateString);
        } catch (e2) {
          print('TourPlanCommentItem: Error parsing date "$dateString": $e2');
          return DateTime.now();
        }
      }
    }

    return TourPlanCommentItem(
      id: json['id'] ?? 0,
      tourPlanId: json['tourPlanId'] ?? 0,
      dcrId: json['dcrId'],
      deviationId: json['deviationId'],
      tourPlanType: json['tourPlanType'],
      comment: json['comment'] ?? '',
      isSystemGenerated: json['isSystemGenerated'] ?? 0,
      userId: json['userId'] ?? 0,
      userName: json['userName'] ?? '',
      commentDate: parseDate(json['commentDate']),
      bizUnit: json['bizUnit'],
      createdDate: parseDate(json['createdDate']),
      modifiedDate: parseDate(json['modifiedDate']),
    );
  }
}

