class SalesOrderListRequest {
  final int? id;
  final int pageNumber;
  final int pageSize;
  final int sortOrder;
  final int bizunit;
  final bool? active;
  final int sortDir;
  final String? searchText;
  final String sortField;
  final String? filterExpression;
  final String? sortExpression;
  final String? fromDate;
  final String? toDate;
  final String? fieldName;
  final String? pageName;
  final int userId; // Required - passed in listing API to fetch records
  final int menuId;
  final String url;
  final int? isFullyUsed;

  SalesOrderListRequest({
    this.id,
    required this.pageNumber,
    required this.pageSize,
    required this.sortOrder,
    required this.bizunit,
    this.active,
    required this.sortDir,
    this.searchText,
    required this.sortField,
    this.filterExpression,
    this.sortExpression,
    this.fromDate,
    this.toDate,
    this.fieldName,
    this.pageName,
    required this.userId, // Required - passed in listing API to fetch records
    required this.menuId,
    required this.url,
    this.isFullyUsed,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'PageNumber': pageNumber,
      'PageSize': pageSize,
      'SortOrder': sortOrder,
      'Bizunit': bizunit,
      'Active': active,
      'SortDir': sortDir,
      'SearchText': searchText,
      'SortField': sortField,
      'FilterExpression': filterExpression,
      'SortExpression': sortExpression,
      'FromDate': fromDate,
      'ToDate': toDate,
      'FieldName': fieldName,
      'PageName': pageName,
      'UserId': userId, // Always include userId in listing API
      'MenuId': menuId,
      'Url': url,
      'IsFullyUsed': isFullyUsed,
    };
  }
}

class SalesOrderListResponse {
  final List<SalesOrderApiItem> items;
  final int? totalRecords;
  final int? filteredRecords;

  SalesOrderListResponse({
    required this.items,
    this.totalRecords,
    this.filteredRecords,
  });

  factory SalesOrderListResponse.fromJson(Map<String, dynamic> json) {
    return SalesOrderListResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => SalesOrderApiItem.fromJson(item))
              .toList() ??
          [],
      totalRecords: json['totalRecords'],
      filteredRecords: json['filteredRecords'],
    );
  }
}

class SalesOrderApiItem {
  final int id;
  final int? createdBy;
  final int status;
  final int sbuId;
  final String? modifiedDate;
  final String? company;
  final int? bizunit;
  final int? userId;
  final int workflowFlag;
  final String? code;
  final String? department;
  final String? soNumber;
  final String? customerName;
  final String? typeText;
  final String? currencyText;
  final double amount;
  final String? date;
  final String? itemName;
  final int bonusQuantity;
  final int additionalBonusQuantity;
  final String? customer;
  final int? customerId;
  final String? cusAddress;
  final String? customerRef;
  final int? type;
  final String? currency;
  final int? currencyId;
  final double? exchangeRate;
  final String? deliveryDate;
  final double? totalAmount;
  final String? refNo;
  final int? quotationHeaderId;
  final String? statusText;
  final String? salesRep;
  final String? salesRepName;
  final int? taxId;
  final dynamic salesContractItems;
  final dynamic fileUploadDetails;
  final dynamic taxAndOtherChargesDetail;
  final int? pageId;
  final int? refid;
  final int? processId;
  final int? processActionId;
  final String? processName;
  final int? menuId;
  final int? moduleId;
  final int? module;
  final int workflowStatus;
  final String? workflowComment;
  final String? currencyBC;
  final int? totalQuantity;
  final double? totalConvAmount;
  final double? totalDiscount;
  final double? totalTax;
  final double? totalShipCharge;
  final double? totalAdjust;
  final double? netAmount;
  final double? netAmountBC;
  final String? division;
  final String? divisionGroup;
  final String? divisionText;
  final String? divisionGroupText;
  final String? divisionGroupName;
  final String? actionValue;
  final String? saleOrderShortCloseReason;
  final String? saleOrderShortCloseRefNo;
  final bool? checkFlag;
  final int? pageType;
  final String? poNo;
  final String? tenderNo;
  final String? reqNo;
  final int soStatus;
  final bool? isCancel;
  final int? isFullyUsed;
  final int doCounts;
  final int doCount;
  final int isShortClosed;
  final int isCancelled;
  final int isClosed;
  final String? decimalFormat;
  final String? rateFormat;
  final bool? hasEdit;
  final int? despatchedQty;
  final String? invoiceNo;
  final String? despatchNo;
  final String? isFullyUsedText;
  final String? deliveryAddress;
  final bool? isCustomerPODuplicateAllowed;
  final int? distributerForId;
  final int? actualCreatedBy;
  final String? actualCreatedByText;
  final String? saleOrderType;
  final bool? isBonusSO;
  final String? soType;
  final bool? isSalesRepEdit;
  final bool? vatRegistered;
  final bool? taxInclusive;
  final bool? bonusEnabled;
  final bool? discountEnabled;

