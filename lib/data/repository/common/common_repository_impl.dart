import 'package:boilerplate/data/network/apis/common/common_api.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
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
      int countryId, int employeeId) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getClusterList(countryId, employeeId);
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
      // API get tour plan products list failed
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
      // API get DCR products list failed
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
  Future<List<CommonDropdownItem>> getItemDescriptionList(
      int divisionId) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getItemDescriptionList(divisionId);
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
    required int customerId,
    int module = 6,
    int transactionType = 14,
  }) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();

        final response = await commonApi.getBatchNoList(
          itemId: itemId,
          employeeId: employeeId,
          toDate: toDate,
          bizUnit: bizUnit,
          customerId: customerId,
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
}
