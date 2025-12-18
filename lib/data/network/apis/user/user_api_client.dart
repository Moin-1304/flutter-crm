import 'dart:math' as math;
import 'dart:convert';
import 'package:dio/dio.dart';

import '../../../../core/data/network/dio/dio_client.dart';
import '../../../../domain/entity/user/user_detail.dart';
import '../../constants/endpoints.dart';
import 'lib/domain/entity/tour_plan/calendar_view_data.dart';
import 'lib/domain/entity/tour_plan/tour_plan_api_models.dart';

class UserApiClient {
  final DioClient _dioClient;

  UserApiClient(this._dioClient);

  Future<Response> get(String endpoint, {Map<String, dynamic>? queryParams, String? token}) async {
    return await _dioClient.dio.get(
      endpoint,
      queryParameters: queryParams,
      options: Options(headers: {"Authorization": "Bearer $token"}),
    );
  }

  /// Get user details by ID with bearer token authentication
  Future<UserDetail> getUserById(int userId, String token) async {
    try {
      final response = await _dioClient.dio.get(
        Endpoints.userGet,
        queryParameters: {'Id': userId},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data != null) {
        return UserDetail.fromJson(response.data);
      } else {
        throw Exception('No user data received');
      }
    } catch (e) {
      throw Exception('Failed to fetch user details: ${e.toString()}');
    }
  }

  /// Get tour plan calendar view data
  Future<List<CalendarViewData>> getTourPlanCalendarViewData(
    CalendarViewRequest request,
    String token,
  ) async {
    try {
      // Debug: log endpoint and payload (token redacted)

      final response = await _dioClient.dio.post(
        Endpoints.tourPlanCalendarView,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      

      // Accept response as List or wrapped in a Map
      if (response.data == null) {
        throw Exception('No calendar view data received');
      }

      dynamic payload = response.data;
      if (payload is Map) {
        payload = payload['items'] ?? payload['data'] ?? payload['result'] ?? payload['Records'] ?? [];
      }

      if (payload is! List) {
        throw Exception('Unexpected calendar view response shape: ${response.data.runtimeType}');
      }

      return payload
          .map<CalendarViewData>((json) => CalendarViewData.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch calendar view data: ${e.toString()}');
    }
  }

  /// Get tour plan list data
  Future<TourPlanGetResponse> getTourPlanDetail(
    TourPlanGetRequest request,
    String token,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.tourPlanGet,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data != null) {
        return TourPlanGetResponse.fromJson(response.data);
      } else {
        throw Exception('No tour plan data received');
      }
    } catch (e) {
      throw Exception('Failed to fetch tour plan list: ${e.toString()}');
    }
  }

