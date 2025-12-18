import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:boilerplate/core/widgets/month_calendar.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';
import 'package:boilerplate/presentation/crm/tour_plan/widgets/status_summary.dart';
import 'package:boilerplate/domain/entity/tour_plan/tour_plan.dart' as domain;
import 'package:boilerplate/presentation/crm/tour_plan/store/tour_plan_store.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/domain/repository/tour_plan/tour_plan_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobx/mobx.dart';
import 'package:boilerplate/presentation/crm/widgets/manager_comment_dialog.dart';

import 'package:boilerplate/data/network/apis/user/lib/domain/entity/tour_plan/calendar_view_data.dart';
import 'package:boilerplate/data/network/apis/user/lib/domain/entity/tour_plan/tour_plan_api_models.dart';
import 'dart:async';

const String kFilterClearToken = '__CLEAR__';

class TourPlanManagerReviewScreen extends StatefulWidget {
  const TourPlanManagerReviewScreen({super.key});

  @override
  State<TourPlanManagerReviewScreen> createState() => _TourPlanManagerReviewScreenState();
}

class _TourPlanManagerReviewScreenState extends State<TourPlanManagerReviewScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  String? _customer;
  String? _employee;
  String? _status; // Draft/Pending/Approved/Rejected
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDay; // No initial selection - shows all items
  late final TourPlanStore _store;
  late final UserDetailStore _userDetailStore;
  
  // Teal-green color constant
  static const Color tealGreen = Color(0xFF4db1b3);
  
  // Customer options loaded from API
  List<String> _customerOptions = [];
  final Map<String, int> _customerNameToId = {};
  
  // Status options loaded from API
  List<String> _statusOptions = [];
  final Map<String, int> _statusNameToId = {};
  
  // Employee options loaded from API (Manager's team employees)
  List<String> _employeeOptions = [];
  final Map<String, int> _employeeNameToId = {};

  // Selection state for bulk operations
  final Set<String> _selectedIds = <String>{};
  final Set<int> _selectedTourPlanIds = <int>{};
  // Auto-refresh support
  Timer? _autoRefreshTimer;
  bool _isAppInForeground = true;
  bool _isRefreshing = false;
  int _dataVersion = 0;
  
  // Filter modal state
  bool _showFilterModal = false;
  AnimationController? _filterModalController;
  Animation<double>? _filterModalAnimation;
  final ScrollController _filterScrollController = ScrollController();
  final GlobalKey _customerFilterSectionKey = GlobalKey();
  final GlobalKey _statusFilterSectionKey = GlobalKey();
  final GlobalKey _employeeFilterSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize stores
    _store = getIt<TourPlanStore>();
    _userDetailStore = getIt<UserDetailStore>();
    _store.month = _month;
    
    // Initialize filter modal animation
    _filterModalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _filterModalAnimation = CurvedAnimation(
      parent: _filterModalController!,
      curve: Curves.easeOut,
    );
    
    // Load initial data from API
    _refreshAll();
    _getTourPlanStatusList();
    _loadMappedCustomersByEmployeeId(); // Load customer list using API
    _getEmployeeList(); // Load employee list for filter (Manager's team)
    // Auto-refresh disabled - removed periodic API calls
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _filterModalController?.dispose();
    _filterScrollController.dispose();
    super.dispose();
  }
  
  void _openFilterModal() {
    if (_filterModalController == null) return;
    setState(() {
      _showFilterModal = true;
    });
    _filterModalController!.forward();
  }
  
  void _closeFilterModal() {
    if (_filterModalController == null) return;
    _filterModalController!.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showFilterModal = false;
        });
      }
    });
  }

  void _scrollFilterSectionIntoView(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      if (context == null || !_filterScrollController.hasClients) return;
      final RenderObject? renderObject = context.findRenderObject();
      if (renderObject == null || !renderObject.attached) return;
      final RenderAbstractViewport? viewport = RenderAbstractViewport.of(renderObject);
      if (viewport == null) return;
      final double target = viewport.getOffsetToReveal(renderObject, 0.05).offset;
      final position = _filterScrollController.position;
      final double clamped = target.clamp(position.minScrollExtent, position.maxScrollExtent);
      _filterScrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;
    if (_isAppInForeground) {
      _refreshAll();
      // Auto-refresh disabled
    } else {
      _autoRefreshTimer?.cancel();
    }
  }

  Future<void> _refreshAll() async {
    if (_isRefreshing) {
      print('TourPlanManagerReviewScreen: Refresh already in progress, skipping');
      return;
    }
    _isRefreshing = true;
    print('TourPlanManagerReviewScreen: Starting refresh all data...');
    try {
      print('TourPlanManagerReviewScreen: Loading calendar view data...');
      await _loadCalendarViewData();
      print('TourPlanManagerReviewScreen: Loading employee list summary...');
      await _loadTourPlanEmployeeListSummary();
      print('TourPlanManagerReviewScreen: Loading tour plan summary...');
      await _loadTourPlanSummary();
      // Load data with current filters (if any) - local filtering will handle display
      if (_hasActiveFilters()) {
        print('TourPlanManagerReviewScreen: Loading calendar item list data with filters...');
        await _loadCalendarItemListData();
      } else {
        print('TourPlanManagerReviewScreen: Loading calendar item list data without filters...');
        await _loadCalendarItemListDataWithoutFilters();
      }
      print('TourPlanManagerReviewScreen: Refresh all data completed successfully');
    } catch (e) {
      print('TourPlanManagerReviewScreen: Error during refresh: $e');
    } finally {
      _isRefreshing = false;
      if (mounted) {
        setState(() { 
          _dataVersion++;
          print('TourPlanManagerReviewScreen: Data version incremented to $_dataVersion');
        });
      }
    }
  }

  Future<void> _refreshAllWithLoader() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await _refreshAll();
    } finally {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  // Auto-refresh disabled - removed periodic API calls
  // void _startAutoRefresh() {
  //   _autoRefreshTimer?.cancel();
  //   _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
  //     if (_isAppInForeground && mounted) {
  //       await _refreshAll();
  //     }
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final double actionHeight = isTablet ? 54 : 48;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          SafeArea(
            child: Container(
              color: Colors.grey[50],
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 20 : 16,
                ),
                child: RefreshIndicator(
                  onRefresh: _onPullToRefresh,
                  edgeOffset: 12,
                  displacement: 36,
                  color: tealGreen,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: 24 + MediaQuery.of(context).padding.bottom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Modern Header Section
                        Container(
                          margin: EdgeInsets.only(bottom: isTablet ? 20 : 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedIds.isNotEmpty 
                                            ? '${_selectedIds.length} plan(s) selected'
                                            : 'Manager Review',
                                        style: GoogleFonts.inter(
                                          fontSize: isTablet ? 20 : 18,
                                          fontWeight: FontWeight.normal,
                                          color: Colors.grey[900],
                                          letterSpacing: -0.8,
                                        ),
                                      ),
                                      SizedBox(height: isTablet ? 6 : 4),
                                      Text(
                                        _selectedIds.isNotEmpty 
                                            ? 'Review selected plans'
                                            : 'Select plans to review',
                                        style: GoogleFonts.inter(
                                          fontSize: isTablet ? 14 : 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Filter Icon Button with Badge
                                  _FilterIconButton(
                                    filterCount: _getActiveFilterCount(),
                                    onTap: _openFilterModal,
                                    isTablet: isTablet,
                                  ),
                                ],
                              ),
                              SizedBox(height: isTablet ? 20 : 16),
                              // Action Buttons Row - Select All and Filter Count in one row (50% 50%)
                              // Hide entire row when items are selected
                              if (_selectedIds.isEmpty)
                                Row(
                                  children: [
                                    // Select All Button - 50% width
                                    if (_store.calendarItemListData.isNotEmpty)
                                      Expanded(
                                        child: SizedBox(
                                          height: actionHeight,
                                          child: FilledButton.icon(
                                            onPressed: _selectAllPlans,
                                            icon: Icon(Icons.select_all, size: isTablet ? 20 : 18),
                                            label: Text(
                                              'Select All',
                                              style: GoogleFonts.inter(
                                                fontSize: isTablet ? 16 : 15,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: tealGreen,
                                              foregroundColor: Colors.white,
                                              elevation: 4,
                                              shadowColor: tealGreen.withOpacity(0.4),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isTablet ? 20 : 16,
                                              ),
                                              minimumSize: Size.fromHeight(actionHeight),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_store.calendarItemListData.isNotEmpty)
                                      SizedBox(width: isTablet ? 12 : 10),
                                    // Filter Count Display - 50% width
                                    Expanded(
                                      child: SizedBox(
                                        height: actionHeight,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isTablet ? 16 : 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tealGreen.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: tealGreen.withOpacity(0.2),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.filter_alt_rounded,
                                                color: tealGreen,
                                                size: isTablet ? 18 : 16,
                                              ),
                                              SizedBox(width: isTablet ? 8 : 6),
                                              Flexible(
                                                child: Text(
                                                  _hasActiveFilters()
                                                      ? '${_getFilteredRecordCount()} records'
                                                      : 'No filters',
                                                  style: GoogleFonts.inter(
                                                    fontSize: isTablet ? 14 : 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: tealGreen,
                                                    letterSpacing: -0.1,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        // Only add spacing if the action buttons row is visible
                        if (_selectedIds.isEmpty)
                          const SizedBox(height: 12),
                        // Selection summary card - similar to DCR manager review
                        if (_selectedIds.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final bool isMobile = constraints.maxWidth < 600;
                              return Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 12 : 16,
                                  vertical: isMobile ? 10 : 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF7F7), // Light blue-green background
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF4db1b3).withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    // Checkmark icon on left
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4db1b3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Selection count text
                                    Expanded(
                                      child: Text(
                                        '${_selectedIds.length} plan(s) selected',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF4db1b3),
                                          fontSize: isMobile ? 13 : 14,
                                        ),
                                      ),
                                    ),
                                    // Clear Selection text and X button on right
                                    InkWell(
                                      onTap: _clearSelection,
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.close, color: Color(0xFF4db1b3), size: 18),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Clear Selection',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF4db1b3),
                                                fontSize: isMobile ? 13 : 14,
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
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Monthly status donut summary
                        Observer(
                          builder: (_) {
                            // Show loading indicator while summary data is loading
                            if (_store.tourPlanSummaryLoading || _store.fetchTourPlanSummaryFuture == null) {
                              return Card(
                                margin: EdgeInsets.zero,
                                // elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Monthly Status Summary',
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 16),
                                      const Center(
                                        child: Column(
                                          children: [
                                            CircularProgressIndicator(),
                                            SizedBox(height: 8),
                                            Text('Loading summary...'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            
                            // Use same API data as tour plan screen
                            if (_store.tourPlanSummaryData != null) {
                              final data = _store.tourPlanSummaryData!;
                              final Map<TourPlanStatus, int> apiCounts = {
                                TourPlanStatus.planned: data.planedDays,
                                TourPlanStatus.approved: data.approvedDays,
                                TourPlanStatus.pending: data.pendingDays,
                                TourPlanStatus.leaveDays: 0,
                                TourPlanStatus.notEntered: data.sentBackDays,
                              };
                              return StatusDonutCard(
                                counts: apiCounts,
                                title: 'Monthly Status Summary',
                              );
                            } else {
                              return StatusDonutCard(
                                counts: _buildMonthlyCounts([]),
                                title: 'Monthly Status Summary',
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        // Calendar with API loading indicator
                        Observer(
                  builder: (_) {
                    return Card(
                      color: Colors.white,
                      margin: EdgeInsets.zero,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                      ),
                      elevation: 12,
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Observer(
                                  builder: (_) {
                                    // Rebuild decorations when calendar view data changes or filters change
                                    final Map<DateTime, CalendarDayDecoration> decorations = _buildApiDayDecorations(_store.calendarViewData);
                                    final bool isLoading = _store.calendarLoading;
                                    return Stack(
                                      children: [
                                        MonthCalendar(
                                          key: ValueKey('mgr-month-cal-$_dataVersion-${_employee}-${_customer}-${_status}'),
                                          visibleMonth: _month,
                                          selectedDate: _selectedDay,
                                          onDateTap: (d) {
                                            setState(() {
                                              _selectedDay = _selectedDay != null && _isSameDate(_selectedDay!, d) ? null : d;
                                            });
                                          },
                                          onMonthChanged: (m) async {
                                            setState(() {
                                              _month = DateTime(m.year, m.month, 1);
                                              _selectedDay = null;
                                              _store.month = _month;
                                            });
                                            
                                            // Call API when month changes - use filters if any are active
                                            await _loadCalendarViewData();
                                            if (_hasActiveFilters()) {
                                            await _loadCalendarItemListData();
                                            } else {
                                              await _loadCalendarItemListDataWithoutFilters();
                                            }
                                            await _loadTourPlanEmployeeListSummary();
                                            await _loadTourPlanSummary(); // Load tour plan summary for new month
                                            
                                            // Force UI update after all data is loaded
                                            if (mounted) {
                                              setState(() {});
                                            }
                                          },
                                          summaryText: _daysAndHolidaysLabel(_month),
                                          cellSpacing: 10,
                                          cellCornerRadius: 12,
                                          dayDecorations: decorations,
                                          legendItems: _buildLegendItems(),
                                        ),
                                        // Calendar loading overlay - reactive to loading state
                                        if (isLoading)
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.8),
                                                borderRadius: BorderRadius.circular(28),
                                              ),
                                              child: const Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    CircularProgressIndicator(),
                                                    SizedBox(height: 8),
                                                    Text('Loading calendar...'),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                        const SizedBox(height: 12),
                        // Selected day plans from API (Calendar Item List Data)
                        Observer(builder: (_) {
                  final DateTime? selected = _selectedDay;
                  // Apply all filters: date, customer, employee, and status
                  final apiItems = _store.calendarItemListData.where((item) {
                    // Filter by date
                    final bool byDate = selected == null || _isSameDate(item.planDate, selected);
                    
                    // Filter by customer
                    bool byCustomer = true;
                    if (_customer != null && _customer!.isNotEmpty) {
                      byCustomer = false;
                      // Try matching by name (case-insensitive)
                      if (item.customerName != null && item.customerName!.trim().isNotEmpty) {
                        final itemName = item.customerName!.trim().toLowerCase();
                        final filterName = _customer!.trim().toLowerCase();
                        if (itemName == filterName) {
                          byCustomer = true;
                        }
                      }
                      // Try matching by ID if name didn't match
                      if (!byCustomer && _customerNameToId.containsKey(_customer)) {
                        final filterCustomerId = _customerNameToId[_customer!];
                        if (item.customerId == filterCustomerId) {
                          byCustomer = true;
                        }
                      }
                    }
                    
                    // Filter by employee
                    bool byEmployee = true;
                    if (_employee != null && _employee!.isNotEmpty) {
                      byEmployee = false;
                      // Try matching by name (case-insensitive)
                      if (item.employeeName != null && item.employeeName!.trim().isNotEmpty) {
                        final itemName = item.employeeName!.trim().toLowerCase();
                        final filterName = _employee!.trim().toLowerCase();
                        if (itemName == filterName) {
                          byEmployee = true;
                        }
                      }
                      // Try matching by ID if name didn't match
                      if (!byEmployee && _employeeNameToId.containsKey(_employee)) {
                        final filterEmployeeId = _employeeNameToId[_employee!];
                        if (item.employeeId == filterEmployeeId) {
                          byEmployee = true;
                        }
                      }
                    }
                    
                    // Filter by status
                    // Apply local status filtering as a verification/safety check
                    // Note: API already filters by status, but we verify here for consistency
                    bool byStatus = true;
                    if (_status != null && _status!.isNotEmpty) {
                      final filterStatusId = _statusNameToId[_status];
                      
                      if (filterStatusId != null) {
                        // Check item.status field (this is the status value from API)
                        // Status IDs: 5=Approved, 1=Pending/Submitted, 4=Sent Back, 3=Rejected, 2=Submitted
                        if (item.status == filterStatusId) {
                          byStatus = true;
                        }
                        // Also check statusId field as fallback
                        else if (item.statusId == filterStatusId) {
                          byStatus = true;
                        }
                        // Try statusText matching for text-based filtering
                        else if (item.statusText != null && item.statusText!.trim().isNotEmpty) {
                          final itemStatusText = item.statusText!.trim().toLowerCase();
                          final filterStatusText = _status!.trim().toLowerCase();
                          if (itemStatusText == filterStatusText || 
                              itemStatusText.contains(filterStatusText) || 
                              filterStatusText.contains(itemStatusText)) {
                            byStatus = true;
                          }
                        }
                        // If none match but API filtered, trust API result (API already filtered correctly)
                        // This handles edge cases where local fields don't match but API filtered correctly
                        else {
                          // Trust API filtering - if API returned it with status filter, it's correct
                          byStatus = true;
                        }
                      } else {
                        // Status not in mapping - use text matching only
                        if (item.statusText != null && item.statusText!.trim().isNotEmpty) {
                          final itemStatusText = item.statusText!.trim().toLowerCase();
                          final filterStatusText = _status!.trim().toLowerCase();
                          if (itemStatusText == filterStatusText || 
                              itemStatusText.contains(filterStatusText) || 
                              filterStatusText.contains(itemStatusText)) {
                            byStatus = true;
                          } else {
                            byStatus = false;
                          }
                        } else {
                          // No status text available - trust API filtering
                          byStatus = true;
                        }
                      }
                    }
                    
                    final bool passes = byDate && byCustomer && byEmployee && byStatus;
                    return passes;
                  }).toList()
                    ..sort((a, b) => a.planDate.compareTo(b.planDate));
                  
                  // Debug: Log filtering results
                  if (_status != null) {
                    print('TourPlanManagerReviewScreen: Status filter "$_status" applied - '
                        'Total items: ${_store.calendarItemListData.length}, '
                        'Filtered items: ${apiItems.length}');
                  }
                  
                  return Card(
                    color: Colors.white,
                    margin: EdgeInsets.zero,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                    ),
                    elevation: 12,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      selected != null 
                                          ? 'Plans on ${_formatDate(selected)} (Manager Review)'
                                          : 'All Tour plans (Manager Review)',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (apiItems.isNotEmpty) ...[
                                // Hide records count when items are selected
                                if (_selectedIds.isEmpty) ...[
                                  Text(
                                    'Total Records: ${apiItems.length}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                ...(apiItems.map((item) => _buildTourPlanItemCard(item))),
                              ] else if (!_store.calendarItemListDataLoading) ...[
                                Text(
                                  selected != null 
                                      ? 'No plans for the selected day.'
                                      : 'No tour plans available for review.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_store.calendarItemListDataLoading)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 8),
                                  Text('Loading tour plans...'),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Filter Modal
          if (_showFilterModal) _buildFilterModal(isMobile: isMobile, isTablet: isTablet, tealGreen: tealGreen),
        ],
      ),
      bottomNavigationBar: _selectedIds.isNotEmpty
          ? _BottomActionBar(
              selectedCount: _selectedIds.length,
              onApprove: _bulkApprove,
              onSendBack: () => _bulkSendBackWithComment(),
              onClear: _clearSelection,
              canApprove: _canApproveSelected(),
              canSendBack: _canSendBackSelected(),
            )
          : null,
    );
  }

  Future<void> _onPullToRefresh() async {
    await _refreshAll();
  }

  /// Helper methods to determine button states based on selected items' statuses
  /// Workflow rules:
  /// 1. If Approved: No actions allowed
  /// 2. If Sent Back: Approve button is disabled
  /// 3. Legacy “Rejected” status is treated like Sent Back — only Approve allowed
  /// 4. If Pending: Approve or Send Back allowed
  
  bool _canApproveSelected() {
    if (_selectedIds.isEmpty) return false;
    
    // Get statuses of selected items
    final selectedItems = _store.calendarItemListData
        .where((item) => _selectedIds.contains(item.id.toString()))
        .toList();
    
    if (selectedItems.isEmpty) return false;
    
    // Check if all items are approved
    final allApproved = selectedItems.every((item) => item.status == 5);
    if (allApproved) return false;
    
    // Check if any item is sent back (status = 4) - disable Approve button
    final hasSentBack = selectedItems.any((item) => item.status == 4);
    if (hasSentBack) return false;
    
    // Can approve if not all are approved and none are sent back
    return true;
  }
  
  bool _canSendBackSelected() {
    if (_selectedIds.isEmpty) return false;
    
    final selectedItems = _store.calendarItemListData
        .where((item) => _selectedIds.contains(item.id.toString()))
        .toList();
    
    if (selectedItems.isEmpty) return false;
    
    // Check statuses: 5=Approved, 4=Sent Back, 3=Rejected, 1/2=Pending
    final allApproved = selectedItems.every((item) => item.status == 5);
    final allSentBack = selectedItems.every((item) => item.status == 4);
    
    // Can send back if pending or rejected (not if already sent back or approved)
    return !allApproved && !allSentBack;
  }
  

  /// Build a card widget for a tour plan item with selection checkbox
  Widget _buildTourPlanItemCard(TourPlanItem item) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final bool isSelected = _selectedIds.contains(item.id.toString());
    // Disable selection for approved tour plans (status = 5)
    final bool isApproved = item.status == 5;
    final bool isDisabled = isApproved;
    
    // Get status text with fallbacks
    final statusText = _getStatusDisplayText(item);
    final statusColor = _getStatusColor(item.status);
    final statusBgColor = _getStatusBackgroundColor(item.status);
    final customerName = item.customerName ?? 'Customer ${item.customerId}';
    
    return InkWell(
      onTap: () => _viewPlanDetails(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: EdgeInsets.only(bottom: isTablet ? 12 : 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(.06), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Opacity(
          opacity: isDisabled ? 0.7 : 1.0,
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 14 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row: Icon + Customer Name + View Button (matching DCR list)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Selection checkbox - disabled if approved
                    SizedBox(
                      width: isTablet ? 22 : 20,
                      height: isTablet ? 22 : 20,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: isDisabled ? null : (_) => _toggleSelection(item),
                        activeColor: tealGreen,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Icon container (matching DCR list)
                    Container(
                      width: isTablet ? 40 : 36,
                      height: isTablet ? 40 : 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        color: tealGreen,
                        size: isTablet ? 20 : 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Customer Name - matching DCR list text color
                    Expanded(
                      child: Text(
                        customerName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 13 : 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: Colors.black87, // Same as DCR list
                        ),
                      ),
                    ),
                    // View Button - Right side (visual only, card is clickable)
                    Container(
                      width: isTablet ? 36 : 32,
                      height: isTablet ? 36 : 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: Icon(Icons.visibility_outlined, size: isTablet ? 16 : 14, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Employee row (matching DCR list)
                if (item.employeeName != null && item.employeeName!.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: isTablet ? 13 : 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item.employeeName!,
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 11 : 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                // Status and Date row: Status on left, Date on right (matching DCR list layout)
                Row(
                  children: [
                    // Status chip on left
                    if (statusText.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: isTablet ? 9 : 8, vertical: isTablet ? 4 : 3),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: isTablet ? 5 : 4,
                              height: isTablet ? 5 : 4,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: isTablet ? 5 : 4),
                            Flexible(
                              child: Text(
                                statusText,
                                style: GoogleFonts.inter(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: isTablet ? 11 : 10,
                                  letterSpacing: 0.1,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    // Date on right (where status was)
                    if (item.planDate != null) ...[
                      Icon(
                        Icons.calendar_today_outlined,
                        size: isTablet ? 13 : 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatDate(item.planDate!),
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 11 : 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
  
  /// Build info section for card display (simplified version)
  Widget _buildCardInfoSection(String title, List<MapEntry<String, String>> items, bool isTablet) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: isTablet ? 11 : 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: isTablet ? 100 : 90,
                child: Text(
                  '${item.key}:',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 11 : 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  item.value,
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 11 : 10,
                    color: Colors.grey[900],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  /// Check if tour plan can be selected (not approved)
  bool _canSelectTourPlan(TourPlanItem item) {
    // Approved tour plans (status = 5) cannot be selected
    return item.status != 5;
  }

  /// Toggle selection of a tour plan item
  void _toggleSelection(TourPlanItem item) {
    // Don't allow selection of approved tour plans
    if (!_canSelectTourPlan(item)) {
      ToastMessage.show(
        context,
        message: 'Approved tour plans cannot be selected for review actions',
        type: ToastType.warning,
      );
      return;
    }
    
    setState(() {
      if (_selectedIds.contains(item.id.toString())) {
        _selectedIds.remove(item.id.toString());
        _selectedTourPlanIds.remove(item.tourPlanId);
      } else {
        _selectedIds.add(item.id.toString());
        _selectedTourPlanIds.add(item.tourPlanId);
      }
    });
  }

  /// Select all visible tour plans (excluding approved ones)
  void _selectAllPlans() {
    setState(() {
      _selectedIds.clear();
      _selectedTourPlanIds.clear();
      
      for (final item in _store.calendarItemListData) {
        // Only select plans that are not approved
        if (_canSelectTourPlan(item)) {
          _selectedIds.add(item.id.toString());
          _selectedTourPlanIds.add(item.tourPlanId);
        }
      }
    });
    
    ToastMessage.show(
      context,
      message: 'Selected ${_selectedIds.length} tour plan(s)',
      type: ToastType.info,
    );
  }

  /// Clear all selections
  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _selectedTourPlanIds.clear();
    });
    
    ToastMessage.show(
      context,
      message: 'Selection cleared',
      type: ToastType.info,
    );
  }

  /// View detailed information for a tour plan
  void _viewPlanDetails(TourPlanItem item) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final statusText = _getStatusDisplayText(item);
    final statusColor = _getStatusColor(item.status);
    final statusBgColor = _getStatusBackgroundColor(item.status);
    final customerName = item.customerName ?? 'Customer ${item.customerId}';
    final customerCode = item.customerId != null ? ' - P${item.customerId.toString().padLeft(5, '0')}' : '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 600 : MediaQuery.of(context).size.width,
          maxHeight: MediaQuery.of(context).size.height * (isTablet ? 0.85 : 0.9),
        ),
        margin: isTablet
            ? EdgeInsets.symmetric(
                horizontal: (MediaQuery.of(context).size.width - 600) / 2,
                vertical: MediaQuery.of(context).size.height * 0.075,
              )
            : null,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header (mint like deviation screen)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F7),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4db1b3).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.description_outlined,
                            color: const Color(0xFF4db1b3),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  'Tour Plan Details',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[900],
                                    fontSize: isTablet ? 16 : 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Status Chip
                              if (statusText.isNotEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 9 : 8,
                                    vertical: isTablet ? 4 : 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: statusColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: isTablet ? 5 : 4,
                                        height: isTablet ? 5 : 4,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      SizedBox(width: isTablet ? 5 : 4),
                                      Text(
                                        statusText,
                                        style: GoogleFonts.inter(
                                          color: statusColor,
                                          fontSize: isTablet ? 11 : 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                          color: Colors.grey[700],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Employee Information
                    if (item.employeeName != null || item.designation != null || item.planDate != null) ...[
                      Text(
                        'Employee Information',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 14 : 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: isTablet ? 10 : 8),
                      Container(
                        padding: EdgeInsets.all(isTablet ? 12 : 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            if (item.employeeName != null && item.employeeName!.isNotEmpty)
                              _DetailRow('Name', item.employeeName!),
                            if (item.designation != null && item.designation!.isNotEmpty) ...[
                              if (item.employeeName != null && item.employeeName!.isNotEmpty) SizedBox(height: isTablet ? 6 : 4),
                              _DetailRow('Designation', item.designation!),
                            ],
                            if (item.planDate != null) ...[
                              if ((item.employeeName != null && item.employeeName!.isNotEmpty) || (item.designation != null && item.designation!.isNotEmpty))
                                SizedBox(height: isTablet ? 6 : 4),
                              _DetailRow('Date', _formatDate(item.planDate)),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: isTablet ? 12 : 10),
                    ],
                    
                    // Location Details
                    if (item.cluster != null || item.clusters != null || item.territory != null) ...[
                      Text(
                        'Location Details',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 14 : 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: isTablet ? 10 : 8),
                      Container(
                        padding: EdgeInsets.all(isTablet ? 12 : 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            if (item.clusters != null && item.clusters!.isNotEmpty) ...[
                              _DetailRow('Clusters', item.clusters!),
                            ] else if (item.cluster != null && item.cluster!.isNotEmpty) ...[
                              _DetailRow('Cluster', item.cluster!),
                            ],
                            if (item.territory != null && item.territory!.isNotEmpty) ...[
                              if (item.cluster != null || item.clusters != null) SizedBox(height: isTablet ? 6 : 4),
                              _DetailRow('Territory', item.territory!),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: isTablet ? 12 : 10),
                    ],
                    
                    // Visit Details
                    if (customerName.isNotEmpty || item.productsToDiscuss != null || item.samplesToDistribute != null || item.objective != null) ...[
                      Text(
                        'Visit Details',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 14 : 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: isTablet ? 10 : 8),
                      Container(
                        padding: EdgeInsets.all(isTablet ? 12 : 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _DetailRow('Customer', '$customerName$customerCode'),
                            if (item.productsToDiscuss != null && item.productsToDiscuss!.isNotEmpty) ...[
                              SizedBox(height: isTablet ? 6 : 4),
                              _DetailRow('Products to Discuss', item.productsToDiscuss!),
                            ],
                            if (item.samplesToDistribute != null && item.samplesToDistribute!.isNotEmpty) ...[
                              SizedBox(height: isTablet ? 6 : 4),
                              _DetailRow('Samples to Distribute', item.samplesToDistribute!),
                            ],
                            if (item.objective != null && item.objective!.isNotEmpty) ...[
                              SizedBox(height: isTablet ? 6 : 4),
                              _DetailRow('Objective', item.objective!),
                            ],
                            if (item.tourPlanType != null && item.tourPlanType!.isNotEmpty) ...[
                              SizedBox(height: isTablet ? 6 : 4),
                              _DetailRow('Plan Type', item.tourPlanType!),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: isTablet ? 12 : 10),
                    ],
                    
                    // Additional Information
                    if (item.notes != null || item.remarks != null || item.managerComments != null) ...[
                      Text(
                        'Additional Information',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 14 : 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: isTablet ? 10 : 8),
                      Container(
                        padding: EdgeInsets.all(isTablet ? 12 : 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            if (item.notes != null && item.notes!.isNotEmpty) ...[
                              _DetailRow('Notes', item.notes!, isMultiline: true),
                            ],
                            if (item.remarks != null && item.remarks!.isNotEmpty) ...[
                              if (item.notes != null && item.notes!.isNotEmpty) SizedBox(height: isTablet ? 6 : 4),
                              _DetailRow('Remarks', item.remarks!, isMultiline: true),
                            ],
                            if (item.managerComments != null && item.managerComments!.isNotEmpty) ...[
                              if ((item.notes != null && item.notes!.isNotEmpty) || (item.remarks != null && item.remarks!.isNotEmpty))
                                SizedBox(height: isTablet ? 6 : 4),
                              _DetailRow('Manager Comments', item.managerComments!, isMultiline: true),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
              // Footer actions
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_shouldShowDeleteButton(item))
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _deleteTourPlan(item);
                          },
                          icon: const Icon(Icons.delete_outlined, size: 18),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Detail row widget for popup (matching deviation screen)
  Widget _DetailRow(String label, String value, {bool isMultiline = false}) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: isMobile ? 100 : 120,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 11 : 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
              fontSize: isMobile ? 12 : 13,
            ),
            maxLines: isMultiline ? null : 3,
            overflow: isMultiline ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Check if delete button should be shown for a tour plan item
  /// Delete button should only be visible when status is "Pending" (status == 1 or 2)
  /// If roleCategoryId === 3, only show delete for pending tour plans
  bool _shouldShowDeleteButton(TourPlanItem item) {
    // Status IDs: 5=Approved, 4=Sent Back, 3=Rejected, 2=Submitted, 1=Pending, 0=Draft
    // Only show delete for Pending status (1 or 2)
    final bool isPending = item.status == 1 || item.status == 2;
    
    if (!isPending) return false;
    
    // If roleCategoryId === 3, only show delete for pending tour plans
    final roleCategory = _userDetailStore.userDetail?.roleCategory;
    if (roleCategory == 3) {
      return isPending; // Already checked above, but explicit for clarity
    }
    
    // For other roles, show delete for pending status
    return isPending;
  }

  /// Delete tour plan
  Future<void> _deleteTourPlan(TourPlanItem item) async {
    // Close the details dialog first
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    
    // Show confirmation dialog
    final bool? confirmed = await _showConfirmationDialog(
      'Delete Tour Plan',
      'Are you sure you want to delete this tour plan? This action cannot be undone.',
    );
    
    if (confirmed != true) return;
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      final response = await _store.deleteTourPlan(item.id);
      
      // Close loading dialog
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (mounted) {
        if (response.status) {
          ToastMessage.show(
            context,
            message: response.message.isNotEmpty ? response.message : 'Tour plan deleted successfully',
            type: ToastType.success,
          );
          
          // Refresh data after deletion
          await _refreshAllWithLoader();
        } else {
          ToastMessage.show(
            context,
            message: response.message.isNotEmpty ? response.message : 'Failed to delete tour plan',
            type: ToastType.error,
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Error deleting tour plan: $e',
          type: ToastType.error,
        );
      }
    }
  }

  /// Build detail row for dialog
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  /// Build info row for card
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Bulk approve selected tour plans
  void _bulkApprove() async {
    if (_selectedIds.isEmpty) {
      ToastMessage.show(
        context,
        message: 'Please select at least one tour plan to approve',
        type: ToastType.warning,
      );
      return;
    }
    
    // Filter out approved items from selection
    final validSelectedIds = <String>{};
    final sentBackSelectedIds = <String>{}; // Track sent back items separately
    for (final item in _store.calendarItemListData) {
      if (_selectedIds.contains(item.id.toString()) && _canSelectTourPlan(item)) {
        validSelectedIds.add(item.id.toString());
        // Track sent back items separately for debugging
        if (item.status == 4) {
          sentBackSelectedIds.add(item.id.toString());
          print('TourPlanManagerReviewScreen: Found sent back item in selection: ID=${item.id}, Status=${item.status}, TourPlanId=${item.tourPlanId}');
        }
      }
    }
    
    print('TourPlanManagerReviewScreen: Total selected: ${_selectedIds.length}, Valid: ${validSelectedIds.length}, Sent Back: ${sentBackSelectedIds.length}');
    
    if (validSelectedIds.isEmpty) {
      ToastMessage.show(
        context,
        message: 'No valid tour plans selected. Approved plans cannot be selected.',
        type: ToastType.warning,
      );
      return;
    }
    
    // Show confirmation dialog
    final bool? confirmed = await _showConfirmationDialog(
      'Approve Tour Plans',
      'Are you sure you want to approve ${validSelectedIds.length} selected tour plan(s)?',
    );
    
    if (confirmed != true) return;
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Group by tour plan ID for bulk operations (include all valid items together - pending, sent back, etc.)
      final Map<int, List<int>> groupedByTourPlan = {};
      final Map<int, List<int>> sentBackItemIds = {}; // Track sent back item IDs for logging
      
      for (final item in _store.calendarItemListData) {
        if (validSelectedIds.contains(item.id.toString()) && _canSelectTourPlan(item)) {
          // Check if this is a sent back item (status = 4) for logging
          if (item.status == 4) {
            if (!sentBackItemIds.containsKey(item.tourPlanId)) {
              sentBackItemIds[item.tourPlanId] = [];
            }
            sentBackItemIds[item.tourPlanId]!.add(item.id);
            print('TourPlanManagerReviewScreen: Including sent back item in approval: ID=${item.id}, Status=${item.status}, TourPlanId=${item.tourPlanId}');
          }
          
          // Group all items together by tour plan ID (including sent back items)
          if (!groupedByTourPlan.containsKey(item.tourPlanId)) {
            groupedByTourPlan[item.tourPlanId] = [];
          }
          groupedByTourPlan[item.tourPlanId]!.add(item.id);
        }
      }
      
      // Log grouping information
      if (sentBackItemIds.isNotEmpty) {
        print('TourPlanManagerReviewScreen: Found ${sentBackItemIds.length} tour plan(s) with sent back items to approve');
        for (final entry in sentBackItemIds.entries) {
          print('TourPlanManagerReviewScreen: Tour plan ${entry.key} has ${entry.value.length} sent back item(s): ${entry.value}');
        }
      }
      
      // Perform bulk approve for each tour plan (all items together, including sent back)
      int successCount = 0;
      int failedCount = 0;
      
      for (final entry in groupedByTourPlan.entries) {
        final request = TourPlanBulkActionRequest(
          id: entry.key,
          action: 5, // Action code for approve (works for both pending and sent back items)
          tourPlanDetails: entry.value.map((id) => TourPlanDetailItem(id: id)).toList(),
        );
        
        final hasSentBackItems = sentBackItemIds.containsKey(entry.key);
        final itemType = hasSentBackItems ? 'items (including sent back)' : 'items';
        print('TourPlanManagerReviewScreen: Approving ${itemType} for tour plan ${entry.key}: ${entry.value}');
        print('TourPlanManagerReviewScreen: Request payload: ${request.toJson()}');
        
        try {
          final response = await _store.bulkApproveTourPlans(request);
          print('TourPlanManagerReviewScreen: API response - Status: ${response.status}, Message: ${response.message}');
          
          // Some environments return false/empty message despite succeeding.
          // Treat empty/Success-like messages as success to match observed behavior.
          final String msg = (response.message ?? '').trim().toLowerCase();
          final bool looksSuccessful = response.status ||
              msg.isEmpty ||
              msg == 'success' ||
              msg == 'ok' ||
              msg.contains('approved') ||
              msg.contains('done');
          
          if (looksSuccessful) {
            successCount += entry.value.length;
            print('TourPlanManagerReviewScreen: Counted success for ${entry.value.length} ${itemType} on tour plan ${entry.key}');
          } else {
            failedCount += entry.value.length;
            print('TourPlanManagerReviewScreen: API indicated failure for tour plan ${entry.key}: ${response.message}');
            if (hasSentBackItems && mounted) {
              ToastMessage.show(
                context,
                message: 'Failed to approve tour plan ${entry.key} (includes sent back items): ${response.message}',
                type: ToastType.warning,
                duration: const Duration(seconds: 4),
              );
            }
          }
        } catch (e) {
          failedCount += entry.value.length;
          print('TourPlanManagerReviewScreen: Exception approving ${itemType} for tour plan ${entry.key}: $e');
          
          // Show error message to user
          if (mounted) {
            ToastMessage.show(
              context,
              message: 'Error approving tour plan ${entry.key}: $e',
              type: ToastType.error,
              duration: const Duration(seconds: 4),
            );
          }
        }
      }
      
      // Close loading dialog
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (mounted) {
        // Show success/error message based on results
        if (successCount == validSelectedIds.length) {
          ToastMessage.show(
            context,
            message: 'Success: Approved $successCount out of ${validSelectedIds.length} plan(s)',
            type: ToastType.success,
          );
        } else if (successCount > 0) {
          ToastMessage.show(
            context,
            message: 'Partially approved: $successCount out of ${validSelectedIds.length} plan(s) approved. ${failedCount > 0 ? "$failedCount failed." : ""}',
            type: ToastType.warning,
            duration: const Duration(seconds: 4),
          );
        } else {
          ToastMessage.show(
            context,
            message: 'Failed to approve any tour plans. Please check the logs for details.',
            type: ToastType.error,
            duration: const Duration(seconds: 4),
          );
        }
        setState(() {
          _selectedIds.clear();
          _selectedTourPlanIds.clear();
        });
        print('TourPlanManagerReviewScreen: Calling _refreshAllWithLoader() after approval...');
        await _refreshAllWithLoader();
        print('TourPlanManagerReviewScreen: _refreshAllWithLoader() completed');
      }
    } catch (e) {
      // Close loading dialog
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Failed to approve plans: $e',
          type: ToastType.error,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  /// Bulk send back with comment
  void _bulkSendBackWithComment() async {
    if (_selectedIds.isEmpty) {
      ToastMessage.show(
        context,
        message: 'Please select at least one tour plan to send back',
        type: ToastType.warning,
      );
      return;
    }
    
    // Filter out approved items from selection
    final validSelectedIds = <String>{};
    for (final item in _store.calendarItemListData) {
      if (_selectedIds.contains(item.id.toString()) && _canSelectTourPlan(item)) {
        validSelectedIds.add(item.id.toString());
      }
    }
    
    if (validSelectedIds.isEmpty) {
      ToastMessage.show(
        context,
        message: 'No valid tour plans selected. Approved plans cannot be sent back.',
        type: ToastType.warning,
      );
      return;
    }
    
    final String? comment = await _showCommentDialog('Send Back');
    if (comment == null || comment.trim().isEmpty) {
      // ToastMessage.show(
      //   context,
      //   message: 'Comment is required for send back action',
      //   type: ToastType.warning,
      // );
      return;
    }
    
    // Show confirmation dialog
    final bool? confirmed = await _showConfirmationDialog(
      'Send Back Tour Plans',
      'Are you sure you want to send back ${validSelectedIds.length} selected tour plan(s) with the comment: "$comment"?',
    );
    
    if (confirmed != true) return;
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Group by tour plan ID for bulk operations (only non-approved items)
      final Map<int, List<int>> groupedByTourPlan = {};
      for (final item in _store.calendarItemListData) {
        if (validSelectedIds.contains(item.id.toString()) && _canSelectTourPlan(item)) {
          if (!groupedByTourPlan.containsKey(item.tourPlanId)) {
            groupedByTourPlan[item.tourPlanId] = [];
          }
          groupedByTourPlan[item.tourPlanId]!.add(item.id);
        }
      }
      
      // Perform bulk send back for each tour plan
      int successCount = 0;
      for (final entry in groupedByTourPlan.entries) {
        final request = TourPlanBulkActionRequest(
          id: entry.key,
          action: 4, // Action code for send back
          tourPlanDetails: entry.value.map((id) => TourPlanDetailItem(id: id)).toList(),
        );
        
        final response = await _store.bulkSendBackTourPlans(request);
        if (response.status) {
          successCount += entry.value.length;
          
          // Save comment for this tour plan
          await _saveCommentForTourPlan(entry.key, comment);
        }
      }
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Success: Sent back $successCount out of ${validSelectedIds.length} plan(s)',
          type: ToastType.success,
        );
        setState(() {
          _selectedIds.clear();
          _selectedTourPlanIds.clear();
        });
        await _refreshAllWithLoader();
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Failed to send back plans: $e',
          type: ToastType.error,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  /// Show comment dialog for send back or reject actions
  Future<String?> _showCommentDialog(String action) {
    return ManagerCommentDialog.show(
      context,
      action: action,
      entityLabel: 'Plans',
      description: 'Please provide a comment for $action action:',
      hintText: 'Enter your comment...',
      requireComment: true,
    );
  }
 

  /// Show confirmation dialog for bulk operations
  Future<bool?> _showConfirmationDialog(String title, String message) async {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTablet ? 20 : 18),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 500 : double.infinity,
          ),
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: isTablet ? 40 : 36,
                    height: isTablet ? 40 : 36,
                    decoration: BoxDecoration(
                      color: tealGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: tealGreen,
                      size: isTablet ? 22 : 20,
                    ),
                  ),
                  SizedBox(width: isTablet ? 14 : 12),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (Navigator.of(context, rootNavigator: true).canPop()) {
                        Navigator.of(context, rootNavigator: true).pop(false);
                      }
                    },
                    icon: Icon(Icons.close, color: Colors.grey[600], size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 20 : 16),
              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 15 : 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              SizedBox(height: isTablet ? 24 : 20),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 20,
                        vertical: isTablet ? 14 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 15 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  SizedBox(width: isTablet ? 12 : 10),
                  FilledButton(
                    onPressed: () {
                      if (Navigator.of(context, rootNavigator: true).canPop()) {
                        Navigator.of(context, rootNavigator: true).pop(true);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: tealGreen,
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 20,
                        vertical: isTablet ? 14 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Confirm',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 15 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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

  // ... (Include all the helper methods from the original tour_plan_screen.dart)
  // I'll include the essential methods here:

  Map<DateTime, CalendarDayDecoration> _buildApiDayDecorations(List<CalendarViewData> apiData) {
    final Map<DateTime, CalendarDayDecoration> map = <DateTime, CalendarDayDecoration>{};
    for (final d in apiData) {
      Color? color;
      if (d.isHolidayDay == true) {
        color = Colors.purple;
      } else if (d.isWeekend == true) {
        color = Colors.grey;
      } else {
        final Object? calls = d.plannedCalls;
        if (calls is List && calls.isNotEmpty) {
          bool hasApproved = false;
          bool hasSentBackOrRejected = false;
          bool hasPending = false;

          for (final c in calls) {
            if (c is Map) {
              final int statusId = (c['statusId'] is int)
                  ? c['statusId'] as int
                  : int.tryParse('${c['statusId']}') ?? 0;
              if (statusId == 5) hasApproved = true;
              if (statusId == 4 || statusId == 3) hasSentBackOrRejected = true;
              if (statusId == 1 || statusId == 2) hasPending = true;
            }
          }

          if (hasApproved) {
            color = const Color(0xFF2DBE64);
          } else if (hasSentBackOrRejected) {
            color = Colors.redAccent;
          } else if (hasPending) {
            color = const Color(0xFFFFA41C);
          }
        }

        color ??= (d.plannedCount > 0) ? const Color(0xFF2B78FF) : null;
      }

      if (color != null) {
        map[DateTime(d.planDate.year, d.planDate.month, d.planDate.day)] =
            CalendarDayDecoration(backgroundColor: color);
      }
    }
    return map;
  }

  Map<TourPlanStatus, int> _buildMonthlyCounts(List<domain.TourPlanEntry> entries) {
    int planned = entries.length;
    int pending = entries.where((e) => e.status == domain.TourPlanEntryStatus.pending || e.status == domain.TourPlanEntryStatus.sentBack).length;
    int approved = entries.where((e) => e.status == domain.TourPlanEntryStatus.approved).length;
    int leaveDays = 0;
    int notEntered = entries.where((e) => e.status == domain.TourPlanEntryStatus.draft || e.status == domain.TourPlanEntryStatus.rejected).length;
    return {
      TourPlanStatus.planned: planned,
      TourPlanStatus.pending: pending,
      TourPlanStatus.approved: approved,
      TourPlanStatus.leaveDays: leaveDays,
      TourPlanStatus.notEntered: notEntered,
    };
  }

  Map<TourPlanStatus, int> _buildManagerSummaryCounts(TourPlanGetManagerSummaryResponse data) {
    return {
      TourPlanStatus.planned: data.totalPlanned,
      TourPlanStatus.pending: data.totalPending,
      TourPlanStatus.approved: data.totalApproved,
      TourPlanStatus.leaveDays: data.totalLeave,
      TourPlanStatus.notEntered: data.totalNotEntered,
    };
  }

  bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Save comment for a tour plan
  Future<void> _saveCommentForTourPlan(int tourPlanId, String comment) async {
    try {
      final userId = _userDetailStore.userDetail?.userId ?? 0;
      
      // Format date as ISO 8601 format: "2025-11-10T20:27:00.000" (local time, no timezone)
      // Use local time instead of UTC to match the user's current time
      final now = DateTime.now(); // Use local time, not UTC
      final year = now.year.toString().padLeft(4, '0');
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      final hour = now.hour.toString().padLeft(2, '0');
      final minute = now.minute.toString().padLeft(2, '0');
      final second = now.second.toString().padLeft(2, '0');
      final millisecond = now.millisecond.toString().padLeft(3, '0');
      // Format: "2025-11-10T20:27:00.000" (no 'Z' suffix since it's local time)
      final commentDate = '$year-$month-${day}T$hour:$minute:$second.${millisecond}';
      
      print('TourPlanManagerReviewScreen: Comment date (local time): $commentDate');
      print('TourPlanManagerReviewScreen: Current local time: ${now.toString()}');
      
      final request = TourPlanCommentSaveRequest(
        createdBy: userId,
        tourPlanId: tourPlanId,
        comment: comment,
        commentDate: commentDate, // Format: "2025-11-10T20:27:00.000"
        isSystemGenerated: 0,
        tourPlanType: 'TP',
        userId: userId,
        active: 1,
      );
      
      await _store.saveTourPlanComment(request);
      print('TourPlanManagerReviewScreen: Comment saved for tour plan $tourPlanId');
    } catch (e) {
      print('TourPlanManagerReviewScreen: Error saving comment for tour plan $tourPlanId: $e');
      // Don't throw error here as the main action (send back/reject) might have succeeded
    }
  }

  void _applyFilters() {
    // Filters are applied both locally (immediate UI update) and via API (server-side filtering)
    if (mounted) {
      // Clear any selected approved items before applying filters
      setState(() {
        _selectedIds.removeWhere((id) {
          try {
            final item = _store.calendarItemListData.firstWhere(
              (item) => item.id.toString() == id,
            );
            return !_canSelectTourPlan(item);
          } catch (e) {
            // Item not found in current list, remove it
            return true;
          }
        });
      });
      
      // Trigger UI rebuild to apply local filters immediately
      setState(() {});
      
      // Reload calendar view and list data from API with filters applied
      // This ensures server-side filtering and gets the correct filtered data
      // The loading indicators in the UI will automatically show while data loads
      _loadCalendarViewData();
      _loadCalendarItemListData();
      _loadTourPlanSummary();
      _loadTourPlanEmployeeListSummary();
    }
  }

  void _clearAllFilters() async {
    setState(() {
      _customer = null;
      _employee = null;
      _status = null;
      _dataVersion++; // Force UI rebuild
    });
    // Force hard refresh - reload calendar view and list data without filters
    await Future.wait([
      _loadCalendarViewData(),
      _loadCalendarItemListDataWithoutFilters(),
      _loadTourPlanEmployeeListSummary(),
    ]);
    // Apply filters after data is loaded
    if (mounted) {
      setState(() {
        _applyFilters();
      });
    }
  }
  
  /// Load calendar item list data without any filters applied
  Future<void> _loadCalendarItemListDataWithoutFilters() async {
    try {
      final userId = _userDetailStore.userDetail?.id;
      final employeeId = _userDetailStore.userDetail?.employeeId;
      
      if (userId == null || employeeId == null || employeeId == 0) {
        print('TourPlanManagerReviewScreen: userId or employeeId is null/invalid, skipping load');
        return;
      }
      
      print('TourPlanManagerReviewScreen: Loading calendar item list data without filters - EmployeeId: $employeeId, SelectedEmployeeId: $employeeId');
      
      // SelectedEmployeeId must equal employeeId as per API requirement
      await _store.loadCalendarItemListData(
        searchText: null,
        pageNumber: 1,
        pageSize: 1000,
        employeeId: employeeId,
        month: _month.month,
        userId: userId,
        bizunit: 1,
        year: _month.year,
        selectedEmployeeId: employeeId, // SelectedEmployeeId must equal employeeId
        customerId: null,
        status: null,
        sortOrder: 0,
        sortDir: 0,
        sortField: null,
      );
    } catch (e) {
      print('TourPlanManagerReviewScreen: Error loading calendar item list data: $e');
    }
  }

  bool _hasActiveFilters() {
    return _customer != null || _employee != null || _status != null;
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_customer != null) count++;
    if (_status != null) count++;
    if (_employee != null) count++;
    return count;
  }

  int _getFilteredRecordCount() {
    // Use API's filteredRecords count from the list API response
    try {
      final future = _store.fetchCalendarItemListDataFuture;
      if (future.status == FutureStatus.fulfilled && future.value != null) {
        final response = future.value!;
        // Use filteredRecords from API response (this is the count from the API)
        if (response.filteredRecords > 0) {
          return response.filteredRecords;
        }
      }
      // Fallback to local count if API response not available
      return _store.calendarItemListData.length;
    } catch (e) {
      // Fallback to local count if error
      return _store.calendarItemListData.length;
    }
  }

  Future<void> _applyFiltersFromModal() async {
    _closeFilterModal();
    // Force hard refresh - reload data with updated filters
    await Future.wait([
      _loadCalendarViewData(),
      _loadCalendarItemListData(),
      _loadTourPlanEmployeeListSummary(),
    ]);
    // Apply filters after data is loaded
    if (mounted) {
      setState(() {
        _applyFilters();
        _dataVersion++; // Force UI rebuild
      });
    }
  }

  Future<void> _loadCalendarViewData() async {
    try {
      final int? userId = _userDetailStore.userDetail?.userId; // Keep as null if not available
      final managerId = _userDetailStore.userDetail?.id ?? 0;
      
      // Determine EmployeeId and SelectedEmployeeId based on filters
      // If employee filter is selected, use filtered employeeId for both EmployeeId and SelectedEmployeeId
      final int? filteredEmployeeId = (_employee != null && _employee!.isNotEmpty && _employeeNameToId.containsKey(_employee))
          ? _employeeNameToId[_employee!]
          : null;
      
      // Get user's employeeId - ensure it's not null/0
      final int? userEmployeeId = _userDetailStore.userDetail?.employeeId;
      if (userEmployeeId == null || userEmployeeId == 0) {
        print('TourPlanManagerReviewScreen: EmployeeId not available from user store, cannot load calendar view data');
        return;
      }
      
      // Use filtered employeeId if available, otherwise use user's employeeId
      final int finalEmployeeId = filteredEmployeeId ?? userEmployeeId;
      final int finalSelectedEmployeeId = filteredEmployeeId ?? userEmployeeId;
      
      print('TourPlanManagerReviewScreen: Calendar View - EmployeeId: $finalEmployeeId, SelectedEmployeeId: $finalSelectedEmployeeId (filtered: ${filteredEmployeeId != null})');
      
      // SelectedEmployeeId must equal employeeId (filtered if employee filter is applied)
      final request = CalendarViewRequest(
        month: _month.month,
        year: _month.year,
        userId: userId, // null if not available, as per API requirement
        managerId: managerId,
        employeeId: finalEmployeeId, // Use filtered employeeId if employee filter is applied
        selectedEmployeeId: finalSelectedEmployeeId, // Use filtered employeeId if employee filter is applied
      );
      
      await _store.loadCalendarViewData(
        month: request.month,
        year: request.year,
        userId: request.userId, // Pass null directly, not 0
        managerId: request.managerId,
        employeeId: request.employeeId,
        selectedEmployeeId: request.selectedEmployeeId, // Use filtered employeeId if employee filter is applied
      );
      
      // Force UI update after calendar view data is loaded to refresh calendar
      if (mounted) {
        setState(() {
          _dataVersion++; // Increment to force calendar rebuild
        });
      }
    } catch (e) {
      print('TourPlanManagerReviewScreen: Error loading calendar view data: $e');
    }
  }

  Future<void> _loadTourPlanSummary() async {
    try {
      final userId = _userDetailStore.userDetail?.userId ?? 0;
      await _store.loadTourPlanSummary(
        month: _month.month,
        year: _month.year,
        userId: userId,
        bizunit: 1,
      );
    } catch (e) {
      print('TourPlanManagerReviewScreen: Error loading tour plan summary: $e');
    }
  }

  Future<void> _loadManagerSummary() async {
    try {
      final userId = _userDetailStore.userDetail?.userId ?? 0;
      await _store.loadManagerSummary(
        employeeId: userId,
        month: _month.month,
        year: _month.year,
      );
    } catch (e) {
      print('TourPlanManagerReviewScreen: Error loading manager summary: $e');
    }
  }

  Future<void> _loadTourPlanEmployeeListSummary() async {
    try {
      final int employeeId = _getEmployeeIdForApi();
      await _store.loadTourPlanEmployeeListSummary(
        employeeId: employeeId,
        month: _month.month,
        year: _month.year,
      );
    } catch (e) {
      print('TourPlanManagerReviewScreen: Error loading employee list summary: $e');
    }
  }

  Future<void> _loadCalendarItemListData() async {
    try {
      final userId = _userDetailStore.userDetail?.id;
      final employeeId = _userDetailStore.userDetail?.employeeId;
      
      if (userId == null || employeeId == null) {
        print('TourPlanManagerReviewScreen: userId or employeeId is null, skipping load');
        return;
      }
      
      // Determine EmployeeId and SelectedEmployeeId based on filters
      // If employee filter is selected, use filtered employeeId for both EmployeeId and SelectedEmployeeId
      final int? filteredEmployeeId = (_employee != null && _employee!.isNotEmpty && _employeeNameToId.containsKey(_employee))
          ? _employeeNameToId[_employee!]
          : null;
      
      // Ensure employeeId is valid (not null/0)
      if (employeeId == null || employeeId == 0) {
        print('TourPlanManagerReviewScreen: Invalid employeeId ($employeeId), cannot load calendar item list data');
        return;
      }
      
      // Use filtered employeeId if available, otherwise use user's employeeId
      final int finalEmployeeId = filteredEmployeeId ?? employeeId;
      final int finalSelectedEmployeeId = filteredEmployeeId ?? employeeId;
      
      // Get customerId and status from filters
      final int? customerId = (_customer != null && _customer!.isNotEmpty && _customerNameToId.containsKey(_customer))
          ? _customerNameToId[_customer!]
          : null;
      final int? status = (_status != null && _statusNameToId.containsKey(_status))
          ? _statusNameToId[_status!]
          : null;
      
      print('TourPlanManagerReviewScreen: Loading calendar item list data with filters - '
          'EmployeeId: $finalEmployeeId, SelectedEmployeeId: $finalSelectedEmployeeId, '
          'CustomerId: $customerId, Status: $status (statusText: "$_status")');
      
      await _store.loadCalendarItemListData(
        searchText: null,
        pageNumber: 1,
        pageSize: 1000,
        employeeId: finalEmployeeId, // Use filtered employeeId if employee filter is applied
        month: _month.month,
        userId: userId,
        bizunit: 1,
        year: _month.year,
        selectedEmployeeId: finalSelectedEmployeeId, // Use filtered employeeId if employee filter is applied
        customerId: customerId,
        status: status,
        sortOrder: 0,
        sortDir: 0,
        sortField: null,
      );
      
      print('TourPlanManagerReviewScreen: Calendar item list data loaded successfully - ${_store.calendarItemListData.length} items');
      
      // Log status distribution for debugging
      final statusCounts = <int, int>{};
      for (final item in _store.calendarItemListData) {
        statusCounts[item.status] = (statusCounts[item.status] ?? 0) + 1;
      }
      print('TourPlanManagerReviewScreen: Status distribution: $statusCounts');
      
      // Force UI update after data is loaded to refresh the list
      if (mounted) {
        setState(() {
          _dataVersion++; // Force calendar rebuild
        });
      }
      
    } catch (e) {
      print('TourPlanManagerReviewScreen: Error loading calendar item list data: $e');
      // Show error to user
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Error loading tour plans: ${e.toString()}',
          type: ToastType.error,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  Future<void> _getTourPlanStatusList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        final List<CommonDropdownItem> items = await commonRepo.getTourPlanStatusList();
        final names = items.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toSet();
        
        print('TourPlanManagerReviewScreen: Loaded ${items.length} status options from API');
        for (final item in items) {
          print('  - Status: "${item.text.trim()}" (ID: ${item.id})');
        }
        
        if (names.isNotEmpty && mounted) {
          setState(() {
            _statusOptions = {..._statusOptions, ...names}.toList();
            for (final item in items) {
              final String key = item.text.trim();
              if (key.isNotEmpty) {
                _statusNameToId[key] = item.id;
              }
            }
          });
          print('TourPlanManagerReviewScreen: Status mapping created with ${_statusNameToId.length} entries');
        }
      }
    } catch (e) {
      print('TourPlanManagerReviewScreen: Error getting tour plan status list: $e');
    }
  }

  Future<void> _getEmployeeList({int? employeeId}) async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        // If employeeId is not provided, try to get it from user store
        final int? finalEmployeeId = employeeId ?? _userDetailStore.userDetail?.employeeId;
        final List<CommonDropdownItem> items = await commonRepo.getEmployeeList(employeeId: finalEmployeeId);
        final names = items.map((e) => (e.employeeName.isNotEmpty ? e.employeeName : e.text).trim()).where((s) => s.isNotEmpty).toSet();
        
        if (names.isNotEmpty && mounted) {
          setState(() {
            _employeeOptions = {..._employeeOptions, ...names}.toList();
            // map names to ids for potential employee ID mapping
            String? selectedEmployeeName;
            for (final item in items) {
              final String key = (item.employeeName.isNotEmpty ? item.employeeName : item.text).trim();
              if (key.isNotEmpty) {
                _employeeNameToId[key] = item.id;
                // If this employee's id matches the employeeId used in API call, auto-select it
                if (finalEmployeeId != null && item.id == finalEmployeeId) {
                  selectedEmployeeName = key;
                }
              }
            }
            // Auto-select the employee if found (always select if id matches the employeeId used in API)
            if (selectedEmployeeName != null) {
              _employee = selectedEmployeeName;
              print('TourPlanManagerReviewScreen: Auto-selected employee: $selectedEmployeeName (ID: $finalEmployeeId)');
            }
          });
          print('TourPlanManagerReviewScreen: Loaded ${_employeeOptions.length} employees ${finalEmployeeId != null ? "for employeeId: $finalEmployeeId" : ""}');
        }
      }
    } catch (e) {
      print('TourPlanManagerReviewScreen: Error getting employee list: $e');
    }
  }

  Future<void> _loadMappedCustomersByEmployeeId() async {
    try {
      final int? employeeId = _userDetailStore.userDetail?.employeeId;
      if (employeeId == null || employeeId == 0) {
        print('TourPlanManagerReviewScreen: Employee ID is null or 0, skipping customer load');
        return;
      }

      if (getIt.isRegistered<TourPlanRepository>()) {
        final repo = getIt<TourPlanRepository>();
        final request = GetMappedCustomersByEmployeeIdRequest(
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
          id: employeeId, // Pass employeeId as Id
          action: null,
          comment: null,
          status: null,
          tourPlanAcceptId: null,
          remarks: null,
          selectedEmployeeId: null,
          date: null,
        );

        final response = await repo.getMappedCustomersByEmployeeId(request);
        
        if (response.customers.isNotEmpty) {
          final names = response.customers
              .map((e) => e.customerName.trim())
              .where((s) => s.isNotEmpty)
              .toSet();
          
          if (names.isNotEmpty) {
            setState(() {
              _customerOptions = names.toList()..sort();
              _customerNameToId.clear();
              for (final customer in response.customers) {
                final String key = customer.customerName.trim();
                if (key.isNotEmpty) {
                  _customerNameToId[key] = customer.customerId;
                }
              }
            });
            print('TourPlanManagerReviewScreen: Loaded ${_customerOptions.length} customers for employee $employeeId');
          }
        } else {
          print('TourPlanManagerReviewScreen: No customers found for employee $employeeId');
        }
      }
    } catch (e) {
      print('TourPlanManagerReviewScreen: Error loading mapped customers by employee ID: $e');
    }
  }

  int _getEmployeeIdForApi() {
    if (_employee != null && _employeeNameToId.containsKey(_employee)) {
      return _employeeNameToId[_employee!]!;
    }
    
    final userEmployeeId = _userDetailStore.userDetail?.employeeId;
    return userEmployeeId ?? 0;
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 5:
        return const Color(0xFF2DBE64); // Approved - Green
      case 4:
        return Colors.orange; // Sent Back - Orange
      case 3:
        return Colors.redAccent; // Rejected - Red
      case 2:
      case 1:
        return const Color(0xFFFFA41C); // Pending / Submitted - Yellow
      default:
        return Colors.grey;
    }
  }
  
  /// Get status background color based on status value
  Color _getStatusBackgroundColor(int status) {
    switch (status) {
      case 5:
        return const Color(0xFF2DBE64).withOpacity(0.15); // Approved - Green
      case 4:
        return Colors.orange.withOpacity(0.15); // Sent Back - Orange
      case 3:
        return Colors.redAccent.withOpacity(0.15); // Rejected - Red
      case 2:
      case 1:
        return const Color(0xFFFFA41C).withOpacity(0.15); // Pending / Submitted - Yellow
      default:
        return Colors.grey.withOpacity(0.15);
    }
  }

  /// Get status display text from item, using tourPlanStatus field or deriving from status field
  String _getStatusDisplayText(TourPlanItem item) {
    // First try tourPlanStatus field (this is the actual status text from API)
    if (item.tourPlanStatus != null && item.tourPlanStatus!.trim().isNotEmpty) {
      return item.tourPlanStatus!.trim();
    }
    
    // Fallback to statusText if tourPlanStatus is not available
    if (item.statusText != null && item.statusText!.trim().isNotEmpty) {
      return item.statusText!.trim();
    }
    
    // Derive from status field (primary status value)
    // Status IDs: 5=Approved, 4=Sent Back, 3=Rejected, 2=Submitted, 1=Pending, 0=Draft
    final statusId = item.status != 0 ? item.status : item.statusId;
    
    switch (statusId) {
      case 5:
        return 'Approved';
      case 4:
        return 'Sent Back';
      case 3:
        return 'Rejected';
      case 2:
        return 'Submitted';
      case 1:
        return 'Pending';
      case 0:
        return 'Draft';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  List<CalendarLegendItem> _buildLegendItems() {
    if (_store.employeeListSummaryData != null) {
      final data = _store.employeeListSummaryData!;
      return [
        CalendarLegendItem(
          label: 'Total Employee', 
          color: const Color(0xFF1976D2), 
          count: data.totalEmployees
        ),
        CalendarLegendItem(
          label: 'Approved', 
          color: const Color(0xFF2DBE64), 
          count: data.totalApproved
        ),
        CalendarLegendItem(
          label: 'Send Back', 
          color: Colors.redAccent, 
          count: data.totalSentBack
        ),
        CalendarLegendItem(
          label: 'Planned', 
          color: const Color(0xFF2B78FF), 
          count: data.totalPlanned
        ),
        CalendarLegendItem(
          label: 'Pending', 
          color: const Color(0xFFFFA41C), 
          count: data.totalPending
        ),
        CalendarLegendItem(
          label: 'Not Entered', 
          color: Colors.grey, 
          count: data.totalNotEntered
        ),
        CalendarLegendItem(
          label: 'Leave', 
          color: Colors.purple, 
          count: data.totalLeave
        ),
      ];
    } else {
      return const [
        CalendarLegendItem(label: 'Total Employee', color: Color(0xFF1976D2), count: 0),
        CalendarLegendItem(label: 'Approved', color: Color(0xFF2DBE64), count: 0),
        CalendarLegendItem(label: 'Send Back', color: Colors.redAccent, count: 0),
        CalendarLegendItem(label: 'Planned', color: Color(0xFF2B78FF), count: 0),
        CalendarLegendItem(label: 'Pending', color: Color(0xFFFFA41C), count: 0),
        CalendarLegendItem(label: 'Not Entered', color: Colors.grey, count: 0),
        CalendarLegendItem(label: 'Leave', color: Colors.purple, count: 0),
      ];
    }
  }

  String _daysAndHolidaysLabel(DateTime date) {
    final days = _daysInMonth(date);
    final holidays = _countWeekendDays(date);
    return 'Days: $days  |  Holidays: $holidays';
  }

  int _daysInMonth(DateTime date) {
    final firstDayThisMonth = DateTime(date.year, date.month, 1);
    final firstDayNextMonth = DateTime(date.year, date.month + 1, 1);
    return firstDayNextMonth.difference(firstDayThisMonth).inDays;
  }

  int _countWeekendDays(DateTime date) {
    final totalDays = _daysInMonth(date);
    int weekends = 0;
    for (int d = 1; d <= totalDays; d++) {
      final weekday = DateTime(date.year, date.month, d).weekday;
      if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
        weekends++;
      }
    }
    return weekends;
  }

  Widget _buildSummaryChipsRow(TourPlanGetEmployeeListSummaryResponse data) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSummaryChip('Total Employee', data.totalEmployees, const Color(0xFF1976D2)),
          const SizedBox(width: 12),
          _buildSummaryChip('Approved', data.totalApproved, const Color(0xFF2DBE64)),
          const SizedBox(width: 12),
          _buildSummaryChip('Send Back', data.totalSentBack, Colors.redAccent),
          const SizedBox(width: 12),
          _buildSummaryChip('Planned', data.totalPlanned, const Color(0xFF2B78FF)),
          const SizedBox(width: 12),
          _buildSummaryChip('Pending', data.totalPending, const Color(0xFFFFA41C)),
          const SizedBox(width: 12),
          _buildSummaryChip('Not Entered', data.totalNotEntered, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildSummaryChipsRowEmpty() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSummaryChip('Total Employee', 0, const Color(0xFF1976D2)),
          const SizedBox(width: 12),
          _buildSummaryChip('Approved', 0, const Color(0xFF2DBE64)),
          const SizedBox(width: 12),
          _buildSummaryChip('Send Back', 0, Colors.redAccent),
          const SizedBox(width: 12),
          _buildSummaryChip('Planned', 0, const Color(0xFF2B78FF)),
          const SizedBox(width: 12),
          _buildSummaryChip('Pending', 0, const Color(0xFFFFA41C)),
          const SizedBox(width: 12),
          _buildSummaryChip('Not Entered', 0, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count calls',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Build Filter Modal (DCR style)
  Widget _buildFilterModal({required bool isMobile, required bool isTablet, required Color tealGreen}) {
    String? _tempCustomer = _customer;
    String? _tempStatus = _status;
    String? _tempEmployee = _employee;
    
    return GestureDetector(
      onTap: _closeFilterModal,
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(_filterModalAnimation ?? const AlwaysStoppedAnimation(0.0)),
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping inside modal
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Modal Header
                        Container(
                          padding: EdgeInsets.all(isMobile ? 16 : 20),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Filters',
                                style: GoogleFonts.inter(
                                  fontSize: isMobile ? 18 : 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.grey[900],
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: _closeFilterModal,
                                icon: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Modal Content
                        Flexible(
                          child: SingleChildScrollView(
                            controller: _filterScrollController,
                            padding: EdgeInsets.fromLTRB(
                              isMobile ? 16 : 20,
                              isMobile ? 16 : 20,
                              isMobile ? 16 : 20,
                              MediaQuery.of(context).viewInsets.bottom + (isMobile ? 16 : 20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Customer Filter - Searchable Dropdown
                                _SearchableFilterDropdown(
                                  key: _customerFilterSectionKey,
                                  title: 'Customer',
                                  icon: Icons.person_outline,
                                  selectedValue: _tempCustomer,
                                  options: _customerOptions,
                                  onChanged: (value) {
                                    setModalState(() {
                                      _tempCustomer = value;
                                    });
                                  },
                                  isTablet: isTablet,
                                  onExpanded: () => _scrollFilterSectionIntoView(_customerFilterSectionKey),
                                ),
                                SizedBox(height: isTablet ? 24 : 20),
                                // Status Filter - Searchable Dropdown
                                _SearchableFilterDropdown(
                                  key: _statusFilterSectionKey,
                                  title: 'Status',
                                  icon: Icons.verified_outlined,
                                  selectedValue: _tempStatus,
                                  options: _statusOptions.isNotEmpty ? _statusOptions : const ['Draft', 'Pending', 'Approved', 'Rejected'],
                                  onChanged: (value) {
                                    setModalState(() {
                                      _tempStatus = value;
                                    });
                                  },
                                  isTablet: isTablet,
                                  onExpanded: () => _scrollFilterSectionIntoView(_statusFilterSectionKey),
                                ),
                                SizedBox(height: isTablet ? 24 : 20),
                                // Employee Filter - Searchable Dropdown
                                _SearchableFilterDropdown(
                                  key: _employeeFilterSectionKey,
                                  title: 'Employee',
                                  icon: Icons.badge_outlined,
                                  selectedValue: _tempEmployee,
                                  options: _employeeOptions,
                                  onChanged: (value) {
                                    setModalState(() {
                                      _tempEmployee = value;
                                    });
                                  },
                                  isTablet: isTablet,
                                  onExpanded: () => _scrollFilterSectionIntoView(_employeeFilterSectionKey),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Modal Footer Buttons
                        Container(
                          padding: EdgeInsets.all(isMobile ? 16 : 20),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Colors.grey.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setModalState(() {
                                      _tempCustomer = null;
                                      _tempStatus = null;
                                      _tempEmployee = null;
                                    });
                                    _clearAllFilters();
                                    _closeFilterModal();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: BorderSide(color: tealGreen, width: 1.5),
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
                                    setState(() {
                                      _customer = _tempCustomer;
                                      _status = _tempStatus;
                                      _employee = _tempEmployee;
                                    });
                                    _applyFiltersFromModal();
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: tealGreen,
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
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

// Helper widgets
// Bottom action bar widget - matching DCR manager review style
class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.selectedCount,
    required this.onApprove,
    required this.onSendBack,
    required this.onClear,
    required this.canApprove,
    required this.canSendBack,
  });
  
  final int selectedCount;
  final VoidCallback onApprove;
  final VoidCallback onSendBack;
  final VoidCallback onClear;
  final bool canApprove;
  final bool canSendBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F7), // Light blue-green background
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16, 
                vertical: isMobile ? 10 : 12
              ),
              child: isMobile
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Selection count and X button in same row
                        Row(
                          children: [
                            // Checkmark icon on left
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4db1b3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Selection count text
                            Expanded(
                              child: Text(
                                '$selectedCount plan(s) selected',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4db1b3),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            // Clear Selection text and X button on right
                            InkWell(
                              onTap: onClear,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.close, color: Color(0xFF4db1b3), size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Clear Selection',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF4db1b3),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Action buttons - properly aligned with no text wrapping
                        Row(
                          children: [
                            Expanded(
                              child: _FloatingActionButton(
                                label: 'Approve',
                                icon: Icons.check_circle,
                                color: Colors.green,
                                onPressed: onApprove,
                                isMobile: true,
                                isEnabled: canApprove,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _FloatingActionButton(
                                label: 'Send Back',
                                icon: Icons.undo,
                                color: Colors.orange,
                                onPressed: onSendBack,
                                isMobile: true,
                                isEnabled: canSendBack,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Selection count and X button in same row
                        Row(
                          children: [
                            // Checkmark icon on left
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4db1b3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Selection count text
                            Expanded(
                              child: Text(
                                '$selectedCount plan(s) selected',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4db1b3),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            // Clear Selection text and X button on right
                            InkWell(
                              onTap: onClear,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.close, color: Color(0xFF4db1b3), size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Clear Selection',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF4db1b3),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Action buttons - properly aligned with no text wrapping
                        Row(
                          children: [
                            Expanded(
                              child: _FloatingActionButton(
                                label: 'Approve',
                                icon: Icons.check_circle,
                                color: Colors.green,
                                onPressed: onApprove,
                                isMobile: false,
                                isEnabled: canApprove,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _FloatingActionButton(
                                label: 'Send Back',
                                icon: Icons.undo,
                                color: Colors.orange,
                                onPressed: onSendBack,
                                isMobile: false,
                                isEnabled: canSendBack,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
        ),
      ),
        );
      },
    );
  }
}

// Helper widget for floating action buttons - matching DCR manager review style
class _FloatingActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool isMobile;
  final bool isEnabled;

  const _FloatingActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
    this.isMobile = false,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: isEnabled ? onPressed : null,
        icon: Icon(icon, size: isMobile ? 14 : 16),
        label: Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 12 : 14,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          softWrap: false,
        ),
        style: FilledButton.styleFrom(
          backgroundColor: isEnabled ? color : Colors.grey,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          minimumSize: Size(0, isMobile ? 42 : 48),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 12,
            vertical: isMobile ? 12 : 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
          ),
          elevation: isEnabled ? 2 : 0,
        ),
      ),
    );
  }
}

// Include the same helper classes from the original file
class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.icon, required this.label, this.onTap, this.onLongPress});
  final IconData icon; 
  final String label; 
  final VoidCallback? onTap; 
  final VoidCallback? onLongPress;
  
  @override
  Widget build(BuildContext context) {
    final Color border = Theme.of(context).dividerColor.withValues(alpha: 0.25);
    return Material(
      color: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: border)),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _pickFromList(BuildContext context, {required String title, required List<String> options, String? selected, bool searchable = false}) async {
  // If searchable is true or options list is large, use searchable version
  final bool useSearch = searchable || options.length > 10;
  
  if (useSearch) {
    return _pickFromListSearchable(context, title: title, options: options, selected: selected);
  }
  
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemBuilder: (c, i) => ListTile(
                title: Text(options[i]),
                trailing: options[i] == selected ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () => Navigator.pop(ctx, options[i]),
              ),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: options.length,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _pickFromListSearchable(BuildContext context, {required String title, required List<String> options, String? selected}) async {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _SearchableListBottomSheet(
      title: title,
      options: options,
      selected: selected,
    ),
  );
}

class _SearchableListBottomSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? selected;

  const _SearchableListBottomSheet({
    required this.title,
    required this.options,
    this.selected,
  });

  @override
  State<_SearchableListBottomSheet> createState() => _SearchableListBottomSheetState();
}

class _SearchableListBottomSheetState extends State<_SearchableListBottomSheet> {
  late List<String> _filteredOptions;
  late TextEditingController _searchController;
  final FocusNode _searchFocusNode = FocusNode();
  bool _hasEnsuredUnfocused = false;

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    // Ensure search field is not focused when bottom sheet opens (only once)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasEnsuredUnfocused) {
        _searchFocusNode.unfocus();
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
        _hasEnsuredUnfocused = true;
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredOptions = widget.options;
      } else {
        _filteredOptions = widget.options.where((option) =>
          option.toLowerCase().contains(query)
        ).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, child) {
                  return TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: value.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onTap: () {
                      // Request focus when user explicitly taps on search field
                      _searchFocusNode.requestFocus();
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _filteredOptions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'No results found',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      itemBuilder: (c, i) => ListTile(
                        title: Text(_filteredOptions[i]),
                        trailing: _filteredOptions[i] == widget.selected
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () => Navigator.pop(context, _filteredOptions[i]),
                      ),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemCount: _filteredOptions.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Filter Icon Button Widget
class _FilterIconButton extends StatelessWidget {
  final int filterCount;
  final VoidCallback onTap;
  final bool isTablet;
  
  static const Color tealGreen = Color(0xFF4db1b3);
  
  const _FilterIconButton({
    required this.filterCount,
    required this.onTap,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: isTablet ? 56 : 48,
          height: isTablet ? 56 : 48,
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  Icons.filter_alt,
                  color: tealGreen,
                  size: isTablet ? 28 : 24,
                ),
              ),
              if (filterCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: EdgeInsets.all(isTablet ? 4 : 3),
                    decoration: BoxDecoration(
                      color: tealGreen,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    constraints: BoxConstraints(
                      minWidth: isTablet ? 20 : 18,
                      minHeight: isTablet ? 20 : 18,
                    ),
                    child: Center(
                      child: Text(
                        filterCount.toString(),
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 10 : 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
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
}

// Searchable Filter Dropdown Widget
class _SearchableFilterDropdown extends StatefulWidget {
  final String title;
  final IconData icon;
  final String? selectedValue;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool isTablet;
  final VoidCallback? onExpanded;
  
  static const Color tealGreen = Color(0xFF4db1b3);
  
  const _SearchableFilterDropdown({
    super.key,
    required this.title,
    required this.icon,
    required this.selectedValue,
    required this.options,
    required this.onChanged,
    required this.isTablet,
    this.onExpanded,
  });

  @override
  State<_SearchableFilterDropdown> createState() => _SearchableFilterDropdownState();
}

class _SearchableFilterDropdownState extends State<_SearchableFilterDropdown> {
  late TextEditingController _searchController;
  late List<String> _filteredOptions;
  bool _isExpanded = false;
  
  static const Color tealGreen = Color(0xFF4db1b3);
  
  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredOptions = widget.options;
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
      _filteredOptions = widget.options
          .where((option) => option.toLowerCase().contains(query))
          .toList();
    });
  }
  
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (!_isExpanded) {
        _searchController.clear();
        _filteredOptions = widget.options;
      }
    });
    if (_isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onExpanded?.call();
      });
    }
  }
  
  void _selectOption(String? option) {
    widget.onChanged(option);
    setState(() {
      _isExpanded = false;
      _searchController.clear();
      _filteredOptions = widget.options;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              widget.icon,
              size: widget.isTablet ? 18 : 16,
              color: tealGreen,
            ),
            SizedBox(width: widget.isTablet ? 10 : 8),
            Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: widget.isTablet ? 16 : 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey[900],
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        SizedBox(height: widget.isTablet ? 14 : 12),
        // Selected Value Display / Dropdown Trigger
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: EdgeInsets.all(widget.isTablet ? 14 : 12),
              decoration: BoxDecoration(
                color: widget.selectedValue != null
                    ? tealGreen.withOpacity(0.1)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.selectedValue != null
                      ? tealGreen.withOpacity(0.3)
                      : Colors.grey[200]!,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.selectedValue ?? 'Select ${widget.title}',
                      style: GoogleFonts.inter(
                        fontSize: widget.isTablet ? 14 : 13,
                        fontWeight: widget.selectedValue != null
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: widget.selectedValue != null
                            ? tealGreen
                            : Colors.grey[600],
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  if (widget.selectedValue != null)
                    Padding(
                      padding: EdgeInsets.only(right: widget.isTablet ? 8 : 6),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _selectOption(null),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: widget.isTablet ? 16 : 14,
                              color: tealGreen,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: widget.isTablet ? 20 : 18,
                    color: tealGreen,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Expanded Dropdown with Search
        if (_isExpanded)
          Container(
            margin: EdgeInsets.only(top: widget.isTablet ? 12 : 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: tealGreen.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: BoxConstraints(
              maxHeight: widget.isTablet ? 400 : 350,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search Field
                Padding(
                  padding: EdgeInsets.all(widget.isTablet ? 12 : 10),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, child) {
                      return TextField(
                        controller: _searchController,
                        autofocus: false,
                        style: GoogleFonts.inter(
                          fontSize: widget.isTablet ? 14 : 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[900],
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search ${widget.title.toLowerCase()}...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: widget.isTablet ? 14 : 13,
                            color: Colors.grey[400],
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Colors.grey[500],
                            size: widget.isTablet ? 20 : 18,
                          ),
                          suffixIcon: value.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    size: widget.isTablet ? 18 : 16,
                                    color: Colors.grey[500],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey[200]!,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.grey[200]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: tealGreen,
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                        horizontal: widget.isTablet ? 14 : 12,
                        vertical: widget.isTablet ? 12 : 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Options List
                Flexible(
                  child: _filteredOptions.isEmpty
                      ? Padding(
                          padding: EdgeInsets.all(widget.isTablet ? 20 : 18),
                          child: Text(
                            'No results found',
                            style: GoogleFonts.inter(
                              fontSize: widget.isTablet ? 13 : 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.isTablet ? 12 : 10,
                            vertical: widget.isTablet ? 8 : 6,
                          ),
                          itemCount: _filteredOptions.length,
                          separatorBuilder: (_, __) => SizedBox(height: widget.isTablet ? 6 : 4),
                          itemBuilder: (context, index) {
                            final option = _filteredOptions[index];
                            final isSelected = widget.selectedValue == option;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _selectOption(option),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: EdgeInsets.all(widget.isTablet ? 12 : 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? tealGreen.withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(
                                            color: tealGreen.withOpacity(0.3),
                                            width: 1,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: widget.isTablet ? 18 : 16,
                                        height: widget.isTablet ? 18 : 16,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? tealGreen
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isSelected
                                                ? tealGreen
                                                : Colors.grey[400]!,
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? Icon(
                                                Icons.check_rounded,
                                                size: widget.isTablet ? 12 : 11,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                      SizedBox(width: widget.isTablet ? 12 : 10),
                                      Expanded(
                                        child: Text(
                                          option,
                                          style: GoogleFonts.inter(
                                            fontSize: widget.isTablet ? 14 : 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? tealGreen
                                                : Colors.grey[700],
                                            letterSpacing: -0.1,
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
              ],
            ),
          ),
      ],
    );
  }
}

// Enhanced UI Components - Same as DCR Deviation UI
class _EnhancedActionPill extends StatelessWidget {
  const _EnhancedActionPill({
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color backgroundColor = isActive ? Colors.blue.shade50 : Colors.white;
    final Color iconColor = isActive ? Colors.blue.shade600 : theme.colorScheme.primary;
    final Color textColor = isActive ? Colors.blue.shade700 : Colors.grey.shade700;
    final Color borderColor = isActive ? Colors.blue.shade200 : Colors.grey.shade200;
    
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      elevation: isActive ? 3 : 2,
      shadowColor: isActive ? Colors.blue.withOpacity(0.2) : Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: textColor,
                    fontSize: 13, // Slightly smaller for better mobile fit
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                size: 14,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearFiltersButton extends StatelessWidget {
  const _ClearFiltersButton({
    required this.onPressed,
    this.isActive = false,
  });
  
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color backgroundColor = isActive ? Colors.red.shade50 : Colors.grey.shade100;
    final Color iconColor = isActive ? Colors.red.shade600 : Colors.grey.shade600;
    final Color textColor = isActive ? Colors.red.shade700 : Colors.grey.shade600;
    
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isActive ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isActive ? Border.all(color: Colors.red.shade200) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_off,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Clear',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: textColor,
                  fontSize: 13, // Slightly smaller for better mobile fit
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
