import 'package:boilerplate/domain/entity/common/common_api_models.dart'
    show CommonDropdownItem, TaxComponentResponse, ItemDetailResponse;

abstract class CommonRepository {
  Future<List<CommonDropdownItem>> getEmployeeList({int? employeeId});
  Future<List<CommonDropdownItem>> getTourPlanEmployeeList();
  Future<List<CommonDropdownItem>> getEmployeesReportingTo(int id);
  Future<List<CommonDropdownItem>> getClusterList(
      int countryId, int employeeId);
  Future<List<CommonDropdownItem>> getTypeOfWorkList();
  Future<List<CommonDropdownItem>> getTourPlanStatusList();
  Future<List<CommonDropdownItem>> getExpenseTypeList();
  Future<List<CommonDropdownItem>> getDcrDetailStatusList();
  Future<List<CommonDropdownItem>> getDeviationStatusList(int bizUnit);
  Future<List<CommonDropdownItem>> getDeviationTypeList();
  Future<List<CommonDropdownItem>> getDcrListForEmployee(
      int userId, int employeeId, int bizUnit);
  Future<List<CommonDropdownItem>> getDeviationEmployeesReportingTo(int id);
  Future<List<CommonDropdownItem>> getTourPlanDropdown({
    required int userId,
    required int employeeId,
    required int bizUnit,
    required String date,
  });
  Future<List<CommonDropdownItem>> getTourPlanProductsList(int userId,
      {int? isFromAMCUser});
  Future<List<CommonDropdownItem>> getDcrProductsList(int userId);
  Future<List<CommonDropdownItem>> getMappedInstrumentsList(
      int userId, int customerId);
  Future<List<CommonDropdownItem>> getDeviationInstrumentsList(int userId);
  Future<List<CommonDropdownItem>> getDeviationSerialNumbersList({
    required int instrumentId,
    required String toDate,
    required int bizUnit,
    int module = 6,
  });
  Future<List<CommonDropdownItem>> getCustomerTypeList(int userId,
      {String type = 'Service Engineer'});
  Future<List<CommonDropdownItem>> getPurposeOfVisitList(
      int userId, String text);
  Future<List<CommonDropdownItem>> getStoreList();
  Future<List<CommonDropdownItem>> getIssueToList(int userId, int bizUnit);
  Future<List<CommonDropdownItem>> getIssueAgainstList();
  Future<List<CommonDropdownItem>> getDivisionCategoryList();
  Future<List<CommonDropdownItem>> getCustomerList({
    required int bizUnit,
    int? customerId,
    String? searchText,
    int? userId,
    int? distributerId,
    int? customer,
    int? sector,
    int? taxFlag,
    bool? includeCancelled,
    int? id,
    int? transactionId,
    int? countryId,
    int? clusterId,
    int? employeeId,
    String? pageUrl,
    int? sbuId,
    int? cityId,
    int? stateId,
    int? districtId,
    int? townId,
    int? module,
  });
  Future<List<CommonDropdownItem>> getItemDescriptionList(
    int? divisionId, {
    required int bizUnit,
    int? divisionGroup,
    int? distributerId,
    String? searchText,
  });
  Future<List<CommonDropdownItem>> getMappedCustomersByEmployeeId({
    String? searchText,
    int? pageNumber,
    int? pageSize,
    int? employeeId,
    int? clusterId,
    int? customerTypeId,
    int? id,
  });
  Future<List<CommonDropdownItem>> getBatchNoList({
    required int itemId,
    required int employeeId,
    required String toDate,
    required int bizUnit,
    int module = 13,
    int transactionType = 12,
  });
  Future<List<CommonDropdownItem>> getReportingManagerList({
    required int id,
  });
  Future<List<CommonDropdownItem>> getSalesRepList({
    required int userId,
    required int customerId,
  });
  Future<List<CommonDropdownItem>> getDistributorList({
    required int bizUnit,
    required int customerId,
  });
  Future<List<CommonDropdownItem>> getItemList({
    required int distributerId,
    String? searchText,
  });
  Future<List<CommonDropdownItem>> getUOMList({
    required int itemId,
  });
  Future<List<CommonDropdownItem>> getItemTaxList({
    required int itemId,
  });
  Future<List<CommonDropdownItem>> getTaxListForTaxSection();
  Future<List<CommonDropdownItem>> getDiscountListForTaxSection();
  Future<List<TaxComponentResponse>> getTaxComponentFormulas({
    required int id,
    int? userId,
    int pageNumber = 0,
    int pageSize = 0,
    String? searchText,
    int sortOrder = 0,
    int sortDir = 0,
    String? sortField,
    String? json,
    String? filterExpression,
    int? pageId,
    int? type,
  });
  Future<ItemDetailResponse> getItemDetail({
    required int itemId,
    required String date,
    required int customerId,
  });

  /// Generic GetAuto call by CommandType
  Future<List<CommonDropdownItem>> getCommonAuto(int commandType,
      {int? userId});
}
