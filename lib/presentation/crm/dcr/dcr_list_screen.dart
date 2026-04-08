import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:async';
import 'dcr_entry_screen.dart' show DcrEntryScreen;
import '../expenses/expense_entry_screen.dart'
    show ExpenseEntryScreen; // kept if needed elsewhere
import 'package:boilerplate/domain/repository/dcr/dcr_repository.dart';
import 'package:boilerplate/domain/repository/expense/expense_repository.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/domain/entity/dcr/dcr.dart';
import 'package:boilerplate/domain/entity/dcr/dcr_api_models.dart';
import 'package:boilerplate/domain/entity/dcr/unified_dcr_item.dart';
import 'package:boilerplate/data/network/apis/dcr/dcr_api.dart';
import 'package:boilerplate/domain/entity/expense/expense.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api_models.dart';
import 'package:geolocator/geolocator.dart';
import '../deviation/deviation_entry_screen.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/presentation/user/store/user_validation_store.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';
import 'package:boilerplate/presentation/crm/widgets/attachment_viewer_screen.dart';

const String kFilterClearToken = '__CLEAR__';

enum _DateFilterMode { day, range }

/// Daily Call Report screen (My DCR) – styled closely to the provided mock
class DcrListScreen extends StatefulWidget {
  const DcrListScreen({super.key});

  @override
  State<DcrListScreen> createState() => _DcrListScreenState();
}

