// Common API Models for dropdown data
class CommonGetAutoRequest {
  final int commandType;
  final int? value;
  final int? role;
  final int? id;
  final int? countryId;
  final int? employeeId;
  final int? bizUnit;
  final int? userId;
  final String? date;
  final int? customer;
  final int? customerId;
  final int? distributerId;
  final String? searchText;
  final int? item;
  final int? pageType;
  final String? planDate;

  CommonGetAutoRequest({
    required this.commandType,
    this.value,
    this.role,
    this.id,
    this.countryId,
    this.employeeId,
    this.bizUnit,
    this.userId,
    this.date,
    this.customer,
    this.customerId,
    this.distributerId,
    this.searchText,
    this.item,
    this.pageType,
    this.planDate,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'CommandType': commandType,
    };

    if (value != null) data['Value'] = value;
    if (role != null) data['Role'] = role;
    if (id != null) data['Id'] = id;
    if (countryId != null) data['CountryId'] = countryId;
    if (employeeId != null) data['EmployeeId'] = employeeId;
    if (bizUnit != null) data['BizUnit'] = bizUnit;
    if (userId != null) data['UserId'] = userId;
    if (date != null) data['Date'] = date;
    if (customer != null) data['Customer'] = customer;
    if (customerId != null) data['CustomerId'] = customerId;
    if (distributerId != null) data['DistributerId'] = distributerId;
    if (searchText != null) data['SearchText'] = searchText;
    if (item != null) data['Item'] = item;
    if (pageType != null) data['PageType'] = pageType;
    if (planDate != null) data['PlanDate'] = planDate;

    return data;
  }
}

/// Request model for Tour Plan Products to Discuss (CommandType: 335)
class TourPlanProductsRequest {
  final int userId;
  final int? isFromAMCUser;

  TourPlanProductsRequest({required this.userId, this.isFromAMCUser});

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
      'IsFromAMCUser': isFromAMCUser,
      'IsContra': null,
      'receiveSubType': null,
      'IssueId': null,
      'CustomerSelectedList': null,
    };
  }
}

/// Request model for DCR Products to Discuss (CommandType: 335)
/// Only UserId is dynamic, IsFromAMCUser is always 0
class DcrProductsRequest {
  final int userId;

  DcrProductsRequest({required this.userId});

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

/// Request model for Instruments (CommandType: 335) for Deviation
/// Matches the curl request: UserId, IsFromAMCUser: 1
class DeviationInstrumentRequest {
  final int userId;

  DeviationInstrumentRequest({required this.userId});

  Map<String, dynamic> toJson() {
    return {
      'SearchText': null,
      'Id': null,
      'TransactionId': null,
      'UserId': userId,
      'CommandType': 335,
      'TaxFlag': 0,
      'IncludeCancelled': false,
      'Sector': 0,
      'IsMaterialIssue': false,
      'IsItemIssue': false,
      'IsFromAMCUser': 1,
    };
  }
}

/// Request model for Serial Numbers (CommandType: 146) using GetAutoBigInt
/// Matches the curl request: Id (instrument ID), ToDate, BizUnit, Sector: 0, Module: 6
class DeviationSerialNumberRequest {
  final int id; // Instrument ID
  final String toDate; // Format: "yyyy-MM-dd"
  final int bizUnit;
  final int module; // 6 for Deviation

  DeviationSerialNumberRequest({
    required this.id,
    required this.toDate,
    required this.bizUnit,
    this.module = 6,
  });

  Map<String, dynamic> toJson() {
    return {
      'SearchText': null,
      'Id': id,
      'CommandType': 146,
      'TaxFlag': 0,
      'IncludeCancelled': false,
      'ToDate': toDate,
      'BizUnit': bizUnit,
      'Sector': 0,
      'Module': module,
      'IsMaterialIssue': false,
      'IsItemIssue': false,
    };
  }
}

/// Request model for Mapped Instruments (CommandType: 335)
/// UserId is dynamic, IsFromAMCUser is always 1, CustomerSelectedList contains selected customer
class MappedInstrumentsRequest {
  final int userId;
  final int customerId;

  MappedInstrumentsRequest({required this.userId, required this.customerId});

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
      'IsFromAMCUser': 1,
      'IsContra': null,
      'receiveSubType': null,
      'IssueId': null,
      'CustomerSelectedList': [
        {
          'CustomerId': customerId,
        }
      ],
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

/// Request model for Store List (CommandType: 127, SpecialCondition: "SC")
class StoreListRequest {
  StoreListRequest();