  SalesOrderApiItem({
    required this.id,
    this.createdBy,
    required this.status,
    required this.sbuId,
    this.modifiedDate,
    this.company,
    this.bizunit,
    this.userId,
    required this.workflowFlag,
    this.code,
    this.department,
    this.soNumber,
    this.customerName,
    this.typeText,
    this.currencyText,
    required this.amount,
    this.date,
    this.itemName,
    required this.bonusQuantity,
    required this.additionalBonusQuantity,
    this.customer,
    this.customerId,
    this.cusAddress,
    this.customerRef,
    this.type,
    this.currency,
    this.currencyId,
    this.exchangeRate,
    this.deliveryDate,
    this.totalAmount,
    this.refNo,
    this.quotationHeaderId,
    this.statusText,
    this.salesRep,
    this.salesRepName,
    this.taxId,
    this.salesContractItems,
    this.fileUploadDetails,
    this.taxAndOtherChargesDetail,
    this.pageId,
    this.refid,
    this.processId,
    this.processActionId,
    this.processName,
    this.menuId,
    this.moduleId,
    this.module,
    required this.workflowStatus,
    this.workflowComment,
    this.currencyBC,
    this.totalQuantity,
    this.totalConvAmount,
    this.totalDiscount,
    this.totalTax,
    this.totalShipCharge,
    this.totalAdjust,
    this.netAmount,
    this.netAmountBC,
    this.division,
    this.divisionGroup,
    this.divisionText,
    this.divisionGroupText,
    this.divisionGroupName,
    this.actionValue,
    this.saleOrderShortCloseReason,
    this.saleOrderShortCloseRefNo,
    this.checkFlag,
    this.pageType,
    this.poNo,
    this.tenderNo,
    this.reqNo,
    required this.soStatus,
    this.isCancel,
    this.isFullyUsed,
    required this.doCounts,
    required this.doCount,
    required this.isShortClosed,
    required this.isCancelled,
    required this.isClosed,
    this.decimalFormat,
    this.rateFormat,
    this.hasEdit,
    this.despatchedQty,
    this.invoiceNo,
    this.despatchNo,
    this.isFullyUsedText,
    this.deliveryAddress,
    this.isCustomerPODuplicateAllowed,
    this.distributerForId,
    this.actualCreatedBy,
    this.actualCreatedByText,
    this.saleOrderType,
    this.isBonusSO,
    this.soType,
    this.isSalesRepEdit,
    this.vatRegistered,
    this.taxInclusive,
    this.bonusEnabled,
    this.discountEnabled,
  });

