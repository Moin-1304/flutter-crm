import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:google_fonts/google_fonts.dart';
import 'package:boilerplate/core/widgets/app_form_fields.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/presentation/crm/tour_plan/store/tour_plan_store.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/repository/tour_plan/tour_plan_repository.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/data/network/apis/user/lib/domain/entity/tour_plan/tour_plan_api_models.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';
import 'package:boilerplate/presentation/login/store/login_store.dart';
import 'package:boilerplate/utils/routes/routes.dart';
import 'package:boilerplate/domain/entity/user/user_detail.dart';

void main() {
  runApp(const MaterialApp(
    home: NewTourPlanScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class NewTourPlanScreen extends StatefulWidget {
  final TourPlanItem? tourPlanToEdit; // Add optional parameter for editing

  const NewTourPlanScreen({super.key, this.tourPlanToEdit});

  @override
  State<NewTourPlanScreen> createState() => _NewTourPlanScreenState();
}

class _NewTourPlanScreenState extends State<NewTourPlanScreen> {
  DateTime _tourPlanDate = DateTime.now();
  late final TextEditingController _dateCtrl;
  Set<String> _selectedClusters = <String>{};
  List<String> _clusters =[];
  final Map<String, int> _clusterNameToId = <String, int>{};

  // Customer and purpose options (static defaults + API appended)
  List<String> _customerOptions =  [];

  List<String> _purposeOptions =  [];
  final Map<String, int> _typeOfWorkNameToId = <String, int>{};
  final Map<int, String> _typeOfWorkIdToName = <int, String>{}; // Reverse mapping for editing
  
  // Products options for multi-select dropdown
  List<String> _productOptions = [];
  final Map<String, int> _productNameToId = <String, int>{};
  final Map<String, int> _customerNameToId = <String, int>{};
  final Map<int, String> _customerIdToName = <int, String>{}; // Added: reverse mapping id -> name
  final Map<String, String> _customerNameToClusterName = <String, String>{};
  Set<String> _autoSelectedClusters = <String>{};
  
  // Customer Type dropdown
  List<String> _customerTypeOptions = [];
  final Map<String, int> _customerTypeNameToId = <String, int>{};
  String? _selectedCustomerType;
  String? _customerTypeError;

  // Employee dropdown for managers/field managers
  List<String> _employeeOptions = [];
  final Map<String, int> _employeeNameToId = <String, int>{};
  String? _selectedEmployee;
  String? _employeeError;
  bool _isLoadingEmployees = false;
  bool _isManagerOrFieldManager = false;
  int? _selectedEmployeeId; // Store the selected employee ID

  // Dynamic calls list
  final List<_CallData> _calls = <_CallData>[
    _CallData(),
  ];
  List<_CallValidationState> _callErrors = const <_CallValidationState>[];
  String? _dateError;
  String? _clusterError;
  
  bool _isLoadingDetails = false; // Flag to track if we're loading tour plan details
  TourPlanItem? _fullTourPlanData; // Store the full tour plan data after fetching
  bool _isSubmitting = false; // Flag to track if we're submitting the tour plan

  @override
  void dispose() {
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

    // Check if user is manager or field manager
    _checkUserRole();

    if (widget.tourPlanToEdit != null) {
      // For editing, fetch full tour plan details from API
      _loadTourPlanDetails();
    } else {
      // For new tour plan, initialize with basic data
      // Load all data when screen opens
      _loadInitialData().catchError((e) {
        print('NewTourPlanScreen: Error loading initial data: $e');
      });
    }
    _clearCallErrors();
  }

  /// Check if user is manager or field manager/coordinator
  void _checkUserRole() {
    final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final String? serviceArea = userStore?.userDetail?.serviceArea;
    
    if (serviceArea != null) {
      final String serviceAreaLower = serviceArea.trim().toLowerCase();
      // Check if service area contains "manager" or "field manager" or "coordinator"
      _isManagerOrFieldManager = serviceAreaLower.contains('manager') || 
                                  serviceAreaLower.contains('coordinator');
      
      print('NewTourPlanScreen: [Employee] Service Area: "$serviceArea", Is Manager/Field Manager: $_isManagerOrFieldManager');
      
      if (!_isManagerOrFieldManager) {
        // For non-managers, set current employee as selected
        final int? employeeId = userStore?.userDetail?.employeeId;
        final String? employeeName = userStore?.userDetail?.employeeName;
        final String? employeeCode = userStore?.userDetail?.code;
        
        if (employeeId != null && employeeId > 0 && employeeName != null) {
          final String displayName = employeeCode != null && employeeCode.isNotEmpty
              ? '$employeeCode - $employeeName'
              : employeeName;
          setState(() {
            _selectedEmployee = displayName;
            _selectedEmployeeId = employeeId;
          });
          print('NewTourPlanScreen: [Employee] Set current employee: $_selectedEmployee (ID: $_selectedEmployeeId)');
        }
      } else {
        // For managers, load reporting staff list
        _loadReportingStaffList();
      }
    } else {
      print('NewTourPlanScreen: [Employee] Service Area is null');
    }
  }

  /// Load reporting staff list for managers/field managers using CommandType 276
  Future<void> _loadReportingStaffList() async {
    if (!_isManagerOrFieldManager) return;
    
    setState(() {
      _isLoadingEmployees = true;
    });

    try {
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
      final int? loginEmployeeId = userStore?.userDetail?.employeeId;
      
      if (loginEmployeeId == null || loginEmployeeId <= 0) {
        print('NewTourPlanScreen: [Employee] Login employeeId is null or invalid');
        return;
      }

      if (!getIt.isRegistered<CommonRepository>()) {
        print('NewTourPlanScreen: [Employee] CommonRepository not registered');
        return;
      }

      final repo = getIt<CommonRepository>();
      print('NewTourPlanScreen: [Employee] Loading reporting staff for employeeId: $loginEmployeeId');
      
      final List<CommonDropdownItem> items = await repo.getEmployeesReportingTo(loginEmployeeId);
      
      if (items.isEmpty) {
        print('NewTourPlanScreen: [Employee] No reporting staff found');
        setState(() {
          _employeeOptions = [];
          _employeeNameToId.clear();
        });
        return;
      }

      setState(() {
        _employeeOptions.clear();
        _employeeNameToId.clear();
        
        for (final item in items) {
          // Format: "CODE - NAME" or just "NAME" if no code
          final String employeeName = item.employeeName.isNotEmpty ? item.employeeName : item.text;
          final String employeeCode = item.code ?? '';
          final String displayName = employeeCode.isNotEmpty
              ? '$employeeCode - $employeeName'
              : employeeName;
          
          if (displayName.trim().isNotEmpty) {
            _employeeOptions.add(displayName);
            _employeeNameToId[displayName] = item.id;
          }
        }
        
        print('NewTourPlanScreen: [Employee] Loaded ${_employeeOptions.length} reporting staff');
      });
    } catch (e) {
      print('NewTourPlanScreen: [Employee] Error loading reporting staff: $e');
    } finally {
      setState(() {
        _isLoadingEmployees = false;
      });
    }
  }
  
  /// Load basic data (clusters, customers, type of work, products, customer type) for new tour plans
  Future<void> _loadInitialData() async {
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
    
    setState(() {
      _isLoadingDetails = true;
    });
    
    try {
      print('NewTourPlanScreen: ========== LOADING TOUR PLAN DETAILS ==========');
      print('NewTourPlanScreen: tourPlanToEdit is not null: ${widget.tourPlanToEdit != null}');
      print('NewTourPlanScreen: tourPlanId value: ${widget.tourPlanToEdit!.tourPlanId}');
      print('NewTourPlanScreen: id value: ${widget.tourPlanToEdit!.id}');
      
      // Fetch full tour plan details using TourPlanId and Id
      final repo = getIt<TourPlanRepository>();
      
      // Debug: Print the exact values being sent to API
      // Note: If tourPlanId is 0 or null, use id as tourPlanId
      int effectiveTourPlanId = widget.tourPlanToEdit!.tourPlanId;
      int effectiveId = widget.tourPlanToEdit!.id;
      
      // If tourPlanId is 0 or null, use id as tourPlanId (for list items that might have tourPlanId=0)
      if (effectiveTourPlanId == 0 || effectiveTourPlanId == null) {
        effectiveTourPlanId = effectiveId;
        print('NewTourPlanScreen: tourPlanId was 0/null, using id as tourPlanId: $effectiveTourPlanId');
      }
      
      print('NewTourPlanScreen: Calling API with tourPlanId=$effectiveTourPlanId, id=$effectiveId');
      
      TourPlanGetResponse response;
      try {
        response = await repo.getTourPlanDetails(
          tourPlanId: effectiveTourPlanId,
          id: effectiveId,
        );
      } catch (e) {
        print('NewTourPlanScreen: API call failed with error: $e');
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
        fullTourPlan = response.items.first;
        print('NewTourPlanScreen: Using full tour plan data from API');
        print('  - Customer: ${fullTourPlan.customerName}');
        print('  - Products: ${fullTourPlan.productsToDiscuss}');
        print('  - Samples: ${fullTourPlan.samplesToDistribute}');
        print('  - Notes: ${fullTourPlan.notes}');
        print('  - TourPlanDetails count: ${fullTourPlan.tourPlanDetails?.length ?? 0}');
      } else {
        fullTourPlan = widget.tourPlanToEdit; // Fallback to provided data
        print('NewTourPlanScreen: API returned empty, using fallback data');
      }
      
      // Store the full tour plan data
      _fullTourPlanData = fullTourPlan;
      
      // Now populate the form with full data
      if (fullTourPlan != null) {
        print('NewTourPlanScreen: Populating form with tour plan data...');
        await _populateFormFromTourPlan(fullTourPlan);
        print('NewTourPlanScreen: Form populated successfully');
        // Ensure customers are loaded so we can resolve names
        _loadMappedCustomers();
      }
    } catch (e) {
      print('Error loading tour plan details: $e');
      // Fallback to using the provided data
      if (widget.tourPlanToEdit != null) {
        await _populateFormFromTourPlan(widget.tourPlanToEdit!);
      }
    } finally {
      setState(() {
        _isLoadingDetails = false;
      });
    }
  }
  
  /// Populate form fields from TourPlanItem data
  Future<void> _populateFormFromTourPlan(TourPlanItem tourPlan) async {
    // Load all data in parallel for faster loading
    await Future.wait([
      _ensureClustersLoaded(),
      _loadTypeOfWorkList(),
      _loadProductsList(),
      _loadCustomerTypeList(),
    ]);
    
    // Set tour plan date - use first detail's planDate if available
    if (tourPlan.tourPlanDetails != null && tourPlan.tourPlanDetails!.isNotEmpty) {
      final detail = tourPlan.tourPlanDetails!.first;
      if (detail.planDate != null) {
        _tourPlanDate = detail.planDate;
        _dateCtrl.text = _formatDate(_tourPlanDate);
        print('NewTourPlanScreen: Set date from detail: ${detail.planDate}');
      }
    } else if (tourPlan.planDate != null && tourPlan.planDate != DateTime(0)) {
      _tourPlanDate = tourPlan.planDate;
      _dateCtrl.text = _formatDate(_tourPlanDate);
      print('NewTourPlanScreen: Set date from tourPlan.planDate: ${tourPlan.planDate}');
    }
    
    // Set clusters - use comma-split so dropdown can pre-check individual items
    Set<String> _parseClusters(String s) {
      return s
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    }
    
    // First, ensure clusters are loaded so we can use clusterId from tourPlanDetails
    await _ensureClustersLoaded(force: true);
    
    // Extract cluster information from tourPlanDetails
    int? clusterIdFromDetail;
    if (tourPlan.tourPlanDetails != null && tourPlan.tourPlanDetails!.isNotEmpty) {
      final detail = tourPlan.tourPlanDetails!.first;
      // Get clusterId from detail if available
      if (detail.clusterId != null && detail.clusterId! > 0) {
        clusterIdFromDetail = detail.clusterId;
        print('NewTourPlanScreen: Found clusterId from detail: $clusterIdFromDetail');
      }
      
      // Set cluster names from detail
      if (detail.clusterNames != null && detail.clusterNames!.isNotEmpty) {
        _selectedClusters = _parseClusters(detail.clusterNames!);
        print('NewTourPlanScreen: Set clusters from detail: ${_selectedClusters.toList()}');
        
        // If we have clusterId from detail, use it to directly map the cluster name(s)
        if (clusterIdFromDetail != null && _selectedClusters.isNotEmpty) {
          // Map the first cluster name to the clusterId from detail
          final firstClusterName = _selectedClusters.first;
          final clusterId = clusterIdFromDetail!; // Non-null assertion since we checked above
          if (!_clusterNameToId.containsKey(firstClusterName) || _clusterNameToId[firstClusterName] == null) {
            print('NewTourPlanScreen: Mapping cluster name "$firstClusterName" to clusterId $clusterId from detail');
            setState(() {
              _clusterNameToId[firstClusterName] = clusterId;
              // Also add to clusters list if not present
              if (!_clusters.contains(firstClusterName)) {
                _clusters.add(firstClusterName);
              }
            });
          } else {
            // Update existing mapping to use the ID from detail (more reliable)
            print('NewTourPlanScreen: Updating cluster mapping "$firstClusterName" to clusterId $clusterId from detail');
            setState(() {
              _clusterNameToId[firstClusterName] = clusterId;
            });
          }
        }
      }
    }
    // Fallback to header-level clusters if detail didn't provide
    if (_selectedClusters.isEmpty && tourPlan.clusters != null && tourPlan.clusters!.isNotEmpty) {
      _selectedClusters = _parseClusters(tourPlan.clusters!);
      print('NewTourPlanScreen: Set clusters from header: ${_selectedClusters.toList()}');
    }
    
    // Verify that all selected cluster names have corresponding IDs
    final missingClusterIds = _selectedClusters.where((clusterName) {
      final clusterId = _clusterNameToId[clusterName];
      if (clusterId == null || clusterId <= 0) {
        print('NewTourPlanScreen: Warning - Cluster "$clusterName" does not have a valid ID in map');
        print('NewTourPlanScreen: Available cluster names in map: ${_clusterNameToId.keys.toList()}');
        return true;
      }
      return false;
    }).toList();
    
    if (missingClusterIds.isNotEmpty) {
      print('NewTourPlanScreen: Some clusters are missing IDs: $missingClusterIds');
      print('NewTourPlanScreen: Attempting to match cluster names (case-insensitive)...');
      // Try case-insensitive matching
      for (final missingCluster in missingClusterIds) {
        final matchedKey = _clusterNameToId.keys.firstWhere(
          (key) => key.toLowerCase().trim() == missingCluster.toLowerCase().trim(),
          orElse: () => '',
        );
        if (matchedKey.isNotEmpty) {
          print('NewTourPlanScreen: Found case-insensitive match: "$missingCluster" -> "$matchedKey"');
          _selectedClusters.remove(missingCluster);
          _selectedClusters.add(matchedKey);
        }
      }
    }
    
    // Load customers based on selected clusters (for edit mode)
    if (_selectedClusters.isNotEmpty) {
      print('NewTourPlanScreen: Loading customers for selected clusters during edit');
      print('NewTourPlanScreen: Selected clusters: ${_selectedClusters.toList()}');
      final clusterIds = _selectedClusters.map((c) => _clusterNameToId[c]).where((id) => id != null && id! > 0).toList();
      print('NewTourPlanScreen: Cluster IDs: $clusterIds');
      if (clusterIds.isNotEmpty) {
        await _loadMappedCustomers();
      } else {
        print('NewTourPlanScreen: Warning - No valid cluster IDs found, cannot load customers');
      }
    }
    
    // Load tour plan details into calls
    if (tourPlan.tourPlanDetails != null && tourPlan.tourPlanDetails!.isNotEmpty) {
      _calls.clear();
      print('NewTourPlanScreen: Populating calls from tourPlanDetails');
      
      for (final detail in tourPlan.tourPlanDetails!) {
        print('  - detail.customerId: ${detail.customerId}');
        print('  - detail.productsToDiscuss: ${detail.productsToDiscuss}');
        print('  - detail.samplesToDistribute: ${detail.samplesToDistribute}');
        print('  - detail.remarks: ${detail.remarks}');
        print('  - detail.typeOfWorkId: ${detail.typeOfWorkId}');
        
        // Best-effort customer name from location text (e.g., "CLUSTER - CUSTOMER")
        String? fallbackCustomerName;
        if (detail.location != null && detail.location!.contains('-')) {
          final parts = detail.location!.split('-');
          if (parts.length >= 2) {
            fallbackCustomerName = parts.sublist(1).join('-').trim();
            if (fallbackCustomerName.isEmpty) fallbackCustomerName = null;
          }
        }
        
        // Resolve customer name from ID if available, otherwise use fallback or placeholder
        Set<String> resolvedCustomers = <String>{};
        if (detail.customerId > 0) {
          final customerName = _customerIdToName[detail.customerId];
          if (customerName != null && customerName.isNotEmpty && _customerOptions.contains(customerName)) {
            resolvedCustomers = {customerName};
            print('NewTourPlanScreen: Resolved customer ID ${detail.customerId} to name: $customerName');
          } else if (fallbackCustomerName != null && _customerOptions.contains(fallbackCustomerName)) {
            resolvedCustomers = {fallbackCustomerName};
            print('NewTourPlanScreen: Using fallback customer name: $fallbackCustomerName');
          } else if (fallbackCustomerName != null) {
            resolvedCustomers = {fallbackCustomerName};
            print('NewTourPlanScreen: Using fallback customer name (may not be in dropdown): $fallbackCustomerName');
          } else {
            resolvedCustomers = {'Customer ID: ${detail.customerId}'};
            print('NewTourPlanScreen: Using placeholder for customer ID: ${detail.customerId}');
          }
        } else if (fallbackCustomerName != null) {
          resolvedCustomers = {fallbackCustomerName};
          print('NewTourPlanScreen: Using fallback customer name (no customerId): $fallbackCustomerName');
        }
        
        // Parse products from comma-separated string
        Set<String> parsedProducts = <String>{};
        if (detail.productsToDiscuss != null && detail.productsToDiscuss!.isNotEmpty) {
          parsedProducts = detail.productsToDiscuss!
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet();
        }
        
        final callData = _CallData(
          products: parsedProducts,
          samplesCtrl: TextEditingController(
              text: detail.samplesToDistribute ?? ''),
          remarksCtrl: TextEditingController(text: detail.remarks ?? ''),
          customers: resolvedCustomers,
          // Set purpose immediately if mapping is already available; else mark Loading...
          purpose: _typeOfWorkIdToName[detail.typeOfWorkId] ?? (detail.typeOfWorkId > 0 ? 'Loading...' : null),
        );

        _calls.add(callData);
      }
    } else {
      // If no tourPlanDetails but we have customer name, create one call with that customer
      _calls.clear();
      
      // Parse products from comma-separated string
      Set<String> parsedProducts = <String>{};
      if (tourPlan.productsToDiscuss != null && tourPlan.productsToDiscuss!.isNotEmpty) {
        parsedProducts = tourPlan.productsToDiscuss!
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet();
      }
      
      final callData = _CallData(
        products: parsedProducts,
        samplesCtrl: TextEditingController(
            text: tourPlan.samplesToDistribute ?? ''),
        remarksCtrl: TextEditingController(text: tourPlan.notes ?? ''),
        customers: tourPlan.customerName != null && 
                   tourPlan.customerName!.isNotEmpty
                   ? {tourPlan.customerName!}
                   : <String>{},
        purpose: null,
      );
      
      _calls.add(callData);
    }
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.tourPlanToEdit != null ? 'Edit Tour Plan' : 'New Tour Plan',
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
                        constraints: BoxConstraints(maxWidth: isTablet ? 900 : double.infinity),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Employee dropdown (for managers/field managers) or read-only display (for others)
                            _Labeled(
                              label: 'Employee',
                              required: _isManagerOrFieldManager,
                              errorText: _employeeError,
                              child: _isManagerOrFieldManager
                                  ? _isLoadingEmployees
                                      ? AppTextField(
                                          hint: 'Loading employees...',
                                          readOnly: true,
                                          controller: TextEditingController(),
                                        )
                                      : _SingleSelectDropdown(
                                          options: _employeeOptions,
                                          value: _selectedEmployee,
                                          hintText: 'Select Employee',
                                          onChanged: (v) {
                                        setState(() {
                                          _selectedEmployee = v;
                                          _selectedEmployeeId = v != null ? _employeeNameToId[v] : null;
                                          _employeeError = null;
                                          // Clear clusters and customers when employee changes
                                          _selectedClusters.clear();
                                          _customerOptions.clear();
                                          _customerNameToId.clear();
                                          _customerIdToName.clear();
                                          _customerNameToClusterName.clear();
                                          _autoSelectedClusters.clear();
                                          for (final call in _calls) {
                                            call.customers = {};
                                          }
                                          _updateAutoSelectedClusters();
                                        });
                                        // Reload clusters and customers for selected employee
                                        if (_selectedEmployeeId != null) {
                                          _loadClusterList(force: true);
                                        }
                                      },
                                    )
                                  : AppTextField(
                                      hint: 'Employee',
                                      readOnly: true,
                                      controller: TextEditingController(text: _selectedEmployee ?? ''),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            _Labeled(
                              label: 'Tour Plan Date',
                              required: true,
                              errorText: _dateError,
                              child: AppTextField(
                                hint: 'Select Date',
                                readOnly: true,
                                suffixIcon: const Icon(Icons.calendar_today_outlined),
                                onTap: _pickDate,
                                controller: _dateCtrl,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Labeled(
                              label: 'Cluster/city',
                              required: true,
                              errorText: _clusterError,
                              child: _MultiSelectDropdown(
                                options: _clusters,
                                selectedValues: _selectedClusters,
                                hintText: _isLoadingClusters ? 'Loading clusters...' : 'Select cluster/city',
                                isLoading: _isLoadingClusters,
                                emptyMessage: _isLoadingClusters ? 'Loading clusters...' : 'No clusters found',
                                onBeforeOpen: () => _ensureClustersLoaded(),
                                onChanged: (v) {
                                  setState(() {
                                    _selectedClusters = v;
                                    _clusterError = null;
                                    _updateAutoSelectedClusters();
                                  });
                                  // Refresh customers filtered by selected clusters
                                  // This will also update cluster mapping from API response
                                  _loadMappedCustomers().catchError((e) {
                                    print('NewTourPlanScreen: Error loading customers: $e');
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Labeled(
                              label: 'Customer Type',
                              required: true,
                              errorText: _customerTypeError,
                              child: _SingleSelectDropdown(
                                options: _customerTypeOptions,
                                value: _selectedCustomerType,
                                hintText: 'Select customer type',
                                onChanged: (v) {
                                  setState(() {
                                    _selectedCustomerType = v;
                                    _customerTypeError = null;
                                  });
                                  // Reload customers when customer type changes
                                  if (_selectedClusters.isNotEmpty) {
                                    _loadMappedCustomers();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            for (int i = 0; i < _calls.length; i++) ...[
                              _CallCard(
                                index: i,
                                dateLabel: _formatDate(_tourPlanDate),
                                data: _calls[i],
                                customerOptions: _customerOptions,
                                purposeOptions: _purposeOptions,
                                productOptions: _productOptions,
                                customerError: i < _callErrors.length ? _callErrors[i].customerError : null,
                                purposeError: i < _callErrors.length ? _callErrors[i].purposeError : null,
                                onCustomersChanged: (customers) => setState(() {
                                  _calls[i].customers = customers;
                                  if (_callErrors.length > i) {
                                    final List<_CallValidationState> updated = _cloneCallErrors();
                                    updated[i].customerError = null;
                                    _callErrors = updated;
                                  }
                                  _updateAutoSelectedClusters();
                                }),
                                onPurposeChanged: (purpose) => setState(() {
                                  _calls[i].purpose = purpose;
                                  if (_callErrors.length > i) {
                                    final List<_CallValidationState> updated = _cloneCallErrors();
                                    updated[i].purposeError = null;
                                    _callErrors = updated;
                                  }
                                }),
                                onProductsChanged: (products) => setState(() {
                                  _calls[i].products = products;
                                }),
                                onToggleExpand: () => setState(() {
                                  final bool current = _calls[i].isExpanded ?? true;
                                  _calls[i].isExpanded = !current;
                                }),
                                // Hide Remove button when updating/editing a tour plan
                                onRemove: widget.tourPlanToEdit == null ? () {
                                  if (_calls.length == 1) {
                                    _showSnack('⚠ At least one call is required.');
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
                                } : null,
                              ),
                              const SizedBox(height: 16),
                            ],
                            Row(
                              children: [
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
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _isSubmitting ? null : () async {
                                      if (!_validateForm()) {
                                        return;
                                      }
                                      _handleSubmit();
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF4db1b3),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 2,
                                      disabledBackgroundColor: const Color(0xFF4db1b3).withOpacity(0.6),
                                    ),
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            widget.tourPlanToEdit != null ? 'Update' : 'Submit',
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
      print('NewTourPlanScreen: ========== ${isEditing
          ? 'UPDATING'
          : 'SUBMITTING'} TOUR PLAN ==========');
      
      final store = getIt<TourPlanStore>();
      final userStore = getIt<UserDetailStore>();
      final DateTime selectedPlanDate = _tourPlanDate;
      final String planDateStr = selectedPlanDate.toIso8601String().split('T').first;

      // Resolve selected cluster ID (first selected if multiple)
      final int resolvedClusterId = _selectedClusters.isEmpty
          ? 0
          : (_clusterNameToId[_selectedClusters.first] ?? 0);

      // Build details: one entry per call with array formats
      final List<Map<String, dynamic>> details = <Map<String, dynamic>>[];
      // Array of selected cluster IDs
      final List<int> clusterIdsArray = _selectedClusters
          .map((name) => _clusterNameToId[name] ?? 0)
          .where((id) => id > 0)
          .toList();

      for (int i = 0; i < _calls.length; i++) {
        final _CallData call = _calls[i];
        final int typeOfWorkId = call.purpose == null
            ? 0
            : (_typeOfWorkNameToId[call.purpose!] ?? 0);

        final List<int> customerIdsArray = call.customers
            .map((name) => _customerNameToId[name] ?? 0)
            .where((id) => id > 0)
            .toList();

        final List<String> purposesArray = call.purpose != null ? [call.purpose!] : [];

        // Build customers array with CustomerId and ClusterId pairs
        final List<Map<String, dynamic>> customersArray = <Map<String, dynamic>>[];
        for (int j = 0; j < call.customers.length; j++) {
          final customerName = call.customers.elementAt(j);
          final customerId = _customerNameToId[customerName] ?? 0;
          final clusterId = clusterIdsArray.isNotEmpty ? clusterIdsArray[j % clusterIdsArray.length] : resolvedClusterId;
          
          customersArray.add({
            'CustomerId': customerId,
            'ClusterId': clusterId,
          });
        }

        // Build ProductsToBeDiscussed array with ProductId and ProductName
        final List<Map<String, dynamic>> productsToBeDiscussedArray = <Map<String, dynamic>>[];
        for (final productName in call.products) {
          final productId = _productNameToId[productName] ?? 0;
          if (productId > 0) {
            productsToBeDiscussedArray.add({
              'ProductId': productId,
              'ProductName': null,
            });
          }
        }

        // If editing, map existing detail id from fetched item by index
        // Prefer IDs from fully-fetched API data if available
        final int existingDetailId = (_fullTourPlanData?.tourPlanDetails != null
                                    && _fullTourPlanData!.tourPlanDetails!.length > i)
                                ? (_fullTourPlanData!.tourPlanDetails![i].id)
                                : ((widget.tourPlanToEdit?.tourPlanDetails != null
                                        && widget.tourPlanToEdit!.tourPlanDetails!.length > i)
                                    ? widget.tourPlanToEdit!.tourPlanDetails![i].id
                                    : 0);

        // If customerId could not be resolved from UI, fallback to existing detail
        final int fallbackCustomerId = (_fullTourPlanData?.tourPlanDetails != null
                && _fullTourPlanData!.tourPlanDetails!.length > i)
            ? _fullTourPlanData!.tourPlanDetails![i].customerId
            : ((widget.tourPlanToEdit?.tourPlanDetails != null
                    && widget.tourPlanToEdit!.tourPlanDetails!.length > i)
                ? widget.tourPlanToEdit!.tourPlanDetails![i].customerId
                : 0);

        final String clusterNameForDetail = _selectedClusters.isNotEmpty ? _selectedClusters.first : '';
        final String locationFromCustomer = call.customers.isNotEmpty
            ? ' - ${call.customers.first}'
            : ' - ';
        details.add({
          'Id': existingDetailId, // Detail Id must be the "id" from list item
          'PlanDate': '${planDateStr}T06:30:00.000',
          'TypeOfWorkId': typeOfWorkId,
          'ClusterId': clusterIdsArray.isEmpty ? 0 : clusterIdsArray.first,
          'CustomerId': customerIdsArray.isEmpty ? 0 : customerIdsArray.first,
          'Status': 1,
          'Remarks': call.remarksCtrl.text.trim(),
          'Location': locationFromCustomer,
          'Latitude': null,
          'Longitude': null,
          'SamplesToDistribute': call.samplesCtrl.text.trim(),
          'ProductsToDiscuss': '',
          'ClusterNames': null,
          'Customers': customersArray,
          'ProductsToBeDiscussed': productsToBeDiscussedArray,
          'MappedInstruments': [],
        });
      }

                          // Build header TourPlanType as array of all selected purposes
                          final Set<String> purposesAll = <String>{};
                          for (final _CallData call in _calls) {
                            if (call.purpose != null) {
                              purposesAll.add(call.purpose!);
                            }
                          }
                          final List<String> tourPlanTypeArray = purposesAll.isEmpty
                              ? ['General']
                              : purposesAll.toList();

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
                          
                          // For managers/field managers, use selectedEmployeeId; otherwise use current user's employeeId
                          final int employeeId = (_isManagerOrFieldManager && _selectedEmployeeId != null)
                              ? _selectedEmployeeId!
                              : (userStore.userDetail?.employeeId ?? 0);
                          final String employee = (_isManagerOrFieldManager && _selectedEmployee != null)
                              ? _selectedEmployee!
                              : (userStore.userDetail?.employeeName ?? "");

                          print('NewTourPlanScreen: [Submit] Using employeeId: $employeeId (Manager/Field Manager: $_isManagerOrFieldManager)');

                          // For updates: Header Id must be TourPlanId from the list item
                          final bool isNewTourPlan = widget.tourPlanToEdit == null;
                          final String headerClusterName = _selectedClusters.isNotEmpty ? _selectedClusters.first : "";
                          
                          // Get customer type ID
                          final int? customerTypeId = _selectedCustomerType != null && _customerTypeNameToId.containsKey(_selectedCustomerType!)
                              ? _customerTypeNameToId[_selectedCustomerType!]
                              : null;
                          print('NewTourPlanScreen: [DEBUG] _selectedCustomerType: $_selectedCustomerType');
                          print('NewTourPlanScreen: [DEBUG] _customerTypeNameToId: $_customerTypeNameToId');
                          print('NewTourPlanScreen: [DEBUG] customerTypeId: $customerTypeId');
                          
                          final Map<String, dynamic> body = {
                            'Id': isNewTourPlan ? null : (widget.tourPlanToEdit!.tourPlanId != 0 ? widget.tourPlanToEdit!.tourPlanId : widget.tourPlanToEdit!.id),
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
                            'Date': '${planDateStr}T06:30:00.000',
                            'Territory': "",
                            'Cluster': "",
                            'ClusterId': null,
                            'TourPlanType': tourPlanTypeArray.isNotEmpty ? tourPlanTypeArray.first : 'General',
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
                            'EmployeeName': "",
                            'Designation': "",
                            'StatusText': "",
                            'PlanDate': '0001-01-01T00:00:00.000',
                            'CustomerId': 0,
                            'CustomerName': "",
                            'Clusters': "",
                            'SamplesToDistribute': null,
                            'ProductsToDiscuss': null,
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
                            'CustomerType': customerTypeId,
                          };
                          
                          // Print Request Data
                          print('NewTourPlanScreen: ========== REQUEST DATA ==========');
                          print('NewTourPlanScreen: ${isEditing
                              ? 'Update'
                              : 'Create'} Mode');
                          print('NewTourPlanScreen: Tour Plan ID: ${widget
                              .tourPlanToEdit?.id ?? 'New'}');
                          print('NewTourPlanScreen: User ID: $userId');
                          print('NewTourPlanScreen: Employee ID: $employeeId');
                          print('NewTourPlanScreen: SBU ID: $sbuId');
                          print('NewTourPlanScreen: Plan Date: $planDateStr');
                          print('NewTourPlanScreen: Selected Clusters: $_selectedClusters');
                          print('NewTourPlanScreen: Cluster IDs: $clusterIdsArray');
                          print('NewTourPlanScreen: Tour Plan Type: $tourPlanTypeArray');
                          print('NewTourPlanScreen: Selected Customer Type: $_selectedCustomerType');
                          print('NewTourPlanScreen: Customer Type ID: ${_selectedCustomerType != null ? _customerTypeNameToId[_selectedCustomerType!] : null}');
                          print('NewTourPlanScreen: Customer Type Map: $_customerTypeNameToId');
                          print('NewTourPlanScreen: Number of Calls: ${_calls.length}');

                          for (int i = 0; i < _calls.length; i++) {
                            final call = _calls[i];
                            print('NewTourPlanScreen: Call ${i + 1}:');
                            print('  - Customers: ${call.customers}');
                            print('  - Purpose: ${call.purpose}');
                            print('  - Remarks: ${call.remarksCtrl.text.trim()}');
                          }
                          print('NewTourPlanScreen: Full Request Body:');
                          print('  $body');
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
                          print('NewTourPlanScreen: ========== ${isEditing
                              ? 'UPDATE'
                              : 'SUBMIT'} COMPLETED ==========');
                          
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
                              errorMessage = res['errorMessage']?.toString() ?? 
                                           res['error']?.toString() ?? 
                                           res['msg']?.toString() ?? 
                                           'Unknown error occurred';
                            } else {
                              // No error indicators - consider it success
                              isSuccess = true;
                            }
                          }
                          ToastMessage.show(
                            context,
                            message: isSuccess
                                ? 'Success: Tour plan ${isEditing ? 'updated' : 'submitted'} successfully'
                                : 'Failed: ${errorMessage.isNotEmpty ? errorMessage : 'No response received from server.'}',
                            type: isSuccess ? ToastType.success : ToastType.error,
                            duration: Duration(seconds: isSuccess ? 3 : 4),
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
                            } catch (_) {}

                            // Only navigate back for edit mode, stay on screen for create mode
                            if (isEditing) {
                              Navigator.of(context).pop(true);
                            }
                            // For create mode, stay on screen so user can create another tour plan
                          }
                        } catch (e, stackTrace) {
                          final bool isEditing = widget.tourPlanToEdit != null;
                          print('NewTourPlanScreen: ========== ERROR OCCURRED ==========');
                          print('NewTourPlanScreen: ERROR ${isEditing
                              ? 'UPDATING'
                              : 'SUBMITTING'} TOUR PLAN: $e');
                          print('NewTourPlanScreen: Stack Trace: $stackTrace');
                          print('NewTourPlanScreen: ========== ERROR END ==========');
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '✗ ${isEditing
                                    ? 'Update'
                                    : 'Submission'} Failed!\nError: $e',
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 13,
                                ),
                              ),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
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
    // Get today's date at midnight for comparison
    final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    // For editing, allow the existing date even if it's in the past
    // But for new tour plans, only allow today or future dates
    final bool isEditing = widget.tourPlanToEdit != null;
    final DateTime firstDate = isEditing && _tourPlanDate.isBefore(today) 
        ? _tourPlanDate 
        : today;
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _tourPlanDate.isBefore(today) && isEditing ? _tourPlanDate : (_tourPlanDate.isBefore(today) ? today : _tourPlanDate),
      firstDate: firstDate, // Allow existing past date when editing, otherwise only today or future dates
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
      final DateTime selectedDate = DateTime(picked.year, picked.month, picked.day);
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
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day.toString().padLeft(2, '0')}-${months[d.month - 1]}-${d.year}';
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
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
    final List<_CallValidationState> updated = List<_CallValidationState>.generate(
      _calls.length,
      (index) => index < _callErrors.length ? _callErrors[index] : _CallValidationState(),
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

    if (derivedClusters.isNotEmpty) {
      final Set<String> combined = {..._clusters, ...derivedClusters};
      if (combined.length != _clusters.length) {
        _clusters = combined.toList();
      }
    }

    final Set<String> manualClusters = _selectedClusters.difference(_autoSelectedClusters);
    final Set<String> updatedSelected = {...manualClusters, ...derivedClusters};

    final bool selectionChanged = !setEquals(_selectedClusters, updatedSelected);
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
    final List<_CallValidationState> callErrors = List<_CallValidationState>.generate(
      _calls.length,
      (_) => _CallValidationState(),
    );

    // Validate employee selection for managers/field managers
    if (_isManagerOrFieldManager) {
      if (_selectedEmployee == null || _selectedEmployee!.isEmpty || _selectedEmployeeId == null) {
        employeeError = 'Please select an employee';
        firstMessage ??= 'Select an employee';
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
        final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final DateTime selectedDate = DateTime(_tourPlanDate.year, _tourPlanDate.month, _tourPlanDate.day);
        
        if (selectedDate.isBefore(today)) {
          dateError = 'Cannot select a past date. Please select today or a future date.';
          firstMessage ??= 'Cannot select a past date. Please select today or a future date.';
          isValid = false;
        }
      }
    }

    if (_selectedClusters.isEmpty) {
      clusterError = 'Please select at least one cluster/city';
      firstMessage ??= 'Select at least one cluster/city';
      isValid = false;
    }

    String? customerTypeError;
    if (_selectedCustomerType == null || _selectedCustomerType!.isEmpty) {
      customerTypeError = 'Please select a customer type';
      firstMessage ??= 'Select a customer type';
      isValid = false;
    }

    if (_calls.isEmpty) {
      firstMessage ??= 'Add at least one call';
      isValid = false;
    } else {
      for (int i = 0; i < _calls.length; i++) {
        final call = _calls[i];
        final String callLabel = 'Call ${i + 1}';

        if (call.customers.isEmpty) {
          callErrors[i].customerError = 'Please select at least one customer';
          firstMessage ??= 'Select customer for $callLabel';
          isValid = false;
        }

        final String purpose = (call.purpose ?? '').trim();
        if (purpose.isEmpty || purpose.toLowerCase() == 'loading...') {
          callErrors[i].purposeError = 'Please select purpose of visit';
          firstMessage ??= 'Select purpose for $callLabel';
          isValid = false;
        }
      }
    }

    setState(() {
      _dateError = dateError;
      _clusterError = clusterError;
      _employeeError = employeeError;
      _customerTypeError = customerTypeError;
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
        final List<CommonDropdownItem> items = await repo.getTourPlanEmployeeList();
        final names = items.map((e) => (e.employeeName.isNotEmpty ? e.employeeName : e.text).trim()).where((s) => s.isNotEmpty).toSet();
        if (names.isNotEmpty) {
          setState(() {
            _customerOptions = {..._customerOptions, ...names}.toList();
            // map names to ids for potential CustomerId mapping when employee list represents customers
            for (final item in items) {
              final String key = (item.employeeName.isNotEmpty ? item.employeeName : item.text).trim();
              if (key.isNotEmpty) _customerNameToId[key] = item.id;
            }
          });
        }
      }
    } catch (e) {
    }
  }

  bool _requestedInitialClusters = false;
  bool _isLoadingClusters = false;

  Future<void> _loadClusterList({bool force = false}) async {
    if (_isLoadingClusters) return;
    if (_clusters.isNotEmpty && !force) return;

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
        print('NewTourPlanScreen: [Clusters] Using selected employeeId: $employeeIdNullable (Manager/Field Manager)');
      } else {
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
        employeeIdNullable = userStore?.userDetail?.employeeId;
        int retry = 0;
        while (employeeIdNullable == null && retry < 5) {
          await Future.delayed(const Duration(milliseconds: 200));
          employeeIdNullable = userStore?.userDetail?.employeeId;
          retry++;
        }
        if (employeeIdNullable == null) {
          print('NewTourPlanScreen: [Clusters] employeeId still null after retries');
          return;
        }
        print('NewTourPlanScreen: [Clusters] Using current user employeeId: $employeeIdNullable');
      }

      // At this point, employeeIdNullable is guaranteed to be non-null
      final int employeeId = employeeIdNullable!;
      final List<CommonDropdownItem> items = await repo.getClusterList(countryId, employeeId);
      final Set<String> clusters = items
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
            for (final item in items) {
              final String key = (item.text.isNotEmpty ? item.text : item.cityName).trim();
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
          for (final item in items) {
            final String key = (item.text.isNotEmpty ? item.text : item.cityName).trim();
            if (key.isNotEmpty) {
              _clusterNameToId[key] = item.id;
            }
          }
        }
      }
    } catch (e) {
      print('NewTourPlanScreen: [Clusters] Error loading clusters: $e');
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
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
        
        // Wait for user to be loaded (retry up to 20 times = 6 seconds max)
        int retry = 0;
        while (userStore?.isUserLoaded != true && retry < 20) {
          await Future.delayed(const Duration(milliseconds: 300));
          retry++;
          print('NewTourPlanScreen: [PurposeOfVisit] Waiting for user to load... retry $retry');
        }
        
        int? userId = userStore?.userDetail?.id;
        String? serviceArea = userStore?.userDetail?.serviceArea;
        
        print('NewTourPlanScreen: [PurposeOfVisit] userId: $userId, serviceArea: "$serviceArea"');
        
        if (userId == null || userId <= 0) {
          print('NewTourPlanScreen: [PurposeOfVisit] userId invalid, skipping');
          return;
        }
        
        // Determine the text parameter based on serviceArea
        // Only "Service Engineer" gets "ServiceEng PurposeVisit"
        // All others (including null/empty serviceArea) get "Salesrep PurposeVisit"
        String purposeText;
        final String serviceAreaTrimmed = (serviceArea ?? '').trim();
        
        if (serviceAreaTrimmed == 'Service Engineer') {
          purposeText = 'ServiceEng PurposeVisit';
        } else {
          // All other users (Sales, Manager, Field Coordinator, empty, null, etc.)
          purposeText = 'Salesrep PurposeVisit';
        }
        
        print('NewTourPlanScreen: [PurposeOfVisit] serviceArea: "$serviceAreaTrimmed", using text: "$purposeText"');
        final List<CommonDropdownItem> items = await repo.getPurposeOfVisitList(userId, purposeText);
        print('NewTourPlanScreen: [PurposeOfVisit] API returned ${items.length} items');
        
        final works = items
            .map((e) => (e.text.isNotEmpty ? e.text : e.typeText).trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        if (works.isNotEmpty) {
          setState(() {
            _purposeOptions = works.toList();
            _typeOfWorkNameToId.clear();
            _typeOfWorkIdToName.clear();
            // map names to ids for submit
            for (final item in items) {
              final String key = (item.text.isNotEmpty ? item.text : item.typeText).trim();
              if (key.isNotEmpty) {
                _typeOfWorkNameToId[key] = item.id;
                _typeOfWorkIdToName[item.id] = key; // Reverse mapping for editing
              }
            }
            
            // Resolve purpose names for existing calls if editing
            if (_fullTourPlanData != null || widget.tourPlanToEdit != null) {
              print('NewTourPlanScreen: Resolving purpose names from typeOfWorkId');
              print('  - Number of calls: ${_calls.length}');
              print('  - typeOfWorkIdToName map: $_typeOfWorkIdToName');
              
              for (final call in _calls) {
                if (call.purpose == 'Loading...') {
                  print('  - Found call with Loading... purpose');
                  // Find the corresponding typeOfWorkId from tourPlanDetails
                  // Use full tour plan data if available, otherwise fallback to widget data
                  final tourPlan = _fullTourPlanData ?? widget.tourPlanToEdit;
                  if (tourPlan != null && tourPlan.tourPlanDetails != null) {
                    print('  - tourPlanDetails count: ${tourPlan.tourPlanDetails!.length}');
                    for (final detail in tourPlan.tourPlanDetails!) {
                      print('    - Checking detail with typeOfWorkId: ${detail.typeOfWorkId}');
                      if (detail.typeOfWorkId > 0) {
                        final purposeName = _typeOfWorkIdToName[detail.typeOfWorkId];
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
          
          print('NewTourPlanScreen: [PurposeOfVisit] Loaded ${_purposeOptions.length} options');
        }
      }
    } catch (e) {
      print('NewTourPlanScreen: [PurposeOfVisit] Error: $e');
    }
  }

  Future<void> _loadProductsList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
        
        // Wait for user to be loaded (retry up to 20 times = 6 seconds max)
        int retry = 0;
        while (userStore?.isUserLoaded != true && retry < 20) {
          await Future.delayed(const Duration(milliseconds: 300));
          retry++;
        }
        
        int? userId = userStore?.userDetail?.id;
        int? employeeId = userStore?.userDetail?.employeeId;
        String? serviceArea = userStore?.userDetail?.serviceArea;
        
        if (userId == null || userId <= 0) {
          print('NewTourPlanScreen: [Products] userId is still null/0, skipping products load');
          return;
        }
        
        // For Service Engineers: use employeeId as userId and set IsFromAMCUser = 0
        // For others: use userId and set IsFromAMCUser = null
        int? actualUserId = userId;
        int? isFromAMCUser;
        
        if (serviceArea != null && serviceArea.trim() == 'Service Engineer') {
          if (employeeId != null && employeeId > 0) {
            actualUserId = employeeId;
            isFromAMCUser = 0;
            print('NewTourPlanScreen: [Products] Service Engineer detected - using employeeId: $actualUserId, IsFromAMCUser: $isFromAMCUser');
          } else {
            print('NewTourPlanScreen: [Products] Service Engineer but employeeId is null/0, using userId: $actualUserId');
          }
        } else {
          isFromAMCUser = null;
          print('NewTourPlanScreen: [Products] Non-Service Engineer - using userId: $actualUserId, IsFromAMCUser: null');
        }
        
        print('NewTourPlanScreen: [Products] Loading products with userId: $actualUserId, isFromAMCUser: $isFromAMCUser');
        final List<CommonDropdownItem> items = await repo.getTourPlanProductsList(actualUserId, isFromAMCUser: isFromAMCUser);
        if (items.isNotEmpty) {
          setState(() {
            _productOptions.clear();
            _productNameToId.clear();
            for (final item in items) {
              final String productName = (item.text.isNotEmpty ? item.text : item.name).trim();
              if (productName.isNotEmpty) {
                _productOptions.add(productName);
                _productNameToId[productName] = item.id;
              }
            }
          });
          print('NewTourPlanScreen: [Products] Loaded ${_productOptions.length} products');
        }
      }
    } catch (e) {
      print('NewTourPlanScreen: [Products] Error loading products: $e');
    }
  }

  Future<void> _loadCustomerTypeList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
        
        // Wait for user to be loaded (retry up to 20 times = 6 seconds max)
        int retry = 0;
        while (userStore?.isUserLoaded != true && retry < 20) {
          await Future.delayed(const Duration(milliseconds: 300));
          retry++;
        }
        
        int? userId = userStore?.userDetail?.id;
        String? serviceArea = userStore?.userDetail?.serviceArea;
        if (userId == null || userId <= 0) {
          print('NewTourPlanScreen: [CustomerType] userId is still null/0, skipping');
          return;
        }
        
        // Use serviceArea directly as the Type parameter (pass empty string if null)
        final String typeParam = serviceArea ?? '';
        print('NewTourPlanScreen: [CustomerType] Loading customer types with userId: $userId, type: "$typeParam"');
        final List<CommonDropdownItem> items = await repo.getCustomerTypeList(userId, type: typeParam);
        print('NewTourPlanScreen: [CustomerType] API returned ${items.length} items');
        if (items.isNotEmpty) {
          setState(() {
            _customerTypeOptions.clear();
            _customerTypeNameToId.clear();
            for (final item in items) {
              final String typeName = (item.text.isNotEmpty ? item.text : item.name).trim();
              if (typeName.isNotEmpty) {
                _customerTypeOptions.add(typeName);
                _customerTypeNameToId[typeName] = item.id;
                print('NewTourPlanScreen: [CustomerType] Added: "$typeName" -> ${item.id}');
              }
            }
          });
          print('NewTourPlanScreen: [CustomerType] Loaded ${_customerTypeOptions.length} customer types');
          print('NewTourPlanScreen: [CustomerType] Map: $_customerTypeNameToId');
        }
      }
    } catch (e) {
      print('NewTourPlanScreen: [CustomerType] Error loading customer types: $e');
    }
  }

  Future<void> _loadMappedCustomers() async {
    try {
      print('NewTourPlanScreen: [Customers] Start loading mapped customers');
      if (!getIt.isRegistered<TourPlanRepository>()) {
        print('NewTourPlanScreen: [Customers] TourPlanRepository not registered - skipping');
        return;
      }
      final repo = getIt<TourPlanRepository>();
      
      // For managers/field managers, use selectedEmployeeId; otherwise use current user's employeeId
      int? employeeId;
      int? selectedEmployeeIdForRequest;
      
      if (_isManagerOrFieldManager && _selectedEmployeeId != null) {
        // Manager/Field Manager: use selected employee
        employeeId = _selectedEmployeeId;
        selectedEmployeeIdForRequest = _selectedEmployeeId;
        print('NewTourPlanScreen: [Customers] Using selected employeeId: $employeeId (Manager/Field Manager)');
      } else {
        // Regular user: use current user's employeeId
        final userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
        employeeId = userStore?.userDetail?.employeeId;
        selectedEmployeeIdForRequest = null;
        if (employeeId == null) {
          print('NewTourPlanScreen: [Customers] employeeId is null - skipping');
          return;
        }
        print('NewTourPlanScreen: [Customers] Using current user employeeId: $employeeId');
      }

      // Build ClusterIds from selected clusters in dropdown
      final List<ClusterIdModel> selectedClusterIds = _selectedClusters
          .map((clusterName) => _clusterNameToId[clusterName])
          .where((clusterId) => clusterId != null && clusterId > 0)
          .map((clusterId) => ClusterIdModel(clusterId: clusterId!))
          .toList();

      print('NewTourPlanScreen: [Customers] Selected clusters: $_selectedClusters');
      print('NewTourPlanScreen: [Customers] Cluster IDs: ${selectedClusterIds.map((c) => c.clusterId).toList()}');

      // Get selected customer type ID
      final int? customerTypeId = _selectedCustomerType != null && _customerTypeNameToId.containsKey(_selectedCustomerType!)
          ? _customerTypeNameToId[_selectedCustomerType!]
          : null;

      // If no clusters are selected OR no customer type is selected, clear all customers
      if (selectedClusterIds.isEmpty || customerTypeId == null) {
        print('NewTourPlanScreen: [Customers] Cluster or CustomerType not selected - clearing customers');
        print('NewTourPlanScreen: [Customers] Clusters empty: ${selectedClusterIds.isEmpty}, CustomerTypeId: $customerTypeId');
        setState(() {
          _customerOptions = [];
          _customerNameToId.clear();
          _customerIdToName.clear();
          _customerNameToClusterName.clear();
          _autoSelectedClusters.clear();
          // Clear all customer selections when requirements not met
          for (final call in _calls) {
            call.customers = {};
          }
          _updateAutoSelectedClusters();
        });
        return;
      }

      // Dynamic Id: use tour plan Id if editing; otherwise fall back to employeeId
      final int? dynamicId = widget.tourPlanToEdit?.id ?? employeeId;

      // Use current plan date (yyyy-MM-dd)
      final String dateStr = _tourPlanDate.toIso8601String().split('T').first;
      
      final req = GetMappedCustomersByEmployeeIdRequest(
        searchText: null,
        pageNumber: 0,
        pageSize: 0,
        sortOrder: 0,
        sortDir: 0,
        sortField: null,
        employeeId: null,
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
        customerTypeId: customerTypeId,
      );
      print('NewTourPlanScreen: [Customers] Request body => ${req.toJson()}');
      final res = await repo.getMappedCustomersByEmployeeId(req);
      print('NewTourPlanScreen: [Customers] API returned ${res.customers.length} customers');
      if (res.customers.isNotEmpty) {
        final sample = res.customers.take(5).map((c) => {
          'CustomerId': c.customerId,
          'CustomerName': c.customerName,
          'ClusterId': c.clusterId,
          'ClusterName': c.clusterName,
        }).toList();
        print('NewTourPlanScreen: [Customers] Sample => $sample');
      }
      
      // If API returns 0 customers, clear the list
      if (res.customers.isEmpty) {
        print('NewTourPlanScreen: [Customers] No customers returned - clearing list');
        setState(() {
          _customerOptions.clear();
          _customerNameToId.clear();
          _customerIdToName.clear();
          _customerNameToClusterName.clear();
          for (final call in _calls) {
            call.customers = {};
          }
        });
        return;
      }

      setState(() {
        // Clear any old data so only new API values appear
        _customerOptions.clear();
        _customerNameToId.clear();
        _customerIdToName.clear();
        _customerNameToClusterName.clear();
        
        // Store customers and update cluster mapping from API response
        final Set<String> clusterNamesFromApi = {};
        for (final mc in res.customers) {
          _customerOptions.add(mc.customerName);
          _customerNameToId[mc.customerName] = mc.customerId;
          _customerIdToName[mc.customerId] = mc.customerName;
          final String clusterName = mc.clusterName.trim();
          if (clusterName.isNotEmpty) {
            _customerNameToClusterName[mc.customerName] = clusterName;
          }
          
          // Store cluster names from API response
          if (clusterName.isNotEmpty && mc.clusterId > 0) {
            clusterNamesFromApi.add(clusterName);
            // Update cluster name to ID mapping if not already present
            if (!_clusterNameToId.containsKey(clusterName)) {
              _clusterNameToId[clusterName] = mc.clusterId;
              print('NewTourPlanScreen: [Customers] Added cluster from API: $clusterName (ID: ${mc.clusterId})');
            }
            // Update cluster list if not already present
            if (!_clusters.contains(clusterName)) {
              _clusters.add(clusterName);
              print('NewTourPlanScreen: [Customers] Added cluster to list: $clusterName');
            }
          }
        }
        _customerOptions = _customerOptions.toSet().toList();
        _clusters = _clusters.toSet().toList();
        
        // Update selected clusters to match cluster names from API
        // This ensures cluster names from API are properly associated when submitting
        if (clusterNamesFromApi.isNotEmpty) {
          print('NewTourPlanScreen: [Customers] Cluster names from API: ${clusterNamesFromApi.toList()}');
          print('NewTourPlanScreen: [Customers] Currently selected clusters: ${_selectedClusters.toList()}');
          
          // Sync selected clusters with API cluster names (case-insensitive match)
          final Set<String> updatedSelectedClusters = {};
          for (final selectedCluster in _selectedClusters) {
            // Try to find matching cluster name from API (case-insensitive)
            String? matchedCluster;
            for (final apiCluster in clusterNamesFromApi) {
              if (apiCluster.toLowerCase().trim() == selectedCluster.toLowerCase().trim()) {
                matchedCluster = apiCluster;
                break;
              }
            }
            // Use API cluster name if found, otherwise keep original
            if (matchedCluster != null) {
              updatedSelectedClusters.add(matchedCluster);
              if (matchedCluster != selectedCluster) {
                print('NewTourPlanScreen: [Customers] Updated cluster name: "$selectedCluster" -> "$matchedCluster"');
              }
            } else {
              // Keep original if no match found (might be from cluster list API)
              updatedSelectedClusters.add(selectedCluster);
            }
          }
          
          // Update selected clusters if there were any changes
          if (!setEquals(_selectedClusters, updatedSelectedClusters)) {
            _selectedClusters = updatedSelectedClusters;
            print('NewTourPlanScreen: [Customers] Updated selected clusters to match API: ${_selectedClusters.toList()}');
          }
        }

        // Create a set of valid customer names for quick lookup
        final Set<String> validCustomerNames = _customerOptions.toSet();

        // Resolve customer names in existing calls, aligning by index with details if available
        final tourPlan = _fullTourPlanData ?? widget.tourPlanToEdit;
        if (tourPlan?.tourPlanDetails != null && tourPlan!.tourPlanDetails!.isNotEmpty) {
          final int count = (tourPlan.tourPlanDetails!.length < _calls.length)
              ? tourPlan.tourPlanDetails!.length
              : _calls.length;
          for (int i = 0; i < count; i++) {
            final detail = tourPlan.tourPlanDetails![i];
            final name = _customerIdToName[detail.customerId];
            if (name != null && name.isNotEmpty && validCustomerNames.contains(name)) {
              _calls[i].customers = {name};
            } else {
              // Clear customer if not found in new list (cluster changed)
              _calls[i].customers = {};
            }
          }
        } else {
          // If no details, try to replace placeholders like 'Customer ID: X'
          // Also clear invalid customers when cluster changes
          for (final call in _calls) {
            if (call.customers.length == 1) {
              final only = call.customers.first;
              if (only.startsWith('Customer ID:')) {
                final idStr = only.split(':').last.trim();
                final int? cid = int.tryParse(idStr);
                if (cid != null && _customerIdToName[cid] != null) {
                  final resolvedName = _customerIdToName[cid]!;
                  if (validCustomerNames.contains(resolvedName)) {
                    call.customers = {resolvedName};
                  } else {
                    // Clear if resolved customer is not in new list
                    call.customers = {};
                  }
                } else {
                  // Clear if customer ID not found
                  call.customers = {};
                }
              } else {
                // Check if customer name is still valid in new cluster
                if (!validCustomerNames.contains(only)) {
                  // Clear customer if not in new list (cluster changed)
                  call.customers = {};
                }
              }
            } else if (call.customers.length > 1) {
              // For multiple customers, filter to only valid ones
              call.customers = call.customers.where((c) => validCustomerNames.contains(c)).toSet();
            }
          }
        }
        _syncCallErrorsLength();
        _updateAutoSelectedClusters();
      });
    } catch (e) {
      // Silent fail
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
    Set<String>? customers,
    String? purpose,
    Set<String>? products,
    TextEditingController? samplesCtrl,
    TextEditingController? remarksCtrl,
  })  : isExpanded = isExpanded ?? true,
        customers = customers ?? <String>{},
        purpose = purpose,
        products = products ?? <String>{},
        samplesCtrl = samplesCtrl ?? TextEditingController(),
        remarksCtrl = remarksCtrl ?? TextEditingController();
  bool? isExpanded;
  Set<String> customers = <String>{};
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
  _CallValidationState({this.customerError, this.purposeError});
  String? customerError;
  String? purposeError;

  _CallValidationState copy() {
    return _CallValidationState(
      customerError: customerError,
      purposeError: purposeError,
    );
  }
}

class _CallCard extends StatelessWidget {
  const _CallCard({
    required this.index,
    required this.dateLabel,
    required this.data,
    required this.customerOptions,
    required this.purposeOptions,
    required this.productOptions,
    this.customerError,
    this.purposeError,
    this.onCustomersChanged,
    this.onPurposeChanged,
    this.onProductsChanged,
    this.onRemove,
    this.onToggleExpand,
  });
  final int index;
  final String dateLabel;
  final _CallData data;
  final List<String> customerOptions;
  final List<String> purposeOptions;
  final List<String> productOptions;
  final String? customerError;
  final String? purposeError;
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
                if (onToggleExpand != null)
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!expanded) ...[
              _CollapsedSummary(data: data),
              const SizedBox(height: 4),
            ],
            if (expanded) ...[
              const SizedBox(height: 4),
              _Labeled(
                label: 'Customer',
                required: true,
                errorText: customerError,
                child: _MultiSelectDropdown(
                  options: customerOptions,
                  selectedValues: data.customers,
                  hintText: 'Select customer',
                  emptyMessage: 'No customers found',
                  onChanged: (set) {
                    if (onCustomersChanged != null) {
                      onCustomersChanged!(set);
                    } else {
                      data.customers = set;
                    }
                  },
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
                  hintText: 'Select purpose',
                  onChanged: (value) {
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
              child: _MultiSelectDropdown(
                options: productOptions,
                selectedValues: data.products,
                hintText: 'Select products',
                emptyMessage: 'No products found',
                onChanged: (set) {
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
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
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
  const _CollapsedSummary({required this.data});
  final _CallData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String customers = data.customers.isEmpty ? 'No customer' : data.customers.join(', ');
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
    this.hintText,
    this.isLoading = false,
    this.onBeforeOpen,
    this.emptyMessage,
  });
  final List<String> options;
  final Set<String> selectedValues;
  final ValueChanged<Set<String>> onChanged;
  final String? hintText;
  final bool isLoading;
  final Future<void> Function()? onBeforeOpen;
  final String? emptyMessage;

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
    final Set<String> currentValues = setEquals(_selected, widget.selectedValues) 
        ? _selected 
        : widget.selectedValues;
    final String display = _summary(currentValues);
    if (_displayController.text != display) {
      _displayController.text = display;
      // Move cursor to end
      _displayController.selection = TextSelection.collapsed(offset: display.length);
    }
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
      _displayController.selection = TextSelection.collapsed(offset: display.length);
    }
    
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: () async => _toggleOverlay(),
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
                  ? (widget.isLoading ? 'Loading...' : (widget.hintText ?? 'Select'))
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
              child: GestureDetector(onTap: _removeOverlay, behavior: HitTestBehavior.translucent),
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
                      BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 18, offset: const Offset(0, 6)),
                    ],
                    border: Border.all(color: Colors.black.withOpacity(.06)),
                  ),
                  child: Theme(
                    data: theme.copyWith(
                      checkboxTheme: CheckboxThemeData(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        side: BorderSide(color: Colors.black.withOpacity(.35), width: 1.4),
                        fillColor: WidgetStateProperty.resolveWith((states) => const Color(0xFF4db1b3)),
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
                              isMobile ? 10 : 8
                            ),
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
                                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                                suffixIcon: (_query.isNotEmpty)
                                    ? IconButton(
                                        icon: Icon(Icons.close, color: Colors.grey[600]),
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
                                  vertical: isMobile ? 16 : 10
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF5F6F8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.black.withOpacity(.10)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.black.withOpacity(.10)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
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
                                      mainAxisAlignment: MainAxisAlignment.center,
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
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 20,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.emptyMessage ?? 'No data found',
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
                                
                                final filtered = _query.isEmpty
                                    ? widget.options
                                    : widget.options
                                        .where((o) => o.toLowerCase().contains(_query))
                                        .toList(growable: false);
                                
                                // Check if filtered list is empty (after search)
                                if (filtered.isEmpty) {
                                  return Padding(
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
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    final opt = filtered[i];
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
                                                        ? const Color(0xFF4db1b3)
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
                                                opt,
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
    _displayController.selection = TextSelection.collapsed(offset: display.length);
    
    // Update parent so it can sync its state
    widget.onChanged({..._selected});
    // Update overlay state
    _entry?.markNeedsBuild();
    // Force rebuild of this widget
    setState(() {});
  }

  String _summary(Set<String> values) {
    if (values.isEmpty) return '';
    if (values.length <= 2) return values.join(', ');
    final firstTwo = values.take(2).join(', ');
    return '$firstTwo +${values.length - 2}';
  }
}


class _SingleSelectDropdown extends StatefulWidget {
  const _SingleSelectDropdown({required this.options, required this.value, required this.onChanged, this.hintText});
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? hintText;

  @override
  State<_SingleSelectDropdown> createState() => _SingleSelectDropdownState();
}

class _SingleSelectDropdownState extends State<_SingleSelectDropdown> {
  final LayerLink _link = LayerLink();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _entry;
  String? _value;

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    // Prevent the field from requesting focus to avoid keyboard
    _focusNode.canRequestFocus = false;
  }

  @override
  void didUpdateWidget(covariant _SingleSelectDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _value) {
      _value = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: _value ?? '');
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: _toggleOverlay,
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
        final theme = Theme.of(context);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(onTap: _removeOverlay, behavior: HitTestBehavior.translucent),
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
                      BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 18, offset: const Offset(0, 6)),
                    ],
                    border: Border.all(color: Colors.black.withOpacity(.06)),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: widget.options.isEmpty
                        ? Padding(
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
                                  'No data found',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            itemCount: widget.options.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, i) {
                              final opt = widget.options[i];
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
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: selected
                                                ? const Color(0xFF4db1b3)
                                                : Colors.black.withOpacity(.35),
                                            width: 1.4,
                                          ),
                                          color: selected ? const Color(0xFF4db1b3) : Colors.transparent,
                                        ),
                                        child: selected
                                            ? const Icon(Icons.check, size: 16, color: Colors.white)
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
    _focusNode.unfocus();
  }
}

