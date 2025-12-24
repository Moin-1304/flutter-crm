/// ItemIssue List API Models

class ItemIssueListRequest {
  final String? searchText;
  final int sortOrder;
  final int sortDir;
  final int pageNumber;
  final bool? active;
  final int menuId;
  final int pageSize;
  final String? fromDate; // ISO format: "2025-07-17T05:10:27.125"
  final String? toDate;
  final String? filterExpression;
  final int userId;
  final String? sortExpression;
  final String? sortField;
  final int? department;
  final int? status;
  final int bizUnit;
  final int? type;
  final int? toStore;
  final String? company;
  final bool? isWorkOrder;
  final String? no;
  final String url;
  final int? id;
  final int? processId;
  final int transactionType;
  final String? commandText;

  ItemIssueListRequest({
    this.searchText,
    this.sortOrder = 0,
    this.sortDir = 1,
    required this.pageNumber,
    this.active,
    required this.menuId,
    required this.pageSize,
    this.fromDate,
    this.toDate,
    this.filterExpression,
    required this.userId,
    this.sortExpression,
    this.sortField,
    this.department,
    this.status,
    required this.bizUnit,
    this.type,
    this.toStore,
    this.url = '/itemissue/list/{Type:int?}',
    this.id,
    this.processId,
    this.transactionType = 14,
    this.commandText,
    this.company,
    this.isWorkOrder,
    this.no,
  });

  Map<String, dynamic> toJson() {
    return {
      'SearchText': searchText,
      'SortOrder': sortOrder,
      'SortDir': sortDir,
      'PageNumber': pageNumber,
      'Active': active,
      'MenuId': menuId,
      'PageSize': pageSize,
      'FromDate': fromDate,
      'ToDate': toDate,
      'FilterExpression': filterExpression,
      'UserId': userId,
      'SortExpression': sortExpression,
      'SortField': sortField,
      'Department': department,
      'Status': status,
      'BizUnit': bizUnit,
      'Type': type,
      'ToStore': toStore,
      'Company': company,
      'IsWorkOrder': isWorkOrder,
      'No': no,
      'Url': url,
      'Id': id,
      'ProcessId': processId,
      'TransactionType': transactionType,
      'CommandText': commandText,
    };
  }
}

class ItemIssueListResponse {
  final List<ItemIssueApiItem> items;
  final int? totalRecords;
  final int? filteredRecords;

  ItemIssueListResponse({
    required this.items,
    this.totalRecords,
    this.filteredRecords,
  });

  factory ItemIssueListResponse.fromJson(Map<String, dynamic> json) {
    return ItemIssueListResponse(
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => ItemIssueApiItem.fromJson(item))
          .toList() ?? [],
      totalRecords: json['totalRecords'],
      filteredRecords: json['filteredRecords'],
    );
  }
}

class ItemIssueApiItem {
  final String createdDate;
  final int modifiedBy;
  final String? modifiedDate;
  final int id;
  final int? createdBy;
  final int status;
  final int sbuId;
  final String no;
  final String? version;
  final String date;
  final String? fromDate;
  final String? toDate;
  final int type;
  final int? totalQty;
  final String? remarks;
  final String? comments;
  final int department;
  final int toStore;
  final int? issueTo;
  final int? bizunit;
  final int? module;
  final String? company;
  final bool? isWorkOrder;
  final bool? isEdit;
  final bool? confirmStockValueChange;
  final String? astDocMode;
  final String? aptCode;
  final bool? isMultipleBatch;
  final String? multiBatchGroup;
  final int transactionType;
  final bool? isCancelled;
  final String? workflowProcess;
  final String? reference;
  final int workflowFlag;
  final int? processId;
  final int? processActionId;
  final String? workflowComment;
  final int workflowStatus;
  final String departmentText;
  final String toStoreText;
  final String? companyText;
  final String? typeText;
  final String statusText;
  final bool isSelected;
  final bool hasEdit;
  final String? edit;
  final String? action;
  final String? view;
  final String? delete;
  final List<dynamic>? details;
  final bool? dateRequired;
  final bool? departmentRequired;
  final bool? toStoreRequired;
  final bool? totalQtyNegative;
  final bool? detailsRequired;
  final int? refid;
  final int? menuId;
  final int? moduleId;
  final int? userId;
  final int? divisionGroup;
  final int? issueAgainst;
  final int? issueReceiptType;
  final String itemText;