  factory SalesOrderApiItem.fromJson(Map<String, dynamic> json) {
    return SalesOrderApiItem(
      id: json['id'] ?? 0,
      createdBy: json['createdBy'],
      status: json['status'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      modifiedDate: json['modifiedDate'],
      company: json['company']?.toString(),
      bizunit: json['bizunit'],
      userId: json['userId'],
      workflowFlag: json['workflowFlag'] ?? 0,
      code: json['code'],
      department: json['department'],
      soNumber: json['soNumber'],
      customerName: json['customerName'],
      typeText: json['typeText'],
      currencyText: json['currencyText'],
      amount: (json['amount'] ?? 0).toDouble(),
      date: json['date'],
      itemName: json['itemName'],
      bonusQuantity: json['bonusQuantity'] ?? 0,
      additionalBonusQuantity: json['additionalBonusQuantity'] ?? 0,
      customer: json['customer'],
      customerId: json['customerId'],
      cusAddress: json['cusAddress'],
      customerRef: json['customerRef'],
      type: json['type'],
      currency: json['currency'],
      currencyId: json['currencyId'],
      exchangeRate: json['exchangeRate']?.toDouble(),
      deliveryDate: json['deliveryDate'],
      totalAmount: json['totalAmount']?.toDouble(),
      refNo: json['refNo'],
      quotationHeaderId: json['quotationHeaderId'],
      statusText: json['statusText'],
      salesRep: json['salesRep']?.toString(),
      salesRepName: json['salesRepName'],
      taxId: json['taxId'],
      salesContractItems: json['salesContractItems'],
      fileUploadDetails: json['fileUploadDetails'],
      taxAndOtherChargesDetail: json['taxAndOtherChargesDetail'],
      pageId: json['pageId'],
      refid: json['refid'],
      processId: json['processId'],
      processActionId: json['processActionId'],
      processName: json['processName'],
      menuId: json['menuId'],
      moduleId: json['moduleId'],
      module: json['module'],
      workflowStatus: json['workflowStatus'] ?? 0,
      workflowComment: json['workflowComment'],
      currencyBC: json['currencyBC'],
      totalQuantity: json['totalQuantity'],
      totalConvAmount: json['totalConvAmount']?.toDouble(),
      totalDiscount: json['totalDiscount']?.toDouble(),
      totalTax: json['totalTax']?.toDouble(),
      totalShipCharge: json['totalShipCharge']?.toDouble(),
      totalAdjust: json['totalAdjust']?.toDouble(),
      netAmount: json['netAmount']?.toDouble(),
      netAmountBC: json['netAmountBC']?.toDouble(),
      division: json['division'],
      divisionGroup: json['divisionGroup']?.toString(),
      divisionText: json['divisionText'],
      divisionGroupText: json['divisionGroupText'],
      divisionGroupName: json['divisionGroupName'],
      actionValue: json['actionValue'],
      saleOrderShortCloseReason: json['saleOrderShortCloseReason'],
      saleOrderShortCloseRefNo: json['saleOrderShortCloseRefNo'],
      checkFlag: json['checkFlag'],
      pageType: json['pageType'],
      poNo: json['poNo'],
      tenderNo: json['tenderNo'],
      reqNo: json['reqNo'],
      soStatus: json['soStatus'] ?? 0,
      isCancel: json['isCancel'],
      isFullyUsed: json['isFullyUsed'],
      doCounts: json['doCounts'] ?? 0,
      doCount: json['doCount'] ?? 0,
      isShortClosed: json['isShortClosed'] ?? 0,
      isCancelled: json['isCancelled'] ?? 0,
      isClosed: json['isClosed'] ?? 0,
      decimalFormat: json['decimalFormat'],
      rateFormat: json['rateFormat'],
      hasEdit: json['hasEdit'],
      despatchedQty: json['despatchedQty'],
      invoiceNo: json['invoiceNo'],
      despatchNo: json['despatchNo'],
      isFullyUsedText: json['isFullyUsedText'],
      deliveryAddress: json['deliveryAddress'],
      isCustomerPODuplicateAllowed: json['isCustomerPODuplicateAllowed'],
      distributerForId: json['distributerForId'],
      actualCreatedBy: json['actualCreatedBy'],
      actualCreatedByText: json['actualCreatedByText'],
      saleOrderType: json['saleOrderType']?.toString(),
      isBonusSO: json['isBonusSO'],
      soType: json['soType'],
      isSalesRepEdit: json['isSalesRepEdit'] == 1 || json['isSalesRepEdit'] == true,
      vatRegistered: json['vatRegistered'],
      taxInclusive: json['taxInclusive'],
      bonusEnabled: json['bonusEnabled'],
      discountEnabled: json['discountEnabled'],
    );
  }
}

/// Request model for GetSalesInvoiceCommonAuto endpoint
class GetSalesInvoiceCommonAutoRequest {
  final int? id;
  final int pageNumber;
  final int pageSize;
  final int sortOrder;
  final int bizUnit;
  final bool? active;
  final int sortDir;
  final String? searchText;
  final String? sortField;
  final String? filterExpression;
  final String? sortExpression;
  final String? fromDate;
  final String? toDate;
  final String? fieldName;
  final String? pageName;
  final int? userId;
  final int? menuId;
  final String? url;
  final bool? isFullyUsed;
  final int? refId;

