import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:boilerplate/domain/entity/sales/sales_api_models.dart';
import 'package:boilerplate/domain/repository/sales/sales_repository.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart'
    show
        CommonDropdownItem,
        TaxComponentResponse,
        ChargesType,
        ItemDetailResponse;
import 'package:boilerplate/domain/entity/workflow/workflow_api_models.dart'
    show
        WorkflowGetAllActionsRequest,
        WorkflowGetAllActionsResponse,
        ProcessActionDetail,
        WorkflowGetUserPagePrivilegesRequest,
        WorkflowGetUserPagePrivilegesResponse,
        ButtonPrivilege;
import 'package:boilerplate/domain/repository/workflow/workflow_repository.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';

import 'models/sales_product.dart';

class SaleCreationScreen extends StatefulWidget {
  final String? contractId;
  final String? orderId;
  final SalesOrderApiItem? orderData;

  const SaleCreationScreen({
    super.key,
    this.contractId,
    this.orderId,
    this.orderData,
  });

  @override
  State<SaleCreationScreen> createState() => _SaleCreationScreenState();
}

class _SaleCreationScreenState extends State<SaleCreationScreen> {
  bool _isLoading = false;
  SalesOrderApiItem? _loadedOrderData;
  bool _isLoadingCustomers = false;
  bool _isActionsMenuOpen = false; // Track if actions menu is open

// Customers fetched from API
  List<Customer> Customers = [];

  List<String> _salesReps = []; // Will be populated from API

  List<String> _distributors = []; // Will be populated from API
  List<CommonDropdownItem> _distributorItems =
      []; // Store full distributor items for ID mapping

  // Products are fetched from API via _searchItems, no mock data needed

// Form state
  late DateTime _contractDate;
  late DateTime _deliveryDate;
  DateTime? _reqdDate; // Required Date (readonly)
  String? _soNumber; // Auto-generated, can be null for new orders
  String? _selectedType;
  String? _selectedCurrency = 'LKR';
  String? _selectedCustomerCode;
  final TextEditingController CustomerAddressController =
      TextEditingController();
  final TextEditingController _customerSearchController =
      TextEditingController();
  String? _selectedSalesRep;
  List<CommonDropdownItem> _salesRepItems =
      []; // Store sales rep items with IDs
  String? _selectedDistributor;
  final TextEditingController _notesController = TextEditingController();

  // New fields
  final TextEditingController _customerPOController = TextEditingController();
  String? _selectedUserGroup;
  final TextEditingController _quotationNoController = TextEditingController();
  bool _isBonusSO = false;
  bool _isBonusEnabled = false;
  final TextEditingController _exchangeRateController = TextEditingController();
  final TextEditingController _deliveryAddressController =
      TextEditingController();

  // Tax and charges
  final TextEditingController _subTotalController = TextEditingController();
  final TextEditingController _priceAdjustmentController =
      TextEditingController();

  double get _subTotal => double.tryParse(_subTotalController.text) ?? 0.0;

  static int? _parseChargeDetailId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString());
  }

  // Multiple tax/discount/other charge rows
  final List<_TaxChargeRow> _taxRows = [];
  final List<_TaxChargeRow> _discountRows = [];
  final List<_TaxChargeRow> _otherChargeRows = [];

  double get _priceAdjustment =>
      double.tryParse(_priceAdjustmentController.text) ?? 0.0;

  // Tax Component Formulas (loaded from API)
  List<TaxComponentResponse> _taxComponentFormulas = [];
  bool _isLoadingTaxFormulas = false;

  // When editing: preserve API ids for tax/charge rows so save sends them back (avoids 500)
  int? _loadedPriceAdjustmentChargeId;
  int? _loadedGrandTotalChargeId;

  // Workflow Actions (loaded from API)
  WorkflowGetAllActionsResponse? _workflowResponse;
  List<ProcessActionDetail> _workflowActions = [];
  bool _isLoadingWorkflowActions =
      true; // Start as true to show loader until API completes
  bool _isFirstButtonEnabled = false; // Based on HasEdit of first button

  // User Page Privileges (loaded from API)
  WorkflowGetUserPagePrivilegesResponse? _userPrivilegesResponse;
  Map<String, ButtonPrivilege> _buttonPrivileges = {};
  bool _isLoadingPrivileges =
      true; // Start as true to show loader until API completes
  bool _hasButtonSaveRight = false; // ButtonSave HasRight
  bool _hasPrintRight = false; // Print button HasRight
  bool _isDraftSaveEnabled =
      false; // Draft Save enabled based on ButtonSave or IsSalesRepEdit
  bool _firstPrivilegeLoadCompleted =
      false; // Track if first load has completed
  bool _hasBeenSubmitted =
      false; // Track if order has been submitted (for WorkflowFlag logic)

  final List<String> _typeOptions = ['Normal', 'Bonus', 'Domestic'];
  final List<String> _currencyOptions = ['LKR', 'USD'];
  List<String> _taxTypeOptions = [
    'Select'
  ]; // Will be loaded from API, starts with "Select"
  List<String> _discountTypeOptions = [
    'Select'
  ]; // Will be loaded from API, starts with "Select"
  final List<String> _userGroupOptions = ['Diagnostic', 'Pharmacy', 'Hospital'];

