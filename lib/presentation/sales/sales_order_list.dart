import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/routes/routes.dart';
import 'package:boilerplate/domain/repository/sales/sales_repository.dart';
import 'package:boilerplate/domain/entity/sales/sales_api_models.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/core/widgets/app_dropdowns.dart';

class SaleOrderListScreen extends StatefulWidget {
  const SaleOrderListScreen({super.key});
  @override
  State<SaleOrderListScreen> createState() => _SaleOrderListScreenState();
}

class _SaleOrderListScreenState extends State<SaleOrderListScreen>
    with SingleTickerProviderStateMixin {
  final searchCtrl = TextEditingController();
  final fromCtrl = TextEditingController();
  final toCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String customer = '';
  String status = '';

  // API data
  List<SalesOrderApiItem> _apiOrders = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _loadError;
  int _currentPage = 1;
  final int _pageSize = 15;
  bool _hasMore = true;

  // Date filters
  DateTime? _fromDate;
  DateTime? _toDate;

  // Customer list from API
  List<String> _customerList = ['All Customers'];
  String _selectedCustomer = 'All Customers';

  // Currency list from API
  List<String> _currencyList = ['Select All', 'USD', 'LKR'];
  Set<String> _selectedCurrencies = {};

  // // Filter modal state
  // AnimationController? _filterModalController;
  // Animation<Offset>? _filterModalAnimation;
  // bool _showFilterModal = false;
  // VoidCallback? _pendingFilterApply;
  // final ScrollController _filterScrollController = ScrollController();

  // // Filter state - simplified like deviation
  // String? _status;
  // String? _fromStore;
  // String? _issueNo;
  // DateTime? _stDateFrom;
  // DateTime? _stDateTo;

  // // Filter options
  // final List<String> _statusList = ['Approved', 'Drafted', 'Cancelled'];
  // final List<String> _fromStoreList = ['Inventory', 'Customer Store'];
  // List<String> _issueNoList = [];

  // // Column filter state - keep for complex filters
  // final Map<String, ColumnFilterState> _columnFilters = {
  //   'stDate': ColumnFilterState(),
  //   'fromStore': ColumnFilterState(),
  //   'itemDetails': ColumnFilterState(),
  // };

  // // Status filter state (single-select to match tour plan style)
  // String? _selectedStatus;

  // // Issue No filter state (single-select to match tour plan style)
  // String? _selectedIssueNo;

  // // Old filter methods - keeping for compatibility but not used in new card-based layout
  // String? _activeFilterColumn;

  // // API-loaded data
  // List<CustomerIssueItem> _issues = [];
  // // Store full API items by ID for editing
  // final Map<String, ItemIssueApiItem> _apiItemsById = {};
  // String? _loadError;
  // int _currentPage = 1;
  // final int _pageSize = 15;
  // bool _hasMore = true;

  // // Cached filtered issues for performance optimization
  // List<CustomerIssueItem>? _cachedFilteredIssues;

  // final List<String> _filterOperators = [
  //   'Is equal to',
  //   'Is not equal to',
  //   'Starts with',
  //   'Contains',
  //   'Does not contain',
  //   'Ends with',
  //   'Is null',
  //   'Is not null',
  //   'Is empty',
  //   'Is not empty',
  //   'Has no value',
  //   'Has value',
  // ];

  // final List<String> _dateFilterOperators = [
  //   'Is equal to',
  //   'Is not equal to',
  //   'Is after or equal to',
  //   'Is after',
  //   'Is before or equal to',
  //   'Is before',
  //   'Is null',
  //   'Is not null',
  // ];
  // need to set same filter for this screen
  // Initialize filter modal animation
  AnimationController? _filterModalController;
  Animation<Offset>? _filterModalAnimation;
  bool _showFilterModal = false;
  VoidCallback? _pendingFilterApply;
  final ScrollController _filterScrollController = ScrollController();

  // Filter state
  String? _status;
  String? _transactionStatus;
  String? _SOType;

  // Filter options
  List<String> _statusList = ['Select All']; // Will be loaded from API
  List<String> _transactionStatusList = ['Select All']; // Will be loaded from API
  List<String> _SOTypeList = ['Select All']; // Will be loaded from API
  bool _isLoadingStatusFilters = false;
  bool _isLoadingTransactionStatusFilters = false;
  bool _isLoadingSOTypeFilters = false;
  bool _isFilterByExpanded = true; // Collapsible Filter By section

  // Column filter state - keep for complex filters
  final Map<String, ColumnFilterState> _columnFilters = {
    'date': ColumnFilterState(),
    'soNumber': ColumnFilterState(),
    'customer': ColumnFilterState(),
    'itemDetails': ColumnFilterState(),
    'type': ColumnFilterState(),
    'deliveryDate': ColumnFilterState(),
    'currency': ColumnFilterState(),
    'quantity': ColumnFilterState(),
    'bonusQty': ColumnFilterState(),
    'addlBonusQty': ColumnFilterState(),
    'amount': ColumnFilterState(),
    'despatchedQty': ColumnFilterState(),
    'despatchNo': ColumnFilterState(),
    'invoiceNo': ColumnFilterState(),
    'status': ColumnFilterState(),
    'transactionStatus': ColumnFilterState(),
    'soType': ColumnFilterState(),
  };


  // Status filter state (multi-select like Currency)
  Set<String> _selectedStatuses = {};
  Set<String> _selectedTransactionStatuses = {}; // Changed to multi-select Set
  Set<String> _selectedSOTypes = {};

  @override
  void initState() {
    super.initState();

    _filterModalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Set default dates (last month to today)
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, now.day);
    _fromDate = lastMonth;
    _toDate = now;
    fromCtrl.text = _formatDateForDisplay(_fromDate!);
    toCtrl.text = _formatDateForDisplay(_toDate!);

    // Load data from API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatusFilters();
      _loadTransactionStatusFilters();
      _loadSOTypeFilters();
      _loadCurrencyFilters();
      _loadSalesOrders();
    });
    
    // Add scroll listener for infinite scroll
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadStatusFilters() async {
    if (_isLoadingStatusFilters) return;

    setState(() {
      _isLoadingStatusFilters = true;
    });

    try {
      // Get bizUnit from user
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();
      if (user == null) {
        setState(() {
          _isLoadingStatusFilters = false;
        });
        return;
      }

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
      final statusFilters = await salesRepository.getStatusFilters(bizUnit: bizUnit);

      if (mounted) {
        setState(() {
          // Add "Select All" at the beginning if not already present
          _statusList = ['Select All', ...statusFilters];
          _isLoadingStatusFilters = false;
        });
      }
    } catch (e) {
      print('Error loading status filters: $e');
      if (mounted) {
        setState(() {
          _isLoadingStatusFilters = false;
          // Keep default list on error
          _statusList = ['Select All'];
        });
      }
    }
  }

  Future<void> _loadTransactionStatusFilters() async {
    if (_isLoadingTransactionStatusFilters) return;

    setState(() {
      _isLoadingTransactionStatusFilters = true;
    });

    try {
      // Get bizUnit from user
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();
      if (user == null) {
        setState(() {
          _isLoadingTransactionStatusFilters = false;
        });
        return;
      }

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
      final transactionStatusFilters = await salesRepository.getTransactionStatusFilters(bizUnit: bizUnit);

      if (mounted) {
        setState(() {
          // Add "Select All" at the beginning if not already present
          _transactionStatusList = ['Select All', ...transactionStatusFilters];
          _isLoadingTransactionStatusFilters = false;
        });
      }
    } catch (e) {
      print('Error loading transaction status filters: $e');
      if (mounted) {
        setState(() {
          _isLoadingTransactionStatusFilters = false;
          // Keep default list on error
          _transactionStatusList = ['Select All'];
        });
      }
    }
  }

  Future<void> _loadSOTypeFilters() async {
    if (_isLoadingSOTypeFilters) return;

    setState(() {
      _isLoadingSOTypeFilters = true;
    });

    try {
      // Get bizUnit from user
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();
      if (user == null) {
        setState(() {
          _isLoadingSOTypeFilters = false;
        });
        return;
      }

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
      final soTypeFilters = await salesRepository.getSOTypeFilters(bizUnit: bizUnit);

      if (mounted) {
        setState(() {
          // Add "Select All" at the beginning if not already present
          _SOTypeList = ['Select All', ...soTypeFilters];
          _isLoadingSOTypeFilters = false;
        });
      }
    } catch (e) {
      print('Error loading SO type filters: $e');
      if (mounted) {
        setState(() {
          _isLoadingSOTypeFilters = false;
          // Keep default list on error
          _SOTypeList = ['Select All'];
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when within 200 pixels of bottom
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _loadMore();
      }
    }
  }

  Future<void> _loadCurrencyFilters() async {
    try {
      // Get bizUnit from user
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();
      if (user == null) {
        return;
      }

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
      final currencyFilters = await salesRepository.getCurrencyFilters(bizUnit: bizUnit);

      if (mounted) {
        setState(() {
          // Add "Select All" at the beginning if not already present
          _currencyList = ['Select All', ...currencyFilters];
        });
      }
    } catch (e) {
      print('Error loading currency filters: $e');
      if (mounted) {
        setState(() {
          // Keep default list on error
          _currencyList = ['Select All', 'USD', 'LKR'];
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    _currentPage++;
    await _loadSalesOrders(refresh: false);
    
    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    searchCtrl.dispose();
    fromCtrl.dispose();
    toCtrl.dispose();
    super.dispose();
  }

  String _formatDateForDisplay(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${_mon(date.month)}-${date.year}';
  }

  Future<void> _handleDeleteOrder(SalesOrderApiItem order) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Sales Order'),
          content: Text(
            'Are you sure you want to delete sales order ${order.soNumber ?? 'SO-${order.id}'}? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Get user details
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();

      if (user == null) {
        throw Exception('User not available');
      }

      final userId = user.userId ?? user.id;

      // Get bizUnit from UserDetailStore
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

      // Call delete API
      final salesRepository = getIt<SalesRepository>();
      await salesRepository.deleteSalesOrder(
        id: order.id,
        bizunit: bizUnit,
        userId: userId,
      );

      // Close loading indicator
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sales order ${order.soNumber ?? 'SO-${order.id}'} deleted successfully',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      // Refresh the list
      _loadSalesOrders(refresh: true);
    } catch (e) {
      // Close loading indicator
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show error message
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

  /// Load Sales Orders from API
  Future<void> _loadSalesOrders({bool refresh = false}) async {
    if (!mounted) return;

    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _apiOrders.clear();
    }

    if (!_hasMore && !refresh) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      // Get user info from SharedPreferences (for bizUnit and userId)
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();

      if (user == null) {
        throw Exception('User not available');
      }

      // Get userId from user
      final userId = user.userId ?? user.id;

      // Get bizUnit from UserDetailStore
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

      // Get menuId (1110 for Sales Order List as per API documentation)
      final menuId = 1110;

      // Prepare date filters - use yyyy-MM-dd format (no time) as per API requirements
      String? fromDateStr;
      if (_fromDate != null) {
        fromDateStr = DateFormat("yyyy-MM-dd").format(_fromDate!);
      }

      String? toDateStr;
      if (_toDate != null) {
        toDateStr = DateFormat("yyyy-MM-dd").format(_toDate!);
      }

      // Prepare search text
      String? searchText =
          searchCtrl.text.trim().isEmpty ? null : searchCtrl.text.trim();

      // Build FilterExpression from all active filters
      String? filterExpression = _buildFilterExpression();
      
      // Map Transaction Status to IsFullyUsed numeric value
      int? isFullyUsed;
      if (_selectedTransactionStatuses.isNotEmpty && !_selectedTransactionStatuses.contains('Select All')) {
        // Get the first selected transaction status (since we're using single select in dropdown)
        final selectedStatus = _selectedTransactionStatuses.first;
        isFullyUsed = _mapTransactionStatusToIsFullyUsed(selectedStatus);
      }

      final salesRepository = getIt<SalesRepository>();
      final response = await salesRepository.getSalesOrderList(
        id: null,
        pageNumber: _currentPage,
        pageSize: _pageSize,
        sortOrder: 0,
        bizunit: bizUnit,
        active: null, // null as per working API call
        sortDir: 1, // 1 as per working API call
        searchText: searchText,
        sortField: 'Date', // Capitalized as per working API call
        filterExpression: filterExpression,
        sortExpression: null,
        fromDate: fromDateStr,
        toDate: toDateStr,
        fieldName: null,
        pageName: null,
        userId: userId, // Pass userId in listing API to fetch records
        menuId: menuId,
        url:
            '/sales/salescontract/list', // Relative path as per working API call
        isFullyUsed: isFullyUsed,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _apiOrders = response.items;
            _currentPage = 1;
          } else {
            _apiOrders.addAll(response.items);
          }

          _hasMore = response.items.length >= _pageSize;
          _isLoading = false;
          _isLoadingMore = false;

          // Debug logging
          print('📊 API Response: ${response.items.length} items received');
          print('📊 _apiOrders length: ${_apiOrders.length}');
          print('📊 _filteredOrders length: ${_filteredOrders.length}');
          print('📊 _displayOrders length: ${_displayOrders.length}');

          // Update customer list from API data
          final customers = response.items
              .map((item) => item.customerName ?? item.customer ?? '')
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList();
          _customerList = ['All Customers', ...customers];
          
          // Currency list is now loaded separately via _loadCurrencyFilters()
        });
      }
    } catch (e) {
      print('Error loading Sales Orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Failed to load sales orders: ${e.toString()}';
        });
      }
    }
  }

  List<Map<String, String>> get _displayOrders {
    return _apiOrders.map((item) {
      // Parse date
      String dateStr = '';
      if (item.date != null) {
        try {
          final date = DateTime.parse(item.date!);
          dateStr = _formatDateForDisplay(date);
        } catch (e) {
          dateStr = item.date ?? '';
        }
      }

      // Format amount
      String amountStr =
          '${item.currencyText ?? 'LKR'}${_formatCurrency(item.amount)}';

      // Get status text
      String statusText = item.statusText ?? 'Pending';
      String deliveryText = item.isClosed == 1 ? 'Delivered' : 'Pending';

      return {
        'id': item.id.toString(),
        'date': dateStr,
        'order': item.soNumber ?? '',
        'customer': item.customerName ?? item.customer ?? '',
        'qty': (item.totalQuantity ?? 0).toString(),
        'amount': amountStr,
        'status': statusText,
        'delivery': deliveryText,
      };
    }).toList();
  }

  String _formatCurrency(double value) {
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (i > 0 && ((count == 3) || (count > 3 && (count - 3) % 2 == 0))) {
        buf.write(',');
      }
    }
    return buf.toString().split('').reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 800;
    const Color tealGreen = Color(0xFF4db1b3);
    final list = _filteredOrders;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadSalesOrders(refresh: true);
        },
        color: tealGreen,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // Header Section
            SliverToBoxAdapter(
              child: _buildHeader(isTablet, tealGreen),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: isTablet ? 14 : 2),
            ),
            // Filters Section
            // SliverToBoxAdapter(
            //   child: _buildFiltersSection(isTablet, tealGreen),
            // ),
            SliverToBoxAdapter(
              child: SizedBox(height: isTablet ? 14 : 12),
            ),
            // List of orders
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isTablet ? 16 : 12,
                0,
                isTablet ? 16 : 12,
                16,
              ),
              sliver: _isLoading && _apiOrders.isEmpty
                  ? SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    )
                  : _loadError != null && _apiOrders.isEmpty
                      ? SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    size: 64, color: Colors.red.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Failed to load sales orders',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _loadError!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _loadSalesOrders(refresh: true),
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: tealGreen,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : list.isEmpty
                          ? SliverToBoxAdapter(
                              child: Container(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inbox,
                                        size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No sales orders found',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your search or filter criteria',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  // Show loading indicator at the end
                                  if (index >= list.length) {
                                    return _isLoadingMore && index == list.length
                                        ? Container(
                                            padding: const EdgeInsets.all(20),
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF4db1b3),
                                                ),
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink();
                                  }
                                  
                                  final order = list[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _SalesOrderCard(
                                      order: order,
                                      onView: () {
                                        Navigator.pushNamed(
                                          context,
                                          Routes.saleView,
                                          arguments: {
                                            'orderId': order.id.toString(),
                                            'orderData': order,
                                          },
                                        );
                                      },
                                      onEdit: () async {
                                        final result = await Navigator.pushNamed(
                                          context,
                                          Routes.saleCreate,
                                          arguments: {
                                            'orderId': order.id.toString(),
                                            'orderData': order,
                                          },
                                        );
                                        // Refresh list if order was saved/submitted
                                        if (result == true) {
                                          _loadSalesOrders(refresh: true);
                                        }
                                      },
                                      onDelete: () => _handleDeleteOrder(order),
                                    ),
                                  );
                                },
                                childCount: list.length + (_isLoadingMore ? 1 : 0),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet, Color tealGreen) {
    final bool isMobile = !isTablet;
    const double buttonHeight = 48;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 8 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with filter icon on the right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
          Text(
            'Sales Orders',
            style: GoogleFonts.inter(
              fontSize: isTablet ? 20 : 18,
              fontWeight: FontWeight.normal,
              color: Colors.grey[900],
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: isTablet ? 6 : 4),
          Text(
            'View and manage sales orders',
            style: GoogleFonts.inter(
              fontSize: isTablet ? 13 : 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              letterSpacing: 0.2,
                      ),
                    ),
                  ],
            ),
          ),
          // Filter Icon with Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: isMobile ? 48 : 56,
                height: isMobile ? 48 : 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openFilterModal,
                    borderRadius: BorderRadius.circular(12),
                    child: Icon(
                      Icons.filter_alt,
                      color: tealGreen,
                      size: isMobile ? 24 : 28,
                    ),
                  ),
                ),
              ),
              if (_getFilterCount() > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: EdgeInsets.all(isMobile ? 3 : 4),
                    decoration: BoxDecoration(
                      color: tealGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    constraints: BoxConstraints(
                      minWidth: isMobile ? 18 : 20,
                      minHeight: isMobile ? 18 : 20,
                    ),
                    child: Center(
                      child: Text(
                        _getFilterCount().toString(),
                        style: TextStyle(
                          fontSize: isMobile ? 9 : 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                    ),
                ],
                ),
            ],
          ),

          const SizedBox(height: 25),

          Row(
            children: [
              // Sale Order Button
              Expanded(
                child: SizedBox(
                  height: buttonHeight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        Routes.saleCreate,
                      );
                      // Refresh list if order was created
                      if (result == true) {
                        _loadSalesOrders(refresh: true);
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    // text lenght is cutting need fix it
                    label: Text(
                      'New SO',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),

                    style: FilledButton.styleFrom(
                      backgroundColor: tealGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.format_list_bulleted_outlined,
                        size: 18,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _apiOrders.isEmpty
                            ? 'No records'
                            : '${_apiOrders.length} ${_apiOrders.length == 1 ? 'record' : 'records'}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget _buildFiltersSection(bool isTablet, Color tealGreen) {
  //   final bool isMobile = !isTablet;
  //   return Padding(
  //     padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
  //     child: SaleOrdersHeader(
  //       onRaiseOrder: () {
  //         Navigator.pushNamed(context, Routes.saleCreate);
  //       },
  //       searchCtrl: searchCtrl,
  //       fromCtrl: fromCtrl,
  //       toCtrl: toCtrl,
  //       customers: _customerList,
  //       statuses: const ['All', 'Pending', 'Approved', 'Draft', 'Delivered'],
  //       selectedCustomer: _selectedCustomer,
  //       selectedStatus: status,
  //       onCustomerChanged: (v) {
  //         setState(() => _selectedCustomer = v ?? 'All Customers');
  //         _loadSalesOrders(refresh: true);
  //       },
  //       onStatusChanged: (v) {
  //         setState(() => status = v ?? '');
  //         _loadSalesOrders(refresh: true);
  //       },
  //       onSearchChanged: () {
  //         _loadSalesOrders(refresh: true);
  //       },
  //       onFromDateChanged: (date) {
  //         setState(() {
  //           _fromDate = date;
  //           if (date != null) {
  //             fromCtrl.text = _formatDateForDisplay(date);
  //           }
  //         });
  //         _loadSalesOrders(refresh: true);
  //       },
  //       onToDateChanged: (date) {
  //         setState(() {
  //           _toDate = date;
  //           if (date != null) {
  //             toCtrl.text = _formatDateForDisplay(date);
  //           }
  //         });
  //         _loadSalesOrders(refresh: true);
  //       },
  //     ),
  //   );
  // }

    void _openFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildFilterModal(),
    );
  }
  Widget _buildFilterModal() {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Filters',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Scrollable Content
              Flexible(
        child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                      const SizedBox(height: 8),

                      /// FILTER BY SECTION (Collapsible with attractive border)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey[200]!.withOpacity(0.5),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header (clickable)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setModalState(() {
                                    _isFilterByExpanded = !_isFilterByExpanded;
                                  });
                                },
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(12),
                                      topRight: const Radius.circular(12),
                                      bottomLeft: _isFilterByExpanded
                                          ? Radius.zero
                                          : const Radius.circular(12),
                                      bottomRight: _isFilterByExpanded
                                          ? Radius.zero
                                          : const Radius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.filter_list,
                                        color: Colors.grey[700],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Filter By',
                                        style: GoogleFonts.inter(
                                          fontSize: isTablet ? 18 : 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[900],
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        _isFilterByExpanded
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: Colors.grey[600],
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            // Content (expandable)
                            if (_isFilterByExpanded) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(12),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    // From, To, Transaction Status in a row (responsive)
                                    LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 600;
                  if (isWide) {
                    // Wide layout: All in one row
                    return Row(
                      children: [
                        // From Date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'From',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _fromDate ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                    helpText: 'Select From Date',
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _fromDate = picked;
                                      fromCtrl.text = _formatDateForDisplay(picked);
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.grey[50],
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          fromCtrl.text.isEmpty
                                              ? 'Select Date'
                                              : fromCtrl.text,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.calendar_today,
                                        size: 18,
                                        color: Colors.grey[600],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // To Date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'To',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _toDate ?? DateTime.now(),
                                    firstDate: _fromDate ?? DateTime(2000),
                                    lastDate: DateTime(2100),
                                    helpText: 'Select To Date',
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _toDate = picked;
                                      toCtrl.text = _formatDateForDisplay(picked);
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.grey[50],
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          toCtrl.text.isEmpty
                                              ? 'Select Date'
                                              : toCtrl.text,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.calendar_today,
                                        size: 18,
                                        color: Colors.grey[600],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Transaction Status Dropdown
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Transaction',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  // Build options list dynamically - "All" first, then all transaction statuses except "Select All"
                                  final List<String> availableOptions = _transactionStatusList
                                      .where((s) => s != 'Select All')
                                      .toList();
                                  
                                  final List<String> options = ['All', ...availableOptions];
                                  
                                  // Compute current value - show "All" if nothing selected, otherwise show first selected
                                  // Make sure the value exists in options, otherwise default to "All"
                                  String currentValue = 'All';
                                  if (_selectedTransactionStatuses.isNotEmpty) {
                                    final selected = _selectedTransactionStatuses.first;
                                    if (options.contains(selected)) {
                                      currentValue = selected;
                                    } else {
                                      // If selected value is not in options, clear it
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (mounted) {
                                          setState(() {
                                            _selectedTransactionStatuses.clear();
                                          });
                                        }
                                      });
                                    }
                                  }
                                  
                                  print('🔵 Transaction dropdown (wide) - currentValue: $currentValue, options: $options (${options.length} items), selected: $_selectedTransactionStatuses');
                                  
                                  return SearchableDropdown(
                                    key: ValueKey('transaction_wide_${currentValue}_${options.length}'),
                                    options: options,
                                    value: currentValue,
                                  onChanged: (String? newValue) {
                                    print('🔵 Transaction dropdown (wide) onChanged: $newValue (previous: $currentValue, current selected: $_selectedTransactionStatuses)');
                                    if (newValue == null || newValue.isEmpty) {
                                      print('🔵 Ignoring null/empty value');
                                      return;
                                    }
                                    
                                    if (!mounted) return;
                                    
                                    // Update state immediately and synchronously
                                    setState(() {
                                      if (newValue == 'All') {
                                        _selectedTransactionStatuses.clear();
                                        print('🔵 Cleared transaction status filter - showing all');
                                      } else if (options.contains(newValue)) {
                                        _selectedTransactionStatuses = {newValue};
                                        print('🔵 Set transaction status filter to: $_selectedTransactionStatuses');
                                      } else {
                                        print('🔵 Warning: Selected value "$newValue" not in options, ignoring');
                                        return;
                                      }
                                    });
                                    
                                    print('🔵 After setState: _selectedTransactionStatuses = $_selectedTransactionStatuses');
                                    
                                    // Reload data after state update
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) {
                                        _loadSalesOrders(refresh: true);
                                      }
                                    });
                                  },
                                    hintText: 'Select Transaction',
                                    searchHintText: 'Search transaction status...',
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Narrow layout: Stacked
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'From',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _fromDate ?? DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                        helpText: 'Select From Date',
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _fromDate = picked;
                                          fromCtrl.text = _formatDateForDisplay(picked);
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey[300]!),
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.grey[50],
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              fromCtrl.text.isEmpty
                                                  ? 'Select Date'
                                                  : fromCtrl.text,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.calendar_today,
                                            size: 18,
                                            color: Colors.grey[600],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'To',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _toDate ?? DateTime.now(),
                                        firstDate: _fromDate ?? DateTime(2000),
                                        lastDate: DateTime(2100),
                                        helpText: 'Select To Date',
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _toDate = picked;
                                          toCtrl.text = _formatDateForDisplay(picked);
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey[300]!),
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.grey[50],
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              toCtrl.text.isEmpty
                                                  ? 'Select Date'
                                                  : toCtrl.text,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.calendar_today,
                                            size: 18,
                                            color: Colors.grey[600],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Transaction Status Dropdown
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transaction',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                // Build options list dynamically - "All" first, then all transaction statuses except "Select All"
                                final List<String> availableOptions = _transactionStatusList
                                    .where((s) => s != 'Select All')
                                    .toList();
                                
                                final List<String> options = ['All', ...availableOptions];
                                
                                // Compute current value - show "All" if nothing selected, otherwise show first selected
                                // Make sure the value exists in options, otherwise default to "All"
                                String currentValue = 'All';
                                if (_selectedTransactionStatuses.isNotEmpty) {
                                  final selected = _selectedTransactionStatuses.first;
                                  if (options.contains(selected)) {
                                    currentValue = selected;
                                  } else {
                                    // If selected value is not in options, clear it
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) {
                                        setState(() {
                                          _selectedTransactionStatuses.clear();
                                        });
                                      }
                                    });
                                  }
                                }
                                
                                print('🔵 Transaction dropdown (narrow) - currentValue: $currentValue, options: $options (${options.length} items), selected: $_selectedTransactionStatuses');
                                
                                return SearchableDropdown(
                                  key: ValueKey('transaction_narrow_${currentValue}_${options.length}'),
                                  options: options,
                                  value: currentValue,
                                  onChanged: (String? newValue) {
                                    print('🔵 Transaction dropdown (narrow) onChanged: $newValue (previous: $currentValue, current selected: $_selectedTransactionStatuses)');
                                    if (newValue == null || newValue.isEmpty) {
                                      print('🔵 Ignoring null/empty value');
                                      return;
                                    }
                                    
                                    if (!mounted) return;
                                    
                                    // Update state immediately and synchronously
                                    setState(() {
                                      if (newValue == 'All') {
                                        _selectedTransactionStatuses.clear();
                                        print('🔵 Cleared transaction status filter - showing all');
                                      } else if (options.contains(newValue)) {
                                        _selectedTransactionStatuses = {newValue};
                                        print('🔵 Set transaction status filter to: $_selectedTransactionStatuses');
                                      } else {
                                        print('🔵 Warning: Selected value "$newValue" not in options, ignoring');
                                        return;
                                      }
                                    });
                                    
                                    print('🔵 After setState: _selectedTransactionStatuses = $_selectedTransactionStatuses');
                                    
                                    // Reload data after state update
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) {
                                        _loadSalesOrders(refresh: true);
                                      }
                                    });
                                  },
                                  hintText: 'Select Transaction',
                                  searchHintText: 'Search transaction status...',
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                },
              ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 24),

              /// ADDITIONAL FILTERS
              _filterTrigger('Date', 'date', _dateOperators),
              const SizedBox(height: 12),
              _filterTrigger('SO Number', 'soNumber', _textOperators),
              const SizedBox(height: 12),
              
              // Status Filter (like Currency)
              _statusFilterTrigger(),
              const SizedBox(height: 12),
              
              // SO Type Filter (like Currency)
              _soTypeFilterTrigger(),
              const SizedBox(height: 12),
              
              // Transaction Status Filter (like Currency)
              _transactionStatusFilterTrigger(),
              const SizedBox(height: 12),
              
              _filterTrigger('Customer', 'customer', _textOperators),
              const SizedBox(height: 12),
              _filterTrigger('Item Details', 'itemDetails', _textOperators),
              const SizedBox(height: 12),
              _filterTrigger('Type', 'type', _textOperators),
              const SizedBox(height: 12),
              _filterTrigger('Delivery Date', 'deliveryDate', _dateOperators),
              const SizedBox(height: 12),
              _currencyFilterTrigger(),
              const SizedBox(height: 12),
              _filterTrigger('Quantity', 'quantity', _numberOperators),
              const SizedBox(height: 12),
              _filterTrigger('Bonus Qty', 'bonusQty', _numberOperators),
              const SizedBox(height: 12),
              _filterTrigger('Addl. Bonus Qty', 'addlBonusQty', _numberOperators),
              const SizedBox(height: 12),
              _filterTrigger('Amount', 'amount', _numberOperators),
              const SizedBox(height: 12),
              _filterTrigger('Despatched Qty', 'despatchedQty', _numberOperators),
              const SizedBox(height: 12),
              _filterTrigger('Despatch No', 'despatchNo', _textOperators),
              const SizedBox(height: 12),
              _filterTrigger('Invoice No', 'invoiceNo', _textOperators),

              const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          // Fixed Buttons at Bottom
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearAllFilters,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Color(0xFF4db1b3), width: 1.5),
                      ),
                      child: Text(
                        'Clear All',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4db1b3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Reload sales orders with new filters
                        _loadSalesOrders(refresh: true);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4db1b3),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Apply',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _currencyFilterTrigger() {
    final isActive = _selectedCurrencies.isNotEmpty;
    const Color tealGreen = Color(0xFF4db1b3);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _CurrencyFilterPopup(
              availableCurrencies: _currencyList,
              selectedCurrencies: _selectedCurrencies,
              onApply: (selected) {
                setState(() {
                  _selectedCurrencies = selected;
                });
                Navigator.pop(context);
              },
              onClear: () {
                setState(() {
                  _selectedCurrencies.clear();
                });
                Navigator.pop(context);
              },
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Currency',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[900],
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Icon(
                isActive ? Icons.filter_alt : Icons.filter_alt_outlined,
                color: isActive ? tealGreen : Colors.grey[400],
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterTrigger(String title, String key, List<String> operators) {
    final filterState = _columnFilters[key];
    if (filterState == null) {
      // If filter state doesn't exist, return empty widget
      return const SizedBox.shrink();
    }
    
    final isActive = filterState.isActive;
    const Color tealGreen = Color(0xFF4db1b3);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
          builder: (_) => _ColumnFilterPopup(
            filterState: filterState,
            operators: operators,
            onApply: () {
              setState(() {
                filterState.isActive = true;
              });
              Navigator.pop(context);
              // Reload sales orders with new filter
              _loadSalesOrders(refresh: true);
            },
            onClear: () {
              setState(() => filterState.clear());
              Navigator.pop(context);
              // Reload sales orders after clearing filter
              _loadSalesOrders(refresh: true);
            },
          ),
        );
      },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[900],
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Icon(
                isActive ? Icons.filter_alt : Icons.filter_alt_outlined,
                color: isActive ? tealGreen : Colors.grey[400],
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusFilterTrigger() {
    final isActive = _selectedStatuses.isNotEmpty;
    const Color tealGreen = Color(0xFF4db1b3);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _StatusFilterPopup(
              availableStatuses: _statusList,
              selectedStatuses: _selectedStatuses,
              onApply: (selected) {
                setState(() {
                  _selectedStatuses = selected;
                });
                Navigator.pop(context);
              },
              onClear: () {
                setState(() {
                  _selectedStatuses.clear();
                });
                Navigator.pop(context);
              },
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Status',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[900],
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Icon(
                isActive ? Icons.filter_alt : Icons.filter_alt_outlined,
                color: isActive ? tealGreen : Colors.grey[400],
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _soTypeFilterTrigger() {
    final isActive = _selectedSOTypes.isNotEmpty;
    const Color tealGreen = Color(0xFF4db1b3);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _SOTypeFilterPopup(
              availableSOTypes: _SOTypeList,
              selectedSOTypes: _selectedSOTypes,
              onApply: (selected) {
                setState(() {
                  _selectedSOTypes = selected;
                });
                Navigator.pop(context);
              },
              onClear: () {
                setState(() {
                  _selectedSOTypes.clear();
                });
                Navigator.pop(context);
              },
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'SO Type',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[900],
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Icon(
                isActive ? Icons.filter_alt : Icons.filter_alt_outlined,
                color: isActive ? tealGreen : Colors.grey[400],
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _transactionStatusFilterTrigger() {
    final isActive = _selectedTransactionStatuses.isNotEmpty;
    const Color tealGreen = Color(0xFF4db1b3);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _TransactionStatusFilterPopup(
              availableTransactionStatuses: _transactionStatusList,
              selectedTransactionStatuses: _selectedTransactionStatuses,
              onApply: (selected) {
                setState(() {
                  _selectedTransactionStatuses = selected;
                });
                Navigator.pop(context);
                _loadSalesOrders(refresh: true);
              },
              onClear: () {
                setState(() {
                  _selectedTransactionStatuses.clear();
                });
                Navigator.pop(context);
                _loadSalesOrders(refresh: true);
              },
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Transaction',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[900],
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Icon(
                isActive ? Icons.filter_alt : Icons.filter_alt_outlined,
                color: isActive ? tealGreen : Colors.grey[400],
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<SalesOrderApiItem> get _filteredOrders {
    // Check if FilterExpression is being used (if _buildFilterExpression returns non-null)
    // Also check if Transaction Status is selected (which uses IsFullyUsed field, not FilterExpression)
    final filterExpression = _buildFilterExpression();
    final hasFilterExpression = filterExpression != null && filterExpression.isNotEmpty;
    final hasTransactionStatusFilter = _selectedTransactionStatuses.isNotEmpty && 
                                       !_selectedTransactionStatuses.contains('Select All');
    final hasApiFiltering = hasFilterExpression || hasTransactionStatusFilter;
    
    if (hasApiFiltering) {
      // When API is filtering via FilterExpression or IsFullyUsed, just return the API results as-is
      // The API has already applied these filters, so we don't need to filter again
      if (hasFilterExpression && hasTransactionStatusFilter) {
        print('🔵 API filtering active (FilterExpression: $filterExpression, IsFullyUsed: ${_mapTransactionStatusToIsFullyUsed(_selectedTransactionStatuses.first)}), returning ${_apiOrders.length} items without client-side filtering');
      } else if (hasFilterExpression) {
        print('🔵 API filtering active (FilterExpression: $filterExpression), returning ${_apiOrders.length} items without client-side filtering');
      } else if (hasTransactionStatusFilter) {
        print('🔵 API filtering active (IsFullyUsed: ${_mapTransactionStatusToIsFullyUsed(_selectedTransactionStatuses.first)}), returning ${_apiOrders.length} items without client-side filtering');
      }
      return _apiOrders;
    }
    
    // Otherwise, apply client-side filtering for any remaining filters
    print('🟢 No API filtering, applying client-side filtering to ${_apiOrders.length} items');
    return _apiOrders.where((o) {

      // NORMAL FILTERS
      // Status filter (multi-select)
      if (_selectedStatuses.isNotEmpty && !_selectedStatuses.contains('Select All')) {
        final status = o.statusText ?? '';
        if (!_selectedStatuses.contains(status)) {
          return false;
        }
      }

      // Transaction Status filter (multi-select) - only apply if not using API filtering
      if (_selectedTransactionStatuses.isNotEmpty && !_selectedTransactionStatuses.contains('Select All')) {
        final transactionStatus = (o.isClosed ?? 0) == 1 ? '100% Dispatched' : 'Pending';
        if (!_selectedTransactionStatuses.contains(transactionStatus)) {
          return false;
        }
      }

      // SO Type filter (multi-select)
      if (_selectedSOTypes.isNotEmpty && !_selectedSOTypes.contains('Select All')) {
        // Handle both API formats: 'N'/'B' or 'Normal'/'Bonus'
        String soTypeText;
        if (o.soType == 'N' || o.soType == 'Normal') {
          soTypeText = 'Normal';
        } else if (o.soType == 'B' || o.soType == 'Bonus') {
          soTypeText = 'Bonus';
        } else {
          soTypeText = o.soType ?? '';
        }
        
        if (!_selectedSOTypes.contains(soTypeText)) {
          return false;
        }
      }

      // Currency filter
      if (_selectedCurrencies.isNotEmpty && !_selectedCurrencies.contains('Select All')) {
        // Handle both currencyText and currency fields
        final currency = o.currencyText ?? o.currency ?? 'LKR';
        if (!_selectedCurrencies.contains(currency)) {
          return false;
        }
      }

      // COMPLEX FILTERS (only apply if not already filtered by API via FilterExpression)
      // Note: Date filter is handled by API via FilterExpression, so we skip client-side date filtering
      for (final f in _columnFilters.entries) {
        // Skip date filter as it's handled by API FilterExpression
        if (f.key == 'date') continue;
        
        if (!f.value.isActive) continue;
        final value = _getFieldValue(o, f.key);
        if (!_evaluateCondition(value, f.value)) return false;
      }

      return true;
    }).toList();
  }
  bool _evaluateCondition(dynamic fieldValue, ColumnFilterState filter) {
    bool eval(String op, String val) {
      if (op == 'Is null') return fieldValue == null || fieldValue.toString().isEmpty;
      if (op == 'Is not null') return fieldValue != null && fieldValue.toString().isNotEmpty;
      if (fieldValue == null) return false;

      final v = fieldValue.toString().toLowerCase();
      final c = val.toLowerCase();

      switch (op) {
        case 'Contains': return v.contains(c);
        case 'Does not contain': return !v.contains(c);
        case 'Is equal to': return v == c;
        case 'Is not equal to': return v != c;
        case 'Starts with': return v.startsWith(c);
        case 'Ends with': return v.endsWith(c);
        case 'Greater than': return double.tryParse(v) != null && double.parse(v) > double.parse(c);
        case 'Less than': return double.tryParse(v) != null && double.parse(v) < double.parse(c);
        default: return true;
      }
    }

    final r1 = eval(filter.condition1Operator, filter.condition1Value);
    final r2 = filter.condition2Value.isEmpty
        ? true
        : eval(filter.condition2Operator, filter.condition2Value);

    return filter.logicalOperator == 'And'
        ? r1 && r2
        : r1 || r2;
  }



  dynamic _getFieldValue(SalesOrderApiItem o, String key) {
    switch (key) {
      case 'date':
        return o.date;
      case 'soNumber':
        return o.soNumber;
      case 'customer':
        return o.customerName;
      case 'itemDetails':
        return o.itemName;
      case 'type':
        return o.typeText;
      case 'deliveryDate':
        return o.deliveryDate;
      case 'currency':
        return o.currencyText;
      case 'quantity':
        return o.totalQuantity;
      case 'bonusQty':
        return o.bonusQuantity;
      case 'addlBonusQty':
        return o.additionalBonusQuantity;
      case 'amount':
        return o.amount;
      case 'despatchedQty':
        return o.despatchedQty;
      case 'despatchNo':
        return o.despatchNo;
      case 'invoiceNo':
        return o.invoiceNo;
      case 'status':
        return o.statusText ?? '';
      case 'transactionStatus':
        return (o.isClosed ?? 0) == 1 ? '100% Dispatched' : 'Pending';
      case 'soType':
        if (o.soType == null) return '';
        return o.soType == 'N' ? 'Normal' : (o.soType == 'B' ? 'Bonus' : o.soType);
      default:
        return null;
    }
  }

  /// Build FilterExpression string from all active filters
  String? _buildFilterExpression() {
    final List<String> expressions = [];

    // Date filter from ColumnFilterState
    final dateFilter = _columnFilters['date'];
    if (dateFilter != null && dateFilter.isActive && dateFilter.condition1Value.isNotEmpty) {
      final fieldName = 'Date';
      final operator = dateFilter.condition1Operator;
      final value = dateFilter.condition1Value;
      
      if (operator == 'Is equal to' && value.isNotEmpty) {
        // Format date as 'yyyy-MM-dd'
        try {
          final date = DateTime.parse(value);
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          expressions.add("$fieldName = '$dateStr'");
        } catch (e) {
          // If parsing fails, use value as is
          expressions.add("$fieldName = '$value'");
        }
      } else if (operator == 'Is not equal to' && value.isNotEmpty) {
        try {
          final date = DateTime.parse(value);
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          expressions.add("$fieldName != '$dateStr'");
        } catch (e) {
          expressions.add("$fieldName != '$value'");
        }
      } else if (operator == 'Is after or equal to' && value.isNotEmpty) {
        try {
          final date = DateTime.parse(value);
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          expressions.add("$fieldName >= '$dateStr'");
        } catch (e) {
          expressions.add("$fieldName >= '$value'");
        }
      } else if (operator == 'Is after' && value.isNotEmpty) {
        try {
          final date = DateTime.parse(value);
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          expressions.add("$fieldName > '$dateStr'");
        } catch (e) {
          expressions.add("$fieldName > '$value'");
        }
      } else if (operator == 'Is before or equal to' && value.isNotEmpty) {
        try {
          final date = DateTime.parse(value);
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          expressions.add("$fieldName <= '$dateStr'");
        } catch (e) {
          expressions.add("$fieldName <= '$value'");
        }
      } else if (operator == 'Is before' && value.isNotEmpty) {
        try {
          final date = DateTime.parse(value);
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          expressions.add("$fieldName < '$dateStr'");
        } catch (e) {
          expressions.add("$fieldName < '$value'");
        }
      }
      
      // Handle second condition if present (for date filters with logical operator)
      if (dateFilter.condition2Value.isNotEmpty) {
        final operator2 = dateFilter.condition2Operator;
        final value2 = dateFilter.condition2Value;
        String? expr2;
        
        if (operator2 == 'Is equal to' && value2.isNotEmpty) {
          try {
            final date = DateTime.parse(value2);
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            expr2 = "$fieldName = '$dateStr'";
          } catch (e) {
            expr2 = "$fieldName = '$value2'";
          }
        } else if (operator2 == 'Is not equal to' && value2.isNotEmpty) {
          try {
            final date = DateTime.parse(value2);
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            expr2 = "$fieldName != '$dateStr'";
          } catch (e) {
            expr2 = "$fieldName != '$value2'";
          }
        } else if (operator2 == 'Is after or equal to' && value2.isNotEmpty) {
          try {
            final date = DateTime.parse(value2);
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            expr2 = "$fieldName >= '$dateStr'";
          } catch (e) {
            expr2 = "$fieldName >= '$value2'";
          }
        } else if (operator2 == 'Is after' && value2.isNotEmpty) {
          try {
            final date = DateTime.parse(value2);
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            expr2 = "$fieldName > '$dateStr'";
          } catch (e) {
            expr2 = "$fieldName > '$value2'";
          }
        } else if (operator2 == 'Is before or equal to' && value2.isNotEmpty) {
          try {
            final date = DateTime.parse(value2);
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            expr2 = "$fieldName <= '$dateStr'";
          } catch (e) {
            expr2 = "$fieldName <= '$value2'";
          }
        } else if (operator2 == 'Is before' && value2.isNotEmpty) {
          try {
            final date = DateTime.parse(value2);
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            expr2 = "$fieldName < '$dateStr'";
          } catch (e) {
            expr2 = "$fieldName < '$value2'";
          }
        }
        
        if (expr2 != null && expressions.isNotEmpty) {
          final logicalOp = dateFilter.logicalOperator == 'And' ? 'AND' : 'OR';
          final lastExpr = expressions.removeLast();
          expressions.add("($lastExpr $logicalOp $expr2)");
        }
      }
    }

    // Status filter (multi-select) - Always use IN() format with StatusText field name
    if (_selectedStatuses.isNotEmpty && !_selectedStatuses.contains('Select All')) {
      final statuses = _selectedStatuses.where((s) => s != 'Select All').map((s) => "'$s'").join(',');
      if (statuses.isNotEmpty) {
        expressions.add("StatusText IN($statuses)");
      }
    }

    // SO Type filter (multi-select) - Use separate conditions with AND as per API example
    if (_selectedSOTypes.isNotEmpty && !_selectedSOTypes.contains('Select All')) {
      final selectedTypes = _selectedSOTypes.where((s) => s != 'Select All').toList();
      if (selectedTypes.isNotEmpty) {
        // Build separate conditions with AND (as shown in API example)
        // Note: The example shows AND, but logically OR would make more sense
        // However, following the API example format: SOType = 'Normal' AND SOType = 'Bonus'
        final soTypeConditions = selectedTypes.map((s) {
          // Use display name directly (Normal/Bonus) as shown in API example
          return "SOType = '$s'";
        }).join(' AND ');
        expressions.add(soTypeConditions);
      }
    }

    // Currency filter (multi-select) - Always use IN() format as per API example
    if (_selectedCurrencies.isNotEmpty && !_selectedCurrencies.contains('Select All')) {
      final currencies = _selectedCurrencies.where((c) => c != 'Select All').map((c) => "'$c'").join(',');
      if (currencies.isNotEmpty) {
        expressions.add("Currency IN($currencies)");
      }
    }

    // Transaction Status filter is handled separately via IsFullyUsed field, not FilterExpression

    // Delivery Date filter (similar to Date filter)
    final deliveryDateFilter = _columnFilters['deliveryDate'];
    if (deliveryDateFilter != null && deliveryDateFilter.isActive && deliveryDateFilter.condition1Value.isNotEmpty) {
      final fieldName = 'DeliveryDate';
      final operator = deliveryDateFilter.condition1Operator;
      final value = deliveryDateFilter.condition1Value;
      
      if (operator == 'Is equal to' && value.isNotEmpty) {
        try {
          final date = DateTime.parse(value);
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          expressions.add("$fieldName = '$dateStr'");
        } catch (e) {
          expressions.add("$fieldName = '$value'");
        }
      } else if (operator == 'Is not equal to' && value.isNotEmpty) {
        try {
          final date = DateTime.parse(value);
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          expressions.add("$fieldName != '$dateStr'");
        } catch (e) {
          expressions.add("$fieldName != '$value'");
        }
      } else if (operator == 'Is after or equal to' && value.isNotEmpty) {
        try {
          final date = DateTime.parse(value);
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          expressions.add("$fieldName >= '$dateStr'");
        } catch (e) {
          expressions.add("$fieldName >= '$value'");
        }
      } else if (operator == 'Is after' && value.isNotEmpty) {
        try {
          final date = DateTime.parse(value);
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          expressions.add("$fieldName > '$dateStr'");
        } catch (e) {
          expressions.add("$fieldName > '$value'");
        }
      } else if (operator == 'Is before or equal to' && value.isNotEmpty) {
        try {
          final date = DateTime.parse(value);
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          expressions.add("$fieldName <= '$dateStr'");
        } catch (e) {
          expressions.add("$fieldName <= '$value'");
        }
      } else if (operator == 'Is before' && value.isNotEmpty) {
        try {
          final date = DateTime.parse(value);
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          expressions.add("$fieldName < '$dateStr'");
        } catch (e) {
          expressions.add("$fieldName < '$value'");
        }
      }
      
      // Handle second condition for delivery date if present
      if (deliveryDateFilter.condition2Value.isNotEmpty) {
        final operator2 = deliveryDateFilter.condition2Operator;
        final value2 = deliveryDateFilter.condition2Value;
        String? expr2;
        
        if (operator2 == 'Is equal to' && value2.isNotEmpty) {
          try {
            final date = DateTime.parse(value2);
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            expr2 = "$fieldName = '$dateStr'";
          } catch (e) {
            expr2 = "$fieldName = '$value2'";
          }
        } else if (operator2 == 'Is not equal to' && value2.isNotEmpty) {
          try {
            final date = DateTime.parse(value2);
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            expr2 = "$fieldName != '$dateStr'";
          } catch (e) {
            expr2 = "$fieldName != '$value2'";
          }
        } else if (operator2 == 'Is after or equal to' && value2.isNotEmpty) {
          try {
            final date = DateTime.parse(value2);
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            expr2 = "$fieldName >= '$dateStr'";
          } catch (e) {
            expr2 = "$fieldName >= '$value2'";
          }
        } else if (operator2 == 'Is after' && value2.isNotEmpty) {
          try {
            final date = DateTime.parse(value2);
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            expr2 = "$fieldName > '$dateStr'";
          } catch (e) {
            expr2 = "$fieldName > '$value2'";
          }
        } else if (operator2 == 'Is before or equal to' && value2.isNotEmpty) {
          try {
            final date = DateTime.parse(value2);
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            expr2 = "$fieldName <= '$dateStr'";
          } catch (e) {
            expr2 = "$fieldName <= '$value2'";
          }
        } else if (operator2 == 'Is before' && value2.isNotEmpty) {
          try {
            final date = DateTime.parse(value2);
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            expr2 = "$fieldName < '$dateStr'";
          } catch (e) {
            expr2 = "$fieldName < '$value2'";
          }
        }
        
        if (expr2 != null && expressions.isNotEmpty) {
          final logicalOp = deliveryDateFilter.logicalOperator == 'And' ? 'AND' : 'OR';
          final lastExpr = expressions.removeLast();
          expressions.add("($lastExpr $logicalOp $expr2)");
        }
      }
    }

    // Other column filters
    for (final entry in _columnFilters.entries) {
      final key = entry.key;
      final filter = entry.value;
      
      // Skip date and deliveryDate filters as they're already handled above
      if (key == 'date' || key == 'deliveryDate' || !filter.isActive || filter.condition1Value.isEmpty) {
        continue;
      }

      final fieldName = _getApiFieldName(key);
      if (fieldName == null) continue;

      final operator = filter.condition1Operator;
      final value = filter.condition1Value;

      // Check if this is a number field
      final isNumberField = ['quantity', 'bonusQty', 'addlBonusQty', 'amount', 'despatchedQty'].contains(key);

      String? expr;
      if (operator == 'Is equal to') {
        // For Type field, use IN() format even for single value as per API example
        if (key == 'type') {
          expr = "$fieldName IN('$value')";
        } else if (key == 'amount') {
          // For Amount field, use IN() format without quotes as per API example
          expr = "$fieldName IN($value)";
        } else if (isNumberField) {
          // For other number fields, use = with quotes
          expr = "$fieldName = '$value'";
        } else {
          expr = "$fieldName = '$value'";
        }
      } else if (operator == 'Is not equal to') {
        if (isNumberField) {
          expr = "$fieldName != '$value'";
        } else {
          expr = "$fieldName != '$value'";
        }
      } else if (operator == 'Contains') {
        expr = "$fieldName LIKE '%$value%'";
      } else if (operator == 'Starts with') {
        expr = "$fieldName LIKE '$value%'";
      } else if (operator == 'Ends with') {
        expr = "$fieldName LIKE '%$value'";
      } else if (operator == 'Greater than') {
        // For number fields, don't use quotes
        if (isNumberField) {
          expr = "$fieldName > $value";
        } else {
          expr = "$fieldName > '$value'";
        }
      } else if (operator == 'Less than') {
        // For number fields, don't use quotes
        if (isNumberField) {
          expr = "$fieldName < $value";
        } else {
          expr = "$fieldName < '$value'";
        }
      } else if (operator == 'Greater than or equal to') {
        // For number fields, don't use quotes
        if (isNumberField) {
          expr = "$fieldName >= $value";
        } else {
          expr = "$fieldName >= '$value'";
        }
      } else if (operator == 'Less than or equal to') {
        // For number fields, don't use quotes
        if (isNumberField) {
          expr = "$fieldName <= $value";
        } else {
          expr = "$fieldName <= '$value'";
        }
      } else if (operator == 'Is null') {
        expr = "$fieldName IS NULL";
      } else if (operator == 'Is not null') {
        expr = "$fieldName IS NOT NULL";
      }

      if (expr != null) {
        // Handle second condition if present
        if (filter.condition2Value.isNotEmpty) {
          final operator2 = filter.condition2Operator;
          final value2 = filter.condition2Value;
          String? expr2;
          
          if (operator2 == 'Is equal to') {
            // For Type field, use IN() format even for single value
            if (key == 'type') {
              expr2 = "$fieldName IN('$value2')";
            } else if (key == 'amount') {
              // For Amount field, use IN() format without quotes as per API example
              expr2 = "$fieldName IN($value2)";
            } else if (isNumberField) {
              // For other number fields, use = with quotes
              expr2 = "$fieldName = '$value2'";
            } else {
              expr2 = "$fieldName = '$value2'";
            }
          } else if (operator2 == 'Is not equal to') {
            if (isNumberField) {
              expr2 = "$fieldName != '$value2'";
            } else {
              expr2 = "$fieldName != '$value2'";
            }
          } else if (operator2 == 'Contains') {
            expr2 = "$fieldName LIKE '%$value2%'";
          } else if (operator2 == 'Starts with') {
            expr2 = "$fieldName LIKE '$value2%'";
          } else if (operator2 == 'Ends with') {
            expr2 = "$fieldName LIKE '%$value2'";
          } else if (operator2 == 'Greater than') {
            // For number fields, don't use quotes
            if (isNumberField) {
              expr2 = "$fieldName > $value2";
            } else {
              expr2 = "$fieldName > '$value2'";
            }
          } else if (operator2 == 'Less than') {
            // For number fields, don't use quotes
            if (isNumberField) {
              expr2 = "$fieldName < $value2";
            } else {
              expr2 = "$fieldName < '$value2'";
            }
          } else if (operator2 == 'Greater than or equal to') {
            // For number fields, don't use quotes
            if (isNumberField) {
              expr2 = "$fieldName >= $value2";
            } else {
              expr2 = "$fieldName >= '$value2'";
            }
          } else if (operator2 == 'Less than or equal to') {
            // For number fields, don't use quotes
            if (isNumberField) {
              expr2 = "$fieldName <= $value2";
            } else {
              expr2 = "$fieldName <= '$value2'";
            }
          }

          if (expr2 != null) {
            final logicalOp = filter.logicalOperator == 'And' ? 'AND' : 'OR';
            expr = "($expr $logicalOp $expr2)";
          }
        }
        expressions.add(expr);
      }
    }

    if (expressions.isEmpty) {
      return null;
    }

    return expressions.join(' AND ');
  }

  /// Map UI field names to API field names
  String? _getApiFieldName(String key) {
    switch (key) {
      case 'date':
        return 'Date';
      case 'soNumber':
        return 'SONumber';
      case 'customer':
        return 'Customer';
      case 'itemDetails':
        return 'ItemName'; // API uses ItemName, not ItemDetails
      case 'type':
        return 'TypeText'; // API uses TypeText, not Type
      case 'deliveryDate':
        return 'DeliveryDate';
      case 'currency':
        return 'Currency';
      case 'quantity':
        return 'TotalQuantity'; // API uses TotalQuantity, not Quantity
      case 'bonusQty':
        return 'BonusQuantity'; // API uses BonusQuantity, not BonusQty
      case 'addlBonusQty':
        return 'AdditionalBonusQuantity'; // API uses AdditionalBonusQuantity, not AddlBonusQty
      case 'amount':
        return 'Amount';
      case 'despatchedQty':
        return 'DespatchedQty';
      case 'despatchNo':
        return 'DespatchNo';
      case 'invoiceNo':
        return 'InvoiceNo';
      case 'status':
        return 'Status';
      case 'transactionStatus':
        return 'IsFullyUsed';
      case 'soType':
        return 'SOType';
      default:
        return null;
    }
  }

  /// Map Transaction Status text to IsFullyUsed numeric value
  /// Based on API: "Pending" -> 0 (or null), "100% Dispatched" -> 1
  int? _mapTransactionStatusToIsFullyUsed(String statusText) {
    final normalizedStatus = statusText.trim().toLowerCase();
    
    // Map common transaction statuses to numeric values
    if (normalizedStatus.contains('pending') || normalizedStatus == 'pending') {
      return 0; // Pending = not fully used
    } else if (normalizedStatus.contains('100%') || 
               normalizedStatus.contains('dispatched') ||
               normalizedStatus.contains('fully')) {
      return 1; // Fully dispatched = fully used
    } else {
      // Default: if it's not "Pending", assume it's fully dispatched
      // This handles cases like "100% Dispatched", "Fully Dispatched", etc.
      return 1;
    }
  }

  int _getFilterCount() {
    int count = 0;
    if (_selectedStatuses.isNotEmpty && !_selectedStatuses.contains('Select All')) count++;
    if (_selectedTransactionStatuses.isNotEmpty && !_selectedTransactionStatuses.contains('Select All')) count++;
    if (_selectedSOTypes.isNotEmpty && !_selectedSOTypes.contains('Select All')) count++;
    if (_selectedCurrencies.isNotEmpty && !_selectedCurrencies.contains('Select All')) count++;
    count += _columnFilters.values.where((f) => f.isActive).length;
    return count;
  }
  void _clearAllFilters() {
    setState(() {
      _selectedStatuses.clear();
      _selectedTransactionStatuses.clear();
      _selectedSOTypes.clear();
      _selectedCurrencies.clear();

      for (final f in _columnFilters.values) {
        f.clear();
      }
    });
    // Reload sales orders immediately after clearing filters
    _loadSalesOrders(refresh: true);
  }


}

class SaleOrdersHeader extends StatelessWidget {
  final VoidCallback onRaiseOrder;
  final TextEditingController searchCtrl;
  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final List<String> customers;
  final List<String> statuses;
  final String selectedCustomer;
  final String selectedStatus;
  final ValueChanged<String?> onCustomerChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback? onSearchChanged;
  final ValueChanged<DateTime?>? onFromDateChanged;
  final ValueChanged<DateTime?>? onToDateChanged;

  const SaleOrdersHeader({
    super.key,
    required this.onRaiseOrder,
    required this.searchCtrl,
    required this.fromCtrl,
    required this.toCtrl,
    required this.customers,
    required this.statuses,
    required this.selectedCustomer,
    required this.selectedStatus,
    required this.onCustomerChanged,
    required this.onStatusChanged,
    this.onSearchChanged,
    this.onFromDateChanged,
    this.onToDateChanged,
  });

  OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: 1),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 700;

    const borderColor = Color(0xFFE5E7EB);
    final placeholder = GoogleFonts.inter(
      color: const Color(0xFF9CA3AF),
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    const inputPad = EdgeInsets.symmetric(horizontal: 14, vertical: 12);

    final customerField = SizedBox(
      width: isTablet ? 260 : double.infinity,
      child: InputDecorator(
        decoration: InputDecoration(
          contentPadding: inputPad,
          enabledBorder: _fieldBorder(borderColor),
          focusedBorder: _fieldBorder(theme.colorScheme.primary),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: selectedCustomer.isEmpty ? null : selectedCustomer,
            hint: Text('Dr. Meera Joshi', style: placeholder),
            items: customers
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    ))
                .toList(),
            onChanged: onCustomerChanged,
          ),
        ),
      ),
    );

    final fromField = SizedBox(
      width: 130,
      child: TextField(
        controller: fromCtrl,
        readOnly: true,
        decoration: InputDecoration(
          contentPadding: inputPad,
          labelText: 'From',
          enabledBorder: _fieldBorder(borderColor),
          focusedBorder: _fieldBorder(theme.colorScheme.primary),
          hintText: '24-Aug-25',
          hintStyle: placeholder,
        ),
        onTap: () async {
          final now = DateTime.now();
          final initial = onFromDateChanged != null ? null : now;
          final picked = await showDatePicker(
            context: context,
            initialDate: initial ?? now,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null && onFromDateChanged != null) {
            onFromDateChanged!(picked);
          } else if (picked != null) {
            fromCtrl.text =
                '${picked.day.toString().padLeft(2, '0')}-${_mon(picked.month)}-${picked.year}';
          }
        },
      ),
    );

    final toField = SizedBox(
      width: 130,
      child: TextField(
        controller: toCtrl,
        readOnly: true,
        decoration: InputDecoration(
          contentPadding: inputPad,
          labelText: 'To',
          enabledBorder: _fieldBorder(borderColor),
          focusedBorder: _fieldBorder(theme.colorScheme.primary),
          hintText: '24-Sep-25',
          hintStyle: placeholder,
        ),
        onTap: () async {
          final now = DateTime.now();
          final initial = onToDateChanged != null ? null : now;
          final picked = await showDatePicker(
            context: context,
            initialDate: initial ?? now,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null && onToDateChanged != null) {
            onToDateChanged!(picked);
          } else if (picked != null) {
            toCtrl.text =
                '${picked.day.toString().padLeft(2, '0')}-${_mon(picked.month)}-${picked.year}';
          }
        },
      ),
    );

    final statusField = SizedBox(
      width: isTablet ? 160 : double.infinity,
      child: InputDecorator(
        decoration: InputDecoration(
          contentPadding: inputPad,
          enabledBorder: _fieldBorder(borderColor),
          focusedBorder: _fieldBorder(theme.colorScheme.primary),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: selectedStatus.isEmpty ? null : selectedStatus,
            hint: Text('Status', style: placeholder),
            items: statuses
                .map((s) => DropdownMenuItem(
                      value: s == 'All' ? '' : s,
                      child: Text(s),
                    ))
                .toList(),
            onChanged: onStatusChanged,
          ),
        ),
      ),
    );
// keep any value
    final searchField = const SizedBox.shrink();
    // Expanded(
    //   child: TextField(
    //     controller: searchCtrl,
    //     onChanged: (_) => onSearchChanged?.call(),
    //     decoration: InputDecoration(
    //       hintText: 'Search Sale Orders…',
    //       hintStyle: placeholder,
    //       contentPadding: inputPad,
    //       enabledBorder: _fieldBorder(borderColor),
    //       focusedBorder: _fieldBorder(theme.colorScheme.primary),
    //       suffixIcon: const Icon(Icons.search, color: Color(0xFF9AA0A6)),
    //     ),
    //   ),
    // );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filters
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: LayoutBuilder(
            builder: (context, c) {
              final isTablet = c.maxWidth >= 700;
              final children = <Widget>[
                SizedBox(
                    width: isTablet ? null : double.infinity,
                    child: customerField),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  fromField,
                  const SizedBox(width: 8),
                  toField,
                ]),
                statusField,
                if (isTablet) searchField,
              ];

              return Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: children,
                  ),
                  if (!isTablet) ...[
                    const SizedBox(height: 12),
                    Row(children: [Expanded(child: searchField)]),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SalesOrderCard extends StatelessWidget {
  final SalesOrderApiItem order;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _SalesOrderCard({
    required this.order,
    this.onView,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallMobile = screenWidth < 360;
    final isMobile = screenWidth < 600;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(.06), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isSmallMobile ? 12 : (isMobile ? 14 : 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isMobile ? 40 : 44,
                height: isMobile ? 40 : 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sell_outlined,
                  color: Color(0xFF4db1b3),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.soNumber ?? 'SO-${order.id}',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 12 : 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _getStatusChip(order.statusText ?? 'Pending'),
                  ],
                ),
              ),
              // Delete icon (only for draft orders) - at the right end
              Builder(
                builder: (context) {
                  final statusTextLower = order.statusText?.toLowerCase().trim() ?? '';
                  final isDraft = statusTextLower == 'drafted' || 
                                 statusTextLower == 'draft' ||
                                 order.status == 0;
                  
                  if (isDraft && onDelete != null) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
              height: 1, thickness: 1, color: Colors.black.withOpacity(.06)),
          const SizedBox(height: 10),
          _iconKvRow(
            context,
            Icons.calendar_today_outlined,
            'Date',
            order.date != null
                ? DateFormat('dd-MMM-yyyy').format(DateTime.parse(order.date!))
                : 'N/A',
          ),
          SizedBox(height: isMobile ? 6 : 8),
          _iconKvRow(
            context,
            Icons.person_outline,
            'Customer',
            order.customerName ?? order.customer ?? 'N/A',
          ),
          SizedBox(height: isMobile ? 6 : 8),
          _iconKvRow(
            context,
            Icons.inventory_2_outlined,
            'Qty',
            (order.totalQuantity ?? 0).toString(),
          ),
          SizedBox(height: isMobile ? 6 : 8),
          _iconKvRow(
            context,
            Icons.money_outlined,
            'Amount',
            '${order.currencyText ?? 'LKR '}${_formatCurrencyINR(order.amount)}',
          ),
          const SizedBox(height: 12),
          Divider(
              height: 1, thickness: 1, color: Colors.black.withOpacity(.06)),
          const SizedBox(height: 12),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4db1b3),
                    side:
                        const BorderSide(color: Color(0xFF4db1b3), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4db1b3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _getStatusChip(String status) {
    Color bgColor;
    Color textColor;
    switch (status.toLowerCase()) {
      case 'approved':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case 'pending':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        break;
      case 'draft':
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        break;
      default:
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  static Widget _iconKvRow(
      BuildContext context, IconData icon, String label, String valueText) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final bool isSmallMobile = MediaQuery.of(context).size.width < 360;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: isSmallMobile ? 14 : 16, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: isSmallMobile ? 11 : (isMobile ? 12 : 13),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            valueText,
            style: GoogleFonts.inter(
              color: const Color(0xFF1F1F1F),
              fontWeight: FontWeight.w500,
              fontSize: isSmallMobile ? 12 : (isMobile ? 13 : 14),
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  static String _formatCurrencyINR(double value) {
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (i > 0 && ((count == 3) || (count > 3 && (count - 3) % 2 == 0))) {
        buf.write(',');
      }
    }
    return buf.toString().split('').reversed.join();
  }
}

class _ResponsiveOrdersTable extends StatelessWidget {
  final List<Map<String, String>> data;
  final bool isTablet;
  const _ResponsiveOrdersTable({required this.data, required this.isTablet});

  Color _statusColor(String v) {
    switch (v) {
      case 'Pending':
        return Colors.orange;
      case 'Delivered':
        return Colors.green;
      case 'Approved':
        return Colors.blue;
      case 'Draft':
        return Colors.grey;
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    // On small phones, render as cards; on tablets, render a DataTable
    if (!isTablet) {
      return Column(
        children: data.map((o) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv('Date', o['date'] ?? ''),
                  _kv('Sale Order #', o['order'] ?? ''),
                  _kv('Customer', o['customer'] ?? ''),
                  _kv('Qty', o['qty'] ?? ''),
                  _kv('Amount', o['amount'] ?? ''),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _chip(o['status'] ?? '', _statusColor(o['status'] ?? '')),
                      const SizedBox(width: 8),
                      _chip(o['delivery'] ?? '',
                          _statusColor(o['delivery'] ?? '')),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(Colors.grey.shade50),
        columnSpacing: 24,
        horizontalMargin: 16,
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Sale Order #')),
          DataColumn(label: Text('Customer')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Delivery')),
        ],
        rows: data.map((o) {
          return DataRow(
            cells: [
              DataCell(Text(o['date'] ?? '')),
              DataCell(Text(o['order'] ?? '')),
              DataCell(Text(o['customer'] ?? '')),
              DataCell(Text(o['qty'] ?? '')),
              DataCell(Text(o['amount'] ?? '')),
              DataCell(
                  _chip(o['status'] ?? '', _statusColor(o['status'] ?? ''))),
              DataCell(_chip(
                  o['delivery'] ?? '', _statusColor(o['delivery'] ?? ''))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
              width: 110,
              child: Text(k, style: const TextStyle(color: Color(0xFF6B7280)))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

}

String _mon(int m) {
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
  return months[m - 1];
}

const List<String> _textOperators = [
  'Contains',
  'Is equal to',
  'Is not equal to',
  'Starts with',
  'Ends with',
  'Is null',
  'Is not null',
];

const List<String> _numberOperators = [
  'Is equal to',
  'Is not equal to',
  'Greater than',
  'Less than',
  'Greater than or equal to',
  'Less than or equal to',
  'Is null',
  'Is not null',
];

const List<String> _dateOperators = [
  'Is equal to',
  'Is not equal to',
  'Is after or equal to',
  'Is after',
  'Is before or equal to',
  'Is before',
];

class ColumnFilterState {
  bool isActive = false;
  String condition1Operator = 'Contains';
  String condition1Value = '';
  String logicalOperator = 'And';
  String condition2Operator = 'Contains';
  String condition2Value = '';

  void clear() {
    isActive = false;
    condition1Operator = 'Contains';
    condition1Value = '';
    logicalOperator = 'And';
    condition2Operator = 'Contains';
    condition2Value = '';
  }
}

class _ColumnFilterPopup extends StatefulWidget {
  final ColumnFilterState filterState;
  final List<String> operators;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const _ColumnFilterPopup({
    required this.filterState,
    required this.operators,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_ColumnFilterPopup> createState() => _ColumnFilterPopupState();
}

class _ColumnFilterPopupState extends State<_ColumnFilterPopup> {
  late ColumnFilterState _localState;

  @override
  void initState() {
    super.initState();
    // Ensure operators are valid for the current filter type
    final validOp1 = widget.operators.contains(widget.filterState.condition1Operator)
        ? widget.filterState.condition1Operator
        : widget.operators.first;
    final validOp2 = widget.operators.contains(widget.filterState.condition2Operator)
        ? widget.filterState.condition2Operator
        : widget.operators.first;
    
    _localState = ColumnFilterState()
      ..condition1Operator = validOp1
      ..condition1Value = widget.filterState.condition1Value
      ..logicalOperator = widget.filterState.logicalOperator
      ..condition2Operator = validOp2
      ..condition2Value = widget.filterState.condition2Value;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        // Header with title and close button
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Filter',
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 20 : 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Content
        Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Condition 1
                _buildConditionRow(
                  operator: _localState.condition1Operator,
                  value: _localState.condition1Value,
                  onOperatorChanged: (op) {
                    setState(() {
                      _localState.condition1Operator = op;
                    });
                  },
                  onValueChanged: (val) {
                    setState(() {
                      _localState.condition1Value = val;
                    });
                  },
                ),

                // Logical operator and Condition 2 (always shown)
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: _localState.logicalOperator,
                    isExpanded: true,
                    style: const TextStyle(
                      fontWeight: FontWeight.normal,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'And',
                        child: Text(
                          'And',
                          style: TextStyle(fontWeight: FontWeight.normal),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Or',
                        child: Text(
                          'Or',
                          style: TextStyle(fontWeight: FontWeight.normal),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _localState.logicalOperator = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildConditionRow(
                  operator: _localState.condition2Operator,
                  value: _localState.condition2Value,
                  onOperatorChanged: (op) {
                    setState(() {
                      _localState.condition2Operator = op;
                    });
                  },
                  onValueChanged: (val) {
                    setState(() {
                      _localState.condition2Value = val;
                    });
                  },
                ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          // Fixed Buttons at Bottom
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onClear,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: const Color(0xFF4db1b3), width: 1.5),
                          padding: EdgeInsets.symmetric(
                              vertical: isMobile ? 14 : 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Clear',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF4db1b3),
                            fontSize: isMobile ? 14 : 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 12 : 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          widget.filterState
                            ..condition1Operator =
                                _localState.condition1Operator
                            ..condition1Value = _localState.condition1Value
                            ..logicalOperator = _localState.logicalOperator
                            ..condition2Operator =
                                _localState.condition2Operator
                            ..condition2Value = _localState.condition2Value
                            ..isActive = true;
                          widget.onApply();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4db1b3),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              vertical: isMobile ? 14 : 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Filter',
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 14 : 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildConditionRow({
    required String operator,
    required String value,
    required ValueChanged<String> onOperatorChanged,
    required ValueChanged<String> onValueChanged,
  }) {
    final bool needsValue = ![
      'Is null',
      'Is not null',
      'Is empty',
      'Is not empty',
      'Has no value',
      'Has value'
    ].contains(operator);
    
    // Check if this is a date filter by comparing operators list with _dateOperators
    // Compare by checking if all operators in the list are date operators and vice versa
    final bool isDateFilter = widget.operators.length == _dateOperators.length &&
        widget.operators.every((op) => _dateOperators.contains(op)) &&
        _dateOperators.every((op) => widget.operators.contains(op));
    
    // Check if this is a number filter by comparing operators list with _numberOperators
    final bool isNumberFilter = widget.operators.length == _numberOperators.length &&
        widget.operators.every((op) => _numberOperators.contains(op)) &&
        _numberOperators.every((op) => widget.operators.contains(op));

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              flex: needsValue ? 1 : 2,
              child: DropdownButtonFormField<String>(
                value: operator,
                isExpanded: true,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.normal,
                  color: Colors.black87,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF4db1b3),
                      width: 2,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: widget.operators.map((op) {
                  return DropdownMenuItem(
                    value: op,
                    child: Text(
                      op,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    onOperatorChanged(val);
                  }
                },
              ),
            ),
            if (needsValue) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: isDateFilter
                    ? _buildDatePickerField(value, onValueChanged)
                    : isNumberFilter
                        ? _buildNumberField(value, onValueChanged)
                        : TextField(
                        controller: TextEditingController(text: value)
                          ..selection = TextSelection.collapsed(
                            offset: value.length,
                          ),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF4db1b3),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                  ),
                  onChanged: onValueChanged,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDatePickerField(String value, ValueChanged<String> onValueChanged) {
    DateTime? selectedDate;
    
    // Try to parse the existing value
    if (value.isNotEmpty) {
      try {
        // Try different date formats
        if (value.contains('/')) {
          final parts = value.split('/');
          if (parts.length == 3) {
            final month = int.tryParse(parts[0]);
            final day = int.tryParse(parts[1]);
            final year = int.tryParse(parts[2]);
            if (month != null && day != null && year != null) {
              selectedDate = DateTime(year, month, day);
            }
          }
        } else {
          selectedDate = DateTime.parse(value);
        }
      } catch (e) {
        // If parsing fails, use null
        selectedDate = null;
      }
    }

    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF4db1b3),
                  onPrimary: Colors.white,
                  onSurface: Colors.black87,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          // Format as M/d/yyyy
          final formattedDate = '${picked.month}/${picked.day}/${picked.year}';
          onValueChanged(formattedDate);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? 'M/d/yyyy' : value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: value.isEmpty ? Colors.grey[600] : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today,
              size: 20,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField(String value, ValueChanged<String> onValueChanged) {
    return TextField(
      controller: TextEditingController(text: value)
        ..selection = TextSelection.collapsed(offset: value.length),
      style: GoogleFonts.inter(
        fontSize: 14,
        color: Colors.black87,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF4db1b3),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        filled: true,
        fillColor: Colors.white,
        hintText: 'Enter number',
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      onChanged: onValueChanged,
    );
  }
}

// Currency Filter Popup with Searchable Checkboxes
class _CurrencyFilterPopup extends StatefulWidget {
  final List<String> availableCurrencies;
  final Set<String> selectedCurrencies;
  final ValueChanged<Set<String>> onApply;
  final VoidCallback onClear;

  const _CurrencyFilterPopup({
    required this.availableCurrencies,
    required this.selectedCurrencies,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_CurrencyFilterPopup> createState() => _CurrencyFilterPopupState();
}

class _CurrencyFilterPopupState extends State<_CurrencyFilterPopup> {
  late Set<String> _localSelected;
  late TextEditingController _searchController;
  late List<String> _filteredCurrencies;

  @override
  void initState() {
    super.initState();
    _localSelected = Set<String>.from(widget.selectedCurrencies);
    _searchController = TextEditingController();
    _filteredCurrencies = widget.availableCurrencies;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCurrencies = widget.availableCurrencies
          .where((currency) =>
              currency.toLowerCase().contains(query) ||
              query.isEmpty)
          .toList();
    });
  }

  void _toggleCurrency(String currency) {
    setState(() {
      if (currency == 'Select All') {
        if (_localSelected.contains('Select All') ||
            _localSelected.length == widget.availableCurrencies.length - 1) {
          // Deselect all
          _localSelected.clear();
        } else {
          // Select all
          _localSelected = Set<String>.from(widget.availableCurrencies);
        }
      } else {
        if (_localSelected.contains(currency)) {
          _localSelected.remove(currency);
          _localSelected.remove('Select All');
        } else {
          _localSelected.add(currency);
          // If all individual currencies are selected, also select "Select All"
          if (_localSelected.length == widget.availableCurrencies.length - 1) {
            _localSelected.add('Select All');
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    const Color tealGreen = Color(0xFF4db1b3);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Currency',
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 20 : 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Search field
          Padding(
            padding: const EdgeInsets.all(20),
                child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black87,
              ),
                  decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[600],
                  size: 20,
                ),
                    border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: tealGreen,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          // Currency list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filteredCurrencies.length,
              itemBuilder: (context, index) {
                final currency = _filteredCurrencies[index];
                final isSelected = _localSelected.contains(currency);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _toggleCurrency(currency),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSelected ? tealGreen : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? tealGreen
                                    : Colors.grey[400]!,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              currency,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.grey[900]
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Fixed Buttons at Bottom
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onClear,
                      child: Text(
                        'Clear',
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 14 : 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        widget.onApply(_localSelected);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: tealGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Filter',
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 14 : 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Status Filter Popup with Searchable Checkboxes
class _StatusFilterPopup extends StatefulWidget {
  final List<String> availableStatuses;
  final Set<String> selectedStatuses;
  final ValueChanged<Set<String>> onApply;
  final VoidCallback onClear;

  const _StatusFilterPopup({
    required this.availableStatuses,
    required this.selectedStatuses,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_StatusFilterPopup> createState() => _StatusFilterPopupState();
}

class _StatusFilterPopupState extends State<_StatusFilterPopup> {
  late Set<String> _localSelected;
  late TextEditingController _searchController;
  late List<String> _filteredStatuses;

  @override
  void initState() {
    super.initState();
    _localSelected = Set<String>.from(widget.selectedStatuses);
    _searchController = TextEditingController();
    _filteredStatuses = widget.availableStatuses;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStatuses = widget.availableStatuses
          .where((status) =>
              status.toLowerCase().contains(query) ||
              query.isEmpty)
          .toList();
    });
  }

  void _toggleStatus(String status) {
    setState(() {
      if (status == 'Select All') {
        if (_localSelected.contains('Select All') ||
            _localSelected.length == widget.availableStatuses.length - 1) {
          _localSelected.clear();
        } else {
          _localSelected = Set<String>.from(widget.availableStatuses);
        }
      } else {
        if (_localSelected.contains(status)) {
          _localSelected.remove(status);
          _localSelected.remove('Select All');
        } else {
          _localSelected.add(status);
          if (_localSelected.length == widget.availableStatuses.length - 1) {
            _localSelected.add('Select All');
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    const Color tealGreen = Color(0xFF4db1b3);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Status',
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 20 : 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[600],
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: tealGreen,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filteredStatuses.length,
              itemBuilder: (context, index) {
                final status = _filteredStatuses[index];
                final isSelected = _localSelected.contains(status);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _toggleStatus(status),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSelected ? tealGreen : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? tealGreen
                                    : Colors.grey[400]!,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              status,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: Colors.grey[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onClear,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Color(0xFF4db1b3), width: 1.5),
                    ),
                    child: Text(
                      'Clear',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4db1b3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => widget.onApply(_localSelected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tealGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Apply',
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
    );
  }
}

// Transaction Status Filter Popup with Searchable Checkboxes
class _TransactionStatusFilterPopup extends StatefulWidget {
  final List<String> availableTransactionStatuses;
  final Set<String> selectedTransactionStatuses;
  final ValueChanged<Set<String>> onApply;
  final VoidCallback onClear;

  const _TransactionStatusFilterPopup({
    required this.availableTransactionStatuses,
    required this.selectedTransactionStatuses,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_TransactionStatusFilterPopup> createState() => _TransactionStatusFilterPopupState();
}

class _TransactionStatusFilterPopupState extends State<_TransactionStatusFilterPopup> {
  late Set<String> _localSelected;
  late TextEditingController _searchController;
  late List<String> _filteredTransactionStatuses;

  @override
  void initState() {
    super.initState();
    _localSelected = Set<String>.from(widget.selectedTransactionStatuses);
    _searchController = TextEditingController();
    _filteredTransactionStatuses = widget.availableTransactionStatuses;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTransactionStatuses = widget.availableTransactionStatuses
          .where((status) =>
              status.toLowerCase().contains(query) ||
              query.isEmpty)
          .toList();
    });
  }

  void _toggleTransactionStatus(String status) {
    setState(() {
      if (status == 'Select All') {
        if (_localSelected.contains('Select All') ||
            _localSelected.length == widget.availableTransactionStatuses.length - 1) {
          _localSelected.clear();
        } else {
          _localSelected = Set<String>.from(widget.availableTransactionStatuses);
        }
      } else {
        if (_localSelected.contains(status)) {
          _localSelected.remove(status);
          _localSelected.remove('Select All');
        } else {
          _localSelected.add(status);
          if (_localSelected.length == widget.availableTransactionStatuses.length - 1) {
            _localSelected.add('Select All');
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    const Color tealGreen = Color(0xFF4db1b3);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Transaction',
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 20 : 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[600],
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: tealGreen,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filteredTransactionStatuses.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final status = _filteredTransactionStatuses[index];
                final isSelected = _localSelected.contains(status);
                return InkWell(
                  onTap: () => _toggleTransactionStatus(status),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleTransactionStatus(status),
                          activeColor: tealGreen,
                          shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                        ),
                        Expanded(
                          child: Text(
                            status,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.normal,
                              color: Colors.grey[900],
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
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onClear,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: tealGreen,
                          width: 1.5,
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 14 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Clear',
                        style: GoogleFonts.inter(
                          color: tealGreen,
                          fontSize: isMobile ? 14 : 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        widget.onApply(_localSelected);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: tealGreen,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 14 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Apply',
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 14 : 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// SO Type Filter Popup with Searchable Checkboxes
class _SOTypeFilterPopup extends StatefulWidget {
  final List<String> availableSOTypes;
  final Set<String> selectedSOTypes;
  final ValueChanged<Set<String>> onApply;
  final VoidCallback onClear;

  const _SOTypeFilterPopup({
    required this.availableSOTypes,
    required this.selectedSOTypes,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_SOTypeFilterPopup> createState() => _SOTypeFilterPopupState();
}

class _SOTypeFilterPopupState extends State<_SOTypeFilterPopup> {
  late Set<String> _localSelected;
  late TextEditingController _searchController;
  late List<String> _filteredSOTypes;

  @override
  void initState() {
    super.initState();
    _localSelected = Set<String>.from(widget.selectedSOTypes);
    _searchController = TextEditingController();
    _filteredSOTypes = widget.availableSOTypes;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSOTypes = widget.availableSOTypes
          .where((soType) =>
              soType.toLowerCase().contains(query) ||
              query.isEmpty)
          .toList();
    });
  }

  void _toggleSOType(String soType) {
    setState(() {
      if (soType == 'Select All') {
        if (_localSelected.contains('Select All') ||
            _localSelected.length == widget.availableSOTypes.length - 1) {
          _localSelected.clear();
        } else {
          _localSelected = Set<String>.from(widget.availableSOTypes);
        }
      } else {
        if (_localSelected.contains(soType)) {
          _localSelected.remove(soType);
          _localSelected.remove('Select All');
        } else {
          _localSelected.add(soType);
          if (_localSelected.length == widget.availableSOTypes.length - 1) {
            _localSelected.add('Select All');
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    const Color tealGreen = Color(0xFF4db1b3);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'SO Type',
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 20 : 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[600],
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: tealGreen,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filteredSOTypes.length,
              itemBuilder: (context, index) {
                final soType = _filteredSOTypes[index];
                final isSelected = _localSelected.contains(soType);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _toggleSOType(soType),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSelected ? tealGreen : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? tealGreen
                                    : Colors.grey[400]!,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              soType,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: Colors.grey[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onClear,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Color(0xFF4db1b3), width: 1.5),
                    ),
                    child: Text(
                      'Clear',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4db1b3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => widget.onApply(_localSelected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tealGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Apply',
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
    );
  }
}
