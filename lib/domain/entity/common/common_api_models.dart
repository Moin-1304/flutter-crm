// Common API Models for dropdown data
class CommonGetAutoRequest {
  final int commandType;
  final int? role;
  final int? id;
  final int? countryId;
  final int? employeeId;
  final int? bizUnit;
  final int? userId;
  final String? date;

  CommonGetAutoRequest({
    required this.commandType,
    this.role,
    this.id,
    this.countryId,
    this.employeeId,
    this.bizUnit,
    this.userId,
    this.date,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'CommandType': commandType,
    };
    
    if (role != null) data['Role'] = role;
    if (id != null) data['Id'] = id;
    if (countryId != null) data['CountryId'] = countryId;
    if (employeeId != null) data['EmployeeId'] = employeeId;
    if (bizUnit != null) data['BizUnit'] = bizUnit;
    if (userId != null) data['UserId'] = userId;
    if (date != null) data['Date'] = date;
    
    return data;
  }
}

/// Request model for Tour Plan Products to Discuss (CommandType: 335)
class TourPlanProductsRequest {
  final int userId;

  TourPlanProductsRequest({required this.userId});

  Map<String, dynamic> toJson() {
    return {
      'SearchText': null,
      'Id': null,
      'TransactionId': null,
      'UserId': userId,
      'CommandType': 335,
      'CommandText': null,
      'Value': null,
      'CountryId': null,
      'Key': null,
      'Text': null,
      'Type': null,
      'TaxFlag': 0,
      'SubType': null,
      'RoleMapList': null,
      'CategoryId': null,
      'ClusterId': null,
      'EmployeeId': null,
      'PageUrl': null,
      'IncludeCancelled': false,
      'Program': null,
      'Category': null,
      'Status': null,
      'FromDate': null,
      'ToDate': null,
      'ReportName': null,
      'IsOrganizationUser': null,
      'ItemGroupName': null,
      'Active': null,
      'ConstantMasterPk': null,
      'ConstantMasterActive': null,
      'ConstantMasterGroup': null,
      'ConstantMasterGroupValue': null,
      'ConstantMasterGroupTypeValue': null,
      'TypeValue': null,
      'SbuId': null,
      'LsmLine': null,
      'LsmListType': null,
      'LineId': null,
      'Item': null,
      'Date': null,
      'Department': null,
      'ItemGrade': null,
      'Process': null,
      'Surface': null,
      'Colour': null,
      'Thickness': null,
      'Sterile': null,
      'Nature': null,
      'Grade': null,
      'Length': null,
      'Chlorination': null,
      'Size': null,
      'AdditionalSpec1': null,
      'ProductGroupId': null,
      'SpecialCondition': null,
      'P_COA_SUB_TYPE': null,
      'Group': null,
      'GroupType': null,
      'Name': null,
      'CityId': null,
      'StateId': null,
      'DistributerId': null,
      'TaxCategory': null,
      'OnlyParent': null,
      'DesignationCode': null,
      'DistrictId': null,
      'TownId': null,
      'BizUnit': null,
      'ProcessId': null,
      'FieldName': null,
      'Sector': 0,
      'ConstantMasterParent': null,
      'Vendor': null,
      'ReceiveType': null,
      'Module': null,
      'Flag': null,
      'CustomerId': null,
      'Customer': null,
      'DespatchNo': null,
      'SurveyType': null,
      'PageName': null,
      'Mode': null,
      'Division': null,
      'DivisionGroup': null,
      'Role': null,
      'TypeId': null,
      'PageType': null,
      'IsTax': null,
      'CategoryAccountType': null,
      'AddressLine1': null,
      'AddressLine2': null,
      'AddressLine3': null,
      'PostalCode': null,
      'VehicleNo': null,
      'StatusType': null,
      'CurrentStatusID': null,
      'ProcessType': null,
      'IsMaterialIssue': false,
      'IsItemIssue': false,
      'ReferenceType': null,
      'TransactionType': null,
      'ManufacturerMasterDoc': null,
      'BrandName': null,
      'AccountSubType': null,
      'IsFromAMCUser': 0,
      'IsContra': null,
      'receiveSubType': null,
      'IssueId': null,
      'CustomerSelectedList': null,
    };
  }
}

