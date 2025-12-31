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
  final int? type;
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
    this.type,
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
      type: json['type'],
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
      isCancelled: json['isCancelled'] is bool 
          ? json['isCancelled'] 
          : (json['isCancelled'] == 1 || json['isCancelled'] == true),
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

/// ItemIssue Save API Models

class ItemIssueSaveRequest {
  final int? id;
  final int? createdBy;
  final int status;
  final int sbuId;
  final String no;
  final String? version;
  final String date;
  final String? fromDate;
  final String? toDate;
  final int? type;
  final double? totalQty;
  final String? remarks;
  final String? comments;
  final int department;
  final int toStore;
  final int issueTo;
  final int bizunit;
  final int? module;
  final int company;
  final int? modifiedBy;
  final String? modifiedDate;
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
  final String? departmentText;
  final String? toStoreText;
  final String? companyText;
  final String? typeText;
  final String? statusText;
  final bool isSelected;
  final bool hasEdit;
  final String? edit;
  final String? action;
  final String? view;
  final String? delete;
  final List<ItemIssueDetailSaveRequest> details;
  final String? dateRequired;
  final bool? departmentRequired;
  final bool? toStoreRequired;
  final bool? totalQtyNegative;
  final bool? detailsRequired;
  final int? refid;
  final int menuId;
  final int moduleId;
  final int userId;
  final int? divisionGroup;
  final String? issueAgainst; // Changed to String as API expects string
  final int issueReceiptType;
  final String? itemText;

  ItemIssueSaveRequest({
    this.id,
    this.createdBy,
    this.status = 0,
    this.sbuId = 0,
    required this.no,
    this.version,
    required this.date,
    this.fromDate,
    this.toDate,
    this.type,
    this.totalQty,
    this.remarks,
    this.comments,
    required this.department,
    required this.toStore,
    required this.issueTo,
    required this.bizunit,
    this.module,
    required this.company,
    this.modifiedBy,
    this.modifiedDate,
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
    this.workflowStatus = 0,
    this.departmentText,
    this.toStoreText,
    this.companyText,
    this.typeText,
    this.statusText,
    this.isSelected = false,
    this.hasEdit = true,
    this.edit,
    this.action,
    this.view,
    this.delete,
    required this.details,
    this.dateRequired,
    this.departmentRequired,
    this.toStoreRequired,
    this.totalQtyNegative,
    this.detailsRequired,
    this.refid,
    required this.menuId,
    required this.moduleId,
    required this.userId,
    this.divisionGroup,
    this.issueAgainst,
    required this.issueReceiptType,
    this.itemText,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'CreatedBy': createdBy,
      'Status': status,
      'SbuId': sbuId,
      'No': no,
      'Version': version,
      'Date': date,
      'FromDate': fromDate,
      'ToDate': toDate,
      'Type': type,
      'TotalQty': totalQty,
      'Remarks': remarks,
      'Comments': comments,
      'Department': department,
      'ToStore': toStore,
      'IssueTo': issueTo,
      'Bizunit': bizunit,
      'Module': module,
      'Company': company,
      'ModifiedBy': modifiedBy,
      'ModifiedDate': modifiedDate,
      'IsWorkOrder': isWorkOrder,
      'IsEdit': isEdit,
      'ConfirmStockValueChange': confirmStockValueChange,
      'AstDocMode': astDocMode,
      'AptCode': aptCode,
      'IsMultipleBatch': isMultipleBatch,
      'MultiBatchGroup': multiBatchGroup,
      'TransactionType': transactionType,
      'IsCancelled': isCancelled,
      'WorkflowProcess': workflowProcess,
      'Reference': reference,
      'WorkflowFlag': workflowFlag,
      'ProcessId': processId,
      'ProcessActionId': processActionId,
      'WorkflowComment': workflowComment,
      'WorkflowStatus': workflowStatus,
      'DepartmentText': departmentText,
      'ToStoreText': toStoreText,
      'CompanyText': companyText,
      'TypeText': typeText,
      'StatusText': statusText,
      'IsSelected': isSelected,
      'HasEdit': hasEdit,
      'Edit': edit,
      'Action': action,
      'View': view,
      'Delete': delete,
      'Details': details.map((detail) => detail.toJson()).toList(),
      'DateRequired': dateRequired,
      'DepartmentRequired': departmentRequired,
      'ToStoreRequired': toStoreRequired,
      'TotalQtyNegative': totalQtyNegative,
      'DetailsRequired': detailsRequired,
      'Refid': refid,
      'MenuId': menuId,
      'ModuleId': moduleId,
      'UserId': userId,
      'DivisionGroup': divisionGroup,
      'IssueAgainst': issueAgainst,
      'IssueReceiptType': issueReceiptType,
      'ItemText': itemText,
    };
  }
}

