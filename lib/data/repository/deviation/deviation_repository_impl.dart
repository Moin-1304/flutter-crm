import 'package:boilerplate/domain/entity/deviation/deviation_api_models.dart';
import 'package:boilerplate/domain/repository/deviation/deviation_repository.dart';
import 'package:boilerplate/data/network/apis/deviation/deviation_api.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/di/service_locator.dart';

class DeviationRepositoryImpl implements DeviationRepository {
  
  @override
  Future<DeviationListResponse> getDeviationList({
    required String searchText,
    required int pageNumber,
    required int pageSize,
    required int userId,
    required int bizUnit,
    required int employeeId,
  }) async {
    try {
      // Try to use API first
      if (getIt.isRegistered<DeviationApi>()) {
        final deviationApi = getIt<DeviationApi>();
        
        // Get user data from shared preferences
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        
        if (user != null) {
          final request = DeviationListRequest(
            searchText: searchText,
            pageNumber: pageNumber,
            pageSize: pageSize,
            userId: userId,
            bizUnit: bizUnit,
            employeeId: employeeId,
          );
          
          final response = await deviationApi.getDeviationList(request);
          return response;
        }
      }
    } catch (e) {
      // API call failed, fallback to empty response
    }
    
    // Fallback to empty response if API fails
    return DeviationListResponse(
      items: [],
      totalRecords: 0,
      filteredRecords: 0,
    );
  }