  ItemIssueApiItem({
    required this.createdDate,
    required this.modifiedBy,
    this.modifiedDate,
    required this.id,
    this.createdBy,
    required this.status,
    required this.sbuId,
    required this.no,
    this.version,
    required this.date,
    this.fromDate,
    this.toDate,
    required this.type,
    this.totalQty,
    this.remarks,
    this.comments,
    required this.department,
    required this.toStore,
    this.issueTo,
    this.bizunit,
    this.module,
    this.company,
    this.isWorkOrder,
    this.isEdit,
    this.confirmStockValueChange,
    this.astDocMode,
    this.aptCode,
    this.isMultipleBatch,
    this.multiBatchGroup,
    required this.transactionType,
    this.isCancelled,
    this.workflowProcess,
    this.reference,
    required this.workflowFlag,
    this.processId,
    this.processActionId,
    this.workflowComment,
    required this.workflowStatus,
    required this.departmentText,
    required this.toStoreText,
    this.companyText,
    this.typeText,
    required this.statusText,
    required this.isSelected,
    required this.hasEdit,
    this.edit,
    this.action,
    this.view,
    this.delete,
    this.details,
    this.dateRequired,
    this.departmentRequired,
    this.toStoreRequired,
    this.totalQtyNegative,
    this.detailsRequired,
    this.refid,
    this.menuId,
    this.moduleId,
    this.userId,
    this.divisionGroup,
    this.issueAgainst,
    this.issueReceiptType,
    required this.itemText,
  });

  factory ItemIssueApiItem.fromJson(Map<String, dynamic> json) {
    return ItemIssueApiItem(
      createdDate: json['createdDate'] ?? '',
      modifiedBy: json['modifiedBy'] ?? 0,
      modifiedDate: json['modifiedDate'],
      id: json['id'] ?? 0,
      createdBy: json['createdBy'],
      status: json['status'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      no: json['no'] ?? '',
      version: json['version'],
      date: json['date'] ?? '',
      fromDate: json['fromDate'],
      toDate: json['toDate'],
      type: json['type'] ?? 0,
      totalQty: json['totalQty'],
      remarks: json['remarks'],
      comments: json['comments'],
      department: json['department'] ?? 0,
      toStore: json['toStore'] ?? 0,
      issueTo: json['issueTo'],
      bizunit: json['bizunit'],
      module: json['module'],
      company: json['company'],
      isWorkOrder: json['isWorkOrder'],
      isEdit: json['isEdit'],
      confirmStockValueChange: json['confirmStockValueChange'],
      astDocMode: json['astDocMode'],
      aptCode: json['aptCode'],
      isMultipleBatch: json['isMultipleBatch'],
      multiBatchGroup: json['multiBatchGroup'],
      transactionType: json['transactionType'] ?? 14,
      isCancelled: json['isCancelled'],
      workflowProcess: json['workflowProcess'],
      reference: json['reference'],
      workflowFlag: json['workflowFlag'] ?? 0,
      processId: json['processId'],
      processActionId: json['processActionId'],
      workflowComment: json['workflowComment'],
      workflowStatus: json['workflowStatus'] ?? 0,
      departmentText: json['departmentText'] ?? '',
      toStoreText: json['toStoreText'] ?? '',
      companyText: json['companyText'],
      typeText: json['typeText'],
      statusText: json['statusText'] ?? '',
      isSelected: json['isSelected'] ?? false,
      hasEdit: json['hasEdit'] ?? false,
      edit: json['edit'],
      action: json['action'],
      view: json['view'],
      delete: json['delete'],
      details: json['details'],
      dateRequired: json['dateRequired'],
      departmentRequired: json['departmentRequired'],
      toStoreRequired: json['toStoreRequired'],
      totalQtyNegative: json['totalQtyNegative'],
      detailsRequired: json['detailsRequired'],
      refid: json['refid'],
      menuId: json['menuId'],
      moduleId: json['moduleId'],
      userId: json['userId'],
      divisionGroup: json['divisionGroup'],
      issueAgainst: json['issueAgainst'],
      issueReceiptType: json['issueReceiptType'],
      itemText: json['itemText'] ?? '',
    );
  }
}

