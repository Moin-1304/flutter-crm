import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:convert';
import 'package:boilerplate/core/widgets/month_calendar.dart';
import 'package:boilerplate/presentation/tour_plan/new_tour_plan_screen.dart';
import 'package:boilerplate/presentation/crm/tour_plan/widgets/status_summary.dart';
import 'package:boilerplate/presentation/crm/dcr/dcr_entry_screen.dart';
import 'package:boilerplate/domain/entity/dcr/dcr.dart' as dcr;
import 'package:boilerplate/domain/entity/tour_plan/tour_plan.dart' as domain;
import 'package:boilerplate/presentation/crm/tour_plan/mock/mock_tour_plan.dart';
import 'package:boilerplate/presentation/crm/tour_plan/store/tour_plan_store.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/presentation/user/store/user_validation_store.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/presentation/login/store/login_store.dart' as login;
import 'package:boilerplate/di/service_locator.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/repository/tour_plan/tour_plan_repository.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/presentation/crm/tour_plan/tour_plan_manager_review_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

import '../../data/network/apis/user/lib/domain/entity/tour_plan/calendar_view_data.dart';
import '../../data/network/apis/user/lib/domain/entity/tour_plan/tour_plan_api_models.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';

void main() {
  runApp(const MaterialApp(home: TourPlanScreen()));
}

class TourPlanScreen extends StatefulWidget {
  const TourPlanScreen({super.key});

  @override
  State<TourPlanScreen> createState() => _TourPlanScreenState();
}