  GetSalesInvoiceCommonAutoRequest({
    this.id,
    required this.pageNumber,
    required this.pageSize,
    required this.sortOrder,
    required this.bizUnit,
    this.active,
    required this.sortDir,
    this.searchText,
    this.sortField,
    this.filterExpression,
    this.sortExpression,
    this.fromDate,
    this.toDate,
    required this.fieldName,
    required this.pageName,
    this.userId,
    this.menuId,
    this.url,
    this.isFullyUsed,
    this.refId,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'pageNumber': pageNumber,
      'pageSize': pageSize,
      'sortOrder': sortOrder,
      'bizUnit': bizUnit,
      'sortDir': sortDir,
      'fieldName': fieldName,
      'pageName': pageName,
    };

    if (id != null) data['id'] = id;
    if (active != null) data['active'] = active;
    if (searchText != null) data['searchText'] = searchText;
    if (sortField != null) data['sortField'] = sortField;
    if (filterExpression != null) data['filterExpression'] = filterExpression;
    if (sortExpression != null) data['sortExpression'] = sortExpression;
    if (fromDate != null) data['fromDate'] = fromDate;
    if (toDate != null) data['toDate'] = toDate;
    if (userId != null) data['userId'] = userId;
    if (menuId != null) data['menuId'] = menuId;
    if (url != null) data['url'] = url;
    if (isFullyUsed != null) data['isFullyUsed'] = isFullyUsed;
    if (refId != null) data['refId'] = refId;

    return data;
  }
}

// Sales Order Save Models
class SalesContractItem {
  final int? id;
  final int? createdBy;
  final int status;
  final int sbuId;
  final String? itemCategoryText;
  final int? itemCategory;
  final String? packingSpecText;
  final int? packingSpec;
  final int? subCategory;
  final String? itemText;
  final int item;
  final double quantity;
  final int uom;
  final double unitPrice;
  final double? mrp; // MRP field
  final double amount;
  final double discount;
  final double? tax;
  final double totalAmount;
  final String reqdDate;
  final String? remarks;
  final String? addlRemarks;
  final double bonusQuantity;
  final String uomText;
  final double discountAmount;
  final int? additionalQuantity;
  final int? divisionGroup;
  final String? divisionGroupText;
  final String? manufacturerName;
  final String? divisionGroupName;
  final bool? isUpdate;
  final int? taxId;
  final String? taxText;
  final String? itemNo;
  final bool isFOC;
  final bool? isRateUpdateConfirm;

  SalesContractItem({
    this.id,
    this.createdBy,
    required this.status,
    required this.sbuId,
    this.itemCategoryText,
    this.itemCategory,
    this.packingSpecText,
    this.packingSpec,
    this.subCategory,
    required this.itemText,
    required this.item,
    required this.quantity,
    required this.uom,
    required this.unitPrice,
    this.mrp,
    required this.amount,
    required this.discount,
    this.tax,
    required this.totalAmount,
    required this.reqdDate,
    this.remarks,
    this.addlRemarks,
    required this.bonusQuantity,
    required this.uomText,
    required this.discountAmount,
    this.additionalQuantity,
    this.divisionGroup,
    this.divisionGroupText,
    this.manufacturerName,
    this.divisionGroupName,
    this.isUpdate,
    this.taxId,
    this.taxText,
    this.itemNo,
    required this.isFOC,
    this.isRateUpdateConfirm,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'CreatedBy': createdBy,
      'Status': status,
      'SbuId': sbuId,
      'ItemCategoryText': itemCategoryText,
      'ItemCategory': itemCategory,
      'PackingSpecText': packingSpecText,
      'PackingSpec': packingSpec,
      'SubCategory': subCategory,
      'ItemText': itemText,
      'Item': item,
      'Quantity': quantity,
      'UOM': uom,
      'UnitPrice': unitPrice,
      'MRP': mrp,
      'Amount': amount,
      'Discount': discount,
      'Tax': tax,
      'TotalAmount': totalAmount,
      'ReqdDate': reqdDate,
      'Remarks': remarks,
      'AddlRemarks': addlRemarks,
      'BonusQuantity': bonusQuantity,
      'UomText': uomText,
      'DiscountAmount': discountAmount,
      'AdditionalQuantity': additionalQuantity,
      'DivisionGroup': divisionGroup,
      'DivisionGroupText': divisionGroupText,
      'ManufacturerName': manufacturerName,
      'DivisionGroupName': divisionGroupName,
      'IsUpdate': isUpdate,
      'TaxId': taxId,
      'TaxText': taxText,
      'ItemNo': itemNo,
      'IsFOC': isFOC,
      'IsRateUpdateConfirm': isRateUpdateConfirm,
    };
  }
}

class TaxAndOtherChargeDetail {
  final int? id;
  final int? gridId;
  final int type;
  final int? subType;
  final double value;
  final int hasMultiple;
  final int pageId;
  final String? formula;
  final bool hasMultipleItem;
  final String operator;
  final int? chargeTypeId;
  final int? chargeTypePageMapId;
  final int? subTypeId;
  final int? levelType;
  final String? chargeTypeText;
  final String? subTypeText;
  final String? typeText;
  final String? remarks;
  final String? pageName;
  final bool? isCustom;
  final bool? isCustomSelected;
  final double? customPercentage;
  final String? vendor;
  final String? currency;
  final String? invoiceNo;
  final String? customer;
  final String? invoiceDate;
  final String? label;

