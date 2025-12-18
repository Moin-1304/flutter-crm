class DcrListRequest {
  // Full payload fields (server expects PascalCase keys)
  final String? searchText;
  final int pageNumber;
  final int pageSize;
  final int sortOrder; // 0 default
  final int sortDir; // 0 default
  final String? sortField;
  final String? fromDate; // ISO yyyy-MM-dd or null
  final String? toDate;   // ISO yyyy-MM-dd or null
  final int userId;
  final int bizunit;
  final int? status; // Optional server-side status filter
  final String? filterExpression;
  final String transactionType; // "" default
  final int? id;
  final int? dcrId;
  final String? dateOfExpense;
  final int employeeId;
  final int? cityId;
  final int? expenceType; // server field name is ExpenceType
  final double? expenseAmount;
  final String? remarks;
  final String dcrDate; // ISO yyyy-MM-dd
  final int managerId; // 0 default

  DcrListRequest({
    this.searchText,
    required this.pageNumber,
    required this.pageSize,
    this.sortOrder = 0,
    this.sortDir = 0,
    this.sortField,
    this.fromDate,
    this.toDate,
    required this.userId,
    required this.bizunit,
    this.status,
    this.filterExpression,
    this.transactionType = '',
    this.id,
    this.dcrId,
    this.dateOfExpense,
    required this.employeeId,
    this.cityId,
    this.expenceType,
    this.expenseAmount,
    this.remarks,
    required this.dcrDate,
    this.managerId = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'SearchText': searchText,
      'PageNumber': pageNumber,
      'PageSize': pageSize,
      'SortOrder': sortOrder,
      'SortDir': sortDir,
      'SortField': sortField,
      'FromDate': fromDate,
      'ToDate': toDate,
      'UserId': userId,
      'Bizunit': bizunit,
      'Status': status,
      'FilterExpression': filterExpression,
      'TransactionType': transactionType,
      'Id': id,
      'DCRId': dcrId,
      'DateOfExpense': dateOfExpense,
      'EmployeeId': employeeId,
      'CityId': cityId,
      'ExpenceType': expenceType,
      'ExpenseAmount': expenseAmount,
      'Remarks': remarks,
      'DCRDate': dcrDate,
      'ManagerId': managerId,
    };
  }
}

class DcrListResponse {
  final List<DcrApiItem> items;
  final int totalRecords;
  final int filteredRecords;

  DcrListResponse({
    required this.items,
    required this.totalRecords,
    required this.filteredRecords,
  });

  factory DcrListResponse.fromJson(Map<String, dynamic> json) {
    return DcrListResponse(
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => DcrApiItem.fromJson(item))
          .toList() ?? [],
      totalRecords: json['totalRecords'] ?? 0,
      filteredRecords: json['filteredRecords'] ?? 0,
    );
  }
}

class DcrApiItem {
  final int id;
  final int cityId;
  final int createdBy;
  final int status;
  final int sbuId;
  final int dcrStatusId;
  final int dcrId;
  final int tourPlanId;
  final int employeeId;
  final String dcrDate;
  final bool isDeviationRequested;
  final bool isBasedOnPlan;
  final int deviatedFrom;
  final String remarks;
  final bool active;
  final int userId;
  final List<TourPlanDcrDetail> tourPlanDCRDetails;
  final String employeeName;
  final String designation;
  final String clusterNames;
  final String statusText;
  final String typeOfWork;
  final String customerName;
  final List<ExpenseApiItem> expenses;
  final int customerId;
  final String samplesToDistribute;
  final String productsToDiscuss;
  final String transactionType;
  final int typeOfWorkId;
  final int isGeneric;
  final double? customerLatitude;
  final double? customerLongitude;

  DcrApiItem({
    required this.id,
    required this.cityId,
    required this.createdBy,
    required this.status,
    required this.sbuId,
    required this.dcrStatusId,
    required this.dcrId,
    required this.tourPlanId,
    required this.employeeId,
    required this.dcrDate,
    required this.isDeviationRequested,
    required this.isBasedOnPlan,
    required this.deviatedFrom,
    required this.remarks,
    required this.active,
    required this.userId,
    required this.tourPlanDCRDetails,
    required this.employeeName,
    required this.designation,
    required this.clusterNames,
    required this.statusText,
    required this.typeOfWork,
    required this.customerName,
    required this.expenses,
    required this.customerId,
    required this.samplesToDistribute,
    required this.productsToDiscuss,
    required this.transactionType,
    required this.typeOfWorkId,
    required this.isGeneric,
    this.customerLatitude,
    this.customerLongitude,
  });

