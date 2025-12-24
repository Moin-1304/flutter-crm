import 'package:dio/dio.dart';
import '../../../../core/data/network/dio/dio_client.dart';
import '../../constants/endpoints.dart';
import '../../../../domain/entity/item_issue/item_issue_api_models.dart';

class ItemIssueApi {
  final DioClient _dioClient;

  ItemIssueApi(this._dioClient);

  /// Get ItemIssue list with filter criteria
  Future<ItemIssueListResponse> getItemIssueList(ItemIssueListRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.itemIssueList,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        return ItemIssueListResponse.fromJson(response.data);
      } else {
        throw Exception('No ItemIssue data received');
      }
    } catch (e) {
      throw Exception('Failed to fetch ItemIssue list: ${e.toString()}');
    }
  }
}

