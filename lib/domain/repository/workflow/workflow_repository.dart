import '../../entity/workflow/workflow_api_models.dart';

abstract class WorkflowRepository {
  Future<WorkflowGetAllActionsResponse> getAllActions(WorkflowGetAllActionsRequest request);
}