  factory DcrApiItem.fromJson(Map<String, dynamic> json) {
    return DcrApiItem(
      id: json['id'] ?? 0,
      cityId: json['cityId'] ?? 0,
      createdBy: json['createdBy'] ?? 0,
      status: json['status'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      dcrStatusId: json['dcrStatusId'] ?? 0,
      dcrId: json['dcrId'] ?? 0,
      tourPlanId: json['tourPlanId'] ?? 0,
      employeeId: json['employeeId'] ?? 0,
      dcrDate: json['dcrDate'] ?? '',
      isDeviationRequested: json['isDeviationRequested'] ?? false,
      isBasedOnPlan: json['isBasedOnPlan'] ?? false,
      deviatedFrom: json['deviatedFrom'] ?? 0,
      remarks: json['remarks'] ?? '',
      active: json['active'] ?? false,
      userId: json['userId'] ?? 0,
      tourPlanDCRDetails: (json['tourPlanDCRDetails'] as List<dynamic>?)
          ?.map((item) => TourPlanDcrDetail.fromJson(item))
          .toList() ?? [],
      employeeName: json['employeeName'] ?? '',
      designation: json['designation'] ?? '',
      clusterNames: json['clusterNames'] ?? '',
      statusText: json['statusText'] ?? '',
      typeOfWork: json['typeOfWork'] ?? '',
      customerName: json['customerName'] ?? '',
      expenses: (json['expenses'] as List<dynamic>?)
          ?.map((item) => ExpenseApiItem.fromJson(item))
          .toList() ?? [],
      customerId: json['customerId'] ?? 0,
      samplesToDistribute: json['samplesToDistribute'] ?? '',
      productsToDiscuss: json['productsToDiscuss'] ?? '',
      transactionType: json['transactionType'] ?? '',
      typeOfWorkId: json['typeOfWorkId'] ?? 0,
      isGeneric: json['isGeneric'] ?? 0,
      customerLatitude: (json['customerLatitude'] == null) ? null : (json['customerLatitude'] as num).toDouble(),
      customerLongitude: (json['customerLongitude'] == null) ? null : (json['customerLongitude'] as num).toDouble(),
    );
  }
}

class TourPlanDcrDetail {
  final int id;
  final String planDate;
  final int typeOfWorkId;
  final int cityId;
  final int clusterId;
  final int customerId;
  final int statusId;
  final String remarks;
  final String customerFeedback;
  final bool isDeviationRequested;
  final String reasonForDeviation;
  final int deviationStatus;
  final String comments;
  final int deviatedFrom;
  final int isBasedOnPlan;
  final int tourPlanDetailId;
  final bool isJoinVisit;
  final int joinVisitWithEmployeeId;
  final String joinVisitWithEmployeeName;
  final String location;
  final double latitude;
  final double longitude;
  final int bizunit;
  final String samplesToDistribute;
  final String productsToDiscuss;
  final int createdBy;
  final int status;
  final int sbuId;
  final int tourPlanId;
  final int employeeId;
  final String dcrDate;
  final bool active;
  final int userId;
  final String territory;
  final String cluster;
  final String dcrType;
  final String dcrStatus;
  final List<CallApiItem> calls;
  final List<ExpenseApiItem> expenses;
  final String createdAt;
  final String updatedAt;
  final String clusterNames;
  final String customerName;
  final String visitTime;
  final double visitDuration;

  TourPlanDcrDetail({
    required this.id,
    required this.planDate,
    required this.typeOfWorkId,
    required this.cityId,
    required this.clusterId,
    required this.customerId,
    required this.statusId,
    required this.remarks,
    required this.customerFeedback,
    required this.isDeviationRequested,
    required this.reasonForDeviation,
    required this.deviationStatus,
    required this.comments,
    required this.deviatedFrom,
    required this.isBasedOnPlan,
    required this.tourPlanDetailId,
    required this.isJoinVisit,
    required this.joinVisitWithEmployeeId,
    required this.joinVisitWithEmployeeName,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.bizunit,
    required this.samplesToDistribute,
    required this.productsToDiscuss,
    required this.createdBy,
    required this.status,
    required this.sbuId,
    required this.tourPlanId,
    required this.employeeId,
    required this.dcrDate,
    required this.active,
    required this.userId,
    required this.territory,
    required this.cluster,
    required this.dcrType,
    required this.dcrStatus,
    required this.calls,
    required this.expenses,
    required this.createdAt,
    required this.updatedAt,
    required this.clusterNames,
    required this.customerName,
    required this.visitTime,
    required this.visitDuration,
  });

