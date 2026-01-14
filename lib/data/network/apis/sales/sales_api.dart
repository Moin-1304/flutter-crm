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
}

