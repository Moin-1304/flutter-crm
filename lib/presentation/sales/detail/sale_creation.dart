import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:boilerplate/domain/entity/sales/sales_api_models.dart';
import 'package:boilerplate/domain/repository/sales/sales_repository.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/di/service_locator.dart';

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

// Customers fetched from API
  List<Customer> Customers = [];

  List<String> _salesReps = []; // Will be populated from API

  List<String> _distributors = []; // Will be populated from API

  final List<Product> Products = const [
    Product(
        id: 'P001',
        name: 'Paracetamol 500mg',
        manufacturer: 'Cipla',
        rate: 200.00,
        uom: 'Box',
        availableQty: 120),
    Product(
        id: 'P002',
        name: 'Aspirin 75mg',
        manufacturer: 'Sun Pharma',
        rate: 150.50,
        uom: 'Strip',
        availableQty: 85),
    Product(
        id: 'P003',
        name: "Cough Syrup",
        manufacturer: "Dr. Reddy's",
        rate: 320.00,
        uom: 'Bottle',
        availableQty: 50),
  ];

// Form state
  late DateTime _contractDate;
  late DateTime _deliveryDate;
  String? _soNumber; // Auto-generated, can be null for new orders
  String? _selectedType;
  String? _selectedCurrency = 'LKR';
  String? _selectedCustomerCode;
  final TextEditingController CustomerAddressController =
      TextEditingController();
  final TextEditingController _customerSearchController = TextEditingController();
  String? _selectedSalesRep;
  String? _selectedDistributor;
  final TextEditingController _notesController = TextEditingController();
  
  // New fields
  final TextEditingController _customerPOController = TextEditingController();
  String? _selectedUserGroup;
  final TextEditingController _quotationNoController = TextEditingController();
  bool _isBonusSO = false;
  final TextEditingController _exchangeRateController = TextEditingController(text: '1.00000');
  final TextEditingController _deliveryAddressController = TextEditingController();
  
  // Tax and charges
  double _subTotal = 0.0;
  String? _selectedTaxType = 'VAT 18%';
  double _taxAmount = 0.0;
  String? _selectedDiscountType;
  double _discountAmount = 0.0;
  double _otherCharge = 0.0;
  double _priceAdjustment = 0.0;
  
  final List<String> _typeOptions = ['Normal', 'Bonus', 'Domestic'];
  final List<String> _currencyOptions = ['LKR', 'USD'];
  final List<String> _taxTypeOptions = ['VAT 18%', 'GST 5%', 'No Tax'];
  final List<String> _discountTypeOptions = ['Percentage', 'Fixed Amount'];
  final List<String> _userGroupOptions = ['Diagnostic', 'Pharmacy', 'Hospital'];