  factory TourPlanDcrDetail.fromJson(Map<String, dynamic> json) {
    return TourPlanDcrDetail(
      id: json['id'] ?? 0,
      planDate: json['planDate'] ?? '',
      typeOfWorkId: json['typeOfWorkId'] ?? 0,
      cityId: json['cityId'] ?? 0,
      clusterId: json['clusterId'] ?? 0,
      customerId: json['customerId'] ?? 0,
      statusId: json['statusId'] ?? 0,
      remarks: json['remarks'] ?? '',
      customerFeedback: json['customerFeedback'] ?? '',
      isDeviationRequested: json['isDeviationRequested'] ?? false,
      reasonForDeviation: json['reasonForDeviation'] ?? '',
      deviationStatus: json['deviationStatus'] ?? 0,
      comments: json['comments'] ?? '',
      deviatedFrom: json['deviatedFrom'] ?? 0,
      isBasedOnPlan: json['isBasedOnPlan'] ?? 0,
      tourPlanDetailId: json['tourPlanDetailId'] ?? 0,
      isJoinVisit: json['isJoinVisit'] ?? false,
      joinVisitWithEmployeeId: json['joinVisitWithEmployeeId'] ?? 0,
      joinVisitWithEmployeeName: json['joinVisitWithEmployeeName'] ?? '',
      location: json['location'] ?? '',
      latitude: (json['customerLatitude'] ?? json['latitude'] ?? 0).toDouble(),
      longitude: (json['customerLongitude'] ?? json['longitude'] ?? 0).toDouble(),
      bizunit: json['bizunit'] ?? 0,
      samplesToDistribute: json['samplesToDistribute'] ?? '',
      productsToDiscuss: json['productsToDiscuss'] ?? '',
      createdBy: json['createdBy'] ?? 0,
      status: json['status'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      tourPlanId: json['tourPlanId'] ?? 0,
      employeeId: json['employeeId'] ?? 0,
      dcrDate: json['dcrDate'] ?? '',
      active: json['active'] ?? false,
      userId: json['userId'] ?? 0,
      territory: json['territory'] ?? '',
      cluster: json['cluster'] ?? '',
      dcrType: json['dcrType'] ?? '',
      dcrStatus: json['dcrStatus'] ?? '',
      calls: (json['calls'] as List<dynamic>?)
          ?.map((item) => CallApiItem.fromJson(item))
          .toList() ?? [],
      expenses: (json['expenses'] as List<dynamic>?)
          ?.map((item) => ExpenseApiItem.fromJson(item))
          .toList() ?? [],
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      clusterNames: json['clusterNames'] ?? '',
      customerName: json['customerName'] ?? '',
      visitTime: json['visitTime'] ?? '',
      visitDuration: (json['visitDuration'] ?? 0).toDouble(),
    );
  }
}

class CallApiItem {
  final int id;
  final String planDate;
  final int typeOfWorkId;
  final int cityId;
  final int clusterId;
  final int customerId;
  final int statusId;
  final String remarks;
  final String customerFeedback;
  final bool isDeviationRequested;
  final String reasonForDeviation;
  final int deviationStatus;
  final String comments;
  final int deviatedFrom;
  final int isBasedOnPlan;
  final int tourPlanDetailId;
  final bool isJoinVisit;
  final int joinVisitWithEmployeeId;
  final String joinVisitWithEmployeeName;
  final String location;
  final double latitude;
  final double longitude;
  final int bizunit;
  final String samplesToDistribute;
  final String productsToDiscuss;
  final String customerName;
  final String startTime;
  final String endTime;
  final String purpose;
  final String outcome;
  final String nextAction;
  final String callType;
  final String callStatus;
  final String notes;
  final String clusterNames;

  CallApiItem({
    required this.id,
    required this.planDate,
    required this.typeOfWorkId,
    required this.cityId,
    required this.clusterId,
    required this.customerId,
    required this.statusId,
    required this.remarks,
    required this.customerFeedback,
    required this.isDeviationRequested,
    required this.reasonForDeviation,
    required this.deviationStatus,
    required this.comments,
    required this.deviatedFrom,
    required this.isBasedOnPlan,
    required this.tourPlanDetailId,
    required this.isJoinVisit,
    required this.joinVisitWithEmployeeId,
    required this.joinVisitWithEmployeeName,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.bizunit,
    required this.samplesToDistribute,
    required this.productsToDiscuss,
    required this.customerName,
    required this.startTime,
    required this.endTime,
    required this.purpose,
    required this.outcome,
    required this.nextAction,
    required this.callType,
    required this.callStatus,
    required this.notes,
    required this.clusterNames,
  });

