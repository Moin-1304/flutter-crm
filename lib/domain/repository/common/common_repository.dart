import 'package:boilerplate/domain/entity/common/common_api_models.dart';

abstract class CommonRepository {
  Future<List<CommonDropdownItem>> getEmployeeList({int? employeeId});
  Future<List<CommonDropdownItem>> getTourPlanEmployeeList();
  Future<List<CommonDropdownItem>> getEmployeesReportingTo(int id);
  Future<List<CommonDropdownItem>> getClusterList(int countryId, int employeeId);
  Future<List<CommonDropdownItem>> getTypeOfWorkList();
  Future<List<CommonDropdownItem>> getTourPlanStatusList();
  Future<List<CommonDropdownItem>> getExpenseTypeList();
  Future<List<CommonDropdownItem>> getDcrDetailStatusList();
  Future<List<CommonDropdownItem>> getDeviationStatusList(int bizUnit);
  Future<List<CommonDropdownItem>> getDeviationTypeList();
  Future<List<CommonDropdownItem>> getDcrListForEmployee(int userId, int employeeId, int bizUnit);
  Future<List<CommonDropdownItem>> getDeviationEmployeesReportingTo(int id);
  Future<List<CommonDropdownItem>> getTourPlanDropdown({
    required int userId,
    required int employeeId,
    required int bizUnit,
    required String date,
  });
  Future<List<CommonDropdownItem>> getTourPlanProductsList(int userId);
  Future<List<CommonDropdownItem>> getCustomerTypeList(int userId, {String type = 'Service Engineer'});
  Future<List<CommonDropdownItem>> getPurposeOfVisitList(int userId, String text);
}