class ItemIssueDetailSaveRequest {
  final int? id;
  final int? createdBy;
  final int status;
  final int sbuId;
  final int displayOrder;
  final bool hasRight;
  final String? text;
  final int? rowNo;
  final String itemCode;
  final String batchNo;
  final String? itemName;
  final String? itemDescription;
  final String itemText;
  final double? minStk;
  final double? rolStk;
  final double? maxStk;
  final double? quantityInStock;
  final double? quantityPnOrder;
  final double? quantityApproved;
  final double quantityConsumed; // Quantity Issued Value
  final double? requestQuantity;
  final String? uomCode;
  final String? categoryName;
  final String? categoryText;
  final bool? itemIsPm;
  final String? requestSpec;
  final int? category;
  final String? code;
  final double? wholesaleRate;
  final double? retailRate;
  final String? name;
  final double rate;
  final String? description;
  final int itemCategory;
  final String itemCategoryText;
  final double? requestedQty;
  final String? specification;
  final int? requestedBy;
  final String uomText;
  final int purchaseRequestHeaderId;
  final String? no;
  final String? date;
  final int version;
  final bool? select;
  final int slNo;
  final int item;
  final int batchId;
  final dynamic stockBatch;
  final String? itemSpecification;
  final String? purpose;
  final double quantityRequested;
  final double? quantityRecieved;
  final double? quantityOrdered;
  final String? instruction;
  final int uom;
  final String? requiredDate;
  final String? remarks;
  final int department;
  final int bizunit;
  final int? oldItem;
  final String? editComments;
  final bool isChecked;
  final String? lotNo;
  final String? dateOfManufacture;
  final double stock;
  final String stockText;
  final String? expiryDate;
  final String? comments;
  final double? tax;
  final double? discount;
  final double? totalAmount;
  final double? netAmount;
  final double? adjAmount;
  final double? shippingAmount;
  final double? customerQty;
  final int customerItem;
  final int action;
  final double amount;
  final double? quantity;
  final String? valueText;
  final double? amountWise;
  final double? quantityWise;
  final String? pageName;
  final int? purchaseRequestId;
  final int? itemCount;
  final int? division;
  final String divisionText;
  final String? manufacturerText;
  final String? divisionName;
  final String? divisionGroupText;
  final int? divisionGroup;
  final int? taxId;
  final String? taxText;
  final bool? isUpdate;
  final String? manufacturerCountry;
  final bool isFOC;
  final String? country;
  final int? rowIndex;
  final bool? isReceiptBatchRequired;
  final int? detailId;
  final String? actualBatchNo;

