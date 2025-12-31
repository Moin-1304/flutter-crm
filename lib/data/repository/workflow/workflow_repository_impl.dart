import 'package:boilerplate/domain/repository/workflow/workflow_repository.dart';
import 'package:boilerplate/domain/entity/workflow/workflow_api_models.dart';
import 'package:boilerplate/data/network/apis/workflow/workflow_api.dart';
import 'package:boilerplate/di/service_locator.dart';

class WorkflowRepositoryImpl implements WorkflowRepository {
  @override
  Future<WorkflowGetAllActionsResponse> getAllActions(WorkflowGetAllActionsRequest request) async {
    try {
      if (getIt.isRegistered<WorkflowApi>()) {
        final workflowApi = getIt<WorkflowApi>();
        return await workflowApi.getAllActions(request);
      } else {
        throw Exception('WorkflowApi not registered in service locator');
      }
    } catch (e) {
      throw Exception('Failed to get workflow actions: ${e.toString()}');
    }
  }
}