/// Request model for Customer Type (CommandType: 230)
class CustomerTypeRequest {
  final int userId;
  final String type;

  CustomerTypeRequest({required this.userId, this.type = 'Service Engineer'});

  Map<String, dynamic> toJson() {
    return {
      'SearchText': null,
      'Id': null,
      'TransactionId': null,
      'UserId': userId,
      'CommandType': 230,
      'CommandText': null,
      'Value': null,
      'CountryId': null,
      'Key': null,
      'Text': null,
      'Type': type,
      'TaxFlag': 0,
      'SubType': null,
      'RoleMapList': null,
      'CategoryId': null,
      'ClusterId': null,
      'EmployeeId': null,
      'PageUrl': null,
      'IncludeCancelled': false,
      'Program': null,
      'Category': null,
      'Status': null,
      'FromDate': null,
      'ToDate': null,
      'ReportName': null,
      'IsOrganizationUser': null,
      'ItemGroupName': null,
      'Active': null,
      'ConstantMasterPk': null,
      'ConstantMasterActive': null,
      'ConstantMasterGroup': null,
      'ConstantMasterGroupValue': null,
      'ConstantMasterGroupTypeValue': null,
      'TypeValue': null,
      'SbuId': null,
      'LsmLine': null,
      'LsmListType': null,
      'LineId': null,
      'Item': null,
      'Date': null,
      'Department': null,
      'ItemGrade': null,
      'Process': null,
      'Surface': null,
      'Colour': null,
      'Thickness': null,
      'Sterile': null,
      'Nature': null,
      'Grade': null,
      'Length': null,
      'Chlorination': null,
      'Size': null,
      'AdditionalSpec1': null,
      'ProductGroupId': null,
      'SpecialCondition': null,
      'P_COA_SUB_TYPE': null,
      'Group': null,
      'GroupType': null,
      'Name': null,
      'CityId': null,
      'StateId': null,
      'DistributerId': null,
      'TaxCategory': null,
      'OnlyParent': null,
      'DesignationCode': null,
      'DistrictId': null,
      'TownId': null,
      'BizUnit': null,
      'ProcessId': null,
      'FieldName': null,
      'Sector': 0,
      'ConstantMasterParent': null,
      'Vendor': null,
      'ReceiveType': null,
      'Module': null,
      'Flag': null,
      'CustomerId': null,
      'Customer': null,
      'DespatchNo': null,
      'SurveyType': null,
      'PageName': null,
      'Mode': null,
      'Division': null,
      'DivisionGroup': null,
      'Role': null,
      'TypeId': null,
      'PageType': null,
      'IsTax': null,
      'CategoryAccountType': null,
      'AddressLine1': null,
      'AddressLine2': null,
      'AddressLine3': null,
      'PostalCode': null,
      'VehicleNo': null,
      'StatusType': null,
      'CurrentStatusID': null,
      'ProcessType': null,
      'IsMaterialIssue': false,
      'IsItemIssue': false,
      'ReferenceType': null,
      'TransactionType': null,
      'ManufacturerMasterDoc': null,
      'BrandName': null,
      'AccountSubType': null,
      'IsFromAMCUser': null,
      'IsContra': null,
      'receiveSubType': null,
      'IssueId': null,
      'CustomerSelectedList': null,
    };
  }
}

/// Request model for Purpose of Visit (CommandType: 337)
class PurposeOfVisitRequest {
  final int userId;
  final String text; // "ServiceEng PurposeVisit" or "Salesrep PurposeVisit"

  PurposeOfVisitRequest({required this.userId, required this.text});

