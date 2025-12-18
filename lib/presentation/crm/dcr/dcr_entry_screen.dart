import 'package:flutter/material.dart';
import 'package:boilerplate/core/widgets/app_buttons.dart';
import 'package:boilerplate/core/widgets/app_form_fields.dart';
import 'package:boilerplate/core/widgets/app_dropdowns.dart';
import 'package:boilerplate/core/widgets/date_picker_field.dart';
import 'package:boilerplate/domain/entity/dcr/dcr.dart';
import 'package:boilerplate/domain/repository/dcr/dcr_repository.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/domain/repository/tour_plan/tour_plan_repository.dart';
import 'package:boilerplate/data/network/apis/user/lib/domain/entity/tour_plan/tour_plan_api_models.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boilerplate/presentation/common/map_picker_screen.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';

class DcrEntryScreen extends StatefulWidget {
  final String? dcrId; // Optional DCR ID for editing existing DCR
  final String? id; // Optional ID for editing existing DCR
  final DcrEntry? initialEntry; // Optional initial data for immediate prefill
  // Optional initial IDs from upstream (e.g., Tour Plan) to avoid name->ID lookup failures
  final int? initialCustomerId;
  final int? initialClusterId; // AKA cityId in API
  final int? initialTypeOfWorkId;
  
  const DcrEntryScreen({
    super.key,
    this.dcrId,
    this.id,
    this.initialEntry,
    this.initialCustomerId,
    this.initialClusterId,
    this.initialTypeOfWorkId,
  });

  @override
  State<DcrEntryScreen> createState() => _DcrEntryScreenState();
}

class _DcrEntryScreenState extends State<DcrEntryScreen> {
  String? _cluster;
  String? _customer;
  String? _purpose;
  bool _atLocation = true; // mock geo indicator
  bool _coVisit = false; // Co Visit checkbox
  bool _isSavingDraft = false; // Loading state for save draft
  bool _isSubmitting = false; // Loading state for submit
  bool _isLoadingClusters = false; // Loading state for clusters
  bool _isLoadingDcrDetails = false; // Loading state for DCR details (edit mode)
  List<String> _clusters = []; // Dynamic cluster list
  final Map<String, int> _clusterNameToId = <String, int>{}; // Map cluster names to IDs
  String? _clusterError; // Error message for cluster loading
  
  // Customer and purpose options (dynamic from API)
  List<String> _customerOptions = [];
  List<String> _purposeOptions = [];
  final Map<String, int> _typeOfWorkNameToId = <String, int>{};
  final Map<int, String> _typeOfWorkIdToName = <int, String>{}; // Reverse mapping for pre-filling (same as tour plan form)
  final Map<String, int> _customerNameToId = <String, int>{};
  int _purposeVersion = 0; // Version counter to force dropdown rebuild
  int? _loadedTypeOfWorkId; // Store typeOfWorkId from loaded DCR entry for editing
  
  final TextEditingController _durationCtrl = TextEditingController();
  final TextEditingController _productsCtrl = TextEditingController();
  final TextEditingController _samplesCtrl = TextEditingController();
  final TextEditingController _discussionCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now(); // Initialize to current time
  Position? _position;
  String? _clusterErrorText;
  String? _customerErrorText;
  String? _purposeErrorText;
  String? _durationErrorText;
  
  // Store loaded entry for preserving detailId and clusterId during updates
  DcrEntry? _loadedEntry;

