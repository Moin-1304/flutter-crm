import 'package:flutter/material.dart';
import 'package:boilerplate/core/widgets/app_buttons.dart';
import 'package:boilerplate/core/widgets/app_form_fields.dart';
import 'package:boilerplate/core/widgets/app_dropdowns.dart';
import 'package:boilerplate/core/widgets/date_picker_field.dart';
import 'package:boilerplate/domain/repository/deviation/deviation_repository.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/domain/repository/tour_plan/tour_plan_repository.dart';
import 'package:boilerplate/data/network/apis/user/lib/domain/entity/tour_plan/tour_plan_api_models.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';

import '../../../domain/entity/common/common_api_models.dart';
import '../../../domain/repository/common/common_repository.dart';

void main() {
  runApp(const MaterialApp(
    home: DeviationEntryScreen(),
  ));
}
class DeviationEntryScreen extends StatefulWidget {
  final int? deviationId; // null for new deviation, non-null for editing
  final int? dcrId; // DCR ID when creating deviation from DCR screen
  final int? tourPlanId; // Tour Plan ID when creating deviation from DCR screen
  final DateTime? initialDate; // Initial date to use for the deviation date field
  const DeviationEntryScreen({
    super.key, 
    this.deviationId,
    this.dcrId,
    this.tourPlanId,
    this.initialDate,
  });

  @override
  State<DeviationEntryScreen> createState() => _DeviationEntryScreenState();
}

class _DeviationEntryScreenState extends State<DeviationEntryScreen> {
  String? _deviationType;
  String? _tourPlan;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _impactController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  String? _deviationTypeErrorText;
  String? _reasonErrorText;
  String? _dateError;
  String? _toClusterErrorText;
  String? _toCustomerErrorText;
  bool _isLoading = false;
  bool _isEditing = false;
  List<String> _deviationTypes = [];
  final Map<String, int> _deviationTypeNameToId = {};
  List<String> _tourPlanOptions = [];
  late Map<String, int> _tourPlanNameToId = {};
  
  // Cluster and Customer for UnPlanned Visit (single select)
  String? _selectedCluster;
  List<String> _clusterOptions = [];
  final Map<String, int> _clusterNameToId = <String, int>{};
  String? _selectedCustomer;
  List<String> _customerOptions = [];
  final Map<String, int> _customerNameToId = <String, int>{};
  
  // From Cluster and From Customer (read-only, from Tour Plan)
  String? _fromCluster;
  String? _fromCustomer;
  
  // Store tour plan detail ID for editing mode
  int? _storedTourPlanDetailId;
  
  // Store tour plan data: map from tour plan display text to cluster/customer
  Map<String, String> _tourPlanToCluster = <String, String>{};
  Map<String, String> _tourPlanToCustomer = <String, String>{};