class _TourPlanScreenState extends State<TourPlanScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  String? _customer;
  String? _employee;
  String? _status; // Draft/Pending/Approved/Rejected
  final bool _isManager = false; // toggle when wiring roles
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDay; // No initial selection - shows all items
  List<domain.TourPlanEntry> _allEntries = <domain.TourPlanEntry>[];
  List<domain.TourPlanEntry> _entries = <domain.TourPlanEntry>[];
  late final TourPlanStore _store;
  late final UserDetailStore _userDetailStore;
  int _dataVersion = 0; // bump to force calendar rebuilds when data changes

  // Customer options loaded from API
  List<String> _customerOptions = [];
  final Map<String, int> _customerNameToId = {};

  // Status options loaded from API
  List<String> _statusOptions = [];
  final Map<String, int> _statusNameToId = {};

  // Employee options loaded from API
  List<String> _employeeOptions = [];
  final Map<String, int> _employeeNameToId = {};
  // Auto-refresh support (reference: DCR list)
  Timer? _autoRefreshTimer;
  bool _isAppInForeground = true;
  bool _isRefreshing = false;

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

    // Listen to user detail changes to rebuild when roleCategory changes
    _userDetailStore.addListener(_onUserDetailChanged);

    // Load initial data from API only (no mock)
    _refreshAll();
    _getTourPlanStatusList(); // Load status list for filter
    _loadMappedCustomersByEmployeeId(); // Load customer list using API
    _getEmployeeList(); // Load employee list for filter
    // Auto-refresh disabled - removed periodic API calls

    // Validate user when screen opens
    _validateUserOnScreenOpen();
  }

  /// Validate user when Tour Plan screen opens
  Future<void> _validateUserOnScreenOpen() async {
    try {
      if (getIt.isRegistered<UserValidationStore>()) {
        final validationStore = getIt<UserValidationStore>();
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        if (user != null && (user.userId != null || user.id != null)) {
          final userId = user.userId ?? user.id;
          print(
              '📱 [TourPlanScreen] Validating user on screen open - userId: $userId');
          await validationStore.validateUser(userId!);
        } else {
          print('⚠️ [TourPlanScreen] User not available for validation');
        }
      }
    } catch (e) {
      print('❌ [TourPlanScreen] Error validating user: $e');
    }
  }

  void _openFilterModal() {
    if (_filterModalController == null) return;
    if (!_filterModalController!.isAnimating) {
      setState(() {
        _showFilterModal = true;
      });
      _filterModalController!.forward();
    }
  }

  void _closeFilterModal() {
    if (_filterModalController == null) return;
    if (_filterModalController!.isAnimating || _showFilterModal) {
      _filterModalController!.reverse().then((_) {
        if (mounted) {
          setState(() {
            _showFilterModal = false;
          });
        }
      });
    }
  }

  void _applyFiltersFromModal() {
    _closeFilterModal();
    setState(() {
      _dataVersion++;
    });
    Future.wait([
      _loadCalendarViewData(),
      _loadCalendarItemListData(),
      if (_employee != null) _loadTourPlanEmployeeListSummary(),
    ]).then((_) {
      if (mounted) {
        setState(() {
          _applyFilters();
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
      final RenderAbstractViewport? viewport =
          RenderAbstractViewport.of(renderObject);
      if (viewport == null) return;
      final double target =
          viewport.getOffsetToReveal(renderObject, 0.05).offset;
      final position = _filterScrollController.position;
      final double clamped =
          target.clamp(position.minScrollExtent, position.maxScrollExtent);
      _filterScrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onUserDetailChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userDetailStore.removeListener(_onUserDetailChanged);
    _autoRefreshTimer?.cancel();
    _filterModalController?.dispose();
    _filterScrollController.dispose();
    super.dispose();
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
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      // Load all data in parallel for faster response
      await Future.wait([
        _loadCalendarViewData(),
        _loadTourPlanEmployeeListSummary(),
        _loadCalendarItemListData(),
        _loadTourPlanSummary(),
        _loadAggregateCountSummary(),
        _loadManagerSummary(), // Manager summary if applicable (safe to call regardless)
      ]);
    } finally {
      _isRefreshing = false;
      if (mounted) {
        setState(() {
          _dataVersion++; // trigger rebuild of consumers with ValueKey
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

  // Modern teal-green color matching login screen
  static const Color tealGreen = Color(0xFF4db1b3);

  @override
  Widget build(BuildContext context) {
    // Check if Manager Review tab should be hidden
    final shouldHideManagerReview =
        _userDetailStore.userDetail?.roleCategory == 3;
    final tabLength = shouldHideManagerReview ? 1 : 2;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Stack(
      children: [
        DefaultTabController(
          length: tabLength,
          child: Scaffold(
            backgroundColor: Colors.grey[50],
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 0,
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(isTablet ? 56 : 52),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                  ),
                  child: TabBar(
                    isScrollable: false,
                    labelColor: tealGreen,
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: tealGreen,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: GoogleFonts.inter(
                      fontSize: isTablet ? 16 : 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    unselectedLabelStyle: GoogleFonts.inter(
                      fontSize: isTablet ? 16 : 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    tabs: shouldHideManagerReview
                        ? [
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.route_outlined,
                                      size: isTablet ? 20 : 18),
                                  SizedBox(width: isTablet ? 8 : 6),
                                  const Text('My Tour Plan'),
                                ],
                              ),
                            ),
                          ]
                        : [
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.route_outlined,
                                      size: isTablet ? 20 : 18),
                                  SizedBox(width: isTablet ? 8 : 6),
                                  const Text('My Tour Plan'),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.verified_user_outlined,
                                      size: isTablet ? 20 : 18),
                                  SizedBox(width: isTablet ? 8 : 6),
                                  const Text('Manager Review'),
                                ],
                              ),
                            ),
                          ],
                  ),
                ),
              ),
            ),
            body: TabBarView(
              children: shouldHideManagerReview
                  ? [
                      // My Tour Plan Tab only
                      _buildMyDCRTab(),
                    ]
                  : [
                      // My Tour Plan Tab
                      _buildMyDCRTab(),
                      // Manager Review Tab
                      const TourPlanManagerReviewScreen(),
                    ],
            ),
          ),
        ),
        // Filter Modal
        if (_showFilterModal)
          _buildFilterModal(
              isMobile: !isTablet, isTablet: isTablet, tealGreen: tealGreen),
      ],
    );
  }

  Widget _buildMyDCRTab() {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final double actionHeight = isTablet ? 54 : 48;

    return SafeArea(
      child: Container(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 20 : 16,
            vertical: isTablet ? 20 : 16,
          ),
          child: RefreshIndicator(
            onRefresh: _refreshAll,
            edgeOffset: 12,
            displacement: 36,
            color: tealGreen,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                  bottom: 24 + MediaQuery.of(context).padding.bottom),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'My Tour Plan',
                                    style: GoogleFonts.inter(
                                      fontSize: isTablet ? 20 : 18,
                                      fontWeight: FontWeight.normal,
                                      color: Colors.grey[900],
                                      letterSpacing: -0.8,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: isTablet ? 6 : 4),
                                  Text(
                                    'Today\'s Plans',
                                    style: GoogleFonts.inter(
                                      fontSize: isTablet ? 14 : 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Filter Icon Button with Badge
                            _FilterIconButton(
                              filterCount: _getActiveFilterCount(),
                              onTap: _openFilterModal,
                              isTablet: isTablet,
                            ),
                          ],
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        // Action Buttons Row - New Plan and Filter Count in one row (50% 50%)
                        Row(
                          children: [
                            // New Plan Button - 50% width
                            Expanded(
                              child: SizedBox(
                                height: actionHeight,
                                child: getIt.isRegistered<UserValidationStore>()
                                    ? ListenableBuilder(
                                        listenable:
                                            getIt<UserValidationStore>(),
                                        builder: (context, _) {
                                          final validationStore =
                                              getIt<UserValidationStore>();
                                          final isEnabled =
                                              validationStore.canCreateTourPlan;
                                          return FilledButton.icon(
                                            onPressed: isEnabled
                                                ? () async {
                                                    final result =
                                                        await Navigator.of(
                                                                context)
                                                            .push(
                                                      MaterialPageRoute(
                                                          builder: (_) =>
                                                              const NewTourPlanScreen()),
                                                    );
                                                    if (result == true &&
                                                        mounted) {
                                                      await _refreshAllWithLoader();
                                                    }
                                                  }
                                                : null,
                                            icon: Icon(Icons.add_rounded,
                                                size: isTablet ? 20 : 18),
                                            label: Text(
                                              'New Plan',
                                              style: GoogleFonts.inter(
                                                fontSize: isTablet ? 16 : 15,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: isEnabled
                                                  ? tealGreen
                                                  : Colors.grey,
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor:
                                                  Colors.grey.shade300,
                                              disabledForegroundColor:
                                                  Colors.grey.shade600,
                                              elevation: isEnabled ? 4 : 0,
                                              shadowColor: isEnabled
                                                  ? tealGreen.withOpacity(0.4)
                                                  : Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isTablet ? 20 : 16,
                                              ),
                                              minimumSize:
                                                  Size.fromHeight(actionHeight),
                                            ),
                                          );
                                        },
                                      )
                                    : FilledButton.icon(
                                        onPressed: () async {
                                          final result =
                                              await Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const NewTourPlanScreen()),
                                          );
                                          if (result == true && mounted) {
                                            await _refreshAllWithLoader();
                                          }
                                        },
                                        icon: Icon(Icons.add_rounded,
                                            size: isTablet ? 20 : 18),
                                        label: Text(
                                          'New Plan',
                                          style: GoogleFonts.inter(
                                            fontSize: isTablet ? 16 : 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: tealGreen,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isTablet ? 20 : 16,
                                          ),
                                          minimumSize:
                                              Size.fromHeight(actionHeight),
                                        ),
                                      ),
                              ),
                            ),
                            // Spacing between buttons
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
                  const SizedBox(height: 12),
                  // Calendar with API loading indicator
                  Observer(
                    builder: (_) {
                      return Card(
                        margin: EdgeInsets.zero,
                        color: Colors.white,
                        surfaceTintColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                          side:
                              BorderSide(color: Colors.black.withOpacity(.06)),
                        ),
                        elevation: 12,
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12),
                              child: Observer(
                                builder: (_) {
                                  // Rebuild decorations when calendar view data changes or filters change
                                  final Map<DateTime, CalendarDayDecoration>
                                      decorations = _buildApiDayDecorations(
                                          _store.calendarViewData);
                                  final bool isLoading = _store.calendarLoading;
                                  return LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Stack(
                                        children: [
                                          MonthCalendar(
                                            width: constraints.maxWidth,
                                            key: ValueKey(
                                                'month-cal-$_dataVersion-${_employee}-${_customer}-${_status}'),
                                            visibleMonth: _month,
                                            selectedDate: _selectedDay,
                                            onDateTap: (d) {
                                              setState(() {
                                                // Toggle selection: if same date is tapped again, deselect it
                                                _selectedDay = _selectedDay !=
                                                            null &&
                                                        _isSameDate(
                                                            _selectedDay!, d)
                                                    ? null
                                                    : d;
                                              });
                                              // No need to reload data - filtering is handled in the UI
                                            },
                                            onMonthChanged: (m) async {
                                              setState(() {
                                                _month = DateTime(
                                                    m.year, m.month, 1);
                                                _selectedDay =
                                                    null; // Clear selection when month changes
                                                _store.month = _month;
                                              });

                                              // Call API when month changes
                                              await _loadCalendarViewData();
                                              await _loadCalendarItemListData();
                                              await _loadTourPlanEmployeeListSummary();
                                              await _loadTourPlanSummary();

                                              // Force UI update after all data is loaded
                                              if (mounted) {
                                                setState(() {});
                                              }
                                            },
                                            summaryText:
                                                _daysAndHolidaysLabel(_month),
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
                                                  color: Colors.white
                                                      .withOpacity(0.8),
                                                  borderRadius:
                                                      BorderRadius.circular(28),
                                                ),
                                                child: Center(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      CircularProgressIndicator(
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                    Color>(
                                                                tealGreen),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      const Text(
                                                          'Loading calendar...'),
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
                  // Day plans list with quick edit (only show when a date is selected)
                  Builder(builder: (context) {
                    if (_selectedDay == null) return const SizedBox.shrink();
                    final items = _entries
                        .where((e) => _isSameDate(e.date, _selectedDay!))
                        .toList();
                    if (items.isEmpty) return const SizedBox.shrink();
                    return _DayPlansCard(
                      date: _selectedDay!,
                      entries: items,
                      onEdit: (entry) async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NewTourPlanScreen(),
                          ),
                        );
                        if (result == true && mounted) {
                          await _refreshAllWithLoader();
                          setState(() {});
                        } else {
                          _applyFilters();
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                  // Selected day plans from API (Calendar Item List Data)
                  Observer(builder: (_) {
                    final DateTime? selected = _selectedDay;
                    final isTablet = MediaQuery.of(context).size.width >= 600;
                    // Apply all filters: date, customer, employee, and status
                    final apiItems = _store.calendarItemListData.where((item) {
                      // Filter by date
                      final bool byDate = selected == null ||
                          _isSameDate(item.planDate, selected);

                      // Filter by customer
                      bool byCustomer = true;
                      if (_customer != null && _customer!.isNotEmpty) {
                        byCustomer = false;
                        // Try matching by name (case-insensitive)
                        if (item.customerName != null &&
                            item.customerName!.trim().isNotEmpty) {
                          final itemName =
                              item.customerName!.trim().toLowerCase();
                          final filterName = _customer!.trim().toLowerCase();
                          if (itemName == filterName) {
                            byCustomer = true;
                          }
                        }
                        // Try matching by ID if name didn't match
                        if (!byCustomer &&
                            _customerNameToId.containsKey(_customer)) {
                          final filterCustomerId =
                              _customerNameToId[_customer!];
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
                        if (item.employeeName != null &&
                            item.employeeName!.trim().isNotEmpty) {
                          final itemName =
                              item.employeeName!.trim().toLowerCase();
                          final filterName = _employee!.trim().toLowerCase();
                          if (itemName == filterName) {
                            byEmployee = true;
                          }
                        }
                        // Try matching by ID if name didn't match
                        if (!byEmployee &&
                            _employeeNameToId.containsKey(_employee)) {
                          final filterEmployeeId =
                              _employeeNameToId[_employee!];
                          if (item.employeeId == filterEmployeeId) {
                            byEmployee = true;
                          }
                        }
                      }

                      // Filter by status
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
                          else if (item.statusText != null &&
                              item.statusText!.trim().isNotEmpty) {
                            final itemStatusText =
                                item.statusText!.trim().toLowerCase();
                            final filterStatusText =
                                _status!.trim().toLowerCase();
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
                          if (item.statusText != null &&
                              item.statusText!.trim().isNotEmpty) {
                            final itemStatusText =
                                item.statusText!.trim().toLowerCase();
                            final filterStatusText =
                                _status!.trim().toLowerCase();
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

                      final bool passes =
                          byDate && byCustomer && byEmployee && byStatus;
                      return passes;
                    }).toList()
                      ..sort((a, b) => a.planDate.compareTo(b.planDate));

                    // Debug: Log filtering results
                    if (_status != null ||
                        _customer != null ||
                        _employee != null) {
                      print('TourPlanScreen: Filters applied - '
                          'Status: "$_status", Customer: "$_customer", Employee: "$_employee" - '
                          'Total items: ${_store.calendarItemListData.length}, '
                          'Filtered items: ${apiItems.length}');
                    }
                    return Card(
                      margin: EdgeInsets.zero,
                      color: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: BorderSide(color: Colors.black.withOpacity(.06)),
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
                                            ? 'Plans on ${_formatDate(selected)}'
                                            : 'All Tour plans',
                                        style: GoogleFonts.inter(
                                          fontSize: isTablet ? 18 : 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey[900],
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (apiItems.isNotEmpty) ...[
                                  Text(
                                    'Total Records: ${apiItems.length}',
                                    style: GoogleFonts.inter(
                                      fontSize: isTablet ? 13 : 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...(apiItems.map(
                                      (item) => _buildTourPlanItemCard(item))),
                                ] else if (!_store
                                    .calendarItemListDataLoading) ...[
                                  Text(
                                    selected != null
                                        ? 'No plans for the selected day.'
                                        : 'No tour plans available.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.grey[600]),
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
                  const SizedBox(height: 12),
                  // Tour Plan List API Results
                  // Observer(
                  //   builder: (_) {
                  //     return Card(
                  //       color: Colors.white,
                  //       surfaceTintColor: Colors.transparent,
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(28),
                  //         side: BorderSide(color: Colors.black.withOpacity(.06)),
                  //       ),
                  //       elevation: 12,
                  //       child: Stack(
                  //         children: [
                  //           Padding(
                  //             padding: const EdgeInsets.all(16.0),
                  //             child: Column(
                  //               crossAxisAlignment: CrossAxisAlignment.stretch,
                  //               children: [
                  //                 Row(
                  //                   children: [
                  //                     Expanded(
                  //                       child: Text(
                  //                         'Tour Plan List (API)',
                  //                         style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  //                       ),
                  //                     ),
                  //                     if (_store.tourPlanListLoading)
                  //                       const SizedBox(
                  //                         width: 16,
                  //                         height: 16,
                  //                         child: CircularProgressIndicator(strokeWidth: 2),
                  //                       ),
                  //                   ],
                  //                 ),
                  //                 const SizedBox(height: 12),
                  //                 if (_store.tourPlanListItems.isNotEmpty) ...[
                  //                   Text(
                  //                     'Total Records: ${_store.tourPlanListItems.length}',
                  //                     style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  //                   ),
                  //                   const SizedBox(height: 8),
                  //                   ...(_store.tourPlanListItems.take(5).map((item) => _buildTourPlanItemCard(item))),
                  //                   if (_store.tourPlanListItems.length > 5)
                  //                     Text(
                  //                       '... and ${_store.tourPlanListItems.length - 5} more items',
                  //                       style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  //                     ),
                  //                 ] else if (!_store.tourPlanListLoading)
                  //                   Text(
                  //                     'No tour plan data available. Tap the list icon to load data.',
                  //                     style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  //                   ),
                  //               ],
                  //             ),
                  //           ),
                  //           // Loading overlay
                  //           if (_store.tourPlanListLoading)
                  //             Container(
                  //               decoration: BoxDecoration(
                  //                 color: Colors.white.withOpacity(0.8),
                  //                 borderRadius: BorderRadius.circular(28),
                  //               ),
                  //               child: const Center(
                  //                 child: Column(
                  //                   mainAxisSize: MainAxisSize.min,
                  //                   children: [
                  //                     CircularProgressIndicator(),
                  //                     SizedBox(height: 8),
                  //                     Text('Loading tour plan list...'),
                  //                   ],
                  //                 ),
                  //               ),
                  //             ),
                  //         ],
                  //       ),
                  //     );
                  //   },
                  // ),
                  // const SizedBox(height: 12),
                  // Manager Summary API Results
                  // Observer(
                  //   builder: (_) {
                  //     return Card(
                  //       color: Colors.white,
                  //       surfaceTintColor: Colors.transparent,
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(28),
                  //         side: BorderSide(color: Colors.black.withOpacity(.06)),
                  //       ),
                  //       elevation: 12,
                  //       // child: Stack(
                  //       //   children: [
                  //       //     Padding(
                  //       //       padding: const EdgeInsets.all(16.0),
                  //       //       child: Column(
                  //       //         crossAxisAlignment: CrossAxisAlignment.stretch,
                  //       //         children: [
                  //       //           Row(
                  //       //             children: [
                  //       //               Expanded(
                  //       //                 child: Text(
                  //       //                   'Manager Summary (API)',
                  //       //                   style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  //       //                 ),
                  //       //               ),
                  //       //               if (_store.managerSummaryLoading)
                  //       //                 const SizedBox(
                  //       //                   width: 16,
                  //       //                   height: 16,
                  //       //                   child: CircularProgressIndicator(strokeWidth: 2),
                  //       //                 ),
                  //       //             ],
                  //       //           ),
                  //       //           const SizedBox(height: 12),
                  //       //           if (_store.managerSummaryData != null) ...[
                  //       //             _buildManagerSummaryDisplay(_store.managerSummaryData!),
                  //       //           ] else if (!_store.managerSummaryLoading)
                  //       //             Text(
                  //       //               'No manager summary data available. Tap the manage accounts icon to load data.',
                  //       //               style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  //       //             ),
                  //       //         ],
                  //       //       ),
                  //       //     ),
                  //       //     // Loading overlay
                  //       //     if (_store.managerSummaryLoading)
                  //       //       Container(
                  //       //         decoration: BoxDecoration(
                  //       //           color: Colors.white.withOpacity(0.8),
                  //       //           borderRadius: BorderRadius.circular(28),
                  //       //         ),
                  //       //         child: const Center(
                  //       //           child: Column(
                  //       //             mainAxisSize: MainAxisSize.min,
                  //       //             children: [
                  //       //               CircularProgressIndicator(),
                  //       //               SizedBox(height: 8),
                  //       //               Text('Loading manager summary...'),
                  //       //             ],
                  //       //           ),
                  //       //         ),
                  //       //       ),
                  //       //   ],
                  //       // ),
                  //     );
                  //   },
                  // ),
                  // const SizedBox(height: 12),
                  // // Employee List Summary API Results
                  // Observer(
                  //   builder: (_) {
                  //     return Card(
                  //       color: Colors.white,
                  //       surfaceTintColor: Colors.transparent,
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(28),
                  //         side: BorderSide(color: Colors.black.withOpacity(.06)),
                  //       ),
                  //       elevation: 12,
                  //       child: Stack(
                  //         children: [
                  //           Padding(
                  //             padding: const EdgeInsets.all(16.0),
                  //             child: Column(
                  //               crossAxisAlignment: CrossAxisAlignment.stretch,
                  //               children: [
                  //                 Row(
                  //                   children: [
                  //                     Expanded(
                  //                       child: Text(
                  //                         'Employee List Summary (API)',
                  //                         style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  //                       ),
                  //                     ),
                  //                     if (_store.employeeListSummaryLoading)
                  //                       const SizedBox(
                  //                         width: 16,
                  //                         height: 16,
                  //                         child: CircularProgressIndicator(strokeWidth: 2),
                  //                       ),
                  //                   ],
                  //                 ),
                  //                 const SizedBox(height: 12),
                  //                 if (_store.employeeListSummaryData != null) ...[
                  //                   _buildEmployeeListSummaryDisplay(_store.employeeListSummaryData!),
                  //                 ] else if (!_store.employeeListSummaryLoading)
                  //                   Text(
                  //                     'No employee list summary data available. Tap the people icon to load data.',
                  //                     style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  //                   ),
                  //               ],
                  //             ),
                  //           ),
                  //           // Loading overlay
                  //           if (_store.employeeListSummaryLoading)
                  //             Container(
                  //               decoration: BoxDecoration(
                  //                 color: Colors.white.withOpacity(0.8),
                  //                 borderRadius: BorderRadius.circular(28),
                  //               ),
                  //               child: const Center(
                  //                 child: Column(
                  //                   mainAxisSize: MainAxisSize.min,
                  //                   children: [
                  //                     CircularProgressIndicator(),
                  //                     SizedBox(height: 8),
                  //                     Text('Loading employee list summary...'),
                  //                   ],
                  //                 ),
                  //               ),
                  //             ),
                  //         ],
                  //       ),
                  //     );
                  //   },
                  // ),
                  // const SizedBox(height: 12),
                  // Mapped Customers API Results
                  // Observer(
                  //   builder: (_) {
                  //     return Card(
                  //       color: Colors.white,
                  //       surfaceTintColor: Colors.transparent,
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(28),
                  //         side: BorderSide(color: Colors.black.withOpacity(.06)),
                  //       ),
                  //       elevation: 12,
                  //       child: Stack(
                  //         children: [
                  //           Padding(
                  //             padding: const EdgeInsets.all(16.0),
                  //             child: Column(
                  //               crossAxisAlignment: CrossAxisAlignment.stretch,
                  //               children: [
                  //                 Row(
                  //                   children: [
                  //                     Expanded(
                  //                       child: Text(
                  //                         'Mapped Customers (API)',
                  //                         style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  //                       ),
                  //                     ),
                  //                     if (_store.mappedCustomersLoading)
                  //                       const SizedBox(
                  //                         width: 16,
                  //                         height: 16,
                  //                         child: CircularProgressIndicator(strokeWidth: 2),
                  //                       ),
                  //                   ],
                  //                 ),
                  //                 const SizedBox(height: 12),
                  //                 if (_store.mappedCustomers.isNotEmpty) ...[
                  //                   _buildMappedCustomersDisplay(_store.mappedCustomers),
                  //                 ] else if (!_store.mappedCustomersLoading)
                  //                   Text(
                  //                     'No mapped customers data available. Tap the refresh button to load data.',
                  //                     style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  //                   ),
                  //               ],
                  //             ),
                  //           ),
                  //           // Loading overlay
                  //           if (_store.mappedCustomersLoading)
                  //             Container(
                  //               decoration: BoxDecoration(
                  //                 color: Colors.white.withOpacity(0.8),
                  //                 borderRadius: BorderRadius.circular(28),
                  //               ),
                  //               child: const Center(
                  //                 child: Column(
                  //                   mainAxisSize: MainAxisSize.min,
                  //                   children: [
                  //                     CircularProgressIndicator(),
                  //                     SizedBox(height: 8),
                  //                     Text('Loading mapped customers...'),
                  //                   ],
                  //                 ),
                  //               ),
                  //             ),
                  //         ],
                  //       ),
                  //     );
                  //   },
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<DateTime, CalendarDayDecoration> _buildDayDecorations(
      List<domain.TourPlanEntry> entries) {
    final Map<String, Color> dayColor = <String, Color>{};
    for (final e in entries) {
      final String key = '${e.date.year}-${e.date.month}-${e.date.day}';
      final Color next = _statusColor(e.status);
      if (dayColor[key] == null || next == const Color(0xFF2DBE64)) {
        dayColor[key] = next;
      }
    }
    final Map<DateTime, CalendarDayDecoration> map =
        <DateTime, CalendarDayDecoration>{};
    dayColor.forEach((key, color) {
      final parts = key.split('-').map(int.parse).toList();
      final d = DateTime(parts[0], parts[1], parts[2]);
      map[d] = CalendarDayDecoration(backgroundColor: color);
    });
    return map;
  }

  Map<TourPlanStatus, int> _buildMonthlyCounts(
      List<domain.TourPlanEntry> entries) {
    int planned = entries.length;
    int pending = entries
        .where((e) =>
            e.status == domain.TourPlanEntryStatus.pending ||
            e.status == domain.TourPlanEntryStatus.sentBack)
        .length;
    int approved = entries
        .where((e) => e.status == domain.TourPlanEntryStatus.approved)
        .length;
    int leaveDays = 0;
    int notEntered = entries
        .where((e) =>
            e.status == domain.TourPlanEntryStatus.draft ||
            e.status == domain.TourPlanEntryStatus.rejected)
        .length;
    return {
      TourPlanStatus.planned: planned,
      TourPlanStatus.pending: pending,
      TourPlanStatus.approved: approved,
      TourPlanStatus.leaveDays: leaveDays,
      TourPlanStatus.notEntered: notEntered,
    };
  }

  /// Build day decorations from API calendar view data
  Map<DateTime, CalendarDayDecoration> _buildApiDayDecorations(
      List<CalendarViewData> apiData) {
    final Map<DateTime, CalendarDayDecoration> map =
        <DateTime, CalendarDayDecoration>{};
    for (final d in apiData) {
      // Priority: Holiday > Weekend > Status-derived > Planned
      Color? color;
      if (d.isHolidayDay == true) {
        color = Colors.purple; // Leave/Holiday
      } else if (d.isWeekend == true) {
        color = Colors.grey; // Weekend
      } else {
        // Determine color from plannedCalls' statuses if available
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
              // Map status ids: 5=Approved, 1=Pending, 4=Sent Back, 3=Rejected
              if (statusId == 5) hasApproved = true;
              if (statusId == 4 || statusId == 3) hasSentBackOrRejected = true;
              if (statusId == 1 || statusId == 2)
                hasPending = true; // include Submitted as pending-like
            }
          }

          if (hasApproved) {
            color = const Color(0xFF2DBE64); // Approved
          } else if (hasSentBackOrRejected) {
            color = Colors.redAccent; // Sent Back / Rejected
          } else if (hasPending) {
            color = const Color(0xFFFFA41C); // Pending
          }
        }

        // If still no color but plannedCount > 0, mark as Planned
        color ??= (d.plannedCount > 0) ? const Color(0xFF2B78FF) : null;
      }

      if (color != null) {
        map[DateTime(d.planDate.year, d.planDate.month, d.planDate.day)] =
            CalendarDayDecoration(backgroundColor: color);
      }
    }
    return map;
  }

  domain.TourPlanEntryStatus? _parseStatus(String? label) {
    switch (label) {
      case 'Draft':
        return domain.TourPlanEntryStatus.draft;
      case 'Pending':
        return domain.TourPlanEntryStatus.pending;
      case 'Approved':
        return domain.TourPlanEntryStatus.approved;
      case 'Rejected':
        return domain.TourPlanEntryStatus.rejected;
    }
    return null;
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _applyFilters() {
    // Filters are applied both locally (immediate UI update) and via API (server-side filtering)
    if (mounted) {
      // Trigger UI rebuild to apply local filters immediately
      setState(() {
        _dataVersion++; // Force UI rebuild
      });

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
    // Get the default employee (current user's employee) before clearing
    final String? defaultEmployee = _getDefaultEmployee();

    setState(() {
      _customer = null;
      _status = null;
      // Preserve default employee (current user's employee) when clearing
      // Only clear employee if it's not the default employee
      if (_employee != defaultEmployee) {
        _employee = null;
      } else {
        // Keep the default employee selected
        _employee = defaultEmployee;
      }
      // Don't clear employee if roleCategory === 3 (employee filter disabled)
      if (_shouldDisableEmployeeFilter() && defaultEmployee != null) {
        _employee = defaultEmployee;
      }
      _dataVersion++; // Force UI rebuild
    });
    // Force hard refresh - reload calendar view and list data with cleared filters
    await Future.wait([
      _loadCalendarViewData(),
      _loadCalendarItemListData(),
      _loadTourPlanEmployeeListSummary(),
    ]);
    // Apply local filters after data is loaded
    if (mounted) {
      setState(() {
        _applyFilters();
      });
    }
  }

  // Get the default employee (current user's employee name)
  String? _getDefaultEmployee() {
    final int? userEmployeeId = _userDetailStore.userDetail?.employeeId;
    if (userEmployeeId == null) return null;

    // Find the employee name that matches the current user's employee ID
    for (final entry in _employeeNameToId.entries) {
      if (entry.value == userEmployeeId) {
        return entry.key;
      }
    }
    return null;
  }

  bool _hasActiveFilters() {
    return _customer != null || _employee != null || _status != null;
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_customer != null) count++;
    if (_status != null) count++;
    if (_employee != null && !_shouldDisableEmployeeFilter()) count++;
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

  // Check if employee filter should be disabled (when roleCategory === 3)
  bool _shouldDisableEmployeeFilter() {
    return _userDetailStore.userDetail?.roleCategory == 3;
  }

  // Build Filter Modal (DCR style)
  Widget _buildFilterModal(
      {required bool isMobile,
      required bool isTablet,
      required Color tealGreen}) {
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
                                  fontWeight: FontWeight.normal,
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
                              MediaQuery.of(context).viewInsets.bottom +
                                  (isMobile ? 16 : 20),
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
                                  onExpanded: () =>
                                      _scrollFilterSectionIntoView(
                                          _customerFilterSectionKey),
                                ),
                                SizedBox(height: isTablet ? 24 : 20),
                                // Status Filter - Searchable Dropdown
                                _SearchableFilterDropdown(
                                  key: _statusFilterSectionKey,
                                  title: 'Status',
                                  icon: Icons.verified_outlined,
                                  selectedValue: _tempStatus,
                                  options: _statusOptions.isNotEmpty
                                      ? _statusOptions
                                      : const [
                                          'Draft',
                                          'Pending',
                                          'Approved',
                                          'Rejected'
                                        ],
                                  onChanged: (value) {
                                    setModalState(() {
                                      _tempStatus = value;
                                    });
                                  },
                                  isTablet: isTablet,
                                  onExpanded: () =>
                                      _scrollFilterSectionIntoView(
                                          _statusFilterSectionKey),
                                ),
                                SizedBox(height: isTablet ? 24 : 20),
                                // Employee Filter - Searchable Dropdown
                                if (!_shouldDisableEmployeeFilter())
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
                                    onExpanded: () =>
                                        _scrollFilterSectionIntoView(
                                            _employeeFilterSectionKey),
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
                                    // Get default employee before clearing
                                    final String? defaultEmployee =
                                        _getDefaultEmployee();
                                    setModalState(() {
                                      _tempCustomer = null;
                                      _tempStatus = null;
                                      // Preserve default employee in modal state
                                      _tempEmployee = defaultEmployee;
                                    });
                                    _clearAllFilters();
                                    _closeFilterModal();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                        vertical: isMobile ? 14 : 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: BorderSide(
                                        color: tealGreen, width: 1.5),
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
                                    padding: EdgeInsets.symmetric(
                                        vertical: isMobile ? 14 : 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: Text(
                                    'Apply Filters',
                                    style: TextStyle(
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

  /// Load calendar view data from API with logging
  Future<void> _loadCalendarViewData() async {
    try {
      print(
          'TourPlanScreen: Loading calendar view data for ${_month.month}/${_month.year}');

      // Get user details from UserDetailStore
      final int? userId =
          _userDetailStore.userDetail?.userId; // Keep as null if not available
      final managerId = _userDetailStore.userDetail?.id ??
          0; // Assuming user is their own manager for now

      // Determine EmployeeId and SelectedEmployeeId based on filters
      // If employee filter is selected, use filtered employeeId for both EmployeeId and SelectedEmployeeId
      final int? filteredEmployeeId =
          _employee != null && _employeeNameToId.containsKey(_employee!)
              ? _employeeNameToId[_employee!]
              : null;

      // Get user's employeeId - ensure it's not null/0
      final int? userEmployeeId = _userDetailStore.userDetail?.employeeId;
      if (userEmployeeId == null || userEmployeeId == 0) {
        print(
            'TourPlanScreen: EmployeeId not available from user store, cannot load calendar view data');
        return;
      }

      // Use filtered employeeId if available, otherwise use user's employeeId
      final int finalEmployeeId = filteredEmployeeId ?? userEmployeeId;
      final int finalSelectedEmployeeId = filteredEmployeeId ?? userEmployeeId;

      print(
          'TourPlanScreen: User details - userId: $userId, managerId: $managerId, employeeId: $finalEmployeeId, selectedEmployeeId: $finalSelectedEmployeeId (filtered: ${filteredEmployeeId != null})');

      // Create request with current month/year and user details
      // SelectedEmployeeId must equal employeeId (filtered if employee filter is applied)
      final request = CalendarViewRequest(
        month: _month.month,
        year: _month.year,
        userId: userId, // null if not available, as per API requirement
        managerId: managerId,
        employeeId:
            finalEmployeeId, // Use filtered employeeId if employee filter is applied
        selectedEmployeeId:
            finalSelectedEmployeeId, // Use filtered employeeId if employee filter is applied
      );

      print('TourPlanScreen: Calendar View API Request - ${request.toJson()}');

      // Call the API through store
      await _store.loadCalendarViewData(
        month: request.month,
        year: request.year,
        userId: request.userId, // Pass null directly, not 0
        managerId: request.managerId,
        employeeId: request.employeeId,
        selectedEmployeeId: request
            .selectedEmployeeId, // Use filtered employeeId if employee filter is applied
      );

      print(
          'TourPlanScreen: Calendar View API Response received - ${_store.calendarViewData.length} calendar entries');

      // Log each calendar entry
      for (int i = 0; i < _store.calendarViewData.length; i++) {
        final data = _store.calendarViewData[i];
        print(
            'Day ${data.planDate.day}: Planned=${data.plannedCount}, Weekend=${data.isWeekend}, Holiday=${data.isHolidayDay}');
      }

      // Force UI update after calendar view data is loaded to refresh calendar
      if (mounted) {
        setState(() {
          _dataVersion++; // Increment to force calendar rebuild
        });
      }

      // Log full JSON response for debugging
      try {
        final jsonList =
            _store.calendarViewData.map((e) => e.toJson()).toList();
        print(
            'TourPlanScreen: CalendarViewData JSON => ${jsonEncode(jsonList)}');
      } catch (e) {
        print('TourPlanScreen: Failed to encode CalendarViewData to JSON: $e');
      }

      print('TourPlanScreen: Calendar view data loaded successfully');
    } catch (e) {
      print('TourPlanScreen: Error loading calendar view data: $e');
    }
  }

  /// Load tour plan list data from API
  Future<void> _loadTourPlanDetail() async {
    try {
      print('TourPlanScreen: Loading tour plan list data');

      // Get user details from UserDetailStore
      final userId = _userDetailStore.userDetail?.id ?? 1;
      final int employeeId = _getEmployeeIdForApi();

      print(
          'TourPlanScreen: Loading tour plan list with userId: $userId, employeeId: $employeeId');

      // Create request with current month/year and user details
      // SelectedEmployeeId must always equal employeeId as per API requirement
      await _store.loadTourPlanDetails(
        pageNumber: 1,
        pageSize: 100,
        month: _month.month,
        year: _month.year,
        userId: userId,
        employeeId: employeeId,
        bizunit: 1, // TODO: Get from user context or make configurable
        selectedEmployeeId:
            employeeId, // SelectedEmployeeId must equal employeeId
      );

      print(
          'TourPlanScreen: Tour plan list loaded successfully - ${_store.tourPlanListItems.length} items');
    } catch (e) {
      print('TourPlanScreen: Error loading tour plan list: $e');
    }
  }

  /// Load aggregate count summary data from API
  Future<void> _loadAggregateCountSummary() async {
    try {
      print('TourPlanScreen: Loading aggregate count summary data');
      final int employeeId = _getEmployeeIdForApi();

      // Create request with current month/year and employee ID
      await _store.loadAggregateCountSummary(
        employeeId: employeeId,
        month: _month.month,
        year: _month.year,
      );

      print('TourPlanScreen: Aggregate count summary loaded successfully');
    } catch (e) {
      print('TourPlanScreen: Error loading aggregate count summary: $e');
    }
  }

  Future<void> _getTourPlanStatusList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        final List<CommonDropdownItem> items =
            await commonRepo.getTourPlanStatusList();
        final names =
            items.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toSet();

        if (names.isNotEmpty && mounted) {
          setState(() {
            _statusOptions = {..._statusOptions, ...names}.toList();
            // map names to ids for potential status ID mapping
            for (final item in items) {
              final String key = item.text.trim();
              if (key.isNotEmpty) _statusNameToId[key] = item.id;
            }
          });
          print(
              'TourPlanScreen: Loaded ${_statusOptions.length} tour plan statuses');
        }
      }
    } catch (e) {
      print('TourPlanScreen: Error getting tour plan status list: $e');
    }
  }

  /// Load tour plan summary data from API
  Future<void> _loadTourPlanSummary() async {
    try {
      print('TourPlanScreen: Loading tour plan summary data');
      final userId = _userDetailStore.userDetail?.userId ?? 0;
      // Create request with current month/year and user parameters
      await _store.loadTourPlanSummary(
        month: _month.month,
        year: _month.year,
        userId: userId, // TODO: Get from user context
        bizunit: 1, // TODO: Get from user context
      );

      print('TourPlanScreen: Tour plan summary loaded successfully');
    } catch (e) {
      print('TourPlanScreen: Error loading tour plan summary: $e');
    }
  }

  /// Load manager summary data from API
  Future<void> _loadManagerSummary() async {
    try {
      print('TourPlanScreen: Loading manager summary data');
      final int employeeId = _getEmployeeIdForApi();

      // Create request with current month/year and employee ID
      await _store.loadManagerSummary(
        employeeId: employeeId, // TODO: Get from user context
        month: _month.month,
        year: _month.year,
      );

      print('TourPlanScreen: Manager summary loaded successfully');
    } catch (e) {
      print('TourPlanScreen: Error loading manager summary: $e');
    }
  }

  /// Get employee ID for API calls - either from filter or UserStore
  int _getEmployeeIdForApi() {
    // If employee filter is applied, use the filtered employee ID
    if (_employee != null && _employeeNameToId.containsKey(_employee)) {
      final filteredEmployeeId = _employeeNameToId[_employee!]!;
      print(
          'TourPlanScreen: Using filtered employee ID: $filteredEmployeeId for employee: $_employee');
      return filteredEmployeeId;
    }

    // Otherwise, use the current user's employee ID from UserStore
    final userEmployeeId = _userDetailStore.userDetail?.employeeId;
    if (userEmployeeId == null) {
      print('TourPlanScreen: Employee ID not available from UserStore');
      return 0; // Return 0 to indicate no valid employee ID
    }
    print('TourPlanScreen: Using current user employee ID: $userEmployeeId');
    return userEmployeeId;
  }

  /// Load employee list summary data from API
  Future<void> _loadTourPlanEmployeeListSummary() async {
    try {
      print('TourPlanScreen: [START] Loading employee list summary data');
      print(
          'TourPlanScreen: [INFO] Current month: ${_month.month}, year: ${_month.year}');

      // Get employee ID from UserStore or from applied filter
      final int employeeId = _getEmployeeIdForApi();
      print(
          'TourPlanScreen: [INFO] Using employeeId: $employeeId for API call');

      // Check if employee filter is applied
      if (_employee != null) {
        print('TourPlanScreen: [INFO] Employee filter applied: $_employee');
      } else {
        print(
            'TourPlanScreen: [INFO] No employee filter applied, using current user data');
      }

      // Create request with current month/year and employee ID
      print(
          'TourPlanScreen: [API] Calling loadTourPlanEmployeeListSummary with employeeId: $employeeId, month: ${_month.month}, year: ${_month.year}');

      await _store.loadTourPlanEmployeeListSummary(
        employeeId: employeeId,
        month: _month.month,
        year: _month.year,
      );

      print(
          'TourPlanScreen: [SUCCESS] Employee list summary loaded successfully');
      print(
          'TourPlanScreen: [INFO] Employee list summary data available: ${_store.employeeListSummaryData != null}');

      // Log the loaded data if available
      if (_store.employeeListSummaryData != null &&
          _store.employeeListSummaryData
              is TourPlanGetEmployeeListSummaryResponse) {
        final data = _store.employeeListSummaryData
            as TourPlanGetEmployeeListSummaryResponse;
        print('TourPlanScreen: [DATA] Total Employees: ${data.totalEmployees}');
        print('TourPlanScreen: [DATA] Total Planned: ${data.totalPlanned}');
        print('TourPlanScreen: [DATA] Total Approved: ${data.totalApproved}');
        print('TourPlanScreen: [DATA] Total Pending: ${data.totalPending}');
        print('TourPlanScreen: [DATA] Total Sent Back: ${data.totalSentBack}');
        print(
            'TourPlanScreen: [DATA] Total Not Entered: ${data.totalNotEntered}');
        print('TourPlanScreen: [DATA] Total Leave: ${data.totalLeave}');
      } else {
        print(
            'TourPlanScreen: [WARNING] Employee list summary data is null after API call');
      }

      print('TourPlanScreen: [END] Employee list summary loading completed');
    } catch (e) {
      print('TourPlanScreen: [ERROR] Failed to load employee list summary: $e');
      print('TourPlanScreen: [ERROR] Stack trace: ${StackTrace.current}');
    }
  }

  // Tour Plan Related Common API Methods
  Future<void> _getEmployeeList({int? employeeId}) async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        // If employeeId is not provided, try to get it from user store
        final int? finalEmployeeId =
            employeeId ?? _userDetailStore.userDetail?.employeeId;
        final List<CommonDropdownItem> items =
            await commonRepo.getEmployeeList(employeeId: finalEmployeeId);
        final names = items
            .map((e) =>
                (e.employeeName.isNotEmpty ? e.employeeName : e.text).trim())
            .where((s) => s.isNotEmpty)
            .toSet();

        if (names.isNotEmpty && mounted) {
          setState(() {
            _employeeOptions = {..._employeeOptions, ...names}.toList();
            // map names to ids for potential employee ID mapping
            String? selectedEmployeeName;
            for (final item in items) {
              final String key =
                  (item.employeeName.isNotEmpty ? item.employeeName : item.text)
                      .trim();
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
              print(
                  'TourPlanScreen: Auto-selected employee: $selectedEmployeeName (ID: $finalEmployeeId)');
            }
          });
          print(
              'TourPlanScreen: Loaded ${_employeeOptions.length} employees ${finalEmployeeId != null ? "for employeeId: $finalEmployeeId" : ""}');
        }
      }
    } catch (e) {
      print('TourPlanScreen: Error getting employee list: $e');
    }
  }

  /// Load mapped customers by employee ID from API
  Future<void> _loadMappedCustomersByEmployeeId() async {
    try {
      final int? employeeId = _userDetailStore.userDetail?.employeeId;
      if (employeeId == null || employeeId == 0) {
        print(
            'TourPlanScreen: Employee ID is null or 0, skipping customer load');
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
            print(
                'TourPlanScreen: Loaded ${_customerOptions.length} customers for employee $employeeId');
          }
        } else {
          print('TourPlanScreen: No customers found for employee $employeeId');
        }
      }
    } catch (e) {
      print(
          'TourPlanScreen: Error loading mapped customers by employee ID: $e');
    }
  }

  /// Load calendar item list data from API (Tour Plan List endpoint)
  Future<void> _loadCalendarItemListData() async {
    try {
      print('TourPlanScreen: Loading calendar item list data');

      // Get user details from UserDetailStore
      final userId = _userDetailStore.userDetail?.id;
      final employeeId = _userDetailStore.userDetail?.employeeId;

      if (userId == null || employeeId == null) {
        print(
            'TourPlanScreen: User details not available for calendar item list');
        return;
      }

      print(
          'TourPlanScreen: Loading calendar item list with userId: $userId, employeeId: $employeeId, month: ${_month.month}, year: ${_month.year}');

      // Determine EmployeeId and SelectedEmployeeId based on filters
      // If employee filter is selected, use filtered employeeId for both EmployeeId and SelectedEmployeeId
      final int? filteredEmployeeId =
          _employee != null && _employeeNameToId.containsKey(_employee!)
              ? _employeeNameToId[_employee!]
              : null;

      // Ensure employeeId is valid (not null/0)
      if (employeeId == null || employeeId == 0) {
        print(
            'TourPlanScreen: Invalid employeeId ($employeeId), cannot load calendar item list data');
        return;
      }

      // Use filtered employeeId if available, otherwise use user's employeeId
      final int finalEmployeeId = filteredEmployeeId ?? employeeId;
      final int finalSelectedEmployeeId = filteredEmployeeId ?? employeeId;

      // Get customerId and status from filters
      final int? customerId =
          _customer != null && _customerNameToId.containsKey(_customer!)
              ? _customerNameToId[_customer!]
              : null;
      final int? status =
          _status != null && _statusNameToId.containsKey(_status!)
              ? _statusNameToId[_status!]
              : null;

      print(
          'TourPlanScreen: API Request params - EmployeeId: $finalEmployeeId, SelectedEmployeeId: $finalSelectedEmployeeId, CustomerId: $customerId, Status: $status');

      await _store.loadCalendarItemListData(
        searchText: null,
        pageNumber: 1,
        pageSize: 1000,
        employeeId:
            finalEmployeeId, // Use filtered employeeId if employee filter is applied
        month: _month.month,
        userId: userId,
        bizunit: 1, // TODO: Get from user context or make configurable
        year: _month.year,
        selectedEmployeeId:
            finalSelectedEmployeeId, // Use filtered employeeId if employee filter is applied
        customerId: customerId,
        status: status,
        sortOrder: 0,
        sortDir: 0,
        sortField: null,
      );

      print(
          'TourPlanScreen: Calendar item list data loaded successfully - ${_store.calendarItemListData.length} items');

      // Force UI update after data is loaded to refresh the list
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('TourPlanScreen: Error loading calendar item list data: $e');
    }
  }

  /// Approve a single tour plan entry
  void _approveSingleTourPlan(int tourPlanId, String comment) async {
    try {
      print('TourPlanScreen: Approving single tour plan with ID: $tourPlanId');

      final request = TourPlanActionRequest(
        id: tourPlanId,
        action: 5, // Action code for approve
        comment: comment,
      );

      final response = await _store.approveSingleTourPlan(request);

      final String msg = (response.message).trim().toLowerCase();
      final bool success = response.status ||
          msg.isEmpty ||
          msg == 'success' ||
          msg == 'ok' ||
          msg.contains('approved');
      if (mounted) {
        ToastMessage.show(
          context,
          message: success
              ? 'Success: Tour plan approved'
              : 'Failed to approve tour plan: ${response.message}',
          type: success ? ToastType.success : ToastType.error,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      print('TourPlanScreen: Error approving tour plan: $e');
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Error approving tour plan: $e',
          type: ToastType.error,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  /// Reject a single tour plan entry
  void _rejectSingleTourPlan(int tourPlanId, String comment) async {
    try {
      print('TourPlanScreen: Rejecting single tour plan with ID: $tourPlanId');

      final request = TourPlanActionRequest(
        id: tourPlanId,
        action: 4, // Action code for reject
        comment: comment,
      );

      final response = await _store.rejectSingleTourPlan(request);

      final String msg = (response.message).trim().toLowerCase();
      final bool success = response.status ||
          msg.isEmpty ||
          msg == 'success' ||
          msg == 'ok' ||
          msg.contains('rejected');
      if (mounted) {
        ToastMessage.show(
          context,
          message: success
              ? 'Success: Tour plan rejected'
              : 'Failed to reject tour plan: ${response.message}',
          type: success ? ToastType.success : ToastType.error,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      print('TourPlanScreen: Error rejecting tour plan: $e');
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Error rejecting tour plan: $e',
          type: ToastType.error,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  /// Bulk approve multiple tour plan entries
  void _bulkApproveTourPlans(
      int tourPlanId, List<int> tourPlanDetailIds) async {
    try {
      print('TourPlanScreen: Bulk approving tour plans with ID: $tourPlanId');

      final request = TourPlanBulkActionRequest(
        id: tourPlanId,
        action: 5, // Action code for approve
        tourPlanDetails:
            tourPlanDetailIds.map((id) => TourPlanDetailItem(id: id)).toList(),
      );

      final response = await _store.bulkApproveTourPlans(request);

      final String msg = (response.message).trim().toLowerCase();
      final bool success = response.status ||
          msg.isEmpty ||
          msg == 'success' ||
          msg == 'ok' ||
          msg.contains('approved');
      if (mounted) {
        ToastMessage.show(
          context,
          message: success
              ? 'Success: Approved ${tourPlanDetailIds.length} item(s)'
              : 'Failed to approve ${tourPlanDetailIds.length} item(s): ${response.message}',
          type: success ? ToastType.success : ToastType.error,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      print('TourPlanScreen: Error bulk approving tour plans: $e');
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Error bulk approving tour plans: $e',
          type: ToastType.error,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  /// Bulk send back multiple tour plan entries
  void _bulkSendBackTourPlans(
      int tourPlanId, List<int> tourPlanDetailIds) async {
    try {
      print(
          'TourPlanScreen: Bulk sending back tour plans with ID: $tourPlanId');

      final request = TourPlanBulkActionRequest(
        id: tourPlanId,
        action: 4, // Action code for send back
        tourPlanDetails:
            tourPlanDetailIds.map((id) => TourPlanDetailItem(id: id)).toList(),
      );

      final response = await _store.bulkSendBackTourPlans(request);

      final String msg = (response.message).trim().toLowerCase();
      final bool success = response.status ||
          msg.isEmpty ||
          msg == 'success' ||
          msg == 'ok' ||
          msg.contains('send back') ||
          msg.contains('sent back');
      if (mounted) {
        ToastMessage.show(
          context,
          message: success
              ? 'Success: Sent back ${tourPlanDetailIds.length} item(s)'
              : 'Failed to send back ${tourPlanDetailIds.length} item(s): ${response.message}',
          type: success ? ToastType.success : ToastType.error,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      print('TourPlanScreen: Error bulk sending back tour plans: $e');
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Error bulk sending back tour plans: $e',
          type: ToastType.error,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  /// Build a card widget for a tour plan item
  Widget _buildTourPlanItemCard(TourPlanItem item) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    // Get status text with fallbacks
    final statusText = _getStatusDisplayText(item);
    final statusColor = _getStatusColor(item.status);
    final statusBgColor = _getStatusBackgroundColor(item.status);
    final customerName = item.customerName ?? 'Customer ${item.customerId}';

    return InkWell(
      onTap: () => _showTourPlanDetails(item),
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
                    child: Icon(Icons.visibility_outlined,
                        size: isTablet ? 16 : 14, color: Colors.grey.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Employee row (matching DCR list)
              if (item.employeeName != null &&
                  item.employeeName!.isNotEmpty) ...[
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
                      padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 9 : 8,
                          vertical: isTablet ? 4 : 3),
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
    );
  }

  /// Build info section for card display (simplified version)
  Widget _buildCardInfoSection(
      String title, List<MapEntry<String, String>> items, bool isTablet) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: isTablet ? 13 : 12,
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
                        fontSize: isTablet ? 13 : 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.value,
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 13 : 12,
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

  /// Check if comment button should be shown for tour plan
  /// Shows comment icon for: Pending (1, 2), Approved (5), and Sent Back (4)
  /// Status IDs: 5=Approved, 1=Pending/Submitted, 4=Sent Back, 3=Rejected, 2=Submitted
  bool _canCommentTourPlan(TourPlanItem item) {
    return item.status == 1 ||
        item.status == 2 ||
        item.status == 4 ||
        item.status == 5;
  }

  /// Check if tour plan can be edited (Draft, Pending, or Sent Back status)
  bool _canEditTourPlan(TourPlanItem item) {
    // First check if user validation allows updates
    if (getIt.isRegistered<UserValidationStore>()) {
      final validationStore = getIt<UserValidationStore>();
      if (!validationStore.canUpdateTourPlan) {
        return false; // Disable edit if validation fails
      }
    }
    
    // Allow editing for Draft (status 0), Pending (status 1 or 2), and Sent Back (status 4) tour plans
    // Status 4 = Sent Back - user should be able to edit and resubmit
    return item.status == 0 ||
        item.status == 1 ||
        item.status == 2 ||
        item.status == 4;
  }

  /// Check if tour plan can be deleted (Medical Rep with roleCategory == 3, and not approved/sent back)
  bool _canDeleteTourPlan(TourPlanItem item) {
    // Only allow delete for Medical Rep (roleCategory == 3)
    // Exclude Approved (5) and Sent Back (4) statuses - server doesn't allow deleting sent back tour plans
    final roleCategory = _userDetailStore.userDetail?.roleCategory;
    return roleCategory == 3 &&
        item.status != 5 &&
        item.status != 4; // Status 5 = Approved, 4 = Sent Back
  }

  /// Check if DCR can be created from tour plan (not available for pending or sent back tour plans)
  bool _canCreateDcrFromTourPlan(TourPlanItem item) {
    // DCR cannot be created from pending tour plans (status 1 or 2) or sent back tour plans (status 4)
    // DCR can be created from Draft (0), Approved (5), and Rejected (3) tour plans
    return item.status != 1 &&
        item.status != 2 &&
        item.status != 4; // Exclude pending and sent back statuses
  }

  /// Show detailed popup for Tour Plan item with bottom-to-top slide animation
  void _showTourPlanDetails(TourPlanItem item) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final statusText = _getStatusDisplayText(item);
    final statusColor = _getStatusColor(item.status);
    final statusBgColor = _getStatusBackgroundColor(item.status);
    final customerName = item.customerName ?? 'Customer ${item.customerId}';
    final customerCode = item.customerId != null
        ? ' - P${item.customerId.toString().padLeft(5, '0')}'
        : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 600 : MediaQuery.of(context).size.width,
          maxHeight:
              MediaQuery.of(context).size.height * (isTablet ? 0.85 : 0.9),
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
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
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
                      if (item.employeeName != null ||
                          item.designation != null ||
                          item.planDate != null) ...[
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
                              if (item.employeeName != null &&
                                  item.employeeName!.isNotEmpty)
                                _DetailRow('Name', item.employeeName!),
                              if (item.designation != null &&
                                  item.designation!.isNotEmpty) ...[
                                if (item.employeeName != null &&
                                    item.employeeName!.isNotEmpty)
                                  SizedBox(height: isTablet ? 6 : 4),
                                _DetailRow('Designation', item.designation!),
                              ],
                              if (item.planDate != null) ...[
                                if ((item.employeeName != null &&
                                        item.employeeName!.isNotEmpty) ||
                                    (item.designation != null &&
                                        item.designation!.isNotEmpty))
                                  SizedBox(height: isTablet ? 6 : 4),
                                _DetailRow('Date', _formatDate(item.planDate)),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: isTablet ? 12 : 10),
                      ],

                      // Location Details
                      if (item.cluster != null ||
                          item.clusters != null ||
                          item.territory != null) ...[
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
                              if (item.clusters != null &&
                                  item.clusters!.isNotEmpty) ...[
                                _DetailRow('Clusters', item.clusters!),
                              ] else if (item.cluster != null &&
                                  item.cluster!.isNotEmpty) ...[
                                _DetailRow('Cluster', item.cluster!),
                              ],
                              if (item.territory != null &&
                                  item.territory!.isNotEmpty) ...[
                                if (item.cluster != null ||
                                    item.clusters != null)
                                  SizedBox(height: isTablet ? 6 : 4),
                                _DetailRow('Territory', item.territory!),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: isTablet ? 12 : 10),
                      ],

                      // Visit Details
                      if (customerName.isNotEmpty ||
                          item.productsToDiscuss != null ||
                          item.samplesToDistribute != null ||
                          item.objective != null) ...[
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
                              _DetailRow(
                                  'Customer', '$customerName$customerCode'),
                              if (item.productsToDiscuss != null &&
                                  item.productsToDiscuss!.isNotEmpty) ...[
                                SizedBox(height: isTablet ? 6 : 4),
                                _DetailRow('Products to Discuss',
                                    item.productsToDiscuss!),
                              ],
                              if (item.samplesToDistribute != null &&
                                  item.samplesToDistribute!.isNotEmpty) ...[
                                SizedBox(height: isTablet ? 6 : 4),
                                _DetailRow('Samples to Distribute',
                                    item.samplesToDistribute!),
                              ],
                              if (item.objective != null &&
                                  item.objective!.isNotEmpty) ...[
                                SizedBox(height: isTablet ? 6 : 4),
                                _DetailRow('Objective', item.objective!),
                              ],
                              if (item.tourPlanType != null &&
                                  item.tourPlanType!.isNotEmpty) ...[
                                SizedBox(height: isTablet ? 6 : 4),
                                _DetailRow('Plan Type', item.tourPlanType!),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: isTablet ? 12 : 10),
                      ],

                      // Additional Information
                      if (item.notes != null ||
                          item.remarks != null ||
                          item.managerComments != null) ...[
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
                              if (item.notes != null &&
                                  item.notes!.isNotEmpty) ...[
                                _DetailRow('Notes', item.notes!,
                                    isMultiline: true),
                              ],
                              if (item.remarks != null &&
                                  item.remarks!.isNotEmpty) ...[
                                if (item.notes != null &&
                                    item.notes!.isNotEmpty)
                                  SizedBox(height: isTablet ? 6 : 4),
                                _DetailRow('Remarks', item.remarks!,
                                    isMultiline: true),
                              ],
                              if (item.managerComments != null &&
                                  item.managerComments!.isNotEmpty) ...[
                                if ((item.notes != null &&
                                        item.notes!.isNotEmpty) ||
                                    (item.remarks != null &&
                                        item.remarks!.isNotEmpty))
                                  SizedBox(height: isTablet ? 6 : 4),
                                _DetailRow(
                                    'Manager Comments', item.managerComments!,
                                    isMultiline: true),
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
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      // Edit button
                      if (_canEditTourPlan(item))
                        getIt.isRegistered<UserValidationStore>()
                            ? ListenableBuilder(
                                listenable: getIt<UserValidationStore>(),
                                builder: (context, _) {
                                  final validationStore =
                                      getIt<UserValidationStore>();
                                  final isEnabled =
                                      validationStore.canUpdateTourPlan;
                                  return FilledButton.icon(
                                    onPressed: isEnabled
                                        ? () {
                                            Navigator.of(context).pop();
                                            _editTourPlan(item);
                                          }
                                        : null,
                                    icon: Icon(Icons.edit_outlined,
                                        size: isTablet ? 18 : 16),
                                    label: Text(
                                      'Edit',
                                      style: GoogleFonts.inter(
                                        fontSize: isTablet ? 14 : 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          isEnabled ? tealGreen : Colors.grey,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          Colors.grey.shade300,
                                      disabledForegroundColor:
                                          Colors.grey.shade600,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isTablet ? 20 : 16,
                                        vertical: isTablet ? 12 : 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : FilledButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _editTourPlan(item);
                                },
                                icon: Icon(Icons.edit_outlined,
                                    size: isTablet ? 18 : 16),
                                label: Text(
                                  'Edit',
                                  style: GoogleFonts.inter(
                                    fontSize: isTablet ? 14 : 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: tealGreen,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 20 : 16,
                                    vertical: isTablet ? 12 : 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                      // Comment button (for Pending, Approved, and Sent Back)
                      if (_canCommentTourPlan(item))
                        FilledButton.icon(
                          onPressed: () {
                            // Don't close the popup - let the comment dialog open on top
                            _addCommentToTourPlan(item);
                          },
                          icon: Icon(Icons.comment_outlined,
                              size: isTablet ? 18 : 16),
                          label: Text(
                            'Comment',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 14 : 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: tealGreen,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 20 : 16,
                              vertical: isTablet ? 12 : 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      // Create DCR button
                      if (_canCreateDcrFromTourPlan(item))
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _createDcrFromTourPlan(item);
                          },
                          icon: Icon(Icons.description_outlined,
                              size: isTablet ? 18 : 16),
                          label: Text(
                            'Create DCR',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 14 : 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: tealGreen,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 20 : 16,
                              vertical: isTablet ? 12 : 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      // Delete button
                      if (_canDeleteTourPlan(item))
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _deleteTourPlan(item);
                          },
                          icon: Icon(Icons.delete_outlined,
                              size: isTablet ? 18 : 16),
                          label: Text(
                            'Delete',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 14 : 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 20 : 16,
                              vertical: isTablet ? 12 : 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
      crossAxisAlignment:
          isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
            overflow:
                isMultiline ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Navigate to edit tour plan screen
  void _editTourPlan(TourPlanItem item) async {
    print('TourPlanScreen: Editing tour plan with ID: ${item.id}');

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewTourPlanScreen(tourPlanToEdit: item),
      ),
    );

    // Refresh the data after editing
    if (result == true && mounted) {
      await _refreshAllWithLoader();
    }
  }

  /// Delete tour plan (for Medical Rep only, before approval)
  Future<void> _deleteTourPlan(TourPlanItem item) async {
    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tour Plan'),
        content: Text(
            'Are you sure you want to delete this tour plan? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
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
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        if (response.status) {
          ToastMessage.show(
            context,
            message: response.message.isNotEmpty
                ? response.message
                : 'Tour plan deleted successfully',
            type: ToastType.success,
            duration: const Duration(seconds: 3),
          );
          await _refreshAllWithLoader();
        } else {
          ToastMessage.show(
            context,
            message: response.message.isNotEmpty
                ? response.message
                : 'Failed to delete tour plan',
            type: ToastType.error,
            duration: const Duration(seconds: 4),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        // Extract a more user-friendly error message
        String errorMessage = 'Failed to delete tour plan';
        if (e.toString().contains('500')) {
          errorMessage =
              'Cannot delete this tour plan. It may have been sent back or is in a state that cannot be deleted.';
        } else if (e.toString().contains('status code')) {
          errorMessage =
              'Server error: Unable to delete tour plan. Please try again later.';
        } else {
          errorMessage = 'Error: ${e.toString()}';
        }

        ToastMessage.show(
          context,
          message: errorMessage,
          type: ToastType.error,
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  /// Create DCR from a tour plan item
  void _createDcrFromTourPlan(TourPlanItem item) async {
    try {
      print(
          'TourPlanScreen: Creating DCR from tour plan - Item ID: ${item.id}, TourPlanId: ${item.tourPlanId}');

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      int? typeOfWorkId;
      TourPlanItem? fullItem = item;

      // If tourPlanDetails is null, fetch full tour plan details from API (same as edit tour plan form)
      if (item.tourPlanDetails == null || item.tourPlanDetails!.isEmpty) {
        print(
            'TourPlanScreen: tourPlanDetails is null/empty - fetching full details from API...');

        try {
          final repo = getIt<TourPlanRepository>();
          int effectiveTourPlanId = item.tourPlanId;
          int effectiveId = item.id;

          // If tourPlanId is 0 or null, use id as tourPlanId
          if (effectiveTourPlanId == 0) {
            effectiveTourPlanId = effectiveId;
            print(
                'TourPlanScreen: tourPlanId was 0, using id as tourPlanId: $effectiveTourPlanId');
          }

          print(
              'TourPlanScreen: Calling getTourPlanDetails with tourPlanId=$effectiveTourPlanId, id=$effectiveId');
          final response = await repo.getTourPlanDetails(
            tourPlanId: effectiveTourPlanId,
            id: effectiveId,
          );

          if (response.items.isNotEmpty) {
            fullItem = response.items.first;
            print('TourPlanScreen: ✓ Fetched full tour plan details');
            print(
                'TourPlanScreen: tourPlanDetails count: ${fullItem.tourPlanDetails?.length ?? 0}');
          } else {
            print(
                'TourPlanScreen: ⚠ API returned empty items, using original item');
          }
        } catch (e) {
          print('TourPlanScreen: ⚠ Error fetching tour plan details: $e');
          print('TourPlanScreen: Using original item data');
        }
      }

      // Get typeOfWorkId and other data from tour plan details (same as edit tour plan form)
      int? customerIdFromDetail;
      int? clusterIdFromDetail;
      if (fullItem != null &&
          fullItem.tourPlanDetails != null &&
          fullItem.tourPlanDetails!.isNotEmpty) {
        final detail = fullItem.tourPlanDetails!.first;
        typeOfWorkId = detail.typeOfWorkId;
        customerIdFromDetail = detail.customerId;
        clusterIdFromDetail = detail.clusterId;
        print('TourPlanScreen: ✓ Extracted from tourPlanDetails[0]:');
        print('  - typeOfWorkId: $typeOfWorkId');
        print('  - customerId: $customerIdFromDetail');
        print('  - clusterId: $clusterIdFromDetail');
      } else {
        print(
            'TourPlanScreen: ⚠ No tourPlanDetails found, typeOfWorkId will be null');
      }

      // Ensure fullItem is not null before using it
      if (fullItem == null) {
        // Close loading dialog
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✗ Failed to load tour plan details'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      // At this point, fullItem is guaranteed to be non-null
      final TourPlanItem finalItem = fullItem;

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Map tour plan to DCR entry (purpose will be set from typeOfWorkId in DCR entry screen)
      // All data will be populated from tourPlanDetails[0] (same as edit tour plan form)
      final dcr.DcrEntry initial =
          _mapTourPlanToDcr(finalItem, purposeOfVisit: null);

      print(
          'TourPlanScreen: Opening DCR entry screen with initialTypeOfWorkId: $typeOfWorkId');

      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DcrEntryScreen(
            initialEntry: initial,
            // Use customerId from tourPlanDetails[0] if available, otherwise fallback to header
            initialCustomerId:
                customerIdFromDetail != null && customerIdFromDetail! > 0
                    ? customerIdFromDetail
                    : (finalItem.customerId == 0 ? null : finalItem.customerId),
            // Use clusterId from tourPlanDetails[0] if available, otherwise fallback to header
            initialClusterId: clusterIdFromDetail ?? finalItem.clusterId,
            initialTypeOfWorkId: typeOfWorkId,
          ),
        ),
      );
      if (result == true && mounted) {
        // Optional: refresh any DCR-dependent UI or show a snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Success: DCR created successfully.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Failed to open DCR: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  dcr.DcrEntry _mapTourPlanToDcr(TourPlanItem item, {String? purposeOfVisit}) {
    // Prefer data from tourPlanDetails[0] if available (same as edit tour plan form)
    // This matches the JSON structure provided by the user
    TourPlanDetail? detail;
    if (item.tourPlanDetails != null && item.tourPlanDetails!.isNotEmpty) {
      detail = item.tourPlanDetails!.first;
      print('TourPlanScreen: Using tourPlanDetails[0] for DCR mapping');
    }

    // Extract date from tourPlanDetails[0].planDate (format: "2025-11-13T00:00:00")
    final DateTime visitDate;
    final TimeOfDay visitTime;
    if (detail != null && detail.planDate != null) {
      visitDate = detail.planDate;
      // Extract time from planDate (format: "2025-11-13T00:00:00")
      visitTime = TimeOfDay(hour: visitDate.hour, minute: visitDate.minute);
      print('TourPlanScreen: Using planDate from detail: ${detail.planDate}');
    } else {
      // Fallback to item.planDate
      visitDate = item.planDate;
      final now = DateTime.now();
      visitTime = TimeOfDay(hour: now.hour, minute: now.minute);
      print('TourPlanScreen: Using planDate from item: ${item.planDate}');
    }

    // Extract cluster from tourPlanDetails[0].clusterNames
    final String clusterName;
    if (detail != null &&
        detail.clusterNames != null &&
        detail.clusterNames!.trim().isNotEmpty) {
      clusterName = detail.clusterNames!.trim();
      print('TourPlanScreen: Using clusterNames from detail: $clusterName');
    } else {
      // Fallback to header-level cluster
      clusterName = item.cluster?.trim().isNotEmpty == true
          ? item.cluster!.trim()
          : (item.clusters?.trim() ?? '');
    }

    // Extract customer from tourPlanDetails[0].location (format: "CLUSTER - CUSTOMER - CODE")
    // Example: "ANGURUWELLA - Safeway Pharmaceuticals (Pvt) Ltd - P01304"
    String customerName = '';
    if (detail != null &&
        detail.location != null &&
        detail.location!.contains('-')) {
      final parts = detail.location!.split('-');
      if (parts.length >= 2) {
        // Customer name is typically the second part (index 1)
        customerName = parts[1].trim();
        print(
            'TourPlanScreen: Extracted customer from location: $customerName');
      }
    }
    // Fallback to header-level customerName
    if (customerName.isEmpty) {
      customerName = item.customerName?.trim() ?? '';
    }

    // Extract products from tourPlanDetails[0].productsToDiscuss
    final String products;
    if (detail != null &&
        detail.productsToDiscuss != null &&
        detail.productsToDiscuss!.trim().isNotEmpty) {
      products = detail.productsToDiscuss!.trim();
      print('TourPlanScreen: Using productsToDiscuss from detail: $products');
    } else {
      products = item.productsToDiscuss?.trim() ?? '';
    }

    // Extract samples from tourPlanDetails[0].samplesToDistribute
    final String samples;
    if (detail != null &&
        detail.samplesToDistribute != null &&
        detail.samplesToDistribute!.trim().isNotEmpty) {
      samples = detail.samplesToDistribute!.trim();
      print('TourPlanScreen: Using samplesToDistribute from detail: $samples');
    } else {
      samples = item.samplesToDistribute?.trim() ?? '';
    }

    // Extract notes/remarks from tourPlanDetails[0].remarks
    final String notes;
    if (detail != null &&
        detail.remarks != null &&
        detail.remarks!.trim().isNotEmpty) {
      notes = detail.remarks!.trim();
      print('TourPlanScreen: Using remarks from detail: $notes');
    } else {
      notes = item.notes?.trim() ?? '';
    }

    // Extract location from tourPlanDetails[0].location
    final String? location;
    if (detail != null &&
        detail.location != null &&
        detail.location!.trim().isNotEmpty) {
      location = detail.location!.trim();
      print('TourPlanScreen: Using location from detail: $location');
    } else {
      location = null;
    }

    // Don't set purposeOfVisit here - it will be resolved in DCR entry screen from typeOfWorkId
    // (same approach as edit tour plan form)
    // This ensures consistency and uses the same reverse mapping logic
    // Pass empty string as placeholder - will be set from typeOfWorkId in DCR entry screen
    final String finalPurposeOfVisit =
        ''; // Will be resolved from typeOfWorkId in DCR entry screen

    // Create DateTime with date from planDate and time from planDate (extracted earlier)
    final DateTime dcrDate = DateTime(
      visitDate.year,
      visitDate.month,
      visitDate.day,
      visitTime.hour,
      visitTime.minute,
    );

    print('TourPlanScreen: Mapped DCR Entry:');
    print('  - Date: $dcrDate');
    print('  - Cluster: $clusterName');
    print('  - Customer: $customerName');
    print('  - Products: $products');
    print('  - Samples: $samples');
    print('  - Notes: $notes');
    print('  - Location: $location');

    return dcr.DcrEntry(
      id: '',
      date: dcrDate,
      cluster: clusterName,
      customer: customerName,
      purposeOfVisit: finalPurposeOfVisit,
      callDurationMinutes: 0,
      productsDiscussed: products,
      samplesDistributed: samples,
      keyDiscussionPoints: notes,
      status: dcr.DcrStatus.draft,
      employeeId: _userDetailStore.userDetail?.employeeId.toString() ?? '',
      employeeName: _userDetailStore.userDetail?.employeeName ?? '',
      // Link to the Tour Plan header ID
      linkedTourPlanId: (item.tourPlanId ?? item.id).toString(),
      geoProximity: dcr.GeoProximity.at,
      customerLatitude: detail?.latitude ?? null,
      customerLongitude: detail?.longitude ?? null,
      createdAt: null,
      updatedAt: null,
    );
  }

  /// Helper method to build info sections with titles
  Widget _buildInfoSection(String title, List<MapEntry<String, String>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.blue[700],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!, width: 0.5),
          ),
          child: Column(
            children: items
                .map((item) => _buildInfoRow(item.key, item.value))
                .toList(),
          ),
        ),
      ],
    );
  }

  /// Helper method to build info rows with consistent styling
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Get status color based on status value
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
        return const Color(0xFFFFA41C)
            .withOpacity(0.15); // Pending / Submitted - Yellow
      default:
        return Colors.grey.withOpacity(0.15);
    }
  }

  /// Get status display text with fallbacks
  String _getStatusDisplayText(TourPlanItem item) {
    // First try statusText
    if (item.statusText != null && item.statusText!.trim().isNotEmpty) {
      return item.statusText!.trim();
    }

    // Fallback to tourPlanStatus
    if (item.tourPlanStatus != null && item.tourPlanStatus!.trim().isNotEmpty) {
      return item.tourPlanStatus!.trim();
    }

    // Fallback to deriving from status ID
    switch (item.status) {
      case 5:
        return 'Approved';
      case 4:
        return 'Sent Back';
      case 3:
        return 'Rejected';
      case 2:
      case 1:
        return 'Pending';
      case 0:
        return 'Draft';
      default:
        return 'Unknown';
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  /// Build aggregate count summary display
  Widget _buildAggregateCountSummary(TourPlanAggregateCountResponse data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal scrollable list of summary cards
        SizedBox(
          height: 120, // Fixed height for horizontal cards
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildHorizontalSummaryCard(
                  'Total Employees', data.totalEmployees, Colors.blue),
              const SizedBox(width: 8),
              _buildHorizontalSummaryCard(
                  'Planned', data.planned, Colors.green),
              const SizedBox(width: 8),
              _buildHorizontalSummaryCard(
                  'Approved', data.approved, Colors.teal),
              const SizedBox(width: 8),
              _buildHorizontalSummaryCard(
                  'Pending', data.pending, Colors.orange),
              const SizedBox(width: 8),
              _buildHorizontalSummaryCard(
                  'Send Back', data.sendBack, Colors.red),
              const SizedBox(width: 8),
              _buildHorizontalSummaryCard(
                  'Not Entered', data.notEntered, Colors.grey),
              const SizedBox(width: 8),
              _buildHorizontalSummaryCard(
                  'Leave Count', data.leaveCount, Colors.purple),
            ],
          ),
        ),
      ],
    );
  }

  /// Build individual summary card
  Widget _buildSummaryCard(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              value.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Build horizontal summary card for horizontal list
  Widget _buildHorizontalSummaryCard(String label, int value, Color color) {
    return Container(
      width: 100, // Fixed width for horizontal cards
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Build legend items for calendar using employee list summary data
  List<CalendarLegendItem> _buildLegendItems() {
    // Use employee list summary data if available, otherwise fallback to default values
    if (_store.employeeListSummaryData != null &&
        _store.employeeListSummaryData
            is TourPlanGetEmployeeListSummaryResponse) {
      final data = _store.employeeListSummaryData
          as TourPlanGetEmployeeListSummaryResponse;
      return [
        CalendarLegendItem(
            label: 'Total Employee',
            color: const Color(0xFF1976D2),
            count: data.totalEmployees),
        CalendarLegendItem(
            label: 'Approved',
            color: const Color(0xFF2DBE64),
            count: data.totalApproved),
        CalendarLegendItem(
            label: 'Send Back',
            color: Colors.redAccent,
            count: data.totalSentBack),
        CalendarLegendItem(
            label: 'Planned',
            color: const Color(0xFF2B78FF),
            count: data.totalPlanned),
        CalendarLegendItem(
            label: 'Pending',
            color: const Color(0xFFFFA41C),
            count: data.totalPending),
        CalendarLegendItem(
            label: 'Not Entered',
            color: Colors.grey,
            count: data.totalNotEntered),
        CalendarLegendItem(
            label: 'Leave', color: Colors.purple, count: data.totalLeave),
      ];
    } else {
      // Fallback to default values when no data is available
      return const [
        CalendarLegendItem(
            label: 'Total Employee', color: Color(0xFF1976D2), count: 0),
        CalendarLegendItem(
            label: 'Approved', color: Color(0xFF2DBE64), count: 0),
        CalendarLegendItem(
            label: 'Send Back', color: Colors.redAccent, count: 0),
        CalendarLegendItem(
            label: 'Planned', color: Color(0xFF2B78FF), count: 0),
        CalendarLegendItem(
            label: 'Pending', color: Color(0xFFFFA41C), count: 0),
        CalendarLegendItem(label: 'Not Entered', color: Colors.grey, count: 0),
        CalendarLegendItem(label: 'Leave', color: Colors.purple, count: 0),
      ];
    }
  }

  /// Build tour plan summary display
  Widget _buildTourPlanSummaryDisplay(TourPlanGetSummaryResponse data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary stats in a grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _buildSummaryCard('Planned Days', data.planedDays, Colors.blue),
            _buildSummaryCard('Approved Days', data.approvedDays, Colors.green),
            _buildSummaryCard('Pending Days', data.pendingDays, Colors.orange),
            _buildSummaryCard('Sent Back Days', data.sentBackDays, Colors.red),
          ],
        ),
        const SizedBox(height: 16),
        // Summary statistics
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly Summary Statistics',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryStat(
                      'Total Planned', data.planedDays, Colors.blue),
                  _buildSummaryStat(
                      'Total Approved', data.approvedDays, Colors.green),
                  _buildSummaryStat(
                      'Total Pending', data.pendingDays, Colors.orange),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryStat(
                      'Total Sent Back', data.sentBackDays, Colors.red),
                  _buildSummaryStat('Approval Rate',
                      _calculateApprovalRate(data), Colors.teal),
                  _buildSummaryStat('Completion Rate',
                      _calculateCompletionRate(data), Colors.purple),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build summary stat item
  Widget _buildSummaryStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Calculate approval rate percentage
  int _calculateApprovalRate(TourPlanGetSummaryResponse data) {
    final total = data.planedDays;
    if (total == 0) return 0;
    return ((data.approvedDays / total) * 100).round();
  }

  /// Calculate completion rate percentage
  int _calculateCompletionRate(TourPlanGetSummaryResponse data) {
    final total = data.planedDays;
    if (total == 0) return 0;
    return (((data.approvedDays + data.sentBackDays) / total) * 100).round();
  }

  /// Build manager summary display
  Widget _buildManagerSummaryDisplay(TourPlanGetManagerSummaryResponse data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Employee overview stats
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _buildSummaryCard(
                'Total Employees', data.totalEmployees, Colors.blue),
            _buildSummaryCard('Not Planned Employees', data.notPlannedEmployees,
                Colors.orange),
            _buildSummaryCard(
                'Fully Approved', data.fullyApproved, Colors.green),
            _buildSummaryCard(
                'Partially Approved', data.partiallyApprovedCount, Colors.teal),
          ],
        ),
        const SizedBox(height: 16),
        // Detailed breakdown
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detailed Breakdown',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryStat(
                      'Total Planned', data.totalPlanned, Colors.blue),
                  _buildSummaryStat(
                      'Total Approved', data.totalApproved, Colors.green),
                  _buildSummaryStat(
                      'Total Pending', data.totalPending, Colors.orange),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryStat(
                      'Total Sent Back', data.totalSentBack, Colors.red),
                  _buildSummaryStat(
                      'Total Leave', data.totalLeave, Colors.purple),
                  _buildSummaryStat(
                      'Total Not Entered', data.totalNotEntered, Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              // Additional metrics
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Additional Metrics',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryStat(
                            'Approved Days', data.approvedDays, Colors.green),
                        _buildSummaryStat('Partial Mixed Status',
                            data.partialMixedStatus, Colors.amber),
                        _buildSummaryStat(
                            'Not Planned', data.notPlanned, Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build employee list summary display
  Widget _buildEmployeeListSummaryDisplay(
      TourPlanGetEmployeeListSummaryResponse data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Employee overview stats
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _buildSummaryCard(
                'Total Employees', data.totalEmployees, Colors.blue),
            _buildSummaryCard('Not Planned Employees', data.notPlannedEmployees,
                Colors.orange),
            _buildSummaryCard(
                'Fully Approved', data.fullyApproved, Colors.green),
            _buildSummaryCard(
                'Partially Approved', data.partiallyApprovedCount, Colors.teal),
          ],
        ),
        const SizedBox(height: 16),
        // Detailed breakdown
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Employee Tour Plan Breakdown',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryStat(
                      'Total Planned', data.totalPlanned, Colors.blue),
                  _buildSummaryStat(
                      'Total Approved', data.totalApproved, Colors.green),
                  _buildSummaryStat(
                      'Total Pending', data.totalPending, Colors.orange),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryStat(
                      'Total Sent Back', data.totalSentBack, Colors.red),
                  _buildSummaryStat(
                      'Total Leave', data.totalLeave, Colors.purple),
                  _buildSummaryStat(
                      'Total Not Entered', data.totalNotEntered, Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              // Additional metrics
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Employee Performance Metrics',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.green[800],
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryStat(
                            'Approved Days', data.approvedDays, Colors.green),
                        _buildSummaryStat('Partial Mixed Status',
                            data.partialMixedStatus, Colors.amber),
                        _buildSummaryStat(
                            'Not Planned', data.notPlanned, Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build display widget for mapped customers
  Widget _buildMappedCustomersDisplay(List<MappedCustomer> customers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total Mapped Customers: ${customers.length}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.blue[800],
              ),
        ),
        const SizedBox(height: 12),
        if (customers.isNotEmpty) ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        customer.isActive ? Colors.green : Colors.grey,
                    child: Text(
                      customer.customerName.isNotEmpty
                          ? customer.customerName[0].toUpperCase()
                          : 'C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    customer.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cluster: ${customer.clusterName}'),
                      if (customer.territory != null)
                        Text('Territory: ${customer.territory}'),
                      if (customer.contactNumber != null)
                        Text('Contact: ${customer.contactNumber}'),
                      if (customer.lastVisitDate != null)
                        Text(
                            'Last Visit: ${_formatDate(customer.lastVisitDate!)}'),
                    ],
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: customer.isActive ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      customer.isActive ? 'Active' : 'Inactive',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'No mapped customers found for the selected employee.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ],
    );
  }

  /// Add comment to a pending tour plan
  Future<void> _addCommentToTourPlan(TourPlanItem item) async {
    try {
      // Use item.id (not item.tourPlanId) for both GetList and Save APIs
      // GetList API expects: {"id": <tour_plan_item_id>}
      // Save API expects: {"TourPlanId": <tour_plan_item_id>}
      final int tourPlanItemId = item.id;
      print(
          'TourPlanScreen: Adding comment to tour plan - Item ID: ${item.id}, Item tourPlanId: ${item.tourPlanId}');
      print(
          'TourPlanScreen: Using item.id ($tourPlanItemId) for both GetList and Save APIs');

      // Open comment dialog with previous comments
      await _openTourPlanCommentsDialog(context, id: tourPlanItemId);
    } catch (e) {
      print('TourPlanScreen: Error opening comment dialog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  /// Save a tour plan comment
  Future<void> _saveTourPlanComment({
    required int tourPlanId,
    required String comment,
  }) async {
    try {
      print('TourPlanScreen: Saving tour plan comment for ID: $tourPlanId');

      // Get user ID from UserDetailStore (use id field which is non-nullable)
      // Fallback to UserStore (login response) if UserDetailStore is not loaded
      int? userId;

      if (_userDetailStore.userDetail != null) {
        // Use id field (non-nullable) or userId field if available
        userId = _userDetailStore.userDetail!.userId ??
            _userDetailStore.userDetail!.id;
        print(
            'TourPlanScreen: Got userId from UserDetailStore: $userId (id: ${_userDetailStore.userDetail!.id}, userId: ${_userDetailStore.userDetail!.userId})');
      } else {
        // Fallback to UserStore (login response) - this has the login API response
        final loginUserStore = getIt<login.UserStore>();
        userId = loginUserStore.currentUser?.userId ??
            loginUserStore.currentUser?.id;
        print(
            'TourPlanScreen: Got userId from UserStore (login): $userId (id: ${loginUserStore.currentUser?.id}, userId: ${loginUserStore.currentUser?.userId})');
      }

      if (userId == null || userId == 0) {
        print(
            'TourPlanScreen: User details not available for tour plan comment');
        if (mounted) {
          ToastMessage.show(
            context,
            message: 'User details not available. Please login again.',
            type: ToastType.error,
            duration: const Duration(seconds: 3),
          );
        }
        return;
      }

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
      final commentDate =
          '$year-$month-${day}T$hour:$minute:$second.${millisecond}';

      print('TourPlanScreen: Comment date (local time): $commentDate');
      print('TourPlanScreen: Current local time: ${now.toString()}');

      // Create request with hardcoded values: IsSystemGenerated = 0, Active = 1
      final request = TourPlanCommentSaveRequest(
        createdBy: userId, // CreatedBy = UserId
        tourPlanId: tourPlanId,
        comment: comment,
        commentDate: commentDate, // Format: "2025-11-10"
        isSystemGenerated: 0, // Hardcoded
        userId: userId, // UserId = UserId
        active: 1, // Hardcoded
        // tourPlanType is optional, not included in API requirement
      );

      print('TourPlanScreen: Comment save request: ${request.toJson()}');

      // Call API through store
      final response = await _store.saveTourPlanComment(request);

      print('TourPlanScreen: Comment saved successfully: ${response.comment}');

      // Show success message
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Comment saved successfully',
          type: ToastType.success,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      print('TourPlanScreen: Error saving tour plan comment: $e');
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Error saving comment: ${e.toString()}',
          type: ToastType.error,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  /// Get tour plan comments list
  /* Future<List<TourPlanCommentItem>> _getTourPlanCommentsList({
    required int tourPlanId,
    String tourPlanType = 'TP',
  }) async
  {
    try {
      print('TourPlanScreen: Getting comments list for tour plan ID: $tourPlanId');
      
      // Create request
      final request = TourPlanCommentGetListRequest(
        id: tourPlanId,
        tourPlanType: tourPlanType,
      );
      
      print('TourPlanScreen: Comments list request: ${request.toJson()}');
      
      // Call API through store (assuming we'll add this to TourPlanStore)
      // For now, we'll call the API client directly
      final apiClient = getIt<UserApiClient>();
      final token = 'your_token_here'; // TODO: Get from auth store
      
      final response = await apiClient.getTourPlanCommentsList(request, token);
      
      print('TourPlanScreen: Comments list response: ${response.length} comments');
      
      return response;
      
    } catch (e) {
      print('TourPlanScreen: Error getting tour plan comments list: $e');
      return [];
    }
  }*/

  /// Get tour plan comments list from API
  /// Note: The 'id' parameter here is the tour plan item's id (not tourPlanId field)
  Future<List<TourPlanCommentItem>> _getTourPlanCommentsList(int id) async {
    try {
      print('TourPlanScreen: Getting comments list for tour plan item ID: $id');

      // Create request with id (this is the tour plan item's id, not tourPlanId)
      // API expects: {"id": <tour_plan_item_id>}
      final request = TourPlanCommentGetListRequest(id: id);

      print('TourPlanScreen: Comments list request: ${request.toJson()}');

      // Call API through store (which uses repository)
      final comments = await _store.getTourPlanCommentsList(request);

      print(
          'TourPlanScreen: Comments list response received - ${comments.length} comments');

      // Log each comment for debugging
      for (int i = 0; i < comments.length; i++) {
        final comment = comments[i];
        print(
            'TourPlanScreen: Comment ${i + 1}: ID=${comment.id}, User=${comment.userName}, Date=${comment.commentDate}, Text="${comment.comment}"');
      }

      return comments;
    } catch (e, stackTrace) {
      print('TourPlanScreen: Error getting tour plan comments list: $e');
      print('TourPlanScreen: Stack trace: $stackTrace');
      return [];
    }
  }

  /// Open comprehensive comment dialog with previous comments and add comment section
  /// Note: The 'id' parameter is the tour plan item's id (not tourPlanId field)
  Future<void> _openTourPlanCommentsDialog(BuildContext context,
      {required int id}) async {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      // Use bottom sheet on mobile
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (dialogContext) => _TourPlanCommentsDialog(
          tourPlanId: id, // This is actually the tour plan item's id
          onGetComments: _getTourPlanCommentsList,
          onSaveComment: _saveTourPlanComment,
          onCommentAdded: () {
            // Refresh data after comment is added
            _refreshAll();
          },
        ),
      );
    } else {
      // Use dialog on tablet/desktop
      await showDialog(
        context: context,
        builder: (dialogContext) => _TourPlanCommentsDialog(
          tourPlanId: id, // This is actually the tour plan item's id
          onGetComments: _getTourPlanCommentsList,
          onSaveComment: _saveTourPlanComment,
          onCommentAdded: () {
            // Refresh data after comment is added
            _refreshAll();
          },
        ),
      );
    }
  }
}

/// Tour Plan Comments Dialog Widget
class _TourPlanCommentsDialog extends StatefulWidget {
  final int tourPlanId;
  final Future<List<TourPlanCommentItem>> Function(int) onGetComments;
  final Future<void> Function(
      {required int tourPlanId, required String comment}) onSaveComment;
  final VoidCallback? onCommentAdded;

  const _TourPlanCommentsDialog({
    required this.tourPlanId,
    required this.onGetComments,
    required this.onSaveComment,
    this.onCommentAdded,
  });

  @override
  State<_TourPlanCommentsDialog> createState() =>
      _TourPlanCommentsDialogState();
}

class _TourPlanCommentsDialogState extends State<_TourPlanCommentsDialog> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isSaving = false;
  List<TourPlanCommentItem> _comments = [];

  static const Color tealGreen = Color(0xFF4db1b3);

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await widget.onGetComments(widget.tourPlanId);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveComment() async {
    final commentText = _commentController.text.trim();

    // Validation: Check if comment is empty
    if (commentText.isEmpty) {
      ToastMessage.show(
        context,
        message: 'Please enter a comment',
        type: ToastType.warning,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // Validation: Check minimum length
    if (commentText.length < 3) {
      ToastMessage.show(
        context,
        message: 'Comment must be at least 3 characters long',
        type: ToastType.warning,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // Validation: Check maximum length
    if (commentText.length > 1000) {
      ToastMessage.show(
        context,
        message: 'Comment must be less than 1000 characters',
        type: ToastType.warning,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // Show saving indicator
    setState(() => _isSaving = true);

    try {
      // Save the comment (don't close dialog)
      await widget.onSaveComment(
        tourPlanId: widget.tourPlanId,
        comment: commentText,
      );

      // Clear the text field
      _commentController.clear();

      // Reload comments list to show the newly added comment
      await _loadComments();

      // Note: Success toast is shown by the parent _saveTourPlanComment method
    } catch (e) {
      // Note: Error toast is shown by the parent _saveTourPlanComment method
      // Re-throw to let parent handle the error toast
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenHeight = MediaQuery.of(context).size.height;

    // Use bottom sheet on mobile, dialog on tablet
    if (isMobile) {
      return DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                _buildHeader(isTablet: isTablet),
                Expanded(
                  child: _buildContent(
                    isTablet: isTablet,
                    isMobile: isMobile,
                    screenHeight: screenHeight,
                    scrollController: scrollController,
                  ),
                ),
                _buildActionButtons(isTablet: isTablet, isMobile: isMobile),
              ],
            ),
          );
        },
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: screenHeight * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isTablet: isTablet),
            // Content
            Flexible(
              child: _buildContent(
                isTablet: isTablet,
                isMobile: isMobile,
                screenHeight: screenHeight,
                scrollController: null,
              ),
            ),
            _buildActionButtons(isTablet: isTablet, isMobile: isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isTablet}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : 16,
        vertical: isTablet ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: tealGreen.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isTablet ? 40 : 32,
            height: isTablet ? 40 : 32,
            decoration: BoxDecoration(
              color: tealGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              color: tealGreen,
              size: isTablet ? 24 : 18,
            ),
          ),
          SizedBox(width: isTablet ? 12 : 10),
          Expanded(
            child: Text(
              'Tour Plan Comments',
              style: GoogleFonts.inter(
                color: Colors.grey[900],
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon:
                Icon(Icons.close, color: Colors.grey, size: isTablet ? 24 : 20),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent({
    required bool isTablet,
    required bool isMobile,
    required double screenHeight,
    ScrollController? scrollController,
  }) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.only(
        left: isTablet ? 20 : 14,
        right: isTablet ? 20 : 14,
        top: isTablet ? 16 : 12,
        bottom: 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Previous Comments Section
          Row(
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: isTablet ? 20 : 18, color: tealGreen),
              SizedBox(width: isTablet ? 8 : 6),
              Flexible(
                child: Text(
                  'Previous Comments (${_comments.length})',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 12 : 10),

          // Comments List with Scrollbar
          if (_isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
                child: CircularProgressIndicator(
                  color: tealGreen,
                ),
              ),
            )
          else if (_comments.isEmpty)
            Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: isTablet ? 48 : 40, color: Colors.grey[400]),
                    SizedBox(height: isTablet ? 12 : 10),
                    Text(
                      'No comments yet',
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: isTablet ? 14 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: isTablet ? 4 : 3),
                    Text(
                      'Be the first to comment!',
                      style: GoogleFonts.inter(
                        color: Colors.grey[500],
                        fontSize: isTablet ? 12 : 11,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              constraints: BoxConstraints(
                maxHeight:
                    isMobile ? screenHeight * 0.18 : (isTablet ? 220 : 180),
              ),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: _scrollController,
                  shrinkWrap: true,
                  padding: EdgeInsets.all(isTablet ? 8 : 6),
                  itemCount: _comments.length,
                  separatorBuilder: (context, index) =>
                      SizedBox(height: isTablet ? 8 : 6),
                  itemBuilder: (context, index) {
                    return _buildCommentItem(_comments[index],
                        isTablet: isTablet);
                  },
                ),
              ),
            ),

          SizedBox(height: isTablet ? 16 : 12),

          // Add Comment Section
          Row(
            children: [
              Icon(Icons.add_comment,
                  size: isTablet ? 20 : 18, color: tealGreen),
              SizedBox(width: isTablet ? 8 : 6),
              Flexible(
                child: Text(
                  'Add Comment *',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 12 : 10),

          TextField(
            controller: _commentController,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 14 : 13,
            ),
            decoration: InputDecoration(
              hintText: 'Enter your comment...',
              hintStyle: GoogleFonts.inter(
                color: Colors.grey[400],
                fontSize: isTablet ? 14 : 13,
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
                borderSide: BorderSide(color: tealGreen, width: 2),
              ),
              contentPadding: EdgeInsets.all(isTablet ? 16 : 14),
              errorText: _commentController.text.trim().isEmpty &&
                      _commentController.text.isNotEmpty
                  ? 'Comment is required'
                  : null,
              helperText: 'Minimum 3 characters, maximum 1000 characters',
              helperStyle: GoogleFonts.inter(
                fontSize: isTablet ? 12 : 11,
                color: Colors.grey[600],
              ),
              helperMaxLines: 2,
            ),
            maxLines: isMobile ? 3 : 4,
            minLines: isMobile ? 2 : 3,
            maxLength: 1000,
            onChanged: (value) {
              setState(() {});
            },
          ),
          if (!isMobile) SizedBox(height: isTablet ? 6 : 4),
          if (!isMobile)
            Text(
              'Please provide your comment for this tour plan.',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 12 : 11,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons({required bool isTablet, required bool isMobile}) {
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(
        left: isTablet ? 20 : 14,
        right: isTablet ? 20 : 14,
        top: isTablet ? 16 : 0,
        bottom: isMobile
            ? (safeAreaBottom > 0 ? safeAreaBottom : 6)
            : (isTablet ? 20 : 14),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: isMobile
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveComment,
                    icon: _isSaving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.add, size: 18),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Add Comment',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: tealGreen,
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
                      disabledBackgroundColor: tealGreen.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isTablet ? 10 : 4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: isTablet ? 14 : 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 12 : 10),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveComment,
                  icon: _isSaving
                      ? SizedBox(
                          width: isTablet ? 18 : 16,
                          height: isTablet ? 18 : 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.add, size: isTablet ? 18 : 16),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Add Comment',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: isTablet ? 14 : 13,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: tealGreen,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 16,
                      vertical: isTablet ? 12 : 10,
                    ),
                    disabledBackgroundColor: tealGreen.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCommentItem(TourPlanCommentItem comment,
      {required bool isTablet}) {
    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 12 : 10),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar
          Container(
            width: isTablet ? 40 : 36,
            height: isTablet ? 40 : 36,
            decoration: BoxDecoration(
              color: tealGreen.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                comment.userName.isNotEmpty
                    ? comment.userName[0].toUpperCase()
                    : 'U',
                style: GoogleFonts.inter(
                  color: tealGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: isTablet ? 16 : 14,
                ),
              ),
            ),
          ),
          SizedBox(width: isTablet ? 12 : 10),
          // Comment Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.userName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: isTablet ? 14 : 13,
                          color: Colors.grey[900],
                          letterSpacing: -0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: isTablet ? 8 : 6),
                    Flexible(
                      child: Text(
                        _formatCommentDate(comment.commentDate),
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 12 : 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isTablet ? 8 : 6),
                Text(
                  comment.comment,
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 14 : 13,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCommentDate(DateTime date) {
    // Convert UTC date to local time for display
    final localDate = date.isUtc ? date.toLocal() : date;
    final now = DateTime.now();
    final difference = now.difference(localDate);

    if (difference.inDays == 0) {
      // Today - show time
      final hour = localDate.hour > 12
          ? localDate.hour - 12
          : (localDate.hour == 0 ? 12 : localDate.hour);
      final minute = localDate.minute.toString().padLeft(2, '0');
      final period = localDate.hour >= 12 ? 'PM' : 'AM';
      return 'Today at $hour:$minute $period';
    } else if (difference.inDays == 1) {
      // Yesterday
      final hour = localDate.hour > 12
          ? localDate.hour - 12
          : (localDate.hour == 0 ? 12 : localDate.hour);
      final minute = localDate.minute.toString().padLeft(2, '0');
      final period = localDate.hour >= 12 ? 'PM' : 'AM';
      return 'Yesterday at $hour:$minute $period';
    } else {
      // Format as "Nov 10, 2025 at 03:09 PM"
      final months = [
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
      final month = months[localDate.month - 1];
      final day = localDate.day;
      final year = localDate.year;
      final hour = localDate.hour > 12
          ? localDate.hour - 12
          : (localDate.hour == 0 ? 12 : localDate.hour);
      final minute = localDate.minute.toString().padLeft(2, '0');
      final period = localDate.hour >= 12 ? 'PM' : 'AM';
      return '$month $day, $year at $hour:$minute $period';
    }
  }

  /// Load comments for a specific tour plan
  /*Future<void> _loadTourPlanComments(int tourPlanId) async {
    try {
      print('TourPlanScreen: Loading comments for tour plan ID: $tourPlanId');
      
      final comments = await _getTourPlanCommentsList(tourPlanId: tourPlanId);
      
      print('TourPlanScreen: Loaded ${comments.length} comments');
      
      // Log each comment for debugging
      for (int i = 0; i < comments.length; i++) {
        final comment = comments[i];
        print('Comment ${i + 1}: ${comment.userName} - ${comment.comment} (${comment.commentDate})');
      }
      
    } catch (e) {
      print('TourPlanScreen: Error loading tour plan comments: $e');
    }
  }*/
}

// ===== Helpers copied from CRM Tour Plan list for filters, pickers, and day list =====

const String kFilterClearToken = '__CLEAR__';

class _FilterPill extends StatelessWidget {
  const _FilterPill(
      {required this.icon, required this.label, this.onTap, this.onLongPress});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  @override
  Widget build(BuildContext context) {
    final Color border = Theme.of(context).dividerColor.withOpacity(.25);
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

Future<String?> _pickFromList(BuildContext context,
    {required String title,
    required List<String> options,
    String? selected,
    bool searchable = false}) async {
  // If searchable is true or options list is large, use searchable version
  final bool useSearch = searchable || options.length > 10;

  if (useSearch) {
    return _pickFromListSearchable(context,
        title: title, options: options, selected: selected);
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
                Expanded(
                    child: Text(title,
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700))),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx))
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
                trailing: options[i] == selected
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
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

Future<String?> _pickFromListSearchable(BuildContext context,
    {required String title,
    required List<String> options,
    String? selected}) async {
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
  State<_SearchableListBottomSheet> createState() =>
      _SearchableListBottomSheetState();
}

class _SearchableListBottomSheetState
    extends State<_SearchableListBottomSheet> {
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
        _filteredOptions = widget.options
            .where((option) => option.toLowerCase().contains(query))
            .toList();
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
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      itemBuilder: (c, i) => ListTile(
                        title: Text(_filteredOptions[i]),
                        trailing: _filteredOptions[i] == widget.selected
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () =>
                            Navigator.pop(context, _filteredOptions[i]),
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

Future<Set<String>?> _pickMultipleFromList(BuildContext context,
    {required String title,
    required List<String> options,
    required Set<String> initiallySelected}) async {
  final Set<String> temp = {...initiallySelected};
  return showModalBottomSheet<Set<String>>(
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
                Expanded(
                    child: Text(title,
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, <String>{}),
                    child: const Text('Clear')),
                const SizedBox(width: 4),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, temp),
                    child: const Text('Apply')),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: options.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final opt = options[i];
                final selected = temp.contains(opt);
                return ListTile(
                  onTap: () {
                    if (selected) {
                      temp.remove(opt);
                    } else {
                      temp.add(opt);
                    }
                    (context as Element).markNeedsBuild();
                  },
                  leading: Checkbox(
                      value: selected,
                      onChanged: (_) {
                        if (selected) {
                          temp.remove(opt);
                        } else {
                          temp.add(opt);
                        }
                        (context as Element).markNeedsBuild();
                      }),
                  title: Text(opt),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _DayPlansCard extends StatelessWidget {
  const _DayPlansCard(
      {required this.date, required this.entries, required this.onEdit});
  final DateTime date;
  final List<domain.TourPlanEntry> entries;
  final void Function(domain.TourPlanEntry entry) onEdit;
  @override
  Widget build(BuildContext context) {
    final String label =
        '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                  child: Text('Planned Calls on $label',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 12),
            ...entries.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PlanRow(
                      index: e.key + 1,
                      entry: e.value,
                      onEdit: () => onEdit(e.value)),
                )),
          ],
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow(
      {required this.index, required this.entry, required this.onEdit});
  final int index;
  final domain.TourPlanEntry entry;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF6F7FA),
          borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(radius: 16, child: Text('$index')),
          const SizedBox(width: 12),
          Expanded(
              child: Text(
                  '${entry.customer} • ${entry.callDetails.purposes.isNotEmpty ? entry.callDetails.purposes.join(', ') : 'No purpose'}')),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: _statusColor(entry.status).withOpacity(.15),
                borderRadius: BorderRadius.circular(20)),
            child: Text(_statusText(entry.status)),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onEdit, child: const Text('Edit')),
        ],
      ),
    );
  }

  Color _statusColor(domain.TourPlanEntryStatus s) {
    switch (s) {
      case domain.TourPlanEntryStatus.approved:
        return const Color(0xFF2DBE64);
      case domain.TourPlanEntryStatus.pending:
      case domain.TourPlanEntryStatus.sentBack:
        return const Color(0xFFFFA41C);
      case domain.TourPlanEntryStatus.draft:
      case domain.TourPlanEntryStatus.rejected:
      default:
        return const Color(0xFFFFA41C);
    }
  }

  String _statusText(domain.TourPlanEntryStatus s) {
    switch (s) {
      case domain.TourPlanEntryStatus.draft:
        return 'Draft';
      case domain.TourPlanEntryStatus.pending:
        return 'Pending';
      case domain.TourPlanEntryStatus.approved:
        return 'Approved';
      case domain.TourPlanEntryStatus.sentBack:
        return 'Sent Back';
      case domain.TourPlanEntryStatus.rejected:
        return 'Rejected';
    }
  }
}

Color _statusColor(domain.TourPlanEntryStatus s) {
  switch (s) {
    case domain.TourPlanEntryStatus.approved:
      return const Color(0xFF2DBE64);
    case domain.TourPlanEntryStatus.pending:
    case domain.TourPlanEntryStatus.sentBack:
      return const Color(0xFFFFA41C);
    case domain.TourPlanEntryStatus.rejected:
      return Colors.redAccent;
    case domain.TourPlanEntryStatus.draft:
    default:
      return Colors.grey;
  }
}

class _FiltersBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _OutlinedChip(child: const Text('MR. John Doe')),
        _OutlinedChip(child: const Text('All Customers')),
        _OutlinedChip(child: const Text('Status: All')),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Map<TourPlanStatus, int> counts = {
      TourPlanStatus.planned: 1,
      TourPlanStatus.pending: 1,
      TourPlanStatus.approved: 0,
      TourPlanStatus.leaveDays: 3,
      TourPlanStatus.notEntered: 14,
    };

    return MonthlyStatusSummary(
      counts: counts,
      initiallyExpanded: true,
      onFilterChanged: (statuses) {},
    );
  }
}

class _CalendarSection extends StatefulWidget {
  @override
  State<_CalendarSection> createState() => _CalendarSectionState();
}

class _CalendarSectionState extends State<_CalendarSection> {
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    // Demo mapping to match the screenshot-like look
    const Color green = Color(0xFF2DBE64); // Approved
    const Color red = Color(0xFFFF6A21); // Sent
    const Color blue = Color(0xFF2B78FF); // Paneled
    const Color yellow = Color(0xFFFFA41C); // Draft/Pending

    final Map<DateTime, CalendarDayDecoration> decorations =
        <DateTime, CalendarDayDecoration>{
      DateTime(_focusedDay.year, _focusedDay.month, 1):
          const CalendarDayDecoration(backgroundColor: green),
      DateTime(_focusedDay.year, _focusedDay.month, 2):
          const CalendarDayDecoration(backgroundColor: yellow),
      DateTime(_focusedDay.year, _focusedDay.month, 21):
          const CalendarDayDecoration(backgroundColor: blue),
      DateTime(_focusedDay.year, _focusedDay.month, 22):
          const CalendarDayDecoration(backgroundColor: yellow),
      DateTime(_focusedDay.year, _focusedDay.month, 23):
          const CalendarDayDecoration(backgroundColor: yellow),
      DateTime(_focusedDay.year, _focusedDay.month, 24):
          const CalendarDayDecoration(backgroundColor: yellow),
    };

    final List<CalendarLegendItem> legend = const <CalendarLegendItem>[
      CalendarLegendItem(label: 'Approved', color: green, count: 1),
      CalendarLegendItem(label: 'Sent', color: red, count: 1),
      CalendarLegendItem(label: 'Planned', color: blue, count: 1),
      CalendarLegendItem(label: 'Draft/Ped..', color: yellow, count: 1),
    ];

    final String summary = _daysAndHolidaysLabel(_focusedDay)
        .replaceAll('|', '\u00A0|\u00A0Holidays:');

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: Colors.black.withOpacity(.06)),
      ),
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return MonthCalendar(
              width: constraints.maxWidth,
              visibleMonth: DateTime(_focusedDay.year, _focusedDay.month, 1),
              onMonthChanged: (m) => setState(() => _focusedDay = m),
              summaryText: _daysAndHolidaysLabel(_focusedDay),
              cellSpacing: 10,
              cellCornerRadius: 12,
              dayDecorations: decorations,
              legendItems: legend,
            );
          },
        ),
      ),
    );
  }

  void _openMonthPicker() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (context) => _MonthPickerSheet(initial: _focusedDay),
    );
    if (picked != null) {
      setState(() => _focusedDay = DateTime(picked.year, picked.month, 1));
    }
  }

  _DayStatus _statusForDay(int d) {
    // No longer used in the simplified MonthCalendar view, kept for reference.
    return const _DayStatus(
        label: '', color: Colors.transparent, calls: 0, window: '');
  }
}

class _DayCard extends StatelessWidget {
  final int day;
  final _DayStatus status;
  const _DayCard({required this.day, required this.status});

  @override
  Widget build(BuildContext context) {
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(.4)),
    );
    final tooltip = status.label.isEmpty
        ? ''
        : '${status.label}  •  ${status.calls} calls\n${status.window}';
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        shape: border,
        child: InkWell(
          onTap: () {},
          customBorder: border,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(day.toString(),
                        style: Theme.of(context).textTheme.bodyLarge),
                    const Spacer(),
                    if (status.calls > 0)
                      Text('${status.calls} calls',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Colors.grey[600])),
                  ],
                ),
                const Spacer(),
                if (status.label.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: status.color.withOpacity(.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                          color: status.color, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  final int day;
  final _DayStatus status;
  final bool selected;
  final bool highlight;
  const _CalendarCell(
      {required this.day,
      required this.status,
      required this.selected,
      required this.highlight});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg =
        selected ? colorScheme.primary.withOpacity(.08) : Colors.transparent;
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: highlight
            ? colorScheme.primary.withOpacity(.35)
            : Theme.of(context).dividerColor.withOpacity(.25),
      ),
    );
    final tooltip = status.label.isEmpty
        ? ''
        : '${status.label}  •  ${status.calls} calls\n${status.window}';
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Material(
        color: bg,
        shape: border,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('$day', style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  if (status.calls > 0) _CallsCounterSmall(count: status.calls),
                ],
              ),
              const SizedBox(height: 2),
              if (status.label.isNotEmpty)
                _StatusBadge(label: status.label, color: status.color),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallsPill extends StatelessWidget {
  final int count;
  const _CallsPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(.15),
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 0),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$count calls',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: Colors.grey[700], fontSize: 10),
        ),
      ),
    );
  }
}

/// Ultra-compact counter: "3c" style to avoid any overflow
class _CallsCounterSmall extends StatelessWidget {
  final int count;
  const _CallsCounterSmall({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${count}c',
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey[800],
              fontSize: 9,
              letterSpacing: .1,
            ),
      ),
    );
  }
}

/// Tiny status badge with fixed max width to never overflow
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 60),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 9.5),
        ),
      ),
    );
  }
}

class _MonthPickerSheet extends StatefulWidget {
  final DateTime initial;
  const _MonthPickerSheet({required this.initial});

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late DateTime _cursor;

  static const Color tealGreen = Color(0xFF4db1b3);

  @override
  void initState() {
    super.initState();
    _cursor = DateTime(widget.initial.year, widget.initial.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() =>
                      _cursor = DateTime(_cursor.year - 1, _cursor.month, 1)),
                  icon: Icon(Icons.chevron_left, color: tealGreen),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_cursor.year}',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() =>
                      _cursor = DateTime(_cursor.year + 1, _cursor.month, 1)),
                  icon: Icon(Icons.chevron_right, color: tealGreen),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 600;
                final isSmallMobile = constraints.maxWidth < 400;
                // Adjust aspect ratio based on screen size to prevent text overlap
                final childAspectRatio =
                    isTablet ? 3.2 : (isSmallMobile ? 2.5 : 2.8);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, i) {
                    final date = DateTime(_cursor.year, i + 1, 1);
                    final selected = date.year == widget.initial.year &&
                        date.month == widget.initial.month;
                    return OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selected
                            ? tealGreen.withOpacity(0.1)
                            : Colors.white,
                        side: BorderSide(
                          color: selected
                              ? tealGreen.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.3),
                          width: selected ? 1.5 : 1,
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 8 : (isSmallMobile ? 2 : 4),
                          vertical: isTablet ? 12 : (isSmallMobile ? 8 : 10),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.of(context).pop(date),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            _monthShort(i + 1),
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w500,
                              color: selected
                                  ? tealGreen
                                  : tealGreen.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.visible,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

String _monthShort(int month) {
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

class _CalendarHeader extends StatelessWidget {
  final String monthLabel;
  final String? subtitle;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPickMonth;
  const _CalendarHeader(
      {required this.monthLabel,
      required this.onPrev,
      required this.onNext,
      required this.onPickMonth,
      this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: InkWell(
            onTap: onPickMonth,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          monthLabel,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.black54),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

class _CircleDay extends StatelessWidget {
  final DateTime day;
  final Color color;
  final bool filled;
  final bool disabled;
  final bool dot;
  const _CircleDay(
      {required this.day,
      required this.color,
      required this.filled,
      required this.disabled,
      required this.dot});

  @override
  Widget build(BuildContext context) {
    final bg = filled ? color.withOpacity(.15) : Colors.transparent;
    final fg = filled ? color : (disabled ? Colors.black38 : color);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
          ),
          alignment: Alignment.center,
          child: Text('${day.day}',
              style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
        ),
        if (dot)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          ),
      ],
    );
  }
}

String _monthName(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  return '${months[date.month - 1]} ${date.year}';
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
    final weekday = DateTime(date.year, date.month, d).weekday; // 1=Mon..7=Sun
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      weekends++;
    }
  }
  return weekends;
}

class _DayStatus {
  final String label;
  final Color color;
  final int calls;
  final String window;
  const _DayStatus(
      {required this.label,
      required this.color,
      required this.calls,
      required this.window});
}

class _OutlinedChip extends StatelessWidget {
  final Widget child;
  const _OutlinedChip({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(.4)),
      ),
      child: child,
    );
  }
}

class _SpendBreakdownCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Unused after introducing StatusByCategoryCard & StatusDonutCard. Kept for reference.
    return const SizedBox.shrink();
  }
}

class _CategoryAndDonutRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Map<String, Map<TourPlanStatus, int>> byCategory = {
      'Shopping': {
        TourPlanStatus.planned: 2,
        TourPlanStatus.pending: 1,
        TourPlanStatus.approved: 3,
        TourPlanStatus.leaveDays: 0,
        TourPlanStatus.notEntered: 1,
      },
      'Device': {
        TourPlanStatus.planned: 1,
        TourPlanStatus.pending: 2,
        TourPlanStatus.approved: 1,
        TourPlanStatus.leaveDays: 0,
        TourPlanStatus.notEntered: 2,
      },
      'Grocery': {
        TourPlanStatus.planned: 1,
        TourPlanStatus.pending: 0,
        TourPlanStatus.approved: 1,
        TourPlanStatus.leaveDays: 1,
        TourPlanStatus.notEntered: 1,
      },
    };

    final Map<TourPlanStatus, int> overall = {
      TourPlanStatus.planned: 4,
      TourPlanStatus.pending: 3,
      TourPlanStatus.approved: 5,
      TourPlanStatus.leaveDays: 1,
      TourPlanStatus.notEntered: 4,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stacked = constraints.maxWidth < 800;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            //   Expanded(child: StatusByCategoryCard(data: {
            //     'Shopping': {
            //       TourPlanStatus.planned: 2,
            //       TourPlanStatus.pending: 1,
            //       TourPlanStatus.approved: 3,
            //       TourPlanStatus.leaveDays: 0,
            //       TourPlanStatus.notEntered: 1,
            //     },
            //     'Device': {
            //       TourPlanStatus.planned: 1,
            //       TourPlanStatus.pending: 2,
            //       TourPlanStatus.approved: 1,
            //       TourPlanStatus.leaveDays: 0,
            //       TourPlanStatus.notEntered: 2,
            //     },
            //     'Grocery': {
            //       TourPlanStatus.planned: 1,
            //       TourPlanStatus.pending: 0,
            //       TourPlanStatus.approved: 1,
            //       TourPlanStatus.leaveDays: 1,
            //       TourPlanStatus.notEntered: 1,
            //     },
            //   }, title: 'By Category')),
            SizedBox(width: 12),
            Expanded(
                child: StatusDonutCard(counts: {
              TourPlanStatus.planned: 4,
              TourPlanStatus.pending: 3,
              TourPlanStatus.approved: 5,
              TourPlanStatus.leaveDays: 1,
              TourPlanStatus.notEntered: 4,
            }, title: 'Monthly Status Summary')),
          ],
        );
      },
    );
  }
}