  factory CallApiItem.fromJson(Map<String, dynamic> json) {
    return CallApiItem(
      id: json['id'] ?? 0,
      planDate: json['planDate'] ?? '',
      typeOfWorkId: json['typeOfWorkId'] ?? 0,
      cityId: json['cityId'] ?? 0,
      clusterId: json['clusterId'] ?? 0,
      customerId: json['customerId'] ?? 0,
      statusId: json['statusId'] ?? 0,
      remarks: json['remarks'] ?? '',
      customerFeedback: json['customerFeedback'] ?? '',
      isDeviationRequested: json['isDeviationRequested'] ?? false,
      reasonForDeviation: json['reasonForDeviation'] ?? '',
      deviationStatus: json['deviationStatus'] ?? 0,
      comments: json['comments'] ?? '',
      deviatedFrom: json['deviatedFrom'] ?? 0,
      isBasedOnPlan: json['isBasedOnPlan'] ?? 0,
      tourPlanDetailId: json['tourPlanDetailId'] ?? 0,
      isJoinVisit: json['isJoinVisit'] ?? false,
      joinVisitWithEmployeeId: json['joinVisitWithEmployeeId'] ?? 0,
      joinVisitWithEmployeeName: json['joinVisitWithEmployeeName'] ?? '',
      location: json['location'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      bizunit: json['bizunit'] ?? 0,
      samplesToDistribute: json['samplesToDistribute'] ?? '',
      productsToDiscuss: json['productsToDiscuss'] ?? '',
      customerName: json['customerName'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      purpose: json['purpose'] ?? '',
      outcome: json['outcome'] ?? '',
      nextAction: json['nextAction'] ?? '',
      callType: json['callType'] ?? '',
      callStatus: json['callStatus'] ?? '',
      notes: json['notes'] ?? '',
      clusterNames: json['clusterNames'] ?? '',
    );
  }
}

class ExpenseApiItem {
  final int id;
  final int dcrId;
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
  final List<AttachmentApiItem> attachments;

  ExpenseApiItem({
    required this.id,
    required this.dcrId,
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
    required this.attachments,
  });

  factory ExpenseApiItem.fromJson(Map<String, dynamic> json) {
    return ExpenseApiItem(
      id: json['id'] ?? 0,
      dcrId: json['dcrId'] ?? 0,
      dateOfExpense: json['dateOfExpense'] ?? '',
      employeeId: json['employeeId'] ?? 0,
      cityId: json['cityId'] ?? 0,
      clusterId: json['clusterId'],
      bizUnit: json['bizUnit'] ?? 0,
      expenceType: json['expenceType'] ?? 0,
      expenseAmount: (json['expenseAmount'] ?? 0).toDouble(),
      remarks: json['remarks'] ?? '',
      userId: json['userId'] ?? 0,
      dcrStatus: json['dcrStatus'] ?? '',
      dcrStatusId: json['dcrStatusId'] ?? 0,
      clusterNames: json['clusterNames'],
      isGeneric: json['isGeneric'] ?? 0,
      employeeName: json['employeeName'],
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((item) => AttachmentApiItem.fromJson(item))
          .toList() ?? [],
    );
  }
}

class AttachmentApiItem {
  final String fileName;
  final String fileType;
  final String filePath;
  final String type;

  AttachmentApiItem({
    required this.fileName,
    required this.fileType,
    required this.filePath,
    required this.type,
  });

  factory AttachmentApiItem.fromJson(Map<String, dynamic> json) {
    return AttachmentApiItem(
      fileName: json['fileName'] ?? json['FileName'] ?? '',
      fileType: json['fileType'] ?? json['FileType'] ?? '',
      filePath: json['filePath'] ?? json['FilePath'] ?? '',
      type: json['type'] ?? json['Type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'FileName': fileName,
      'FileType': fileType,
      'FilePath': filePath,
      'Type': type,
    };
  }
}

// DCR Save API Models
class DcrSaveRequest {
  // Root payload fields (nullable/defaults allowed to match API contract)
  final int? id;
  final int? cityId;
  final int? createdBy;
  final int status;
  final int sbuId;
  final int dcrStatusId;
  final int? dcrId;
  final int tourPlanId;
  final int employeeId;
  final String dcrDate;
  final bool isDeviationRequested;
  final bool isBasedOnPlan;
  final int? deviatedFrom;
  final String? remarks;
  final bool active;
  final int userId;
  final List<TourPlanDcrDetailSave> tourPlanDCRDetails;
  final String employeeName;
  final String? designation;
  final String? clusterNames;
  final String? statusText;
  final String? typeOfWork;
  final String? customerName;
  final List<dynamic> expenses; // keep dynamic per server contract
  final int? customerId;
  final String? samplesToDistribute;
  final String? productsToDiscuss;
  final String? transactionType;
  final int? typeOfWorkId;
  final int? isGeneric;

  DcrSaveRequest({
    this.id,
    this.cityId,
    this.createdBy,
    this.status = 0,
    this.sbuId = 0,
    required this.dcrStatusId,
    this.dcrId,
    this.tourPlanId = 0,
    required this.employeeId,
    required this.dcrDate,
    this.isDeviationRequested = false,
    this.isBasedOnPlan = false,
    this.deviatedFrom,
    this.remarks,
    this.active = true,
    required this.userId,
    required this.tourPlanDCRDetails,
    required this.employeeName,
    this.designation,
    this.clusterNames,
    this.statusText,
    this.typeOfWork,
    this.customerName,
    List<dynamic>? expenses,
    this.customerId,
    this.samplesToDistribute,
    this.productsToDiscuss,
    this.transactionType,
    this.typeOfWorkId,
    this.isGeneric,
  }) : expenses = expenses ?? const [];

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'CityId': cityId,
      'CreatedBy': createdBy,
      'Status': status,
      'SbuId': sbuId,
      'DCRStatusId': dcrStatusId,
      'DCRId': dcrId,
      'TourPlanId': tourPlanId,
      'EmployeeId': employeeId,
      'DCRDate': dcrDate,
      'IsDeviationRequested': isDeviationRequested,
      'IsBasedOnPlan': isBasedOnPlan,
      'DeviatedFrom': deviatedFrom,
      'Remarks': remarks,
      'Active': active,
      'UserId': userId,
      'TourPlanDCRDetails': tourPlanDCRDetails.map((detail) => detail.toJson()).toList(),
      'EmployeeName': employeeName,
      'Designation': designation,
      'ClusterNames': clusterNames,
      'StatusText': statusText,
      'TypeOfWork': typeOfWork,
      'CustomerName': customerName,
      'Expenses': expenses,
      'CustomerId': customerId,
      'SamplesToDistribute': samplesToDistribute,
      'ProductsToDiscuss': productsToDiscuss,
      'TransactionType': transactionType,
      'TypeOfWorkId': typeOfWorkId,
      'IsGeneric': isGeneric,
    };
  }
}

class DcrUpdateRequest {
  // Use the same structure as DcrSaveRequest for consistency with server expectations
  final int? id;
  final int? cityId;
  final int? createdBy;
  final int status;
  final int sbuId;
  final int dcrStatusId;
  final int? dcrId;
  final int tourPlanId;
  final int employeeId;
  final String dcrDate;
  final bool? isDeviationRequested;
  final bool isBasedOnPlan;
  final int? deviatedFrom;
  final String? remarks;
  final bool active;
  final int userId;
  final List<TourPlanDcrDetailSave> tourPlanDCRDetails;
  final String employeeName;
  final String? designation;
  final String? clusterNames;
  final String? statusText;
  final String? typeOfWork;
  final String? customerName;
  final List<dynamic> expenses;
  final int? customerId;
  final String? samplesToDistribute;
  final String? productsToDiscuss;
  final String? transactionType;
  final int? typeOfWorkId;
  final int? isGeneric;