  @override
  void initState() {
    super.initState();
    _isEditing = widget.deviationId != null;
    
    // Initialize date field with selected date or current date for new deviations
    if (!_isEditing) {
      final date = widget.initialDate ?? DateTime.now();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      _dateController.text = '${date.day.toString().padLeft(2, '0')}-${months[date.month - 1]}-${date.year}';
    }
    
    // Debug logging for DCR parameters
    if (widget.dcrId != null || widget.tourPlanId != null) {
      print('DeviationEntryScreen: Creating deviation from DCR');
      print('  - DCR ID: ${widget.dcrId}');
      print('  - Tour Plan ID: ${widget.tourPlanId}');
    }
    
    _initializeData();
    // Auto-refresh removed: APIs will only be called once during initialization
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load deviation types first
      await _loadDeviationTypeList();
      
      // Load clusters and customers (for UnPlanned Visit)
      await _loadClusterList();
      
      // If editing, load deviation data first to get the date, then load tour plans with that date
      if (_isEditing) {
        // Load deviation data first to get the date
        await _loadDeviationDataForDate();
        
        // Load tour plans using the deviation date
        await _loadTourPlanList();
        
        // Now set the tour plan value after the list is loaded
        await _setTourPlanFromDeviationData();
      } else {
        // For new deviations, load tour plans with current date
        await _loadTourPlanList();
      }
      
      // Force a final update to ensure UI is properly refreshed
      if (mounted) {
        setState(() {
          // Force rebuild to ensure all values are properly displayed
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDeviationTypeList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        final List<CommonDropdownItem> items = await commonRepo.getDeviationTypeList();
        final types = items.map((e) => (e.employeeName.isNotEmpty ? e.employeeName : e.text).trim()).where((s) => s.isNotEmpty).toSet();
        
        if (types.isNotEmpty && mounted) {
          setState(() {
            _deviationTypes = types.toList();
            // map names to ids for potential deviation type ID mapping
            for (final item in items) {
              final String key = (item.employeeName.isNotEmpty ? item.employeeName : item.text).trim();
              if (key.isNotEmpty) _deviationTypeNameToId[key] = item.id;
            }
          });
          print('DeviationEntryScreen: Loaded ${_deviationTypes.length} deviation types');
        }
      }
    } catch (e) {
      print('DeviationEntryScreen: Error getting deviation type list: $e');
      // Fallback to default types
      if (mounted) {
        setState(() {
          _deviationTypes = ['Route Change','Customer Unavailable','Emergency Leave','Adhoc Visit','Other'];
        });
      }
    }
  }

  Future<void> _loadTourPlanList() async {
    try {
      if (getIt.isRegistered<CommonRepository>() && getIt.isRegistered<UserDetailStore>()) {
        final commonRepo = getIt<CommonRepository>();
        final userStore = getIt<UserDetailStore>();

        final userDetail = userStore.userDetail;
        if (userDetail != null) {
          final requestDate = _buildTourPlanRequestDate();
          final userId = userDetail.id ?? 0;
          final employeeId = userDetail.employeeId ?? 0;
          final bizUnit = userDetail.sbuId ?? 1;

          final tourPlanItems = await commonRepo.getTourPlanDropdown(
            userId: userId,
            employeeId: employeeId,
            bizUnit: bizUnit,
            date: requestDate,
          );

          if (mounted) {
            final List<String> tourPlanOptions = [];
            final Map<String, int> tourPlanNameToId = {};
            final Map<String, String> tourPlanToCluster = {};
            final Map<String, String> tourPlanToCustomer = {};

            for (final item in tourPlanItems) {
              final planText = item.text.trim().isNotEmpty ? item.text.trim() : 'Unknown';
              final customer = item.customer.trim().isNotEmpty ? item.customer.trim() : 'Unknown';
              final planDate = _formatApiDate(item.planDate);
              final displayText = '$planText | $customer | $planDate';

              tourPlanOptions.add(displayText);
              tourPlanNameToId[displayText] = item.id;
              
              // Store mapping for From fields: text -> cluster, customer -> customer
              tourPlanToCluster[displayText] = planText; // text field contains cluster
              tourPlanToCustomer[displayText] = customer; // customer field contains customer
            }

            setState(() {
              _tourPlanOptions = tourPlanOptions;
              _tourPlanNameToId = tourPlanNameToId;
              _tourPlanToCluster = tourPlanToCluster;
              _tourPlanToCustomer = tourPlanToCustomer;
            });

            print('DeviationEntryScreen: Loaded ${_tourPlanOptions.length} tour plans');
          }
        }
      }
    } catch (e) {
      print('DeviationEntryScreen: Error loading tour plan list: $e');
      // Fallback to default options
      if (mounted) {
        setState(() {
          _tourPlanOptions = [
            'N/A | Apollo Hospital | 10-Nov-2025',
            'N/A | Fortis Healthcare | 11-Nov-2025',
            'N/A | Medanta Clinic | 12-Nov-2025',
          ];
          _tourPlanNameToId = {};
        });
      }
    }
  }
  String _formatDate(DateTime date) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day.toString().padLeft(2, '0')}-${months[date.month - 1]}-${date.year}';
  }

  /// Load deviation data to get the date and other fields (except tour plan)
  /// This is called before loading tour plan list when editing
  Future<void> _loadDeviationDataForDate() async {
    if (widget.deviationId == null) return;
    
    try {
      if (getIt.isRegistered<DeviationRepository>()) {
        final deviationRepo = getIt<DeviationRepository>();
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
        final int? employeeId = userStore?.userDetail?.employeeId;

        if (user != null && employeeId != null) {
          print('DeviationEntryScreen: Loading deviation data for date extraction - ID: ${widget.deviationId}');
          
          // Get all deviations and find the one with matching ID
          final response = await deviationRepo.getDeviationList(
            searchText: '',
            pageNumber: 1,
            pageSize: 1000,
            userId: user.userId,
            bizUnit: user.sbuId,
            employeeId: employeeId,
          );
          
          // Find the deviation with matching ID
          final deviation = response.items.firstWhere(
            (item) => item.id == widget.deviationId,
            orElse: () => response.items.first,
          );
          
          if (mounted) {
            // Store tour plan detail ID for later use
            _storedTourPlanDetailId = deviation.tourPlanDetailId;
            
            setState(() {
              // Set deviation type
              _deviationType = deviation.deviationType;
              
              // Set reason/description
              _reasonController.text = deviation.description ?? '';
              
              // Set impact
              _impactController.text = deviation.impact ?? '';
              
              // Set date - convert from yyyy-MM-dd to dd-MMM-yyyy format
              if (deviation.dateOfDeviation.isNotEmpty) {
                try {
                  final date = DateTime.parse(deviation.dateOfDeviation);
                  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                  _dateController.text = '${date.day.toString().padLeft(2, '0')}-${months[date.month - 1]}-${date.year}';
                } catch (e) {
                  _dateController.text = deviation.dateOfDeviation;
                }
              }
              
              // Set cluster and customer for UnPlanned Visit
              if (deviation.deviationType?.toLowerCase() == 'unplanned visit') {
                // Set cluster if clusterName is available
                if (deviation.clusterName != null && deviation.clusterName!.isNotEmpty) {
                  final clusterName = deviation.clusterName!;
                  if (_clusterOptions.contains(clusterName)) {
                    _selectedCluster = clusterName;
                  }
                }
              }
            });
            
            // Load customers if cluster is set for UnPlanned Visit
            if (deviation.deviationType?.toLowerCase() == 'unplanned visit' && 
                _selectedCluster != null && 
                _selectedCluster!.isNotEmpty) {
              await _loadMappedCustomers();
              
              // Set customer after customers are loaded
              if (mounted && deviation.customerId != null && deviation.customerId! > 0) {
                // Find customer name by ID
                final customerName = _customerNameToId.entries
                    .firstWhere(
                      (entry) => entry.value == deviation.customerId,
                      orElse: () => MapEntry('', 0),
                    )
                    .key;
                if (customerName.isNotEmpty && mounted) {
                  setState(() {
                    _selectedCustomer = customerName;
                  });
                }
              }
            }
            
            print('DeviationEntryScreen: Loaded deviation data for date extraction - TourPlanDetailId: $_storedTourPlanDetailId');
          }
        }
      }
    } catch (e) {
      print('DeviationEntryScreen: Error loading deviation data for date: $e');
    }
  }

  /// Set tour plan value from stored tour plan detail ID after tour plan list is loaded
  Future<void> _setTourPlanFromDeviationData() async {
    if (_storedTourPlanDetailId == null || _storedTourPlanDetailId! <= 0) {
      print('DeviationEntryScreen: No tour plan detail ID to set');
      return;
    }

    print('DeviationEntryScreen: Setting tour plan from stored ID: $_storedTourPlanDetailId');
    print('DeviationEntryScreen: Available tour plan options: ${_tourPlanOptions.length}');
    print('DeviationEntryScreen: Tour plan ID map: $_tourPlanNameToId');

    // Find tour plan by ID
    String? selectedOption;
    for (final entry in _tourPlanNameToId.entries) {
      if (entry.value == _storedTourPlanDetailId) {
        selectedOption = entry.key;
        print('DeviationEntryScreen: Found tour plan by ID: $selectedOption');
        break;
      }
    }

    if (selectedOption != null && mounted) {
      setState(() {
        _tourPlan = selectedOption;
        // Populate From fields when Tour Plan is set
        _fromCluster = _tourPlanToCluster[selectedOption] ?? '';
        _fromCustomer = _tourPlanToCustomer[selectedOption] ?? '';
      });
      print('DeviationEntryScreen: Tour plan set successfully: $_tourPlan');
      print('DeviationEntryScreen: From Cluster: $_fromCluster, From Customer: $_fromCustomer');
    } else {
      print('DeviationEntryScreen: Tour plan with ID $_storedTourPlanDetailId not found in list');
      // Optionally, you could add a fallback option here
    }
  }

  String _buildTourPlanRequestDate() {
    DateTime targetDate = DateTime.now();

    if (_dateController.text.isNotEmpty) {
      final parsed = _parseDisplayedDate(_dateController.text);
      if (parsed != null) {
        targetDate = parsed;
      }
    }

    final month = targetDate.month.toString().padLeft(2, '0');
    final day = targetDate.day.toString().padLeft(2, '0');
    final year = targetDate.year.toString();

    return '$month/$day/$year';
  }

  DateTime? _parseDisplayedDate(String value) {
    try {
      final parts = value.split('-');
      if (parts.length == 3) {
        const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        final day = int.parse(parts[0]);
        final monthIndex = months.indexOf(parts[1]);
        final year = int.parse(parts[2]);
        if (monthIndex >= 0) {
          return DateTime(year, monthIndex + 1, day);
        }
      }
    } catch (e) {
      print('DeviationEntryScreen: Error parsing displayed date "$value": $e');
    }
    return null;
  }

  String _formatApiDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Unknown';
    }

    final raw = value.trim();
    try {
      final parts = raw.split('/');
      if (parts.length == 3) {
        final first = int.parse(parts[0]);
        final second = int.parse(parts[1]);
        final year = int.parse(parts[2]);

        // Attempt MM/dd/yyyy first (matches API sample)
        if (first >= 1 && first <= 12 && second >= 1 && second <= 31) {
          final date = DateTime(year, first, second);
          return _formatDate(date);
        }

        // Fallback: treat as dd/MM/yyyy
        if (second >= 1 && second <= 12 && first >= 1 && first <= 31) {
          final date = DateTime(year, second, first);
          return _formatDate(date);
        }
      }
    } catch (e) {
      print('DeviationEntryScreen: Error formatting API date "$raw": $e');
    }

    return raw;
  }

  Future<void> _loadClusterList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        const int countryId = 208;
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
        final int? employeeId = userStore?.userDetail?.employeeId;
        
        if (employeeId == null) {
          print('DeviationEntryScreen: Employee ID not available for cluster list');
          return;
        }
        
        final List<CommonDropdownItem> items = await repo.getClusterList(countryId, employeeId);
        final clusters = items.map((e) => (e.text.isNotEmpty ? e.text : e.cityName).trim()).where((s) => s.isNotEmpty).toSet();
        if (clusters.isNotEmpty && mounted) {
          setState(() {
            _clusterOptions = clusters.toList();
            // map names to ids
            for (final item in items) {
              final String key = (item.text.isNotEmpty ? item.text : item.cityName).trim();
              if (key.isNotEmpty) _clusterNameToId[key] = item.id;
            }
          });
          print('DeviationEntryScreen: Loaded ${_clusterOptions.length} clusters');
        }
      }
    } catch (e) {
      print('DeviationEntryScreen: Error loading cluster list: $e');
    }
  }

  Future<void> _loadMappedCustomers() async {
    try {
      if (!getIt.isRegistered<TourPlanRepository>()) {
        print('DeviationEntryScreen: TourPlanRepository not registered - skipping');
        return;
      }
      final repo = getIt<TourPlanRepository>();
      final userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
      final int? employeeId = userStore?.userDetail?.employeeId;
      
      if (employeeId == null) {
        print('DeviationEntryScreen: Employee ID not available for customer list');
        return;
      }

      // Build ClusterIds from selected cluster in dropdown
      final List<ClusterIdModel> selectedClusterIds = [];
      if (_selectedCluster != null && _selectedCluster!.isNotEmpty) {
        final clusterId = _clusterNameToId[_selectedCluster];
        if (clusterId != null && clusterId > 0) {
          selectedClusterIds.add(ClusterIdModel(clusterId: clusterId));
        }
      }

      print('DeviationEntryScreen: Selected cluster: $_selectedCluster');
      print('DeviationEntryScreen: Cluster IDs: ${selectedClusterIds.map((c) => c.clusterId).toList()}');

      // If no cluster is selected, clear customers
      if (selectedClusterIds.isEmpty) {
        print('DeviationEntryScreen: No cluster selected - clearing customers');
        setState(() {
          _customerOptions = [];
          _customerNameToId.clear();
          _selectedCustomer = null;
        });
        return;
      }

      // Use deviation date or current date
      DateTime deviationDate = DateTime.now();
      if (_dateController.text.isNotEmpty) {
        try {
          final parts = _dateController.text.split('-');
          if (parts.length == 3) {
            const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
            final monthIndex = months.indexOf(parts[1]);
            if (monthIndex != -1) {
              deviationDate = DateTime(int.parse(parts[2]), monthIndex + 1, int.parse(parts[0]));
            }
          }
        } catch (e) {
          print('DeviationEntryScreen: Error parsing date: $e');
        }
      }

      final String dateStr = deviationDate.toIso8601String().split('T').first;

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
        selectedEmployeeId: null,
        date: dateStr,
      );

      print('DeviationEntryScreen: [Customers] Request body => ${req.toJson()}');
      final response = await repo.getMappedCustomersByEmployeeId(req);
      print('DeviationEntryScreen: [Customers] Response received: ${response.customers.length} customers');

      if (mounted) {
        final List<String> customerOptions = [];
        final Map<String, int> customerNameToId = {};

        for (final item in response.customers) {
          final customerName = item.customerName.trim();
          if (customerName.isNotEmpty) {
            customerOptions.add(customerName);
            customerNameToId[customerName] = item.customerId;
          }
        }

        setState(() {
          _customerOptions = customerOptions;
          _customerNameToId.clear();
          _customerNameToId.addAll(customerNameToId);
        });

        print('DeviationEntryScreen: Loaded ${_customerOptions.length} customers');
      }
    } catch (e) {
      print('DeviationEntryScreen: Error loading mapped customers: $e');
      if (mounted) {
        setState(() {
          _customerOptions = [];
          _customerNameToId.clear();
        });
      }
    }
  }

  Future<void> _setTourPlanValue(String? tourPlanName, int? tourPlanId) async {
    if (tourPlanName == null || tourPlanName.isEmpty) {
      print('DeviationEntryScreen: No tour plan name to set');
      return;
    }

    // Ensure tour plan options are loaded
    if (_tourPlanOptions.isEmpty) {
      print('DeviationEntryScreen: Tour plan options not loaded, loading now...');
      await _loadTourPlanList();
    }

    print('DeviationEntryScreen: Setting tour plan - Name: $tourPlanName, ID: $tourPlanId');
    print('DeviationEntryScreen: Available options: ${_tourPlanOptions.length}');
    
    // Try to find exact match first
    String? selectedOption;
    
    // Strategy 1: Match by ID (most reliable)
    if (tourPlanId != null && tourPlanId > 0) {
      for (final entry in _tourPlanNameToId.entries) {
        if (entry.value == tourPlanId) {
          selectedOption = entry.key;
          print('DeviationEntryScreen: Found by ID: $selectedOption');
          break;
        }
      }
    }
    
    // Strategy 2: Match by name (partial match)
    if (selectedOption == null) {
      for (final option in _tourPlanOptions) {
        if (option.toLowerCase().contains(tourPlanName.toLowerCase())) {
          selectedOption = option;
          print('DeviationEntryScreen: Found by name: $selectedOption');
          break;
        }
      }
    }
    
    // Strategy 3: Create fallback with proper formatting
    if (selectedOption == null) {
      // Format the fallback to match the expected format: "Date | Cluster | Customer"
      final currentDate = DateTime.now();
      final dateStr = _formatDate(currentDate);
      selectedOption = '$dateStr | $tourPlanName (Previous)';
      _tourPlanOptions.add(selectedOption);
      _tourPlanNameToId[selectedOption] = tourPlanId ?? 0;
      // For fallback, try to extract cluster/customer from the tour plan name
      // Format would be different, so we'll leave it empty or try to parse
      print('DeviationEntryScreen: Created fallback: $selectedOption');
    }
    
    if (mounted) {
      setState(() {
        _tourPlan = selectedOption;
        // Populate From fields when Tour Plan is set
        if (selectedOption != null) {
          _fromCluster = _tourPlanToCluster[selectedOption] ?? '';
          _fromCustomer = _tourPlanToCustomer[selectedOption] ?? '';
        }
      });
    }
    print('DeviationEntryScreen: Final tour plan set to: $_tourPlan');
  }


  Future<void> _loadDeviationData() async {
    if (widget.deviationId == null) return;
    
    try {
      if (getIt.isRegistered<DeviationRepository>()) {
        final deviationRepo = getIt<DeviationRepository>();
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
        final int? employeeId = userStore?.userDetail?.employeeId;

        if (user != null && employeeId != null) {
          print('DeviationEntryScreen: Loading deviation data for ID: ${widget.deviationId}');
          
          // Get all deviations and find the one with matching ID
          final response = await deviationRepo.getDeviationList(
            searchText: '',
            pageNumber: 1,
            pageSize: 1000,
            userId: user.userId,
            bizUnit: user.sbuId,
            employeeId: employeeId,
          );
          
          // Find the deviation with matching ID
          final deviation = response.items.firstWhere(
            (item) => item.id == widget.deviationId,
            orElse: () => response.items.first,
          );
          
          if (mounted) {
            // Set tour plan using the helper method (outside setState since it's async)
            await _setTourPlanValue(deviation.tourPlanName, deviation.tourPlanDetailId);
            
            setState(() {
              // Set deviation type
              _deviationType = deviation.deviationType;
              
              // Set reason/description
              _reasonController.text = deviation.description ?? '';
              
              // Set impact
              _impactController.text = deviation.impact ?? '';
              
              // Set date - convert from yyyy-MM-dd to dd-MMM-yyyy format
              if (deviation.dateOfDeviation.isNotEmpty) {
                try {
                  final date = DateTime.parse(deviation.dateOfDeviation);
                  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                  _dateController.text = '${date.day.toString().padLeft(2, '0')}-${months[date.month - 1]}-${date.year}';
                } catch (e) {
                  _dateController.text = deviation.dateOfDeviation;
                }
              }
              
              // Set cluster and customer for UnPlanned Visit
              if (deviation.deviationType?.toLowerCase() == 'unplanned visit') {
                // Set cluster if clusterName is available
                if (deviation.clusterName != null && deviation.clusterName!.isNotEmpty) {
                  final clusterName = deviation.clusterName!;
                  if (_clusterOptions.contains(clusterName)) {
                    _selectedCluster = clusterName;
                  }
                }
              }
            });
            
            // Load customers if cluster is set for UnPlanned Visit, and await completion
            if (deviation.deviationType?.toLowerCase() == 'unplanned visit' && 
                _selectedCluster != null && 
                _selectedCluster!.isNotEmpty) {
              await _loadMappedCustomers();
              
              // Set customer after customers are loaded
              if (mounted && deviation.customerId != null && deviation.customerId! > 0) {
                // Find customer name by ID
                final customerName = _customerNameToId.entries
                    .firstWhere(
                      (entry) => entry.value == deviation.customerId,
                      orElse: () => MapEntry('', 0),
                    )
                    .key;
                if (customerName.isNotEmpty && mounted) {
                  setState(() {
                    _selectedCustomer = customerName;
                  });
                }
              }
            }
            
            print('DeviationEntryScreen: Loaded deviation data successfully');
          }
        } else {
          if (mounted) {
            ToastMessage.show(
              context,
              message: 'User information not available. Please login again.',
              type: ToastType.error,
              useRootNavigator: true,
              duration: const Duration(seconds: 3),
            );
          }
        }
      }
    } catch (e) {
      print('DeviationEntryScreen: Error loading deviation data: $e');
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Error loading deviation: ${e.toString().replaceFirst('Exception: ', '')}',
          type: ToastType.error,
          useRootNavigator: true,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _impactController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // Auto-refresh methods removed: APIs are now only called once during initialization
  // This prevents unnecessary API calls at intervals when editing a deviation

  bool _validateForm() {
    bool isValid = true;
    String? firstMessage;

    String? dateError;
    if (_dateController.text.trim().isEmpty) {
      dateError = 'Please select a deviation date';
      firstMessage ??= 'Select a deviation date';
      isValid = false;
    }

    String? deviationTypeError;
    if (_deviationType == null || _deviationType!.trim().isEmpty) {
      deviationTypeError = 'Please select a deviation type';
      isValid = false;
      firstMessage ??= 'Select a deviation type';
    }

    String? reasonError;
    if (_reasonController.text.trim().isEmpty) {
      reasonError = 'Please enter reason for deviation';
      isValid = false;
      firstMessage ??= 'Enter reason for deviation';
    }

    // Validate To Cluster and To Customer for Unplanned Visit
    String? toClusterError;
    String? toCustomerError;
    if (_deviationType?.toLowerCase() == 'unplanned visit') {
      if (_selectedCluster == null || _selectedCluster!.trim().isEmpty) {
        toClusterError = 'Please select To Cluster';
        isValid = false;
        firstMessage ??= 'Select To Cluster';
      }
      if (_selectedCustomer == null || _selectedCustomer!.trim().isEmpty) {
        toCustomerError = 'Please select To Customer';
        isValid = false;
        firstMessage ??= 'Select To Customer';
      }
    }

    setState(() {
      _dateError = dateError;
      _deviationTypeErrorText = deviationTypeError;
      _reasonErrorText = reasonError;
      _toClusterErrorText = toClusterError;
      _toCustomerErrorText = toCustomerError;
    });

    if (!isValid) {
      ToastMessage.show(
        context,
        message: firstMessage ?? 'Please review the highlighted fields',
        type: ToastType.warning,
        useRootNavigator: true,
        duration: const Duration(seconds: 3),
      );
    }

    return isValid;
  }

  Future<void> _saveDeviation() async {
    if (!_validateForm()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (getIt.isRegistered<DeviationRepository>()) {
        final deviationRepo = getIt<DeviationRepository>();
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        
        if (user != null) {
          // Parse date from controller
          String dateOfDeviation = '';
          if (_dateController.text.isNotEmpty) {
            try {
              // Convert from dd-MMM-yyyy to yyyy-MM-dd format
              final parts = _dateController.text.split('-');
              if (parts.length == 3) {
                const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                final monthIndex = months.indexOf(parts[1]);
                if (monthIndex != -1) {
                  final day = parts[0].padLeft(2, '0');
                  final month = (monthIndex + 1).toString().padLeft(2, '0');
                  final year = parts[2];
                  dateOfDeviation = '$year-$month-$day';
                }
              }
            } catch (e) {
              dateOfDeviation = DateTime.now().toIso8601String().split('T')[0];
            }
          } else {
            dateOfDeviation = DateTime.now().toIso8601String().split('T')[0];
          }

          // Map deviation type to type ID using API data
          int typeOfDeviation = _deviationTypeNameToId[_deviationType] ?? 1; // Default to 1 if not found

          // Get selected tour plan ID if tour plan is selected
          int? tourPlanDetailId;
          if (_tourPlan != null && _tourPlanNameToId.containsKey(_tourPlan)) {
            tourPlanDetailId = _tourPlanNameToId[_tourPlan];
          }

          // Get cluster and customer IDs for UnPlanned Visit
          int clusterId = 0;
          int customerId = 0;
          String? clusterName;
          
          if (_deviationType?.toLowerCase() == 'unplanned visit') {
            // Get selected cluster ID
            if (_selectedCluster != null && _selectedCluster!.isNotEmpty) {
              clusterId = _clusterNameToId[_selectedCluster!] ?? 0;
              clusterName = _selectedCluster;
            }
            
            // Get selected customer ID
            if (_selectedCustomer != null && _selectedCustomer!.isNotEmpty) {
              customerId = _customerNameToId[_selectedCustomer!] ?? 0;
            }
          }

          final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
          final userDetail = userStore?.userDetail;

          if (_isEditing && widget.deviationId != null) {
            // Update existing deviation
            final finalTourPlanDetailId = widget.tourPlanId ?? tourPlanDetailId;
            final finalDcrDetailId = widget.dcrId;
            
            print('DeviationEntryScreen: Updating deviation with DCR details');
            print('  - Deviation ID: ${widget.deviationId}');
            print('  - DCRDetailId: $finalDcrDetailId');
            print('  - TourPlanDetailId: $finalTourPlanDetailId');
            
            final response = await deviationRepo.updateDeviation(
              id: widget.deviationId!,
              createdBy: user.userId,
              status: 0,
              sbuId: user.sbuId,
              bizUnit: user.sbuId,
              tourPlanDetailId: finalTourPlanDetailId,
              dcrDetailId: finalDcrDetailId,
              dateOfDeviation: dateOfDeviation,
              typeOfDeviation: typeOfDeviation,
              description: _reasonController.text,
              customerId: customerId,
              clusterId: clusterId,
              impact: _impactController.text,
              deviationType: _deviationType!,
              deviationStatus: 'Open',
              commentCount: null,
              clusterName: clusterName,
              employeeId: userDetail!.employeeId,
              employeeName: null,
              employeeCode: null,
              tourPlanName: null,
            );

            if (mounted) {
              ToastMessage.show(
                context,
                message: 'Deviation updated successfully',
                type: ToastType.success,
                useRootNavigator: true,
                duration: const Duration(seconds: 3),
              );
              
              // Navigate back with success indicator
              Navigator.of(context).pop(true);
            }
          } else {
            // Create new deviation
            final finalTourPlanDetailId = widget.tourPlanId ?? tourPlanDetailId;
            final finalDcrDetailId = widget.dcrId;
            
            print('DeviationEntryScreen: Saving deviation with DCR details');
            print('  - DCRDetailId: $finalDcrDetailId');
            print('  - TourPlanDetailId: $finalTourPlanDetailId');
            print('  - Description: ${_reasonController.text}');
            print('  - DeviationType: ${_deviationType}');
            
            final response = await deviationRepo.saveDeviation(
              id: null,
              createdBy: user.userId,
              status: 0,
              sbuId: user.sbuId,
              bizUnit: user.sbuId,
              tourPlanDetailId: finalTourPlanDetailId,
              dcrDetailId: finalDcrDetailId,
              dateOfDeviation: dateOfDeviation,
              typeOfDeviation: typeOfDeviation,
              description: _reasonController.text,
              customerId: customerId,
              clusterId: clusterId,
              impact: _impactController.text,
              deviationType: _deviationType!,
              deviationStatus: 'Open',
              commentCount: null,
              clusterName: clusterName,
              employeeId: userDetail!.employeeId,
              employeeName: null,
              employeeCode: null,
              tourPlanName: null,
            );

            if (mounted) {
              ToastMessage.show(
                context,
                message: 'Deviation saved successfully',
                type: ToastType.success,
                useRootNavigator: true,
                duration: const Duration(seconds: 3),
              );
              
              // Navigate back with success indicator for new deviation
              Navigator.of(context).pop(true);
            }
          }
        } else {
          if (mounted) {
            ToastMessage.show(
              context,
              message: 'User not found. Please login again.',
              type: ToastType.error,
              useRootNavigator: true,
              duration: const Duration(seconds: 4),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Error ${_isEditing ? 'updating' : 'saving'} deviation: ${e.toString().replaceFirst('Exception: ', '')}',
          type: ToastType.error,
          useRootNavigator: true,
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    const Color tealGreen = Color(0xFF4db1b3);
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
          _isEditing ? 'Edit Deviation' : 'New Deviation',
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
      body: Stack(
        children: [
          SafeArea(
            child: Theme(
              data: screenTheme,
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
                            
                            // Date and Type row
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool stack = constraints.maxWidth < 500;
                                final dateField = _LabeledField(
                                  label: 'Deviation Date',
                                  required: true,
                                  errorText: _dateError,
                                  child: _DateField(
                                    controller: _dateController,
                                    onChanged: (date) {
                                      setState(() {
                                        _dateController.text = date;
                                        _dateError = null; // Clear error when date is selected
                                      });
                                      // Reload customers if cluster is selected (for UnPlanned Visit)
                                      if (_deviationType?.toLowerCase() == 'unplanned visit' && _selectedCluster != null && _selectedCluster!.isNotEmpty) {
                                        _loadMappedCustomers();
                                      }
                                    },
                                  ),
                                );
                                final typeField = _LabeledField(
                                  label: 'Deviation Type',
                                  required: true,
                                  errorText: _deviationTypeErrorText,
                                  child: SearchableDropdown(
                                    options: _deviationTypes,
                                    value: _deviationType,
                                    hintText: 'Select deviation type',
                                    searchHintText: 'Search deviation type...',
                                    hasError: _deviationTypeErrorText != null,
                                    onChanged: (v) {
                                      setState(() {
                                        _deviationType = v;
                                        _deviationTypeErrorText = null;
                                        // Clear cluster and customer selections when deviation type changes
                                        if (v?.toLowerCase() != 'unplanned visit') {
                                          _selectedCluster = null;
                                          _selectedCustomer = null;
                                          _toClusterErrorText = null;
                                          _toCustomerErrorText = null;
                                        }
                                      });
                                      // Load customers if UnPlanned Visit is selected and cluster is selected
                                      if (v?.toLowerCase() == 'unplanned visit' && _selectedCluster != null && _selectedCluster!.isNotEmpty) {
                                        _loadMappedCustomers();
                                      }
                                    },
                                  ),
                                );
                                
                                if (stack) {
                                  return Column(
                                    children: [
                                      dateField,
                                      const SizedBox(height: 16),
                                      typeField,
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: dateField),
                                    const SizedBox(width: 16),
                                    Expanded(child: typeField),
                                  ],
                                );
                              },
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Tour Plan (always visible)
                            _LabeledField(
                              label: 'Tour Plan (Optional)',
                              child: SearchableDropdown(
                                options: _tourPlanOptions,
                                value: _tourPlan,
                                hintText: 'Select tour plan',
                                searchHintText: 'Search tour plan...',
                                onChanged: (v) {
                                  setState(() {
                                    _tourPlan = v;
                                    // Populate From fields when Tour Plan is selected
                                    if (v != null && v.isNotEmpty) {
                                      _fromCluster = _tourPlanToCluster[v] ?? '';
                                      _fromCustomer = _tourPlanToCustomer[v] ?? '';
                                    } else {
                                      // Clear From fields when Tour Plan is cleared
                                      _fromCluster = null;
                                      _fromCustomer = null;
                                    }
                                  });
                                },
                              ),
                            ),
                            
                            // From and To Area/Customer for UnPlanned Visit
                            if (_deviationType?.toLowerCase() == 'unplanned visit') ...[
                              const SizedBox(height: 20),
                              Divider(height: 1, color: Colors.grey.shade300),
                              const SizedBox(height: 20),
                              
                              // From Area / Customer (Read-Only) - Only show when Tour Plan is selected
                              if (_tourPlan != null && _tourPlan!.isNotEmpty) ...[
                                Text(
                                  'From Area / Customer',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _LabeledField(
                                  label: 'From Cluster',
                                  child: TextFormField(
                                    readOnly: true,
                                    enabled: false,
                                    controller: TextEditingController(text: _fromCluster ?? ''),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.grey[600],
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Will be filled from Tour Plan',
                                      hintStyle: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _LabeledField(
                                  label: 'From Customer',
                                  child: TextFormField(
                                    readOnly: true,
                                    enabled: false,
                                    controller: TextEditingController(text: _fromCustomer ?? ''),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.grey[600],
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Will be filled from Tour Plan',
                                      hintStyle: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              
                              // To Area / Customer (Mandatory)
                              Text(
                                'To Area / Customer',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                  letterSpacing: 0.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _LabeledField(
                                label: 'To Cluster',
                                required: true,
                                errorText: _toClusterErrorText,
                                child: SearchableDropdown(
                                  options: _clusterOptions,
                                  value: _selectedCluster,
                                  hintText: 'Select cluster/city',
                                  searchHintText: 'Search cluster/city...',
                                  hasError: _toClusterErrorText != null,
                                  onChanged: (v) {
                                    setState(() {
                                      _selectedCluster = v;
                                      _toClusterErrorText = null; // Clear error when changed
                                      // Clear customer when cluster changes
                                      _selectedCustomer = null;
                                    });
                                    // Load customers based on selected cluster
                                    if (v != null && v.isNotEmpty) {
                                      _loadMappedCustomers();
                                    } else {
                                      setState(() {
                                        _customerOptions = [];
                                        _customerNameToId.clear();
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              _LabeledField(
                                label: 'To Customer',
                                required: true,
                                errorText: _toCustomerErrorText,
                                child: SearchableDropdown(
                                  options: _customerOptions,
                                  value: _selectedCustomer,
                                  hintText: _selectedCluster == null || _selectedCluster!.isEmpty
                                      ? 'Select cluster first' 
                                      : 'Select customer',
                                  searchHintText: 'Search customer...',
                                  hasError: _toCustomerErrorText != null,
                                  onChanged: (v) {
                                    setState(() {
                                      _selectedCustomer = v;
                                      _toCustomerErrorText = null; // Clear error when changed
                                    });
                                  },
                                ),
                              ),
                            ],
                            
                            const SizedBox(height: 12),
                            
                            // Reason and Impact row
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool stack = constraints.maxWidth < 500;
                                final reason = _LabeledField(
                                  label: 'Reason for Deviation',
                                  required: true,
                                  errorText: _reasonErrorText,
                                  child: TextFormField(
                                    controller: _reasonController,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.grey[900],
                                    ),
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      hintText: 'Explain the reason for the deviation in detail...',
                                      hintStyle: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.grey.shade400,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: _reasonErrorText != null ? Colors.red.shade400 : Colors.grey.shade300, width: 1),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: _reasonErrorText != null ? Colors.red.shade400 : tealGreen, width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    onChanged: (_) => setState(() => _reasonErrorText = null),
                                  ),
                                );
                                final impact = _LabeledField(
                                  label: 'Impact (Optional)',
                                  child: TextFormField(
                                    controller: _impactController,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.grey[900],
                                    ),
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      hintText: 'Describe any impact of this deviation...',
                                      hintStyle: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.grey.shade400,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: tealGreen, width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                  ),
                                );
                                
                                if (stack) {
                                  return Column(
                                    children: [
                                      reason,
                                      const SizedBox(height: 16),
                                      impact,
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: reason),
                                    const SizedBox(width: 16),
                                    Expanded(child: impact),
                                  ],
                                );
                              },
                            ),
                            
                            const SizedBox(height: 20),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      side: BorderSide(color: tealGreen),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: tealGreen,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _isLoading ? null : _saveDeviation,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF4db1b3),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: _isLoading 
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Text(
                                            _isEditing ? 'Update' : 'Submit',
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
          // Loading overlay when prefilled data is being loaded
          if (_isLoading)
            AbsorbPointer(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(tealGreen),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isEditing ? 'Loading deviation details...' : 'Loading...',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
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
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
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

class _DateField extends StatelessWidget {
  const _DateField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')}-${months[date.month - 1]}-${date.year}';
  }
  
  DateTime? _parseDate(String dateText) {
    if (dateText.isEmpty) return null;
    try {
      final parts = dateText.split('-');
      if (parts.length == 3) {
        const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        final monthIndex = months.indexOf(parts[1]);
        if (monthIndex != -1) {
          return DateTime(int.parse(parts[2]), monthIndex + 1, int.parse(parts[0]));
        }
      }
    } catch (e) {
      // If parsing fails, return null
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      controller: controller,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: 'Select Date',
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.grey[500],
        ),
        suffixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      onTap: () async {
        // Use the date from controller if available, otherwise use current date
        final currentDate = _parseDate(controller.text) ?? DateTime.now();
        
        final picked = await showDatePicker(
          context: context,
          initialDate: currentDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
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
                    foregroundColor: const Color(0xFF4db1b3),
                  ),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onChanged(_formatDate(picked));
        }
      },
    );
  }
}