// Helper widgets for enhanced filter UI
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

  static const Color tealGreen = Color(0xFF4db1b3);

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final Color backgroundColor =
        isActive ? tealGreen.withOpacity(0.12) : Colors.grey[50]!;
    final Color iconColor = isActive ? tealGreen : Colors.grey[600]!;
    final Color textColor = isActive ? tealGreen : Colors.grey[700]!;
    final Color borderColor =
        isActive ? tealGreen.withOpacity(0.3) : Colors.grey[200]!;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      elevation: isActive ? 2 : 0,
      shadowColor: isActive ? tealGreen.withOpacity(0.2) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: tealGreen.withOpacity(0.1),
        highlightColor: tealGreen.withOpacity(0.05),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 14 : 12,
            vertical: isTablet ? 12 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: isTablet ? 18 : 16, color: iconColor),
              SizedBox(width: isTablet ? 8 : 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 14 : 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: textColor,
                    letterSpacing: -0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              SizedBox(width: isTablet ? 6 : 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: isTablet ? 18 : 16,
                color: iconColor,
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
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final Color backgroundColor =
        isActive ? Colors.red.shade50 : Colors.grey[100]!;
    final Color iconColor =
        isActive ? Colors.red.shade600 : Colors.grey.shade600;
    final Color textColor =
        isActive ? Colors.red.shade700 : Colors.grey.shade600;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      elevation: isActive ? 1 : 0,
      child: InkWell(
        onTap: isActive ? onPressed : null,
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.red.withOpacity(0.1),
        highlightColor: Colors.red.withOpacity(0.05),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 14 : 12,
            vertical: isTablet ? 12 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: isActive
                ? Border.all(color: Colors.red.shade200, width: 1)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.filter_alt_off_rounded,
                size: isTablet ? 18 : 16,
                color: iconColor,
              ),
              SizedBox(width: isTablet ? 6 : 4),
              Text(
                'Clear',
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 14 : 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Filter Icon Button with Badge
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

// Filter Modal with Fade-up Animation
class _FilterModal extends StatefulWidget {
  final String? customer;
  final String? status;
  final String? employee;
  final List<String> customerOptions;
  final List<String> statusOptions;
  final List<String> employeeOptions;
  final ValueChanged<String?> onCustomerChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onEmployeeChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final bool shouldDisableEmployeeFilter;

  const _FilterModal({
    required this.customer,
    required this.status,
    required this.employee,
    required this.customerOptions,
    required this.statusOptions,
    required this.employeeOptions,
    required this.onCustomerChanged,
    required this.onStatusChanged,
    required this.onEmployeeChanged,
    required this.onApply,
    required this.onClear,
    required this.shouldDisableEmployeeFilter,
  });

  @override
  State<_FilterModal> createState() => _FilterModalState();
}

class _FilterModalState extends State<_FilterModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  String? _tempCustomer;
  String? _tempStatus;
  String? _tempEmployee;

  static const Color tealGreen = Color(0xFF4db1b3);

  @override
  void initState() {
    super.initState();
    _tempCustomer = widget.customer;
    _tempStatus = widget.status;
    _tempEmployee = widget.employee;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleClose() {
    _controller.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _handleApply() {
    widget.onCustomerChanged(_tempCustomer);
    widget.onStatusChanged(_tempStatus);
    widget.onEmployeeChanged(_tempEmployee);
    _controller.reverse().then((_) {
      widget.onApply();
    });
  }

  void _handleClear() {
    setState(() {
      _tempCustomer = null;
      _tempStatus = null;
      _tempEmployee = null;
    });
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    // Better responsive sizing for tablets
    final modalHeight = isTablet
        ? (screenHeight * 0.65).clamp(500.0, 700.0)
        : screenHeight * 0.75;
    final modalWidth =
        isTablet ? (screenWidth * 0.6).clamp(500.0, 700.0) : screenWidth;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GestureDetector(
          onTap: _handleClose,
          child: Container(
            color: Colors.black.withOpacity(0.5 * _fadeAnimation.value),
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping inside modal
              child: Align(
                alignment: isTablet ? Alignment.center : Alignment.bottomCenter,
                child: Transform.translate(
                  offset: isTablet
                      ? Offset(
                          0,
                          (modalHeight * _slideAnimation.value) -
                              (screenHeight - modalHeight) / 2)
                      : Offset(0, modalHeight * _slideAnimation.value),
                  child: Container(
                    height: modalHeight,
                    width: modalWidth,
                    margin: isTablet
                        ? EdgeInsets.symmetric(
                            horizontal: (screenWidth - modalWidth) / 2)
                        : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: isTablet
                          ? BorderRadius.circular(28)
                          : const BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: EdgeInsets.all(isTablet ? 24 : 20),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Filters',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 22 : 20,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.grey[900],
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _handleClose,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: isTablet ? 40 : 36,
                                    height: isTablet ? 40 : 36,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: isTablet ? 22 : 20,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Filter Content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(isTablet ? 24 : 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Customer Filter - Searchable Dropdown
                                _SearchableFilterDropdown(
                                  title: 'Customer',
                                  icon: Icons.person_outline,
                                  selectedValue: _tempCustomer,
                                  options: widget.customerOptions,
                                  onChanged: (value) {
                                    setState(() {
                                      _tempCustomer = value;
                                    });
                                  },
                                  isTablet: isTablet,
                                ),
                                SizedBox(height: isTablet ? 24 : 20),
                                // Status Filter - Searchable Dropdown
                                _SearchableFilterDropdown(
                                  title: 'Status',
                                  icon: Icons.verified_outlined,
                                  selectedValue: _tempStatus,
                                  options: widget.statusOptions,
                                  onChanged: (value) {
                                    setState(() {
                                      _tempStatus = value;
                                    });
                                  },
                                  isTablet: isTablet,
                                ),
                                SizedBox(height: isTablet ? 24 : 20),
                                // Employee Filter - Searchable Dropdown
                                if (!widget.shouldDisableEmployeeFilter)
                                  _SearchableFilterDropdown(
                                    title: 'Employee',
                                    icon: Icons.badge_outlined,
                                    selectedValue: _tempEmployee,
                                    options: widget.employeeOptions,
                                    onChanged: (value) {
                                      setState(() {
                                        _tempEmployee = value;
                                      });
                                    },
                                    isTablet: isTablet,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Footer Buttons
                        Container(
                          padding: EdgeInsets.all(isTablet ? 24 : 20),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _handleClear,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: tealGreen,
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: isTablet ? 16 : 14,
                                    ),
                                  ),
                                  child: Text(
                                    'Clear',
                                    style: GoogleFonts.inter(
                                      fontSize: isTablet ? 16 : 15,
                                      fontWeight: FontWeight.w700,
                                      color: tealGreen,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: isTablet ? 16 : 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton(
                                  onPressed: _handleApply,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: tealGreen,
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shadowColor: tealGreen.withOpacity(0.4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: isTablet ? 16 : 14,
                                    ),
                                  ),
                                  child: Text(
                                    'Apply Filters',
                                    style: GoogleFonts.inter(
                                      fontSize: isTablet ? 16 : 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
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
                ),
              ),
            ),
          ),
        );
      },
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
  State<_SearchableFilterDropdown> createState() =>
      _SearchableFilterDropdownState();
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
                fontWeight: FontWeight.normal,
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
                          separatorBuilder: (_, __) =>
                              SizedBox(height: widget.isTablet ? 6 : 4),
                          itemBuilder: (context, index) {
                            final option = _filteredOptions[index];
                            final isSelected = widget.selectedValue == option;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _selectOption(option),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding:
                                      EdgeInsets.all(widget.isTablet ? 12 : 10),
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
                                          borderRadius:
                                              BorderRadius.circular(4),
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
                                      SizedBox(
                                          width: widget.isTablet ? 12 : 10),
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
