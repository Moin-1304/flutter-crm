import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:boilerplate/core/widgets/app_buttons.dart';
import 'package:boilerplate/core/widgets/app_form_fields.dart';
import 'package:boilerplate/core/widgets/app_dropdowns.dart';
import 'package:boilerplate/core/widgets/date_picker_field.dart';
import 'package:boilerplate/domain/entity/dcr/dcr.dart';
import 'package:boilerplate/domain/repository/dcr/dcr_repository.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/data/network/apis/common/common_api.dart';
import 'package:boilerplate/core/data/network/dio/dio_client.dart';
import 'package:boilerplate/data/network/constants/endpoints.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:boilerplate/domain/repository/tour_plan/tour_plan_repository.dart';
import 'package:boilerplate/data/network/apis/user/lib/domain/entity/tour_plan/tour_plan_api_models.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'location_picker_map_screen.dart';

/// Max value for 32-bit signed int (backend UIN type). Max digits = 10.
const int _kUinMaxInt = 2147483647;
const int _kUinMaxDigits = 10;

/// Format DateTime for Service Report Save API. .NET expects ISO 8601 (e.g. 2026-02-18T17:08:18.163) for JSON DateTime.
String _formatServiceReportDateTimeForApi(DateTime d) {
  return d.toIso8601String();
}

// Service report enums and helpers
enum ServiceReportType {
  Installation,
  Service,
  Repair,
  Calibration,
  PM,
}

extension ServiceReportTypeX on ServiceReportType {
  /// Human-friendly description (like C# DescriptionAttribute)
  String get description {
    switch (this) {
      case ServiceReportType.Installation:
        return 'Installation';
      case ServiceReportType.Service:
        return 'Service';
      case ServiceReportType.Repair:
        return 'Repair';
      case ServiceReportType.Calibration:
        return 'Calibration';
      case ServiceReportType.PM:
        return 'PM';
    }
  }

  /// Integer value for backend mapping
  int get value {
    switch (this) {
      case ServiceReportType.Installation:
        return 1;
      case ServiceReportType.Service:
        return 2;
      case ServiceReportType.Repair:
        return 3;
      case ServiceReportType.Calibration:
        return 4;
      case ServiceReportType.PM:
        return 5;
    }
  }
}

// Electricity safety test enum
enum ElectricitySafetyTestStatus { Yes, No }

extension ElectricitySafetyTestStatusX on ElectricitySafetyTestStatus {
  String get description {
    switch (this) {
      case ElectricitySafetyTestStatus.Yes:
        return 'Yes';
      case ElectricitySafetyTestStatus.No:
        return 'No';
    }
  }

  int get value {
    switch (this) {
      case ElectricitySafetyTestStatus.Yes:
        return 1;
      case ElectricitySafetyTestStatus.No:
        return 2;
    }
  }
}

// Service report status enum
enum ServiceReportStatus { Resolved, NotResolved }

extension ServiceReportStatusX on ServiceReportStatus {
  String get description {
    switch (this) {
      case ServiceReportStatus.Resolved:
        return 'Resolved';
      case ServiceReportStatus.NotResolved:
        return 'Not Resolved';
    }
  }

  int get value {
    switch (this) {
      case ServiceReportStatus.Resolved:
        return 1;
      case ServiceReportStatus.NotResolved:
        return 2;
    }
  }
}

// Feedback status enum
enum ServiceFeedbackStatus { Bad, Good, Fair, Excellent }

extension ServiceFeedbackStatusX on ServiceFeedbackStatus {
  String get description {
    switch (this) {
      case ServiceFeedbackStatus.Bad:
        return 'Bad';
      case ServiceFeedbackStatus.Good:
        return 'Good';
      case ServiceFeedbackStatus.Fair:
        return 'Fair';
      case ServiceFeedbackStatus.Excellent:
        return 'Excellent';
    }
  }

  /// Emoji for feedback option (thumbs down, thumbs up, smile, star)
  String get emoji {
    switch (this) {
      case ServiceFeedbackStatus.Bad:
        return '👎';
      case ServiceFeedbackStatus.Good:
        return '👍';
      case ServiceFeedbackStatus.Fair:
        return '😊';
      case ServiceFeedbackStatus.Excellent:
        return '⭐';
    }
  }

  /// Border/accent color for feedback card (red, blue, yellow, green)
  Color get borderColor {
    switch (this) {
      case ServiceFeedbackStatus.Bad:
        return Colors.red;
      case ServiceFeedbackStatus.Good:
        return Colors.blue;
      case ServiceFeedbackStatus.Fair:
        return Colors.amber;
      case ServiceFeedbackStatus.Excellent:
        return Colors.green;
    }
  }

  int get value {
    switch (this) {
      case ServiceFeedbackStatus.Bad:
        return 1;
      case ServiceFeedbackStatus.Good:
        return 2;
      case ServiceFeedbackStatus.Fair:
        return 3;
      case ServiceFeedbackStatus.Excellent:
        return 4;
    }
  }
}

class DcrEntryScreen extends StatefulWidget {
  final String? dcrId; // Optional DCR ID for editing existing DCR
  final String? id; // Optional ID for editing existing DCR
  final DcrEntry? initialEntry; // Optional initial data for immediate prefill
  // Optional initial IDs from upstream (e.g., Tour Plan) to avoid name->ID lookup failures
  final int? initialCustomerId;
  final int? initialClusterId; // AKA cityId in API
  final int? initialTypeOfWorkId;

  /// When true, form is shown in read-only mode (same layout as edit, no save buttons).
  final bool viewOnly;

  /// When true (e.g. for submitted DCRs), Create DCR tab stays read-only but Service Report
  /// tab is editable and can be saved. Used with viewOnly for "View DCR + Edit Service Report".
  final bool allowServiceReportEditOnly;

  const DcrEntryScreen({
    super.key,
    this.dcrId,
    this.id,
    this.initialEntry,
    this.initialCustomerId,
    this.initialClusterId,
    this.initialTypeOfWorkId,
    this.viewOnly = false,
    this.allowServiceReportEditOnly = false,
  });

  @override
  State<DcrEntryScreen> createState() => _DcrEntryScreenState();
}