  Map<String, dynamic> toJson() {
    return {
      'SearchText': null,
      'Id': null,
      'TransactionId': null,
      'UserId': userId,
      'CommandType': 337,
      'CommandText': null,
      'Value': null,
      'CountryId': null,
      'Key': null,
      'Text': text,
      'Type': null,
      'TaxFlag': 0,
      'SubType': null,
      'RoleMapList': null,
      'CategoryId': null,
      'ClusterId': null,
      'EmployeeId': null,
      'PageUrl': null,
      'IncludeCancelled': false,
      'Program': null,
      'Category': null,
      'Status': null,
      'FromDate': null,
      'ToDate': null,
      'ReportName': null,
      'IsOrganizationUser': null,
      'ItemGroupName': null,
      'Active': null,
      'ConstantMasterPk': null,
      'ConstantMasterActive': null,
      'ConstantMasterGroup': null,
      'ConstantMasterGroupValue': null,
      'ConstantMasterGroupTypeValue': null,
      'TypeValue': null,
      'SbuId': null,
      'LsmLine': null,
      'LsmListType': null,
      'LineId': null,
      'Item': null,
      'Date': null,
      'Department': null,
      'ItemGrade': null,
      'Process': null,
      'Surface': null,
      'Colour': null,
      'Thickness': null,
      'Sterile': null,
      'Nature': null,
      'Grade': null,
      'Length': null,
      'Chlorination': null,
      'Size': null,
      'AdditionalSpec1': null,
      'ProductGroupId': null,
      'SpecialCondition': null,
      'P_COA_SUB_TYPE': null,
      'Group': null,
      'GroupType': null,
      'Name': null,
      'CityId': null,
      'StateId': null,
      'DistributerId': null,
      'TaxCategory': null,
      'OnlyParent': null,
      'DesignationCode': null,
      'DistrictId': null,
      'TownId': null,
      'BizUnit': null,
      'ProcessId': null,
      'FieldName': null,
      'Sector': 0,
      'ConstantMasterParent': null,
      'Vendor': null,
      'ReceiveType': null,
      'Module': null,
      'Flag': null,
      'CustomerId': null,
      'Customer': null,
      'DespatchNo': null,
      'SurveyType': null,
      'PageName': null,
      'Mode': null,
      'Division': null,
      'DivisionGroup': null,
      'Role': null,
      'TypeId': null,
      'PageType': null,
      'IsTax': null,
      'CategoryAccountType': null,
      'AddressLine1': null,
      'AddressLine2': null,
      'AddressLine3': null,
      'PostalCode': null,
      'VehicleNo': null,
      'StatusType': null,
      'CurrentStatusID': null,
      'ProcessType': null,
      'IsMaterialIssue': false,
      'IsItemIssue': false,
      'ReferenceType': null,
      'TransactionType': null,
      'ManufacturerMasterDoc': null,
      'BrandName': null,
      'AccountSubType': null,
      'IsFromAMCUser': null,
      'IsContra': null,
      'receiveSubType': null,
      'IssueId': null,
      'CustomerSelectedList': null,
    };
  }
}

class CommonDropdownItem {
  final int id;
  final String text;
  final int doubleTank;
  final int virtual;
  final int version;
  final String compoundStartDate;
  final String compoundEndDate;
  final String name;
  final int stock;
  final String address;
  final int uom;
  final int hasChild;
  final int hasInstrument;
  final int category;
  final String employeeName;
  final String accountNo;
  final String branch;
  final String manufacturerName;
  final String manufacturerCountry;
  final int account;
  final int pageType;
  final String no;
  final int value;
  final String expiryDate;
  final int accountSubType;
  final int totalAmount;
  final int balanceAmount;
  final String cityName;
  final int rate;
  final String typeText;
  final int currency;
  final int type;
  final int days;
  final String invoiceNo;
  final int invoiceId;
  final int saleInvoiceDetailId;
  final int level;
  final int divisionGroupId;
  final String currencyText;
  final String decimalFormat;
  final String rateFormat;
  final String code;
  final String addressLine1;
  final String addressLine2;
  final String addressLine3;
  final String postalCode;
  final int countryId;
  final int stateId;
  final int cityId;
  final String packSize;
  final String hsCode;
  final String taxNumber;
  final int role;
  final String customer;
  final String planDate;
  final String designation;
  final String stateText;
  final int clusterId;
  final int subType;
  final int isReceiptBatchRequired;
  final int displayOrder;

