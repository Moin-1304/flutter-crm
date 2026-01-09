import 'package:boilerplate/domain/repository/item_issue/item_issue_repository.dart';
import 'package:boilerplate/domain/entity/item_issue/item_issue_api_models.dart';
import 'package:boilerplate/data/network/apis/item_issue/item_issue_api.dart';
import 'package:boilerplate/di/service_locator.dart';

class ItemIssueRepositoryImpl implements ItemIssueRepository {
  @override
  Future<ItemIssueListResponse> getItemIssueList(ItemIssueListRequest request) async {
    try {
      if (getIt.isRegistered<ItemIssueApi>()) {
        final itemIssueApi = getIt<ItemIssueApi>();
        return await itemIssueApi.getItemIssueList(request);
      } else {
        throw Exception('ItemIssueApi not registered in service locator');
      }
    } catch (e) {
      throw Exception('Failed to get ItemIssue list: ${e.toString()}');
    }
  }

  @override
  Future<ItemIssueApiItem> getItemIssue(int id) async {
    try {
      if (getIt.isRegistered<ItemIssueApi>()) {
        final itemIssueApi = getIt<ItemIssueApi>();
        return await itemIssueApi.getItemIssue(id);
      } else {
        throw Exception('ItemIssueApi not registered in service locator');
      }
    } catch (e) {
      throw Exception('Failed to get ItemIssue: ${e.toString()}');
    }
  }

  @override
  Future<ItemIssueSaveResponse> saveItemIssue(ItemIssueSaveRequest request) async {
    try {
      if (getIt.isRegistered<ItemIssueApi>()) {
        final itemIssueApi = getIt<ItemIssueApi>();
        return await itemIssueApi.saveItemIssue(request);
      } else {
        throw Exception('ItemIssueApi not registered in service locator');
      }
    } catch (e) {
      throw Exception('Failed to save ItemIssue: ${e.toString()}');
    }
  }
}