  DcrUpdateRequest({
    this.id,
    this.cityId,
    this.createdBy,
    this.status = 0,
    this.sbuId = 0,
    required this.dcrStatusId,
    this.dcrId,
    this.tourPlanId = 0,
    required this.employeeId,
    required this.dcrDate,
    this.isDeviationRequested,
    this.isBasedOnPlan = false,
    this.deviatedFrom,
    this.remarks,
    this.active = true,
    required this.userId,
    required this.tourPlanDCRDetails,
    required this.employeeName,
    this.designation,
    this.clusterNames,
    this.statusText,
    this.typeOfWork,
    this.customerName,
    this.expenses = const [],
    this.customerId,
    this.samplesToDistribute,
    this.productsToDiscuss,
    this.transactionType,
    this.typeOfWorkId,
    this.isGeneric,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'CityId': cityId,
      'CreatedBy': createdBy,
      'Status': status,
      'SbuId': sbuId,
      'DCRStatusId': dcrStatusId,
      'DCRId': dcrId,
      'TourPlanId': tourPlanId,
      'EmployeeId': employeeId,
      'DCRDate': dcrDate,
      'IsDeviationRequested': isDeviationRequested,
      'IsBasedOnPlan': isBasedOnPlan,
      'DeviatedFrom': deviatedFrom,
      'CustomerLatitude': null, // Always null at root level
      'CustomerLongitude': null, // Always null at root level
      'Remarks': remarks,
      'Active': active,
      'UserId': userId,
      'TourPlanDCRDetails': tourPlanDCRDetails.map((e) => e.toJson()).toList(),
      'EmployeeName': employeeName,
      'Designation': designation,
      'ClusterNames': clusterNames,
      'StatusText': statusText,
      'TypeOfWork': typeOfWork,
      'CustomerName': customerName,
      'Expenses': expenses,
      'CustomerId': customerId,
      'SamplesToDistribute': samplesToDistribute,
      'ProductsToDiscuss': productsToDiscuss,
      'TransactionType': transactionType,
      'TypeOfWorkId': typeOfWorkId,
      'IsGeneric': isGeneric,
    };
  }
}

class TourPlanDcrDetailSave {
  // Required
  final String planDate;
  final int typeOfWorkId;
  final int cityId;
  final int customerId;
  final int statusId;
  final String remarks;
  final int isBasedOnPlan; // API expects 1/0 here
  final int bizunit;
  final String samplesToDistribute;
  final String productsToDiscuss;
  final String customerName;
  final String visitTime;
  final double visitDuration;