  /// Get tour plan list data using /List endpoint (calendar item list data)
  Future<TourPlanGetResponse> getTourPlanListData(
    TourPlanGetRequest request,
    String token,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.tourPlanList,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data != null) {
        return TourPlanGetResponse.fromJson(response.data);
      } else {
        throw Exception('No tour plan list data received');
      }
    } catch (e) {
      throw Exception('Failed to fetch tour plan list data: ${e.toString()}');
    }
  }

  /// Get tour plan details by TourPlanId and optional Id, userId
  /// API: GET PharmaCRM/TourPlan/Get with query params
  /// Keep response as TourPlanGetResponse (items list), server filters by ids
  Future<TourPlanGetResponse> getTourPlanDetails({
    required int tourPlanId,
    int? id,
    required String token,
    int? userId,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        Endpoints.tourPlanGet,
        queryParameters: {
          'TourPlanId': tourPlanId,
          if (id != null) 'Id': id,
          if (userId != null) 'UserId': userId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data != null) {
        // Check if response is a single TourPlanItem or TourPlanGetResponse
        if (response.data is Map && response.data['items'] != null) {
          // Standard response with items array
          return TourPlanGetResponse.fromJson(response.data);
        } else {
          // Single TourPlanItem response - wrap it in TourPlanGetResponse
          final singleItem = TourPlanItem.fromJson(response.data);
          return TourPlanGetResponse(
            items: [singleItem],
            totalRecords: 1,
            filteredRecords: 1,
          );
        }
      } else {
        throw Exception('No tour plan details received');
      }
    } catch (e) {
      throw Exception('Failed to fetch tour plan details: ${e.toString()}');
    }
  }

  /// Save tour plan (dummy request allowed). Returns minimal { msg, status }.
  Future<Map<String, dynamic>> saveTourPlan(
    Map<String, dynamic> requestBody,
    String token,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.tourPlanSave,
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      final data = response.data;
      return data;
    } catch (e) {
      rethrow;
    }
  }

  /// Update tour plan. Returns minimal { msg, status }.
  Future<Map<String, dynamic>> updateTourPlan(
    Map<String, dynamic> requestBody,
    String token,
  ) async {
    try {

      final response = await _dioClient.dio.post(
        Endpoints.tourPlanUpdate,
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );


      final data = response.data;
      if (data is Map<String, dynamic>) {
        return {
          'msg': data['msg'] ?? 'Success',
          'status': data['status'] ?? true,
        };
      }
      return {
        'msg': 'Success',
        'status': true,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Get tour plan aggregate count summary
  Future<TourPlanAggregateCountResponse> getTourPlanAggregateCountSummary(
    TourPlanAggregateCountRequest request,
    String token,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.tourPlanAggregateCountSummary,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data != null) {
        return TourPlanAggregateCountResponse.fromJson(response.data);
      } else {
        throw Exception('No aggregate count data received');
      }
    } catch (e) {
      throw Exception('Failed to fetch aggregate count summary: ${e.toString()}');
    }
  }

  /// Get tour plan summary
  Future<TourPlanGetSummaryResponse> getTourPlanSummary(
    TourPlanGetSummaryRequest request,
    String token,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.tourPlanGetSummary,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data != null) {
        return TourPlanGetSummaryResponse.fromJson(response.data);
      } else {
        throw Exception('No tour plan summary data received');
      }
    } catch (e) {
      throw Exception('Failed to fetch tour plan summary: ${e.toString()}');
    }
  }

  /// Get tour plan manager summary
  Future<TourPlanGetManagerSummaryResponse> getTourPlanManagerSummary(
    TourPlanGetManagerSummaryRequest request,
    String token,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.tourPlanGetManagerSummary,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data != null) {
        return TourPlanGetManagerSummaryResponse.fromJson(response.data);
      } else {
        throw Exception('No tour plan manager summary data received');
      }
    } catch (e) {
      throw Exception('Failed to fetch tour plan manager summary: ${e.toString()}');
    }
  }

  /// Get tour plan employee list summary
  Future<TourPlanGetEmployeeListSummaryResponse> getTourPlanEmployeeListSummary(
    TourPlanGetEmployeeListSummaryRequest request,
    String token,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.tourPlanGetEmployeeListSummary,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data != null) {
        return TourPlanGetEmployeeListSummaryResponse.fromJson(response.data);
      } else {
        throw Exception('No tour plan employee list summary data received');
      }
    } catch (e) {
      throw Exception('Failed to fetch tour plan employee list summary: ${e.toString()}');
    }
  }

  /// Approve a single tour plan entry
  Future<TourPlanActionResponse> approveSingleTourPlan(
    TourPlanActionRequest request,
    String token,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.tourPlanApproveSingle,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data != null) {
        return TourPlanActionResponse.fromJson(response.data);
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to approve tour plan: ${e.toString()}');
    }
  }

  /// Reject a single tour plan entry
  Future<TourPlanActionResponse> rejectSingleTourPlan(
    TourPlanActionRequest request,
    String token,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.tourPlanRejectSingle,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data != null) {
        return TourPlanActionResponse.fromJson(response.data);
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to reject tour plan: ${e.toString()}');
    }
  }

  /// Bulk approve multiple tour plan entries
  Future<TourPlanActionResponse> bulkApproveTourPlans(
    TourPlanBulkActionRequest request,
    String token,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.tourPlanBulkApprove,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data != null) {
        return TourPlanActionResponse.fromJson(response.data);
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to bulk approve tour plans: ${e.toString()}');
    }
  }

  /// Bulk send back multiple tour plan entries
  Future<TourPlanActionResponse> bulkSendBackTourPlans(
    TourPlanBulkActionRequest request,
    String token,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.tourPlanBulkSendBack,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data != null) {
        return TourPlanActionResponse.fromJson(response.data);
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      throw Exception('Failed to bulk send back tour plans: ${e.toString()}');
    }
  }

  /// Get mapped customers by employee ID
  Future<GetMappedCustomersByEmployeeIdResponse> getMappedCustomersByEmployeeId(
    GetMappedCustomersByEmployeeIdRequest request,
    String token,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.tourPlanGetMappedCustomersByEmployeeId,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data != null) {
        return GetMappedCustomersByEmployeeIdResponse.fromJson(response.data);
      } else {
        throw Exception('No mapped customers data received');
      }
    } catch (e) {
      throw Exception('Failed to fetch mapped customers: ${e.toString()}');
    }
  }

  /// Save a tour plan comment
  Future<TourPlanCommentSaveResponse> saveTourPlanComment(
    TourPlanCommentSaveRequest request,
    String token,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.tourPlanCommentSave,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data != null) {
        return TourPlanCommentSaveResponse.fromJson(response.data);
      } else {
        throw Exception('No tour plan comment save response received');
      }
    } catch (e) {
      throw Exception('Failed to save tour plan comment: ${e.toString()}');
    }
  }

  /// Delete a tour plan by ID
  /// API: GET /api/PharmaCRM/TourPlan/Delete?Id={id}
  /// Note: The API uses GET method for delete operations
  Future<TourPlanActionResponse> deleteTourPlan(
    int id,
    String token,
  ) async {
    try {
      final response = await _dioClient.dio.get(
        Endpoints.tourPlanDelete,
        queryParameters: {
          'Id': id,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data != null) {
        // Try to parse as TourPlanActionResponse
        if (response.data is Map) {
          return TourPlanActionResponse.fromJson(response.data);
        } else {
          // If response is not in expected format, return success
          return TourPlanActionResponse(status: true, message: 'Tour plan deleted successfully');
        }
      } else {
        // If no response data, assume success
        return TourPlanActionResponse(status: true, message: 'Tour plan deleted successfully');
      }
    } catch (e) {
      throw Exception('Failed to delete tour plan: ${e.toString()}');
    }
  }

  /// Get tour plan comments list
  Future<List<TourPlanCommentItem>> getTourPlanCommentsList(
    TourPlanCommentGetListRequest request,
    String token,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        Endpoints.tourPlanCommentGetList,
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.data != null) {
        // Handle array response (expected format)
        if (response.data is List) {
          final List<dynamic> dataList = response.data as List;
          
          final comments = dataList
              .map((item) {
                try {
                  return TourPlanCommentItem.fromJson(item as Map<String, dynamic>);
                } catch (e) {
                  rethrow;
                }
              })
              .toList();
          
          return comments;
        } 
        // Handle single object response (unexpected but handle gracefully)
        else if (response.data is Map) {
          return [TourPlanCommentItem.fromJson(response.data as Map<String, dynamic>)];
        } 
        // Handle empty response
        else if (response.data.toString().isEmpty) {
          return [];
        }
        else {
          throw Exception('Unexpected response format: ${response.data.runtimeType}');
        }
      } else {
        throw Exception('No tour plan comments list response received');
      }
    } catch (e, stackTrace) {
      throw Exception('Failed to fetch tour plan comments list: ${e.toString()}');
    }
  }
}