  TaxAndOtherChargeDetail({
    this.id,
    this.gridId,
    required this.type,
    this.subType,
    required this.value,
    required this.hasMultiple,
    required this.pageId,
    this.formula,
    required this.hasMultipleItem,
    required this.operator,
    this.chargeTypeId,
    this.chargeTypePageMapId,
    this.subTypeId,
    this.levelType,
    this.chargeTypeText,
    this.subTypeText,
    this.typeText,
    this.remarks,
    this.pageName,
    this.isCustom,
    this.isCustomSelected,
    this.customPercentage,
    this.vendor,
    this.currency,
    this.invoiceNo,
    this.customer,
    this.invoiceDate,
    this.label,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'GridId': gridId,
      'Type': type,
      'SubType': subType,
      'Value': value,
      'HasMultiple': hasMultiple,
      'PageId': pageId,
      'Formula': formula,
      'HasMultipleItem': hasMultipleItem,
      'Operator': operator,
      'ChargeTypeId': chargeTypeId,
      'ChargeTypePageMapId': chargeTypePageMapId,
      'SubTypeId': subTypeId,
      'LevelType': levelType,
      'ChargeTypeText': chargeTypeText,
      'SubTypeText': subTypeText,
      'TypeText': typeText,
      'Remarks': remarks ?? '',
      'PageName': pageName,
      'IsCustom': isCustom,
      'IsCustomSelected': isCustomSelected,
      'CustomPercentage': customPercentage,
      'Vendor': vendor,
      'Currency': currency,
      'InvoiceNo': invoiceNo,
      'Customer': customer,
      'InvoiceDate': invoiceDate,
      'Label': label,
    };
  }
}

class SalesOrderSaveRequest {
  final int? id;
  final int createdBy;
  final int status;
  final int sbuId;
  final int company;
  final int bizunit;
  final int userId;
  final int workflowFlag;
  final String code;
  final int department;
  final String? soNumber;
  final String? customerName;
  final String? typeText;
  final String? currencyText;
  final double amount;
  final String date;
  final String? itemName;
  final int? bonusQuantity;
  final int? additionalBonusQuantity;
  final String? customer;
  final int? customerId;
  final String? cusAddress;
  final String? customerRef;
  final int type;
  final String currency;
  final int currencyId;
  final double exchangeRate;
  final String deliveryDate;
  final double totalAmount;
  final String? refNo;
  final int? quotationHeaderId;
  final String? statusText;
  final int? salesRep;
  final String? salesRepName;
  final int? taxId;
  final List<SalesContractItem> salesContractItems;
  final dynamic fileUploadDetails;
  final List<TaxAndOtherChargeDetail> taxAndOtherChargesDetail;
  final int pageId;
  final int? refid;
  final int? processId;
  final int? processActionId;
  final String? processName;
  final int menuId;
  final int? moduleId;
  final int? module;
  final int workflowStatus;
  final String? workflowComment;
  final int? currencyBC;
  final double? totalQuantity;
  final double? totalConvAmount;
  final double? totalDiscount;
  final double? totalTax;
  final double? totalShipCharge;
  final double? totalAdjust;
  final double? netAmount;
  final double? netAmountBC;
  final String? division;
  final int? divisionGroup;
  final String? divisionText;
  final String? divisionGroupText;
  final String? divisionGroupName;
  final String? actionValue;
  final String? saleOrderShortCloseReason;
  final String? saleOrderShortCloseRefNo;
  final bool? checkFlag;
  final int? pageType;
  final String? poNo;
  final String? tenderNo;
  final String? reqNo;
  final int soStatus;
  final bool? isCancel;
  final int? isFullyUsed;
  final int doCounts;
  final int doCount;
  final int isShortClosed;
  final int isCancelled;
  final int isClosed;
  final String? decimalFormat;
  final String? rateFormat;
  final bool? hasEdit;
  final int? despatchedQty;
  final String? invoiceNo;
  final String? despatchNo;
  final String? isFullyUsedText;
  final String? deliveryAddress;
  final bool? isCustomerPODuplicateAllowed;
  final int? distributerForId;
  final int? actualCreatedBy;
  final int? saleOrderType;
  final bool? isBonusSO;
  final String? soType;
  final bool? isSalesRepEdit;
  final bool? vatRegistered;
  final bool? taxInclusive;
  final bool? bonusEnabled;