  Map<String, dynamic> toJson() {
    return {
      'SearchText': null,
      'Id': null,
      'TransactionId': null,
      'UserId': null,
      'CommandType': 127,
      'CommandText': null,
      'Value': null,
      'CountryId': null,
      'Key': null,
      'Text': null,
      'Type': '',
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
      'SpecialCondition': 'SC',
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

/// Request model for Issue To List (CommandType: 150)
class IssueToListRequest {
  final int userId;
  final int bizUnit;

  IssueToListRequest({required this.userId, required this.bizUnit});

  Map<String, dynamic> toJson() {
    return {
      'SearchText': null,
      'Id': null,
      'TransactionId': null,
      'UserId': userId,
      'CommandType': 150,
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
      'BizUnit': bizUnit,
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

/// Request model for Issue Against List (CommandType: 102, Type: "Stock Transfer", SpecialCondition: "Customer")
class IssueAgainstListRequest {
  IssueAgainstListRequest();

  Map<String, dynamic> toJson() {
    return {
      'SearchText': null,
      'Id': null,
      'TransactionId': null,
      'UserId': null,
      'CommandType': 102,
      'CommandText': null,
      'Value': null,
      'CountryId': null,
      'Key': null,
      'Text': null,
      'Type': 'Stock Transfer',
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
      'SpecialCondition': 'Customer',
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

/// Request model for Division/Category List (CommandType: 215)
class DivisionCategoryRequest {
  DivisionCategoryRequest();

  Map<String, dynamic> toJson() {
    return {
      'SearchText': null,
      'Id': null,
      'TransactionId': null,
      'UserId': null,
      'CommandType': 215,
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
      'IsFromAMCUser': null,
      'IsContra': null,
      'receiveSubType': null,
      'IssueId': null,
      'CustomerSelectedList': null,
    };
  }
}

/// Request model for Item Description List (CommandType: 105)
/// Can use either DivisionId or DistributerId
class ItemDescriptionRequest {
  final int? divisionId;
  final int? bizUnit;
  final int? divisionGroup;
  final int? distributerId;
  final String? searchText;

  ItemDescriptionRequest({
    this.divisionId,
    this.bizUnit,
    this.divisionGroup,
    this.distributerId,
    this.searchText,
  });

  Map<String, dynamic> toJson() {
    return {
      'SearchText': searchText,
      'Id': null,
      'TransactionId': null,
      'UserId': null,
      'CommandType': 105,
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
      'DistributerId': distributerId,
      'TaxCategory': null,
      'OnlyParent': null,
      'DesignationCode': null,
      'DistrictId': null,
      'TownId': null,
      'BizUnit': bizUnit,
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
      'Division': divisionId,
      'DivisionGroup': divisionGroup,
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

/// Request model for Batch No List (CommandType: 332)
/// Requires Item ID from selected Item Description
class BatchNoRequest {
  final int itemId;
  final int employeeId;
  final String toDate; // Format: "yyyy-MM-dd'T'HH:mm:ss.SSS"
  final int bizUnit;
  final int module; // 13 for Sample Issue
  final int transactionType; // 12 for Sample Issue

  BatchNoRequest({
    required this.itemId,
    required this.employeeId,
    required this.toDate,
    required this.bizUnit,
    this.module = 13,
    this.transactionType = 12,
  });

  Map<String, dynamic> toJson() {
    return {
      'SearchText': null,
      'Id': itemId,
      'TransactionId': null,
      'UserId': null,
      'CommandType': 332,
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
      'EmployeeId': employeeId,
      'PageUrl': null,
      'IncludeCancelled': false,
      'Program': null,
      'Category': null,
      'Status': null,
      'FromDate': null,
      'ToDate': toDate,
      'BizUnit': bizUnit,
      'ProcessId': null,
      'FieldName': null,
      'Sector': 0,
      'ConstantMasterParent': null,
      'Vendor': null,
      'ReceiveType': null,
      'Module': module,
      'TransactionType': transactionType,
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

/// Request model for Customer List (CommandType: 71)
class CustomerListRequest {
  final int bizUnit;
  final int? customerId;
  final String? searchText;
  final int? userId;
  final int? distributerId;
  final int? customer;
  final int sector;
  final int taxFlag;
  final bool includeCancelled;
  final int? id;
  final int? transactionId;
  final int? countryId;
  final int? clusterId;
  final int? employeeId;
  final String? pageUrl;
  final int? sbuId;
  final int? cityId;
  final int? stateId;
  final int? districtId;
  final int? townId;
  final int? module;

  CustomerListRequest({
    required this.bizUnit,
    this.customerId,
    this.searchText,
    this.userId,
    this.distributerId,
    this.customer,
    this.sector = 0,
    this.taxFlag = 0,
    this.includeCancelled = false,
    this.id,
    this.transactionId,
    this.countryId,
    this.clusterId,
    this.employeeId,
    this.pageUrl,
    this.sbuId,
    this.cityId,
    this.stateId,
    this.districtId,
    this.townId,
    this.module,
  });

  Map<String, dynamic> toJson() {
    return {
      'SearchText': searchText,
      'Id': id,
      'TransactionId': transactionId,
      'UserId': userId,
      'CommandType': 71,
      'CommandText': null,
      'Value': null,
      'CountryId': countryId,
      'Key': null,
      'Text': null,
      'Type': null,
      'TaxFlag': taxFlag,
      'SubType': null,
      'RoleMapList': null,
      'CategoryId': null,
      'ClusterId': clusterId,
      'EmployeeId': employeeId,
      'PageUrl': pageUrl,
      'IncludeCancelled': includeCancelled,
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
      'SbuId': sbuId,
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
      'CityId': cityId,
      'StateId': stateId,
      'DistributerId': distributerId,
      'TaxCategory': null,
      'OnlyParent': null,
      'DesignationCode': null,
      'DistrictId': districtId,
      'TownId': townId,
      'BizUnit': bizUnit,
      'ProcessId': null,
      'FieldName': null,
      'Sector': sector,
      'ConstantMasterParent': null,
      'Vendor': null,
      'ReceiveType': null,
      'Module': module,
      'Flag': null,
      'CustomerId': customerId,
      'Customer': customer,
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

/// Request model for Reporting Manager List (CommandType: 333, Id: 91)
class ReportingManagerRequest {
  final int? id;
  ReportingManagerRequest({
    this.id,
  });

  Map<String, dynamic> toJson() {
    return {
      'SearchText': null,
      'Id': id,
      'TransactionId': null,
      'UserId': null,
      'CommandType': 333,
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
  final double rate;
  final String typeText;
  final int currency;
  final int type;
  final int days;
  final String invoiceNo;
  final int invoiceId;
  final int saleInvoiceDetailId;
  final int item;
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
  final bool bonusEnabled;
  final bool isSelected;
  final int? repType;

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
    required this.item,
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
    this.bonusEnabled = false,
    this.isSelected = false,
    this.repType,
  });

  factory CommonDropdownItem.fromJson(Map<String, dynamic> json) {
    return CommonDropdownItem(
      id: json['id'] ?? json['Id'] ?? 0,
      text: json['text'] ?? json['Text'] ?? '',
      doubleTank: json['doubleTank'] ?? 0,
      virtual: json['virtual'] ?? 0,
      version: json['version'] ?? 0,
      compoundStartDate: json['compoundStartDate'] ?? '',
      compoundEndDate: json['compoundEndDate'] ?? '',
      name: json['name'] ?? json['Name'] ?? '',
      stock: json['stock'] ??
          json['Stock'] ??
          json['quantityInStock'] ??
          json['QuantityInStock'] ??
          0, // Support both 'stock' and 'quantityInStock'
      address: json['address'] ?? '',
      uom: json['uom'] ?? json['UOM'] ?? json['Uom'] ?? 0,
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
      value: json['value'] ?? json['Value'] ?? 0,
      expiryDate: json['expiryDate'] ?? '',
      accountSubType: json['accountSubType'] ?? 0,
      totalAmount: json['totalAmount'] ?? 0,
      balanceAmount: json['balanceAmount'] ?? 0,
      cityName: json['cityName'] ?? '',
      rate: json['rate'] != null
          ? (json['rate'] is int
              ? json['rate'].toDouble()
              : (json['rate'] as num).toDouble())
          : json['Rate'] != null
              ? (json['Rate'] is int
                  ? json['Rate'].toDouble()
                  : (json['Rate'] as num).toDouble())
          : 0.0,
      typeText: json['typeText'] ?? json['TypeText'] ?? '',
      currency: json['currency'] ?? 0,
      type: json['type'] ?? 0,
      days: json['days'] ?? 0,
      invoiceNo: json['invoiceNo'] ?? '',
      invoiceId: json['invoiceId'] ?? 0,
      saleInvoiceDetailId: json['saleInvoiceDetailId'] ?? 0,
      item: json['Item'] ?? json['item'] ?? json['ProductId'] ?? json['productId'] ?? 0,
      level: json['level'] ?? 0,
      divisionGroupId: json['divisionGroupId'] ?? json['DivisionGroupId'] ?? 0,
      currencyText: json['currencyText'] ?? '',
      decimalFormat: json['decimalFormat'] ?? '',
      rateFormat: json['rateFormat'] ?? '',
      code: json['code'] ?? json['Code'] ?? '',
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
      bonusEnabled: json['bonusEnabled'] == true ||
          json['BonusEnabled'] == true ||
          json['bonusEnabled'] == 1 ||
          json['BonusEnabled'] == 1,
      isSelected: json['isSelected'] == true ||
          json['IsSelected'] == true ||
          json['isSelected'] == 1 ||
          json['IsSelected'] == 1,
      repType: _parseOptionalInt(json['repType'] ?? json['RepType']),
    );
  }

  static int? _parseOptionalInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

/// Tax Component Request Model
class TaxComponentRequest {
  final int id;
  final int? userId;
  final int pageNumber;
  final int pageSize;
  final String? searchText;
  final int sortOrder;
  final int sortDir;
  final String? sortField;
  final String? json;
  final String? filterExpression;
  final int? pageId;
  final int? type;

  TaxComponentRequest({
    required this.id,
    this.userId,
    this.pageNumber = 0,
    this.pageSize = 0,
    this.searchText,
    this.sortOrder = 0,
    this.sortDir = 0,
    this.sortField,
    this.json,
    this.filterExpression,
    this.pageId,
    this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'UserId': userId,
      'PageNumber': pageNumber,
      'PageSize': pageSize,
      'SearchText': searchText,
      'SortOrder': sortOrder,
      'SortDir': sortDir,
      'SortField': sortField,
      'Json': json,
      'FilterExpression': filterExpression,
      'PageId': pageId,
      'Type': type,
    };
  }
}

/// Tax Component Response Model
class TaxComponentResponse {
  final int id;
  final int
      chargesType; // 1=SubTotal, 2=Discount, 3=OtherCharge, 4=Tax, 5=PriceAdjustment, 6=GrandTotal, 7=ShippingCharge, 8=DedAdvPaid
  final String? formula;
  final String? label;
  final int? displayOrder;
  final bool? isActive;
  final String? description;

  TaxComponentResponse({
    required this.id,
    required this.chargesType,
    this.formula,
    this.label,
    this.displayOrder,
    this.isActive,
    this.description,
  });

  factory TaxComponentResponse.fromJson(Map<String, dynamic> json) {
    return TaxComponentResponse(
      id: json['id'] ?? 0,
      chargesType: json['chargesType'] ?? json['ChargesType'] ?? 0,
      formula: json['formula'] ?? json['Formula'],
      label: json['label'] ?? json['Label'],
      displayOrder: json['displayOrder'] ?? json['DisplayOrder'],
      isActive: json['isActive'] ?? json['IsActive'],
      description: json['description'] ?? json['Description'],
    );
  }
}

/// ChargesType Enum Helper
enum ChargesType {
  subTotal(1),
  discount(2),
  otherCharge(3),
  tax(4),
  priceAdjustment(5),
  grandTotal(6),
  shippingCharge(7),
  dedAdvPaid(8);

  final int value;
  const ChargesType(this.value);

  static ChargesType? fromInt(int? value) {
    if (value == null) return null;
    return ChargesType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ChargesType.subTotal,
    );
  }
}

/// Item Detail Response Model from Common/GetItemDetail endpoint
class ItemDetailResponse {
  final int? item;
  final double? rate;
  final double? retailRate;
  final double? mrp;
  final double? unitPrice;
  final int? uom;
  final String? uomText;
  final double? discount;
  final double? amount;
  final String? itemText;
  final String? manufacturerName;
  final int? divisionGroup;
  final String? divisionGroupText;
  final double? quantity;
  final double? bonusQuantity;
  final double? additionalBonusQuantity;
  final bool? isFOC;
  final bool? isRateUpdateConfirm;
  final String? reqdDate;
  final Map<String, dynamic>? otherFields;

  ItemDetailResponse({
    this.item,
    this.rate,
    this.retailRate,
    this.mrp,
    this.unitPrice,
    this.uom,
    this.uomText,
    this.discount,
    this.amount,
    this.itemText,
    this.manufacturerName,
    this.divisionGroup,
    this.divisionGroupText,
    this.quantity,
    this.bonusQuantity,
    this.additionalBonusQuantity,
    this.isFOC,
    this.isRateUpdateConfirm,
    this.reqdDate,
    this.otherFields,
  });

  factory ItemDetailResponse.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse numbers
    num? parseNum(dynamic value) {
      if (value == null) return null;
      if (value is num) return value;
      if (value is String) {
        final parsed = num.tryParse(value);
        return parsed;
      }
      return null;
    }

    // Helper to safely parse doubles
    double? parseDouble(dynamic value) {
      final numValue = parseNum(value);
      return numValue?.toDouble();
    }

    // Helper to safely parse ints
    int? parseInt(dynamic value) {
      final numValue = parseNum(value);
      return numValue?.toInt();
    }

    // Helper to safely parse bools
    bool? parseBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is int) return value != 0;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      return null;
    }

    return ItemDetailResponse(
      item: parseInt(json['Item'] ?? json['item']),
      rate: parseDouble(json['Rate'] ??
          json['rate'] ??
          json['WholesaleRate'] ??
          json['wholesaleRate']),
      retailRate: parseDouble(json['RetailRate'] ?? json['retailRate']),
      mrp: parseDouble(json['MRP'] ?? json['mrp'] ?? json['MaxRetailPrice']),
      unitPrice: parseDouble(json['UnitPrice'] ??
          json['unitPrice'] ??
          json['Price'] ??
          json['rate'] ??
          json['Rate']),
      uom: parseInt(json['UOM'] ?? json['uom'] ?? json['Uom']),
      uomText: json['UOMText']?.toString() ??
          json['uomText']?.toString() ??
          json['UomText']?.toString(),
      discount: parseDouble(json['Discount'] ?? json['discount']),
      amount: parseDouble(json['Amount'] ?? json['amount']),
      itemText: json['ItemText']?.toString() ?? json['itemText']?.toString(),
      manufacturerName: json['ManufacturerName']?.toString() ??
          json['manufacturerName']?.toString(),
      divisionGroup: parseInt(json['DivisionGroup'] ?? json['divisionGroup']),
      divisionGroupText: json['DivisionGroupText']?.toString() ??
          json['divisionGroupText']?.toString(),
      quantity: parseDouble(json['Quantity'] ?? json['quantity']),
      bonusQuantity:
          parseDouble(json['BonusQuantity'] ?? json['bonusQuantity']),
      additionalBonusQuantity: parseDouble(
          json['AdditionalBonusQuantity'] ?? json['additionalBonusQuantity']),
      isFOC: parseBool(json['IsFOC'] ?? json['isFOC']),
      isRateUpdateConfirm:
          parseBool(json['IsRateUpdateConfirm'] ?? json['isRateUpdateConfirm']),
      reqdDate: json['ReqdDate']?.toString() ?? json['reqdDate']?.toString(),
      otherFields: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Item': item,
      'Rate': rate,
      'RetailRate': retailRate,
      'MRP': mrp,
      'UnitPrice': unitPrice,
      'UOM': uom,
      'UOMText': uomText,
      'Discount': discount,
      'Amount': amount,
      'ItemText': itemText,
      'ManufacturerName': manufacturerName,
      'DivisionGroup': divisionGroup,
      'DivisionGroupText': divisionGroupText,
      'Quantity': quantity,
      'BonusQuantity': bonusQuantity,
      'AdditionalBonusQuantity': additionalBonusQuantity,
      'IsFOC': isFOC,
      'IsRateUpdateConfirm': isRateUpdateConfirm,
      'ReqdDate': reqdDate,
      ...?otherFields,
    };
  }
}
