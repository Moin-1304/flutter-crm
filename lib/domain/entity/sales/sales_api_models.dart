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
  final dynamic _fileUploadDetailsRaw;
  List<FileUploadDetail>? get fileUploadDetails {
    final raw = _fileUploadDetailsRaw;
    if (raw == null) return null;
    if (raw is List<FileUploadDetail>) return raw;
    if (raw is List) {
      return raw
          .where((e) => e != null)
          .map((e) {
            if (e is FileUploadDetail) return e;
            if (e is Map<String, dynamic>) return FileUploadDetail.fromJson(e);
            if (e is Map) {
              // Defensive: if map isn't typed, coerce to <String, dynamic>.
              return FileUploadDetail.fromJson(Map<String, dynamic>.from(e));
            }
            // Unknown element shape; skip it.
            return null;
          })
          .whereType<FileUploadDetail>()
          .toList();
    }
    return null;
  }

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
    dynamic fileUploadDetails,
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
  }) : _fileUploadDetailsRaw = fileUploadDetails;

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
      salesContractItems:
          json['salesContractItems'] ?? json['SalesContractItems'],
      fileUploadDetails: json['fileUploadDetails'] ??
          json['FileUploadDetails'] ??
          json['Attachments'] ??
          json['attachments'],
      taxAndOtherChargesDetail:
          json['taxAndOtherChargesDetail'] ?? json['TaxAndOtherChargesDetail'],
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
      despatchedQty: json['despatchedQty'] ?? json['DespatchedQty'],
      invoiceNo: json['invoiceNo'] ?? json['InvoiceNo'],
      despatchNo: json['despatchNo'] ?? json['DespatchNo'],
      isFullyUsedText: json['isFullyUsedText'],
      deliveryAddress: json['deliveryAddress'],
      isCustomerPODuplicateAllowed: json['isCustomerPODuplicateAllowed'],
      distributerForId: json['distributerForId'],
      actualCreatedBy: json['actualCreatedBy'],
      actualCreatedByText: json['actualCreatedByText'],
      saleOrderType: json['saleOrderType']?.toString(),
      isBonusSO: json['isBonusSO'],
      soType: json['soType'],
      isSalesRepEdit:
          json['isSalesRepEdit'] == 1 || json['isSalesRepEdit'] == true,
      vatRegistered: json['vatRegistered'],
      taxInclusive: json['taxInclusive'],
      bonusEnabled: json['bonusEnabled'],
      discountEnabled: json['discountEnabled'],
    );
  }
}

// fileUploadDetails
class FileUploadDetail {
  final int id;
  final String? url;
  final String? fileName;
  final String? extension;

  FileUploadDetail({
    required this.id,
    this.url,
    this.fileName,
    this.extension,
  });

