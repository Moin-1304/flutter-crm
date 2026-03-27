import 'package:file_picker/file_picker.dart';
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
    required int userId, // Required - passed in listing API to fetch records
    required int menuId,
    required String url,
    int? isFullyUsed,
  });

  Future<SalesOrderApiItem> getSalesOrderById(int id);

  Future<List<String>> getStatusFilters({
    required int bizUnit,
  });

  Future<List<String>> getTransactionStatusFilters({
    required int bizUnit,
  });

  Future<List<String>> getSOTypeFilters({
    required int bizUnit,
  });

  Future<List<String>> getCurrencyFilters({
    required int bizUnit,
  });

  Future<SalesBonusListResponse> getBonusList({
    required int itemId,
  });

  Future<SalesBonusSlabListResponse> getBonusSlabList({
    required int slabId,
  });

  Future<SalesDiscountListResponse> getDiscountList({
    required int itemId,
  });

  Future<SalesOrderSaveResponse> saveSalesOrder(
    SalesOrderSaveRequest request, {
    List<PlatformFile>? files,
  });

  Future<void> deleteSalesOrder({
    required int id,
    required int bizunit,
    required int userId,
  });

  Future<void> transactionCancelSalesOrder(
      SalesOrderTransactionCancelRequest request);
}