// Items
  final List<_LineItem> _items = [];
  final Map<int, bool> _slabAvailabilityCache = {};
  final Map<int, List<SalesBonusSlabItem>> _discountSlabCache = {};

  // Attachments
  final List<PlatformFile> _attachments = [];
  bool _isAttachmentsExpanded = true; // Default to expanded

  // Tax section
  bool _isTaxSectionExpanded = true; // Default to expanded

  // Order Information section
  bool _isOrderInfoExpanded = true; // Default to expanded

  // Scroll controller to preserve scroll position
  final ScrollController _scrollController = ScrollController();

  // Flag to prevent automatic focus restoration after dropdown selection
  bool _preventingFocusRestoration = false;

  bool get _isEditMode =>
      widget.contractId != null ||
      widget.orderId != null ||
      widget.orderData != null;

  @override
  void initState() {
    super.initState();
    // Initialize with default values first to prevent null errors
    _contractDate = DateTime.now();
    _deliveryDate = DateTime.now();

    // Load tax and discount options for Tax section dropdowns
    _loadTaxOptionsForTaxSection();
    _loadDiscountOptionsForTaxSection();
    // Load tax component formulas (using default id: 22 as per API example)
    _loadTaxComponentFormulas(id: 22);
    // Load workflow actions
    _loadWorkflowActions();
    // Load user page privileges
    _loadUserPagePrivileges();

    if (_isEditMode) {
      // Always fetch full order from API when we have an ID (orderId or orderData.id)
      // so we get complete data including fileUploadDetails/attachments
      final idToFetch = widget.orderId != null
          ? int.tryParse(widget.orderId!)
          : widget.orderData?.id;
      if (idToFetch != null && idToFetch > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadOrderData(fetchOrderId: idToFetch);
        });
      } else if (widget.orderData != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadedOrderData = widget.orderData;
          _populateFormFromOrderData(widget.orderData!);
          _updateDraftSaveEnabled();
        });
      } else {
        // Legacy edit mode with contractId
        _loadEditModeData(widget.contractId!);
      }
    } else {
      _loadNewModeData();
    }
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoadingCustomers = true;
    });

    try {
      // Get bizUnit from user data
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();

      if (user == null) {
        throw Exception('User not available');
      }

      // Get bizUnit from UserDetailStore or user prefs
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;

      int? bizUnitFromStore = userStore?.userDetail?.sbuId;
      int? bizUnitFromPrefs = user.sbuId;
      final int bizUnit = (bizUnitFromStore != null && bizUnitFromStore > 0)
          ? bizUnitFromStore
          : ((bizUnitFromPrefs != null && bizUnitFromPrefs > 0)
              ? bizUnitFromPrefs
              : 1);

      if (bizUnit == 0) {
        throw Exception(
            'BizUnit is 0. Please ensure user details are loaded correctly.');
      }

      // Get userId
      final int userId = user?.id ?? user?.userId ?? 43;

      // Get customer ID - check orderData first (edit mode), then selected customer code
      int? customerId;

      // In edit mode, check if we have orderData with customerId
      if (widget.orderData?.customerId != null) {
        customerId = widget.orderData!.customerId;
      } else if (_loadedOrderData?.customerId != null) {
        customerId = _loadedOrderData!.customerId;
      } else if (_selectedCustomerCode != null &&
          _selectedCustomerCode!.isNotEmpty) {
        // Try to parse selected customer code (should be customer ID as string)
        customerId = int.tryParse(_selectedCustomerCode!);
      }

      print(
          '🔵 [LoadCustomers] CustomerId: $customerId, UserId: $userId, BizUnit: $bizUnit');

      final commonRepository = getIt<CommonRepository>();
      // Load ALL customers without search text filter - fetch once only
      final items = await commonRepository.getCustomerList(
        bizUnit: bizUnit,
        customerId: customerId,
        searchText: null, // No search text - get all customers
        userId: userId,
        sector: 0,
        taxFlag: 0,
        includeCancelled: false,
      );

      if (mounted) {
        setState(() {
          // Convert CommonDropdownItem to Customer
          Customers = items.map((item) {
            return Customer(
              code: item.id.toString(),
              name: item.text,
              address: item.address.isNotEmpty ? item.address : 'N/A',
              city: item.cityName.isNotEmpty ? item.cityName : 'N/A',
              bonusEnabled: item.bonusEnabled,
            );
          }).toList();
          _isLoadingCustomers = false;
        });
      }
    } catch (e) {
      print('Error loading customers: $e');
      if (mounted) {
        setState(() {
          _isLoadingCustomers = false;
          Customers = [];
        });
      }
    }
  }

  Future<void> _loadSalesReps(String customerCode) async {
    try {
      // Get user info
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();

      if (user == null) {
        print('Error: User not available for Sales Rep API');
        return;
      }

      // Get userId from user object
      final int userId = user.userId;

      if (userId == 0) {
        print('Error: UserId is 0');
        return;
      }

      // Parse customer code to int (customer ID)
      final int? customerId = int.tryParse(customerCode);
      if (customerId == null) {
        print('Error: Invalid customer code: $customerCode');
        return;
      }

      print(
          '🔵 Loading Sales Rep for UserId: $userId, CustomerId: $customerId');

      final commonRepository = getIt<CommonRepository>();
      final salesReps = await commonRepository.getSalesRepList(
        userId: userId,
        customerId: customerId,
      );

      if (mounted) {
        setState(() {
          // Store sales rep items with IDs
          _salesRepItems = salesReps;

          // Convert CommonDropdownItem to String list (using text field)
          _salesReps = salesReps.map((item) => item.text).toList();

          // Auto-select the first Sales Rep if available
          if (_salesReps.isNotEmpty) {
            // If current selection is not in the new list, or no selection exists, select the first one
            if (_selectedSalesRep == null ||
                !_salesReps.contains(_selectedSalesRep)) {
              _selectedSalesRep = _salesReps.first;
              print('✅ Auto-selected Sales Rep: ${_selectedSalesRep}');
            }
          } else {
            // Clear selection if no sales reps available
            _selectedSalesRep = null;
          }
        });
        print('✅ Loaded ${_salesReps.length} Sales Reps');
      }
    } catch (e) {
      print('Error loading sales reps: $e');
      if (mounted) {
        setState(() {
          _salesReps = [];
          _selectedSalesRep = null;
        });
      }
    }
  }

  Future<void> _loadDistributorAndSetSelection(
      String customerCode, int distributorId) async {
    try {
      // Get user info for bizUnit
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();

      if (user == null) {
        print('Error: User not available for Distributor API');
        return;
      }

      // Get bizUnit from UserDetailStore or user prefs
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;

      int? bizUnitFromStore = userStore?.userDetail?.sbuId;
      int? bizUnitFromPrefs = user.sbuId;
      final int bizUnit = (bizUnitFromStore != null && bizUnitFromStore > 0)
          ? bizUnitFromStore
          : ((bizUnitFromPrefs != null && bizUnitFromPrefs > 0)
              ? bizUnitFromPrefs
              : 1);

      if (bizUnit == 0) {
        print('Error: BizUnit is 0');
        return;
      }

      // Parse customer code to int (customer ID)
      final int? customerId = int.tryParse(customerCode);
      if (customerId == null) {
        print('Error: Invalid customer code: $customerCode');
        return;
      }

      print(
          '🔵 Loading Distributors for BizUnit: $bizUnit, CustomerId: $customerId, DistributorId: $distributorId');

      final commonRepository = getIt<CommonRepository>();
      final distributors = await commonRepository.getDistributorList(
        bizUnit: bizUnit,
        customerId: customerId,
      );

      if (mounted) {
        setState(() {
          // Store full items for ID mapping
          _distributorItems = distributors;
          // Convert CommonDropdownItem to String list (using text field)
          _distributors = distributors.map((item) => item.text).toList();

          // Find distributor by ID and set selection
          CommonDropdownItem? distributorItem;
          try {
            distributorItem = distributors.firstWhere(
              (item) => item.id == distributorId,
            );
          } catch (e) {
            // Distributor not found by ID, use first one if available
            distributorItem =
                distributors.isNotEmpty ? distributors.first : null;
          }

          if (distributorItem != null && distributorItem.text.isNotEmpty) {
            _selectedDistributor = distributorItem.text;
            print(
                '✅ Set Distributor by ID: ${distributorItem.id} -> ${distributorItem.text}');
          } else if (_distributors.isNotEmpty) {
            _selectedDistributor = _distributors.first;
            print('✅ Auto-selected first Distributor: ${_selectedDistributor}');
          } else {
            _selectedDistributor = null;
          }
        });
        print('✅ Loaded ${_distributors.length} Distributors');
      }
    } catch (e) {
      print('Error loading distributors: $e');
      if (mounted) {
        setState(() {
          _distributors = [];
          _distributorItems = [];
          _selectedDistributor = null;
        });
      }
    }
  }

  Future<void> _loadDistributors(String customerCode) async {
    try {
      // Get user info for bizUnit
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();

      if (user == null) {
        print('Error: User not available for Distributor API');
        return;
      }

      // Get bizUnit from UserDetailStore or user prefs
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;

      int? bizUnitFromStore = userStore?.userDetail?.sbuId;
      int? bizUnitFromPrefs = user.sbuId;
      final int bizUnit = (bizUnitFromStore != null && bizUnitFromStore > 0)
          ? bizUnitFromStore
          : ((bizUnitFromPrefs != null && bizUnitFromPrefs > 0)
              ? bizUnitFromPrefs
              : 1);

      if (bizUnit == 0) {
        print('Error: BizUnit is 0');
        return;
      }

      // Parse customer code to int (customer ID)
      final int? customerId = int.tryParse(customerCode);
      if (customerId == null) {
        print('Error: Invalid customer code: $customerCode');
        return;
      }

      print(
          '🔵 Loading Distributors for BizUnit: $bizUnit, CustomerId: $customerId');

      final commonRepository = getIt<CommonRepository>();
      final distributors = await commonRepository.getDistributorList(
        bizUnit: bizUnit,
        customerId: customerId,
      );

      if (mounted) {
        setState(() {
          // Store full items for ID mapping
          _distributorItems = distributors;
          // Convert CommonDropdownItem to String list (using text field)
          _distributors = distributors.map((item) => item.text).toList();

          // Auto-select the first Distributor if available
          if (_distributors.isNotEmpty) {
            // If current selection is not in the new list, or no selection exists, select the first one
            if (_selectedDistributor == null ||
                !_distributors.contains(_selectedDistributor)) {
              _selectedDistributor = _distributors.first;
              print('✅ Auto-selected Distributor: ${_selectedDistributor}');
            }
          } else {
            // Clear selection if no distributors available
            _selectedDistributor = null;
          }
        });
        print('✅ Loaded ${_distributors.length} Distributors');
      }
    } catch (e) {
      print('Error loading distributors: $e');
      if (mounted) {
        setState(() {
          _distributors = [];
          _selectedDistributor = null;
        });
      }
    }
  }

  Future<void> _loadOrderData({int? fetchOrderId}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      SalesOrderApiItem? orderData;
      final orderId = fetchOrderId ??
          (widget.orderId != null ? int.tryParse(widget.orderId!) : null);

      // Fetch from API when we have an ID to get complete data (items, tax, fileUploadDetails)
      if (orderId != null && orderId > 0) {
        final salesRepository = getIt<SalesRepository>();
        orderData = await salesRepository.getSalesOrderById(orderId);
      }

      if (orderData != null && mounted) {
        _loadedOrderData = orderData;
        await _populateFormFromOrderData(orderData);
        // Update draft save enabled after order data is loaded (to check IsSalesRepEdit)
        _updateDraftSaveEnabled();
        setState(() {
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load order data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading order: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _populateFormFromOrderData(SalesOrderApiItem orderData) async {
    // Parse date
    if (orderData.date != null) {
      try {
        _contractDate = DateTime.parse(orderData.date!);
      } catch (e) {
        _contractDate = DateTime.now();
      }
    }

    // Parse delivery date
    if (orderData.deliveryDate != null) {
      try {
        _deliveryDate = DateTime.parse(orderData.deliveryDate!);
      } catch (e) {
        _deliveryDate = DateTime.now();
      }
    }

    // Parse required date (reqdDate) - calculate from items if not available
    if (_items.isNotEmpty) {
      _reqdDate = _items
          .map((item) => item.requiredDate)
          .reduce((a, b) => a.isBefore(b) ? a : b);
    } else {
      _reqdDate = null;
    }

    // Basic fields
    _soNumber = orderData.soNumber;
    _selectedType = orderData.typeText;
    _selectedCurrency = orderData.currencyText ?? orderData.currency ?? 'LKR';
    // Use customerId (as string) instead of customer name for _selectedCustomerCode
    // This ensures we can find the customer by ID when building save request
    _selectedCustomerCode = orderData.customerId?.toString();
    CustomerAddressController.text = orderData.cusAddress ?? '';
    _customerSearchController.text =
        orderData.customerName ?? orderData.customer ?? '';
    _selectedSalesRep = orderData.salesRepName ?? orderData.salesRep;
    _customerPOController.text = orderData.customerRef ?? '';
    _selectedUserGroup = orderData.divisionGroupName;
    _quotationNoController.text = orderData.refNo ?? '';
    _isBonusSO = orderData.isBonusSO ?? false;
    _exchangeRateController.text =
        orderData.exchangeRate?.toStringAsFixed(5) ?? '1.00000';
    _deliveryAddressController.text = orderData.deliveryAddress ?? '';

    // Check if order has been submitted
    // Check statusText if available, or check workflowStatus/soStatus
    if (orderData.statusText != null && orderData.statusText!.isNotEmpty) {
      final statusLower = orderData.statusText!.toLowerCase();
      _hasBeenSubmitted = statusLower.contains('submitted') ||
          statusLower.contains('pending') ||
          statusLower.contains('approved');
    } else {
      // If statusText is not available, check workflowStatus or soStatus
      // Non-zero workflowStatus or soStatus typically indicates submission
      _hasBeenSubmitted =
          (orderData.workflowStatus != null && orderData.workflowStatus! > 0) ||
              (orderData.soStatus != null && orderData.soStatus! > 0);
    }

    // Load distributor list and set selected distributor by ID
    if (orderData.distributerForId != null && orderData.customerId != null) {
      // Load distributors first, then match by ID
      await _loadDistributorAndSetSelection(
        orderData.customerId.toString(),
        orderData.distributerForId!,
      );
      // Reload workflow actions and privileges after distributor is set to use correct bizUnit
      await _loadWorkflowActions();
      await _loadUserPagePrivileges();
    } else if (orderData.customerId != null) {
      // Just load distributors without setting selection
      await _loadDistributors(orderData.customerId.toString());
      // Reload workflow actions and privileges after distributor is loaded
      await _loadWorkflowActions();
      await _loadUserPagePrivileges();
    } else {
      // Reload privileges even if no distributor
      await _loadUserPagePrivileges();
    }

    // Load Sales Rep list for edit mode so dropdown has options (customer already set above)
    if (orderData.customerId != null) {
      await _loadSalesReps(orderData.customerId.toString());
    }

    // Load customers to populate customer field correctly
    // This is important so the customer name is displayed instead of ID
    if (orderData.customerId != null) {
      await _loadCustomers();
      // After customers are loaded, update the customer search controller with the name
      if (mounted && Customers.isNotEmpty && _selectedCustomerCode != null) {
        try {
          final customer =
              Customers.firstWhere((c) => c.code == _selectedCustomerCode);
          _customerSearchController.text = customer.name;
          _isBonusEnabled = customer.bonusEnabled;
          print(
              '✅ Updated customer search controller with name: ${customer.name}, bonusEnabled: $_isBonusEnabled');
        } catch (e) {
          print(
              '⚠️ Customer not found in list for code: $_selectedCustomerCode');
          // If customer not found, try to use customerName from API
          if (orderData.customerName != null &&
              orderData.customerName!.isNotEmpty) {
            _customerSearchController.text = orderData.customerName!;
            print('✅ Using customerName from API: ${orderData.customerName}');
          }
        }
      }
    }

    // Parse items
    _items.clear();
    print('🔵 Parsing salesContractItems...');
    print(
        '   salesContractItems type: ${orderData.salesContractItems.runtimeType}');
    print(
        '   salesContractItems is null: ${orderData.salesContractItems == null}');

    if (orderData.salesContractItems != null &&
        orderData.salesContractItems is List) {
      final itemsList = orderData.salesContractItems as List;
      print('   Found ${itemsList.length} items in list');

      for (int i = 0; i < itemsList.length; i++) {
        final itemData = itemsList[i];
        print('   Processing item $i: ${itemData.runtimeType}');

        if (itemData is Map<String, dynamic>) {
          print('     Item data keys: ${itemData.keys.toList()}');
          if (itemData.isNotEmpty) {
            try {
              final parsedItem = _parseItemFromData(itemData);
              _items.add(parsedItem);
              print('     ✅ Successfully parsed item $i');
            } catch (e, stackTrace) {
              print('     ❌ Error parsing item $i: $e');
              print('     Stack trace: $stackTrace');
              print('     Item data: $itemData');
              // Skip this item and continue with others
            }
          } else {
            print('     ⚠️ Item $i is empty map, skipping');
          }
        } else {
          print(
              '     ⚠️ Item $i is not a Map: ${itemData.runtimeType}, skipping');
        }
      }
    } else {
      print('   ⚠️ salesContractItems is not a List or is null');
      if (orderData.salesContractItems != null) {
        print('     Type: ${orderData.salesContractItems.runtimeType}');
      }
    }

    print('   Total parsed items: ${_items.length}');

    // After parsing items, trigger bonus and discount calculation for each to populate calculated fields
    for (final item in _items) {
      final itemId = int.tryParse(item.product.id) ?? 0;
      if (itemId > 0) {
        // Run in background without awaiting to keep UI responsive
        _calculateAndApplyBonusForItem(item, itemId);
        _calculateAndApplyDiscountForItem(item, itemId);
      }
    }

    // If no items found, create a default empty item (will be populated from API when user searches)
    if (_items.isEmpty) {
      print('   ⚠️ No items found, creating default empty item');
      final emptyProduct = Product(
        id: '0',
        name: 'Item',
        manufacturer: 'N/A',
        rate: 0.0,
        mrp: null,
        uom: 'Unit',
        availableQty: 0,
      );
      _items.add(_LineItem.fromProduct(
        emptyProduct,
        itemDescription: '',
        rate: 0.0,
      ));
      print('   ✅ Created default empty item');
    }

    // Set SubTotal from totalAmount first (primary source)
    if (orderData.totalAmount != null && orderData.totalAmount! > 0) {
      _subTotalController.text = orderData.totalAmount!.toStringAsFixed(2);
      print('🔵 Set SubTotal from totalAmount: ${orderData.totalAmount}');
    }

    // Parse tax and charges from taxAndOtherChargesDetail using typeText
    if (orderData.taxAndOtherChargesDetail != null &&
        orderData.taxAndOtherChargesDetail is List) {
      _loadedPriceAdjustmentChargeId = null;
      _loadedGrandTotalChargeId = null;
      final charges = orderData.taxAndOtherChargesDetail as List;
      for (var charge in charges) {
        if (charge is Map<String, dynamic>) {
          final typeText = charge['typeText']?.toString() ?? '';
          final label = charge['label']?.toString() ?? '';
          final value = (charge['value'] ?? 0).toDouble();

          // Use typeText for exact matching (more reliable than label)
          // Skip SubTotal from charges if totalAmount is already set
          if (typeText == 'SubTotal' || typeText.toLowerCase() == 'subtotal') {
            // Only set from charges if totalAmount is not available
            if (orderData.totalAmount == null || orderData.totalAmount == 0) {
              _subTotalController.text =
                  value == 0.0 ? '' : value.toStringAsFixed(2);
            }
          } else if (typeText == 'Tax' ||
              typeText.toLowerCase() == 'tax' ||
              label.toLowerCase() == 'tax') {
            // Add tax row
            final chargeId = _parseChargeDetailId(charge['id'] ?? charge['Id']);
            final taxRow = _TaxChargeRow(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              rowType: 'tax',
              chargeDetailApiId: chargeId,
            );
            taxRow.valueController.text =
                value == 0.0 ? '' : value.toStringAsFixed(2);
            // Use typeText first (e.g., "VAT 18%"), then subTypeText, otherwise try to extract from label
            final chargeTypeText = charge['typeText']?.toString();
            final subTypeText = charge['subTypeText']?.toString();
            if (chargeTypeText != null &&
                chargeTypeText.isNotEmpty &&
                chargeTypeText.toLowerCase() != 'tax') {
              taxRow.selectedType = chargeTypeText;
            } else if (subTypeText != null && subTypeText.isNotEmpty) {
              taxRow.selectedType = subTypeText;
            } else {
              // Try to extract tax type from label
              if (label.contains('VAT') || label.contains('18%')) {
                taxRow.selectedType = 'VAT 18%';
              } else if (label.contains('GST') || label.contains('5%')) {
                taxRow.selectedType = 'GST 5%';
              }
            }
            _taxRows.add(taxRow);
          } else if (typeText == 'Discount' ||
              typeText.toLowerCase() == 'discount') {
            // Add discount row
            final chargeId = _parseChargeDetailId(charge['id'] ?? charge['Id']);
            final discountRow = _TaxChargeRow(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              rowType: 'discount',
              chargeDetailApiId: chargeId,
            );
            discountRow.valueController.text =
                value == 0.0 ? '' : value.toStringAsFixed(2);

            // Check if this is a custom discount
            final isCustom = charge['isCustom'] == true ||
                charge['isCustom'] == 1 ||
                charge['isCustomSelected'] == true ||
                charge['isCustomSelected'] == 1;
            final customPercentage = charge['customPercentage'];

            if (isCustom) {
              // Set selectedType to "Custom" if isCustom is true
              discountRow.selectedType = 'Custom';
              print(
                  '🔵 Discount isCustom=true, setting selectedType to "Custom"');

              // If customPercentage has a value, enable checkbox and set percentage
              if (customPercentage != null) {
                final percentageValue = (customPercentage is num)
                    ? customPercentage.toDouble()
                    : double.tryParse(customPercentage.toString()) ?? 0.0;
                if (percentageValue > 0) {
                  discountRow.isPercentageEnabled = true;
                  discountRow.percentageController.text =
                      percentageValue.toStringAsFixed(2);
                  print(
                      '🔵 Discount customPercentage=$percentageValue, enabling checkbox and setting percentage');
                }
              }
            } else {
              // Use subTypeText if available (for non-custom discounts)
              final subTypeText = charge['subTypeText']?.toString();
              if (subTypeText != null && subTypeText.isNotEmpty) {
                discountRow.selectedType = subTypeText;
              }
            }

            _discountRows.add(discountRow);
          } else if (typeText == 'OtherCharge' ||
              typeText.toLowerCase() == 'othercharge') {
            // Add other charge row
            final chargeId = _parseChargeDetailId(charge['id'] ?? charge['Id']);
            final otherChargeRow = _TaxChargeRow(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              rowType: 'otherCharge',
              chargeDetailApiId: chargeId,
            );
            otherChargeRow.valueController.text =
                value == 0.0 ? '' : value.toStringAsFixed(2);
            _otherChargeRows.add(otherChargeRow);
          } else if (typeText == 'PriceAdjustment' ||
              typeText.toLowerCase() == 'priceadjustment') {
            _loadedPriceAdjustmentChargeId =
                _parseChargeDetailId(charge['id'] ?? charge['Id']);
            _priceAdjustmentController.text =
                value == 0.0 ? '' : value.toStringAsFixed(2);
          } else if (typeText == 'GrandTotal' ||
              typeText.toLowerCase() == 'grandtotal') {
            _loadedGrandTotalChargeId =
                _parseChargeDetailId(charge['id'] ?? charge['Id']);
          }
          // Note: GrandTotal value is calculated, not stored in a controller
        }
      }
    } else {
      // Fallback to direct fields - calculate from items if available
      if (_items.isNotEmpty) {
        final calculatedSubTotal =
            _items.fold(0.0, (sum, item) => sum + item.amount);
        _subTotalController.text = calculatedSubTotal == 0.0
            ? ''
            : calculatedSubTotal.toStringAsFixed(2);
      } else {
        final subTotalValue = orderData.totalAmount ?? orderData.amount ?? 0.0;
        _subTotalController.text =
            subTotalValue == 0.0 ? '' : subTotalValue.toStringAsFixed(2);
      }
      // Note: Tax, discount, and other charges should be loaded from taxAndOtherChargesDetail
      // If not available, we can create default rows
      if (orderData.totalTax != null && orderData.totalTax! > 0) {
        final taxRow = _TaxChargeRow(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          rowType: 'tax',
        );
        taxRow.valueController.text = orderData.totalTax.toString();
        _taxRows.add(taxRow);
      }
      if (orderData.totalDiscount != null && orderData.totalDiscount! > 0) {
        final discountRow = _TaxChargeRow(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          rowType: 'discount',
        );
        discountRow.valueController.text = orderData.totalDiscount.toString();
        _discountRows.add(discountRow);
      }
      if (orderData.totalShipCharge != null && orderData.totalShipCharge! > 0) {
        final otherChargeRow = _TaxChargeRow(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          rowType: 'otherCharge',
        );
        otherChargeRow.valueController.text =
            orderData.totalShipCharge.toString();
        _otherChargeRows.add(otherChargeRow);
      }
      _priceAdjustmentController.text =
          (orderData.totalAdjust ?? 0.0).toString();
    }

    _updateTotals();
    if (mounted) {
      setState(() {});
    }
  }

  /// Parse an int from itemData using the first key that exists (API may use camelCase or PascalCase).
  int _parseIntFromItemData(Map<String, dynamic> itemData, List<String> keys) {
    for (final key in keys) {
      final v = itemData[key];
      if (v == null) continue;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final n = int.tryParse(v);
        if (n != null) return n;
      }
    }
    return 0;
  }

  _LineItem _parseItemFromData(Map<String, dynamic> itemData) {
    print('🔵 _parseItemFromData called with keys: ${itemData.keys.toList()}');

    // Validate itemData is not null or empty
    if (itemData.isEmpty) {
      print('❌ Item data is empty');
      throw Exception('Item data is empty');
    }

    // Use item description from data
    final itemDescription = itemData['ItemText']?.toString() ??
        itemData['itemText']?.toString() ??
        itemData['itemName']?.toString() ??
        itemData['itemDescription']?.toString() ??
        itemData['description']?.toString() ??
        '';

    // Safely parse rate - handle null and type conversion
    double rate = 0.0;
    try {
      final rateValue = itemData['UnitPrice'] ??
          itemData['unitPrice'] ??
          itemData['rate'] ??
          itemData['Rate'] ??
          itemData['price'] ??
          0.0;
      if (rateValue is num) {
        rate = rateValue.toDouble();
      } else if (rateValue is String) {
        rate = double.tryParse(rateValue) ?? 0.0;
      }
    } catch (e) {
      rate = 0.0;
    }

    // Safely parse MRP
    double? mrp;
    try {
      final mrpValue =
          itemData['mrp'] ?? itemData['maxRetailPrice'] ?? itemData['mrpValue'];
      if (mrpValue != null) {
        if (mrpValue is num) {
          final mrpDouble = mrpValue.toDouble();
          mrp = mrpDouble > 0 ? mrpDouble : null;
        } else if (mrpValue is String) {
          final mrpDouble = double.tryParse(mrpValue);
          mrp = mrpDouble != null && mrpDouble > 0 ? mrpDouble : null;
        }
      }
    } catch (e) {
      mrp = null;
    }

    // Safely parse discount (API may send Discount, DiscountAmount, discount, discountAmount)
    double discount = 0.0;
    try {
      final discountValue = itemData['discount'] ??
          itemData['discountAmount'] ??
          itemData['Discount'] ??
          itemData['DiscountAmount'] ??
          0.0;
      if (discountValue is num) {
        discount = discountValue.toDouble();
      } else if (discountValue is String) {
        discount = double.tryParse(discountValue) ?? 0.0;
      }
    } catch (e) {
      discount = 0.0;
    }

    // Safely parse per-line tax (API may send tax/Tax)
    double tax = 0.0;
    try {
      final taxValue = itemData['tax'] ?? itemData['Tax'] ?? 0.0;
      if (taxValue is num) {
        tax = taxValue.toDouble();
      } else if (taxValue is String) {
        tax = double.tryParse(taxValue) ?? 0.0;
      }
    } catch (e) {
      tax = 0.0;
    }

    // Get UOM - prioritize uomText (actual text) over uom (numeric ID)
    final uom = itemData['uomText']?.toString() ??
        (itemData['uom'] != null ? itemData['uom'].toString() : null);

    // Create default product from item data (no mock data, always use API data)
    // Ensure all required fields have safe defaults to prevent constructor errors
    // Get item ID - prioritize item/Item field (product/item ID) first, then fallback to id/Id (contract item ID)
    final itemIdValue = itemData['item'] ??
        itemData['Item'] ??
        itemData['itemId'] ??
        itemData['ItemId'] ??
        itemData['id'] ??
        itemData['Id'];
    final itemIdStr = (itemIdValue?.toString() ?? '0').trim();

    final itemName =
        itemDescription.isNotEmpty ? itemDescription.trim() : 'Item';

    final manufacturerName = (itemData['manufacturerName']?.toString() ??
            itemData['ManufacturerName']?.toString() ??
            'N/A')
        .trim();

    final safeRate = rate > 0 ? rate : 0.0;
    final safeMrp = mrp;
    final safeUom =
        (uom != null && uom.trim().isNotEmpty) ? uom.trim() : 'Unit';

    // Safely parse availableQty - handle both int and string types
    int safeAvailableQty = 0;
    try {
      final stockValue = itemData['stock'] ??
          itemData['availableQty'] ??
          itemData['Stock'] ??
          itemData['AvailableQty'] ??
          0;
      if (stockValue is int) {
        safeAvailableQty = stockValue;
      } else if (stockValue is String) {
        safeAvailableQty = int.tryParse(stockValue) ?? 0;
      } else if (stockValue is num) {
        safeAvailableQty = stockValue.toInt();
      }
    } catch (e) {
      safeAvailableQty = 0;
    }

    // Ensure all required fields are non-null and valid before creating Product
    // This prevents the "No constructor 'Product.' with matching arguments" error
    final finalItemId = itemIdStr.isNotEmpty ? itemIdStr : '0';
    final finalItemName = itemName.isNotEmpty ? itemName : 'Item';
    final finalManufacturer =
        manufacturerName.isNotEmpty ? manufacturerName : 'N/A';
    final finalUom = safeUom.isNotEmpty ? safeUom : 'Unit';

    // Debug logging before Product creation
    print('     🔵 Creating Product with:');
    print('        id: "$finalItemId" (type: ${finalItemId.runtimeType})');
    print(
        '        name: "$finalItemName" (type: ${finalItemName.runtimeType})');
    print(
        '        manufacturer: "$finalManufacturer" (type: ${finalManufacturer.runtimeType})');
    print('        rate: $safeRate (type: ${safeRate.runtimeType})');
    print('        mrp: $safeMrp (type: ${safeMrp.runtimeType})');
    print('        uom: "$finalUom" (type: ${finalUom.runtimeType})');
    print(
        '        availableQty: $safeAvailableQty (type: ${safeAvailableQty.runtimeType})');

    // Double-check all values are valid and non-null
    if (finalItemId.isEmpty) {
      throw Exception('Invalid Product data: id is empty');
    }
    if (finalItemName.isEmpty) {
      throw Exception('Invalid Product data: name is empty');
    }
    if (finalManufacturer.isEmpty) {
      throw Exception('Invalid Product data: manufacturer is empty');
    }
    if (finalUom.isEmpty) {
      throw Exception('Invalid Product data: uom is empty');
    }

    // Create Product with all validated fields - ensure all parameters are explicitly provided
    Product defaultProduct;
    try {
      defaultProduct = Product(
        id: finalItemId,
        name: finalItemName,
        manufacturer: finalManufacturer,
        rate: safeRate,
        mrp: safeMrp,
        uom: finalUom,
        availableQty: safeAvailableQty,
      );
      print('     ✅ Product created successfully');
    } catch (e, stackTrace) {
      print('     ❌ Error creating Product: $e');
      print('     Stack trace: $stackTrace');
      rethrow;
    }

    // Verify the product was created successfully
    if (defaultProduct.id.isEmpty ||
        defaultProduct.name.isEmpty ||
        defaultProduct.manufacturer.isEmpty ||
        defaultProduct.uom.isEmpty) {
      throw Exception(
          'Product created with invalid data: id="${defaultProduct.id}", name="${defaultProduct.name}", manufacturer="${defaultProduct.manufacturer}", uom="${defaultProduct.uom}"');
    }

    // Parse required date
    DateTime reqDate = DateTime.now();
    final reqdDateStr = itemData['reqdDate'] ??
        itemData['requiredDate'] ??
        itemData['deliveryDate'];
    if (reqdDateStr != null) {
      try {
        if (reqdDateStr is String) {
          reqDate = DateTime.parse(reqdDateStr);
        }
      } catch (e) {
        reqDate = DateTime.now();
      }
    }

    final remarks =
        itemData['remarks']?.toString() ?? itemData['Remarks']?.toString();
    // Parse dispatched quantity (backend requires quantity >= despatched). Try all common API key variants.
    final despatchedQty = itemData['despatchedQty'] ??
        itemData['DespatchedQty'] ??
        itemData['quantityDespatched'] ??
        itemData['QuantityDespatched'] ??
        itemData['dispatchedQuantity'] ??
        itemData['DispatchedQuantity'] ??
        itemData['Dispatched'];
    final lineItem = _LineItem.fromProduct(
      defaultProduct,
      reqDate: reqDate,
      qty:
          (itemData['quantity'] ?? itemData['Quantity'] ?? itemData['qty'] ?? 0)
              .toInt(),
      bonusQty: _parseIntFromItemData(itemData, [
        'bonusQty',
        'bonusQuantity',
        'BonusQuantity',
      ]),
      addlBonusQty: _parseIntFromItemData(itemData, [
        'addlBonus',
        'additionalBonusQuantity',
        'additionalQuantity',
        'AdditionalBonusQuantity',
        'AdditionalQuantity',
      ]),
      itemDescription: itemDescription,
      rate: rate, // Pass rate even if 0, so it can be loaded from API later
      mrp: mrp, // Pass MRP even if 0, so it can be loaded from API later
      discount: discount,
      taxAmount: tax,
      uom: uom,
      remarks: remarks,
    );
    if (despatchedQty != null) {
      final num? v = despatchedQty is int
          ? despatchedQty
          : despatchedQty is double
              ? despatchedQty.round()
              : int.tryParse(despatchedQty.toString());
      if (v != null && v >= 0) lineItem.despatchedQty = v.toInt();
    }

    // Contract line detail Id (each row has its own Id; do not use order Id for line items)
    final detailIdRaw = itemData['id'] ?? itemData['Id'] ?? itemData['detailId'] ?? itemData['DetailId'];
    if (detailIdRaw != null) {
      final num? did = detailIdRaw is int ? detailIdRaw : detailIdRaw is double ? detailIdRaw.round() : int.tryParse(detailIdRaw.toString());
      if (did != null && did > 0) lineItem.detailId = did.toInt();
    }

    // Set selectedUOM from itemData if available (before loading options)
    if (uom != null && uom.isNotEmpty) {
      lineItem.selectedUOM = uom;
      print('✅ Set UOM from itemData: $uom');
    }

    // Load UOM options if item ID is available
    final itemId = int.tryParse(defaultProduct.id) ?? 0;
    if (itemId > 0) {
      // Load UOM options asynchronously - pass existingUOM to preserve it if it matches
      _loadUOMForItem(lineItem, itemId, uom);
    } else if (uom != null && uom.isNotEmpty) {
      // If no itemId but we have UOM from data, set it directly
      lineItem.selectedUOM = uom;
      print('✅ Set UOM directly (no itemId): $uom');
    }

    // Load Tax options if item ID is available
    if (itemId > 0) {
      // Load Tax options asynchronously
      _loadTaxForItem(lineItem, itemId);
    }

    return lineItem;
  }

  Future<void> _loadUOMForItem(_LineItem item, int itemId,
      [String? existingUOM, VoidCallback? onChanged]) async {
    try {
      print(
          '🔵 Loading UOM for ItemId: $itemId, existingUOM: $existingUOM, current selectedUOM: ${item.selectedUOM}');
      final commonRepository = getIt<CommonRepository>();
      final uomList = await commonRepository.getUOMList(itemId: itemId);
      item.uomItems = uomList; // Store items with IDs
      item.uomOptions = uomList.map((uom) => uom.text).toList();
      // If existingUOM is provided and exists in options, use it; otherwise preserve current or auto-select first
      if (item.uomOptions.isNotEmpty) {
        if (existingUOM != null &&
            existingUOM.isNotEmpty &&
            item.uomOptions.contains(existingUOM)) {
          item.selectedUOM = existingUOM;
          print('✅ Using existing UOM: ${item.selectedUOM}');
        } else if (item.selectedUOM != null &&
            item.selectedUOM!.isNotEmpty &&
            item.uomOptions.contains(item.selectedUOM)) {
          // Preserve current selectedUOM if it exists in options
          print('✅ Preserving current UOM: ${item.selectedUOM}');
        } else if (item.selectedUOM != null && item.selectedUOM!.isNotEmpty) {
          // Try case-insensitive match if exact match not found
          final currentUOM = item.selectedUOM!;
          final matchedUOM = item.uomOptions.firstWhere(
            (uom) => uom.toLowerCase() == currentUOM.toLowerCase(),
            orElse: () => item.uomOptions.first,
          );
          item.selectedUOM = matchedUOM;
          print(
              '✅ Matched UOM (case-insensitive): ${item.selectedUOM} (was: $currentUOM)');
        } else {
          // Only auto-select first if no UOM is currently set
          item.selectedUOM = item.uomOptions.first;
          print('✅ Auto-selected first UOM: ${item.selectedUOM}');
        }
      } else if (existingUOM != null && existingUOM.isNotEmpty) {
        // If no options but we have existingUOM, keep it
        item.selectedUOM = existingUOM;
        print('✅ Keeping existing UOM (no options): ${item.selectedUOM}');
      }
      print('✅ Loaded ${item.uomOptions.length} UOM options');
      if (onChanged != null) {
        onChanged();
      } else if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Check if it's a connection error (expected and handled gracefully)
      final isConnectionError = e.toString().contains('Connection refused') ||
          e.toString().contains('connection error') ||
          e.toString().contains('SocketException');

      if (!isConnectionError) {
        // Only log non-connection errors (connection errors are already logged in API/repository layers)
        print('⚠️ Error loading UOM for item $itemId: $e');
      }

      item.uomOptions = [];
      // Preserve existing UOM even on error
      if (existingUOM != null && existingUOM.isNotEmpty) {
        item.selectedUOM = existingUOM;
        print(
            '✅ Preserved existing UOM due to API unavailability: ${item.selectedUOM}');
      }
      if (onChanged != null) {
        onChanged();
      } else if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadTaxForItem(_LineItem item, int itemId,
      [VoidCallback? onChanged]) async {
    try {
      print('🔵 Loading Tax for ItemId: $itemId');
      final commonRepository = getIt<CommonRepository>();
      final taxList = await commonRepository.getItemTaxList(itemId: itemId);
      item.taxOptions =
          taxList.map((tax) => tax.text).where((t) => t.isNotEmpty).toList();
      // Auto-select first tax if available and not already set
      if (item.taxOptions.isNotEmpty && item.selectedTax == null) {
        item.selectedTax = item.taxOptions.first;
        print('✅ Auto-selected Tax: ${item.selectedTax}');
      }
      print('✅ Loaded ${item.taxOptions.length} Tax options');
      if (onChanged != null) {
        onChanged();
      } else if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading Tax for item $itemId: $e');
      item.taxOptions = [];
      if (onChanged != null) {
        onChanged();
      } else if (mounted) {
        setState(() {});
      }
    }
  }

  /// Load item details (MRP, Rate, etc.) from GetItemDetail API
  Future<void> _loadItemDetail(_LineItem item, int itemId,
      [VoidCallback? onChanged]) async {
    try {
      // Get customer ID and date
      final customerId = _selectedCustomerCode != null
          ? int.tryParse(_selectedCustomerCode!)
          : null;

      if (customerId == null) {
        print(
            '⚠️ [GetItemDetail] Skipped — customer not selected. Select customer to print full API details for ItemId: $itemId');
        return;
      }

      // Format date as yyyy-MM-dd
      final dateStr = DateFormat('yyyy-MM-dd').format(_contractDate);

      print(
          '🔵 Loading Item Detail for ItemId: $itemId, Date: $dateStr, CustomerId: $customerId');

      final commonRepository = getIt<CommonRepository>();
      final itemDetail = await commonRepository.getItemDetail(
        itemId: itemId,
        date: dateStr,
        customerId: customerId,
      );

      // Complete API payload for this item (GetItemDetail)
      print('');
      print(
          '══════════════════════════════════════════════════════════════════════════════');
      print(
          '[GetItemDetail] COMPLETE API DETAILS — ItemId: $itemId, CustomerId: $customerId, Date: $dateStr');
      print(
          '══════════════════════════════════════════════════════════════════════════════');
      final raw = itemDetail.otherFields;
      if (raw != null && raw.isNotEmpty) {
        try {
          print(JsonEncoder.withIndent('  ').convert(raw));
        } catch (e) {
          print(
              '[GetItemDetail] (JSON encode failed: $e — printing key/value pairs)');
          for (final entry in raw.entries) {
            print('  ${entry.key}: ${entry.value}');
          }
        }
      } else {
        print('  (no otherFields on response)');
      }
      print(
          '──────────────────────────────────────────────────────────────────────────────');
      print('[GetItemDetail] Parsed model fields:');
      print('   item: ${itemDetail.item}');
      print('   itemText: ${itemDetail.itemText}');
      print('   manufacturerName: ${itemDetail.manufacturerName}');
      print('   rate: ${itemDetail.rate}');
      print('   retailRate: ${itemDetail.retailRate}');
      print('   mrp: ${itemDetail.mrp}');
      print('   unitPrice: ${itemDetail.unitPrice}');
      print('   uom: ${itemDetail.uom} | uomText: ${itemDetail.uomText}');
      print('   discount: ${itemDetail.discount}');
      print('   amount: ${itemDetail.amount}');
      print('   quantity: ${itemDetail.quantity}');
      print('   bonusQuantity: ${itemDetail.bonusQuantity}');
      print('   additionalBonusQuantity: ${itemDetail.additionalBonusQuantity}');
      print('   divisionGroup: ${itemDetail.divisionGroup}');
      print('   divisionGroupText: ${itemDetail.divisionGroupText}');
      print('   isFOC: ${itemDetail.isFOC}');
      print('   isRateUpdateConfirm: ${itemDetail.isRateUpdateConfirm}');
      print('   reqdDate: ${itemDetail.reqdDate}');
      print(
          '══════════════════════════════════════════════════════════════════════════════');
      print('');

      print('✅ Item Detail loaded:');
      print('   Rate: ${itemDetail.rate}');
      print('   RetailRate: ${itemDetail.retailRate}');
      print('   MRP: ${itemDetail.mrp}');
      print('   UnitPrice: ${itemDetail.unitPrice}');
      print('   UOM: ${itemDetail.uom} (${itemDetail.uomText})');
      print('   Discount: ${itemDetail.discount}');

      // Update item fields with item detail data
      // Map retailRate to Rate field (prefer retailRate over rate)
      if (itemDetail.retailRate != null && itemDetail.retailRate! > 0) {
        item.rateController.text = itemDetail.retailRate!.toStringAsFixed(2);
        print('✅ Updated Rate from RetailRate: ${item.rateController.text}');
      } else if (itemDetail.rate != null && itemDetail.rate! > 0) {
        item.rateController.text = itemDetail.rate!.toStringAsFixed(2);
        print('✅ Updated Rate: ${item.rateController.text}');
      }

      if (itemDetail.mrp != null && itemDetail.mrp! > 0) {
        item.mrpController.text = itemDetail.mrp!.toStringAsFixed(2);
        print('✅ Updated MRP: ${item.mrpController.text}');
      } else if (itemDetail.unitPrice != null && itemDetail.unitPrice! > 0) {
        // Fallback to unitPrice if MRP is not available
        item.mrpController.text = itemDetail.unitPrice!.toStringAsFixed(2);
        print('✅ Updated MRP from UnitPrice: ${item.mrpController.text}');
      }

      if (itemDetail.discount != null && itemDetail.discount! > 0) {
        item.discountController.text = itemDetail.discount!.toStringAsFixed(2);
        print('✅ Updated Discount: ${item.discountController.text}');
      } else if (itemDetail.discount != null) {
        item.discountController.text = itemDetail.discount!.toStringAsFixed(2);
      }

      // Update Bonus Qty and Addl. Bonus from Item Detail API when available
      if (itemDetail.bonusQuantity != null) {
        item.bonusQtyController.text = itemDetail.bonusQuantity!.toInt().toString();
        print('✅ Updated Bonus Qty from API: ${item.bonusQtyController.text}');
      }
      if (itemDetail.additionalBonusQuantity != null) {
        item.addlBonusQtyController.text =
            itemDetail.additionalBonusQuantity!.toInt().toString();
        print('✅ Updated Addl. Bonus from API: ${item.addlBonusQtyController.text}');
      }

      // Update UOM if available
      if (itemDetail.uomText != null && itemDetail.uomText!.isNotEmpty) {
        item.selectedUOM = itemDetail.uomText;
        print('✅ Updated UOM: ${item.selectedUOM}');
      }

      // Trigger recalculation
      if (onChanged != null) {
        onChanged();
      } else if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('⚠️ Error loading item detail for item $itemId: $e');
      // Don't block the UI if item detail fails - continue with existing values
    }
  }

  Future<void> _calculateAndApplyBonusForItem(
      _LineItem item, int itemId, [VoidCallback? onChanged]) async {
    try {
      // Match backend/client rules:
      // - If bonus is disabled for selected customer, do nothing.
      // - If this is a Bonus SO, do nothing.
      if (_isBonusEnabled == false || _isBonusSO == true) {
        item.calculatedBonusQuantity = 0;
        item.bonusQtyController.text = '0';
        item.validateBonusQty();
        if (onChanged != null) {
          onChanged();
        } else if (mounted) {
          setState(() {});
        }
        return;
      }

      final quantity = double.tryParse(item.qtyController.text.trim()) ?? 0.0;
      if (itemId <= 0 || quantity <= 0) {
        item.bonusQtyController.text = '0';
        item.calculatedBonusQuantity = 0;
        item.validateBonusQty();
        if (onChanged != null) {
          onChanged();
        } else if (mounted) {
          setState(() {});
        }
        return;
      }

      final salesRepository = getIt<SalesRepository>();
      final bonusListResponse = await salesRepository.getBonusList(itemId: itemId);
      if (bonusListResponse.items.isEmpty) {
        item.bonusQtyController.text = '0';
        item.calculatedBonusQuantity = 0;
        item.validateBonusQty();
        if (onChanged != null) {
          onChanged();
        } else if (mounted) {
          setState(() {});
        }
        return;
      }

      final List<(double maxVal, double bonusQty)> lumpSumSlabs = [];
      final List<(double maxVal, double bonusPct)> percentageSlabs = [];

      for (final bonus in bonusListResponse.items) {
        final bonusQty = bonus.bonusQty ?? 0;
        if (bonusQty <= 0) continue;

        if ((bonus.lumpsum ?? 0) == 1) {
          final minQty = bonus.qty ?? 0;
          if (minQty > 0) {
            lumpSumSlabs.add((minQty, bonusQty));
          }
          continue;
        }

        if (bonus.slabId == null) continue;
        final slabId = bonus.slabId!;

        bool hasSlab = _slabAvailabilityCache[slabId] ?? false;
        if (!_slabAvailabilityCache.containsKey(slabId)) {
          final slabResponse = await salesRepository.getBonusSlabList(slabId: slabId);
          hasSlab = slabResponse.items.isNotEmpty;
          _slabAvailabilityCache[slabId] = hasSlab;
        }

        if (hasSlab && bonus.maxVal != null) {
          percentageSlabs.add((bonus.maxVal!, bonusQty));
        }
      }

      lumpSumSlabs.sort((a, b) => b.$1.compareTo(a.$1));
      percentageSlabs.sort((a, b) => b.$1.compareTo(a.$1));

      double calculatedBonus = 0.0;
      if (lumpSumSlabs.isNotEmpty) {
        calculatedBonus = _calculateLumpSumBonusQuantity(lumpSumSlabs, quantity);
      } else if (percentageSlabs.isNotEmpty) {
        final matched = percentageSlabs.firstWhere(
          (slab) => quantity > slab.$1,
          orElse: () => (0.0, 0.0),
        );
        if (matched.$2 > 0) {
          calculatedBonus = (quantity * matched.$2) / 100.0;
        }
      }

      final bonusAsInt = calculatedBonus.floor();
      item.calculatedBonusQuantity = bonusAsInt;

      // Auto-fill with calculated value (but allow user to reduce later).
      item.bonusQtyController.text = bonusAsInt > 0 ? bonusAsInt.toString() : '0';
      item.validateBonusQty();

      if (onChanged != null) {
        onChanged();
      } else if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('⚠️ Bonus calculation failed for itemId=$itemId: $e');
    }
  }

  Future<void> _calculateAndApplyDiscountForItem(
      _LineItem item, int itemId, [VoidCallback? onChanged]) async {
    try {
      final quantity = double.tryParse(item.qtyController.text.trim()) ?? 0.0;
      final unitPrice = double.tryParse(item.rateController.text) ?? 0.0;
      if (itemId <= 0 || quantity <= 0 || unitPrice <= 0) {
        item.discountController.text = '0.00';
        if (onChanged != null) {
          onChanged();
        } else if (mounted) {
          setState(() {});
        }
        return;
      }

      final salesRepository = getIt<SalesRepository>();
      final discountResponse = await salesRepository.getDiscountList(itemId: itemId);
      if (discountResponse.items.isEmpty) {
        item.discountController.text = '0.00';
        if (onChanged != null) {
          onChanged();
        } else if (mounted) {
          setState(() {});
        }
        return;
      }

      double discountPercentage = 0.0;
      double bestMatchedMin = -1;
      double bestMatchedMax = -1;
      SalesDiscountItem? bestLumpSum;

      for (final discount in discountResponse.items) {
        final currentPct = (discount.bonusQty ?? 0.0);
        if (currentPct <= 0) continue;

        if ((discount.lumpsum ?? 0) == 1) {
          final threshold = discount.qty ?? 0.0;
          if (threshold <= quantity) {
            if (bestLumpSum == null || threshold > (bestLumpSum.qty ?? 0.0)) {
              bestLumpSum = discount;
            }
          }
          continue;
        }

        if (discount.slabId == null) continue;
        final slabId = discount.slabId!;
        List<SalesBonusSlabItem> slabItems = _discountSlabCache[slabId] ?? [];
        if (!_discountSlabCache.containsKey(slabId)) {
          final slabResponse = await salesRepository.getBonusSlabList(slabId: slabId);
          slabItems = slabResponse.items;
          _discountSlabCache[slabId] = slabItems;
        }

        if (slabItems.isNotEmpty) {
          final matchedSlab = slabItems.firstWhere(
            (slab) {
              final min = slab.minVal;
              final max = slab.maxVal;
              if (min == null || max == null) return false;
              return quantity >= min && quantity <= max;
            },
            orElse: () => SalesBonusSlabItem(),
          );
          if (matchedSlab.id != null &&
              matchedSlab.minVal != null &&
              matchedSlab.maxVal != null &&
              matchedSlab.id == slabId) {
            // Pick the most specific matched slab range:
            // higher minVal first, then higher maxVal.
            final min = matchedSlab.minVal!;
            final max = matchedSlab.maxVal!;
            final isBetter = min > bestMatchedMin ||
                (min == bestMatchedMin && max > bestMatchedMax);
            if (isBetter) {
              bestMatchedMin = min;
              bestMatchedMax = max;
              discountPercentage = currentPct / 100.0;
              print(
                  '✅ Discount slab(API) matched: item=$itemId slabId=$slabId range=$min-$max pct=${currentPct.toStringAsFixed(2)}');
            }
          }
        }

        // Fallback: when SlabList API is empty/unavailable, parse slabName range (e.g. "5-500")
        // from DiscountList response and use it for percentage matching.
        if (discountPercentage == 0.0) {
          final range = _parseSlabNameRange(discount.slabName);
          if (range != null) {
            final min = range.$1;
            final max = range.$2;
            if (quantity >= min && quantity <= max) {
              final isBetter = min > bestMatchedMin ||
                  (min == bestMatchedMin && max > bestMatchedMax);
              if (isBetter) {
                bestMatchedMin = min;
                bestMatchedMax = max;
                discountPercentage = currentPct / 100.0;
                print(
                    '✅ Discount slab(name) matched: item=$itemId slabId=$slabId range=$min-$max pct=${currentPct.toStringAsFixed(2)}');
              }
            }
          }
        }
      }

      if (discountPercentage == 0.0 && bestLumpSum != null) {
        discountPercentage = (bestLumpSum.bonusQty ?? 0.0) / 100.0;
        print(
            '✅ Discount lumpsum fallback: item=$itemId threshold=${bestLumpSum.qty} pct=${bestLumpSum.bonusQty}');
      }

      final amount = unitPrice * quantity;
      final discountAmount = amount * discountPercentage;
      item.discountController.text = discountAmount.toStringAsFixed(2);

      if (onChanged != null) {
        onChanged();
      } else if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('⚠️ Discount calculation failed for itemId=$itemId: $e');
    }
  }

  (double, double)? _parseSlabNameRange(String? slabName) {
    if (slabName == null) return null;
    final value = slabName.trim();
    if (value.isEmpty) return null;
    final parts = value.split('-');
    if (parts.length != 2) return null;
    final min = double.tryParse(parts[0].trim());
    final max = double.tryParse(parts[1].trim());
    if (min == null || max == null) return null;
    return (min, max);
  }

  double _calculateLumpSumBonusQuantity(
      List<(double maxVal, double bonusQty)> slabs, double quantity) {
    if (quantity <= 0 || slabs.isEmpty) return 0.0;

    // factor = floor(remaining / maxVal)
    // remaining = remaining % maxVal
    // total += factor * bonusQty
    double totalBonus = 0.0;
    double remainingQty = quantity;

    for (final slab in slabs) {
      final maxVal = slab.$1;
      final bonusQty = slab.$2;
      if (maxVal <= 0 || bonusQty <= 0) continue;

      final factor = (remainingQty / maxVal).floorToDouble();
      remainingQty = remainingQty % maxVal;
      totalBonus += factor * bonusQty;
    }

    return totalBonus;
  }

  Future<void> _loadTaxOptionsForTaxSection() async {
    try {
      print('🔵 Loading Tax Options for Tax Section');
      final commonRepository = getIt<CommonRepository>();
      final taxList = await commonRepository.getTaxListForTaxSection();
      if (mounted) {
        setState(() {
          final apiOptions = taxList
              .map((tax) => tax.text)
              .where((t) => t.isNotEmpty)
              .toList();
          // Always keep "Select" as first option, then API options
          _taxTypeOptions =
              apiOptions.isEmpty ? ['VAT 18%', 'GST 5%', 'No Tax'] : apiOptions;
        });
        print('✅ Loaded ${_taxTypeOptions.length} Tax options for Tax Section');
      }
    } catch (e) {
      print('Error loading Tax options for Tax Section: $e');
      if (mounted) {
        setState(() {
          // Keep default options on error (without "Select", it's added in dropdownOptions)
          _taxTypeOptions = ['VAT 18%', 'GST 5%', 'No Tax'];
        });
      }
    }
  }

  Future<void> _loadDiscountOptionsForTaxSection() async {
    try {
      print('🔵 Loading Discount Options for Tax Section');
      final commonRepository = getIt<CommonRepository>();
      final discountList =
          await commonRepository.getDiscountListForTaxSection();
      if (mounted) {
        setState(() {
          final apiOptions = discountList
              .map((discount) => discount.text)
              .where((t) => t.isNotEmpty)
              .toList();
          print('🔵 Loaded Discount options from API: $apiOptions');
          // Always keep API options (or defaults if empty), "Select" is added in dropdownOptions
          _discountTypeOptions =
              apiOptions.isEmpty ? ['Percentage', 'Fixed Amount'] : apiOptions;
        });
        print(
            '✅ Loaded ${_discountTypeOptions.length} Discount options for Tax Section');
      }
    } catch (e) {
      print('Error loading Discount options for Tax Section: $e');
      if (mounted) {
        setState(() {
          // Keep default options on error (without "Select", it's added in dropdownOptions)
          _discountTypeOptions = ['Percentage', 'Fixed Amount'];
        });
      }
    }
  }

  Future<void> _loadWorkflowActions() async {
    // Only skip if we're already loading (prevent duplicate calls)
    // But allow initial load even if flag is true from initialization
    if (_isLoadingWorkflowActions && _workflowActions.isNotEmpty) return;

    try {
      setState(() {
        _isLoadingWorkflowActions = true;
      });

      // Get userId and bizUnit from user data
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();
      final userId = user?.id ?? 43; // Default fallback

      // Get bizUnit from UserDetailStore or user prefs
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;

      int? bizUnitFromStore = userStore?.userDetail?.sbuId;
      int? bizUnitFromPrefs = user?.sbuId;
      int bizUnit = (bizUnitFromStore != null && bizUnitFromStore > 0)
          ? bizUnitFromStore
          : ((bizUnitFromPrefs != null && bizUnitFromPrefs > 0)
              ? bizUnitFromPrefs
              : 1);

      // For edit mode, use selected distributor ID as bizUnit
      if (_isEditMode &&
          _distributorItems.isNotEmpty &&
          _selectedDistributor != null) {
        // Find distributor ID from selected distributor name
        try {
          final distributorItem = _distributorItems.firstWhere(
            (item) => item.text == _selectedDistributor,
          );
          // Use distributor ID (id field) as bizUnit, fallback to value if id is 0
          bizUnit = (distributorItem.id > 0)
              ? distributorItem.id
              : (distributorItem.value > 0 ? distributorItem.value : bizUnit);
          print(
              '✅ Using Distributor ID as bizUnit: $bizUnit (Distributor: ${distributorItem.text})');
        } catch (e) {
          // If distributor not found, use default bizUnit
          print(
              '⚠️ Distributor not found in list, using default bizUnit: $bizUnit');
        }
      }

      final request = WorkflowGetAllActionsRequest(
        refId: null,
        applicationId: _isEditMode
            ? (widget.orderId != null
                ? int.tryParse(widget.orderId!)
                : widget.orderData?.id)
            : null,
        menuId: 1110,
        userId: userId,
        module: 5,
        bizUnit: bizUnit,
        url: _isEditMode
            ? '/sales/salescontract/edit'
            : '/sales/salescontract/create',
      );

      print('🔵 Loading Workflow Actions');
      final workflowRepository = getIt<WorkflowRepository>();
      final response = await workflowRepository.getAllActions(request);

      if (mounted) {
        setState(() {
          _workflowResponse = response;
          _workflowActions = response.processActionDetails;
          // Take the first button and check HasEdit
          if (_workflowActions.isNotEmpty) {
            final firstAction = _workflowActions.first;
            _isFirstButtonEnabled = firstAction.hasEdit;
          } else {
            _isFirstButtonEnabled = false;
          }
          _isLoadingWorkflowActions = false;
          // Update draft save enabled after workflow actions are loaded
          _updateDraftSaveEnabled();
        });
        print('✅ Loaded ${_workflowActions.length} Workflow Actions');
        if (_workflowActions.isNotEmpty) {
          print(
              '✅ First button enabled: $_isFirstButtonEnabled (HasEdit: ${_workflowActions.first.hasEdit})');
        }
      }
    } catch (e) {
      print('Error loading Workflow Actions: $e');
      if (mounted) {
        setState(() {
          _isLoadingWorkflowActions = false;
          _isFirstButtonEnabled = false; // Default to disabled on error
        });
      }
    }
  }

  Future<void> _loadUserPagePrivileges() async {
    // Allow reloads - don't block even if already loading
    // The setState will handle any race conditions

    try {
      setState(() {
        _isLoadingPrivileges = true;
      });

      // Get userId and bizUnit from user data
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();
      final userId = user?.id ?? 43; // Default fallback

      // Get bizUnit from UserDetailStore or user prefs
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;

      int? bizUnitFromStore = userStore?.userDetail?.sbuId;
      int? bizUnitFromPrefs = user?.sbuId;
      int bizUnit = (bizUnitFromStore != null && bizUnitFromStore > 0)
          ? bizUnitFromStore
          : ((bizUnitFromPrefs != null && bizUnitFromPrefs > 0)
              ? bizUnitFromPrefs
              : 1);

      // For edit mode, use selected distributor ID as bizUnit
      if (_isEditMode &&
          _distributorItems.isNotEmpty &&
          _selectedDistributor != null) {
        // Find distributor ID from selected distributor name
        try {
          final distributorItem = _distributorItems.firstWhere(
            (item) => item.text == _selectedDistributor,
          );
          // Use distributor ID (id field) as bizUnit, fallback to value if id is 0
          bizUnit = (distributorItem.id > 0)
              ? distributorItem.id
              : (distributorItem.value > 0 ? distributorItem.value : bizUnit);
          print(
              '✅ Using Distributor ID as bizUnit for privileges: $bizUnit (Distributor: ${distributorItem.text})');
        } catch (e) {
          // If distributor not found, use default bizUnit
          print(
              '⚠️ Distributor not found in list for privileges, using default bizUnit: $bizUnit');
        }
      }

      final request = WorkflowGetUserPagePrivilegesRequest(
        groupName: null,
        pageName: null,
        userId: userId,
        roleId: null,
        groupId: null,
        pageId: null,
        pageUrl: _isEditMode
            ? '/sales/salescontract/edit'
            : '/sales/salescontract/create',
        menuId: 1110,
        module: 5,
        hasRight: false,
        hierarchy: null,
        sectorId: null,
        tabName: null,
        subTabName: null,
        bizunit: bizUnit,
      );

      print('🔵 Loading User Page Privileges');
      final workflowRepository = getIt<WorkflowRepository>();
      final response = await workflowRepository.getUserPagePrivileges(request);

      if (mounted) {
        setState(() {
          _userPrivilegesResponse = response;
          _buttonPrivileges = response.buttonPrivileges;

          // Extract ButtonSave right
          final buttonSavePrivilege = _buttonPrivileges['ButtonSave'] ??
              _buttonPrivileges['buttonSave'];
          _hasButtonSaveRight = buttonSavePrivilege?.hasRight ?? false;

          // Extract Print right
          final printPrivilege =
              _buttonPrivileges['Print'] ?? _buttonPrivileges['print'];
          _hasPrintRight = printPrivilege?.hasRight ?? false;

          // Determine if Draft Save is enabled
          // Enable if ButtonSave has right = true OR (editing and IsSalesRepEdit = 1)
          _updateDraftSaveEnabled();

          _isLoadingPrivileges = false;
          _firstPrivilegeLoadCompleted = true;
        });
        print('✅ Loaded User Page Privileges');
        print('   ButtonSave HasRight: $_hasButtonSaveRight');
        print('   Print HasRight: $_hasPrintRight');
        print(
            '   Draft Save Enabled: $_isDraftSaveEnabled (ButtonSave: $_hasButtonSaveRight, IsSalesRepEdit: ${_loadedOrderData?.isSalesRepEdit})');
      }
    } catch (e) {
      print('Error loading User Page Privileges: $e');
      if (mounted) {
        setState(() {
          _isLoadingPrivileges = false;
          _hasButtonSaveRight = false;
          _hasPrintRight = false;
          _isDraftSaveEnabled = false;
          _firstPrivilegeLoadCompleted =
              true; // Mark as completed even on error
        });
      }
    }
  }

  void _updateDraftSaveEnabled() {
    // Enable Save button if:
    // 1. ButtonSave has right = true OR
    // 2. (Editing and IsSalesRepEdit = true) OR
    // 3. (Editing and order is not cancelled/closed/short closed) OR
    // 4. Any workflow action has hasEdit = true
    final isSalesRepEdit = _loadedOrderData?.isSalesRepEdit == true ||
        _loadedOrderData?.isSalesRepEdit == 1;
    final isOrderEditable = _loadedOrderData != null &&
        (_loadedOrderData!.isCancelled == 0 ||
            _loadedOrderData!.isCancelled == null) &&
        (_loadedOrderData!.isClosed == 0 ||
            _loadedOrderData!.isClosed == null) &&
        (_loadedOrderData!.isShortClosed == 0 ||
            _loadedOrderData!.isShortClosed == null);
    final hasAnyEditableAction =
        _workflowActions.any((action) => action.hasEdit == true);

    _isDraftSaveEnabled = _hasButtonSaveRight ||
        (_isEditMode && isSalesRepEdit) ||
        (_isEditMode && isOrderEditable) ||
        hasAnyEditableAction ||
        !_isEditMode; // Always enable in create mode

    print(
        '📝 Draft Save Enabled: $_isDraftSaveEnabled (ButtonSave: $_hasButtonSaveRight, IsSalesRepEdit: $isSalesRepEdit, EditMode: $_isEditMode, IsOrderEditable: $isOrderEditable, HasAnyEditableAction: $hasAnyEditableAction)');
  }

  /// True when order is approved: show Modify and Cancel in bottom bar instead of Save and Submit.
  bool get _isApprovedOrder {
    if (!_isEditMode || _loadedOrderData == null) return false;
    final statusLower = _loadedOrderData!.statusText?.toLowerCase() ?? '';
    if (statusLower.contains('approved')) return true;
    return _workflowActions
        .any((action) => action.transactionCompleted == true);
  }

  Future<void> _loadTaxComponentFormulas({required int id, int? userId}) async {
    if (_isLoadingTaxFormulas) return;

    try {
      setState(() {
        _isLoadingTaxFormulas = true;
      });

      print('🔵 Loading Tax Component Formulas for Id: $id');
      final commonRepository = getIt<CommonRepository>();
      final formulas = await commonRepository.getTaxComponentFormulas(
        id: id,
        userId: userId,
      );

      if (mounted) {
        setState(() {
          _taxComponentFormulas = formulas;
          _isLoadingTaxFormulas = false;
        });
        print(
            '✅ Loaded ${_taxComponentFormulas.length} Tax Component Formulas');
        // Recalculate totals with new formulas
        _updateTotals();
      }
    } catch (e) {
      print('Error loading Tax Component Formulas: $e');
      if (mounted) {
        setState(() {
          _isLoadingTaxFormulas = false;
          _taxComponentFormulas = [];
        });
      }
    }
  }

  /// Evaluate a formula string using current values
  /// Supports variables like: SubTotal, Tax, Discount, OtherCharge, PriceAdjustment, GrandTotal
  double _evaluateFormula(
    String? formula, {
    required double subTotal,
    required double tax,
    required double discount,
    required double otherCharge,
    required double priceAdjustment,
  }) {
    if (formula == null || formula.isEmpty) {
      return 0.0;
    }

    try {
      // Replace variables with actual values
      String expression = formula
          .replaceAll('SubTotal', subTotal.toString())
          .replaceAll('Tax', tax.toString())
          .replaceAll('Discount', discount.toString())
          .replaceAll('OtherCharge', otherCharge.toString())
          .replaceAll('PriceAdjustment', priceAdjustment.toString())
          .replaceAll(
              'GrandTotal',
              (subTotal + tax - discount + otherCharge + priceAdjustment)
                  .toString());

      // Simple evaluation (for basic arithmetic)
      // Note: For complex formulas, consider using a proper expression evaluator
      // This is a simplified version that handles basic operations
      expression = expression.replaceAll(' ', '');

      // Handle percentage calculations (e.g., "SubTotal * 0.18" for 18% tax)
      // Evaluate using a simple parser or use a library like math_expressions
      return _simpleEvaluate(expression);
    } catch (e) {
      print('Error evaluating formula "$formula": $e');
      return 0.0;
    }
  }

  /// Simple expression evaluator for basic arithmetic
  /// Supports: +, -, *, /, parentheses, and decimal numbers
  double _simpleEvaluate(String expression) {
    try {
      // Remove spaces
      expression = expression.replaceAll(' ', '');

      // Handle parentheses first
      while (expression.contains('(')) {
        final start = expression.lastIndexOf('(');
        final end = expression.indexOf(')', start);
        if (end == -1) break;

        final subExpr = expression.substring(start + 1, end);
        final result = _simpleEvaluate(subExpr);
        expression = expression.substring(0, start) +
            result.toString() +
            expression.substring(end + 1);
      }

      // Evaluate multiplication and division
      while (expression.contains('*') || expression.contains('/')) {
        final multIndex = expression.indexOf('*');
        final divIndex = expression.indexOf('/');
        final opIndex = (multIndex != -1 && divIndex != -1)
            ? (multIndex < divIndex ? multIndex : divIndex)
            : (multIndex != -1 ? multIndex : divIndex);

        if (opIndex == -1) break;

        final left = _extractNumber(expression, opIndex, -1);
        final right = _extractNumber(expression, opIndex, 1);
        final op = expression[opIndex];
        final result = op == '*' ? left * right : left / right;

        expression = expression.substring(0, opIndex - left.toString().length) +
            result.toString() +
            expression.substring(opIndex + right.toString().length + 1);
      }

      // Evaluate addition and subtraction
      double result = 0.0;
      String currentNumber = '';
      String lastOp = '+';

      for (int i = 0; i < expression.length; i++) {
        final char = expression[i];
        if (char == '+' || char == '-') {
          if (currentNumber.isNotEmpty) {
            final num = double.tryParse(currentNumber) ?? 0.0;
            result = lastOp == '+' ? result + num : result - num;
            currentNumber = '';
          }
          lastOp = char;
        } else {
          currentNumber += char;
        }
      }

      if (currentNumber.isNotEmpty) {
        final num = double.tryParse(currentNumber) ?? 0.0;
        result = lastOp == '+' ? result + num : result - num;
      }

      return result;
    } catch (e) {
      print('Error in simple evaluate: $e');
      return double.tryParse(expression) ?? 0.0;
    }
  }

  /// Extract a number from expression at given position
  double _extractNumber(String expression, int opIndex, int direction) {
    int start = opIndex;
    int end = opIndex;

    if (direction < 0) {
      // Extract left number
      start = opIndex - 1;
      while (start >= 0 &&
          (expression[start].contains(RegExp(r'[0-9.]')) ||
              expression[start] == '-')) {
        start--;
      }
      start++;
    } else {
      // Extract right number
      end = opIndex + 1;
      if (end < expression.length && expression[end] == '-') end++;
      while (end < expression.length &&
          expression[end].contains(RegExp(r'[0-9.]'))) {
        end++;
      }
    }

    return double.tryParse(expression.substring(start, end)) ?? 0.0;
  }

  /// Calculate value based on formula and charge type
  double _calculateChargeValue(
    TaxComponentResponse component, {
    required double subTotal,
    required double tax,
    required double discount,
    required double otherCharge,
    required double priceAdjustment,
  }) {
    final chargesType = ChargesType.fromInt(component.chargesType);

    // If formula is provided, use it
    if (component.formula != null && component.formula!.isNotEmpty) {
      return _evaluateFormula(
        component.formula,
        subTotal: subTotal,
        tax: tax,
        discount: discount,
        otherCharge: otherCharge,
        priceAdjustment: priceAdjustment,
      );
    }

    // Fallback to default calculation based on charge type
    switch (chargesType) {
      case ChargesType.subTotal:
        return subTotal;
      case ChargesType.tax:
        return tax;
      case ChargesType.discount:
        return discount;
      case ChargesType.otherCharge:
        return otherCharge;
      case ChargesType.priceAdjustment:
        return priceAdjustment;
      case ChargesType.grandTotal:
        return subTotal + tax - discount + otherCharge + priceAdjustment;
      case ChargesType.shippingCharge:
        return otherCharge;
      case ChargesType.dedAdvPaid:
        return 0.0; // Default for advance paid deduction
      default:
        return 0.0;
    }
  }

  /// Calculate charges using formulas from TaxComponent API
  void _calculateChargesUsingFormulas() {
    final subTotal = _subTotal;
    final currentTax = _totalTaxAmount;
    final currentDiscount = _totalDiscountAmount;
    final currentOtherCharge = _totalOtherChargeAmount;
    final priceAdjustment = _priceAdjustment;

    // Calculate each charge type using formulas
    for (final component in _taxComponentFormulas) {
      final chargesType = ChargesType.fromInt(component.chargesType);
      final calculatedValue = _calculateChargeValue(
        component,
        subTotal: subTotal,
        tax: currentTax,
        discount: currentDiscount,
        otherCharge: currentOtherCharge,
        priceAdjustment: priceAdjustment,
      );

      // Update the appropriate row or controller based on charge type
      switch (chargesType) {
        case ChargesType.tax:
          // Update tax rows if formula-based calculation is enabled
          // For now, we'll keep manual tax rows but can auto-calculate if needed
          break;
        case ChargesType.discount:
          // Update discount rows if formula-based calculation is enabled
          break;
        case ChargesType.otherCharge:
          // Update other charge rows if formula-based calculation is enabled
          break;
        case ChargesType.priceAdjustment:
          // Price adjustment is already in a controller, can be updated if needed
          break;
        case ChargesType.grandTotal:
          // Grand total is calculated, not stored separately
          break;
        default:
          break;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    CustomerAddressController.dispose();
    _customerSearchController.dispose();
    _notesController.dispose();
    _customerPOController.dispose();
    _quotationNoController.dispose();
    _exchangeRateController.dispose();
    _deliveryAddressController.dispose();
    _priceAdjustmentController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    _items.clear();
    for (final row in _taxRows) {
      row.dispose();
    }
    _taxRows.clear();
    for (final row in _discountRows) {
      row.dispose();
    }
    _discountRows.clear();
    for (final row in _otherChargeRows) {
      row.dispose();
    }
    _otherChargeRows.clear();
    super.dispose();
  }

  void _updateTotals() {
    // Auto-calculate SubTotal as sum of TotalAmount of all Order Items
    // SubTotal = Sum of (Quantity * Rate) for all items
    final calculatedSubTotal =
        _items.fold(0.0, (sum, item) => sum + item.totalAmount);
    // Always update SubTotal from items (no manual override)
    _subTotalController.text =
        calculatedSubTotal == 0.0 ? '' : calculatedSubTotal.toStringAsFixed(2);
    print(
        '🔵 Updated SubTotal: ${calculatedSubTotal.toStringAsFixed(2)} (Sum of ${_items.length} items)');

    // Update Reqd Date from items (earliest required date)
    if (_items.isNotEmpty) {
      _reqdDate = _items
          .map((item) => item.requiredDate)
          .reduce((a, b) => a.isBefore(b) ? a : b);
    } else {
      _reqdDate = null;
    }

    // Calculate tax, discount, and other charges using formulas if available
    if (_taxComponentFormulas.isNotEmpty) {
      _calculateChargesUsingFormulas();
    }

    setState(() {});
  }

  void _updateTotalsWithoutSetState() {
    // Auto-calculate SubTotal as sum of TotalAmount of all Order Items
    // SubTotal = Sum of (Quantity * Rate) for all items
    final calculatedSubTotal =
        _items.fold(0.0, (sum, item) => sum + item.totalAmount);
    // Always update SubTotal from items (no manual override)
    _subTotalController.text =
        calculatedSubTotal == 0.0 ? '' : calculatedSubTotal.toStringAsFixed(2);
    print(
        '🔵 Updated SubTotal: ${calculatedSubTotal.toStringAsFixed(2)} (Sum of ${_items.length} items)');

    // Update Reqd Date from items (earliest required date)
    if (_items.isNotEmpty) {
      _reqdDate = _items
          .map((item) => item.requiredDate)
          .reduce((a, b) => a.isBefore(b) ? a : b);
    } else {
      _reqdDate = null;
    }

    // Calculate tax, discount, and other charges using formulas if available
    if (_taxComponentFormulas.isNotEmpty) {
      _calculateChargesUsingFormulas();
    }
    // Note: This version does NOT call setState() to allow caller to control when rebuild happens
  }

  double get _totalTaxAmount {
    return _taxRows.fold(0.0, (sum, row) => sum + row.value);
  }

  double get _totalDiscountAmount {
    return _discountRows.fold(0.0, (sum, row) => sum + row.value);
  }

  double get _totalOtherChargeAmount {
    return _otherChargeRows.fold(0.0, (sum, row) => sum + row.value);
  }

  double _calculateGrandTotal() {
    // Use formula-based calculation if available
    if (_taxComponentFormulas.isNotEmpty) {
      final grandTotalFormula = _taxComponentFormulas.firstWhere(
        (f) => ChargesType.fromInt(f.chargesType) == ChargesType.grandTotal,
        orElse: () =>
            TaxComponentResponse(id: 0, chargesType: 6), // Default GrandTotal
      );

      if (grandTotalFormula.formula != null &&
          grandTotalFormula.formula!.isNotEmpty) {
        return _evaluateFormula(
          grandTotalFormula.formula,
          subTotal: _subTotal,
          tax: _totalTaxAmount,
          discount: _totalDiscountAmount,
          otherCharge: _totalOtherChargeAmount,
          priceAdjustment: _priceAdjustment,
        );
      }
    }

    // Fallback to default calculation
    return _subTotal +
        _totalTaxAmount -
        _totalDiscountAmount +
        _totalOtherChargeAmount +
        _priceAdjustment;
  }

  void _loadEditModeData(String id) {
    // This method is legacy - data should be loaded from API via _loadOrderData or _populateFormFromOrderData
    // Clear items - they will be populated from API
    _items.clear();
    // Load customers once when editing order
    _loadCustomers();
    setState(() {});
  }

  void _loadNewModeData() {
    _contractDate = DateTime.now();
    _deliveryDate = DateTime.now();
    _reqdDate = null; // Will be calculated from items when added
    _soNumber = null; // Auto-generated
    _selectedType = null;
    _selectedCurrency = null; // Empty by default
    _selectedCustomerCode = null;
    CustomerAddressController.text = '';
    _selectedDistributor = null;
    _selectedSalesRep = null;
    // Load customers once when creating new order
    _loadCustomers();
    _items
        .clear(); // Start with empty items - user will add items via API search
    _notesController.clear();
    _customerPOController.clear();
    _quotationNoController.clear();
    _exchangeRateController.clear(); // Empty by default
    _deliveryAddressController.clear();
    _selectedUserGroup = null;
    _isBonusSO = false;
    _taxRows.clear();
    _discountRows.clear();
    _otherChargeRows.clear();
    _updateTotals();
    setState(() {});
  }

  Customer? get _selectedCustomer {
    if (_selectedCustomerCode == null || Customers.isEmpty) return null;
    try {
      return Customers.firstWhere((c) => c.code == _selectedCustomerCode);
    } catch (e) {
      return null;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd-MMM-yyyy').format(date);
  }

  String _formatCurrency(double value) {
    // Format with comma separators for thousands
    final s = value.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '';
    final buf = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      buf.write(intPart[i]);
      count++;
      if (i > 0 && ((count == 3) || (count > 3 && (count - 3) % 2 == 0))) {
        buf.write(',');
      }
    }
    final formattedInt = buf.toString().split('').reversed.join();
    return decPart.isNotEmpty ? '$formattedInt.$decPart' : formattedInt;
  }

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime initialDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final DateTime first = DateTime(2000);
    final DateTime last = DateTime(2100);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: first,
      lastDate: last,
      helpText: 'Select Date',
    );
    if (picked != null) {
      onPicked(picked);
      setState(() {});
    }
  }

  Color _statusBackgroundColor() {
    return _isEditMode ? const Color(0xFFDCFCE7) : const Color(0xFFE5E7EB);
  }

  Color _statusTextColor() {
    return _isEditMode ? const Color(0xFF16A34A) : const Color(0xFF4B5563);
  }

  String _statusText() {
    return _isEditMode ? 'Approved' : 'Draft';
  }

  @override
  Widget build(BuildContext context) {
// Tablet vs Mobile responsive: width breakpoint ~ 800
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 800;
        const Color tealGreen = Color(0xFF4db1b3);
        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            backgroundColor: tealGreen,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'Back',
            ),
            titleSpacing: 0,
            title: Text(
              _isEditMode ? 'Edit Sales Order' : 'New Sales Order',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: isTablet ? 20 : 18,
                letterSpacing: -0.5,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            foregroundColor: Colors.white,
            actions: _isEditMode
                ? [
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isActionsMenuOpen = !_isActionsMenuOpen;
                        });
                      },
                      tooltip: 'More options',
                    ),
                  ]
                : [],
          ),
          body: Stack(
            children: [
              SafeArea(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          // Scrollable content
                          Expanded(
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                inputDecorationTheme: Theme.of(context)
                                    .inputDecorationTheme
                                    .copyWith(
                                      filled: true,
                                      fillColor: Colors.grey.withOpacity(0.05),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF4db1b3), width: 2),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: isTablet ? 16 : 14,
                                        vertical: isTablet ? 16 : 14,
                                      ),
                                    ),
                              ),
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                padding: EdgeInsets.fromLTRB(
                                  isTablet ? 16 : 12,
                                  12,
                                  isTablet ? 16 : 12,
                                  16,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 800),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildHeaderCard(isTablet: isTablet),
                                        const SizedBox(height: 14),
                                        _buildItemsCard(isTablet: isTablet),
                                        const SizedBox(height: 14),
                                        _buildTaxSection(isTablet: isTablet),
                                        const SizedBox(height: 14),
                                        _buildAttachmentsSection(
                                            isTablet: isTablet),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Fixed bottom bar with buttons
                          _buildBottomActionBar(isTablet: isTablet),
                        ],
                      ),
              ),
              // Actions menu overlay
              if (_isEditMode) _buildActionsMenuOverlay(isTablet: isTablet),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard({required bool isTablet}) {
    final border = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(16),
    );

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Collapsible Header
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isOrderInfoExpanded = !_isOrderInfoExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sales Order Details',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      Icon(
                        _isOrderInfoExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.grey.shade600,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Order Information Content (shown when expanded)
            if (_isOrderInfoExpanded) ...[
              const SizedBox(height: 20),
              // Form layout with two rows as per image
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  return isWide
                      ? Column(
                          children: [
                            // Top Row: Customer, SO Number, Date
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildTopRowField1(isTablet)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildTopRowField2(isTablet)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildTopRowField3(isTablet)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Bottom Row: Customer Address, Delivery Date, Sales Rep, Distributor For
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: _buildBottomRowField1(isTablet)),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: _buildBottomRowField2(isTablet)),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: _buildBottomRowField3(isTablet)),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: _buildBottomRowField4(isTablet)),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            // Top Row fields
                            _buildTopRowField1(isTablet),
                            const SizedBox(height: 20),
                            _buildTopRowField2(isTablet),
                            const SizedBox(height: 20),
                            _buildTopRowField3(isTablet),
                            const SizedBox(height: 20),
                            // Bottom Row fields
                            _buildBottomRowField1(isTablet),
                            const SizedBox(height: 20),
                            _buildBottomRowField2(isTablet),
                            const SizedBox(height: 20),
                            _buildBottomRowField3(isTablet),
                            const SizedBox(height: 20),
                            _buildBottomRowField4(isTablet),
                          ],
                        );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Top Row Field 1: Customer
  Widget _buildTopRowField1(bool isTablet) {
    return _LabeledField(
      label: 'Customer',
      child: _SearchableCustomerField(
        controller: _customerSearchController,
        selectedCustomerCode: _selectedCustomerCode,
        allCustomers: Customers, // Pass all loaded customers
        onCustomerSelected: (customer) {
          setState(() {
            _selectedCustomerCode = customer.code;
            CustomerAddressController.text = customer.address;
            _isBonusEnabled = customer.bonusEnabled;
          });
          // Load Sales Rep and Distributor when customer is selected
          _loadSalesReps(customer.code);
          _loadDistributors(customer.code);
        },
        onCustomerCleared: () {
          setState(() {
            _selectedCustomerCode = null;
            CustomerAddressController.clear();
            _isBonusEnabled = false;
          });
        },
      ),
    );
  }

  // Top Row Field 2: SO Number
  Widget _buildTopRowField2(bool isTablet) {
    return _LabeledField(
      label: 'SO Number',
      child: _TextField(
        label: '',
        controller: TextEditingController(
          text: _soNumber ?? '[NEW]',
        ),
        enabled: false,
        hintText: '[NEW]',
      ),
    );
  }

  // Top Row Field 3: Date
  Widget _buildTopRowField3(bool isTablet) {
    return _LabeledField(
      label: 'Date',
      child: _DateField(
        label: '',
        value: _contractDate,
        onTap: () => _pickDate(
          context: context,
          initialDate: _contractDate,
          onPicked: (d) => setState(() => _contractDate = d),
        ),
      ),
    );
  }

  // Bottom Row Field 1: Customer Address
  Widget _buildBottomRowField1(bool isTablet) {
    final border = OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(10),
    );

    return _LabeledField(
      label: 'Customer Address',
      child: TextField(
        controller: CustomerAddressController,
        readOnly: true,
        maxLines: 3,
        style: GoogleFonts.inter(
          fontSize: isTablet ? 15 : 14,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF111827),
        ),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 16 : 14,
            vertical: isTablet ? 16 : 14,
          ),
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
          disabledBorder: border,
          errorBorder: border,
        ),
      ),
    );
  }

  // Bottom Row Field 2: Delivery Date
  Widget _buildBottomRowField2(bool isTablet) {
    return _LabeledField(
      label: 'Delivery Date',
      child: _DateField(
        label: '',
        value: _deliveryDate,
        onTap: () => _pickDate(
          context: context,
          initialDate: _deliveryDate,
          onPicked: (d) => setState(() => _deliveryDate = d),
        ),
      ),
    );
  }

  // Bottom Row Field 5: Reqd Date (Readonly)
  Widget _buildBottomRowField5(bool isTablet) {
    return _LabeledField(
      label: 'Reqd Date',
      child: _ReadonlyDateField(
        value: _reqdDate,
      ),
    );
  }

  // Bottom Row Field 3: Sales Rep
  Widget _buildBottomRowField3(bool isTablet) {
    return _LabeledField(
      label: 'Sales Rep',
      child: _DropdownField<String>(
        label: '',
        value: _selectedSalesRep,
        hint: '',
        items: [
          for (final s in _salesReps)
            DropdownMenuItem(value: s, child: Text(s)),
        ],
        onChanged: (v) => setState(() => _selectedSalesRep = v),
      ),
    );
  }

  // Bottom Row Field 4: Distributor For
  Widget _buildBottomRowField4(bool isTablet) {
    return _LabeledField(
      label: 'Distributer For',
      child: _DropdownField<String>(
        label: '',
        value: _selectedDistributor,
        hint: '',
        items: [
          for (final d in _distributors)
            DropdownMenuItem(value: d, child: Text(d)),
        ],
        onChanged: (v) {
          setState(() => _selectedDistributor = v);
          // Reload workflow actions and privileges when distributor changes in edit mode
          if (_isEditMode) {
            _loadWorkflowActions();
            _loadUserPagePrivileges();
          }
        },
      ),
    );
  }

  Widget _buildItemsCard({required bool isTablet}) {
    const Color tealGreen = Color(0xFF4db1b3);
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section Title with Add Item Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Items',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      for (final it in _items) {
                        it.expanded = false;
                      }
                      // Create empty item - user will search and select from API
                      final emptyProduct = Product(
                        id: '0',
                        name: 'Item',
                        manufacturer: 'N/A',
                        rate: 0.0,
                        uom: 'Unit',
                        availableQty: 0,
                      );
                      _items.add(
                        _LineItem.fromProduct(
                          emptyProduct,
                          itemDescription: '',
                          rate: 0.0,
                        ),
                      );
                      _updateTotals();
                    });
                  },
                  icon: Icon(Icons.add, size: 18, color: tealGreen),
                  label: Text(
                    'Add Item',
                    style: GoogleFonts.inter(
                      color: tealGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Items List
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No items added. Click "Add Item" to begin.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < _items.length; i++) ...[
                    _ItemCard(
                      index: i,
                      totalCount: _items.length,
                      item: _items[i],
                      isEditMode: _isEditMode,
                      onRemove: () {
                        setState(() {
                          _items.removeAt(i);
                        });
                      },
                      onChanged: () {
                        setState(() {
                          _updateTotals();
                        });
                      },
                      onToggle: () {
                        setState(() {
                          final wasExpanded = _items[i].expanded;
                          for (final it in _items) {
                            it.expanded = false;
                          }
                          _items[i].expanded = !wasExpanded;
                        });
                      },
                      formatCurrency: _formatCurrency,
                      loadUOMForItem: _loadUOMForItem,
                      loadTaxForItem: _loadTaxForItem,
                      loadItemDetail: _loadItemDetail,
                      calculateBonusForItem: _calculateAndApplyBonusForItem,
                      calculateDiscountForItem: _calculateAndApplyDiscountForItem,
                      formatDate: _formatDate,
                      getDistributorId: () {
                        // Get distributor ID - use selected distributor or fallback to bizUnit
                        int distributorId;

                        // Get bizUnit from user store as fallback
                        int bizUnit = 1;
                        try {
                          final UserDetailStore? userStore =
                              getIt.isRegistered<UserDetailStore>()
                                  ? getIt<UserDetailStore>()
                                  : null;

                          int? bizUnitFromStore = userStore?.userDetail?.sbuId;
                          bizUnit =
                              (bizUnitFromStore != null && bizUnitFromStore > 0)
                                  ? bizUnitFromStore
                                  : 1;
                        } catch (e) {
                          print('⚠️ Error getting bizUnit, using default: $e');
                        }

                        // Default to bizUnit
                        distributorId = bizUnit;

                        // If distributor is selected, use its ID
                        if (_selectedDistributor != null &&
                            _distributorItems.isNotEmpty) {
                          try {
                            final distributorItem =
                                _distributorItems.firstWhere(
                              (item) => item.text == _selectedDistributor,
                            );
                            distributorId = distributorItem.id;
                            print(
                                '✅ Using selected Distributor ID: $distributorId (Distributor: ${distributorItem.text})');
                          } catch (e) {
                            // Distributor not found, use bizUnit as fallback
                            print(
                                '⚠️ Selected distributor not found in list, using bizUnit: $bizUnit');
                          }
                        } else {
                          print(
                              '⚠️ No distributor selected, using bizUnit: $bizUnit');
                        }

                        return distributorId;
                      },
                    ),
                    if (i != _items.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxSection({required bool isTablet}) {
    const Color tealGreen = Color(0xFF4db1b3);
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Collapsible Header
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isTaxSectionExpanded = !_isTaxSectionExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tax',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      Icon(
                        _isTaxSectionExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.grey.shade600,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Tax Table Content (shown when expanded)
            if (_isTaxSectionExpanded) ...[
              const SizedBox(height: 20),
              // Table Rows - Auto-sizing based on content
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    // Sub Total Row
                    _buildTaxTableRowWithController(
                      label: 'Sub Total',
                      controller: _subTotalController,
                      isTablet: isTablet,
                    ),
                    Divider(height: 1, color: Colors.grey.shade200, indent: 48),
                    // Tax Rows (shown in create mode OR edit mode with Draft status)
                    if (!_isEditMode ||
                        (_isEditMode && _loadedOrderData?.status == 0)) ...[
                      for (int i = 0; i < _taxRows.length; i++) ...[
                        _buildTaxTableRowWithModel(
                          row: _taxRows[i],
                          index: i,
                          rowType: 'tax',
                          hasDeleteButton: true,
                          isTablet: isTablet,
                        ),
                        Divider(
                            height: 1, color: Colors.grey.shade200, indent: 48),
                      ],
                      // Add Tax Button Row (only in create mode or edit mode with Draft status)
                      const SizedBox(height: 4),
                      _buildAddButtonRow(
                        label: 'Tax',
                        onAdd: () {
                          setState(() {
                            _taxRows.add(_TaxChargeRow(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              rowType: 'tax',
                            ));
                          });
                        },
                        isTablet: isTablet,
                      ),
                      const SizedBox(height: 4),
                    ],
                    // Discount Rows
                    if (_discountRows.isNotEmpty || !_isEditMode) ...[
                      Divider(
                          height: 1,
                          color: Colors.grey.shade200,
                          indent: 48,
                          thickness: 1.5),
                      const SizedBox(height: 4),
                    ],
                    for (int i = 0; i < _discountRows.length; i++) ...[
                      _buildTaxTableRowWithModel(
                        row: _discountRows[i],
                        index: i,
                        rowType: 'discount',
                        hasDeleteButton: true,
                        isTablet: isTablet,
                      ),
                      Divider(
                          height: 1, color: Colors.grey.shade200, indent: 48),
                    ],
                    // Add Discount Button Row (available in both create and edit mode)
                    const SizedBox(height: 4),
                    _buildAddButtonRow(
                      label: 'Discount',
                      onAdd: () {
                        setState(() {
                          _discountRows.add(_TaxChargeRow(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            rowType: 'discount',
                          ));
                        });
                      },
                      isTablet: isTablet,
                    ),
                    const SizedBox(height: 4),
                    // Other Charge Rows
                    if (_otherChargeRows.isNotEmpty || !_isEditMode) ...[
                      Divider(
                          height: 1,
                          color: Colors.grey.shade200,
                          indent: 48,
                          thickness: 1.5),
                      const SizedBox(height: 4),
                    ],
                    for (int i = 0; i < _otherChargeRows.length; i++) ...[
                      _buildTaxTableRowWithModel(
                        row: _otherChargeRows[i],
                        index: i,
                        rowType: 'otherCharge',
                        hasDeleteButton: true,
                        isTablet: isTablet,
                      ),
                      Divider(
                          height: 1, color: Colors.grey.shade200, indent: 48),
                    ],
                    // Add Other Charge Button Row (available in both create and edit mode)
                    const SizedBox(height: 4),
                    _buildAddButtonRow(
                      label: 'Other Charge',
                      onAdd: () {
                        setState(() {
                          _otherChargeRows.add(_TaxChargeRow(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            rowType: 'otherCharge',
                          ));
                        });
                      },
                      isTablet: isTablet,
                    ),
                    const SizedBox(height: 4),
                    // Price Adjustment Row
                    Divider(
                        height: 1,
                        color: Colors.grey.shade200,
                        indent: 48,
                        thickness: 1.5),
                    const SizedBox(height: 4),
                    _buildTaxTableRowWithController(
                      label: 'Price Adjustment',
                      controller: _priceAdjustmentController,
                      isTablet: isTablet,
                      enabled: true, // Enable Price Adjustment field
                    ),
                    const SizedBox(height: 4),
                    Divider(
                        height: 2, color: Colors.grey.shade300, thickness: 2),
                    const SizedBox(height: 8),
                    // Grand Total Row
                    Builder(
                      builder: (context) {
                        const Color tealGreen = Color(0xFF4db1b3);
                        return Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 16 : 12,
                              vertical: isTablet ? 16 : 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(width: isTablet ? 40 : 36),
                              SizedBox(width: isTablet ? 12 : 8),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Grand Total',
                                  style: GoogleFonts.inter(
                                    fontSize: isTablet ? 16 : 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade900,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              Expanded(flex: 2, child: const SizedBox.shrink()),
                              SizedBox(width: isTablet ? 12 : 8),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _formatCurrency(_calculateGrandTotal()),
                                  textAlign: TextAlign.end,
                                  style: GoogleFonts.inter(
                                    fontSize: isTablet ? 18 : 16,
                                    fontWeight: FontWeight.w900,
                                    color: tealGreen,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddButtonRow({
    required String label,
    required VoidCallback onAdd,
    required bool isTablet,
  }) {
    const Color tealGreen = Color(0xFF4db1b3);
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 16 : 12, vertical: isTablet ? 14 : 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: isTablet ? 32 : 28,
              height: isTablet ? 32 : 28,
              decoration: BoxDecoration(
                color: tealGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: tealGreen.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.add,
                  color: Colors.white, size: isTablet ? 20 : 18),
            ),
            SizedBox(width: isTablet ? 12 : 8),
            Expanded(
              flex: 2,
              child: Text(
                'Add $label',
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 15 : 14,
                  fontWeight: FontWeight.w600,
                  color: tealGreen,
                ),
              ),
            ),
            Expanded(flex: 2, child: const SizedBox.shrink()),
            Expanded(flex: 1, child: const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxTableRowWithModel({
    required _TaxChargeRow row,
    required int index,
    required String rowType,
    required bool hasDeleteButton,
    required bool isTablet,
  }) {
    const Color tealGreen = Color(0xFF4db1b3);
    final hasDropdown = rowType == 'tax' || rowType == 'discount';
    // Get dropdown options, always include "Select" as first option
    final List<String> dropdownOptions = [
      'Select',
      ...(rowType == 'tax' ? _taxTypeOptions : _discountTypeOptions)
          .where((option) => option != 'Select')
          .toList()
    ];

    // Debug: Log the condition check
    if (rowType == 'discount') {
      print(
          '🔵 _buildTaxTableRowWithModel - Discount row: selectedType="${row.selectedType}", isCustom: ${row.selectedType != null && row.selectedType!.trim().toLowerCase() == 'custom'}');
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12, vertical: isTablet ? 14 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          if (isMobile) {
            // Mobile: Stack layout
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: hasDeleteButton
                          ? IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.remove,
                                    color: Colors.white, size: 16),
                              ),
                              onPressed: () {
                                setState(() {
                                  if (rowType == 'tax') {
                                    row.dispose();
                                    _taxRows.removeAt(index);
                                  } else if (rowType == 'discount') {
                                    row.dispose();
                                    _discountRows.removeAt(index);
                                  } else if (rowType == 'otherCharge') {
                                    row.dispose();
                                    _otherChargeRows.removeAt(index);
                                  }
                                  _updateTotals();
                                });
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rowType == 'tax'
                            ? 'Tax'
                            : (rowType == 'discount'
                                ? 'Discount'
                                : 'Other Charge'),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (hasDropdown)
                  Padding(
                    padding: const EdgeInsets.only(left: 44),
                    child: PopupMenuButton<String>(
                      initialValue: row.selectedType,
                      // Open upward to avoid overlapping with bottom buttons
                      position: PopupMenuPosition.over,
                      offset: const Offset(0, -4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      onSelected: (value) {
                        // Preserve scroll position synchronously before any async operations
                        final scrollOffset = _scrollController.hasClients
                            ? _scrollController.offset
                            : 0.0;
                        // Set flag to prevent automatic focus restoration
                        _preventingFocusRestoration = true;
                        // Prevent focus from moving to any field - use primaryFocus to clear focus
                        final currentFocus = FocusScope.of(context);
                        final primaryFocus = FocusManager.instance.primaryFocus;
                        if (primaryFocus != null) {
                          primaryFocus.unfocus();
                        }
                        currentFocus.unfocus();
                        // Also prevent any automatic focus restoration
                        WidgetsBinding.instance.focusManager.primaryFocus
                            ?.unfocus();
                        // Update the row data first without setState
                        row.selectedType = (value == 'Select') ? null : value;
                        print(
                            '🔵 Discount dropdown selected (Mobile): "$value", final selectedType: "${row.selectedType}"');
                        // Reset checkbox and percentage if not Custom (case-insensitive check)
                        if (row.selectedType == null ||
                            (row.selectedType!.trim().toLowerCase() !=
                                    'custom' ||
                                rowType != 'discount')) {
                          row.isPercentageEnabled = false;
                          row.percentageController.clear();
                        }
                        // Update totals without setState first
                        _updateTotalsWithoutSetState();
                        // Use a more reliable approach: preserve scroll position and restore after rebuild
                        if (mounted) {
                          setState(() {});
                          // Restore scroll position immediately and repeatedly to ensure it sticks
                          if (_scrollController.hasClients &&
                              scrollOffset > 0) {
                            // Immediate restoration
                            _scrollController.jumpTo(scrollOffset);
                            // Multiple restoration attempts to handle any delayed rebuilds
                            Future.microtask(() {
                              if (_scrollController.hasClients && mounted) {
                                _scrollController.jumpTo(scrollOffset);
                                // Ensure focus stays cleared
                                FocusManager.instance.primaryFocus?.unfocus();
                              }
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_scrollController.hasClients && mounted) {
                                _scrollController.jumpTo(scrollOffset);
                                // Ensure focus stays cleared
                                FocusManager.instance.primaryFocus?.unfocus();
                              }
                            });
                            SchedulerBinding.instance.addPostFrameCallback((_) {
                              if (_scrollController.hasClients && mounted) {
                                _scrollController.jumpTo(scrollOffset);
                                // Ensure focus stays cleared
                                FocusManager.instance.primaryFocus?.unfocus();
                              }
                            });
                            // Additional delayed attempts with focus prevention
                            Future.delayed(const Duration(milliseconds: 10),
                                () {
                              if (_scrollController.hasClients && mounted) {
                                _scrollController.jumpTo(scrollOffset);
                                FocusManager.instance.primaryFocus?.unfocus();
                              }
                            });
                            Future.delayed(const Duration(milliseconds: 50),
                                () {
                              if (_scrollController.hasClients && mounted) {
                                _scrollController.jumpTo(scrollOffset);
                                FocusManager.instance.primaryFocus?.unfocus();
                              }
                            });
                            // Reset flag after a longer delay to allow all focus attempts to be prevented
                            Future.delayed(const Duration(milliseconds: 200),
                                () {
                              if (mounted) {
                                _preventingFocusRestoration = false;
                              }
                            });
                          } else {
                            // Reset flag even if no scroll restoration needed
                            Future.delayed(const Duration(milliseconds: 200),
                                () {
                              if (mounted) {
                                _preventingFocusRestoration = false;
                              }
                            });
                          }
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: tealGreen, width: 2),
                          ),
                          suffixIcon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: tealGreen,
                          ),
                        ),
                        child: Text(
                          row.selectedType ?? 'Select',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: row.selectedType != null
                                ? Colors.grey.shade900
                                : Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      itemBuilder: (context) => dropdownOptions.map((option) {
                        return PopupMenuItem<String>(
                          value: option,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 120),
                            child: Text(
                              option,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: option == 'Select'
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade900,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                // Show checkbox, %, and percentage input when Custom is selected for discount (Mobile)
                if (rowType == 'discount' &&
                    row.selectedType != null &&
                    row.selectedType!.trim().toLowerCase() == 'custom') ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 44),
                    child: Row(
                      children: [
                        Checkbox(
                          value: row.isPercentageEnabled,
                          onChanged: (value) {
                            setState(() {
                              row.isPercentageEnabled = value ?? false;
                              if (!row.isPercentageEnabled) {
                                row.percentageController.clear();
                              }
                              _updateTotals();
                            });
                          },
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '%',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: row.isPercentageEnabled
                                ? tealGreen
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: row.percentageController,
                            enabled: row.isPercentageEnabled,
                            textAlign: TextAlign.end,
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: row.isPercentageEnabled
                                  ? const Color(0xFF111827)
                                  : Colors.grey.shade400,
                            ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFFD1D5DB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: row.isPercentageEnabled
                                      ? const Color(0xFFD1D5DB)
                                      : Colors.grey.shade300,
                                ),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: tealGreen, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              isDense: true,
                              filled: true,
                              fillColor: row.isPercentageEnabled
                                  ? Colors.white
                                  : Colors.grey.shade50,
                              hintText: '0',
                              hintStyle: GoogleFonts.inter(
                                  color: Colors.grey.shade400),
                            ),
                            onChanged: (text) {
                              // Auto-calculate discount value when percentage is entered
                              if (rowType == 'discount' &&
                                  row.selectedType != null &&
                                  row.selectedType!.trim().toLowerCase() ==
                                      'custom' &&
                                  row.isPercentageEnabled) {
                                final percentage = double.tryParse(text) ?? 0.0;
                                final subTotal = _subTotal;
                                if (percentage > 0 && subTotal > 0) {
                                  final calculatedDiscount =
                                      (subTotal * percentage) / 100;
                                  row.valueController.text =
                                      calculatedDiscount.toStringAsFixed(2);
                                  print(
                                      '🔵 Auto-calculated discount: ${calculatedDiscount.toStringAsFixed(2)} from ${percentage}% of ${subTotal}');
                                } else if (percentage == 0 || subTotal == 0) {
                                  row.valueController.text = '0.00';
                                }
                              }
                              _updateTotals();
                            },
                            maxLines: 1,
                            textAlignVertical: TextAlignVertical.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: TextField(
                    controller: row.valueController,
                    enabled: rowType != 'tax' &&
                        (rowType == 'otherCharge' ||
                            !_isEditMode), // Enable Other Charge in edit mode, disable Tax in all modes
                    textAlign: TextAlign.end,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: (rowType == 'tax' ||
                              (_isEditMode && rowType != 'otherCharge'))
                          ? Colors.grey.shade400
                          : const Color(0xFF111827),
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: tealGreen, width: 2),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 16 : 14,
                        vertical: isTablet ? 16 : 14,
                      ),
                      filled: true,
                      fillColor: (rowType == 'tax' ||
                              (_isEditMode && rowType != 'otherCharge'))
                          ? Colors.grey.shade50
                          : Colors.white,
                      hintText: '0',
                      hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                    ),
                    onChanged: (text) {
                      _updateTotals();
                    },
                  ),
                ),
              ],
            );
          }
          // Desktop/Tablet: Horizontal layout with consistent alignment
          // Use a structured layout to ensure value fields align properly
          return Row(
            children: [
              // Delete button column (fixed width)
              SizedBox(
                width: isTablet ? 40 : 36,
                child: hasDeleteButton
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.remove,
                              color: Colors.white, size: 18),
                        ),
                        onPressed: () {
                          setState(() {
                            if (rowType == 'tax') {
                              row.dispose();
                              _taxRows.removeAt(index);
                            } else if (rowType == 'discount') {
                              row.dispose();
                              _discountRows.removeAt(index);
                            } else if (rowType == 'otherCharge') {
                              row.dispose();
                              _otherChargeRows.removeAt(index);
                            }
                            _updateTotals();
                          });
                        },
                      )
                    : const SizedBox.shrink(),
              ),
              SizedBox(width: isTablet ? 12 : 8),
              // Label column (fixed width to match Sub Total structure)
              SizedBox(
                width: isTablet ? 90 : 75,
                child: Text(
                  rowType == 'tax'
                      ? 'Tax'
                      : (rowType == 'discount' ? 'Discount' : 'Other Charge'),
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 14 : 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
              SizedBox(width: isTablet ? 8 : 6),
              // Middle section: Dropdown + Custom fields (flexible width, but consistent structure)
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    // Dropdown column (flexible width to prevent overflow)
                    Flexible(
                      flex: 2,
                      child: hasDropdown
                          ? PopupMenuButton<String>(
                              initialValue: row.selectedType,
                              // Open upward to avoid overlapping with bottom buttons
                              position: PopupMenuPosition.over,
                              offset: const Offset(0, -4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side:
                                    const BorderSide(color: Color(0xFFD1D5DB)),
                              ),
                              onSelected: (value) {
                                // Preserve scroll position synchronously before any async operations
                                final scrollOffset =
                                    _scrollController.hasClients
                                        ? _scrollController.offset
                                        : 0.0;
                                // Set flag to prevent automatic focus restoration
                                _preventingFocusRestoration = true;
                                // Prevent focus from moving to any field - use primaryFocus to clear focus
                                final currentFocus = FocusScope.of(context);
                                final primaryFocus =
                                    FocusManager.instance.primaryFocus;
                                if (primaryFocus != null) {
                                  primaryFocus.unfocus();
                                }
                                currentFocus.unfocus();
                                // Also prevent any automatic focus restoration
                                WidgetsBinding
                                    .instance.focusManager.primaryFocus
                                    ?.unfocus();
                                // Update the row data first without setState
                                row.selectedType =
                                    (value == 'Select') ? null : value;
                                print(
                                    '🔵 Discount dropdown selected: "$value", final selectedType: "${row.selectedType}"');
                                // Reset checkbox and percentage if not Custom (case-insensitive check)
                                if (row.selectedType == null ||
                                    (row.selectedType!.trim().toLowerCase() !=
                                            'custom' ||
                                        rowType != 'discount')) {
                                  row.isPercentageEnabled = false;
                                  row.percentageController.clear();
                                }
                                // Update totals without setState first
                                _updateTotalsWithoutSetState();
                                // Use a more reliable approach: preserve scroll position and restore after rebuild
                                if (mounted) {
                                  setState(() {});
                                  // Restore scroll position immediately and repeatedly to ensure it sticks
                                  if (_scrollController.hasClients &&
                                      scrollOffset > 0) {
                                    // Immediate restoration
                                    _scrollController.jumpTo(scrollOffset);
                                    // Multiple restoration attempts to handle any delayed rebuilds
                                    Future.microtask(() {
                                      if (_scrollController.hasClients &&
                                          mounted) {
                                        _scrollController.jumpTo(scrollOffset);
                                        // Ensure focus stays cleared
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                      }
                                    });
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (_scrollController.hasClients &&
                                          mounted) {
                                        _scrollController.jumpTo(scrollOffset);
                                        // Ensure focus stays cleared
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                      }
                                    });
                                    SchedulerBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (_scrollController.hasClients &&
                                          mounted) {
                                        _scrollController.jumpTo(scrollOffset);
                                        // Ensure focus stays cleared
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                      }
                                    });
                                    // Additional delayed attempts with focus prevention
                                    Future.delayed(
                                        const Duration(milliseconds: 10), () {
                                      if (_scrollController.hasClients &&
                                          mounted) {
                                        _scrollController.jumpTo(scrollOffset);
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                      }
                                    });
                                    Future.delayed(
                                        const Duration(milliseconds: 50), () {
                                      if (_scrollController.hasClients &&
                                          mounted) {
                                        _scrollController.jumpTo(scrollOffset);
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                      }
                                    });
                                    // Reset flag after a longer delay to allow all focus attempts to be prevented
                                    Future.delayed(
                                        const Duration(milliseconds: 200), () {
                                      if (mounted) {
                                        _preventingFocusRestoration = false;
                                      }
                                    });
                                  } else {
                                    // Reset flag even if no scroll restoration needed
                                    Future.delayed(
                                        const Duration(milliseconds: 200), () {
                                      if (mounted) {
                                        _preventingFocusRestoration = false;
                                      }
                                    });
                                  }
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 12 : 10,
                                    vertical: isTablet ? 12 : 10,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFD1D5DB)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFD1D5DB)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        BorderSide(color: tealGreen, width: 2),
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 20,
                                    color: tealGreen,
                                  ),
                                ),
                                child: Text(
                                  row.selectedType ?? 'Select',
                                  style: GoogleFonts.inter(
                                    fontSize: isTablet ? 13 : 12,
                                    color: row.selectedType != null
                                        ? Colors.grey.shade900
                                        : Colors.grey.shade500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              itemBuilder: (context) =>
                                  dropdownOptions.map((option) {
                                return PopupMenuItem<String>(
                                  value: option,
                                  child: SizedBox(
                                    width: isTablet ? 150 : 120,
                                    child: Text(
                                      option,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: option == 'Select'
                                            ? Colors.grey.shade500
                                            : Colors.grey.shade900,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            )
                          : const SizedBox.shrink(),
                    ),
                    SizedBox(width: isTablet ? 6 : 4),
                    // Custom discount fields (checkbox, %, percentage input) - only for discount with Custom selected
                    Builder(
                      builder: (context) {
                        final showCustomFields = rowType == 'discount' &&
                            row.selectedType != null &&
                            row.selectedType!.trim().toLowerCase() == 'custom';

                        if (showCustomFields) {
                          print(
                              '🔵 ✅ Building Custom discount UI - selectedType: "${row.selectedType}", isPercentageEnabled: ${row.isPercentageEnabled}');
                        }

                        if (!showCustomFields) {
                          return const SizedBox.shrink();
                        }

                        return Flexible(
                          flex: 2,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Checkbox with % label
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: row.isPercentageEnabled,
                                    onChanged: (value) {
                                      setState(() {
                                        row.isPercentageEnabled =
                                            value ?? false;
                                        if (!row.isPercentageEnabled) {
                                          // Clear percentage when unchecked
                                          row.percentageController.clear();
                                        }
                                        _updateTotals();
                                      });
                                    },
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '%',
                                    style: GoogleFonts.inter(
                                      fontSize: isTablet ? 14 : 13,
                                      fontWeight: FontWeight.w600,
                                      color: row.isPercentageEnabled
                                          ? tealGreen
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 6),
                              // Percentage input field (enabled when checkbox is checked) - flexible width
                              Flexible(
                                child: TextField(
                                  controller: row.percentageController,
                                  enabled: row.isPercentageEnabled,
                                  textAlign: TextAlign.end,
                                  keyboardType: TextInputType.numberWithOptions(
                                      decimal: true),
                                  style: GoogleFonts.inter(
                                    fontSize: isTablet ? 14 : 13,
                                    fontWeight: FontWeight.w500,
                                    color: row.isPercentageEnabled
                                        ? const Color(0xFF111827)
                                        : Colors.grey.shade400,
                                  ),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFD1D5DB)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: row.isPercentageEnabled
                                            ? const Color(0xFFD1D5DB)
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    disabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: tealGreen, width: 2),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: isTablet ? 12 : 10,
                                      vertical: isTablet ? 12 : 10,
                                    ),
                                    isDense: true,
                                    filled: true,
                                    fillColor: row.isPercentageEnabled
                                        ? Colors.white
                                        : Colors.grey.shade50,
                                    hintText: '0',
                                    hintStyle: GoogleFonts.inter(
                                        color: Colors.grey.shade400),
                                  ),
                                  onChanged: (text) {
                                    // Auto-calculate discount value when percentage is entered
                                    if (rowType == 'discount' &&
                                        row.selectedType != null &&
                                        row.selectedType!
                                                .trim()
                                                .toLowerCase() ==
                                            'custom' &&
                                        row.isPercentageEnabled) {
                                      final percentage =
                                          double.tryParse(text) ?? 0.0;
                                      final subTotal = _subTotal;
                                      if (percentage > 0 && subTotal > 0) {
                                        final calculatedDiscount =
                                            (subTotal * percentage) / 100;
                                        row.valueController.text =
                                            calculatedDiscount
                                                .toStringAsFixed(2);
                                        print(
                                            '🔵 Auto-calculated discount: ${calculatedDiscount.toStringAsFixed(2)} from ${percentage}% of ${subTotal}');
                                      } else if (percentage == 0 ||
                                          subTotal == 0) {
                                        row.valueController.text = '0.00';
                                      }
                                    }
                                    _updateTotals();
                                  },
                                  maxLines: 1,
                                  textAlignVertical: TextAlignVertical.center,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(width: isTablet ? 8 : 6),
              // Value input field column (fixed width to match Sub Total alignment)
              Expanded(
                flex: 2,
                child: TextField(
                  controller: row.valueController,
                  enabled: rowType != 'tax' &&
                      (rowType == 'otherCharge' ||
                          !_isEditMode), // Enable Other Charge in edit mode, disable Tax in all modes
                  textAlign: TextAlign.end,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 14 : 13,
                    fontWeight: FontWeight.w500,
                    color: (rowType == 'tax' ||
                            (_isEditMode && rowType != 'otherCharge'))
                        ? Colors.grey.shade900
                        : const Color(0xFF111827),
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: (rowType == 'tax' ||
                                (_isEditMode && rowType != 'otherCharge'))
                            ? Colors.grey.shade300
                            : tealGreen,
                        width: (rowType == 'tax' ||
                                (_isEditMode && rowType != 'otherCharge'))
                            ? 1
                            : 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 12 : 10,
                      vertical: isTablet ? 12 : 10,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: (rowType == 'tax' ||
                            (_isEditMode && rowType != 'otherCharge'))
                        ? Colors.grey.shade50
                        : Colors.white,
                    hintText: '0.00',
                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                  ),
                  onChanged: (text) {
                    _updateTotals();
                  },
                  maxLines: 1,
                  textAlignVertical: TextAlignVertical.center,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTaxTableRowWithController({
    required String label,
    required TextEditingController controller,
    required bool isTablet,
    bool enabled =
        false, // Default to disabled, but can be enabled for Price Adjustment
  }) {
    const Color tealGreen = Color(0xFF4db1b3);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12, vertical: isTablet ? 14 : 12),
      child: Row(
        children: [
          SizedBox(width: isTablet ? 40 : 36),
          SizedBox(width: isTablet ? 12 : 8),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: isTablet ? 15 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
                letterSpacing: 0.1,
              ),
            ),
          ),
          Expanded(flex: 2, child: const SizedBox.shrink()),
          SizedBox(width: isTablet ? 12 : 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller,
              enabled: enabled,
              textAlign: TextAlign.end,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(
                fontSize: isTablet ? 14 : 13,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.grey.shade900 : Colors.grey.shade900,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: enabled ? tealGreen : Colors.grey.shade300,
                    width: enabled ? 2 : 1,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 14 : 12,
                  vertical: isTablet ? 14 : 12,
                ),
                isDense: true,
                filled: true,
                fillColor: enabled ? Colors.white : Colors.grey.shade50,
                hintText: '0.00',
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
              ),
              onChanged: (text) {
                _updateTotals();
              },
              maxLines: 1,
              textAlignVertical: TextAlignVertical.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxTableRow({
    required String label,
    required bool hasActionButton,
    required bool hasDeleteButton,
    required bool hasDropdown,
    String? dropdownValue,
    List<String>? dropdownOptions,
    ValueChanged<String?>? onDropdownChanged,
    required double value,
    required bool isEditable,
    ValueChanged<double>? onValueChanged,
    bool isTotal = false,
    required bool isTablet,
  }) {
    const Color tealGreen = Color(0xFF4db1b3);
    return Row(
      children: [
        // Actions Column
        SizedBox(
          width: 40,
          child: hasActionButton
              ? IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: tealGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 18),
                  ),
                  onPressed: () {
                    // Action button functionality can be added here
                  },
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        // Label Column
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 14 : 13,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: Colors.grey.shade900,
            ),
          ),
        ),
        // Configuration Column (Dropdown)
        Expanded(
          flex: 2,
          child: hasDropdown
              ? PopupMenuButton<String>(
                  initialValue: dropdownValue,
                  offset: const Offset(0, 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                  onSelected: onDropdownChanged,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 14 : 12,
                        vertical: isTablet ? 14 : 12,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: tealGreen, width: 2),
                      ),
                      suffixIcon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: tealGreen,
                      ),
                    ),
                    child: Text(
                      dropdownValue ?? 'Select',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 13 : 12,
                        color: dropdownValue != null
                            ? Colors.grey.shade900
                            : Colors.grey.shade500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  itemBuilder: (context) =>
                      (dropdownOptions ?? []).map((option) {
                    return PopupMenuItem<String>(
                      value: option,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minWidth: isTablet ? 150 : 120),
                        child: Text(
                          option,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: option == 'Select'
                                ? Colors.grey.shade500
                                : Colors.grey.shade900,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        // Value Column
        Expanded(
          flex: 1,
          child: isEditable
              ? TextField(
                  controller: TextEditingController(
                      text: value == 0.0 ? '' : value.toStringAsFixed(2)),
                  textAlign: TextAlign.end,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 14 : 13,
                    fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
                    color: isTotal ? tealGreen : Colors.grey.shade900,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: (text) {
                    final newValue = double.tryParse(text) ?? 0.0;
                    onValueChanged?.call(newValue);
                  },
                )
              : Text(
                  value == 0.0 ? '0' : _formatCurrency(value),
                  textAlign: TextAlign.end,
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 14 : 13,
                    fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
                    color: isTotal ? tealGreen : Colors.grey.shade900,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTaxRow(String label, double value,
      {bool isTotal = false, required bool isTablet}) {
    const Color tealGreen = Color(0xFF4db1b3);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isTablet ? 14 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        Text(
          _formatCurrency(value),
          style: GoogleFonts.inter(
            fontSize: isTablet ? 14 : 13,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
            color: isTotal ? tealGreen : Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildTaxRowWithDropdown(
    String label,
    double value,
    String? selectedValue,
    List<String> options,
    ValueChanged<String?> onChanged, {
    required bool isTablet,
  }) {
    const Color tealGreen = Color(0xFF4db1b3);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 14 : 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade900,
            ),
          ),
        ),
        Expanded(
          child: PopupMenuButton<String>(
            initialValue: selectedValue,
            offset: const Offset(0, 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            onSelected: onChanged,
            child: InputDecorator(
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 14 : 12,
                  vertical: isTablet ? 14 : 12,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: tealGreen, width: 2),
                ),
                suffixIcon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: tealGreen,
                ),
              ),
              child: Text(
                selectedValue ?? 'Select',
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 14 : 13,
                  color: selectedValue != null
                      ? Colors.grey.shade900
                      : Colors.grey.shade500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            itemBuilder: (context) => options.map((option) {
              return PopupMenuItem<String>(
                value: option,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: isTablet ? 150 : 120),
                  child: Text(
                    option,
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 100,
          child: Text(
            _formatCurrency(value),
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 14 : 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentsSection({required bool isTablet}) {
    const Color tealGreen = Color(0xFF4db1b3);
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section Title with Expand/Collapse and Add File Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isAttachmentsExpanded = !_isAttachmentsExpanded;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      child: Text(
                        'Attachments',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _pickFile(),
                      icon: Icon(Icons.attach_file, size: 18, color: tealGreen),
                      label: Text(
                        'Add File',
                        style: GoogleFonts.inter(
                          color: tealGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isAttachmentsExpanded = !_isAttachmentsExpanded;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            _isAttachmentsExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.grey.shade600,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Attachments List - Scrollable (shown when expanded)
            if (_isAttachmentsExpanded) ...[
              const SizedBox(height: 16),
              _buildAttachmentsList(isTablet),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          // Images
          'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp',
          // Documents
          'pdf', 'doc', 'docx', 'txt',
          // Spreadsheets
          'xls', 'xlsx',
          // Presentations
          'ppt', 'pptx',
        ],
        allowMultiple: true,
        withData: true,
        withReadStream: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachments.addAll(result.files);
        });
      }
    } catch (e) {
      print('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Build attachments list: existing (from loaded order) + new (picked files).
  Widget _buildAttachmentsList(bool isTablet) {
    final existingAttachments =
        _loadedOrderData?.fileUploadDetails ?? <FileUploadDetail>[];
    final hasExisting = existingAttachments.isNotEmpty;
    final hasNew = _attachments.isNotEmpty;

    if (!hasExisting && !hasNew) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Center(
          child: Text(
            'No attachments. Click "Add File" to upload.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: ListView(
        shrinkWrap: true,
        children: [
          if (hasExisting) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Existing attachments',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            ...existingAttachments.map((att) {
              final name = (att.fileName ?? '').trim().isNotEmpty
                  ? att.fileName!.trim()
                  : 'Attachment';
              final ext =
                  (att.extension ?? '').toLowerCase().replaceAll('.', '');
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file,
                      color: Colors.grey.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (ext.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                ext.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Saved',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
          if (hasNew) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'New attachments',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            ...List.generate(_attachments.length, (index) {
              final file = _attachments[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file,
                      color: Colors.grey.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatFileSize(file.size),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() => _attachments.removeAt(index));
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActionBar({required bool isTablet}) {
    const Color tealGreen = Color(0xFF4db1b3);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        isTablet ? 16 : 12,
        16,
        isTablet ? 16 : 12,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: SafeArea(
        top: false,
        child: (_isLoadingWorkflowActions || _isLoadingPrivileges)
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(tealGreen),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading actions...',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 14 : 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              )
            : _isApprovedOrder
                ? _buildApprovedOrderBottomBar(isTablet: isTablet)
                : Row(
                    children: [
                      // Save Button - Enabled based on Draft Save privilege (ButtonSave HasRight OR IsSalesRepEdit)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isDraftSaveEnabled ? _onSaveDraft : null,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: isTablet ? 16 : 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: _isDraftSaveEnabled
                                  ? tealGreen
                                  : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            'Save',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w700,
                              color: _isDraftSaveEnabled
                                  ? tealGreen
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      // Workflow Action Buttons - Display dynamically from API response
                      // Display all buttons, but enable only those with processAction value
                      ...(_workflowActions.map((action) {
                        // Enable button if processAction has value (not null and not empty)
                        final hasProcessAction = action.processAction != null &&
                            action.processAction!.isNotEmpty;
                        final isEnabled = hasProcessAction && !_isLoading;

                        // Parse color from API, but use tealGreen for enabled buttons if color is grey/light
                        final parsedColor = _parseColorFromHex(action.color);
                        Color enabledColor;
                        if (isEnabled && parsedColor != null) {
                          // Check if color is too light/grey - if so, use tealGreen instead
                          final brightness = parsedColor.computeLuminance();
                          if (brightness > 0.7 ||
                              action.color?.toLowerCase().contains('d3d3d3') ==
                                  true) {
                            // Color is too light or grey, use tealGreen for enabled buttons
                            enabledColor = tealGreen;
                          } else {
                            enabledColor = parsedColor;
                          }
                        } else {
                          enabledColor =
                              tealGreen; // Default to tealGreen for enabled buttons
                        }

                        print(
                            '🔘 Workflow Button: ${action.name}, ProcessAction: ${action.processAction?.length ?? 0}, Enabled: $isEnabled, Color: ${action.color} -> ${enabledColor.value.toRadixString(16)}');

                        return [
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isEnabled
                                  ? () => _onWorkflowAction(action)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: isTablet ? 16 : 14,
                                ),
                                backgroundColor:
                                    isEnabled ? enabledColor : Colors.grey.shade300,
                                foregroundColor:
                                    isEnabled ? Colors.white : Colors.grey.shade600,
                                disabledBackgroundColor: Colors.grey.shade300,
                                disabledForegroundColor: Colors.grey.shade600,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: isEnabled ? 2 : 0,
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          isEnabled
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      action.name,
                                      style: GoogleFonts.inter(
                                        fontSize: isTablet ? 16 : 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ];
                      }).expand((buttons) => buttons)),
                    ],
                  ),
      ),
    );
  }

  /// Bottom bar for approved orders: Amend, Modify, and Cancel (no Save, no Submit).
  Widget _buildApprovedOrderBottomBar({required bool isTablet}) {
    const Color tealGreen = Color(0xFF4db1b3);
    final bool transactionCompleted = _workflowActions.isNotEmpty &&
        _workflowActions
            .any((action) => action.transactionCompleted == true);
    final bool isCancelled = _loadedOrderData?.isCancelled == 1;
    final bool isShortClosed = _loadedOrderData?.isShortClosed == 1;
    final bool showModify = transactionCompleted &&
        !isCancelled &&
        !isShortClosed &&
        (_buttonPrivileges['ButtonModify'] ?? _buttonPrivileges['buttonModify'])
            ?.hasRight ==
            true;
    final bool showCancel = transactionCompleted &&
        !isCancelled &&
        !isShortClosed &&
        (_buttonPrivileges['ButtonCancel'] ?? _buttonPrivileges['buttonCancel'])
            ?.hasRight ==
            true;
    // Amend: workflow action with name "Amend" (from API)
    final amendList = _workflowActions
        .where((a) =>
            a.name.toLowerCase() == 'amend' &&
            a.processAction != null &&
            a.processAction!.isNotEmpty)
        .toList();
    final ProcessActionDetail? amendAction =
        amendList.isEmpty ? null : amendList.first;
    final bool showAmend = !_isLoading && amendAction != null;
    final ProcessActionDetail? amendActionForButton = amendAction;

    final List<Widget> buttons = [];
    if (showAmend && amendActionForButton != null) {
      final amendActionToRun = amendActionForButton;
      buttons.add(
        Expanded(
          child: OutlinedButton(
            onPressed: () => _onWorkflowAction(amendActionToRun),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: tealGreen, width: 1.5),
            ),
            child: Text(
              'Amend',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w700,
                color: tealGreen,
              ),
            ),
          ),
        ),
      );
    }
    if (showModify) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 12));
      buttons.add(
        Expanded(
          child: OutlinedButton(
            onPressed: _handleModifyOrder,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: tealGreen, width: 1.5),
            ),
            child: Text(
              'Modify',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w700,
                color: tealGreen,
              ),
            ),
          ),
        ),
      );
    }
    if (showCancel) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 12));
      buttons.add(
        Expanded(
          child: ElevatedButton(
            onPressed: _handleCancelOrder,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }
    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(children: buttons);
  }

  /// Build actions menu overlay with smooth animation
  Widget _buildActionsMenuOverlay({required bool isTablet}) {
    if (_buttonPrivileges.isEmpty) {
      return const SizedBox.shrink();
    }

    // Map button names to icons, labels, actions, and colors
    final buttonConfig = {
      'ButtonCancel': {
        'icon': Icons.cancel_outlined,
        'label': 'Cancel',
        'color': Colors.red,
        'action': () => _handleCancelOrder(),
      },
      'ButtonModify': {
        'icon': Icons.edit_document,
        'label': 'Modify',
        'color': Colors.red,
        'action': () => _handleModifyOrder(),
      },
      'ButtonPrint': {
        'icon': Icons.print_outlined,
        'label': 'Print',
        'color': Colors.blue,
        'action': () {
          setState(() => _isActionsMenuOpen = false);
          ToastMessage.show(
            context,
            message: 'Print action triggered',
            type: ToastType.info,
            icon: Icons.print_outlined,
            duration: const Duration(seconds: 2),
          );
        },
      },
      'ButtonSave': {
        'icon': Icons.save_outlined,
        'label': 'Save',
        'color': Colors.green,
        'action': () {
          setState(() => _isActionsMenuOpen = false);
          _onSaveDraft();
        },
      },
      'ButtonDelete': {
        'icon': Icons.delete_outlined,
        'label': 'Delete',
        'color': Colors.red,
        'action': () => _handleDeleteOrder(),
      },
      // ButtonShortClose is removed - not needed for sales rep
    };

    // Collect buttons with hasRight = true, but exclude ButtonSave (already shown in bottom bar)
    // Exclude Modify and Cancel from actions menu - they are shown in the bottom bar for approved orders
    final List<Map<String, dynamic>> enabledButtons = [];
    for (final entry in _buttonPrivileges.entries) {
      final buttonKey = entry.key;
      final privilege = entry.value;

      // Skip ButtonSave as it's already displayed in the bottom action bar
      if (buttonKey == 'ButtonSave') {
        continue;
      }

      // Skip Modify and Cancel - shown in bottom bar for approved orders, not in actions section
      if (buttonKey == 'ButtonModify' || buttonKey == 'buttonModify') {
        continue;
      }
      if (buttonKey == 'ButtonCancel' || buttonKey == 'buttonCancel') {
        continue;
      }

      // Skip ButtonShortClose - not needed for sales rep
      if (buttonKey == 'ButtonShortClose') {
        continue;
      }

      // Special handling for ButtonCancel (kept for any other code path; button already skipped above)
      if (buttonKey == 'ButtonCancel') {
        // Check if cancel button should be shown:
        // 1. Must have privilege (hasRight = true)
        // 2. transactionCompleted must be 1 (from workflow actions)
        // 3. Must NOT be cancelled or short closed (if editing)

        if (!privilege.hasRight) {
          continue; // No privilege, skip
        }

        // Check transactionCompleted from workflow actions
        // transactionCompleted = 1 means transaction is complete
        bool transactionCompleted = false;
        if (_workflowActions.isNotEmpty) {
          // Check if any workflow action has transactionCompleted = true
          transactionCompleted = _workflowActions
              .any((action) => action.transactionCompleted == true);
        }

        // Only show if transactionCompleted = 1 (true)
        if (!transactionCompleted) {
          continue; // Transaction not completed, skip
        }

        // If editing, check if order is already cancelled or short closed
        if (_isEditMode && _loadedOrderData != null) {
          final isCancelled = _loadedOrderData!.isCancelled == 1;
          final isShortClosed = _loadedOrderData!.isShortClosed == 1;

          if (isCancelled || isShortClosed) {
            continue; // Already cancelled or short closed, skip
          }
        }
      }

      // Special handling for ButtonModify
      if (buttonKey == 'ButtonModify') {
        // Check if modify button should be shown:
        // 1. Must have privilege (hasRight = true)
        // 2. transactionCompleted must be 1 (from workflow actions) - show only when TransactionComplete = 1
        // 3. Must NOT be cancelled or short closed (if editing)

        if (!privilege.hasRight) {
          continue; // No privilege, skip
        }

        // Check transactionCompleted from workflow actions
        // transactionCompleted = 1 means transaction is complete
        // Show Modify button ONLY when TransactionComplete = 1
        bool transactionCompleted = false;
        if (_workflowActions.isNotEmpty) {
          // Check if any workflow action has transactionCompleted = true
          transactionCompleted = _workflowActions
              .any((action) => action.transactionCompleted == true);
        }

        // Only show if transactionCompleted = 1 (true)
        // If TransactionComplete = 0, don't show even if privilege is true
        if (!transactionCompleted) {
          continue; // Transaction not completed, skip
        }

        // If editing, check if order is already cancelled or short closed
        if (_isEditMode && _loadedOrderData != null) {
          final isCancelled = _loadedOrderData!.isCancelled == 1;
          final isShortClosed = _loadedOrderData!.isShortClosed == 1;

          if (isCancelled || isShortClosed) {
            continue; // Already cancelled or short closed, skip
          }
        }
      }

      // Special handling for ButtonDelete (same visibility as Cancel)
      if (buttonKey == 'ButtonDelete') {
        if (!privilege.hasRight) continue;

        bool transactionCompleted = false;
        if (_workflowActions.isNotEmpty) {
          transactionCompleted = _workflowActions
              .any((action) => action.transactionCompleted == true);
        }
        if (!transactionCompleted) continue;

        if (_isEditMode && _loadedOrderData != null) {
          if (_loadedOrderData!.isCancelled == 1 ||
              _loadedOrderData!.isShortClosed == 1) {
            continue;
          }
        }
      }

      if (privilege.hasRight && buttonConfig.containsKey(buttonKey)) {
        final config = Map<String, dynamic>.from(buttonConfig[buttonKey]!);
        config['key'] = buttonKey;
        enabledButtons.add(config);
      }
    }

    if (enabledButtons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Backdrop
        if (_isActionsMenuOpen)
          GestureDetector(
            onTap: () {
              setState(() => _isActionsMenuOpen = false);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              color: _isActionsMenuOpen
                  ? Colors.black.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
        // Side menu panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: _isActionsMenuOpen ? 0 : -MediaQuery.of(context).size.height,
          right: 0,
          child: Container(
            width: isTablet ? 280 : 240,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Actions',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          setState(() => _isActionsMenuOpen = false);
                        },
                        color: Colors.grey.shade700,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Buttons list
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: enabledButtons.asMap().entries.map((entry) {
                      final index = entry.key;
                      final button = entry.value;
                      final icon = button['icon'] as IconData;
                      final label = button['label'] as String;
                      final color = button['color'] as Color;
                      final action = button['action'] as VoidCallback;

                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 200 + (index * 50)),
                        tween: Tween(
                            begin: 0.0, end: _isActionsMenuOpen ? 1.0 : 0.0),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Opacity(
                              opacity: value,
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OutlinedButton.icon(
                            onPressed: action,
                            icon: Icon(icon, size: 22),
                            label: Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: color,
                              side: BorderSide(color: color, width: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(double.infinity, 52),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<SalesOrderSaveRequest> _buildSaveRequest(int workflowFlag) async {
    // Get user info
    final sharedPrefHelper = getIt<SharedPreferenceHelper>();
    final user = await sharedPrefHelper.getUser();
    if (user == null) {
      throw Exception('User not available');
    }

    // Get bizUnit and distributor info
    final UserDetailStore? userStore =
        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;

    int? bizUnitFromStore = userStore?.userDetail?.sbuId;
    int? bizUnitFromPrefs = user.sbuId;
    final int bizUnit = (bizUnitFromStore != null && bizUnitFromStore > 0)
        ? bizUnitFromStore
        : ((bizUnitFromPrefs != null && bizUnitFromPrefs > 0)
            ? bizUnitFromPrefs
            : 1);

    // Get distributor ID - use selected distributor or fallback to bizUnit
    int distributorId = bizUnit; // Default to user's bizUnit

    if (_selectedDistributor != null && _distributorItems.isNotEmpty) {
      try {
        final distributorItem = _distributorItems.firstWhere(
          (item) => item.text == _selectedDistributor,
        );
        distributorId = distributorItem.id;
        print('🔵 Selected Distributor ID: $distributorId');
      } catch (e) {
        print(
            'Warning: Selected distributor not found in list, using bizUnit: $e');
      }
    }

    // Backend requires SbuId and Bizunit to be set to DistributorId for workflow/amendment processing
    final int finalSbuId = distributorId;
    final int finalBizUnit = distributorId;

    // Get customer ID
    final int? customerId = _selectedCustomerCode != null
        ? int.tryParse(_selectedCustomerCode!)
        : null;

    // Get sales rep ID - find from stored items
    int? salesRepId;
    if (_selectedSalesRep != null && _salesRepItems.isNotEmpty) {
      try {
        final salesRepItem = _salesRepItems.firstWhere(
          (item) => item.text == _selectedSalesRep,
        );
        salesRepId = salesRepItem.id;
        print('🔵 Sales Rep ID: $salesRepId for "${_selectedSalesRep}"');
      } catch (e) {
        print('⚠️ Sales Rep not found in list: ${_selectedSalesRep}');
      }
    }

    // Get currency ID
    int currencyId = 79; // Default LKR - should be fetched from API
    if (_selectedCurrency == 'USD') {
      currencyId = 80; // Placeholder - should be fetched from API
    }

    // Get type ID
    int typeId = 1; // Default to 1 for Domestic
    if (_selectedType == 'Bonus') {
      typeId = 2;
    } else if (_selectedType == 'Normal') {
      typeId = 0;
    }

    // Get exchange rate
    final double exchangeRate =
        double.tryParse(_exchangeRateController.text) ?? 1.0;

    // Format dates - Try ISO 8601 format first, fallback to space format
    // .NET System.Text.Json should parse ISO 8601 format: "2025-12-23T00:00:01.000"
    final DateTime contractDate = _contractDate;
    final DateTime deliveryDate = _deliveryDate;

    // Use ISO 8601 format with 'T' separator (standard format that .NET can definitely parse)
    // Format: yyyy-MM-ddTHH:mm:ss.SSS
    String formatDateForApi(DateTime dt) {
      // Get ISO 8601 string and ensure milliseconds are included
      final isoString = dt.toIso8601String();
      // ISO 8601 format is: yyyy-MM-ddTHH:mm:ss.microsecondsZ or yyyy-MM-ddTHH:mm:ss.microseconds
      // We need: yyyy-MM-ddTHH:mm:ss.SSS (3 digit milliseconds, no Z)
      if (isoString.contains('.')) {
        final parts = isoString.split('.');
        final dateTimePart = parts[0]; // yyyy-MM-ddTHH:mm:ss
        final microSeconds =
            parts[1].replaceAll('Z', ''); // Remove Z if present
        // Convert microseconds to milliseconds (first 3 digits)
        final milliseconds = microSeconds.length >= 3
            ? microSeconds.substring(0, 3)
            : microSeconds.padRight(3, '0');
        return '$dateTimePart.$milliseconds';
      } else {
        // No milliseconds, add .000
        final cleanIso = isoString.replaceAll('Z', '');
        return '$cleanIso.000';
      }
    }

    final String dateStr = formatDateForApi(contractDate);
    final String deliveryDateStr = formatDateForApi(deliveryDate);

    // Validate dates are not empty
    if (dateStr.isEmpty || deliveryDateStr.isEmpty) {
      throw Exception(
          'Date formatting failed: dateStr=$dateStr, deliveryDateStr=$deliveryDateStr');
    }

    print('📅 Formatted Date: $dateStr');
    print('📅 Formatted DeliveryDate: $deliveryDateStr');

    // Build sales contract items
    final List<SalesContractItem> contractItems = [];
    for (final item in _items) {
      final itemId = int.tryParse(item.product.id) ?? 0;
      if (itemId == 0) continue; // Skip invalid items

      final qty = double.tryParse(item.qtyController.text.trim()) ?? 0.0;
      final dispatched = (item.despatchedQty ?? 0).toDouble();
      // Backend requires: quantity >= despatched quantity. Enforce minimum so save never fails.
      final quantity = (qty >= dispatched ? qty : dispatched).clamp(dispatched, double.infinity);
      // Get rate from controller, fallback to product rate if controller is empty
      final rateFromController = item.rateController.text.isNotEmpty
          ? double.tryParse(item.rateController.text)
          : null;
      final unitPrice = rateFromController ?? item.product.rate;
      // Get MRP from controller, fallback to product MRP if controller is empty
      final mrpFromController = item.mrpController.text.isNotEmpty
          ? double.tryParse(item.mrpController.text)
          : null;
      final mrp = mrpFromController ?? item.product.mrp;
      final discount = double.tryParse(item.discountController.text) ?? 0.0;

      print(
          '🔵 Building contract item: ItemId=$itemId, Qty=$qty, Dispatched=$dispatched, Quantity sent=$quantity, Rate=$unitPrice');
      final amountSent = quantity * unitPrice;
      final totalAmountSent = amountSent - discount;
      final bonusQty = double.tryParse(item.bonusQtyController.text) ?? 0.0;
      final additionalQty =
          int.tryParse(item.addlBonusQtyController.text.trim()) ?? 0;
      // Format ReqdDate using the same ISO 8601 format helper
      final reqdDateStr = formatDateForApi(item.requiredDate);

      // Get UOM ID from stored items
      int uomId = 44; // Default Box - fallback if not found
      if (item.selectedUOM != null && item.uomItems.isNotEmpty) {
        try {
          final uomItem = item.uomItems.firstWhere(
            (uom) => uom.text == item.selectedUOM,
          );
          uomId = uomItem.id;
          print('🔵 UOM ID: $uomId for "${item.selectedUOM}"');
        } catch (e) {
          print(
              '⚠️ UOM not found in list: ${item.selectedUOM}, using default: $uomId');
        }
      }

      // Existing line items: send their line item Id (detailId from API). New line items: must send null. Never use header/order id as line id (causes 500).
      final int? lineId = _isEditMode ? item.detailId : null;
      contractItems.add(SalesContractItem(
        id: lineId,
        createdBy: user.userId,
        status: 0,
        sbuId: finalSbuId,
        itemCategoryText: 'Pharma', // Should be from product data
        itemCategory: 6, // Should be from product data
        itemText: item.itemDescriptionController.text.isNotEmpty
            ? item.itemDescriptionController.text
            : item.product.name,
        item: itemId,
        quantity: quantity,
        uom: uomId,
        unitPrice: unitPrice,
        mrp: mrp,
        amount: amountSent,
        discount: discount,
        tax: item.taxAmount ?? 0.0,
        totalAmount: totalAmountSent,
        reqdDate: reqdDateStr,
        remarks: item.remarksController.text.isNotEmpty
            ? item.remarksController.text.trim()
            : null,
        addlRemarks: null,
        bonusQuantity: bonusQty,
        // Backend expects AdditionalQuantity in SalesContractItems to persist Addl. Bonus Qty
        additionalQuantity: additionalQty,
        uomText: item.selectedUOM ?? item.product.uom,
        discountAmount: discount,
        divisionGroup: 2, // Should be from product/customer data
        manufacturerName: item.product.manufacturer,
        isFOC: false,
        isRateUpdateConfirm: false,
        despatchedQty: item.despatchedQty ?? 0, // Send 0 when null so backend validation (quantity >= despatched) gets a value
      ));
    }

    // Build tax and other charges detail
    final List<TaxAndOtherChargeDetail> taxCharges = [];

    // Add SubTotal (if needed - typically not sent as a charge, but included in example)
    // SubTotal is usually calculated, not sent separately

    // Add Tax rows - include all tax rows even if value is 0 (they might be required by the API)
    for (final taxRow in _taxRows) {
      final value = taxRow.value;
      // Include tax row if it has a selectedType (meaning it was intentionally added)
      // or if it has a value > 0
      if ((taxRow.selectedType != null && taxRow.selectedType!.isNotEmpty) ||
          value > 0) {
        taxCharges.add(TaxAndOtherChargeDetail(
          id: _isEditMode ? taxRow.chargeDetailApiId : null,
          gridId: 80, // Should be from tax component formulas
          type: 22, // Tax type - should be mapped from selectedType
          value: value,
          hasMultiple: 1,
          pageId: 3,
          formula: null, // Should be from tax component formulas if available
          hasMultipleItem: true,
          operator: '+',
          chargeTypeId: 4, // Tax
          chargeTypePageMapId: 8, // Should be from tax component formulas
          levelType: 1,
          chargeTypeText: 'Tax',
          subTypeText: taxRow.selectedType,
          typeText: '',
          pageName: 'SalesOrder',
          isCustom: false,
          isCustomSelected: false,
          label: 'Tax',
        ));
      }
    }

    // Add Discount rows
    for (final discountRow in _discountRows) {
      final value = discountRow.value;
      final isCustom = discountRow.selectedType != null &&
          discountRow.selectedType!.trim().toLowerCase() == 'custom';
      final customPercentage = isCustom && discountRow.isPercentageEnabled
          ? discountRow.percentageValue
          : null;

      taxCharges.add(TaxAndOtherChargeDetail(
        id: _isEditMode ? discountRow.chargeDetailApiId : null,
        gridId: 81,
        type: -1, // Discount type
        value: value,
        hasMultiple: 1,
        pageId: 3,
        hasMultipleItem: true,
        operator: '-',
        chargeTypeId: 2, // Discount
        chargeTypePageMapId: 9,
        levelType: 1,
        chargeTypeText: 'Discount',
        subTypeText: discountRow.selectedType,
        typeText: '',
        pageName: 'SalesOrder',
        isCustom: isCustom,
        isCustomSelected: isCustom,
        customPercentage: customPercentage,
        label: 'Discount',
      ));
    }

    // Add Other Charge rows
    for (final otherChargeRow in _otherChargeRows) {
      final value = otherChargeRow.value;
      if (value > 0) {
        taxCharges.add(TaxAndOtherChargeDetail(
          id: _isEditMode ? otherChargeRow.chargeDetailApiId : null,
          gridId: 82,
          type: 0,
          value: value,
          hasMultiple: 1,
          pageId: 3,
          hasMultipleItem: true,
          operator: '+',
          chargeTypeId: 3, // OtherCharge
          chargeTypePageMapId: 10,
          levelType: 1,
          chargeTypeText: 'OtherCharge',
          typeText: '',
          pageName: 'SalesOrder',
          isCustom: false,
          isCustomSelected: false,
          label: 'Other Charge',
        ));
      }
    }

    // Add Price Adjustment
    final priceAdjustment = _priceAdjustment;
    taxCharges.add(TaxAndOtherChargeDetail(
      id: _isEditMode ? _loadedPriceAdjustmentChargeId : null,
      gridId: 83,
      type: 0,
      value: priceAdjustment,
      hasMultiple: 0,
      pageId: 3,
      hasMultipleItem: false,
      operator: '+',
      chargeTypeId: 5, // PriceAdjustment
      chargeTypePageMapId: 11,
      levelType: 1,
      chargeTypeText: 'PriceAdjustment',
      typeText: '',
      pageName: 'SalesOrder',
      isCustom: false,
      isCustomSelected: false,
      label: 'Price Adjustment',
    ));

    // Calculate Grand Total
    final grandTotal = _calculateGrandTotal();
    taxCharges.add(TaxAndOtherChargeDetail(
      id: _isEditMode ? _loadedGrandTotalChargeId : null,
      gridId: 84,
      type: 0,
      value: grandTotal,
      hasMultiple: 0,
      pageId: 3,
      hasMultipleItem: false,
      operator: ' ',
      chargeTypeId: 6, // GrandTotal
      chargeTypePageMapId: 38,
      levelType: 1,
      chargeTypeText: 'GrandTotal',
      typeText: null,
      pageName: 'SalesOrder',
      isCustom: false,
      isCustomSelected: false,
      label: 'Grand Total',
    ));

    // Calculate totals
    final totalQty =
        contractItems.fold(0.0, (sum, item) => sum + item.quantity);
    final totalConvAmount = _subTotal;
    final totalTax = _totalTaxAmount;
    final totalDiscount = _totalDiscountAmount;
    final totalShipCharge = _totalOtherChargeAmount;
    final totalAdjust = priceAdjustment;
    final netAmount = grandTotal;

    // Workflow fields:
    // Backend expects these even for Draft save in some environments.
    // Prefer values from workflow-get; fallback to loaded order values (edit mode).
    final int? processId = _workflowResponse?.id ?? _loadedOrderData?.processId;
    final int? processActionId = _workflowActions.isNotEmpty
        ? _workflowActions.first.processActionId
        : _loadedOrderData?.processActionId;

    // Set SaleOrderType based on role context to avoid null payloads.
    // Client rule:
    // if (IsDistributer == true || IsSalesRep == true) => 1, else => 0
    final bool isDistributer =
        _selectedDistributor != null && _selectedDistributor!.trim().isNotEmpty;
    final bool isSalesRep =
        _selectedSalesRep != null && _selectedSalesRep!.trim().isNotEmpty;
    final int saleOrderType = (isDistributer || isSalesRep) ? 1 : 0;

    // Get dynamic userId from user (login user)
    final dynamicUserId = user.userId;

    // Backend requirement:
    // - New (Submit / Save as new): UserId = login userId
    // - Edit / Amend: UserId = CreatedBy from GET response
    final int payloadUserId = _isEditMode
        ? (_loadedOrderData?.createdBy ??
            _loadedOrderData?.actualCreatedBy ??
            dynamicUserId)
        : dynamicUserId;

    // Console logging for dynamic values
    print('═══════════════════════════════════════════════════════════');
    print('📤 Sales Order Save - Dynamic Values');
    print('═══════════════════════════════════════════════════════════');
    print('Login User ID: $dynamicUserId (from user.userId)');
    print(
        'Payload UserId: $payloadUserId (${_isEditMode ? "EDIT/AMEND uses CreatedBy from GET" : "NEW uses login user"})');
    print(
        'Loaded Order CreatedBy (GET): ${_loadedOrderData?.createdBy}, ActualCreatedBy (GET): ${_loadedOrderData?.actualCreatedBy}');
    print('Customer ID: $customerId');
    print('Customer Name: ${_selectedCustomer?.name}');
    print(
        'Customer (field): ${_selectedCustomer?.name} (sending name instead of ID)');
    print('Sales Rep ID: $salesRepId');
    print('SbuId / Bizunit (DistributorId): $finalSbuId');
    print('Distributor ID (DistributerForId): $distributorId');
    print(
        'SaleOrderType: $saleOrderType (IsDistributer: $isDistributer, IsSalesRep: $isSalesRep)');
    print('WorkflowFlag: $workflowFlag');
    print('ProcessId: $processId');
    print('ProcessActionId: $processActionId');
    print('═══════════════════════════════════════════════════════════');

    return SalesOrderSaveRequest(
      id: _isEditMode && _loadedOrderData != null ? _loadedOrderData!.id : null,
      createdBy: dynamicUserId, // Dynamic userId from user
      status: 0,
      sbuId: finalSbuId, // Must be DistributorId per backend requirement
      company: 1, // Default - should be from user/config
      bizunit: finalBizUnit, // Must be DistributorId per backend requirement
      userId: payloadUserId,
      workflowFlag: workflowFlag,
      code: 'SO',
      department: 1, // Default - should be from user/config
      soNumber: _soNumber,
      customerName: _selectedCustomer?.name,
      typeText: _selectedType,
      currencyText: _selectedCurrency,
      amount: _subTotal,
      date: dateStr,
      customer: _selectedCustomer?.name, // Pass customer name instead of ID
      customerId: customerId,
      cusAddress: CustomerAddressController.text,
      customerRef: _customerPOController.text,
      type: typeId,
      currency: _selectedCurrency ?? 'LKR',
      currencyId: currencyId,
      exchangeRate: exchangeRate,
      deliveryDate: deliveryDateStr,
      totalAmount: _subTotal,
      refNo: _quotationNoController.text.isEmpty
          ? null
          : _quotationNoController.text,
      salesRep: salesRepId,
      salesRepName: _selectedSalesRep,
      salesContractItems: contractItems,
      fileUploadDetails:
          _isEditMode && _loadedOrderData?.fileUploadDetails != null
              ? _loadedOrderData!.fileUploadDetails
              : null,
      taxAndOtherChargesDetail: taxCharges,
      pageId: 3, // SalesOrder page ID
      processId: processId,
      processActionId: processActionId,
      menuId: 1110, // Should be from navigation/routing
      workflowStatus: 0,
      soStatus: 0,
      doCounts: 0,
      doCount: 0,
      isShortClosed: 0,
      isCancelled: 0,
      isClosed: 0,
      isCancel: _loadedOrderData?.isCancel is bool
          ? _loadedOrderData!.isCancel
          : (_loadedOrderData?.isCancel as bool? ??
              null), // Keep as bool (conversion to int happens in toJson)
      totalQuantity: totalQty,
      totalConvAmount: totalConvAmount,
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      totalShipCharge: totalShipCharge,
      totalAdjust: totalAdjust,
      netAmount: netAmount,
      netAmountBC: netAmount,
      divisionGroup: 2, // Should be from customer/product data
      isBonusSO: _isBonusSO,
      bonusEnabled: _isBonusEnabled,
      vatRegistered: true, // Should be from customer data
      taxInclusive: false, // Should be from config
      distributerForId: distributorId, // Important: Pass selected DistributerId
      saleOrderType: saleOrderType,
      isFullyUsed: _loadedOrderData?.isFullyUsed ??
          0, // Use from loaded data or default to 0
      hasEdit: _loadedOrderData?.hasEdit ??
          false, // Use from loaded data or default to false
      despatchedQty: _isEditMode ? _loadedOrderData?.despatchedQty : null,
      despatchNo: _isEditMode ? _loadedOrderData?.despatchNo : null,
      actualCreatedBy:
          dynamicUserId, // Actual logged-in user ID (required for save to work)
    );
  }

  void _onSave() {
    // Local/dev save handler – still enforce item validation
    if (!_validateItemsForSaveOrSubmit()) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Saved (local only)')));
  }

  /// Validate that at least one order item exists AND
  /// every added item has all required fields filled.
  ///
  /// Required fields per item:
  /// - Item selected
  /// - Quantity > 0
  /// - Rate > 0
  /// - UOM selected
  bool _validateItemsForSaveOrSubmit() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one order item before saving.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];

      final bool hasProduct = item.product.id != '0' &&
          item.itemDescriptionController.text.trim().isNotEmpty;
      final double qty = double.tryParse(item.qtyController.text.trim()) ?? 0.0;
      final double rate =
          double.tryParse(item.rateController.text.trim()) ?? 0.0;
      final bool hasUom =
          item.selectedUOM != null && item.selectedUOM!.trim().isNotEmpty;

      if (!hasProduct || qty <= 0 || rate <= 0 || !hasUom) {
        final int itemNumber = i + 1;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please fill all required fields (Item, Qty, Rate, UOM) for order item #$itemNumber.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      // Bonus Qty must be <= calculated bonus qty (when we have a calculated value).
      item.validateBonusQty();
      if (item.bonusQtyError != null && item.bonusQtyError!.isNotEmpty) {
        final int itemNumber = i + 1;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item $itemNumber: ${item.bonusQtyError}'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _onSaveDraft() async {
    // Prevent saving draft if items are missing or incomplete
    if (!_validateItemsForSaveOrSubmit()) {
      return;
    }
    // Determine WorkflowFlag:
    // - WorkflowFlag = 0 if draft saving before submit (not yet submitted)
    // - WorkflowFlag = 1 if draft saving after submit (already submitted)
    final int workflowFlag = _hasBeenSubmitted ? 1 : 0;

    print(
        '💾 Saving as Draft with WorkflowFlag: $workflowFlag (HasBeenSubmitted: $_hasBeenSubmitted)');

    try {
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      // Build save request
      final request = await _buildSaveRequest(workflowFlag);

      // Call save API (upload attachments if any)
      final salesRepository = getIt<SalesRepository>();
      final response = await salesRepository.saveSalesOrder(
        request,
        files: _attachments.isEmpty ? null : _attachments,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (response.success) {
        // Update order ID if this is a new order
        if (response.data is Map && response.data['id'] != null) {
          final savedOrderId = response.data['id'];
          print('✅ Order saved with ID: $savedOrderId');

          if (!_isEditMode) {
            // For new orders, navigate back to listing screen with success result
            ToastMessage.show(
              context,
              message: 'Order drafted successfully',
              type: ToastType.success,
              icon: Icons.check_circle_outline,
              duration: const Duration(seconds: 2),
            );
            // Pop with result to trigger refresh in listing screen
            Navigator.of(context).pop(true);
            return;
          }
        }

        ToastMessage.show(
          context,
          message: 'Draft order edited successfully',
          type: ToastType.success,
          icon: Icons.check_circle_outline,
        );
      } else {
        throw Exception(response.message ?? 'Failed to save order');
      }
    } catch (e) {
      print('❌ Error saving draft: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      final errorString = e.toString();
      final bool is500 = errorString.contains('500') ||
          errorString.toLowerCase().contains('internal server error');
      if (is500) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error while saving'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // Extract error message
      String errorMessage = 'Failed to save draft';
      if (errorString.startsWith('Exception: ')) {
        errorMessage = errorString.replaceFirst('Exception: ', '');
      } else {
        errorMessage = errorString;
      }

      // Show error dialog for better readability
      _showErrorDialog('Error Saving Draft', errorMessage);
    }
  }

  Future<void> _onSubmitForApproval() async {
    // Prevent submit if items are missing or incomplete
    if (!_validateItemsForSaveOrSubmit()) {
      return;
    }
    // Always pass WorkflowFlag = 1 for submit
    final int workflowFlag = 1;

    print('📤 Submitting for Approval with WorkflowFlag: $workflowFlag');

    try {
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      // Build save request with WorkflowFlag = 1
      final request = await _buildSaveRequest(workflowFlag);

      // Call save API (upload attachments if any)
      final salesRepository = getIt<SalesRepository>();
      final response = await salesRepository.saveSalesOrder(
        request,
        files: _attachments.isEmpty ? null : _attachments,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        // Mark as submitted on success
        _hasBeenSubmitted = true;
      });

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order submitted for approval successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Navigate back to listing screen with success result
        if (!_isEditMode || true) {
          // Pop with result to trigger refresh in listing screen
          Navigator.of(context).pop(true);
          return;
        }
      } else {
        throw Exception(response.message ?? 'Failed to submit order');
      }
    } catch (e) {
      print('❌ Error submitting order: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      final errorString = e.toString();
      final bool is500 = errorString.contains('500') ||
          errorString.toLowerCase().contains('internal server error');
      if (is500) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error while saving'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // Extract error message
      String errorMessage = 'Failed to submit order';
      if (errorString.startsWith('Exception: ')) {
        errorMessage = errorString.replaceFirst('Exception: ', '');
      } else {
        errorMessage = errorString;
      }

      // Show error dialog for better readability
      _showErrorDialog('Error Submitting Order', errorMessage);
    }
  }

  /// Show error dialog with title and message
  void _showErrorDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color? _parseColorFromHex(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return null;
    try {
      // Remove # if present
      String hex = hexColor.replaceAll('#', '');
      // Handle 3-character hex colors
      if (hex.length == 3) {
        hex = hex.split('').map((char) => char + char).join();
      }
      // Parse to int and create Color
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      print('Error parsing color: $hexColor - $e');
      return null;
    }
  }

  /// Handle Modify Order action - calls Save API with WorkflowFlag = 0
  Future<void> _handleModifyOrder() async {
    try {
      // Show loading indicator
      if (!mounted) return;
      setState(() => _isActionsMenuOpen = false);

      setState(() {
        _isLoading = true;
      });

      // Build save request with WorkflowFlag = 0 for Modify
      final request = await _buildSaveRequest(0);

      // Call save API (upload attachments if any)
      final salesRepository = getIt<SalesRepository>();
      final response = await salesRepository.saveSalesOrder(
        request,
        files: _attachments.isEmpty ? null : _attachments,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (response.success) {
        ToastMessage.show(
          context,
          message: 'Sales order ${_loadedOrderData?.soNumber ?? 'SO-${_loadedOrderData?.id ?? ''}'} modified successfully',
          type: ToastType.success,
          icon: Icons.check_circle_outline,
          duration: const Duration(seconds: 2),
        );
        // Navigate back to listing screen
        Navigator.of(context).pop(true);
      } else {
        throw Exception(response.message ?? 'Failed to modify order');
      }
    } catch (e) {
      print('❌ Error modifying order: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Extract error message
      String errorMessage = 'Failed to modify order';
      final errorString = e.toString();
      if (errorString.startsWith('Exception: ')) {
        errorMessage = errorString.replaceFirst('Exception: ', '');
      } else {
        errorMessage = errorString;
      }

      // Show error dialog for better readability
      _showErrorDialog('Error Modifying Order', errorMessage);
    }
  }

  /// Handle Cancel Order action with confirmation
  Future<void> _handleCancelOrder() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Sales Order'),
          content: Text(
            'Are you sure you want to cancel sales order ${_loadedOrderData?.soNumber ?? 'SO-${_loadedOrderData?.id ?? ''}'}? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return; // User cancelled
    }

    // Show loading indicator
    if (!mounted) return;
    setState(() => _isActionsMenuOpen = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Get ProcessId from workflow response
      final processId = _workflowResponse?.id ?? _loadedOrderData?.processId;

      if (processId == null || processId == 0) {
        throw Exception('Process ID not available. Cannot cancel order.');
      }

      // Get Transaction Id (order id)
      final transactionId = _loadedOrderData?.id;
      if (transactionId == null) {
        throw Exception('Transaction ID not available.');
      }

      // Build cancel request
      final cancelRequest = SalesOrderTransactionCancelRequest(
        poId: null,
        id: transactionId,
        itemId: null,
        vendorId: null,
        processId: processId,
      );

      // Call cancel API
      final salesRepository = getIt<SalesRepository>();
      await salesRepository.transactionCancelSalesOrder(cancelRequest);

      // Close loading indicator
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show success message at top as snackbar-style toast
      if (!mounted) return;
      ToastMessage.show(
        context,
        message: 'Sales order ${_loadedOrderData?.soNumber ?? 'SO-${_loadedOrderData?.id ?? ''}'} cancelled successfully',
        type: ToastType.success,
        icon: Icons.check_circle_outline,
        duration: const Duration(seconds: 2),
      );
      // Navigate back to listing screen
      Navigator.of(context).pop(true);
    } catch (e) {
      // Close loading indicator
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show error message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel sales order: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Handle Delete Order action with confirmation.
  /// API: /api/SaleOrder/Delete with Id = Transaction Id.
  Future<void> _handleDeleteOrder() async {
    if (!_isEditMode || _loadedOrderData == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Sales Order'),
          content: Text(
            'Are you sure you want to delete sales order ${_loadedOrderData?.soNumber ?? 'SO-${_loadedOrderData?.id ?? ''}'}? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Yes, Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _isActionsMenuOpen = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final transactionId = _loadedOrderData!.id;
      if (transactionId == null) {
        throw Exception('Transaction ID not available.');
      }

      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();
      if (user == null) {
        throw Exception('User not available');
      }
      final userId = user.userId ?? user.id;

      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      int? bizUnitFromStore = userStore?.userDetail?.sbuId;
      int? bizUnitFromPrefs = user.sbuId;
      final int bizUnit = (bizUnitFromStore != null && bizUnitFromStore > 0)
          ? bizUnitFromStore
          : ((bizUnitFromPrefs != null && bizUnitFromPrefs > 0)
              ? bizUnitFromPrefs
              : 1);

      final salesRepository = getIt<SalesRepository>();
      await salesRepository.deleteSalesOrder(
        id: transactionId,
        bizunit: bizUnit,
        userId: userId,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (!mounted) return;
      ToastMessage.show(
        context,
        message: 'Sales order ${_loadedOrderData?.soNumber ?? 'SO-${_loadedOrderData?.id ?? ''}'} deleted successfully',
        type: ToastType.success,
        icon: Icons.check_circle_outline,
        duration: const Duration(seconds: 2),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete sales order: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _onWorkflowAction(ProcessActionDetail action) async {
    // Prevent executing workflow actions (Submit / Approve / etc.)
    // when items are missing or incomplete.
    if (!_validateItemsForSaveOrSubmit()) {
      return;
    }

    // Backend requires WorkflowFlag = 1 for Save/Amend; actionValue identifies the action (e.g. 15 for Amend)
    const int workflowFlag = 1;

    print(
        '📤 Executing workflow action: ${action.name} with WorkflowFlag: $workflowFlag, ActionValue: ${action.actionValue}');

    try {
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      // Build save request with WorkflowFlag = 1 (required for workflow/amendment processing)
      final request = await _buildSaveRequest(workflowFlag);

      // Update processId (use actionValue per client example, e.g. 15 for Amend), processActionId and actionValue
      final updatedRequest = SalesOrderSaveRequest(
        id: request.id,
        createdBy: request.createdBy,
        status: request.status,
        sbuId: request.sbuId,
        company: request.company,
        bizunit: request.bizunit,
        userId: request.userId,
        workflowFlag: workflowFlag,
        code: request.code,
        department: request.department,
        soNumber: request.soNumber,
        customerName: request.customerName,
        typeText: request.typeText,
        currencyText: request.currencyText,
        amount: request.amount,
        date: request.date,
        itemName: request.itemName,
        bonusQuantity: request.bonusQuantity,
        additionalBonusQuantity: request.additionalBonusQuantity,
        customer: request.customer,
        customerId: request.customerId,
        cusAddress: request.cusAddress,
        customerRef: request.customerRef,
        type: request.type,
        currency: request.currency,
        currencyId: request.currencyId,
        exchangeRate: request.exchangeRate,
        deliveryDate: request.deliveryDate,
        totalAmount: request.totalAmount,
        refNo: request.refNo,
        quotationHeaderId: request.quotationHeaderId,
        statusText: request.statusText,
        salesRep: request.salesRep,
        salesRepName: request.salesRepName,
        taxId: request.taxId,
        salesContractItems: request.salesContractItems,
        fileUploadDetails: request.fileUploadDetails,
        taxAndOtherChargesDetail: request.taxAndOtherChargesDetail,
        pageId: request.pageId,
        refid: request.refid,
        processId: action.processID,
        processActionId: action.processActionId,
        processName: action.name, // e.g. "Amend", "Submit" per client payload
        menuId: request.menuId,
        moduleId: request.moduleId,
        module: request.module,
        workflowStatus: request.workflowStatus,
        workflowComment: request.workflowComment,
        currencyBC: request.currencyBC,
        totalQuantity: request.totalQuantity,
        totalConvAmount: request.totalConvAmount,
        totalDiscount: request.totalDiscount,
        totalTax: request.totalTax,
        totalShipCharge: request.totalShipCharge,
        totalAdjust: request.totalAdjust,
        netAmount: request.netAmount,
        netAmountBC: request.netAmountBC,
        division: request.division,
        divisionGroup: request.divisionGroup,
        divisionText: request.divisionText,
        divisionGroupText: request.divisionGroupText,
        divisionGroupName: request.divisionGroupName,
        actionValue: action.actionValue.toString(), // e.g. 15 for Amend
        saleOrderShortCloseReason: request.saleOrderShortCloseReason,
        saleOrderShortCloseRefNo: request.saleOrderShortCloseRefNo,
        checkFlag: request.checkFlag,
        pageType: request.pageType,
        poNo: request.poNo,
        tenderNo: request.tenderNo,
        reqNo: request.reqNo,
        soStatus: request.soStatus,
        isCancel: request.isCancel,
        isFullyUsed: request.isFullyUsed ?? 0, // Default to 0 if null
        doCounts: request.doCounts,
        doCount: request.doCount,
        isShortClosed: request.isShortClosed,
        isCancelled: request.isCancelled,
        isClosed: request.isClosed,
        decimalFormat: request.decimalFormat,
        rateFormat: request.rateFormat,
        hasEdit: request.hasEdit,
        despatchedQty: request.despatchedQty,
        invoiceNo: request.invoiceNo,
        despatchNo: request.despatchNo,
        isFullyUsedText: request.isFullyUsedText,
        deliveryAddress: request.deliveryAddress,
        isCustomerPODuplicateAllowed: request.isCustomerPODuplicateAllowed,
        distributerForId: request.distributerForId,
        actualCreatedBy: request.actualCreatedBy,
        saleOrderType: request.saleOrderType,
        isBonusSO: request.isBonusSO,
        soType: request.soType,
        isSalesRepEdit: request.isSalesRepEdit,
        vatRegistered: request.vatRegistered,
        taxInclusive: request.taxInclusive,
        bonusEnabled: request.bonusEnabled,
      );

      // Call save API (upload attachments if any)
      final salesRepository = getIt<SalesRepository>();
      final response = await salesRepository.saveSalesOrder(
        updatedRequest,
        files: _attachments.isEmpty ? null : _attachments,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        // Mark as submitted on success if action is Submit
        if (action.name.toLowerCase() == 'submit' || workflowFlag == 1) {
          _hasBeenSubmitted = true;
        }
      });

      if (response.success) {
        ToastMessage.show(
          context,
          message: 'Order ${action.name} successfully',
          type: ToastType.success,
          icon: Icons.check_circle_outline,
          duration: const Duration(seconds: 2),
        );
        // Navigate back to listing screen with success result
        Navigator.of(context).pop(true);
        return;
      } else {
        throw Exception(response.message ?? 'Failed to ${action.name} order');
      }
    } catch (e) {
      print('❌ Error executing workflow action ${action.name}: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Extract error message
      String errorMessage = 'Failed to ${action.name.toLowerCase()} order';
      final errorString = e.toString();
      if (errorString.startsWith('Exception: ')) {
        errorMessage = errorString.replaceFirst('Exception: ', '');
      } else {
        errorMessage = errorString;
      }

      // Show error dialog for better readability
      _showErrorDialog('Error ${action.name}', errorMessage);
    }
  }
}

class _ItemCard extends StatelessWidget {
  final int index;
  final int totalCount;
  final _LineItem item;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final VoidCallback onToggle; // explicit toggle button + header tap
  final String Function(double) formatCurrency;
  final Future<void> Function(_LineItem, int, [String?, VoidCallback?])
      loadUOMForItem;
  final Future<void> Function(_LineItem, int, [VoidCallback?]) loadTaxForItem;
  final Future<void> Function(_LineItem, int, [VoidCallback?]) loadItemDetail;
  final Future<void> Function(_LineItem, int, [VoidCallback?])
      calculateBonusForItem;
  final Future<void> Function(_LineItem, int, [VoidCallback?])
      calculateDiscountForItem;
  final String Function(DateTime) formatDate;
  final bool isEditMode;
  final int Function() getDistributorId;

  const _ItemCard({
    required this.index,
    required this.totalCount,
    required this.item,
    required this.onRemove,
    required this.onChanged,
    required this.onToggle,
    required this.formatCurrency,
    required this.loadUOMForItem,
    required this.loadTaxForItem,
    required this.loadItemDetail,
    required this.calculateBonusForItem,
    required this.calculateDiscountForItem,
    required this.formatDate,
    required this.isEditMode,
    required this.getDistributorId,
  });

  @override
  Widget build(BuildContext context) {
    final bool canRemove = totalCount > 1;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
// Title Row (tappable + explicit toggle button)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Text(
                      'Item Details #${index + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151)),
                    ),
                  ),
                ),
              ),
              if (canRemove)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  tooltip: 'Remove',
                ),
              IconButton(
                onPressed: onToggle,
                tooltip: item.expanded ? 'Collapse' : 'Expand',
                icon: Icon(
                  item.expanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (item.expanded) ...[
            // Item Description (full width)
            _SearchableItemField(
              label: 'Item Description*',
              controller: item.itemDescriptionController,
              selectedProduct: item.product,
              onProductSelected: (product) {
                print(
                    '🔵 [onProductSelected] Product selected: ${product.name}, Rate: ${product.rate}, MRP: ${product.mrp}');

                // Set product which will populate Rate and MRP
                item.setProduct(product);

                // Ensure quantity defaults to 1 if empty for amount calculation
                if (item.qtyController.text.isEmpty ||
                    item.qtyController.text == '0') {
                  item.qtyController.text = '1';
                  print('🔵 [onProductSelected] Set default quantity to 1');
                }

                // Load item details (MRP, Rate, etc.) from GetItemDetail API
                final itemId = int.tryParse(product.id) ?? 0;
                print(
                    '🔵 [onProductSelected] Requesting GetItemDetail for itemId=$itemId (full API dump follows in console when customer + date are set)');
                if (itemId > 0) {
                  // Load item detail first to get accurate MRP and Rate
                  loadItemDetail(item, itemId, onChanged);
                  // Then load UOM and Tax
                  loadUOMForItem(item, itemId, null, onChanged);
                  loadTaxForItem(item, itemId, onChanged);
                  calculateBonusForItem(item, itemId, onChanged);
                  calculateDiscountForItem(item, itemId, onChanged);
                }

                // Verify Rate and MRP are set
                print(
                    '🔵 [onProductSelected] After setProduct - RateController: "${item.rateController.text}", MRPController: "${item.mrpController.text}"');
                print(
                    '🔵 [onProductSelected] Calculated Amount: ${item.amount}, Total Amount: ${item.totalAmount}');

                // Trigger recalculation of totals after setting product
                // This will rebuild the UI with updated Rate, MRP, Amount, and Total Amount
                onChanged();
              },
              getDistributorId: getDistributorId,
            ),
            const SizedBox(height: 16),

            // Row: Quantity & UOM
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: 'Quantity*',
                    controller: item.qtyController,
                    min: 0,
                    onChanged: (v) {
                      onChanged();
                      item.debouncePricingRecalculation(() {
                        final itemId = int.tryParse(item.product.id) ?? 0;
                        if (itemId > 0) {
                          calculateBonusForItem(item, itemId, onChanged);
                          calculateDiscountForItem(item, itemId, onChanged);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SearchableUOMField(
                    label: 'UOM',
                    selectedUOM: item.selectedUOM,
                    uomOptions: item.uomOptions,
                    isLoading: false,
                    onUOMSelected: (uom) {
                      item.selectedUOM = uom;
                      onChanged();
                    },
                    onLoadUOM: (itemId) async {
                      if (itemId > 0) {
                        try {
                          final commonRepository = getIt<CommonRepository>();
                          final uomList =
                              await commonRepository.getUOMList(itemId: itemId);
                          final newUomOptions =
                              uomList.map((item) => item.text).toList();
                          item.uomOptions = newUomOptions;
                          // Preserve existing UOM if it exists in options, otherwise auto-select first only if no UOM is set
                          if (item.uomOptions.isNotEmpty) {
                            if (item.selectedUOM != null &&
                                item.uomOptions.contains(item.selectedUOM)) {
                              // Keep existing UOM if it's in the options
                              print(
                                  '✅ Preserving existing UOM: ${item.selectedUOM}');
                            } else if (item.selectedUOM == null ||
                                item.selectedUOM!.isEmpty) {
                              // Only auto-select first if no UOM is currently set
                              item.selectedUOM = item.uomOptions.first;
                              print(
                                  '✅ Auto-selected first UOM: ${item.selectedUOM}');
                            } else {
                              // If existing UOM is not in options, try to find a match (case-insensitive)
                              final existingUOM = item.selectedUOM!;
                              final matchedUOM = item.uomOptions.firstWhere(
                                (uom) =>
                                    uom.toLowerCase() ==
                                    existingUOM.toLowerCase(),
                                orElse: () => item.uomOptions.first,
                              );
                              item.selectedUOM = matchedUOM;
                              print(
                                  '✅ Matched UOM: ${item.selectedUOM} (was: $existingUOM)');
                            }
                          } else {
                            // If no options, keep existing UOM or set to null
                            if (item.selectedUOM == null ||
                                item.selectedUOM!.isEmpty) {
                              item.selectedUOM = null;
                            }
                          }
                          onChanged();
                        } catch (e) {
                          print('Error loading UOM: $e');
                        }
                      }
                    },
                    itemId: int.tryParse(item.product.id) ?? 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row: Rate & MRP
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      // Calculate Rate value from controller or product rate
                      final rateValue = item.rateController.text.isNotEmpty
                          ? double.tryParse(item.rateController.text) ?? 0.0
                          : (item.product.rate > 0 ? item.product.rate : 0.0);

                      return _ReadonlyField(
                        label: 'Rate*',
                        value: rateValue > 0 ? formatCurrency(rateValue) : '',
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      // Calculate MRP value from controller or product mrp
                      final mrpValue = item.mrpController.text.isNotEmpty
                          ? double.tryParse(item.mrpController.text) ?? 0.0
                          : (item.product.mrp != null && item.product.mrp! > 0
                              ? item.product.mrp!
                              : 0.0);

                      return _ReadonlyField(
                        label: 'MRP*',
                        value: mrpValue > 0 ? formatCurrency(mrpValue) : '',
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row: Amount & Disc
            Row(
              children: [
                Expanded(
                  child: _ReadonlyField(
                    label: 'Amount',
                    value:
                        item.amount == 0.0 ? '' : formatCurrency(item.amount),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ReadonlyField(
                    label: 'Disc',
                    value: formatCurrency(item.discount),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row: Bonus Qty & Addl. Bonus
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        label: 'Bonus Qty',
                        controller: item.bonusQtyController,
                        min: 0,
                        highlightError: item.bonusQtyError != null &&
                            item.bonusQtyError!.isNotEmpty,
                        suffixIcon: (item.bonusQtyError != null &&
                                item.bonusQtyError!.isNotEmpty)
                            ? const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFDC2626),
                              )
                            : null,
                        onChanged: (v) {
                          item.validateBonusQty();
                          onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NumberField(
                        label: 'Addl. Bonus',
                        controller: item.addlBonusQtyController,
                        min: 0,
                        onChanged: (v) => onChanged(),
                      ),
                    ),
                  ],
                ),
                if (item.bonusQtyError != null &&
                    item.bonusQtyError!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.bonusQtyError!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Row: Total Amount & Reqd. date
            Row(
              children: [
                Expanded(
                  child: _ReadonlyField(
                    label: 'Total Amount',
                    value: item.totalAmount == 0.0
                        ? ''
                        : formatCurrency(item.totalAmount),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ReadonlyField(
                    label: 'Reqd. date',
                    value: formatDate(item.requiredDate),
                  ),
                ),
              ],
            ),
            // Remarks field (available in both create and edit mode)
            const SizedBox(height: 16),
            _TextField(
              label: 'Remarks',
              controller: item.remarksController,
              hintText: 'Enter remarks...',
              maxLines: 3,
              onChanged: (v) => onChanged(),
            ),
          ],
        ],
      ),
    );
  }
}

class _LineItem {
  Product product;
  DateTime requiredDate;

  final TextEditingController itemDescriptionController;
  final TextEditingController qtyController;
  final TextEditingController bonusQtyController;
  final TextEditingController addlBonusQtyController;
  final TextEditingController rateController; // Added for rate input
  final TextEditingController mrpController; // MRP field
  final TextEditingController discountController; // Discount field
  double? taxAmount; // Per-line tax amount from API/selection
  TextEditingController?
      _remarksController; // Remarks field - nullable for hot reload compatibility
  String? selectedUOM; // UOM dropdown value
  List<String> uomOptions = []; // UOM options from API
  List<CommonDropdownItem> uomItems = []; // UOM items with IDs from API
  String? selectedTax; // Tax dropdown value
  List<String> taxOptions = []; // Tax options from API

  bool expanded;
  Timer? _pricingDebounceTimer;
  int? calculatedBonusQuantity;
  String? bonusQtyError;

  /// Contract line detail Id from API (when editing). Sent as SalesContractItem.Id so backend can match and validate dispatched qty.
  int? detailId;

  /// Dispatched quantity from API (when editing). Quantity sent on save must be >= this.
  int? despatchedQty;

  // Getter for remarksController that initializes if null (for hot reload compatibility)
  TextEditingController get remarksController {
    _remarksController ??= TextEditingController();
    return _remarksController!;
  }

  _LineItem({
    required this.product,
    required this.requiredDate,
    required this.itemDescriptionController,
    required this.qtyController,
    required this.bonusQtyController,
    required this.addlBonusQtyController,
    required this.rateController,
    required this.mrpController,
    required this.discountController,
    this.taxAmount,
    TextEditingController? remarksController,
    this.selectedUOM,
    this.selectedTax,
    this.expanded = true,
    this.detailId,
    this.despatchedQty,
    this.calculatedBonusQuantity,
    this.bonusQtyError,
  }) : _remarksController = remarksController ?? TextEditingController();

  factory _LineItem.fromProduct(
    Product product, {
    DateTime? reqDate,
    int qty = 1,
    int bonusQty = 0,
    int addlBonusQty = 0,
    String? itemDescription,
    double? rate,
    double? mrp,
    double? discount,
    double? taxAmount,
    String? uom,
    String? remarks,
    bool expanded = true,
  }) {
    return _LineItem(
      product: product,
      requiredDate: reqDate ?? DateTime.now(),
      itemDescriptionController: TextEditingController(
        text: itemDescription ?? '',
      ),
      qtyController: TextEditingController(text: qty > 0 ? qty.toString() : ''),
      bonusQtyController: TextEditingController(text: bonusQty.toString()),
      addlBonusQtyController:
          TextEditingController(text: addlBonusQty.toString()),
      rateController: TextEditingController(
          text: rate != null ? rate.toStringAsFixed(2) : ''),
      mrpController: TextEditingController(
          text: mrp != null ? mrp.toStringAsFixed(2) : ''),
      discountController: TextEditingController(
          text: discount != null ? discount.toStringAsFixed(2) : '0.00'),
      taxAmount: taxAmount,
      remarksController: TextEditingController(text: remarks ?? ''),
      selectedUOM: uom,
      selectedTax: null, // Will be auto-selected when item is selected
      expanded: expanded,
      calculatedBonusQuantity: 0,
      bonusQtyError: null,
    );
  }

  void setProduct(Product newProduct) {
    product = newProduct;
    itemDescriptionController.text = newProduct.name;

    // Automatically set Rate from product.rate
    if (newProduct.rate > 0) {
      rateController.text = newProduct.rate.toStringAsFixed(2);
      print('✅ [setProduct] Set Rate: ${newProduct.rate.toStringAsFixed(2)}');
    } else {
      rateController.clear();
      print('⚠️ [setProduct] Product rate is 0 or empty, cleared Rate field');
    }

    // Automatically set MRP from product.mrp if available
    if (newProduct.mrp != null && newProduct.mrp! > 0) {
      mrpController.text = newProduct.mrp!.toStringAsFixed(2);
      print('✅ [setProduct] Set MRP: ${newProduct.mrp!.toStringAsFixed(2)}');
    } else {
      mrpController.clear();
      print('⚠️ [setProduct] Product MRP is null or 0, cleared MRP field');
    }

    // Recalculate Amount and Total Amount
    // Amount = Rate * Quantity (will be calculated via getter)
    // Total Amount = Quantity * Rate (will be calculated via getter, updates automatically when quantity changes)

    selectedUOM = null; // Will be auto-selected when UOM loads
  }

  double get amount {
    final qty = double.tryParse(qtyController.text) ?? 0.0;
    final rate = double.tryParse(rateController.text) ?? 0.0;
    return rate * qty;
  }

  double get discount {
    return double.tryParse(discountController.text) ?? 0.0;
  }

  double get totalAmount {
    return amount - discount;
  }

  double get lineTotal => totalAmount;

  void validateBonusQty() {
    final entered = int.tryParse(bonusQtyController.text.trim()) ?? 0;
    final calculated = calculatedBonusQuantity ?? 0;
    if (entered > calculated) {
      bonusQtyError = 'Cannot add bonus for product with no approved bonus';
    } else {
      bonusQtyError = null;
    }
  }

  void debouncePricingRecalculation(
    VoidCallback action, {
    Duration delay = const Duration(milliseconds: 450),
  }) {
    _pricingDebounceTimer?.cancel();
    _pricingDebounceTimer = Timer(delay, action);
  }

  void dispose() {
    _pricingDebounceTimer?.cancel();
    itemDescriptionController.dispose();
    qtyController.dispose();
    bonusQtyController.dispose();
    addlBonusQtyController.dispose();
    rateController.dispose();
    mrpController.dispose();
    discountController.dispose();
    _remarksController?.dispose();
  }
}

// Tax/Charge Row Model
class _TaxChargeRow {
  final String id;
  String? selectedType;
  final TextEditingController valueController;
  final String rowType; // 'tax', 'discount', 'otherCharge'

  // For Custom discount: checkbox state and percentage input
  bool isPercentageEnabled = false;
  final TextEditingController percentageController;

  /// When editing: API id of this charge row (from taxAndOtherChargesDetail). Send back on save to avoid 500.
  int? chargeDetailApiId;

  _TaxChargeRow({
    required this.id,
    this.selectedType,
    required this.rowType,
    this.isPercentageEnabled = false,
    this.chargeDetailApiId,
  })  : valueController = TextEditingController(text: ''),
        percentageController = TextEditingController(text: '');

  double get value => double.tryParse(valueController.text) ?? 0.0;

  double get percentageValue =>
      double.tryParse(percentageController.text) ?? 0.0;

  void dispose() {
    valueController.dispose();
    percentageController.dispose();
  }
}

// Reusable form widgets
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade700,
        letterSpacing: 0.1,
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  const _DateField(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 800;
    final border = OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(10),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        if (label.isNotEmpty) const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 14,
                vertical: isTablet ? 16 : 14,
              ),
              suffixIcon:
                  const Icon(Icons.event, size: 20, color: Color(0xFF4db1b3)),
              filled: true,
              fillColor: Colors.white,
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide:
                    const BorderSide(color: Color(0xFF4db1b3), width: 2),
              ),
            ),
            child: Text(
              DateFormat('dd-MMM-yyyy').format(value),
              style: GoogleFonts.inter(
                fontSize: isTablet ? 15 : 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF111827),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadonlyDateField extends StatelessWidget {
  final DateTime? value;

  const _ReadonlyDateField({this.value});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 800;
    final border = OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(10),
    );

    return InputDecorator(
      decoration: InputDecoration(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 14,
          vertical: isTablet ? 16 : 14,
        ),
        suffixIcon: const Icon(Icons.event, size: 20, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: border,
        enabledBorder: border,
        disabledBorder: border,
      ),
      child: Text(
        value != null ? _formatDate(value!) : '--',
        style: GoogleFonts.inter(
          fontSize: isTablet ? 15 : 14,
          fontWeight: FontWeight.w500,
          color: value != null ? const Color(0xFF111827) : Colors.grey.shade500,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd-MMM-yyyy').format(date);
  }
}

class _DropdownField<T> extends StatefulWidget {
  final String label;
  final T? value;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final Widget? footer;
  final bool searchable;
  final bool enabled;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    this.hint,
    this.onChanged,
    this.footer,
    this.searchable = true,
    this.enabled = true,
  });

  @override
  State<_DropdownField<T>> createState() => _DropdownFieldState<T>();
}

class _DropdownFieldState<T> extends State<_DropdownField<T>> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  List<MapEntry<T, String>> get _options => [
        for (final it in widget.items)
          if (it.value != null)
            MapEntry(
              it.value as T,
              (it.child is Text)
                  ? (((it.child as Text).data) ?? it.value.toString())
                  : it.value.toString(),
            ),
      ];

  String _labelForValue(T? v) {
    if (v == null) return '';
    for (final item in widget.items) {
      if (item.value == v) {
        final child = item.child;
        if (child is Text) {
          return child.data ?? child.toString();
        }
        return v.toString();
      }
    }
    return v.toString();
  }

  void _open() {
    if (!widget.enabled) return;
    if (!widget.searchable) return;
    if (_isOpen) return;
    _overlayEntry = _buildOverlay();
    Overlay.of(context, rootOverlay: false)?.insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
    });
  }

  void _close() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_isOpen) {
      setState(() {
        _isOpen = false;
      });
    }
  }

  OverlayEntry _buildOverlay() {
    final border = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(8),
    );
    List<MapEntry<T, String>> filtered = List.of(_options);

    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 48),
              child: Material(
                elevation: 8,
                shadowColor: Colors.black.withOpacity(0.15),
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxHeight: 360, minWidth: 240),
                  child: SizedBox(
                    width: _fieldSize()?.width,
                    height: 360,
                    child: StatefulBuilder(
                      builder: (context, setSheetState) {
                        void applyFilter(String q) {
                          setSheetState(() {
                            final query = q.toLowerCase();
                            filtered = _options
                                .where((e) =>
                                    e.value.toLowerCase().contains(query))
                                .toList(growable: false);
                          });
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                style: GoogleFonts.inter(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Search...',
                                  hintStyle: GoogleFonts.inter(
                                      color: Colors.grey.shade500),
                                  prefixIcon: const Icon(Icons.search,
                                      color: Color(0xFF4db1b3)),
                                ),
                                onChanged: applyFilter,
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFFF3F4F6)),
                            Expanded(
                              child: ListView.separated(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                shrinkWrap: false,
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  color: Color(0xFFF3F4F6),
                                ),
                                itemBuilder: (context, index) {
                                  final entry = filtered[index];
                                  final bool isSelected =
                                      widget.value == entry.key;
                                  return ListTile(
                                    dense: true,
                                    title: Text(entry.value),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle,
                                            color: Color(0xFF2563EB))
                                        : null,
                                    onTap: () {
                                      widget.onChanged?.call(entry.key);
                                      _close();
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
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
  }

  Size? _fieldSize() {
    final renderBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 800;
    final border = OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(10),
    );
    final filledBackground =
        !widget.enabled ? const Color(0xFFF3F4F6) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(widget.label),
        if (widget.label.isNotEmpty) const SizedBox(height: 8),
        CompositedTransformTarget(
          link: _layerLink,
          child: InkWell(
            key: _fieldKey,
            onTap: widget.enabled ? _open : null,
            child: InputDecorator(
              decoration: InputDecoration(
                hintText: widget.hint,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 16 : 14,
                  vertical: isTablet ? 16 : 14,
                ),
                filled: true,
                fillColor: filledBackground,
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                  borderSide: widget.enabled
                      ? const BorderSide(color: Color(0xFF4db1b3), width: 2)
                      : border.borderSide,
                ),
                disabledBorder: border,
                hintStyle: GoogleFonts.inter(
                  fontSize: isTablet ? 15 : 14,
                  color: Colors.grey.shade400,
                ),
                suffixIcon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: widget.enabled
                      ? const Color(0xFF4db1b3)
                      : Colors.grey.shade400,
                ),
              ),
              child: Text(
                widget.value == null
                    ? (widget.hint ?? '')
                    : _labelForValue(widget.value),
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 15 : 14,
                  fontWeight: FontWeight.w500,
                  color: widget.enabled
                      ? (widget.value == null
                          ? Colors.grey.shade400
                          : const Color(0xFF111827))
                      : Colors.grey.shade500,
                ),
              ),
            ),
          ),
        ),
        if (widget.footer != null) ...[
          const SizedBox(height: 6),
          widget.footer!,
        ],
      ],
    );
  }
}

class _TextAreaField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final int minLines;
  final int maxLines;
  final InputBorder? border;

  const _TextAreaField({
    required this.label,
    required this.controller,
    this.hintText,
    this.minLines = 2,
    this.maxLines = 4,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final baseBorder = border ??
        OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(10),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: baseBorder,
            enabledBorder: baseBorder,
            focusedBorder: baseBorder.copyWith(
                borderSide: const BorderSide(color: Color(0xFF2563EB))),
          ),
        ),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int? maxLines;

  const _TextField({
    required this.label,
    required this.controller,
    this.hintText,
    this.onChanged,
    this.enabled = true,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 800;
    final border = OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(10),
    );
    final filledBackground = !enabled ? const Color(0xFFF3F4F6) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        if (label.isNotEmpty) const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          enabled: enabled,
          maxLines: maxLines,
          style: GoogleFonts.inter(
            fontSize: isTablet ? 15 : 14,
            fontWeight: FontWeight.w500,
            color: enabled ? const Color(0xFF111827) : Colors.grey.shade500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 14,
              vertical: isTablet ? 16 : 14,
            ),
            filled: true,
            fillColor: filledBackground,
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: enabled
                  ? const BorderSide(color: Color(0xFF4db1b3), width: 2)
                  : border.borderSide,
            ),
            disabledBorder: border,
            errorBorder: border,
          ),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int min;
  final ValueChanged<String>? onChanged;
  final bool highlightError;
  final Widget? suffixIcon;

  const _NumberField({
    required this.label,
    required this.controller,
    this.min = 0,
    this.onChanged,
    this.highlightError = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 800;
    final baseBorder = OutlineInputBorder(
      borderSide: BorderSide(
        color: highlightError ? const Color(0xFFDC2626) : const Color(0xFFD1D5DB),
        width: highlightError ? 2 : 1,
      ),
      borderRadius: BorderRadius.circular(10),
    );
    final focusedBorder = baseBorder.copyWith(
      borderSide: BorderSide(
        color: highlightError ? const Color(0xFFDC2626) : const Color(0xFF4db1b3),
        width: 2,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        if (label.isNotEmpty) const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.inter(
            fontSize: isTablet ? 15 : 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF111827),
          ),
          onChanged: (v) {
// clamp to min
            final parsed = int.tryParse(v) ?? min;
            if (parsed < min) {
              controller.text = min.toString();
              controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: controller.text.length));
            }
            onChanged?.call(controller.text);
          },
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 14,
              vertical: isTablet ? 16 : 14,
            ),
            filled: true,
            fillColor: Colors.white,
            border: baseBorder,
            enabledBorder: baseBorder,
            focusedBorder: focusedBorder,
            errorBorder: baseBorder,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadonlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(10),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        if (label.isNotEmpty) const SizedBox(height: 8),
        InputDecorator(
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: border,
            enabledBorder: border,
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchableItemField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final Product? selectedProduct;
  final ValueChanged<Product> onProductSelected;
  final int Function() getDistributorId;

  const _SearchableItemField({
    required this.label,
    required this.controller,
    required this.selectedProduct,
    required this.onProductSelected,
    required this.getDistributorId,
  });

  @override
  State<_SearchableItemField> createState() => _SearchableItemFieldState();
}

class _SearchableItemFieldState extends State<_SearchableItemField> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _textFieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  List<Product> _filteredProducts = [];
  bool _isLoading = false;
  bool _isInitialLoad = true;
  Timer? _debounceTimer;
  /// Ignores stale API responses when the user types again before the request finishes.
  int _searchGeneration = 0;
  bool _hasText = false; // Track if text field has content

  @override
  void initState() {
    super.initState();
    print('🔍 [SearchableItemField] initState called');
    widget.controller.addListener(_onTextChanged);
    // Initialize _hasText based on current controller value
    _hasText = widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounceTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    final query = widget.controller.text.trim();
    print('🔍 [SearchableItemField] Text changed: "$query"');

    final hasText = widget.controller.text.isNotEmpty;
    // Update _hasText state to show/hide clear icon
    if (_hasText != hasText) {
      setState(() {
        _hasText = hasText;
      });
    }

    // Cancel previous timer
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      _filteredProducts = [];
      _removeOverlay();
      return;
    }

    // Debounce API calls after user pauses typing
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (query.isNotEmpty) {
        _searchItems(query);
      } else {
        _filteredProducts = [];
        _removeOverlay();
      }
    });
  }

  Future<void> _searchItems(String searchText) async {
    if (!mounted) return;
    final gen = ++_searchGeneration;

    setState(() {
      _isLoading = true;
    });
    _overlayEntry?.markNeedsBuild();

    try {
      print('🔍 [SearchableItemField] Getting CommonRepository');
      final commonRepository = getIt<CommonRepository>();
      print('🔍 [SearchableItemField] CommonRepository obtained');

      // Get distributor ID from parent widget callback
      final distributorId = widget.getDistributorId();

      // Call API with search text and correct distributor ID
      print(
          '🔍 [SearchableItemField] CALLING API with SearchText: "$searchText", CommandType: 105, DistributerId: $distributorId');
      final items = await commonRepository.getItemList(
        distributerId: distributorId,
        searchText: searchText,
      );

      if (!mounted || gen != _searchGeneration) return;

      print('🔍 [SearchableItemField] API returned ${items.length} items');

      // Log rate values from API response
      if (items.isNotEmpty) {
        print('🔍 [SearchableItemField] Sample item rates from API:');
        for (var i = 0; i < (items.length > 3 ? 3 : items.length); i++) {
          final item = items[i];
          print(
              '   Item ${i + 1}: ${item.text} - Rate: ${item.rate}, ID: ${item.id}');
        }
      }

      final mapped = items.map((item) {
        final product = Product(
          id: item.id.toString(),
          name: item.text,
          manufacturer: item.name.isNotEmpty ? item.name : 'N/A',
          rate: item.rate,
          mrp: null, // MRP will be loaded from item details if needed
          uom: item.uom > 0 ? 'UOM-${item.uom}' : 'Unit',
          availableQty: item.stock,
        );
        if (item.rate == 0 || item.rate == null) {
          print(
              '⚠️ [SearchableItemField] Item "${item.text}" (ID: ${item.id}) has rate = ${item.rate}');
        }
        return product;
      }).toList();

      setState(() {
        _filteredProducts = mapped;
        _isLoading = false;
        _isInitialLoad = false;
      });
      print(
          '🔍 [SearchableItemField] Loaded ${_filteredProducts.length} products');

      if (_filteredProducts.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    } catch (e, stackTrace) {
      print('❌ [SearchableItemField] Error loading items: $e');
      print('❌ [SearchableItemField] Stack trace: $stackTrace');
      if (!mounted || gen != _searchGeneration) return;
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
        _filteredProducts = [];
      });
      _removeOverlay();
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }

    // Get the width of the TextField to match overlay width
    final RenderBox? renderBox =
        _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final double? fieldWidth = renderBox?.size.width;
    final double overlayWidth =
        fieldWidth ?? 300.0; // Fallback width if not available

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: overlayWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0.0, 48.0),
          followerAnchor: Alignment.topLeft,
          targetAnchor: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _isInitialLoad
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: Text('Loading items...')),
                        )
                      : _filteredProducts.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 12.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('No items found'),
                                  if (_filteredProducts.isEmpty && !_isLoading)
                                    const SizedBox(height: 8),
                                  if (_filteredProducts.isEmpty && !_isLoading)
                                    Text(
                                      'No items found',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const ClampingScrollPhysics(),
                              padding: EdgeInsets.zero,
                              itemCount: _filteredProducts.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: Colors.grey.shade200,
                                thickness: 1,
                              ),
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                return InkWell(
                                  onTap: () {
                                    widget.controller.text = product.name;
                                    // Update _hasText state
                                    setState(() {
                                      _hasText = true;
                                    });
                                    widget.onProductSelected(product);
                                    _removeOverlay();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 12.0,
                                    ),
                                    color: Colors.transparent,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.name,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      const Color(0xFF111827),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (product.manufacturer !=
                                                  'N/A') ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  product.manufacturer,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        if (product.rate > 0)
                                          Text(
                                            product.rate.toStringAsFixed(2),
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF111827),
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
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(widget.label),
        if (widget.label.isNotEmpty) const SizedBox(height: 8),
        CompositedTransformTarget(
          link: _layerLink,
          child: TextField(
            key: _textFieldKey,
            controller: widget.controller,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF111827),
            ),
            decoration: InputDecoration(
              hintText: '',
              suffixIcon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _hasText
                      ? IconButton(
                          icon:
                              const Icon(Icons.clear, color: Color(0xFF4db1b3)),
                          onPressed: () {
                            // Clear the text field
                            widget.controller.clear();
                            // Update state immediately
                            setState(() {
                              _hasText = false;
                              _filteredProducts = [];
                            });
                            // Remove overlay
                            _removeOverlay();
                          },
                        )
                      : IconButton(
                          icon: const Icon(Icons.search,
                              color: Color(0xFF4db1b3)),
                          onPressed: () {
                            // Load all items by searching with empty string
                            _searchItems('');
                          },
                        ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide:
                    const BorderSide(color: Color(0xFF4db1b3), width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onTap: () {
              // Show overlay when field is tapped, if we have items loaded
              if (!_isLoading && !_isInitialLoad) {
                if (widget.controller.text.isEmpty) {
                  // Show overlay with empty state
                  _showOverlay();
                } else if (_filteredProducts.isNotEmpty) {
                  _showOverlay();
                }
              }
            },
            onChanged: (value) {
              // _onTextChanged is called via listener
            },
          ),
        ),
      ],
    );
  }
}

class _SearchableCustomerField extends StatefulWidget {
  final TextEditingController controller;
  final String? selectedCustomerCode;
  final ValueChanged<Customer> onCustomerSelected;
  final VoidCallback?
      onCustomerCleared; // Optional callback when field is cleared

  final List<Customer> allCustomers; // All customers loaded once

  const _SearchableCustomerField({
    required this.controller,
    required this.selectedCustomerCode,
    required this.onCustomerSelected,
    required this.allCustomers, // Pass all customers from parent
    this.onCustomerCleared, // Optional callback for clearing
  });

  @override
  State<_SearchableCustomerField> createState() =>
      _SearchableCustomerFieldState();
}

class _SearchableCustomerFieldState extends State<_SearchableCustomerField> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _textFieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  List<Customer> _filteredCustomers = [];
  Timer? _debounceTimer;
  bool _isSettingCustomer =
      false; // Flag to prevent listener from triggering when setting customer
  bool _hasText = false; // Track if text field has content

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    // Initialize with all customers
    _filteredCustomers = List.from(widget.allCustomers);
    // Initialize _hasText based on current controller value
    _hasText = widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounceTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SearchableCustomerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update filtered customers when allCustomers list changes
    if (oldWidget.allCustomers != widget.allCustomers) {
      final query = widget.controller.text.trim().toLowerCase();
      if (query.isEmpty) {
        _filteredCustomers = List.from(widget.allCustomers);
      } else {
        _filterCustomers(query);
      }
    }
  }

  void _onTextChanged() {
    // Skip if we're programmatically setting the customer
    if (_isSettingCustomer) {
      return;
    }

    final query = widget.controller.text.trim().toLowerCase();
    final hasText = widget.controller.text.isNotEmpty;

    // Update _hasText state to show/hide clear icon
    if (_hasText != hasText) {
      setState(() {
        _hasText = hasText;
      });
    }

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Filter customers locally based on search text
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (query.isEmpty) {
        // Show all customers by default when search is empty
        setState(() {
          _filteredCustomers = List.from(widget.allCustomers);
          if (_filteredCustomers.isNotEmpty) {
            _showOverlay();
          } else {
            _removeOverlay();
          }
        });
      } else {
        // Filter customers locally based on search text
        setState(() {
          _filteredCustomers = widget.allCustomers.where((customer) {
            // Only match customers whose names start with the entered text (case-insensitive)
            final name = customer.name.toLowerCase();
            return name.startsWith(query);
          }).toList();

          if (_filteredCustomers.isNotEmpty) {
            _showOverlay();
          } else {
            _removeOverlay();
          }
        });
      }
    });
  }

  void _filterCustomers(String query) {
    setState(() {
      _filteredCustomers = widget.allCustomers.where((customer) {
        // Only match customers whose names start with the entered text (case-insensitive)
        final name = customer.name.toLowerCase();
        return name.startsWith(query);
      }).toList();
    });
  }

  void _showOverlay() {
    _removeOverlay(); // Remove existing overlay if any

    // Get the width of the TextField to match overlay width
    final RenderBox? renderBox =
        _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final double? fieldWidth = renderBox?.size.width;
    final double overlayWidth =
        fieldWidth ?? 300.0; // Fallback width if not available

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: overlayWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0.0, 48.0),
          followerAnchor: Alignment.topLeft,
          targetAnchor: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _filteredCustomers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No customers found'),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _filteredCustomers.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.grey.shade200,
                      ),
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];
                        final isSelected =
                            widget.selectedCustomerCode == customer.code;
                        return InkWell(
                          onTap: () {
                            // Set flag to prevent text change listener from triggering
                            _isSettingCustomer = true;
                            // Set the customer name in the controller
                            widget.controller.text = customer.name;
                            // Update _hasText state
                            setState(() {
                              _hasText = true;
                            });
                            // Remove overlay first
                            _removeOverlay();
                            // Unfocus the TextField to close keyboard
                            FocusScope.of(context).unfocus();
                            // Call the callback to update parent state
                            widget.onCustomerSelected(customer);
                            // Reset flag after a short delay
                            Future.delayed(const Duration(milliseconds: 100),
                                () {
                              if (mounted) {
                                _isSettingCustomer = false;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4db1b3).withOpacity(0.05)
                                  : Colors.transparent,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade900,
                                        ),
                                      ),
                                      if (customer.city != 'N/A' &&
                                          customer.city.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          customer.city,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF4db1b3),
                                    size: 20,
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
    );

    // Small delay to ensure TextField is laid out before showing overlay
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && _overlayEntry != null) {
        Overlay.of(context).insert(_overlayEntry!);
      }
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 800;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        key: _textFieldKey,
        controller: widget.controller,
        style: GoogleFonts.inter(
          fontSize: isTablet ? 15 : 14,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF111827),
        ),
        decoration: InputDecoration(
          hintText: 'Type to search customers...',
          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
          suffixIcon: _hasText
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Clear icon
                    IconButton(
                      icon: const Icon(Icons.clear, color: Color(0xFF4db1b3)),
                      onPressed: () {
                        // Set flag to prevent listener from triggering
                        _isSettingCustomer = true;
                        // Clear the text field
                        widget.controller.clear();
                        // Update state immediately
                        setState(() {
                          _hasText = false;
                          _filteredCustomers = List.from(widget.allCustomers);
                        });
                        // Remove overlay
                        _removeOverlay();
                        // Notify parent that customer was cleared
                        widget.onCustomerCleared?.call();
                        // Reset flag after a short delay
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted) {
                            _isSettingCustomer = false;
                          }
                        });
                      },
                    ),
                    // Search icon - shows all customers when clicked
                    IconButton(
                      icon: const Icon(Icons.search, color: Color(0xFF4db1b3)),
                      onPressed: () {
                        // Show all customers regardless of current text
                        setState(() {
                          _filteredCustomers = List.from(widget.allCustomers);
                        });
                        _showOverlay();
                      },
                    ),
                  ],
                )
              : IconButton(
                  icon: const Icon(Icons.search, color: Color(0xFF4db1b3)),
                  onPressed: () {
                    // Show all customers when search icon is clicked
                    setState(() {
                      _filteredCustomers = List.from(widget.allCustomers);
                    });
                    _showOverlay();
                  },
                ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 16 : 14,
            vertical: isTablet ? 16 : 14,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF4db1b3), width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onTap: () {
          // Show all customers when field is tapped/focused
          if (widget.allCustomers.isNotEmpty) {
            // If search text is empty, show all customers
            if (widget.controller.text.trim().isEmpty) {
              setState(() {
                _filteredCustomers = List.from(widget.allCustomers);
              });
            }
            _showOverlay();
          }
        },
      ),
    );
  }
}

// Searchable Tax Field Widget
class _SearchableTaxField extends StatefulWidget {
  final String label;
  final String? selectedTax;
  final List<String> taxOptions;
  final bool isLoading;
  final ValueChanged<String> onTaxSelected;
  final Future<void> Function(int itemId) onLoadTax;
  final int itemId;

  const _SearchableTaxField({
    required this.label,
    required this.selectedTax,
    required this.taxOptions,
    required this.isLoading,
    required this.onTaxSelected,
    required this.onLoadTax,
    required this.itemId,
  });

  @override
  State<_SearchableTaxField> createState() => _SearchableTaxFieldState();
}

class _SearchableTaxFieldState extends State<_SearchableTaxField> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _textFieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredTaxes = [];
  bool _hasLoadedTax = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.selectedTax ?? '';
    // Load Tax when itemId is available
    if (widget.itemId > 0 && !_hasLoadedTax) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadTax();
      });
    }
  }

  @override
  void didUpdateWidget(_SearchableTaxField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller text if selectedTax changed
    if (widget.selectedTax != oldWidget.selectedTax) {
      _controller.text = widget.selectedTax ?? '';
    }
    // Load Tax if itemId changed
    if (widget.itemId != oldWidget.itemId && widget.itemId > 0) {
      _hasLoadedTax = false; // Reset flag to allow reload
      _loadTax();
    }
    // Update filtered list if options changed
    if (widget.taxOptions != oldWidget.taxOptions) {
      _filteredTaxes = widget.taxOptions;
      // Update controller text with selected Tax (should be auto-selected by parent)
      _controller.text = widget.selectedTax ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _removeOverlay();
    super.dispose();
  }

  Future<void> _loadTax() async {
    if (widget.itemId <= 0) return;

    // Check if Tax options are already loaded
    if (widget.taxOptions.isNotEmpty) {
      _hasLoadedTax = true;
      setState(() {
        _filteredTaxes = widget.taxOptions;
        _controller.text = widget.selectedTax ?? '';
      });
      return;
    }

    if (_hasLoadedTax) return;

    _hasLoadedTax = true;
    await widget.onLoadTax(widget.itemId);
    if (mounted) {
      setState(() {
        _filteredTaxes = widget.taxOptions;
        // Update controller text with selected Tax (which should be auto-selected)
        _controller.text = widget.selectedTax ?? '';
      });
    }
  }

  void _onTextChanged(String value) {
    setState(() {
      if (value.isEmpty) {
        _filteredTaxes = widget.taxOptions;
      } else {
        _filteredTaxes = widget.taxOptions
            .where((tax) => tax.toLowerCase().contains(value.toLowerCase()))
            .toList();
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();

    // Reset search and show all options
    _searchController.clear();
    _filteredTaxes = widget.taxOptions;

    // Get the width of the TextField
    final RenderBox? renderBox =
        _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final double? fieldWidth = renderBox?.size.width;
    final double overlayWidth =
        fieldWidth ?? MediaQuery.of(context).size.width * 0.9;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: overlayWidth,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0.0, 48.0),
            followerAnchor: Alignment.topLeft,
            targetAnchor: Alignment.topLeft,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onTextChanged,
                        decoration: InputDecoration(
                          hintText: 'Search tax...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFF4db1b3)),
                          ),
                        ),
                      ),
                    ),
                    // Options list
                    Flexible(
                      child: _filteredTaxes.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'No tax options available',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _filteredTaxes.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                color: Colors.grey.shade200,
                              ),
                              itemBuilder: (context, index) {
                                final tax = _filteredTaxes[index];
                                final isSelected = tax == widget.selectedTax;
                                return InkWell(
                                  onTap: () {
                                    widget.onTaxSelected(tax);
                                    _controller.text = tax;
                                    _removeOverlay();
                                  },
                                  child: Container(
                                    color: isSelected
                                        ? const Color(0xFF4db1b3)
                                            .withOpacity(0.1)
                                        : Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            tax,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: Colors.grey.shade900,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check,
                                            size: 20,
                                            color: Color(0xFF4db1b3),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    // Small delay to ensure TextField is laid out
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && _overlayEntry != null) {
        Overlay.of(context).insert(_overlayEntry!);
      }
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(widget.label),
          if (widget.label.isNotEmpty) const SizedBox(height: 8),
          TextField(
            key: _textFieldKey,
            controller: _controller,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: '',
              suffixIcon: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.arrow_drop_down),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF4db1b3)),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            readOnly: true,
            onTap: () {
              if (widget.taxOptions.isNotEmpty) {
                _showOverlay();
              } else if (widget.itemId > 0) {
                // Load tax if not loaded yet
                _loadTax().then((_) {
                  if (widget.taxOptions.isNotEmpty) {
                    _showOverlay();
                  }
                });
              }
            },
          ),
        ],
      ),
    );
  }
}