  factory FileUploadDetail.fromJson(Map<String, dynamic> json) {
    return FileUploadDetail(
      id: json['id'] ?? json['Id'] ?? 0,
      url: json['url'] ?? json['Url'] ?? json['filePath'] ?? json['FilePath'],
      fileName: json['fileName'] ?? json['FileName'],
      extension: json['extension'] ?? json['Extension'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Url': url,
      'FileName': fileName,
      'Extension': extension,
    };
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

class SalesBonusListRequest {
  final int itemId;

  SalesBonusListRequest({required this.itemId});

  Map<String, dynamic> toJson() {
    return {
      'PageNumber': 0,
      'PageSize': 0,
      'SortOrder': 0,
      'SortDir': 0,
      'SortField': null,
      'SearchText': null,
      'CommandText': null,
      'PageName': null,
      'SortExpression': null,
      'FilterExpression': null,
      'Id': null,
      'ItemId': itemId,
      'Lumpsum': null,
      'ItemName': null,
      'SlabName': null,
      'UOMText': null,
      'Percentage': null,
      'SlabId': null,
      'Qty': null,
      'QtyUom': null,
      'BonusQty': null,
      'BqtyUom': null,
      'Active': null,
      'CreatedBy': null,
      'FromDate': null,
      'ToDate': null,
      'HasHistory': null,
      'SbuId': null,
      'Status': 0,
      'UserId': null,
      'ActiveText': null,
    };
  }
}

class SalesBonusItem {
  final int? id;
  final int? itemId;
  final int? lumpsum;
  final double? maxVal;
  final int? slabId;
  final double? qty;
  final double? bonusQty;

  SalesBonusItem({
    this.id,
    this.itemId,
    this.lumpsum,
    this.maxVal,
    this.slabId,
    this.qty,
    this.bonusQty,
  });

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  factory SalesBonusItem.fromJson(Map<String, dynamic> json) {
    return SalesBonusItem(
      id: _asInt(json['id'] ?? json['Id']),
      itemId: _asInt(json['itemId'] ?? json['ItemId']),
      lumpsum: _asInt(json['lumpsum'] ?? json['Lumpsum']),
      maxVal: _asDouble(json['maxVal'] ?? json['MaxVal']),
      slabId: _asInt(json['slabId'] ?? json['SlabId']),
      qty: _asDouble(json['qty'] ?? json['Qty']),
      bonusQty: _asDouble(json['bonusQty'] ?? json['BonusQty']),
    );
  }
}

class SalesBonusListResponse {
  final List<SalesBonusItem> items;
  final int totalRecords;
  final int filteredRecords;

  SalesBonusListResponse({
    required this.items,
    required this.totalRecords,
    required this.filteredRecords,
  });

  factory SalesBonusListResponse.fromJson(Map<String, dynamic> json) {
    return SalesBonusListResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => SalesBonusItem.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      totalRecords: (json['totalRecords'] as num?)?.toInt() ?? 0,
      filteredRecords: (json['filteredRecords'] as num?)?.toInt() ?? 0,
    );
  }
}

class SalesBonusSlabListRequest {
  final int id;

  SalesBonusSlabListRequest({required this.id});

  Map<String, dynamic> toJson() {
    return {
      'PageNumber': 1,
      'PageSize': 15,
      'SortOrder': 0,
      'SortDir': 0,
      'SortField': null,
      'SearchText': null,
      'Id': id,
      'Name': null,
      'Uom': 0,
      'MinVal': 0,
      'MaxVaL': 0,
      'UomText': null,
      'Active': 0,
      'CreatedBy': null,
      'SbuId': 0,
      'Status': 0,
      'UserId': null,
      'ActiveText': null,
    };
  }
}

class SalesBonusSlabItem {
  final int? id;
  final double? minVal;
  final double? maxVal;

  SalesBonusSlabItem({
    this.id,
    this.minVal,
    this.maxVal,
  });

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  factory SalesBonusSlabItem.fromJson(Map<String, dynamic> json) {
    return SalesBonusSlabItem(
      id: _asInt(json['id'] ?? json['Id']),
      minVal: _asDouble(json['minVal'] ?? json['MinVal']),
      maxVal: _asDouble(json['maxVal'] ?? json['MaxVaL'] ?? json['MaxVal']),
    );
  }
}

class SalesBonusSlabListResponse {
  final List<SalesBonusSlabItem> items;

  SalesBonusSlabListResponse({required this.items});

  factory SalesBonusSlabListResponse.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      final rawItems = json['items'];
      if (rawItems is List) {
        return SalesBonusSlabListResponse(
          items: rawItems
              .map((e) =>
                  SalesBonusSlabItem.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
        );
      }
      return SalesBonusSlabListResponse(items: []);
    }
    return SalesBonusSlabListResponse(items: []);
  }
}

class SalesDiscountListRequest {
  final int itemId;

  SalesDiscountListRequest({required this.itemId});

  Map<String, dynamic> toJson() {
    return {
      'PageNumber': 1,
      'PageSize': 15,
      'SortOrder': 0,
      'SortDir': 0,
      'SortField': null,
      'SearchText': null,
      'CommandText': null,
      'PageName': null,
      'SortExpression': null,
      'FilterExpression': null,
      'Id': null,
      'ItemId': itemId,
      'Lumpsum': 0,
      'Percentage': 0,
      'SlabId': null,
      'Qty': 0.0,
      'QtyUom': 0,
      'BonusQty': 0.0,
      'BqtyUom': 0,
      'FromDate': null,
      'ToDate': null,
      'HasHistory': null,
      'Active': null,
      'CreatedBy': null,
      'SbuId': 0,
      'Status': 0,
      'UserId': null,
      'ActiveText': null,
    };
  }
}

class SalesDiscountItem {
  final int? id;
  final int? itemId;
  final int? lumpsum;
  final int? percentage;
  final int? slabId;
  final String? slabName;
  final double? qty;
  final double? bonusQty;

