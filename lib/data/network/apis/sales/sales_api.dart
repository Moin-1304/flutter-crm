import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../../core/data/network/dio/dio_client.dart';
import '../../constants/endpoints.dart';
import '../../../../domain/entity/sales/sales_api_models.dart';

class SalesApi {
  final DioClient _dioClient;

  SalesApi(this._dioClient);

  /// Get Sales Order list with filter criteria
  Future<SalesOrderListResponse> getSalesOrderList(
      SalesOrderListRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.salesOrderList,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        return SalesOrderListResponse.fromJson(response.data);
      } else {
        throw Exception('No sales order data received');
      }
    } catch (e) {
      throw Exception('Failed to fetch sales order list: ${e.toString()}');
    }
  }

  /// Get Sales Order by ID
  Future<SalesOrderApiItem> getSalesOrderById(int id) async {
    try {
      print('🌐 [SalesApi] getSalesOrderById called with id: $id');
      print('   Endpoint: ${Endpoints.salesOrderGet}');
      print('   Query params: {Id: $id}');
      
      final response = await _dioClient.dio.get(
        Endpoints.salesOrderGet,
        queryParameters: {'Id': id},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      print('📥 [SalesApi] Response received');
      print('   Status code: ${response.statusCode}');
      print('   Has data: ${response.data != null}');
      
      if (response.data != null) {
        print('   Parsing response data...');
        final orderData = SalesOrderApiItem.fromJson(response.data);
        print('   ✅ Parsed successfully - Order ID: ${orderData.id}, SO Number: ${orderData.soNumber}');
        return orderData;
      } else {
        print('   ❌ No data in response');
        throw Exception('No sales order data received');
      }
    } catch (e, stackTrace) {
      print('❌ [SalesApi] Error in getSalesOrderById: $e');
      print('   Stack trace: $stackTrace');
      throw Exception('Failed to fetch sales order: ${e.toString()}');
    }
  }

  /// Get Status filters for Sales Order List
  /// Uses GetSalesInvoiceCommonAuto endpoint with fieldName: "Status" and pageName: "SaleOrderList"
  Future<List<String>> getStatusFilters({
    required int bizUnit,
  }) async {
    try {
      final request = GetSalesInvoiceCommonAutoRequest(
        id: null,
        pageNumber: 0,
        pageSize: 0,
        sortOrder: 0,
        bizUnit: bizUnit,
        active: null,
        sortDir: 0,
        searchText: null,
        sortField: null,
        filterExpression: null,
        sortExpression: null,
        fromDate: null,
        toDate: null,
        fieldName: 'Status',
        pageName: 'SaleOrderList',
        userId: null,
        menuId: null,
        url: null,
        isFullyUsed: null,
        refId: null,
      );

      final response = await _dioClient.dio.post(
        Endpoints.salesInvoiceCommonAuto,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        // Response is likely a list of strings or objects with text/name fields
        if (response.data is List) {
          final List<dynamic> dataList = response.data as List<dynamic>;
          return dataList.map<String>((item) {
            if (item is String) {
              return item;
            } else if (item is Map) {
              // Try common field names for status text
              return item['text'] ?? item['name'] ?? item['value'] ?? item['label'] ?? item.toString();
            }
            return item.toString();
          }).toList();
        } else {
          throw Exception('Invalid response format - expected array');
        }
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to fetch status filters: ${e.toString()}');
    }
  }

  /// Get Transaction Status filters for Sales Order List
  /// Uses GetSalesInvoiceCommonAuto endpoint with fieldName: "IsFullyUsedText" and pageName: "SaleOrderList"
  Future<List<String>> getTransactionStatusFilters({
    required int bizUnit,
  }) async {
    try {
      final request = GetSalesInvoiceCommonAutoRequest(
        id: null,
        pageNumber: 0,
        pageSize: 0,
        sortOrder: 0,
        bizUnit: bizUnit,
        active: null,
        sortDir: 0,
        searchText: null,
        sortField: null,
        filterExpression: null,
        sortExpression: null,
        fromDate: null,
        toDate: null,
        fieldName: 'IsFullyUsedText',
        pageName: 'SaleOrderList',
        userId: null,
        menuId: null,
        url: null,
        isFullyUsed: null,
        refId: null,
      );

      final response = await _dioClient.dio.post(
        Endpoints.salesInvoiceCommonAuto,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        // Response is likely a list of strings or objects with text/name fields
        if (response.data is List) {
          final List<dynamic> dataList = response.data as List<dynamic>;
          return dataList.map<String>((item) {
            if (item is String) {
              return item;
            } else if (item is Map) {
              // Try common field names for transaction status text
              return item['text'] ?? item['name'] ?? item['value'] ?? item['label'] ?? item.toString();
            }
            return item.toString();
          }).toList();
        } else {
          throw Exception('Invalid response format - expected array');
        }
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to fetch transaction status filters: ${e.toString()}');
    }
  }

  /// Get SO Type filters for Sales Order List
  /// Uses GetSalesInvoiceCommonAuto endpoint with fieldName: "SOType" and pageName: "SaleOrderList"
  Future<List<String>> getSOTypeFilters({
    required int bizUnit,
  }) async {
    try {
      final request = GetSalesInvoiceCommonAutoRequest(
        id: null,
        pageNumber: 0,
        pageSize: 0,
        sortOrder: 0,
        bizUnit: bizUnit,
        active: null,
        sortDir: 0,
        searchText: null,
        sortField: null,
        filterExpression: null,
        sortExpression: null,
        fromDate: null,
        toDate: null,
        fieldName: 'SOType',
        pageName: 'SaleOrderList',
        userId: null,
        menuId: null,
        url: null,
        isFullyUsed: null,
        refId: null,
      );

      final response = await _dioClient.dio.post(
        Endpoints.salesInvoiceCommonAuto,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        // Response is likely a list of strings or objects with text/name fields
        if (response.data is List) {
          final List<dynamic> dataList = response.data as List<dynamic>;
          return dataList.map<String>((item) {
            if (item is String) {
              return item;
            } else if (item is Map) {
              // Try common field names for SO type text
              return item['text'] ?? item['name'] ?? item['value'] ?? item['label'] ?? item.toString();
            }
            return item.toString();
          }).toList();
        } else {
          throw Exception('Invalid response format - expected array');
        }
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to fetch SO type filters: ${e.toString()}');
    }
  }

  /// Get Currency filters for Sales Order List
  /// Uses GetSalesInvoiceCommonAuto endpoint with fieldName: "Currency" and pageName: "SaleOrderList"
  Future<List<String>> getCurrencyFilters({
    required int bizUnit,
  }) async {
    try {
      final request = GetSalesInvoiceCommonAutoRequest(
        id: null,
        pageNumber: 0,
        pageSize: 0,
        sortOrder: 0,
        bizUnit: bizUnit,
        active: null,
        sortDir: 0,
        searchText: null,
        sortField: null,
        filterExpression: null,
        sortExpression: null,
        fromDate: null,
        toDate: null,
        fieldName: 'Currency',
        pageName: 'SaleOrderList',
        userId: null,
        menuId: null,
        url: null,
        isFullyUsed: null,
        refId: null,
      );

      final response = await _dioClient.dio.post(
        Endpoints.salesInvoiceCommonAuto,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        // Response is likely a list of strings or objects with text/name fields
        if (response.data is List) {
          final List<dynamic> dataList = response.data as List<dynamic>;
          return dataList.map<String>((item) {
            if (item is String) {
              return item;
            } else if (item is Map) {
              // Try different possible field names
              return (item['text'] ?? item['name'] ?? item['value'] ?? item['label'] ?? item.toString()) as String;
            }
            return item.toString();
          }).toList();
        } else {
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      throw Exception('Failed to fetch Currency filters: ${e.toString()}');
    }
  }

  /// Save Sales Order
  Future<SalesOrderSaveResponse> saveSalesOrder(SalesOrderSaveRequest request) async {
    try {
      // Log request for debugging
      print('═══════════════════════════════════════════════════════════');
      print('📤 Sales Order Save API Request');
      print('═══════════════════════════════════════════════════════════');
      print('URL: ${Endpoints.salesOrderSave}');
      print('Request JSON:');
      print(request.toJson());
      print('═══════════════════════════════════════════════════════════');

      final response = await _dioClient.dio.post(
        Endpoints.salesOrderSave,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      print('✅ Sales Order Save API Success');
      print('Response Status: ${response.statusCode}');
      print('Response Data Type: ${response.data.runtimeType}');
      print('Response Data: ${response.data}');
      print('Response Headers: ${response.headers.map}');

      // Check for success headers (common in ASP.NET APIs)
      final headers = response.headers.map;
      final successCode = headers['successcode']?.first;
      final successMessage = headers['successmessage']?.first ?? 'Sale Order saved successfully';
      
      print('   Success Code: $successCode');
      print('   Success Message: $successMessage');

      // Handle 204 No Content response (success with no body or request payload in body)
      if (response.statusCode == 204) {
        print('✅ 204 No Content - Success response');
        
        // Try to parse response.data if it exists and is not empty
        Map<String, dynamic> responseData;
        
        if (response.data != null && response.data.toString().trim().isNotEmpty) {
          if (response.data is Map<String, dynamic>) {
            // Response data is already a Map
            responseData = response.data as Map<String, dynamic>;
            print('   Using response.data as Map');
          } else if (response.data is String) {
            // Response data is a String, try to parse as JSON
            final dataString = (response.data as String).trim();
            if (dataString.isNotEmpty) {
              try {
                responseData = jsonDecode(dataString) as Map<String, dynamic>;
                print('   Parsed response.data from String to Map');
              } catch (e) {
                print('⚠️ Failed to parse response.data as JSON: $e');
                // Fallback to request data
                responseData = request.toJson();
                responseData['message'] = successMessage;
              }
            } else {
              // Empty string, use request data
              print('   Empty string response.data, using request data');
              responseData = request.toJson();
              responseData['message'] = successMessage;
            }
          } else {
            // Unknown type, use request data
            print('⚠️ Unknown response.data type: ${response.data.runtimeType}');
            responseData = request.toJson();
            responseData['message'] = successMessage;
          }
        } else {
          // No response data or empty, use request data
          print('   No response.data or empty, using request data');
          responseData = request.toJson();
          responseData['message'] = successMessage;
        }
        
        // Ensure message is set
        if (responseData['message'] == null || responseData['message'].toString().isEmpty) {
          responseData['message'] = successMessage;
        }
        
        // Normalize id field (API uses "Id" but fromJson checks "id")
        if (responseData['Id'] != null && responseData['id'] == null) {
          responseData['id'] = responseData['Id'];
        }
        
        // Create response directly with success=true to avoid fromJson logic issues
        return SalesOrderSaveResponse(
          data: responseData,
          success: true, // Always true for 204 responses
          message: responseData['message']?.toString() ?? successMessage,
        );
      }

      // Handle normal JSON response (200 OK with body)
      if (response.data != null) {
        // Check if response.data is a Map
        if (response.data is Map<String, dynamic>) {
          final responseData = response.data as Map<String, dynamic>;
          // Add success message from headers if not present
          if (responseData['message'] == null && successMessage.isNotEmpty) {
            responseData['message'] = successMessage;
          }
          return SalesOrderSaveResponse.fromJson(responseData);
        } else if (response.data is String) {
          // If response is a string, try to parse it as JSON
          try {
            final jsonData = jsonDecode(response.data as String) as Map<String, dynamic>;
            // Add success message from headers if not present
            if (jsonData['message'] == null && successMessage.isNotEmpty) {
              jsonData['message'] = successMessage;
            }
            return SalesOrderSaveResponse.fromJson(jsonData);
          } catch (e) {
            print('⚠️ Response data is string but not valid JSON: ${response.data}');
            // Create success response from request data
            return SalesOrderSaveResponse(
              data: request.toJson(),
              success: true,
              message: successMessage,
            );
          }
        } else {
          // Unknown response type, create success response from request
          print('⚠️ Unknown response data type: ${response.data.runtimeType}');
          return SalesOrderSaveResponse(
            data: request.toJson(),
            success: true,
            message: successMessage,
          );
        }
      } else {
        // No response data but status is success (not 204)
        // Create success response from request data
        return SalesOrderSaveResponse(
          data: request.toJson(),
          success: true,
          message: successMessage,
        );
      }
    } on DioException catch (e) {
      // Enhanced error handling for DioException
      String errorMessage = 'Failed to save Sales Order';
      
      if (e.response != null) {
        // Server responded with error
        print('❌ Sales Order Save API Error');
        print('   Status Code: ${e.response!.statusCode}');
        print('   Response Headers: ${e.response!.headers}');
        print('   Response Data Type: ${e.response!.data.runtimeType}');
        print('   Response Data: ${e.response!.data}');
        
        // First, check response headers for error message (common in ASP.NET APIs)
        final headers = e.response!.headers;
        
        // Debug: Print all header keys to see what's available
        print('   Available Header Keys: ${headers.map.keys.toList()}');
        print('   All Headers:');
        headers.map.forEach((key, value) {
          print('      $key: $value');
        });
        
        // Try to find error message in headers (case-insensitive check)
        String? headerError;
        for (final key in headers.map.keys) {
          final lowerKey = key.toLowerCase();
          if (lowerKey == 'errormessage' || lowerKey == 'error-message') {
            final headerValue = headers.map[key];
            if (headerValue != null && headerValue.isNotEmpty) {
              headerError = headerValue.first;
              print('   Found errorMessage header (key: $key): $headerError');
              break;
            }
          }
        }
        
        if (headerError != null && headerError.isNotEmpty) {
          errorMessage = headerError;
          print('   ✅ Error Message from Header: $errorMessage');
        } else {
          print('   ⚠️ No errorMessage found in headers - will try response body');
        }
        
        // If no error message found in headers, try response body
        if (errorMessage == 'Failed to save Sales Order') {
          final responseData = e.response!.data;
          
          if (responseData != null) {
            if (responseData is String) {
              // If response is a plain string, use it directly
              errorMessage = responseData.isNotEmpty ? responseData : errorMessage;
            } else if (responseData is Map) {
              // Try multiple possible error message fields
              errorMessage = responseData['message']?.toString() ?? 
                            responseData['error']?.toString() ??
                            responseData['errorMessage']?.toString() ??
                            responseData['Message']?.toString() ??
                            responseData['Error']?.toString() ??
                            responseData['ErrorMessage']?.toString() ??
                            responseData['exceptionMessage']?.toString() ??
                            responseData['ExceptionMessage']?.toString() ??
                            responseData['detail']?.toString() ??
                            responseData['Detail']?.toString() ??
                            errorMessage;
              
              // If still default message, try to extract from nested structures
              if (errorMessage == 'Failed to save Sales Order' && responseData.containsKey('errors')) {
                final errors = responseData['errors'];
                if (errors is Map) {
                  final errorList = errors.values.expand((v) => v is List ? v : [v]).toList();
                  if (errorList.isNotEmpty) {
                    errorMessage = errorList.join(', ');
                  }
                } else if (errors is List) {
                  errorMessage = errors.join(', ');
                }
              }
            } else if (responseData is List) {
              // Handle validation errors array (e.g., from .NET Core ModelState)
              if (responseData.isNotEmpty) {
                final errorMessages = responseData.map((err) {
                  if (err is Map) {
                    return err['errorMessage']?.toString() ?? 
                           err['ErrorMessage']?.toString() ??
                           err['message']?.toString() ??
                           err['Message']?.toString() ??
                           err.toString();
                  }
                  return err.toString();
                }).toList();
                errorMessage = 'Validation Errors:\n${errorMessages.join('\n')}';
              }
            }
          }
          
          // For 500 errors, add more context if we couldn't extract a specific message
          if (e.response!.statusCode == 500 && errorMessage == 'Failed to save Sales Order') {
            errorMessage = 'Internal Server Error (500): The server encountered an unexpected error while processing your request. Please try again later or contact support.';
          }
        }
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Connection timeout. Please check your network connection and try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'No internet connection. Please check your network and try again.';
      } else if (e.type == DioExceptionType.sendTimeout) {
        errorMessage = 'Request timeout. The server is taking too long to respond.';
      }
      
      print('   Final Error Message: $errorMessage');
      throw Exception(errorMessage);
    } catch (e) {
      print('❌ Sales Order Save API Error: $e');
      if (e is Exception) {
        rethrow; // Re-throw if it's already an Exception with proper message
      }
      throw Exception('Failed to save Sales Order: ${e.toString()}');
    }
  }

  /// Delete Sales Order
  /// Uses GET request with query parameters matching the API specification
  /// API: /api/SaleOrder/Delete
  /// Type: GET API
  Future<void> deleteSalesOrder({
    required int id,
    required int bizunit,
    required int userId,
  }) async {
    try {
      // Build query parameters matching the API JSON structure
      final queryParams = <String, dynamic>{
        'Id': id, // Transaction Id (required)
        'PageNumber': 0,
        'PageSize': 0,
        'SortOrder': 0,
        'Bizunit': bizunit,
        'Active': null,
        'SortDir': 0,
        'SearchText': null,
        'SortField': null,
        'FilterExpression': null,
        'SortExpression': null,
        'FromDate': null,
        'ToDate': null,
        'FieldName': null,
        'PageName': null,
        'UserId': userId,
        'MenuId': null,
        'Url': null,
        'IsFullyUsed': null,
        'RefId': null,
      };

      // Remove null values from query parameters (standard practice for GET requests)
      queryParams.removeWhere((key, value) => value == null);

      print('═══════════════════════════════════════════════════════════');
      print('🗑️ Sales Order Delete API Request');
      print('═══════════════════════════════════════════════════════════');
      print('URL: ${Endpoints.salesOrderDelete}');
      print('Query Parameters:');
      queryParams.forEach((key, value) {
        print('  $key: $value');
      });
      print('═══════════════════════════════════════════════════════════');
      
      final response = await _dioClient.dio.get(
        Endpoints.salesOrderDelete,
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      print('═══════════════════════════════════════════════════════════');
      print('✅ Sales Order Delete API Response');
      print('═══════════════════════════════════════════════════════════');
      print('Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');
      print('═══════════════════════════════════════════════════════════');
      
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        return;
      } else {
        throw Exception('Failed to delete sales order: Invalid response status ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('═══════════════════════════════════════════════════════════');
      print('❌ Sales Order Delete API Error');
      print('═══════════════════════════════════════════════════════════');
      print('Error Type: ${e.type}');
      print('Error Message: ${e.message}');
      
      String errorMessage = 'Failed to delete Sales Order';
      
      if (e.response != null) {
        print('Status Code: ${e.response!.statusCode}');
        print('Response Data: ${e.response!.data}');
        
        final data = e.response!.data;
        if (data is Map) {
          errorMessage = data['message']?.toString() ?? 
                        data['errorMessage']?.toString() ??
                        data['error']?.toString() ??
                        errorMessage;
        } else if (data is String) {
          errorMessage = data.isNotEmpty ? data : errorMessage;
        }
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      print('❌ Sales Order Delete - Unexpected Error: $e');
      throw Exception('Failed to delete Sales Order: ${e.toString()}');
    }
  }

  /// Transaction Cancel Sales Order
  /// API: /api/SaleOrder/TransactionCancel
  /// Type: POST
  Future<void> transactionCancelSalesOrder(SalesOrderTransactionCancelRequest request) async {
    try {
      print('═══════════════════════════════════════════════════════════');
      print('🚫 Sales Order Transaction Cancel API Request');
      print('═══════════════════════════════════════════════════════════');
      print('URL: ${Endpoints.salesOrderTransactionCancel}');
      print('Request JSON:');
      print(request.toJson());
      print('═══════════════════════════════════════════════════════════');

      final response = await _dioClient.dio.post(
        Endpoints.salesOrderTransactionCancel,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      print('═══════════════════════════════════════════════════════════');
      print('✅ Sales Order Transaction Cancel API Response');
      print('═══════════════════════════════════════════════════════════');
      print('Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');
      print('═══════════════════════════════════════════════════════════');

      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        return;
      } else {
        throw Exception('Failed to cancel sales order: Invalid response status ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('═══════════════════════════════════════════════════════════');
      print('❌ Sales Order Transaction Cancel API Error');
      print('═══════════════════════════════════════════════════════════');
      print('Error Type: ${e.type}');
      print('Error Message: ${e.message}');

      String errorMessage = 'Failed to cancel Sales Order';

      if (e.response != null) {
        print('Status Code: ${e.response!.statusCode}');
        print('Response Data: ${e.response!.data}');

        final data = e.response!.data;
        if (data is Map) {
          errorMessage = data['message']?.toString() ??
                        data['errorMessage']?.toString() ??
                        data['error']?.toString() ??
                        errorMessage;
        } else if (data is String) {
          errorMessage = data.isNotEmpty ? data : errorMessage;
        }
      }

      throw Exception(errorMessage);
    } catch (e) {
      print('❌ Sales Order Transaction Cancel - Unexpected Error: $e');
      throw Exception('Failed to cancel Sales Order: ${e.toString()}');
    }
  }
}