class _DcrEntryScreenState extends State<DcrEntryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool get _isViewOnly => widget.viewOnly;

  String? _cluster;
  String? _customer;
  String? _purpose;
  bool _atLocation = true; // mock geo indicator
  bool _coVisit = false; // Co Visit checkbox
  bool _isManager = false; // Manager role flag
  bool _isNewDcr = false; // Flag for new DCR form
  // Co-visit manager selection
  String? _selectedManager;
  List<String> _managerOptions = [];
  final Map<String, int> _managerNameToId = <String, int>{};
  bool _isLoadingManagers = false;
  String? _managerErrorText;
  bool _isSavingDraft = false; // Loading state for save draft
  bool _isSubmitting = false; // Loading state for submit
  bool _isLoadingClusters = false; // Loading state for clusters
  bool _isLoadingDcrDetails =
      false; // Loading state for DCR details (edit mode)
  List<String> _clusters = []; // Dynamic cluster list
  final Map<String, int> _clusterNameToId =
      <String, int>{}; // Map cluster names to IDs
  String? _clusterError; // Error message for cluster loading

  // Customer and purpose options (dynamic from API)
  List<String> _customerOptions = [];
  List<String> _purposeOptions = [];
  final Map<String, int> _typeOfWorkNameToId = <String, int>{};
  final Map<int, String> _typeOfWorkIdToName = <int,
      String>{}; // Reverse mapping for pre-filling (same as tour plan form)
  final Map<String, int> _customerNameToId = <String, int>{};
  int _purposeVersion = 0; // Version counter to force dropdown rebuild
  int?
      _loadedTypeOfWorkId; // Store typeOfWorkId from loaded DCR entry for editing

  final TextEditingController _durationCtrl = TextEditingController();
  final TextEditingController _samplesCtrl = TextEditingController();
  final TextEditingController _discussionCtrl = TextEditingController();

  // Products to Discuss - Multi-select dropdown
  List<String> _productOptions = [];
  final Map<String, int> _productNameToId = <String, int>{};
  Set<String> _selectedProducts = <String>{};
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now(); // Initialize to current time
  Position? _position;
  String? _clusterErrorText;
  String? _customerErrorText;
  String? _purposeErrorText;
  String? _durationErrorText;
  String? _productsErrorText;

  bool get _customerRequiredForSelectedVisitType {
    final p = _purpose?.trim().toLowerCase() ?? '';
    if (p.isEmpty || p == 'loading...') return true;
    // For these visit types, customer is not applicable.
    if (p.contains('training') || p.contains('meeting') || p.contains('conference')) {
      return false;
    }
    return true;
  }

  // Service Engineer specific fields
  bool _isServiceEngineer = false;
  List<String> _instrumentOptions = [];
  final Map<String, int> _instrumentNameToId = <String, int>{};
  Set<String> _selectedInstruments = <String>{};
  String? _instrumentsErrorText;
  final TextEditingController _complaintCtrl = TextEditingController();
  final TextEditingController _actionTakenCtrl = TextEditingController();
  final TextEditingController _resultCtrl = TextEditingController();
  String?
      _complaintStatus; // "Resolved" or "Not Resolved" (UI value, will be converted to int)
  DateTime? _complaintDate;
  final TextEditingController _complaintRemarksCtrl = TextEditingController();

  // Service Report fields (from image)
  String? _serviceReportCustomer;
  final TextEditingController _contactPersonCtrl = TextEditingController();
  final TextEditingController _contactMobileCtrl = TextEditingController();
  final TextEditingController _serviceDateCtrl = TextEditingController();
  DateTime? _serviceDate;
  // Signature storage (drawing as base64 for local display; uploaded path for API)
  String? _signatureImageBase64;
  String? _signatureValue;

  /// Uploaded signature image path from FilesUpload API (sent as SignatureImageUrl in Save).
  String? _signatureImageUrl;
  bool _isUploadingSignature = false;
  String? _serviceReportProduct;
  final TextEditingController _serialNumberCtrl = TextEditingController();
  String? _serviceType;
  ServiceReportType? _selectedServiceType;
  ElectricitySafetyTestStatus? _selectedElectricitySafetyTest;
  ServiceReportStatus? _selectedServiceReportStatus;
  ServiceFeedbackStatus? _selectedFeedbackOption;
  List<String> _serviceTypeOptions = [];
  final Map<String, int> _serviceTypeNameToId = <String, int>{};
  DateTime? _startTime;
  DateTime? _endTime;
  String? _electricitySafetyTest;
  int? _serviceReportId;

  /// Original CreatedDate from GET; sent back on Update to satisfy server.
  String? _serviceReportCreatedDate;
  List<String> _electricitySafetyOptions = [];
  final Map<String, int> _electricitySafetyNameToId = <String, int>{};
  DateTime? _complaintDateTime;
  final TextEditingController _serviceRateCtrl = TextEditingController();
  String? _serviceStatus;
  List<String> _serviceStatusOptions = [];
  final Map<String, int> _serviceStatusNameToId = <String, int>{};
  final TextEditingController _workDescriptionCtrl = TextEditingController();
  final TextEditingController _materialsUsedCtrl = TextEditingController();
  final TextEditingController _serviceRemarksCtrl = TextEditingController();
  String? _feedbackOption;
  List<String> _feedbackOptions = [];
  final Map<String, int> _feedbackNameToId = <String, int>{};
  final TextEditingController _signedByCtrl = TextEditingController();
  // Signature field - will be handled separately

  // Store loaded entry for preserving detailId and clusterId during updates
  DcrEntry? _loadedEntry;

  // Customer creation fields
  final TextEditingController _customerNameCtrl = TextEditingController();
  final TextEditingController _customerCodeCtrl = TextEditingController();
  final TextEditingController _uinCtrl = TextEditingController();
  String? _selectedCustomerType;
  List<String> _customerTypeOptions = [];
  final Map<String, int> _customerTypeNameToId = <String, int>{};
  final TextEditingController _customerMobileCtrl = TextEditingController();
  String? _selectedCountry;
  List<String> _countryOptions = [];
  final Map<String, int> _countryNameToId = <String, int>{};
  String? _selectedState;
  List<String> _stateOptions = [];
  final Map<String, int> _stateNameToId = <String, int>{};
  String? _selectedCity;
  List<String> _cityOptions = [];
  final Map<String, int> _cityNameToId = <String, int>{};
  // Medical Rep dropdowns (Customer tab)
  String? _selectedSpeciality;
  List<String> _specialityOptions = [];
  final Map<String, int> _specialityNameToId = <String, int>{};
  String? _selectedCategory;
  List<String> _categoryOptions = [];
  final Map<String, int> _categoryNameToId = <String, int>{};
  String? _selectedAreaType;
  List<String> _areaTypeOptions = [];
  final Map<String, int> _areaTypeNameToId = <String, int>{};

  @override
  void initState() {
    super.initState();

    // Initialize TabController with dynamic tab count:
    // - Manager creating new: only "Create DCR" (1 tab).
    // - Service Engineer (creating or updating): "Create DCR" + "Service Report" (2 tabs). No Customer tab.
    // - Updating DCR (any role): no Customer tab (customer cannot be updated). So 1 or 2 tabs.
    // - Creating new, not SE, not manager: "Create DCR" + "Customer" (2 tabs).
    final UserDetailStore? userStore =
        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final int? roleCategory = userStore?.userDetail?.roleCategory;
    final String? serviceArea = userStore?.userDetail?.serviceArea;
    _isServiceEngineer =
        serviceArea != null && serviceArea.trim() == 'Service Engineer';
    _isManager = roleCategory == 1 || roleCategory == 2;
    _isNewDcr = widget.dcrId == null && widget.id == null;

    int initialTabCount;
    if (_isManager && _isNewDcr) {
      initialTabCount = 1; // Only Create DCR
    } else if (_isServiceEngineer) {
      initialTabCount =
          2; // Create DCR + Service Report (no Customer tab ever for SE)
    } else if (!_isNewDcr) {
      initialTabCount =
          1; // Updating DCR: only Create DCR (no Customer tab for anyone)
    } else {
      initialTabCount = 2; // Creating new, not SE: Create DCR + Customer
    }
    _tabController = TabController(length: initialTabCount, vsync: this);
    // When user switches to Service Report tab, load mapped customers for service report
    _tabController.addListener(() {
      try {
        if (!_tabController.indexIsChanging && _tabController.index == 1) {
          // Load mapped customers for Service Report tab (no cluster filter)
          _loadMappedCustomersForServiceReport();
        }
      } catch (e) {
        print('DcrEntryScreen: Error in tab listener: $e');
      }
    });

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
      if (widget.initialTypeOfWorkId != null &&
          widget.initialTypeOfWorkId! > 0) {
        // Try to get from mapping if already loaded (shouldn't happen in initState, but check anyway)
        // Otherwise, set to "Loading..." which will be resolved after typeOfWork list loads (same as tour plan form)
        _purpose =
            _typeOfWorkIdToName[widget.initialTypeOfWorkId] ?? 'Loading...';
        print(
            'DcrEntryScreen: Set purpose to "${_purpose}" for initialTypeOfWorkId: ${widget.initialTypeOfWorkId} (will resolve after typeOfWork list loads)');
      } else {
        // Fallback to purposeOfVisit from entry if no typeOfWorkId provided
        _purpose = e.purposeOfVisit.trim().isNotEmpty ? e.purposeOfVisit : null;
      }
      _durationCtrl.text = e.callDurationMinutes.toString();
      // Parse products from comma-separated string (if any)
      if (e.productsDiscussed.trim().isNotEmpty) {
        _selectedProducts = e.productsDiscussed
            .split(',')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toSet();
      }
      _samplesCtrl.text = e.samplesDistributed;
      _discussionCtrl.text = e.keyDiscussionPoints;
      _date = e.date;
      _time = TimeOfDay(hour: e.date.hour, minute: e.date.minute);
    }

    // Seed name->ID maps early if upstream provided IDs so validation doesn't fail
    if (_customer != null &&
        _customer!.trim().isNotEmpty &&
        widget.initialCustomerId != null) {
      _customerNameToId[_customer!] = widget.initialCustomerId!;
      if (!_customerOptions.contains(_customer)) {
        _customerOptions = {..._customerOptions, _customer!}.toList();
      }
    }
    if (_cluster != null &&
        _cluster!.trim().isNotEmpty &&
        widget.initialClusterId != null) {
      _clusterNameToId[_cluster!] = widget.initialClusterId!;
      if (!_clusters.contains(_cluster)) {
        _clusters = {..._clusters, _cluster!}.toList();
      }
    }

    // Check if user is Service Engineer
    _checkServiceEngineer();

    // Pre-fill Service Date with today if not already set
    if (_serviceDate == null) {
      _serviceDate = DateTime.now();
      try {
        _serviceDateCtrl.text = _formatServiceDate(_serviceDate!);
      } catch (_) {
        // _formatServiceDate may be defined later; it's safe to ignore here
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
          _loadProductsList(),
          _loadCountries(),
          _loadCustomerTypes(),
          _loadMedicalRepDropdowns(),
          _loadServiceDropdowns(),
        ]).whenComplete(() {
          // Load customers after clusters are loaded (if cluster is already selected)
          if (_cluster != null && _cluster!.trim().isNotEmpty) {
            _loadMappedCustomers();
          }
          _loadDcrDetails();
        }).whenComplete(() {
          _loadInstrumentsList();
        });
      });
    } else {
      // No initialTypeOfWorkId, load all lists in parallel
      Future.wait([
        _loadClusterList(),
        _loadTypeOfWorkList(),
        _loadProductsList(),
        _loadCountries(),
        _loadCustomerTypes(),
        _loadMedicalRepDropdowns(),
        _loadServiceDropdowns(),
      ]).whenComplete(() {
        // Load customers after clusters are loaded (if cluster is already selected)
        if (_cluster != null && _cluster!.trim().isNotEmpty) {
          _loadMappedCustomers();
        }
        _loadDcrDetails();
      }).whenComplete(() {
        _loadInstrumentsList();
      });
    }
  }

  void _checkServiceEngineer() {
    final UserDetailStore? userStore =
        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final String? serviceArea = userStore?.userDetail?.serviceArea;
    _isServiceEngineer =
        serviceArea != null && serviceArea.trim() == 'Service Engineer';
    print(
        'DcrEntryScreen: Is Service Engineer: $_isServiceEngineer (serviceArea: "$serviceArea")');
  }

  Future<void> _loadManagerList() async {
    if (!_coVisit) {
      // Don't load if co-visit is not checked
      return;
    }

    setState(() {
      _isLoadingManagers = true;
      _managerErrorText = null;
    });

    try {
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        final int employeeId = userStore?.userDetail?.employeeId ?? 0;
        final List<CommonDropdownItem> items = await repo
            .getReportingManagerList(id: employeeId);
        if (items.isNotEmpty) {
          setState(() {
            _managerOptions = items
                .map((e) => e.text.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            // Map names to IDs for submit
            for (final item in items) {
              final String key = item.text.trim();
              if (key.isNotEmpty) _managerNameToId[key] = item.id;
            }
            _isLoadingManagers = false;
          });
        } else {
          setState(() {
            _managerOptions = [];
            _isLoadingManagers = false;
          });
        }
      }
    } catch (e) {
      print('DcrEntryScreen: [Managers] Error loading managers: $e');
      setState(() {
        _managerOptions = [];
        _isLoadingManagers = false;
        _managerErrorText = 'Failed to load managers';
      });
    }
  }

  Future<void> _loadInstrumentsList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
            ? getIt<UserDetailStore>()
            : null;

        // Wait for user to be loaded
        int retry = 0;
        while (userStore?.isUserLoaded != true && retry < 20) {
          await Future.delayed(const Duration(milliseconds: 300));
          retry++;
        }

        int? userId = userStore?.userDetail?.id;
        int? employeeId = userStore?.userDetail?.employeeId;
        String? serviceArea = userStore?.userDetail?.serviceArea;

        if (userId == null || userId <= 0) {
          print(
              'DcrEntryScreen: [Instruments] userId is null/0, skipping instruments load');
          return;
        }

        // For Service Engineer: use employeeId as UserId
        // For others: use userId as UserId (matches _loadProductsList logic)
        int? actualUserId = employeeId;

        if (serviceArea != null && serviceArea.trim() == 'Service Engineer') {
          if (employeeId != null && employeeId > 0) {
            actualUserId = employeeId;
            print(
                'DcrEntryScreen: [Instruments] Service Engineer detected - using employeeId: $actualUserId as UserId');
          } else {
            print(
                'DcrEntryScreen: [Instruments] Service Engineer but employeeId is null/0, using userId: $actualUserId');
          }
        } else {
          print(
              'DcrEntryScreen: [Instruments] Non-Service Engineer - using actualUserId: $actualUserId');
        }

        // Get selected customer ID - instruments are loaded based on selected customer
        int? customerId = _customerNameToId[_customer];
        print(
            'DcrEntryScreen: [Instruments] Selected customerId present: ${customerId != null && customerId > 0}');
        if (customerId == null || customerId <= 0) {
          print(
              'DcrEntryScreen: [Instruments] customerId is null/0, skipping instruments load');
          setState(() {
            _instrumentOptions.clear();
            _instrumentNameToId.clear();
          });
          return;
        }

        print(
            'DcrEntryScreen: [Instruments] Loading instruments with userId: $actualUserId, customerId: $customerId');
        final List<CommonDropdownItem> items =
            await repo.getMappedInstrumentsList(actualUserId ?? 0, customerId);

        if (items.isNotEmpty) {
          setState(() {
            _instrumentOptions.clear();
            _instrumentNameToId.clear();
            for (final item in items) {
              final String instrumentName =
                  (item.text.isNotEmpty ? item.text : item.name).trim();
              if (instrumentName.isNotEmpty) {
                _instrumentOptions.add(instrumentName);
                _instrumentNameToId[instrumentName] = item.id;
              }
            }
            _instrumentOptions.sort();
            print(
                'DcrEntryScreen: [Instruments] Loaded ${_instrumentOptions.length} instruments');
          });
        } else {
          print(
              'DcrEntryScreen: [Instruments] No instruments returned from API');
          setState(() {
            _instrumentOptions.clear();
            _instrumentNameToId.clear();
          });
        }
      }
    } catch (e) {
      print('DcrEntryScreen: [Instruments] Error loading instruments: $e');
      setState(() {
        _instrumentOptions.clear();
        _instrumentNameToId.clear();
      });
    }
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ToastMessage.show(context, message: 'Location services are disabled.', type: ToastType.error);
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ToastMessage.show(context, message: 'Location permission denied.', type: ToastType.error);
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ToastMessage.show(context, message: 'Location permission is permanently denied.', type: ToastType.error);
        }
        return;
      }
      
      // Show a temporary loading indicator while fetching position
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      
      if (!mounted) return;

      // Open Map Picker Screen to confirm location
      final confirmedPos = await Navigator.of(context).push<Position>(
        MaterialPageRoute(
          builder: (context) => LocationPickerMapScreen(initialPosition: pos),
        ),
      );

      if (confirmedPos != null && mounted) {
        setState(() {
          _position = confirmedPos;
        });
        ToastMessage.show(context, message: 'Location updated successfully.', type: ToastType.success);
      }
    } catch (e) {
      print('DcrEntryScreen: Error initializing location: $e');
    }
  }

  Future<void> _loadClusterList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        const int countryId = 208;
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
            ? getIt<UserDetailStore>()
            : null;
        final int? employeeId = userStore?.userDetail?.employeeId;
        final List<CommonDropdownItem> items =
            await repo.getClusterList(countryId, employeeId!);
        final clusters = items
            .map((e) => (e.text.isNotEmpty ? e.text : e.cityName).trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        if (clusters.isNotEmpty) {
          setState(() {
            _clusters = {..._clusters, ...clusters}.toList();
            // map names to ids for submit
            for (final item in items) {
              final String key =
                  (item.text.isNotEmpty ? item.text : item.cityName).trim();
              if (key.isNotEmpty) _clusterNameToId[key] = item.id;
            }
            // If editing and selected cluster not in list, add it so it shows up
            if (_cluster != null &&
                _cluster!.trim().isNotEmpty &&
                !_clusters.contains(_cluster)) {
              _clusters = {..._clusters, _cluster!}.toList();
            }
          });
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _loadProductsList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
            ? getIt<UserDetailStore>()
            : null;

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
          print(
              'DcrEntryScreen: [Products] userId is still null/0, skipping products load');
          return;
        }

        // For Service Engineer: use employeeId as UserId
        // For others: use userId as UserId
        int? actualUserId = employeeId;

        if (serviceArea != null && serviceArea.trim() == 'Service Engineer') {
          if (employeeId != null && employeeId > 0) {
            actualUserId = employeeId;
            print(
                'DcrEntryScreen: [Products] Service Engineer detected - using employeeId: $actualUserId as UserId');
          } else {
            print(
                'DcrEntryScreen: [Products] Service Engineer but employeeId is null/0, using userId: $actualUserId');
          }
        } else {
          print(
              'DcrEntryScreen: [Products] Non-Service Engineer - using userId: $actualUserId');
        }

        // IsFromAMCUser is always 0 in the request, only UserId is dynamic
        print(
            'DcrEntryScreen: [Products] Loading products with UserId: $actualUserId');
        final List<CommonDropdownItem> items =
            await repo.getDcrProductsList(actualUserId ?? 0);
        if (items.isNotEmpty) {
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
            _productOptions.sort();
            print(
                'DcrEntryScreen: [Products] Loaded ${_productOptions.length} products');
          });
        } else {
          print('DcrEntryScreen: [Products] No products returned from API');
        }
      }
    } catch (e) {
      print('DcrEntryScreen: [Products] Error loading products: $e');
    }
  }

  /// Load dropdowns for Service Report: Service Type, Electricity Safety Test,
  /// Service Status, and Feedback Option using Common/GetAuto (CommandType: 335).
  Future<void> _loadServiceDropdowns() async {
    try {
      if (!getIt.isRegistered<CommonRepository>()) {
        print(
            'DcrEntryScreen: [ServiceReport Dropdowns] CommonRepository not registered - skipping');
        return;
      }

      final repo = getIt<CommonRepository>();
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;

      // Wait until user is loaded (same retry logic as products)
      int retry = 0;
      while (userStore?.isUserLoaded != true && retry < 20) {
        await Future.delayed(const Duration(milliseconds: 300));
        retry++;
      }

      int? userId = userStore?.userDetail?.id;
      int? employeeId = userStore?.userDetail?.employeeId;
      String? serviceArea = userStore?.userDetail?.serviceArea;

      if (userId == null || userId <= 0) {
        print(
            'DcrEntryScreen: [ServiceReport Dropdowns] userId is null/0 - skipping');
        return;
      }

      // For Service Engineer use employeeId as UserId, otherwise use userId
      int? actualUserId = employeeId;
      if (serviceArea != null && serviceArea.trim() == 'Service Engineer') {
        if (employeeId != null && employeeId > 0) {
          actualUserId = employeeId;
        } else {
          actualUserId = userId;
        }
      } else {
        actualUserId = userId;
      }

      print(
          'DcrEntryScreen: [ServiceReport Dropdowns] Loading using UserId: $actualUserId');

      // CommandType 335 as requested
      final List<CommonDropdownItem> items =
          await repo.getCommonAuto(335, userId: actualUserId);

      if (items.isEmpty) {
        print(
            'DcrEntryScreen: [ServiceReport Dropdowns] No items returned for commandType 335');
        return;
      }

      // Populate all four dropdowns using the same returned list (backend returns appropriate entries)
      setState(() {
        _serviceTypeOptions = [];
        _electricitySafetyOptions = [];
        _serviceStatusOptions = [];
        _feedbackOptions = [];
        _serviceTypeNameToId.clear();
        _electricitySafetyNameToId.clear();
        _serviceStatusNameToId.clear();
        _feedbackNameToId.clear();

        for (final it in items) {
          final String display =
              (it.text.isNotEmpty ? it.text : (it.name ?? '')).trim();
          if (display.isEmpty) continue;
          // Use same set for all — backend should return type-distinguished items
          _serviceTypeOptions.add(display);
          _serviceTypeNameToId[display] = it.id;

          _electricitySafetyOptions.add(display);
          _electricitySafetyNameToId[display] = it.id;

          _serviceStatusOptions.add(display);
          _serviceStatusNameToId[display] = it.id;

          _feedbackOptions.add(display);
          _feedbackNameToId[display] = it.id;
        }

        // Deduplicate and sort
        _serviceTypeOptions = _serviceTypeOptions.toSet().toList()..sort();
        _electricitySafetyOptions = _electricitySafetyOptions.toSet().toList()
          ..sort();
        _serviceStatusOptions = _serviceStatusOptions.toSet().toList()..sort();
        _feedbackOptions = _feedbackOptions.toSet().toList()..sort();
      });

      print(
          'DcrEntryScreen: [ServiceReport Dropdowns] Loaded serviceType=${_serviceTypeOptions.length}, safety=${_electricitySafetyOptions.length}, status=${_serviceStatusOptions.length}, feedback=${_feedbackOptions.length}');
    } catch (e) {
      print(
          'DcrEntryScreen: [ServiceReport Dropdowns] Error loading dropdowns: $e');
    }
  }

  Future<void> _loadMappedCustomers() async {
    try {
      print('DcrEntryScreen: [Customers] Start loading mapped customers');
      if (!getIt.isRegistered<TourPlanRepository>()) {
        print(
            'DcrEntryScreen: [Customers] TourPlanRepository not registered - skipping');
        return;
      }

      // If no cluster is selected, clear customers and return
      if (_cluster == null || _cluster!.trim().isEmpty) {
        print(
            'DcrEntryScreen: [Customers] No cluster selected - clearing customers');
        setState(() {
          _customerOptions = [];
          _customerNameToId.clear();
          // Keep existing customer selection if it was set from initialEntry
        });
        return;
      }

      final repo = getIt<TourPlanRepository>();
      final userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      final int? employeeId = userStore?.userDetail?.employeeId;
      if (employeeId == null) {
        print('DcrEntryScreen: [Customers] employeeId is null - skipping');
        return;
      }

      // Get cluster ID from the selected cluster name
      final int? clusterId = _clusterNameToId[_cluster];
      if (clusterId == null || clusterId <= 0) {
        print(
            'DcrEntryScreen: [Customers] Invalid cluster ID for cluster: $_cluster');
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

      print('DcrEntryScreen: [Customers] Selected cluster count: 1');
      print('DcrEntryScreen: [Customers] Cluster IDs count: 1');

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

      print('DcrEntryScreen: [Customers] Request clusterIds count: ${req.clusterIds?.length ?? 0}');
      final res = await repo.getMappedCustomersByEmployeeId(req);
      print('DcrEntryScreen: [Customers] API returned count: ${res.customers.length}');

      if (res.customers.isEmpty) {
        print(
            'DcrEntryScreen: [Customers] No customers found for selected cluster');
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

      print(
          'DcrEntryScreen: [Customers] Loaded ${_customerOptions.length} customers');
    } catch (e) {
      print('DcrEntryScreen: [Customers] Error loading customers: $e');
      // Silent fail - don't clear existing customers on error
    }
  }

  /// Load mapped customers for Service Report tab specifically.
  /// This does not require a selected cluster and will fetch all mapped customers
  /// for the employee (optionally filtered by customerTypeId or date).
  Future<void> _loadMappedCustomersForServiceReport() async {
    try {
      print(
          'DcrEntryScreen: [ServiceReport - Customers] Start loading mapped customers');
      if (!getIt.isRegistered<TourPlanRepository>()) {
        print(
            'DcrEntryScreen: [ServiceReport - Customers] TourPlanRepository not registered - skipping');
        return;
      }

      final repo = getIt<TourPlanRepository>();
      final userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      final int? employeeId = userStore?.userDetail?.employeeId;
      if (employeeId == null) {
        print(
            'DcrEntryScreen: [ServiceReport - Customers] employeeId is null - skipping');
        return;
      }

      final String dateStr = _serviceDate != null
          ? _serviceDate!.toIso8601String().split('T').first
          : DateTime.now().toIso8601String().split('T').first;

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
        clusterIds: null,
        selectedEmployeeId: null,
        date: dateStr,
        customerTypeId: 0,
      );

      print(
          'DcrEntryScreen: [ServiceReport - Customers] Request body => ${req.toJson()}');
      final res = await repo.getMappedCustomersByEmployeeId(req);
      print(
          'DcrEntryScreen: [ServiceReport - Customers] API returned ${res.customers.length} customers');

      if (res.customers.isEmpty) {
        setState(() {
          _customerOptions = [];
          _customerNameToId.clear();
        });
        return;
      }

      setState(() {
        _customerOptions = [];
        _customerNameToId.clear();
        for (final mc in res.customers) {
          _customerOptions.add(mc.customerName);
          _customerNameToId[mc.customerName] = mc.customerId;
        }
        _customerOptions = _customerOptions.toSet().toList();
        _customerOptions.sort();
      });
      print(
          'DcrEntryScreen: [ServiceReport - Customers] Loaded ${_customerOptions.length} customers');
    } catch (e) {
      print(
          'DcrEntryScreen: [ServiceReport - Customers] Error loading customers: $e');
    }
  }

  /// Resolve purpose from typeOfWorkId (extracted as separate method for reusability)
  void _resolvePurposeFromTypeOfWorkId(int typeOfWorkId) {
    print(
        'DcrEntryScreen: Resolving purpose from typeOfWorkId (same as tour plan form)');
    print('  - Current purpose: "$_purpose"');
    print('  - typeOfWorkId to resolve: $typeOfWorkId');
    print(
        '  - Source: ${widget.initialTypeOfWorkId == typeOfWorkId ? "initialTypeOfWorkId" : "loadedTypeOfWorkId (edit mode)"}');
    print('  - typeOfWorkIdToName map size: ${_typeOfWorkIdToName.length}');

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
          print(
              'DcrEntryScreen: ✓ Updated purpose from "$previousPurpose" to "$purposeName" (ID: $typeOfWorkId)');
        } else {
          print(
              'DcrEntryScreen: ✓ Purpose already correct: "$purposeName" (ID: $typeOfWorkId)');
        }
        print('DcrEntryScreen: Purpose set to: "$_purpose"');
        print(
            'DcrEntryScreen: Purpose in options: ${_purposeOptions.contains(purposeName)}');
        print(
            'DcrEntryScreen: Purpose version incremented to: $_purposeVersion');
      });
    } else {
      print(
          'DcrEntryScreen: ⚠ Could not find purpose name for typeOfWorkId: $typeOfWorkId');
      print(
          'DcrEntryScreen: Available IDs in map: ${_typeOfWorkIdToName.keys.toList()}');
      print(
          'DcrEntryScreen: Available typeOfWork mappings count: ${_typeOfWorkIdToName.length}');
    }
  }

  Future<void> _loadTypeOfWorkList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
            ? getIt<UserDetailStore>()
            : null;

        // Wait for user to be loaded (retry up to 20 times = 6 seconds max)
        int retry = 0;
        while (userStore?.isUserLoaded != true && retry < 20) {
          await Future.delayed(const Duration(milliseconds: 300));
          retry++;
          print(
              'DcrEntryScreen: [PurposeOfVisit] Waiting for user to load... retry $retry');
        }

        int? userId = userStore?.userDetail?.id;
        String? serviceArea = userStore?.userDetail?.serviceArea;

        print(
            'DcrEntryScreen: [PurposeOfVisit] userId: $userId, serviceArea: "$serviceArea"');

        if (userId == null || userId <= 0) {
          print('DcrEntryScreen: [PurposeOfVisit] userId invalid, skipping');
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

        print(
            'DcrEntryScreen: [PurposeOfVisit] serviceArea: "$serviceAreaTrimmed", using text: "$purposeText"');
        final List<CommonDropdownItem> items =
            await repo.getPurposeOfVisitList(userId, purposeText);
        print(
            'DcrEntryScreen: [PurposeOfVisit] API returned ${items.length} items');
        final works = items
            .map((e) => (e.text.isNotEmpty ? e.text : e.typeText).trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        if (works.isNotEmpty) {
          setState(() {
            _purposeOptions = works.toList();
            // map names to ids for submit (same logic as tour plan form - line 828-833)
            for (final item in items) {
              final String key =
                  (item.text.isNotEmpty ? item.text : item.typeText).trim();
              if (key.isNotEmpty) {
                _typeOfWorkNameToId[key] = item.id;
                _typeOfWorkIdToName[item.id] =
                    key; // Reverse mapping for pre-filling
              }
            }

            // Resolve purpose names from initialTypeOfWorkId OR loadedTypeOfWorkId (for editing)
            // ALWAYS resolve purpose from typeOfWorkId to ensure it matches API value
            final int? typeOfWorkIdToResolve =
                widget.initialTypeOfWorkId ?? _loadedTypeOfWorkId;
            if (typeOfWorkIdToResolve != null && typeOfWorkIdToResolve > 0) {
              _resolvePurposeFromTypeOfWorkId(typeOfWorkIdToResolve);
            }

            // Fallback: If purpose was set from initialEntry but not in options, try case-insensitive match
            if (_purpose != null &&
                _purpose!.trim().isNotEmpty &&
                !_purposeOptions.contains(_purpose)) {
              // Try case-insensitive matching
              bool found = false;
              String? matchedOption;
              for (final option in _purposeOptions) {
                if (_purpose!.trim().toLowerCase() == option.toLowerCase()) {
                  _purpose = option; // Use exact match from API
                  found = true;
                  matchedOption = option;
                  break;
                }
              }
              print(
                  'DcrEntryScreen: Case-insensitive purpose match count: ${found ? 1 : 0}');
              if (matchedOption != null) {
                print('DcrEntryScreen: Matched option count: 1');
              }
              // If still not found, add it to options (fallback)
              if (!found) {
                _purposeOptions = {..._purposeOptions, _purpose!}.toList();
                print(
                    'DcrEntryScreen: Added purpose to options list (fallback): $_purpose');
              }
            }

            print(
                'DcrEntryScreen: Final purpose value after resolution: "$_purpose"');
            print(
                'DcrEntryScreen: Purpose options count: ${_purposeOptions.length}');
            print(
                'DcrEntryScreen: Purpose is in options: ${_purpose != null && _purposeOptions.contains(_purpose)}');
          });
        } else {
          print(
              'DcrEntryScreen: [PurposeOfVisit] No purpose options returned from API');
        }
      }
    } catch (e) {
      print(
          'DcrEntryScreen: [PurposeOfVisit] Error loading purpose of visit: $e');
      // Silent fail
    }
  }

  /// Load Customer Type list for DCR Customer tab (Sales Rep only).
  /// Uses Common/GetAuto with CommandType: 112, Type: "LI TYPE".
  /// Not loaded or shown for Medical Rep (no Customer Type concept for them).
  Future<void> _loadCustomerTypes() async {
    try {
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      if (userStore?.userDetail?.serviceArea == 'Medical Rep') {
        if (mounted) {
          setState(() {
            _customerTypeOptions = [];
            _customerTypeNameToId.clear();
          });
        }
        print(
            'DcrEntryScreen: [CustomerTypes] Skipping - Medical Rep (Customer Type not applicable)');
        return;
      }
      if (getIt.isRegistered<DioClient>()) {
        final dioClient = getIt<DioClient>();
        final requestData = {
          'CommandType': 112,
          'Type': 'LI TYPE',
        };

        print(
            'DcrEntryScreen: [CustomerTypes] Requesting CommandType=112 (LI TYPE)');
        final response = await dioClient.dio.post(
          Endpoints.commonGetAuto,
          data: requestData,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
            },
          ),
        );

        if (response.data != null && response.data is List && mounted) {
          final List<CommonDropdownItem> items = (response.data as List)
              .map((item) => CommonDropdownItem.fromJson(item))
              .toList();
          setState(() {
            _customerTypeOptions = items
                .map((e) => e.text.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            for (final item in items) {
              final String key = item.text.trim();
              if (key.isNotEmpty) _customerTypeNameToId[key] = item.id;
            }
          });
          print(
              'DcrEntryScreen: [CustomerTypes] Loaded ${_customerTypeOptions.length} customer types');
        } else {
          print(
              'DcrEntryScreen: [CustomerTypes] No customer types returned from API');
        }
      }
    } catch (e) {
      print('DcrEntryScreen: [CustomerTypes] Error loading customer types: $e');
    }
  }

  /// Load Speciality, Category, and Area Type dropdowns for Medical Rep (Customer tab)
  Future<void> _loadMedicalRepDropdowns() async {
    if (!getIt.isRegistered<CommonApi>()) return;
    final commonApi = getIt<CommonApi>();
    try {
      final results = await Future.wait<List<CommonDropdownItem>>([
        commonApi.getSpecialityDropdownList(),
        commonApi.getCategoryDropDownList(),
        commonApi.getAreaTypeDropdownList(),
      ]);
      if (!mounted) return;
      final specialityItems = results[0];
      final categoryItems = results[1];
      final areaTypeItems = results[2];
      setState(() {
        _specialityOptions = specialityItems
            .map((e) => e.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        for (final item in specialityItems) {
          final String key = item.text.trim();
          if (key.isNotEmpty) _specialityNameToId[key] = item.id;
        }
        _categoryOptions = categoryItems
            .map((e) => e.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        for (final item in categoryItems) {
          final String key = item.text.trim();
          if (key.isNotEmpty) _categoryNameToId[key] = item.id;
        }
        _areaTypeOptions = areaTypeItems
            .map((e) => e.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        for (final item in areaTypeItems) {
          final String key = item.text.trim();
          if (key.isNotEmpty) _areaTypeNameToId[key] = item.id;
        }
      });
      print(
          'DcrEntryScreen: [MedicalRep] Loaded speciality: ${_specialityOptions.length}, category: ${_categoryOptions.length}, areaType: ${_areaTypeOptions.length}');
    } catch (e) {
      print('DcrEntryScreen: [MedicalRep] Error loading dropdowns: $e');
    }
  }

  Future<void> _loadCountries() async {
    try {
      if (getIt.isRegistered<DioClient>()) {
        final dioClient = getIt<DioClient>();
        final requestData = {
          'SearchText': null,
          'Id': null,
          'TransactionId': null,
          'UserId': null,
          'CommandType': 5,
          'CommandText': null,
          'Value': null,
          'CountryId': null,
          'Key': null,
          'Text': null,
          'Type': null,
          'TaxFlag': 0,
          'IncludeCancelled': false,
        };

        print(
            'DcrEntryScreen: [Countries] Requesting CommandType=5 for countries');
        final response = await dioClient.dio.post(
          Endpoints.commonGetAuto,
          data: requestData,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
            },
          ),
        );

        if (response.data != null && response.data is List && mounted) {
          final List<CommonDropdownItem> items = (response.data as List)
              .map((item) => CommonDropdownItem.fromJson(item))
              .toList();
          setState(() {
            _countryOptions = items
                .map((e) => e.text.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            for (final item in items) {
              final String key = item.text.trim();
              if (key.isNotEmpty) {
                _countryNameToId[key] = item.id;
              }
            }
          });
          print(
              'DcrEntryScreen: [Countries] Loaded ${_countryOptions.length} countries');
        } else {
          print('DcrEntryScreen: [Countries] No countries returned from API');
        }
      }
    } catch (e) {
      print('DcrEntryScreen: [Countries] Error loading countries: $e');
    }
  }

  Future<void> _loadStates(int countryId) async {
    try {
      if (getIt.isRegistered<DioClient>()) {
        final dioClient = getIt<DioClient>();
        final requestData = {
          'SearchText': null,
          'Id': null,
          'TransactionId': null,
          'UserId': null,
          'CommandType': 14,
          'CommandText': null,
          'Value': null,
          'CountryId': countryId,
          'Key': null,
          'Text': null,
          'TaxFlag': 0,
          'IncludeCancelled': false,
        };

        print(
            'DcrEntryScreen: [States] Requesting CommandType=14 for countryId: $countryId');
        final response = await dioClient.dio.post(
          Endpoints.commonGetAuto,
          data: requestData,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
            },
          ),
        );

        if (response.data != null && response.data is List && mounted) {
          final List<CommonDropdownItem> items = (response.data as List)
              .map((item) => CommonDropdownItem.fromJson(item))
              .toList();
          setState(() {
            _stateOptions = items
                .map((e) => e.text.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            for (final item in items) {
              final String key = item.text.trim();
              if (key.isNotEmpty) {
                _stateNameToId[key] = item.id;
              }
            }
          });
          print(
              'DcrEntryScreen: [States] Loaded ${_stateOptions.length} states for countryId: $countryId');
        } else {
          print(
              'DcrEntryScreen: [States] No states returned from API for countryId: $countryId');
        }
      }
    } catch (e) {
      print('DcrEntryScreen: [States] Error loading states: $e');
    }
  }

  Future<void> _loadCities(int stateId) async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        // Use CommonGetAutoRequest with CommandType for cities (typically 202 or similar)
        // Note: Adjust CommandType value based on your API documentation
        // Since CommonGetAutoRequest doesn't have stateId, we might need to use a different approach
        // Let's check if we can use the getAuto method with a custom request
        // For now, using a workaround: create a custom request with stateId
        final requestData = {
          'CommandType': 10,
          'StateId': stateId,
        };
        final commonApi = getIt<CommonApi>();
        final dioClient = getIt<DioClient>();
        final response = await dioClient.dio.post(
          Endpoints.commonGetAuto,
          data: requestData,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
            },
          ),
        );

        if (response.data != null && response.data is List) {
          final List<CommonDropdownItem> items = (response.data as List)
              .map((item) => CommonDropdownItem.fromJson(item))
              .toList();

          if (items.isNotEmpty && mounted) {
            setState(() {
              _cityOptions = items
                  .map((e) => e.text.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              // Map names to IDs
              for (final item in items) {
                final String key = item.text.trim();
                if (key.isNotEmpty) {
                  _cityNameToId[key] = item.id;
                }
              }
            });
            print(
                'DcrEntryScreen: [Cities] Loaded ${_cityOptions.length} cities for stateId: $stateId');
          } else {
            print(
                'DcrEntryScreen: [Cities] No cities returned from API for stateId: $stateId');
          }
        }
      }
    } catch (e) {
      print('DcrEntryScreen: [Cities] Error loading cities: $e');
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
      final DcrRepository? dcrRepo =
          getIt.isRegistered<DcrRepository>() ? getIt<DcrRepository>() : null;
      if (dcrRepo != null && widget.id != null) {
        // For GET request: use widget.id (detail ID) as Id parameter, widget.dcrId as DCRId parameter
        // The API expects: Id=detailId&DCRId=dcrId
        print(
            'Loading DCR details - widget.id (detail): ${widget.id}, widget.dcrId (parent): ${widget.dcrId}');
        final DcrEntry? dcrEntry =
            await dcrRepo.getById(widget.id!, dcrId: widget.dcrId);
        if (dcrEntry != null) {
          print('DCR Details loaded:');
          print('  Entry.id (DCR Parent ID): ${dcrEntry.id}');
          print(
              '  Entry.detailId (TourPlanDCRDetails ID): ${dcrEntry.detailId}');
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
            print(
                'DcrEntryScreen: Stored typeOfWorkId from loaded DCR: $_loadedTypeOfWorkId (will resolve purpose after typeOfWork list loads)');
          }

          // Populate the form fields with the loaded data
          setState(() {
            _cluster =
                dcrEntry.cluster.isNotEmpty ? dcrEntry.cluster : _cluster;
            _customer =
                dcrEntry.customer.isNotEmpty ? dcrEntry.customer : _customer;
            // Set purpose to "Loading..." if we have typeOfWorkId, otherwise use purposeOfVisit
            // This will be resolved after typeOfWork list loads (same as tour plan form)
            if (_loadedTypeOfWorkId != null && _loadedTypeOfWorkId! > 0) {
              _purpose = 'Loading...';
              print(
                  'DcrEntryScreen: Set purpose to "Loading..." for typeOfWorkId: $_loadedTypeOfWorkId (will resolve after typeOfWork list loads)');
            } else {
              _purpose = dcrEntry.purposeOfVisit.isNotEmpty
                  ? dcrEntry.purposeOfVisit
                  : _purpose;
            }
            _durationCtrl.text = dcrEntry.callDurationMinutes.toString();
            // Parse products from comma-separated string
            if (dcrEntry.productsDiscussed.trim().isNotEmpty) {
              _selectedProducts = dcrEntry.productsDiscussed
                  .split(',')
                  .map((p) => p.trim())
                  .where((p) => p.isNotEmpty)
                  .toSet();
            } else {
              _selectedProducts.clear();
            }
            _samplesCtrl.text = dcrEntry.samplesDistributed;
            _discussionCtrl.text = dcrEntry.keyDiscussionPoints;
            _date = dcrEntry.date;
            // Set time from date if available
            _time = TimeOfDay(
                hour: dcrEntry.date.hour, minute: dcrEntry.date.minute);

            // Set location if available
            if (dcrEntry.customerLatitude != null &&
                dcrEntry.customerLongitude != null) {
              print(
                  'Setting position from DCR data: Lat=${dcrEntry.customerLatitude}, Lng=${dcrEntry.customerLongitude}');
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

            // Pre-fill Service Engineer / Service Report fields if available
            if (dcrEntry.mappedInstruments != null &&
                dcrEntry.mappedInstruments!.isNotEmpty) {
              final Set<String> instrumentNames = <String>{};
              for (final instrument in dcrEntry.mappedInstruments!) {
                try {
                  final dynamic rawName =
                      instrument['productName'] ?? instrument['ProductName'];
                  final dynamic rawId =
                      instrument['productId'] ?? instrument['ProductId'];

                  final String name = rawName?.toString() ?? '';
                  int id = 0;
                  if (rawId is int) {
                    id = rawId;
                  } else if (rawId is String) {
                    id = int.tryParse(rawId) ?? 0;
                  }

                  if (name.isNotEmpty) {
                    instrumentNames.add(name);
                    _instrumentNameToId[name] = id;
                    if (!_instrumentOptions.contains(name)) {
                      _instrumentOptions =
                          {..._instrumentOptions, name}.toList();
                    }
                  }
                } catch (_) {
                  // Ignore malformed instrument entries
                }
              }
              _selectedInstruments = instrumentNames;
            }

            if (dcrEntry.complaint != null &&
                dcrEntry.complaint!.trim().isNotEmpty) {
              _complaintCtrl.text = dcrEntry.complaint!;
            }
            if (dcrEntry.actionTaken != null &&
                dcrEntry.actionTaken!.trim().isNotEmpty) {
              _actionTakenCtrl.text = dcrEntry.actionTaken!;
            }
            if (dcrEntry.result != null && dcrEntry.result!.trim().isNotEmpty) {
              _resultCtrl.text = dcrEntry.result!;
            }

            if (dcrEntry.complaintStatus != null) {
              _complaintStatus =
                  dcrEntry.complaintStatus == 1 ? 'Resolved' : 'Not Resolved';
              // Sync dropdown (Complaint Status uses ServiceReportStatus enum)
              _selectedServiceReportStatus = dcrEntry.complaintStatus == 1
                  ? ServiceReportStatus.Resolved
                  : ServiceReportStatus.NotResolved;
            }

            if (dcrEntry.complaintDate != null) {
              _complaintDate = dcrEntry.complaintDate;
              // Use same value for the DateTime field so it appears in Service Report tab
              _complaintDateTime = dcrEntry.complaintDate;
            }

            if (dcrEntry.complaintRemarks != null &&
                dcrEntry.complaintRemarks!.trim().isNotEmpty) {
              _complaintRemarksCtrl.text = dcrEntry.complaintRemarks!;
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
            // Load co-visit data
            _coVisit = dcrEntry.coVisit;
            if (_coVisit &&
                dcrEntry.coVisitorId != null &&
                dcrEntry.coVisitorId! > 0) {
              // Load manager list first, then find the manager name matching the ID
              _loadManagerList().then((_) {
                // Find manager name by ID
                String? managerName;
                _managerNameToId.forEach((name, id) {
                  if (id == dcrEntry.coVisitorId) {
                    managerName = name;
                  }
                });
                if (managerName != null && mounted) {
                  setState(() {
                    _selectedManager = managerName;
                  });
                }
              });
            }

            // Don't add "Loading..." to options - it will be resolved after typeOfWork list loads
            if (_purpose != null &&
                _purpose!.trim().isNotEmpty &&
                _purpose != 'Loading...') {
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
            print('DcrEntryScreen: Loading customers for selected cluster count: 1');
            _loadMappedCustomers();
          }

          // If we have _loadedTypeOfWorkId and typeOfWork list is already loaded, resolve purpose now
          if (_loadedTypeOfWorkId != null &&
              _loadedTypeOfWorkId! > 0 &&
              _typeOfWorkIdToName.isNotEmpty) {
            print(
                'DcrEntryScreen: Resolving purpose from _loadedTypeOfWorkId after DCR details loaded');
            _resolvePurposeFromTypeOfWorkId(_loadedTypeOfWorkId!);
          }

          // Log the form field values after setting them
          print('Form fields set (counts):');
          print('  Cluster selected count: ${(_cluster?.trim().isNotEmpty ?? false) ? 1 : 0}');
          print('  Customer selected count: ${(_customer?.trim().isNotEmpty ?? false) ? 1 : 0}');
          print('  Purpose selected count: ${(_purpose?.trim().isNotEmpty ?? false) ? 1 : 0}');
          print('  _durationCtrl.text: ${_durationCtrl.text}');
          print('  Selected products count: ${_selectedProducts.length}');
          print('  _samplesCtrl.text: ${_samplesCtrl.text}');
          print('  _discussionCtrl.text: ${_discussionCtrl.text}');
          print('  _date: $_date');
          print('  _time: $_time');
          print('  _position: ${_position?.latitude}, ${_position?.longitude}');

          // When updating DCR and user is Service Engineer: load Service Report by DCR detail Id to autofill (do not call when creating new DCR)
          if (_isServiceEngineer &&
              dcrEntry.detailId != null &&
              dcrEntry.detailId! > 0) {
            await _loadServiceReportForDcrDetail(dcrEntry.detailId!);
          }
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

  /// Load existing Service Report data (if any) for the current DCR detail
  Future<void> _loadServiceReportForDcrDetail(int detailId) async {
    try {
      final dioClient =
          getIt.isRegistered<DioClient>() ? getIt<DioClient>() : null;
      if (dioClient == null) {
        print(
            'DcrEntryScreen: [ServiceReport] DioClient not registered, skipping load');
        return;
      }

      final String url = Endpoints.serviceReportGet(detailId);
      print(
          'DcrEntryScreen: [ServiceReport] Loading existing service report from $url');

      final response = await dioClient.dio.get(url);
      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        print(
            'DcrEntryScreen: [ServiceReport] Get failed with status: ${response.statusCode}');
        return;
      }

      // 204 No Content = no service report saved previously for this DCR detail; nothing to autofill
      if (response.statusCode == 204) {
        print(
            'DcrEntryScreen: [ServiceReport] Get returned 204 No Content - no existing service report');
        return;
      }

      final dynamic data = response.data;
      if (data == null) {
        print('DcrEntryScreen: [ServiceReport] Get returned null body');
        return;
      }

      // API returns a single object (camelCase keys per client spec)
      dynamic payload = data;
      if (data is Map) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(data);
        final dynamic dataList = map['Data'] ?? map['data'];
        if (dataList is List && dataList.isNotEmpty) {
          payload = dataList.first;
        }
      }

      // Defensive casting for both Map<String, dynamic> and generic Map
      final Map<String, dynamic> json = payload is Map<String, dynamic>
          ? payload
          : Map<String, dynamic>.from(payload as Map);

      print(
          'DcrEntryScreen: [ServiceReport] Loaded existing service report: $json');

      // Extract basic identifiers
      final dynamic idRaw = json['id'] ??
          json['Id'] ??
          json['serviceReportId'] ??
          json['ServiceReportId'];
      final int id = idRaw is int
          ? idRaw
          : (idRaw is String ? int.tryParse(idRaw) ?? 0 : 0);

      // Store CreatedDate as-is from API so we send same format back on Update (.NET expects ISO 8601)
      String? parsedCreatedDateStr;
      final String? createdDateStr =
          (json['createdDate'] ?? json['CreatedDate'])?.toString();
      if (createdDateStr != null && createdDateStr.isNotEmpty) {
        parsedCreatedDateStr = createdDateStr;
      }

      final String? customerName =
          (json['customerName'] ?? json['CustomerName'])?.toString();
      final dynamic customerIdRaw = json['customerId'] ?? json['CustomerId'];
      final int? customerId = customerIdRaw is int
          ? customerIdRaw
          : (customerIdRaw is String ? int.tryParse(customerIdRaw) : null);

      final String? productName =
          (json['product'] ?? json['Product'])?.toString();
      final dynamic productIdRaw = json['productId'] ?? json['ProductId'];
      final int? productId = productIdRaw is int
          ? productIdRaw
          : (productIdRaw is String ? int.tryParse(productIdRaw) : null);

      final String? contactPerson =
          (json['contactPerson'] ?? json['ContactPerson'])?.toString();
      final String? contactMobile =
          (json['contactMobile'] ?? json['ContactMobile'])?.toString();
      final String? serviceDateStr =
          (json['serviceDate'] ?? json['ServiceDate'])?.toString();
      final String? serialNumber =
          (json['serialNumber'] ?? json['SerialNumber'])?.toString();

      final dynamic serviceTypeIdRaw =
          json['serviceTypeId'] ?? json['ServiceTypeId'];
      final int? serviceTypeId = serviceTypeIdRaw is int
          ? serviceTypeIdRaw
          : (serviceTypeIdRaw is String
              ? int.tryParse(serviceTypeIdRaw)
              : null);

      final dynamic electricitySafetyIdRaw =
          json['electricitySafetyTestId'] ?? json['ElectricitySafetyTestId'];
      final int? electricitySafetyId = electricitySafetyIdRaw is int
          ? electricitySafetyIdRaw
          : (electricitySafetyIdRaw is String
              ? int.tryParse(electricitySafetyIdRaw)
              : null);

      final dynamic serviceStatusIdRaw =
          json['serviceStatusId'] ?? json['ServiceStatusId'];
      final int? serviceStatusId = serviceStatusIdRaw is int
          ? serviceStatusIdRaw
          : (serviceStatusIdRaw is String
              ? int.tryParse(serviceStatusIdRaw)
              : null);

      final dynamic feedbackOptionIdRaw =
          json['feedbackOptionId'] ?? json['FeedbackOptionId'];
      final int? feedbackOptionId = feedbackOptionIdRaw is int
          ? feedbackOptionIdRaw
          : (feedbackOptionIdRaw is String
              ? int.tryParse(feedbackOptionIdRaw)
              : null);

      final String? complaintDetails =
          (json['complaintDetails'] ?? json['ComplaintDetails'])?.toString();
      final String? actionTaken =
          (json['actionTaken'] ?? json['ActionTaken'])?.toString();
      final String? result = (json['result'] ?? json['Result'])?.toString();
      final String? complaintDateTimeStr =
          (json['complaintDateTime'] ?? json['ComplaintDateTime'])?.toString();
      final String? startTimeStr =
          (json['startTime'] ?? json['StartTime'])?.toString();
      final String? endTimeStr =
          (json['endTime'] ?? json['EndTime'])?.toString();

      final String? workDescription =
          (json['workDescription'] ?? json['WorkDescription'])?.toString();
      final String? materialsUsed =
          (json['materialsUsed'] ?? json['MaterialsUsed'])?.toString();
      final String? remarks = (json['remarks'] ?? json['Remarks'])?.toString();

      final String? signedBy =
          (json['signedBy'] ?? json['SignedBy'])?.toString();
      final String? signatureImageUrl =
          (json['signatureImageUrl'] ?? json['SignatureImageUrl'])?.toString();
      // Legacy: API may return base64 (camelCase or PascalCase)
      final String? signatureImageBase64 = (json['signatureImageBase64'] ??
              json['SignatureImageBase64'] ??
              json['signatureValue'] ??
              json['SignatureValue'])
          ?.toString();

      final dynamic serviceRateRaw = json['serviceRate'] ?? json['ServiceRate'];
      final double? serviceRate = serviceRateRaw is num
          ? serviceRateRaw.toDouble()
          : (serviceRateRaw is String && serviceRateRaw.isNotEmpty
              ? double.tryParse(serviceRateRaw)
              : null);

      DateTime? parsedServiceDate;
      if (serviceDateStr != null && serviceDateStr.isNotEmpty) {
        try {
          parsedServiceDate = DateTime.parse(serviceDateStr);
        } catch (_) {}
      }

      DateTime? parsedComplaintDateTime;
      if (complaintDateTimeStr != null && complaintDateTimeStr.isNotEmpty) {
        try {
          parsedComplaintDateTime = DateTime.parse(complaintDateTimeStr);
        } catch (_) {}
      }

      DateTime? parsedStartTime;
      if (startTimeStr != null && startTimeStr.isNotEmpty) {
        try {
          parsedStartTime = DateTime.parse(startTimeStr);
        } catch (_) {}
      }
      DateTime? parsedEndTime;
      if (endTimeStr != null && endTimeStr.isNotEmpty) {
        try {
          parsedEndTime = DateTime.parse(endTimeStr);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _serviceReportId = id > 0 ? id : _serviceReportId;
        if (parsedCreatedDateStr != null) {
          _serviceReportCreatedDate = parsedCreatedDateStr;
        }

        // Customer
        if (customerName != null && customerName.isNotEmpty) {
          _serviceReportCustomer = customerName;
          if (!_customerOptions.contains(customerName)) {
            _customerOptions = {..._customerOptions, customerName}.toList();
          }
          if (customerId != null && customerId > 0) {
            _customerNameToId[customerName] = customerId;
          }
        }

        // Product
        if (productName != null && productName.isNotEmpty) {
          _serviceReportProduct = productName;
          if (!_productOptions.contains(productName)) {
            _productOptions = {..._productOptions, productName}.toList();
          }
          if (productId != null && productId > 0) {
            _productNameToId[productName] = productId;
          }
        }

        // Basic fields
        _contactPersonCtrl.text = contactPerson ?? _contactPersonCtrl.text;
        _contactMobileCtrl.text = contactMobile ?? _contactMobileCtrl.text;
        _serialNumberCtrl.text = serialNumber ?? _serialNumberCtrl.text;
        _workDescriptionCtrl.text =
            workDescription ?? _workDescriptionCtrl.text;
        _materialsUsedCtrl.text = materialsUsed ?? _materialsUsedCtrl.text;
        _serviceRemarksCtrl.text = remarks ?? _serviceRemarksCtrl.text;
        _signedByCtrl.text = signedBy ?? _signedByCtrl.text;
        if (signatureImageUrl != null && signatureImageUrl.trim().isNotEmpty) {
          _signatureImageUrl = signatureImageUrl.trim();
          _signatureImageBase64 = null;
          _signatureValue = 'Captured';
        } else if (signatureImageBase64 != null &&
            signatureImageBase64.trim().isNotEmpty) {
          _signatureImageBase64 = signatureImageBase64;
          _signatureValue = 'Captured';
        }
        if (serviceRate != null) {
          _serviceRateCtrl.text = serviceRate.toStringAsFixed(2);
        }

        // Dates
        if (parsedServiceDate != null) {
          _serviceDate = parsedServiceDate;
          try {
            _serviceDateCtrl.text = _formatServiceDate(parsedServiceDate);
          } catch (_) {}
        }
        if (parsedComplaintDateTime != null) {
          _complaintDateTime = parsedComplaintDateTime;
        }
        if (parsedStartTime != null) {
          _startTime = parsedStartTime;
        }
        if (parsedEndTime != null) {
          _endTime = parsedEndTime;
        }

        // Complaint fields
        if (complaintDetails != null && complaintDetails.isNotEmpty) {
          _complaintCtrl.text = complaintDetails;
        }
        if (actionTaken != null && actionTaken.isNotEmpty) {
          _actionTakenCtrl.text = actionTaken;
        }
        if (result != null && result.isNotEmpty) {
          _resultCtrl.text = result;
        }

        // Enums: Service Type
        if (serviceTypeId != null && serviceTypeId > 0) {
          for (final t in ServiceReportType.values) {
            if (t.value == serviceTypeId) {
              _selectedServiceType = t;
              break;
            }
          }
        }

        // Enums: Electricity Safety
        if (electricitySafetyId != null && electricitySafetyId > 0) {
          for (final s in ElectricitySafetyTestStatus.values) {
            if (s.value == electricitySafetyId) {
              _selectedElectricitySafetyTest = s;
              break;
            }
          }
        }

        // Enums: Service Status
        if (serviceStatusId != null && serviceStatusId > 0) {
          for (final s in ServiceReportStatus.values) {
            if (s.value == serviceStatusId) {
              _selectedServiceReportStatus = s;
              break;
            }
          }
        }

        // Enums: Feedback
        if (feedbackOptionId != null && feedbackOptionId > 0) {
          for (final f in ServiceFeedbackStatus.values) {
            if (f.value == feedbackOptionId) {
              _selectedFeedbackOption = f;
              break;
            }
          }
        }
      });
    } catch (e, s) {
      print(
          'DcrEntryScreen: [ServiceReport] Error loading existing service report for detailId=$detailId: $e\n$s');
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
          _isViewOnly
              ? 'DCR View'
              : (widget.dcrId != null ? 'Edit DCR' : 'New DCR'),
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
        bottom: _shouldShowOnlyCreateTab()
            ? null
            : TabBar(
                controller: _tabController,
                tabs: [
                  const Tab(text: 'Create DCR'),
                  if (_isServiceEngineer) ...[
                    const Tab(text: 'Service Report'),
                  ],
                  // Show Customer tab only when creating new DCR and user is not Service Engineer.
                  // Never show when updating (customer cannot be updated) or for SE.
                  if ((widget.dcrId == null && widget.id == null) &&
                      !_isServiceEngineer) ...[
                    const Tab(text: 'Customer'),
                  ],
                ],
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
              ),
      ),
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: _isLoadingDcrDetails
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary),
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
                child: _shouldShowOnlyCreateTab()
                    ? _buildCreateDcrTab(context, screenTheme, tealGreen)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // Tab 0: Create DCR
                          _buildCreateDcrTab(context, screenTheme, tealGreen),
                          // Tab 1: Service Report (only for Service Engineer)
                          if (_isServiceEngineer) ...[
                            _buildServiceReportTab(
                                context, screenTheme, tealGreen),
                          ],
                          // Customer tab: only when creating new and not Service Engineer (never when updating)
                          if ((widget.dcrId == null && widget.id == null) &&
                              !_isServiceEngineer) ...[
                            _buildCustomerTab(context, screenTheme, tealGreen),
                          ],
                        ],
                      ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _durationCtrl.dispose();
    _samplesCtrl.dispose();
    _discussionCtrl.dispose();
    _complaintCtrl.dispose();
    _actionTakenCtrl.dispose();
    _resultCtrl.dispose();
    _complaintRemarksCtrl.dispose();
    _contactPersonCtrl.dispose();
    _contactMobileCtrl.dispose();
    _serialNumberCtrl.dispose();
    _serviceRateCtrl.dispose();
    _workDescriptionCtrl.dispose();
    _materialsUsedCtrl.dispose();
    _serviceRemarksCtrl.dispose();
    _signedByCtrl.dispose();
    _serviceDateCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerCodeCtrl.dispose();
    _uinCtrl.dispose();
    _customerMobileCtrl.dispose();
    super.dispose();
  }

  bool _shouldShowOnlyCreateTab() {
    final UserDetailStore? userStore =
        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final int? roleCategory = userStore?.userDetail?.roleCategory;
    final bool isManager = roleCategory == 1 || roleCategory == 2;
    final bool isCreatingNew = widget.dcrId == null && widget.id == null;
    return isManager && isCreatingNew;
  }

  // Build Create DCR Tab
  Widget _buildCreateDcrTab(
      BuildContext context, ThemeData screenTheme, Color tealGreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          MediaQuery.of(context).size.width < 600 ? 12 : 16,
          12,
          MediaQuery.of(context).size.width < 600 ? 12 : 16,
          16 + MediaQuery.of(context).padding.bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                      MediaQuery.of(context).size.width < 600 ? 16.0 : 20.0),
                  child: IgnorePointer(
                    ignoring: _isViewOnly,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildCreateDcrFields(
                          context, screenTheme, tealGreen),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build Service Report Tab
  Widget _buildServiceReportTab(
      BuildContext context, ThemeData screenTheme, Color tealGreen) {
    final bool isExistingDcr =
        widget.dcrId != null || widget.id != null || _loadedEntry != null;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width < 600 ? 12 : 16,
        12,
        MediaQuery.of(context).size.width < 600 ? 12 : 16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Card(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(
                MediaQuery.of(context).size.width < 600 ? 16.0 : 20.0,
              ),
              child: isExistingDcr
                  ? IgnorePointer(
                      // Allow Service Report edit when viewOnly + allowServiceReportEditOnly (submitted DCRs)
                      ignoring:
                          _isViewOnly && !widget.allowServiceReportEditOnly,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children:
                            _buildServiceReportFields(context, screenTheme),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Please save DCR first',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: tealGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You need to add and save a DCR record before you can add a Service Report.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // Build Customer Tab
  Widget _buildCustomerTab(
      BuildContext context, ThemeData screenTheme, Color tealGreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          MediaQuery.of(context).size.width < 600 ? 12 : 16,
          12,
          MediaQuery.of(context).size.width < 600 ? 12 : 16,
          16 + MediaQuery.of(context).padding.bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                      MediaQuery.of(context).size.width < 600 ? 16.0 : 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildCustomerFields(context, screenTheme),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build Create DCR Fields - returns list of widgets
  List<Widget> _buildCreateDcrFields(
      BuildContext context, ThemeData theme, Color tealGreen) {
    return [
      // 1. Date
      _LabeledField(
        label: 'Date',
        child: _DateField(
          initialDate: _date,
          onChanged: (d) => setState(() => _date = d),
        ),
      ),
      const SizedBox(height: 16),
      // 2. Employee (read-only)
      _LabeledField(
        label: 'Employee',
        child: Builder(
          builder: (context) {
            final UserDetailStore? userStore =
                getIt.isRegistered<UserDetailStore>()
                    ? getIt<UserDetailStore>()
                    : null;
            final String employeeName =
                userStore?.userDetail?.employeeName ?? '';
            return TextFormField(
              readOnly: true,
              initialValue: employeeName,
              decoration: const InputDecoration(
                hintText: 'Employee name',
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      // 3. Cluster / City *
      _LabeledField(
        label: 'Cluster / City',
        required: true,
        errorText: _clusterErrorText,
        child: SearchableDropdown(
          options: _clusters,
          value: _cluster,
          hintText: 'Type to search cluster/city...',
          searchHintText: 'Search cluster...',
          hasError: _clusterErrorText != null,
          onChanged: (v) {
            setState(() {
              _cluster = v;
              _clusterErrorText = null;
              _customer = null;
              _customerErrorText = null;
            });
            _loadMappedCustomers();
          },
        ),
      ),
      const SizedBox(height: 16),
      // 4. Time of Visit
      _LabeledField(
        label: 'Time of Visit',
        child: _TimeField(
          initial: _time,
          onChanged: (t) => setState(() => _time = t),
        ),
      ),
      const SizedBox(height: 24),
      // 5. Actual Call Details (section header)
      Text(
        'Actual Call Details',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF4db1b3),
        ),
      ),
      const SizedBox(height: 20),
      // 6. Customer *
      _LabeledField(
        label: 'Customer',
        required: _customerRequiredForSelectedVisitType,
        errorText: _customerErrorText,
        child: Opacity(
          opacity: _customerRequiredForSelectedVisitType ? 1.0 : 0.55,
          child: IgnorePointer(
            ignoring: !_customerRequiredForSelectedVisitType || _isViewOnly,
            child: SearchableDropdown(
              options: _customerOptions,
              value: _customer,
              hintText: '-- Select Customer --',
              searchHintText: 'Search customer...',
              hasError: _customerErrorText != null,
              onChanged: (v) {
                setState(() {
                  _customer = v;
                  _customerErrorText = null;
                  _loadInstrumentsList();
                });
              },
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      // 7. Type of Visit *
      _LabeledField(
        label: 'Type of Visit',
        required: true,
        errorText: _purposeErrorText,
        child: SearchableDropdown(
          key: ValueKey(
              'purpose_${_purpose ?? 'null'}_${_purposeOptions.length}_v$_purposeVersion'),
          options: _purposeOptions,
          value: _purpose,
          hintText: '-- Select Visit Type --',
          searchHintText: 'Search purpose...',
          hasError: _purposeErrorText != null,
          onChanged: (v) {
            setState(() {
              _purpose = v;
              _purposeErrorText = null;
              if (!_customerRequiredForSelectedVisitType) {
                _customer = null;
                _customerErrorText = null;
              }
            });
          },
        ),
      ),
      const SizedBox(height: 16),
      // 8. Products Discussed *
      _LabeledField(
        label: 'Products Discussed',
        required: !_isServiceEngineer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MultiSelectDropdown(
              options: _productOptions,
              selectedValues: _selectedProducts,
              hintText: 'Select Products',
              onChanged: (Set<String> selected) {
                setState(() {
                  _selectedProducts = selected;
                  if (selected.isNotEmpty) {
                    _productsErrorText = null;
                  }
                });
              },
            ),
            if (_productsErrorText != null) ...[
              const SizedBox(height: 4),
              Text(
                _productsErrorText!,
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),

      // add if condition if the logged in person is service engineer than only show this field
      if (_isServiceEngineer) ...[
        const SizedBox(height: 16),
        // 9. Mapped Instruments *
        _LabeledField(
          label: 'Equipment',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MultiSelectDropdown(
                options: _instrumentOptions,
                selectedValues: _selectedInstruments,
                hintText: 'Equipment',
                onChanged: (Set<String> selected) {
                  setState(() {
                    _selectedInstruments = selected;

                    // if (selected.isNotEmpty) {
                    //   _instrumentsErrorText = null;
                    // }
                  });
                },
              ),
              if (_productsErrorText != null) ...[
                const SizedBox(height: 4),
                Text(
                  _productsErrorText!,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      // 10. Samples Distributed (hidden for Service Engineers)
      if (!_isServiceEngineer) ...[
        _LabeledField(
          label: 'Samples Distributed',
          child: TextFormField(
            controller: _samplesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter samples distributed',
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
      // Service Report Details section (Service Engineers only - new/edit/update/view)
      if (_isServiceEngineer) ...[
        const SizedBox(height: 20),
        // Text(
        //   'Service Report Details',
        //   style: GoogleFonts.inter(
        //     fontSize: 18,
        //     fontWeight: FontWeight.w600,
        //     color: Colors.grey.shade800,
        //   ),
        // ),
        // const SizedBox(height: 16),
        _LabeledField(
          label: 'Complaint',
          child: TextFormField(
            controller: _complaintCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Enter complaint details',
            ),
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'Action Taken',
          child: TextFormField(
            controller: _actionTakenCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Enter action taken',
            ),
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'Result',
          child: TextFormField(
            controller: _resultCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter result',
            ),
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'Complaint Status',
          child: DropdownButtonFormField<ServiceReportStatus>(
            value: _selectedServiceReportStatus,
            decoration: InputDecoration(
              hintText: 'Select Status',
              hintStyle: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w400),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            items: ServiceReportStatus.values.map((s) {
              return DropdownMenuItem<ServiceReportStatus>(
                value: s,
                child: Text(s.description, style: theme.textTheme.bodyMedium),
              );
            }).toList(),
            onChanged: (ServiceReportStatus? val) {
              setState(() {
                _selectedServiceReportStatus = val;
                _serviceStatus = val?.description;
              });
            },
            isExpanded: true,
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'Complaint Date / Time',
          child: TextFormField(
            readOnly: true,
            decoration: InputDecoration(
              hintText: _complaintDateTime != null
                  ? '${_complaintDateTime!.day.toString().padLeft(2, '0')}-${_getMonthName(_complaintDateTime!.month)}-${_complaintDateTime!.year} ${_complaintDateTime!.hour.toString().padLeft(2, '0')}:${_complaintDateTime!.minute.toString().padLeft(2, '0')}'
                  : 'dd-MMM-yyyy HH:mm',
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            onTap: () async {
              final DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: _complaintDateTime ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (pickedDate != null) {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: _complaintDateTime != null
                      ? TimeOfDay(
                          hour: _complaintDateTime!.hour,
                          minute: _complaintDateTime!.minute)
                      : TimeOfDay.now(),
                );
                if (pickedTime != null) {
                  setState(() {
                    _complaintDateTime = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime.hour,
                      pickedTime.minute,
                    );
                  });
                }
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'Complaint Remarks',
          child: TextFormField(
            controller: _complaintRemarksCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter complaint remarks',
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
      // 11. Call Duration (minutes)
      _LabeledField(
        label: 'Call Duration (minutes)',
        errorText: _durationErrorText,
        child: TextFormField(
          controller: _durationCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter duration in minutes',
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: _durationErrorText != null
                      ? Colors.red.shade400
                      : Colors.grey.shade300,
                  width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: _durationErrorText != null
                      ? Colors.red.shade400
                      : const Color(0xFF4db1b3),
                  width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onChanged: (_) => setState(() => _durationErrorText = null),
        ),
      ),
      const SizedBox(height: 16),
      // 12. Key Discussion Points
      _LabeledField(
        label: 'Key Discussion Points',
        child: TextFormField(
          controller: _discussionCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Type discussion points',
          ),
        ),
      ),
      const SizedBox(height: 16),
      // 13. Co-Visit (Not shown to managers in new DCR form)
      if (!(_isManager && _isNewDcr)) ...[
        Row(
          children: [
            Checkbox(
              value: _coVisit,
              onChanged: (value) {
                setState(() {
                  _coVisit = value ?? false;
                  if (!_coVisit) {
                    _selectedManager = null;
                    _managerErrorText = null;
                  } else {
                    _loadManagerList();
                  }
                });
              },
              activeColor: const Color(0xFF4db1b3),
            ),
            const SizedBox(width: 8),
            Text(
              'Co-Visit',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey[900],
              ),
            ),
          ],
        ),
        // Manager selection (shown when co-visit is checked)
        if (_coVisit) ...[
          const SizedBox(height: 16),
          _LabeledField(
            label: 'Select Manager',
            required: true,
            errorText: _managerErrorText,
            child: _isLoadingManagers
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : SearchableDropdown(
                    options: _managerOptions,
                    value: _selectedManager,
                    hintText: '-- Select Manager --',
                    searchHintText: 'Search manager...',
                    hasError: _managerErrorText != null,
                    onChanged: (v) {
                      setState(() {
                        _selectedManager = v;
                        _managerErrorText = null;
                      });
                    },
                  ),
          ),
        ],
      ],
      const SizedBox(height: 20),
      // Location picker
      _buildLocationPicker(context, theme, tealGreen),
      const SizedBox(height: 20),
      // Action buttons (hidden in view-only mode)
      if (!_isViewOnly)
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSavingDraft ? null : _saveDraft,
                style: OutlinedButton.styleFrom(
                  foregroundColor: tealGreen,
                  side: BorderSide(color: tealGreen, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Submit'),
              ),
            ),
          ],
        ),
    ];
  }

  // Build Service Report Fields
  List<Widget> _buildServiceReportFields(
      BuildContext context, ThemeData theme) {
    return [
      // Customer Information Section
      Text(
        'Customer Information',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
      const SizedBox(height: 16),
      // Customer Name *
      _LabeledField(
        label: 'Customer Name',
        required: true,
        child: SearchableDropdown(
          options: _customerOptions,
          value: _serviceReportCustomer,
          hintText: 'Select Customer',
          searchHintText: 'Search customer...',
          onChanged: (v) {
            setState(() {
              _serviceReportCustomer = v;
            });
          },
        ),
      ),
      const SizedBox(height: 16),
      // Contact Person *
      _LabeledField(
        label: 'Contact Person',
        required: true,
        child: TextFormField(
          controller: _contactPersonCtrl,
          decoration: const InputDecoration(
            hintText: 'Enter contact person name',
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Contact Mobile *
      _LabeledField(
        label: 'Contact Mobile',
        required: true,
        child: TextFormField(
          controller: _contactMobileCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: 'Enter contact mobile number',
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Service Date *
      _LabeledField(
        label: 'Service Date',
        required: true,
        child: TextFormField(
          controller: _serviceDateCtrl,
          decoration: InputDecoration(
            hintText: 'dd-MMM-yyyy',
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _serviceDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() {
                    _serviceDate = picked;
                    _serviceDateCtrl.text = _formatServiceDate(picked);
                  });
                }
              },
            ),
          ),
          onChanged: (value) {
            // Allow manual editing
            // Optionally parse the date if needed
          },
        ),
      ),
      const SizedBox(height: 24),

      // Product Information Section
      Text(
        'Product Information',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
      const SizedBox(height: 16),
      // Product *
      _LabeledField(
        label: 'Product',
        required: true,
        child: SearchableDropdown(
          options: _productOptions,
          value: _serviceReportProduct,
          hintText: 'Select Product',
          searchHintText: 'Search product...',
          onChanged: (v) {
            setState(() {
              _serviceReportProduct = v;
            });
          },
        ),
      ),
      const SizedBox(height: 16),
      // Serial Number *
      _LabeledField(
        label: 'Serial Number',
        required: true,
        child: TextFormField(
          controller: _serialNumberCtrl,
          decoration: const InputDecoration(
            hintText: 'Enter serial number',
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Service Type
      _LabeledField(
        label: 'Service Type',
        child: DropdownButtonFormField<ServiceReportType>(
          value: _selectedServiceType,
          decoration: InputDecoration(
            hintText: 'Select Service Type',
            hintStyle: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w400),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          items: ServiceReportType.values.map((ServiceReportType t) {
            return DropdownMenuItem<ServiceReportType>(
              value: t,
              child: Text(t.description, style: theme.textTheme.bodyMedium),
            );
          }).toList(),
          onChanged: (ServiceReportType? val) {
            setState(() {
              _selectedServiceType = val;
              // keep legacy string value in sync for other code paths
              _serviceType = val?.description;
            });
          },
          isExpanded: true,
        ),
      ),
      const SizedBox(height: 16),
      // Start Time
      _LabeledField(
        label: 'Start Time',
        child: TextFormField(
          readOnly: true,
          decoration: InputDecoration(
            hintText: _startTime != null
                ? '${_startTime!.day.toString().padLeft(2, '0')}-${_getMonthName(_startTime!.month)}-${_startTime!.year} ${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                : 'dd-MMM-yyyy HH:mm',
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          onTap: () async {
            final DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: _startTime ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (pickedDate != null) {
              final TimeOfDay? pickedTime = await showTimePicker(
                context: context,
                initialTime: _startTime != null
                    ? TimeOfDay(
                        hour: _startTime!.hour, minute: _startTime!.minute)
                    : TimeOfDay.now(),
              );
              if (pickedTime != null) {
                setState(() {
                  _startTime = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    pickedTime.hour,
                    pickedTime.minute,
                  );
                });
              }
            }
          },
        ),
      ),
      const SizedBox(height: 16),
      // End Time
      _LabeledField(
        label: 'End Time',
        child: TextFormField(
          readOnly: true,
          decoration: InputDecoration(
            hintText: _endTime != null
                ? '${_endTime!.day.toString().padLeft(2, '0')}-${_getMonthName(_endTime!.month)}-${_endTime!.year} ${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                : 'dd-MMM-yyyy HH:mm',
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          onTap: () async {
            final DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: _endTime ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (pickedDate != null) {
              final TimeOfDay? pickedTime = await showTimePicker(
                context: context,
                initialTime: _endTime != null
                    ? TimeOfDay(hour: _endTime!.hour, minute: _endTime!.minute)
                    : TimeOfDay.now(),
              );
              if (pickedTime != null) {
                setState(() {
                  _endTime = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    pickedTime.hour,
                    pickedTime.minute,
                  );
                });
              }
            }
          },
        ),
      ),
      const SizedBox(height: 16),
      // Electricity Safety Test
      _LabeledField(
        label: 'Electricity Safety Test',
        child: DropdownButtonFormField<ElectricitySafetyTestStatus>(
          value: _selectedElectricitySafetyTest,
          decoration: InputDecoration(
            hintText: 'Select',
            hintStyle: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w400),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          items: ElectricitySafetyTestStatus.values.map((s) {
            return DropdownMenuItem<ElectricitySafetyTestStatus>(
              value: s,
              child: Text(s.description, style: theme.textTheme.bodyMedium),
            );
          }).toList(),
          onChanged: (ElectricitySafetyTestStatus? val) {
            setState(() {
              _selectedElectricitySafetyTest = val;
              _electricitySafetyTest = val?.description;
            });
          },
          isExpanded: true,
        ),
      ),
      const SizedBox(height: 24),

      // Complaint Information Section
      Text(
        'Complaint Information',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
      const SizedBox(height: 16),
      // Complaint Details
      _LabeledField(
        label: 'Complaint Details',
        child: TextFormField(
          controller: _complaintCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter complaint details',
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Action Taken
      _LabeledField(
        label: 'Action Taken',
        child: TextFormField(
          controller: _actionTakenCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter action taken',
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Result
      _LabeledField(
        label: 'Result',
        child: TextFormField(
          controller: _resultCtrl,
          decoration: const InputDecoration(
            hintText: 'Enter result',
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Complaint Date Time
      _LabeledField(
        label: 'Complaint Date Time',
        child: TextFormField(
          readOnly: true,
          decoration: InputDecoration(
            hintText: _complaintDateTime != null
                ? '${_complaintDateTime!.day.toString().padLeft(2, '0')}-${_getMonthName(_complaintDateTime!.month)}-${_complaintDateTime!.year} ${_complaintDateTime!.hour.toString().padLeft(2, '0')}:${_complaintDateTime!.minute.toString().padLeft(2, '0')}'
                : 'dd-MMM-yyyy HH:mm',
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          onTap: () async {
            final DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: _complaintDateTime ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (pickedDate != null) {
              final TimeOfDay? pickedTime = await showTimePicker(
                context: context,
                initialTime: _complaintDateTime != null
                    ? TimeOfDay(
                        hour: _complaintDateTime!.hour,
                        minute: _complaintDateTime!.minute)
                    : TimeOfDay.now(),
              );
              if (pickedTime != null) {
                setState(() {
                  _complaintDateTime = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    pickedTime.hour,
                    pickedTime.minute,
                  );
                });
              }
            }
          },
        ),
      ),
      const SizedBox(height: 16),
      // Service Rate
      _LabeledField(
        label: 'Service Rate',
        child: TextFormField(
          controller: _serviceRateCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Enter service rate',
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Service Status
      _LabeledField(
        label: 'Service Status',
        child: DropdownButtonFormField<ServiceReportStatus>(
          value: _selectedServiceReportStatus,
          decoration: InputDecoration(
            hintText: 'Select Status',
            hintStyle: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w400),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          items: ServiceReportStatus.values.map((s) {
            return DropdownMenuItem<ServiceReportStatus>(
              value: s,
              child: Text(s.description, style: theme.textTheme.bodyMedium),
            );
          }).toList(),
          onChanged: (ServiceReportStatus? val) {
            setState(() {
              _selectedServiceReportStatus = val;
              _serviceStatus = val?.description;
            });
          },
          isExpanded: true,
        ),
      ),
      const SizedBox(height: 24),

      // Work Information Section
      Text(
        'Work Information',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
      const SizedBox(height: 16),
      // Work Description
      _LabeledField(
        label: 'Work Description',
        child: TextFormField(
          controller: _workDescriptionCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter work description',
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Materials Used
      _LabeledField(
        label: 'Materials Used',
        child: TextFormField(
          controller: _materialsUsedCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter materials used',
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Remarks
      _LabeledField(
        label: 'Remarks',
        child: TextFormField(
          controller: _serviceRemarksCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter remarks',
          ),
        ),
      ),
      const SizedBox(height: 24),

      // Customer Feedback Section
      Text(
        'Customer Feedback',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
      const SizedBox(height: 16),
      // Feedback Option – selectable cards; responsive for mobile & tablet
      LayoutBuilder(
        builder: (context, constraints) {
          final width = MediaQuery.of(context).size.width;
          final isTablet = width >= 600;
          final emojiSize = isTablet ? 26.0 : 20.0;
          final cardPaddingH = isTablet ? 16.0 : 10.0;
          final cardPaddingV = isTablet ? 12.0 : 8.0;
          final spacing = isTablet ? 12.0 : 8.0;
          final borderRadius = isTablet ? 12.0 : 10.0;
          final labelFontSize = isTablet ? 14.0 : 12.0;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: ServiceFeedbackStatus.values.map((option) {
              final isSelected = _selectedFeedbackOption == option;
              final color = option.borderColor;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedFeedbackOption = option;
                    _feedbackOption = option.description;
                  });
                },
                borderRadius: BorderRadius.circular(borderRadius),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: cardPaddingH,
                    vertical: cardPaddingV,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(
                      color: color,
                      width: isSelected ? 2.5 : 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        option.emoji,
                        style: TextStyle(fontSize: emojiSize),
                      ),
                      SizedBox(height: isTablet ? 4 : 2),
                      Text(
                        option.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: color,
                          fontSize: labelFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      const SizedBox(height: 24),

      // Signature Block Section
      Text(
        'Signature Block',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
      const SizedBox(height: 16),
      // Signed By – text field for signatory name
      _LabeledField(
        label: 'Signed By',
        child: TextFormField(
          controller: _signedByCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Enter signatory name',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Signature – draw box (tap opens signature pad like elsewhere in app)
      _LabeledField(
        label: 'Signature',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _isUploadingSignature
                  ? null
                  : () async {
                      FocusScope.of(context).unfocus();
                      final String? base64 = await _openSignaturePad(context);
                      if (base64 == null || base64.isEmpty) return;
                      setState(() {
                        _signatureImageBase64 = base64;
                        _signatureValue = 'Captured';
                        _isUploadingSignature = true;
                      });
                      final String? path = await _uploadSignatureImage(base64);
                      if (!mounted) return;
                      setState(() {
                        _isUploadingSignature = false;
                        if (path != null) _signatureImageUrl = path;
                      });
                    },
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(
                      color: Colors.grey.shade400, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isUploadingSignature
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(height: 8),
                            Text('Uploading signature…',
                                style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      )
                    : _signatureImageBase64 != null
                        ? Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.memory(
                              base64Decode(_signatureImageBase64!),
                              fit: BoxFit.contain,
                            ),
                          )
                        : _signatureDisplayUrl() != null
                            ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: _SignatureImageFromUrl(
                                  key: ValueKey(_signatureImageUrl),
                                  url: _signatureDisplayUrl()!,
                                ),
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.draw,
                                        color: Colors.grey.shade500, size: 36),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap to draw signature',
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
              ),
            ),
            if (_signatureImageBase64 != null ||
                _signatureImageUrl != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _signatureImageBase64 = null;
                    _signatureValue = null;
                    _signatureImageUrl = null;
                  });
                },
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear signature'),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 24),
      // Save Service Report button (shown when editable, or when view-only but service report edit allowed for submitted DCRs)
      if (!_isViewOnly || widget.allowServiceReportEditOnly)
        FilledButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  // Save Service Report
                  setState(() {
                    _isSubmitting = true;
                  });

                  // Show loading dialog
                  if (!mounted) return;
                  showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                            child: CircularProgressIndicator(),
                          ));

                  try {
                    final dioClient = getIt.isRegistered<DioClient>()
                        ? getIt<DioClient>()
                        : null;
                    if (dioClient == null) {
                      throw Exception('Network client not available');
                    }

                    final int customerId =
                        (_customerNameToId[_serviceReportCustomer] ?? 0);
                    final int productId =
                        (_productNameToId[_serviceReportProduct] ?? 0);
                    final int currentUserId =
                        getIt.isRegistered<UserDetailStore>()
                            ? (getIt<UserDetailStore>().userDetail?.id ?? 0)
                            : 0;
                    final int dcrDetailId = _loadedEntry?.detailId ?? 0;
                    final bool isUpdate =
                        _serviceReportId != null && _serviceReportId! > 0;
                    final DateTime now = DateTime.now();
                    final String dateTimeStr =
                        _formatServiceReportDateTimeForApi(now);
                    // On update, send original CreatedDate in same format (yyyy-MM-dd HH:mm:ss.SSS)
                    String createdDateForPayload = dateTimeStr;
                    if (isUpdate &&
                        _serviceReportCreatedDate != null &&
                        _serviceReportCreatedDate!.isNotEmpty) {
                      createdDateForPayload = _serviceReportCreatedDate!;
                    }
                    // Payload with PascalCase keys to match Service Report Save API
                    final Map<String, dynamic> payload = {
                      'CreatedDate': createdDateForPayload,
                      'ModifiedBy': isUpdate ? currentUserId : 0,
                      'ModifiedDate': dateTimeStr,
                      'Id': _serviceReportId,
                      'CreatedBy': currentUserId,
                      'Status': isUpdate ? 0 : 1,
                      'SbuId': 0,
                      'DcrDetailId': dcrDetailId,
                      'CustomerName': _serviceReportCustomer ?? '',
                      'CustomerId': customerId,
                      'ContactPerson': _contactPersonCtrl.text.trim(),
                      'ContactMobile': _contactMobileCtrl.text.trim(),
                      'ServiceDate': _formatServiceReportDateTimeForApi(
                          _serviceDate ?? DateTime.now()),
                      'ProductId': productId,
                      'Product': _serviceReportProduct ?? '',
                      'SerialNumber': _serialNumberCtrl.text.trim(),
                      'ServiceTypeId': _selectedServiceType?.value ?? 0,
                      'ServiceType': _selectedServiceType?.description ?? '',
                      'StartTime': _startTime != null
                          ? _formatServiceReportDateTimeForApi(_startTime!)
                          : null,
                      'EndTime': _endTime != null
                          ? _formatServiceReportDateTimeForApi(_endTime!)
                          : null,
                      'ElectricitySafetyTest':
                          _selectedElectricitySafetyTest?.description,
                      'ElectricitySafetyTestId':
                          _selectedElectricitySafetyTest?.value ?? 0,
                      'ComplaintDetails': _complaintCtrl.text.trim(),
                      'ActionTaken': _actionTakenCtrl.text.trim(),
                      'Result': _resultCtrl.text.trim(),
                      'ComplaintDateTime': _complaintDateTime != null
                          ? _formatServiceReportDateTimeForApi(
                              _complaintDateTime!)
                          : null,
                      'ServiceStatusId':
                          _selectedServiceReportStatus?.value ?? 0,
                      'ServiceStatus':
                          _selectedServiceReportStatus?.description ?? '',
                      'WorkDescription': _workDescriptionCtrl.text.trim(),
                      'MaterialsUsed': _materialsUsedCtrl.text.trim(),
                      'Remarks': _serviceRemarksCtrl.text.trim(),
                      'FeedbackOption':
                          _selectedFeedbackOption?.description ?? '',
                      'FeedbackOptionId': _selectedFeedbackOption?.value ?? 0,
                      'SignedBy': _signedByCtrl.text.trim(),
                      'SignatureImageUrl': _signatureImageUrl,
                      'ServiceRate':
                          double.tryParse(_serviceRateCtrl.text.trim()) ?? 0.0
                    };
                    // Omit null values except Id (API expects Id: null for new report)
                    payload.removeWhere((k, v) => v == null && k != 'Id');

                    final String url = isUpdate
                        ? Endpoints.serviceReportUpdate
                        : Endpoints.serviceReportSave;
                    print(
                        '📞 [ServiceReport] Sending to $url payload: ${payload}');
                    final response = await dioClient.dio.post(
                      url,
                      data: payload,
                      options: Options(
                        headers: {
                          'Content-Type': 'application/json',
                        },
                      ),
                    );

                    if (mounted) Navigator.of(context).pop(); // close loading

                    if (response.statusCode != null &&
                        response.statusCode! >= 200 &&
                        response.statusCode! < 300) {
                      ToastMessage.show(
                        context,
                        message: 'Service report saved successfully',
                        type: ToastType.success,
                        icon: Icons.check_circle_outline,
                      );
                      print(
                          '✅ [ServiceReport] Save response: ${response.data}');
                    } else {
                      print(
                          '❌ [ServiceReport] Save failed: ${response.statusCode} ${response.data}');
                      ToastMessage.show(
                        context,
                        message: 'Failed to save service report',
                        type: ToastType.error,
                        icon: Icons.error_outline,
                      );
                    }
                  } catch (e, s) {
                    if (mounted) Navigator.of(context).pop();
                    if (e is DioException && e.response != null) {
                      print(
                          '❌ [ServiceReport] Server ${e.response?.statusCode}: ${e.response?.data}');
                    }
                    print(
                        '❌ [ServiceReport] Error saving service report: $e\n$s');
                    ToastMessage.show(
                      context,
                      message: 'Error: ${e.toString()}',
                      type: ToastType.error,
                      icon: Icons.error_outline,
                    );
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isSubmitting = false;
                      });
                    }
                  }
                },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4db1b3),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : const Text('Save'),
        ),
    ];
  }

  String _getMonthName(int month) {
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
    return months[month - 1];
  }

  String _formatServiceDate(DateTime date) {
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
    return '${date.day.toString().padLeft(2, '0')}-${months[date.month - 1]}-${date.year}';
  }

  Future<String?> _openSignaturePad(BuildContext context) async {
    final String? result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 300,
          child: _SignaturePadDialog(),
        ),
      ),
    );
    return result;
  }

  /// Upload signature image (PNG base64) to ServiceReport folder; returns path for SignatureImageUrl.
  Future<String?> _uploadSignatureImage(String base64Png) async {
    if (!getIt.isRegistered<ExpenseApi>()) return null;
    try {
      final bytes = base64Decode(base64Png);
      final name = 'signature_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = PlatformFile(name: name, size: bytes.length, bytes: bytes);
      final api = getIt<ExpenseApi>();
      final res = await api.uploadFile(
        file,
        relativePath: 'Uploads/Attachments/ServiceReport',
      );
      if (res.success && res.path.isNotEmpty) {
        return res.path;
      }
      return null;
    } catch (e) {
      print('❌ [ServiceReport] Signature upload error: $e');
      return null;
    }
  }

  /// Build display URL for signature from saved path.
  /// Server expects: path=%2FUploads%2FAttachmentsServiceReport%2Fsignature_xxx.png (leading slash, no slash between Attachments and ServiceReport).
  String? _signatureDisplayUrl() {
    if (_signatureImageUrl == null || _signatureImageUrl!.isEmpty) return null;
    String p = _signatureImageUrl!.trim();
    if (p.startsWith('http')) return p;
    // Ensure leading slash for path param
    if (!p.startsWith('/')) p = '/$p';
    final pathParam = Uri.encodeComponent(p);
    return '${Endpoints.fileDownloadBaseUrl}/FileDownload/Download?path=$pathParam';
  }

  // Build Customer Fields
  List<Widget> _buildCustomerFields(BuildContext context, ThemeData theme) {
    final UserDetailStore? userStore =
        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final String? roleCategory = userStore?.userDetail?.serviceArea;
    final bool isMedicalRep = roleCategory == 'Medical Rep';

    return [
      // Customer Name (uppercase for API)
      _LabeledField(
        label: 'Customer',
        child: TextFormField(
          controller: _customerNameCtrl,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            TextInputFormatter.withFunction(
              (_, value) => TextEditingValue(
                text: value.text.toUpperCase(),
                selection: value.selection,
                composing: value.composing,
              ),
            ),
          ],
          decoration: const InputDecoration(
            hintText: 'Enter customer name',
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Code
      _LabeledField(
        label: 'Code',
        child: TextFormField(
          controller: _customerCodeCtrl,
          decoration: const InputDecoration(
            hintText: 'Enter customer code',
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Customer Type * — only for Sales Representatives (not shown for Medical Rep)
      if (!isMedicalRep) ...[
        _LabeledField(
          label: 'Customer Type',
          required: true,
          child: SearchableDropdown(
            options: _customerTypeOptions,
            value: _selectedCustomerType,
            hintText: '-- Select Customer Type --',
            searchHintText: 'Search customer type...',
            onChanged: (v) {
              setState(() {
                _selectedCustomerType = v;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
      // Speciality, Category, Area Type, UIN — only for Medical Representative (roleCategory == 3)
      if (isMedicalRep) ...[
        _LabeledField(
          label: 'Speciality',
          child: SearchableDropdown(
            options: _specialityOptions,
            value: _selectedSpeciality,
            hintText: '-- Select Speciality --',
            searchHintText: 'Search speciality...',
            onChanged: (v) {
              setState(() {
                _selectedSpeciality = v;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'Category',
          child: SearchableDropdown(
            options: _categoryOptions,
            value: _selectedCategory,
            hintText: '-- Select Category --',
            searchHintText: 'Search category...',
            onChanged: (v) {
              setState(() {
                _selectedCategory = v;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'Area Type',
          child: SearchableDropdown(
            options: _areaTypeOptions,
            value: _selectedAreaType,
            hintText: '-- Select Area Type --',
            searchHintText: 'Search area type...',
            onChanged: (v) {
              setState(() {
                _selectedAreaType = v;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'UIN',
          child: TextFormField(
            controller: _uinCtrl,
            keyboardType: TextInputType.number,
            maxLength: _kUinMaxDigits,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              hintText: 'Enter UIN (max $_kUinMaxDigits digits)',
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
      // Mobile *
      _LabeledField(
        label: 'Mobile',
        required: true,
        child: TextFormField(
          controller: _customerMobileCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: 'Enter mobile number',
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Country *
      _LabeledField(
        label: 'Country',
        required: true,
        child: SearchableDropdown(
          options: _countryOptions,
          value: _selectedCountry,
          hintText: '-- Select Country --',
          searchHintText: 'Search country...',
          onChanged: (v) {
            setState(() {
              _selectedCountry = v;
              _selectedState = null;
              _selectedCity = null;
              _stateOptions.clear();
              _cityOptions.clear();
              // Load states for selected country
              if (v != null) {
                final int? countryId = _countryNameToId[v];
                if (countryId != null && countryId > 0) {
                  _loadStates(countryId);
                }
              }
            });
          },
        ),
      ),
      const SizedBox(height: 16),
      // State *
      _LabeledField(
        label: 'State',
        required: true,
        child: SearchableDropdown(
          options: _stateOptions,
          value: _selectedState,
          hintText: '-- Select State --',
          searchHintText: 'Search state...',
          onChanged: (v) {
            setState(() {
              _selectedState = v;
              _selectedCity = null;
              _cityOptions.clear();
              // Load cities for selected state
              if (v != null) {
                final int? stateId = _stateNameToId[v];
                if (stateId != null && stateId > 0) {
                  _loadCities(stateId);
                }
              }
            });
          },
        ),
      ),
      const SizedBox(height: 16),
      // City *
      _LabeledField(
        label: 'City',
        required: true,
        child: SearchableDropdown(
          options: _cityOptions,
          value: _selectedCity,
          hintText: '-- Select City --',
          searchHintText: 'Search city...',
          onChanged: (v) {
            setState(() {
              _selectedCity = v;
            });
          },
        ),
      ),
      const SizedBox(height: 20),
      // Save Customer button (hidden in view-only mode)
      if (!_isViewOnly)
        FilledButton(
          onPressed: _saveNewCustomer,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4db1b3),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
          ),
          child: const Text('Save Customer'),
        ),
    ];
  }

  Future<void> _saveNewCustomer() async {
    final String name = _customerNameCtrl.text.trim().toUpperCase();
    final String code = _customerCodeCtrl.text.trim();
    final String mobile = _customerMobileCtrl.text.trim();
    final String uin = _uinCtrl.text.trim();
    final String? serviceArea = getIt.isRegistered<UserDetailStore>()
        ? getIt<UserDetailStore>().userDetail?.serviceArea
        : null;

    if (name.isEmpty) {
      ToastMessage.show(
        context,
        message: 'Please enter customer name',
        type: ToastType.error,
        icon: Icons.error_outline,
      );
      return;
    }
    // Customer Type required only for Sales Rep (Pharmacy save); not for Medical Rep (Doctor save)
    final bool isMedicalRepServiceArea = serviceArea == 'Medical Rep';
    if (!isMedicalRepServiceArea) {
      if (_selectedCustomerType == null ||
          !_customerTypeNameToId.containsKey(_selectedCustomerType)) {
        ToastMessage.show(
          context,
          message: 'Please select customer type',
          type: ToastType.error,
          icon: Icons.error_outline,
        );
        return;
      }
    }
    if (mobile.isEmpty) {
      ToastMessage.show(
        context,
        message: 'Please enter mobile number',
        type: ToastType.error,
        icon: Icons.error_outline,
      );
      return;
    }
    if (_selectedCountry == null ||
        !_countryNameToId.containsKey(_selectedCountry)) {
      ToastMessage.show(
        context,
        message: 'Please select country',
        type: ToastType.error,
        icon: Icons.error_outline,
      );
      return;
    }
    if (_selectedState == null || !_stateNameToId.containsKey(_selectedState)) {
      ToastMessage.show(
        context,
        message: 'Please select state',
        type: ToastType.error,
        icon: Icons.error_outline,
      );
      return;
    }
    if (_selectedCity == null || !_cityNameToId.containsKey(_selectedCity)) {
      ToastMessage.show(
        context,
        message: 'Please select city',
        type: ToastType.error,
        icon: Icons.error_outline,
      );
      return;
    }
    // UIN is int on backend; must be within 32-bit signed int range (max $_kUinMaxDigits digits)
    if (uin.isNotEmpty) {
      final int? uinVal = int.tryParse(uin);
      if (uinVal == null || uinVal < 0 || uinVal > _kUinMaxInt) {
        ToastMessage.show(
          context,
          message:
              'UIN must be a number with at most $_kUinMaxDigits digits (max $_kUinMaxInt)',
          type: ToastType.error,
          icon: Icons.error_outline,
        );
        return;
      }
    }

    final UserDetailStore? userDetailStore =
        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final int currentUserId = userDetailStore?.userDetail?.id ?? 0;
    final int? roleCategory = userDetailStore?.userDetail?.roleCategory;
    final int? employeeId = userDetailStore?.userDetail?.employeeId;
    final int userSbuId = userDetailStore?.userDetail?.sbuId ?? 1;
    // serviceArea and isMedicalRepServiceArea already declared at top of method
    // Medical Rep: roleCategory == 3 → Doctor/Save. Else → Pharmacy/Save (Sales Rep).
    final bool isMedicalRep = roleCategory == 3;

    if (isMedicalRepServiceArea) {
      // Medical Rep service area: require Speciality, Category, Area Type (UIN is optional)
      if (_selectedSpeciality == null ||
          !_specialityNameToId.containsKey(_selectedSpeciality)) {
        ToastMessage.show(
          context,
          message: 'Please select speciality',
          type: ToastType.error,
          icon: Icons.error_outline,
        );
        return;
      }
      if (_selectedCategory == null ||
          !_categoryNameToId.containsKey(_selectedCategory)) {
        ToastMessage.show(
          context,
          message: 'Please select category',
          type: ToastType.error,
          icon: Icons.error_outline,
        );
        return;
      }
      if (_selectedAreaType == null ||
          !_areaTypeNameToId.containsKey(_selectedAreaType)) {
        ToastMessage.show(
          context,
          message: 'Please select area type',
          type: ToastType.error,
          icon: Icons.error_outline,
        );
        return;
      }
    }
    // Non–Medical Rep service area: no validation for Speciality, Category, Area Type, UIN

    final dioClient =
        getIt.isRegistered<DioClient>() ? getIt<DioClient>() : null;
    if (dioClient == null) {
      ToastMessage.show(
        context,
        message: 'Network client not available',
        type: ToastType.error,
        icon: Icons.error_outline,
      );
      return;
    }

    final int? customerTypeId = _selectedCustomerType != null &&
            _customerTypeNameToId.containsKey(_selectedCustomerType!)
        ? _customerTypeNameToId[_selectedCustomerType!]
        : null;
    final int? countryId = _countryNameToId[_selectedCountry!];
    final int? stateId = _stateNameToId[_selectedState!];
    final int? cityId = _cityNameToId[_selectedCity!];

    // Ensure we have valid IDs to avoid server 500 (many backends reject 0 or null for required fields)
    if (countryId == null || countryId <= 0) {
      ToastMessage.show(
        context,
        message: 'Please select a valid country',
        type: ToastType.error,
        icon: Icons.error_outline,
      );
      return;
    }
    if (stateId == null || stateId <= 0) {
      ToastMessage.show(
        context,
        message: 'Please select a valid state',
        type: ToastType.error,
        icon: Icons.error_outline,
      );
      return;
    }
    if (cityId == null || cityId <= 0) {
      ToastMessage.show(
        context,
        message: 'Please select a valid city',
        type: ToastType.error,
        icon: Icons.error_outline,
      );
      return;
    }
    // Customer Type required only for Sales Rep (Pharmacy save)
    if (!isMedicalRepServiceArea &&
        (customerTypeId == null || customerTypeId < 0)) {
      ToastMessage.show(
        context,
        message: 'Please select a valid customer type',
        type: ToastType.error,
        icon: Icons.error_outline,
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final String url;
      final Map<String, dynamic> payload;

      // Use Doctor save only when Medical Rep service area (fields were shown and validated).
      // Otherwise use Pharmacy save to avoid null on Speciality/Category/Area Type.
      if (isMedicalRep && isMedicalRepServiceArea) {
        final int? specialityId =
            _specialityNameToId[_selectedSpeciality ?? ''];
        final int? categoryId = _categoryNameToId[_selectedCategory ?? ''];
        final int? areaTypeId = _areaTypeNameToId[_selectedAreaType ?? ''];
        // Server often returns 500 when required doctor fields are 0 or missing
        if (specialityId == null ||
            specialityId <= 0 ||
            categoryId == null ||
            categoryId <= 0 ||
            areaTypeId == null ||
            areaTypeId <= 0) {
          if (!mounted) return;
          Navigator.of(context).pop();
          ToastMessage.show(
            context,
            message: 'Please select valid Speciality, Category and Area Type',
            type: ToastType.error,
            icon: Icons.error_outline,
          );
          return;
        }
        url = Endpoints.doctorSave;
        // API doc: SubType = 1 for Doctor. Use user's sbuId and empty string for optional text fields.
        payload = {
          'Id': null,
          'UserId': currentUserId,
          'CreatedBy': currentUserId,
          'Status': 0,
          'SbuId': userSbuId,
          'Name': name,
          'Code': code.isNotEmpty ? code : 'DCRCUST',
          'CountryId': countryId,
          'CustomerId': null,
          'StateId': stateId,
          'CityId': cityId,
          'TownId': null,
          'CityText': '',
          'CountryText': '',
          'TownText': '',
          'StateText': '',
          'Speciality': specialityId,
          'SpecialityText': '',
          'Category': categoryId,
          'CategoryText': '',
          'Qualification': null,
          'QualificationText': '',
          'Class': null,
          'AreaType': areaTypeId,
          'AreaTypeText': '',
          'Address': '',
          'HospitalName': '',
          'HospitalAddress': '',
          'MobileNo': mobile.isNotEmpty ? mobile : '',
          'DOB': null,
          'AnniversaryDate': null,
          'UIN': uin.isNotEmpty ? uin : '',
          'JobCategoryText': '',
          'GenderText': '',
          'Gender': null,
          'JobCategory': null,
          'QualificationRequested': null,
          'QualificationList': null,
          'CityRequested': null,
          'CityList': null,
          'ItemRequested': null,
          'ItemList': null,
          'Active': 1,
          'ActiveText': '',
          'SubType': 1,
        };
      } else {
        // Pharmacy/Save: minimal payload per API doc; omit nulls. Omit *Text fields so server gets only core fields.
        url = Endpoints.pharmacySave;
        final int? salesRepId =
            (employeeId != null && employeeId > 0) ? employeeId : null;
        final Map<String, dynamic> pharmacyRaw = {
          'Id': null,
          'SbuId': userSbuId,
          'UserId': currentUserId,
          'CreatedBy': currentUserId,
          'Status': 0,
          'Name': name,
          'Code': code.isNotEmpty ? code : 'SALCUST',
          'Address': null,
          'CustomerId': null,
          'CountryId': countryId,
          'StateId': stateId,
          'CityId': cityId,
          'DistrictId': null,
          'TownId': null,
          'ZipCode': null,
          'Type': customerTypeId!,
          'Zip': null,
          'SalesRepId': salesRepId,
          'FieldManagerId': null,
          'Provinance': null,
          'Active': 1,
          'DistributerId': null,
          'BizUnit': userSbuId,
          'SubType': 0,
          'IsFromDCR': 1,
        };
        payload = Map.fromEntries(
          pharmacyRaw.entries.where((e) => e.value != null),
        );
      }

      final response = await dioClient.dio.post(
        url,
        data: payload,
        options: Options(
          headers: const {'Content-Type': 'application/json'},
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close loader

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        ToastMessage.show(
          context,
          message: 'Customer saved successfully',
          type: ToastType.success,
          icon: Icons.check_circle_outline,
        );
      } else {
        String? serverMsg;
        final headers = response.headers.map;
        if (headers.containsKey('errormessage')) {
          serverMsg = headers['errormessage']?.first;
        }
        if (serverMsg == null || serverMsg.trim().isEmpty) {
          serverMsg = _extractServerErrorMessage(response.data);
        }
        final message = _customerSaveErrorMessage(serverMsg);
        ToastMessage.show(
          context,
          message: message,
          type: ToastType.error,
          icon: Icons.error_outline,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // close loader if open
        String? serverMsg;
        if (e is DioException && e.response != null) {
          final resp = e.response!;
          final dynamic data = resp.data;
          final int? statusCode = resp.statusCode;
          print('Pharmacy/Doctor Save $statusCode - Full response: $data');
          final headers = resp.headers.map;
          if (headers.containsKey('errormessage')) {
            serverMsg = headers['errormessage']?.first;
          }
          if (serverMsg == null || serverMsg.trim().isEmpty) {
            serverMsg = _extractServerErrorMessage(data);
          }
        }
        final message = _customerSaveErrorMessage(serverMsg);
        ToastMessage.show(
          context,
          message: message,
          type: ToastType.error,
          icon: Icons.error_outline,
        );
      }
    }
  }

  /// Whether the server message indicates duplicate customer number/code.
  bool _isDuplicateCustomerNumberError(String? msg) {
    if (msg == null || msg.trim().isEmpty) return false;
    final lower = msg.trim().toLowerCase();
    return lower.contains('already exist') ||
        lower.contains('duplicate') ||
        lower.contains('customer with this') ||
        lower.contains('code already') ||
        lower.contains('name already');
  }

  /// Resolve user-facing message for customer save error (duplicate vs other).
  String _customerSaveErrorMessage(String? serverMsg) {
    if (_isDuplicateCustomerNumberError(serverMsg)) {
      return 'Customer with this name already exists. try with another';
    }
    return serverMsg != null && serverMsg.trim().isNotEmpty
        ? serverMsg.trim()
        : 'Action failed, pls try again later';
  }

  /// Extract error message from server response (Map, String, or List).
  String? _extractServerErrorMessage(dynamic data) {
    if (data == null) return null;
    if (data is String)
      return data.trim().isEmpty
          ? null
          : (data.length > 300 ? '${data.substring(0, 300)}...' : data);
    if (data is Map) {
      // .NET often uses ExceptionMessage, message, error, or nested innerException
      final msg = data['ExceptionMessage'] ??
          data['exceptionMessage'] ??
          data['message'] ??
          data['Message'] ??
          data['error'] ??
          data['Error'] ??
          data['MessageDetail'] ??
          data['messageDetail'];
      if (msg != null && msg.toString().trim().isNotEmpty)
        return msg.toString().trim();
      final inner = data['innerException'] ?? data['InnerException'];
      if (inner is Map) return _extractServerErrorMessage(inner);
      if (inner is String && inner.trim().isNotEmpty) return inner.trim();
    }
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is String) return first;
      if (first is Map) return _extractServerErrorMessage(first);
    }
    return null;
  }

  // Build Location Picker Widget
  Widget _buildLocationPicker(
      BuildContext context, ThemeData theme, Color tealGreen) {
    return _LabeledField(
      label: 'Location (optional)',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _position == null
                      ? 'No location selected'
                      : 'Lat: ${_position!.latitude.toStringAsFixed(6)}, Lng: ${_position!.longitude.toStringAsFixed(6)}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await _initLocation();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tealGreen,
                      side: BorderSide(color: tealGreen, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Use current'),
                  ),
                ),
              ],
            );
          } else {
            return Row(
              children: [
                Expanded(
                  child: Text(
                    _position == null
                        ? 'No location selected'
                        : 'Lat: ${_position!.latitude.toStringAsFixed(6)}, Lng: ${_position!.longitude.toStringAsFixed(6)}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.grey.shade700),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    await _initLocation();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tealGreen,
                    side: BorderSide(color: tealGreen, width: 1.5),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Use current'),
                ),
              ],
            );
          }
        },
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
    return '${date.day.toString().padLeft(2, '0')}-${months[date.month - 1]}-${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.now();
    final DateTime todayDateOnly = DateTime(today.year, today.month, today.day);
    final DateTime firstAllowedDate = DateTime(2020);
    final DateTime safeInitialDate = initialDate.isAfter(todayDateOnly)
        ? todayDateOnly
        : initialDate.isBefore(firstAllowedDate)
            ? firstAllowedDate
            : initialDate;

    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        hintText: _formatDate(initialDate),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: safeInitialDate,
          firstDate: firstAllowedDate,
          lastDate: todayDateOnly,
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
    if (_customerRequiredForSelectedVisitType &&
        (_customer == null || _customer!.trim().isEmpty)) {
      customerError = 'Please select a customer';
      isValid = false;
      firstMessage ??= 'Select a customer';
    }

    String? purposeError;
    if (_purpose == null ||
        _purpose!.trim().isEmpty ||
        _purpose == 'Loading...') {
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

    String? productsError;
    if (!_isServiceEngineer && _selectedProducts.isEmpty) {
      productsError = 'Please select at least one product to discuss';
      isValid = false;
      firstMessage ??= 'Select at least one product to discuss';
    }

    // Service Engineer specific validation
    // String? instrumentsError;
    // if (_isServiceEngineer && _selectedInstruments.isEmpty) {
    //   instrumentsError = 'Please select at least one mapped instrument';
    //   isValid = false;
    //   firstMessage ??= 'Select at least one mapped instrument';
    // }

    // Co-visit manager validation
    String? managerError;
    if (_coVisit &&
        (_selectedManager == null || _selectedManager!.trim().isEmpty)) {
      managerError = 'Please select a manager for co-visit';
      isValid = false;
      firstMessage ??= 'Select a manager for co-visit';
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
      _productsErrorText = productsError;
      // _instrumentsErrorText = instrumentsError;
      _managerErrorText = managerError;
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
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      final userDetail = userStore?.userDetail;

      if (userDetail == null) {
        throw Exception('User data not available. Please login again.');
      }

      // Get IDs from the name-to-ID maps, with fallbacks for editing
      int? typeOfWorkId =
          _typeOfWorkNameToId[_purpose] ?? widget.initialTypeOfWorkId;
      int? cityId = _clusterNameToId[_cluster] ?? widget.initialClusterId;
      int? customerId =
          _customerNameToId[_customer] ?? widget.initialCustomerId;

      // If we're editing and still don't have IDs, use fallback values
      if (widget.dcrId != null) {
        typeOfWorkId ??= 1; // Default fallback for editing
        cityId ??= 1; // Default fallback for editing
        if (_customerRequiredForSelectedVisitType) {
          customerId ??= 1; // Default fallback for editing when customer is required
        }
      }

      // Debug logging
      print('DCR Validation Debug:');
      print('  Purpose: $_purpose');
      print('  TypeOfWorkId from map: ${_typeOfWorkNameToId[_purpose]}');
      print('  InitialTypeOfWorkId: ${widget.initialTypeOfWorkId}');
      print('  Final typeOfWorkId: $typeOfWorkId');
      print(
          '  Cluster selected count: ${(_cluster?.trim().isNotEmpty ?? false) ? 1 : 0}');
      print('  CityId from map: ${_clusterNameToId[_cluster]}');
      print('  InitialClusterId: ${widget.initialClusterId}');
      print('  Final cityId: $cityId');
      print(
          '  Customer selected count: ${(_customer?.trim().isNotEmpty ?? false) ? 1 : 0}');
      print('  CustomerId from map: ${_customerNameToId[_customer]}');
      print('  InitialCustomerId: ${widget.initialCustomerId}');
      print('  Final customerId: $customerId');

      // Validate that we have all required IDs
      if (typeOfWorkId == null) {
        print('ERROR: No typeOfWorkId found for purpose: $_purpose');
        print(
            'Available purposes in map: ${_typeOfWorkNameToId.keys.toList()}');
        throw Exception('Please select a valid purpose of visit');
      }
      if (cityId == null) {
        print('ERROR: No cityId found for selected cluster');
        print('Available clusters in map count: ${_clusterNameToId.length}');
        throw Exception('Please select a valid cluster/locality');
      }
      if (_customerRequiredForSelectedVisitType && customerId == null) {
        print('ERROR: No customerId found for selected customer');
        print('Available customers in map count: ${_customerNameToId.length}');
        throw Exception('Please select a valid customer');
      }

      final DateTime visit = DateTime(
          _date.year, _date.month, _date.day, _time.hour, _time.minute);
      final repo = getIt<DcrRepository>();

      // Get manager ID if co-visit is selected
      int? coVisitorId;
      if (_coVisit &&
          _selectedManager != null &&
          _selectedManager!.trim().isNotEmpty) {
        coVisitorId = _managerNameToId[_selectedManager];
        if (coVisitorId == null || coVisitorId <= 0) {
          throw Exception(
              'Invalid manager selected. Please select a valid manager.');
        }
      }

      // Use same logic as dropdowns for UserId consistency
      int actualUserId = userDetail.id;
      if (userDetail.serviceArea.trim() == 'Service Engineer') {
        if (userDetail.employeeId > 0) {
          actualUserId = userDetail.employeeId;
        }
      }

      // Create params with the IDs from UserStore and name-to-ID maps
      final params = CreateDcrParams(
        date: visit,
        cluster: _cluster!,
        customer: _customerRequiredForSelectedVisitType ? (_customer ?? '') : '',
        purposeOfVisit: _purpose!,
        callDurationMinutes: int.tryParse(_durationCtrl.text.trim()) ?? 0,
        productsDiscussed: _selectedProducts.join(', '),
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
        customerId: _customerRequiredForSelectedVisitType ? customerId : null,
        userId: actualUserId,
        bizunit: userDetail.sbuId,
        latitude: _position?.latitude,
        longitude: _position?.longitude,
        // Service Engineer specific fields
        mappedInstruments: _isServiceEngineer && _selectedInstruments.isNotEmpty
            ? _selectedInstruments.map((instrumentName) {
                final instrumentId = _instrumentNameToId[instrumentName] ?? 0;
                return <String, dynamic>{
                  'productId': instrumentId,
                  'productName': instrumentName,
                  'customerId': customerId ?? 0,
                };
              }).toList()
            : null,
        complaint: _isServiceEngineer && _complaintCtrl.text.trim().isNotEmpty
            ? _complaintCtrl.text.trim()
            : null,
        actionTaken:
            _isServiceEngineer && _actionTakenCtrl.text.trim().isNotEmpty
                ? _actionTakenCtrl.text.trim()
                : null,
        result: _isServiceEngineer && _resultCtrl.text.trim().isNotEmpty
            ? _resultCtrl.text.trim()
            : null,
        complaintStatus:
            _isServiceEngineer && _selectedServiceReportStatus != null
                ? (_selectedServiceReportStatus == ServiceReportStatus.Resolved
                    ? 1
                    : 0) // API: 1 = Resolved, 0 = Not Resolved
                : null,
        complaintDate:
            _isServiceEngineer ? (_complaintDateTime ?? _complaintDate) : null,
        complaintRemarks:
            _isServiceEngineer && _complaintRemarksCtrl.text.trim().isNotEmpty
                ? _complaintRemarksCtrl.text.trim()
                : null,
        // Co-visit fields
        coVisit: _coVisit,
        coVisitorId: coVisitorId,
      );

      print('Creating DCR: ${submit ? "Submit" : "Draft"}');
      print(
          'User Data - EmployeeId: ${userDetail.employeeId}, UserId: ${userDetail.id}, Name: ${userDetail.employeeName}');
      print(
          'Mapped IDs - TypeOfWorkId: $typeOfWorkId, CityId: $cityId, CustomerId: $customerId');

      // For update, we also use CreateDcrParams to ensure Service Report fields are included
      // The repository will handle the update by checking if dcrId is provided
      if (widget.id != null || widget.dcrId != null) {
        // Update existing DCR via API - use create method with dcrId set
        // Use dcrId for root ID if available, otherwise use id
        final String dcrIdToUpdate = widget.dcrId ?? widget.id!;
        print(
            'Updating DCR with detailId: ${_loadedEntry?.detailId}, clusterId: ${_loadedEntry?.clusterId}');
        print(
            'Using dcrIdToUpdate: $dcrIdToUpdate (from widget.dcrId: ${widget.dcrId}, widget.id: ${widget.id})');

        // Create params with update info - add dcrId to params for update
        final updateParams = CreateDcrParams(
          date: visit,
          cluster: _cluster!,
          customer: _customerRequiredForSelectedVisitType ? (_customer ?? '') : '',
          purposeOfVisit: _purpose!,
          callDurationMinutes: int.tryParse(_durationCtrl.text.trim()) ?? 0,
          productsDiscussed: _selectedProducts.join(', '),
          samplesDistributed: _samplesCtrl.text.trim(),
          keyDiscussionPoints: _discussionCtrl.text.trim(),
          linkedTourPlanId: _loadedEntry?.linkedTourPlanId,
          employeeId: userDetail.employeeId.toString(),
          employeeName: userDetail.employeeName,
          submit: submit,
          geoProximity: _atLocation ? GeoProximity.at : GeoProximity.away,
          typeOfWorkId: typeOfWorkId,
          cityId: cityId,
          customerId: _customerRequiredForSelectedVisitType ? customerId : null,
          userId: actualUserId,
          bizunit: userDetail.sbuId,
          latitude: _position?.latitude,
          longitude: _position?.longitude,
          // Service Engineer specific fields
          mappedInstruments: _isServiceEngineer &&
                  _selectedInstruments.isNotEmpty
              ? _selectedInstruments.map((instrumentName) {
                  final instrumentId = _instrumentNameToId[instrumentName] ?? 0;
                  return <String, dynamic>{
                    'productId': instrumentId,
                    'productName': instrumentName,
                    'customerId': customerId ?? 0,
                  };
                }).toList()
              : null,
          complaint: _isServiceEngineer && _complaintCtrl.text.trim().isNotEmpty
              ? _complaintCtrl.text.trim()
              : null,
          actionTaken:
              _isServiceEngineer && _actionTakenCtrl.text.trim().isNotEmpty
                  ? _actionTakenCtrl.text.trim()
                  : null,
          result: _isServiceEngineer && _resultCtrl.text.trim().isNotEmpty
              ? _resultCtrl.text.trim()
              : null,
          complaintStatus: _isServiceEngineer &&
                  _selectedServiceReportStatus != null
              ? (_selectedServiceReportStatus == ServiceReportStatus.Resolved
                  ? 1
                  : 0) // API: 1 = Resolved, 0 = Not Resolved
              : null,
          complaintDate: _isServiceEngineer
              ? (_complaintDateTime ?? _complaintDate)
              : null,
          complaintRemarks:
              _isServiceEngineer && _complaintRemarksCtrl.text.trim().isNotEmpty
                  ? _complaintRemarksCtrl.text.trim()
                  : null,
          // Co-visit fields
          coVisit: _coVisit,
          coVisitorId: coVisitorId,
          // Update fields
          dcrId: dcrIdToUpdate,
          detailId: _loadedEntry?.detailId,
        );

        // Use create method which will handle update if dcrId is provided
        await repo.create(updateParams);
      } else {
        await repo.create(params);
      }

      if (!mounted) return;
      if (widget.id != null || widget.dcrId != null) {
        _showSuccessSnack(submit
            ? 'DCR updated & submitted successfully'
            : 'DCR updated successfully');
      } else {
        _showSuccessSnack(
            submit ? 'DCR submitted successfully' : 'Draft saved successfully');
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

// Multi-select dropdown widget for Products to Discuss
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
final Set<OverlayEntry> _dcrSharedOpenOverlays = {};

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
    _displayFocusNode.canRequestFocus = false;
    _searchFocusNode.unfocus();
  }

  @override
  void didUpdateWidget(covariant _MultiSelectDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!setEquals(_selected, widget.selectedValues)) {
      _selected = {...widget.selectedValues};
    }
    _updateDisplayText();
  }

  void _updateDisplayText() {
    final Set<String> currentValues =
        setEquals(_selected, widget.selectedValues)
            ? _selected
            : widget.selectedValues;
    final String display = _summary(currentValues);
    if (_displayController.text != display) {
      _displayController.text = display;
      _displayController.selection =
          TextSelection.collapsed(offset: display.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!setEquals(_selected, widget.selectedValues)) {
      _selected = {...widget.selectedValues};
    }

    final String display = _summary(widget.selectedValues);
    if (_displayController.text != display) {
      _displayController.text = display;
      _displayController.selection =
          TextSelection.collapsed(offset: display.length);
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
    for (final overlay in _dcrSharedOpenOverlays.toList()) {
      overlay.remove();
    }
    _dcrSharedOpenOverlays.clear();

    _displayFocusNode.unfocus();
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    _selected = {...widget.selectedValues};
    _updateDisplayText();
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Size size = box.size;
    _entry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
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

                                final filtered = _query.isEmpty
                                    ? widget.options
                                    : widget.options
                                        .where((o) =>
                                            o.toLowerCase().contains(_query))
                                        .toList(growable: false);

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
                                  primary: false,
                                  physics: const ClampingScrollPhysics(),
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
    _dcrSharedOpenOverlays.add(_entry!);

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
      _dcrSharedOpenOverlays.remove(_entry);
      _entry = null;
    }
    _searchFocusNode.unfocus();
  }

  void _toggle(String opt) {
    if (_selected.contains(opt)) {
      _selected.remove(opt);
    } else {
      _selected.add(opt);
    }
    final String display = _summary(_selected);
    _displayController.text = display;
    _displayController.selection =
        TextSelection.collapsed(offset: display.length);

    widget.onChanged({..._selected});
    _entry?.markNeedsBuild();
    setState(() {});
  }

  String _summary(Set<String> values) {
    if (values.isEmpty) return '';
    if (values.length <= 2) return values.join(', ');
    final firstTwo = values.take(2).join(', ');
    return '$firstTwo +${values.length - 2}';
  }
}

/// Loads signature image via Dio (uses app SSL bypass) and displays as Image.memory.
class _SignatureImageFromUrl extends StatefulWidget {
  const _SignatureImageFromUrl({super.key, required this.url});

  final String url;

  @override
  State<_SignatureImageFromUrl> createState() => _SignatureImageFromUrlState();
}

class _SignatureImageFromUrlState extends State<_SignatureImageFromUrl> {
  Uint8List? _bytes;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!getIt.isRegistered<DioClient>()) {
      if (mounted) setState(() => _error = true);
      return;
    }
    try {
      final dio = getIt<DioClient>().dio;
      final res = await dio.get<List<int>>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (!mounted) return;
      if (res.data != null && res.data!.isNotEmpty) {
        setState(() {
          _bytes = Uint8List.fromList(res.data!);
          _error = false;
        });
      } else {
        setState(() => _error = true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return Image.memory(_bytes!, fit: BoxFit.contain);
    }
    if (_error) {
      return const Center(child: Icon(Icons.broken_image_outlined));
    }
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

// Signature Pad Dialog
class _SignaturePadDialog extends StatefulWidget {
  @override
  State<_SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<_SignaturePadDialog> {
  final GlobalKey _repaintKey = GlobalKey();
  List<Offset?> _points = [];

  void _clear() {
    setState(() {
      _points = [];
    });
  }

  Future<void> _save() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final base64 = base64Encode(bytes);
      Navigator.of(context).pop(base64);
    } catch (e, s) {
      print('❌ Signature save error: $e\n$s');
      Navigator.of(context).pop(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Add Signature',
                  style: Theme.of(context).textTheme.titleMedium),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _clear,
                    tooltip: 'Clear drawing',
                  ),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: _save,
                    tooltip: 'Save signature',
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.close, size: 20),
                    label: const Text('Close'),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              )
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: RepaintBoundary(
            key: _repaintKey,
            child: GestureDetector(
              onPanStart: (details) {
                final box = _repaintKey.currentContext?.findRenderObject()
                    as RenderBox?;
                if (box == null) return;
                final localPos = box.globalToLocal(details.globalPosition);
                final Size sz = box.size;
                final bool inside = localPos.dx >= 0 &&
                    localPos.dy >= 0 &&
                    localPos.dx <= sz.width &&
                    localPos.dy <= sz.height;
                if (!inside) {
                  // end previous stroke if any
                  setState(() => _points = List.from(_points)..add(null));
                  return;
                }
                setState(() {
                  _points = List.from(_points)..add(localPos);
                });
              },
              onPanUpdate: (details) {
                final box = _repaintKey.currentContext?.findRenderObject()
                    as RenderBox?;
                if (box == null) return;
                final localPos = box.globalToLocal(details.globalPosition);
                final Size sz = box.size;
                final bool inside = localPos.dx >= 0 &&
                    localPos.dy >= 0 &&
                    localPos.dx <= sz.width &&
                    localPos.dy <= sz.height;
                if (!inside) {
                  // mark stroke break when pointer leaves modal area
                  setState(() => _points = List.from(_points)..add(null));
                  return;
                }
                setState(() {
                  _points = List.from(_points)..add(localPos);
                });
              },
              onPanEnd: (details) => setState(() => _points.add(null)),
              child: ClipRect(
                child: CustomPaint(
                  painter: _SignaturePainter(_points),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      final p = points[i];
      final p2 = points[i + 1];
      if (p != null && p2 != null) {
        canvas.drawLine(p, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) =>
      oldDelegate.points != points;
}