  SalesDiscountItem({
    this.id,
    this.itemId,
    this.lumpsum,
    this.percentage,
    this.slabId,
    this.slabName,
    this.qty,
    this.bonusQty,
  });

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  factory SalesDiscountItem.fromJson(Map<String, dynamic> json) {
    return SalesDiscountItem(
      id: _asInt(json['id'] ?? json['Id']),
      itemId: _asInt(json['itemId'] ?? json['ItemId']),
      lumpsum: _asInt(json['lumpsum'] ?? json['Lumpsum']),
      percentage: _asInt(json['percentage'] ?? json['Percentage']),
      slabId: _asInt(json['slabId'] ?? json['SlabId']),
      slabName: (json['slabName'] ?? json['SlabName'])?.toString(),
      qty: _asDouble(json['qty'] ?? json['Qty']),
      bonusQty: _asDouble(json['bonusQty'] ?? json['BonusQty']),
    );
  }
}

class SalesDiscountListResponse {
  final List<SalesDiscountItem> items;
  final int totalRecords;
  final int filteredRecords;

  SalesDiscountListResponse({
    required this.items,
    required this.totalRecords,
    required this.filteredRecords,
  });

  factory SalesDiscountListResponse.fromJson(Map<String, dynamic> json) {
    return SalesDiscountListResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => SalesDiscountItem.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      totalRecords: (json['totalRecords'] as num?)?.toInt() ?? 0,
      filteredRecords: (json['filteredRecords'] as num?)?.toInt() ?? 0,
    );
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
  final int? despatchedQty;

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
    this.despatchedQty,
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
      'DespatchedQty': despatchedQty,
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

