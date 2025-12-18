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
          final response = await commonApi.getEmployeeList(employeeId: employeeId);
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
  Future<List<CommonDropdownItem>> getClusterList(int countryId, int employeeId) async {
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
  Future<List<CommonDropdownItem>> getDcrListForEmployee(int userId, int employeeId, int bizUnit) async {
    try {
      if (getIt.isRegistered<CommonApi>()) {
        final commonApi = getIt<CommonApi>();
        
        final response = await commonApi.getDcrListForEmployee(userId, employeeId, bizUnit);
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
  Future<List<CommonDropdownItem>> getDeviationEmployeesReportingTo(int id) async {
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
}
