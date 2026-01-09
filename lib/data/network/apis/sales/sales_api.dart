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
}

