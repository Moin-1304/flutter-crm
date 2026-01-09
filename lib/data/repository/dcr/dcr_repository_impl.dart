import 'dart:async';
import 'package:boilerplate/domain/entity/dcr/dcr.dart';
import 'package:boilerplate/domain/entity/dcr/dcr_api_models.dart';
import 'package:boilerplate/domain/entity/dcr/dcr_action_api_models.dart';
import 'package:boilerplate/domain/repository/dcr/dcr_repository.dart';
import 'package:boilerplate/data/network/apis/dcr/dcr_api.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api_models.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/di/service_locator.dart';

class DcrRepositoryImpl implements DcrRepository {
  final List<DcrEntry> _items = <DcrEntry>[];

  DcrRepositoryImpl() {
    _seedDemoData();
  }

  @override
  Future<DcrEntry> create(CreateDcrParams params) async {
    try {
      // Try to use API first
      if (getIt.isRegistered<DcrApi>()) {
        final dcrApi = getIt<DcrApi>();
        
        // Use IDs from params if available, otherwise get from shared preferences
        int employeeIdInt = int.tryParse(params.employeeId) ?? 0;
        int userIdInt = params.userId ?? 0;
        int bizunitInt = params.bizunit ?? 0;
        String employeeName = params.employeeName;
        
        // Fallback to shared preferences if IDs not provided
        if (employeeIdInt == 0 || userIdInt == 0 || bizunitInt == 0) {
          final sharedPrefHelper = getIt<SharedPreferenceHelper>();
          final user = await sharedPrefHelper.getUser();
          
          if (user != null) {
            employeeIdInt = employeeIdInt == 0 ? user.id : employeeIdInt;
            userIdInt = userIdInt == 0 ? (user.userId ?? user.id) : userIdInt;
            bizunitInt = bizunitInt == 0 ? user.sbuId : bizunitInt;
            employeeName = params.employeeName.isEmpty ? user.name : params.employeeName;
          }
        }
        
        // Validate required IDs
        if (params.typeOfWorkId == null || params.cityId == null || params.customerId == null) {
          throw Exception('Missing required IDs (typeOfWorkId, cityId, or customerId)');
        }
        
        // Create tour plan DCR details with IDs from params
        final int? linkedTourPlanIdInt = int.tryParse(params.linkedTourPlanId ?? '');
        final tourPlanDetails = [
          TourPlanDcrDetailSave(
            // Required fields
            planDate: params.date.toIso8601String().split('T')[0],
            typeOfWorkId: params.typeOfWorkId!,
            cityId: params.cityId!,
            customerId: params.customerId!,
            statusId: params.submit ? 3 : 0, // 3 for submitted as per API, 0 for draft
            remarks: params.keyDiscussionPoints.isNotEmpty ? params.keyDiscussionPoints : params.purposeOfVisit,
            isBasedOnPlan: 1,
            bizunit: bizunitInt,
            samplesToDistribute: params.samplesDistributed.isNotEmpty ? params.samplesDistributed : '',
            productsToDiscuss: params.productsDiscussed.isNotEmpty ? params.productsDiscussed : '',
            customerName: params.customer,
            visitTime: _formatVisitTime(params.date),
            visitDuration: params.callDurationMinutes.toDouble(),
            // Optional fields (left mostly null to match desired payload)
            id: null,
            clusterId: null,
            customerFeedback: null,
            isDeviationRequested: false,
            reasonForDeviation: null,
            deviationStatus: null,
            comments: null,
            deviatedFrom: null,
            tourPlanDetailId: null,
            isJoinVisit: null,
            joinVisitWithEmployeeId: null,
            joinVisitWithEmployeeName: null,
            location: null,
            latitude: params.latitude,
            longitude: params.longitude,
            createdBy: null,
            status: 0,
            sbuId: 0,
            tourPlanId: linkedTourPlanIdInt,
            employeeId: 0,
            dcrDate: '0001-01-01',
            active: true,
            userId: 0,
            territory: null,
            cluster: null,
            dcrType: null,
            dcrStatus: null,
            calls: null,
            expenses: null,
            createdAt: null,
            updatedAt: null,
            clusterNames: null,
          ),
        ];
        
        final request = DcrSaveRequest(
          // Top-level fields aligned to required contract
          id: null,
          cityId: null,
          createdBy: null,
          status: 0,
          sbuId: 0,
          dcrStatusId: params.submit ? 3 : 1, // 3 for submitted, 1 for draft
          dcrId: null,
          tourPlanId: linkedTourPlanIdInt ?? 0,
          employeeId: employeeIdInt,
          dcrDate: params.date.toIso8601String().split('T')[0],
          isDeviationRequested: false,
          isBasedOnPlan: linkedTourPlanIdInt != null,
          deviatedFrom: null,
          remarks: null,
          active: true,
          userId: userIdInt,
          tourPlanDCRDetails: tourPlanDetails,
          employeeName: employeeName.isNotEmpty ? employeeName : 'Unknown',
          designation: null,
          clusterNames: null,
          statusText: null,
          typeOfWork: null,
          customerName: null,
          expenses: const [], // Always empty array when linking with tour plan - expenses should not be included
          customerId: null,
          samplesToDistribute: null,
          productsToDiscuss: null,
          transactionType: null,
          typeOfWorkId: null,
          isGeneric: null,
          coVisit: params.coVisit,
          coVisitorDetails: params.coVisit && params.coVisitorId != null
              ? [
                  CoVisitorDetail(
                    id: null,
                    dcrDetailId: null,
                    coVisitorId: params.coVisitorId!,
                    coordinatorId: employeeIdInt,
                    remarks: null,
                    active: 1,
                    slNo: null,
                    coVisitorName: null,
                  ),
                ]
              : const [], // Empty array when coVisit is false
        );
        
        final response = await dcrApi.saveDcr(request);
        
        if (response.success) {
          // Create local entry for UI consistency
          final DateTime now = DateTime.now();
          final DcrEntry entry = DcrEntry(
            id: _genId(),
            date: DateTime(params.date.year, params.date.month, params.date.day),
            cluster: params.cluster,
            customer: params.customer,
            purposeOfVisit: params.purposeOfVisit,
            callDurationMinutes: params.callDurationMinutes,
            productsDiscussed: params.productsDiscussed,
            samplesDistributed: params.samplesDistributed,
            keyDiscussionPoints: params.keyDiscussionPoints,
            status: params.submit ? DcrStatus.submitted : DcrStatus.draft,
            employeeId: params.employeeId,
            employeeName: params.employeeName,
            linkedTourPlanId: params.linkedTourPlanId,
            geoProximity: params.geoProximity,
            createdAt: now,
            updatedAt: now,
          );
          _items.add(entry);
          return entry;
        } else {
          throw Exception('API save failed: ${response.message}');
        }
      }
    } catch (e) {
      rethrow; // Re-throw to show error to user
    }
    
    // Fallback to local save
    final DateTime now = DateTime.now();
    final DcrEntry entry = DcrEntry(
      id: _genId(),
      date: DateTime(params.date.year, params.date.month, params.date.day),
      cluster: params.cluster,
      customer: params.customer,
      purposeOfVisit: params.purposeOfVisit,
      callDurationMinutes: params.callDurationMinutes,
      productsDiscussed: params.productsDiscussed,
      samplesDistributed: params.samplesDistributed,
      keyDiscussionPoints: params.keyDiscussionPoints,
      status: params.submit ? DcrStatus.submitted : DcrStatus.draft,
      employeeId: params.employeeId,
      employeeName: params.employeeName,
      linkedTourPlanId: params.linkedTourPlanId,
      geoProximity: params.geoProximity,
      createdAt: now,
      updatedAt: now,
    );
    _items.add(entry);
    return entry;
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
  }

