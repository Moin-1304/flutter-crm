import 'package:boilerplate/domain/entity/item_issue/item_issue_api_models.dart';

abstract class ItemIssueRepository {
  Future<ItemIssueListResponse> getItemIssueList(ItemIssueListRequest request);
}

