import 'dart:convert';
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
  Future<List<CommonDropdownItem>> getClusterList(
      int countryId, int employeeId) async {
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
  Future<List<CommonDropdownItem>> getDcrListForEmployee(
      int userId, int employeeId, int bizUnit) async {
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
  Future<List<CommonDropdownItem>> getDeviationEmployeesReportingTo(
      int id) async {
    final request = CommonGetAutoRequest(commandType: 320, id: id);
    return getAuto(request);
  }

  /// Get Purpose of Visit List (CommandType: 337)
  /// text should be "ServiceEng PurposeVisit" for Service Engineer or "Salesrep PurposeVisit" for Sales Rep
  Future<List<CommonDropdownItem>> getPurposeOfVisitList(
      int userId, String text) async {
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
  Future<List<CommonDropdownItem>> getCustomerTypeList(int userId,
      {String type = 'Service Engineer'}) async {
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
  Future<List<CommonDropdownItem>> getTourPlanProductsList(int userId,
      {int? isFromAMCUser}) async {
    try {
      final request =
          TourPlanProductsRequest(userId: userId, isFromAMCUser: isFromAMCUser);
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
  Future<List<CommonDropdownItem>> getMappedInstrumentsList(
      int userId, int customerId) async {
    try {
      final request =
          MappedInstrumentsRequest(userId: userId, customerId: customerId);
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

  /// Get Store List (CommandType: 127, SpecialCondition: "SC")
  /// Returns list of stores for From Store and To Store dropdowns
  Future<List<CommonDropdownItem>> getStoreList() async {
    try {
      final request = StoreListRequest();
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
      throw Exception('Failed to get store list: ${e.toString()}');
    }
  }

  /// Get Issue To List (CommandType: 150)
  /// Returns list of issue-to options for Issue To dropdown
  Future<List<CommonDropdownItem>> getIssueToList(
      int userId, int bizUnit) async {
    try {
      final request = IssueToListRequest(userId: userId, bizUnit: bizUnit);
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
      throw Exception('Failed to get issue-to list: ${e.toString()}');
    }
  }

  /// Get Issue Against List (CommandType: 102, Type: "Stock Transfer", SpecialCondition: "Customer")
  /// Returns list of issue-against options for Issue Against dropdown
  Future<List<CommonDropdownItem>> getIssueAgainstList() async {
    try {
      final request = IssueAgainstListRequest();
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
      throw Exception('Failed to get issue-against list: ${e.toString()}');
    }
  }

  /// Get Division/Category List (CommandType: 215)
  /// Returns list of division/category options for Add Item dialog
  Future<List<CommonDropdownItem>> getDivisionCategoryList() async {
    try {
      final request = DivisionCategoryRequest();
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
      throw Exception('Failed to get division/category list: ${e.toString()}');
    }
  }

  /// Get Item Description List (CommandType: 105)
  /// Returns list of item descriptions based on selected Division ID
  Future<List<CommonDropdownItem>> getItemDescriptionList(
      int divisionId) async {
    try {
      final request = ItemDescriptionRequest(divisionId: divisionId);
      final requestJson = request.toJson();
      final requestJsonString =
          const JsonEncoder.withIndent('  ').convert(requestJson);

      print('\n');
      print('═══════════════════════════════════════════════════════════════');
      print('🔵 ITEM DESCRIPTION API REQUEST');
      print('═══════════════════════════════════════════════════════════════');
      print('📡 Endpoint: POST ${Endpoints.commonGetAuto}');
      print('📋 Request Headers:');
      print('   Content-Type: application/json');
      print('');
      print('📦 Request Body (JSON):');
      print(requestJsonString);
      print('');
      print('🔑 Key Parameters:');
      print('   CommandType: ${requestJson['CommandType']}');
      print('   Division: ${requestJson['Division']}');
      print('   DivisionId: $divisionId');
      print('═══════════════════════════════════════════════════════════════');
      print('');

      final response = await _dioClient.dio.post(
        Endpoints.commonGetAuto,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      // Print API Response Details
      print('═══════════════════════════════════════════════════════════════');
      print('🟢 ITEM DESCRIPTION API RESPONSE');
      print('═══════════════════════════════════════════════════════════════');
      print('📊 Status Code: ${response.statusCode}');
      print('📋 Response Headers:');
      if (response.headers.map.isNotEmpty) {
        response.headers.map.forEach((key, value) {
          print('   $key: ${value.join(", ")}');
        });
      }
      print('');

      if (response.data != null) {
        print('📦 Response Data Type: ${response.data.runtimeType}');

        if (response.data is List) {
          final responseList = response.data as List;
          print('📊 Total Items: ${responseList.length}');
          print('');
          print('📋 Response Body (JSON):');

          // Pretty print the response
          final responseJsonString =
              const JsonEncoder.withIndent('  ').convert(response.data);
          print(responseJsonString);
          print('');

          // Print first few items in detail
          if (responseList.isNotEmpty) {
            print(
                '📝 Sample Items (first ${responseList.length > 3 ? 3 : responseList.length}):');
            for (int i = 0; i < responseList.length && i < 3; i++) {
              final item = responseList[i];
              print('   Item ${i + 1}:');
              if (item is Map) {
                print('     id: ${item['id']}');
                print('     text: ${item['text']}');
                if (item.containsKey('code'))
                  print('     code: ${item['code']}');
                if (item.containsKey('name'))
                  print('     name: ${item['name']}');
                if (item.containsKey('uom')) print('     uom: ${item['uom']}');
                if (item.containsKey('stock'))
                  print('     stock: ${item['stock']}');
                if (item.containsKey('rate'))
                  print('     rate: ${item['rate']}');
              } else {
                print('     $item');
              }
            }
            if (responseList.length > 3) {
              print('   ... and ${responseList.length - 3} more items');
            }
          } else {
            print('⚠️  No item descriptions found in response');
          }
        } else {
          print('📋 Response Body:');
          final responseJsonString =
              const JsonEncoder.withIndent('  ').convert(response.data);
          print(responseJsonString);
        }
      } else {
        print('⚠️  No response data received');
      }
      print('═══════════════════════════════════════════════════════════════');
      print('');

      if (response.data != null) {
        if (response.data is List) {
          final items = (response.data as List)
              .map((item) => CommonDropdownItem.fromJson(item))
              .toList();
          print('✅ Successfully parsed ${items.length} item description items');
          print('');
          return items;
        } else {
          print('❌ Invalid response format - expected array');
          throw Exception('Invalid response format - expected array');
        }
      } else {
        print('❌ No response data received');
        throw Exception('No response data received');
      }
    } catch (e) {
      print('❌ [CommonApi] Item Description API Exception: ${e.toString()}');
      throw Exception('Failed to get item description list: ${e.toString()}');
    }
  }

  /// Get Batch No List (CommandType: 332)
  /// Returns list of batch numbers based on selected Item ID
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
      final request = BatchNoRequest(
        itemId: itemId,
        employeeId: employeeId,
        toDate: toDate,
        bizUnit: bizUnit,
        module: module,
        customerId: customerId,
        transactionType: transactionType,
      );

      // Print API Request Details
      final requestJson = request.toJson();
      final requestJsonString =
          const JsonEncoder.withIndent('  ').convert(requestJson);

      print('\n');
      print('═══════════════════════════════════════════════════════════════');
      print('🔵 BATCH NO API REQUEST (GetAutoBigInt)');
      print('═══════════════════════════════════════════════════════════════');
      print('📡 Endpoint: POST ${Endpoints.commonGetAutoBigInt}');
      print('📋 Request Headers:');
      print('   Content-Type: application/json');
      print('');
      print('📦 Request Body (JSON):');
      print(requestJsonString);
      print('');
      print('🔑 Key Parameters:');
      print('   CommandType: ${requestJson['CommandType']}');
      print('   Id (ItemId): ${requestJson['Id']}');
      print('   EmployeeId: ${requestJson['EmployeeId']}');
      print('   ToDate: ${requestJson['ToDate']}');
      print('   BizUnit: ${requestJson['BizUnit']}');
      print('   Module: ${requestJson['Module']}');
      print('   CustomerId: ${requestJson['CustomerId']}');
      print('   TransactionType: ${requestJson['TransactionType']}');
      print('═══════════════════════════════════════════════════════════════');
      print('');

      final response = await _dioClient.dio.post(
        Endpoints.commonGetAutoBigInt,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      // Print API Response Details
      print('═══════════════════════════════════════════════════════════════');
      print('🟢 BATCH NO API RESPONSE');
      print('═══════════════════════════════════════════════════════════════');
      print('📊 Status Code: ${response.statusCode}');
      print('📋 Response Headers:');
      if (response.headers.map.isNotEmpty) {
        response.headers.map.forEach((key, value) {
          print('   $key: ${value.join(", ")}');
        });
      }
      print('');

      if (response.data != null) {
        print('📦 Response Data Type: ${response.data.runtimeType}');

        if (response.data is List) {
          final responseList = response.data as List;
          print('📊 Total Items: ${responseList.length}');
          print('');
          print('📋 Response Body (JSON):');

          // Pretty print the response
          final responseJsonString =
              const JsonEncoder.withIndent('  ').convert(response.data);
          print(responseJsonString);
          print('');

          // Print first few items in detail
          if (responseList.isNotEmpty) {
            print(
                '📝 Sample Items (first ${responseList.length > 3 ? 3 : responseList.length}):');
            for (int i = 0; i < responseList.length && i < 3; i++) {
              final item = responseList[i];
              print('   Item ${i + 1}:');
              if (item is Map) {
                print('     id: ${item['id']}');
                print('     text: ${item['text']}');
                if (item.containsKey('stock'))
                  print('     stock: ${item['stock']}');
                if (item.containsKey('expiryDate'))
                  print('     expiryDate: ${item['expiryDate']}');
                if (item.containsKey('name'))
                  print('     name: ${item['name']}');
              } else {
                print('     $item');
              }
            }
            if (responseList.length > 3) {
              print('   ... and ${responseList.length - 3} more items');
            }
          } else {
            print('⚠️  No batch numbers found in response');
          }
        } else {
          print('📋 Response Body:');
          final responseJsonString =
              const JsonEncoder.withIndent('  ').convert(response.data);
          print(responseJsonString);
        }
      } else {
        print('⚠️  No response data received');
      }
      print('═══════════════════════════════════════════════════════════════');
      print('');

      if (response.data != null) {
        if (response.data is List) {
          final items = (response.data as List)
              .map((item) => CommonDropdownItem.fromJson(item))
              .toList();
          print('✅ Successfully parsed ${items.length} batch number items');
          print('');
          return items;
        } else {
          print(
              '❌ [CommonApi] Batch No API Error - Invalid response format (expected array)');
          throw Exception('Invalid response format - expected array');
        }
      } else {
        print('❌ [CommonApi] Batch No API Error - No response data received');
        throw Exception('No response data received');
      }
    } catch (e) {
      print('❌ [CommonApi] Batch No API Exception: ${e.toString()}');
      throw Exception('Failed to get batch no list: ${e.toString()}');
    }
  }

  /// Get Reporting Manager List (CommandType: 333, Id: 91)
  /// Returns list of reporting managers for co-visit dropdown
  Future<List<CommonDropdownItem>> getReportingManagerList() async {
    try {
      final request = ReportingManagerRequest();
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
      throw Exception('Failed to get reporting manager list: ${e.toString()}');
    }
  }
}
