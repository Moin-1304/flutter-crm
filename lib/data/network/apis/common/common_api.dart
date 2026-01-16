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
      print('getMappedInstrumentsList: userId: $userId, customerId: $customerId');
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
      final requestPayload = request.toJson();
      
      // Print API request details with formatted JSON
      print('═══════════════════════════════════════════════════════════');
      print('📤 Issue To List API Request');
      print('═══════════════════════════════════════════════════════════');
      print('URL: ${Endpoints.commonGetAuto}');
      print('Method: POST');
      print('Headers: Content-Type: application/json');
      print('');
      print('Request Payload (as formatted JSON):');
      try {
        final jsonEncoder = JsonEncoder.withIndent('  ');
        print(jsonEncoder.convert(requestPayload));
      } catch (e) {
        // Fallback to regular print if jsonEncode fails
        print(requestPayload);
      }
      print('');
      print('Request Payload (key-value pairs):');
      requestPayload.forEach((key, value) {
        print('  $key: $value');
      });
      print('');
      print('Key Parameters:');
      print('  UserId: ${requestPayload['UserId']}');
      print('  CommandType: ${requestPayload['CommandType']}');
      print('  BizUnit: ${requestPayload['BizUnit']}');
      print('  TaxFlag: ${requestPayload['TaxFlag']}');
      print('  IncludeCancelled: ${requestPayload['IncludeCancelled']}');
      print('  Sector: ${requestPayload['Sector']}');
      print('═══════════════════════════════════════════════════════════');
      
      final response = await _dioClient.dio.post(
        Endpoints.commonGetAuto,
        data: requestPayload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      // Print API response details
      print('═══════════════════════════════════════════════════════════');
      print('📥 Issue To List API Response');
      print('═══════════════════════════════════════════════════════════');
      print('Status Code: ${response.statusCode}');
      print('Response Type: ${response.data.runtimeType}');
      if (response.data is List) {
        print('Response Count: ${(response.data as List).length}');
        print('Response Data (first 3 items):');
        final list = response.data as List;
        for (int i = 0; i < (list.length > 3 ? 3 : list.length); i++) {
          print('  [$i]: ${list[i]}');
        }
        if (list.length > 3) {
          print('  ... and ${list.length - 3} more items');
        }
      } else {
        print('Response Data: ${response.data}');
      }
      print('═══════════════════════════════════════════════════════════');

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
      print('❌ Issue To List API Error: $e');
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

  /// Get Customer List (CommandType: 71)
  /// Returns list of customers based on BizUnit
  Future<List<CommonDropdownItem>> getCustomerList({
    required int bizUnit,
    int? customerId,
    String? searchText,
  }) async {
    try {
      final request = CustomerListRequest(
        bizUnit: bizUnit,
        customerId: customerId,
        searchText: searchText,
      );
      final requestJson = request.toJson();
      
      // Debug logging
      print('🔵 [CommonApi] CUSTOMER LIST API REQUEST');
      print('📡 Endpoint: POST ${Endpoints.commonGetAuto}');
      print('📦 Request Body:');
      print('   CommandType: ${requestJson['CommandType']}');
      print('   BizUnit: ${requestJson['BizUnit']}');
      print('   CustomerId: ${requestJson['CustomerId']}');
      
      final response = await _dioClient.dio.post(
        Endpoints.commonGetAuto,
        data: requestJson,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      
      print('🟢 [CommonApi] CUSTOMER LIST API RESPONSE');
      print('📊 Status Code: ${response.statusCode}');
      if (response.data != null && response.data is List) {
        print('📊 Total Customers: ${(response.data as List).length}');
      }

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
      throw Exception('Failed to get customer list: ${e.toString()}');
    }
  }

  /// Get Item Description List (CommandType: 105)
  /// Returns list of item descriptions based on selected Division ID or DistributerId
  Future<List<CommonDropdownItem>> getItemDescriptionList(
    int? divisionId, {
    int? distributerId,
    String? searchText,
  }) async {
    try {
      final request = ItemDescriptionRequest(
        divisionId: divisionId,
        distributerId: distributerId,
        searchText: searchText,
      );
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

  /// Get Sales Rep List (CommandType: 158)
  /// Requires userId and customerId
  Future<List<CommonDropdownItem>> getSalesRepList({
    required int userId,
    required int customerId,
  }) async {
    try {
      // This endpoint requires camelCase field names, not PascalCase
      final requestData = {
        'commandType': 158,
        'userId': userId,
        'customerId': customerId,
      };
      
      print('🔵 Sales Rep API Request: $requestData');
      print('🔵 Sales Rep API Endpoint: ${Endpoints.commonGetAuto}');
      
      final response = await _dioClient.dio.post(
        Endpoints.commonGetAuto,
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      print('🔵 Sales Rep API Response Status: ${response.statusCode}');
      print('🔵 Sales Rep API Response Headers: ${response.headers}');
      print('🔵 Sales Rep API Response Data Type: ${response.data.runtimeType}');
      print('🔵 Sales Rep API Response Data: ${response.data}');
      
      if (response.data == null) {
        print('⚠️ Sales Rep API Response: null');
        return [];
      }

      // Check if response is a List
      if (response.data is List) {
        final List<dynamic> items = response.data as List<dynamic>;
        print('✅ Sales Rep API Response: List with ${items.length} items');
        if (items.isNotEmpty) {
          print('🔵 First item: ${items.first}');
        }
        return items.map((item) {
          print('🔵 Parsing item: $item');
          return CommonDropdownItem.fromJson(item);
        }).toList();
      } else if (response.data is Map) {
        print('⚠️ Sales Rep API Response: Map (not List)');
        print('🔵 Map keys: ${(response.data as Map).keys}');
        print('🔵 Map values: ${(response.data as Map).values}');
        // Try to find a list in the map
        final Map<String, dynamic> dataMap = response.data as Map<String, dynamic>;
        if (dataMap.containsKey('items') && dataMap['items'] is List) {
          final List<dynamic> items = dataMap['items'] as List<dynamic>;
          print('✅ Found items list in response map: ${items.length} items');
          return items.map((item) => CommonDropdownItem.fromJson(item)).toList();
        } else if (dataMap.containsKey('data') && dataMap['data'] is List) {
          final List<dynamic> items = dataMap['data'] as List<dynamic>;
          print('✅ Found data list in response map: ${items.length} items');
          return items.map((item) => CommonDropdownItem.fromJson(item)).toList();
        }
        return [];
      } else {
        print('⚠️ Sales Rep API Response: Unknown type (${response.data.runtimeType})');
        return [];
      }
    } catch (e, stackTrace) {
      print('❌ Error getting sales rep list: $e');
      print('❌ Stack trace: $stackTrace');
      throw Exception('Failed to get sales rep list: ${e.toString()}');
    }
  }

  /// Get Distributor List (CommandType: 114)
  /// Requires bizUnit and customerId
  Future<List<CommonDropdownItem>> getDistributorList({
    required int bizUnit,
    required int customerId,
  }) async {
    try {
      final request = CommonGetAutoRequest(
        commandType: 114,
        bizUnit: bizUnit,
        customerId: customerId,
      );
      return getAuto(request);
    } catch (e) {
      throw Exception('Failed to get distributor list: ${e.toString()}');
    }
  }

  /// Get Item List (CommandType: 105)
  /// Requires distributerId and optional searchText
  Future<List<CommonDropdownItem>> getItemList({
    required int distributerId,
    String? searchText,
  }) async {
    try {
      // This endpoint requires camelCase field names, not PascalCase
      // Use searchText if provided, otherwise use "%" to get all items
      final requestData = {
        'searchText': searchText ?? '%',
        'commandType': 105,
        'distributerId': distributerId,
      };
      
      print('🔵 Item List API Request: $requestData');
      print('🔵 Item List API Endpoint: ${Endpoints.commonGetAuto}');
      
      final response = await _dioClient.dio.post(
        Endpoints.commonGetAuto,
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      
      print('🔵 Item List API Response Status: ${response.statusCode}');
      
      if (response.data == null) {
        print('⚠️ Item List API Response: null');
        return [];
      }

      // Check if response is a List
      if (response.data is List) {
        final List<dynamic> items = response.data as List<dynamic>;
        print('✅ Item List API Response: List with ${items.length} items');
        return items.map((item) {
          return CommonDropdownItem.fromJson(item);
        }).toList();
      } else if (response.data is Map) {
        print('⚠️ Item List API Response: Map (not List)');
        return [];
      } else {
        print('❌ Item List API Response: Unexpected type ${response.data.runtimeType}');
        throw Exception('Invalid response format - expected array');
      }
    } catch (e) {
      print('❌ [CommonApi] Item List API Exception: ${e.toString()}');
      throw Exception('Failed to get item list: ${e.toString()}');
    }
  }

  /// Get UOM List (CommandType: 64)
  /// Requires itemId
  /// Endpoint: POST /api/Common/GetAuto
  /// Payload: { "CommandType": 64, "Item": itemId }
  Future<List<CommonDropdownItem>> getUOMList({
    required int itemId,
  }) async {
    try {
      // This endpoint requires PascalCase field names
      final requestData = {
        'CommandType': 64,
        'Item': itemId,
      };
      
      print('🔵 UOM List API Request: $requestData');
      print('🔵 UOM List API Endpoint: ${Endpoints.commonGetAuto}');
      
      final response = await _dioClient.dio.post(
        Endpoints.commonGetAuto,
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      
      print('🔵 UOM List API Response Status: ${response.statusCode}');
      
      if (response.data == null) {
        print('⚠️ UOM List API Response: null');
        return [];
      }

      // Check if response is a List
      if (response.data is List) {
        final List<dynamic> items = response.data as List<dynamic>;
        print('✅ UOM List API Response: List with ${items.length} items');
        return items.map((item) {
          return CommonDropdownItem.fromJson(item);
        }).toList();
      } else if (response.data is Map) {
        print('⚠️ UOM List API Response: Map (not List)');
        return [];
      } else {
        print('❌ UOM List API Response: Unexpected type ${response.data.runtimeType}');
        throw Exception('Invalid response format - expected array');
      }
    } catch (e) {
      print('❌ [CommonApi] UOM List API Exception: ${e.toString()}');
      throw Exception('Failed to get UOM list: ${e.toString()}');
    }
  }

  /// Get Item Tax List (GET)
  /// Endpoint: GET /api/Common/GetCatItemTax
  /// Payload: { "Id": itemId }
  Future<List<CommonDropdownItem>> getItemTaxList({
    required int itemId,
  }) async {
    try {
      // This endpoint uses GET with query parameters
      final requestData = {
        'Id': itemId,
      };
      
      print('🔵 Item Tax API Request: $requestData');
      print('🔵 Item Tax API Endpoint: ${Endpoints.commonGetCatItemTax}');
      
      final response = await _dioClient.dio.get(
        Endpoints.commonGetCatItemTax,
        queryParameters: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      
      print('🔵 Item Tax API Response Status: ${response.statusCode}');
      
      if (response.data == null) {
        print('⚠️ Item Tax API Response: null');
        return [];
      }

      // Check if response is a List
      if (response.data is List) {
        final List<dynamic> items = response.data as List<dynamic>;
        print('✅ Item Tax API Response: List with ${items.length} items');
        return items.map((item) {
          return CommonDropdownItem.fromJson(item);
        }).toList();
      } else if (response.data is Map) {
        print('⚠️ Item Tax API Response: Map (not List)');
        return [];
      } else {
        print('❌ Item Tax API Response: Unexpected type ${response.data.runtimeType}');
        throw Exception('Invalid response format - expected array');
      }
    } catch (e) {
      print('❌ [CommonApi] Item Tax API Exception: ${e.toString()}');
      throw Exception('Failed to get item tax list: ${e.toString()}');
    }
  }

  /// Get Tax List for Tax Section (CommandType: 153)
  /// Endpoint: POST /api/Common/GetAuto
  /// Payload: { "id": 4, "commandType": 153, "pageType": 2 }
  Future<List<CommonDropdownItem>> getTaxListForTaxSection() async {
    try {
      final request = CommonGetAutoRequest(
        commandType: 153,
        id: 4,
        pageType: 2,
      );
      
      print('🔵 Tax List API Request: ${request.toJson()}');
      print('🔵 Tax List API Endpoint: ${Endpoints.commonGetAuto}');
      
      final response = await _dioClient.dio.post(
        Endpoints.commonGetAuto,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      
      print('🔵 Tax List API Response Status: ${response.statusCode}');
      
      if (response.data == null) {
        print('⚠️ Tax List API Response: null');
        return [];
      }

      // Check if response is a List
      if (response.data is List) {
        final List<dynamic> items = response.data as List<dynamic>;
        print('✅ Tax List API Response: List with ${items.length} items');
        return items.map((item) {
          return CommonDropdownItem.fromJson(item);
        }).toList();
      } else if (response.data is Map) {
        print('⚠️ Tax List API Response: Map (not List)');
        return [];
      } else {
        print('❌ Tax List API Response: Unexpected type ${response.data.runtimeType}');
        throw Exception('Invalid response format - expected array');
      }
    } catch (e) {
      print('❌ [CommonApi] Tax List API Exception: ${e.toString()}');
      throw Exception('Failed to get tax list: ${e.toString()}');
    }
  }

  /// Get Discount List for Tax Section (CommandType: 153, id: 2)
  /// Endpoint: POST /api/Common/GetAuto
  /// Payload: { "id": 2, "commandType": 153, "pageType": 2 }
  Future<List<CommonDropdownItem>> getDiscountListForTaxSection() async {
    try {
      final request = CommonGetAutoRequest(
        commandType: 153,
        id: 2,
        pageType: 2,
      );
      
      print('🔵 Discount List API Request: ${request.toJson()}');
      print('🔵 Discount List API Endpoint: ${Endpoints.commonGetAuto}');
      
      final response = await _dioClient.dio.post(
        Endpoints.commonGetAuto,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      
      print('🔵 Discount List API Response Status: ${response.statusCode}');
      
      if (response.data == null) {
        print('⚠️ Discount List API Response: null');
        return [];
      }

      // Check if response is a List
      if (response.data is List) {
        final List<dynamic> items = response.data as List<dynamic>;
        print('✅ Discount List API Response: List with ${items.length} items');
        return items.map((item) {
          return CommonDropdownItem.fromJson(item);
        }).toList();
      } else if (response.data is Map) {
        print('⚠️ Discount List API Response: Map (not List)');
        return [];
      } else {
        print('❌ Discount List API Response: Unexpected type ${response.data.runtimeType}');
        throw Exception('Invalid response format - expected array');
      }
    } catch (e) {
      print('❌ [CommonApi] Discount List API Exception: ${e.toString()}');
      throw Exception('Failed to get discount list: ${e.toString()}');
    }
  }

  /// Get Tax Component Formulas (GET)
  /// Endpoint: GET /api/TaxComponent/Get
  /// Query Parameters: Id, UserId, PageNumber, PageSize, SearchText, SortOrder, SortDir, SortField, Json, FilterExpression, PageId, Type
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
      final request = TaxComponentRequest(
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
      
      print('🔵 Tax Component API Request: ${request.toJson()}');
      print('🔵 Tax Component API Endpoint: ${Endpoints.taxComponentGet}');
      
      // Using GET request with query parameters
      final response = await _dioClient.dio.get(
        Endpoints.taxComponentGet,
        queryParameters: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      
      print('🔵 Tax Component API Response Status: ${response.statusCode}');
      
      if (response.data == null) {
        print('⚠️ Tax Component API Response: null');
        return [];
      }

      // Check if response is a List
      if (response.data is List) {
        final List<dynamic> items = response.data as List<dynamic>;
        print('✅ Tax Component API Response: List with ${items.length} items');
        return items.map((item) {
          return TaxComponentResponse.fromJson(item);
        }).toList();
      } else if (response.data is Map) {
        // If single object, wrap in list
        print('✅ Tax Component API Response: Single object');
        return [TaxComponentResponse.fromJson(response.data as Map<String, dynamic>)];
      } else {
        print('❌ Tax Component API Response: Unexpected type ${response.data.runtimeType}');
        throw Exception('Invalid response format - expected array or object');
      }
    } catch (e) {
      print('❌ [CommonApi] Tax Component API Exception: ${e.toString()}');
      throw Exception('Failed to get tax component formulas: ${e.toString()}');
    }
  }
}