  CommonDropdownItem({
    required this.id,
    required this.text,
    required this.doubleTank,
    required this.virtual,
    required this.version,
    required this.compoundStartDate,
    required this.compoundEndDate,
    required this.name,
    required this.stock,
    required this.address,
    required this.uom,
    required this.hasChild,
    required this.hasInstrument,
    required this.category,
    required this.employeeName,
    required this.accountNo,
    required this.branch,
    required this.manufacturerName,
    required this.manufacturerCountry,
    required this.account,
    required this.pageType,
    required this.no,
    required this.value,
    required this.expiryDate,
    required this.accountSubType,
    required this.totalAmount,
    required this.balanceAmount,
    required this.cityName,
    required this.rate,
    required this.typeText,
    required this.currency,
    required this.type,
    required this.days,
    required this.invoiceNo,
    required this.invoiceId,
    required this.saleInvoiceDetailId,
    required this.level,
    required this.divisionGroupId,
    required this.currencyText,
    required this.decimalFormat,
    required this.rateFormat,
    required this.code,
    required this.addressLine1,
    required this.addressLine2,
    required this.addressLine3,
    required this.postalCode,
    required this.countryId,
    required this.stateId,
    required this.cityId,
    required this.packSize,
    required this.hsCode,
    required this.taxNumber,
    required this.role,
    required this.customer,
    required this.planDate,
    required this.designation,
    required this.stateText,
    required this.clusterId,
    required this.subType,
    required this.isReceiptBatchRequired,
    required this.displayOrder,
  });

  factory CommonDropdownItem.fromJson(Map<String, dynamic> json) {
    return CommonDropdownItem(
      id: json['id'] ?? 0,
      text: json['text'] ?? '',
      doubleTank: json['doubleTank'] ?? 0,
      virtual: json['virtual'] ?? 0,
      version: json['version'] ?? 0,
      compoundStartDate: json['compoundStartDate'] ?? '',
      compoundEndDate: json['compoundEndDate'] ?? '',
      name: json['name'] ?? '',
      stock: json['stock'] ?? 0,
      address: json['address'] ?? '',
      uom: json['uom'] ?? 0,
      hasChild: json['hasChild'] ?? 0,
      hasInstrument: json['hasInstrument'] ?? 0,
      category: json['category'] ?? 0,
      employeeName: json['employeeName'] ?? '',
      accountNo: json['accountNo'] ?? '',
      branch: json['branch'] ?? '',
      manufacturerName: json['manufacturerName'] ?? '',
      manufacturerCountry: json['manufacturerCountry'] ?? '',
      account: json['account'] ?? 0,
      pageType: json['pageType'] ?? 0,
      no: json['no'] ?? '',
      value: json['value'] ?? 0,
      expiryDate: json['expiryDate'] ?? '',
      accountSubType: json['accountSubType'] ?? 0,
      totalAmount: json['totalAmount'] ?? 0,
      balanceAmount: json['balanceAmount'] ?? 0,
      cityName: json['cityName'] ?? '',
      rate: json['rate'] ?? 0,
      typeText: json['typeText'] ?? '',
      currency: json['currency'] ?? 0,
      type: json['type'] ?? 0,
      days: json['days'] ?? 0,
      invoiceNo: json['invoiceNo'] ?? '',
      invoiceId: json['invoiceId'] ?? 0,
      saleInvoiceDetailId: json['saleInvoiceDetailId'] ?? 0,
      level: json['level'] ?? 0,
      divisionGroupId: json['divisionGroupId'] ?? 0,
      currencyText: json['currencyText'] ?? '',
      decimalFormat: json['decimalFormat'] ?? '',
      rateFormat: json['rateFormat'] ?? '',
      code: json['code'] ?? '',
      addressLine1: json['addressLine1'] ?? '',
      addressLine2: json['addressLine2'] ?? '',
      addressLine3: json['addressLine3'] ?? '',
      postalCode: json['postalCode'] ?? '',
      countryId: json['countryId'] ?? 0,
      stateId: json['stateId'] ?? 0,
      cityId: json['cityId'] ?? 0,
      packSize: json['packSize'] ?? '',
      hsCode: json['hsCode'] ?? '',
      taxNumber: json['taxNumber'] ?? '',
      role: json['role'] ?? 0,
      customer: json['customer'] ?? '',
      planDate: json['planDate'] ?? '',
      designation: json['designation'] ?? '',
      stateText: json['stateText'] ?? '',
      clusterId: json['clusterId'] ?? 0,
      subType: json['subType'] ?? 0,
      isReceiptBatchRequired: json['isReceiptBatchRequired'] ?? 0,
      displayOrder: json['displayOrder'] ?? 0,
    );
  }
}