// Helper function to load Tax for an item

// Searchable UOM Field Widget
class _SearchableUOMField extends StatefulWidget {
  final String label;
  final String? selectedUOM;
  final List<String> uomOptions;
  final bool isLoading;
  final ValueChanged<String> onUOMSelected;
  final Future<void> Function(int itemId) onLoadUOM;
  final int itemId;

  const _SearchableUOMField({
    required this.label,
    required this.selectedUOM,
    required this.uomOptions,
    required this.isLoading,
    required this.onUOMSelected,
    required this.onLoadUOM,
    required this.itemId,
  });

  @override
  State<_SearchableUOMField> createState() => _SearchableUOMFieldState();
}

class _SearchableUOMFieldState extends State<_SearchableUOMField> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _textFieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredUOMs = [];
  bool _hasLoadedUOM = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.selectedUOM ?? '';
    // Load UOM when itemId is available
    if (widget.itemId > 0 && !_hasLoadedUOM) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUOM();
      });
    }
  }

  @override
  void didUpdateWidget(_SearchableUOMField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller text if selectedUOM changed
    if (widget.selectedUOM != oldWidget.selectedUOM) {
      _controller.text = widget.selectedUOM ?? '';
    }
    // Load UOM if itemId changed
    if (widget.itemId != oldWidget.itemId && widget.itemId > 0) {
      _hasLoadedUOM = false; // Reset flag to allow reload
      _loadUOM();
    }
    // Update filtered list if options changed
    if (widget.uomOptions != oldWidget.uomOptions) {
      _filteredUOMs = widget.uomOptions;
      // Update controller text with selected UOM (should be auto-selected by parent)
      _controller.text = widget.selectedUOM ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _removeOverlay();
    super.dispose();
  }

  Future<void> _loadUOM() async {
    if (widget.itemId <= 0) return;

    // Check if UOM options are already loaded
    if (widget.uomOptions.isNotEmpty) {
      _hasLoadedUOM = true;
      setState(() {
        _filteredUOMs = widget.uomOptions;
        _controller.text = widget.selectedUOM ?? '';
      });
      return;
    }

    if (_hasLoadedUOM) return;

    _hasLoadedUOM = true;
    await widget.onLoadUOM(widget.itemId);
    if (mounted) {
      setState(() {
        _filteredUOMs = widget.uomOptions;
        // Update controller text with selected UOM (which should be auto-selected)
        _controller.text = widget.selectedUOM ?? '';
      });
    }
  }

  void _onTextChanged(String value) {
    setState(() {
      if (value.isEmpty) {
        _filteredUOMs = widget.uomOptions;
      } else {
        _filteredUOMs = widget.uomOptions
            .where((uom) => uom.toLowerCase().contains(value.toLowerCase()))
            .toList();
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();

    // Reset search and show all options
    _searchController.clear();
    _filteredUOMs = widget.uomOptions;

    // Get the width of the TextField
    final RenderBox? renderBox =
        _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final double? fieldWidth = renderBox?.size.width;
    final double overlayWidth =
        fieldWidth ?? MediaQuery.of(context).size.width * 0.9;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: overlayWidth,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0.0, 48.0),
            followerAnchor: Alignment.topLeft,
            targetAnchor: Alignment.topLeft,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onTextChanged,
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFF4db1b3)),
                          ),
                        ),
                      ),
                    ),
                    // UOM List
                    if (widget.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_filteredUOMs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No UOM found'),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _filteredUOMs.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.grey.shade200,
                          ),
                          itemBuilder: (context, index) {
                            final uom = _filteredUOMs[index];
                            final isSelected = widget.selectedUOM == uom;
                            return InkWell(
                              onTap: () {
                                _controller.text = uom;
                                widget.onUOMSelected(uom);
                                _removeOverlay();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF4db1b3)
                                          .withOpacity(0.05)
                                      : Colors.transparent,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        uom,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade900,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF4db1b3),
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    // Small delay to ensure TextField is laid out
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && _overlayEntry != null) {
        Overlay.of(context).insert(_overlayEntry!);
      }
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(widget.label),
          if (widget.label.isNotEmpty) const SizedBox(height: 8),
          TextField(
            key: _textFieldKey,
            controller: _controller,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: '',
              suffixIcon: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.arrow_drop_down),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF4db1b3)),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            readOnly: true,
            onTap: () {
              if (widget.uomOptions.isNotEmpty) {
                _filteredUOMs = widget.uomOptions;
                _showOverlay();
              } else if (widget.itemId > 0) {
                // Load UOM if not loaded yet
                _loadUOM().then((_) {
                  if (widget.uomOptions.isNotEmpty) {
                    _filteredUOMs = widget.uomOptions;
                    _showOverlay();
                  }
                });
              }
            },
          ),
        ],
      ),
    );
  }
}