  ItemIssueDetailSaveRequest({
    this.id,
    this.createdBy,
    this.status = 0,
    this.sbuId = 0,
    this.displayOrder = 0,
    this.hasRight = false,
    this.text,
    this.rowNo,
    required this.itemCode,
    required this.batchNo,
    this.itemName,
    this.itemDescription,
    required this.itemText,
    this.minStk,
    this.rolStk,
    this.maxStk,
    this.quantityInStock,
    this.quantityPnOrder,
    this.quantityApproved,
    required this.quantityConsumed,
    this.requestQuantity,
    this.uomCode,
    this.categoryName,
    this.categoryText,
    this.itemIsPm,
    this.requestSpec,
    this.category,
    this.code,
    this.wholesaleRate,
    this.retailRate,
    this.name,
    required this.rate,
    this.description,
    required this.itemCategory,
    required this.itemCategoryText,
    this.requestedQty,
    this.specification,
    this.requestedBy,
    required this.uomText,
    this.purchaseRequestHeaderId = 0,
    this.no,
    this.date,
    this.version = 0,
    this.select,
    this.slNo = 0,
    required this.item,
    required this.batchId,
    this.stockBatch,
    this.itemSpecification,
    this.purpose,
    this.quantityRequested = 0.0,
    this.quantityRecieved,
    this.quantityOrdered,
    this.instruction,
    required this.uom,
    this.requiredDate,
    this.remarks,
    this.department = 0,
    this.bizunit = 0,
    this.oldItem,
    this.editComments,
    this.isChecked = false,
    this.lotNo,
    this.dateOfManufacture,
    required this.stock,
    required this.stockText,
    this.expiryDate,
    this.comments,
    this.tax,
    this.discount,
    this.totalAmount,
    this.netAmount,
    this.adjAmount,
    this.shippingAmount,
    this.customerQty,
    this.customerItem = 0,
    this.action = 0,
    required this.amount,
    this.quantity,
    this.valueText,
    this.amountWise,
    this.quantityWise,
    this.pageName,
    this.purchaseRequestId,
    this.itemCount,
    this.division,
    required this.divisionText,
    this.manufacturerText,
    this.divisionName,
    this.divisionGroupText,
    this.divisionGroup,
    this.taxId,
    this.taxText,
    this.isUpdate,
    this.manufacturerCountry,
    this.isFOC = false,
    this.country,
    this.rowIndex,
    this.isReceiptBatchRequired,
    this.detailId,
    this.actualBatchNo,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'CreatedBy': createdBy,
      'Status': status,
      'SbuId': sbuId,
      'DisplayOrder': displayOrder,
      'HasRight': hasRight,
      'Text': text,
      'ROW_NO': rowNo,
      'ItemCode': itemCode,
      'BatchNo': batchNo,
      'ItemName': itemName,
      'ItemDescription': itemDescription,
      'ItemText': itemText,
      'MinStk': minStk,
      'RolStk': rolStk,
      'MaxStk': maxStk,
      'QuantityInStock': quantityInStock,
      'QuantityPnOrder': quantityPnOrder,
      'QuantityApproved': quantityApproved,
      'QuantityConsumed': quantityConsumed,
      'RequestQuantity': requestQuantity,
      'UomCode': uomCode,
      'CategoryName': categoryName,
      'CategoryText': categoryText,
      'ItemIsPm': itemIsPm,
      'RequestSpec': requestSpec,
      'Category': category,
      'Code': code,
      'WholesaleRate': wholesaleRate,
      'RetailRate': retailRate,
      'Name': name,
      'Rate': rate,
      'Description': description,
      'ItemCategory': itemCategory,
      'ItemCategoryText': itemCategoryText,
      'RequestedQty': requestedQty,
      'Specification': specification,
      'RequestedBy': requestedBy,
      'UOMText': uomText,
      'PurchaseRequestHeaderId': purchaseRequestHeaderId,
      'No': no,
      'Date': date,
      'Version': version,
      'Select': select,
      'SlNo': slNo,
      'Item': item,
      'BatchId': batchId,
      'StockBatch': stockBatch,
      'ItemSpecification': itemSpecification,
      'Purpose': purpose,
      'QuantityRequested': quantityRequested,
      'QuantityRecieved': quantityRecieved,
      'QuantityOrdered': quantityOrdered,
      'Instruction': instruction,
      'Uom': uom,
      'RequiredDate': requiredDate,
      'Remarks': remarks,
      'Department': department,
      'Bizunit': bizunit,
      'OldItem': oldItem,
      'EditComments': editComments,
      'IsChecked': isChecked,
      'LotNo': lotNo,
      'DateOfManufacture': dateOfManufacture,
      'Stock': stock,
      'StockText': stockText,
      'ExpiryDate': expiryDate,
      'Comments': comments,
      'Tax': tax,
      'Discount': discount,
      'TotalAmount': totalAmount,
      'NetAmount': netAmount,
      'AdjAmount': adjAmount,
      'ShippingAmount': shippingAmount,
      'CustomerQty': customerQty,
      'CustomerItem': customerItem,
      'Action': action,
      'Amount': amount,
      'Quantity': quantity,
      'ValueText': valueText,
      'AmountWise': amountWise,
      'QuantityWise': quantityWise,
      'PageName': pageName,
      'PurchaseRequestId': purchaseRequestId,
      'ItemCount': itemCount,
      'Division': division,
      'DivisionText': divisionText,
      'ManufacturerText': manufacturerText,
      'DivisionName': divisionName,
      'DivisionGroupText': divisionGroupText,
      'DivisionGroup': divisionGroup,
      'TaxId': taxId,
      'TaxText': taxText,
      'IsUpdate': isUpdate,
      'ManufacturerCountry': manufacturerCountry,
      'IsFOC': isFOC,
      'Country': country,
      'RowIndex': rowIndex,
      'IsReceiptBatchRequired': isReceiptBatchRequired,
      'DetailId': detailId,
      'ActualBatchNo': actualBatchNo,
    };
  }
}

class ItemIssueSaveResponse {
  final int? id;
  final bool success;
  final String? message;

  ItemIssueSaveResponse({
    this.id,
    required this.success,
    this.message,
  });

  factory ItemIssueSaveResponse.fromJson(Map<String, dynamic> json) {
    return ItemIssueSaveResponse(
      id: json['id'],
      success: json['success'] ?? true,
      message: json['message'],
    );
  }
}