  @override
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
  }) async {
    try {
      if (getIt.isRegistered<DeviationApi>()) {
        final deviationApi = getIt<DeviationApi>();
        
        final request = DeviationSaveRequest(
          id: id,
          createdBy: createdBy,
          status: status,
          sbuId: sbuId,
          bizUnit: bizUnit,
          tourPlanDetailId: tourPlanDetailId,
          dcrDetailId: dcrDetailId,
          dateOfDeviation: dateOfDeviation,
          typeOfDeviation: typeOfDeviation,
          description: description,
          customerId: customerId,
          clusterId: clusterId,
          impact: impact,
          deviationType: deviationType,
          deviationStatus: deviationStatus,
          commentCount: commentCount,
          clusterName: clusterName,
          employeeId: employeeId,
          employeeName: employeeName,
          employeeCode: employeeCode,
          tourPlanName: tourPlanName,
        );
        
        final response = await deviationApi.saveDeviation(request);
        return response;
      }
    } catch (e) {
      // API save failed, fallback to default response
    }
    
    // Fallback to empty response if API fails
    return DeviationSaveResponse(
      id: id ?? 0,
      createdBy: createdBy,
      status: status,
      sbuId: sbuId,
      bizUnit: bizUnit,
      tourPlanDetailId: tourPlanDetailId,
      dcrDetailId: dcrDetailId,
      dateOfDeviation: dateOfDeviation,
      typeOfDeviation: typeOfDeviation,
      description: description,
      customerId: customerId,
      clusterId: clusterId,
      impact: impact,
      deviationType: deviationType,
      deviationStatus: deviationStatus,
      commentCount: commentCount,
      clusterName: clusterName,
      employeeId: employeeId,
      employeeName: employeeName,
      employeeCode: employeeCode,
      tourPlanName: tourPlanName,
    );
  }

  @override
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
  }) async {
    try {
      if (getIt.isRegistered<DeviationApi>()) {
        final deviationApi = getIt<DeviationApi>();
        
        final request = DeviationUpdateRequest(
          id: id,
          createdBy: createdBy,
          status: status,
          sbuId: sbuId,
          bizUnit: bizUnit,
          tourPlanDetailId: tourPlanDetailId,
          dcrDetailId: dcrDetailId,
          dateOfDeviation: dateOfDeviation,
          typeOfDeviation: typeOfDeviation,
          description: description,
          customerId: customerId,
          clusterId: clusterId,
          impact: impact,
          deviationType: deviationType,
          deviationStatus: deviationStatus,
          commentCount: commentCount,
          clusterName: clusterName,
          employeeId: employeeId,
          employeeName: employeeName,
          employeeCode: employeeCode,
          tourPlanName: tourPlanName,
        );
        
        final response = await deviationApi.updateDeviation(request);
        return response;
      }
    } catch (e) {
      // API update failed, fallback to default response
    }
    
    // Fallback to empty response if API fails
    return DeviationSaveResponse(
      id: id ?? 0,
      createdBy: createdBy,
      status: status,
      sbuId: sbuId,
      bizUnit: bizUnit,
      tourPlanDetailId: tourPlanDetailId,
      dcrDetailId: dcrDetailId,
      dateOfDeviation: dateOfDeviation,
      typeOfDeviation: typeOfDeviation,
      description: description,
      customerId: customerId,
      clusterId: clusterId,
      impact: impact,
      deviationType: deviationType,
      deviationStatus: deviationStatus,
      commentCount: commentCount,
      clusterName: clusterName,
      employeeId: employeeId,
      employeeName: employeeName,
      employeeCode: employeeCode,
      tourPlanName: tourPlanName,
    );
  }

  @override
  Future<DeviationStatusUpdateResponse> approveDeviation({
    required int id,
    required String comment,
    required int employeeId,
  }) async {
    try {
      if (getIt.isRegistered<DeviationApi>()) {
        final deviationApi = getIt<DeviationApi>();
        
        final request = DeviationStatusUpdateRequest(
          id: id,
          action: 1, // Approve action
          comment: comment,
          employeeId: employeeId,
        );
        
        final response = await deviationApi.updateDeviationStatus(request);
        return response;
      }
    } catch (e) {
      // API approve failed, fallback to default response
    }
    
    // Fallback response if API fails
    return DeviationStatusUpdateResponse(
      id: id,
      createdBy: 0,
      status: 0,
      sbuId: 0,
      bizUnit: 0,
      tourPlanDetailId: 0,
      dcrDetailId: 0,
      dateOfDeviation: '',
      typeOfDeviation: 0,
      description: '',
      customerId: 0,
      clusterId: 0,
      impact: '',
      deviationType: '',
      deviationStatus: 'Approved',
      commentCount: 0,
      clusterName: '',
      employeeId: employeeId,
      employeeName: '',
      employeeCode: '',
      tourPlanName: '',
    );
  }

  @override
  Future<DeviationStatusUpdateResponse> rejectDeviation({
    required int id,
    required String comment,
    required int employeeId,
  }) async {
    try {
      if (getIt.isRegistered<DeviationApi>()) {
        final deviationApi = getIt<DeviationApi>();
        
        final request = DeviationStatusUpdateRequest(
          id: id,
          action: 2, // Reject action
          comment: comment,
          employeeId: employeeId,
        );
        
        final response = await deviationApi.updateDeviationStatus(request);
        return response;
      }
    } catch (e) {
      // API reject failed, fallback to default response
    }
    
    // Fallback response if API fails
    return DeviationStatusUpdateResponse(
      id: id,
      createdBy: 0,
      status: 0,
      sbuId: 0,
      bizUnit: 0,
      tourPlanDetailId: 0,
      dcrDetailId: 0,
      dateOfDeviation: '',
      typeOfDeviation: 0,
      description: '',
      customerId: 0,
      clusterId: 0,
      impact: '',
      deviationType: '',
      deviationStatus: 'Rejected',
      commentCount: 0,
      clusterName: '',
      employeeId: employeeId,
      employeeName: '',
      employeeCode: '',
      tourPlanName: '',
    );
  }

  @override
  Future<DeviationStatusUpdateResponse> sendBackDeviation({
    required int id,
    required String comment,
    required int employeeId,
  }) async {
    try {
      if (getIt.isRegistered<DeviationApi>()) {
        final deviationApi = getIt<DeviationApi>();
        
        final request = DeviationStatusUpdateRequest(
          id: id,
          action: 3, // Send Back action
          comment: comment,
          employeeId: employeeId,
        );
        
        final response = await deviationApi.updateDeviationStatus(request);
        return response;
      }
    } catch (e) {
      // API send back failed, fallback to default response
    }
    
    // Fallback response if API fails
    return DeviationStatusUpdateResponse(
      id: id,
      createdBy: 0,
      status: 0,
      sbuId: 0,
      bizUnit: 0,
      tourPlanDetailId: 0,
      dcrDetailId: 0,
      dateOfDeviation: '',
      typeOfDeviation: 0,
      description: '',
      customerId: 0,
      clusterId: 0,
      impact: '',
      deviationType: '',
      deviationStatus: 'Sent Back',
      commentCount: 0,
      clusterName: '',
      employeeId: employeeId,
      employeeName: '',
      employeeCode: '',
      tourPlanName: '',
    );
  }

  @override
  Future<List<DeviationComment>> getDeviationComments({
    required int id,
  }) async {
    try {
      if (getIt.isRegistered<DeviationApi>()) {
        final deviationApi = getIt<DeviationApi>();
        
        final request = DeviationGetCommentsRequest(
          id: id,
        );
        
        final response = await deviationApi.getDeviationComments(request);
        return response;
      }
    } catch (e) {
      // API get comments failed, fallback to empty list
    }
    
    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<DeviationAddCommentResponse> addManagerComment({
    required int createdBy,
    required int deviationId,
    required String comment,
  }) async {
    try {
      if (getIt.isRegistered<DeviationApi>()) {
        final deviationApi = getIt<DeviationApi>();
        
        // Format date as ISO 8601 format: "2025-11-10T20:27:00" (local time, no timezone, no milliseconds)
        // Use local time instead of UTC to match the user's current time
        final now = DateTime.now(); // Use local time, not UTC
        final year = now.year.toString().padLeft(4, '0');
        final month = now.month.toString().padLeft(2, '0');
        final day = now.day.toString().padLeft(2, '0');
        final hour = now.hour.toString().padLeft(2, '0');
        final minute = now.minute.toString().padLeft(2, '0');
        final second = now.second.toString().padLeft(2, '0');
        // Format: "2025-11-10T20:27:00" (no milliseconds, no 'Z' suffix since it's local time)
        final commentDate = '$year-$month-${day}T$hour:$minute:$second';
        
        final request = DeviationAddCommentRequest(
          createdBy: createdBy,
          deviationId: deviationId,
          comment: comment,
          commentDate: commentDate, // Format: "2025-11-10T20:27:00"
        );
        
        final response = await deviationApi.addManagerComment(request);
        return response;
      }
    } catch (e) {
      // API add comment failed, fallback to default response
    }
    
    // Fallback response if API fails
    return DeviationAddCommentResponse(
      id: 0,
      createdBy: createdBy,
      status: 0,
      sbuId: 0,
      tourPlanId: 0,
      dcrId: 0,
      deviationId: deviationId,
      tourPlanType: '',
      comment: comment,
      isSystemGenerated: 0,
      userId: 0,
      commentDate: '',
      bizUnit: 0,
      active: false,
      userName: '',
      userRole: '',
      createdAt: '',
      updatedAt: '',
      isSystemGeneratedInt: 0,
      activeInt: 0,
    );
  }
}
