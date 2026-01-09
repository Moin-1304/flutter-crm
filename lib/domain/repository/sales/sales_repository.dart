import 'package:boilerplate/domain/entity/sales/sales_api_models.dart';

abstract class SalesRepository {
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
    required int userId,
    required int menuId,
    required String url,
  });

  Future<SalesOrderApiItem> getSalesOrderById(int id);
}