  static dynamic _fileUploadDetailsToJson(dynamic fileUploadDetails) {
    if (fileUploadDetails == null) return null;
    if (fileUploadDetails is List) {
      return fileUploadDetails
          .map((e) => e is FileUploadDetail ? e.toJson() : e)
          .toList();
    }
    return fileUploadDetails;
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
      'SalesContractItems':
          salesContractItems.map((item) => item.toJson()).toList(),
      'FileUploadDetails': _fileUploadDetailsToJson(fileUploadDetails),
      'TaxAndOtherChargesDetail':
          taxAndOtherChargesDetail.map((item) => item.toJson()).toList(),
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
      'IsCancel': _convertBoolToInt(
          isCancel), // Convert bool? to int (1 for true, 0 for false/null)
      'IsFullyUsed':
          isFullyUsed ?? 0, // Default to 0 if null to avoid .NET parsing error
      'DOCounts': doCounts,
      'DOCount': doCount,
      'IsShortClosed': isShortClosed,
      'IsCancelled': isCancelled,
      'IsClosed': isClosed,
      'DecimalFormat': decimalFormat,
      'RateFormat': rateFormat,
      'HasEdit': hasEdit ??
          false, // Default to false if null to avoid .NET parsing error
      'DespatchedQty': despatchedQty,
      'InvoiceNo': invoiceNo,
      'DespatchNo': despatchNo,
      'IsFullyUsedText': isFullyUsedText,
      'DeliveryAddress': deliveryAddress,
      'IsCustomerPODuplicateAllowed':
          isCustomerPODuplicateAllowed ?? false, // Default to false if null
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

class SalesOrderBonusApprovalListRequest {
  final String? searchText;
  final int sortOrder;
  final int sortDir;
  final int pageNumber;
  final int pageSize;
  final String? fromDate;
  final String? toDate;
  final String? filterExpression;
  final int userId;
  final String? sortExpression;
  final int? id;
  final int? menuId;
  final String? commandText;
  final String? pageName;
  final int? sbuId;
  final int? bizUnit;
  final String? fieldName;
  final String? sortField;
  final String? url;
  final String? sono;
  final int? itemId;

  SalesOrderBonusApprovalListRequest({
    this.searchText,
    this.sortOrder = 0,
    this.sortDir = 1,
    this.pageNumber = 1,
    this.pageSize = 15,
    this.fromDate,
    this.toDate,
    this.filterExpression,
    required this.userId,
    this.sortExpression,
    this.id,
    this.menuId,
    this.commandText,
    this.pageName,
    this.sbuId,
    this.bizUnit,
    this.fieldName,
    this.sortField,
    this.url,
    this.sono,
    this.itemId,
  });

  Map<String, dynamic> toJson() => {
        'SearchText': searchText,
        'SortOrder': sortOrder,
        'SortDir': sortDir,
        'PageNumber': pageNumber,
        'PageSize': pageSize,
        'FromDate': fromDate,
        'ToDate': toDate,
        'FilterExpression': filterExpression,
        'UserId': userId,
        'SortExpression': sortExpression,
        'Id': id,
        'MenuId': menuId,
        'CommandText': commandText,
        'PageName': pageName,
        'SbuId': sbuId,
        'BizUnit': bizUnit,
        'FieldName': fieldName,
        'SortField': sortField,
        'Url': url,
        'SONO': sono,
        'ItemId': itemId,
      };
}

class SalesOrderBonusApprovalResponse {
  final List<SalesOrderBonusApprovalItem> items;
  final int? totalRecords;
  final int? filteredRecords;

  SalesOrderBonusApprovalResponse({
    required this.items,
    this.totalRecords,
    this.filteredRecords,
  });

  factory SalesOrderBonusApprovalResponse.fromJson(Map<String, dynamic> json) {
    return SalesOrderBonusApprovalResponse(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => SalesOrderBonusApprovalItem.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      totalRecords: json['totalRecords'] as int?,
      filteredRecords: json['filteredRecords'] as int?,
    );
  }
}

class SalesOrderBonusApprovalItem {
  final int id;
  final int? createdBy;
  final int? status;
  final int? company;
  final int? bizunit;
  final int? sbuId;
  final int? rowNumber;
  final String saleOrderNo;
  final int detailId;
  final String? date;
  final int? division;
  final String? divisionText;
  final int item;
  final String itemCode;
  final String itemName;
  final String customerName;
  final int customer;
  final double quantityOrdered;
  final double quantityApproved;
  final double bonusQuantity;
  final double additionalQuantity;
  final double additionalQuantityApproved;
  final double rate;
  final double netAmount;
  final String? createdDate;
  final int? userId;
  final int? pageType;
  final int? workflowFlag;
  final int? workflowStatus;
  final String? workflowComment;
  final int? processId;
  final dynamic actionValue;
  final int? processActionId;
  final String? processName;
  final int? menuId;
  final int? moduleId;
  final int? refid;
  final String? distributorName;
  final String? salesRepName;
  final String? approvedBy;
  final String? approvedDate;
  final bool isSelected;

  SalesOrderBonusApprovalItem({
    required this.id,
    this.createdBy,
    this.status,
    this.company,
    this.bizunit,
    this.sbuId,
    this.rowNumber,
    required this.saleOrderNo,
    required this.detailId,
    required this.date,
    this.division,
    required this.divisionText,
    required this.item,
    required this.itemCode,
    required this.itemName,
    required this.customerName,
    required this.customer,
    required this.quantityOrdered,
    required this.quantityApproved,
    required this.bonusQuantity,
    required this.additionalQuantity,
    required this.additionalQuantityApproved,
    required this.rate,
    required this.netAmount,
    this.createdDate,
    this.userId,
    this.pageType,
    this.workflowFlag,
    this.workflowStatus,
    this.workflowComment,
    this.processId,
    this.actionValue,
    this.processActionId,
    this.processName,
    this.menuId,
    this.moduleId,
    this.refid,
    this.distributorName,
    this.salesRepName,
    this.approvedBy,
    this.approvedDate,
    this.isSelected = false,
  });

  factory SalesOrderBonusApprovalItem.fromJson(Map<String, dynamic> json) {
    double toDoubleSafe(dynamic value) =>
        value == null ? 0 : (value as num).toDouble();

    return SalesOrderBonusApprovalItem(
      id: (json['id'] ?? json['Id'] ?? 0) as int,
      createdBy: (json['createdBy'] ?? json['CreatedBy']) as int?,
      status: (json['status'] ?? json['Status']) as int?,
      company: (json['company'] ?? json['Company']) as int?,
      bizunit: (json['bizunit'] ?? json['Bizunit']) as int?,
      sbuId: (json['sbuId'] ?? json['SbuId']) as int?,
      rowNumber: (json['rowNumber'] ?? json['RowNumber']) as int?,
      saleOrderNo:
          (json['saleOrderNo'] ?? json['SaleOrderNo'] ?? '') as String,
      detailId: (json['detailId'] ?? json['DetailId'] ?? 0) as int,
      date: (json['date'] ?? json['Date'])?.toString(),
      division: (json['division'] ?? json['Division']) as int?,
      divisionText:
          (json['divisionText'] ?? json['DivisionText'])?.toString(),
      item: (json['item'] ?? json['Item'] ?? 0) as int,
      itemCode: (json['itemCode'] ?? json['ItemCode'] ?? '') as String,
      itemName: (json['itemName'] ?? json['ItemName'] ?? '') as String,
      customerName:
          (json['customerName'] ?? json['CustomerName'] ?? '') as String,
      customer: (json['customer'] ?? json['Customer'] ?? 0) as int,
      quantityOrdered:
          toDoubleSafe(json['quantityOrdered'] ?? json['QuantityOrdered']),
      quantityApproved:
          toDoubleSafe(json['quantityApproved'] ?? json['QuantityApproved']),
      bonusQuantity:
          toDoubleSafe(json['bonusQuantity'] ?? json['BonusQuantity']),
      additionalQuantity:
          toDoubleSafe(json['additionalQuantity'] ?? json['AdditionalQuantity']),
      additionalQuantityApproved: toDoubleSafe(
          json['additionalQuantityApproved'] ??
              json['AdditionalQuantityApproved']),
      rate: toDoubleSafe(json['rate'] ?? json['Rate']),
      netAmount: toDoubleSafe(json['netAmount'] ?? json['NetAmount']),
      createdDate: (json['createdDate'] ?? json['CreatedDate'])?.toString(),
      userId: (json['userId'] ?? json['UserId']) as int?,
      pageType: (json['pageType'] ?? json['PageType']) as int?,
      workflowFlag: (json['workflowFlag'] ?? json['WorkflowFlag']) as int?,
      workflowStatus: (json['workflowStatus'] ?? json['WorkflowStatus']) as int?,
      workflowComment:
          (json['workflowComment'] ?? json['WorkflowComment'])?.toString(),
      processId: (json['processId'] ?? json['ProcessId']) as int?,
      actionValue: json['actionValue'] ?? json['ActionValue'],
      processActionId:
          (json['processActionId'] ?? json['ProcessActionId']) as int?,
      processName: (json['processName'] ?? json['ProcessName'])?.toString(),
      menuId: (json['menuId'] ?? json['MenuId']) as int?,
      moduleId: (json['moduleId'] ?? json['ModuleId']) as int?,
      refid: (json['refid'] ?? json['Refid']) as int?,
      distributorName:
          (json['distributorName'] ?? json['DistributorName'])?.toString(),
      salesRepName: (json['salesRepName'] ?? json['SalesRepName'])?.toString(),
      approvedBy: (json['approvedBy'] ?? json['ApprovedBy'])?.toString(),
      approvedDate:
          (json['approvedDate'] ?? json['ApprovedDateTime'] ?? json['ApprovedDate'])
              ?.toString(),
      isSelected: (json['isSelected'] ?? json['IsSelected'] ?? false) == true,
    );
  }

  SalesOrderBonusApprovalItem copyWith({
    double? additionalQuantityApproved,
    bool? isSelected,
  }) {
    return SalesOrderBonusApprovalItem(
      id: id,
      createdBy: createdBy,
      status: status,
      company: company,
      bizunit: bizunit,
      sbuId: sbuId,
      rowNumber: rowNumber,
      saleOrderNo: saleOrderNo,
      detailId: detailId,
      date: date,
      division: division,
      divisionText: divisionText,
      item: item,
      itemCode: itemCode,
      itemName: itemName,
      customerName: customerName,
      customer: customer,
      quantityOrdered: quantityOrdered,
      quantityApproved: quantityApproved,
      bonusQuantity: bonusQuantity,
      additionalQuantity: additionalQuantity,
      additionalQuantityApproved:
          additionalQuantityApproved ?? this.additionalQuantityApproved,
      rate: rate,
      netAmount: netAmount,
      createdDate: createdDate,
      userId: userId,
      pageType: pageType,
      workflowFlag: workflowFlag,
      workflowStatus: workflowStatus,
      workflowComment: workflowComment,
      processId: processId,
      actionValue: actionValue,
      processActionId: processActionId,
      processName: processName,
      menuId: menuId,
      moduleId: moduleId,
      refid: refid,
      distributorName: distributorName,
      salesRepName: salesRepName,
      approvedBy: approvedBy,
      approvedDate: approvedDate,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toApprovalJson() => {
        'Id': id,
        'CreatedBy': createdBy,
        'Status': status ?? 0,
        'Company': company,
        'Bizunit': bizunit,
        'SbuId': sbuId ?? 0,
        'RowNumber': rowNumber ?? 0,
        'SaleOrderNo': saleOrderNo,
        'DetailId': detailId,
        'Date': SalesOrderBonusApprovalActionRequest._normalizeIsoDate(date),
        'Division': division,
        'DivisionText': divisionText,
        'Item': item,
        'ItemCode': itemCode,
        'ItemName': itemName,
        'CustomerName': customerName,
        'Customer': customer,
        'QuantityOrdered': quantityOrdered,
        'QuantityApproved': quantityApproved,
        'BonusQuantity': bonusQuantity,
        'AdditionalQuantity': additionalQuantity,
        'AdditionalQuantityApproved': additionalQuantityApproved,
        'Rate': rate,
        'NetAmount': netAmount,
        'CreatedDate':
            SalesOrderBonusApprovalActionRequest._normalizeIsoDate(createdDate),
        'UserId': userId,
        'PageType': pageType,
        'WorkflowFlag': workflowFlag,
        'WorkflowStatus': workflowStatus,
        'WorkflowComment': workflowComment,
        'ProcessId': processId,
        'ActionValue': actionValue,
        'ProcessActionId': processActionId,
        'ProcessName': processName,
        'MenuId': menuId,
        'ModuleId': moduleId,
        'Refid': refid,
        'IsSelected': false,
        'DistributorName': distributorName,
        'SalesRepName': salesRepName,
        'ApprovedBy': approvedBy,
        'ApprovedDate':
            SalesOrderBonusApprovalActionRequest._normalizeIsoDate(approvedDate),
        'ApprovedDateTime':
            SalesOrderBonusApprovalActionRequest._normalizeIsoDate(approvedDate),
      };
}

class SalesOrderBonusApprovalActionRequest {
  final int createdBy;
  final String createdDate;
  final int sbuId;
  final int userId;
  final int bizunit;
  final List<SalesOrderBonusApprovalItem> selectedItems;

  SalesOrderBonusApprovalActionRequest({
    required this.createdBy,
    required this.createdDate,
    required this.sbuId,
    required this.userId,
    required this.bizunit,
    required this.selectedItems,
  });

  Map<String, dynamic> toJson() => {
        'Id': null,
        'CreatedBy': createdBy,
        'CreatedDate': _normalizeIsoDate(createdDate),
        'ModifiedBy': null,
        'ModifiedDate': null,
        'IsActive': true,
        'SbuId': sbuId,
        'Status': 0,
        'UserId': userId,
        'MenuId': null,
        'Url': null,
        'Bizunit': bizunit,
        'SelectedItems': selectedItems.map((e) => e.toApprovalJson()).toList(),
      };

  /// Server is strict about date-time format for this endpoint.
  /// Normalizes to `yyyy-MM-ddTHH:mm:ss.SSS` when possible.
  static String? _normalizeIsoDate(dynamic input) {
    if (input == null) return null;
    final raw = input.toString().trim();
    if (raw.isEmpty) return null;

    // Replace space separator with 'T' (e.g. "2026-04-16 19:39:45.045068")
    var s = raw.contains(' ') && !raw.contains('T') ? raw.replaceFirst(' ', 'T') : raw;

    // If it has fractional seconds, trim to 3 digits.
    final dot = s.indexOf('.');
    if (dot != -1) {
      final end = s.indexOf(RegExp(r'[Z\+\-]'), dot); // timezone or Z
      final fracEnd = end == -1 ? s.length : end;
      final frac = s.substring(dot + 1, fracEnd);
      if (frac.length > 3) {
        s = s.substring(0, dot + 1) + frac.substring(0, 3) + s.substring(fracEnd);
      } else if (frac.length < 3) {
        s = s.substring(0, dot + 1) + frac.padRight(3, '0') + s.substring(fracEnd);
      }
      return s;
    }

    // If it's an ISO timestamp without fractional seconds, add ".000".
    if (s.contains('T') && RegExp(r'T\d{2}:\d{2}:\d{2}$').hasMatch(s)) {
      return '$s.000';
    }

    // If it already includes time but no fraction (e.g. "...:00"), add ".000".
    if (RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}').hasMatch(s)) {
      return s.replaceFirstMapped(
        RegExp(r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?!\.)'),
        (m) => '${m[1]}.000',
      );
    }

    return s;
  }
}