// Items
  final List<_LineItem> _items = [];

  bool get _isEditMode => widget.contractId != null || widget.orderId != null || widget.orderData != null;

  @override
  void initState() {
    super.initState();
    // Initialize with default values first to prevent null errors
    _contractDate = DateTime.now();
    _deliveryDate = DateTime.now().add(const Duration(days: 7));
    
    if (_isEditMode) {
      // Always fetch from API if orderId is provided to get complete data with items
      if (widget.orderId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadOrderData();
        });
      } else if (widget.orderData != null) {
        // If only orderData is provided (no orderId), use it but note it might be incomplete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _populateFormFromOrderData(widget.orderData!);
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
        throw Exception('BizUnit is 0. Please ensure user details are loaded correctly.');
      }

      final commonRepository = getIt<CommonRepository>();
      final items = await commonRepository.getCustomerList(
        bizUnit: bizUnit,
        customerId: null,
      );

      if (mounted) {
        setState(() {
          // Convert CommonDropdownItem to Customer
          Customers = items.map((item) {
            return Customer(
              code: item.id.toString(),
              name: item.text,
              address: item.address.isNotEmpty ? item.address : 'N/A',
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

      print('🔵 Loading Sales Rep for UserId: $userId, CustomerId: $customerId');

      final commonRepository = getIt<CommonRepository>();
      final salesReps = await commonRepository.getSalesRepList(
        userId: userId,
        customerId: customerId,
      );

      if (mounted) {
        setState(() {
          // Convert CommonDropdownItem to String list (using text field)
          _salesReps = salesReps.map((item) => item.text).toList();
          
          // Auto-select the first Sales Rep if available
          if (_salesReps.isNotEmpty) {
            // If current selection is not in the new list, or no selection exists, select the first one
            if (_selectedSalesRep == null || !_salesReps.contains(_selectedSalesRep)) {
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

      print('🔵 Loading Distributors for BizUnit: $bizUnit, CustomerId: $customerId');

      final commonRepository = getIt<CommonRepository>();
      final distributors = await commonRepository.getDistributorList(
        bizUnit: bizUnit,
        customerId: customerId,
      );

      if (mounted) {
        setState(() {
          // Convert CommonDropdownItem to String list (using text field)
          _distributors = distributors.map((item) => item.text).toList();
          
          // Auto-select the first Distributor if available
          if (_distributors.isNotEmpty) {
            // If current selection is not in the new list, or no selection exists, select the first one
            if (_selectedDistributor == null || !_distributors.contains(_selectedDistributor)) {
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

  Future<void> _loadOrderData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      SalesOrderApiItem? orderData;
      
      // Always fetch from API if orderId is provided to get complete data with items and tax details
      if (widget.orderId != null) {
        final orderId = int.tryParse(widget.orderId!);
        if (orderId != null && orderId > 0) {
          final salesRepository = getIt<SalesRepository>();
          orderData = await salesRepository.getSalesOrderById(orderId);
        }
      }

      if (orderData != null && mounted) {
        _loadedOrderData = orderData;
        _populateFormFromOrderData(orderData);
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

  void _populateFormFromOrderData(SalesOrderApiItem orderData) {
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
        _deliveryDate = DateTime.now().add(const Duration(days: 7));
      }
    }

    // Basic fields
    _soNumber = orderData.soNumber;
    _selectedType = orderData.typeText;
    _selectedCurrency = orderData.currencyText ?? orderData.currency ?? 'LKR';
    _selectedCustomerCode = orderData.customer;
    CustomerAddressController.text = orderData.cusAddress ?? '';
    _customerSearchController.text = orderData.customerName ?? orderData.customer ?? '';
    _selectedSalesRep = orderData.salesRepName ?? orderData.salesRep;
    _customerPOController.text = orderData.customerRef ?? '';
    _selectedUserGroup = orderData.divisionGroupName;
    _quotationNoController.text = orderData.refNo ?? '';
    _isBonusSO = orderData.isBonusSO ?? false;
    _exchangeRateController.text = orderData.exchangeRate?.toStringAsFixed(5) ?? '1.00000';
    _deliveryAddressController.text = orderData.deliveryAddress ?? '';

    // Parse items
    _items.clear();
    if (orderData.salesContractItems != null && orderData.salesContractItems is List) {
      final itemsList = orderData.salesContractItems as List;
      for (var itemData in itemsList) {
        if (itemData is Map<String, dynamic>) {
          _items.add(_parseItemFromData(itemData));
        }
      }
    }
    
    // If no items found, create a default item
    if (_items.isEmpty) {
      final defaultProduct = Products.isNotEmpty
          ? Products.first
          : Product(
              id: '0',
              name: 'Item',
              manufacturer: 'N/A',
              rate: 0.0,
              uom: 'Unit',
              availableQty: 0,
            );
      _items.add(_LineItem.fromProduct(
        defaultProduct,
        itemDescription: '',
        rate: 0.0,
      ));
    }

    // Parse tax and charges
    if (orderData.taxAndOtherChargesDetail != null && orderData.taxAndOtherChargesDetail is List) {
      final charges = orderData.taxAndOtherChargesDetail as List;
      for (var charge in charges) {
        if (charge is Map<String, dynamic>) {
          final label = charge['label']?.toString().toLowerCase() ?? '';
          final value = (charge['value'] ?? 0).toDouble();
          
          if (label.contains('sub total') || label.contains('subtotal')) {
            _subTotal = value;
          } else if (label.contains('tax')) {
            _taxAmount = value;
            // Try to extract tax type from label or use default
            final taxLabel = charge['label']?.toString() ?? '';
            if (taxLabel.contains('VAT') || taxLabel.contains('18%')) {
              _selectedTaxType = 'VAT 18%';
            } else if (taxLabel.contains('GST') || taxLabel.contains('5%')) {
              _selectedTaxType = 'GST 5%';
            }
          } else if (label.contains('discount')) {
            _discountAmount = value;
          } else if (label.contains('other charge')) {
            _otherCharge = value;
          } else if (label.contains('price adjustment')) {
            _priceAdjustment = value;
          }
        }
      }
    } else {
      // Fallback to direct fields - calculate from items if available
      if (_items.isNotEmpty) {
        _subTotal = _items.fold(0.0, (sum, item) => sum + item.amount);
      } else {
        _subTotal = orderData.totalAmount ?? orderData.amount ?? 0.0;
      }
      _taxAmount = orderData.totalTax ?? 0.0;
      _discountAmount = orderData.totalDiscount ?? 0.0;
      _otherCharge = orderData.totalShipCharge ?? 0.0;
      _priceAdjustment = orderData.totalAdjust ?? 0.0;
    }

    _updateTotals();
    if (mounted) {
      setState(() {});
    }
  }

  _LineItem _parseItemFromData(Map<String, dynamic> itemData) {
    // Use item description from data
    final itemDescription = itemData['itemText'] ?? 
                          itemData['itemName'] ?? 
                          itemData['itemDescription'] ?? 
                          itemData['description'] ?? 
                          '';
    final rate = (itemData['rate'] ?? itemData['unitPrice'] ?? itemData['price'] ?? 0.0).toDouble();
    
    // Use first product as default for factory method (will be overridden by itemDescription)
    Product defaultProduct = Products.isNotEmpty
        ? Products.first
        : Product(
            id: '0',
            name: itemDescription.isNotEmpty ? itemDescription : 'Item',
            manufacturer: 'N/A',
            rate: rate > 0 ? rate : 0.0,
            uom: 'Unit',
            availableQty: 0,
          );

    // Parse required date
    DateTime reqDate = DateTime.now();
    final reqdDateStr = itemData['reqdDate'] ?? itemData['requiredDate'] ?? itemData['deliveryDate'];
    if (reqdDateStr != null) {
      try {
        if (reqdDateStr is String) {
          reqDate = DateTime.parse(reqdDateStr);
        }
      } catch (e) {
        reqDate = DateTime.now();
      }
    }

    return _LineItem.fromProduct(
      defaultProduct,
      reqDate: reqDate,
      qty: (itemData['quantity'] ?? itemData['qty'] ?? 0).toInt(),
      bonusQty: (itemData['bonusQty'] ?? itemData['bonusQuantity'] ?? 0).toInt(),
      addlBonusQty: (itemData['addlBonus'] ?? itemData['additionalBonusQuantity'] ?? 0).toInt(),
      notes: itemData['notes'] ?? itemData['remarks'] ?? '',
      itemDescription: itemDescription,
      rate: rate,
    );
  }

  @override
  void dispose() {
    CustomerAddressController.dispose();
    _customerSearchController.dispose();
    _notesController.dispose();
    _customerPOController.dispose();
    _quotationNoController.dispose();
    _exchangeRateController.dispose();
    _deliveryAddressController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    _items.clear();
    super.dispose();
  }
  
  void _updateTotals() {
    _subTotal = _items.fold(0.0, (sum, item) => sum + item.lineTotal);
    // Calculate tax based on selected tax type
    if (_selectedTaxType == 'VAT 18%') {
      _taxAmount = _subTotal * 0.18;
    } else if (_selectedTaxType == 'GST 5%') {
      _taxAmount = _subTotal * 0.05;
    } else {
      _taxAmount = 0.0;
    }
    setState(() {});
  }

  void _loadEditModeData(String id) {
// Header
    _contractDate = DateTime(2025, 9, 18);
    _selectedCustomerCode = 'C001';
    CustomerAddressController.text =
        '123 Health St, Wellness City, Mumbai - 400001';
    _selectedDistributor = null; // Will be auto-selected when customer is chosen
    _selectedSalesRep = null; // Will be auto-selected when customer is chosen

// Items
    _items.clear();
    _items.addAll([
      _LineItem.fromProduct(
        _findProduct('P001'),
        reqDate: DateTime(2025, 9, 25),
        qty: 12,
        bonusQty: 1,
        addlBonusQty: 0,
        notes: 'Diwali Offer',
        expanded: true,
      ),
      _LineItem.fromProduct(
        _findProduct('P003'),
        reqDate: DateTime(2025, 9, 24),
        qty: 5,
        bonusQty: 0,
        addlBonusQty: 0,
        notes: '',
        expanded: false,
      ),
    ]);
    setState(() {});
  }

  void _loadNewModeData() {
    _contractDate = DateTime.now();
    _deliveryDate = DateTime.now().add(const Duration(days: 7));
    _soNumber = null; // Auto-generated
    _selectedType = null;
    _selectedCurrency = 'LKR';
    _selectedCustomerCode = null;
    CustomerAddressController.text = '';
    _selectedDistributor = null;
    _selectedSalesRep = null;
    _items.clear();
    _items.add(_LineItem.fromProduct(
      Products.first,
      itemDescription: '',
      rate: 0.0,
    ));
    _notesController.clear();
    _customerPOController.clear();
    _quotationNoController.clear();
    _exchangeRateController.text = '1.00000';
    _deliveryAddressController.clear();
    _selectedUserGroup = null;
    _isBonusSO = false;
    _updateTotals();
    setState(() {});
  }

  Product _findProduct(String id) {
    return Products.firstWhere((p) => p.id == id);
  }

  Customer? get _selectedCustomer {
    if (_selectedCustomerCode == null || Customers.isEmpty) return null;
    try {
    return Customers.firstWhere((c) => c.code == _selectedCustomerCode);
    } catch (e) {
      return null;
    }
  }

  String _formatCurrency(double value) {
// Simple INR-like formatting without extra dependencies
    return 'LKR${value.toStringAsFixed(2)}';
  }

  double _calculateGrandTotal() {
    return _subTotal + _taxAmount - _discountAmount + _otherCharge + _priceAdjustment;
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
              _isEditMode ? 'Edit SO' : 'New SO',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: isTablet ? 20 : 18,
                letterSpacing: -0.5,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            foregroundColor: Colors.white,
            actions: [
              // Grand Total Display - Only for tablet view
              if (isTablet)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                Text(
                        'Grand Total',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatCurrency(_calculateGrandTotal()),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          body: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Scrollable content
                      Expanded(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
                              filled: true,
                              fillColor: Colors.grey.withOpacity(0.05),
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
                                borderSide: const BorderSide(color: Color(0xFF4db1b3), width: 2),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 16 : 14,
                                vertical: isTablet ? 16 : 14,
                              ),
                            ),
                          ),
              child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              isTablet ? 16 : 12,
                              12,
                              isTablet ? 16 : 12,
                              16,
                            ),
                            child: Center(
                child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(isTablet: isTablet),
                                    const SizedBox(height: 14),
                      _buildItemsCard(isTablet: isTablet),
                                    const SizedBox(height: 14),
                                    _buildTaxSection(isTablet: isTablet),
                                    const SizedBox(height: 14),
                                    _buildNotesSection(isTablet: isTablet),
                                    const SizedBox(height: 14),
                                    _buildAttachmentsSection(isTablet: isTablet),
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
            // Section Title
            Text(
              'Order Information',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
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
                          Expanded(child: _buildBottomRowField1(isTablet)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildBottomRowField2(isTablet)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildBottomRowField3(isTablet)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildBottomRowField4(isTablet)),
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
        onCustomerSelected: (customer) {
                          setState(() {
            _selectedCustomerCode = customer.code;
            CustomerAddressController.text = customer.address;
          });
          // Load Sales Rep and Distributor when customer is selected
          _loadSalesReps(customer.code);
          _loadDistributors(customer.code);
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
    return _LabeledField(
              label: 'Customer Address',
      child: TextField(
              controller: CustomerAddressController,
        maxLines: 3,
        style: GoogleFonts.inter(fontSize: 14),
        decoration: InputDecoration(),
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

  // Bottom Row Field 3: Sales Rep
  Widget _buildBottomRowField3(bool isTablet) {
    return _LabeledField(
                        label: 'Sales Rep',
      child: _DropdownField<String>(
        label: '',
                        value: _selectedSalesRep,
        hint: '-- Select Sales Rep --',
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
                        hint: '-- Select Distributor --',
                        items: [
                          for (final d in _distributors)
                            DropdownMenuItem(value: d, child: Text(d)),
                        ],
        onChanged: (v) => setState(() => _selectedDistributor = v),
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
                      final defaultProduct = Products.isNotEmpty
                          ? Products.first
                          : Product(
                              id: '0',
                              name: 'Item',
                              manufacturer: 'N/A',
                              rate: 0.0,
                              uom: 'Unit',
                              availableQty: 0,
                            );
                      _items.add(
                          _LineItem.fromProduct(
                            defaultProduct,
                            itemDescription: '',
                            rate: 0.0,
                          ));
                      _updateTotals();
                    });
                  },
                  icon: const Icon(Icons.add, size: 18, color: tealGreen),
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
            Text(
              'Tax',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Column(
                children: [
                  _buildTaxRow('Sub Total', _subTotal, isTablet: isTablet),
                  const SizedBox(height: 12),
                  _buildTaxRowWithDropdown(
                    'Tax',
                    _taxAmount,
                    _selectedTaxType,
                    _taxTypeOptions,
                    (value) {
                      setState(() {
                        _selectedTaxType = value;
                        _updateTotals();
                  });
                },
                    isTablet: isTablet,
                  ),
                  const SizedBox(height: 12),
                  _buildTaxRowWithDropdown(
                    'Discount',
                    _discountAmount,
                    _selectedDiscountType,
                    _discountTypeOptions,
                    (value) {
                      setState(() {
                        _selectedDiscountType = value;
                      });
                    },
                    isTablet: isTablet,
                  ),
                  const SizedBox(height: 12),
                  _buildTaxRow('Other Charge', _otherCharge, isTablet: isTablet),
                  const SizedBox(height: 12),
                  _buildTaxRow('Price Adjustment', _priceAdjustment, isTablet: isTablet),
                  const Divider(height: 24),
                  _buildTaxRow('Grand Total', _calculateGrandTotal(), isTotal: true, isTablet: isTablet),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxRow(String label, double value, {bool isTotal = false, required bool isTablet}) {
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
            onSelected: onChanged,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
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
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => options.map((option) {
              return PopupMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  style: GoogleFonts.inter(fontSize: 14),
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

  Widget _buildNotesSection({required bool isTablet}) {
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
            Text(
              'Notes / Remarks',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 4,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
              decoration: InputDecoration(
                hintText: 'Any special instructions or remarks...',
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection({required bool isTablet}) {
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
            Text(
              'Attachments',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Center(
                child: Text(
                  'No attachments',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ),
          ],
        ),
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
        child: Row(
          children: [
            // Save Draft Button
        Expanded(
          child: OutlinedButton(
            onPressed: _onSaveDraft,
            style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: isTablet ? 16 : 14,
                  ),
              shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                ),
                child: Text(
                  'Save Draft',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
            ),
          ),
        ),
        const SizedBox(width: 12),
            // Submit Button
        Expanded(
          child: ElevatedButton(
            onPressed: _onSubmitForApproval,
            style: ElevatedButton.styleFrom(
                  backgroundColor: tealGreen,
              foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: isTablet ? 16 : 14,
                  ),
              shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  'Submit',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ],
        ),
      ),
    );
  }

  void _onSave() {
// TODO: Replace with actual save logic
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Saved')));
  }

  void _onSaveDraft() {
// TODO: Replace with actual draft logic
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Saved as Draft')));
  }

  void _onSubmitForApproval() {
// TODO: Replace with actual submit logic
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Submitted for Approval')));
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

  const _ItemCard({
    required this.index,
    required this.totalCount,
    required this.item,
    required this.onRemove,
    required this.onChanged,
    required this.onToggle,
    required this.formatCurrency,
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
              IconButton(
                onPressed: onToggle,
                tooltip: item.expanded ? 'Collapse' : 'Expand',
                icon: Icon(
                  item.expanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF6B7280),
                ),
              ),
              if (canRemove)
                TextButton(
                  onPressed: onRemove,
                  child: const Text(
                    'Remove',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (item.expanded) ...[

            // Row 1: Item Description*, Quantity*, UOM
            LayoutBuilder(
              builder: (context, constraints) {
                final bool wide = constraints.maxWidth >= 720;
                if (wide) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _SearchableItemField(
                          label: 'Item Description*',
                          controller: item.itemDescriptionController,
                          selectedProduct: item.product,
                          onProductSelected: (product) {
                            item.setProduct(product);
                            // Load UOM for the selected item
                            final itemId = int.tryParse(product.id) ?? 0;
                            if (itemId > 0) {
                              _loadUOMForItem(item, itemId, onChanged);
                            }
                            onChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberField(
                          label: 'Quantity*',
                          controller: item.qtyController,
                          min: 0,
                          onChanged: (v) => onChanged(),
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
                                final uomList = await commonRepository.getUOMList(itemId: itemId);
                                item.uomOptions = uomList.map((item) => item.text).toList();
                                // Always auto-select first UOM when item is selected
                                if (item.uomOptions.isNotEmpty) {
                                  item.selectedUOM = item.uomOptions.first;
                                } else {
                                  item.selectedUOM = null;
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
                  );
                }
                return Column(
                  children: [
                    _SearchableItemField(
                      label: 'Item Description*',
                      controller: item.itemDescriptionController,
                      selectedProduct: item.product,
                      onProductSelected: (product) {
                        item.setProduct(product);
                        // Load UOM for the selected item
                        final itemId = int.tryParse(product.id) ?? 0;
                        if (itemId > 0) {
                          _loadUOMForItem(item, itemId, onChanged);
                        }
                        onChanged();
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _NumberField(
                            label: 'Quantity*',
                            controller: item.qtyController,
                            min: 0,
                            onChanged: (v) => onChanged(),
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
                                  final uomList = await commonRepository.getUOMList(itemId: itemId);
                                  item.uomOptions = uomList.map((item) => item.text).toList();
                                  // Always auto-select first UOM when item is selected
                                  if (item.uomOptions.isNotEmpty) {
                                    item.selectedUOM = item.uomOptions.first;
                                  } else {
                                    item.selectedUOM = null;
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
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Row 2: Bonus Qty, Addl. Bonus, Rate*, MRP*
            LayoutBuilder(
              builder: (context, constraints) {
                final bool wide = constraints.maxWidth >= 720;
                if (wide) {
                  return Row(
                    children: [
                  Expanded(
                    child: _NumberField(
                          label: 'Bonus Qty',
                          controller: item.bonusQtyController,
                      min: 0,
                      onChanged: (v) => onChanged(),
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
                  const SizedBox(width: 12),
                  Expanded(
                        child: _NumberField(
                          label: 'Rate*',
                          controller: item.rateController,
                          min: 0,
                          onChanged: (v) => onChanged(),
                    ),
                  ),
                  const SizedBox(width: 12),
                      Expanded(
                        child: _NumberField(
                          label: 'MRP*',
                          controller: item.mrpController,
                          min: 0,
                          onChanged: (v) => onChanged(),
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    Row(
                      children: [
                  Expanded(
                    child: _NumberField(
                      label: 'Bonus Qty',
                      controller: item.bonusQtyController,
                      min: 0,
                      onChanged: (v) => onChanged(),
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
                    const SizedBox(height: 12),
                    Row(
                    children: [
                        Expanded(
                          child: _NumberField(
                            label: 'Rate*',
                            controller: item.rateController,
                            min: 0,
                            onChanged: (v) => onChanged(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _NumberField(
                            label: 'MRP*',
                            controller: item.mrpController,
                            min: 0,
                            onChanged: (v) => onChanged(),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
                      const SizedBox(height: 12),

            // Row 3: Amount, Discount, Total Amount
            LayoutBuilder(
              builder: (context, constraints) {
                final bool wide = constraints.maxWidth >= 720;
                if (wide) {
                  return Row(
                    children: [
                      Expanded(
                        child: _ReadonlyField(
                          label: 'Amount',
                          value: formatCurrency(item.amount),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberField(
                          label: 'Discount',
                          controller: item.discountController,
                          min: 0,
                          onChanged: (v) => onChanged(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ReadonlyField(
                          label: 'Total Amount',
                          value: formatCurrency(item.totalAmount),
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ReadonlyField(
                            label: 'Amount',
                            value: formatCurrency(item.amount),
                          ),
                        ),
                      const SizedBox(width: 12),
                        Expanded(
                          child: _NumberField(
                            label: 'Discount',
                            controller: item.discountController,
                            min: 0,
                            onChanged: (v) => onChanged(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ReadonlyField(
                      label: 'Total Amount',
                      value: formatCurrency(item.totalAmount),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Row 4: Remarks
            _TextField(
              label: 'Remarks',
              controller: item.notesController,
              hintText: 'Enter remarks',
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
  final TextEditingController notesController;
  final TextEditingController rateController; // Added for rate input
  final TextEditingController mrpController; // MRP field
  final TextEditingController discountController; // Discount field
  String? selectedUOM; // UOM dropdown value
  List<String> uomOptions = []; // UOM options from API

  bool expanded;

  _LineItem({
    required this.product,
    required this.requiredDate,
    required this.itemDescriptionController,
    required this.qtyController,
    required this.bonusQtyController,
    required this.addlBonusQtyController,
    required this.notesController,
    required this.rateController,
    required this.mrpController,
    required this.discountController,
    this.selectedUOM,
    this.expanded = true,
  });

  factory _LineItem.fromProduct(
    Product product, {
    DateTime? reqDate,
    int qty = 1,
    int bonusQty = 0,
    int addlBonusQty = 0,
    String notes = '',
    String? itemDescription,
    double? rate,
    double? mrp,
    double? discount,
    String? uom,
    bool expanded = true,
  }) {
    return _LineItem(
      product: product,
      requiredDate: reqDate ?? DateTime.now(),
      itemDescriptionController: TextEditingController(
        text: itemDescription ?? product.name,
      ),
      qtyController: TextEditingController(text: qty.toStringAsFixed(2)),
      bonusQtyController: TextEditingController(text: bonusQty.toStringAsFixed(2)),
      addlBonusQtyController:
          TextEditingController(text: addlBonusQty.toStringAsFixed(2)),
      notesController: TextEditingController(text: notes),
      rateController: TextEditingController(
        text: (rate ?? product.rate).toStringAsFixed(2),
      ),
      mrpController: TextEditingController(
        text: (mrp ?? product.rate).toStringAsFixed(2),
      ),
      discountController: TextEditingController(
        text: (discount ?? 0.0).toStringAsFixed(2),
      ),
      selectedUOM: uom ?? product.uom,
      expanded: expanded,
    );
  }

  void setProduct(Product newProduct) {
    product = newProduct;
    itemDescriptionController.text = newProduct.name;
    rateController.text = newProduct.rate.toStringAsFixed(2);
    mrpController.text = newProduct.rate.toStringAsFixed(2);
    selectedUOM = newProduct.uom;
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

  void dispose() {
    itemDescriptionController.dispose();
    qtyController.dispose();
    bonusQtyController.dispose();
    addlBonusQtyController.dispose();
    notesController.dispose();
    rateController.dispose();
    mrpController.dispose();
    discountController.dispose();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              suffixIcon: const Icon(Icons.event, size: 20, color: Color(0xFF4db1b3)),
            ),
            child: Text(
              '${value.month}/${value.day}/${value.year}',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ),
      ],
    );
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
                  constraints: const BoxConstraints(maxHeight: 360, minWidth: 240),
                  child: SizedBox(
                    width: _fieldSize()?.width,
                    child: StatefulBuilder(
                      builder: (context, setSheetState) {
                        void applyFilter(String q) {
                          setSheetState(() {
                            final query = q.toLowerCase();
                            filtered = _options
                                .where((e) => e.value.toLowerCase().contains(query))
                                .toList(growable: false);
                          });
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                style: GoogleFonts.inter(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Search...',
                                  hintStyle: GoogleFonts.inter(color: Colors.grey.shade500),
                                  prefixIcon: const Icon(Icons.search, color: Color(0xFF4db1b3)),
                                ),
                                onChanged: applyFilter,
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFFF3F4F6)),
                            Flexible(
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  color: Color(0xFFF3F4F6),
                                ),
                                itemBuilder: (context, index) {
                                  final entry = filtered[index];
                                  final bool isSelected = widget.value == entry.key;
                                  return ListTile(
                                    dense: true,
                                    title: Text(entry.value),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle, color: Color(0xFF2563EB))
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
    final renderBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
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
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade500),
                suffixIcon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: widget.enabled ? const Color(0xFF4db1b3) : Colors.grey.shade400,
                ),
              ),
              child: Text(
                widget.value == null
                    ? (widget.hint ?? '')
                    : _labelForValue(widget.value),
                style: GoogleFonts.inter(
                  color: widget.enabled
                      ? (widget.value == null
                          ? Colors.grey.shade500
                          : Colors.grey.shade800)
                      : Colors.grey.shade500,
                  fontSize: 14,
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
            fontSize: 14,
            color: enabled ? Colors.grey.shade800 : Colors.grey.shade500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade500),
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

  const _NumberField({
    required this.label,
    required this.controller,
    this.min = 0,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        if (label.isNotEmpty) const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey.shade800,
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
          decoration: InputDecoration(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        if (label.isNotEmpty) const SizedBox(height: 8),
        InputDecorator(
          decoration: InputDecoration(),
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade800,
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

  const _SearchableItemField({
    required this.label,
    required this.controller,
    required this.selectedProduct,
    required this.onProductSelected,
  });

  @override
  State<_SearchableItemField> createState() => _SearchableItemFieldState();
}

class _SearchableItemFieldState extends State<_SearchableItemField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<Product> _filteredProducts = [];
  bool _isLoading = false;
  bool _isInitialLoad = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    print('🔍 [SearchableItemField] initState called');
    widget.controller.addListener(_onTextChanged);
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
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    if (query.isEmpty) {
      _filteredProducts = [];
      _removeOverlay();
      return;
    }

    // Debounce API calls - wait 500ms after user stops typing
    // Start searching with single character
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
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

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔍 [SearchableItemField] Getting CommonRepository');
      final commonRepository = getIt<CommonRepository>();
      print('🔍 [SearchableItemField] CommonRepository obtained');
      
      // Call API with search text
      print('🔍 [SearchableItemField] ⚠️ CALLING API with SearchText: "$searchText", CommandType: 105, DistributerId: 71');
      final items = await commonRepository.getItemList(
        distributerId: 71,
        searchText: searchText,
      );

      print('🔍 [SearchableItemField] API returned ${items.length} items');
      
      if (mounted) {
        setState(() {
          _filteredProducts = items.map((item) {
            return Product(
              id: item.id.toString(),
              name: item.text,
              manufacturer: item.name.isNotEmpty ? item.name : 'N/A',
              rate: item.rate,
              uom: item.uom > 0 ? 'UOM-${item.uom}' : 'Unit',
              availableQty: item.stock,
            );
          }).toList();
          _isLoading = false;
          _isInitialLoad = false;
          print('🔍 [SearchableItemField] Loaded ${_filteredProducts.length} products');
          
          if (_filteredProducts.isNotEmpty) {
            _showOverlay();
          } else {
            _removeOverlay();
          }
        });
      }
    } catch (e, stackTrace) {
      print('❌ [SearchableItemField] Error loading items: $e');
      print('❌ [SearchableItemField] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialLoad = false;
          _filteredProducts = [];
          _removeOverlay();
        });
      }
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width * 0.9,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0.0, 50.0),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
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
                          padding: const EdgeInsets.all(16.0),
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
                          itemCount: _filteredProducts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                product.name,
                                style: GoogleFonts.inter(fontSize: 14),
                              ),
                              subtitle: product.manufacturer != 'N/A'
                                  ? Text(
                                      product.manufacturer,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    )
                                  : null,
                              trailing: Text(
                                'LKR ${product.rate.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onTap: () {
                                widget.controller.text = product.name;
                                widget.onProductSelected(product);
                                _removeOverlay();
                              },
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
            controller: widget.controller,
            style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
              hintText: 'Type to search items...',
              suffixIcon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search),
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

  const _SearchableCustomerField({
    required this.controller,
    required this.selectedCustomerCode,
    required this.onCustomerSelected,
  });

  @override
  State<_SearchableCustomerField> createState() => _SearchableCustomerFieldState();
}

class _SearchableCustomerFieldState extends State<_SearchableCustomerField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<Customer> _filteredCustomers = [];
  bool _isLoading = false;
  int? _bizUnit;
  Timer? _debounceTimer;
  bool _isSettingCustomer = false; // Flag to prevent listener from triggering when setting customer

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _initializeBizUnit();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounceTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  Future<void> _initializeBizUnit() async {
    try {
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();

      if (user == null) return;

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

      if (mounted) {
        setState(() {
          _bizUnit = bizUnit;
        });
      }
    } catch (e) {
      print('Error initializing bizUnit: $e');
    }
  }

  void _onTextChanged() {
    // Skip if we're programmatically setting the customer
    if (_isSettingCustomer) {
      return;
    }
    
    final query = widget.controller.text.trim();
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    if (query.isEmpty) {
      _filteredCustomers = [];
      _removeOverlay();
      return;
    }

    // Debounce API calls - wait 500ms after user stops typing
    // Start searching with single character
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty && _bizUnit != null) {
        _searchCustomers(query);
      } else {
        _filteredCustomers = [];
        _removeOverlay();
      }
    });
  }

  Future<void> _searchCustomers(String searchText) async {
    if (_bizUnit == null) {
      await _initializeBizUnit();
      if (_bizUnit == null) return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final commonRepository = getIt<CommonRepository>();
      print('🔍 [SearchableCustomerField] Searching customers with: "$searchText"');
      
      // Call API with search text
      final items = await commonRepository.getCustomerList(
        bizUnit: _bizUnit!,
        customerId: null,
        searchText: searchText.isEmpty ? null : searchText,
      );

      if (mounted) {
        setState(() {
          // Convert CommonDropdownItem to Customer
          _filteredCustomers = items.map((item) {
            return Customer(
              code: item.id.toString(),
              name: item.text,
              address: item.address.isNotEmpty ? item.address : 'N/A',
            );
          }).toList();

          _isLoading = false;

          if (_filteredCustomers.isNotEmpty) {
            _showOverlay();
          } else {
            _removeOverlay();
          }
        });
      }
    } catch (e) {
      print('Error searching customers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _filteredCustomers = [];
          _removeOverlay();
        });
      }
    }
  }

  void _showOverlay() {
    _removeOverlay(); // Remove existing overlay if any

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width * 0.9,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0.0, 48.0),
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
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _filteredCustomers.isEmpty
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
                            final isSelected = widget.selectedCustomerCode == customer.code;
                            return InkWell(
                              onTap: () {
                                // Set flag to prevent text change listener from triggering
                                _isSettingCustomer = true;
                                // Set the customer name in the controller
                                widget.controller.text = customer.name;
                                // Remove overlay first
                                _removeOverlay();
                                // Unfocus the TextField to close keyboard
                                FocusScope.of(context).unfocus();
                                // Call the callback to update parent state
                                widget.onCustomerSelected(customer);
                                // Reset flag after a short delay
                                Future.delayed(const Duration(milliseconds: 100), () {
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            customer.name,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade900,
                                            ),
                                          ),
                                          if (customer.address != 'N/A') ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              customer.address,
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

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        style: GoogleFonts.inter(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Type to search customers...',
          suffixIcon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.search),
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
        onTap: () {
          if (widget.controller.text.isNotEmpty && _filteredCustomers.isNotEmpty) {
            _showOverlay();
          }
        },
      ),
    );
  }
}

// Helper function to load UOM for an item
Future<void> _loadUOMForItem(_LineItem item, int itemId, VoidCallback onChanged) async {
  try {
    print('🔵 Loading UOM for ItemId: $itemId');
    final commonRepository = getIt<CommonRepository>();
    final uomList = await commonRepository.getUOMList(itemId: itemId);
    item.uomOptions = uomList.map((uomItem) => uomItem.text).toList();
    // Auto-select first UOM if available (always auto-select, even if one was previously selected)
    if (item.uomOptions.isNotEmpty) {
      item.selectedUOM = item.uomOptions.first;
      print('✅ Auto-selected UOM: ${item.selectedUOM}');
    }
    onChanged(); // Trigger rebuild to update UI
    print('✅ Loaded ${item.uomOptions.length} UOM options');
  } catch (e) {
    print('Error loading UOM: $e');
    item.uomOptions = [];
    item.selectedUOM = null;
    onChanged(); // Still trigger rebuild even on error
  }
}

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
    final RenderBox? renderBox = _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final double? fieldWidth = renderBox?.size.width;
    final double overlayWidth = fieldWidth ?? MediaQuery.of(context).size.width * 0.9;

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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            borderSide: const BorderSide(color: Color(0xFF4db1b3)),
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
                                      ? const Color(0xFF4db1b3).withOpacity(0.05)
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
              hintText: '-- Select UOM --',
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
