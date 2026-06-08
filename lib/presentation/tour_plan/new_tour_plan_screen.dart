import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:google_fonts/google_fonts.dart';
import 'package:boilerplate/core/widgets/app_form_fields.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/presentation/crm/tour_plan/store/tour_plan_store.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/repository/tour_plan/tour_plan_repository.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/domain/entity/user/user_detail.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/data/network/apis/user/lib/domain/entity/tour_plan/tour_plan_api_models.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';
import 'package:boilerplate/utils/purpose_visit_helper.dart';

void main() {
  runApp(const MaterialApp(
    home: NewTourPlanScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class NewTourPlanScreen extends StatefulWidget {
  final TourPlanItem? tourPlanToEdit; // Add optional parameter for editing
  final bool isViewOnly; // If true, form is read-only (for approved tour plans)

  const NewTourPlanScreen({
    super.key,
    this.tourPlanToEdit,
    this.isViewOnly = false,
  });

  @override
  State<NewTourPlanScreen> createState() => _NewTourPlanScreenState();
}

class _NewTourPlanScreenState extends State<NewTourPlanScreen> {
  DateTime _tourPlanDate = DateTime.now();
  late final TextEditingController _dateCtrl;
  Set<String> _selectedClusters = <String>{};
  List<String> _clusters = [];
  final Map<String, int> _clusterNameToId = <String, int>{};

  List<String> _purposeOptions = [];
  final Map<String, int> _typeOfWorkNameToId = <String, int>{};
  final Map<int, String> _typeOfWorkIdToName =
      <int, String>{}; // Reverse mapping for editing
  bool _isLoadingPurpose = false;

  // Products options for multi-select dropdown
  List<String> _productOptions = [];
  final Map<String, int> _productNameToId = <String, int>{};
  bool _isLoadingProducts = false;
  final Map<String, int> _customerNameToId = <String, int>{};
  final Map<int, String> _customerIdToName =
      <int, String>{}; // Added: reverse mapping id -> name
  final Map<String, String> _customerNameToClusterName = <String, String>{};
  Set<String> _autoSelectedClusters = <String>{};
  Set<String> _removedAutoSelectedClusters = <String>{};

  // Customer Type dropdown options (selected per call)
  List<String> _customerTypeOptions = [];
  final Map<String, int> _customerTypeNameToId = <String, int>{};
  bool _isLoadingCustomerType = false;

  // Employee: for all users shows their name (read-only). For managers this is manager name.
  String? _selectedEmployee;
  // Reporting Staff: dropdown for managers only; selected staff drives clusters/customers etc.
  List<String> _employeeOptions = [];
  final Map<String, int> _employeeNameToId = <String, int>{};
  /// Reporting staff [CommonDropdownItem.id] is employeeId — not login userId.
  final Map<int, int> _reportingStaffRepTypeByEmployeeId = <int, int>{};
  final Map<int, String> _reportingStaffDesignationByEmployeeId = <int, String>{};
  String? _selectedReportingStaff; // Selected reporting staff display name (managers only)
  int? _selectedEmployeeId; // For managers = selected reporting staff ID; for non-managers = current user's employeeId
  String? _employeeError;
  bool _isLoadingEmployees = false;
  bool _isManagerOrFieldManager = false;
  bool _isServiceEngineer = false;
  bool _isPocRep = false;

  // Dynamic calls list
  final List<_CallData> _calls = <_CallData>[
    _CallData(),
  ];
  List<_CallValidationState> _callErrors = const <_CallValidationState>[];
  String? _dateError;
  String? _clusterError;

  bool _isLoadingDetails =
      false; // Flag to track if we're loading tour plan details
  TourPlanItem?
      _fullTourPlanData; // Store the full tour plan data after fetching
  bool _isSubmitting = false; // Flag to track if we're submitting the tour plan
  UserDetailStore? _userDetailStore;
  int? _lastLoadedPurposeRepType;
  int _purposeLoadGeneration = 0;

  /// Check if the form should be in view-only mode
  /// Returns true if isViewOnly is true OR if the tour plan is approved (status 5)
  bool get _isViewOnlyMode {
    if (widget.isViewOnly) return true;
    if (widget.tourPlanToEdit != null) {
      // Check if tour plan is approved
      final status = widget.tourPlanToEdit!.status != 0 
          ? widget.tourPlanToEdit!.status 
          : widget.tourPlanToEdit!.statusId;
      if (status == 5) return true; // Status 5 = Approved
      
      // Also check tourPlanStatus text field
      if (widget.tourPlanToEdit!.tourPlanStatus != null) {
        final statusText = widget.tourPlanToEdit!.tourPlanStatus!.toLowerCase();
        if (statusText.contains('approved')) return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _userDetailStore?.removeListener(_onUserProfileUpdated);
    _dateCtrl.dispose();
    for (final c in _calls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _dateCtrl = TextEditingController(text: _formatDate(_tourPlanDate));
    _clearCallErrors();

    if (getIt.isRegistered<UserDetailStore>()) {
      _userDetailStore = getIt<UserDetailStore>();
      _userDetailStore!.addListener(_onUserProfileUpdated);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
    _clearCallErrors();
  }

  Future<void> _initializeScreen() async {
    await PurposeVisitHelper.ensureLoggedInUserProfile(_userDetailStore);
    if (!mounted) return;

    _checkUserRole();

    if (widget.tourPlanToEdit != null) {
      await _loadTourPlanDetails();
      return;
    }

    // Managers: load reporting staff first so repType map is ready for purpose API.
    if (_isManagerOrFieldManager) {
      await _loadReportingStaffList();
    }

    final shouldLoadNow =
        !_isManagerOrFieldManager || (_selectedEmployeeId != null);
    if (shouldLoadNow) {
      try {
        await _loadInitialData();
      } catch (e) {
        print('NewTourPlanScreen: Error loading initial data: $e');
      }
    } else {
      print(
          'NewTourPlanScreen: Skipping initial data load until Reporting Staff is selected (role 1/2)');
    }
  }

  void _onUserProfileUpdated() {
    if (!mounted) return;
    final int? repType = _userDetailStore?.userDetail?.repType;
    if (repType == null || repType <= 0) return;
    if (_isManagerOrFieldManager && _selectedEmployeeId == null) return;
    // Re-fetch if profile arrived late or list looks truncated (e.g. stuck at 3).
    if (repType == _lastLoadedPurposeRepType &&
        _purposeOptions.length > 5 &&
        PurposeVisitHelper.isServiceEngineer(repType: repType)) {
      return;
    }

    _checkUserRole();
    _loadTypeOfWorkList();
  }

  /// Check if user is manager or field manager/coordinator based on RoleCategory
  /// RoleCategory 1 or 2 = Manager/Field Manager/Coordinator (show employee dropdown)
  /// RoleCategory 3 = Representative (show read-only employee field)
  void _checkUserRole() {
    final UserDetailStore? userStore =
        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final String serviceArea =
        (userStore?.userDetail?.serviceArea ?? '').trim();
    _isServiceEngineer = PurposeVisitHelper.isServiceEngineer(
      serviceArea: serviceArea,
      repType: userStore?.userDetail?.repType,
    );
    final int? roleCategory = userStore?.userDetail?.roleCategory;
    final int? repType = userStore?.userDetail?.repType;
    _isPocRep = (repType == 3 && roleCategory == 3);

    if (roleCategory != null) {
      // RoleCategory 1 or 2 = Manager/Field Manager/Coordinator
      // RoleCategory 3 = Representative
      _isManagerOrFieldManager = roleCategory == 1 || roleCategory == 2;

      print(
          'NewTourPlanScreen: [Employee] RoleCategory: $roleCategory, RepType: $repType, Is Manager/Field Manager: $_isManagerOrFieldManager, Is POC Rep: $_isPocRep');

      if (!_isManagerOrFieldManager) {
        // For representatives (RoleCategory 3), set current employee as selected (read-only)
        final int? employeeId = userStore?.userDetail?.employeeId;
        final String? employeeName = userStore?.userDetail?.employeeName;
        final String? employeeCode = userStore?.userDetail?.code;

        if (employeeId != null && employeeId > 0 && employeeName != null) {
          final String displayName =
              employeeCode != null && employeeCode.isNotEmpty
                  ? '$employeeCode - $employeeName'
                  : employeeName;
          if (mounted) {
            setState(() {
              _selectedEmployee = displayName;
              _selectedEmployeeId = employeeId;
            });
          }
          print(
              'NewTourPlanScreen: [Employee] Set current employee: $_selectedEmployee (ID: $_selectedEmployeeId)');
        }
      } else {
        // For managers/field managers: Employee field shows manager's name (read-only)
        final int? managerEmployeeId = userStore?.userDetail?.employeeId;
        final String? managerName = userStore?.userDetail?.employeeName;
        final String? managerCode = userStore?.userDetail?.code;
        if (managerEmployeeId != null && managerName != null) {
          final String displayName =
              managerCode != null && managerCode.isNotEmpty
                  ? '$managerCode - $managerName'
                  : managerName;
          if (mounted) {
            setState(() {
              _selectedEmployee = displayName;
              // Service-engineer managers plan for themselves using employeeId.
              if (PurposeVisitHelper.isServiceEngineer(
                serviceArea: userStore?.userDetail?.serviceArea,
                repType: repType,
              )) {
                _selectedEmployeeId = managerEmployeeId;
                print(
                    'NewTourPlanScreen: [Employee] SE manager — pre-selected self employeeId: $managerEmployeeId, repType: $repType');
              } else {
                _selectedEmployeeId = null;
              }
            });
          }
          print(
              'NewTourPlanScreen: [Employee] Set manager name in Employee field: $_selectedEmployee');
        }
      }
    } else {
      print(
          'NewTourPlanScreen: [Employee] RoleCategory is null, defaulting to representative');
      // Default to representative behavior if RoleCategory is null
      final int? employeeId = userStore?.userDetail?.employeeId;
      final String? employeeName = userStore?.userDetail?.employeeName;
      final String? employeeCode = userStore?.userDetail?.code;

      if (employeeId != null && employeeId > 0 && employeeName != null) {
        final String displayName =
            employeeCode != null && employeeCode.isNotEmpty
                ? '$employeeCode - $employeeName'
                : employeeName;
        if (mounted) {
          setState(() {
            _selectedEmployee = displayName;
            _selectedEmployeeId = employeeId;
          });
        }
      }
    }
  }

  /// Load reporting staff list for managers/field managers using CommandType 276
  Future<void> _loadReportingStaffList() async {
    if (!_isManagerOrFieldManager) return;

    if (mounted) {
      setState(() {
        _isLoadingEmployees = true;
      });
    }

    try {
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;

      // Wait for user to be loaded (retry up to 10 times = 3 seconds max)
      int retry = 0;
      while (userStore?.isUserLoaded != true && retry < 10) {
        await Future.delayed(const Duration(milliseconds: 300));
        retry++;
        print(
            'NewTourPlanScreen: [Employee] Waiting for user to load... retry $retry');
      }

      final int? loginEmployeeId = userStore?.userDetail?.employeeId;

      if (loginEmployeeId == null || loginEmployeeId <= 0) {
        print(
            'NewTourPlanScreen: [Employee] Login employeeId is null or invalid after waiting');
        return;
      }

      if (!getIt.isRegistered<CommonRepository>()) {
        print('NewTourPlanScreen: [Employee] CommonRepository not registered');
        return;
      }

      final repo = getIt<CommonRepository>();
      print(
          'NewTourPlanScreen: [Employee] Loading reporting staff for employeeId: $loginEmployeeId');

      final List<CommonDropdownItem> items =
          await repo.getEmployeesReportingTo(loginEmployeeId);

      if (items.isEmpty) {
        print('NewTourPlanScreen: [Employee] No reporting staff found');
        if (mounted) {
          setState(() {
            _employeeOptions = [];
            _employeeNameToId.clear();
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _employeeOptions.clear();
          _employeeNameToId.clear();
          _reportingStaffRepTypeByEmployeeId.clear();
          _reportingStaffDesignationByEmployeeId.clear();

          for (final item in items) {
            // Format: "CODE - NAME" or just "NAME" if no code
            final String employeeName =
                item.employeeName.isNotEmpty ? item.employeeName : item.text;
            final String employeeCode = item.code ?? '';
            final String displayName = employeeCode.isNotEmpty
                ? '$employeeCode - $employeeName'
                : employeeName;

            if (displayName.trim().isNotEmpty) {
              _employeeOptions.add(displayName);
              // item.id from CommandType 276 is employeeId (not login userId).
              _employeeNameToId[displayName] = item.id;
              if (item.repType != null && item.repType! > 0) {
                _reportingStaffRepTypeByEmployeeId[item.id] = item.repType!;
              }
              final String designation = item.designation.trim();
              if (designation.isNotEmpty) {
                _reportingStaffDesignationByEmployeeId[item.id] = designation;
              }
            }
          }

          // Default reporting staff to logged-in manager when listed under their team.
          if (_selectedEmployeeId == null &&
              loginEmployeeId != null &&
              loginEmployeeId > 0) {
            for (final MapEntry<String, int> entry
                in _employeeNameToId.entries) {
              if (entry.value == loginEmployeeId) {
                _selectedReportingStaff = entry.key;
                _selectedEmployeeId = loginEmployeeId;
                print(
                    'NewTourPlanScreen: [Employee] Auto-selected reporting staff: $_selectedReportingStaff (employeeId: $_selectedEmployeeId)');
                break;
              }
            }
          }

          print(
              'NewTourPlanScreen: [Employee] Loaded ${_employeeOptions.length} reporting staff');
        });
      }
    } catch (e) {
      print('NewTourPlanScreen: [Employee] Error loading reporting staff: $e');
      if (mounted) {
        ToastMessage.show(context,
            message: 'Error loading reporting staff: ${e.toString()}',
            type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingEmployees = false;
        });
      }
    }
  }

  /// Load basic data (clusters, customers, type of work, products, customer type) for new tour plans
  Future<void> _loadInitialData() async {
    // For managers/field managers, do not load until a reporting staff is selected
    if (_isManagerOrFieldManager && _selectedEmployeeId == null) {
      print(
          'NewTourPlanScreen: [InitialData] Manager role without selected reporting staff - skipping');
      return;
    }
    // Load all data in parallel for faster loading
    await Future.wait([
      _ensureClustersLoaded(),
      _loadTypeOfWorkList(),
      _loadProductsList(),
      _loadCustomerTypeList(),
    ]);
    // Don't load customers until clusters are selected
    // Customers will be loaded when user selects clusters
  }

  /// Load full tour plan details from API when editing
  Future<void> _loadTourPlanDetails() async {
    if (widget.tourPlanToEdit == null) return;

    if (mounted) {
      setState(() {
        _isLoadingDetails = true;
      });
    }

    try {
      print(
          'NewTourPlanScreen: ========== LOADING TOUR PLAN DETAILS ==========');
      print(
          'NewTourPlanScreen: tourPlanToEdit is not null: ${widget.tourPlanToEdit != null}');
      if (widget.tourPlanToEdit != null) {

        if (widget.tourPlanToEdit!.tourPlanDetails != null &&
            widget.tourPlanToEdit!.tourPlanDetails!.isNotEmpty) {
          print('  - ✅ HAS DETAILS:');
          for (int i = 0;
              i < widget.tourPlanToEdit!.tourPlanDetails!.length;
              i++) {
            final detail = widget.tourPlanToEdit!.tourPlanDetails![i];
            print('    Detail $i:');
            print('      - customerId: ${detail.customerId}');
            print('      - clusterNames: "${detail.clusterNames}"');
            print('      - typeOfWorkId: ${detail.typeOfWorkId}');
            print('      - customerType: ${detail.customerType}');
            print('      - planDate: ${detail.planDate}');
            print('      - productsToDiscuss: "${detail.productsToDiscuss}"');
            print(
                '      - productsToBeDiscussed: ${detail.productsToBeDiscussed?.length ?? 0} items');
          }
        } else {
          print('  - ❌ NO DETAILS in original data');
        }
        print(
            'NewTourPlanScreen: ============================================');
      }
      print(
          'NewTourPlanScreen: tourPlanId value: ${widget.tourPlanToEdit!.tourPlanId}');
      print('NewTourPlanScreen: id value: ${widget.tourPlanToEdit!.id}');

      // Check if original data already has details (even if header fields are empty)
      final bool originalHasDetails = widget.tourPlanToEdit != null &&
          widget.tourPlanToEdit!.tourPlanDetails != null &&
          widget.tourPlanToEdit!.tourPlanDetails!.isNotEmpty;

      if (originalHasDetails) {
        print(
            'NewTourPlanScreen: ✅ Original data has ${widget.tourPlanToEdit!.tourPlanDetails!.length} details. Using it directly (skipping API call).');
        _fullTourPlanData = widget.tourPlanToEdit;
        if (mounted) {
          setState(() {
            _isLoadingDetails = false;
          });
        }
        await _populateFormFromTourPlan(widget.tourPlanToEdit!);
        return;
      } else {
        print(
            'NewTourPlanScreen: Original data has ${widget.tourPlanToEdit!.tourPlanDetails?.length ?? 0} details. Will fetch from API.');
      }

      // Fetch full tour plan details using TourPlanId and Id
      final repo = getIt<TourPlanRepository>();

      // Debug: Print the exact values being sent to API
      // Note: If tourPlanId is 0 or null, use id as tourPlanId
      int effectiveTourPlanId = widget.tourPlanToEdit!.tourPlanId;
      int effectiveId = widget.tourPlanToEdit!.id;

      // If tourPlanId is 0, use id as tourPlanId (for list items that might have tourPlanId=0)
      if (effectiveTourPlanId == 0) {
        effectiveTourPlanId = effectiveId;
        print(
            'NewTourPlanScreen: tourPlanId was 0, using id as tourPlanId: $effectiveTourPlanId');
      }

      print(
          'NewTourPlanScreen: Calling API with tourPlanId=$effectiveTourPlanId, id=$effectiveId');

      // Get userId for API call
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      int? userId = userStore?.userDetail?.id;

      TourPlanGetResponse response;
      try {
        response = await repo
            .getTourPlanDetails(
              tourPlanId: effectiveTourPlanId,
              id: effectiveId,
              userId: userId,
            )
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        print('NewTourPlanScreen: API call failed or timed out with error: $e');
        rethrow;
      }

      print('NewTourPlanScreen: API call completed successfully');
      print('NewTourPlanScreen: API Response received:');
      print('  - Total records: ${response.totalRecords}');
      print('  - Filtered records: ${response.filteredRecords}');
      print('  - Items count: ${response.items.length}');

      // Get the first (and only) tour plan item from the response
      TourPlanItem? fullTourPlan;
      if (response.items.isNotEmpty) {
        final apiTourPlan = response.items.first;
        print('NewTourPlanScreen: API returned tour plan data');
        print('  - ID: ${apiTourPlan.id}');
        print('  - Customer: ${apiTourPlan.customerName}');
        print(
            '  - Products count: ${(apiTourPlan.productsToDiscuss ?? '').split(',').where((p) => p.trim().isNotEmpty).length}');
        print('  - Samples: ${apiTourPlan.samplesToDistribute}');
        print('  - Notes: ${apiTourPlan.notes}');
        print(
            '  - TourPlanDetails count: ${apiTourPlan.tourPlanDetails?.length ?? 0}');
        print(
            '  - Clusters count: ${(apiTourPlan.clusters ?? '').split(',').where((c) => c.trim().isNotEmpty).length}');
        print('  - TourPlanType: ${apiTourPlan.tourPlanType}');
        print('  - PlanDate: ${apiTourPlan.planDate}');

        // Check if API response has empty details but original data has details
        final bool apiHasEmptyDetails = apiTourPlan.tourPlanDetails == null ||
            apiTourPlan.tourPlanDetails!.isEmpty;
        final bool originalHasDetails = widget.tourPlanToEdit != null &&
            widget.tourPlanToEdit!.tourPlanDetails != null &&
            widget.tourPlanToEdit!.tourPlanDetails!.isNotEmpty;

        // Also check if API response has empty header fields
        final bool apiHasEmptyHeaderFields =
            (apiTourPlan.clusters == null || apiTourPlan.clusters!.isEmpty) &&
                (apiTourPlan.tourPlanType == null ||
                    apiTourPlan.tourPlanType!.isEmpty) &&
                (apiTourPlan.planDate == DateTime(0));

        if ((apiHasEmptyDetails && originalHasDetails) ||
            (apiHasEmptyHeaderFields && originalHasDetails)) {
          print(
              'NewTourPlanScreen: ⚠️ API returned incomplete data (details: ${apiTourPlan.tourPlanDetails?.length ?? 0}, original: ${widget.tourPlanToEdit!.tourPlanDetails?.length ?? 0}).');
          print(
              'NewTourPlanScreen: Using original tourPlanToEdit data which has complete details.');
          // Use original data which has the details
          fullTourPlan = widget.tourPlanToEdit;
        } else {
          // Use API response
          fullTourPlan = apiTourPlan;
        }
      } else {
        fullTourPlan = widget.tourPlanToEdit; // Fallback to provided data
        print(
            'NewTourPlanScreen: API returned empty list, using fallback data from widget');
        print('  - Fallback ID: ${fullTourPlan?.id}');
        print(
            '  - Fallback TourPlanDetails count: ${fullTourPlan?.tourPlanDetails?.length ?? 0}');
      }

      // Store the full tour plan data
      _fullTourPlanData = fullTourPlan;

      // Now populate the form with full data
      if (fullTourPlan != null) {
        print('NewTourPlanScreen: Populating form with tour plan data...');
        await _populateFormFromTourPlan(fullTourPlan);
        print('NewTourPlanScreen: Form populated successfully');
      } else {
        print(
            'NewTourPlanScreen: ⚠️ fullTourPlan is null, using widget.tourPlanToEdit');
        if (widget.tourPlanToEdit != null) {
          await _populateFormFromTourPlan(widget.tourPlanToEdit!);
        }
      }
    } catch (e) {
      print('Error loading tour plan details: $e');
      if (mounted) {
        ToastMessage.show(context,
            message: 'Error loading details: ${e.toString()}',
            type: ToastType.error);
      }
      // Fallback to using the provided data
      if (widget.tourPlanToEdit != null) {
        print(
            'NewTourPlanScreen: Using fallback - widget.tourPlanToEdit with ${widget.tourPlanToEdit!.tourPlanDetails?.length ?? 0} details');
        await _populateFormFromTourPlan(widget.tourPlanToEdit!);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
    }
  }

  /// Populate form fields from TourPlanItem data
  Future<void> _populateFormFromTourPlan(TourPlanItem tourPlan) async {
    print('NewTourPlanScreen: [Edit] Starting _populateFormFromTourPlan');
    print('  - TourPlan ID: ${tourPlan.id}');
    print(
        '  - TourPlan Header Clusters count: ${(tourPlan.clusters ?? '').split(',').where((c) => c.trim().isNotEmpty).length}');
    print('  - TourPlan Header Type: ${tourPlan.tourPlanType}');
    print('  - TourPlan Header Date: ${tourPlan.planDate}');
    print(
        '  - TourPlanDetails Count: ${tourPlan.tourPlanDetails?.length ?? 0}');

    // Helper function to parse clusters
    Set<String> _parseClusters(String? s) {
      if (s == null || s.isEmpty) return <String>{};
      return s
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    }

    // Extract data from tour plan (don't set state yet)
    Set<String> clustersToSelect = <String>{};
    DateTime? dateToSelect;

    // Extract clusters
    if (tourPlan.tourPlanDetails != null &&
        tourPlan.tourPlanDetails!.isNotEmpty) {
      for (final detail in tourPlan.tourPlanDetails!) {
        if (detail.clusterNames != null && detail.clusterNames!.isNotEmpty) {
          clustersToSelect.addAll(_parseClusters(detail.clusterNames));
        }
      }
    }
    if (clustersToSelect.isEmpty &&
        tourPlan.clusters != null &&
        tourPlan.clusters!.isNotEmpty) {
      clustersToSelect = _parseClusters(tourPlan.clusters);
    }

    // Extract date
    if (tourPlan.tourPlanDetails != null &&
        tourPlan.tourPlanDetails!.isNotEmpty) {
      dateToSelect = tourPlan.tourPlanDetails!.first.planDate;
    } else if (tourPlan.planDate != DateTime(0)) {
      dateToSelect = tourPlan.planDate;
    }

    // 1. Set Reporting Staff for Managers (Employee field already shows manager name)
    if (_isManagerOrFieldManager) {
      if (tourPlan.employeeId > 0) {
        if (mounted) {
          setState(() {
            _selectedEmployeeId = tourPlan.employeeId;
            _selectedReportingStaff =
                tourPlan.employeeName ?? 'Unknown Employee';
          });
        }
        print(
            'NewTourPlanScreen: [Edit] Set reporting staff to $_selectedReportingStaff (ID: $_selectedEmployeeId)');

        // Wait for reporting staff options to load
        int retry = 0;
        while (_isLoadingEmployees && retry < 20) {
          await Future.delayed(const Duration(milliseconds: 200));
          retry++;
        }

        // Match formatted name from options if available
        String? correctlyFormattedName;
        _employeeNameToId.forEach((name, id) {
          if (id == tourPlan.employeeId) {
            correctlyFormattedName = name;
          }
        });
        if (correctlyFormattedName != null) {
          if (mounted) {
            setState(() {
              _selectedReportingStaff = correctlyFormattedName;
            });
          }
          print(
              'NewTourPlanScreen: [Edit] Refined reporting staff name to: $_selectedReportingStaff');
        }
      }
    }

    // 2. Set tour plan date
    if (dateToSelect != null) {
      if (mounted) {
        setState(() {
          _tourPlanDate = dateToSelect!;
          _dateCtrl.text = _formatDate(_tourPlanDate);
        });
      }
      print('NewTourPlanScreen: Set date: $dateToSelect');
    }

    // 3. Load ALL dropdown options FIRST (before setting selected values)
    print('NewTourPlanScreen: [Edit] Loading dropdown options...');
    try {
      await Future.wait([
        _ensureClustersLoaded(force: true),
        _loadTypeOfWorkList(),
        _loadProductsList(),
        _loadCustomerTypeList(),
      ]);
      print('NewTourPlanScreen: [Edit] Dropdown options loaded');
      print('  - Clusters: ${_clusters.length}');
      print('  - Customer Types: ${_customerTypeOptions.length}');
      print('  - Products: ${_productOptions.length}');
      print('  - Purpose: ${_purposeOptions.length}');
    } catch (e) {
      print('NewTourPlanScreen: [Edit] Error loading dropdown options: $e');
    }

    // 4. NOW set selected values after options are loaded
    if (mounted) {
      setState(() {
        // Reset any previous selections first so we always reflect the
        // latest tour-plan payload (e.g. after Send Back update refresh).
        _selectedClusters = clustersToSelect;
        _autoSelectedClusters = <String>{};
        _removedAutoSelectedClusters = <String>{};
        _clusterError = null;
        print(
            'NewTourPlanScreen: [Edit] Set clusters: ${_selectedClusters.toList()}');
      });
    }

    // 5. Map cluster IDs and verify cluster names match loaded options
    if (tourPlan.tourPlanDetails != null &&
        tourPlan.tourPlanDetails!.isNotEmpty) {
      final detail = tourPlan.tourPlanDetails!.first;
      if (detail.clusterId > 0 && _selectedClusters.isNotEmpty) {
        final firstClusterName = _selectedClusters.first;
        if (mounted) {
          setState(() {
            _clusterNameToId[firstClusterName] = detail.clusterId;
            if (!_clusters.contains(firstClusterName)) {
              _clusters.add(firstClusterName);
            }
          });
        }
      }
    }

    // Verify cluster names match loaded options (case-insensitive fallback)
    if (_selectedClusters.isNotEmpty) {
      final missingClusterIds = _selectedClusters.where((clusterName) {
        final clusterId = _clusterNameToId[clusterName];
        return clusterId == null || clusterId <= 0;
      }).toList();

      if (missingClusterIds.isNotEmpty) {
        final Set<String> correctedClusters = <String>{};
        for (final cluster in _selectedClusters) {
          if (missingClusterIds.contains(cluster)) {
            // Try case-insensitive match
            final matchedKey = _clusterNameToId.keys.firstWhere(
              (key) => key.toLowerCase().trim() == cluster.toLowerCase().trim(),
              orElse: () => cluster, // Keep original if no match
            );
            correctedClusters.add(matchedKey);
          } else {
            correctedClusters.add(cluster);
          }
        }
        if (mounted) {
          setState(() {
            _selectedClusters = correctedClusters;
          });
        }
      }
    }

    // 6. Populate calls from tourPlanDetails (customers loaded per call afterward)
    if (mounted) {
      setState(() {
        _calls.clear();
      });
    }

    if (tourPlan.tourPlanDetails != null &&
        tourPlan.tourPlanDetails!.isNotEmpty) {
      print(
          'NewTourPlanScreen: [Edit] Populating ${tourPlan.tourPlanDetails!.length} calls...');

      for (final detail in tourPlan.tourPlanDetails!) {
        print('  Call Detail:');
        print('    - customerId: ${detail.customerId}');
        print('    - customerType: ${detail.customerType}');
        print('    - typeOfWorkId: ${detail.typeOfWorkId}');
        print('    - productsToDiscuss: ${detail.productsToDiscuss}');
        print('    - samplesToDistribute: ${detail.samplesToDistribute}');
        print('    - remarks: ${detail.remarks}');

        Set<String> parsedProducts = <String>{};
        if (detail.productsToBeDiscussed != null &&
            detail.productsToBeDiscussed!.isNotEmpty) {
          for (final product in detail.productsToBeDiscussed!) {
            if (product.productName.isNotEmpty) {
              parsedProducts.add(product.productName);
              if (product.productId > 0 &&
                  !_productNameToId.containsKey(product.productName)) {
                _productNameToId[product.productName] = product.productId;
              }
            }
          }
          print('    ✅ Loaded ${parsedProducts.length} products from array');
        } else if (detail.productsToDiscuss != null &&
            detail.productsToDiscuss!.isNotEmpty) {
          parsedProducts = detail.productsToDiscuss!
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet();
          print('    ✅ Loaded ${parsedProducts.length} products from string');
        }

        String? purposeValue = _typeOfWorkIdToName[detail.typeOfWorkId];
        if (purposeValue == null && detail.typeOfWorkId > 0) {
          purposeValue = null;
          print('    ⚠️ Purpose ID ${detail.typeOfWorkId} not found in map');
        } else if (purposeValue != null) {
          print('    ✅ Resolved purpose: $purposeValue');
        }

        final String? customerTypeValue =
            _resolveCustomerTypeName(detail.customerType);
        if (customerTypeValue != null) {
          print('    ✅ Resolved customer type: $customerTypeValue');
        }

        final callData = _CallData(
          customerType: customerTypeValue,
          products: parsedProducts,
          samplesCtrl:
              TextEditingController(text: detail.samplesToDistribute ?? ''),
          remarksCtrl: TextEditingController(text: detail.remarks ?? ''),
          purpose: purposeValue,
        );

        if (mounted) {
          setState(() {
            _calls.add(callData);
          });
        }
      }

      for (int i = 0; i < _calls.length; i++) {
        final detail = tourPlan.tourPlanDetails![i];
        if (_isCustomerOptionalPurposeForCall(_calls[i])) continue;
        if (_calls[i].customerType == null || _calls[i].customerType!.isEmpty) {
          continue;
        }
        if (_selectedClusters.isEmpty) continue;

        try {
          await _loadMappedCustomersForCall(i);
        } catch (e) {
          print(
              'NewTourPlanScreen: [Edit] Error loading customers for call ${i + 1}: $e');
        }

        Set<String> resolvedCustomers = <String>{};
        if (detail.customerId > 0) {
          final customerName = _customerIdToName[detail.customerId];
          if (customerName != null &&
              customerName.isNotEmpty &&
              _calls[i].customerOptions.contains(customerName)) {
            resolvedCustomers = {customerName};
            print(
                '    ✅ Resolved customer ID ${detail.customerId} to: $customerName');
          } else {
            String? fallbackCustomerName;
            if (detail.location != null && detail.location!.contains('-')) {
              final parts = detail.location!.split('-');
              if (parts.length >= 2) {
                fallbackCustomerName = parts.sublist(1).join('-').trim();
              }
            }
            if (fallbackCustomerName != null &&
                fallbackCustomerName.isNotEmpty) {
              if (_calls[i].customerOptions.contains(fallbackCustomerName)) {
                resolvedCustomers = {fallbackCustomerName};
                print('    ✅ Using fallback customer: $fallbackCustomerName');
              } else {
                resolvedCustomers = {fallbackCustomerName};
                print(
                    '    ⚠️ Using fallback customer (not in dropdown): $fallbackCustomerName');
              }
            } else {
              resolvedCustomers = {'Customer ID: ${detail.customerId}'};
              print(
                  '    ⚠️ Using placeholder for customer ID: ${detail.customerId}');
            }
          }
        }

        if (mounted && resolvedCustomers.isNotEmpty) {
          setState(() {
            _calls[i].customers = resolvedCustomers;
          });
        }
      }
    } else {
      // Fallback: create one call from header data
      print(
          'NewTourPlanScreen: [Edit] No tourPlanDetails, creating call from header');
      Set<String> parsedProducts = <String>{};
      if (tourPlan.productsToDiscuss != null &&
          tourPlan.productsToDiscuss!.trim().isNotEmpty) {
        parsedProducts = tourPlan.productsToDiscuss!
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet();
      }

      final callData = _CallData(
        products: parsedProducts,
        samplesCtrl:
            TextEditingController(text: tourPlan.samplesToDistribute ?? ''),
        remarksCtrl: TextEditingController(text: tourPlan.notes ?? ''),
        customers:
            tourPlan.customerName != null && tourPlan.customerName!.isNotEmpty
                ? {tourPlan.customerName!}
                : <String>{},
        purpose: null,
      );

      if (mounted) {
        setState(() {
          _calls.add(callData);
        });
      }
    }

    // Final state update
    if (mounted) {
      setState(() {
        _updateAutoSelectedClusters();
        _clearCallErrors();
      });
    }
    print('NewTourPlanScreen: [Edit] ✅ Form population completed!');
    print('  - Clusters selected: ${_selectedClusters.length}');
    print('  - Calls created: ${_calls.length}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requestedInitialClusters) {
      _requestedInitialClusters = true;
      _ensureClustersLoaded();
    }
  }

  // Theme color matching login and punch screens
  static const Color tealGreen = Color(0xFF4db1b3);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 768;
    final borderColor = Colors.grey.withOpacity(0.2);
    final InputBorder commonBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: borderColor, width: 1),
    );
    final screenTheme = theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
        border: commonBorder,
        enabledBorder: commonBorder,
        focusedBorder: commonBorder.copyWith(
          borderSide: const BorderSide(color: Color(0xFF4db1b3), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2.2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 14,
          vertical: isTablet ? 16 : 14,
        ),
      ),
    );
    final bool allCallsCustomerOptional = _calls.isNotEmpty &&
        _calls.every(_isCustomerOptionalPurposeForCall);
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          _isViewOnlyMode
              ? 'View Tour Plan'
              : (widget.tourPlanToEdit != null ? 'Edit Tour Plan' : 'New Tour Plan'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFF4db1b3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Theme(
          data: screenTheme,
          child: _isLoadingDetails
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF4db1b3),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: const Color(0xFF4db1b3),
                  edgeOffset: 12,
                  displacement: 36,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 24 : 16,
                      20,
                      isTablet ? 24 : 16,
                      20 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: isTablet ? 900 : double.infinity),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Employee: read-only, shows current user's name (for both manager and non-manager)
                            _Labeled(
                              label: 'Employee',
                              required: true,
                              child: AppTextField(
                                hint: 'Employee',
                                readOnly: true,
                                controller: TextEditingController(
                                    text: _selectedEmployee ?? ''),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Reporting Staff: dropdown for managers only; other fields load based on selection
                            if (_isManagerOrFieldManager) ...[
                              _Labeled(
                                label: 'Reporting Staff',
                                required: true,
                                errorText: _employeeError,
                                child: _isLoadingEmployees
                                    ? AppTextField(
                                        hint: 'Loading reporting staff...',
                                        readOnly: true,
                                        controller: TextEditingController(),
                                      )
                                    : _SingleSelectDropdown(
                                        options: _employeeOptions,
                                        value: _selectedReportingStaff,
                                        hintText: 'Select Reporting Staff',
                                        enableSearch: true,
                                        onChanged: (v) {
                                          setState(() {
                                            _selectedReportingStaff = v;
                                            _selectedEmployeeId = v != null
                                                ? _employeeNameToId[v]
                                                : null;
                                            _employeeError = null;
                                            // Clear clusters and customers when reporting staff changes
                                            _selectedClusters.clear();
                                            _customerNameToId.clear();
                                            _customerIdToName.clear();
                                            _customerNameToClusterName
                                                .clear();
                                            _autoSelectedClusters.clear();
                                            _removedAutoSelectedClusters.clear();
                                            _purposeOptions.clear();
                                            _typeOfWorkNameToId.clear();
                                            _typeOfWorkIdToName.clear();
                                            _lastLoadedPurposeRepType = null;
                                            _productOptions.clear();
                                            _productNameToId.clear();
                                            _customerTypeOptions.clear();
                                            _customerTypeNameToId.clear();
                                            for (final call in _calls) {
                                              call.customers = {};
                                              call.customerType = null;
                                              call.customerOptions = [];
                                            }
                                            _updateAutoSelectedClusters();
                                          });
                                          if (_selectedEmployeeId != null) {
                                            _loadClusterList(force: true);
                                            _loadTypeOfWorkList();
                                            _loadProductsList();
                                            _loadCustomerTypeList();
                                          }
                                        },
                                      ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            _Labeled(
                              label: 'Tour Plan Date',
                              required: true,
                              errorText: _dateError,
                              child: AppTextField(
                                hint: 'Select Date',
                                readOnly: true,
                                suffixIcon:
                                    const Icon(Icons.calendar_today_outlined),
                                onTap: _isViewOnlyMode ? null : _pickDate,
                                controller: _dateCtrl,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Labeled(
                              label: 'Cluster/city',
                              required: !allCallsCustomerOptional,
                              errorText: _clusterError,
                              child: _MultiSelectDropdown(
                                options: _clusters,
                                selectedValues: _selectedClusters,
                                hintText: _isLoadingClusters
                                    ? 'Loading clusters...'
                                    : 'Select cluster/city',
                                isLoading: _isLoadingClusters,
                                emptyMessage: _isLoadingClusters
                                    ? 'Loading clusters...'
                                    : 'No clusters found',
                                isEnabled: !_isViewOnlyMode &&
                                    !allCallsCustomerOptional,
                                onBeforeOpen: _isViewOnlyMode ? null : () => _ensureClustersLoaded(),
                                onChanged: _isViewOnlyMode
                                    ? (_) {} // No-op function for view-only mode
                                    : (v) {
                                        setState(() {
                                          final Set<String> removedNow =
                                              _selectedClusters
                                                  .difference(v)
                                                  .intersection(
                                                      _autoSelectedClusters);
                                          if (removedNow.isNotEmpty) {
                                            _removedAutoSelectedClusters
                                                .addAll(removedNow);
                                          }
                                          final Set<String> reAddedNow = v
                                              .intersection(
                                                  _removedAutoSelectedClusters);
                                          if (reAddedNow.isNotEmpty) {
                                            _removedAutoSelectedClusters
                                                .removeAll(reAddedNow);
                                          }
                                          _selectedClusters = v;
                                          _clusterError = null;
                                          _updateAutoSelectedClusters();
                                        });
                                        // Refresh customers for each call
                                        _loadMappedCustomersForAllCalls()
                                            .catchError((e) {
                                          print(
                                              'NewTourPlanScreen: Error loading customers: $e');
                                        });
                                      },
                              ),
                            ),
                            const SizedBox(height: 16),
                            for (int i = 0; i < _calls.length; i++) ...[
                              _CallCard(
                                index: i,
                                dateLabel: _formatDate(_tourPlanDate),
                                data: _calls[i],
                                customerTypeOptions: _customerTypeOptions,
                                isLoadingCustomerType: _isLoadingCustomerType,
                                customerOptions: _calls[i].customerOptions,
                                customerLabelBuilder: (name) {
                                  final cluster =
                                      _customerNameToClusterName[name]?.trim();
                                  if (cluster == null || cluster.isEmpty) {
                                    return name;
                                  }
                                  return '$name ($cluster)';
                                },
                                purposeOptions: _purposeOptions,
                                isLoadingPurpose: _isLoadingPurpose,
                                productOptions: _productOptions,
                                isViewOnly: _isViewOnlyMode,
                                isCustomerEnabled:
                                    !_isCustomerOptionalPurposeForCall(_calls[i]),
                                isCustomerRequired:
                                    !_isCustomerOptionalPurposeForCall(_calls[i]),
                                isProductsRequired:
                                    _isProductsMandatoryForCall(_calls[i]),
                                isCustomerTypeEnabled:
                                    !_isCustomerOptionalPurposeForCall(_calls[i]),
                                isCustomerTypeRequired:
                                    !_isCustomerOptionalPurposeForCall(_calls[i]),
                                isLoadingCustomers: _calls[i].isLoadingCustomers,
                                customerTypeError: i < _callErrors.length
                                    ? _callErrors[i].customerTypeError
                                    : null,
                                customerError: i < _callErrors.length
                                    ? _callErrors[i].customerError
                                    : null,
                                purposeError: i < _callErrors.length
                                    ? _callErrors[i].purposeError
                                    : null,
                                productsError: i < _callErrors.length
                                    ? _callErrors[i].productsError
                                    : null,
                                onCustomersChanged: _isViewOnlyMode
                                    ? null
                                    : (customers) => setState(() {
                                        _calls[i].customers = customers;
                                        if (_callErrors.length > i) {
                                          final List<_CallValidationState> updated =
                                              _cloneCallErrors();
                                          updated[i].customerError = null;
                                          _callErrors = updated;
                                        }
                                        _updateAutoSelectedClusters();
                                      }),
                                onCustomerTypeChanged: _isViewOnlyMode
                                    ? null
                                    : (customerType) {
                                        setState(() {
                                          _calls[i].customerType = customerType;
                                          _calls[i].customers = <String>{};
                                          _calls[i].customerOptions = [];
                                          if (_callErrors.length > i) {
                                            final List<_CallValidationState>
                                                updated = _cloneCallErrors();
                                            updated[i].customerTypeError = null;
                                            updated[i].customerError = null;
                                            _callErrors = updated;
                                          }
                                        });
                                        if (customerType != null &&
                                            customerType.isNotEmpty &&
                                            _selectedClusters.isNotEmpty) {
                                          _loadMappedCustomersForCall(i)
                                              .catchError((e) {
                                            print(
                                                'NewTourPlanScreen: Error loading customers for call ${i + 1}: $e');
                                          });
                                        }
                                      },
                                onPurposeChanged: _isViewOnlyMode
                                    ? null
                                    : (purpose) => setState(() {
                                        _calls[i].purpose = purpose;
                                        final bool isCustomerOptional =
                                            _isCustomerOptionalPurposeForCall(
                                                _calls[i]);
                                        if (isCustomerOptional) {
                                          _calls[i].customers = <String>{};
                                          _calls[i].customerType = null;
                                          _calls[i].customerOptions = [];
                                        }
                                        final bool allOptionalNow =
                                            _calls.isNotEmpty &&
                                                _calls.every(
                                                    _isCustomerOptionalPurposeForCall);
                                        if (allOptionalNow) {
                                          _selectedClusters = <String>{};
                                          _clusterError = null;
                                        }
                                        if (_callErrors.length > i) {
                                          final List<_CallValidationState> updated =
                                              _cloneCallErrors();
                                          if (isCustomerOptional) {
                                            updated[i].customerError = null;
                                            updated[i].customerTypeError = null;
                                          }
                                          updated[i].purposeError = null;
                                          if (!_isProductsMandatoryForCall(
                                              _calls[i])) {
                                            updated[i].productsError = null;
                                          }
                                          _callErrors = updated;
                                        }
                                      }),
                                onProductsChanged: _isViewOnlyMode
                                    ? null
                                    : (products) => setState(() {
                                        _calls[i].products = products;
                                        if (_callErrors.length > i) {
                                          final List<_CallValidationState> updated =
                                              _cloneCallErrors();
                                          updated[i].productsError = null;
                                          _callErrors = updated;
                                        }
                                      }),
                                onToggleExpand: _isViewOnlyMode
                                    ? null
                                    : () => setState(() {
                                        final bool current =
                                            _calls[i].isExpanded ?? true;
                                        _calls[i].isExpanded = !current;
                                      }),
                                // Allow removing calls while creating/editing.
                                // Keep disabled only in view-only mode.
                                onRemove: (!_isViewOnlyMode)
                                    ? () {
                                        if (_calls.length == 1) {
                                          _showSnack(
                                              '⚠ At least one call is required.');
                                          return;
                                        }
                                        setState(() {
                                          _calls.removeAt(i);
                                          if (_callErrors.length > i) {
                                            final updated = _cloneCallErrors();
                                            updated.removeAt(i);
                                            _callErrors = updated;
                                          }
                                          _updateAutoSelectedClusters();
                                        });
                                      }
                                    : null,
                              ),
                              const SizedBox(height: 16),
                            ],
                            Row(
                              children: [
                                // Hide Add Call button in view-only mode
                                if (!_isViewOnlyMode)
                                  Expanded(
                                    child: _AddAnotherCallButton(
                                      onPressed: () => setState(() {
                                        for (final c in _calls) {
                                          c.isExpanded = false;
                                        }
                                        _calls.add(_CallData(isExpanded: true));
                                        _callErrors = [
                                          ..._cloneCallErrors(),
                                          _CallValidationState(),
                                        ];
                                      }),
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                // Hide submit button in view-only mode
                                if (!_isViewOnlyMode)
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : () async {
                                              if (!_validateForm()) {
                                                return;
                                              }
                                              _handleSubmit();
                                            },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF4db1b3),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        elevation: 2,
                                        disabledBackgroundColor:
                                            const Color(0xFF4db1b3)
                                              .withOpacity(0.6),
                                    ),
                                    child: Text(
                                      widget.tourPlanToEdit != null
                                          ? 'Update'
                                          : 'Submit',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return; // Prevent double submission

    setState(() {
      _isSubmitting = true;
    });

    try {
      final bool isEditing = widget.tourPlanToEdit != null;
      print(
          'NewTourPlanScreen: ========== ${isEditing ? 'UPDATING' : 'SUBMITTING'} TOUR PLAN ==========');

      final store = getIt<TourPlanStore>();
      final userStore = getIt<UserDetailStore>();
      final DateTime selectedPlanDate = _toLocalMidnight(_tourPlanDate);
      final String planDateStr =
          '${selectedPlanDate.year.toString().padLeft(4, '0')}-${selectedPlanDate.month.toString().padLeft(2, '0')}-${selectedPlanDate.day.toString().padLeft(2, '0')}';
      final String planDateTimeStr = _formatApiDateTime(selectedPlanDate);
      final DateTime today = DateTime.now();
      final String todayDateTimeStr = _formatApiDateTime(_toLocalMidnight(today));

      // Resolve selected cluster ID (first selected if multiple)
      final int resolvedClusterId = _selectedClusters.isEmpty
          ? 0
          : (_clusterNameToId[_selectedClusters.first] ?? 0);

      final bool allCallsCustomerOptional = _calls.isNotEmpty &&
          _calls.every(_isCustomerOptionalPurposeForCall);

      // Enforce: for each selected cluster/city, at least one customer must be selected
      // (Skip this enforcement when Service Engineer marks purpose as "Available".)
      if (_selectedClusters.isNotEmpty && !allCallsCustomerOptional) {
        String norm(String s) => s.toLowerCase().trim();

        bool isCallCustomerOptional(_CallData call) {
          return _isCustomerOptionalPurposeForCall(call);
        }

        final requiredCalls =
            _calls.where((c) => !isCallCustomerOptional(c)).toList();

        // If no call requires customer selection, don't block submission.
        if (requiredCalls.isNotEmpty) {
          final Set<String> selectedClustersNorm =
              _selectedClusters.map(norm).toSet();

          final Set<String> clustersWithCustomersNorm = <String>{};
          for (final call in requiredCalls) {
            for (final customer in call.customers) {
              final customerCluster =
                  _customerNameToClusterName[customer]?.trim();
              if (customerCluster == null || customerCluster.isEmpty) continue;
              final cNorm = norm(customerCluster);
              if (selectedClustersNorm.contains(cNorm)) {
                clustersWithCustomersNorm.add(cNorm);
              }
            }
          }

          final missingClusters = _selectedClusters
              .where((c) => !clustersWithCustomersNorm.contains(norm(c)))
              .toList(growable: false);

          if (missingClusters.isNotEmpty) {
            if (mounted) {
              setState(() {
                _clusterError =
                    'Select at least one customer for each selected cluster/city';
              });
            }
            _showSnack(
                'Please select at least one customer for each selected cluster/city: ${missingClusters.join(', ')}');
            return;
          }
        }
      }

      // Build details: one entry per selected customer (with its cluster)
      final List<Map<String, dynamic>> details = <Map<String, dynamic>>[];
      // Array of selected cluster IDs
      final List<int> clusterIdsArray = _selectedClusters
          .map((name) => _clusterNameToId[name] ?? 0)
          .where((id) => id > 0)
          .toList();

      // If no clusters selected, use resolvedClusterId as fallback
      final List<int> effectiveClusterIds = clusterIdsArray.isNotEmpty 
          ? clusterIdsArray 
          : (resolvedClusterId > 0 ? [resolvedClusterId] : []);

      // Create one detail entry for each selected customer (per call)
      int detailIndex = 0;
      for (int callIndex = 0; callIndex < _calls.length; callIndex++) {
        final _CallData call = _calls[callIndex];
        final int typeOfWorkId = call.purpose == null
            ? 0
            : (_typeOfWorkNameToId[call.purpose!] ?? 0);

        // Build ProductsToBeDiscussed array with ProductId and ProductName
        final List<Map<String, dynamic>> productsToBeDiscussedArray =
            <Map<String, dynamic>>[];
        for (final productName in call.products) {
          final productId = _productNameToId[productName] ?? 0;
          if (productId > 0) {
            productsToBeDiscussedArray.add({
              'ProductId': productId,
              'ProductName': null,
            });
          }
        }

        final bool isCustomerOptionalPurpose =
            _isCustomerOptionalPurposeForCall(call);
        final bool isPocWarrantyPurpose = _isProductsMandatoryForCall(call);

        if (isCustomerOptionalPurpose) {
          // Available/Warranty Services entry should not require/select customer or city.
          final int existingDetailId =
              (_fullTourPlanData?.tourPlanDetails != null &&
                      _fullTourPlanData!.tourPlanDetails!.length > detailIndex)
                  ? (_fullTourPlanData!.tourPlanDetails![detailIndex].id)
                  : ((widget.tourPlanToEdit?.tourPlanDetails != null &&
                          widget.tourPlanToEdit!.tourPlanDetails!.length >
                              detailIndex)
                      ? widget.tourPlanToEdit!.tourPlanDetails![detailIndex].id
                      : 0);

          details.add({
            'Id': existingDetailId,
            'PlanDate': planDateTimeStr,
            'TypeOfWorkId': typeOfWorkId,
            'ClusterId': 0,
            'CustomerId': 0,
            'Status': 1,
            'Remarks': call.remarksCtrl.text.trim(),
            'Location': ' - ',
            'Latitude': null,
            'Longitude': null,
            'SamplesToDistribute': '',
            'ProductsToDiscuss': '',
            'ClusterNames': null,
            'Customers': null,
            'ProductsToBeDiscussed':
                isPocWarrantyPurpose ? productsToBeDiscussedArray : [],
            'MappedInstruments': [],
            'CustomerType': null,
          });
          detailIndex++;
        } else {
          for (final customerName in call.customers) {
          final int customerId = _customerNameToId[customerName] ?? 0;

          // Prefer cluster mapping returned by API for this customer; fallback if only one cluster selected
          String clusterName =
              (_customerNameToClusterName[customerName] ?? '').trim();
          if (clusterName.isEmpty && _selectedClusters.length == 1) {
            clusterName = _selectedClusters.first.trim();
          }

          int clusterId = 0;
          if (clusterName.isNotEmpty) {
            clusterId = _clusterNameToId[clusterName] ?? 0;
          }
          if (clusterId == 0 && effectiveClusterIds.length == 1) {
            clusterId = effectiveClusterIds.first;
          }

          // If editing, map existing detail id from fetched item by index
          final int existingDetailId =
              (_fullTourPlanData?.tourPlanDetails != null &&
                      _fullTourPlanData!.tourPlanDetails!.length > detailIndex)
                  ? (_fullTourPlanData!.tourPlanDetails![detailIndex].id)
                  : ((widget.tourPlanToEdit?.tourPlanDetails != null &&
                          widget.tourPlanToEdit!.tourPlanDetails!.length >
                              detailIndex)
                      ? widget
                          .tourPlanToEdit!.tourPlanDetails![detailIndex].id
                      : 0);

          final List<Map<String, dynamic>> customersArray =
              <Map<String, dynamic>>[
            {
              'CustomerId': customerId,
              'ClusterId': clusterId,
            }
          ];

          final String locationFromCustomer = clusterName.isNotEmpty
              ? '$clusterName - $customerName'
              : ' - $customerName';

          final int? callCustomerTypeId =
              _resolveCustomerTypeId(call.customerType);

          details.add({
            'Id': existingDetailId,
            'PlanDate': planDateTimeStr,
            'TypeOfWorkId': typeOfWorkId,
            'ClusterId': clusterId,
            'CustomerId': customerId,
            'Status': 1,
            'Remarks': call.remarksCtrl.text.trim(),
            'Location': locationFromCustomer,
            'Latitude': null,
            'Longitude': null,
            'SamplesToDistribute': call.samplesCtrl.text.trim(),
            'ProductsToDiscuss': '',
            'ClusterNames': clusterName.isNotEmpty ? clusterName : null,
            'Customers': customersArray,
            'ProductsToBeDiscussed': productsToBeDiscussedArray,
            'MappedInstruments': [],
            'CustomerType': callCustomerTypeId,
          });
          detailIndex++;
        }
        }
      }

      // Build header TourPlanType as array of all selected purposes
      final Set<String> purposesAll = <String>{};
      for (final _CallData call in _calls) {
        if (call.purpose != null) {
          purposesAll.add(call.purpose!);
        }
      }
      final List<String> tourPlanTypeArray =
          purposesAll.isEmpty ? ['General'] : purposesAll.toList();

      // Aggregate samples and products from all calls for header level
      final List<String> allSamples = <String>[];
      final Set<String> allProducts = <String>{};
      for (final _CallData call in _calls) {
        final String samples = call.samplesCtrl.text.trim();
        if (samples.isNotEmpty) {
          allSamples.add(samples);
        }
        allProducts.addAll(call.products);
      }
      final String aggregatedSamples = allSamples.join(', ');
      final String aggregatedProducts = allProducts.join(', ');

      final int userId = userStore.userDetail?.id ?? 0;
      final int sbuId = userStore.userDetail?.sbuId ?? 0;

      final bool shouldSendAvailableHeaderDefaults = allCallsCustomerOptional;

      // For managers use selected reporting staff; otherwise use current user
      final int employeeId =
          (_isManagerOrFieldManager && _selectedEmployeeId != null)
              ? _selectedEmployeeId!
              : (userStore.userDetail?.employeeId ?? 0);
      final String employeeName =
          (_isManagerOrFieldManager && _selectedReportingStaff != null)
              ? _selectedReportingStaff!
              : (userStore.userDetail?.employeeName ?? "");

      print(
          'NewTourPlanScreen: [Submit] Using employeeId: $employeeId (Manager/Field Manager: $_isManagerOrFieldManager)');

      // For updates: Header Id must be TourPlanId from the list item
      final bool isNewTourPlan = widget.tourPlanToEdit == null;
      // (kept) headerClusterName was unused; removed

      // Header customer type: use when all non-optional calls share the same type
      final Set<int?> headerCustomerTypeIds = <int?>{};
      for (final _CallData call in _calls) {
        if (_isCustomerOptionalPurposeForCall(call)) continue;
        headerCustomerTypeIds.add(_resolveCustomerTypeId(call.customerType));
      }
      final int? customerTypeId = headerCustomerTypeIds.length == 1
          ? headerCustomerTypeIds.first
          : null;
      print('NewTourPlanScreen: [DEBUG] headerCustomerTypeIds: $headerCustomerTypeIds');
      print('NewTourPlanScreen: [DEBUG] customerTypeId: $customerTypeId');

      final Map<String, dynamic> body = {
        'Id': isNewTourPlan
            ? null
            : (widget.tourPlanToEdit!.tourPlanId != 0
                ? widget.tourPlanToEdit!.tourPlanId
                : widget.tourPlanToEdit!.id),
        'TourPlanId': isNewTourPlan ? null : widget.tourPlanToEdit!.tourPlanId,
        'CreatedBy': widget.tourPlanToEdit?.createdBy ?? userId,
        'Status': 1,
        'SbuId': sbuId,
        'Employee': employeeId,
        'Month': selectedPlanDate.month,
        'Year': selectedPlanDate.year,
        'StatusId': 0,
        'SubmittedDate': null,
        'Remarks': null,
        'Active': false,
        'UserId': userId,
        'EmployeeId': employeeId,
        'Date': todayDateTimeStr,
        'Territory': "",
        'Cluster': "",
        'ClusterId': null,
        'TourPlanType':
            shouldSendAvailableHeaderDefaults
                ? (_isPocRep ? 'Warranty Services' : 'Available')
                : (tourPlanTypeArray.isNotEmpty
                    ? tourPlanTypeArray.first
                    : 'General'),
        'Objective': null,
        'TourPlanStatus': 'Pending',
        'TourPlanHeaderStatus': null,
        'Summary': null,
        'TourPlanDetails': details,
        'SubmittedAt': null,
        'ApprovedAt': null,
        'RejectedAt': null,
        'RejectionReason': null,
        'ManagerComments': null,
        'ActionComments': null,
        'Comments': [],
        'Bizunit': sbuId,
        'IsSelected': false,
        'EmployeeName': employeeName,
        'Designation': "",
        'StatusText': "",
        'PlanDate': planDateTimeStr,
        'CustomerId': 0,
        'CustomerName': "",
        'Clusters': shouldSendAvailableHeaderDefaults
            ? ""
            : (_selectedClusters.isNotEmpty ? _selectedClusters.join(', ') : ""),
        'SamplesToDistribute':
            shouldSendAvailableHeaderDefaults
                ? null
                : (aggregatedSamples.isNotEmpty ? aggregatedSamples : null),
        'ProductsToDiscuss':
            shouldSendAvailableHeaderDefaults
                ? null
                : (aggregatedProducts.isNotEmpty ? aggregatedProducts : null),
        'Notes': null,
        'FromDeviation': null,
        'TotalCustomers': null,
        'PlannedMonth': null,
        'PlannedPercentage': null,
        'VisitedMonth': null,
        'VisitedPercentage': null,
        'PendingMonth': null,
        'PlannedToday': null,
        'VisitedToday': null,
        'RepType': null,
        'CustomerType':
            shouldSendAvailableHeaderDefaults ? null : customerTypeId,
      };

      // Print Request Data with full payload
      print('NewTourPlanScreen: ========== REQUEST PAYLOAD ==========');
      print('NewTourPlanScreen: ${isEditing ? 'UPDATE' : 'CREATE'} TOUR PLAN');
      print('NewTourPlanScreen: Mode: ${isEditing ? 'Update' : 'Create'}');
      print('NewTourPlanScreen: Tour Plan ID: ${widget.tourPlanToEdit?.id ?? 'New'}');
      print('NewTourPlanScreen: User ID: $userId');
      print('NewTourPlanScreen: Employee ID: $employeeId');
      print('NewTourPlanScreen: SBU ID: $sbuId');
      print('NewTourPlanScreen: Plan Date: $planDateStr');
      print(
          'NewTourPlanScreen: Selected Clusters count: ${_selectedClusters.length}');
      print('NewTourPlanScreen: Cluster IDs Array: $clusterIdsArray');
      print('NewTourPlanScreen: Effective Cluster IDs: $effectiveClusterIds');
      print('NewTourPlanScreen: Number of Details to Create: ${details.length}');
      print('NewTourPlanScreen: Tour Plan Type: $tourPlanTypeArray');
      print('NewTourPlanScreen: Customer Type ID (header): $customerTypeId');
      print('NewTourPlanScreen: Number of Calls: ${_calls.length}');

      print('NewTourPlanScreen: Call debug entries count: ${_calls.length}');
      print(
          'NewTourPlanScreen: Tour Plan Details debug entries count: ${details.length}');

      // Print request summary only (avoid logging payload chunks in loop).
      print('NewTourPlanScreen: ========== FULL REQUEST BODY (JSON) ==========');
      try {
        final jsonString = const JsonEncoder.withIndent('  ').convert(body);
        print('NewTourPlanScreen: JSON Length: ${jsonString.length} characters');
        print(
            'NewTourPlanScreen: JSON Chunk Count: ${(jsonString.length / 1000).ceil()}');
      } catch (e) {
        print('NewTourPlanScreen: Error formatting JSON: $e');
        print('NewTourPlanScreen: Stack trace: ${StackTrace.current}');
        final bodyString = body.toString();
        print('NewTourPlanScreen: Body String Length: ${bodyString.length} characters');
        print(
            'NewTourPlanScreen: Body String Chunk Count: ${(bodyString.length / 1000).ceil()}');
      }
      print('NewTourPlanScreen: ========== END OF REQUEST BODY ==========');
      print('NewTourPlanScreen: ========== SENDING REQUEST ==========');

      // Use updateTourPlan for editing and saveTourPlan for new tour plans
      if (isEditing) {
        await store.updateTourPlan(body);
      } else {
        await store.saveTourPlan(body);
      }

      final res = store.saveResponse;

      // Print Response Data
      print('NewTourPlanScreen: ========== RESPONSE DATA ==========');
      if (res != null) {
        print('NewTourPlanScreen: Full Response Body:');
        print('  $res');
      } else {
        print('NewTourPlanScreen:  No response received from API');
      }
      print(
          'NewTourPlanScreen: ========== ${isEditing ? 'UPDATE' : 'SUBMIT'} COMPLETED ==========');

      if (!mounted) return;

      // Show success/error toast
      // Error case: store sets status: false (boolean) when there's an error
      // Success case: API returns tour plan object with status: 0 (integer)
      bool isSuccess = false;
      String errorMessage = '';

      if (res != null) {
        // Check for explicit error set by store (boolean false)
        final hasStoreError = res['status'] == false;

        // Check for error message fields
        final hasErrorMessage = res['error'] != null ||
            res['errorMessage'] != null ||
            (res['msg']?.toString().toLowerCase().contains('error') == true);

        if (hasStoreError || hasErrorMessage) {
          // It's an error
          isSuccess = false;
          // Prioritize errorMessage (which contains the extracted user-friendly message)
          // then msg, then error (which may contain technical details)
          errorMessage = res['errorMessage']?.toString() ??
              res['msg']?.toString() ??
              res['error']?.toString() ??
              'Unknown error occurred';
          
          // Clean up error message - remove technical DioException details if present
          if (errorMessage.contains('DioException')) {
            // Try to extract just the meaningful part
            if (errorMessage.contains('msg:')) {
              final msgIndex = errorMessage.indexOf('msg:');
              final afterMsg = errorMessage.substring(msgIndex + 4).trim();
              if (afterMsg.isNotEmpty && !afterMsg.contains('DioException')) {
                errorMessage = afterMsg.split('\n').first.trim();
              }
            }
            // If still contains DioException, use a generic message
            if (errorMessage.contains('DioException')) {
              errorMessage = res['msg']?.toString() ?? 
                           'An error occurred while ${isEditing ? 'updating' : 'submitting'} the tour plan. Please try again.';
            }
          }
        } else {
          // No error indicators - consider it success
          isSuccess = true;
        }
      } else {
        // No response received
        isSuccess = false;
        errorMessage = 'No response received from server. Please check your connection and try again.';
      }
      
      ToastMessage.show(
        context,
        message: isSuccess
            ? 'Success: Tour plan ${isEditing ? 'updated' : 'submitted'} successfully'
            : errorMessage.isNotEmpty 
                ? errorMessage 
                : 'Failed to ${isEditing ? 'update' : 'submit'} tour plan. Please try again.',
        type: isSuccess ? ToastType.success : ToastType.error,
        duration: Duration(seconds: isSuccess ? 3 : 5),
      );

      // Refresh Tour Plan data on success before leaving
      if (isSuccess && mounted) {
        try {
          final tourPlanStore = getIt<TourPlanStore>();
          final userStore2 = getIt<UserDetailStore>();
          final int employeeId2 = userStore2.userDetail?.employeeId ?? 0;
          // IMPORTANT: use actual userId for calendar view consistency
          final int userIdForCalendar = userStore2.userDetail?.userId ?? 0;
          final int userIdForList = userStore2.userDetail?.id ?? 0;
          final int bizunit2 = userStore2.userDetail?.sbuId ?? 0;
          final int month2 = _tourPlanDate.month;
          final int year2 = _tourPlanDate.year;

          // Await refresh calls to ensure UI sees latest data before returning
          await tourPlanStore.loadCalendarViewData(
            month: month2,
            year: year2,
            userId: userIdForCalendar,
            managerId: 0,
            employeeId: employeeId2,
            selectedEmployeeId: employeeId2,
          );
          await tourPlanStore.loadCalendarItemListData(
            employeeId: employeeId2,
            month: month2,
            userId: userIdForList,
            bizunit: bizunit2,
            year: year2,
          );
          // Also refresh summary widgets commonly shown with calendar
          try {
            await tourPlanStore.loadTourPlanEmployeeListSummary(
              employeeId: employeeId2,
              month: month2,
              year: year2,
            );
            await tourPlanStore.loadTourPlanSummary(
              month: month2,
              year: year2,
              userId: userIdForCalendar,
              bizunit: bizunit2,
            );
          } catch (_) {}

          // Add a small delay to ensure API has processed the new tour plan
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (_) {}

        // Pop back to previous screen after successful save/update
        // This ensures navigation back to tour plan main page after updating
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e, stackTrace) {
      final bool isEditing = widget.tourPlanToEdit != null;
      print('NewTourPlanScreen: ========== ERROR OCCURRED ==========');
      print(
          'NewTourPlanScreen: ERROR ${isEditing ? 'UPDATING' : 'SUBMITTING'} TOUR PLAN: $e');
      print('NewTourPlanScreen: Stack Trace: $stackTrace');
      print('NewTourPlanScreen: ========== ERROR END ==========');
      if (!mounted) return;
      
      // Extract user-friendly error message
      String errorMessage = 'Failed to ${isEditing ? 'update' : 'submit'} tour plan';
      
      // Check if it's a DioException and extract message
      if (e is DioException) {
        if (e.response != null) {
          final responseData = e.response?.data;
          if (responseData is Map) {
            errorMessage = responseData['errormessage']?.toString() ??
                          responseData['message']?.toString() ??
                          responseData['errorMessage']?.toString() ??
                          responseData['error']?.toString() ??
                          responseData['msg']?.toString() ??
                          errorMessage;
          } else if (responseData is String && responseData.isNotEmpty) {
            errorMessage = responseData;
          } else {
            final statusCode = e.response?.statusCode;
            if (statusCode == 500) {
              errorMessage = 'Server error occurred. Please try again later or contact support.';
            } else if (statusCode == 400) {
              errorMessage = 'Invalid request. Please check your input and try again.';
            } else if (statusCode == 401) {
              errorMessage = 'Authentication failed. Please login again.';
            }
          }
        } else {
          errorMessage = 'No response from server. Please check your connection and try again.';
        }
      } else {
        // For non-DioException, try to extract meaningful message
        final errorString = e.toString();
        if (errorString.startsWith('Exception: ')) {
          errorMessage = errorString.replaceFirst('Exception: ', '');
        } else if (!errorString.contains('DioException')) {
          errorMessage = errorString;
        }
      }
      
      ToastMessage.show(
        context,
        message: errorMessage,
        type: ToastType.error,
        duration: const Duration(seconds: 5),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    // Avoid duplicate loads while details are loading
    if (_isLoadingDetails) return;
    if (widget.tourPlanToEdit != null) {
      await _loadTourPlanDetails();
    } else {
      await _loadInitialData();
    }
  }

  Future<void> _pickDate() async {
    // Don't allow date picking in view-only mode
    if (_isViewOnlyMode) return;
    // Get today's date at midnight for comparison
    final DateTime today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // For editing, allow the existing date even if it's in the past
    // But for new tour plans, only allow today or future dates
    final bool isEditing = widget.tourPlanToEdit != null;
    final DateTime firstDate =
        isEditing && _tourPlanDate.isBefore(today) ? _tourPlanDate : today;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _tourPlanDate.isBefore(today) && isEditing
          ? _tourPlanDate
          : (_tourPlanDate.isBefore(today) ? today : _tourPlanDate),
      firstDate:
          firstDate, // Allow existing past date when editing, otherwise only today or future dates
      lastDate: DateTime(2035, 12, 31),
      helpText: 'Select date',
      builder: (context, child) {
        final ThemeData base = Theme.of(context);
        return Theme(
          data: base.copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4db1b3),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF4db1b3),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      // Validate that the selected date is not in the past (for new tour plans or when changing date in edit mode)
      final DateTime selectedDate =
          DateTime(picked.year, picked.month, picked.day);
      if (selectedDate.isBefore(today)) {
        // This shouldn't happen due to firstDate restriction, but add safety check
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠ Cannot select a past date. Please select today or a future date.',
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 13,
                ),
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        _tourPlanDate = picked;
        _dateCtrl.text = _formatDate(picked);
        _dateError = null;
      });
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')}-${months[d.month - 1]}-${d.year}';
  }

  DateTime _toLocalMidnight(DateTime date) {
    final DateTime localDate = date.toLocal();
    return DateTime(localDate.year, localDate.month, localDate.day);
  }

  String _formatApiDateTime(DateTime dateTime) {
    final String y = dateTime.year.toString().padLeft(4, '0');
    final String m = dateTime.month.toString().padLeft(2, '0');
    final String d = dateTime.day.toString().padLeft(2, '0');
    final String hh = dateTime.hour.toString().padLeft(2, '0');
    final String mm = dateTime.minute.toString().padLeft(2, '0');
    final String ss = dateTime.second.toString().padLeft(2, '0');
    final String ms = dateTime.millisecond.toString().padLeft(3, '0');
    return '$y-$m-${d}T$hh:$mm:$ss.$ms';
  }

  void _showSnack(String message, {Color backgroundColor = Colors.orange}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
            ),
          ),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  bool _isCustomerOptionalPurposeForCall(_CallData call) {
    final String purposeLower = (call.purpose ?? '').trim().toLowerCase();
    final bool serviceEngineerAvailable =
        _isServiceEngineer && purposeLower == 'available';
    final bool pocRepWarranty =
        _isPocRep && purposeLower == 'warranty services';
    return serviceEngineerAvailable || pocRepWarranty;
  }

  bool _isProductsMandatoryForCall(_CallData call) {
    final String purposeLower = (call.purpose ?? '').trim().toLowerCase();
    return _isPocRep && purposeLower == 'warranty services';
  }

  void _clearCallErrors() {
    _callErrors = List<_CallValidationState>.generate(
      _calls.length,
      (_) => _CallValidationState(),
    );
  }

  List<_CallValidationState> _cloneCallErrors() {
    return _callErrors.map((e) => e.copy()).toList();
  }

  void _syncCallErrorsLength() {
    if (_callErrors.length == _calls.length) {
      return;
    }
    final List<_CallValidationState> updated =
        List<_CallValidationState>.generate(
      _calls.length,
      (index) => index < _callErrors.length
          ? _callErrors[index]
          : _CallValidationState(),
    );
    _callErrors = updated;
  }

  void _updateAutoSelectedClusters() {
    final Set<String> derivedClusters = <String>{};
    for (final call in _calls) {
      for (final customer in call.customers) {
        final clusterName = _customerNameToClusterName[customer]?.trim();
        if (clusterName != null && clusterName.isNotEmpty) {
          derivedClusters.add(clusterName);
        }
      }
    }

    if (_removedAutoSelectedClusters.isNotEmpty) {
      derivedClusters.removeAll(_removedAutoSelectedClusters);
    }

    if (derivedClusters.isNotEmpty) {
      final Set<String> combined = {..._clusters, ...derivedClusters};
      if (combined.length != _clusters.length) {
        _clusters = combined.toList();
      }
    }

    final Set<String> manualClusters =
        _selectedClusters.difference(_autoSelectedClusters);
    final Set<String> updatedSelected = {...manualClusters, ...derivedClusters};

    final bool selectionChanged =
        !setEquals(_selectedClusters, updatedSelected);
    _autoSelectedClusters = derivedClusters;

    if (selectionChanged) {
      _selectedClusters = updatedSelected;
    }

    if (_selectedClusters.isNotEmpty) {
      _clusterError = null;
    }
  }

  bool _validateForm() {
    bool isValid = true;
    String? firstMessage;

    String? dateError;
    String? clusterError;
    String? employeeError;
    final List<_CallValidationState> callErrors =
        List<_CallValidationState>.generate(
      _calls.length,
      (_) => _CallValidationState(),
    );

    // Validate reporting staff selection for managers/field managers
    if (_isManagerOrFieldManager) {
      if (_selectedReportingStaff == null ||
          _selectedReportingStaff!.isEmpty ||
          _selectedEmployeeId == null) {
        employeeError = 'Please select Reporting Staff';
        firstMessage ??= 'Select Reporting Staff';
        isValid = false;
      }
    }

    if (_dateCtrl.text.trim().isEmpty) {
      dateError = 'Please select a tour plan date';
      firstMessage ??= 'Select a tour plan date';
      isValid = false;
    } else {
      // Validate that the selected date is not in the past
      // Only validate for new tour plans (not when editing existing tour plans)
      final bool isEditing = widget.tourPlanToEdit != null;
      if (!isEditing) {
        final DateTime today = DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final DateTime selectedDate = DateTime(
            _tourPlanDate.year, _tourPlanDate.month, _tourPlanDate.day);

        if (selectedDate.isBefore(today)) {
          dateError =
              'Cannot select a past date. Please select today or a future date.';
          firstMessage ??=
              'Cannot select a past date. Please select today or a future date.';
          isValid = false;
        }
      }
    }

    final bool allCallsCustomerOptional = _calls.isNotEmpty &&
        _calls.every(_isCustomerOptionalPurposeForCall);

    if (_selectedClusters.isEmpty && !allCallsCustomerOptional) {
      clusterError = 'Please select at least one cluster/city';
      firstMessage ??= 'Select at least one cluster/city';
      isValid = false;
    }

    if (_calls.isEmpty) {
      firstMessage ??= 'Add at least one call';
      isValid = false;
    } else {
      for (int i = 0; i < _calls.length; i++) {
        final call = _calls[i];
        final String callLabel = 'Call ${i + 1}';

        final bool isCustomerOptionalPurpose =
            _isCustomerOptionalPurposeForCall(call);

        if (!isCustomerOptionalPurpose && call.customers.isEmpty) {
          callErrors[i].customerError = 'Please select at least one customer';
          firstMessage ??= 'Select customer for $callLabel';
          isValid = false;
        }

        if (!isCustomerOptionalPurpose &&
            (call.customerType == null || call.customerType!.isEmpty)) {
          callErrors[i].customerTypeError = 'Please select a customer type';
          firstMessage ??= 'Select customer type for $callLabel';
          isValid = false;
        }

        final String purpose = (call.purpose ?? '').trim();
        if (purpose.isEmpty) {
          callErrors[i].purposeError = 'Please select purpose of visit';
          firstMessage ??= 'Select purpose for $callLabel';
          isValid = false;
        }

        if (_isProductsMandatoryForCall(call) && call.products.isEmpty) {
          callErrors[i].productsError =
              'Please select at least one product';
          firstMessage ??= 'Select product for $callLabel';
          isValid = false;
        }
      }
    }

    setState(() {
      _dateError = dateError;
      _clusterError = clusterError;
      _employeeError = employeeError;
      _callErrors = callErrors;
    });

    if (!isValid) {
      if (firstMessage != null) {
        _showSnack('⚠ $firstMessage');
      }
      return false;
    }

    return true;
  }

  Future<void> _loadTourPlanEmployeeList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        final List<CommonDropdownItem> items =
            await repo.getTourPlanEmployeeList();
        final names = items
            .map((e) =>
                (e.employeeName.isNotEmpty ? e.employeeName : e.text).trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        if (names.isNotEmpty) {
          for (final item in items) {
            final String key =
                (item.employeeName.isNotEmpty ? item.employeeName : item.text)
                    .trim();
            if (key.isNotEmpty) _customerNameToId[key] = item.id;
          }
        }
      }
    } catch (e) {}
  }

  bool _requestedInitialClusters = false;
  bool _isLoadingClusters = false;

  Future<void> _loadClusterList({bool force = false}) async {
    if (_isLoadingClusters) return;
    if (_clusters.isNotEmpty && !force) return;

    // Manager/Field Manager must select Reporting Staff first
    if (_isManagerOrFieldManager && _selectedEmployeeId == null) {
      print(
          'NewTourPlanScreen: [Clusters] Manager role without selected reporting staff - skipping cluster load');
      return;
    }

    if (mounted) {
      setState(() => _isLoadingClusters = true);
    } else {
      _isLoadingClusters = true;
    }

    try {
      if (!getIt.isRegistered<CommonRepository>()) {
        return;
      }
      final repo = getIt<CommonRepository>();
      const int countryId = 208;

      // For managers/field managers, use selectedEmployeeId; otherwise use current user's employeeId
      int? employeeIdNullable;
      if (_isManagerOrFieldManager && _selectedEmployeeId != null) {
        employeeIdNullable = _selectedEmployeeId;
        print(
            'NewTourPlanScreen: [Clusters] Using selected employeeId: $employeeIdNullable (Manager/Field Manager)');
      } else {
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
            ? getIt<UserDetailStore>()
            : null;
        employeeIdNullable = userStore?.userDetail?.employeeId;
        int retry = 0;
        while (employeeIdNullable == null && retry < 5) {
          await Future.delayed(const Duration(milliseconds: 200));
          employeeIdNullable = userStore?.userDetail?.employeeId;
          retry++;
        }
        if (employeeIdNullable == null) {
          print(
              'NewTourPlanScreen: [Clusters] employeeId still null after retries');
          return;
        }
        print(
            'NewTourPlanScreen: [Clusters] Using current user employeeId: $employeeIdNullable');
      }

      // At this point, employeeIdNullable is guaranteed to be non-null
      final int employeeId = employeeIdNullable!;
      final String planDateTimeStr =
          _formatApiDateTime(_toLocalMidnight(_tourPlanDate));
      final List<CommonDropdownItem> items = await repo
          .getClusterList(countryId, employeeId, planDate: planDateTimeStr)
          .timeout(const Duration(seconds: 15));
      final Set<String> clusters = items
          .map((e) => (e.text.isNotEmpty ? e.text : e.cityName).trim())
          .where((s) => s.isNotEmpty)
          .toSet();
      final Set<String> preselectedClusters = items
          .where((e) => e.isSelected)
          .map((e) => (e.text.isNotEmpty ? e.text : e.cityName).trim())
          .where((s) => s.isNotEmpty)
          .toSet();

      if (clusters.isNotEmpty) {
        if (mounted) {
          setState(() {
            if (force) {
              _clusters = clusters.toList();
            } else {
              _clusters = {..._clusters, ...clusters}.toList();
            }
            _selectedClusters = {..._selectedClusters, ...preselectedClusters};
            _clusterError = null;
            for (final item in items) {
              final String key =
                  (item.text.isNotEmpty ? item.text : item.cityName).trim();
              if (key.isNotEmpty) {
                _clusterNameToId[key] = item.id;
              }
            }
          });
        } else {
          if (force) {
            _clusters = clusters.toList();
          } else {
            _clusters = {..._clusters, ...clusters}.toList();
          }
          _selectedClusters = {..._selectedClusters, ...preselectedClusters};
          for (final item in items) {
            final String key =
                (item.text.isNotEmpty ? item.text : item.cityName).trim();
            if (key.isNotEmpty) {
              _clusterNameToId[key] = item.id;
            }
          }
        }
      }
    } catch (e) {
      print('NewTourPlanScreen: [Clusters] Error loading clusters: $e');
      if (mounted) {
        ToastMessage.show(context,
            message: 'Error loading clusters: ${e.toString()}',
            type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingClusters = false);
      } else {
        _isLoadingClusters = false;
      }
    }
  }

  Future<void> _ensureClustersLoaded({bool force = false}) async {
    if (_clusters.isNotEmpty && !force) return;
    await _loadClusterList(force: force);
  }

  Future<void> _loadTypeOfWorkList() async {
    final int loadGeneration = ++_purposeLoadGeneration;
    try {
      if (mounted) {
        setState(() {
          _isLoadingPurpose = true;
        });
      }
      // Manager/Field Manager must select Reporting Staff first
      if (_isManagerOrFieldManager && _selectedEmployeeId == null) {
        print(
            'NewTourPlanScreen: [PurposeOfVisit] Manager role without selected reporting staff - skipping');
        if (mounted) {
          setState(() {
            _isLoadingPurpose = false;
          });
        }
        return;
      }
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        final UserDetail? loggedInUser =
            await PurposeVisitHelper.ensureLoggedInUserProfile(_userDetailStore);

        // SE manager planning own tour plan — ensure reporting staff employeeId is set.
        if (_isManagerOrFieldManager &&
            _selectedEmployeeId == null &&
            PurposeVisitHelper.isServiceEngineerUser(loggedInUser)) {
          _selectedEmployeeId = loggedInUser?.employeeId;
          print(
              'NewTourPlanScreen: [PurposeOfVisit] Late-bound SE manager employeeId: $_selectedEmployeeId');
        }

        int? reportingStaffRepType;
        String? reportingStaffDesignation;

        if (_isManagerOrFieldManager && _selectedEmployeeId != null) {
          reportingStaffRepType =
              _reportingStaffRepTypeByEmployeeId[_selectedEmployeeId!];
          reportingStaffDesignation =
              _reportingStaffDesignationByEmployeeId[_selectedEmployeeId!];
        }

        final int userId = PurposeVisitHelper.resolvePurposeApiUserId(
          loggedInUser: loggedInUser,
          selectedEmployeeId: _selectedEmployeeId,
        );

        final int? effectiveRepType = PurposeVisitHelper.isPlanningForSelf(
          loggedInUser: loggedInUser,
          selectedEmployeeId: _selectedEmployeeId,
        )
            ? (loggedInUser?.repType ?? reportingStaffRepType)
            : reportingStaffRepType;

        String purposeText = PurposeVisitHelper.resolveTourPlanPurposeText(
          loggedInUser: loggedInUser,
          selectedEmployeeId: _selectedEmployeeId,
          reportingStaffRepType: reportingStaffRepType,
          reportingStaffDesignation: reportingStaffDesignation,
        );

        // Hard guarantee for Service Engineer profiles (repType 5 / serviceArea).
        if (PurposeVisitHelper.isServiceEngineer(
          serviceArea: PurposeVisitHelper.isPlanningForSelf(
            loggedInUser: loggedInUser,
            selectedEmployeeId: _selectedEmployeeId,
          )
              ? loggedInUser?.serviceArea
              : null,
          repType: effectiveRepType,
          designation: reportingStaffDesignation,
        )) {
          purposeText = PurposeVisitTexts.serviceEng;
        }

        print(
            'NewTourPlanScreen: [PurposeOfVisit] apiUserId: $userId, selectedEmployeeId: $_selectedEmployeeId, repType: ${loggedInUser?.repType}, staffRepType: $reportingStaffRepType, effectiveRepType: $effectiveRepType, text: "$purposeText"');

        if (userId <= 0) {
          print('NewTourPlanScreen: [PurposeOfVisit] userId invalid, skipping');
          if (mounted) {
            setState(() {
              _isLoadingPurpose = false;
            });
          }
          return;
        }

        final List<CommonDropdownItem> items = await repo
            .getPurposeOfVisitList(userId, purposeText)
            .timeout(const Duration(seconds: 15));

        if (!mounted || loadGeneration != _purposeLoadGeneration) {
          print(
              'NewTourPlanScreen: [PurposeOfVisit] Ignoring stale response (gen $loadGeneration)');
          return;
        }

        print(
            'NewTourPlanScreen: [PurposeOfVisit] API returned ${items.length} items for Text="$purposeText"');
        if (items.isNotEmpty) {
          print(
              'NewTourPlanScreen: [PurposeOfVisit] labels: ${items.map((e) => (e.text.isNotEmpty ? e.text : e.typeText).trim()).where((s) => s.isNotEmpty).join(", ")}');
        }

        final Map<String, String> normalizedPurposeToDisplay =
            <String, String>{};
        for (final e in items) {
          final String raw = (e.text.isNotEmpty ? e.text : e.typeText).trim();
          if (raw.isEmpty) continue;
          normalizedPurposeToDisplay.putIfAbsent(raw.toLowerCase(), () => raw);
        }
        final Set<String> works = normalizedPurposeToDisplay.values.toSet();
        if (works.isNotEmpty) {
          _lastLoadedPurposeRepType = effectiveRepType;
          if (mounted) {
            setState(() {
              final List<String> dedupedPurposeOptions = works.toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              _purposeOptions = dedupedPurposeOptions;
              _typeOfWorkNameToId.clear();
              _typeOfWorkIdToName.clear();
              // map names to ids for submit
              for (final item in items) {
                final String key =
                    (item.text.isNotEmpty ? item.text : item.typeText).trim();
                if (key.isNotEmpty) {
                  _typeOfWorkNameToId[key] = item.id;
                  _typeOfWorkIdToName[item.id] =
                      key; // Reverse mapping for editing
                }
              }

              // Resolve purpose names for existing calls if editing
              if (_fullTourPlanData != null || widget.tourPlanToEdit != null) {
                print(
                    'NewTourPlanScreen: Resolving purpose names from typeOfWorkId');
                print('  - Number of calls: ${_calls.length}');
                print(
                    '  - typeOfWorkIdToName map size: ${_typeOfWorkIdToName.length}');

                for (final call in _calls) {
                  if (call.purpose == null || call.purpose!.trim().isEmpty) {
                    print('  - Found call with unresolved purpose');
                    // Find the corresponding typeOfWorkId from tourPlanDetails
                    // Use full tour plan data if available, otherwise fallback to widget data
                    final tourPlan = _fullTourPlanData ?? widget.tourPlanToEdit;
                    if (tourPlan != null && tourPlan.tourPlanDetails != null) {
                      print(
                          '  - tourPlanDetails count: ${tourPlan.tourPlanDetails!.length}');
                      for (final detail in tourPlan.tourPlanDetails!) {
                        print(
                            '    - Checking detail with typeOfWorkId: ${detail.typeOfWorkId}');
                        if (detail.typeOfWorkId > 0) {
                          final purposeName =
                              _typeOfWorkIdToName[detail.typeOfWorkId];
                          print('    - Found purpose name: $purposeName');
                          call.purpose = purposeName;
                          break;
                        }
                      }
                    }
                  }
                }
              }
            });
          }

          print(
              'NewTourPlanScreen: [PurposeOfVisit] Loaded ${_purposeOptions.length} options');
        }
      }
    } catch (e) {
      print('NewTourPlanScreen: [PurposeOfVisit] Error: $e');
      if (mounted) {
        ToastMessage.show(context,
            message: 'Error loading purpose of visit: ${e.toString()}',
            type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPurpose = false;
        });
      }
    }
  }

  Future<void> _loadProductsList() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingProducts = true;
        });
      }
      // Manager/Field Manager must select Reporting Staff first
      if (_isManagerOrFieldManager && _selectedEmployeeId == null) {
        print(
            'NewTourPlanScreen: [Products] Manager role without selected reporting staff - skipping');
        if (mounted) {
          setState(() {
            _isLoadingProducts = false;
          });
        }
        return;
      }
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
            ? getIt<UserDetailStore>()
            : null;

        // Wait for user to be loaded (retry up to 10 times = 3 seconds max)
        int retry = 0;
        while (userStore?.isUserLoaded != true && retry < 10) {
          await Future.delayed(const Duration(milliseconds: 300));
          retry++;
        }

        int? userId = userStore?.userDetail?.id;
        int? employeeId = userStore?.userDetail?.employeeId;
        String? serviceArea = userStore?.userDetail?.serviceArea;

        if (userId == null || userId <= 0) {
          print(
              'NewTourPlanScreen: [Products] userId is still null/0, skipping products load');
          if (mounted) {
            setState(() {
              _isLoadingProducts = false;
            });
          }
          return;
        }

        // For Service Engineers: use employeeId as userId and set IsFromAMCUser = 0
        // For others: use userId and set IsFromAMCUser = 0
        int? actualUserId = employeeId;
        int? isFromAMCUser = 0; // Default to 0

        if (_isManagerOrFieldManager && _selectedEmployeeId != null) {
          actualUserId = _selectedEmployeeId;
          isFromAMCUser = 0;
          print(
              'NewTourPlanScreen: [Products] Manager/Field Manager - using selected employeeId: $actualUserId, IsFromAMCUser: 0');
        } else if (PurposeVisitHelper.isServiceEngineer(
          serviceArea: serviceArea,
          repType: userStore?.userDetail?.repType,
        )) {
          if (employeeId != null && employeeId > 0) {
            actualUserId = employeeId;
            isFromAMCUser = 0;
            print(
                'NewTourPlanScreen: [Products] Service Engineer detected - using employeeId: $actualUserId, IsFromAMCUser: $isFromAMCUser');
          } else {
            actualUserId = userId;
            print(
                'NewTourPlanScreen: [Products] Service Engineer but employeeId is null/0, using userId: $actualUserId');
          }
        } else {
          isFromAMCUser = 0;
          print(
              'NewTourPlanScreen: [Products] Non-Service Engineer - using userId: $actualUserId, IsFromAMCUser: $isFromAMCUser');
        }

        print(
            'NewTourPlanScreen: [Products] Loading products with userId: $actualUserId, isFromAMCUser: $isFromAMCUser');
        final List<CommonDropdownItem> items = await repo
            .getTourPlanProductsList(actualUserId ?? 0,
                isFromAMCUser: isFromAMCUser)
            .timeout(const Duration(seconds: 15));
        if (items.isNotEmpty) {
          if (mounted) {
            setState(() {
              _productOptions.clear();
              _productNameToId.clear();
              for (final item in items) {
                final String productName =
                    (item.text.isNotEmpty ? item.text : item.name).trim();
                if (productName.isNotEmpty) {
                  _productOptions.add(productName);
                  _productNameToId[productName] = item.id;
                }
              }
            });
          }
          print(
              'NewTourPlanScreen: [Products] Loaded ${_productOptions.length} products');
        }
      }
    } catch (e) {
      print('NewTourPlanScreen: [Products] Error loading products: $e');
      if (mounted) {
        ToastMessage.show(context,
            message: 'Error loading products: ${e.toString()}',
            type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  /// Returns the type string for the Customer Type list API. Uses serviceArea when non-empty; otherwise derives from repType (1=Sales Rep, 2=Medical Rep, 5=Service Engineer) so empty serviceArea does not yield wrong API response.
  static String _customerTypeApiTypeParam({
    String? serviceArea,
    int? repType,
  }) {
    final trimmed = (serviceArea ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    switch (repType) {
      case 1:
        return 'Sales Rep';
      case 2:
        return 'Medical Rep';
      case 5:
        return 'Service Engineer';
      default:
        return 'Sales Rep';
    }
  }

  Future<void> _loadCustomerTypeList() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingCustomerType = true;
        });
      }
      // Manager/Field Manager must select Reporting Staff first
      if (_isManagerOrFieldManager && _selectedEmployeeId == null) {
        print(
            'NewTourPlanScreen: [CustomerType] Manager role without selected reporting staff - skipping');
        if (mounted) {
          setState(() {
            _isLoadingCustomerType = false;
          });
        }
        return;
      }
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
            ? getIt<UserDetailStore>()
            : null;

        // Wait for user to be loaded (retry up to 10 times = 3 seconds max)
        int retry = 0;
        while (userStore?.isUserLoaded != true && retry < 10) {
          await Future.delayed(const Duration(milliseconds: 300));
          retry++;
        }

        int? userId = userStore?.userDetail?.id;
        if (_isManagerOrFieldManager && _selectedEmployeeId != null) {
          userId = _selectedEmployeeId;
          print(
              'NewTourPlanScreen: [CustomerType] Using selected employeeId as userId: $userId');
        }
        String? serviceArea = userStore?.userDetail?.serviceArea;
        final int? repType = userStore?.userDetail?.repType;
        if (userId == null || userId <= 0) {
          print(
              'NewTourPlanScreen: [CustomerType] userId is still null/0, skipping');
          if (mounted) {
            setState(() {
              _isLoadingCustomerType = false;
            });
          }
          return;
        }

        // Type for Customer Type API: use serviceArea when non-empty; otherwise derive from repType (1=Sales Rep, 2=Medical Rep, 5=Service Engineer) so empty serviceArea does not give wrong response
        final String typeParam = _customerTypeApiTypeParam(
            serviceArea: serviceArea, repType: repType);
        print(
            'NewTourPlanScreen: [CustomerType] Loading customer types with userId: $userId, type: "$typeParam" (serviceArea: "$serviceArea", repType: $repType)');
        final List<CommonDropdownItem> items = await repo
            .getCustomerTypeList(userId, type: typeParam)
            .timeout(const Duration(seconds: 15));
        print(
            'NewTourPlanScreen: [CustomerType] API returned ${items.length} items');
        if (items.isNotEmpty) {
          if (mounted) {
            setState(() {
              _customerTypeOptions.clear();
              _customerTypeNameToId.clear();
              final Set<String> seenCustomerTypes = <String>{};

              for (final item in items) {
                final String typeName =
                    (item.text.isNotEmpty ? item.text : item.name).trim();
                final String normalizedTypeName = typeName.toLowerCase();
                if (typeName.isNotEmpty &&
                    !seenCustomerTypes.contains(normalizedTypeName)) {
                  seenCustomerTypes.add(normalizedTypeName);
                  _customerTypeOptions.add(typeName);
                  _customerTypeNameToId[typeName] = item.id;
                  print(
                      'NewTourPlanScreen: [CustomerType] Added: "$typeName" -> ${item.id}');
                }
              }
              _customerTypeOptions
                  .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            });
          }
          print(
              'NewTourPlanScreen: [CustomerType] Loaded ${_customerTypeOptions.length} customer types');
          print(
              'NewTourPlanScreen: [CustomerType] Map: $_customerTypeNameToId');
        }
      }
    } catch (e) {
      print(
          'NewTourPlanScreen: [CustomerType] Error loading customer types: $e');
      if (mounted) {
        ToastMessage.show(context,
            message: 'Error loading customer types: ${e.toString()}',
            type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCustomerType = false;
        });
      }
    }
  }

  int? _resolveCustomerTypeId(String? customerTypeName) {
    if (customerTypeName == null || customerTypeName.isEmpty) return null;
    if (_customerTypeNameToId.containsKey(customerTypeName)) {
      return _customerTypeNameToId[customerTypeName];
    }
    final String normalized = customerTypeName.toLowerCase().trim();
    for (final entry in _customerTypeNameToId.entries) {
      if (entry.key.toLowerCase().trim() == normalized) {
        return entry.value;
      }
    }
    return null;
  }

  String? _resolveCustomerTypeName(int? customerTypeId) {
    if (customerTypeId == null || customerTypeId <= 0) return null;
    for (final entry in _customerTypeNameToId.entries) {
      if (entry.value == customerTypeId) return entry.key;
    }
    return null;
  }

  Future<void> _loadMappedCustomersForAllCalls() async {
    for (int i = 0; i < _calls.length; i++) {
      final _CallData call = _calls[i];
      if (_isCustomerOptionalPurposeForCall(call)) continue;
      if (call.customerType == null || call.customerType!.isEmpty) continue;
      await _loadMappedCustomersForCall(i);
    }
  }

  Future<void> _loadMappedCustomersForCall(int callIndex) async {
    if (callIndex < 0 || callIndex >= _calls.length) return;
    final _CallData call = _calls[callIndex];

    if (_isCustomerOptionalPurposeForCall(call)) return;
    if (call.isLoadingCustomers) {
      print(
          'NewTourPlanScreen: [Customers] Call ${callIndex + 1} already loading - skipping');
      return;
    }

    try {
      if (mounted) {
        setState(() => call.isLoadingCustomers = true);
      } else {
        call.isLoadingCustomers = true;
      }

      print(
          'NewTourPlanScreen: [Customers] Start loading mapped customers for call ${callIndex + 1}');
      if (!getIt.isRegistered<TourPlanRepository>()) {
        print(
            'NewTourPlanScreen: [Customers] TourPlanRepository not registered - skipping');
        return;
      }
      final repo = getIt<TourPlanRepository>();

      int? employeeId;
      int? selectedEmployeeIdForRequest;

      if (_isManagerOrFieldManager && _selectedEmployeeId != null) {
        employeeId = _selectedEmployeeId;
        selectedEmployeeIdForRequest = _selectedEmployeeId;
      } else {
        final userStore = getIt.isRegistered<UserDetailStore>()
            ? getIt<UserDetailStore>()
            : null;
        employeeId = userStore?.userDetail?.employeeId;
        selectedEmployeeIdForRequest = null;
        if (employeeId == null) {
          print('NewTourPlanScreen: [Customers] employeeId is null - skipping');
          return;
        }
      }

      final List<ClusterIdModel> selectedClusterIds = [];
      for (final clusterName in _selectedClusters) {
        int? clusterId = _clusterNameToId[clusterName];
        if (clusterId == null || clusterId <= 0) {
          final String normalized = clusterName.toLowerCase().trim();
          for (final entry in _clusterNameToId.entries) {
            if (entry.key.toLowerCase().trim() == normalized) {
              clusterId = entry.value;
              break;
            }
          }
        }
        if (clusterId != null && clusterId > 0) {
          selectedClusterIds.add(ClusterIdModel(clusterId: clusterId));
        }
      }

      final int? customerTypeId = _resolveCustomerTypeId(call.customerType);

      if (selectedClusterIds.isEmpty ||
          call.customerType == null ||
          call.customerType!.isEmpty) {
        if (mounted) {
          setState(() {
            call.customerOptions = [];
            call.customers = {};
          });
        } else {
          call.customerOptions = [];
          call.customers = {};
        }
        return;
      }

      final DateTime localPlanDate = _toLocalMidnight(_tourPlanDate);
      final String dateStr =
          '${localPlanDate.year.toString().padLeft(4, '0')}-${localPlanDate.month.toString().padLeft(2, '0')}-${localPlanDate.day.toString().padLeft(2, '0')}';
      final String planDateTimeStr = _formatApiDateTime(localPlanDate);

      final req = GetMappedCustomersByEmployeeIdRequest(
        searchText: null,
        pageNumber: 0,
        pageSize: 0,
        sortOrder: 0,
        sortDir: 0,
        sortField: null,
        employeeId: employeeId,
        clusterId: null,
        customerId: null,
        month: null,
        tourPlanId: null,
        userId: null,
        bizunit: null,
        filterExpression: null,
        monthNumber: null,
        year: null,
        id: employeeId,
        action: null,
        comment: null,
        status: null,
        tourPlanAcceptId: null,
        remarks: null,
        clusterIds: selectedClusterIds,
        selectedEmployeeId: selectedEmployeeIdForRequest,
        date: dateStr,
        planDate: planDateTimeStr,
        customerTypeId: customerTypeId ?? 0,
      );
      print(
          'NewTourPlanScreen: [Customers] Call ${callIndex + 1} request => ${req.toJson()}');
      final res = await repo
          .getMappedCustomersByEmployeeId(req)
          .timeout(const Duration(seconds: 20));

      final List<String> loadedOptions = [];
      final Set<String> preselectedCustomers = <String>{};
      final Set<String> clusterNamesFromApi = {};

      for (final mc in res.customers) {
        loadedOptions.add(mc.customerName);
        if (mc.isSelected) {
          preselectedCustomers.add(mc.customerName);
        }
        _customerNameToId[mc.customerName] = mc.customerId;
        _customerIdToName[mc.customerId] = mc.customerName;

        String clusterName = mc.clusterName.trim();
        if (clusterName.isEmpty && mc.clusterId > 0) {
          try {
            clusterName = _clusterNameToId.entries
                .firstWhere((e) => e.value == mc.clusterId)
                .key
                .trim();
          } catch (_) {}
        }
        if (clusterName.isNotEmpty) {
          _customerNameToClusterName[mc.customerName] = clusterName;
        }
        if (clusterName.isNotEmpty && mc.clusterId > 0) {
          clusterNamesFromApi.add(clusterName);
          if (!_clusterNameToId.containsKey(clusterName)) {
            _clusterNameToId[clusterName] = mc.clusterId;
          }
          if (!_clusters.contains(clusterName)) {
            _clusters.add(clusterName);
          }
        }
      }

      if (mounted) {
        setState(() {
          call.customerOptions = loadedOptions.toSet().toList();
          _clusters = _clusters.toSet().toList();

          if (clusterNamesFromApi.isNotEmpty) {
            final Set<String> updatedSelectedClusters = {};
            for (final selectedCluster in _selectedClusters) {
              String? matchedCluster;
              for (final apiCluster in clusterNamesFromApi) {
                if (apiCluster.toLowerCase().trim() ==
                    selectedCluster.toLowerCase().trim()) {
                  matchedCluster = apiCluster;
                  break;
                }
              }
              updatedSelectedClusters
                  .add(matchedCluster ?? selectedCluster);
            }
            if (!setEquals(_selectedClusters, updatedSelectedClusters)) {
              _selectedClusters = updatedSelectedClusters;
            }
          }

          final Set<String> validCustomerNames = call.customerOptions.toSet();
          if (call.customers.length == 1) {
            final only = call.customers.first;
            if (only.startsWith('Customer ID:')) {
              final idStr = only.split(':').last.trim();
              final int? cid = int.tryParse(idStr);
              if (cid != null && _customerIdToName[cid] != null) {
                final resolvedName = _customerIdToName[cid]!;
                call.customers = validCustomerNames.contains(resolvedName)
                    ? {resolvedName}
                    : {};
              } else {
                call.customers = {};
              }
            } else if (!validCustomerNames.contains(only)) {
              call.customers = {};
            }
          } else if (call.customers.length > 1) {
            call.customers =
                call.customers.where(validCustomerNames.contains).toSet();
          }

          if (widget.tourPlanToEdit == null &&
              preselectedCustomers.isNotEmpty &&
              call.customers.isEmpty) {
            call.customers = preselectedCustomers
                .where(validCustomerNames.contains)
                .toSet();
          }

          _syncCallErrorsLength();
          _updateAutoSelectedClusters();
        });
      } else {
        call.customerOptions = loadedOptions.toSet().toList();
      }
    } catch (e) {
      print(
          'NewTourPlanScreen: [Customers] Error loading customers for call ${callIndex + 1}: $e');
      if (mounted) {
        ToastMessage.show(context,
            message: 'Error loading customers: ${e.toString()}',
            type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => call.isLoadingCustomers = false);
      } else {
        call.isLoadingCustomers = false;
      }
    }
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({
    this.label,
    required this.child,
    this.errorText,
    this.required = false,
  });
  final String? label;
  final Widget child;
  final String? errorText;
  final bool required;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          RichText(
            text: TextSpan(
              text: label!,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 0.1,
              ),
              children: required
                  ? [
                      TextSpan(
                        text: ' *',
                        style: GoogleFonts.inter(
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 8),
        ],
        child,
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: GoogleFonts.inter(
              color: Colors.red.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ],
    );
  }
}

class _SpacerLabel extends StatelessWidget {
  const _SpacerLabel(this.height);
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

class _CallData {
  _CallData({
    bool? isExpanded,
    String? customerType,
    Set<String>? customers,
    List<String>? customerOptions,
    String? purpose,
    Set<String>? products,
    TextEditingController? samplesCtrl,
    TextEditingController? remarksCtrl,
  })  : isExpanded = isExpanded ?? true,
        customerType = customerType,
        customers = customers ?? <String>{},
        customerOptions = customerOptions ?? <String>[],
        purpose = purpose,
        products = products ?? <String>{},
        samplesCtrl = samplesCtrl ?? TextEditingController(),
        remarksCtrl = remarksCtrl ?? TextEditingController();
  bool? isExpanded;
  String? customerType;
  Set<String> customers = <String>{};
  List<String> customerOptions = <String>[];
  bool isLoadingCustomers = false;
  String? purpose;
  Set<String> products = <String>{};
  late final TextEditingController samplesCtrl;
  late final TextEditingController remarksCtrl;
  void dispose() {
    samplesCtrl.dispose();
    remarksCtrl.dispose();
  }
}

class _CallValidationState {
  _CallValidationState({
    this.customerTypeError,
    this.customerError,
    this.purposeError,
    this.productsError,
  });
  String? customerTypeError;
  String? customerError;
  String? purposeError;
  String? productsError;

  _CallValidationState copy() {
    return _CallValidationState(
      customerTypeError: customerTypeError,
      customerError: customerError,
      purposeError: purposeError,
      productsError: productsError,
    );
  }
}

class _CallCard extends StatelessWidget {
  const _CallCard({
    required this.index,
    required this.dateLabel,
    required this.data,
    required this.customerTypeOptions,
    this.isLoadingCustomerType = false,
    required this.customerOptions,
    this.customerLabelBuilder,
    required this.purposeOptions,
    required this.productOptions,
    this.isLoadingPurpose = false,
    this.isLoadingProducts = false,
    this.isViewOnly = false,
    this.isCustomerTypeEnabled = true,
    this.isCustomerTypeRequired = true,
    this.isCustomerEnabled = true,
    this.isCustomerRequired = true,
    this.isProductsRequired = false,
    this.isLoadingCustomers = false,
    this.customerTypeError,
    this.customerError,
    this.purposeError,
    this.productsError,
    this.onCustomerTypeChanged,
    this.onCustomersChanged,
    this.onPurposeChanged,
    this.onProductsChanged,
    this.onRemove,
    this.onToggleExpand,
  });
  final int index;
  final String dateLabel;
  final _CallData data;
  final List<String> customerTypeOptions;
  final bool isLoadingCustomerType;
  final List<String> customerOptions;
  final String Function(String)? customerLabelBuilder;
  final List<String> purposeOptions;
  final List<String> productOptions;
  final bool isLoadingPurpose;
  final bool isLoadingProducts;
  final bool isViewOnly;
  final bool isCustomerTypeEnabled;
  final bool isCustomerTypeRequired;
  final bool isCustomerEnabled;
  final bool isCustomerRequired;
  final bool isProductsRequired;
  final bool isLoadingCustomers;
  final String? customerTypeError;
  final String? customerError;
  final String? purposeError;
  final String? productsError;
  final ValueChanged<String?>? onCustomerTypeChanged;
  final ValueChanged<Set<String>>? onCustomersChanged;
  final ValueChanged<String?>? onPurposeChanged;
  final ValueChanged<Set<String>>? onProductsChanged;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 768;
    final bool expanded = data.isExpanded ?? true;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isTablet ? 20 : 16,
          isTablet ? 18 : 16,
          isTablet ? 20 : 16,
          isTablet ? 18 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4db1b3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.phone_in_talk_rounded,
                    color: Color(0xFF4db1b3),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Call ${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (onToggleExpand != null && !isViewOnly)
                  TextButton.icon(
                    onPressed: onToggleExpand,
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                    ),
                    label: Text(
                      expanded ? 'Less' : 'More',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4db1b3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!expanded) ...[
              _CollapsedSummary(
                data: data,
                customersToShow: isCustomerEnabled ? data.customers : <String>{},
              ),
              const SizedBox(height: 4),
            ],
            if (expanded) ...[
              const SizedBox(height: 4),
              if (isCustomerTypeEnabled) ...[
                _Labeled(
                  label: 'Customer Type',
                  required: isCustomerTypeRequired,
                  errorText: customerTypeError,
                  child: _SingleSelectDropdown(
                    options: customerTypeOptions,
                    value: data.customerType,
                    hintText: isLoadingCustomerType
                        ? 'Loading customer types...'
                        : 'Select customer type',
                    isLoading: isLoadingCustomerType,
                    isEnabled: !isViewOnly && isCustomerTypeEnabled,
                    onChanged: isViewOnly
                        ? (_) {}
                        : (value) {
                            if (onCustomerTypeChanged != null) {
                              onCustomerTypeChanged!(value);
                            } else {
                              data.customerType = value;
                            }
                          },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _Labeled(
                label: 'Customer',
                required: isCustomerRequired,
                errorText: customerError,
                child: _MultiSelectDropdown(
                  options: customerOptions,
                  selectedValues: isCustomerEnabled ? data.customers : <String>{},
                  labelBuilder: customerLabelBuilder,
                  hintText: isLoadingCustomers
                      ? 'Loading customers...'
                      : 'Select customer',
                  emptyMessage: isLoadingCustomers
                      ? 'Loading customers...'
                      : 'No customers found',
                  isLoading: isLoadingCustomers,
                  isEnabled: !isViewOnly && isCustomerEnabled,
                  onChanged: isViewOnly
                      ? (_) {} // No-op function for view-only mode
                      : (!isCustomerEnabled ? (_) {} : (set) {
                          if (onCustomersChanged != null) {
                            onCustomersChanged!(set);
                          } else {
                            data.customers = set;
                          }
                        }),
                ),
              ),
              const SizedBox(height: 12),
              _Labeled(
                label: 'Purpose of Visit',
                required: true,
                errorText: purposeError,
                child: _SingleSelectDropdown(
                  options: purposeOptions,
                  value: data.purpose,
                  hintText: isLoadingPurpose
                      ? 'Loading purpose...'
                      : purposeOptions.isEmpty
                          ? 'Select purpose'
                          : 'Select purpose (${purposeOptions.length} options)',
                  isLoading: isLoadingPurpose,
                  isEnabled: !isViewOnly,
                  enableSearch: true,
                  onChanged: isViewOnly
                      ? (_) {} // No-op function for view-only mode
                      : (value) {
                          if (onPurposeChanged != null) {
                            onPurposeChanged!(value);
                          } else {
                            data.purpose = value;
                          }
                        },
                ),
              ),
              const SizedBox(height: 12),
              _Labeled(
                label: 'Products to Discuss',
                required: isProductsRequired,
                errorText: productsError,
                child: _MultiSelectDropdown(
                  options: productOptions,
                  selectedValues: data.products,
                  hintText: isLoadingProducts
                      ? 'Loading products...'
                      : 'Select products',
                  emptyMessage: isLoadingProducts
                      ? 'Loading products...'
                      : 'No products found',
                  isLoading: isLoadingProducts,
                  isEnabled: !isViewOnly,
                  onChanged: isViewOnly
                      ? (_) {} // No-op function for view-only mode
                      : (set) {
                          if (onProductsChanged != null) {
                            onProductsChanged!(set);
                          } else {
                            data.products = set;
                          }
                        },
                ),
              ),
              const SizedBox(height: 12),
              _Labeled(
                label: 'Notes/Remarks',
                child: TextFormField(
                  controller: data.remarksCtrl,
                  maxLines: 3,
                  readOnly: isViewOnly,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Expanded(
                  //   child: OutlinedButton(
                  //     onPressed: () {},
                  //     style: OutlinedButton.styleFrom(
                  //       padding: const EdgeInsets.symmetric(vertical: 14),
                  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  //     ),
                  //     child: const Text('Save as draft'),
                  //   ),
                  // ),
                  // const SizedBox(width: 16),
                  // Only show Remove button if onRemove callback is provided (not in edit mode)
                  if (onRemove != null)
                    FilledButton(
                      onPressed: onRemove,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 14),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        visualDensity: VisualDensity.compact,
                        elevation: 0,
                      ),
                      child: Text(
                        'Remove',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CollapsedSummary extends StatelessWidget {
  const _CollapsedSummary({
    required this.data,
    required this.customersToShow,
  });
  final _CallData data;
  final Set<String> customersToShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String customers = customersToShow.isEmpty
        ? 'No customer'
        : customersToShow.join(', ');
    String purpose = data.purpose ?? 'No purpose';
    final String products = data.products.join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          customers,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          purpose,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Colors.grey[700],
          ),
        ),
        if (products.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            products,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
}

class _AddAnotherCallButton extends StatelessWidget {
  const _AddAnotherCallButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const Color tealGreen = Color(0xFF4db1b3);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_circle_outline, size: 18, color: tealGreen),
      label: Text(
        'Add Call',
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: tealGreen,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: tealGreen,
        side: const BorderSide(color: tealGreen, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _MultiSelectDropdown extends StatefulWidget {
  const _MultiSelectDropdown({
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    this.labelBuilder,
    this.hintText,
    this.isLoading = false,
    this.onBeforeOpen,
    this.emptyMessage,
    this.isEnabled = true,
  });
  final List<String> options;
  final Set<String> selectedValues;
  final ValueChanged<Set<String>> onChanged;
  final String Function(String value)? labelBuilder;
  final String? hintText;
  final bool isLoading;
  final Future<void> Function()? onBeforeOpen;
  final String? emptyMessage;
  final bool isEnabled;

  @override
  State<_MultiSelectDropdown> createState() => _MultiSelectDropdownState();
}

// Shared static set to track all open dropdown overlays across all dropdown instances
final Set<OverlayEntry> _sharedOpenOverlays = {};

class _MultiSelectDropdownState extends State<_MultiSelectDropdown> {
  final LayerLink _link = LayerLink();
  final FocusNode _displayFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  OverlayEntry? _entry;
  Set<String> _selected = <String>{};
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _displayController = TextEditingController();

  @override
  void dispose() {
    _removeOverlay();
    _searchCtrl.dispose();
    _displayController.dispose();
    _displayFocusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selectedValues};
    _updateDisplayText();
    // Prevent the display field from requesting focus to avoid keyboard
    _displayFocusNode.canRequestFocus = false;
    // Ensure search field starts unfocused
    _searchFocusNode.unfocus();
  }

  @override
  void didUpdateWidget(covariant _MultiSelectDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync with parent if it changed externally
    if (!setEquals(_selected, widget.selectedValues)) {
      _selected = {...widget.selectedValues};
    }
    // Update display text when widget updates
    _updateDisplayText();
  }

  void _updateDisplayText() {
    // Use _selected if it's in sync, otherwise use widget.selectedValues
    final Set<String> currentValues =
        setEquals(_selected, widget.selectedValues)
            ? _selected
            : widget.selectedValues;
    final String display = _summary(currentValues);
    if (_displayController.text != display) {
      _displayController.text = display;
      // Move cursor to end
      _displayController.selection =
          TextSelection.collapsed(offset: display.length);
    }
  }

  String _labelFor(String value) {
    final builder = widget.labelBuilder;
    return builder != null ? builder(value) : value;
  }

  @override
  Widget build(BuildContext context) {
    // Always use widget.selectedValues to ensure we're in sync with parent
    // Sync _selected with widget.selectedValues for overlay state
    if (!setEquals(_selected, widget.selectedValues)) {
      _selected = {...widget.selectedValues};
    }

    // Update display text in build to ensure it's always current
    final String display = _summary(widget.selectedValues);
    // Ensure controller text matches display
    if (_displayController.text != display) {
      _displayController.text = display;
      _displayController.selection =
          TextSelection.collapsed(offset: display.length);
    }

    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: widget.isEnabled ? () async => _toggleOverlay() : null,
        behavior: HitTestBehavior.opaque,
        child: AbsorbPointer(
          child: TextFormField(
            readOnly: true,
            controller: _displayController,
            focusNode: _displayFocusNode,
            enableInteractiveSelection: false,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: display.isEmpty
                  ? (widget.isLoading
                      ? 'Loading...'
                      : (widget.hintText ?? 'Select'))
                  : null,
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey[500],
              ),
              suffixIcon: widget.isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  : const Icon(Icons.expand_more),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleOverlay() async {
    // Don't open overlay if disabled
    if (!widget.isEnabled) return;
    
    // Dismiss keyboard and unfocus everything
    _displayFocusNode.unfocus();
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    if (_entry == null) {
      if (widget.onBeforeOpen != null) {
        await widget.onBeforeOpen!();
      }
      if (!mounted) return;
      if (widget.isLoading) {
        return;
      }
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    // Close all other open overlays first to prevent overlap
    for (final overlay in _sharedOpenOverlays.toList()) {
      overlay.remove();
    }
    _sharedOpenOverlays.clear();

    // Dismiss keyboard and unfocus everything before showing overlay
    _displayFocusNode.unfocus();
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    // Always sync local selection with latest parent-provided values
    _selected = {...widget.selectedValues};
    // Update display text to ensure it's in sync
    _updateDisplayText();
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Size size = box.size;
    _entry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        // Detect if mobile device (width < 600)
        final bool isMobile = MediaQuery.of(context).size.width < 600;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                  onTap: _removeOverlay, behavior: HitTestBehavior.translucent),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 8),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: size.width,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(.10),
                          blurRadius: 18,
                          offset: const Offset(0, 6)),
                    ],
                    border: Border.all(color: Colors.black.withOpacity(.06)),
                  ),
                  child: Theme(
                    data: theme.copyWith(
                      checkboxTheme: CheckboxThemeData(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        side: BorderSide(
                            color: Colors.black.withOpacity(.35), width: 1.4),
                        fillColor: WidgetStateProperty.resolveWith(
                            (states) => const Color(0xFF4db1b3)),
                      ),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                                isMobile ? 12 : 12,
                                isMobile ? 12 : 10,
                                isMobile ? 12 : 12,
                                isMobile ? 10 : 8),
                            child: TextField(
                              controller: _searchCtrl,
                              focusNode: _searchFocusNode,
                              autofocus: false,
                              style: GoogleFonts.inter(
                                color: Colors.black87,
                                fontSize: isMobile ? 14 : 13,
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                hintStyle: GoogleFonts.inter(
                                  color: Colors.grey[500],
                                  fontSize: isMobile ? 14 : 13,
                                ),
                                prefixIcon:
                                    Icon(Icons.search, color: Colors.grey[600]),
                                suffixIcon: (_query.isNotEmpty)
                                    ? IconButton(
                                        icon: Icon(Icons.close,
                                            color: Colors.grey[600]),
                                        tooltip: 'Clear',
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          _query = '';
                                          _entry?.markNeedsBuild();
                                        },
                                      )
                                    : null,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 16 : 12,
                                    vertical: isMobile ? 16 : 10),
                                filled: true,
                                fillColor: const Color(0xFFF5F6F8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.black.withOpacity(.10)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.black.withOpacity(.10)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2),
                                ),
                              ),
                              onChanged: (q) {
                                _query = q.trim().toLowerCase();
                                _entry?.markNeedsBuild();
                              },
                              onTap: () {
                                // Request focus when user explicitly taps on search field
                                _searchFocusNode.requestFocus();
                              },
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                if (widget.isLoading) {
                                  return Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          widget.emptyMessage ?? 'Loading...',
                                          style: GoogleFonts.inter(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                // Check if options list is empty
                                if (widget.options.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 20,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.emptyMessage ??
                                              'No data found',
                                          style: GoogleFonts.inter(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                // Filter options and show selected items on top
                                final filtered = _query.isEmpty
                                    ? widget.options
                                    : widget.options
                                        .where((o) =>
                                            o.toLowerCase().contains(_query) ||
                                            _labelFor(o)
                                                .toLowerCase()
                                                .contains(_query))
                                        .toList(growable: false);

                                // Sort to show selected items on top
                                final sortedFiltered =
                                    List<String>.from(filtered);
                                sortedFiltered.sort((a, b) {
                                  final aSelected = _selected.contains(a);
                                  final bSelected = _selected.contains(b);
                                  if (aSelected && !bSelected) return -1;
                                  if (!aSelected && bSelected) return 1;
                                  return 0;
                                });

                                // Check if filtered list is empty (after search)
                                if (filtered.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 20,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'No matching results',
                                          style: GoogleFonts.inter(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  itemCount: sortedFiltered.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    final opt = sortedFiltered[i];
                                    final selected = _selected.contains(opt);
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _toggle(opt),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 10),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                    color: selected
                                                        ? const Color(
                                                            0xFF4db1b3)
                                                        : Colors.black
                                                            .withOpacity(.42),
                                                    width: 1.6),
                                                color: selected
                                                    ? const Color(0xFF4db1b3)
                                                    : Colors.transparent,
                                              ),
                                              child: selected
                                                  ? const Icon(Icons.check,
                                                      size: 16,
                                                      color: Colors.white)
                                                  : null,
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Text(
                                                _labelFor(opt),
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_entry!);
    _sharedOpenOverlays.add(_entry!);

    // Ensure search field is not focused after overlay is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.unfocus();
        _displayFocusNode.unfocus();
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  void _removeOverlay() {
    if (_entry != null) {
      _entry!.remove();
      _sharedOpenOverlays.remove(_entry);
      _entry = null;
    }
    // Unfocus search field when overlay is removed
    _searchFocusNode.unfocus();
  }

  void _toggle(String opt) {
    if (_selected.contains(opt)) {
      _selected.remove(opt);
    } else {
      _selected.add(opt);
    }
    // Update display text immediately based on local state
    final String display = _summary(_selected);
    _displayController.text = display;
    _displayController.selection =
        TextSelection.collapsed(offset: display.length);

    // Update parent so it can sync its state
    widget.onChanged({..._selected});
    // Update overlay state
    _entry?.markNeedsBuild();
    // Force rebuild of this widget
    setState(() {});
  }

  String _summary(Set<String> values) {
    if (values.isEmpty) return '';
    if (values.length <= 2) {
      return values.map(_labelFor).join(', ');
    }
    final firstTwo = values.take(2).map(_labelFor).join(', ');
    return '$firstTwo +${values.length - 2}';
  }
}

class _SingleSelectDropdown extends StatefulWidget {
  const _SingleSelectDropdown(
      {required this.options,
      required this.value,
      required this.onChanged,
      this.hintText,
      this.isLoading = false,
      this.isEnabled = true,
      this.enableSearch = false});
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? hintText;
  final bool isLoading;
  final bool isEnabled;
  final bool? enableSearch;

  @override
  State<_SingleSelectDropdown> createState() => _SingleSelectDropdownState();
}

class _SingleSelectDropdownState extends State<_SingleSelectDropdown> {
  final LayerLink _link = LayerLink();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchCtrl = TextEditingController();
  OverlayEntry? _entry;
  String? _value;

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.dispose();
    _searchFocusNode.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    // Prevent the field from requesting focus to avoid keyboard
    _focusNode.canRequestFocus = false;
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant _SingleSelectDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _value) {
      _value = widget.value;
    }
    if (oldWidget.options.length != widget.options.length ||
        oldWidget.isLoading != widget.isLoading) {
      _entry?.markNeedsBuild();
    }
    final bool enableSearch = widget.enableSearch ?? false;
    final bool oldEnableSearch = oldWidget.enableSearch ?? false;
    if (!enableSearch && oldEnableSearch) {
      _searchCtrl.clear();
    }
  }

  void _onSearchChanged() {
    if (_entry != null) {
      _entry!.markNeedsBuild();
    }
  }

  List<String> _filteredOptions() {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return widget.options;
    return widget.options
        .where((option) => option.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Loading...',
          suffixIcon: const SizedBox(
            width: 20,
            height: 20,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    final controller = TextEditingController(text: _value ?? '');
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: widget.isEnabled ? _toggleOverlay : null,
        behavior: HitTestBehavior.opaque,
        child: AbsorbPointer(
          child: TextFormField(
            readOnly: true,
            controller: _value == null ? null : controller,
            focusNode: _focusNode,
            enableInteractiveSelection: false,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: _value == null ? (widget.hintText ?? 'Select') : null,
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey[500],
              ),
              suffixIcon: const Icon(Icons.expand_more),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleOverlay() {
    // Don't open overlay if disabled
    if (!widget.isEnabled) return;
    
    // Dismiss keyboard and unfocus everything
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    if (_entry == null) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    // Close all other open overlays first to prevent overlap
    for (final overlay in _sharedOpenOverlays.toList()) {
      overlay.remove();
    }
    _sharedOpenOverlays.clear();

    // Dismiss keyboard and unfocus everything
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Size size = box.size;
    _entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                  onTap: _removeOverlay, behavior: HitTestBehavior.translucent),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 8),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: size.width,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(.10),
                          blurRadius: 18,
                          offset: const Offset(0, 6)),
                    ],
                    border: Border.all(color: Colors.black.withOpacity(.06)),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: Builder(builder: (context) {
                      final filteredOptions = _filteredOptions();
                      final showSearch =
                          (widget.enableSearch ?? false) &&
                              widget.options.isNotEmpty;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showSearch)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                              child: TextFormField(
                                controller: _searchCtrl,
                                focusNode: _searchFocusNode,
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: 'Search...',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _searchCtrl.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: _searchCtrl.clear,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          if (filteredOptions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.options.isEmpty
                                        ? 'No data found'
                                        : 'No matching results',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            SizedBox(
                              height: (filteredOptions.length * 52.0 + 24)
                                  .clamp(80.0, showSearch ? 260.0 : 320.0),
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                itemCount: filteredOptions.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, i) {
                                  final opt = filteredOptions[i];
                                  final selected = opt == _value;
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      _value = opt;
                                      widget.onChanged(opt);
                                      setState(() {});
                                      _removeOverlay();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: selected
                                                    ? const Color(
                                                        0xFF4db1b3)
                                                    : Colors.black
                                                        .withOpacity(.35),
                                                width: 1.4,
                                              ),
                                              color: selected
                                                  ? const Color(0xFF4db1b3)
                                                  : Colors.transparent,
                                            ),
                                            child: selected
                                                ? const Icon(Icons.check,
                                                    size: 16,
                                                    color: Colors.white)
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              opt,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_entry!);
    _sharedOpenOverlays.add(_entry!);

    // Ensure nothing is focused after overlay is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.unfocus();
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  void _removeOverlay() {
    if (_entry != null) {
      _entry!.remove();
      _sharedOpenOverlays.remove(_entry);
      _entry = null;
    }
    _searchCtrl.clear();
    _searchFocusNode.unfocus();
    _focusNode.unfocus();
  }
}