  @override
  Future<DcrEntry?> getById(String id, {String? dcrId}) async {
    try {
      // Try to use API first
      if (getIt.isRegistered<DcrApi>()) {
        final dcrApi = getIt<DcrApi>();
        
        // Get user data from shared preferences
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        
        if (user != null) {
          // Parse the ID to get both id and dcrId
          final intId = int.tryParse(id) ?? 0;
          final intDcrId = dcrId != null ? int.tryParse(dcrId) ?? intId : intId;
          
          // First try direct GET API call with provided dcrId
          try {
            final response = await dcrApi.getDcrDetails(intId, intDcrId);
            return _convertApiResponseToDcrEntry(response);
          } catch (e) {
            
            // Get the correct dcrId from List API with better parameters
            try {
              final listReq = DcrListRequest(
                pageNumber: 1,
                pageSize: 50,
                userId: user.userId ?? user.id,
                bizunit: user.sbuId,
                employeeId: user.id,
                // Use current date and wider range
                dcrDate: DateTime.now().toIso8601String().split('T')[0],
                fromDate: DateTime.now().subtract(const Duration(days: 365)).toIso8601String().split('T')[0], // 1 year back
                toDate: DateTime.now().add(const Duration(days: 365)).toIso8601String().split('T')[0], // 1 year forward
                id: intId, // Search by ID instead of dcrId
                dcrId: null, // Don't filter by dcrId
                status: null,
                searchText: null,
                filterExpression: null,
                sortOrder: 0,
                sortDir: 0,
                sortField: null,
                transactionType: '',
              );
              
              final listResp = await dcrApi.getDcrList(listReq);
              
              if (listResp.items.isNotEmpty) {
                // Find the matching DcrApiItem by id
                final match = listResp.items.firstWhere((e) => e.id == intId, orElse: () => listResp.items.first);
                final correctDcrId = match.dcrId;
                
                // Now call the GET API with the correct dcrId
                try {
                  final response = await dcrApi.getDcrDetails(intId, correctDcrId);
                  return _convertApiResponseToDcrEntry(response);
                } catch (e2) {
                  // Fallback: use the list data directly
                  return _convertApiItemToDcrEntry(match);
                }
              } else {
                return null;
              }
            } catch (e2) {
              return null;
            }
          }
        }
      }
    } catch (e) {
      // API get failed, fallback to local data
    }
    
    // Fallback to local data
    try {
      return _items.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<DcrEntry>> listByDateRange({
    required DateTime start,
    required DateTime end,
    String? employeeId,
    String? customer,
    int? statusId,
  }) async {
    try {
      // Try to use API first
      if (getIt.isRegistered<DcrApi>()) {
        final dcrApi = getIt<DcrApi>();
        
        // Get user data from shared preferences
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        
        if (user != null) {
          final request = DcrListRequest(
            pageNumber: 1,
            pageSize: 1000,
            userId: user.userId, // Get from user session
            bizunit: user.sbuId, // Get from user session
            employeeId: employeeId != null ? int.tryParse(employeeId) ?? user.id : user.id,
            dcrDate: start.toIso8601String().split('T')[0], // Format as YYYY-MM-DD
            status: statusId,
            // Defaults for server contract
            searchText: null,
            sortOrder: 0,
            sortDir: 0,
            sortField: null,
            fromDate: null,
            toDate: null,
            filterExpression: null,
            transactionType: '',
            id: null,
            dcrId: null,
            dateOfExpense: null,
            cityId: null,
            expenceType: null,
            expenseAmount: null,
            remarks: null,
            managerId: 0,
          );
          
          final response = await dcrApi.getDcrList(request);
          return _convertApiResponseToDcrEntries(response);
        }
      }
    } catch (e) {
      // Fall back to local data if API fails
    }
    
    // Fallback to local data
    return _items.where((e) {
      final bool inRange = !e.date.isBefore(start) && !e.date.isAfter(end);
      final bool byEmp = employeeId == null || e.employeeId == employeeId;
      final bool byCustomer = customer == null || e.customer == customer;
      final bool byStatus = statusId == null || _mapStatusToServer(e.status) == statusId;
      return inRange && byEmp && byCustomer && byStatus;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<List<DcrApiItem>> getDcrListUnified({
    required DateTime start,
    required DateTime end,
    String? employeeId,
    int? statusId,
    String? transactionType,
  }) async {
    try {
      // Try to use API first
      if (getIt.isRegistered<DcrApi>()) {
        final dcrApi = getIt<DcrApi>();
        
        // Get user data from shared preferences
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        
        if (user != null) {
          // Format dates with full ISO8601 format (with time)
          final String fromDateStr = DateTime(start.year, start.month, start.day, 0, 0, 0, 0)
              .toIso8601String()
              .replaceAll(RegExp(r'\.\d{6}'), '.000'); // Ensure .000 format
          final String toDateStr = DateTime(end.year, end.month, end.day, 23, 59, 59, 999)
              .toIso8601String()
              .replaceAll(RegExp(r'\.\d{6}'), '.000'); // Ensure .000 format
          
          final request = DcrListRequest(
            pageNumber: 1,
            pageSize: 1000,
            sortOrder: 0, // 0 for asc
            sortDir: 0, // 0 for asc
            sortField: 'DCRDate',
            fromDate: fromDateStr,
            toDate: toDateStr,
            userId: user.userId ?? user.id,
            bizunit: user.sbuId,
            status: statusId,
            employeeId: employeeId != null ? int.tryParse(employeeId) ?? 0 : 0,
            transactionType: transactionType ?? '', // Use provided transactionType or empty string for both
            dcrDate: null, // Set to null as per requirement
          );
          
          final response = await dcrApi.getDcrList(request);
          return response.items;
        }
      }
    } catch (e) {
      // Error loading unified DCR list from API
    }
    
    // Fallback to empty list if API fails
    return [];
  }

  @override
  Future<void> approve(List<String> ids) async {
    try {
      // Try to use API first for single DCR approval
      if (getIt.isRegistered<DcrApi>() && ids.length == 1) {
        final dcrApi = getIt<DcrApi>();
        final request = DcrApproveRequest(
          id: int.tryParse(ids.first) ?? 0,
          action: 5, // Approve action
          comment: 'Approved',
        );
        
        final response = await dcrApi.approveDcr(request);
        
        if (response.status) {
          _bulkUpdate(ids, DcrStatus.approved);
          return;
        } else {
          throw Exception('API approval failed: ${response.message}');
        }
      }
    } catch (e) {
      // API approve failed, falling back to local update
    }
    
    // Fallback to local update
    _bulkUpdate(ids, DcrStatus.approved);
  }

  @override
  Future<void> reject(List<String> ids, {required String comment}) async {
    _bulkUpdate(ids, DcrStatus.rejected);
  }

  @override
  Future<void> sendBack(List<String> ids, {required String comment}) async {
    try {
      // Try to use API first for single DCR send back
      if (getIt.isRegistered<DcrApi>() && ids.length == 1) {
        final dcrApi = getIt<DcrApi>();
        final request = DcrSendBackRequest(
          id: int.tryParse(ids.first) ?? 0,
          action: 2, // Send back action (matches _mapStatusToServer where sentBack = 2)
          comment: comment,
        );
        
        final response = await dcrApi.sendBackDcr(request);
        
        if (response.status) {
          _bulkUpdate(ids, DcrStatus.sentBack);
          return;
        } else {
          throw Exception('API send back failed: ${response.message}');
        }
      }
    } catch (e) {
      // API send back failed, falling back to local update
    }
    
    // Fallback to local update
    _bulkUpdate(ids, DcrStatus.sentBack);
  }

  int _mapStatusToServer(DcrStatus s) {
    switch (s) {
      case DcrStatus.draft:
        return 1;
      case DcrStatus.submitted:
        return 3;  // Based on your JSON example
      case DcrStatus.approved:
        return 5;  // Based on your logs showing dcrStatusId=5 for approved
      case DcrStatus.rejected:
        return 4;
      case DcrStatus.sentBack:
        return 2;
    }
  }

  @override
  Future<void> submitForApproval(List<String> ids) async {
    _bulkUpdate(ids, DcrStatus.submitted);
  }

  @override
  Future<DcrEntry> update(DcrEntry entry) async {
    try {
      // Try to use API first for update
      if (getIt.isRegistered<DcrApi>()) {
        final dcrApi = getIt<DcrApi>();
        
        // Get user data from shared preferences
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        
        if (user != null) {
          // Use the same structure as create for update - convert DcrEntry to DcrSaveRequest
          final int? linkedTourPlanIdInt = int.tryParse(entry.linkedTourPlanId ?? '');
          
          // Create tour plan DCR details for update
          final tourPlanDetails = [
            TourPlanDcrDetailSave(
              // Required fields
              planDate: entry.date.toIso8601String().split('T')[0],
              typeOfWorkId: entry.typeOfWorkId ?? 1, // Use 1 as default
              cityId: entry.cityId ?? 0,
              customerId: entry.customerId ?? 1, // Use 1 as default
              statusId: _mapStatusToServer(entry.status),
              remarks: entry.keyDiscussionPoints.isNotEmpty ? entry.keyDiscussionPoints : entry.purposeOfVisit,
              isBasedOnPlan: 1, // Always 1 as per requirement
              bizunit: 1, // Always 1 as per requirement
              samplesToDistribute: entry.samplesDistributed.isNotEmpty ? entry.samplesDistributed : '',
              productsToDiscuss: entry.productsDiscussed.isNotEmpty ? entry.productsDiscussed : '',
              customerName: entry.customer,
              visitTime: _formatVisitTime(entry.date),
              visitDuration: entry.callDurationMinutes.toDouble(),
              // Optional fields
              id: entry.detailId,
              clusterId: entry.clusterId ?? 0,
              customerFeedback: null,
              isDeviationRequested: null, // Always null as per requirement
              reasonForDeviation: null,
              deviationStatus: null,
              comments: null,
              deviatedFrom: null,
              tourPlanDetailId: null,
              isJoinVisit: null,
              joinVisitWithEmployeeId: null,
              joinVisitWithEmployeeName: null,
              location: null,
              latitude: entry.customerLatitude,
              longitude: entry.customerLongitude,
              createdBy: null,
              status: 0,
              sbuId: 0,
              tourPlanId: null, // Always null as per requirement
              employeeId: 0,
              dcrDate: '0001-01-01',
              active: true,
              userId: 0,
              territory: null,
              cluster: null,
              dcrType: null,
              dcrStatus: null,
              calls: null,
              expenses: null,
              createdAt: null,
              updatedAt: null,
              clusterNames: null,
            ),
          ];
          
          // Create save request using DcrSaveRequest (use Save endpoint for edit)
          final saveRequest = DcrSaveRequest(
            // Use the existing ID for update
            id: int.tryParse(entry.id) ?? 0,
            cityId: null, // Always null as per requirement
            createdBy: null,
            status: 0,
            sbuId: 0,
            dcrStatusId: _mapStatusToServer(entry.status),
            dcrId: null, // Will be set by server
            tourPlanId: linkedTourPlanIdInt ?? 0,
            employeeId: int.tryParse(entry.employeeId) ?? user.id,
            dcrDate: entry.date.toIso8601String().split('T')[0],
            isDeviationRequested: false, // Keep false at root
            isBasedOnPlan: false, // Root flag remains false; detail has 1
            deviatedFrom: null,
            remarks: null,
            active: true,
            userId: user.userId ?? user.id,
            tourPlanDCRDetails: tourPlanDetails,
            employeeName: entry.employeeName.isNotEmpty ? entry.employeeName : 'Unknown',
            designation: null,
            clusterNames: null,
            statusText: null,
            typeOfWork: null,
            customerName: null,
            expenses: const [], // Always empty array - expenses should not be included when linked with tour plan
            customerId: null,
            samplesToDistribute: null,
            productsToDiscuss: null,
            transactionType: null,
            typeOfWorkId: null,
            isGeneric: null,
            coVisit: entry.coVisit,
            coVisitorDetails: entry.coVisit && entry.coVisitorId != null
                ? [
                    CoVisitorDetail(
                      id: null,
                      dcrDetailId: null,
                      coVisitorId: entry.coVisitorId!,
                      coordinatorId: int.tryParse(entry.employeeId) ?? user.id,
                      remarks: null,
                      active: 1,
                      slNo: null,
                      coVisitorName: null,
                    ),
                  ]
                : const [], // Empty array when coVisit is false
          );
          
          final response = await dcrApi.saveDcr(saveRequest);
          
          if (response.success) {
            // Update local entry with server response
            final updatedEntry = entry.copyWith(updatedAt: DateTime.now());
            final int i = _items.indexWhere((e) => e.id == entry.id);
            if (i >= 0) {
              _items[i] = updatedEntry;
            } else {
              _items.add(updatedEntry);
            }
            return updatedEntry;
          } else {
            throw Exception('API update failed: ${response.message}');
          }
        }
      }
    } catch (e) {
      // API update failed, falling back to local update
    }
    
    // Fallback to local update
    final int i = _items.indexWhere((e) => e.id == entry.id);
    final DateTime now = DateTime.now();
    if (i >= 0) {
      _items[i] = entry.copyWith(updatedAt: now);
      return _items[i];
    }
    _items.add(entry.copyWith(updatedAt: now));
    return entry;
  }

  void _bulkUpdate(List<String> ids, DcrStatus status) {
    final DateTime now = DateTime.now();
    for (int i = 0; i < _items.length; i++) {
      final e = _items[i];
      if (ids.contains(e.id)) {
        _items[i] = e.copyWith(status: status, updatedAt: now);
      }
    }
  }

  String _genId() => DateTime.now().microsecondsSinceEpoch.toString();

  String _formatVisitTime(DateTime date) {
    // Format as "YYYY-MM-DDTHH:MM:SS" (e.g., "2025-10-13T15:43:33") without milliseconds
    return date.toIso8601String().split('.').first;
  }

  List<DcrEntry> _convertApiResponseToDcrEntries(DcrListResponse response) {
    return response.items.map((apiItem) {
      // Convert API status to DcrStatus enum
      DcrStatus status;
      switch (apiItem.statusText.toLowerCase()) {
        case 'approved':
          status = DcrStatus.approved;
          break;
        case 'submitted':
          status = DcrStatus.submitted;
          break;
        case 'rejected':
          status = DcrStatus.rejected;
          break;
        case 'sent back':
          status = DcrStatus.sentBack;
          break;
        default:
          status = DcrStatus.draft;
      }

      // Parse date from API response
      DateTime dcrDate;
      try {
        dcrDate = DateTime.parse(apiItem.dcrDate);
      } catch (e) {
        dcrDate = DateTime.now();
      }

      // Prefer detail-level fields when available
      final detail = apiItem.tourPlanDCRDetails.isNotEmpty ? apiItem.tourPlanDCRDetails.first : null;
      
      // Parse visitTime to extract time component and combine with date
      DateTime finalDcrDate = dcrDate;
      if (detail != null && detail.visitTime.isNotEmpty) {
        try {
          // Try to parse visitTime as full DateTime (e.g., "2025-11-02T03:25:00")
          final visitDateTime = DateTime.parse(detail.visitTime);
          // Combine the date from dcrDate with the time from visitTime
          finalDcrDate = DateTime(
            dcrDate.year,
            dcrDate.month,
            dcrDate.day,
            visitDateTime.hour,
            visitDateTime.minute,
            visitDateTime.second,
          );
        } catch (e) {
          // Fall back to dcrDate if parsing fails
        }
      }
      final String cluster = (apiItem.clusterNames.isNotEmpty
              ? apiItem.clusterNames
              : (detail?.clusterNames ?? '')).isNotEmpty
          ? (apiItem.clusterNames.isNotEmpty ? apiItem.clusterNames : (detail?.clusterNames ?? ''))
          : (detail?.cluster ?? '');
      final String customer = (detail?.customerName ?? '').isNotEmpty
          ? detail!.customerName
          : (apiItem.customerName.isNotEmpty ? apiItem.customerName : '');
      final String purpose = (detail?.remarks ?? '').isNotEmpty
          ? detail!.remarks
          : (apiItem.remarks.isNotEmpty ? apiItem.remarks : '');
      final int visitDuration = (detail?.visitDuration ?? 0) > 0
          ? detail!.visitDuration.round()
          : (apiItem.tourPlanDCRDetails.isNotEmpty ? apiItem.tourPlanDCRDetails.first.visitDuration.round() : 0);
      final String productsToDiscuss = (detail?.productsToDiscuss ?? '').isNotEmpty
          ? detail!.productsToDiscuss
          : (apiItem.productsToDiscuss.isNotEmpty ? apiItem.productsToDiscuss : '');
      final String samplesToDistribute = (detail?.samplesToDistribute ?? '').isNotEmpty
          ? detail!.samplesToDistribute
          : (apiItem.samplesToDistribute.isNotEmpty ? apiItem.samplesToDistribute : '');
      final String remarks = apiItem.remarks.isNotEmpty
          ? apiItem.remarks
          : ((detail?.remarks ?? '').isNotEmpty ? detail!.remarks : '');

      return DcrEntry(
        id: apiItem.id.toString(),
        date: finalDcrDate, // Use date combined with visitTime
        cluster: cluster.isNotEmpty ? cluster : 'Unknown',
        customer: customer.isNotEmpty ? customer : 'Unknown Customer',
        purposeOfVisit: purpose.isNotEmpty ? purpose : 'Visit',
        callDurationMinutes: visitDuration,
        productsDiscussed: productsToDiscuss,
        samplesDistributed: samplesToDistribute,
        keyDiscussionPoints: remarks,
        status: status,
        employeeId: apiItem.employeeId.toString(),
        employeeName: apiItem.employeeName.isNotEmpty ? apiItem.employeeName : 'Unknown',
        linkedTourPlanId: apiItem.tourPlanId > 0 ? apiItem.tourPlanId.toString() : null,
        geoProximity: GeoProximity.away,
        customerLatitude: apiItem.customerLatitude ?? detail?.latitude,
        customerLongitude: apiItem.customerLongitude ?? detail?.longitude,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }).toList();
  }

  DcrEntry _convertApiItemToDcrEntry(DcrApiItem apiItem) {
    // Convert API status to DcrStatus enum
    DcrStatus status;
    switch (apiItem.statusText.toLowerCase()) {
      case 'approved':
        status = DcrStatus.approved;
        break;
      case 'submitted':
        status = DcrStatus.submitted;
        break;
      case 'rejected':
        status = DcrStatus.rejected;
        break;
      case 'sent back':
        status = DcrStatus.sentBack;
        break;
      default:
        status = DcrStatus.draft;
    }

    // Parse date from API response
    DateTime dcrDate;
    try {
      dcrDate = DateTime.parse(apiItem.dcrDate);
    } catch (e) {
      dcrDate = DateTime.now();
    }

    return DcrEntry(
      id: apiItem.id.toString(),
      date: dcrDate,
      cluster: apiItem.clusterNames.isNotEmpty ? apiItem.clusterNames : 'Unknown',
      customer: apiItem.customerName.isNotEmpty ? apiItem.customerName : 'Unknown Customer',
      purposeOfVisit: apiItem.typeOfWork.isNotEmpty ? apiItem.typeOfWork : 'Visit',
      callDurationMinutes: 0, // Not available in list response
      productsDiscussed: apiItem.productsToDiscuss ?? '',
      samplesDistributed: apiItem.samplesToDistribute ?? '',
      keyDiscussionPoints: apiItem.remarks ?? '',
      status: status,
      employeeId: apiItem.employeeId.toString(),
      employeeName: apiItem.employeeName.isNotEmpty ? apiItem.employeeName : 'Unknown',
      linkedTourPlanId: apiItem.tourPlanId > 0 ? apiItem.tourPlanId.toString() : null,
      geoProximity: GeoProximity.away,
      customerLatitude: apiItem.customerLatitude,
      customerLongitude: apiItem.customerLongitude,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      typeOfWorkId: apiItem.typeOfWorkId,
      cityId: apiItem.cityId,
      customerId: apiItem.customerId,
    );
  }

  DcrEntry _convertApiResponseToDcrEntry(DcrGetResponse response) {
    // Get the first DCR detail from tourPlanDCRDetails array
    final TourPlanDcrDetailGet? dcrDetail = response.tourPlanDCRDetails.isNotEmpty 
        ? response.tourPlanDCRDetails.first 
        : null;
    
    if (dcrDetail == null) {
      throw Exception('No DCR details found in response');
    }

    // Convert API status to DcrStatus enum
    DcrStatus status;
    switch (response.statusText.toLowerCase()) {
      case 'approved':
        status = DcrStatus.approved;
        break;
      case 'submitted':
        status = DcrStatus.submitted;
        break;
      case 'rejected':
        status = DcrStatus.rejected;
        break;
      case 'sent back':
        status = DcrStatus.sentBack;
        break;
      default:
        status = DcrStatus.draft;
    }

    // Parse date from API response
    DateTime dcrDate;
    try {
      dcrDate = DateTime.parse(response.dcrDate);
    } catch (e) {
      dcrDate = DateTime.now();
    }
    
    // Parse visitTime to extract time component and combine with date
    DateTime finalDcrDate = dcrDate;
    if (dcrDetail.visitTime.isNotEmpty) {
      try {
        // Try to parse visitTime as full DateTime (e.g., "2025-11-02T03:25:00")
        final visitDateTime = DateTime.parse(dcrDetail.visitTime);
        // Combine the date from dcrDate with the time from visitTime
        finalDcrDate = DateTime(
          dcrDate.year,
          dcrDate.month,
          dcrDate.day,
          visitDateTime.hour,
          visitDateTime.minute,
          visitDateTime.second,
        );
      } catch (e) {
        // Fall back to dcrDate if parsing fails
      }
    }

    // Use data from tourPlanDCRDetails array
    final String cluster = dcrDetail.clusterNames.isNotEmpty ? dcrDetail.clusterNames : 'Unknown';
    final String customer = dcrDetail.customerName.isNotEmpty ? dcrDetail.customerName : 'Unknown Customer';
    final String purpose = dcrDetail.remarks.isNotEmpty ? dcrDetail.remarks : 'Visit';
    final String productsToDiscuss = dcrDetail.productsToDiscuss.isNotEmpty ? dcrDetail.productsToDiscuss : '';
    final String samplesToDistribute = dcrDetail.samplesToDistribute.isNotEmpty ? dcrDetail.samplesToDistribute : '';
    final String remarks = dcrDetail.remarks.isNotEmpty ? dcrDetail.remarks : '';

    // Helper function to check if a coordinate is valid (not 0.0)
    bool isValidCoordinate(double? coord) {
      return coord != null && coord != 0.0;
    }
    
    // Determine final coordinates - prefer customerLatitude/customerLongitude but treat 0.0 as invalid
    double? finalLat = dcrDetail.customerLatitude;
    double? finalLng = dcrDetail.customerLongitude;
    
    // If customerLatitude/customerLongitude are 0.0 or null, try latitude/longitude
    if (!isValidCoordinate(finalLat)) {
      finalLat = dcrDetail.latitude;
    }
    if (!isValidCoordinate(finalLng)) {
      finalLng = dcrDetail.longitude;
    }
    
    // Final check: if still 0.0, set to null
    if (!isValidCoordinate(finalLat)) {
      finalLat = null;
    }
    if (!isValidCoordinate(finalLng)) {
      finalLng = null;
    }
    
    // Use detailId only if it's greater than 0, otherwise set to null
    final int? validDetailId = (dcrDetail.id != null && dcrDetail.id! > 0) ? dcrDetail.id : null;
    
    return DcrEntry(
      id: response.id.toString(), // This is the DCR parent ID
      date: finalDcrDate, // Use date combined with visitTime
      cluster: cluster,
      customer: customer,
      purposeOfVisit: purpose,
      callDurationMinutes: dcrDetail.visitDuration.round(), // Convert double to int
      productsDiscussed: productsToDiscuss,
      samplesDistributed: samplesToDistribute,
      keyDiscussionPoints: remarks,
      status: status,
      employeeId: response.employeeId.toString(),
      employeeName: response.employeeName.isNotEmpty ? response.employeeName : 'Unknown',
      linkedTourPlanId: response.tourPlanId > 0 ? response.tourPlanId.toString() : null,
      geoProximity: GeoProximity.away,
      customerLatitude: finalLat,
      customerLongitude: finalLng,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      typeOfWorkId: dcrDetail.typeOfWorkId,
      cityId: dcrDetail.cityId,
      customerId: dcrDetail.customerId,
      detailId: validDetailId,
      clusterId: dcrDetail.clusterId,
    );
  }

  @override
  Future<void> bulkApprove(List<String> ids, {required String comment}) async {
    try {
      // Try to use API first for bulk approval
      if (getIt.isRegistered<DcrApi>()) {
        final dcrApi = getIt<DcrApi>();
        
        // Get user data from shared preferences
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        
        if (user != null) {
          final request = DcrBulkApproveRequest(
            id: user.userId ?? user.id,
            comments: comment,
            userId: user.userId ?? user.id,
            action: 5, // Approve action
            tourPlanDCRDetails: ids.map((id) => DcrBulkDetail(id: int.tryParse(id) ?? 0)).toList(),
          );
          
          final response = await dcrApi.bulkApproveDcr(request);
          
          if (response.status) {
            _bulkUpdate(ids, DcrStatus.approved);
            return;
          } else {
            throw Exception('API bulk approval failed: ${response.message}');
          }
        }
      }
    } catch (e) {
      // API bulk approve failed, falling back to local update
    }
    
    // Fallback to local update
    _bulkUpdate(ids, DcrStatus.approved);
  }

  @override
  Future<void> bulkSendBack(List<String> ids, {required String comment}) async {
    try {
      // Try to use API first for bulk send back
      if (getIt.isRegistered<DcrApi>()) {
        final dcrApi = getIt<DcrApi>();
        
        // Get user data from shared preferences
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        
        if (user != null) {
          final request = DcrBulkSendBackRequest(
            id: user.userId ?? user.id,
            comments: comment,
            userId: user.userId ?? user.id,
            action: 4, // Manager review send back action (Action: 4 for DCR manager review screen)
            tourPlanDCRDetails: ids.map((id) => DcrBulkDetail(id: int.tryParse(id) ?? 0)).toList(),
          );
          
          final response = await dcrApi.bulkSendBackDcr(request);
          
          if (response.status) {
            _bulkUpdate(ids, DcrStatus.sentBack);
            return;
          } else {
            throw Exception('API bulk send back failed: ${response.message}');
          }
        }
      }
    } catch (e) {
      // API bulk send back failed, falling back to local update
    }
    
    // Fallback to local update
    _bulkUpdate(ids, DcrStatus.sentBack);
  }

  @override
  Future<void> bulkReject(List<String> ids, {required String comment}) async {
    // For now, use the same logic as bulk send back but with rejected status
    // In a real implementation, you might have a separate reject API
    try {
      // Try to use API first for bulk reject
      if (getIt.isRegistered<DcrApi>()) {
        final dcrApi = getIt<DcrApi>();
        
        // Get user data from shared preferences
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        
        if (user != null) {
          final request = DcrBulkSendBackRequest(
            id: user.userId ?? user.id,
            comments: comment,
            userId: user.userId ?? user.id,
            action: 4, // Reject action (matches _mapStatusToServer where rejected = 4)
            tourPlanDCRDetails: ids.map((id) => DcrBulkDetail(id: int.tryParse(id) ?? 0)).toList(),
          );
          
          final response = await dcrApi.bulkSendBackDcr(request);
          
          if (response.status) {
            _bulkUpdate(ids, DcrStatus.rejected);
            return;
          } else {
            throw Exception('API bulk reject failed: ${response.message}');
          }
        }
      }
    } catch (e) {
      // API bulk reject failed, falling back to local update
    }
    
    // Fallback to local update
    _bulkUpdate(ids, DcrStatus.rejected);
  }

  void _seedDemoData() {
    if (_items.isNotEmpty) return;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    _items.addAll(<DcrEntry>[
      DcrEntry(
        id: _genId(),
        date: today,
        cluster: 'Andheri East',
        customer: 'Sunrise Clinic',
        purposeOfVisit: 'Product Detailing',
        callDurationMinutes: 25,
        productsDiscussed: 'Device X',
        samplesDistributed: 'Sample A',
        keyDiscussionPoints: 'Discussed features',
        status: DcrStatus.approved,
        employeeId: 'me',
        employeeName: 'John Doe',
        geoProximity: GeoProximity.at,
        createdAt: now,
        updatedAt: now,
      ),
      DcrEntry(
        id: _genId(),
        date: today,
        cluster: 'Andheri East',
        customer: 'Dr. Meera Joshi',
        purposeOfVisit: 'Follow-up',
        callDurationMinutes: 15,
        productsDiscussed: 'Device Y',
        samplesDistributed: 'Sample B',
        keyDiscussionPoints: 'Next steps',
        status: DcrStatus.submitted,
        employeeId: 'me',
        employeeName: 'John Doe',
        geoProximity: GeoProximity.near,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  }

  @override
  Future<ExpenseSaveResponse> saveExpense(ExpenseSaveRequest request) async {
    try {
      // Use API to save expense
      if (getIt.isRegistered<DcrApi>()) {
        final dcrApi = getIt<DcrApi>();
        return await dcrApi.saveExpense(request);
      } else {
        throw Exception('DCR API not available');
      }
    } catch (e) {
      throw Exception('Failed to save expense: ${e.toString()}');
    }
  }

  @override
  Future<DcrValidateUserResponse> validateUser(int userId) async {
    try {
      // Use API to validate user
      if (getIt.isRegistered<DcrApi>()) {
        final dcrApi = getIt<DcrApi>();
        final request = DcrValidateUserRequest(userId: userId);
        return await dcrApi.validateUser(request);
      } else {
        throw Exception('DCR API not available');
      }
    } catch (error) {
      throw Exception('Failed to validate user: ${error.toString()}');
    }
  }
}


