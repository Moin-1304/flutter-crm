import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/routes/routes.dart';
import 'package:boilerplate/domain/repository/sales/sales_repository.dart';
import 'package:boilerplate/domain/entity/sales/sales_api_models.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';

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

  String customer = '';
  String status = '';

  // API data
  List<SalesOrderApiItem> _apiOrders = [];
  bool _isLoading = false;
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
  final List<String> _statusList = ['Select All', 'Approved', 'Drafted', 'Cancelled' ,'Short Closed'];
  final List<String> _transactionStatusList = ['Select All', 'Pending', '100% Dispatched'];
  final List<String> _SOTypeList = ['Select All', 'Normal', 'Bonus'];

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
  };


  // Status filter state (single-select to match tour plan style)
  String? _selectedStatus;
  String? _selectedTransactionStatus;
  String? _selectedSOType;

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
      _loadSalesOrders();
    });
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    fromCtrl.dispose();
    toCtrl.dispose();
    super.dispose();
  }

  String _formatDateForDisplay(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${_mon(date.month)}-${date.year}';
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
      // Get user info from SharedPreferences
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
        filterExpression: null,
        sortExpression: null,
        fromDate: fromDateStr,
        toDate: toDateStr,
        fieldName: null,
        pageName: null,
        userId: userId,
        menuId: menuId,
        url:
            '/sales/salescontract/list', // Relative path as per working API call
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _apiOrders = response.items;
          } else {
            _apiOrders.addAll(response.items);
          }

          _hasMore = response.items.length >= _pageSize;
          _isLoading = false;

          // Update customer list from API data
          final customers = response.items
              .map((item) => item.customerName ?? item.customer ?? '')
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList();
          _customerList = ['All Customers', ...customers];
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
                      : _displayOrders.isEmpty
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
                                      onEdit: () {
                                        // TODO: Navigate to edit order
                                        Navigator.pushNamed(
                                            context, Routes.saleCreate);
                                      },
                                    ),
                                  );
                                },
                                childCount: _apiOrders.length,
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
          // Title row
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

          const SizedBox(height: 25),

          Row(
            children: [
              // Sale Order Button
              Expanded(
                child: SizedBox(
                  height: buttonHeight,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, Routes.saleCreate);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    // text lenght is cutting need fix it
                    label: Text(
                      'Sale Order',
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _buildFilterModal(),
    );
  }
  Widget _buildFilterModal() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// NORMAL FILTERS
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _statusList
                    .map((e) => DropdownMenuItem<String>(
                          value: e,
                          child: Text(e),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedStatus = v),
              ),

              DropdownButtonFormField<String>(
                value: _selectedTransactionStatus,
                decoration: const InputDecoration(
                  labelText: 'Transaction Status',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _transactionStatusList
                    .map((e) => DropdownMenuItem<String>(
                          value: e,
                          child: Text(e),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedTransactionStatus = v),
              ),

              DropdownButtonFormField<String>(
                value: _selectedSOType,
                decoration: const InputDecoration(
                  labelText: 'SO Type',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _SOTypeList
                    .map((e) => DropdownMenuItem<String>(
                          value: e,
                          child: Text(e),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSOType = v),
              ),

              const Divider(height: 32),

              /// COMPLEX FILTERS
              _filterTrigger('Date', 'date', _dateOperators),
              _filterTrigger('SO Number', 'soNumber', _textOperators),
              _filterTrigger('Customer', 'customer', _textOperators),
              _filterTrigger('Item Details', 'itemDetails', _textOperators),
              _filterTrigger('Type', 'type', _textOperators),
              _filterTrigger('Delivery Date', 'deliveryDate', _dateOperators),
              _filterTrigger('Currency', 'currency', _textOperators),
              _filterTrigger('Quantity', 'quantity', _numberOperators),
              _filterTrigger('Bonus Qty', 'bonusQty', _numberOperators),
              _filterTrigger('Addl. Bonus Qty', 'addlBonusQty', _numberOperators),
              _filterTrigger('Amount', 'amount', _numberOperators),
              _filterTrigger('Despatched Qty', 'despatchedQty', _numberOperators),
              _filterTrigger('Despatch No', 'despatchNo', _textOperators),
              _filterTrigger('Invoice No', 'invoiceNo', _textOperators),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearAllFilters,
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _filterTrigger(String title, String key, List<String> operators) {
    return ListTile(
      title: Text(title),
      trailing: Icon(
        _columnFilters[key]!.isActive
            ? Icons.filter_alt
            : Icons.filter_alt_outlined,
        color: _columnFilters[key]!.isActive
            ? const Color(0xFF4db1b3)
            : Colors.grey,
      ),
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (_) => _ColumnFilterPopup(
            filterState: _columnFilters[key]!,
            operators: operators,
            onApply: () {
              setState(() {
                _columnFilters[key]!.isActive = true;
              });
              Navigator.pop(context);
            },
            onClear: () {
              setState(() => _columnFilters[key]!.clear());
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }
  List<SalesOrderApiItem> get _filteredOrders {
    return _apiOrders.where((o) {

      // NORMAL FILTERS
      if (_selectedStatus != null &&
          _selectedStatus != 'Select All' &&
          o.statusText != _selectedStatus) return false;

      if (_selectedTransactionStatus != null &&
          _selectedTransactionStatus != 'Select All') {
        if (_selectedTransactionStatus == 'Pending' &&
            o.isClosed == 1) return false;

        if (_selectedTransactionStatus == '100% Dispatched' &&
            o.isClosed != 1) return false;
      }

      if (_selectedSOType != null &&
          _selectedSOType != 'Select All') {
        final soTypeText = o.soType == 'N'
            ? 'Normal'
            : o.soType == 'B'
                ? 'Bonus'
                : o.soType;

        if (soTypeText != _selectedSOType) return false;
      }

      // COMPLEX FILTERS
      for (final f in _columnFilters.entries) {
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
        return o.statusText;
      case 'soType':
        return o.soType;
      default:
        return null;
    }
  }

  int _getFilterCount() {
    int count = 0;
    if (_selectedStatus != null && _selectedStatus != 'Select All') count++;
    if (_selectedTransactionStatus != null && _selectedTransactionStatus != 'Select All') count++;
    if (_selectedSOType != null && _selectedSOType != 'Select All') count++;
    count += _columnFilters.values.where((f) => f.isActive).length;
    return count;
  }
  void _clearAllFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedTransactionStatus = null;
      _selectedSOType = null;

      for (final f in _columnFilters.values) {
        f.clear();
      }
    });
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

  const _SalesOrderCard({required this.order, this.onView, this.onEdit});

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
  'Before',
  'After',
  'Between',
  'Is null',
  'Is not null',
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
    _localState = ColumnFilterState()
      ..condition1Operator = widget.filterState.condition1Operator
      ..condition1Value = widget.filterState.condition1Value
      ..logicalOperator = widget.filterState.logicalOperator
      ..condition2Operator = widget.filterState.condition2Operator
      ..condition2Value = widget.filterState.condition2Value;
  }

  @override
  Widget build(BuildContext context) {
    const blueColor = Color(0xFF2196F3);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with title and close button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Filter',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.normal),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Content
        Flexible(
          child: Container(
            width: isMobile ? screenWidth - 32 : 320,
            constraints: BoxConstraints(
              maxWidth: isMobile ? screenWidth - 32 : 320,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            padding: const EdgeInsets.all(16),
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

                const SizedBox(height: 16),

                // Buttons
                Row(
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
              ],
            ),
          ),
        ),
      ],
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              flex: needsValue ? 1 : 2,
              child: DropdownButtonFormField<String>(
                value: operator,
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: widget.operators.map((op) {
                  return DropdownMenuItem(
                    value: op,
                    child: Text(
                      op,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.normal,
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
                child: TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
}