  SalesOrderSaveRequest({
    this.id,
    required this.createdBy,
    required this.status,
    required this.sbuId,
    required this.company,
    required this.bizunit,
    required this.userId,
    required this.workflowFlag,
    required this.code,
    required this.department,
    this.soNumber,
    this.customerName,
    this.typeText,
    this.currencyText,
    required this.amount,
    required this.date,
    this.itemName,
    this.bonusQuantity,
    this.additionalBonusQuantity,
    this.customer,
    this.customerId,
    this.cusAddress,
    this.customerRef,
    required this.type,
    required this.currency,
    required this.currencyId,
    required this.exchangeRate,
    required this.deliveryDate,
    required this.totalAmount,
    this.refNo,
    this.quotationHeaderId,
    this.statusText,
    this.salesRep,
    this.salesRepName,
    this.taxId,
    required this.salesContractItems,
    this.fileUploadDetails,
    required this.taxAndOtherChargesDetail,
    required this.pageId,
    this.refid,
    this.processId,
    this.processActionId,
    this.processName,
    required this.menuId,
    this.moduleId,
    this.module,
    required this.workflowStatus,
    this.workflowComment,
    this.currencyBC,
    this.totalQuantity,
    this.totalConvAmount,
    this.totalDiscount,
    this.totalTax,
    this.totalShipCharge,
    this.totalAdjust,
    this.netAmount,
    this.netAmountBC,
    this.division,
    this.divisionGroup,
    this.divisionText,
    this.divisionGroupText,
    this.divisionGroupName,
    this.actionValue,
    this.saleOrderShortCloseReason,
    this.saleOrderShortCloseRefNo,
    this.checkFlag,
    this.pageType,
    this.poNo,
    this.tenderNo,
    this.reqNo,
    required this.soStatus,
    this.isCancel,
    this.isFullyUsed,
    required this.doCounts,
    required this.doCount,
    required this.isShortClosed,
    required this.isCancelled,
    required this.isClosed,
    this.decimalFormat,
    this.rateFormat,
    this.hasEdit,
    this.despatchedQty,
    this.invoiceNo,
    this.despatchNo,
    this.isFullyUsedText,
    this.deliveryAddress,
    this.isCustomerPODuplicateAllowed,
    this.distributerForId,
    this.actualCreatedBy,
    this.saleOrderType,
    this.isBonusSO,
    this.soType,
    this.isSalesRepEdit,
    this.vatRegistered,
    this.taxInclusive,
    this.bonusEnabled,
  });