class _DcrListScreenState extends State<DcrListScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Date filter (defaults to current day)
  _DateFilterMode _dateFilterMode = _DateFilterMode.day;
  DateTime _selectedDay = DateTime.now();
  DateTimeRange _selectedRange =
      DateTimeRange(start: DateTime.now(), end: DateTime.now());
  String? _status;
  String? _employee; // managers only
  List<UnifiedDcrItem> _unifiedItems = const [];
  Position? _currentPosition;
  double _geoFenceRadiusMeters = 5000; // 5 km in meters

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isDefaultDateFilter() {
    final today = _dayOnly(DateTime.now());
    if (_dateFilterMode == _DateFilterMode.day) {
      return _dayOnly(_selectedDay) == today;
    }
    return _dayOnly(_selectedRange.start) == today &&
        _dayOnly(_selectedRange.end) == today;
  }

  static String _formatDateRange(DateTimeRange r) {
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
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
    return '${fmt(r.start)} - ${fmt(r.end)}';
  }

  static String _formatSingleDay(DateTime d) {
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
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd ${months[d.month - 1]} ${d.year}';
  }

  List<String> _employeeOptions = [];
  final Map<String, int> _employeeNameToId = {};

  // Status options loaded from API
  List<String> _statusOptions = [];
  final Map<String, int> _statusNameToId = {};

  // Auto-refresh support
  Timer? _autoRefreshTimer;
  bool _isAppInForeground = true;
  bool _isRefreshing = false;

  // Filter modal state
  bool _showFilterModal = false;
  late AnimationController _filterModalController;
  late Animation<double> _filterModalAnimation;
  final ScrollController _filterScrollController = ScrollController();
  final GlobalKey _statusFilterSectionKey = GlobalKey();
  final GlobalKey _employeeFilterSectionKey = GlobalKey();

  // Transaction type filter (DCR, Expense)
  Set<String> _selectedTransactionTypes = {
    'DCR',
    'Expense'
  }; // Default: both selected

  // Temp apply hook for modal (commits temp selections before Apply Filters)
  VoidCallback? _pendingFilterApply;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize filter modal animation
    _filterModalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _filterModalAnimation = CurvedAnimation(
      parent: _filterModalController,
      curve: Curves.easeOut,
    );

    _load();
    final UserDetailStore? userStore =
        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final int? roleCategory = userStore?.userDetail?.roleCategory;
    if (!(roleCategory == 1 || roleCategory == 2)) {
      _getEmployeeList();
    }
    _getDcrDetailStatusList(); // Load status list for filter
    _initLocation();
    _startAutoRefresh();

    // Validate user when screen opens
    _validateUserOnScreenOpen();
  }

  /// Validate user when DCR screen opens
  Future<void> _validateUserOnScreenOpen() async {
    try {
      if (getIt.isRegistered<UserValidationStore>()) {
        final validationStore = getIt<UserValidationStore>();
        final userStore = getIt.isRegistered<UserDetailStore>()
            ? getIt<UserDetailStore>()
            : null;
        final int? employeeId = userStore?.userDetail?.employeeId;
        if (employeeId != null && employeeId > 0) {
          print(
              '📱 [DcrListScreen] Validating user on screen open - employeeId as userId: $employeeId');
          await validationStore.validateUser(employeeId);
        } else {
          print('⚠️ [DcrListScreen] Employee ID not available for validation');
        }
      }
    } catch (e) {
      print('❌ [DcrListScreen] Error validating user: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _filterModalController.dispose();
    _filterScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    setState(() {
      _isAppInForeground = state == AppLifecycleState.resumed;
    });

    if (_isAppInForeground) {
      // App came to foreground, refresh data and restart timer
      _load();
      _startAutoRefresh();
    } else {
      // App went to background, stop timer to save battery
      _autoRefreshTimer?.cancel();
    }
  }

  Future<void> _load() async {
    if (_isRefreshing) return; // Prevent multiple simultaneous refreshes

    setState(() {
      _isRefreshing = true;
    });

    try {
      // Get employee ID from UserDetailStore
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      final int? employeeId = userStore?.userDetail?.employeeId;
      final int? roleCategory = userStore?.userDetail?.roleCategory;

      if (employeeId == null) {
        print(
            'Error: Employee ID not available. Please ensure user is logged in.');
        if (!mounted) return;
        setState(() {
          _unifiedItems = [];
        });
        return;
      }

      final DateTime start;
      final DateTime end;
      if (_dateFilterMode == _DateFilterMode.day) {
        final d = _dayOnly(_selectedDay);
        start = d;
        end = d;
      } else {
        start = _dayOnly(_selectedRange.start);
        end = _dayOnly(_selectedRange.end);
      }
      final DcrRepository? dcrRepo =
          getIt.isRegistered<DcrRepository>() ? getIt<DcrRepository>() : null;

      if (dcrRepo == null) {
        print('Error: DCR Repository not registered');
        if (!mounted) return;
        setState(() {
          _unifiedItems = [];
        });
        return;
      }

      // Use selected employee if provided, else current user
      final bool forceLoggedIn = roleCategory == 1 || roleCategory == 2;
      final int effectiveEmployeeId =
          forceLoggedIn ? employeeId : (_selectedEmployeeId() ?? employeeId);
      final int? selectedStatusId = _statusIdFromText(_status);

      // Load unified DCR list (includes both DCR and Expense items)
      final List<DcrApiItem> apiItems = await dcrRepo.getDcrListUnified(
        start: start,
        end: end,
        employeeId: effectiveEmployeeId.toString(),
        statusId: selectedStatusId,
      );

      // Convert API items to unified items
      final List<UnifiedDcrItem> unifiedItems = apiItems
          .map<UnifiedDcrItem>((item) => UnifiedDcrItem.fromDcrApiItem(item))
          .toList();

      if (!mounted) return;

      setState(() {
        _unifiedItems = unifiedItems;
      });
    } catch (e) {
      print('Error loading DCR data: $e');
      if (!mounted) return;
      setState(() {
        _unifiedItems = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _initLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (_) {
        // Fallback to last known if immediate fix not available
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) return;
      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
      });

      // Recompute proximity when location available
      if (!mounted) return;
      if (_unifiedItems.isNotEmpty) {
        setState(() {
          // Note: Proximity calculation would need to be implemented for unified items
          // For now, we'll skip this as the unified items don't have the same structure
        });
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  /// Start auto-refresh timer
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel(); // Cancel any existing timer

    // Refresh every 30 seconds when app is in foreground
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isAppInForeground && mounted) {
        print('DCR List Screen: Auto-refreshing data...');
        _load();
      }
    });
  }

  /// Stop auto-refresh timer
  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  /// Manual refresh method
  Future<void> _refreshData() async {
    print('DCR List Screen: Manual refresh triggered');
    await _load();
    if (mounted) {
      _showToast(
        'Data refreshed',
        type: ToastType.success,
        icon: Icons.refresh,
      );
    }
  }

  /// Toggle auto-refresh on/off
  void _toggleAutoRefresh() {
    if (_autoRefreshTimer != null) {
      _stopAutoRefresh();
      print('DCR List Screen: Auto-refresh stopped');
    } else {
      _startAutoRefresh();
      print('DCR List Screen: Auto-refresh started');
    }
  }

  DcrEntry _withProximity(DcrEntry entry) {
    // If we lack coordinates (either user or entry), consider it in range for now
    if (_currentPosition == null ||
        entry.customerLatitude == null ||
        entry.customerLongitude == null) {
      return entry.copyWith(geoProximity: GeoProximity.at);
    }
    final double distanceMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      entry.customerLatitude!,
      entry.customerLongitude!,
    );
    // Treat everything within the configured radius as "At location" (green)
    if (distanceMeters <= _geoFenceRadiusMeters) {
      return entry.copyWith(geoProximity: GeoProximity.at);
    } else {
      return entry.copyWith(geoProximity: GeoProximity.away);
    }
  }

  String? _distanceKmText(DcrEntry entry) {
    if (_currentPosition == null ||
        entry.customerLatitude == null ||
        entry.customerLongitude == null) return null;
    final double meters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      entry.customerLatitude!,
      entry.customerLongitude!,
    );
    final double km = meters / 1000.0;
    return km < 0.1
        ? '${meters.toStringAsFixed(0)} m'
        : '${km.toStringAsFixed(2)} km';
  }

  // Method to clear all filters and reload data
  Future<void> _clearAllFilters() async {
    setState(() {
      _status = null;
      _selectedTransactionTypes = {'DCR', 'Expense'}; // Reset to both selected
      // Preserve employee filter selection even when clearing
      _dateFilterMode = _DateFilterMode.day;
      _selectedDay = DateTime.now();
      _selectedRange = DateTimeRange(start: _selectedDay, end: _selectedDay);
    });
    await _load();
    _showToast(
      'Filters cleared',
      type: ToastType.success,
      icon: Icons.filter_alt_off,
    );
  }

  // Check if any filters are active
  bool _hasActiveFilters() {
    final bool isDateFiltered = !_isDefaultDateFilter();
    final bool isTransactionTypeFiltered =
        _selectedTransactionTypes.length != 2;
    return _status != null ||
        _employee != null ||
        isDateFiltered ||
        isTransactionTypeFiltered;
  }

  // Check if employee filter should be disabled (when roleCategory === 3)
  bool _shouldDisableEmployeeFilter() {
    final UserDetailStore? userStore =
        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    return userStore?.userDetail?.roleCategory == 3;
  }

  bool _shouldHideEmployeeFilter() {
    final UserDetailStore? userStore =
        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final int? roleCategory = userStore?.userDetail?.roleCategory;
    return roleCategory == 1 || roleCategory == 2;
  }

  /// Build empty state widget when no DCR data is available
  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Empty state icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            'No DCR Data Found',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            _hasActiveFilters()
                ? 'No records found\nTry adjusting your filters'
                : 'No Daily Call Reports found for the selected date.\nTry creating a new DCR.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 32),

          // Action buttons - Responsive (side-by-side on all sizes)
          LayoutBuilder(builder: (context, constraints) {
            final double w = constraints.maxWidth;
            final bool isVeryNarrow = w < 380;
            if (isVeryNarrow) {
              // Stack vertically on small phones to avoid overflow
              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: getIt.isRegistered<UserValidationStore>()
                        ? ListenableBuilder(
                            listenable: getIt<UserValidationStore>(),
                            builder: (context, _) {
                              final validationStore =
                                  getIt<UserValidationStore>();
                              final isEnabled = validationStore.canCreateDcr;
                              return FilledButton.icon(
                                onPressed: isEnabled
                                    ? () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const DcrEntryScreen()),
                                        );
                                        if (context.mounted) {
                                          await _load();
                                        }
                                      }
                                    : null,
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(
                                  'Create New DCR',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      isEnabled ? tealGreen : Colors.grey,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  disabledForegroundColor: Colors.grey.shade600,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  elevation: isEnabled ? 2 : 0,
                                ),
                              );
                            },
                          )
                        : FilledButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const DcrEntryScreen()),
                              );
                              if (context.mounted) {
                                await _load();
                              }
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(
                              'Create New DCR',
                              style: GoogleFonts.inter(
                                  fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: tealGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 2,
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _clearAllFilters,
                      icon: Icon(Icons.refresh, size: 18, color: tealGreen),
                      label: Text(
                        'Clear Filters',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: tealGreen),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: tealGreen, width: 1.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              // Flexible row that avoids overflow on mobile by expanding buttons
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: getIt.isRegistered<UserValidationStore>()
                        ? ListenableBuilder(
                            listenable: getIt<UserValidationStore>(),
                            builder: (context, _) {
                              final validationStore =
                                  getIt<UserValidationStore>();
                              final isEnabled = validationStore.canCreateDcr;
                              return FilledButton.icon(
                                onPressed: isEnabled
                                    ? () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const DcrEntryScreen()),
                                        );
                                        if (context.mounted) {
                                          await _load();
                                        }
                                      }
                                    : null,
                                icon: const Icon(Icons.add, size: 20),
                                label: Text(
                                  'Create New DCR',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      isEnabled ? tealGreen : Colors.grey,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  disabledForegroundColor: Colors.grey.shade600,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  elevation: isEnabled ? 2 : 0,
                                ),
                              );
                            },
                          )
                        : FilledButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const DcrEntryScreen()),
                              );
                              if (context.mounted) {
                                await _load();
                              }
                            },
                            icon: const Icon(Icons.add, size: 20),
                            label: Text(
                              'Create New DCR',
                              style: GoogleFonts.inter(
                                  fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: tealGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 2,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearAllFilters,
                      icon: Icon(Icons.refresh, size: 20, color: tealGreen),
                      label: Text(
                        'Clear Filters',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: tealGreen),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: tealGreen, width: 1.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              );
            }
          }),
        ],
      ),
    );
  }

  static const Color tealGreen = Color(0xFF4db1b3);

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 768;
    final isMobile = screenWidth < 600;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refreshData,
          color: tealGreen,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                shrinkWrap: false,
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 12 : 16,
                  isMobile ? 8 : 12, // reduce top gap
                  isMobile ? 12 : 16,
                  isMobile ? 12 : 16,
                ),
                children: [
                  // Header Section
                  _buildHeader(isMobile, isTablet, tealGreen),
                  SizedBox(height: isMobile ? 12 : 14),

                  // Action Buttons Section
                  _buildActionButtonsSection(isMobile, isTablet, tealGreen),
                  SizedBox(height: isMobile ? 12 : 14),

                  // Summary Cards Section
                  _buildSummaryCards(isMobile, isTablet, tealGreen),
                  SizedBox(height: isMobile ? 12 : 14),

                  // Filter tags removed as per design; use Clear in modal footer instead

                  SizedBox(height: isMobile ? 12 : 14),

                  // Cards list (grouped by cluster/city or Ad-hoc) or empty state
                  if (_unifiedItems.isEmpty) ...[
                    _buildEmptyState(),
                  ] else ...[
                    for (final e in _groupedByClusterOrAdhoc()) ...[
                      _SectionCard(
                        title: '${e.cluster} • ${e.items.length} items',
                        actionText: _groupInRangeText(e),
                        child: Column(
                          children: [
                            for (final item in e.items) ...[
                              // Debug logging for each item
                              if (item.isDcr) ...[
                                Builder(
                                  builder: (context) {
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _UnifiedItemCard(
                                  item: item,
                                  currentPosition: _currentPosition,
                                  geoFenceRadiusMeters: _geoFenceRadiusMeters,
                                  isEditable: _isDcrEditable(item),
                                  onCreateDeviation: item.isDcr &&
                                          !_isDcrSentBack(item) &&
                                          (!getIt.isRegistered<
                                                  UserValidationStore>() ||
                                              getIt<UserValidationStore>()
                                                  .canCreateDeviation)
                                      ? () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  DeviationEntryScreen(
                                                dcrId: item.dcrId,
                                                tourPlanId: item.tourPlanId,
                                                initialDate: item.parsedDate ??
                                                    DateTime.now(),
                                              ),
                                            ),
                                          );
                                        }
                                      : null,
                                  onViewDetails: () => _showDcrDetails(item),
                                  onViewFull: () => _openFullEntryView(item),
                                  onEdit: _isDcrEditable(item)
                                      ? () async {
                                          if (getIt.isRegistered<
                                              UserValidationStore>()) {
                                            final validationStore =
                                                getIt<UserValidationStore>();
                                            if (!validationStore.canUpdateDcr) {
                                              return; // Button disabled
                                            }
                                          }
                                          if (item.isDcr) {
                                            // Edit DCR - pass both id and dcrId
                                            await Navigator.of(context).push(
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      DcrEntryScreen(
                                                        id: item.id.toString(),
                                                        dcrId: item.dcrId
                                                            .toString(),
                                                      )),
                                            );
                                          } else if (item.isExpense) {
                                            // Edit Expense - pass both id and dcrId
                                            await Navigator.of(context).push(
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      ExpenseEntryScreen(
                                                        id: item.id.toString(),
                                                        dcrId: item.dcrId
                                                            .toString(),
                                                      )),
                                            );
                                          } else {
                                            print(
                                                'Unknown transaction type: ${item.transactionType}');
                                          }
                                          if (context.mounted) {
                                            await _load();
                                          }
                                        }
                                      : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ),

        // Filter Modal
        if (_showFilterModal) _buildFilterModal(isMobile, isTablet, tealGreen),
      ],
    );
  }

  // Build Header Section
  Widget _buildHeader(bool isMobile, bool isTablet, Color tealGreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 0,
        vertical: isMobile ? 8 : 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My DCR',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey[900],
                    letterSpacing: -0.8,
                  ),
                ),
                SizedBox(height: isTablet ? 6 : 4),
                Text(
                  'Today\'s Reports',
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
                        textAlign: TextAlign.center,
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

  // Build Action Buttons Section
  Widget _buildActionButtonsSection(
      bool isMobile, bool isTablet, Color tealGreen) {
    return getIt.isRegistered<UserValidationStore>()
        ? ListenableBuilder(
            listenable: getIt<UserValidationStore>(),
            builder: (context, _) {
              final validationStore = getIt<UserValidationStore>();
              // Service Engineers: always allow New DCR; others: use validate-user API
              final canCreateDcr = _isCurrentUserServiceEngineer() ||
                  validationStore.canCreateDcr;
              final canCreateExpense = validationStore.canCreateExpense;

              return Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.add,
                      label: 'New DCR',
                      color: tealGreen,
                      isMobile: isMobile,
                      onTap: canCreateDcr
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const DcrEntryScreen()),
                              );
                              if (context.mounted) {
                                await _load();
                              }
                            }
                          : null,
                    ),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.add,
                      label: 'New Expense',
                      color: tealGreen,
                      isMobile: isMobile,
                      onTap: canCreateExpense
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ExpenseEntryScreen()),
                              );
                              if (context.mounted) {
                                await _load();
                              }
                            }
                          : null,
                    ),
                  ),
                ],
              );
            },
          )
        : Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.add,
                  label: 'New DCR',
                  color: tealGreen,
                  isMobile: isMobile,
                  onTap: null, // Disabled if validation store not available
                ),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.add,
                  label: 'New Expense',
                  color: tealGreen,
                  isMobile: isMobile,
                  onTap: null, // Disabled if validation store not available
                ),
              ),
            ],
          );
  }

  // Build Action Button
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isMobile,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return Container(
      height: isMobile ? 44 : 48,
      decoration: BoxDecoration(
        color: isEnabled ? color : Colors.grey,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: isMobile ? 18 : 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 14 : 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build Summary Cards
  Widget _buildSummaryCards(bool isMobile, bool isTablet, Color tealGreen) {
    final dcrCount = _getDcrCount();
    final expenseCount = _getExpenseCount();

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            count: dcrCount,
            label: 'DCR Reports',
            isMobile: isMobile,
            tealGreen: tealGreen,
          ),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(
          child: _buildSummaryCard(
            count: expenseCount,
            label: 'Expenses',
            isMobile: isMobile,
            tealGreen: tealGreen,
          ),
        ),
      ],
    );
  }

  // Build Summary Card
  Widget _buildSummaryCard({
    required int count,
    required String label,
    required bool isMobile,
    required Color tealGreen,
  }) {
    // White card with teal number and gray label
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: isMobile ? 32 : 40,
              fontWeight: FontWeight.w700,
              color: tealGreen,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  // Build Filter Tags
  Widget _buildFilterTags(bool isMobile, Color tealGreen) {
    final tags = <Widget>[];

    if (_selectedTransactionTypes.length != 2) {
      for (final type in _selectedTransactionTypes) {
        tags.add(_buildFilterTag(type, isMobile, tealGreen));
      }
    }

    if (_status != null) {
      tags.add(_buildFilterTag(_status!, isMobile, tealGreen));
    }

    // Employee tag
    if (_employee != null && _employee!.isNotEmpty) {
      tags.add(_buildFilterTag(_employee!, isMobile, tealGreen));
    }

    // Date tag
    if (!_isDefaultDateFilter()) {
      final label = _dateFilterMode == _DateFilterMode.day
          ? _formatSingleDay(_selectedDay)
          : _formatDateRange(_selectedRange);
      tags.add(_buildFilterTag(label, isMobile, tealGreen));
    }

    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...tags,
        TextButton(
          onPressed: _clearAllFilters,
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Clear',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // Build Filter Tag
  Widget _buildFilterTag(String label, bool isMobile, Color tealGreen) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
      decoration: BoxDecoration(
        color: tealGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tealGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tealGreen,
          fontSize: isMobile ? 13 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Build Filter Modal
  Widget _buildFilterModal(bool isMobile, bool isTablet, Color tealGreen) {
    // Temp selections that live for the lifetime of the modal (StatefulBuilder rebuilds won't reset these)
    String? _tempStatus = _status;
    String? _tempEmployee = _employee;
    _DateFilterMode _tempMode = _dateFilterMode;
    DateTime _tempDay = _selectedDay;
    DateTimeRange _tempRange = _selectedRange;
    // Keep transaction types local to the modal until Apply is pressed
    final Set<String> _tempTransactionTypes = {..._selectedTransactionTypes};
    return GestureDetector(
      onTap: _closeFilterModal,
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(_filterModalAnimation),
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping inside modal
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
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
                child: Column(
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

                    // Modal Content (StatefulBuilder to keep filters local until Apply)
                    StatefulBuilder(
                      builder: (context, setModalState) {
                        return Flexible(
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
                                // Transaction Type Section
                                Text(
                                  'Transaction Type',
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 14 : 15,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.grey[900],
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCheckboxOption(
                                        'DCR',
                                        _tempTransactionTypes.contains('DCR'),
                                        (value) {
                                          setModalState(() {
                                            if (value == true) {
                                              _tempTransactionTypes.add('DCR');
                                            } else {
                                              _tempTransactionTypes
                                                  .remove('DCR');
                                            }
                                          });
                                        },
                                        isMobile,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildCheckboxOption(
                                        'Expense',
                                        _tempTransactionTypes
                                            .contains('Expense'),
                                        (value) {
                                          setModalState(() {
                                            if (value == true) {
                                              _tempTransactionTypes
                                                  .add('Expense');
                                            } else {
                                              _tempTransactionTypes
                                                  .remove('Expense');
                                            }
                                          });
                                        },
                                        isMobile,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),
                                // Status Section (Searchable)
                                _SearchableFilterDropdown(
                                  key: _statusFilterSectionKey,
                                  title: 'Status',
                                  icon: Icons.verified_outlined,
                                  selectedValue: _tempStatus,
                                  options: _statusOptions,
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

                                const SizedBox(height: 24),
                                // Date Section
                                Text(
                                  'Date',
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 14 : 15,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.grey[900],
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // One day / Date range toggle
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          onTap: () {
                                            setModalState(() {
                                              _tempMode = _DateFilterMode.day;
                                              _tempDay = _dayOnly(_tempDay);
                                              _tempRange = DateTimeRange(
                                                  start: _tempDay,
                                                  end: _tempDay);
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                            decoration: BoxDecoration(
                                              color: _tempMode ==
                                                      _DateFilterMode.day
                                                  ? Colors.white
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'One day',
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: _tempMode ==
                                                          _DateFilterMode.day
                                                      ? Colors.grey[900]
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          onTap: () {
                                            setModalState(() {
                                              _tempMode =
                                                  _DateFilterMode.range;
                                              final s = _dayOnly(_tempRange.start);
                                              final e = _dayOnly(_tempRange.end);
                                              _tempRange =
                                                  DateTimeRange(start: s, end: e);
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10),
                                            decoration: BoxDecoration(
                                              color: _tempMode ==
                                                      _DateFilterMode.range
                                                  ? Colors.white
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Date range',
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: _tempMode ==
                                                          _DateFilterMode.range
                                                      ? Colors.grey[900]
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _EnhancedDateSelector(
                                  label: _tempMode == _DateFilterMode.day
                                      ? _formatSingleDay(_tempDay)
                                      : _formatDateRange(_tempRange),
                                  isActive: _tempMode == _DateFilterMode.day
                                      ? _dayOnly(_tempDay) != _dayOnly(DateTime.now())
                                      : !(_dayOnly(_tempRange.start) ==
                                              _dayOnly(DateTime.now()) &&
                                          _dayOnly(_tempRange.end) ==
                                              _dayOnly(DateTime.now())),
                                  onTap: () async {
                                    if (_tempMode == _DateFilterMode.day) {
                                      final DateTime? picked =
                                          await showDatePicker(
                                        context: context,
                                        initialDate: _dayOnly(_tempDay),
                                        firstDate: DateTime(2000, 1, 1),
                                        lastDate: DateTime.now()
                                            .add(const Duration(days: 365)),
                                        builder: (context, child) {
                                          final theme = Theme.of(context);
                                          return Theme(
                                            data: theme.copyWith(
                                              colorScheme:
                                                  theme.colorScheme.copyWith(
                                                primary: tealGreen,
                                              ),
                                            ),
                                            child: child ??
                                                const SizedBox.shrink(),
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setModalState(() {
                                          _tempDay = _dayOnly(picked);
                                          _tempRange = DateTimeRange(
                                              start: _tempDay, end: _tempDay);
                                        });
                                      }
                                    } else {
                                      final DateTimeRange? picked =
                                          await showDateRangePicker(
                                        context: context,
                                        firstDate: DateTime(2000, 1, 1),
                                        lastDate: DateTime.now().add(
                                            const Duration(days: 365)),
                                        initialDateRange: _tempRange,
                                        builder: (context, child) {
                                          final theme = Theme.of(context);
                                          return Theme(
                                            data: theme.copyWith(
                                              colorScheme:
                                                  theme.colorScheme.copyWith(
                                                primary: tealGreen,
                                                secondary: tealGreen,
                                              ),
                                            ),
                                            child: child ??
                                                const SizedBox.shrink(),
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setModalState(() => _tempRange = picked);
                                      }
                                    }
                                  },
                                ),

                                const SizedBox(height: 24),
                                // Employee Section (Searchable)
                                if (!_shouldHideEmployeeFilter())
                                  AbsorbPointer(
                                    absorbing: _shouldDisableEmployeeFilter(),
                                    child: Opacity(
                                      opacity: _shouldDisableEmployeeFilter()
                                          ? 0.6
                                          : 1.0,
                                      child: _SearchableFilterDropdown(
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
                                    ),
                                  ),

                                const SizedBox(height: 8),
                                // Apply changes to outer state when pressing footer button
                                // Footer handled below; values captured here
                                Builder(builder: (_) {
                                  // Attach a callback to store temps on widget tree for footer access
                                  _pendingFilterApply = () {
                                    setState(() {
                                      _selectedTransactionTypes
                                        ..clear()
                                        ..addAll(_tempTransactionTypes);
                                      _status = _tempStatus;
                                      _employee = _tempEmployee;
                                      _dateFilterMode = _tempMode;
                                      _selectedDay = _tempDay;
                                      _selectedRange = _tempRange;
                                    });
                                  };
                                  return const SizedBox.shrink();
                                }),
                              ],
                            ),
                          ),
                        );
                      },
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
                              onPressed: () async {
                                await _clearAllFilters(); // preserves employee by design
                                _closeFilterModal();
                              },
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                    vertical: isMobile ? 14 : 16),
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
                                // Commit modal temps to outer state then apply
                                _pendingFilterApply?.call();
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build Checkbox Option
  Widget _buildCheckboxOption(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
    bool isMobile,
  ) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Transform.scale(
              scale: isMobile ? 0.9 : 1.0,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: tealGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: isMobile ? 14 : 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
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
    return '${months[d.month - 1]} ${d.year}'; // Month and year only
  }

  /// Format complaint date string (e.g. ISO 2026-02-03T04:44:36.77) for display.
  static String _formatComplaintDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    try {
      final d = DateTime.parse(raw);
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
      final day = d.day.toString().padLeft(2, '0');
      final month = months[d.month - 1];
      final year = d.year;
      final hour = d.hour.toString().padLeft(2, '0');
      final minute = d.minute.toString().padLeft(2, '0');
      return '$day $month $year, $hour:$minute';
    } catch (_) {
      return raw;
    }
  }

  static bool _isToday(DateTime d) {
    final DateTime now = DateTime.now();
    return now.year == d.year && now.month == d.month; // Check month only
  }

  // Show month/year picker
  Future<DateTime?> _showMonthYearPicker(
      BuildContext context, DateTime initialDate, Color tealGreen) async {
    int selectedYear = initialDate.year;
    int selectedMonth = initialDate.month;

    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final bool isTablet = MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 1024;

    return showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 20 : 24,
                    8,
                    isMobile ? 20 : 24,
                    isMobile ? 20 : 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      // Year selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                selectedYear--;
                              });
                            },
                            icon: Icon(
                              Icons.chevron_left,
                              color: tealGreen,
                              size: isMobile ? 24 : 28,
                            ),
                            padding: EdgeInsets.all(isMobile ? 8 : 12),
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '$selectedYear',
                            style: GoogleFonts.inter(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[900],
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                selectedYear++;
                              });
                            },
                            icon: Icon(
                              Icons.chevron_right,
                              color: tealGreen,
                              size: isMobile ? 24 : 28,
                            ),
                            padding: EdgeInsets.all(isMobile ? 8 : 12),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      SizedBox(height: isMobile ? 20 : 24),
                      // Month grid
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final double spacing = isMobile ? 10 : 12;
                          final double crossAxisSpacing = spacing;
                          final double mainAxisSpacing = spacing;
                          final int crossAxisCount = 3;
                          final double availableWidth = constraints.maxWidth;
                          final double itemWidth = (availableWidth -
                                  (crossAxisSpacing * (crossAxisCount - 1))) /
                              crossAxisCount;
                          final double itemHeight = isMobile ? 48 : 56;

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: crossAxisSpacing,
                              mainAxisSpacing: mainAxisSpacing,
                              childAspectRatio: itemWidth / itemHeight,
                            ),
                            itemCount: 12,
                            itemBuilder: (context, index) {
                              final month = index + 1;
                              final isSelected = selectedMonth == month;
                              return OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    selectedMonth = month;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isSelected
                                        ? tealGreen
                                        : Colors.grey.shade300,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  backgroundColor: isSelected
                                      ? tealGreen.withOpacity(0.1)
                                      : Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 8 : 12,
                                    vertical: isMobile ? 12 : 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    [
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
                                    ][index],
                                    style: GoogleFonts.inter(
                                      fontSize: isMobile ? 14 : 16,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? tealGreen
                                          : Colors.grey[900],
                                      letterSpacing: 0.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      SizedBox(height: isMobile ? 24 : 28),
                      // Confirm button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(context)
                                .pop(DateTime(selectedYear, selectedMonth, 1));
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: tealGreen,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: isMobile ? 16 : 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Select',
                            style: GoogleFonts.inter(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                          height: MediaQuery.of(context).padding.bottom > 0
                              ? 8
                              : 0),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper method to show toast message at the top
  void _showToast(String message,
      {ToastType type = ToastType.info, IconData? icon}) {
    if (!mounted) return;
    ToastMessage.show(
      context,
      message: message,
      type: type,
      icon: icon,
      useRootNavigator: true,
      duration: const Duration(seconds: 3),
    );
  }

  bool _canCreateDcr() {
    // Allow when user position exists and there is at least one in-range customer group
    if (_currentPosition == null)
      return true; // fallback: allow if no location yet
    final groups = _groupedByClusterOrAdhoc();
    return groups.any((g) => g.items.any((item) =>
        item.isDcr &&
        item.customerLatitude != null &&
        item.customerLongitude != null));
  }

  // DCR Related Common API Methods
  Future<void> _getEmployeesReportingTo(int id) async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();

        final employees = await commonRepo.getEmployeesReportingTo(id);

        if (mounted) {
          _showToast(
            'Found ${employees.length} employees reporting to ID: $id',
            type: ToastType.success,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showToast(
          'Error getting employees reporting to: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _getExpenseTypeList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();

        final types = await commonRepo.getExpenseTypeList();

        if (mounted) {
          _showToast(
            'Found ${types.length} expense types',
            type: ToastType.success,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showToast(
          'Error getting expense type list: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _getDcrListForEmployee(
      int userId, int employeeId, int bizUnit) async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();

        final dcrs =
            await commonRepo.getDcrListForEmployee(userId, employeeId, bizUnit);

        if (mounted) {
          _showToast(
            'Found ${dcrs.length} DCRs for employee: $employeeId',
            type: ToastType.success,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showToast(
          'Error getting DCR list for employee: $e',
          type: ToastType.error,
        );
      }
    }
  }

  // Removed customer filter and related loader as per requirement

  /// Load employee list from API for employee filter
  Future<void> _getEmployeeList({int? employeeId}) async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        // Get employeeId from user store if not provided
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
            ? getIt<UserDetailStore>()
            : null;
        final int? finalEmployeeId =
            employeeId ?? userStore?.userDetail?.employeeId;

        // Use same API call as tour plan manager review (CommandType 106 or 276 if employeeId provided)
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
            // Update even if _employee is already set to ensure it's correct
            if (selectedEmployeeName != null) {
              _employee = selectedEmployeeName;
              print(
                  'DcrListScreen: Auto-selected employee: $selectedEmployeeName (ID: $finalEmployeeId)');
            }
          });
          print(
              'DcrListScreen: Loaded ${_employeeOptions.length} employees ${finalEmployeeId != null ? "for employeeId: $finalEmployeeId" : ""}');
        }
      }
    } catch (e) {
      print('DcrListScreen: Error getting employee list: $e');
    }
  }

  /// Load DCR detail status list from API for status filter
  Future<void> _getDcrDetailStatusList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        final List<CommonDropdownItem> items =
            await commonRepo.getDcrDetailStatusList();
        final statuses =
            items.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toSet();

        if (statuses.isNotEmpty && mounted) {
          setState(() {
            _statusOptions = {..._statusOptions, ...statuses}.toList();
            // map names to ids for potential status ID mapping
            for (final item in items) {
              final String key = item.text.trim();
              if (key.isNotEmpty) _statusNameToId[key] = item.id;
            }
          });
          print(
              'DcrListScreen: Loaded ${_statusOptions.length} statuses for filter');
        }
      }
    } catch (e) {
      print('DcrListScreen: Error getting DCR detail status list: $e');
    }
  }

  /// Helper method to check if an item is approved
  bool _isItemApproved(UnifiedDcrItem item) {
    final statusText = item.statusText.trim().toLowerCase();

    // Check statusText first - if it explicitly contains "approved", it's approved
    if (statusText.contains('approved')) {
      return true;
    }

    // Check dcrStatusId as fallback/primary method
    if (item.isExpense) {
      // For Expense items: dcrStatusId == 5 means Approved
      if (item.dcrStatusId == 5) {
        return true;
      }
    } else if (item.isDcr) {
      // For DCR items: dcrStatusId == 4 means Approved
      if (item.dcrStatusId == 4) {
        return true;
      }
    }

    return false;
  }

  /// Helper method to check if a DCR item is editable
  /// DCR is editable if status is Draft or Sent Back
  bool _isDcrEditable(UnifiedDcrItem item) {
    if (item.isDcr) {
      final statusText = item.statusText.trim().toLowerCase();
      final bool isDraftOrSentBackByText = statusText.contains('draft') ||
          statusText.contains('sent back') ||
          statusText.contains('sentback');
      final bool isDraftOrSentBackById = item.dcrStatusId == 0 ||
          item.dcrStatusId == 1 ||
          item.dcrStatusId == 6 ||
          item.dcrStatusId == 7;

      // Service Engineers can always edit draft/sent-back DCRs (bypass validate-user for update)
      if (_isCurrentUserServiceEngineer() &&
          (isDraftOrSentBackByText || isDraftOrSentBackById)) {
        return true;
      }

      // For others, check if user validation allows updates
      if (getIt.isRegistered<UserValidationStore>()) {
        final validationStore = getIt<UserValidationStore>();
        if (!validationStore.canUpdateDcr) {
          return false;
        }
      }

      if (isDraftOrSentBackByText || isDraftOrSentBackById) {
        return true;
      }
      return false;
    }
    // For non-DCR items (expenses), editable only in draft or sent back states
    final statusText = item.statusText.trim().toLowerCase();
    if (statusText.contains('draft')) {
      return true;
    }
    if (statusText.contains('sent back') || statusText.contains('sentback')) {
      return true;
    }
    if (statusText.contains('submit')) {
      return false;
    }

    // Fallback to status id mapping
    switch (item.dcrStatusId) {
      case 0: // Draft
      case 1: // Draft
        return true;
      case 2: // Sent Back
      case 4: // Sent Back
        return true;
      case 5: // Approved
        return false;
      case 3: // Submitted
      default:
        return false;
    }
  }

  bool _isDcrSentBack(UnifiedDcrItem item) {
    if (!item.isDcr) return false;
    final statusText = item.statusText.trim().toLowerCase();
    if (statusText.contains('sent back') || statusText.contains('sentback')) {
      return true;
    }
    return item.dcrStatusId == 6;
  }

  /// Check if current user is a Service Engineer
  bool _isCurrentUserServiceEngineer() {
    final UserDetailStore? userStore =
        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final String? serviceArea = userStore?.userDetail?.serviceArea;
    final bool isServiceEngineer =
        serviceArea != null && serviceArea.trim() == 'Service Engineer';
    return isServiceEngineer;
  }

  /// Check if item has Service Report data
  bool _hasServiceReportData(UnifiedDcrItem item) {
    final bool hasMappedInstruments =
        item.mappedInstruments != null && item.mappedInstruments!.isNotEmpty;
    final bool hasComplaint =
        item.complaint != null && item.complaint!.isNotEmpty;
    final bool hasActionTaken =
        item.actionTaken != null && item.actionTaken!.isNotEmpty;
    final bool hasResult = item.result != null && item.result!.isNotEmpty;
    final bool hasComplaintStatus =
        item.complaintStatus != null && item.complaintStatus!.isNotEmpty;
    final bool hasComplaintDate =
        item.complaintDate != null && item.complaintDate!.isNotEmpty;
    final bool hasComplaintRemarks =
        item.complaintRemarks != null && item.complaintRemarks!.isNotEmpty;

    final bool result = hasMappedInstruments ||
        hasComplaint ||
        hasActionTaken ||
        hasResult ||
        hasComplaintStatus ||
        hasComplaintDate ||
        hasComplaintRemarks;

    print('_hasServiceReportData:');
    print('  - hasMappedInstruments: $hasMappedInstruments');
    print('  - hasComplaint: $hasComplaint');
    print('  - hasActionTaken: $hasActionTaken');
    print('  - hasResult: $hasResult');
    print('  - hasComplaintStatus: $hasComplaintStatus');
    print('  - hasComplaintDate: $hasComplaintDate');
    print('  - hasComplaintRemarks: $hasComplaintRemarks');
    print('  - Result: $result');

    return result;
  }

  /// Open full DCR / expense entry screen (read-only; SE submitted DCR keeps Service Report editable).
  Future<void> _openFullEntryView(UnifiedDcrItem item) async {
    if (item.isDcr) {
      if (item.id <= 0 || item.dcrId <= 0) {
        if (!mounted) return;
        ToastMessage.show(
          context,
          message: 'Cannot open record: missing id.',
          type: ToastType.error,
          icon: Icons.error_outline,
        );
        return;
      }
      final bool serviceReportOnlyEdit = _isCurrentUserServiceEngineer() &&
          !_isDcrEditable(item);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DcrEntryScreen(
            id: item.id.toString(),
            dcrId: item.dcrId.toString(),
            viewOnly: true,
            allowServiceReportEditOnly: serviceReportOnlyEdit,
          ),
        ),
      );
    } else if (item.isExpense) {
      // Draft / standalone expenses use dcrId 0; pass same string as Edit so GetExpense params match.
      if (item.id <= 0) {
        if (!mounted) return;
        ToastMessage.show(
          context,
          message: 'Cannot open record: missing id.',
          type: ToastType.error,
          icon: Icons.error_outline,
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExpenseEntryScreen(
            id: item.id.toString(),
            dcrId: item.dcrId.toString(),
            viewOnly: true,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ToastMessage.show(
        context,
        message: 'Unsupported record type.',
        type: ToastType.warning,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }
    if (mounted) await _load();
  }

  /// Show detailed popup for DCR or Expense item
  Future<void> _showDcrDetails(UnifiedDcrItem item) async {
    // For DCR items, fetch full details using Get API to get Service Report fields
    UnifiedDcrItem displayItem = item;

    if (item.isDcr && item.dcrId > 0) {
      try {
        print(
            'Fetching DCR details using Get API - ID: ${item.id}, DCR ID: ${item.dcrId}');
        final DcrRepository? dcrRepo =
            getIt.isRegistered<DcrRepository>() ? getIt<DcrRepository>() : null;

        if (dcrRepo != null) {
          final int detailId = item.id;
          final int dcrId = item.dcrId;

          final dcrEntry = await dcrRepo.getById(detailId.toString(),
              dcrId: dcrId.toString());

          if (dcrEntry != null) {
            // Fetch the full DCR response using the API directly
            final dcrApi = getIt<DcrApi>();
            final dcrGetResponse = await dcrApi.getDcrDetails(detailId, dcrId);

            // Convert to UnifiedDcrItem
            final fromGet = UnifiedDcrItem.fromDcrGetResponse(dcrGetResponse);

            // Preserve the original list status text / id (e.g. "Missed")
            displayItem = fromGet.copyWith(
              statusText: item.statusText,
              dcrStatusId: item.dcrStatusId,
            );
            print(
                'Successfully fetched DCR details from Get API (status preserved as "${displayItem.statusText}")');
          }
        }
      } catch (e) {
        print('Error fetching DCR details from Get API: $e');
        // Fall back to using the item from list
        print('Falling back to list item data');
      }
    }

    if (!mounted) return;

    final isTablet = MediaQuery.of(context).size.width >= 600;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final double panelHeight =
        isTablet ? screenHeight * 0.85 : screenHeight * 0.9;
    final double mobileMaxContentHeight = screenHeight * 0.7;

    Widget buildPanelContent(BuildContext ctx) {
      final isTabletPanel = isTablet;
      return Container(
        width: isTabletPanel ? 600 : screenWidth,
        height: isTabletPanel ? panelHeight : null,
        constraints:
            isTabletPanel ? null : BoxConstraints(maxHeight: panelHeight),
        margin: isTabletPanel
            ? EdgeInsets.symmetric(
                horizontal: (screenWidth - 600) / 2,
                vertical: screenHeight * 0.075,
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
          child: Column(
            mainAxisSize: isTabletPanel ? MainAxisSize.max : MainAxisSize.min,
            children: [
              // Header (mint like tour plan)
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
                            displayItem.isDcr
                                ? Icons.assignment_outlined
                                : Icons.account_balance_wallet_outlined,
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
                                  displayItem.isDcr
                                      ? 'DCR Details'
                                      : 'Expense Details',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[900],
                                    fontSize: isTabletPanel ? 16 : 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _getStatusChipForItem(displayItem),
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
              // Content: tablet = Flexible; mobile = ConstrainedBox so sheet sizes to content
              if (isTabletPanel)
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      MediaQuery.of(ctx).padding.bottom + 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildDcrDetailContent(
                          ctx, displayItem, item, isTabletPanel),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints:
                      BoxConstraints(maxHeight: mobileMaxContentHeight),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      MediaQuery.of(ctx).padding.bottom + 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: _buildDcrDetailContent(
                          ctx, displayItem, item, isTabletPanel),
                    ),
                  ),
                ),
              // Footer actions (Tour Plan-like wide pill buttons)
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.of(context).padding.bottom + 16,
                  ),
                  child: Row(
                    children: [
                      if (_isDcrEditable(item)) ...[
                        Expanded(
                          flex: 1,
                          child: FilledButton.icon(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              if (item.isDcr) {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DcrEntryScreen(
                                      id: item.id.toString(),
                                      dcrId: item.dcrId.toString(),
                                    ),
                                  ),
                                );
                              } else if (item.isExpense) {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ExpenseEntryScreen(
                                      id: item.id.toString(),
                                      dcrId: item.dcrId.toString(),
                                    ),
                                  ),
                                );
                              }
                              if (mounted) {
                                await _load();
                              }
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit', maxLines: 1),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF4db1b3),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Full-screen View beside Deviation (same behavior as list "View" / _openFullEntryView)
                      if (item.isDcr && !_isDcrSentBack(item)) ...[
                        Expanded(
                          flex: 1,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _openFullEntryView(item);
                            },
                            icon: const Icon(Icons.visibility_outlined,
                                size: 18, color: Color(0xFF4db1b3)),
                            label: const Text('View', maxLines: 1),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4db1b3),
                              minimumSize: const Size.fromHeight(44),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              side: const BorderSide(
                                  color: Color(0xFF4db1b3), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Builder(
                            builder: (context) {
                              final bool showFilled = !_isDcrEditable(item);
                              final onPressed = () {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DeviationEntryScreen(
                                      dcrId: item.dcrId,
                                      tourPlanId: item.tourPlanId,
                                      initialDate:
                                          item.parsedDate ?? DateTime.now(),
                                    ),
                                  ),
                                );
                              };
                              final deviationLabel = FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: const Text(
                                  'Deviation',
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              );
                              if (showFilled) {
                                return FilledButton.icon(
                                  onPressed: onPressed,
                                  icon: const Icon(Icons.alt_route, size: 18),
                                  label: deviationLabel,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF4db1b3),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(44),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                );
                              }
                              return OutlinedButton.icon(
                                onPressed: onPressed,
                                icon: const Icon(Icons.alt_route,
                                    size: 18, color: Color(0xFF4db1b3)),
                                label: deviationLabel,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF4db1b3),
                                  minimumSize: const Size.fromHeight(44),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  side: const BorderSide(
                                      color: Color(0xFF4db1b3), width: 1.5),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      // Full-screen View for expenses (read-only entry screen)
                      if (item.isExpense) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _openFullEntryView(item);
                            },
                            icon: const Icon(Icons.visibility_outlined,
                                size: 18, color: Color(0xFF4db1b3)),
                            label: const Text('View'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4db1b3),
                              minimumSize: const Size.fromHeight(44),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              side: const BorderSide(
                                  color: Color(0xFF4db1b3), width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isTablet) {
      Navigator.of(context, rootNavigator: true)
          .push(
        PageRouteBuilder<void>(
          opaque: false,
          barrierColor: Colors.black54,
          barrierDismissible: true,
          pageBuilder: (ctx, _, __) => Center(
            child: Material(
              color: Colors.transparent,
              child: buildPanelContent(ctx),
            ),
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      )
          .then((_) {
        if (mounted) _load();
      });
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => buildPanelContent(ctx),
      ).then((_) {
        if (mounted) _load();
      });
    }
  }

  List<Widget> _buildDcrDetailContent(BuildContext ctx,
      UnifiedDcrItem displayItem, UnifiedDcrItem item, bool isTablet) {
    final String clusterRaw = displayItem.clusterNames.trim();
    final bool hasCluster = clusterRaw.isNotEmpty;
    final String customerName = displayItem.customerName.trim();
    final bool hasCustomer =
        customerName.isNotEmpty && customerName != 'Unknown Customer' && displayItem.customerId != 0;
    return [
      _DetailRow('Transaction Type', displayItem.transactionType),
      const SizedBox(height: 12),
      _DetailRow('Date', _formatDate(displayItem.parsedDate ?? DateTime.now())),
      const SizedBox(height: 12),
      _DetailRow('Employee', displayItem.employeeName),
      const SizedBox(height: 12),
      if (displayItem.designation.isNotEmpty) ...[
        _DetailRow('Designation', displayItem.designation),
        const SizedBox(height: 12),
      ],
      if (hasCluster) ...[
        _DetailRow('Cluster', displayItem.clusterDisplayName),
        const SizedBox(height: 12),
      ],
      _DetailRow('Status', displayItem.statusText),
      if (displayItem.isDcr) ...[
        const SizedBox(height: 20),
        Divider(height: 1, color: Colors.grey.shade300),
        const SizedBox(height: 20),
        if (hasCustomer) ...[
          _DetailRow('Customer', customerName),
          const SizedBox(height: 12),
        ],
        _DetailRow('Purpose', displayItem.typeOfWork),
        const SizedBox(height: 12),
        if (displayItem.samplesToDistribute != null &&
            displayItem.samplesToDistribute!.isNotEmpty) ...[
          _DetailRow('Samples to Distribute', displayItem.samplesToDistribute!),
          const SizedBox(height: 12),
        ],
        if (displayItem.productsToDiscuss != null &&
            displayItem.productsToDiscuss!.isNotEmpty) ...[
          _DetailRow('Products to Discuss', displayItem.productsToDiscuss!),
          const SizedBox(height: 12),
        ],
      ] else ...[
        const SizedBox(height: 20),
        Divider(height: 1, color: Colors.grey.shade300),
        const SizedBox(height: 20),
        _DetailRow('Expense Type', displayItem.expenseType ?? 'Unknown'),
        const SizedBox(height: 12),
        _DetailRow(
            'Amount',
            displayItem.expenseAmount != null
                ? 'LKR ${displayItem.expenseAmount!.toStringAsFixed(2)}'
                : 'Unknown'),
        // Attachments: always show section and button for expense details
        const SizedBox(height: 20),
        Divider(height: 1, color: Colors.grey.shade300),
        const SizedBox(height: 20),
        Text(
          'Attachments',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: Colors.grey[900],
            fontSize: isTablet ? 15 : 14,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<ExpenseDetailResponse?>(
          future: getIt.isRegistered<ExpenseRepository>()
              ? getIt<ExpenseRepository>().getExpenseFromApi(item.id)
              : Future.value(null),
          builder: (context, snapshot) {
            final attachments = snapshot.data?.attachments ?? [];
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            if (isLoading) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _DcrListScreenState.tealGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Loading attachments...',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }
            if (attachments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'No attachments',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: attachments.map((att) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    onTap: () =>
                        AttachmentViewerScreen.openAttachment(context, att),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_file,
                            size: 18,
                            color: _DcrListScreenState.tealGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              att.fileName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: _DcrListScreenState.tealGreen,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.open_in_new,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
      // Service Report details (show when DCR has this data - for SE and for manager review)
      Builder(
        builder: (context) {
          final bool hasServiceReportData = _hasServiceReportData(displayItem);
          final bool shouldShow = displayItem.isDcr && hasServiceReportData;

          if (!shouldShow) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Divider(height: 1, color: Colors.grey.shade300),
              const SizedBox(height: 20),
              // Text(
              //   'Service Report Details',
              //   style: GoogleFonts.inter(
              //     fontWeight: FontWeight.w700,
              //     color: Colors.cyan,
              //     fontSize: isTablet ? 16 : 14,
              //   ),
              // ),
              // const SizedBox(height: 16),
              if (displayItem.mappedInstruments != null &&
                  displayItem.mappedInstruments!.isNotEmpty) ...[
                _DetailRow(
                  'Mapped Instruments',
                  displayItem.mappedInstruments!
                      .map((e) =>
                          e['productName'] ?? e['ProductName'] ?? 'Unknown')
                      .join(', '),
                ),
                const SizedBox(height: 12),
              ],
              if (displayItem.complaint != null &&
                  displayItem.complaint!.isNotEmpty) ...[
                _DetailRow('Complaint', displayItem.complaint!,
                    isMultiline: true),
                const SizedBox(height: 12),
              ],
              if (displayItem.actionTaken != null &&
                  displayItem.actionTaken!.isNotEmpty) ...[
                _DetailRow('Action Taken', displayItem.actionTaken!,
                    isMultiline: true),
                const SizedBox(height: 12),
              ],
              if (displayItem.result != null &&
                  displayItem.result!.isNotEmpty) ...[
                _DetailRow('Result', displayItem.result!, isMultiline: true),
                const SizedBox(height: 12),
              ],
              if (displayItem.complaintStatus != null &&
                  displayItem.complaintStatus!.isNotEmpty) ...[
                _DetailRow('Complaint Status', displayItem.complaintStatus!),
                const SizedBox(height: 12),
              ],
              if (displayItem.complaintDate != null &&
                  displayItem.complaintDate!.isNotEmpty) ...[
                _DetailRow('Complaint Date',
                    _formatComplaintDate(displayItem.complaintDate)),
                const SizedBox(height: 12),
              ],
              if (displayItem.complaintRemarks != null &&
                  displayItem.complaintRemarks!.isNotEmpty) ...[
                _DetailRow('Complaint Remarks', displayItem.complaintRemarks!,
                    isMultiline: true),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
      if (displayItem.remarks.isNotEmpty) ...[
        const SizedBox(height: 20),
        Divider(height: 1, color: Colors.grey.shade300),
        const SizedBox(height: 20),
        _DetailRow('Key Points Discussed', displayItem.remarks,
            isMultiline: true),
      ],
    ];
  }
}

class DcrManagerReviewList extends StatelessWidget {
  const DcrManagerReviewList({super.key});

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.now();
    final DateTime d = DateTime(today.year, today.month, today.day);

    return FutureBuilder<List<DcrEntry>>(
      future: _loadDcrList(d),
      initialData: const [],
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            snap.data?.isEmpty == true) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error loading DCR list: ${snap.error}'),
            ),
          );
        }

        final items = (snap.data ?? [])
            .where((e) =>
                e.status == DcrStatus.submitted ||
                e.status == DcrStatus.sentBack)
            .toList();
        return _ManagerReviewBody(initialItems: items);
      },
    );
  }

  Future<List<DcrEntry>> _loadDcrList(DateTime date) async {
    try {
      // Get employee ID from UserDetailStore
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      final int? employeeId = userStore?.userDetail?.employeeId;

      if (employeeId == null) {
        print('Error: Employee ID not available for manager review');
        return [];
      }

      final DcrRepository? dcrRepo =
          getIt.isRegistered<DcrRepository>() ? getIt<DcrRepository>() : null;
      if (dcrRepo == null) {
        print('Error: DCR Repository not registered');
        return [];
      }

      return await dcrRepo.listByDateRange(
          start: date, end: date, employeeId: employeeId.toString());
    } catch (e) {
      print('Error loading DCR list for manager: $e');
      return [];
    }
  }
}

class _ManagerReviewBody extends StatefulWidget {
  const _ManagerReviewBody({required this.initialItems});
  final List<DcrEntry> initialItems;
  @override
  State<_ManagerReviewBody> createState() => _ManagerReviewBodyState();
}

class _ManagerReviewBodyState extends State<_ManagerReviewBody> {
  late List<DcrEntry> _items = widget.initialItems;
  final Set<String> _selected = <String>{};

  void _showToast(String message,
      {ToastType type = ToastType.info, IconData? icon}) {
    if (!mounted) return;
    ToastMessage.show(
      context,
      message: message,
      type: type,
      icon: icon,
      useRootNavigator: true,
      duration: const Duration(seconds: 3),
    );
  }

  Widget _statusChipForManager(DcrStatus s) {
    switch (s) {
      case DcrStatus.draft:
        return const _StatusChip.pending('Draft');
      case DcrStatus.submitted:
        return const _StatusChip.pending('Submitted');
      case DcrStatus.approved:
        return const _StatusChip.approved('Approved');
      case DcrStatus.rejected:
        return const _StatusChip.rejected('Rejected');
      case DcrStatus.sentBack:
        return const _StatusChip.pending('Sent Back');
    }
  }

  /// Build empty state widget for manager review when no DCRs are pending
  Widget _buildManagerEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Empty state icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            'No DCRs Pending Review',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            'All DCRs have been reviewed or there are no submitted DCRs\nfor the selected date.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 32),

          // Action button
          ElevatedButton.icon(
            onPressed: () {
              // Refresh the data
              setState(() {
                // This will trigger a rebuild and reload
              });
            },
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return _buildManagerEmptyState();
    }
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('Pending: ${_items.length}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              InkWell(
                onTap: () {
                  setState(() {
                    if (_selected.length == _items.length) {
                      _selected.clear();
                    } else {
                      _selected
                        ..clear()
                        ..addAll(_items.map((e) => e.id));
                    }
                  });
                },
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Icon(
                      _selected.length == _items.length
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                        _selected.length == _items.length
                            ? 'Unselect All'
                            : 'Select All',
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final e = _items[index];
              final bool sel = _selected.contains(e.id);
              final Color statusColor = e.status == DcrStatus.sentBack
                  ? const Color(0xFFFFC54D)
                  : theme.colorScheme.primary;
              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border(
                        left: BorderSide(
                            color: statusColor.withOpacity(.6), width: 4)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: sel,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(e.id);
                                } else {
                                  _selected.remove(e.id);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${e.customer} • ${e.purposeOfVisit}',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Wrap(spacing: 8, runSpacing: 6, children: [
                                  _MiniChip(
                                      icon: Icons.person,
                                      label: e.employeeName),
                                  _MiniChip(
                                      icon: Icons.location_on,
                                      label: e.cluster),
                                  _statusChipForManager(e.status),
                                ]),
                              ],
                            ),
                          ),
                          // trailing actions removed; use bottom action bar
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(.06)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: Text('Approve (${_selected.length})',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _selected.isEmpty
                          ? null
                          : () => _approve(_selected.toList()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.undo),
                      label: const Text('Revert',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      style: FilledButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _selected.isEmpty
                          ? null
                          : () => _sendBack(_selected.toList()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel, color: Colors.redAccent),
                      label: const Text('Reject',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        side: BorderSide(
                            color: Colors.redAccent.withOpacity(.7), width: 1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _selected.isEmpty
                          ? null
                          : () => _reject(_selected.toList()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _approve(List<String> ids) async {
    print('DCR List Screen: Approving DCRs - IDs: $ids');
    if (getIt.isRegistered<DcrRepository>()) {
      await getIt<DcrRepository>().approve(ids);
    }
    setState(() {
      _items = _items
          .map((e) =>
              ids.contains(e.id) ? e.copyWith(status: DcrStatus.approved) : e)
          .toList();
      _selected.removeWhere((id) => ids.contains(id));
    });
    print('DCR List Screen: DCRs approved successfully');
  }

  Future<void> _sendBack(List<String> ids) async {
    print('DCR List Screen: Sending back DCRs - IDs: $ids');
    if (getIt.isRegistered<DcrRepository>()) {
      await getIt<DcrRepository>().sendBack(ids, comment: '');
    }
    setState(() {
      _items = _items
          .map((e) =>
              ids.contains(e.id) ? e.copyWith(status: DcrStatus.sentBack) : e)
          .toList();
      _selected.removeWhere((id) => ids.contains(id));
    });
    print('DCR List Screen: DCRs sent back successfully');
  }

  Future<void> _reject(List<String> ids) async {
    if (getIt.isRegistered<DcrRepository>()) {
      await getIt<DcrRepository>().reject(ids, comment: '');
    }
    setState(() {
      _items = _items
          .map((e) =>
              ids.contains(e.id) ? e.copyWith(status: DcrStatus.rejected) : e)
          .toList();
      _selected.removeWhere((id) => ids.contains(id));
    });
  }

  // Expense approval methods
  Future<void> _approveExpenseSingle(int expenseId,
      {String comment = ''}) async {
    print('DCR List Screen: Approving expense - ID: $expenseId');
    try {
      if (getIt.isRegistered<ExpenseRepository>()) {
        final result = await getIt<ExpenseRepository>()
            .approveExpenseSingle(expenseId, comment: comment);
        print('Expense approved: $result');
        if (mounted) {
          _showToast(
            'Expense approved successfully',
            type: ToastType.success,
          );
        }
      }
    } catch (e) {
      print('Error approving expense: $e');
      if (mounted) {
        _showToast(
          'Error approving expense: ${e.toString()}',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _sendBackExpenseSingle(int expenseId,
      {String comment = ''}) async {
    print('DCR List Screen: Sending back expense - ID: $expenseId');
    try {
      if (getIt.isRegistered<ExpenseRepository>()) {
        final result = await getIt<ExpenseRepository>()
            .sendBackExpenseSingle(expenseId, comment: comment);
        print('Expense sent back: $result');
        if (mounted) {
          _showToast(
            'Expense sent back successfully',
            type: ToastType.success,
          );
        }
      }
    } catch (e) {
      print('Error sending back expense: $e');
      if (mounted) {
        _showToast(
          'Error sending back expense: ${e.toString()}',
          type: ToastType.error,
        );
      }
    }
  }
}

// Helper widget for detail rows in the popup
class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.isMultiline = false});

  final String label;
  final String value;
  final bool isMultiline;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenWidth = MediaQuery.of(context).size.width;
    final labelWidth =
        isMobile ? (screenWidth * 0.38).clamp(100.0, 140.0) : 120.0;

    return Row(
      crossAxisAlignment:
          isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 11 : 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: isMobile ? 8 : 12),
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
}

// ---------- UI helpers to match screenshot styling ----------

_StatusChip _getStatusChipForItem(UnifiedDcrItem item) {
  // Clean and normalize the status text
  final statusText = item.statusText.trim().toLowerCase();

  if (item.isDcr) {
    // Map status text to DCR status with more flexible matching
    if (statusText.contains('draft')) {
      return const _StatusChip.pending('Draft');
    } else if (statusText.contains('submitted')) {
      return const _StatusChip.pending('Submitted');
    } else if (statusText.contains('approved')) {
      return const _StatusChip.approved('Approved');
    } else if (statusText.contains('rejected')) {
      return const _StatusChip.rejected('Rejected');
    } else if (statusText.contains('missed')) {
      return const _StatusChip.missed('Missed');
    } else if (statusText.contains('sent back') ||
        statusText.contains('sentback')) {
      return const _StatusChip.pending('Sent Back');
    } else {
      // If we don't recognize the status, try to map based on dcrStatusId
      print(
          'Unknown DCR status: "$statusText", trying dcrStatusId=${item.dcrStatusId}');

      // Map based on dcrStatusId as fallback
      switch (item.dcrStatusId) {
        case 0:
          return const _StatusChip.pending('Draft');
        case 1:
          return const _StatusChip.pending('Draft');
        case 2:
          return const _StatusChip.pending('Submitted');
        case 3:
          return const _StatusChip.pending('Submitted');
        case 4:
          return const _StatusChip.approved('Approved');
        case 5:
          return const _StatusChip.rejected('Rejected');
        case 6:
          return const _StatusChip.pending('Sent Back');
        default:
          return _StatusChip.pending(
              item.statusText.isNotEmpty ? item.statusText : 'Unknown');
      }
    }
  } else {
    // Map status text to Expense status
    if (statusText.contains('draft')) {
      return const _StatusChip.pending('Draft');
    } else if (statusText.contains('submitted')) {
      return const _StatusChip.pending('Submitted');
    } else if (statusText.contains('approved')) {
      return const _StatusChip.approved('Approved');
    } else if (statusText.contains('rejected')) {
      return const _StatusChip.rejected('Rejected');
    } else if (statusText.contains('missed')) {
      return const _StatusChip.missed('Missed');
    } else if (statusText.contains('sent back') ||
        statusText.contains('sentback')) {
      return const _StatusChip.pending('Sent Back');
    } else if (statusText.contains('expense')) {
      // For expenses, if statusText is "Expense", try to use dcrStatusId to determine actual status
      // Map dcrStatusId to ExpenseStatus
      // Common mappings: 0=Draft, 1=Draft, 2=SentBack, 3=Submitted, 4=SentBack, 5=Approved
      switch (item.dcrStatusId) {
        case 0:
        case 1:
          return const _StatusChip.pending('Draft');
        case 2:
          return const _StatusChip.pending('Sent Back');
        case 3:
          return const _StatusChip.pending('Submitted');
        case 4:
          return const _StatusChip.pending('Sent Back');
        case 5:
          return const _StatusChip.approved('Approved');
        default:
          return const _StatusChip.expense('Expense');
      }
    } else {
      print('Unknown Expense status: "$statusText"');
      return _StatusChip.pending(
          item.statusText.isNotEmpty ? item.statusText : 'Unknown');
    }
  }
}

class _UnifiedItemCard extends StatelessWidget {
  const _UnifiedItemCard({
    required this.item,
    this.onCreateDeviation,
    this.onEdit,
    this.onViewDetails,
    this.onViewFull,
    this.isEditable = true,
    this.currentPosition,
    this.geoFenceRadiusMeters,
  });

  final UnifiedDcrItem item;
  final VoidCallback? onCreateDeviation;
  final VoidCallback? onEdit;
  final VoidCallback? onViewDetails;
  final VoidCallback? onViewFull;
  final bool isEditable;
  final Position? currentPosition;
  final double? geoFenceRadiusMeters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallMobile = screenWidth < 360;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600;

    final TextStyle label = GoogleFonts.inter(
        color: Colors.black54,
        fontWeight: FontWeight.w600,
        fontSize: isMobile ? 13 : 14);
    final TextStyle value = GoogleFonts.inter(
        color: const Color(0xFF1F2937),
        fontWeight: FontWeight.w600,
        fontSize: isMobile ? 14 : 15);

    final String headerTitle = (item.displayTitle ?? '').isNotEmpty
        ? item.displayTitle!
        : (item.isExpense ? 'Expense' : 'DCR');
    return InkWell(
      onTap: onViewDetails,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(.06), width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.03),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        padding: EdgeInsets.all(isSmallMobile ? 10 : (isMobile ? 12 : 14)),
        margin: EdgeInsets.only(bottom: isMobile ? 8 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: Icon + Title + View
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: isTablet ? 40 : 36,
                  height: isTablet ? 40 : 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.isExpense
                        ? Icons.account_balance_wallet_outlined
                        : Icons.description_outlined,
                    color: const Color(0xFF4db1b3),
                    size: isTablet ? 20 : 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    headerTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 13 : 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (onViewFull != null)
                  TextButton.icon(
                    onPressed: onViewFull,
                    icon: Icon(
                      Icons.visibility_outlined,
                      size: isTablet ? 16 : 14,
                      color: const Color(0xFF4db1b3),
                    ),
                    label: Text(
                      'View',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 12 : 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4db1b3),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 8 : 6,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Employee and Date row
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
                    item.employeeName.isNotEmpty
                        ? item.employeeName
                        : 'Unknown',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 11 : 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.calendar_today_outlined,
                  size: isTablet ? 13 : 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 5),
                Text(
                  _formatItemDate(item),
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 11 : 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Status and distance row (simplified)
            Row(
              children: [
                _getStatusChipForItem(item),
                const Spacer(),
                // Geo proximity + distance (DCR only)
                if (item.isDcr) ...[
                  _ProximityDot(inRange: _isInRange(item)),
                  const SizedBox(width: 5),
                  if (_getDistanceText(item) != null)
                    Text(
                      _getDistanceText(item)!,
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 11 : 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                ] else if (item.expenseAmount != null) ...[
                  Text(
                    'LKR ${item.expenseAmount!.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 12 : 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _kvRow(BuildContext context, String label, String valueText,
      TextStyle? lStyle, TextStyle? vStyle) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final bool isSmallMobile = MediaQuery.of(context).size.width < 360;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallMobile ? 3 : 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: isMobile ? 2 : 1,
            child: Text(
              label,
              style: GoogleFonts.inter(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  fontSize: isSmallMobile ? 11 : (isMobile ? 12 : 13),
                  letterSpacing: 0.1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: isSmallMobile ? 10 : 16),
          Expanded(
            flex: isMobile ? 3 : 2,
            child: Text(
              valueText,
              style: GoogleFonts.inter(
                  color: const Color(0xFF1F1F1F),
                  fontWeight: FontWeight.w500,
                  fontSize: isSmallMobile ? 12 : (isMobile ? 13 : 14),
                  letterSpacing: -0.1),
              textAlign: TextAlign.right,
              overflow: TextOverflow.visible,
              maxLines: isMobile ? (isSmallMobile ? 4 : 3) : 2,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  // Icon + key/value row to match compact list design
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
              letterSpacing: 0.1,
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
              letterSpacing: -0.1,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  bool _isInRange(UnifiedDcrItem item) {
    // Check if we have valid coordinates for both user and customer
    if (currentPosition == null) {
      return false;
    }

    if (item.customerLatitude == null ||
        item.customerLongitude == null ||
        item.customerLatitude == 0.0 ||
        item.customerLongitude == 0.0) {
      return false;
    }

    // Calculate distance between user and customer
    final double distanceMeters = Geolocator.distanceBetween(
      currentPosition!.latitude,
      currentPosition!.longitude,
      item.customerLatitude!,
      item.customerLongitude!,
    );

    // Check if within geofence radius (default to 20km if not provided)
    final double radius = geoFenceRadiusMeters ?? 20000;
    return distanceMeters <= radius;
  }

  String? _getDistanceText(UnifiedDcrItem item) {
    // Only show distance for DCR items with valid coordinates
    if (!item.isDcr) {
      return null;
    }

    if (currentPosition == null) {
      return null;
    }
    // Ignore invalid device coordinates (0,0)
    if (currentPosition!.latitude.abs() < 0.0001 &&
        currentPosition!.longitude.abs() < 0.0001) {
      return null;
    }

    if (item.customerLatitude == null ||
        item.customerLongitude == null ||
        item.customerLatitude == 0.0 ||
        item.customerLongitude == 0.0) {
      return null;
    }

    // Calculate distance between user and customer
    final double distanceMeters = Geolocator.distanceBetween(
      currentPosition!.latitude,
      currentPosition!.longitude,
      item.customerLatitude!,
      item.customerLongitude!,
    );

    // Format distance text
    // Treat < 50m as "At location" to avoid confusing "0 m"
    if (distanceMeters < 50) {
      return 'At location';
    } else if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)} m';
    } else {
      final double km = distanceMeters / 1000.0;
      return '${km.toStringAsFixed(2)} km';
    }
  }

  String _formatItemDate(UnifiedDcrItem item) {
    try {
      final DateTime? parsed = item.parsedDate;
      if (parsed != null) {
        return '${parsed.day.toString().padLeft(2, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.year}';
      }
    } catch (e) {
      // Fallback to raw date string if parsing fails
    }
    // Fallback: return the raw date string or a default
    return item.dcrDate.isNotEmpty ? item.dcrDate : 'N/A';
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color border = Theme.of(context).dividerColor.withOpacity(.25);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Material(
        color: Colors.white,
        shape: StadiumBorder(side: BorderSide(color: border)),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color border = Theme.of(context).dividerColor.withOpacity(.25);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140),
      child: Material(
        color: Colors.white,
        shape: StadiumBorder(side: BorderSide(color: border)),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge)),
                const SizedBox(width: 8),
                const Icon(Icons.expand_more, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedPills extends StatelessWidget {
  const _SegmentedPills(
      {required this.options,
      required this.selectedIndex,
      required this.onChanged});
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
        border: Border.all(color: Colors.black.withOpacity(.06)),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          for (int i = 0; i < options.length; i++)
            Expanded(
              child: _SelectablePill(
                label: options[i],
                selected: i == selectedIndex,
                onTap: () => onChanged(i),
                selectedColor: scheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectablePill extends StatelessWidget {
  const _SelectablePill(
      {required this.label,
      required this.selected,
      required this.onTap,
      required this.selectedColor});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = Theme.of(context).textTheme.titleMedium ??
        const TextStyle(fontSize: 16);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [selectedColor.withOpacity(.75), selectedColor])
              : null,
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: selected
              ? style.copyWith(color: Colors.white, fontWeight: FontWeight.w700)
              : style.copyWith(
                  color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.title, required this.actionText, required this.child});
  final String title;
  final String actionText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInRange = actionText.toLowerCase().contains('in-range');
    final statusColor =
        isInRange ? const Color(0xFF2DBE64) : const Color(0xFFE53935);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.black.withOpacity(.06), width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.grey.shade900,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: statusColor.withOpacity(.25), width: 2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      actionText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF6F7FA),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _DcrDetails extends StatelessWidget {
  const _DcrDetails(
      {required this.cluster,
      required this.customer,
      required this.purpose,
      required this.status,
      this.geo,
      this.hasTourPlan = false,
      this.distanceText,
      this.onCreateDeviation,
      this.onEdit});
  final String cluster;
  final String customer;
  final String purpose;
  final _StatusChip status;
  final GeoProximity? geo;
  final bool hasTourPlan;
  final String? distanceText;
  final VoidCallback? onCreateDeviation;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final TextStyle? label = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: Colors.black45, fontWeight: FontWeight.w600);
    final TextStyle? value = Theme.of(context)
        .textTheme
        .bodyLarge
        ?.copyWith(color: const Color(0xFF12223B), fontWeight: FontWeight.w800);
    final String trimmedCustomer = customer.trim();
    final bool showCustomer =
        trimmedCustomer.isNotEmpty && trimmedCustomer != 'Unknown Customer';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Cluster', style: label)),
            Expanded(
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (hasTourPlan)
                  _MiniChip(icon: Icons.event_available, label: 'Planned')
                else
                  _MiniChip(icon: Icons.bolt, label: 'Ad-hoc'),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(cluster,
                        style: value,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (showCustomer) ...[
          Row(
            children: [
              Expanded(child: Text('Customer', style: label)),
              Expanded(
                  child: Text(trimmedCustomer,
                      style: value,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2)),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(child: Text('Purpose', style: label)),
            Expanded(
                child: Text(purpose,
                    style: value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('DCR Status', style: label),
            const Spacer(),
            status,
          ],
        ),
        const SizedBox(height: 12),
        if (geo != null)
          Row(
            children: [
              _ProximityDot(inRange: geo == GeoProximity.at),
              const SizedBox(width: 8),
              if (distanceText != null)
                _MiniChip(icon: Icons.straighten, label: distanceText!),
              const Spacer(),
              if (onEdit != null)
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                    label: const Text(
                      'Edit',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                ),
              if (!hasTourPlan && onCreateDeviation != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onCreateDeviation,
                    icon: const Icon(Icons.alt_route,
                        size: 16, color: Colors.white),
                    label: const Text(
                      'Create Dev',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _row(String l, String v, TextStyle? lStyle, TextStyle? vStyle) {
    return Row(
      children: [
        Expanded(child: Text(l, style: lStyle)),
        Expanded(child: Text(v, style: vStyle, textAlign: TextAlign.right)),
      ],
    );
  }
}

class _ExpenseDetails extends StatelessWidget {
  const _ExpenseDetails(
      {required this.cluster,
      required this.expenseTitle,
      required this.amountText,
      required this.status});
  final String cluster;
  final String expenseTitle;
  final String amountText;
  final _StatusChip status;

  @override
  Widget build(BuildContext context) {
    final TextStyle? label = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: Colors.black45, fontWeight: FontWeight.w600);
    final TextStyle? value = Theme.of(context)
        .textTheme
        .bodyLarge
        ?.copyWith(color: const Color(0xFF12223B), fontWeight: FontWeight.w800);
    final TextStyle? amountStyle = Theme.of(context)
        .textTheme
        .bodyLarge
        ?.copyWith(color: const Color(0xFF12223B), fontWeight: FontWeight.w800);
    final String trimmedCluster = cluster.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (trimmedCluster.isNotEmpty) ...[
          _row('Cluster', trimmedCluster, label, value),
          const SizedBox(height: 12),
        ],
        _row('Customer', expenseTitle, label, value),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text('Purpose', style: label)),
            Expanded(
                child: Text(amountText,
                    style: amountStyle, textAlign: TextAlign.right)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Expense Status', style: label),
            const Spacer(),
            status,
          ],
        ),
      ],
    );
  }

  Widget _row(String l, String v, TextStyle? lStyle, TextStyle? vStyle) {
    return Row(
      children: [
        Expanded(child: Text(l, style: lStyle)),
        Expanded(child: Text(v, style: vStyle, textAlign: TextAlign.right)),
      ],
    );
  }
}

class _DcrCompactCard extends StatelessWidget {
  const _DcrCompactCard({
    required this.cluster,
    required this.customer,
    required this.purpose,
    required this.statusChip,
    required this.isAdhoc,
    this.geo,
    this.distanceText,
    this.onCreateDeviation,
    this.onEdit,
  });
  final String cluster;
  final String customer;
  final String purpose;
  final _StatusChip statusChip;
  final bool isAdhoc;
  final GeoProximity? geo;
  final String? distanceText;
  final VoidCallback? onCreateDeviation;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final TextStyle? label = theme.textTheme.bodyMedium
        ?.copyWith(color: Colors.black45, fontWeight: FontWeight.w600);
    final TextStyle? value = theme.textTheme.bodyLarge
        ?.copyWith(color: const Color(0xFF12223B), fontWeight: FontWeight.w800);
    final String trimmedCustomer = customer.trim();
    final bool showCustomer =
        trimmedCustomer.isNotEmpty && trimmedCustomer != 'Unknown Customer';
    final bool inRange = geo == GeoProximity.at;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(.06)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 12,
              offset: const Offset(0, 6))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Ad-hoc/Planned + Status + actions + dot
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ProximityDot(inRange: inRange),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MiniChip(
                        icon: isAdhoc ? Icons.bolt : Icons.event_available,
                        label: isAdhoc ? 'Ad-hoc' : 'Planned'),
                    statusChip,
                  ],
                ),
              ),
              if (onCreateDeviation != null)
                IconButton(
                  tooltip: 'Create deviation',
                  onPressed: onCreateDeviation,
                  icon: const Icon(Icons.alt_route, size: 20),
                ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
              height: 1, thickness: 1, color: Colors.black.withOpacity(.06)),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          _kvRow('Cluster', cluster, label, value),
          const SizedBox(height: 10),
          if (showCustomer) ...[
            _kvRow('Customer', trimmedCustomer, label, value),
            const SizedBox(height: 10),
          ],
          _kvRow('Purpose', purpose, label, value),
        ],
      ),
    );
  }

  Widget _kvRow(
      String label, String valueText, TextStyle? lStyle, TextStyle? vStyle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: lStyle)),
        Expanded(
            child: Text(valueText,
                style: vStyle,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                maxLines: 2)),
      ],
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
                            ?.copyWith(fontWeight: FontWeight.w500))),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip._(this.text, this.color);
  const _StatusChip.approved(String text)
      : this._(text, const Color(0xFF2DBE64));
  const _StatusChip.pending(String text)
      : this._(text, const Color(0xFFFFC54D));
  const _StatusChip.expense(String text)
      : this._(text, const Color(0xFF00C4DE));
  const _StatusChip.rejected(String text)
      : this._(text, const Color(0xFFE53935));
  const _StatusChip.missed(String text) : this._(text, const Color(0xFF9E9E9E));

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 9, vertical: isMobile ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: isMobile ? 5 : 6,
            height: isMobile ? 5 : 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: isMobile ? 5 : 6),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 10 : 11,
                    letterSpacing: 0.1,
                    height: 1.2,
                  ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.black54),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProximityDot extends StatelessWidget {
  const _ProximityDot({required this.inRange});
  final bool inRange;
  @override
  Widget build(BuildContext context) {
    final Color color =
        inRange ? const Color(0xFF2DBE64) : const Color(0xFFFFC54D);
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: color.withOpacity(.35), width: 3),
      ),
    );
  }
}

class _ClusterGroup {
  _ClusterGroup({required this.cluster, required this.items});
  final String cluster;
  final List<UnifiedDcrItem> items;
}

extension _Grouping on _DcrListScreenState {
  List<_ClusterGroup> _groupedByClusterOrAdhoc() {
    final Map<String, List<UnifiedDcrItem>> itemsByCluster = {};

    for (final item in _applyFilters(_unifiedItems)) {
      String group;
      if (item.isDcr) {
        group = (item.tourPlanId == 0) ? 'Ad-hoc' : item.clusterDisplayName;
      } else {
        group = item.clusterDisplayName;
      }
      (itemsByCluster[group] ??= []).add(item);
    }

    return itemsByCluster.entries
        .map((entry) => _ClusterGroup(cluster: entry.key, items: entry.value))
        .toList();
  }

  List<UnifiedDcrItem> _applyFilters(List<UnifiedDcrItem> list) {
    return list.where((item) {
      // Transaction type filter
      final String transactionType = item.isDcr ? 'DCR' : 'Expense';
      final byTransactionType =
          _selectedTransactionTypes.contains(transactionType);

      // Status filter
      final byStatus =
          _status == null || _getStatusChipForItem(item).text == _status;

      return byTransactionType && byStatus;
    }).toList();
  }

  // Get filter count (number of active filters)
  int _getFilterCount() {
    int count = 0;
    if (_status != null) count++;
    if (_selectedTransactionTypes.length != 2)
      count++; // If not both selected, it's a filter
    // Count employee only if the filter is enabled (not MR role)
    if (_employee != null && !_shouldDisableEmployeeFilter()) count++;
    // Count date if not today
    if (!_isDefaultDateFilter()) count++;
    return count;
  }

  // Get filtered records count
  int _getFilteredRecordsCount() {
    return _applyFilters(_unifiedItems).length;
  }

  // Get DCR count
  int _getDcrCount() {
    return _unifiedItems.where((item) => item.isDcr).length;
  }

  // Get Expense count
  int _getExpenseCount() {
    return _unifiedItems.where((item) => item.isExpense).length;
  }

  // Open filter modal
  void _openFilterModal() {
    setState(() {
      _showFilterModal = true;
    });
    _filterModalController.forward();
  }

  // Close filter modal
  void _closeFilterModal() {
    _filterModalController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showFilterModal = false;
        });
      }
    });
  }

  // Apply filters from modal
  void _applyFiltersFromModal() {
    _closeFilterModal();
    _load(); // Reload data with new filters
    _showToast(
      'Filters applied',
      type: ToastType.success,
      icon: Icons.filter_alt,
    );
  }

  _StatusChip _statusChipFor(DcrStatus s) {
    switch (s) {
      case DcrStatus.draft:
        return const _StatusChip.pending('Draft');
      case DcrStatus.submitted:
        return const _StatusChip.pending('Submitted');
      case DcrStatus.approved:
        return const _StatusChip.approved('Approved');
      case DcrStatus.rejected:
        return const _StatusChip.rejected('Rejected');
      case DcrStatus.sentBack:
        return const _StatusChip.pending('Sent Back');
    }
  }

  _StatusChip _expenseStatusChipFor(ExpenseStatus s) {
    switch (s) {
      case ExpenseStatus.draft:
        return const _StatusChip.pending('Draft');
      case ExpenseStatus.submitted:
        return const _StatusChip.pending('Submitted');
      case ExpenseStatus.approved:
        return const _StatusChip.approved('Approved');
      case ExpenseStatus.rejected:
        return const _StatusChip.rejected('Rejected');
      case ExpenseStatus.sentBack:
        return const _StatusChip.pending('Sent Back');
    }
  }

  // Helpers for mapping selected filters
  int? _selectedEmployeeId() {
    if (_employee == null) return null;
    return _employeeNameToId[_employee!];
  }

  int? _statusIdFromText(String? text) =>
      text == null ? null : _statusNameToId[text];

  String _groupInRangeText(_ClusterGroup g) {
    // Consider only DCR items for geo stats
    final dcrItems = g.items.where((i) => i.isDcr).toList();
    final int totalGeo = dcrItems.length;
    if (totalGeo == 0) return 'Out-of-range 0/0';
    // If device location is unavailable/invalid, avoid misleading out-of-range label
    if (_currentPosition == null ||
        (_currentPosition!.latitude.abs() < 0.0001 &&
            _currentPosition!.longitude.abs() < 0.0001)) {
      return 'Geo off 0/$totalGeo';
    }
    final int inRange = dcrItems.where((item) {
      if (_currentPosition == null ||
          item.customerLatitude == null ||
          item.customerLongitude == null ||
          item.customerLatitude == 0.0 ||
          item.customerLongitude == 0.0) {
        return false;
      }
      final double distanceMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        item.customerLatitude!,
        item.customerLongitude!,
      );
      return distanceMeters <= _geoFenceRadiusMeters;
    }).length;
    return inRange > 0
        ? 'In-range $inRange/$totalGeo'
        : 'Out-of-range 0/$totalGeo';
  }
}

// Enhanced UI Components for DCR Filters
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
    final Color iconColor =
        isActive ? Colors.blue.shade600 : theme.colorScheme.primary;
    final Color textColor =
        isActive ? Colors.blue.shade700 : Colors.grey.shade700;
    final Color borderColor =
        isActive ? Colors.blue.shade200 : Colors.grey.shade200;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      elevation: isActive ? 3 : 2,
      shadowColor: isActive
          ? Colors.blue.withOpacity(0.2)
          : Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              const SizedBox(width: 4),
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
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final Color backgroundColor =
        isActive ? Colors.red.shade50 : Colors.grey.shade100;
    final Color iconColor =
        isActive ? Colors.red.shade600 : Colors.grey.shade600;
    final Color textColor =
        isActive ? Colors.red.shade700 : Colors.grey.shade600;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isActive ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 12,
            vertical: isMobile ? 12 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isActive ? Border.all(color: Colors.red.shade200) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_off,
                size: isMobile ? 18 : 16,
                color: iconColor,
              ),
              SizedBox(width: isMobile ? 8 : 6),
              Flexible(
                child: Text(
                  'Clear',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: textColor,
                    fontSize: isMobile ? 13 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Searchable Filter Dropdown (ported from Tour Plan filter UI)
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
              color: _DcrListScreenState.tealGreen,
            ),
            SizedBox(width: widget.isTablet ? 10 : 8),
            Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: widget.isTablet ? 16 : 14,
                fontWeight: FontWeight.normal,
                color: Colors.grey[900],
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
                    ? _DcrListScreenState.tealGreen.withOpacity(0.1)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.selectedValue != null
                      ? _DcrListScreenState.tealGreen.withOpacity(0.3)
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
                            ? _DcrListScreenState.tealGreen
                            : Colors.grey[600],
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
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close_rounded,
                                size: 16, color: _DcrListScreenState.tealGreen),
                          ),
                        ),
                      ),
                    ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: widget.isTablet ? 20 : 18,
                    color: _DcrListScreenState.tealGreen,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isExpanded)
          Container(
            margin: EdgeInsets.only(top: widget.isTablet ? 12 : 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _DcrListScreenState.tealGreen.withOpacity(0.2),
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
                                    color: Colors.grey[500],
                                    size: widget.isTablet ? 18 : 16,
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
                            borderSide:
                                BorderSide(color: Colors.grey[200]!, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.grey[200]!, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: _DcrListScreenState.tealGreen, width: 2),
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
                // Options
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
                                        ? _DcrListScreenState.tealGreen
                                            .withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(
                                            color: _DcrListScreenState.tealGreen
                                                .withOpacity(0.3),
                                            width: 1)
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: widget.isTablet ? 18 : 16,
                                        height: widget.isTablet ? 18 : 16,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? _DcrListScreenState.tealGreen
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isSelected
                                                ? _DcrListScreenState.tealGreen
                                                : Colors.grey[400]!,
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check_rounded,
                                                size: 12, color: Colors.white)
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
                                                ? _DcrListScreenState.tealGreen
                                                : Colors.grey[700],
                                          ),
                                          overflow: TextOverflow.ellipsis,
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

// Enhanced Action Button for better user engagement
class _EnhancedActionButton extends StatelessWidget {
  const _EnhancedActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.isMobile = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
      elevation: 2,
      shadowColor: color.withOpacity(0.3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16,
            vertical: isMobile ? 10 : 14,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: isMobile ? 16 : 20, color: Colors.white),
              SizedBox(width: isMobile ? 6 : 8),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced Date Selector
class _EnhancedDateSelector extends StatelessWidget {
  const _EnhancedDateSelector({
    required this.label,
    this.onTap,
    this.isActive = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    // Use app teal theme for consistency with Tour Plan design
    final Color primary = _DcrListScreenState.tealGreen;
    final Color backgroundColor =
        isActive ? primary.withOpacity(0.10) : Colors.grey.shade50;
    final Color iconColor = isActive ? primary : Colors.grey.shade600;
    final Color textColor = isActive ? primary : Colors.grey.shade700;
    final Color borderColor =
        isActive ? primary.withOpacity(0.30) : Colors.grey.shade200;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      elevation: isActive ? 3 : 2,
      shadowColor:
          isActive ? primary.withOpacity(0.2) : Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: textColor,
                      ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: 14,
                color: isActive ? primary : Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
