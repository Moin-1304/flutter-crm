import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'customer_issue_list_screen.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/core/widgets/app_dropdowns.dart';
import 'package:boilerplate/data/network/constants/endpoints.dart';
import 'package:boilerplate/domain/repository/workflow/workflow_repository.dart';
import 'package:boilerplate/domain/entity/workflow/workflow_api_models.dart';
import 'package:boilerplate/domain/repository/item_issue/item_issue_repository.dart';
import 'package:boilerplate/domain/entity/item_issue/item_issue_api_models.dart';

class ItemDetail {
  String? divisionCategory;
  String? itemDescription;
  String? batchNo;
  int? batchId; // Store batch ID when batch is selected
  TextEditingController qtyInStockCtrl = TextEditingController();
  TextEditingController qtyIssuedCtrl = TextEditingController();
  TextEditingController uomCtrl = TextEditingController();
  TextEditingController rateCtrl = TextEditingController();
  TextEditingController amountCtrl = TextEditingController();
  TextEditingController remarksCtrl = TextEditingController();
  String? divisionCategoryError;
  String? itemDescriptionError;
  String? qtyIssuedError;

  // Dropdown options for this item (can be loaded per item or shared)
  List<String> itemDescriptionOptions = [];
  List<String> batchNoOptions = [];

  ItemDetail();

  void dispose() {
    qtyInStockCtrl.dispose();
    qtyIssuedCtrl.dispose();
    uomCtrl.dispose();
    rateCtrl.dispose();
    amountCtrl.dispose();
    remarksCtrl.dispose();
  }
}

class CustomerIssueEntryScreen extends StatefulWidget {
  final String? issueId; // Optional issue ID for edit/view mode
  final CustomerIssueItem?
      issueData; // Optional pre-loaded issue data (limited fields)
  final ItemIssueApiItem?
      apiIssueData; // Optional full API issue data (preferred for editing)
  final bool isViewOnly; // If true, shows read-only view mode

  CustomerIssueEntryScreen({
    super.key,
    this.issueId,
    this.issueData,
    this.apiIssueData,
    this.isViewOnly = false,
  });

  @override
  State<CustomerIssueEntryScreen> createState() =>
      _CustomerIssueEntryScreenState();
}

class _CustomerIssueEntryScreenState extends State<CustomerIssueEntryScreen> {
  // Form fields
  DateTime _stDate = DateTime.now();
  String? _issueAgainst;
  String? _issueTo;
  String? _fromStore;
  String? _toStore;
  final TextEditingController _referenceCtrl = TextEditingController();
  String? _stNo; // ST Number (read-only, from API)

  // Validation errors
  String? _issueAgainstError;
  String? _issueToError;
  String? _fromStoreError;
  String? _toStoreError;

  // Collapsible sections
  bool _isDetailsExpanded = true;
  bool _isListExpanded = true;

  // Items list - using ItemDetail for expandable sections (like ExpenseDetail)
  List<ItemDetail> _itemDetails = [ItemDetail()];
  int _expandedIndex = 0; // Track which item detail is expanded

  // Legacy items list (for backward compatibility, will be converted from _itemDetails)
  List<IssueItemDetail> _items = [];

  // Loading state
  bool _isLoading = false;

  // Store API issue data for delayed population (after dropdowns load)
  ItemIssueApiItem? _pendingApiIssueData;

  // Check if in edit mode
  bool get _isEditMode =>
      !widget.isViewOnly &&
      (widget.issueId != null ||
          widget.issueData != null ||
          widget.apiIssueData != null);
  // Check if in view mode
  bool get _isViewMode => widget.isViewOnly;

  // Dropdown options
  List<String> _issueAgainstOptions = [
    'Customer',
    'Vendor',
    'Internal'
  ]; // Will be replaced by API data
  List<String> _issueToOptions = [
    'Warehouse',
    'Store',
    'Customer'
  ]; // Will be replaced by API data
  // Store list from API
  List<CommonDropdownItem> _storeList = [];
  List<String> _fromStoreOptions = [];
  List<String> _toStoreOptions = [];
  // Issue To list from API
  List<CommonDropdownItem> _issueToList = [];
  // Issue Against list from API
  List<CommonDropdownItem> _issueAgainstList = [];

  // Loading states
  bool _isLoadingStores = false;
  String? _storeLoadError;
  bool _isLoadingIssueTo = false;
  String? _issueToLoadError;
  bool _isLoadingIssueAgainst = false;
  String? _issueAgainstLoadError;

  // Division/Category dropdown options (shared across all items)
  List<String> _divisionCategoryOptions = [];
  List<CommonDropdownItem> _divisionCategoryList = [];
  bool _isLoadingDivisionCategory = false;

  // Item Description dropdown options (loaded per item based on division)
  final Map<String, List<String>> _divisionToItemDescriptions = {};
  final Map<String, List<CommonDropdownItem>> _divisionToItemDescriptionList =
      {};

  // Batch No dropdown options (loaded per item based on item description)
  final Map<String, List<String>> _itemToBatchNumbers = {};
  final Map<String, List<CommonDropdownItem>> _itemToBatchNumberList = {};