  // Optional/nullable fields to mirror server contract
  final int? id;
  final int? clusterId;
  final String? customerFeedback;
  final bool? isDeviationRequested;
  final String? reasonForDeviation;
  final int? deviationStatus;
  final String? comments;
  final int? deviatedFrom;
  final int? tourPlanDetailId;
  final bool? isJoinVisit;
  final int? joinVisitWithEmployeeId;
  final String? joinVisitWithEmployeeName;
  final String? location;
  final double? latitude;
  final double? longitude;
  final int? createdBy;
  final int? status;
  final int? sbuId;
  final int? tourPlanId;
  final int? employeeId;
  final String? dcrDate;
  final bool? active;
  final int? userId;
  final String? territory;
  final String? cluster;
  final String? dcrType;
  final String? dcrStatus;
  final dynamic calls; // keep dynamic per backend: can be null or list
  final dynamic expenses; // keep dynamic per backend: can be null or list
  final String? createdAt;
  final String? updatedAt;
  final String? clusterNames;

  TourPlanDcrDetailSave({
    required this.planDate,
    required this.typeOfWorkId,
    required this.cityId,
    required this.customerId,
    required this.statusId,
    required this.remarks,
    required this.isBasedOnPlan,
    required this.bizunit,
    required this.samplesToDistribute,
    required this.productsToDiscuss,
    required this.customerName,
    required this.visitTime,
    required this.visitDuration,
    this.id,
    this.clusterId,
    this.customerFeedback,
    this.isDeviationRequested,
    this.reasonForDeviation,
    this.deviationStatus,
    this.comments,
    this.deviatedFrom,
    this.tourPlanDetailId,
    this.isJoinVisit,
    this.joinVisitWithEmployeeId,
    this.joinVisitWithEmployeeName,
    this.location,
    this.latitude,
    this.longitude,
    this.createdBy,
    this.status,
    this.sbuId,
    this.tourPlanId,
    this.employeeId,
    this.dcrDate,
    this.active,
    this.userId,
    this.territory,
    this.cluster,
    this.dcrType,
    this.dcrStatus,
    this.calls,
    this.expenses,
    this.createdAt,
    this.updatedAt,
    this.clusterNames,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'PlanDate': planDate,
      'TypeOfWorkId': typeOfWorkId,
      'CityId': cityId,
      'ClusterId': clusterId,
      'CustomerId': customerId,
      'StatusId': statusId,
      'Remarks': remarks,
      'CustomerFeedback': customerFeedback,
      'IsDeviationRequested': isDeviationRequested ?? false,
      'ReasonForDeviation': reasonForDeviation,
      'DeviationStatus': deviationStatus,
      'Comments': comments,
      'DeviatedFrom': deviatedFrom,
      'IsBasedOnPlan': isBasedOnPlan,
      'TourPlanDetailId': tourPlanDetailId,
      'IsJoinVisit': isJoinVisit,
      'JoinVisitWithEmployeeId': joinVisitWithEmployeeId,
      'JoinVisitWithEmployeeName': joinVisitWithEmployeeName,
      'Location': location,
      'Latitude': latitude,
      'Longitude': longitude,
      'Bizunit': 1, // Always 1 as per requirement
      'SamplesToDistribute': samplesToDistribute,
      'ProductsToDiscuss': productsToDiscuss,
      'CustomerLatitude': latitude, // Map latitude to CustomerLatitude
      'CustomerLongitude': longitude, // Map longitude to CustomerLongitude
      'CreatedBy': createdBy,
      'Status': status,
      'SbuId': sbuId,
      'TourPlanId': tourPlanId,
      'EmployeeId': employeeId,
      'DCRDate': dcrDate,
      'Active': active,
      'UserId': userId,
      'Territory': territory,
      'Cluster': cluster,
      'DCRType': dcrType,
      'DCRStatus': dcrStatus,
      'Calls': calls,
      'Expenses': expenses,
      'CreatedAt': createdAt,
      'UpdatedAt': updatedAt,
      'ClusterNames': clusterNames,
      'CustomerName': customerName,
      'VisitTime': visitTime,
      'VisitDuration': visitDuration,
    };
  }
}

class DcrSaveResponse {
  final bool success;
  final String message;

  DcrSaveResponse({
    required this.success,
    required this.message,
  });

  factory DcrSaveResponse.fromJson(Map<String, dynamic> json) {
    final bool derivedSuccess =
        (json['success'] == true) ||
        (json['status'] == true) ||
        json.containsKey('DCRStatusId') ||
        json.containsKey('dcrStatusId') ||
        json.containsKey('EmployeeId') ||
        json.containsKey('employeeId');

    final String derivedMessage =
        (json['message'] ?? json['msg'] ?? 'OK').toString();

    return DcrSaveResponse(
      success: derivedSuccess,
      message: derivedMessage,
    );
  }
}

// DCR Get API Models
class DcrGetRequest {
  final int id;
  final int dcrId;

