import 'package:dio/dio.dart';
import '../../../../core/data/network/dio/dio_client.dart';
import '../../constants/endpoints.dart';
import '../../../../domain/entity/workflow/workflow_api_models.dart';

class WorkflowApi {
  final DioClient _dioClient;

  WorkflowApi(this._dioClient);

  /// Get all workflow actions
  Future<WorkflowGetAllActionsResponse> getAllActions(
      WorkflowGetAllActionsRequest request) async {
    try {
      print('═══════════════════════════════════════════════════════════');
      print('📤 Workflow GetAllActions API Request');
      print('═══════════════════════════════════════════════════════════');
      print('URL: ${Endpoints.workflowGetAllActions}');
      print('Request: ${request.toJson()}');

      final response = await _dioClient.dio.post(
        Endpoints.workflowGetAllActions,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Data Type: ${response.data.runtimeType}');
      print('Response Data: ${response.data}');

      // Handle 204 No Content response
      if (response.statusCode == 204) {
        print('⚠️ Received 204 No Content - No workflow actions available');
        // Return empty response when no workflow is configured
        return WorkflowGetAllActionsResponse(
          id: 0,
          processName: '',
          workFlowStatus: 0,
          hasEdit: false,
          processActionDetails: [],
        );
      }

      // Handle null or empty response data
      if (response.data == null || response.data.toString().isEmpty) {
        print('⚠️ Response data is null or empty');
        return WorkflowGetAllActionsResponse(
          id: 0,
          processName: '',
          workFlowStatus: 0,
          hasEdit: false,
          processActionDetails: [],
        );
      }

      // Handle string response (should be JSON string)
      if (response.data is String) {
        print('⚠️ Response is a String, attempting to parse as JSON');
        try {
          // Try to parse the string as JSON
          final jsonData = response.data as String;
          if (jsonData.trim().isEmpty) {
            return WorkflowGetAllActionsResponse(
              id: 0,
              processName: '',
              workFlowStatus: 0,
              hasEdit: false,
              processActionDetails: [],
            );
          }
          // If it's a JSON string, it should have been parsed by Dio already
          // But if not, we'll handle it in the catch block
        } catch (e) {
          print('❌ Error parsing string response: $e');
          return WorkflowGetAllActionsResponse(
            id: 0,
            processName: '',
            workFlowStatus: 0,
            hasEdit: false,
            processActionDetails: [],
          );
        }
      }

      // Normal JSON response
      if (response.data is Map<String, dynamic>) {
        print('✅ Parsing JSON response');
        return WorkflowGetAllActionsResponse.fromJson(response.data);
      }

      // Fallback: return empty response
      print('⚠️ Unknown response format, returning empty response');
      return WorkflowGetAllActionsResponse(
        id: 0,
        processName: '',
        workFlowStatus: 0,
        hasEdit: false,
        processActionDetails: [],
      );
    } catch (e) {
      print('❌ Error in workflow API: $e');
      if (e is DioException) {
        if (e.response?.statusCode == 204) {
          print('⚠️ 204 No Content response - returning empty workflow');
          return WorkflowGetAllActionsResponse(
            id: 0,
            processName: '',
            workFlowStatus: 0,
            hasEdit: false,
            processActionDetails: [],
          );
        }
        print('DioException Status: ${e.response?.statusCode}');
        print('DioException Data: ${e.response?.data}');
      }
      throw Exception('Failed to get workflow actions: ${e.toString()}');
    }
  }

  /// Get user page privileges
  Future<WorkflowGetUserPagePrivilegesResponse> getUserPagePrivileges(
      WorkflowGetUserPagePrivilegesRequest request) async {
    try {
      print('═══════════════════════════════════════════════════════════');
      print('📤 Workflow GetUserPagePrivileges API Request');
      print('═══════════════════════════════════════════════════════════');
      print('URL: ${Endpoints.workflowGetUserPagePrivileges}');
      print('Request: ${request.toJson()}');

      final response = await _dioClient.dio.post(
        Endpoints.workflowGetUserPagePrivileges,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Data Type: ${response.data.runtimeType}');
      print('Response Data: ${response.data}');

      // Handle null or empty response data
      if (response.data == null || response.data.toString().isEmpty) {
        print('⚠️ Response data is null or empty');
        return WorkflowGetUserPagePrivilegesResponse(buttonPrivileges: {});
      }

      // Normal JSON response
      if (response.data is Map<String, dynamic>) {
        print('✅ Parsing JSON response');
        return WorkflowGetUserPagePrivilegesResponse.fromJson(response.data);
      }

      // Fallback: return empty response
      print('⚠️ Unknown response format, returning empty response');
      return WorkflowGetUserPagePrivilegesResponse(buttonPrivileges: {});
    } catch (e) {
      print('❌ Error in GetUserPagePrivileges API: $e');
      if (e is DioException) {
        print('DioException Status: ${e.response?.statusCode}');
        print('DioException Data: ${e.response?.data}');
      }
      throw Exception('Failed to get user page privileges: ${e.toString()}');
    }
  }
}
