import 'package:boilerplate/domain/entity/deviation/deviation_api_models.dart';

abstract class DeviationRepository {
  Future<DeviationListResponse> getDeviationList({
    required String searchText,
    required int pageNumber,
    required int pageSize,
    required int userId,
    required int bizUnit,
    required int employeeId,
  });

  Future<DeviationSaveResponse> saveDeviation({
    required int? id,
    required int createdBy,
    required int status,
    required int sbuId,
    required int bizUnit,
    required int? tourPlanDetailId,
    required int? dcrDetailId,
    required String dateOfDeviation,
    required int typeOfDeviation,
    required String description,
    required int customerId,
    required int clusterId,
    required String impact,
    required String deviationType,
    required String deviationStatus,
    required int? commentCount,
    required String? clusterName,
    required int employeeId,
    required String? employeeName,
    required String? employeeCode,
    required String? tourPlanName,
  });

  Future<DeviationSaveResponse> updateDeviation({
    required int? id,
    required int createdBy,
    required int status,
    required int sbuId,
    required int bizUnit,
    required int? tourPlanDetailId,
    required int? dcrDetailId,
    required String dateOfDeviation,
    required int typeOfDeviation,
    required String description,
    required int customerId,
    required int clusterId,
    required String impact,
    required String deviationType,
    required String deviationStatus,
    required int? commentCount,
    required String? clusterName,
    required int employeeId,
    required String? employeeName,
    required String? employeeCode,
    required String? tourPlanName,
  });

  Future<DeviationStatusUpdateResponse> approveDeviation({
    required int id,
    required String comment,
    required int employeeId,
  });

  Future<DeviationStatusUpdateResponse> rejectDeviation({
    required int id,
    required String comment,
    required int employeeId,
  });

  Future<DeviationStatusUpdateResponse> sendBackDeviation({
    required int id,
    required String comment,
    required int employeeId,
  });

  Future<List<DeviationComment>> getDeviationComments({
    required int id,
  });

  Future<DeviationAddCommentResponse> addManagerComment({
    required int createdBy,
    required int deviationId,
    required String comment,
  });
}
