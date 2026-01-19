import 'package:boilerplate/domain/entity/sales/sales_api_models.dart';
import 'package:boilerplate/domain/repository/sales/sales_repository.dart';
import 'package:boilerplate/data/network/apis/sales/sales_api.dart';
import 'package:boilerplate/di/service_locator.dart';

class SalesRepositoryImpl implements SalesRepository {
  @override
  Future<SalesOrderListResponse> getSalesOrderList({
    required int? id,
    required int pageNumber,
    required int pageSize,
    required int sortOrder,
    required int bizunit,
    bool? active,
    required int sortDir,
    String? searchText,
    required String sortField,
    String? filterExpression,
    String? sortExpression,
    String? fromDate,
    String? toDate,
    String? fieldName,
    String? pageName,
    required int userId, // Required - passed in listing API to fetch records
    required int menuId,
    required String url,
    int? isFullyUsed,
  }) async {
    try {
      if (getIt.isRegistered<SalesApi>()) {
        final salesApi = getIt<SalesApi>();

        final request = SalesOrderListRequest(
          id: id,
          pageNumber: pageNumber,
          pageSize: pageSize,
          sortOrder: sortOrder,
          bizunit: bizunit,
          active: active,
          sortDir: sortDir,
          searchText: searchText,
          sortField: sortField,
          filterExpression: filterExpression,
          sortExpression: sortExpression,
          fromDate: fromDate,
          toDate: toDate,
          fieldName: fieldName,
          pageName: pageName,
          userId: userId, // Pass userId in listing API
          menuId: menuId,
          url: url,
          isFullyUsed: isFullyUsed,
        );

        final response = await salesApi.getSalesOrderList(request);
        return response;
      }
    } catch (e) {
      // API call failed, fallback to empty response
    }

    // Fallback to empty response if API fails
    return SalesOrderListResponse(
      items: [],
      totalRecords: 0,
      filteredRecords: 0,
    );
  }

  @override
  Future<SalesOrderApiItem> getSalesOrderById(int id) async {
    try {
      if (getIt.isRegistered<SalesApi>()) {
        final salesApi = getIt<SalesApi>();
        final response = await salesApi.getSalesOrderById(id);
        return response;
      }
      throw Exception('SalesApi not registered');
    } catch (e) {
      throw Exception('Failed to fetch sales order: ${e.toString()}');
    }
  }

  @override
  Future<List<String>> getStatusFilters({
    required int bizUnit,
  }) async {
    try {
      if (getIt.isRegistered<SalesApi>()) {
        final salesApi = getIt<SalesApi>();
        final response = await salesApi.getStatusFilters(bizUnit: bizUnit);
        return response;
      }
    } catch (e) {
      print('Error getting status filters: $e');
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<String>> getTransactionStatusFilters({
    required int bizUnit,
  }) async {
    try {
      if (getIt.isRegistered<SalesApi>()) {
        final salesApi = getIt<SalesApi>();
        final response = await salesApi.getTransactionStatusFilters(bizUnit: bizUnit);
        return response;
      }
    } catch (e) {
      print('Error getting transaction status filters: $e');
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<String>> getSOTypeFilters({
    required int bizUnit,
  }) async {
    try {
      if (getIt.isRegistered<SalesApi>()) {
        final salesApi = getIt<SalesApi>();
        final response = await salesApi.getSOTypeFilters(bizUnit: bizUnit);
        return response;
      }
    } catch (e) {
      print('Error getting SO type filters: $e');
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<List<String>> getCurrencyFilters({
    required int bizUnit,
  }) async {
    try {
      if (getIt.isRegistered<SalesApi>()) {
        final salesApi = getIt<SalesApi>();
        final response = await salesApi.getCurrencyFilters(bizUnit: bizUnit);
        return response;
      }
    } catch (e) {
      print('Error getting currency filters: $e');
    }

    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<SalesOrderSaveResponse> saveSalesOrder(SalesOrderSaveRequest request) async {
    try {
      if (getIt.isRegistered<SalesApi>()) {
        final salesApi = getIt<SalesApi>();
        final response = await salesApi.saveSalesOrder(request);
        return response;
      }
      throw Exception('SalesApi not registered');
    } catch (e) {
      throw Exception('Failed to save sales order: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteSalesOrder({
    required int id,
    required int bizunit,
    required int userId,
  }) async {
    try {
      if (getIt.isRegistered<SalesApi>()) {
        final salesApi = getIt<SalesApi>();
        await salesApi.deleteSalesOrder(
          id: id,
          bizunit: bizunit,
          userId: userId,
        );
        return;
      }
      throw Exception('SalesApi not registered');
    } catch (e) {
      throw Exception('Failed to delete sales order: ${e.toString()}');
    }
  }
}

