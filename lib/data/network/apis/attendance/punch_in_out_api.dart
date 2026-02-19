import 'package:dio/dio.dart';
import 'dart:convert';
import '../../../../core/data/network/dio/dio_client.dart';
import '../../constants/endpoints.dart';
import '../../../../domain/entity/attendance/punch_in_out_api_models.dart';

class PunchInOutApi {
  final DioClient _dioClient;

  PunchInOutApi(this._dioClient);

  /// Save Punch In/Out Record
  /// URL: /api/PunchInOut/Save
  Future<PunchInOutResponse> savePunchInOut(PunchInOutSaveRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.punchInOutSave,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.json,
        ),
      );

      if (response.data != null) {
        final dynamic raw = response.data;
        if (raw is Map<String, dynamic>) {
          return PunchInOutResponse.fromJson(raw);
        }
        if (raw is String) {
          final t = raw.trim();
          if (t.isEmpty) {
            // Treat empty body as OK and synthesize a minimal response
            return PunchInOutResponse(
              id: 0,
              createdBy: request.createdBy,
              status: request.status,
              sbuId: request.sbuId,
              employeeId: request.employeeId,
              userId: request.userId,
              checkInStatus: request.checkInStatus,
              bizUnit: request.bizUnit,
              userName: '',
              sbuName: '',
              lastLoggedOutTime: null,
              logDetails: const [],
              kilometerIn: request.kilometerIn,
              kilometerOut: request.kilometerOut,
            );
          }
          if (t.startsWith('{') || t.startsWith('[')) {
            final decoded = jsonDecode(t);
            if (decoded is Map<String, dynamic>) {
              return PunchInOutResponse.fromJson(decoded);
            }
          }
          // Non-JSON string like "OK" or "true"
          return PunchInOutResponse(
            id: 0,
            createdBy: request.createdBy,
            status: request.status,
            sbuId: request.sbuId,
            employeeId: request.employeeId,
            userId: request.userId,
            checkInStatus: request.checkInStatus,
            bizUnit: request.bizUnit,
            userName: '',
            sbuName: '',
            lastLoggedOutTime: null,
            logDetails: const [],
            kilometerIn: request.kilometerIn,
            kilometerOut: request.kilometerOut,
          );
        }
        throw Exception('Unexpected response type: ${raw.runtimeType}');
      } else {
        throw Exception('No response data received');
      }
    } on DioException catch (e) {
      // Enhanced error handling for DioException
      String errorMessage = 'Failed to save punch in/out';
      
      if (e.response != null) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        
        // Try to extract error message from response
        if (responseData is Map<String, dynamic>) {
          final message = responseData['message'] ?? 
                         responseData['Message'] ?? 
                         responseData['errorMessage'] ?? 
                         responseData['error'] ?? 
                         responseData['Error'];
          if (message != null && message.toString().isNotEmpty) {
            errorMessage = message.toString();
          } else if (statusCode != null) {
            if (statusCode == 500) {
              errorMessage = 'Server error occurred. Please try again later.';
            } else if (statusCode == 400) {
              errorMessage = 'Invalid request. Please check your input and try again.';
            } else if (statusCode == 401) {
              errorMessage = 'Authentication failed. Please login again.';
            } else {
              errorMessage = 'Failed to save punch in/out. Please try again.';
            }
          }
        } else if (responseData is String && responseData.isNotEmpty) {
          errorMessage = responseData;
        } else if (statusCode != null) {
          if (statusCode == 500) {
            errorMessage = 'Server error occurred. Please try again later.';
          } else {
            errorMessage = 'Failed to save punch in/out (Status $statusCode). Please try again.';
          }
        }
      } else {
        // No response - connection/timeout errors
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'Connection error. Please check your internet connection and try again.';
        } else {
          errorMessage = 'Network error. Please check your connection and try again.';
        }
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      // For non-DioException errors, provide a generic message
      throw Exception('Failed to save punch in/out. Please try again.');
    }
  }

  /// Get Punch In/Out List
  /// URL: /api/PunchInOut/List
  Future<PunchInOutListResponse> getPunchInOutList(PunchInOutListRequest request) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.punchInOutList,
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.json,
        ),
      );

      if (response.data != null) {
        final dynamic raw = response.data;
        if (raw is Map<String, dynamic>) {
          return PunchInOutListResponse.fromJson(raw);
        }
        if (raw is String) {
          final t = raw.trim();
          if (t.isEmpty) {
            return PunchInOutListResponse(items: const [], totalRecords: 0, filteredRecords: 0);
          }
          if (t.startsWith('{') || t.startsWith('[')) {
            final decoded = jsonDecode(t);
            if (decoded is Map<String, dynamic>) {
              return PunchInOutListResponse.fromJson(decoded);
            }
          }
          // Non-JSON string fallback: return empty list
          return PunchInOutListResponse(items: const [], totalRecords: 0, filteredRecords: 0);
        }
        throw Exception('Unexpected response type: ${raw.runtimeType}');
      } else {
        throw Exception('No response data received');
      }
    } on DioException catch (e) {
      // Enhanced error handling for DioException
      String errorMessage = 'Failed to load punch records';
      
      if (e.response != null) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 500) {
          errorMessage = 'Server error occurred. Please try again later.';
        } else if (statusCode == 400) {
          errorMessage = 'Invalid request. Please try again.';
        } else if (statusCode == 401) {
          errorMessage = 'Authentication failed. Please login again.';
        } else {
          errorMessage = 'Failed to load punch records. Please try again.';
        }
      } else {
        // No response - connection/timeout errors
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout) {
          errorMessage = 'Connection error. Please check your internet connection.';
        } else {
          errorMessage = 'Network error. Please check your connection.';
        }
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      // For non-DioException errors, provide a generic message
      throw Exception('Failed to load punch records. Please try again.');
    }
  }
}