  DcrGetRequest({
    required this.id,
    required this.dcrId,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'DCRId': dcrId,
    };
  }
}

class DcrGetResponse {
  final int id;
  final int cityId;
  final int createdBy;
  final int status;
  final int sbuId;
  final int dcrStatusId;
  final int dcrId;
  final int tourPlanId;
  final int employeeId;
  final String dcrDate;
  final bool isDeviationRequested;
  final bool isBasedOnPlan;
  final int deviatedFrom;
  final String remarks;
  final bool active;
  final int userId;
  final List<TourPlanDcrDetailGet> tourPlanDCRDetails;
  final String employeeName;
  final String designation;
  final String clusterNames;
  final String statusText;
  final String typeOfWork;
  final String customerName;
  final List<ExpenseApiItem> expenses;
  final int customerId;
  final String samplesToDistribute;
  final String productsToDiscuss;
  final String transactionType;
  final int typeOfWorkId;
  final int isGeneric;

  DcrGetResponse({
    required this.id,
    required this.cityId,
    required this.createdBy,
    required this.status,
    required this.sbuId,
    required this.dcrStatusId,
    required this.dcrId,
    required this.tourPlanId,
    required this.employeeId,
    required this.dcrDate,
    required this.isDeviationRequested,
    required this.isBasedOnPlan,
    required this.deviatedFrom,
    required this.remarks,
    required this.active,
    required this.userId,
    required this.tourPlanDCRDetails,
    required this.employeeName,
    required this.designation,
    required this.clusterNames,
    required this.statusText,
    required this.typeOfWork,
    required this.customerName,
    required this.expenses,
    required this.customerId,
    required this.samplesToDistribute,
    required this.productsToDiscuss,
    required this.transactionType,
    required this.typeOfWorkId,
    required this.isGeneric,
  });

  factory DcrGetResponse.fromJson(Map<String, dynamic> json) {
    return DcrGetResponse(
      id: json['id'] ?? 0,
      cityId: json['cityId'] ?? 0,
      createdBy: json['createdBy'] ?? 0,
      status: json['status'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      dcrStatusId: json['dcrStatusId'] ?? 0,
      dcrId: json['dcrId'] ?? 0,
      tourPlanId: json['tourPlanId'] ?? 0,
      employeeId: json['employeeId'] ?? 0,
      dcrDate: json['dcrDate'] ?? '',
      isDeviationRequested: json['isDeviationRequested'] ?? false,
      isBasedOnPlan: json['isBasedOnPlan'] ?? false,
      deviatedFrom: json['deviatedFrom'] ?? 0,
      remarks: json['remarks'] ?? '',
      active: json['active'] ?? false,
      userId: json['userId'] ?? 0,
      tourPlanDCRDetails: (json['tourPlanDCRDetails'] as List<dynamic>?)
          ?.map((item) => TourPlanDcrDetailGet.fromJson(item))
          .toList() ?? [],
      employeeName: json['employeeName'] ?? '',
      designation: json['designation'] ?? '',
      clusterNames: json['clusterNames'] ?? '',
      statusText: json['statusText'] ?? '',
      typeOfWork: json['typeOfWork'] ?? '',
      customerName: json['customerName'] ?? '',
      expenses: (json['expenses'] as List<dynamic>?)
          ?.map((item) => ExpenseApiItem.fromJson(item))
          .toList() ?? [],
      customerId: json['customerId'] ?? 0,
      samplesToDistribute: json['samplesToDistribute'] ?? '',
      productsToDiscuss: json['productsToDiscuss'] ?? '',
      transactionType: json['transactionType'] ?? '',
      typeOfWorkId: json['typeOfWorkId'] ?? 0,
      isGeneric: json['isGeneric'] ?? 0,
    );
  }
}

class TourPlanDcrDetailGet {
  final int? id;
  final String planDate;
  final int typeOfWorkId;
  final int cityId;
  final int clusterId;
  final int customerId;
  final int statusId;
  final String remarks;
  final String customerFeedback;
  final bool isDeviationRequested;
  final String reasonForDeviation;
  final int deviationStatus;
  final String comments;
  final int deviatedFrom;
  final int isBasedOnPlan;
  final int tourPlanDetailId;
  final bool isJoinVisit;
  final int joinVisitWithEmployeeId;
  final String joinVisitWithEmployeeName;
  final String location;
  final double latitude;
  final double longitude;
  final int bizunit;
  final String samplesToDistribute;
  final String productsToDiscuss;
  final int createdBy;
  final int status;
  final int sbuId;
  final int tourPlanId;
  final int employeeId;
  final String dcrDate;
  final bool active;
  final int userId;
  final String territory;
  final String cluster;
  final String dcrType;
  final String dcrStatus;
  final List<CallApiItem> calls;
  final List<ExpenseApiItem> expenses;
  final String createdAt;
  final String updatedAt;
  final String clusterNames;
  final String customerName;
  final String visitTime;
  final double visitDuration;
  final double? customerLatitude;
  final double? customerLongitude;

