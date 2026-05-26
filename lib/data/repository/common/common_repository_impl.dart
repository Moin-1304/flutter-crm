import 'package:boilerplate/data/network/apis/common/common_api.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart'
    show
        CommonDropdownItem,
        TaxComponentResponse,
        ItemDetailResponse,
        CommonGetAutoRequest;
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/di/service_locator.dart';

class CommonRepositoryImpl implements CommonRepository {
  @override
  Future<List<CommonDropdownItem>> getEmployeeList({int? employeeId}) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        if (employeeId != null) {
          final response =
              await commonApi.getEmployeeList(employeeId: employeeId);
          return response;
        } else {
          final response = await commonApi.getEmployeeList();
          return response;
        }
      }
    } catch (e) {
      // API get employee list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getTourPlanEmployeeList() async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getTourPlanEmployeeList();
        return response;
      }
    } catch (e) {
      // API get tour plan employee list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getEmployeesReportingTo(int id) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getEmployeesReportingTo(id);
        return response;
      }
    } catch (e) {
      // API get employees reporting to failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getClusterList(
      int countryId, int employeeId,
      {String? planDate}) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getClusterList(
          countryId,
          employeeId,
          planDate: planDate,
        );
        return response;
      }
    } catch (e) {
      // API get cluster list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getTypeOfWorkList() async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getTypeOfWorkList();
        return response;
      }
    } catch (e) {
      // API get type of work list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getTourPlanStatusList() async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getTourPlanStatusList();
        return response;
      }
    } catch (e) {
      // API get tour plan status list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getExpenseTypeList() async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getExpenseTypeList();
        return response;
      }
    } catch (e) {
      // API get expense type list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getDcrDetailStatusList() async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getDcrDetailStatusList();
        return response;
      }
    } catch (e) {
      // API get DCR detail status list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getDeviationStatusList(int bizUnit) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getDeviationStatusList(bizUnit);
        return response;
      }
    } catch (e) {
      // API get deviation status list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getDeviationTypeList() async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getDeviationTypeList();
        return response;
      }
    } catch (e) {
      // API get deviation type list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getDcrListForEmployee(
      int userId, int employeeId, int bizUnit) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response =
            await commonApi.getDcrListForEmployee(userId, employeeId, bizUnit);
        return response;
      }
    } catch (e) {
      // API get DCR list for employee failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getTourPlanDropdown({
    required int userId,
    required int employeeId,
    required int bizUnit,
    required String date,
  }) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getTourPlanDropdown(
          userId: userId,
          employeeId: employeeId,
          bizUnit: bizUnit,
          date: date,
        );
        return response;
      }
    } catch (e) {
      // API get tour plan dropdown failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getDeviationEmployeesReportingTo(
      int id) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getDeviationEmployeesReportingTo(id);
        return response;
      }
    } catch (e) {
      // API get deviation employees reporting to failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getTourPlanProductsList(int userId,
      {int? isFromAMCUser}) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getTourPlanProductsList(userId,
            isFromAMCUser: isFromAMCUser);
        return response;
      }
    } catch (e) {
      print('CommonRepositoryImpl: Error getting tour plan products: $e');
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getDcrProductsList(int userId) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getDcrProductsList(userId);
        return response;
      }
    } catch (e) {
      print('CommonRepositoryImpl: Error getting DCR products: $e');
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getMappedInstrumentsList(
      int userId, int customerId) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response =
            await commonApi.getMappedInstrumentsList(userId, customerId);
        return response;
      }
    } catch (e) {
      // API get mapped instruments list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getDeviationInstrumentsList(
      int userId) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();
        final response = await commonApi.getDeviationInstrumentsList(userId);
        return response;
      }
    } catch (e) {
      print('Error getting deviation instruments list: $e');
    }
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getDeviationSerialNumbersList({
    required int instrumentId,
    required String toDate,
    required int bizUnit,
    int module = 6,
  }) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();
        final response = await commonApi.getDeviationSerialNumbersList(
          instrumentId: instrumentId,
          toDate: toDate,
          bizUnit: bizUnit,
          module: module,
        );
        return response;
      }
    } catch (e) {
      print('Error getting deviation serial numbers list: $e');
    }
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getCustomerTypeList(int userId,
      {String type = 'Service Engineer'}) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response =
            await commonApi.getCustomerTypeList(userId, type: type);
        return response;
      }
    } catch (e) {
      // API get customer type list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getPurposeOfVisitList(
      int userId, String text) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getPurposeOfVisitList(userId, text);
        return response;
      }
    } catch (e) {
      // API get purpose of visit list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getStoreList() async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getStoreList();
        return response;
      }
    } catch (e) {
      // API get store list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getIssueToList(
      int userId, int bizUnit) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getIssueToList(userId, bizUnit);
        return response;
      }
    } catch (e) {
      // API get issue-to list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getIssueAgainstList() async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getIssueAgainstList();
        return response;
      }
    } catch (e) {
      // API get issue-against list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getDivisionCategoryList() async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getDivisionCategoryList();
        return response;
      }
    } catch (e) {
      // API get division/category list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
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
  }) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();
        final response = await commonApi.getCustomerList(
          bizUnit: bizUnit,
          customerId: customerId,
          searchText: searchText,
          userId: userId,
          distributerId: distributerId,
          customer: customer,
          sector: sector,
          taxFlag: taxFlag,
          includeCancelled: includeCancelled,
          id: id,
          transactionId: transactionId,
          countryId: countryId,
          clusterId: clusterId,
          employeeId: employeeId,
          pageUrl: pageUrl,
          sbuId: sbuId,
          cityId: cityId,
          stateId: stateId,
          districtId: districtId,
          townId: townId,
          module: module,
        );
        return response;
      }
    } catch (e) {
      // API get customer list failed
    }
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getMappedCustomersByEmployeeId({
    String? searchText,
    int? pageNumber,
    int? pageSize,
    int? employeeId,
    int? clusterId,
    int? customerTypeId,
    int? id,
  }) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();
        final response = await commonApi.getMappedCustomersByEmployeeId(
          searchText: searchText,
          pageNumber: pageNumber,
          pageSize: pageSize,
          employeeId: employeeId,
          clusterId: clusterId,
          customerTypeId: customerTypeId,
          id: id,
        );
        return response;
      }
    } catch (e) {
      print('Error getting mapped customers: $e');
    }
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getItemDescriptionList(
    int? divisionId, {
    required int bizUnit,
    int? divisionGroup,
    int? distributerId,
    String? searchText,
  }) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getItemDescriptionList(
          divisionId,
          bizUnit: bizUnit,
          divisionGroup: divisionGroup,
          distributerId: distributerId,
          searchText: searchText,
        );
        return response;
      }
    } catch (e) {
      // API get item description list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getBatchNoList({
    required int itemId,
    required int employeeId,
    required String toDate,
    required int bizUnit,
    int module = 13,
    int transactionType = 12,
  }) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getBatchNoList(
          itemId: itemId,
          employeeId: employeeId,
          toDate: toDate,
          bizUnit: bizUnit,
          module: module,
          transactionType: transactionType,
        );
        return response;
      }
    } catch (e) {
      // API get batch no list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getReportingManagerList({
    required int id,
  }) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getReportingManagerList(id: id);
        return response;
      }
    } catch (e) {
      // API get reporting manager list failed
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getSalesRepList({
    required int userId,
    required int customerId,
  }) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getSalesRepList(
          userId: userId,
          customerId: customerId,
        );
        return response;
      }
    } catch (e) {
      // API get sales rep list failed
      print('Error getting sales rep list: $e');
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getDistributorList({
    required int bizUnit,
    required int customerId,
  }) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getDistributorList(
          bizUnit: bizUnit,
          customerId: customerId,
        );
        return response;
      }
    } catch (e) {
      // API get distributor list failed
      print('Error getting distributor list: $e');
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getItemList({
    required int distributerId,
    String? searchText,
  }) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getItemList(
          distributerId: distributerId,
          searchText: searchText,
        );
        return response;
      }
    } catch (e) {
      // API get item list failed
      print('Error getting item list: $e');
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<ItemDetailResponse> getItemDetail({
    required int itemId,
    required String date,
    required int customerId,
  }) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();
        return await commonApi.getItemDetail(
          itemId: itemId,
          date: date,
          customerId: customerId,
        );
      }
    } catch (e) {
      print('Error getting item detail: $e');
    }
    throw Exception('Failed to get item detail');
  }

  @override
  Future<List<CommonDropdownItem>> getCommonAuto(int commandType,
      {int? userId}) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();
        final request =
            CommonGetAutoRequest(commandType: commandType, userId: userId);
        return await commonApi.getAuto(request);
      }
    } catch (e) {
      print('Error getting common auto for commandType $commandType: $e');
    }
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getUOMList({
    required int itemId,
  }) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getUOMList(
          itemId: itemId,
        );
        return response;
      }
    } catch (e) {
      // Check if it's a connection error (expected and handled gracefully)
      final isConnectionError = e.toString().contains('Connection refused') ||
          e.toString().contains('connection error') ||
          e.toString().contains('SocketException');

      if (!isConnectionError) {
        // Only log non-connection errors (connection errors are already logged in API layer)
        print('⚠️ [Repository] UOM List API error: ${e.toString()}');
      }
      // Fallback to empty list if API fails - this will preserve existing UOM or use defaults
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getItemTaxList({
    required int itemId,
  }) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getItemTaxList(
          itemId: itemId,
        );
        return response;
      }
    } catch (e) {
      // API get item tax list failed
      print('Error getting item tax list: $e');
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getTaxListForTaxSection() async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();
        final response = await commonApi.getTaxListForTaxSection();
        return response;
      }
    } catch (e) {
      // API get tax list failed
      print('Error getting tax list for tax section: $e');
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<CommonDropdownItem>> getDiscountListForTaxSection() async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();
        final response = await commonApi.getDiscountListForTaxSection();
        return response;
      }
    } catch (e) {
      // API get discount list failed
      print('Error getting discount list for tax section: $e');
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
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
  }) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();
        final response = await commonApi.getTaxComponentFormulas(
          id: id,
          userId: userId,
          pageNumber: pageNumber,
          pageSize: pageSize,
          searchText: searchText,
          sortOrder: sortOrder,
          sortDir: sortDir,
          sortField: sortField,
          json: json,
          filterExpression: filterExpression,
          pageId: pageId,
          type: type,
        );
        return response;
      }
    } catch (e) {
      // API get tax component formulas failed
      print('Error getting tax component formulas: $e');
    }

    // Fallback to empty list if API fails
    return [];
  }
}