  // Helper method to convert bool? to int for API
  int? _convertBoolToInt(bool? value) {
    if (value == null) return 0;
    return value ? 1 : 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'CreatedBy': createdBy,
      'Status': status,
      'SbuId': sbuId,
      'Company': company,
      'Bizunit': bizunit,
      'UserId': userId,
      'WorkflowFlag': workflowFlag,
      'Code': code,
      'Department': department,
      'SONumber': soNumber,
      'CustomerName': customerName,
      'TypeText': typeText,
      'CurrencyText': currencyText,
      'Amount': amount,
      'Date': date,
      'ItemName': itemName,
      'BonusQuantity': bonusQuantity,
      'AdditionalBonusQuantity': additionalBonusQuantity,
      'Customer': customer,
      'CustomerId': customerId,
      'CusAddress': cusAddress,
      'CustomerRef': customerRef,
      'Type': type,
      'Currency': currency,
      'CurrencyId': currencyId,
      'ExchangeRate': exchangeRate,
      'DeliveryDate': deliveryDate,
      'TotalAmount': totalAmount,
      'RefNo': refNo,
      'QuotationHeaderId': quotationHeaderId,
      'StatusText': statusText,
      'SalesRep': salesRep,
      'SalesRepName': salesRepName,
      'TaxId': taxId,
      'SalesContractItems': salesContractItems.map((item) => item.toJson()).toList(),
      'FileUploadDetails': fileUploadDetails,
      'TaxAndOtherChargesDetail': taxAndOtherChargesDetail.map((item) => item.toJson()).toList(),
      'PageId': pageId,
      'Refid': refid,
      'ProcessId': processId,
      'ProcessActionId': processActionId,
      'ProcessName': processName,
      'MenuId': menuId,
      'ModuleId': moduleId,
      'Module': module,
      'WorkflowStatus': workflowStatus,
      'WorkflowComment': workflowComment,
      'CurrencyBC': currencyBC,
      'TotalQuantity': totalQuantity,
      'TotalConvAmount': totalConvAmount,
      'TotalDiscount': totalDiscount,
      'TotalTax': totalTax,
      'TotalShipCharge': totalShipCharge,
      'TotalAdjust': totalAdjust,
      'NetAmount': netAmount,
      'NetAmountBC': netAmountBC,
      'Division': division,
      'DivisionGroup': divisionGroup,
      'DivisionText': divisionText,
      'DivisionGroupText': divisionGroupText,
      'DivisionGroupName': divisionGroupName,
      'ActionValue': actionValue,
      'SaleOrderShortCloseReason': saleOrderShortCloseReason,
      'SaleOrderShortCloseRefNo': saleOrderShortCloseRefNo,
      'CheckFlag': checkFlag,
      'PageType': pageType,
      'PoNo': poNo,
      'TenderNo': tenderNo,
      'ReqNo': reqNo,
      'SOStatus': soStatus,
      'IsCancel': _convertBoolToInt(isCancel), // Convert bool? to int (1 for true, 0 for false/null)
      'IsFullyUsed': isFullyUsed ?? 0, // Default to 0 if null to avoid .NET parsing error
      'DOCounts': doCounts,
      'DOCount': doCount,
      'IsShortClosed': isShortClosed,
      'IsCancelled': isCancelled,
      'IsClosed': isClosed,
      'DecimalFormat': decimalFormat,
      'RateFormat': rateFormat,
      'HasEdit': hasEdit ?? false, // Default to false if null to avoid .NET parsing error
      'DespatchedQty': despatchedQty,
      'InvoiceNo': invoiceNo,
      'DespatchNo': despatchNo,
      'IsFullyUsedText': isFullyUsedText,
      'DeliveryAddress': deliveryAddress,
      'IsCustomerPODuplicateAllowed': isCustomerPODuplicateAllowed ?? false, // Default to false if null
      'DistributerForId': distributerForId,
      'ActualCreatedBy': actualCreatedBy,
      'SaleOrderType': saleOrderType,
      'IsBonusSO': isBonusSO ?? false, // Default to false if null
      'SOType': soType,
      'IsSalesRepEdit': isSalesRepEdit,
      'VatRegistered': vatRegistered ?? false, // Default to false if null
      'TaxInclusive': taxInclusive ?? false, // Default to false if null
      'BonusEnabled': bonusEnabled ?? false, // Default to false if null
    };
  }
}

class SalesOrderSaveResponse {
  final dynamic data; // Can be SalesOrderApiItem or error object
  final bool success;
  final String? message;

  SalesOrderSaveResponse({
    required this.data,
    required this.success,
    this.message,
  });

  factory SalesOrderSaveResponse.fromJson(Map<String, dynamic> json) {
    return SalesOrderSaveResponse(
      data: json,
      success: json['id'] != null || json['status'] != null,
      message: json['message']?.toString(),
    );
  }
}

/// Transaction Cancel Request Model
/// API: /api/SaleOrder/TransactionCancel
/// Type: POST
class SalesOrderTransactionCancelRequest {
  final int? poId;
  final int id; // Transaction Id (required)
  final int? itemId;
  final int? vendorId;
  final int processId; // Process Id from workflowget (required)

  SalesOrderTransactionCancelRequest({
    this.poId,
    required this.id,
    this.itemId,
    this.vendorId,
    required this.processId,
  });

  Map<String, dynamic> toJson() {
    return {
      'POId': poId,
      'Id': id,
      'ItemId': itemId,
      'VendorId': vendorId,
      'ProcessId': processId,
    };
  }
}
