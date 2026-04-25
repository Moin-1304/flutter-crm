import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/domain/entity/sales/sales_api_models.dart';
import 'package:boilerplate/domain/repository/sales/sales_repository.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';

class SalesBonusApprovalScreen extends StatefulWidget {
  const SalesBonusApprovalScreen({super.key});

  @override
  State<SalesBonusApprovalScreen> createState() => _SalesBonusApprovalScreenState();
}

class _SalesBonusApprovalScreenState extends State<SalesBonusApprovalScreen>
    with SingleTickerProviderStateMixin {
  static const Color _tealGreen = Color(0xFF4FA7A3);
  static const Color _tealDark = Color(0xFF3E8F8B);
  static const Color _lightTealBg = Color(0xFFE8F4F3);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _textPrimary = Color(0xFF1F2A37);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _submittedBg = Color(0xFFFEF3C7);
  static const Color _submittedText = Color(0xFFD97706);
  static const Color _bg = Color(0xFFF5F7F7);
  final Set<int> _selectedIds = <int>{};
  final Map<int, TextEditingController> _qtyCtrls = <int, TextEditingController>{};
  final NumberFormat _amountFmt = NumberFormat('#,##0.00');

  List<SalesOrderBonusApprovalItem> _pendingItems = <SalesOrderBonusApprovalItem>[];
  List<SalesOrderBonusApprovalItem> _approvedItems = <SalesOrderBonusApprovalItem>[];
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isLoadingPending = false;
  bool _isLoadingApproved = false;
  bool _isLoadingMorePending = false;
  bool _isLoadingMoreApproved = false;
  String? _error;
  int _pendingPage = 1;
  int _approvedPage = 1;
  final int _pageSize = 15;
  bool _pendingHasMore = true;
  bool _approvedHasMore = true;
  int _approvedTotalRecords = 0;
  final ScrollController _pendingScrollController = ScrollController();
  final ScrollController _approvedScrollController = ScrollController();
  final Map<String, ColumnFilterState> _columnFilters = {
    'saleOrderNo': ColumnFilterState(),
    'date': ColumnFilterState(
      condition1Operator: 'Is equal to',
      condition2Operator: 'Is equal to',
    ),
    'division': ColumnFilterState(),
    'itemCode': ColumnFilterState(),
    'itemName': ColumnFilterState(),
    'customerName': ColumnFilterState(),
    'quantityOrdered': ColumnFilterState(
      condition1Operator: 'Is equal to',
      condition2Operator: 'Is equal to',
    ),
    'bonusQuantity': ColumnFilterState(
      condition1Operator: 'Is equal to',
      condition2Operator: 'Is equal to',
    ),
    'requestedAddlQty': ColumnFilterState(
      condition1Operator: 'Is equal to',
      condition2Operator: 'Is equal to',
    ),
    'approvedAddlQty': ColumnFilterState(
      condition1Operator: 'Is equal to',
      condition2Operator: 'Is equal to',
    ),
    'rate': ColumnFilterState(
      condition1Operator: 'Is equal to',
      condition2Operator: 'Is equal to',
    ),
    'netAmount': ColumnFilterState(
      condition1Operator: 'Is equal to',
      condition2Operator: 'Is equal to',
    ),
    'salesRep': ColumnFilterState(),
    'distributor': ColumnFilterState(),
    'approvedBy': ColumnFilterState(),
    'approvalDate': ColumnFilterState(
      condition1Operator: 'Is equal to',
      condition2Operator: 'Is equal to',
    ),
  };
  final List<String> _stringOperators = [
    'Contains',
    'Is equal to',
    'Starts with',
    'Ends with',
    'Is empty',
    'Is not empty',
  ];
  final List<String> _numberOperators = [
    'Is equal to',
    'Is not equal to',
    'Greater than',
    'Greater than or equal to',
    'Less than',
    'Less than or equal to',
    'Is empty',
    'Is not empty',
  ];
  final List<String> _dateOperators = [
    'Is equal to',
    'Is not equal to',
    'Is after',
    'Is after or equal to',
    'Is before',
    'Is before or equal to',
    'Is empty',
    'Is not empty',
  ];

  int _userId = 0;
  int _sbuId = 1;
  int _bizUnit = 1;

  @override
  void initState() {
    super.initState();
    _pendingScrollController.addListener(_onPendingScroll);
    _approvedScrollController.addListener(_onApprovedScroll);
    _initData();
  }

  @override
  void dispose() {
    for (final ctrl in _qtyCtrls.values) {
      ctrl.dispose();
    }
    _pendingScrollController.dispose();
    _approvedScrollController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final sharedPref = getIt<SharedPreferenceHelper>();
      final user = await sharedPref.getUser();
      if (user == null) {
        throw Exception('User not found');
      }

      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      final int sbu = userStore?.userDetail?.sbuId ?? user.sbuId;
      const int biz = 1;
      if (!mounted) return;
      _userId = user.id;
      _sbuId = sbu;
      _bizUnit = biz;
      await Future.wait([
        _loadPendingPage(1),
        _loadApprovedPage(1),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadPendingPage(int page, {bool showPageLoader = true}) async {
    if (page == 1 && showPageLoader) {
      setState(() => _isLoadingPending = true);
    } else if (page > 1) {
      setState(() => _isLoadingMorePending = true);
    }
    try {
      final response = await getIt<SalesRepository>().getBonusApprovalList(
        userId: _userId,
        pageNumber: page,
        pageSize: _pageSize,
        sbuId: _sbuId,
        bizUnit: _bizUnit,
      );
      for (final item in response.items) {
        _qtyCtrls.putIfAbsent(
          item.id,
          () => TextEditingController(
            text: item.additionalQuantityApproved.toStringAsFixed(0),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _pendingPage = page;
        _pendingItems =
            page == 1 ? response.items : <SalesOrderBonusApprovalItem>[..._pendingItems, ...response.items];
        _pendingHasMore = response.items.length == _pageSize;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPending = false;
          _isLoadingMorePending = false;
        });
      }
    }
  }

  Future<void> _loadApprovedPage(int page, {bool showPageLoader = true}) async {
    if (page == 1 && showPageLoader) {
      setState(() => _isLoadingApproved = true);
    } else if (page > 1) {
      setState(() => _isLoadingMoreApproved = true);
    }
    try {
      final response = await getIt<SalesRepository>().getBonusApprovedList(
        userId: _userId,
        pageNumber: page,
        pageSize: _pageSize,
        sbuId: _sbuId,
        bizUnit: _bizUnit,
      );
      if (!mounted) return;
      setState(() {
        _approvedPage = page;
        _approvedItems =
            page == 1 ? response.items : <SalesOrderBonusApprovalItem>[..._approvedItems, ...response.items];
        _approvedHasMore = response.items.length == _pageSize;
        _approvedTotalRecords = response.totalRecords ?? response.items.length;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingApproved = false;
          _isLoadingMoreApproved = false;
        });
      }
    }
  }

  Future<void> _refreshPendingTab() async {
    await _loadPendingPage(1, showPageLoader: false);
    if (!mounted) return;
    setState(() {
      _selectedIds.removeWhere((id) => !_pendingItems.any((item) => item.id == id));
    });
  }

  Future<void> _refreshApprovedTab() async {
    await _loadApprovedPage(1, showPageLoader: false);
  }

  void _onPendingScroll() {
    if (!_pendingScrollController.hasClients ||
        _isLoadingPending ||
        _isLoadingMorePending ||
        !_pendingHasMore) {
      return;
    }
    final position = _pendingScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      _loadPendingPage(_pendingPage + 1);
    }
  }

  void _onApprovedScroll() {
    if (!_approvedScrollController.hasClients ||
        _isLoadingApproved ||
        _isLoadingMoreApproved ||
        !_approvedHasMore) {
      return;
    }
    final position = _approvedScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      _loadApprovedPage(_approvedPage + 1);
    }
  }

  double _editedApprovedQty(SalesOrderBonusApprovalItem item) {
    final txt = _qtyCtrls[item.id]?.text.trim() ?? '';
    final parsed = double.tryParse(txt);
    if (parsed == null || parsed < 0) {
      return item.additionalQuantityApproved;
    }
    return parsed;
  }

  Future<void> _submit({required bool isReject}) async {
    final selected = _pendingItems.where((e) => _selectedIds.contains(e.id)).toList();
    if (selected.isEmpty) {
      ToastMessage.show(
        context,
        message: 'Please select at least one row.',
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payload = selected
          .map((e) => e.copyWith(
                additionalQuantityApproved: isReject ? 0 : _editedApprovedQty(e),
                isSelected: true,
              ))
          .toList();

      await getIt<SalesRepository>().submitBonusApprovalAction(
        createdBy: _userId,
        userId: _userId,
        bizunit: _bizUnit,
        sbuId: _sbuId,
        selectedItems: payload,
      );

      if (!mounted) return;
      ToastMessage.show(
        context,
        message: isReject ? 'Rejected successfully.' : 'Approved successfully.',
        type: ToastType.success,
      );
      _selectedIds.clear();
      await Future.wait([
        _loadPendingPage(_pendingPage),
        _loadApprovedPage(1),
      ]);
    } catch (e) {
      if (!mounted) return;
      ToastMessage.show(
        context,
        message: 'Failed: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.width >= 800;
    final bool isMobile = !isTablet;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(
          children: [
            Container(
              color: _bg,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 8 : 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bonus Approval',
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey[900],
                            letterSpacing: -0.8,
                          ),
                        ),
                        SizedBox(height: isTablet ? 6 : 4),
                        Text(
                          'View and manage bonus approvals',
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
                            onTap: _showFilterModal,
                            borderRadius: BorderRadius.circular(12),
                            child: Icon(
                              Icons.filter_alt,
                              color: _tealGreen,
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
                              color: _tealGreen,
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
            ),
            Container(
              color: _bg,
              child: TabBar(
                indicatorColor: _tealGreen,
                labelColor: _tealGreen,
                unselectedLabelColor: _textSecondary,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                unselectedLabelStyle:
                    GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                tabs: const [
                  Tab(text: 'Pending'),
                  Tab(text: 'Approved'),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : TabBarView(
                          children: [
                            _buildPendingTab(),
                            _buildApprovedTab(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTab() {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final bool hasSelection = _selectedIds.isNotEmpty;
    final visiblePending =
        _applyColumnFilters(_pendingItems, isApprovedList: false);
    final bool hasRecords = visiblePending.isNotEmpty;
    final bool allSelected =
        hasRecords && _selectedIds.length == visiblePending.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasRecords ? _tealGreen : const Color(0xFFE6EAF0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasRecords
                          ? _tealGreen.withOpacity(0.45)
                          : const Color(0xFFD2D8E0),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: !hasRecords
                          ? null
                          : () {
                              setState(() {
                                if (allSelected) {
                                  _selectedIds.clear();
                                } else {
                                  _selectedIds
                                    ..clear()
                                    ..addAll(visiblePending.map((e) => e.id));
                                }
                              });
                            },
                      child: Center(
                        child: Text(
                          !hasRecords
                              ? 'Select All'
                              : allSelected
                              ? 'Unselect All'
                              : 'Select All',
                          style: GoogleFonts.inter(
                            color: hasRecords
                                ? Colors.white
                                : const Color(0xFF8A94A6),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _lightTealBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _tealGreen.withOpacity(0.25)),
                  ),
                  child: Center(
                    child: Text(
                      '${visiblePending.length} records',
                      style: GoogleFonts.inter(
                        color: _tealGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshPendingTab,
            color: _tealGreen,
            child: _isLoadingPending
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 180),
                      Center(child: CircularProgressIndicator()),
                    ],
                  )
                : visiblePending.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 180),
                          Center(child: Text('No pending bonus requests')),
                        ],
                      )
                    : ListView.separated(
                        controller: _pendingScrollController,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          12,
                          4,
                          12,
                          hasSelection ? 130 : 12,
                        ),
                        itemCount:
                            visiblePending.length + (_isLoadingMorePending ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          if (index >= visiblePending.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final item = visiblePending[index];
                          final selected = _selectedIds.contains(item.id);
                          return Card(
                            elevation: 0.6,
                            color: _cardBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: selected
                                    ? _tealGreen.withOpacity(0.50)
                                    : Colors.transparent,
                                width: selected ? 1.4 : 0,
                              ),
                            ),
                            shadowColor: Colors.black.withOpacity(0.05),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () =>
                                  _showDetailSheet(item: item, isApprovedTab: false),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: selected,
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedIds.add(item.id);
                                              } else {
                                                _selectedIds.remove(item.id);
                                              }
                                            });
                                          },
                                          activeColor: _tealGreen,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item.saleOrderNo,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              color: _textPrimary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _displayDate(item.date),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: _textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        _buildStatusPill(
                                          text: item.divisionText ?? '-',
                                          fg: _tealGreen,
                                          bg: const Color(0xFF4FA7A3),
                                        ),
                                        _buildStatusPill(
                                          text: 'Submitted',
                                          fg: _submittedText,
                                          bg: const Color(0xFFFBBF24),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${item.itemCode} - ${item.itemName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: _textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.customerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: _textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9FAFB),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _border),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Req: ${item.additionalQuantity.toStringAsFixed(0)}',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: _textSecondary,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 120,
                                            child: TextField(
                                              controller: _qtyCtrls[item.id],
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                              decoration: InputDecoration(
                                                labelText: 'Approved',
                                                isDense: true,
                                                filled: true,
                                                fillColor: const Color(0xFFF9FAFB),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 8,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide:
                                                      const BorderSide(color: _border),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide:
                                                      const BorderSide(color: _border),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide: BorderSide(
                                                    color: _tealGreen.withOpacity(0.9),
                                                    width: 1.4,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Sales Rep: ${item.salesRepName ?? '-'} • Distributor: ${item.distributorName ?? '-'}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: _textSecondary,
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
        ),
        if (hasSelection)
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(0, 4, 0, 0),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              decoration: BoxDecoration(
                color: _lightTealBg,
                border: Border(
                  top: BorderSide(color: _tealGreen.withOpacity(0.18)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: _tealGreen, size: 17),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedIds.length} item(s) selected',
                          style: GoogleFonts.inter(
                            color: _tealGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _selectedIds.clear()),
                        child: Row(
                          children: [
                            Icon(Icons.close, color: _tealGreen, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Clear Selection',
                              style: GoogleFonts.inter(
                                color: _tealGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: isMobile ? 44 : 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                _isSubmitting ? null : () => _submit(isReject: false),
                            icon: const Icon(Icons.check_circle, size: 17),
                            label: Text(
                              _isSubmitting ? 'Submitting...' : 'Approve',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: isMobile ? 44 : 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade500,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                _isSubmitting ? null : () => _submit(isReject: true),
                            icon: const Icon(Icons.cancel, size: 17),
                            label: Text(
                              'Reject',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
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

  Widget _buildApprovedTab() {
    final visibleApproved =
        _applyColumnFilters(_approvedItems, isApprovedList: true);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: _lightTealBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _tealGreen.withOpacity(0.25)),
            ),
            child: Center(
              child: Text(
                '${_approvedTotalRecords} records',
                style: GoogleFonts.inter(
                  color: _tealGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshApprovedTab,
            color: _tealGreen,
            child: _isLoadingApproved
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 180),
                      Center(child: CircularProgressIndicator()),
                    ],
                  )
                : visibleApproved.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 180),
                          Center(child: Text('No approved bonus records')),
                        ],
                      )
                    : ListView.separated(
                        controller: _approvedScrollController,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.all(12),
                        itemCount:
                            visibleApproved.length + (_isLoadingMoreApproved ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          if (index >= visibleApproved.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final item = visibleApproved[index];
                          return Card(
                            elevation: 0.6,
                            shadowColor: Colors.black.withOpacity(0.05),
                            color: _cardBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Colors.transparent),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showDetailSheet(item: item, isApprovedTab: true),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.saleOrderNo,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              color: _textPrimary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _displayDate(item.date),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: _textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        _buildChip(
                                          text: item.divisionText ?? '-',
                                          fg: _tealGreen,
                                          bg: _lightTealBg,
                                        ),
                                        _buildChip(
                                          text: 'Approved',
                                          fg: Colors.green.shade700,
                                          bg: Colors.green.shade100,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${item.itemCode} - ${item.itemName}',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: _textPrimary,
                                      ),
                                    ),
                                    Text(
                                      item.customerName,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: _textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 6,
                                      children: [
                                        _buildMiniStat(
                                          label: 'Req',
                                          value: item.additionalQuantity.toStringAsFixed(0),
                                        ),
                                        _buildMiniStat(
                                          label: 'Approved',
                                          value: item.additionalQuantityApproved.toStringAsFixed(0),
                                        ),
                                        _buildMiniStat(
                                          label: 'Net',
                                          value: _amountFmt.format(item.netAmount),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  String _displayDate(String? raw) {
    if (raw == null || raw.isEmpty || raw.startsWith('0001-01-01')) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd-MMM-yyyy').format(dt);
  }

  Widget _buildChip({
    required String text,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildMiniStat({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: const Border.fromBorderSide(BorderSide(color: _border)),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(color: _textPrimary, fontSize: 12),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill({
    required String text,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.12),
        border: Border.all(
          color: bg.withOpacity(0.35),
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  int _getFilterCount() => _columnFilters.values.where((f) => f.isActive).length;

  void _clearAllFilters() {
    for (final filter in _columnFilters.values) {
      filter.clear();
    }
    setState(() {});
  }

  void _showFilterModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.20),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.60,
                child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Row(
                      children: [
                        Text(
                          'Filters',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.normal,
                            color: _textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop(),
                          borderRadius: BorderRadius.circular(99),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.10),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      children: _columnFilters.keys.map((key) {
                        final fs = _columnFilters[key]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _FilterDropdownTrigger(
                            title: _fieldLabel(key),
                            icon: _fieldIcon(key),
                            hasActiveFilter: fs.isActive,
                            selectedValue:
                                fs.isActive ? _getFilterDisplayText(fs) : null,
                            onTap: () async {
                              final bool isDate =
                                  key == 'date' || key == 'approvalDate';
                              final bool isNumber = [
                                'quantityOrdered',
                                'bonusQuantity',
                                'requestedAddlQty',
                                'approvedAddlQty',
                                'rate',
                                'netAmount',
                              ].contains(key);
                              final operators = isDate
                                  ? _dateOperators
                                  : isNumber
                                      ? _numberOperators
                                      : _stringOperators;
                              await showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20)),
                                ),
                                builder: (dialogContext) {
                                  final keyboardInset =
                                      MediaQuery.of(dialogContext)
                                          .viewInsets
                                          .bottom;
                                  final height =
                                      MediaQuery.of(dialogContext).size.height;
                                  return AnimatedPadding(
                                    duration:
                                        const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                    padding: EdgeInsets.only(bottom: keyboardInset),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight:
                                            height * (keyboardInset > 0 ? 0.78 : 0.7),
                                      ),
                                      child: _ColumnFilterPopupSimple(
                                        filterState: fs,
                                        operators: operators,
                                        isDate: isDate,
                                        onApply: () {
                                          setState(() {});
                                          setSheetState(() {});
                                          Navigator.of(dialogContext).pop();
                                        },
                                        onClear: () {
                                          fs.clear();
                                          setState(() {});
                                          setSheetState(() {});
                                          Navigator.of(dialogContext).pop();
                                        },
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.withOpacity(0.15)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _clearAllFilters();
                              setSheetState(() {});
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: _tealGreen, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: Text(
                              'Clear',
                              style: GoogleFonts.inter(
                                color: _tealGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _tealGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: Text(
                              'Apply Filters',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ));
          },
        ),
      ),
    );
  }

  IconData _fieldIcon(String key) {
    switch (key) {
      case 'date':
      case 'approvalDate':
        return Icons.calendar_today_outlined;
      case 'saleOrderNo':
        return Icons.receipt_long_outlined;
      case 'itemCode':
      case 'itemName':
        return Icons.inventory_2_outlined;
      case 'customerName':
      case 'distributor':
        return Icons.person_outline;
      case 'salesRep':
      case 'approvedBy':
        return Icons.badge_outlined;
      default:
        return Icons.tune;
    }
  }

  String _getFilterDisplayText(ColumnFilterState fs) {
    String txt = '';
    if (fs.condition1Value.trim().isNotEmpty) {
      txt = '${fs.condition1Operator} ${fs.condition1Value}';
    }
    if (fs.condition2Value.trim().isNotEmpty) {
      txt = txt.isEmpty
          ? '${fs.condition2Operator} ${fs.condition2Value}'
          : '$txt ${fs.logicalOperator} ${fs.condition2Operator} ${fs.condition2Value}';
    }
    return txt;
  }

  String _fieldLabel(String key) {
    const labels = {
      'saleOrderNo': 'Sales Order No',
      'date': 'Date',
      'division': 'Division',
      'itemCode': 'Item Code',
      'itemName': 'Item Name',
      'customerName': 'Customer Name',
      'quantityOrdered': 'Quantity Ordered',
      'bonusQuantity': 'Bonus Quantity',
      'requestedAddlQty': 'Requested Addl.Qty',
      'approvedAddlQty': 'Addl Bonus Qty Approved',
      'rate': 'Rate',
      'netAmount': 'Net Amount',
      'salesRep': 'Sales Rep',
      'distributor': 'Distributor',
      'approvedBy': 'Approved By',
      'approvalDate': 'Approval Date',
    };
    return labels[key] ?? key;
  }

  List<SalesOrderBonusApprovalItem> _applyColumnFilters(
    List<SalesOrderBonusApprovalItem> source, {
    required bool isApprovedList,
  }) {
    return source.where((item) {
      for (final entry in _columnFilters.entries) {
        final key = entry.key;
        final fs = entry.value;
        if (!fs.isActive) continue;

        final condition1 = _evaluateForField(
          item,
          key,
          fs.condition1Operator,
          fs.condition1Value,
          isApprovedList,
        );
        final condition2 = fs.condition2Value.trim().isEmpty
            ? true
            : _evaluateForField(
                item,
                key,
                fs.condition2Operator,
                fs.condition2Value,
                isApprovedList,
              );
        final pass =
            fs.logicalOperator == 'OR' ? (condition1 || condition2) : (condition1 && condition2);
        if (!pass) return false;
      }
      return true;
    }).toList();
  }

  bool _evaluateForField(
    SalesOrderBonusApprovalItem item,
    String field,
    String operator,
    String rawValue,
    bool isApprovedList,
  ) {
    final value = rawValue.trim();
    switch (field) {
      case 'date':
      case 'approvalDate':
        final source = DateTime.tryParse(
          field == 'date' ? (item.date ?? '') : (item.approvedDate ?? ''),
        );
        return _evaluateDate(source, operator, value);
      case 'quantityOrdered':
      case 'bonusQuantity':
      case 'requestedAddlQty':
      case 'approvedAddlQty':
      case 'rate':
      case 'netAmount':
        final source = switch (field) {
          'quantityOrdered' => item.quantityOrdered,
          'bonusQuantity' => item.bonusQuantity,
          'requestedAddlQty' => item.additionalQuantity,
          'approvedAddlQty' => item.additionalQuantityApproved,
          'rate' => item.rate,
          _ => item.netAmount,
        };
        return _evaluateNumber(source, operator, value);
      default:
        final source = switch (field) {
          'saleOrderNo' => item.saleOrderNo,
          'division' => item.divisionText ?? '',
          'itemCode' => item.itemCode,
          'itemName' => item.itemName,
          'customerName' => item.customerName,
          'salesRep' => item.salesRepName ?? '',
          'distributor' => item.distributorName ?? '',
          'approvedBy' => isApprovedList ? (item.approvedBy ?? '') : '',
          _ => '',
        };
        return _evaluateString(source, operator, value);
    }
  }

  bool _evaluateString(String source, String operator, String value) {
    final src = source.toLowerCase();
    final v = value.toLowerCase();
    switch (operator) {
      case 'Contains':
        return src.contains(v);
      case 'Starts with':
        return src.startsWith(v);
      case 'Ends with':
        return src.endsWith(v);
      case 'Is equal to':
        return src == v;
      case 'Is empty':
        return src.trim().isEmpty;
      case 'Is not empty':
        return src.trim().isNotEmpty;
      default:
        return true;
    }
  }

  bool _evaluateNumber(double source, String operator, String value) {
    if (operator == 'Is empty') return false;
    if (operator == 'Is not empty') return true;
    final parsed = double.tryParse(value);
    if (parsed == null) return true;
    switch (operator) {
      case 'Is equal to':
        return source == parsed;
      case 'Is not equal to':
        return source != parsed;
      case 'Greater than':
        return source > parsed;
      case 'Greater than or equal to':
        return source >= parsed;
      case 'Less than':
        return source < parsed;
      case 'Less than or equal to':
        return source <= parsed;
      default:
        return true;
    }
  }

  bool _evaluateDate(DateTime? source, String operator, String value) {
    if (operator == 'Is empty') return source == null;
    if (operator == 'Is not empty') return source != null;
    if (source == null) return false;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return true;
    final s = DateTime(source.year, source.month, source.day);
    final p = DateTime(parsed.year, parsed.month, parsed.day);
    switch (operator) {
      case 'Is equal to':
        return s == p;
      case 'Is not equal to':
        return s != p;
      case 'Is after':
        return s.isAfter(p);
      case 'Is after or equal to':
        return s.isAfter(p) || s == p;
      case 'Is before':
        return s.isBefore(p);
      case 'Is before or equal to':
        return s.isBefore(p) || s == p;
      default:
        return true;
    }
  }

  void _showDetailSheet({
    required SalesOrderBonusApprovalItem item,
    required bool isApprovedTab,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        final approvedText = isApprovedTab
            ? item.additionalQuantityApproved.toStringAsFixed(0)
            : (_qtyCtrls[item.id]?.text.trim().isEmpty ?? true)
                ? item.additionalQuantityApproved.toStringAsFixed(0)
                : _qtyCtrls[item.id]!.text.trim();

        final baseDetails = <MapEntry<String, String>>[
          MapEntry('Sales Order No', item.saleOrderNo),
          MapEntry('Date', _displayDate(item.date)),
          MapEntry('Division', item.divisionText ?? '-'),
          MapEntry('Item Code', item.itemCode),
          MapEntry('Item Name', item.itemName),
          MapEntry('Customer Name', item.customerName),
          MapEntry('Quantity Ordered', item.quantityOrdered.toStringAsFixed(0)),
          MapEntry('Bonus Quantity', item.bonusQuantity.toStringAsFixed(0)),
          MapEntry('Requested Addl.Qty', item.additionalQuantity.toStringAsFixed(0)),
          MapEntry('Addl Bonus Qty Approved', approvedText),
          MapEntry('Rate', _amountFmt.format(item.rate)),
          MapEntry('Net Amount', _amountFmt.format(item.netAmount)),
          MapEntry('Sales Rep', item.salesRepName ?? '-'),
          MapEntry('Distributor', item.distributorName ?? '-'),
        ];

        final approvalDetails = <MapEntry<String, String>>[
          if (isApprovedTab) MapEntry('Approved By', item.approvedBy ?? '-'),
          if (isApprovedTab) MapEntry('Approval Date', _displayDate(item.approvedDate)),
        ];

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.68,
          minChildSize: 0.50,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                      decoration: BoxDecoration(
                        color: _lightTealBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _tealGreen.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.card_giftcard_rounded,
                              color: _tealGreen,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isApprovedTab
                                  ? 'Approved Bonus Details'
                                  : 'Bonus Details',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                          ),
                          _buildChip(
                            text: isApprovedTab ? 'Approved' : 'Submitted',
                            fg: isApprovedTab
                                ? const Color(0xFF15803D)
                                : _submittedText,
                            bg: isApprovedTab
                                ? const Color(0xFFDCFCE7)
                                : _submittedBg,
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            color: _textSecondary,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        children: [
                          for (final entry in baseDetails) ...[
                            _detailRow(entry.key, entry.value),
                            const SizedBox(height: 10),
                          ],
                          if (approvalDetails.isNotEmpty) ...[
                            const Divider(height: 24, color: _border),
                            for (final entry in approvalDetails) ...[
                              _detailRow(entry.key, entry.value),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: _textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: _textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class ColumnFilterState {
  ColumnFilterState({
    this.condition1Operator = 'Contains',
    this.condition1Value = '',
    this.logicalOperator = 'AND',
    this.condition2Operator = 'Contains',
    this.condition2Value = '',
  });

  String condition1Operator;
  String condition1Value;
  String logicalOperator;
  String condition2Operator;
  String condition2Value;

  bool get isActive =>
      condition1Value.trim().isNotEmpty || condition2Value.trim().isNotEmpty;

  void clear() {
    condition1Value = '';
    condition2Value = '';
    logicalOperator = 'AND';
  }
}

class _FilterDropdownTrigger extends StatelessWidget {
  const _FilterDropdownTrigger({
    required this.title,
    required this.icon,
    required this.hasActiveFilter,
    required this.selectedValue,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool hasActiveFilter;
  final String? selectedValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF4DB1B3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: teal),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade900,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasActiveFilter ? teal.withOpacity(0.10) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasActiveFilter ? teal.withOpacity(0.30) : Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    (selectedValue != null && selectedValue!.isNotEmpty)
                        ? selectedValue!
                        : 'Select $title',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: hasActiveFilter ? teal : Colors.grey.shade600,
                      fontWeight: hasActiveFilter ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: teal, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ColumnFilterPopupSimple extends StatefulWidget {
  const _ColumnFilterPopupSimple({
    required this.filterState,
    required this.operators,
    required this.isDate,
    required this.onApply,
    required this.onClear,
  });

  final ColumnFilterState filterState;
  final List<String> operators;
  final bool isDate;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  State<_ColumnFilterPopupSimple> createState() =>
      _ColumnFilterPopupSimpleState();
}

class _ColumnFilterPopupSimpleState extends State<_ColumnFilterPopupSimple> {
  late ColumnFilterState _local;
  late TextEditingController _c1;
  late TextEditingController _c2;

  @override
  void initState() {
    super.initState();
    _local = ColumnFilterState(
      condition1Operator: widget.filterState.condition1Operator,
      condition1Value: widget.filterState.condition1Value,
      logicalOperator: widget.filterState.logicalOperator,
      condition2Operator: widget.filterState.condition2Operator,
      condition2Value: widget.filterState.condition2Value,
    );
    _c1 = TextEditingController(text: _local.condition1Value);
    _c2 = TextEditingController(text: _local.condition2Value);
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFirst) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final v = DateFormat('yyyy-MM-dd').format(picked);
    setState(() {
      if (isFirst) {
        _local.condition1Value = v;
        _c1.text = v;
      } else {
        _local.condition2Value = v;
        _c2.text = v;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF4DB1B3);
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;
    final screenWidth = mediaQuery.size.width;
    final keyboardInset = mediaQuery.viewInsets.bottom;
    InputDecoration dec() => InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        );
    final needs1 = !['Is empty', 'Is not empty'].contains(_local.condition1Operator);
    final needs2 = !['Is empty', 'Is not empty'].contains(_local.condition2Operator);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: isMobile ? screenWidth - 32 : 320,
                constraints: BoxConstraints(
                  maxWidth: isMobile ? screenWidth - 32 : 320,
                  maxHeight:
                      mediaQuery.size.height * (keyboardInset > 0 ? 0.78 : 0.7),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: needs1 ? 1 : 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _local.condition1Operator,
                          isExpanded: true,
                          items: widget.operators
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ))
                              .toList(),
                          selectedItemBuilder: (context) => widget.operators
                              .map((e) => Text(
                                    e,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _local.condition1Operator = v!),
                          decoration: dec(),
                        ),
                      ),
                      if (needs1) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _c1,
                            readOnly: widget.isDate,
                            onTap: widget.isDate ? () => _pickDate(true) : null,
                            onChanged: (v) => _local.condition1Value = v,
                            decoration: dec().copyWith(
                              suffixIcon: widget.isDate
                                  ? const Icon(Icons.calendar_today, size: 18)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _local.logicalOperator,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'AND', child: Text('AND')),
                      DropdownMenuItem(value: 'OR', child: Text('OR')),
                    ],
                    onChanged: (v) => setState(() => _local.logicalOperator = v!),
                    decoration: dec(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: needs2 ? 1 : 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _local.condition2Operator,
                          isExpanded: true,
                          items: widget.operators
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ))
                              .toList(),
                          selectedItemBuilder: (context) => widget.operators
                              .map((e) => Text(
                                    e,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _local.condition2Operator = v!),
                          decoration: dec(),
                        ),
                      ),
                      if (needs2) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _c2,
                            readOnly: widget.isDate,
                            onTap: widget.isDate ? () => _pickDate(false) : null,
                            onChanged: (v) => _local.condition2Value = v,
                            decoration: dec().copyWith(
                              suffixIcon: widget.isDate
                                  ? const Icon(Icons.calendar_today, size: 18)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onClear,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: teal, width: 1.5),
                            padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Clear',
                            style: GoogleFonts.inter(
                              color: teal,
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
                              ..condition1Operator = _local.condition1Operator
                              ..condition1Value = _local.condition1Value
                              ..logicalOperator = _local.logicalOperator
                              ..condition2Operator = _local.condition2Operator
                              ..condition2Value = _local.condition2Value;
                            widget.onApply();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: teal,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            'Apply Filters',
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
          ),
        ],
      ),
    );
  }
}

// Backward-compat shim for hot-reload stale widget lookups.
// Safe to keep; new UI path uses _FilterDropdownTrigger + _ColumnFilterPopupSimple.
class _FilterFieldCard extends StatelessWidget {
  const _FilterFieldCard({
    required this.title,
    required this.state,
    required this.operators,
    required this.onChanged,
    required this.isDate,
  });

  final String title;
  final ColumnFilterState state;
  final List<String> operators;
  final VoidCallback onChanged;
  final bool isDate;

  @override
  Widget build(BuildContext context) {
    return _FilterDropdownTrigger(
      title: title,
      icon: Icons.tune,
      hasActiveFilter: state.isActive,
      selectedValue: state.isActive ? '${state.condition1Operator} ${state.condition1Value}' : null,
      onTap: () async {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (dialogContext) {
            final keyboardInset = MediaQuery.of(dialogContext).viewInsets.bottom;
            final height = MediaQuery.of(dialogContext).size.height;
            return AnimatedPadding(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: height * (keyboardInset > 0 ? 0.78 : 0.7),
                ),
                child: _ColumnFilterPopupSimple(
                  filterState: state,
                  operators: operators,
                  isDate: isDate,
                  onApply: () {
                    onChanged();
                    Navigator.of(dialogContext).pop();
                  },
                  onClear: () {
                    state.clear();
                    onChanged();
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