  TourPlanDcrDetailGet({
    this.id,
    required this.planDate,
    required this.typeOfWorkId,
    required this.cityId,
    required this.clusterId,
    required this.customerId,
    required this.statusId,
    required this.remarks,
    required this.customerFeedback,
    required this.isDeviationRequested,
    required this.reasonForDeviation,
    required this.deviationStatus,
    required this.comments,
    required this.deviatedFrom,
    required this.isBasedOnPlan,
    required this.tourPlanDetailId,
    required this.isJoinVisit,
    required this.joinVisitWithEmployeeId,
    required this.joinVisitWithEmployeeName,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.bizunit,
    required this.samplesToDistribute,
    required this.productsToDiscuss,
    required this.createdBy,
    required this.status,
    required this.sbuId,
    required this.tourPlanId,
    required this.employeeId,
    required this.dcrDate,
    required this.active,
    required this.userId,
    required this.territory,
    required this.cluster,
    required this.dcrType,
    required this.dcrStatus,
    required this.calls,
    required this.expenses,
    required this.createdAt,
    required this.updatedAt,
    required this.clusterNames,
    required this.customerName,
    required this.visitTime,
    required this.visitDuration,
    this.customerLatitude,
    this.customerLongitude,
  });

  factory TourPlanDcrDetailGet.fromJson(Map<String, dynamic> json) {
    // Parse id from either PascalCase or camelCase, handling both int and string
    int? parsedId;
    final idValue = json['Id'] ?? json['id'];
    if (idValue != null) {
      if (idValue is int) {
        parsedId = idValue;
      } else if (idValue is String && idValue.isNotEmpty) {
        parsedId = int.tryParse(idValue);
      }
    }
    
    return TourPlanDcrDetailGet(
      id: parsedId,
      planDate: json['planDate'] ?? '',
      typeOfWorkId: json['typeOfWorkId'] ?? 0,
      cityId: json['cityId'] ?? 0,
      clusterId: json['clusterId'] ?? 0,
      customerId: json['customerId'] ?? 0,
      statusId: json['statusId'] ?? 0,
      remarks: json['remarks'] ?? '',
      customerFeedback: json['customerFeedback'] ?? '',
      isDeviationRequested: json['isDeviationRequested'] ?? false,
      reasonForDeviation: json['reasonForDeviation'] ?? '',
      deviationStatus: json['deviationStatus'] ?? 0,
      comments: json['comments'] ?? '',
      deviatedFrom: json['deviatedFrom'] ?? 0,
      isBasedOnPlan: json['isBasedOnPlan'] ?? 0,
      tourPlanDetailId: json['tourPlanDetailId'] ?? 0,
      isJoinVisit: json['isJoinVisit'] ?? false,
      joinVisitWithEmployeeId: json['joinVisitWithEmployeeId'] ?? 0,
      joinVisitWithEmployeeName: json['joinVisitWithEmployeeName'] ?? '',
      location: json['location'] ?? '',
      latitude: (json['customerLatitude'] ?? json['latitude'] ?? 0).toDouble(),
      longitude: (json['customerLongitude'] ?? json['longitude'] ?? 0).toDouble(),
      bizunit: json['bizunit'] ?? 0,
      samplesToDistribute: json['samplesToDistribute'] ?? '',
      productsToDiscuss: json['productsToDiscuss'] ?? '',
      createdBy: json['createdBy'] ?? 0,
      status: json['status'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      tourPlanId: json['tourPlanId'] ?? 0,
      employeeId: json['employeeId'] ?? 0,
      dcrDate: json['dcrDate'] ?? '',
      active: json['active'] ?? false,
      userId: json['userId'] ?? 0,
      territory: json['territory'] ?? '',
      cluster: json['cluster'] ?? '',
      dcrType: json['dcrType'] ?? '',
      dcrStatus: json['dcrStatus'] ?? '',
      calls: (json['calls'] as List<dynamic>?)
          ?.map((item) => CallApiItem.fromJson(item))
          .toList() ?? [],
      expenses: (json['expenses'] as List<dynamic>?)
          ?.map((item) => ExpenseApiItem.fromJson(item))
          .toList() ?? [],
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      clusterNames: json['clusterNames'] ?? '',
      customerName: json['customerName'] ?? '',
      visitTime: json['visitTime'] ?? '',
      visitDuration: (json['visitDuration'] ?? 0).toDouble(),
      customerLatitude: (json['customerLatitude'] == null) ? null : (json['customerLatitude'] as num).toDouble(),
      customerLongitude: (json['customerLongitude'] == null) ? null : (json['customerLongitude'] as num).toDouble(),
    );
  }
}