  @override
  void initState() {
    super.initState();
    // Store API issue data if provided for later population
    if (widget.apiIssueData != null) {
      _pendingApiIssueData = widget.apiIssueData;
    }

    // Load stores, issue-to, issue-against, and division category options after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('🔄 Starting form initialization...');
      print('   Edit Mode: $_isEditMode');
      print('   View Mode: $_isViewMode');
      print('   Issue ID: ${widget.issueId}');
      print('   Has API Data: ${widget.apiIssueData != null}');

      // Step 1: ALWAYS call Get API in edit/view mode to get complete data
      // Even if apiIssueData is provided, Get API has more complete details
      if ((_isEditMode || _isViewMode) && widget.issueId != null) {
        final issueId = int.tryParse(widget.issueId!);
        if (issueId != null && issueId > 0) {
          print(
              '📥 Calling Get API to load complete issue data (ID: $issueId)...');
          print('   (This will override any partial data from list screen)');
          await _loadIssueFromApi(issueId);
        } else {
          print('⚠️ Invalid issue ID: ${widget.issueId}');
        }
      } else {
        print(
            'ℹ️ Not in edit/view mode or no issue ID - skipping Get API call');
      }

      // Step 2: Load all dropdowns in parallel
      print('🔄 Loading dropdowns for form population...');
      await Future.wait([
        _loadStores(),
        _loadIssueToOptions(),
        _loadIssueAgainstOptions(),
        _loadDivisionCategoryOptions(),
      ]);

      print('✅ All dropdowns loaded');
      print('   - Stores: ${_storeList.length}');
      print('   - Issue To: ${_issueToList.length}');
      print('   - Issue Against: ${_issueAgainstList.length}');
      print('   - Division Categories: ${_divisionCategoryList.length}');

      // Step 3: After both API data and dropdowns are loaded, populate form
      // Check pending data first (loaded from API), then widget data
      print('🔍 Checking for API data to populate form...');
      print(
          '   _pendingApiIssueData: ${_pendingApiIssueData != null ? "EXISTS (ID: ${_pendingApiIssueData!.id})" : "NULL"}');
      print(
          '   widget.apiIssueData: ${widget.apiIssueData != null ? "EXISTS (ID: ${widget.apiIssueData!.id})" : "NULL"}');

      final apiDataToUse = _pendingApiIssueData ?? widget.apiIssueData;
      if (apiDataToUse != null && mounted) {
        print(
            '✅ Found API data - Populating form with API data (ID: ${apiDataToUse.id})...');
        await _populateFormFromApiIssue(apiDataToUse);
        _pendingApiIssueData = null; // Clear pending data
        print('✅ Form population completed');
      } else {
        print('❌ No API data to populate!');
        if (widget.issueId != null) {
          print(
              '   Issue ID provided: ${widget.issueId}, but no API data available');
        }
        if (_pendingApiIssueData == null && widget.apiIssueData == null) {
          print(
              '   ⚠️ WARNING: Both _pendingApiIssueData and widget.apiIssueData are null!');
          print('   This means the Get API either failed or was not called.');
        }
      }
    });
  }

  @override
  void dispose() {
    _referenceCtrl.dispose();
    for (final detail in _itemDetails) {
      detail.dispose();
    }
    super.dispose();
  }

  /// Load store list from API
  Future<void> _loadStores() async {
    if (!mounted) return;

    setState(() {
      _isLoadingStores = true;
      _storeLoadError = null;
    });

    try {
      final commonRepository = getIt<CommonRepository>();
      // Add timeout to prevent hanging
      final stores = await commonRepository.getStoreList().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout: Failed to load stores');
        },
      );

      if (mounted) {
        setState(() {
          _storeList = stores;
          _fromStoreOptions = stores.map((store) => store.text).toList();
          _toStoreOptions = stores.map((store) => store.text).toList();
          _isLoadingStores = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStores = false;
          _storeLoadError = 'Failed to load stores: ${e.toString()}';
          // Fallback to empty list or show error
          _fromStoreOptions = [];
          _toStoreOptions = [];
        });

        // Show error message to user - use Future.microtask to ensure context is ready
        Future.microtask(() {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load stores. Please try again.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }

  /// Load Issue To list from API
  Future<void> _loadIssueToOptions() async {
    if (!mounted) return;

    setState(() {
      _isLoadingIssueTo = true;
      _issueToLoadError = null;
    });

    try {
      // Get user info for UserId and BizUnit
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();

      if (user == null) {
        throw Exception('User not available');
      }

      final userId = user.userId ?? user.id ?? 1;
      final bizUnit = user.sbuId ?? 1;

      final commonRepository = getIt<CommonRepository>();
      // Add timeout to prevent hanging
      final issueToList =
          await commonRepository.getIssueToList(userId, bizUnit).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout: Failed to load issue-to options');
        },
      );

      if (mounted) {
        setState(() {
          _issueToList = issueToList;
          _issueToOptions = issueToList.map((item) => item.text).toList();
          _isLoadingIssueTo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingIssueTo = false;
          _issueToLoadError =
              'Failed to load issue-to options: ${e.toString()}';
          // Fallback to empty list or show error
          _issueToOptions = [];
        });

        // Show error message to user - use Future.microtask to ensure context is ready
        Future.microtask(() {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Failed to load issue-to options. Please try again.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }

  /// Load Issue Against list from API
  Future<void> _loadIssueAgainstOptions() async {
    if (!mounted) return;

    setState(() {
      _isLoadingIssueAgainst = true;
      _issueAgainstLoadError = null;
    });

    try {
      final commonRepository = getIt<CommonRepository>();
      // Add timeout to prevent hanging
      final issueAgainstList =
          await commonRepository.getIssueAgainstList().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
              'Request timeout: Failed to load issue-against options');
        },
      );

      if (mounted) {
        setState(() {
          _issueAgainstList = issueAgainstList;
          _issueAgainstOptions =
              issueAgainstList.map((item) => item.text).toList();
          _isLoadingIssueAgainst = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingIssueAgainst = false;
          _issueAgainstLoadError =
              'Failed to load issue-against options: ${e.toString()}';
          // Fallback to empty list or show error
          _issueAgainstOptions = [];
        });

        // Show error message to user - use Future.microtask to ensure context is ready
        Future.microtask(() {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Failed to load issue-against options. Please try again.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }

  /// Load Division/Category list from API (shared across all items)
  Future<void> _loadDivisionCategoryOptions() async {
    if (!mounted) return;

    setState(() {
      _isLoadingDivisionCategory = true;
    });

    try {
      final commonRepository = getIt<CommonRepository>();
      final divisionCategoryList =
          await commonRepository.getDivisionCategoryList().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
              'Request timeout: Failed to load division/category options');
        },
      );

      if (mounted) {
        setState(() {
          _divisionCategoryList = divisionCategoryList;
          _divisionCategoryOptions =
              divisionCategoryList.map((item) => item.text).toList();
          _isLoadingDivisionCategory = false;
        });
      }
    } catch (e) {
      print('Error loading division/category: $e');
      if (mounted) {
        setState(() {
          _isLoadingDivisionCategory = false;
          _divisionCategoryOptions = [];
        });
      }
    }
  }

  /// Load Item Description list for a specific division
  Future<void> _loadItemDescriptionsForDivision(
      String? divisionCategory, ItemDetail itemDetail) async {
    if (!mounted || divisionCategory == null) return;

    // Find division ID from the list
    final divisionItem = _divisionCategoryList.firstWhere(
      (item) => item.text == divisionCategory,
      orElse: () => _divisionCategoryList.first,
    );

    // Check if already loaded
    if (_divisionToItemDescriptions.containsKey(divisionCategory)) {
      setState(() {
        itemDetail.itemDescriptionOptions =
            _divisionToItemDescriptions[divisionCategory]!;
      });
      return;
    }

    try {
      final commonRepository = getIt<CommonRepository>();
      final itemDescriptionList = await commonRepository
          .getItemDescriptionList(divisionItem.id)
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout: Failed to load item descriptions');
        },
      );

      if (mounted) {
        final itemDescriptions =
            itemDescriptionList.map((item) => item.text).toList();
        _divisionToItemDescriptions[divisionCategory] = itemDescriptions;
        _divisionToItemDescriptionList[divisionCategory] = itemDescriptionList;
        setState(() {
          itemDetail.itemDescriptionOptions = itemDescriptions;
        });
      }
    } catch (e) {
      print('Error loading item descriptions: $e');
      if (mounted) {
        setState(() {
          itemDetail.itemDescriptionOptions = [];
        });
      }
    }
  }

  /// Load Batch Numbers for a specific item
  Future<void> _loadBatchNumbersForItem(
      String? itemDescription, ItemDetail itemDetail) async {
    if (!mounted || itemDescription == null) return;

    // Find the division to get the item description list
    String? divisionCategory = itemDetail.divisionCategory;
    if (divisionCategory == null) return;

    final itemDescriptionList =
        _divisionToItemDescriptionList[divisionCategory];
    if (itemDescriptionList == null) return;

    final itemItem = itemDescriptionList.firstWhere(
      (item) => item.text == itemDescription,
      orElse: () => itemDescriptionList.first,
    );

    // Check if already loaded
    if (_itemToBatchNumbers.containsKey(itemDescription)) {
      setState(() {
        itemDetail.batchNoOptions = _itemToBatchNumbers[itemDescription]!;
      });
      return;
    }

    try {
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();
      if (user == null) throw Exception('User not available');

      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      final employeeId = userStore?.userDetail?.employeeId ?? 1;
      final bizUnit = (userStore?.userDetail?.sbuId != null &&
              userStore!.userDetail!.sbuId! > 0)
          ? userStore.userDetail!.sbuId!
          : ((user.sbuId != null && user.sbuId! > 0) ? user.sbuId! : 1);

      final toDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final commonRepository = getIt<CommonRepository>();
      final batchNoList = await commonRepository
          .getBatchNoList(
            itemId: itemItem.id,
            employeeId: employeeId,
            toDate: toDate,
            bizUnit: bizUnit,
            customerId: 0,
          )
          .timeout(const Duration(seconds: 30));

      if (mounted) {
        final batchNos = batchNoList.map((item) => item.text).toList();
        _itemToBatchNumbers[itemDescription] = batchNos;
        _itemToBatchNumberList[itemDescription] = batchNoList;
        setState(() {
          itemDetail.batchNoOptions = batchNos;
        });
      }
    } catch (e) {
      print('Error loading batch numbers: $e');
      if (mounted) {
        setState(() {
          itemDetail.batchNoOptions = [];
        });
      }
    }
  }

  Future<void> _loadIssueData() async {
    // If full API issue data is provided, use it (preferred)
    if (widget.apiIssueData != null) {
      await _populateFormFromApiIssue(widget.apiIssueData!);
      return;
    }

    // If limited issueData is provided, use it
    if (widget.issueData != null) {
      _populateFormFromIssue(widget.issueData!);
      return;
    }

    // Otherwise, load from API using issueId
    if (widget.issueId != null) {
      _loadIssueFromApi(int.tryParse(widget.issueId!) ?? 0);
    }
  }

  /// Load issue data from API by ID
  Future<void> _loadIssueFromApi(int issueId) async {
    if (issueId == 0) {
      print('⚠️ Invalid issue ID: ${widget.issueId}');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('═══════════════════════════════════════════════════════════');
      print('📥 LOADING ISSUE FROM API');
      print('═══════════════════════════════════════════════════════════');
      print('Issue ID: $issueId');

      final itemIssueRepo = getIt<ItemIssueRepository>();
      final apiIssue = await itemIssueRepo.getItemIssue(issueId);

      print('✅ Issue loaded successfully');
      print('   Issue No: ${apiIssue.no}');
      print('   Details Count: ${apiIssue.details?.length ?? 0}');

      // Store for population after dropdowns load
      if (mounted) {
        print('💾 Storing API data in _pendingApiIssueData...');
        _pendingApiIssueData = apiIssue;
        print('   ✅ Stored: Issue ID ${apiIssue.id}, No: ${apiIssue.no}');
        print(
            '   ✅ Stored: Issue To ID ${apiIssue.issueTo}, Issue Against ID ${apiIssue.issueAgainst}');
        print('   ✅ Stored: Details count ${apiIssue.details?.length ?? 0}');

        // If dropdowns are already loaded, populate immediately
        if (_storeList.isNotEmpty &&
            _issueToList.isNotEmpty &&
            _issueAgainstList.isNotEmpty) {
          print('   Dropdowns already loaded - populating form immediately...');
          await _populateFormFromApiIssue(apiIssue);
          _pendingApiIssueData = null;
        } else {
          print(
              '   Dropdowns not loaded yet - will populate after dropdowns load');
        }

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading issue from API: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load customer issue: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _populateFormFromApiIssue(ItemIssueApiItem apiIssue) async {
    print('═══════════════════════════════════════════════════════════');
    print('📝 POPULATING FORM FROM API ISSUE DATA');
    print('═══════════════════════════════════════════════════════════');
    print('Issue ID: ${apiIssue.id}');
    print('Issue No: ${apiIssue.no}');
    print('Date: ${apiIssue.date}');
    print('Department Text: ${apiIssue.departmentText}');
    print('To Store Text: ${apiIssue.toStoreText}');
    print('Issue Against ID: ${apiIssue.issueAgainst}');
    print('Issue To ID: ${apiIssue.issueTo}');
    print('Reference: ${apiIssue.reference}');
    print('Details Count: ${apiIssue.details?.length ?? 0}');
    print('Issue Against List Count: ${_issueAgainstList.length}');
    print('Issue To List Count: ${_issueToList.length}');
    print('═══════════════════════════════════════════════════════════');

    // Map full API issue data to form fields
    setState(() {
      _stNo = apiIssue.no.isNotEmpty ? apiIssue.no : apiIssue.id.toString();

      // Parse date
      try {
        if (apiIssue.date.isNotEmpty) {
          _stDate = DateTime.tryParse(apiIssue.date) ??
              DateFormat('yyyy-MM-dd').parse(apiIssue.date);
        }
      } catch (e) {
        print('Error parsing date: ${apiIssue.date}');
      }

      // Map stores - use text values directly
      _fromStore =
          apiIssue.departmentText.isNotEmpty ? apiIssue.departmentText : null;
      _toStore = apiIssue.toStoreText.isNotEmpty ? apiIssue.toStoreText : null;

      // Map issue against - convert ID to text value
      if (apiIssue.issueAgainst != null) {
        if (_issueAgainstList.isNotEmpty) {
          try {
            final issueAgainstId = apiIssue.issueAgainst;
            print('🔍 Looking for Issue Against ID: $issueAgainstId');
            print(
                '   Available IDs in list: ${_issueAgainstList.map((e) => e.id).toList()}');

            final issueAgainstItem = _issueAgainstList.firstWhere(
              (item) => item.id == issueAgainstId,
            );
            _issueAgainst = issueAgainstItem.text;
            print(
                '✅ Mapped Issue Against: ID $issueAgainstId -> "${issueAgainstItem.text}"');
          } catch (e) {
            print(
                '❌ ERROR: Could not find issue against for ID: ${apiIssue.issueAgainst}');
            print(
                '   Available IDs: ${_issueAgainstList.map((e) => e.id).toList()}');
            print(
                '   Available texts: ${_issueAgainstList.map((e) => e.text).toList()}');
            print('   Error: $e');
            // Don't set _issueAgainst, leave it as null so user can select
          }
        } else {
          print(
              '⚠️ Issue Against list is empty, cannot map ID: ${apiIssue.issueAgainst}');
        }
      } else {
        print('ℹ️ Issue Against is null in API response (field is optional)');
        _issueAgainst = null; // Explicitly set to null
      }

      // Map issue to - convert ID to text value
      if (apiIssue.issueTo != null) {
        if (_issueToList.isNotEmpty) {
          try {
            final issueToId = apiIssue.issueTo;
            print('🔍 Looking for Issue To ID: $issueToId');
            print(
                '   Available IDs in list: ${_issueToList.map((e) => e.id).toList()}');

            final issueToItem = _issueToList.firstWhere(
              (item) => item.id == issueToId,
            );
            _issueTo = issueToItem.text;
            print('✅ Mapped Issue To: ID $issueToId -> "${issueToItem.text}"');
          } catch (e) {
            print(
                '❌ ERROR: Could not find issue to for ID: ${apiIssue.issueTo}');
            print(
                '   Available IDs: ${_issueToList.map((e) => e.id).toList()}');
            print(
                '   Available texts: ${_issueToList.map((e) => e.text).toList()}');
            print('   Error: $e');
            // Don't set _issueTo, leave it as null so user can select
          }
        } else {
          print(
              '⚠️ Issue To list is empty, cannot map ID: ${apiIssue.issueTo}');
        }
      } else {
        print('⚠️ Issue To is null in API response (this should not happen)');
        _issueTo = null; // Explicitly set to null
      }

      // Reference/Remarks
      _referenceCtrl.text = apiIssue.reference ?? '';

      // Populate item details from apiIssue.details
      print('═══════════════════════════════════════════════════════════');
      print('📦 POPULATING ITEM DETAILS');
      print('═══════════════════════════════════════════════════════════');
      print('Details is null: ${apiIssue.details == null}');
      print('Details type: ${apiIssue.details.runtimeType}');
      if (apiIssue.details != null) {
        print('Details is List: ${apiIssue.details is List}');
        if (apiIssue.details is List) {
          print('Details list length: ${(apiIssue.details as List).length}');
        }
      }

      _itemDetails = [];
      if (apiIssue.details != null && apiIssue.details is List) {
        final detailsList = apiIssue.details as List;
        print('📦 Parsing ${detailsList.length} item details...');

        for (int i = 0; i < detailsList.length; i++) {
          final detailJson = detailsList[i];
          print('   Processing detail $i...');
          print('   Detail type: ${detailJson.runtimeType}');

          if (detailJson is Map<String, dynamic>) {
            print('   Detail keys: ${detailJson.keys.toList()}');
            try {
              final itemDetail = ItemDetail();

              // Map fields from API response (check both PascalCase and camelCase)
              itemDetail.divisionCategory = detailJson['divisionText'] ??
                  detailJson['DivisionText'] ??
                  detailJson['itemCategoryText'] ??
                  detailJson['ItemCategoryText'] ??
                  '';
              print('   Division Category: ${itemDetail.divisionCategory}');

              itemDetail.itemDescription = detailJson['itemText'] ??
                  detailJson['ItemText'] ??
                  detailJson['itemCode'] ??
                  detailJson['ItemCode'] ??
                  '';
              print('   Item Description: ${itemDetail.itemDescription}');

              itemDetail.batchNo =
                  detailJson['batchNo'] ?? detailJson['BatchNo'] ?? '';
              print('   Batch No: ${itemDetail.batchNo}');

              // Quantity fields
              final qtyInStock = detailJson['stock'] ??
                  detailJson['Stock'] ??
                  detailJson['quantityInStock'] ??
                  detailJson['QuantityInStock'] ??
                  0.0;
              final qtyInStockValue = qtyInStock is double
                  ? qtyInStock
                  : (qtyInStock is int ? qtyInStock.toDouble() : 0.0);
              itemDetail.qtyInStockCtrl.text =
                  qtyInStockValue.toStringAsFixed(0);
              print('   Qty In Stock: ${itemDetail.qtyInStockCtrl.text}');

              final qtyIssued = detailJson['quantityConsumed'] ??
                  detailJson['QuantityConsumed'] ??
                  0.0;
              final qtyIssuedValue = qtyIssued is double
                  ? qtyIssued
                  : (qtyIssued is int ? qtyIssued.toDouble() : 0.0);
              itemDetail.qtyIssuedCtrl.text = qtyIssuedValue.toStringAsFixed(0);
              print('   Qty Issued: ${itemDetail.qtyIssuedCtrl.text}');

              // UOM
              itemDetail.uomCtrl.text = detailJson['uomText'] ??
                  detailJson['UOMText'] ??
                  detailJson['uomCode'] ??
                  detailJson['UomCode'] ??
                  '';
              print('   UOM: ${itemDetail.uomCtrl.text}');

              // Rate
              final rate = detailJson['rate'] ?? detailJson['Rate'] ?? 0.0;
              final rateValue =
                  rate is double ? rate : (rate is int ? rate.toDouble() : 0.0);
              itemDetail.rateCtrl.text = rateValue.toStringAsFixed(2);
              print('   Rate: ${itemDetail.rateCtrl.text}');

              // Amount
              final amount =
                  detailJson['amount'] ?? detailJson['Amount'] ?? 0.0;
              final amountValue = amount is double
                  ? amount
                  : (amount is int ? amount.toDouble() : 0.0);
              itemDetail.amountCtrl.text = amountValue.toStringAsFixed(2);
              print('   Amount: ${itemDetail.amountCtrl.text}');

              // Remarks
              itemDetail.remarksCtrl.text =
                  detailJson['remarks'] ?? detailJson['Remarks'] ?? '';
              print('   Remarks: ${itemDetail.remarksCtrl.text}');

              // Store batch ID if available (for later use in save)
              final batchId = detailJson['batchId'] ?? detailJson['BatchId'];
              if (batchId != null && batchId is int) {
                itemDetail.batchId = batchId;
                print('   Batch ID: ${itemDetail.batchId}');
              }

              _itemDetails.add(itemDetail);
              print('✅ Added item ${i + 1}: ${itemDetail.itemDescription}');
              print('   - Division: ${itemDetail.divisionCategory}');
              print(
                  '   - Batch: ${itemDetail.batchNo} (ID: ${itemDetail.batchId})');
              print('   - Qty Issued: ${itemDetail.qtyIssuedCtrl.text}');
              print('   - Rate: ${itemDetail.rateCtrl.text}');
              print('   - Amount: ${itemDetail.amountCtrl.text}');

              // Store item info for loading dropdown options after setState
              // We'll load these options after the setState completes
            } catch (e, stackTrace) {
              print('❌ Error parsing item detail $i: $e');
              print('   Stack trace: $stackTrace');
              print('   Detail JSON keys: ${detailJson.keys.toList()}');
              print('   Detail JSON: $detailJson');
            }
          } else {
            print(
                '⚠️ Detail $i is not a Map, it is: ${detailJson.runtimeType}');
          }
        }

        print('═══════════════════════════════════════════════════════════');
        if (_itemDetails.isNotEmpty) {
          _expandedIndex = 0;
          print(
              '✅ Successfully loaded ${_itemDetails.length} items into _itemDetails');
          print('   Expanded Index set to: $_expandedIndex');
          print(
              '   First item description: ${_itemDetails[0].itemDescription}');
          print('   First item batch: ${_itemDetails[0].batchNo}');
        } else {
          print('⚠️ WARNING: No items were successfully parsed!');
          print(
              '   _itemDetails is empty after parsing ${detailsList.length} details');
          print('   This means items will not be displayed in the UI');
          // Add at least one empty item so the UI doesn't break
          _itemDetails.add(ItemDetail());
          print('   Added empty ItemDetail to prevent UI issues');
        }
        print('═══════════════════════════════════════════════════════════');
      } else {
        print('⚠️ Details is null or not a list');
        print('   Details value: ${apiIssue.details}');
        print('   Details type: ${apiIssue.details?.runtimeType}');
        // Ensure at least one empty item exists
        if (_itemDetails.isEmpty) {
          _itemDetails.add(ItemDetail());
          print('   Added empty ItemDetail since details is null');
        }
      }

      // Force UI update after populating items
      print('🔄 Triggering UI rebuild with ${_itemDetails.length} items');
      print('═══════════════════════════════════════════════════════════');
      print('📊 FINAL STATE AFTER ITEM POPULATION');
      print('═══════════════════════════════════════════════════════════');
      print('_itemDetails.length: ${_itemDetails.length}');
      print('_expandedIndex: $_expandedIndex');
      if (_itemDetails.isNotEmpty) {
        for (int i = 0; i < _itemDetails.length; i++) {
          print('Item $i:');
          print('  - Division: ${_itemDetails[i].divisionCategory}');
          print('  - Description: ${_itemDetails[i].itemDescription}');
          print('  - Batch: ${_itemDetails[i].batchNo}');
          print('  - Qty Issued: ${_itemDetails[i].qtyIssuedCtrl.text}');
          print('  - Rate: ${_itemDetails[i].rateCtrl.text}');
          print('  - Amount: ${_itemDetails[i].amountCtrl.text}');
        }
      }
      print('═══════════════════════════════════════════════════════════');
    });

    // After setState, load dropdown options for each item so the values display correctly
    // This needs to happen outside setState because it's async
    if (_itemDetails.isNotEmpty) {
      print('🔄 Loading dropdown options for populated items...');
      for (int i = 0; i < _itemDetails.length; i++) {
        final itemDetail = _itemDetails[i];

        // Load item descriptions if division category is set
        if (itemDetail.divisionCategory != null &&
            itemDetail.divisionCategory!.isNotEmpty) {
          print(
              '   Loading item descriptions for division: ${itemDetail.divisionCategory}');
          await _loadItemDescriptionsForDivision(
              itemDetail.divisionCategory, itemDetail);

          // Load batch numbers if item description is set
          if (itemDetail.itemDescription != null &&
              itemDetail.itemDescription!.isNotEmpty) {
            print(
                '   Loading batch numbers for item: ${itemDetail.itemDescription}');
            await _loadBatchNumbersForItem(
                itemDetail.itemDescription, itemDetail);
          }
        }
      }
      print('✅ Dropdown options loaded for all items');

      // Trigger UI update after loading options
      if (mounted) {
        setState(() {
          // Just trigger rebuild to show the populated values
        });
      }
    }

    print('═══════════════════════════════════════════════════════════');
    print('📝 FORM POPULATION COMPLETE');
    print('═══════════════════════════════════════════════════════════');
  }

  void _populateFormFromIssue(CustomerIssueItem issue) {
    // Map issue data to form fields
    // Note: CustomerIssueItem from list screen has limited fields
    // We only populate what's available, other fields remain empty/null
    setState(() {
      _stNo = issue.issueNo.isNotEmpty ? issue.issueNo : issue.id;
      _stDate = issue.stDate;
      _fromStore = issue.fromStore;
      // Don't overwrite with mock data - keep other fields as they are
      // Other fields will need to be loaded from a full API call if needed
    });
  }

  void _populateFormFromMockData() {
    // Mock data based on screenshot
    setState(() {
      _stNo = 'CMI-25-12-0004';
      _stDate = DateTime(2025, 12, 19);
      _issueAgainst = 'Customer';
      _issueTo = null; // "Select" in screenshot
      _fromStore = 'Inventory';
      _toStore = 'Customer Store';
      _referenceCtrl.text = '';

      // Add mock item to _itemDetails
      final mockDetail = ItemDetail();
      mockDetail.divisionCategory = 'Diagnostics';
      mockDetail.itemDescription =
          'CFX96 Touch Real-Time PCR Detection System with Starter Package - 1855195';
      mockDetail.batchNo = 'EMR-25-12-0008-BTCH/2210';
      mockDetail.qtyInStockCtrl.text = '230';
      mockDetail.qtyIssuedCtrl.text = '12';
      mockDetail.uomCtrl.text = 'Each';
      mockDetail.rateCtrl.text = '654.00';
      mockDetail.amountCtrl.text = '7848.00';
      mockDetail.remarksCtrl.text = '';
      _itemDetails = [mockDetail];
      _expandedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    const tealGreen = Color(0xFF4db1b3);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          _isViewMode
              ? 'View Customer Issue'
              : (_isEditMode ? 'Edit Customer Issue' : 'New Customer Issue'),
          style: GoogleFonts.inter(
            fontSize: isTablet ? 20 : 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: tealGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: _isViewMode
            ? [
                // View mode actions: Info, Print
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  onPressed: () {
                    // TODO: Show issue info
                  },
                  tooltip: 'Info',
                ),
                IconButton(
                  icon: const Icon(Icons.print, color: Colors.white),
                  onPressed: () {
                    // TODO: Print issue
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Printing...')),
                    );
                  },
                  tooltip: 'Print',
                ),
              ]
            : null, // Remove Save button from header - will be at bottom
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Breadcrumb in content area
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 16,
                vertical: 12,
              ),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(Icons.home, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    _isViewMode
                        ? 'Customer Issue > View'
                        : (_isEditMode
                            ? 'Customer Issue > Edit'
                            : 'Customer Issue > New'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Spacer(),
                  // Undo button in breadcrumb area (only in edit/create mode)
                  if (!_isViewMode)
                    TextButton.icon(
                      onPressed: () {
                        // TODO: Implement undo
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Undo last action')),
                        );
                      },
                      icon: Icon(Icons.undo,
                          size: 16, color: Colors.grey.shade600),
                      label: Text(
                        'Undo',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isTablet ? 24 : 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Customer Issue Details Section
                              _buildDetailsCard(context, isTablet),
                              const SizedBox(height: 32),
                              // Add to List Section
                              _buildListCard(context, isTablet),
                              const SizedBox(height: 32),
                              // Submit button at bottom (only in edit/create mode)
                              if (!_isViewMode)
                                _buildSubmitButton(context, isTablet),
                              SizedBox(
                                  height:
                                      MediaQuery.of(context).padding.bottom +
                                          16),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Simple text header (no card, no collapsible)
        Text(
          'Customer Issue Details',
          style: GoogleFonts.inter(
            fontSize: isTablet ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 20),
        // Form fields directly (no card wrapper)
        _buildDetailsForm(context, isTablet),
      ],
    );
  }

  Widget _buildDetailsForm(BuildContext context, bool isTablet) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _LabeledField(
                          label: 'ST No.',
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey
                                  .shade50, // Lighter background for read-only
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.grey.shade200, width: 1),
                            ),
                            child: Text(
                              _stNo ?? '[NEW]',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _LabeledField(
                          label: 'ST Date',
                          required: true,
                          child: _isViewMode
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.grey.shade200, width: 1),
                                  ),
                                  child: Text(
                                    DateFormat('dd-MMM-yyyy').format(_stDate),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                )
                              : InkWell(
                                  onTap: () async {
                                    final DateTime? picked =
                                        await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _stDate = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            DateFormat('dd-MMM-yyyy')
                                                .format(_stDate),
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                        Icon(Icons.calendar_today,
                                            size: 20,
                                            color: Colors.grey.shade600),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                        _LabeledField(
                          label: 'Issue Against',
                          required: true,
                          errorText: _issueAgainstError,
                          child: _isLoadingIssueAgainst
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.grey.shade600),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Loading issue-against options...',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _isViewMode
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        _issueAgainst ?? 'Not selected',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    )
                                  : SearchableDropdown(
                                      options: _issueAgainstOptions,
                                      value: _issueAgainst,
                                      hintText:
                                          'Type to search issue against...',
                                      searchHintText: 'Search issue against...',
                                      hasError: _issueAgainstError != null,
                                      onChanged: (value) {
                                        setState(() {
                                          _issueAgainst = value;
                                          _issueAgainstError = null;
                                        });
                                      },
                                    ),
                        ),
                        const SizedBox(height: 20),
                        _LabeledField(
                          label: 'Issue To',
                          required: true,
                          errorText: _issueToError,
                          child: _isLoadingIssueTo
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.grey.shade600),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Loading issue-to options...',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _isViewMode
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        _issueTo ?? 'Not selected',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    )
                                  : SearchableDropdown(
                                      options: _issueToOptions,
                                      value: _issueTo,
                                      hintText: '-- Select Issue To --',
                                      searchHintText: 'Search issue to...',
                                      hasError: _issueToError != null,
                                      onChanged: (value) {
                                        setState(() {
                                          _issueTo = value;
                                          _issueToError = null;
                                        });
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        _LabeledField(
                          label: 'From Store',
                          required: true,
                          errorText: _fromStoreError,
                          child: _isLoadingStores
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.grey.shade600),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Loading stores...',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _isViewMode
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        _fromStore ?? 'Not selected',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    )
                                  : SearchableDropdown(
                                      options: _fromStoreOptions,
                                      value: _fromStore,
                                      hintText: '-- Select From Store --',
                                      searchHintText: 'Search from store...',
                                      hasError: _fromStoreError != null,
                                      onChanged: (value) {
                                        _handleFromStoreChange(value);
                                      },
                                    ),
                        ),
                        const SizedBox(height: 20),
                        _LabeledField(
                          label: 'To Store',
                          required: true,
                          errorText: _toStoreError,
                          child: _isLoadingStores
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.grey.shade600),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Loading stores...',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _isViewMode
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        _toStore ?? 'Not selected',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    )
                                  : SearchableDropdown(
                                      options: _toStoreOptions,
                                      value: _toStore,
                                      hintText: '-- Select To Store --',
                                      searchHintText: 'Search to store...',
                                      hasError: _toStoreError != null,
                                      onChanged: (value) {
                                        _handleToStoreChange(value);
                                      },
                                    ),
                        ),
                        const SizedBox(height: 20),
                        _LabeledField(
                          label: 'Reference / Remarks',
                          hintText:
                              'Optional: PO number, ticket ID, or remarks',
                          child: _isViewMode
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.grey.shade200, width: 1),
                                  ),
                                  child: Text(
                                    _referenceCtrl.text.isEmpty
                                        ? 'Not provided'
                                        : _referenceCtrl.text,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: _referenceCtrl.text.isEmpty
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                )
                              : TextFormField(
                                  controller: _referenceCtrl,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                          width: 1),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                          width: 1),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: const Color(0xFF4db1b3),
                                          width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _LabeledField(
                    label: 'ST No.',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.grey.shade200, width: 1),
                      ),
                      child: Text(
                        _stNo ?? '[NEW]',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _LabeledField(
                    label: 'ST Date',
                    required: true,
                    child: _isViewMode
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.grey.shade200, width: 1),
                            ),
                            child: Text(
                              DateFormat('dd-MMM-yyyy').format(_stDate),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          )
                        : InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() {
                                  _stDate = picked;
                                });
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.grey.shade300, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      DateFormat('dd-MMM-yyyy').format(_stDate),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.calendar_today,
                                      size: 20, color: Colors.grey.shade600),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  _LabeledField(
                    label: 'Issue Against',
                    required: true,
                    errorText: _issueAgainstError,
                    child: _isLoadingIssueAgainst
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.grey.shade600),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading issue-against options...',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _isViewMode
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  _issueAgainst ?? 'Not selected',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              )
                            : SearchableDropdown(
                                options: _issueAgainstOptions,
                                value: _issueAgainst,
                                hintText: '-- Select Issue Against --',
                                searchHintText: 'Search issue against...',
                                hasError: _issueAgainstError != null,
                                onChanged: (value) {
                                  setState(() {
                                    _issueAgainst = value;
                                    _issueAgainstError = null;
                                  });
                                },
                              ),
                  ),
                  const SizedBox(height: 20),
                  _LabeledField(
                    label: 'Issue To',
                    required: true,
                    errorText: _issueToError,
                    child: _isLoadingIssueTo
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.grey.shade600),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading issue-to options...',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _isViewMode
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  _issueTo ?? 'Not selected',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              )
                            : SearchableDropdown(
                                options: _issueToOptions,
                                value: _issueTo,
                                hintText: '-- Select Issue To --',
                                searchHintText: 'Search issue to...',
                                hasError: _issueToError != null,
                                onChanged: (value) {
                                  setState(() {
                                    _issueTo = value;
                                    _issueToError = null;
                                  });
                                },
                              ),
                  ),
                  const SizedBox(height: 20),
                  _LabeledField(
                    label: 'From Store',
                    required: true,
                    errorText: _fromStoreError,
                    child: _isLoadingStores
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.grey.shade600),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading stores...',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _isViewMode
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  _fromStore ?? 'Not selected',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              )
                            : SearchableDropdown(
                                options: _fromStoreOptions,
                                value: _fromStore,
                                hintText: '-- Select From Store --',
                                searchHintText: 'Search from store...',
                                hasError: _fromStoreError != null,
                                onChanged: (value) {
                                  _handleFromStoreChange(value);
                                },
                              ),
                  ),
                  const SizedBox(height: 20),
                  _LabeledField(
                    label: 'To Store',
                    required: true,
                    errorText: _toStoreError,
                    child: _isLoadingStores
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.grey.shade600),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading stores...',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _isViewMode
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  _toStore ?? 'Not selected',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              )
                            : SearchableDropdown(
                                options: _toStoreOptions,
                                value: _toStore,
                                hintText: '-- Select To Store --',
                                searchHintText: 'Search to store...',
                                hasError: _toStoreError != null,
                                onChanged: (value) {
                                  _handleToStoreChange(value);
                                },
                              ),
                  ),
                  const SizedBox(height: 20),
                  _LabeledField(
                    label: 'Reference / Remarks',
                    hintText: 'Optional: PO number, ticket ID, or remarks',
                    child: _isViewMode
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.grey.shade200, width: 1),
                            ),
                            child: Text(
                              _referenceCtrl.text.isEmpty
                                  ? 'Not provided'
                                  : _referenceCtrl.text,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: _referenceCtrl.text.isEmpty
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          )
                        : TextFormField(
                            controller: _referenceCtrl,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: Colors.grey.shade300, width: 1),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: Colors.grey.shade300, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: const Color(0xFF4db1b3), width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                  ),
                ],
              );
      },
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required bool isTablet,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: isTablet ? 14 : 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Auto-generated',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 11 : 10,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 15 : 14,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(BuildContext context, bool isTablet) {
    final isToday = _stDate.year == DateTime.now().year &&
        _stDate.month == DateTime.now().month &&
        _stDate.day == DateTime.now().day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ST Date *',
          style: GoogleFonts.inter(
            fontSize: isTablet ? 14 : 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        if (!_isViewMode && !isToday)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Default: Today\'s date (${DateFormat('dd-MMM-yyyy').format(DateTime.now())})',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.orange.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _isViewMode
            ? Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Text(
                  DateFormat('dd-MMM-yyyy').format(_stDate),
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 15 : 14,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _stDate = picked;
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('dd-MMM-yyyy').format(_stDate),
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 15 : 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      Icon(Icons.calendar_today,
                          size: 22, color: Colors.grey.shade600),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> options,
    ValueChanged<String?>? onChanged,
    required bool isTablet,
    String? helperText,
    String? errorText,
    Widget? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (prefixIcon != null) ...[
              prefixIcon,
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: isTablet ? 14 : 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              helperText,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _isViewMode
            ? Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Text(
                  value ?? 'Not selected',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 15 : 14,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : DropdownButtonFormField<String>(
                value: value,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: errorText != null
                          ? Colors.red.shade400
                          : Colors.grey.shade300,
                      width: errorText != null ? 1.5 : 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: errorText != null
                          ? Colors.red.shade400
                          : Colors.grey.shade300,
                      width: errorText != null ? 1.5 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: errorText != null
                          ? Colors.red.shade400
                          : const Color(0xFF4db1b3),
                      width: 2,
                    ),
                  ),
                  errorText: errorText,
                  errorStyle: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.red.shade600,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  filled: true,
                  fillColor: Colors.white,
                ),
                isExpanded: true,
                hint: Text(
                  'Select',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 15 : 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                items: options.map((option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Text(
                      option,
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 15 : 14,
                      ),
                    ),
                  );
                }).toList(),
                onChanged:
                    onChanged != null ? (value) => onChanged(value) : null,
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 15 : 14,
                  color: Colors.grey.shade800,
                ),
                icon: Icon(Icons.arrow_drop_down,
                    size: 24, color: Colors.grey.shade700),
              ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool isTablet,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isTablet ? 14 : 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              helperText,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _isViewMode
            ? Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Text(
                  controller.text.isEmpty ? 'Not provided' : controller.text,
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 15 : 14,
                    color: controller.text.isEmpty
                        ? Colors.grey.shade500
                        : Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF4db1b3), width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 15 : 14,
                  color: Colors.grey.shade800,
                ),
              ),
      ],
    );
  }

  void _addAnotherItem() {
    setState(() {
      _itemDetails.add(ItemDetail());
      // Expand the newly added item
      _expandedIndex = _itemDetails.length - 1;
    });
  }

  void _removeItemDetail(int index) {
    if (_itemDetails.length > 1) {
      setState(() {
        _itemDetails[index].dispose();
        _itemDetails.removeAt(index);

        // Adjust expanded index after removal
        if (_expandedIndex == index) {
          _expandedIndex = 0;
        } else if (_expandedIndex > index) {
          _expandedIndex--;
        }

        // If only one item left, reset to always expanded
        if (_itemDetails.length == 1) {
          _expandedIndex = 0;
        }
      });
    }
  }

  void _calculateAmountForItem(ItemDetail detail) {
    final qty = int.tryParse(detail.qtyIssuedCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(detail.rateCtrl.text.trim()) ?? 0.0;
    if (rate > 0 && qty > 0) {
      setState(() {
        detail.amountCtrl.text = (rate * qty).toStringAsFixed(2);
      });
    } else {
      setState(() {
        detail.amountCtrl.text = '0.00';
      });
    }
  }

  List<Widget> _buildItemDetailsSections() {
    final List<Widget> sections = [];

    for (int i = 0; i < _itemDetails.length; i++) {
      final detail = _itemDetails[i];
      final bool isExpanded = _itemDetails.length == 1 || _expandedIndex == i;

      sections.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7F7),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: const Color(0xFF4db1b3).withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with expand/collapse functionality
              InkWell(
                onTap: _itemDetails.length > 1
                    ? () {
                        setState(() {
                          _expandedIndex = isExpanded ? -1 : i;
                        });
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        _itemDetails.length > 1
                            ? 'Item Detail ${i + 1}'
                            : 'Item Details',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4db1b3),
                            ),
                      ),
                      if (detail.itemDescription != null &&
                          detail.itemDescription!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '(${detail.itemDescription})',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF4db1b3),
                                      fontStyle: FontStyle.italic,
                                    ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (_itemDetails.length > 1) ...[
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: const Color(0xFF4db1b3),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _removeItemDetail(i),
                          icon: const Icon(Icons.close, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Expandable content
              if (isExpanded) ...[
                const Divider(height: 1, color: Color(0xFF4db1b3)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildItemDetailForm(detail, i),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return sections;
  }

  Widget _buildItemDetailForm(ItemDetail detail, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Division/Category
        _Labeled(
          label: 'Division / Category',
          required: true,
          errorText: detail.divisionCategoryError,
          child: SearchableDropdown(
            options: _divisionCategoryOptions,
            value: detail.divisionCategory,
            hintText: 'Select Division/Category',
            searchHintText: 'Search division/category...',
            hasError: detail.divisionCategoryError != null,
            onChanged: (v) {
              setState(() {
                detail.divisionCategory = v;
                detail.divisionCategoryError = null;
                detail.itemDescription =
                    null; // Clear item description when division changes
                detail.batchNo = null; // Clear batch no when division changes
                detail.itemDescriptionOptions = [];
                detail.batchNoOptions = [];
              });
              if (v != null) {
                _loadItemDescriptionsForDivision(v, detail);
              }
            },
          ),
        ),
        const SizedBox(height: 12),

        // Item Description
        _Labeled(
          label: 'Item Description',
          required: true,
          errorText: detail.itemDescriptionError,
          child: SearchableDropdown(
            options: detail.itemDescriptionOptions,
            value: detail.itemDescription,
            hintText: 'Select Item Description',
            searchHintText: 'Search item description...',
            hasError: detail.itemDescriptionError != null,
            onChanged: (v) {
              setState(() {
                detail.itemDescription = v;
                detail.itemDescriptionError = null;
                detail.batchNo = null; // Clear batch no when item changes
                detail.batchNoOptions = [];
              });
              if (v != null && detail.divisionCategory != null) {
                _loadBatchNumbersForItem(v, detail);
              }
            },
          ),
        ),
        const SizedBox(height: 12),

        // Batch No
        _Labeled(
          label: 'Batch No',
          child: SearchableDropdown(
            options: detail.batchNoOptions,
            value: detail.batchNo,
            hintText: 'Select Batch No',
            searchHintText: 'Search batch no...',
            onChanged: (v) {
              setState(() {
                detail.batchNo = v;
                // Store batch ID when batch is selected
                if (v != null && detail.itemDescription != null) {
                  final batchList =
                      _itemToBatchNumberList[detail.itemDescription!];
                  if (batchList != null) {
                    try {
                      final batchItem = batchList.firstWhere(
                        (item) => item.text.trim() == v.trim(),
                      );
                      detail.batchId = batchItem.id;
                      print('✅ Batch selected: "$v" -> ID: ${batchItem.id}');
                    } catch (e) {
                      // Try case-insensitive match
                      try {
                        final batchItem = batchList.firstWhere(
                          (item) =>
                              item.text.trim().toLowerCase() ==
                              v.trim().toLowerCase(),
                        );
                        detail.batchId = batchItem.id;
                        print(
                            '✅ Batch selected (case-insensitive): "$v" -> ID: ${batchItem.id}');
                      } catch (e2) {
                        print('⚠️ Batch not found in list: "$v"');
                        detail.batchId = null;
                      }
                    }
                    // Auto-fill qty in stock, UOM, and rate if available
                    if (detail.batchId != null && detail.batchId! > 0) {
                      try {
                        // Find the batch item to get stock, UOM, and rate
                        final batchItem = batchList.firstWhere(
                          (item) => item.id == detail.batchId,
                          orElse: () => batchList.firstWhere(
                            (item) => item.text.trim() == v.trim(),
                          ),
                        );

                        // Auto-fill Stock Quantity
                        if (batchItem.stock > 0) {
                          detail.qtyInStockCtrl.text =
                              batchItem.stock.toString();
                        } else {
                          detail.qtyInStockCtrl.clear();
                        }

                        // Auto-fill UOM (Unit of Measure)
                        // UOM is stored as ID, convert to string for display
                        if (batchItem.uom > 0) {
                          detail.uomCtrl.text = batchItem.uom.toString();
                        } else {
                          detail.uomCtrl.clear();
                        }

                        // Auto-fill Rate (if > 0)
                        if (batchItem.rate > 0) {
                          detail.rateCtrl.text = batchItem.rate.toString();
                          // Recalculate amount if qty issued is already entered
                          _calculateAmountForItem(detail);
                        } else {
                          detail.rateCtrl.clear();
                          _calculateAmountForItem(
                              detail); // Recalculate to set amount to 0
                        }

                        print('✅ Auto-filled from Batch No "$v":');
                        print('   - Stock: ${batchItem.stock}');
                        print('   - UOM: ${batchItem.uom}');
                        print('   - Rate: ${batchItem.rate}');
                      } catch (e) {
                        print('⚠️ Error auto-filling from batch: $e');
                      }
                    } else {
                      // Clear auto-filled fields when batch is cleared or invalid
                      detail.qtyInStockCtrl.clear();
                      detail.uomCtrl.clear();
                      detail.rateCtrl.clear();
                      _calculateAmountForItem(detail);
                    }
                  } else {
                    print(
                        '⚠️ Batch list not loaded for item: ${detail.itemDescription}');
                    detail.batchId = null;
                  }
                } else {
                  detail.batchId = null;
                }
              });
            },
          ),
        ),
        const SizedBox(height: 12),

        // Qty In Stock, Qty Issued, UOM in a row
        Row(
          children: [
            Expanded(
              child: _Labeled(
                label: 'Qty In Stock',
                child: TextFormField(
                  controller: detail.qtyInStockCtrl,
                  keyboardType: TextInputType.number,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Auto-filled',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Labeled(
                label: 'Qty Issued',
                required: true,
                errorText: detail.qtyIssuedError,
                child: TextFormField(
                  controller: detail.qtyIssuedCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter quantity',
                  ),
                  onChanged: (_) {
                    setState(() {
                      detail.qtyIssuedError = null;
                    });
                    _calculateAmountForItem(detail);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Labeled(
                label: 'UOM',
                child: TextFormField(
                  controller: detail.uomCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Auto-filled',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Rate
        _Labeled(
          label: 'Rate (LKR)',
          child: TextFormField(
            controller: detail.rateCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Enter rate',
              // prefixIcon: Icon(Icons.attach_money, size: 20),
            ),
            onChanged: (_) {
              _calculateAmountForItem(detail);
            },
          ),
        ),
        const SizedBox(height: 12),

        // Amount (Read-only)
        _Labeled(
          label: 'Amount (LKR)',
          child: TextFormField(
            controller: detail.amountCtrl,
            readOnly: true,
            decoration: InputDecoration(
              hintText: 'Auto-calculated',
              filled: true,
              fillColor: Colors.grey.shade100,
              prefixIcon: Icon(Icons.calculate, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Remarks
        _Labeled(
          label: 'Remarks',
          child: TextFormField(
            controller: detail.remarksCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add remarks',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListCard(BuildContext context, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Details',
          style: GoogleFonts.inter(
            fontSize: isTablet ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 20),
        // Multiple Item Details Section (like expense details)
        ..._buildItemDetailsSections(),
        const SizedBox(height: 16),
        if (!_isViewMode)
          Center(
            child: OutlinedButton.icon(
              onPressed: _addAnotherItem,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Another Item'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4db1b3),
                side: const BorderSide(color: Color(0xFF4db1b3), width: 1.5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
      ],
    );
  }

  // Convert ItemDetail to IssueItemDetail for submission
  IssueItemDetail _convertItemDetailToIssueItemDetail(ItemDetail detail) {
    return IssueItemDetail(
      divisionCategory: detail.divisionCategory ?? '',
      itemDescription: detail.itemDescription ?? '',
      batchNo: detail.batchNo ?? '',
      batchId: detail.batchId, // Include batchId if available
      qtyInStock: int.tryParse(detail.qtyInStockCtrl.text.trim()) ?? 0,
      qtyIssued: int.tryParse(detail.qtyIssuedCtrl.text.trim()) ?? 0,
      uom: detail.uomCtrl.text.trim(),
      rate: double.tryParse(detail.rateCtrl.text.trim()) ?? 0.0,
      amount: double.tryParse(detail.amountCtrl.text.trim()) ?? 0.0,
      remarks: detail.remarksCtrl.text.trim(),
    );
  }

  Widget _buildSubmitButton(BuildContext context, bool isTablet) {
    const tealGreen = Color(0xFF4db1b3);
    // Convert _itemDetails to _items for validation
    _items = _itemDetails
        .map((detail) => _convertItemDetailToIssueItemDetail(detail))
        .toList();
    final bool canSubmit = _items.isNotEmpty &&
        _issueAgainst != null &&
        _issueTo != null &&
        _fromStore != null &&
        _toStore != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!canSubmit)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _items.isEmpty
                          ? 'Add at least one item to enable save/submit'
                          : 'Complete all required fields to save/submit',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Save and Submit buttons in a row
        Row(
          children: [
            // Save button
            Expanded(
              child: Tooltip(
                message: canSubmit
                    ? 'Save customer issue (without workflow)'
                    : (_items.isEmpty
                        ? 'Add at least one item first'
                        : 'Complete all required fields first'),
                child: OutlinedButton.icon(
                  onPressed: canSubmit && !_isLoading ? _handleSave : null,
                  icon: Icon(
                    Icons.save,
                    size: 20,
                    color: canSubmit && !_isLoading
                        ? tealGreen
                        : Colors.grey.shade700,
                  ),
                  label: Text(
                    'Save',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 15 : 14,
                      fontWeight: FontWeight.w600,
                      color: canSubmit && !_isLoading
                          ? tealGreen
                          : Colors.grey.shade700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tealGreen,
                    side: BorderSide(
                      color: canSubmit && !_isLoading
                          ? tealGreen
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 16,
                      vertical: isTablet ? 16 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 50),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Submit button
            Expanded(
              child: Tooltip(
                message: canSubmit
                    ? 'Submit customer issue (with workflow)'
                    : (_items.isEmpty
                        ? 'Add at least one item first'
                        : 'Complete all required fields first'),
                child: ElevatedButton.icon(
                  onPressed: canSubmit && !_isLoading ? _handleSubmit : null,
                  icon: Icon(
                    _isLoading
                        ? Icons.hourglass_empty
                        : (canSubmit ? Icons.check_circle : Icons.info_outline),
                    size: 22,
                    color: canSubmit && !_isLoading
                        ? Colors.white
                        : Colors.grey.shade700,
                  ),
                  label: Text(
                    _isLoading ? 'Submitting...' : 'Submit',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 16 : 15,
                      fontWeight: FontWeight.w600,
                      color: canSubmit && !_isLoading
                          ? Colors.white
                          : Colors.grey.shade700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSubmit && !_isLoading
                        ? tealGreen
                        : Colors.grey.shade200,
                    disabledBackgroundColor: Colors.grey.shade200,
                    foregroundColor: canSubmit && !_isLoading
                        ? Colors.white
                        : Colors.grey.shade700,
                    disabledForegroundColor: Colors.grey.shade700,
                    elevation: canSubmit && !_isLoading ? 2 : 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 24 : 20,
                      vertical: isTablet ? 16 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 50),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Handle From Store dropdown change
  void _handleFromStoreChange(String? value) {
    if (value != null && value == _toStore) {
      // Show information dialog
      _showStoreSameDialog();
      // Clear the selection
      setState(() {
        _fromStore = null;
        _fromStoreError = null;
      });
    } else {
      setState(() {
        _fromStore = value;
        _fromStoreError = null;
      });
    }
  }

  /// Handle To Store dropdown change
  void _handleToStoreChange(String? value) {
    if (value != null && value == _fromStore) {
      // Show information dialog
      _showStoreSameDialog();
      // Clear the selection
      setState(() {
        _toStore = null;
        _toStoreError = null;
      });
    } else {
      setState(() {
        _toStore = value;
        _toStoreError = null;
      });
    }
  }

  /// Show information dialog when From Store and To Store are the same
  void _showStoreSameDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Yellow warning icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 40,
                  color: Colors.amber.shade800,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                'Information',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              // Message
              Text(
                'From Store and To Store cannot be same',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'OK',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2196F3),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Get ID from text value in a dropdown list
  int _getIdFromText(String? text, List<CommonDropdownItem> list) {
    if (text == null || list.isEmpty) return 0;
    try {
      final item = list.firstWhere(
        (item) => item.text == text,
      );
      return item.id;
    } catch (e) {
      return 0;
    }
  }

  /// Get workflow process ID and action ID
  Future<Map<String, int?>> _getWorkflowIds() async {
    try {
      // Get user info
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();
      if (user == null) {
        throw Exception('User not available');
      }

      final userId = user.userId ?? user.id ?? 1;

      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      final bizUnit = (userStore?.userDetail?.sbuId != null &&
              userStore!.userDetail!.sbuId! > 0)
          ? userStore.userDetail!.sbuId!
          : (user.sbuId ?? 1);

      // Determine URL based on create or edit mode
      final url =
          _isEditMode ? '/Customeritemissue/edit' : '/Customeritemissue/create';

      // MenuId: 1558 for workflow API (as per user requirements)
      final menuId = 1558;
      final module = 6;

      final workflowRepo = getIt<WorkflowRepository>();
      final request = WorkflowGetAllActionsRequest(
        refId: null,
        applicationId: null,
        menuId: menuId,
        userId: userId,
        module: module,
        bizUnit: bizUnit,
        url: url,
      );

      final response = await workflowRepo.getAllActions(request);

      print('✅ Workflow response received');
      print('   Process ID: ${response.id}');
      print('   Process Name: ${response.processName}');
      print('   Action Details Count: ${response.processActionDetails.length}');

      // Extract processId and processActionId from response
      int? processId = response.id > 0 ? response.id : null;
      int? processActionId;

      // Find the "Submit" action
      if (response.processActionDetails.isNotEmpty) {
        final submitAction = response.processActionDetails.firstWhere(
          (action) => action.name.toLowerCase() == 'submit',
          orElse: () => response.processActionDetails.first,
        );
        processActionId = submitAction.processActionId;
        print('   Found Submit Action ID: $processActionId');
      } else {
        print('⚠️ No workflow actions found - proceeding without workflow');
      }

      return {
        'processId': processId,
        'processActionId': processActionId,
      };
    } catch (e) {
      print('Error getting workflow IDs: $e');
      rethrow;
    }
  }

  /// Build save request from form data
  Future<ItemIssueSaveRequest> _buildSaveRequest({
    required int workflowFlag,
    int? processId,
    int? processActionId,
  }) async {
    // Convert _itemDetails to _items for processing
    _items = _itemDetails
        .map((detail) => _convertItemDetailToIssueItemDetail(detail))
        .toList();

    // Get user info
    final sharedPrefHelper = getIt<SharedPreferenceHelper>();
    final user = await sharedPrefHelper.getUser();
    if (user == null) {
      throw Exception('User not available');
    }

    final userId = user.userId ?? user.id ?? 1;
    final createdBy = userId;
    final modifiedBy = userId;

    final UserDetailStore? userStore =
        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final bizUnit = (userStore?.userDetail?.sbuId != null &&
            userStore!.userDetail!.sbuId! > 0)
        ? userStore.userDetail!.sbuId!
        : (user.sbuId ?? 1);

    // Get IDs from text values
    final fromStoreId = _getIdFromText(_fromStore, _storeList);
    final toStoreId = _getIdFromText(_toStore, _storeList);
    final issueToId = _getIdFromText(_issueTo, _issueToList);
    final issueAgainstId = _getIdFromText(_issueAgainst, _issueAgainstList);

    // IssueAgainst needs to be sent as string (text value), not ID
    final issueAgainstValue = _issueAgainst ?? '';

    // Debug: Print ID mappings
    print('═══════════════════════════════════════════════════════════');
    print('🔍 ID MAPPINGS DEBUG');
    print('═══════════════════════════════════════════════════════════');
    print('From Store: "$_fromStore" -> ID: $fromStoreId');
    print('To Store: "$_toStore" -> ID: $toStoreId');
    print('Issue To: "$_issueTo" -> ID: $issueToId');
    print('Issue Against: "$_issueAgainst" -> ID: $issueAgainstId');
    print('Store List Count: ${_storeList.length}');
    print('Issue To List Count: ${_issueToList.length}');
    print('Issue Against List Count: ${_issueAgainstList.length}');
    print('═══════════════════════════════════════════════════════════');

    // Validate critical IDs
    if (toStoreId == 0) {
      throw Exception('To Store ID is 0. Please select a valid To Store.');
    }
    if (issueToId == 0) {
      throw Exception('Issue To ID is 0. Please select a valid Issue To.');
    }
    if (fromStoreId == 0) {
      throw Exception('From Store ID is 0. Please select a valid From Store.');
    }

    // Build details list
    final List<ItemIssueDetailSaveRequest> details = [];
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];

      // Get item description ID and item
      final itemDescriptionList =
          _divisionToItemDescriptionList[item.divisionCategory] ?? [];
      final itemDescriptionId =
          _getIdFromText(item.itemDescription, itemDescriptionList);

      // Get the actual item object to extract UOM and other fields
      CommonDropdownItem? itemDescriptionObj;
      try {
        itemDescriptionObj = itemDescriptionList.firstWhere(
          (obj) => obj.text == item.itemDescription,
        );
      } catch (e) {
        print(
            'Warning: Item description object not found for: ${item.itemDescription}');
      }

      // Get batch ID - prefer stored batchId from IssueItemDetail, otherwise lookup
      int batchId = 0;
      CommonDropdownItem? batchObj;

      // First, try to get batchId from the IssueItemDetail (stored when batch was selected)
      if (item.batchId != null && item.batchId! > 0) {
        batchId = item.batchId!;
        print('✅ Using stored batch ID: $batchId for batch: "${item.batchNo}"');
      } else {
        // Fallback: lookup batch ID from batch list
        final batchList = _itemToBatchNumberList[item.itemDescription];

        if (batchList != null && batchList.isNotEmpty) {
          // Try exact match first
          try {
            batchObj = batchList.firstWhere(
              (obj) => obj.text.trim() == item.batchNo.trim(),
            );
            batchId = batchObj.id;
          } catch (e) {
            // Try case-insensitive match
            try {
              batchObj = batchList.firstWhere(
                (obj) =>
                    obj.text.trim().toLowerCase() ==
                    item.batchNo.trim().toLowerCase(),
              );
              batchId = batchObj.id;
            } catch (e2) {
              // Try partial match (contains)
              try {
                batchObj = batchList.firstWhere(
                  (obj) =>
                      obj.text.trim().contains(item.batchNo.trim()) ||
                      item.batchNo.trim().contains(obj.text.trim()),
                );
                batchId = batchObj.id;
              } catch (e3) {
                print('⚠️ Batch matching failed for: "${item.batchNo}"');
                print('Available batches for "${item.itemDescription}":');
                for (var batch in batchList) {
                  print('  - "${batch.text}" (ID: ${batch.id})');
                }
                // Try using _getIdFromText as fallback
                batchId = _getIdFromText(item.batchNo, batchList);
                if (batchId == 0) {
                  print(
                      '⚠️ Batch ID lookup returned 0. Batch may not be required or needs to be reloaded.');
                }
              }
            }
          }
        } else {
          print(
              '⚠️ Batch list is null or empty for item: ${item.itemDescription}');
          print(
              'Available item descriptions with batches: ${_itemToBatchNumberList.keys.toList()}');
        }
      }

      // Get division category ID
      final divisionCategoryId =
          _getIdFromText(item.divisionCategory, _divisionCategoryList);

      // Get UOM ID from batch object or item description object
      int uomId = 0;
      if (batchObj != null && batchObj.uom > 0) {
        uomId = batchObj.uom;
      } else if (itemDescriptionObj != null && itemDescriptionObj.uom > 0) {
        uomId = itemDescriptionObj.uom;
      }

      // Get item ID from item description
      final itemId = itemDescriptionId > 0
          ? itemDescriptionId
          : (itemDescriptionObj?.id ?? 0);

      // Validate item details
      if (itemId == 0) {
        throw Exception(
            'Item ID is 0 for item: ${item.itemDescription}. Please ensure the item is selected correctly.');
      }
      if (divisionCategoryId == 0) {
        throw Exception(
            'Division Category ID is 0 for: ${item.divisionCategory}. Please ensure the division category is selected correctly.');
      }

      // Batch ID validation - warn but don't fail if batch list wasn't loaded
      // Some APIs might accept 0 for batch ID or handle it differently
      if (batchId == 0 && item.batchNo.isNotEmpty) {
        print('⚠️ WARNING: Batch ID is 0 for batch: "${item.batchNo}"');
        print('   This might cause issues. Trying to continue anyway...');
        // Don't throw exception - let API handle it, but log the warning
        // If API requires batch ID, it will return a proper error message
      }

      // Debug: Print item details
      print('Item $i Details:');
      print('  - Item Description: ${item.itemDescription} -> ID: $itemId');
      print('  - Batch No: ${item.batchNo} -> ID: $batchId');
      print(
          '  - Division Category: ${item.divisionCategory} -> ID: $divisionCategoryId');
      print('  - UOM: ${item.uom} -> UOM ID: $uomId');
      print('  - Qty Issued: ${item.qtyIssued}');
      print('  - Rate: ${item.rate}');
      print('  - Amount: ${item.amount}');

      details.add(ItemIssueDetailSaveRequest(
        id: null,
        createdBy: null,
        status: 0,
        sbuId: 0,
        displayOrder: i,
        hasRight: false,
        text: null,
        rowNo: null,
        itemCode: item.itemDescription,
        batchNo: item.batchNo,
        itemName: null,
        itemDescription: null,
        itemText: item.itemDescription,
        minStk: null,
        rolStk: null,
        maxStk: null,
        quantityInStock: item.qtyInStock.toDouble(),
        quantityPnOrder: null,
        quantityApproved: null,
        quantityConsumed: item.qtyIssued.toDouble(), // Quantity Issued Value
        requestQuantity: null,
        uomCode: null,
        categoryName: null,
        categoryText: null,
        itemIsPm: null,
        requestSpec: null,
        category: null,
        code: null,
        wholesaleRate: null,
        retailRate: null,
        name: null,
        rate: item.rate,
        description: null,
        itemCategory: divisionCategoryId,
        itemCategoryText: item.divisionCategory,
        requestedQty: null,
        specification: null,
        requestedBy: null,
        uomText: item.uom,
        purchaseRequestHeaderId: 0,
        no: null,
        date: null,
        version: 0,
        select: null,
        slNo: i,
        item: itemId,
        batchId: batchId,
        stockBatch: null,
        itemSpecification: null,
        purpose: null,
        quantityRequested: 0.0,
        quantityRecieved: null,
        quantityOrdered: null,
        instruction: null,
        uom: uomId > 0
            ? uomId
            : 44, // Default to 44 if not found (as per sample)
        requiredDate: null,
        remarks: item.remarks,
        department: 0,
        bizunit: 0,
        oldItem: null,
        editComments: null,
        isChecked: false,
        lotNo: null,
        dateOfManufacture: null,
        stock: item.qtyInStock.toDouble(),
        stockText: item.qtyInStock.toString(),
        expiryDate: null,
        comments: null,
        tax: null,
        discount: null,
        totalAmount: null,
        netAmount: null,
        adjAmount: null,
        shippingAmount: null,
        customerQty: null,
        customerItem: 0,
        action: 0,
        amount: item.amount,
        quantity: null,
        valueText: null,
        amountWise: null,
        quantityWise: null,
        pageName: null,
        purchaseRequestId: null,
        itemCount: null,
        division: null,
        divisionText: item.divisionCategory,
        manufacturerText: null,
        divisionName: null,
        divisionGroupText: null,
        divisionGroup: null,
        taxId: null,
        taxText: null,
        isUpdate: null,
        manufacturerCountry: null,
        isFOC: false,
        country: null,
        rowIndex: null,
        isReceiptBatchRequired: null,
        detailId: null,
        actualBatchNo: null,
      ));
    }

    // Validate details
    if (details.isEmpty) {
      throw Exception(
          'No items added. Please add at least one item before saving.');
    }

    // Format date
    // Use ISO 8601 format which is compatible with System.Text.Json in .NET
    // Example: "2025-12-30T15:08:02.222"
    final dateStr = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS").format(_stDate);

    // MenuId: 1554 for save API (as per list screen)
    final menuId = 1554;
    final moduleId = 6;

    return ItemIssueSaveRequest(
      id: _isEditMode ? int.tryParse(widget.issueId ?? '') : null,
      createdBy: createdBy,
      status: 0,
      sbuId: 0,
      no: _stNo ?? '[NEW]',
      version: null,
      date: dateStr,
      fromDate: null,
      toDate: null,
      type: null,
      totalQty: null,
      remarks: _referenceCtrl.text.trim().isEmpty
          ? null
          : _referenceCtrl.text.trim(),
      comments: null,
      department: fromStoreId, // Using fromStoreId as department
      toStore: toStoreId,
      issueTo: issueToId,
      bizunit: bizUnit,
      module: null,
      company: 1,
      modifiedBy: modifiedBy,
      modifiedDate: null,
      isWorkOrder: null,
      isEdit: null,
      confirmStockValueChange: null,
      astDocMode: null,
      aptCode: null,
      isMultipleBatch: null,
      multiBatchGroup: null,
      transactionType: 14,
      isCancelled: null,
      workflowProcess: null,
      reference: _referenceCtrl.text.trim().isEmpty
          ? null
          : _referenceCtrl.text.trim(),
      workflowFlag: workflowFlag,
      processId: processId,
      processActionId: processActionId,
      workflowComment: null,
      workflowStatus: 0,
      departmentText: null,
      toStoreText: null,
      companyText: null,
      typeText: null,
      statusText: null,
      isSelected: false,
      hasEdit: true,
      edit: null,
      action: null,
      view: null,
      delete: null,
      details: details,
      dateRequired: null,
      departmentRequired: null,
      toStoreRequired: null,
      totalQtyNegative: null,
      detailsRequired: null,
      refid: null,
      menuId: menuId,
      moduleId: moduleId,
      userId: userId,
      divisionGroup: null,
      issueAgainst: issueAgainstValue, // Send as string text value
      issueReceiptType: 1,
      itemText: null,
    );
  }

  /// Handle save (without workflow)
  Future<void> _handleSave() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Build save request with workflowFlag = 0 and null process IDs
      final saveRequest = await _buildSaveRequest(
        workflowFlag: 0,
        processId: null,
        processActionId: null,
      );

      // Debug: Print the request JSON
      print('═══════════════════════════════════════════════════════════');
      print('📤 SAVE REQUEST JSON');
      print('═══════════════════════════════════════════════════════════');
      print(saveRequest.toJson());
      print('═══════════════════════════════════════════════════════════');

      // Call save API
      final itemIssueRepo = getIt<ItemIssueRepository>();
      await itemIssueRepo.saveItemIssue(saveRequest);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Customer Issue saved successfully'
                  : 'Customer Issue saved successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save customer issue: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Handle submit (with workflow)
  Future<void> _handleSubmit() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Get workflow process ID and action ID
      final workflowIds = await _getWorkflowIds();
      final processId = workflowIds['processId'];
      final processActionId = workflowIds['processActionId'];

      // Step 2: Build save request with workflowFlag = 1 and process IDs
      final saveRequest = await _buildSaveRequest(
        workflowFlag: 1,
        processId: processId,
        processActionId: processActionId,
      );

      // Step 3: Call save API
      final itemIssueRepo = getIt<ItemIssueRepository>();
      await itemIssueRepo.saveItemIssue(saveRequest);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Customer Issue submitted successfully'
                  : 'Customer Issue submitted successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit customer issue: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _validateForm() {
    bool isValid = true;

    if (_issueAgainst == null) {
      setState(() {
        _issueAgainstError = 'This field is required';
      });
      isValid = false;
    }

    if (_issueTo == null) {
      setState(() {
        _issueToError = 'This field is required';
      });
      isValid = false;
    }

    if (_fromStore == null) {
      setState(() {
        _fromStoreError = 'This field is required';
      });
      isValid = false;
    }

    if (_toStore == null) {
      setState(() {
        _toStoreError = 'This field is required';
      });
      isValid = false;
    }

    // Validate that From Store and To Store are not the same
    if (_fromStore != null && _toStore != null && _fromStore == _toStore) {
      _showStoreSameDialog();
      setState(() {
        _fromStoreError = 'From Store and To Store cannot be same';
        _toStoreError = 'From Store and To Store cannot be same';
      });
      isValid = false;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item before submitting'),
          backgroundColor: Colors.orange,
        ),
      );
      isValid = false;
    }

    if (!isValid) {
      // Scroll to first error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Scrollable.ensureVisible(context);
      });
    }

    return isValid;
  }
}

// Add Item Dialog Widget
class _AddItemDialog extends StatefulWidget {
  final Function(IssueItemDetail) onAdd;

  const _AddItemDialog({required this.onAdd});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  String? _divisionCategory;
  String?
      _itemDescription; // Changed from TextEditingController to String for dropdown
  String? _batchNo; // Changed from TextEditingController to String for dropdown
  final TextEditingController _qtyInStockCtrl = TextEditingController();
  final TextEditingController _qtyIssuedCtrl = TextEditingController();
  final TextEditingController _uomCtrl = TextEditingController();
  final TextEditingController _rateCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();

  // Division/Category dropdown options
  List<String> _divisionCategoryOptions = [];
  List<CommonDropdownItem> _divisionCategoryList = [];
  bool _isLoadingDivisionCategory = false;
  String? _divisionCategoryError;

  // Item Description dropdown options
  List<String> _itemDescriptionOptions = [];
  List<CommonDropdownItem> _itemDescriptionList = [];
  bool _isLoadingItemDescription = false;
  String? _itemDescriptionLoadError;

  // Batch No dropdown options
  List<String> _batchNoOptions = [];
  List<CommonDropdownItem> _batchNoList = [];
  bool _isLoadingBatchNo = false;
  String? _batchNoLoadError;

  // Validation errors
  String? _divisionCategoryFormError;
  String? _itemDescriptionError;
  String? _qtyIssuedError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDivisionCategoryOptions();
    });
  }

  @override
  void dispose() {
    // _itemDescriptionCtrl and _batchNoCtrl removed - now using String? for dropdowns
    _qtyInStockCtrl.dispose();
    _qtyIssuedCtrl.dispose();
    _uomCtrl.dispose();
    _rateCtrl.dispose();
    _amountCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  /// Load Division/Category list from API
  Future<void> _loadDivisionCategoryOptions() async {
    if (!mounted) return;

    setState(() {
      _isLoadingDivisionCategory = true;
      _divisionCategoryError = null;
    });

    try {
      final commonRepository = getIt<CommonRepository>();
      final divisionCategoryList =
          await commonRepository.getDivisionCategoryList().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
              'Request timeout: Failed to load division/category options');
        },
      );

      if (mounted) {
        setState(() {
          _divisionCategoryList = divisionCategoryList;
          _divisionCategoryOptions =
              divisionCategoryList.map((item) => item.text).toList();
          _isLoadingDivisionCategory = false;
        });

        // Debug: Print loaded options
        print(
            'Division/Category options loaded: ${_divisionCategoryOptions.length} items');
        if (_divisionCategoryOptions.isNotEmpty) {
          print('First option: ${_divisionCategoryOptions.first}');
        }
      }
    } catch (e) {
      print('Error loading division/category: $e');
      if (mounted) {
        setState(() {
          _isLoadingDivisionCategory = false;
          _divisionCategoryError =
              'Failed to load division/category options: ${e.toString()}';
          _divisionCategoryOptions = [];
        });

        Future.microtask(() {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Failed to load division/category options. Please try again.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }

  /// Load Item Description list from API based on selected Division ID
  Future<void> _loadItemDescriptions(int divisionId) async {
    if (!mounted) return;

    setState(() {
      _isLoadingItemDescription = true;
      _itemDescriptionLoadError = null;
      _itemDescription = null; // Clear previous selection
      _itemDescriptionOptions = [];
    });

    try {
      final commonRepository = getIt<CommonRepository>();
      final itemDescriptionList =
          await commonRepository.getItemDescriptionList(divisionId).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout: Failed to load item descriptions');
        },
      );

      if (mounted) {
        setState(() {
          _itemDescriptionList = itemDescriptionList;
          _itemDescriptionOptions =
              itemDescriptionList.map((item) => item.text).toList();
          _isLoadingItemDescription = false;
        });

        print(
            'Item Description options loaded: ${_itemDescriptionOptions.length} items');
      }
    } catch (e) {
      print('Error loading item descriptions: $e');
      if (mounted) {
        setState(() {
          _isLoadingItemDescription = false;
          _itemDescriptionLoadError =
              'Failed to load item descriptions: ${e.toString()}';
          _itemDescriptionOptions = [];
        });

        Future.microtask(() {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Failed to load item descriptions. Please try again.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }

  /// Load Batch No list from API based on selected Item ID
  Future<void> _loadBatchNumbers(int itemId) async {
    if (!mounted) return;

    setState(() {
      _isLoadingBatchNo = true;
      _batchNoLoadError = null;
      _batchNo = null; // Clear previous selection
      _batchNoOptions = [];
    });

    try {
      // Get user info for EmployeeId and BizUnit
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();

      if (user == null) {
        throw Exception('User not available');
      }

      // Get employeeId from UserDetailStore
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      final employeeId = userStore?.userDetail?.employeeId ?? 1;

      // Get BizUnit - prioritize UserDetailStore, then SharedPreferenceHelper, then default to 1
      // Same logic as customer_issue_list_screen.dart
      int? bizUnitFromStore = userStore?.userDetail?.sbuId;
      int? bizUnitFromPrefs = user.sbuId;

      // Prefer UserDetailStore, fallback to SharedPreferences, then default to 1
      // If either value is 0, treat it as null and use default
      int bizUnit = (bizUnitFromStore != null && bizUnitFromStore! > 0)
          ? bizUnitFromStore!
          : ((bizUnitFromPrefs != null && bizUnitFromPrefs! > 0)
              ? bizUnitFromPrefs!
              : 1);

      // Log for debugging
      print('BatchNo API: bizUnit from UserDetailStore: $bizUnitFromStore');
      print('BatchNo API: bizUnit from SharedPreferences: $bizUnitFromPrefs');
      print('BatchNo API: Final bizUnit: $bizUnit');

      // Validate BizUnit - it should not be 0
      if (bizUnit == 0) {
        throw Exception(
            'BizUnit is 0. UserDetailStore sbuId: $bizUnitFromStore, SharedPreferences sbuId: $bizUnitFromPrefs. Please ensure user details are loaded correctly.');
      }

      // Get current date in yyyy-MM-dd format
      final toDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // For CustomerId, we'll use a default value for now (can be updated later if needed)
      // In a real scenario, this might come from the customer issue context
      final customerId =
          0; // Default value, can be updated based on business logic

      // Create request object to get full JSON
      final batchNoRequest = BatchNoRequest(
        itemId: itemId,
        employeeId: employeeId,
        toDate: toDate,
        bizUnit: bizUnit,
        module: 6,
        customerId: customerId,
        transactionType: 14,
      );

      // Print Batch No API Request Parameters
      print('═══════════════════════════════════════════════════════════');
      print('📦 BATCH NO API REQUEST (Customer Issue - Add Item)');
      print('═══════════════════════════════════════════════════════════');
      print('API Endpoint: POST ${Endpoints.commonGetAuto}');
      print('Request Parameters:');
      print('  - CommandType: 332');
      print('  - Id (ItemId): $itemId');
      print('  - EmployeeId: $employeeId');
      print('  - ToDate: $toDate');
      print(
          '  - BizUnit: $bizUnit (${bizUnit == 0 ? "⚠️ WARNING: BizUnit is 0!" : "✓ Valid"})');
      print(
          '    - BizUnit Source: ${bizUnitFromStore != null ? "UserDetailStore" : (bizUnitFromPrefs != null ? "SharedPreferences" : "Default (1)")}');
      print('  - Module: 6');
      print('  - CustomerId: $customerId');
      print('  - TransactionType: 14');
      print('');
      print('Full Request JSON:');
      print(batchNoRequest.toJson());
      print('═══════════════════════════════════════════════════════════');

      final commonRepository = getIt<CommonRepository>();
      final batchNoList = await commonRepository
          .getBatchNoList(
        itemId: itemId,
        employeeId: employeeId,
        toDate: toDate,
        bizUnit: bizUnit,
        customerId: customerId,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout: Failed to load batch numbers');
        },
      );

      if (mounted) {
        setState(() {
          _batchNoList = batchNoList;
          _batchNoOptions = batchNoList.map((item) => item.text).toList();
          _isLoadingBatchNo = false;
        });

        // Print Batch No API Response
        print('✅ BATCH NO API RESPONSE');
        print('═══════════════════════════════════════════════════════════');
        print('Status: Success');
        print('Total Items: ${_batchNoOptions.length}');
        if (_batchNoOptions.isNotEmpty) {
          print('Batch Numbers:');
          for (int i = 0; i < _batchNoOptions.length && i < 10; i++) {
            print('  ${i + 1}. ${_batchNoOptions[i]}');
          }
          if (_batchNoOptions.length > 10) {
            print('  ... and ${_batchNoOptions.length - 10} more');
          }
        } else {
          print('⚠️  No batch numbers found');
        }
        print('═══════════════════════════════════════════════════════════');
      }
    } catch (e) {
      print('Error loading batch numbers: $e');
      if (mounted) {
        setState(() {
          _isLoadingBatchNo = false;
          _batchNoLoadError = 'Failed to load batch numbers: ${e.toString()}';
          _batchNoOptions = [];
        });

        Future.microtask(() {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Failed to load batch numbers. Please try again.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }

  void _handleAdd() {
    // Validate form
    bool isValid = true;

    if (_divisionCategory == null) {
      setState(() {
        _divisionCategoryFormError = 'This field is required';
      });
      isValid = false;
    } else {
      setState(() {
        _divisionCategoryFormError = null;
      });
    }

    if (_itemDescription == null || _itemDescription!.trim().isEmpty) {
      setState(() {
        _itemDescriptionError = 'This field is required';
      });
      isValid = false;
    } else {
      setState(() {
        _itemDescriptionError = null;
      });
    }

    final qtyIssued = int.tryParse(_qtyIssuedCtrl.text.trim());
    if (qtyIssued == null || qtyIssued <= 0) {
      setState(() {
        _qtyIssuedError = 'Please enter a valid quantity';
      });
      isValid = false;
    } else {
      setState(() {
        _qtyIssuedError = null;
      });
    }

    if (!isValid) {
      return;
    }

    // Calculate amount if rate is provided
    double amount = 0.0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    if (rate > 0 && qtyIssued != null) {
      amount = rate * qtyIssued;
      _amountCtrl.text = amount.toStringAsFixed(2);
    } else {
      amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    }

    // Print item being added
    print('═══════════════════════════════════════════════════════════');
    print('➕ ADDING ITEM TO CUSTOMER ISSUE');
    print('═══════════════════════════════════════════════════════════');
    print('Item Details:');
    print('  - Division/Category: $_divisionCategory');
    print('  - Item Description: $_itemDescription');
    print('  - Batch No: $_batchNo');
    print('  - Qty In Stock: ${_qtyInStockCtrl.text}');
    print('  - Qty Issued: ${_qtyIssuedCtrl.text}');
    print('  - UOM: ${_uomCtrl.text}');
    print('  - Rate: ${_rateCtrl.text}');
    print('  - Amount: ${_amountCtrl.text}');
    print('  - Remarks: ${_remarksCtrl.text}');
    print('═══════════════════════════════════════════════════════════');

    // Create item
    final item = IssueItemDetail(
      divisionCategory: _divisionCategory!,
      itemDescription: _itemDescription!,
      batchNo: _batchNo ?? '',
      qtyInStock: int.tryParse(_qtyInStockCtrl.text.trim()) ?? 0,
      qtyIssued: qtyIssued!,
      uom: _uomCtrl.text.trim(),
      rate: rate,
      amount: amount,
      remarks: _remarksCtrl.text.trim(),
    );

    widget.onAdd(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Add Item',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Required fields note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fields marked with * are mandatory',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Item Info Section
                      _buildSectionHeader('Item Information'),
                      const SizedBox(height: 12),

                      // Division/Category dropdown with improved loading
                      _buildDivisionCategoryField(),
                      const SizedBox(height: 20),

                      // Item Description (Dropdown, loads based on Division/Category)
                      _buildItemDescriptionField(),
                      const SizedBox(height: 20),

                      // Batch No (Dropdown, loads based on Item Description)
                      _buildBatchNoField(),
                      const SizedBox(height: 24),

                      // Quantity Section
                      _buildSectionHeader('Quantity'),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildSecondaryTextField(
                              controller: _qtyInStockCtrl,
                              label: 'Stock Quantity',
                              icon: Icons.inventory_2,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildPrimaryTextField(
                              controller: _qtyIssuedCtrl,
                              label: 'Order Quantity',
                              isRequired: true,
                              icon: Icons.shopping_cart,
                              errorText: _qtyIssuedError,
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _calculateAmount();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Pricing Section
                      _buildSectionHeader('Pricing'),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildSecondaryTextField(
                              controller: _uomCtrl,
                              label: 'Unit of Measure',
                              icon: Icons.straighten,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildPrimaryTextField(
                              controller: _rateCtrl,
                              label: 'Rate (LKR)',
                              icon: Icons.attach_money,
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              onChanged: (value) {
                                _calculateAmount();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Amount (Read-only, auto-calculated)
                      _buildReadOnlyAmountField(),
                      const SizedBox(height: 24),

                      // Notes Section
                      _buildSectionHeader('Notes'),
                      const SizedBox(height: 12),

                      _buildSecondaryTextField(
                        controller: _remarksCtrl,
                        label: 'Remarks',
                        icon: Icons.note,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Sticky footer with buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _handleAdd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4db1b3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Add Item',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDivisionCategoryField() {
    return _LabeledField(
      label: 'Division / Category',
      required: true,
      errorText: _divisionCategoryFormError,
      child: _isLoadingDivisionCategory
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading categories...',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : SearchableDropdown(
              options: _divisionCategoryOptions,
              value: _divisionCategory,
              hintText: '-- Select Division/Category --',
              searchHintText: 'Search division/category...',
              hasError: _divisionCategoryFormError != null,
              onChanged: _divisionCategoryOptions.isEmpty
                  ? (_) {}
                  : (value) {
                      setState(() {
                        _divisionCategory = value;
                        _divisionCategoryFormError = null;
                        _itemDescription =
                            null; // Clear item description when division changes
                      });

                      // Load item descriptions based on selected division
                      if (value != null) {
                        // Find the division ID from the selected division/category
                        final selectedDivision =
                            _divisionCategoryList.firstWhere(
                          (item) => item.text == value,
                          orElse: () => _divisionCategoryList.first,
                        );

                        if (selectedDivision.id > 0) {
                          _loadItemDescriptions(selectedDivision.id);
                        }
                      }
                    },
            ),
    );
  }

  Widget _buildLoadingDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading categories...',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemDescriptionField() {
    return _LabeledField(
      label: 'Item Description',
      required: true,
      errorText: _itemDescriptionError,
      child: _divisionCategory == null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade100,
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please select Division/Category first',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _isLoadingItemDescription
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Loading items...',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : SearchableDropdown(
                  options: _itemDescriptionOptions,
                  value: _itemDescription,
                  hintText: '-- Select Item Description --',
                  searchHintText: 'Search item description...',
                  hasError: _itemDescriptionError != null,
                  onChanged: _itemDescriptionOptions.isEmpty
                      ? (_) {}
                      : (value) {
                          setState(() {
                            _itemDescription = value;
                            _itemDescriptionError = null;
                            _batchNo = null; // Clear batch no when item changes
                          });

                          // Load batch numbers based on selected item
                          if (value != null) {
                            // Find the item ID from the selected item description
                            final selectedItem =
                                _itemDescriptionList.firstWhere(
                              (item) => item.text == value,
                              orElse: () => _itemDescriptionList.first,
                            );

                            if (selectedItem.id > 0) {
                              _loadBatchNumbers(selectedItem.id);
                            }
                          }
                        },
                ),
    );
  }

  Widget _buildBatchNoField() {
    return _LabeledField(
      label: 'Batch No',
      required: false,
      child: _itemDescription == null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 1),
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: Colors.grey.shade500),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please select Item Description first',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _isLoadingBatchNo
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey.shade50,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Loading batch numbers...',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : SearchableDropdown(
                  options: _batchNoOptions,
                  value: _batchNo,
                  hintText: '-- Select Batch No --',
                  searchHintText: 'Search batch number...',
                  hasError: false,
                  onChanged: _batchNoOptions.isEmpty
                      ? (_) {}
                      : (value) {
                          setState(() {
                            _batchNo = value;

                            // Auto-fill fields from selected batch
                            if (value != null && _batchNoList.isNotEmpty) {
                              try {
                                final selectedBatch = _batchNoList.firstWhere(
                                  (item) => item.text == value,
                                  orElse: () => _batchNoList.first,
                                );

                                // Auto-fill Stock Quantity
                                if (selectedBatch.stock > 0) {
                                  _qtyInStockCtrl.text =
                                      selectedBatch.stock.toString();
                                } else {
                                  _qtyInStockCtrl.clear();
                                }

                                // Auto-fill UOM (Unit of Measure)
                                if (selectedBatch.uom > 0) {
                                  _uomCtrl.text = selectedBatch.uom.toString();
                                } else {
                                  _uomCtrl.clear();
                                }

                                // Auto-fill Rate (if > 0)
                                if (selectedBatch.rate > 0) {
                                  _rateCtrl.text =
                                      selectedBatch.rate.toString();
                                  // Recalculate amount if order quantity is already entered
                                  _calculateAmount();
                                } else {
                                  _rateCtrl.clear();
                                  _calculateAmount(); // Recalculate to set amount to 0
                                }

                                print('✅ Auto-filled from Batch No:');
                                print('  - Stock: ${selectedBatch.stock}');
                                print('  - UOM: ${selectedBatch.uom}');
                                print('  - Rate: ${selectedBatch.rate}');
                              } catch (e) {
                                print('Error auto-filling from batch: $e');
                              }
                            } else {
                              // Clear auto-filled fields when batch is cleared
                              _qtyInStockCtrl.clear();
                              _uomCtrl.clear();
                              _rateCtrl.clear();
                              _calculateAmount(); // Recalculate to set amount to 0
                            }
                          });
                        },
                ),
    );
  }

  Widget _buildPrimaryTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    String? errorText,
    TextInputType? keyboardType,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isRequired)
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )
        else
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            errorText: errorText,
            prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: const Color(0xFF4db1b3), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Amount (LKR)',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Auto-calculated',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountCtrl,
          readOnly: true,
          decoration: InputDecoration(
            prefixIcon:
                Icon(Icons.calculate, size: 20, color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  void _calculateAmount() {
    final qty = int.tryParse(_qtyIssuedCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    if (rate > 0 && qty > 0) {
      setState(() {
        _amountCtrl.text = (rate * qty).toStringAsFixed(2);
      });
    } else {
      setState(() {
        _amountCtrl.text = '0.00';
      });
    }
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> options,
    Function(String?)? onChanged,
    String? helperText,
    String? errorText,
    Widget? prefixIcon,
    bool isSecondary = false, // For optional fields with lighter styling
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label.isEmpty ? null : label,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isSecondary ? Colors.grey.shade300 : Colors.grey.shade400,
            width: isSecondary ? 1 : 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isSecondary ? Colors.grey.shade300 : Colors.grey.shade400,
            width: isSecondary ? 1 : 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isSecondary ? Colors.grey.shade400 : const Color(0xFF4db1b3),
            width: isSecondary ? 1.5 : 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        filled: true,
        fillColor: isSecondary ? Colors.grey.shade50 : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      hint: Text(
        options.isEmpty ? 'No options available' : 'Select an option',
        style: GoogleFonts.inter(
          fontSize: 15,
          color: Colors.grey.shade600,
        ),
      ),
      items: options.isEmpty
          ? [
              DropdownMenuItem<String>(
                value: null,
                enabled: false,
                child: Text(
                  'No options available',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade400,
                    fontSize: 15,
                  ),
                ),
              ),
            ]
          : options.map((option) {
              final isDisabled = option == 'Loading...';
              return DropdownMenuItem<String>(
                value: isDisabled ? null : option,
                enabled: !isDisabled,
                child: Text(
                  option,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: isDisabled
                        ? Colors.grey.shade400
                        : Colors.grey.shade900,
                  ),
                ),
              );
            }).toList(),
      onChanged: options.isEmpty ? null : onChanged,
      isExpanded: true,
      menuMaxHeight: 300,
      icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
      iconSize: 24,
      style: GoogleFonts.inter(
        fontSize: 15,
        color: Colors.grey.shade900,
      ),
    );
  }
}

// Labeled widget matching expense screen pattern
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
                          fontSize: 13,
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 6),
        ],
        child,
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.red.shade600,
            ),
          ),
        ],
      ],
    );
  }
}

// LabeledField widget matching reference design
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.errorText,
    this.required = false,
    this.hintText,
  });
  final String label;
  final Widget child;
  final String? errorText;
  final bool required;
  final String? hintText;

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
              fontWeight: FontWeight.w400, // Lighter font weight
              color: Colors.grey.shade700,
            ),
            children: required
                ? [
                    TextSpan(
                      text: ' *',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 8),
        child,
        if (hintText != null && hintText!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            hintText!,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
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

// Item detail model for the table (different from CustomerIssueItem in list screen)
class IssueItemDetail {
  final String divisionCategory;
  final String itemDescription;
  final String batchNo;
  final int? batchId; // Optional batch ID
  final int qtyInStock;
  final int qtyIssued;
  final String uom;
  final double rate;
  final double amount;
  final String remarks;

  IssueItemDetail({
    required this.divisionCategory,
    required this.itemDescription,
    required this.batchNo,
    this.batchId,
    required this.qtyInStock,
    required this.qtyIssued,
    required this.uom,
    required this.rate,
    required this.amount,
    required this.remarks,
  });
}
