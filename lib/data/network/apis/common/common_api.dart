import 'package:dio/dio.dart';
import '../../../../core/data/network/dio/dio_client.dart';
import '../../constants/endpoints.dart';
import '../../../../domain/entity/common/common_api_models.dart';

class CommonApi {
  final DioClient _dioClient;

  CommonApi(this._dioClient);

  /// Get dropdown data using Common/GetAuto endpoint
  Future<List<CommonDropdownItem>> getAuto(CommonGetAutoRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.commonGetAuto,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        if (response.data is List) {
          return (response.data as List)
              .map((item) => CommonDropdownItem.fromJson(item))
              .toList();
        } else {
          throw Exception('Invalid response format - expected array');
        }
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to get dropdown data: ${e.toString()}');
    }
  }

  /// Get Employee List (CommandType: 106 or 276 if employeeId is provided)
  /// If employeeId is provided, uses CommandType 276 with the employeeId
  Future<List<CommonDropdownItem>> getEmployeeList({int? employeeId}) async {
    if (employeeId != null) {
      final request = CommonGetAutoRequest(commandType: 276, id: employeeId);
      return getAuto(request);
    } else {
      final request = CommonGetAutoRequest(commandType: 106);
      return getAuto(request);
    }
  }

  /// Get Tour Plan Employee List (CommandType: 278, Role: 2)
  Future<List<CommonDropdownItem>> getTourPlanEmployeeList() async {
    final request = CommonGetAutoRequest(commandType: 278, role: 2);
    return getAuto(request);
  }

  /// Get Employees Reporting To (CommandType: 276)
  Future<List<CommonDropdownItem>> getEmployeesReportingTo(int id) async {
    final request = CommonGetAutoRequest(commandType: 276, id: id);
    return getAuto(request);
  }

  /// Get Cluster List (CommandType: 279)
  Future<List<CommonDropdownItem>> getClusterList(int countryId, int employeeId) async {
    final request = CommonGetAutoRequest(
      commandType: 279,
      countryId: countryId,
      employeeId: employeeId,
    );
    return getAuto(request);
  }

  /// Get Type of Work List (CommandType: 280)
  Future<List<CommonDropdownItem>> getTypeOfWorkList() async {
    final request = CommonGetAutoRequest(commandType: 280);
    return getAuto(request);
  }

  /// Get Tour Plan Status List (CommandType: 313)
  Future<List<CommonDropdownItem>> getTourPlanStatusList() async {
    final request = CommonGetAutoRequest(commandType: 313);
    return getAuto(request);
  }

  /// Get Expense Type List (CommandType: 289)
  Future<List<CommonDropdownItem>> getExpenseTypeList() async {
    final request = CommonGetAutoRequest(commandType: 289);
    return getAuto(request);
  }

  /// Get DCR Detail Status List (CommandType: 305)
  Future<List<CommonDropdownItem>> getDcrDetailStatusList() async {
    final request = CommonGetAutoRequest(commandType: 305);
    return getAuto(request);
  }

  /// Get Deviation Status List (CommandType: 303)
  Future<List<CommonDropdownItem>> getDeviationStatusList(int bizUnit) async {
    final request = CommonGetAutoRequest(commandType: 303, bizUnit: bizUnit);
    return getAuto(request);
  }

  /// Get Deviation Type List (CommandType: 281)
  Future<List<CommonDropdownItem>> getDeviationTypeList() async {
    final request = CommonGetAutoRequest(commandType: 281);
    return getAuto(request);
  }

  /// Get DCR List for Employee (CommandType: 290)
  Future<List<CommonDropdownItem>> getDcrListForEmployee(int userId, int employeeId, int bizUnit) async {
    final request = CommonGetAutoRequest(
      commandType: 290,
      userId: userId,
      employeeId: employeeId,
      bizUnit: bizUnit,
    );
    return getAuto(request);
  }

  /// Get Tour Plan dropdown list for deviation entry (CommandType: 290 with Date)
  Future<List<CommonDropdownItem>> getTourPlanDropdown({
    required int userId,
    required int employeeId,
    required int bizUnit,
    required String date,
  }) async {
    final request = CommonGetAutoRequest(
      commandType: 290,
      userId: userId,
      employeeId: employeeId,
      bizUnit: bizUnit,
      date: date,
    );
    return getAuto(request);
  }

  /// Get Deviation Employees Reporting To (CommandType: 320)
  Future<List<CommonDropdownItem>> getDeviationEmployeesReportingTo(int id) async {
    final request = CommonGetAutoRequest(commandType: 320, id: id);
    return getAuto(request);
  }

  /// Get Purpose of Visit List (CommandType: 337)
  /// text should be "ServiceEng PurposeVisit" for Service Engineer or "Salesrep PurposeVisit" for Sales Rep
  Future<List<CommonDropdownItem>> getPurposeOfVisitList(int userId, String text) async {
    try {
      final request = PurposeOfVisitRequest(userId: userId, text: text);
      final response = await _dioClient.dio.post(
        Endpoints.commonGetAuto,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        if (response.data is List) {
          return (response.data as List)
              .map((item) => CommonDropdownItem.fromJson(item))
              .toList();
        } else {
          throw Exception('Invalid response format - expected array');
        }
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to get purpose of visit list: ${e.toString()}');
    }
  }

  /// Get Customer Type List (CommandType: 230)
  Future<List<CommonDropdownItem>> getCustomerTypeList(int userId, {String type = 'Service Engineer'}) async {
    try {
      final request = CustomerTypeRequest(userId: userId, type: type);
      final response = await _dioClient.dio.post(
        Endpoints.commonGetAuto,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        if (response.data is List) {
          return (response.data as List)
              .map((item) => CommonDropdownItem.fromJson(item))
              .toList();
        } else {
          throw Exception('Invalid response format - expected array');
        }
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to get customer type list: ${e.toString()}');
    }
  }

  /// Get Tour Plan Products to Discuss (CommandType: 335)
  Future<List<CommonDropdownItem>> getTourPlanProductsList(int userId, {int? isFromAMCUser}) async {
    try {
      final request = TourPlanProductsRequest(userId: userId, isFromAMCUser: isFromAMCUser);
      final response = await _dioClient.dio.post(
        Endpoints.commonGetAuto,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        if (response.data is List) {
          return (response.data as List)
              .map((item) => CommonDropdownItem.fromJson(item))
              .toList();
        } else {
          throw Exception('Invalid response format - expected array');
        }
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to get tour plan products: ${e.toString()}');
    }
  }

  /// Get DCR Products to Discuss (CommandType: 335)
  /// Only UserId is dynamic, IsFromAMCUser is always 0
  Future<List<CommonDropdownItem>> getDcrProductsList(int userId) async {
    try {
      final request = DcrProductsRequest(userId: userId);
      final response = await _dioClient.dio.post(
        Endpoints.commonGetAuto,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        if (response.data is List) {
          return (response.data as List)
              .map((item) => CommonDropdownItem.fromJson(item))
              .toList();
        } else {
          throw Exception('Invalid response format - expected array');
        }
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to get DCR products: ${e.toString()}');
    }
  }

  /// Get Mapped Instruments (CommandType: 335)
  /// UserId is dynamic, IsFromAMCUser is always 1, CustomerSelectedList contains customerId
  Future<List<CommonDropdownItem>> getMappedInstrumentsList(int userId, int customerId) async {
    try {
      final request = MappedInstrumentsRequest(userId: userId, customerId: customerId);
      final response = await _dioClient.dio.post(
        Endpoints.commonGetAuto,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        if (response.data is List) {
          return (response.data as List)
              .map((item) => CommonDropdownItem.fromJson(item))
              .toList();
        } else {
          throw Exception('Invalid response format - expected array');
        }
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to get mapped instruments: ${e.toString()}');
    }
  }
}
