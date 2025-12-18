import 'package:dio/dio.dart';
import '../../../../core/data/network/dio/dio_client.dart';
import '../../constants/endpoints.dart';
import '../../../../domain/entity/deviation/deviation_api_models.dart';

class DeviationApi {
  final DioClient _dioClient;

  DeviationApi(this._dioClient);

  /// Get deviation list with filter criteria
  Future<DeviationListResponse> getDeviationList(DeviationListRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.deviationList,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        return DeviationListResponse.fromJson(response.data);
      } else {
        throw Exception('No deviation data received');
      }
    } catch (e) {
      throw Exception('Failed to fetch deviation list: ${e.toString()}');
    }
  }

  /// Save deviation with details
  Future<DeviationSaveResponse> saveDeviation(DeviationSaveRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.deviationSave,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        return DeviationSaveResponse.fromJson(response.data);
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to save deviation: ${e.toString()}');
    }
  }

  /// Update deviation with details
  Future<DeviationSaveResponse> updateDeviation(DeviationUpdateRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.deviationUpdate,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        return DeviationSaveResponse.fromJson(response.data);
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to update deviation: ${e.toString()}');
    }
  }

  /// Update deviation status (Approve/Reject/Send Back)
  Future<DeviationStatusUpdateResponse> updateDeviationStatus(DeviationStatusUpdateRequest request) async {
    try {
      final response = await _dioClient.dio.post(
       Endpoints.deviationApprove,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        return DeviationStatusUpdateResponse.fromJson(response.data);
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to update deviation status: ${e.toString()}');
    }
  }

  /// Get deviation comments
  Future<List<DeviationComment>> getDeviationComments(DeviationGetCommentsRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.deviationGetComments,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        if (response.data is List) {
          return (response.data as List)
              .map((item) => DeviationComment.fromJson(item))
              .toList();
        } else {
          throw Exception('Invalid response format - expected array');
        }
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to get deviation comments: ${e.toString()}');
    }
  }

  /// Add manager comment to deviation
  Future<DeviationAddCommentResponse> addManagerComment(DeviationAddCommentRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.deviationAddComment,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data != null) {
        return DeviationAddCommentResponse.fromJson(response.data);
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to add manager comment: ${e.toString()}');
    }
  }
}
