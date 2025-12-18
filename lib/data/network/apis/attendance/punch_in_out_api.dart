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
          );
        }
        throw Exception('Unexpected response type: ${raw.runtimeType}');
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to save punch in/out: ${e.toString()}');
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
    } catch (e) {
      throw Exception('Failed to get punch in/out list: ${e.toString()}');
    }
  }
}