  @override
  void initState() {
    super.initState();
    
    // Show loader immediately if we're in edit mode (when edit icon is clicked)
    if (widget.dcrId != null || widget.id != null) {
      _isLoadingDcrDetails = true;
    }
    
    // If initial entry is provided, prefill immediately (instant UX)
    // Same approach as edit tour plan form (new_tour_plan_screen.dart lines 237-251)
    if (widget.initialEntry != null) {
      final e = widget.initialEntry!;
      _cluster = e.cluster;
      _customer = e.customer;
      // Set purpose using reverse mapping if available, else mark as Loading... (EXACT same as tour plan form line 250)
      // This matches the edit tour plan form behavior exactly: _typeOfWorkIdToName[detail.typeOfWorkId] ?? (detail.typeOfWorkId > 0 ? 'Loading...' : null)
      if (widget.initialTypeOfWorkId != null && widget.initialTypeOfWorkId! > 0) {
        // Try to get from mapping if already loaded (shouldn't happen in initState, but check anyway)
        // Otherwise, set to "Loading..." which will be resolved after typeOfWork list loads (same as tour plan form)
        _purpose = _typeOfWorkIdToName[widget.initialTypeOfWorkId] ?? 'Loading...';
        print('DcrEntryScreen: Set purpose to "${_purpose}" for initialTypeOfWorkId: ${widget.initialTypeOfWorkId} (will resolve after typeOfWork list loads)');
      } else {
        // Fallback to purposeOfVisit from entry if no typeOfWorkId provided
        _purpose = e.purposeOfVisit.trim().isNotEmpty ? e.purposeOfVisit : null;
      }
      _durationCtrl.text = e.callDurationMinutes.toString();
      _productsCtrl.text = e.productsDiscussed;
      _samplesCtrl.text = e.samplesDistributed;
      _discussionCtrl.text = e.keyDiscussionPoints;
      _date = e.date;
      _time = TimeOfDay(hour: e.date.hour, minute: e.date.minute);
    }

    // Seed name->ID maps early if upstream provided IDs so validation doesn't fail
    if (_customer != null && _customer!.trim().isNotEmpty && widget.initialCustomerId != null) {
      _customerNameToId[_customer!] = widget.initialCustomerId!;
      if (!_customerOptions.contains(_customer)) {
        _customerOptions = {..._customerOptions, _customer!}.toList();
      }
    }
    if (_cluster != null && _cluster!.trim().isNotEmpty && widget.initialClusterId != null) {
      _clusterNameToId[_cluster!] = widget.initialClusterId!;
      if (!_clusters.contains(_cluster)) {
        _clusters = {..._clusters, _cluster!}.toList();
      }
    }

    // Load lists first so when details arrive we can map reliably
    // IMPORTANT: Load typeOfWork list FIRST if we have initialTypeOfWorkId to resolve purpose immediately
    if (widget.initialTypeOfWorkId != null && widget.initialTypeOfWorkId! > 0) {
      // Load typeOfWork list first to resolve purpose before other lists
      _loadTypeOfWorkList().then((_) {
        // Then load other lists in parallel
        Future.wait([
          _loadClusterList(),
          _initLocation(),
        ]).whenComplete(() {
          // Load customers after clusters are loaded (if cluster is already selected)
          if (_cluster != null && _cluster!.trim().isNotEmpty) {
            _loadMappedCustomers();
          }
          _loadDcrDetails();
        });
      });
    } else {
      // No initialTypeOfWorkId, load all lists in parallel
      Future.wait([
        _loadClusterList(),
        _loadTypeOfWorkList(),
        _initLocation(),
      ]).whenComplete(() {
        // Load customers after clusters are loaded (if cluster is already selected)
        if (_cluster != null && _cluster!.trim().isNotEmpty) {
          _loadMappedCustomers();
        }
        _loadDcrDetails();
      });
    }
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      if (!mounted) return;
      setState(() {
        _position = pos;
      });
    } catch (_) {}
  }

  Future<void> _loadClusterList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        const int countryId = 208;
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
        final int? employeeId = userStore?.userDetail?.employeeId;
        final List<CommonDropdownItem> items = await repo.getClusterList(countryId, employeeId!);
        final clusters = items.map((e) => (e.text.isNotEmpty ? e.text : e.cityName).trim()).where((s) => s.isNotEmpty).toSet();
        if (clusters.isNotEmpty) {
          setState(() {
            _clusters = {..._clusters, ...clusters}.toList();
            // map names to ids for submit
            for (final item in items) {
              final String key = (item.text.isNotEmpty ? item.text : item.cityName).trim();
              if (key.isNotEmpty) _clusterNameToId[key] = item.id;
            }
            // If editing and selected cluster not in list, add it so it shows up
            if (_cluster != null && _cluster!.trim().isNotEmpty && !_clusters.contains(_cluster)) {
              _clusters = {..._clusters, _cluster!}.toList();
            }
          });
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _loadMappedCustomers() async {
    try {
      print('DcrEntryScreen: [Customers] Start loading mapped customers');
      if (!getIt.isRegistered<TourPlanRepository>()) {
        print('DcrEntryScreen: [Customers] TourPlanRepository not registered - skipping');
        return;
      }
      
      // If no cluster is selected, clear customers and return
      if (_cluster == null || _cluster!.trim().isEmpty) {
        print('DcrEntryScreen: [Customers] No cluster selected - clearing customers');
        setState(() {
          _customerOptions = [];
          _customerNameToId.clear();
          // Keep existing customer selection if it was set from initialEntry
        });
        return;
      }
      
      final repo = getIt<TourPlanRepository>();
      final userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
      final int? employeeId = userStore?.userDetail?.employeeId;
      if (employeeId == null) {
        print('DcrEntryScreen: [Customers] employeeId is null - skipping');
        return;
      }

      // Get cluster ID from the selected cluster name
      final int? clusterId = _clusterNameToId[_cluster];
      if (clusterId == null || clusterId <= 0) {
        print('DcrEntryScreen: [Customers] Invalid cluster ID for cluster: $_cluster');
        setState(() {
          _customerOptions = [];
          _customerNameToId.clear();
        });
        return;
      }

      // Build ClusterIds array with the selected cluster
      final List<ClusterIdModel> selectedClusterIds = [
        ClusterIdModel(clusterId: clusterId),
      ];

      print('DcrEntryScreen: [Customers] Selected cluster: $_cluster');
      print('DcrEntryScreen: [Customers] Cluster ID: $clusterId');

      // Use current date (yyyy-MM-dd)
      final String dateStr = _date.toIso8601String().split('T').first;

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
      
      print('DcrEntryScreen: [Customers] Request body => ${req.toJson()}');
      final res = await repo.getMappedCustomersByEmployeeId(req);
      print('DcrEntryScreen: [Customers] API returned ${res.customers.length} customers');
      
      if (res.customers.isEmpty) {
        print('DcrEntryScreen: [Customers] No customers found for selected cluster');
        setState(() {
          // Keep existing customer if it was set, but clear options
          _customerOptions = [];
          _customerNameToId.clear();
        });
        return;
      }

      setState(() {
        // Clear old customer options
        final String? existingCustomer = _customer;
        _customerOptions = [];
        _customerNameToId.clear();
        
        // Populate with new customers from API
        for (final mc in res.customers) {
          _customerOptions.add(mc.customerName);
          _customerNameToId[mc.customerName] = mc.customerId;
        }
        
        // Remove duplicates and sort
        _customerOptions = _customerOptions.toSet().toList();
        _customerOptions.sort();
        
        // If editing and existing customer is in the new list, keep it selected
        // Otherwise, if it's not in the list, try to preserve it
        if (existingCustomer != null && existingCustomer.trim().isNotEmpty) {
          if (_customerOptions.contains(existingCustomer)) {
            _customer = existingCustomer;
          } else {
            // Customer not in new list, add it if we have its ID
            if (_customerNameToId.containsKey(existingCustomer)) {
              _customerOptions.add(existingCustomer);
              _customerOptions.sort();
            } else {
              // Keep the customer but mark it as potentially invalid
              _customer = existingCustomer;
            }
          }
        }
      });
      
      print('DcrEntryScreen: [Customers] Loaded ${_customerOptions.length} customers');
    } catch (e) {
      print('DcrEntryScreen: [Customers] Error loading customers: $e');
      // Silent fail - don't clear existing customers on error
    }
  }

  /// Resolve purpose from typeOfWorkId (extracted as separate method for reusability)
  void _resolvePurposeFromTypeOfWorkId(int typeOfWorkId) {
    print('DcrEntryScreen: Resolving purpose from typeOfWorkId (same as tour plan form)');
    print('  - Current purpose: "$_purpose"');
    print('  - typeOfWorkId to resolve: $typeOfWorkId');
    print('  - Source: ${widget.initialTypeOfWorkId == typeOfWorkId ? "initialTypeOfWorkId" : "loadedTypeOfWorkId (edit mode)"}');
    print('  - typeOfWorkIdToName map: $_typeOfWorkIdToName');
    
    // Get purpose name from reverse mapping
    final purposeName = _typeOfWorkIdToName[typeOfWorkId];
    if (purposeName != null && purposeName.isNotEmpty) {
      setState(() {
        // ALWAYS set purpose from API value (ensures it's always correct)
        final previousPurpose = _purpose;
        _purpose = purposeName;
        
        // Increment version to force dropdown rebuild
        _purposeVersion++;
        
        // Ensure purpose is in options list
        if (!_purposeOptions.contains(purposeName)) {
          _purposeOptions = {..._purposeOptions, purposeName}.toList();
        }
        
        // Update the name-to-ID map with correct ID
        _typeOfWorkNameToId[purposeName] = typeOfWorkId;
        
        if (previousPurpose != purposeName) {
          print('DcrEntryScreen: ✓ Updated purpose from "$previousPurpose" to "$purposeName" (ID: $typeOfWorkId)');
        } else {
          print('DcrEntryScreen: ✓ Purpose already correct: "$purposeName" (ID: $typeOfWorkId)');
        }
        print('DcrEntryScreen: Purpose set to: "$_purpose"');
        print('DcrEntryScreen: Purpose in options: ${_purposeOptions.contains(purposeName)}');
        print('DcrEntryScreen: Purpose version incremented to: $_purposeVersion');
      });
    } else {
      print('DcrEntryScreen: ⚠ Could not find purpose name for typeOfWorkId: $typeOfWorkId');
      print('DcrEntryScreen: Available IDs in map: ${_typeOfWorkIdToName.keys.toList()}');
      // Log all available mappings for debugging
      _typeOfWorkIdToName.forEach((id, name) {
        print('DcrEntryScreen:   ID $id -> "$name"');
      });
    }
  }

  Future<void> _loadTypeOfWorkList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        final List<CommonDropdownItem> items = await repo.getTypeOfWorkList();
        final works = items
            .map((e) => (e.text.isNotEmpty ? e.text : e.typeText).trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        if (works.isNotEmpty) {
          setState(() {
            _purposeOptions = {..._purposeOptions, ...works}.toList();
            // map names to ids for submit (same logic as tour plan form - line 828-833)
            for (final item in items) {
              final String key = (item.text.isNotEmpty ? item.text : item.typeText).trim();
              if (key.isNotEmpty) {
                _typeOfWorkNameToId[key] = item.id;
                _typeOfWorkIdToName[item.id] = key; // Reverse mapping for pre-filling (same as tour plan form line 832)
              }
            }
            
            // Resolve purpose names from initialTypeOfWorkId OR loadedTypeOfWorkId (for editing)
            // ALWAYS resolve purpose from typeOfWorkId to ensure it matches API value
            final int? typeOfWorkIdToResolve = widget.initialTypeOfWorkId ?? _loadedTypeOfWorkId;
            if (typeOfWorkIdToResolve != null && typeOfWorkIdToResolve > 0) {
              _resolvePurposeFromTypeOfWorkId(typeOfWorkIdToResolve);
            }
            
            // Fallback: If purpose was set from initialEntry but not in options, try case-insensitive match
            if (_purpose != null && _purpose!.trim().isNotEmpty && !_purposeOptions.contains(_purpose)) {
              // Try case-insensitive matching
              bool found = false;
              for (final option in _purposeOptions) {
                if (_purpose!.trim().toLowerCase() == option.toLowerCase()) {
                  _purpose = option; // Use exact match from API
                  found = true;
                  print('DcrEntryScreen: Matched purpose case-insensitively: "$option"');
                  break;
                }
              }
              // If still not found, add it to options (fallback)
              if (!found) {
                _purposeOptions = {..._purposeOptions, _purpose!}.toList();
                print('DcrEntryScreen: Added purpose to options list (fallback): $_purpose');
              }
            }
            
            print('DcrEntryScreen: Final purpose value after resolution: "$_purpose"');
            print('DcrEntryScreen: Purpose options count: ${_purposeOptions.length}');
            print('DcrEntryScreen: Purpose is in options: ${_purpose != null && _purposeOptions.contains(_purpose)}');
          });
          
          // Force a rebuild after resolving purpose to ensure UI updates
          // The setState is already called above, but we increment _purposeVersion to force dropdown rebuild
        }
      }
    } catch (e) {
      print('DcrEntryScreen: Error in _loadTypeOfWorkList: $e');
      // Silent fail
    }
  }

  Future<void> _loadDcrDetails() async {
    // Only load DCR details if we have a DCR ID (editing existing DCR)
    if (widget.dcrId == null && widget.id == null) {
      print('Creating new DCR - no API call needed');
      // Clear loading state if we're not in edit mode
      if (mounted) {
        setState(() {
          _isLoadingDcrDetails = false;
        });
      }
      return;
    }

    // Loading state is already set in initState() when edit mode is detected
    try {
      final DcrRepository? dcrRepo = getIt.isRegistered<DcrRepository>() ? getIt<DcrRepository>() : null;
      if (dcrRepo != null && widget.id != null) {
        // For GET request: use widget.id (detail ID) as Id parameter, widget.dcrId as DCRId parameter
        // The API expects: Id=detailId&DCRId=dcrId
        print('Loading DCR details - widget.id (detail): ${widget.id}, widget.dcrId (parent): ${widget.dcrId}');
        final DcrEntry? dcrEntry = await dcrRepo.getById(widget.id!, dcrId: widget.dcrId);
        if (dcrEntry != null) {
          print('DCR Details loaded:');
          print('  Entry.id (DCR Parent ID): ${dcrEntry.id}');
          print('  Entry.detailId (TourPlanDCRDetails ID): ${dcrEntry.detailId}');
          print('  Customer: ${dcrEntry.customer}');
          print('  Purpose: ${dcrEntry.purposeOfVisit}');
          print('  Cluster: ${dcrEntry.cluster}');
          print('  Products: ${dcrEntry.productsDiscussed}');
          print('  Samples: ${dcrEntry.samplesDistributed}');
          print('  Discussion: ${dcrEntry.keyDiscussionPoints}');
          print('  Date: ${dcrEntry.date}');
          print('  Duration: ${dcrEntry.callDurationMinutes}');
          print('  Customer Latitude: ${dcrEntry.customerLatitude}');
          print('  Customer Longitude: ${dcrEntry.customerLongitude}');
          print('  ClusterId: ${dcrEntry.clusterId}');
          print('  TypeOfWorkId: ${dcrEntry.typeOfWorkId}');
          print('  CityId: ${dcrEntry.cityId}');
          print('  CustomerId: ${dcrEntry.customerId}');
          
          // Store the loaded entry for preserving detailId and clusterId during updates
          _loadedEntry = dcrEntry;
          
          // Store typeOfWorkId from loaded DCR entry to resolve purpose after typeOfWork list loads
          if (dcrEntry.typeOfWorkId != null && dcrEntry.typeOfWorkId! > 0) {
            _loadedTypeOfWorkId = dcrEntry.typeOfWorkId;
            print('DcrEntryScreen: Stored typeOfWorkId from loaded DCR: $_loadedTypeOfWorkId (will resolve purpose after typeOfWork list loads)');
          }
          
          // Populate the form fields with the loaded data
          setState(() {
            _cluster = dcrEntry.cluster.isNotEmpty ? dcrEntry.cluster : _cluster;
            _customer = dcrEntry.customer.isNotEmpty ? dcrEntry.customer : _customer;
            // Set purpose to "Loading..." if we have typeOfWorkId, otherwise use purposeOfVisit
            // This will be resolved after typeOfWork list loads (same as tour plan form)
            if (_loadedTypeOfWorkId != null && _loadedTypeOfWorkId! > 0) {
              _purpose = 'Loading...';
              print('DcrEntryScreen: Set purpose to "Loading..." for typeOfWorkId: $_loadedTypeOfWorkId (will resolve after typeOfWork list loads)');
            } else {
              _purpose = dcrEntry.purposeOfVisit.isNotEmpty ? dcrEntry.purposeOfVisit : _purpose;
            }
            _durationCtrl.text = dcrEntry.callDurationMinutes.toString();
            _productsCtrl.text = dcrEntry.productsDiscussed;
            _samplesCtrl.text = dcrEntry.samplesDistributed;
            _discussionCtrl.text = dcrEntry.keyDiscussionPoints;
            _date = dcrEntry.date;
            // Set time from date if available
            _time = TimeOfDay(hour: dcrEntry.date.hour, minute: dcrEntry.date.minute);
            
            // Set location if available
            if (dcrEntry.customerLatitude != null && dcrEntry.customerLongitude != null) {
              print('Setting position from DCR data: Lat=${dcrEntry.customerLatitude}, Lng=${dcrEntry.customerLongitude}');
              _position = Position(
                latitude: dcrEntry.customerLatitude!,
                longitude: dcrEntry.customerLongitude!,
                timestamp: DateTime.now(),
                accuracy: 0,
                altitude: 0,
                heading: 0,
                speed: 0,
                speedAccuracy: 0,
                altitudeAccuracy: 0,
                headingAccuracy: 0,
              );
            } else {
              print('No latitude/longitude data found in DCR entry');
            }
            
            // Ensure current values appear in dropdowns and seed the name-to-ID maps
            if (_cluster != null && _cluster!.trim().isNotEmpty) {
              if (!_clusters.contains(_cluster)) { 
                _clusters = {..._clusters, _cluster!}.toList(); 
              }
              // Use the actual clusterId from the loaded entry if available
              if (!_clusterNameToId.containsKey(_cluster)) {
                if (dcrEntry.clusterId != null && dcrEntry.clusterId! > 0) {
                  _clusterNameToId[_cluster!] = dcrEntry.clusterId!;
                } else if (dcrEntry.cityId != null && dcrEntry.cityId! > 0) {
                  _clusterNameToId[_cluster!] = dcrEntry.cityId!;
                } else {
                  _clusterNameToId[_cluster!] = 1; // Fallback default ID
                }
              }
            }
            if (_customer != null && _customer!.trim().isNotEmpty) {
              if (!_customerOptions.contains(_customer)) { 
                _customerOptions = {..._customerOptions, _customer!}.toList(); 
              }
              // Use the actual customerId from the loaded entry if available
              if (!_customerNameToId.containsKey(_customer)) {
                if (dcrEntry.customerId != null && dcrEntry.customerId! > 0) {
                  _customerNameToId[_customer!] = dcrEntry.customerId!;
                } else {
                  _customerNameToId[_customer!] = 1; // Fallback default ID
                }
              }
            }
            // Don't add "Loading..." to options - it will be resolved after typeOfWork list loads
            if (_purpose != null && _purpose!.trim().isNotEmpty && _purpose != 'Loading...') {
              if (!_purposeOptions.contains(_purpose)) { 
                _purposeOptions = {..._purposeOptions, _purpose!}.toList(); 
              }
              // If we have typeOfWorkId from loaded entry, use it to seed the map
              if (_loadedTypeOfWorkId != null && _loadedTypeOfWorkId! > 0) {
                _typeOfWorkNameToId[_purpose!] = _loadedTypeOfWorkId!;
              } else if (!_typeOfWorkNameToId.containsKey(_purpose)) {
                _typeOfWorkNameToId[_purpose!] = 1; // Fallback default ID
              }
            }
          });
          
          // Load customers for the selected cluster in edit mode
          if (_cluster != null && _cluster!.trim().isNotEmpty) {
            print('DcrEntryScreen: Loading customers for cluster: $_cluster');
            _loadMappedCustomers();
          }
          
          // If we have _loadedTypeOfWorkId and typeOfWork list is already loaded, resolve purpose now
          if (_loadedTypeOfWorkId != null && _loadedTypeOfWorkId! > 0 && _typeOfWorkIdToName.isNotEmpty) {
            print('DcrEntryScreen: Resolving purpose from _loadedTypeOfWorkId after DCR details loaded');
            _resolvePurposeFromTypeOfWorkId(_loadedTypeOfWorkId!);
          }
          
          // Log the form field values after setting them
          print('Form fields set:');
          print('  _cluster: $_cluster');
          print('  _customer: $_customer');
          print('  _purpose: $_purpose');
          print('  _durationCtrl.text: ${_durationCtrl.text}');
          print('  _productsCtrl.text: ${_productsCtrl.text}');
          print('  _samplesCtrl.text: ${_samplesCtrl.text}');
          print('  _discussionCtrl.text: ${_discussionCtrl.text}');
          print('  _date: $_date');
          print('  _time: $_time');
          print('  _position: ${_position?.latitude}, ${_position?.longitude}');
        } else {
          print('No DCR found with ID: ${widget.id}');
          // Show error message to user
          if (mounted) {
            ToastMessage.show(
              context,
              message: 'DCR not found with ID: ${widget.id}',
              type: ToastType.warning,
              useRootNavigator: true,
              duration: const Duration(seconds: 3),
            );
          }
        }
      }
    } catch (e) {
      print('Error loading DCR details: $e');
      // Show error message to user
      if (mounted) {
        // Extract user-friendly error message
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        ToastMessage.show(
          context,
          message: 'Error loading DCR details: $errorMessage',
          type: ToastType.error,
          useRootNavigator: true,
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      // Clear loading state
      if (mounted) {
        setState(() {
          _isLoadingDcrDetails = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    final InputBorder commonBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade300),
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
          horizontal: MediaQuery.of(context).size.width > 600 ? 16 : 14,
          vertical: MediaQuery.of(context).size.width > 600 ? 16 : 14,
        ),
      ),
    );
    
    const Color tealGreen = Color(0xFF4db1b3);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.dcrId != null ? 'Edit DCR' : 'New DCR',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFF4db1b3),
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: _isLoadingDcrDetails
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading DCR details...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            : Theme(
                data: screenTheme,
                child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.of(context).size.width < 600 ? 12 : 16, 
              12, 
              MediaQuery.of(context).size.width < 600 ? 12 : 16, 
              16 + MediaQuery.of(context).padding.bottom
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // DCR Details Card
                    Card(
                      color: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 16.0 : 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'DCR Details',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                                fontSize: MediaQuery.of(context).size.width < 600 ? 20 : null,
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Date and Time row
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool stack = constraints.maxWidth < 500;
                                final dateField = _LabeledField(
                                  label: 'DCR Date',
                                  child: _DateField(
                                    initialDate: _date,
                                    onChanged: (d) => setState(() => _date = d),
                                  ),
                                );
                                final timeField = _LabeledField(
                                  label: 'Time of Visit',
                                  child: _TimeField(
                                    initial: _time,
                                    onChanged: (t) => setState(() => _time = t),
                                  ),
                                );
                                
                                if (stack) {
                                  return Column(
                                    children: [
                                      dateField,
                                      const SizedBox(height: 16),
                                      timeField,
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: dateField),
                                    const SizedBox(width: 16),
                                    Expanded(child: timeField),
                                  ],
                                );
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Cluster/Locality
                            _LabeledField(
                              label: 'Cluster/city',
                              required: true,
                              errorText: _clusterErrorText,
                              child: SearchableDropdown(
                                options: _clusters,
                                value: _cluster,
                                hintText: 'Select cluster',
                                searchHintText: 'Search cluster...',
                                hasError: _clusterErrorText != null,
                                onChanged: (v) {
                                  setState(() {
                                    _cluster = v;
                                    _clusterErrorText = null;
                                    // Clear customer selection when cluster changes
                                    _customer = null;
                                    _customerErrorText = null;
                                  });
                                  // Load customers for the selected cluster
                                  _loadMappedCustomers();
                                },
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Customer
                            _LabeledField(
                              label: 'Customer',
                              required: true,
                              errorText: _customerErrorText,
                              child: SearchableDropdown(
                                options: _customerOptions,
                                value: _customer,
                                hintText: 'Select customer',
                                searchHintText: 'Search customer...',
                                hasError: _customerErrorText != null,
                                onChanged: (v) => setState(() {
                                  _customer = v;
                                  _customerErrorText = null;
                                }),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Purpose and Duration row
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool stack = constraints.maxWidth < 500;
                                final purpose = _LabeledField(
                                  label: 'Purpose of Visit',
                                  required: true,
                                  errorText: _purposeErrorText,
                                  child: SearchableDropdown(
                                    key: ValueKey('purpose_${_purpose ?? 'null'}_${_purposeOptions.length}_v$_purposeVersion'), // Force rebuild when purpose, options, or version changes
                                    options: _purposeOptions,
                                    value: _purpose,
                                    hintText: 'Select purpose',
                                    searchHintText: 'Search purpose...',
                                    hasError: _purposeErrorText != null,
                                    onChanged: (v) {
                                      print('DcrEntryScreen: Purpose changed to: "$v"');
                                      setState(() {
                                        _purpose = v;
                                        _purposeErrorText = null;
                                        print('DcrEntryScreen: Purpose updated in state: "$_purpose"');
                                      });
                                    },
                                  ),
                                );
                                final duration = _LabeledField(
                                  label: 'Call Duration (minutes) (optional)',
                                  errorText: _durationErrorText,
                                  child: TextFormField(
                                    controller: _durationCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 15',
                                      filled: true,
                                      fillColor: Colors.white,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: _durationErrorText != null ? Colors.red.shade400 : Colors.grey.shade300, width: 1),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: _durationErrorText != null ? Colors.red.shade400 : const Color(0xFF4db1b3), width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                    onChanged: (_) => setState(() => _durationErrorText = null),
                                  ),
                                );
                                
                                if (stack) {
                                  return Column(
                                    children: [
                                      purpose,
                                      const SizedBox(height: 16),
                                      duration,
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: purpose),
                                    const SizedBox(width: 16),
                                    Expanded(child: duration),
                                  ],
                                );
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Products Discussed
                            _LabeledField(
                              label: 'Products to Discuss (optional)',
                              child: TextFormField(
                                controller: _productsCtrl,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  hintText: 'Type Product details',
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Samples Distributed
                            _LabeledField(
                              label: 'Samples to Distribute (optional)',
                              child: TextFormField(
                                controller: _samplesCtrl,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  hintText: 'Type sample details',
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Key Discussion Points
                            _LabeledField(
                              label: 'Notes/Remarks (optional)',
                              child: TextFormField(
                                controller: _discussionCtrl,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  hintText: 'Type discussion points',
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 20),

                            // Location picker (moved to bottom) - responsive layout
                            _LabeledField(
                              label: 'Location (optional)',
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final isMobile = constraints.maxWidth < 600;
                                  
                                  if (isMobile) {
                                    // Mobile: Stack elements vertically
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _position == null
                                              ? 'No location selected'
                                              : 'Lat: ${_position!.latitude.toStringAsFixed(6)}, Lng: ${_position!.longitude.toStringAsFixed(6)}',
                                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () async {
                                                  final LatLng center = _position != null
                                                      ? LatLng(_position!.latitude, _position!.longitude)
                                                      : const LatLng(6.927079, 79.861244);
                                                  final LatLng? picked = await Navigator.of(context).push(
                                                    MaterialPageRoute(builder: (_) => MapPickerScreen(initial: center, title: 'Pick DCR Location', limitTo1KmDefault: true)),
                                                  );
                                                  if (picked != null && mounted) {
                                                    setState(() {
                                                      _position = Position(
                                                        latitude: picked.latitude,
                                                        longitude: picked.longitude,
                                                        timestamp: DateTime.now(),
                                                        accuracy: 0,
                                                        altitude: 0,
                                                        heading: 0,
                                                        speed: 0,
                                                        speedAccuracy: 0,
                                                        altitudeAccuracy: 0,
                                                        headingAccuracy: 0,
                                                      );
                                                    });
                                                  }
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: tealGreen,
                                                  side: const BorderSide(color: tealGreen, width: 1.5),
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                ),
                                                child: const Text('Pick on map'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: TextButton(
                                                onPressed: () async {
                                                  await _initLocation();
                                                },
                                                style: TextButton.styleFrom(
                                                  foregroundColor: tealGreen,
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                ),
                                                child: const Text('Use current'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  } else {
                                    // Desktop: Keep horizontal layout
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _position == null
                                                ? 'No location selected'
                                                : 'Lat: ${_position!.latitude.toStringAsFixed(6)}, Lng: ${_position!.longitude.toStringAsFixed(6)}',
                                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton(
                                          onPressed: () async {
                                            final LatLng center = _position != null
                                                ? LatLng(_position!.latitude, _position!.longitude)
                                                : const LatLng(6.927079, 79.861244);
                                            final LatLng? picked = await Navigator.of(context).push(
                                              MaterialPageRoute(builder: (_) => MapPickerScreen(initial: center, title: 'Pick DCR Location', limitTo1KmDefault: true)),
                                            );
                                            if (picked != null && mounted) {
                                              setState(() {
                                                _position = Position(
                                                  latitude: picked.latitude,
                                                  longitude: picked.longitude,
                                                  timestamp: DateTime.now(),
                                                  accuracy: 0,
                                                  altitude: 0,
                                                  heading: 0,
                                                  speed: 0,
                                                  speedAccuracy: 0,
                                                  altitudeAccuracy: 0,
                                                  headingAccuracy: 0,
                                                );
                                              });
                                            }
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: tealGreen,
                                            side: const BorderSide(color: tealGreen, width: 1.5),
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          ),
                                          child: const Text('Pick on map'),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: () async {
                                            await _initLocation();
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor: tealGreen,
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                                          ),
                                          child: const Text('Use current'),
                                        ),
                                      ],
                                    );
                                  }
                                },
                              ),
                            ),
                            
                            // Co Visit checkbox
                            Row(
                              children: [
                                Checkbox(
                                  value: _coVisit,
                                  onChanged: (value) => setState(() => _coVisit = value ?? false),
                                  activeColor: tealGreen,
                                ),
                                const Text('Co Visit'),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Action buttons - show in one row
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _isSavingDraft ? null : _saveDraft,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: tealGreen,
                                      side: BorderSide(color: tealGreen, width: 1.5),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: _isSavingDraft 
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('Save Draft'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _isSubmitting ? null : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: tealGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      elevation: 2,
                                    ),
                                    child: _isSubmitting 
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text('Submit'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Location Status Card - Hidden
                    // const SizedBox(height: 16),
                    // 
                    // Card(
                    //   color: Colors.white,
                    //   surfaceTintColor: Colors.transparent,
                    //   elevation: 2,
                    //   shape: RoundedRectangleBorder(
                    //     borderRadius: BorderRadius.circular(12),
                    //   ),
                    //   child: Padding(
                    //     padding: const EdgeInsets.all(16.0),
                    //     child: Row(
                    //       children: [
                    //         Icon(
                    //           _atLocation ? Icons.place : Icons.place_outlined,
                    //           color: _atLocation ? Colors.green : Colors.orange,
                    //         ),
                    //         const SizedBox(width: 8),
                    //         Expanded(
                    //           child: Text(
                    //             _atLocation ? 'At location' : 'Away from planned location',
                    //             style: theme.textTheme.bodyMedium,
                    //           ),
                    //         ),
                    //         TextButton(
                    //           onPressed: () => setState(() => _atLocation = !_atLocation),
                    //           child: const Text('Toggle (Demo)'),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.errorText,
    this.required = false,
  });
  final String label;
  final Widget child;
  final String? errorText;
  final bool required;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
            children: required
                ? [
                    TextSpan(
                      text: ' *',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 8),
        child,
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.red.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

// Removed local dropdown in favor of SingleSelectDropdown

class _DateField extends StatelessWidget {
  const _DateField({required this.initialDate, required this.onChanged});
  final DateTime initialDate;
  final ValueChanged<DateTime> onChanged;
  
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')}-${months[date.month - 1]}-${date.year}';
  }
  
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        hintText: _formatDate(initialDate),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
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
        if (picked != null) onChanged(picked);
      },
    );
  }
}

class _TimeField extends StatefulWidget {
  const _TimeField({required this.initial, required this.onChanged});
  final TimeOfDay initial;
  final ValueChanged<TimeOfDay> onChanged;
  
  @override
  State<_TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<_TimeField> {
  late TextEditingController _controller;
  late TimeOfDay _currentTime;
  
  @override
  void initState() {
    super.initState();
    _currentTime = widget.initial;
    // Initialize controller with empty text, will be set in build when context is available
    _controller = TextEditingController();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set the text after context is available
    if (_controller.text.isEmpty) {
      _controller.text = _currentTime.format(context);
    }
  }
  
  @override
  void didUpdateWidget(_TimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initial != oldWidget.initial && widget.initial != _currentTime) {
      _currentTime = widget.initial;
      _controller.text = _currentTime.format(context);
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      controller: _controller,
      decoration: InputDecoration(
        suffixIcon: const Icon(Icons.access_time, color: Colors.grey),
      ),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _currentTime,
          builder: (context, child) {
            final ThemeData base = Theme.of(context);
            const teal = Color(0xFF4db1b3);
            return Theme(
              data: base.copyWith(
                colorScheme: const ColorScheme.light(
                  primary: teal,
                  onPrimary: Colors.white,
                  onSurface: Colors.black87,
                ),
                timePickerTheme: TimePickerThemeData(
                  dialHandColor: teal,
                  dialBackgroundColor: teal.withOpacity(0.12),
                  hourMinuteColor: MaterialStateColor.resolveWith(
                    (states) => states.contains(MaterialState.selected)
                        ? teal
                        : Colors.grey.shade200,
                  ),
                  hourMinuteTextColor: MaterialStateColor.resolveWith(
                    (states) => states.contains(MaterialState.selected)
                        ? Colors.white
                        : Colors.black87,
                  ),
                  dayPeriodColor: MaterialStateColor.resolveWith(
                    (states) => states.contains(MaterialState.selected)
                        ? teal
                        : Colors.grey.shade200,
                  ),
                  dayPeriodTextColor: MaterialStateColor.resolveWith(
                    (states) => states.contains(MaterialState.selected)
                        ? Colors.white
                        : Colors.black87,
                  ),
                  entryModeIconColor: teal,
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(foregroundColor: teal),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            _currentTime = picked;
            _controller.text = picked.format(context);
          });
          widget.onChanged(picked);
        }
      },
    );
  }
}

// Submission handlers
extension on _DcrEntryScreenState {
  bool _validate({required bool forSubmit}) {
    bool isValid = true;
    String? firstMessage;

    String? clusterError;
    if (_cluster == null || _cluster!.trim().isEmpty) {
      clusterError = 'Please select a cluster / locality';
      isValid = false;
      firstMessage ??= 'Select a cluster / locality';
    }

    String? customerError;
    if (_customer == null || _customer!.trim().isEmpty) {
      customerError = 'Please select a customer';
      isValid = false;
      firstMessage ??= 'Select a customer';
    }

    String? purposeError;
    if (_purpose == null || _purpose!.trim().isEmpty || _purpose == 'Loading...') {
      purposeError = 'Please select purpose of visit';
      isValid = false;
      firstMessage ??= 'Select purpose of visit';
    }

    String? durationError;
    final String durationText = _durationCtrl.text.trim();
    if (durationText.isNotEmpty) {
      final int? parsed = int.tryParse(durationText);
      if (parsed == null || parsed < 0) {
        durationError = 'Enter a valid duration in minutes';
        isValid = false;
        firstMessage ??= 'Enter a valid call duration';
      }
    }

    if (forSubmit && !_atLocation) {
      isValid = false;
      firstMessage ??= 'Mark your visit as "At location" before submitting';
    }

    setState(() {
      _clusterErrorText = clusterError;
      _customerErrorText = customerError;
      _purposeErrorText = purposeError;
      _durationErrorText = durationError;
    });

    if (!isValid) {
      _showWarningSnack(firstMessage ?? 'Please review the highlighted fields');
      return false;
    }

    return true;
  }

  Future<void> _saveDraft() async {
    if (!_validate(forSubmit: false)) {
      return;
    }
    await _createOrSubmit(submit: false);
  }

  Future<void> _submit() async {
    if (!_validate(forSubmit: true)) {
      return;
    }
    await _createOrSubmit(submit: true);
  }

  Future<void> _createOrSubmit({required bool submit}) async {
    setState(() {
      if (submit) {
        _isSubmitting = true;
      } else {
        _isSavingDraft = true;
      }
    });

    try {
      // Get user data from UserStore
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
      final userDetail = userStore?.userDetail;
      
      if (userDetail == null) {
        throw Exception('User data not available. Please login again.');
      }

      // Get IDs from the name-to-ID maps, with fallbacks for editing
      int? typeOfWorkId = _typeOfWorkNameToId[_purpose] ?? widget.initialTypeOfWorkId;
      int? cityId = _clusterNameToId[_cluster] ?? widget.initialClusterId;
      int? customerId = _customerNameToId[_customer] ?? widget.initialCustomerId;
      
      // If we're editing and still don't have IDs, use fallback values
      if (widget.dcrId != null) {
        typeOfWorkId ??= 1; // Default fallback for editing
        cityId ??= 1; // Default fallback for editing
        customerId ??= 1; // Default fallback for editing
      }
      
      // Debug logging
      print('DCR Validation Debug:');
      print('  Purpose: $_purpose');
      print('  TypeOfWorkId from map: ${_typeOfWorkNameToId[_purpose]}');
      print('  InitialTypeOfWorkId: ${widget.initialTypeOfWorkId}');
      print('  Final typeOfWorkId: $typeOfWorkId');
      print('  Cluster: $_cluster');
      print('  CityId from map: ${_clusterNameToId[_cluster]}');
      print('  InitialClusterId: ${widget.initialClusterId}');
      print('  Final cityId: $cityId');
      print('  Customer: $_customer');
      print('  CustomerId from map: ${_customerNameToId[_customer]}');
      print('  InitialCustomerId: ${widget.initialCustomerId}');
      print('  Final customerId: $customerId');
      
      // Validate that we have all required IDs
      if (typeOfWorkId == null) {
        print('ERROR: No typeOfWorkId found for purpose: $_purpose');
        print('Available purposes in map: ${_typeOfWorkNameToId.keys.toList()}');
        throw Exception('Please select a valid purpose of visit');
      }
      if (cityId == null) {
        print('ERROR: No cityId found for cluster: $_cluster');
        print('Available clusters in map: ${_clusterNameToId.keys.toList()}');
        throw Exception('Please select a valid cluster/locality');
      }
      if (customerId == null) {
        print('ERROR: No customerId found for customer: $_customer');
        print('Available customers in map: ${_customerNameToId.keys.toList()}');
        throw Exception('Please select a valid customer');
      }

      final DateTime visit = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      final repo = getIt<DcrRepository>();
      
      // Create params with the IDs from UserStore and name-to-ID maps
      final params = CreateDcrParams(
        date: visit,
        cluster: _cluster!,
        customer: _customer!,
        purposeOfVisit: _purpose!,
        callDurationMinutes: int.tryParse(_durationCtrl.text.trim()) ?? 0,
        productsDiscussed: _productsCtrl.text.trim(),
        samplesDistributed: _samplesCtrl.text.trim(),
        keyDiscussionPoints: _discussionCtrl.text.trim(),
        linkedTourPlanId: widget.initialEntry?.linkedTourPlanId,
        employeeId: userDetail.employeeId.toString(),
        employeeName: userDetail.employeeName,
        submit: submit,
        geoProximity: _atLocation ? GeoProximity.at : GeoProximity.away,
        // Pass the IDs for API call
        typeOfWorkId: typeOfWorkId,
        cityId: cityId,
        customerId: customerId,
        userId: userDetail.id,
        bizunit: userDetail.sbuId,
        latitude: _position?.latitude,
        longitude: _position?.longitude,
      );
      
      print('Creating DCR: ${submit ? "Submit" : "Draft"}');
      print('User Data - EmployeeId: ${userDetail.employeeId}, UserId: ${userDetail.id}, Name: ${userDetail.employeeName}');
      print('Mapped IDs - TypeOfWorkId: $typeOfWorkId, CityId: $cityId, CustomerId: $customerId');
      
      if (widget.id != null || widget.dcrId != null) {
        // Update existing DCR via API
        // Use dcrId for root ID if available, otherwise use id
        // The root ID should be the DCR parent ID, not the detail ID
        final String dcrIdToUpdate = widget.dcrId ?? widget.id!;
        print('Updating DCR with detailId: ${_loadedEntry?.detailId}, clusterId: ${_loadedEntry?.clusterId}');
        print('Using dcrIdToUpdate: $dcrIdToUpdate (from widget.dcrId: ${widget.dcrId}, widget.id: ${widget.id})');
        final DcrEntry updated = DcrEntry(
          id: dcrIdToUpdate,
          date: visit, // Preserve the time component from visit DateTime
          cluster: _cluster!,
          customer: _customer!,
          purposeOfVisit: _purpose!,
          callDurationMinutes: int.tryParse(_durationCtrl.text.trim()) ?? 0,
          productsDiscussed: _productsCtrl.text.trim(),
          samplesDistributed: _samplesCtrl.text.trim(),
          keyDiscussionPoints: _discussionCtrl.text.trim(),
          status: submit ? DcrStatus.submitted : DcrStatus.draft,
          employeeId: userDetail.employeeId.toString(), 
          employeeName: userDetail.employeeName,
          linkedTourPlanId: _loadedEntry?.linkedTourPlanId,
          geoProximity: _atLocation ? GeoProximity.at : GeoProximity.away,
          createdAt: _loadedEntry?.createdAt,
          updatedAt: DateTime.now(),
          typeOfWorkId: typeOfWorkId,
          cityId: cityId,
          customerId: customerId,
          customerLatitude: _position?.latitude,
          customerLongitude: _position?.longitude,
          detailId: _loadedEntry?.detailId,
          clusterId: _loadedEntry?.clusterId,
        );
        print('Created DcrEntry for update with detailId: ${updated.detailId}, clusterId: ${updated.clusterId}');
        await repo.update(updated);
      } else {
        await repo.create(params);
      }
      
      if (!mounted) return;
      if (widget.id != null || widget.dcrId != null) {
        _showSuccessSnack(submit ? 'DCR updated & submitted successfully' : 'DCR updated successfully');
      } else {
        _showSuccessSnack(submit ? 'DCR submitted successfully' : 'Draft saved successfully');
      }
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      // Extract user-friendly error message
      String errorMessage = e.toString();
      // Remove "Exception: " prefix if present
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      _showErrorSnack(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          if (submit) {
            _isSubmitting = false;
          } else {
            _isSavingDraft = false;
          }
        });
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ToastMessage.show(
        context,
        message: msg,
        type: ToastType.info,
        useRootNavigator: true,
        duration: const Duration(seconds: 2),
      );
    });
  }

  void _showSuccessSnack(String msg) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ToastMessage.show(
        context,
        message: msg,
        type: ToastType.success,
        useRootNavigator: true,
        duration: const Duration(seconds: 3),
      );
    });
  }

  void _showErrorSnack(String msg) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ToastMessage.show(
        context,
        message: msg,
        type: ToastType.error,
        useRootNavigator: true,
        duration: const Duration(seconds: 4),
      );
    });
  }

  void _showWarningSnack(String msg) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ToastMessage.show(
        context,
        message: msg,
        type: ToastType.warning,
        useRootNavigator: true,
        duration: const Duration(seconds: 3),
      );
    });
  }
}


