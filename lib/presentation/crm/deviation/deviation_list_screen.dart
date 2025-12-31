import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:boilerplate/presentation/crm/deviation/deviation_entry_screen.dart';
import 'package:boilerplate/domain/repository/deviation/deviation_repository.dart';
import 'package:boilerplate/domain/entity/deviation/deviation_api_models.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';

import '../../user/store/user_store.dart';
import '../../user/store/user_validation_store.dart';

class DeviationListScreen extends StatefulWidget {
  const DeviationListScreen({super.key});

  // Static reference for external refresh access
  static _DeviationListScreenState? _currentInstance;

  @override
  State<DeviationListScreen> createState() => _DeviationListScreenState();

  // Static method to refresh from external sources
  static void refreshCurrentInstance() {
    _currentInstance?.refreshData();
  }
}

class _DeviationListScreenState extends State<DeviationListScreen>
    with SingleTickerProviderStateMixin {
  String? _employee;
  String? _status;
  String? _customer;
  String _search = '';
  List<DeviationApiItem> _deviations = [];
  List<DeviationApiItem> _filteredDeviations = []; // Store filtered results
  bool _isLoading = false;
  final Set<int> _selectedDeviations = <int>{};
  List<String> _statusList = ['Pending', 'Approved', 'Draft'];
  List<String> _employeeList = [];
  List<String> _customerList = [];
  final Map<String, int> _employeeNameToId = {};
  final Map<String, int> _customerNameToId = {};
  final Map<String, int> _statusNameToId = {}; // Map status names to IDs
  bool _hasLoadedInitialData = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  bool _isManager = false; // Track if user is a manager
  final ScrollController _listScrollController = ScrollController();

  // Filter modal state
  AnimationController? _filterModalController;
  Animation<Offset>? _filterModalAnimation;
  bool _showFilterModal = false;
  VoidCallback? _pendingFilterApply;
  final ScrollController _filterScrollController = ScrollController();
  final GlobalKey _statusFilterSectionKey = GlobalKey();
  final GlobalKey _employeeFilterSectionKey = GlobalKey();
  final GlobalKey _customerFilterSectionKey = GlobalKey();

  void _dismissKeyboard() {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
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

  @override
  void initState() {
    super.initState();
    // Initialize filter modal animation
    _filterModalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final curvedAnimation = CurvedAnimation(
      parent: _filterModalController!,
      curve: Curves.easeOut,
    );
    _filterModalAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(curvedAnimation);
    // Add focus listener to update UI when focus changes
    _searchFocusNode.addListener(() {
      setState(() {}); // Rebuild to show/hide focus state
    });
    // Register this instance for external refresh access
    DeviationListScreen._currentInstance = this;
    _checkManagerStatus();
    _loadDeviations();
    _loadDeviationStatusList();
    _getEmployeeList();
    _loadCustomerList();
    _hasLoadedInitialData = true;

    // Validate user when screen opens
    _validateUserOnScreenOpen();
  }

  /// Validate user when Deviation screen opens
  Future<void> _validateUserOnScreenOpen() async {
    try {
      if (getIt.isRegistered<UserValidationStore>()) {
        final validationStore = getIt<UserValidationStore>();
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        if (user != null && (user.userId != null || user.id != null)) {
          final userId = user.userId ?? user.id;
          print(
              '📱 [DeviationListScreen] Validating user on screen open - userId: $userId');
          await validationStore.validateUser(userId!);
        } else {
          print('⚠️ [DeviationListScreen] User not available for validation');
        }
      }
    } catch (e) {
      print('❌ [DeviationListScreen] Error validating user: $e');
    }
  }

  @override
  void dispose() {
    // Unregister this instance when disposed
    if (DeviationListScreen._currentInstance == this) {
      DeviationListScreen._currentInstance = null;
    }
    _filterModalController?.dispose();
    _filterScrollController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only refresh on initial load, not on every dependency change
    // The navigation callbacks will handle refresh when returning from deviation entry
  }

  Future<void> _loadDeviations() async {
    setState(() => _isLoading = true);

    try {
      if (getIt.isRegistered<DeviationRepository>()) {
        final deviationRepo = getIt<DeviationRepository>();
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
            ? getIt<UserDetailStore>()
            : null;
        final int? employeeId = userStore?.userDetail?.employeeId;

        if (user != null && employeeId != null) {
          // Get the selected employee ID for filtering
          int? filterEmployeeId = employeeId; // Default to current user
          if (_employee != null) {
            filterEmployeeId = _employeeNameToId[_employee];
            print('Filtering by employee: $_employee (ID: $filterEmployeeId)');
            if (filterEmployeeId == null) {
              print('ERROR: Employee ID not found for $_employee');
              print('Available employees: $_employeeNameToId');
            }
          } else {
            print('Showing all employees (current user: $employeeId)');
          }

          print(
              'Loading deviations with filters - Employee: $filterEmployeeId, Status: $_status');

          final response = await deviationRepo.getDeviationList(
            searchText: _search,
            pageNumber: 1,
            pageSize: 1000,
            userId: user.userId,
            bizUnit: user.sbuId,
            employeeId: filterEmployeeId ?? employeeId,
          );

          if (mounted) {
            print(
                'DeviationListScreen: Received ${response.items.length} deviations from API');
            setState(() {
              _deviations = response.items;
            });
            _applyStatusAndCustomerFilter(); // Apply client-side filters

            // Debug: Show sample data
            if (_deviations.isNotEmpty) {
              print('Sample deviation data:');
              for (var deviation in _deviations.take(3)) {
              print(
                  '  - Employee: ${deviation.employeeName}, Status: ${deviation.deviationStatus1 ?? deviation.deviationStatus}, Customer: ${deviation.clusterName}');
              }
            }
          }
        } else {
          print('DeviationListScreen: User or EmployeeId not available');
          if (mounted) {
            ToastMessage.show(
              context,
              message: 'User information not available. Please login again.',
              type: ToastType.error,
              useRootNavigator: true,
              duration: const Duration(seconds: 3),
            );
          }
        }
      }
    } catch (e) {
      print('Error loading deviations: $e');
      // Fallback to mock data if API fails
      if (mounted) {
        setState(() {
          _deviations = _convertMockToApiItems();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Method to refresh data when returning from deviation entry screen
  Future<void> refreshData() async {
    print(
        'DeviationListScreen: Refreshing data after returning from deviation entry...');
    // Add a small delay to ensure the deviation entry screen has completed its save operation
    await Future.delayed(const Duration(milliseconds: 500));
    await _loadDeviations();
  }

  // Method to reset all filters and reload data
  Future<void> _resetFilters() async {
    setState(() {
      _search = '';
      // Preserve employee filter if roleCategory === 3
      if (!_shouldDisableEmployeeFilter()) {
        _employee = null;
      }
      _status = null;
      _customer = null;
    });
    _searchController.clear();
    await _loadDeviations();
  }

  // Check if current user is a manager
  Future<void> _checkManagerStatus() async {
    try {
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      final userDetail = userStore?.userDetail;

      if (userDetail != null) {
        // Check if user has manager role or permissions
        // This is a simplified check - you may need to adjust based on your role system
        setState(() {
          _isManager =
              userDetail.roleText?.toLowerCase().contains('manager') ?? false;
        });
      }
    } catch (e) {
      print('Error checking manager status: $e');
    }
  }

  void _applyStatusAndCustomerFilter() {
    setState(() {
      // Apply client-side filtering for status and customer
      _filteredDeviations = _deviations.where((e) {
        // Status matching - handle variations (case-insensitive, handle hyphens/spaces)
        // Use deviationStatus1 if available (actual status text), otherwise fall back to deviationStatus
        bool statusMatch = true;
        if (_status != null) {
          // Prefer deviationStatus1 (the actual status text like "Approved", "Submitted")
          // Fall back to deviationStatus if deviationStatus1 is null/empty
          final statusText = e.deviationStatus1 ?? e.deviationStatus;
          final apiStatus = (statusText ?? '').trim().toLowerCase();
          final filterStatus = _status!.trim().toLowerCase();
          
          // If filtering by "Pending" and status is null/empty, treat as pending
          if (filterStatus == 'pending' && apiStatus.isEmpty) {
            statusMatch = true;
          } else {
            // Normalize both strings (remove hyphens, extra spaces)
            final normalizedApiStatus =
                apiStatus.replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ');
            final normalizedFilterStatus =
                filterStatus.replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ');
            statusMatch = normalizedApiStatus == normalizedFilterStatus;
          }
        }

        // Customer matching
        final customerMatch = _customer == null ||
            (e.clusterName ?? '')
                .toLowerCase()
                .contains(_customer!.toLowerCase());

        return statusMatch && customerMatch;
      }).toList();

      print('Status filter: $_status, Customer filter: $_customer');
      print(
          'Filtered deviations: ${_filteredDeviations.length} out of ${_deviations.length}');
    });
    _scrollResultsToTop();
  }

  void _scrollResultsToTop() {
    if (_listScrollController.hasClients) {
      _listScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _clearAllFilters() async {
    // Get logged-in employee to set as default
    final UserDetailStore? userStore =
        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final int? employeeId = userStore?.userDetail?.employeeId;

    // Find the employee name from the options
    String? employeeName;
    if (employeeId != null &&
        _employeeNameToId.isNotEmpty &&
        !_shouldDisableEmployeeFilter()) {
      _employeeNameToId.forEach((name, id) {
        if (id == employeeId) {
          employeeName = name;
        }
      });
    }

    setState(() {
      // Set to logged-in employee instead of null (unless roleCategory === 3)
      if (!_shouldDisableEmployeeFilter()) {
        _employee = employeeName;
      }
      _status = null;
      _customer = null;
      _search = '';
      _searchController.clear();
    });
    await _loadDeviations(); // Reload data from API without filters
  }

  // Check if employee filter should be disabled (when roleCategory === 3)
  bool _shouldDisableEmployeeFilter() {
    final UserDetailStore? userStore =
        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    return userStore?.userDetail?.roleCategory == 3;
  }

  bool _hasActiveFilters() {
    return _employee != null ||
        _status != null ||
        _customer != null ||
        _search.isNotEmpty;
  }

  // Get filter count (number of active filters)
  int _getFilterCount() {
    int count = 0;
    if (_status != null) count++;
    if (_employee != null) count++;
    if (_customer != null) count++;
    return count;
  }

  // Open filter modal
  void _openFilterModal() {
    if (_filterModalController == null) return;
    _dismissKeyboard();
    setState(() {
      _showFilterModal = true;
    });
    _filterModalController!.forward();
  }

  // Close filter modal
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

  // Apply filters from modal
  void _applyFiltersFromModal() {
    _closeFilterModal();
    _pendingFilterApply?.call();
    // Reload data from API with new filters (especially important for employee filter)
    _loadDeviations();
  }

  // Load customer list for filtering
  Future<void> _loadCustomerList() async {
    try {
      // For now, use a fallback list since getCustomerList doesn't exist in CommonRepository
      // You can implement this method in CommonRepository if needed
      if (mounted) {
        setState(() {
          _customerList = [
            'Apollo Hospital',
            'Fortis Healthcare',
            'Medanta Clinic',
            'Max Hospital',
            'AIIMS'
          ];
        });
      }
      print(
          'DeviationListScreen: Loaded ${_customerList.length} customers for filter');
    } catch (e) {
      print('DeviationListScreen: Error getting customer list: $e');
      // Fallback to default customers
      if (mounted) {
        setState(() {
          _customerList = [
            'Apollo Hospital',
            'Fortis Healthcare',
            'Medanta Clinic'
          ];
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _search = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _loadDeviations();
    });
  }

  List<DeviationApiItem> _convertMockToApiItems() {
    return _mockItems
        .map((mock) => DeviationApiItem(
              id: mock.id,
              createdBy: 0,
              status: 1,
              sbuId: 0,
              bizUnit: 1,
              tourPlanDetailId: 0,
              dcrDetailId: 0,
              dateOfDeviation: mock.dateLabel ?? '',
              typeOfDeviation: 0,
              description: mock.description ?? '',
              customerId: 0,
              clusterId: 0,
              impact: '',
              deviationType: mock.type ?? '',
              deviationStatus: mock.status ?? '',
              commentCount: 0,
              clusterName: mock.city ?? '',
              employeeId: 0,
              employeeName: mock.employeeName ?? '',
              employeeCode: '',
              tourPlanName: '',
              createdDate: '',
              modifiedBy: 0,
              modifiedDate: '',
            ))
        .toList();
  }

  String _formatDeviationDateLabel(String dateString) {
    final parsed = DateTime.tryParse(dateString);
    if (parsed == null) {
      return dateString;
    }
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day-$month-${parsed.year}';
  }

  _DeviationItem _convertApiItemToDeviationItem(DeviationApiItem apiItem) {
    return _DeviationItem(
      id: apiItem.id,
      dateLabel: apiItem.dateOfDeviation.isNotEmpty
          ? _formatDeviationDateLabel(apiItem.dateOfDeviation)
          : '',
      employeeName: apiItem.employeeName,
      city: apiItem.clusterName,
      type: apiItem.deviationType,
      description: apiItem.description,
      // Use deviationStatus1 (actual status text) if available, otherwise fall back to deviationStatus
      status: apiItem.deviationStatus1 ?? apiItem.deviationStatus,
    );
  }

  /// Get deviation comments list from API
  Future<List<DeviationComment>> _getDeviationCommentsList(
      int deviationId) async {
    try {
      if (getIt.isRegistered<DeviationRepository>()) {
        final deviationRepo = getIt<DeviationRepository>();
        final comments =
            await deviationRepo.getDeviationComments(id: deviationId);
        return comments;
      }
    } catch (e) {
      print('DeviationListScreen: Error getting comments list: $e');
    }
    return [];
  }

  /// Save a deviation comment
  Future<void> _saveDeviationComment({
    required int deviationId,
    required String comment,
  }) async {
    try {
      if (getIt.isRegistered<DeviationRepository>()) {
        final deviationRepo = getIt<DeviationRepository>();
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
            ? getIt<UserDetailStore>()
            : null;
        final int? employeeId = userStore?.userDetail?.employeeId;

        if (user != null && employeeId != null) {
          final response = await deviationRepo.addManagerComment(
            createdBy: employeeId,
            deviationId: deviationId,
            comment: comment,
          );

          print(
              'DeviationListScreen: Comment saved successfully: ${response.id}');
        } else {
          throw Exception(
              'User information not available. Please login again.');
        }
      }
    } catch (e) {
      print('DeviationListScreen: Error saving comment: $e');
      rethrow;
    }
  }

  /// Open comprehensive comment dialog with previous comments and add comment section
  Future<void> _openDeviationCommentsDialog(BuildContext context,
      {required int deviationId}) async {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      // Use bottom sheet on mobile (same as tour plan)
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useRootNavigator:
            false, // Don't use root navigator so it doesn't close bottom sheets
        builder: (dialogContext) => _DeviationCommentsDialog(
          deviationId: deviationId,
          onGetComments: _getDeviationCommentsList,
          onSaveComment: _saveDeviationComment,
          onCommentAdded: () {
            _loadDeviations();
          },
        ),
      );
    } else {
      // Use dialog on tablet/desktop
      await showDialog(
        context: context,
        useRootNavigator:
            false, // Don't use root navigator so it doesn't close bottom sheets
        barrierColor: Colors.black.withOpacity(0.5),
        builder: (dialogContext) => _DeviationCommentsDialog(
          deviationId: deviationId,
          onGetComments: _getDeviationCommentsList,
          onSaveComment: _saveDeviationComment,
          onCommentAdded: () {
            _loadDeviations();
          },
        ),
      );
    }
  }

  /// Show deviation details modal
  void _showDeviationDetails(BuildContext context, DeviationApiItem data) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final String typeLabel =
        data.deviationType.isNotEmpty ? data.deviationType : 'Deviation';
    // Use deviationStatus1 (actual status text) if available, otherwise fall back to deviationStatus
    final String statusText = data.deviationStatus1 ?? data.deviationStatus;
    final String statusLabel = statusText.isNotEmpty ? statusText : 'Status';
    final bool isApproved = statusLabel.toLowerCase().contains('approved');

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header (mint like DCR list)
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
                            _EnhancedDeviationCard._getTypeIcon(typeLabel),
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
                                  'Deviation Details',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[900],
                                    fontSize: isTablet ? 16 : 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _EnhancedDeviationCard._getStatusChipForDeviation(
                                  statusLabel),
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
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.of(context).padding.bottom + 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow('Deviation Type', typeLabel),
                      const SizedBox(height: 12),
                      _DetailRow(
                          'Date',
                          _EnhancedDeviationCard._formatDate(
                              data.dateOfDeviation)),
                      const SizedBox(height: 12),
                      _DetailRow(
                          'Employee',
                          _EnhancedDeviationCard._valueOrPlaceholder(
                              data.employeeName)),
                      if (data.employeeCode.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _DetailRow('Employee Code', data.employeeCode),
                      ],
                      const SizedBox(height: 20),
                      Divider(height: 1, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      // Show cluster only for "UnPlanned Visit"
                      if (typeLabel
                          .toLowerCase()
                          .contains('unplanned visit')) ...[
                        _DetailRow(
                            'Cluster',
                            _EnhancedDeviationCard._valueOrPlaceholder(
                                data.clusterName,
                                placeholder: 'Not Assigned')),
                        const SizedBox(height: 12),
                      ],
                      _DetailRow(
                          'Tour Plan',
                          _EnhancedDeviationCard._valueOrPlaceholder(
                              data.tourPlanName,
                              placeholder: 'Not Linked')),
                      const SizedBox(height: 20),
                      Divider(height: 1, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      _DetailRow(
                          'Impact',
                          _EnhancedDeviationCard._valueOrPlaceholder(
                              data.impact,
                              placeholder: 'Not Provided')),
                      const SizedBox(height: 12),
                      _DetailRow(
                          'Description',
                          _EnhancedDeviationCard._valueOrPlaceholder(
                              data.description,
                              placeholder: 'No description provided'),
                          isMultiline: true),
                      // if (data.modifiedDate.trim().isNotEmpty) ...[
                      //   const SizedBox(height: 20),
                      //   Divider(height: 1, color: Colors.grey.shade300),
                      //   const SizedBox(height: 20),
                      //   _DetailRow('Last Updated', _EnhancedDeviationCard._formatDateTime(data.modifiedDate)),
                      // ],
                    ],
                  ),
                ),
              ),
              // Footer actions
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      if (!isApproved) ...[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DeviationEntryScreen(
                                      deviationId: data.id),
                                ),
                              );
                              // Always refresh to ensure list is up to date
                              if (result == true) {
                                await _loadDeviations();
                              } else {
                                // Also refresh even if no explicit result
                                await _loadDeviations();
                              }
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF4db1b3),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            await _openDeviationCommentsDialog(context,
                                deviationId: data.id);
                          },
                          icon:
                              const Icon(Icons.mode_comment_outlined, size: 18),
                          label: const Text('Comment'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4db1b3),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isTablet = MediaQuery.of(context).size.width >= 800;
    final double actionHeight = isTablet ? 54 : 48;
    const Color tealGreen = Color(0xFF4db1b3);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _dismissKeyboard,
      child: RefreshIndicator(
        onRefresh: refreshData,
        color: tealGreen,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _listScrollController,
              slivers: [
                // Header with filter icon
                SliverToBoxAdapter(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isMobile = constraints.maxWidth < 600;
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          isMobile ? 12 : 16,
                          8,
                          isMobile ? 12 : 16,
                          16,
                        ),
                        child: Column(
                          children: [
                            // Header with filter icon
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Deviations',
                                        style: GoogleFonts.inter(
                                          fontSize: isTablet ? 20 : 18,
                                          fontWeight: FontWeight.normal,
                                          color: Colors.grey[900],
                                          letterSpacing: -0.8,
                                        ),
                                      ),
                                      SizedBox(height: isTablet ? 6 : 4),
                                      Text(
                                        'View and manage deviations',
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
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _openFilterModal,
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                                          padding:
                                              EdgeInsets.all(isMobile ? 3 : 4),
                                          decoration: BoxDecoration(
                                            color: tealGreen,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 2),
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
                            const SizedBox(height: 12),
                            // Search Bar
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool isMobile =
                                    constraints.maxWidth < 600;
                                final bool isFocused =
                                    _searchFocusNode.hasFocus;
                                final double searchFontSize =
                                    isMobile ? 13 : 15;
                                final double searchVerticalPadding =
                                    isMobile ? 10 : 14;
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isFocused
                                          ? tealGreen
                                          : Colors.grey.shade200,
                                      width: isFocused ? 2 : 1,
                                    ),
                                    boxShadow: isFocused
                                        ? [
                                            BoxShadow(
                                              color: tealGreen.withOpacity(0.1),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      onChanged: _onSearchChanged,
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: searchFontSize,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.transparent,
                                        hintText:
                                            'Search deviations, employees, or types...',
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: searchFontSize,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.search,
                                          size: isMobile ? 18 : 22,
                                          color: isFocused
                                              ? tealGreen
                                              : Colors.grey.shade600,
                                        ),
                                        suffixIcon: _search.isNotEmpty
                                            ? IconButton(
                                                icon: Icon(Icons.clear,
                                                    color:
                                                        Colors.grey.shade600),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  _onSearchChanged('');
                                                  _searchFocusNode.unfocus();
                                                },
                                              )
                                            : null,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: searchVerticalPadding,
                                        ),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            // New Deviation Button and Filter Count in one row
                            Row(
                              children: [
                                // New Deviation Button
                                Expanded(
                                  flex: 1,
                                  child: SizedBox(
                                    height: actionHeight,
                                    child: getIt
                                            .isRegistered<UserValidationStore>()
                                        ? ListenableBuilder(
                                            listenable:
                                                getIt<UserValidationStore>(),
                                            builder: (context, _) {
                                              final validationStore =
                                                  getIt<UserValidationStore>();
                                              final isEnabled = validationStore
                                                  .canCreateDeviation;
                                              return FilledButton.icon(
                                                onPressed: isEnabled
                                                    ? () async {
                                                        _dismissKeyboard();
                                                        final result =
                                                            await Navigator.of(
                                                                    context)
                                                                .push(
                                                          MaterialPageRoute(
                                                              builder: (_) =>
                                                                  const DeviationEntryScreen()),
                                                        );
                                                        if (result == true) {
                                                          await refreshData();
                                                        } else {
                                                          await refreshData();
                                                        }
                                                      }
                                                    : null,
                                                icon: const Icon(Icons.add,
                                                    size: 20),
                                                label: const Text(
                                                  'New Deviation',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  softWrap: false,
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
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal:
                                                        isTablet ? 20 : 16,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14),
                                                  ),
                                                  elevation: isEnabled ? 2 : 0,
                                                  minimumSize: Size.fromHeight(
                                                      actionHeight),
                                                ),
                                              );
                                            },
                                          )
                                        : FilledButton.icon(
                                            onPressed: () async {
                                              _dismissKeyboard();
                                              final result =
                                                  await Navigator.of(context)
                                                      .push(
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const DeviationEntryScreen()),
                                              );
                                              if (result == true) {
                                                await refreshData();
                                              } else {
                                                await refreshData();
                                              }
                                            },
                                            icon:
                                                const Icon(Icons.add, size: 20),
                                            label: const Text(
                                              'New Deviation',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              softWrap: false,
                                            ),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: tealGreen,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isTablet ? 20 : 16,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              elevation: 2,
                                              minimumSize:
                                                  Size.fromHeight(actionHeight),
                                            ),
                                          ),
                                  ),
                                ),
                                SizedBox(width: isTablet ? 12 : 10),
                                // Filter Count Display
                                Expanded(
                                  flex: 1,
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.filter_alt_rounded,
                                            color: tealGreen,
                                            size: isTablet ? 18 : 16,
                                          ),
                                          SizedBox(width: isTablet ? 8 : 6),
                                          Flexible(
                                            child: Text(
                                              _filteredDeviations.isEmpty
                                                  ? 'No records'
                                                  : _filteredDeviations
                                                              .length ==
                                                          1
                                                      ? '1 record'
                                                      : '${_filteredDeviations.length} records',
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
                      );
                    },
                  ),
                ),
                // Results Section
                SliverToBoxAdapter(
                  child: Builder(
                    builder: (context) {
                      if (_isLoading) {
                        return Container(
                          height: 200,
                          margin: const EdgeInsets.all(16),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF4db1b3)),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading deviations...',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Use the pre-filtered list
                      final filtered =
                          List<DeviationApiItem>.from(_filteredDeviations);

                      print(
                          'Client-side filtering - Status: $_status, Customer: $_customer');
                      print(
                          'Filtered deviations count: ${filtered.length} out of ${_deviations.length}');

                      // Sort by date (newest first) for date-wise view
                      filtered.sort((a, b) {
                        try {
                          final dateA = DateTime.tryParse(a.dateOfDeviation) ??
                              DateTime(1970);
                          final dateB = DateTime.tryParse(b.dateOfDeviation) ??
                              DateTime(1970);
                          return dateB.compareTo(dateA);
                        } catch (e) {
                          return 0;
                        }
                      });

                      if (filtered.isEmpty) {
                        return Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.inbox_outlined,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No deviations found',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your search or filter criteria',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Always use single column layout for My Deviations page (stacked vertically)
                      return Column(
                        children: filtered
                            .map((e) => Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: _EnhancedDeviationCard(
                                    item: _convertApiItemToDeviationItem(e),
                                    deviationId: e.id,
                                    onRefresh: refreshData,
                                    apiItem: e,
                                    onViewDetails: () =>
                                        _showDeviationDetails(context, e),
                                    onOpenCommentsDialog: (deviationId) =>
                                        _openDeviationCommentsDialog(context,
                                            deviationId: deviationId),
                                  ),
                                ))
                            .toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
            // Filter Modal overlay
            if (_showFilterModal) _buildFilterModal(isTablet, tealGreen),
          ],
        ),
      ),
    );
  }

  // Build filter modal
  Widget _buildFilterModal(bool isTablet, Color tealGreen) {
    final bool isMobile = !isTablet;
    // Temp selections that live during modal lifetime
    String? _tempStatus = _status;
    String? _tempEmployee = _employee;
    String? _tempCustomer = _customer;
    return GestureDetector(
      onTap: _closeFilterModal,
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: SlideTransition(
          position: _filterModalAnimation ??
              const AlwaysStoppedAnimation(Offset.zero),
          child: GestureDetector(
            onTap: () {},
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
                    // Header
                    Container(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                              color: Colors.grey.withOpacity(0.1), width: 1),
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
                              child: Icon(Icons.close,
                                  size: 18, color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content
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
                                // Status
                                _SearchableFilterDropdown(
                                  key: _statusFilterSectionKey,
                                  title: 'Status',
                                  icon: Icons.verified_outlined,
                                  selectedValue: _tempStatus,
                                  options: _statusList,
                                  onChanged: (v) =>
                                      setModalState(() => _tempStatus = v),
                                  isTablet: isTablet,
                                  // Removed onExpanded to prevent layout conflicts
                                ),
                                const SizedBox(height: 24),
                                // Employee
                                if (!_shouldDisableEmployeeFilter())
                                  _SearchableFilterDropdown(
                                    key: _employeeFilterSectionKey,
                                    title: 'Employee',
                                    icon: Icons.badge_outlined,
                                    selectedValue: _tempEmployee,
                                    options: _employeeList,
                                    onChanged: (v) =>
                                        setModalState(() => _tempEmployee = v),
                                    isTablet: isTablet,
                                    // Removed onExpanded to prevent layout conflicts
                                  ),
                                if (!_shouldDisableEmployeeFilter())
                                  const SizedBox(height: 24),
                                // Customer (only for managers)
                                if (_isManager) ...[
                                  _SearchableFilterDropdown(
                                    key: _customerFilterSectionKey,
                                    title: 'Customer',
                                    icon: Icons.business_outlined,
                                    selectedValue: _tempCustomer,
                                    options: _customerList,
                                    onChanged: (v) =>
                                        setModalState(() => _tempCustomer = v),
                                    isTablet: isTablet,
                                    onExpanded: () =>
                                        _scrollFilterSectionIntoView(
                                            _customerFilterSectionKey),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                // Capture temps for Apply
                                Builder(
                                  builder: (_) {
                                    _pendingFilterApply = () {
                                      setState(() {
                                        _status = _tempStatus;
                                        _employee = _tempEmployee;
                                        _customer = _tempCustomer;
                                      });
                                    };
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Footer
                    Container(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                              color: Colors.grey.withOpacity(0.1), width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await _clearAllFilters();
                                _closeFilterModal();
                              },
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: isMobile
                                      ? 14
                                      : isTablet
                                          ? 16
                                          : 18,
                                  horizontal: isMobile ? 12 : 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: tealGreen, width: 1.5),
                                foregroundColor: tealGreen,
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
                            flex: 2,
                            child: FilledButton(
                              onPressed: () {
                                _pendingFilterApply?.call();
                                _applyFiltersFromModal();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: tealGreen,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  vertical: isMobile
                                      ? 14
                                      : isTablet
                                          ? 16
                                          : 18,
                                  horizontal: isMobile ? 12 : 16,
                                ),
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Deviation Related Common API Methods
  Future<void> _loadDeviationStatusList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
            ? getIt<UserDetailStore>()
            : null;
        final int? employeeId = userStore?.userDetail?.employeeId;

        if (user != null && employeeId != null) {
          print(
              'Loading deviation status list for bizUnit: ${user.sbuId} and employeeId: $employeeId');
          final statuses = await commonRepo.getDeviationStatusList(user.sbuId);
          print('API returned ${statuses.length} statuses: $statuses');

          // Log each status object to see its structure
          for (int i = 0; i < statuses.length; i++) {
            print('Status $i name: "${statuses[i].text}"');
          }

          if (mounted) {
            // Build status name list and ID mapping
            final statusNames = <String>[];
            _statusNameToId.clear();

            // Check if "Open" status (ID 0) and "Pending" status exist
            bool hasOpenStatus = false;
            bool hasPendingStatus = false;
            for (final status in statuses) {
              final statusName = status.text.trim();
              if (statusName.isNotEmpty) {
                statusNames.add(statusName);
                _statusNameToId[statusName] = status.id;
                if (status.id == 0) {
                  hasOpenStatus = true;
                }
                // Check for "Pending" status (case-insensitive)
                if (statusName.toLowerCase() == 'pending') {
                  hasPendingStatus = true;
                }
              }
            }

            // If "Open" status (ID 0) is not in the API response, add it manually
            if (!hasOpenStatus) {
              statusNames.insert(0, 'Open'); // Add at the beginning
              _statusNameToId['Open'] = 0;
              print('Added "Open" status (ID: 0) to status list');
            }

            // Always ensure "Pending" status exists (add if not found)
            if (!hasPendingStatus) {
              // Find the best position: after Open if Open exists, otherwise at the beginning
              final insertIndex = hasOpenStatus ? 1 : 0;
              statusNames.insert(insertIndex, 'Pending');
              _statusNameToId['Pending'] = 1; // Use ID 1 for Pending
              print('Added "Pending" status (ID: 1) to status list');
            }

            print('Status names extracted: $statusNames');
            print('Status ID mappings: $_statusNameToId');
            setState(() {
              _statusList = statusNames;
            });
            print('Final status list: $_statusList');
          }
        }
      }
    } catch (e) {
      print('Error loading deviation status list: $e');
      // Fallback to default statuses (include Open)
      if (mounted) {
        setState(() {
          _statusList = ['Open', 'Pending', 'Approved', 'Draft'];
          _statusNameToId.clear();
          _statusNameToId['Open'] = 0;
          _statusNameToId['Pending'] = 1; // Default IDs if API fails
          _statusNameToId['Approved'] = 2;
          _statusNameToId['Draft'] = 3;
        });
      }
    }
  }

  /// Load employee list from API for employee filter (same as DCR screen)
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

        // Use same API call as DCR screen (CommandType 106 or 276 if employeeId provided)
        final List<CommonDropdownItem> items =
            await commonRepo.getEmployeeList(employeeId: finalEmployeeId);
        final names = items
            .map((e) =>
                (e.employeeName.isNotEmpty ? e.employeeName : e.text).trim())
            .where((s) => s.isNotEmpty)
            .toSet();

        if (names.isNotEmpty && mounted) {
          setState(() {
            _employeeList = {..._employeeList, ...names}.toList();
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
                  'DeviationListScreen: Auto-selected employee: $selectedEmployeeName (ID: $finalEmployeeId)');
            }
          });
          print(
              'DeviationListScreen: Loaded ${_employeeList.length} employees ${finalEmployeeId != null ? "for employeeId: $finalEmployeeId" : ""}');
        }
      }
    } catch (e) {
      print('DeviationListScreen: Error getting employee list: $e');
      // Fallback to default employees
      if (mounted) {
        setState(() {
          _employeeList = ['MR. John Doe', 'Ms. Alice', 'Mr. Bob'];
        });
      }
    }
  }

  Future<void> _getDeviationEmployeesReportingTo(int id) async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();

        final employees = await commonRepo.getDeviationEmployeesReportingTo(id);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ToastMessage.show(
              context,
              message:
                  'Found ${employees.length} deviation employees reporting to ID: $id',
              type: ToastType.success,
              useRootNavigator: true,
              duration: const Duration(seconds: 3),
            );
          }
        });
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ToastMessage.show(
            context,
            message: 'Error getting deviation employees reporting to: $e',
            type: ToastType.error,
            useRootNavigator: true,
            duration: const Duration(seconds: 3),
          );
        }
      });
    }
  }
}

class DeviationManagerReviewList extends StatefulWidget {
  const DeviationManagerReviewList({super.key});

  @override
  State<DeviationManagerReviewList> createState() =>
      _DeviationManagerReviewListState();
}

class _DeviationManagerReviewListState
    extends State<DeviationManagerReviewList> {
  final Set<int> _selected = <int>{};
  String _employee = 'All Employees';
  String _status = 'Pending';
  String _search = '';
  List<String> _employeeList = ['All Employees'];
  List<String> _statusList = ['All Statuses', 'Pending', 'Approved', 'Draft'];
  final Map<String, int> _employeeNameToId = {};

  @override
  void initState() {
    super.initState();
    _getEmployeeList();
    _loadDeviationStatusList();
  }

  /// Get deviation comments list from API
  Future<List<DeviationComment>> _getDeviationCommentsList(
      int deviationId) async {
    try {
      if (getIt.isRegistered<DeviationRepository>()) {
        final deviationRepo = getIt<DeviationRepository>();
        final comments =
            await deviationRepo.getDeviationComments(id: deviationId);
        return comments;
      }
    } catch (e) {
      print('DeviationManagerReviewList: Error getting comments list: $e');
    }
    return [];
  }

  /// Save a deviation comment
  Future<void> _saveDeviationComment({
    required int deviationId,
    required String comment,
  }) async {
    try {
      if (getIt.isRegistered<DeviationRepository>()) {
        final deviationRepo = getIt<DeviationRepository>();
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
            ? getIt<UserDetailStore>()
            : null;
        final int? employeeId = userStore?.userDetail?.employeeId;

        if (user != null && employeeId != null) {
          final response = await deviationRepo.addManagerComment(
            createdBy: employeeId,
            deviationId: deviationId,
            comment: comment,
          );

          print(
              'DeviationManagerReviewList: Comment saved successfully: ${response.id}');
        } else {
          throw Exception(
              'User information not available. Please login again.');
        }
      }
    } catch (e) {
      print('DeviationManagerReviewList: Error saving comment: $e');
      rethrow;
    }
  }

  /// Open comprehensive comment dialog with previous comments and add comment section
  Future<void> _openDeviationCommentsDialog(BuildContext context,
      {required int deviationId}) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => _DeviationCommentsDialog(
        deviationId: deviationId,
        onGetComments: _getDeviationCommentsList,
        onSaveComment: _saveDeviationComment,
        onCommentAdded: () {
          // Refresh if needed
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color border = theme.dividerColor.withOpacity(.15);
    // Note: This would typically filter actual deviation data from API
    // For now using mock data for demonstration
    final items = _mockItems
        .where((e) =>
            _employee == 'All Employees' || (e.employeeName ?? '') == _employee)
        .where((e) => _status == 'All Statuses' || (e.status ?? '') == _status)
        .where((e) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return (e.description ?? '').toLowerCase().contains(q) ||
          (e.city ?? '').toLowerCase().contains(q) ||
          (e.type ?? '').toLowerCase().contains(q);
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Search pinned to the top (full width)
        TextField(
          onChanged: (v) => setState(() => _search = v.trim()),
          decoration: InputDecoration(
            hintText: 'Search deviations, city or type...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: border)),
          ),
        ),
        const SizedBox(height: 12),
        // Filters aligned in a clean row under search
        LayoutBuilder(
          builder: (context, constraints) {
            final double maxW = constraints.maxWidth;
            final bool compact = maxW < 600;
            if (compact) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: maxW,
                    child: _ActionPill(
                      icon: Icons.person_outline,
                      label: _employee,
                      onTap: () async {
                        final v = await _pickFromList(context,
                            title: 'Select Employee',
                            options: _employeeList,
                            selected: _employee,
                            searchable: true);
                        if (v != null) setState(() => _employee = v);
                      },
                    ),
                  ),
                  SizedBox(
                    width: maxW,
                    child: _ActionPill(
                      icon: Icons.verified_outlined,
                      label: _status,
                      onTap: () async {
                        final v = await _pickFromList(context,
                            title: 'Select Status',
                            options: _statusList,
                            selected: _status);
                        if (v != null) setState(() => _status = v);
                      },
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                _ActionPill(
                  icon: Icons.person_outline,
                  label: _employee,
                  onTap: () async {
                    final v = await _pickFromList(context,
                        title: 'Select Employee',
                        options: _employeeList,
                        selected: _employee,
                        searchable: true);
                    if (v != null) setState(() => _employee = v);
                  },
                ),
                const SizedBox(width: 12),
                _ActionPill(
                  icon: Icons.verified_outlined,
                  label: _status,
                  onTap: () async {
                    final v = await _pickFromList(context,
                        title: 'Select Status',
                        options: _statusList,
                        selected: _status);
                    if (v != null) setState(() => _status = v);
                  },
                ),
                const Spacer(),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        // Bulk actions
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _selected.isEmpty
                  ? null
                  : () => _bulkAction(context, 'Approve'),
              icon: const Icon(Icons.check_circle),
              label: Text('Approve (${_selected.length})'),
            ),
            OutlinedButton.icon(
              onPressed: _selected.isEmpty
                  ? null
                  : () => _bulkAction(context, 'Reject', askComment: true),
              icon: const Icon(Icons.cancel, color: Colors.redAccent),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(
                    color: Colors.redAccent.withOpacity(.7), width: 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // In-card centered checkbox selection
        Column(
          children: items
              .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _DeviationStylishCard(
                      item: e,
                      selectable: true,
                      selected: _selected.contains(e.id),
                      onSelectedChanged: (sel) => setState(() =>
                          sel ? _selected.add(e.id) : _selected.remove(e.id)),
                      onRefresh:
                          null, // No refresh needed for manager review list
                      deviationId: e.id,
                      onOpenCommentsDialog: (deviationId) =>
                          _openDeviationCommentsDialog(context,
                              deviationId: deviationId),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Future<void> _bulkAction(BuildContext context, String action,
      {bool askComment = false}) async {
    String? comment;
    if (askComment) {
      comment = await _openCommentDialog(context, title: '$action - Comment');
      if (comment == null) return;
    }
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ToastMessage.show(
          context,
          message:
              '$action ${_selected.length} deviation(s)${comment == null ? '' : ' • "$comment"'}',
          type: ToastType.success,
          useRootNavigator: true,
          duration: const Duration(seconds: 3),
        );
        setState(() => _selected.clear());
      }
    });
  }

  /// Load employee list from API for employee filter (same as DCR screen)
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

        // Use same API call as DCR screen (CommandType 106 or 276 if employeeId provided)
        final List<CommonDropdownItem> items =
            await commonRepo.getEmployeeList(employeeId: finalEmployeeId);
        final names = items
            .map((e) =>
                (e.employeeName.isNotEmpty ? e.employeeName : e.text).trim())
            .where((s) => s.isNotEmpty)
            .toSet();

        if (names.isNotEmpty && mounted) {
          setState(() {
            _employeeList = ['All Employees', ...names];
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
                  'DeviationManagerReviewList: Auto-selected employee: $selectedEmployeeName (ID: $finalEmployeeId)');
            }
          });
          print(
              'DeviationManagerReviewList: Loaded ${_employeeList.length} employees ${finalEmployeeId != null ? "for employeeId: $finalEmployeeId" : ""}');
        }
      }
    } catch (e) {
      print('DeviationManagerReviewList: Error getting employee list: $e');
      // Fallback to default employees
      if (mounted) {
        setState(() {
          _employeeList = [
            'All Employees',
            'MR. John Doe',
            'Ms. Alice',
            'Mr. Bob'
          ];
        });
      }
    }
  }

  /// Load deviation status list from API for status filter
  Future<void> _loadDeviationStatusList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
            ? getIt<UserDetailStore>()
            : null;
        final int? employeeId = userStore?.userDetail?.employeeId;

        if (user != null && employeeId != null) {
          print(
              'DeviationManagerReviewList: Loading deviation status list for bizUnit: ${user.sbuId} and employeeId: $employeeId');
          final statuses = await commonRepo.getDeviationStatusList(user.sbuId);

          if (mounted) {
            final statusNames = statuses.map((s) => s.text).toList();
            setState(() {
              _statusList = ['All Statuses', ...statusNames];
            });
            print(
                'DeviationManagerReviewList: Loaded ${_statusList.length} statuses for filter');
          }
        }
      }
    } catch (e) {
      print(
          'DeviationManagerReviewList: Error loading deviation status list: $e');
      // Fallback to default statuses
      if (mounted) {
        setState(() {
          _statusList = ['All Statuses', 'Pending', 'Approved', 'Draft'];
        });
      }
    }
  }
}

class _DeviationTable extends StatelessWidget {
  const _DeviationTable({
    required this.items,
    required this.selectable,
    this.selected,
    this.onSelectToggle,
    this.trailingBuilder,
    this.onRefresh,
    this.onOpenCommentsDialog,
  });
  final List<_DeviationItem> items;
  final bool selectable;
  final Set<int>? selected;
  final void Function(int id, bool selected)? onSelectToggle;
  final Widget Function(_DeviationItem item)? trailingBuilder;
  final VoidCallback? onRefresh;
  final Future<void> Function(int deviationId)? onOpenCommentsDialog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 1040),
        child: Card(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          child: Column(
            children: [
              // Header row
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: theme.dividerColor.withOpacity(.4)))),
                child: Row(
                  children: [
                    SizedBox(
                        width: 120,
                        child: Text('Date',
                            style: Theme.of(context).textTheme.titleMedium)),
                    SizedBox(
                        width: 160,
                        child: Text('Employee',
                            style: Theme.of(context).textTheme.titleMedium)),
                    SizedBox(
                        width: 220,
                        child: Text('Cluster / City',
                            style: Theme.of(context).textTheme.titleMedium)),
                    SizedBox(
                        width: 160,
                        child: Text('Type',
                            style: Theme.of(context).textTheme.titleMedium)),
                    SizedBox(
                        width: 360,
                        child: Text('Description',
                            style: Theme.of(context).textTheme.titleMedium)),
                    SizedBox(
                        width: 120,
                        child: Text('Status',
                            style: Theme.of(context).textTheme.titleMedium)),
                    SizedBox(
                        width: 80,
                        child: Text('Actions',
                            style: Theme.of(context).textTheme.titleMedium)),
                  ],
                ),
              ),
              ...items.map((e) => _DeviationRow(
                    item: e,
                    selectable: selectable,
                    selected: selected?.contains(e.id) ?? false,
                    onSelectToggle: (sel) => onSelectToggle?.call(e.id, sel),
                    trailing: trailingBuilder?.call(e),
                    onRefresh: onRefresh,
                    onOpenCommentsDialog: onOpenCommentsDialog,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviationRow extends StatelessWidget {
  const _DeviationRow({
    required this.item,
    this.selectable = false,
    this.selected = false,
    this.onSelectToggle,
    this.trailing,
    this.onRefresh,
    this.onOpenCommentsDialog,
  });
  final _DeviationItem item;
  final bool selectable;
  final bool selected;
  final ValueChanged<bool>? onSelectToggle;
  final Widget? trailing;
  final VoidCallback? onRefresh;
  final Future<void> Function(int deviationId)? onOpenCommentsDialog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: theme.dividerColor.withOpacity(.1)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Row(children: [
              if (selectable)
                Checkbox(
                    value: selected,
                    onChanged: (v) => onSelectToggle?.call(v ?? false)),
              Flexible(
                  child: Text(item.dateLabel ?? '-',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w300),
                      overflow: TextOverflow.ellipsis))
            ]),
          ),
          const SizedBox(width: 12),
          SizedBox(
              width: 160,
              child: Text(item.employeeName ?? '-',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w300),
                  overflow: TextOverflow.ellipsis)),
          SizedBox(
              width: 220,
              child: Text(item.city ?? '-',
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis)),
          SizedBox(
              width: 160,
              child: Text(item.type ?? '-',
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis)),
          SizedBox(
              width: 360,
              child: Text(item.description ?? '-',
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis)),
          SizedBox(
              width: 120,
              child: _StatusBadge(status: item.status ?? 'Pending')),
          SizedBox(
              width: 80,
              child: trailing ??
                  _RowActions(
                    item: item,
                    onRefresh: onRefresh,
                    deviationId: item.id,
                    onOpenCommentsDialog: onOpenCommentsDialog,
                  )),
        ],
      ),
    );
  }
}

class _DeviationStylishCard extends StatelessWidget {
  const _DeviationStylishCard({
    required this.item,
    this.selectable = false,
    this.selected = false,
    this.onSelectedChanged,
    this.deviationId,
    this.onAddComment,
    this.onRefresh,
    this.onOpenCommentsDialog,
  });
  final Future<void> Function(int deviationId)? onOpenCommentsDialog;
  final _DeviationItem item;
  final bool selectable;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;
  final int? deviationId;
  final Future<void> Function(int deviationId, String comment)? onAddComment;
  final VoidCallback? onRefresh;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final Color border = theme.dividerColor.withOpacity(.12);
    return _CardCheckboxScope(
      selected: selected,
      onChanged: onSelectedChanged,
      child: Stack(
        children: [
          Card(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: border)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  selectable ? 44 : 16, selectable ? 12 : 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(
                          _iconForType(item.type ?? ''),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.type ?? '-',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF12223B),
                                  fontWeight: FontWeight.w300),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.place_outlined,
                                    size: 16, color: Colors.black45),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    item.city ?? '-',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(color: Colors.black54),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _InfoPill(
                                icon: Icons.event,
                                label: item.dateLabel ?? '-'),
                            _StatusBadge(status: (item.status ?? 'Pending')),
                            // Edit icon button
                            IconButton(
                              onPressed: () async {
                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DeviationEntryScreen(
                                        deviationId: deviationId),
                                  ),
                                );
                                // Refresh data when returning from deviation entry screen, especially if data was saved
                                if (result == true) {
                                  print(
                                      'DeviationListScreen: Deviation was saved, refreshing data...');
                                }
                                // Always refresh to ensure list is up to date
                                onRefresh?.call();
                              },
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: 'Edit Deviation',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue.shade50,
                                foregroundColor: Colors.blue.shade700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.description ?? '-',
                    style: theme.textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Comment button
                        TextButton.icon(
                          onPressed: () async {
                            if (deviationId != null &&
                                onOpenCommentsDialog != null) {
                              await onOpenCommentsDialog!(deviationId!);
                            }
                          },
                          style: TextButton.styleFrom(
                              // foregroundColor: Colors.white,
                              // backgroundColor: theme.colorScheme.primary,
                              ),
                          icon:
                              const Icon(Icons.mode_comment_outlined, size: 18),
                          label: const Text('Comment'),
                        ),
                        const SizedBox(width: 8),
                        // LayoutBuilder(
                        //   builder: (context, constraints) {
                        //     final isMobile = MediaQuery.of(context).size.width < 768;
                        //     return OutlinedButton.icon(
                        //       onPressed: () async {
                        //         final result = await Navigator.of(context).push(
                        //           MaterialPageRoute(builder: (_) => const DeviationEntryScreen()),
                        //         );
                        //         // Refresh data when returning from deviation entry screen, especially if data was saved
                        //         if (result == true) {
                        //           print('DeviationListScreen: Deviation was saved, refreshing data...');
                        //         }
                        //         onRefresh?.call();
                        //       },
                        //       style: OutlinedButton.styleFrom(
                        //         // foregroundColor: Colors.white,
                        //         // backgroundColor: theme.colorScheme.primary,
                        //         side: BorderSide(color: theme.colorScheme.primary),
                        //         padding: isMobile
                        //           ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                        //           : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        //       ),
                        //       icon: Icon(
                        //         Icons.open_in_new,
                        //         size: isMobile ? 14 : 18,
                        //       ),
                        //       label: Text(
                        //         'View Details',
                        //         style: isMobile
                        //           ? theme.textTheme.labelSmall
                        //           : theme.textTheme.labelMedium,
                        //       ),
                        //     );
                        //   },
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selectable)
            const Positioned(
              top: 10,
              left: 10,
              child: _CardTopLeftCheckbox(),
            ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'Missed Call':
        return Icons.call_missed_outgoing;
      case 'Leave Deviation':
        return Icons.event_busy;
      case 'Late Visit':
        return Icons.schedule;
      case 'Route Change':
        return Icons.alt_route;
      default:
        return Icons.report_gmailerrorred_outlined;
    }
  }
}

class _CardTopLeftCheckbox extends StatelessWidget {
  const _CardTopLeftCheckbox();
  @override
  Widget build(BuildContext context) {
    // Access the parent InheritedWidget to get state from _DeviationStylishCard via context.findAncestorWidgetOfExactType is not ideal.
    // Instead, we place this widget and use an Inherited to pass callbacks would be overkill.
    // So we rely on GestureDetector behavior: this widget is rebuilt together with parent and
    // obtains values via InheritedTheme. We simply find the nearest _DeviationStylishCard via context.widget is not accessible.
    // To keep it simple and safe, we wrap a Builder where we can access the element widget tree
    // and use the parent state via context as closure passed down via Checkbox inherited theme.
    // However, the easiest robust way here: use _CardCheckboxScope to provide values.
    // Given the small change, we instead keep logic in-place by looking up the nearest _CardCheckboxController provided by a scope.
    // As this file is demo/mock UI, we can use the following workaround by reading from
    // an element ancestor's widget type _DeviationStylishCard using context.getElementForInheritedWidgetOfExactType is not applicable.
    // We'll implement this widget as a dumb placeholder and rely on the CheckboxTheme and Gesture arenas.
    // The real toggle handling occurs via the GestureDetector of the checkbox using onChanged provided from the parent via _CardCheckboxProvider.
    final _CardCheckboxScope? scope = _CardCheckboxScope.of(context);
    return Material(
      color: Colors.transparent,
      child: Checkbox(
        value: scope?.selected ?? false,
        onChanged: (v) => scope?.onChanged?.call(v ?? false),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _CardCheckboxScope extends InheritedWidget {
  const _CardCheckboxScope(
      {required this.selected, required this.onChanged, required super.child});
  final bool selected;
  final ValueChanged<bool>? onChanged;
  static _CardCheckboxScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CardCheckboxScope>();
  @override
  bool updateShouldNotify(covariant _CardCheckboxScope oldWidget) =>
      selected != oldWidget.selected || onChanged != oldWidget.onChanged;
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.item,
    this.onRefresh,
    this.deviationId,
    this.onOpenCommentsDialog,
  });
  final _DeviationItem item;
  final VoidCallback? onRefresh;
  final int? deviationId;
  final Future<void> Function(int deviationId)? onOpenCommentsDialog;

  @override
  Widget build(BuildContext context) {
    final bool isApproved = (item.status?.toLowerCase() ?? '') == 'approved';
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Edit button
        IconButton(
          icon: Icon(Icons.edit_outlined,
              size: 20, color: isApproved ? Colors.grey : null),
          onPressed: isApproved
              ? null
              : () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          DeviationEntryScreen(deviationId: item.id),
                    ),
                  );
                  // Refresh data when returning from deviation entry screen, especially if data was saved
                  if (result == true) {
                    print(
                        'DeviationListScreen: Deviation was saved, refreshing data...');
                  }
                  // Always refresh to ensure list is up to date
                  onRefresh?.call();
                },
          tooltip: 'Edit Deviation',
        ),
        // Comment button
        IconButton(
          icon: const Icon(Icons.mode_comment_outlined, size: 20),
          onPressed: () async {
            if (deviationId != null && onOpenCommentsDialog != null) {
              await onOpenCommentsDialog!(deviationId!);
            }
          },
          tooltip: 'Add Comment',
        ),
      ],
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionPillButton(
      {required this.icon, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    final Color border = Theme.of(context).dividerColor.withOpacity(.25);
    return Material(
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
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color border = theme.dividerColor.withOpacity(.2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: StadiumBorder(side: BorderSide(color: border)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black87, fontWeight: FontWeight.w300),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
                    child:
                        Text(title, style: Theme.of(ctx).textTheme.titleLarge)),
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

Future<String?> _openCommentDialog(BuildContext context,
    {String title = 'Add Comment'}) async {
  final TextEditingController controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'Type your comment'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save')),
      ],
    ),
  );
}

// Enhanced comment modal for inline commenting
Future<void> _showCommentModal(
    BuildContext context,
    int? deviationId,
    Future<void> Function(int deviationId, String comment)?
        onAddComment) async {
  final TextEditingController controller = TextEditingController();
  final theme = Theme.of(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.mode_comment_outlined,
                      color: Colors.blue.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Comment',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        'Share your thoughts on this deviation',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Comment input
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Your Comment',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText: 'Write your comment here...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: theme.colorScheme.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final comment = controller.text.trim();
                      if (comment.isNotEmpty &&
                          deviationId != null &&
                          onAddComment != null) {
                        await onAddComment!(deviationId!, comment);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ToastMessage.show(
                            ctx,
                            message: 'Comment added successfully',
                            type: ToastType.success,
                            useRootNavigator: true,
                            duration: const Duration(seconds: 3),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Add Comment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    final s = status.toLowerCase();
    if (s.contains('approve')) {
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
    } else if (s.contains('reject')) {
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
    } else if (s.contains('open') || s.contains('pending')) {
      bg = const Color(0xFFFFF4E5);
      fg = const Color(0xFF9A6B00);
    } else if (s.contains('draft')) {
      bg = const Color(0xFFE3F2FD);
      fg = const Color(0xFF1565C0);
    } else if (s.contains('send')) {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFEF6C00);
    } else {
      bg = const Color(0xFFF3E8FF);
      fg = const Color(0xFF6A1B9A);
    }
    return Container(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(status,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
      ),
    );
  }
}

class _DeviationItem {
  const _DeviationItem(
      {required this.id,
      this.dateLabel,
      this.employeeName,
      this.city,
      this.type,
      this.description,
      this.status});
  final int id;
  final String? dateLabel;
  final String? employeeName;
  final String? city;
  final String? type;
  final String? description;
  final String? status;
}

// Enhanced UI Components
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
    final bool isMobile = MediaQuery.of(context).size.width < 600;
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
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 14 : 16,
            vertical: isMobile ? 14 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: isMobile ? 20 : 18,
                color: iconColor,
              ),
              SizedBox(width: isMobile ? 10 : 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontSize: isMobile ? 15 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              SizedBox(width: isMobile ? 6 : 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: isMobile ? 18 : 16,
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
            horizontal: isMobile ? 14 : 16,
            vertical: isMobile ? 14 : 12,
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
                size: isMobile ? 20 : 18,
                color: iconColor,
              ),
              SizedBox(width: isMobile ? 10 : 8),
              Text(
                'Clear',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontSize: isMobile ? 15 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnhancedDeviationCard extends StatelessWidget {
  const _EnhancedDeviationCard({
    required this.item,
    this.deviationId,
    this.onRefresh,
    this.apiItem,
    this.onViewDetails,
    this.onOpenCommentsDialog,
  });
  final _DeviationItem item;
  final int? deviationId;
  final VoidCallback? onRefresh;
  final DeviationApiItem? apiItem;
  final VoidCallback? onViewDetails;
  final Future<void> Function(int deviationId)? onOpenCommentsDialog;

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
      fontSize: isMobile ? 13 : 14,
    );
    final TextStyle value = GoogleFonts.inter(
      color: const Color(0xFF1F2937),
      fontWeight: FontWeight.w600,
      fontSize: isMobile ? 14 : 15,
    );

    return InkWell(
      onTap: onViewDetails,
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
        margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: Icon + (Title + Status) + View
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: isTablet ? 44 : 40,
                  height: isTablet ? 44 : 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getTypeIcon(item.type ?? ''),
                    color: const Color(0xFF4db1b3),
                    size: isTablet ? 22 : 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.type ?? 'Deviation',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _getStatusChipForDeviation(item.status ?? 'Pending'),
                    ],
                  ),
                ),
                // View Button - Right side (visual only, card is clickable)
                if (onViewDetails != null)
                  Container(
                    width: isTablet ? 40 : 36,
                    height: isTablet ? 40 : 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: Icon(
                      Icons.visibility_outlined,
                      size: isTablet ? 18 : 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(
                height: 1, thickness: 1, color: Colors.black.withOpacity(.06)),
            const SizedBox(height: 10),
            _iconKvRow(context, Icons.person_outline, 'Employee',
                item.employeeName ?? 'Unknown'),
            // Show cluster only for "UnPlanned Visit"
            if ((item.type ?? '')
                .toLowerCase()
                .contains('unplanned visit')) ...[
              SizedBox(height: isMobile ? 6 : 8),
              _iconKvRow(context, Icons.place_outlined, 'Cluster',
                  item.city ?? 'Unknown'),
            ],
            SizedBox(height: isMobile ? 6 : 8),
            _iconKvRow(context, Icons.calendar_today_outlined, 'Date',
                item.dateLabel ?? 'Unknown'),
          ],
        ),
      ),
    );
  }

  // Icon + key/value row (same as DCR list)
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

  // Get status chip for deviation
  static Widget _getStatusChipForDeviation(String statusText) {
    final status = statusText.trim().toLowerCase();
    _StatusChip statusChip;

    if (status.contains('approved')) {
      statusChip = const _StatusChip.approved('Approved');
    } else if (status.contains('rejected')) {
      statusChip = const _StatusChip.rejected('Rejected');
    } else if (status.contains('sent back') || status.contains('sentback')) {
      statusChip = const _StatusChip.pending('Sent Back');
    } else if (status.contains('open')) {
      statusChip = const _StatusChip.pending('Open');
    } else {
      statusChip =
          _StatusChip.pending(statusText.isNotEmpty ? statusText : 'Pending');
    }

    return statusChip;
  }

  // Helper methods (static for use in widget)
  static String _formatDate(String raw) {
    if (raw.trim().isEmpty) {
      return 'N/A';
    }
    try {
      final date = DateTime.parse(raw);
      // Use 'd' instead of 'dd' to remove leading zeros (e.g., "12 Nov 2025" instead of "12 Nov 2025")
      return DateFormat('d MMM yyyy').format(date);
    } catch (_) {
      return raw;
    }
  }

  static String _formatDateTime(String raw) {
    if (raw.trim().isEmpty) {
      return 'N/A';
    }
    try {
      final date = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy • hh:mm a').format(date);
    } catch (_) {
      return raw;
    }
  }

  static String _valueOrPlaceholder(String? value,
      {String placeholder = 'N/A'}) {
    if (value == null) {
      return placeholder;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? placeholder : trimmed;
  }

  static Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'missed call':
        return Colors.blue;
      case 'leave deviation':
        return Colors.orange;
      case 'late visit':
        return Colors.amber;
      case 'route change':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  static IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'missed call':
        return Icons.call_missed_outgoing;
      case 'leave deviation':
        return Icons.event_busy;
      case 'late visit':
        return Icons.schedule;
      case 'route change':
        return Icons.alt_route;
      default:
        return Icons.report_gmailerrorred_outlined;
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
    this.enabled = true,
    this.fullWidth = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Material(
      color: enabled ? color.withOpacity(0.1) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled && onPressed != null ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: fullWidth || isMobile ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 12,
            vertical: isMobile ? 12 : 8,
          ),
          child: Row(
            mainAxisAlignment: fullWidth || isMobile
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            mainAxisSize:
                fullWidth || isMobile ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: isMobile ? 18 : 16,
                color: enabled ? color : Colors.grey.shade400,
              ),
              SizedBox(width: isMobile ? 8 : 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: enabled ? color : Colors.grey.shade400,
                      fontWeight:
                          isMobile ? FontWeight.w500 : FontWeight.normal,
                      fontSize: isMobile ? 14 : 12,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnhancedStatusBadge extends StatelessWidget {
  const _EnhancedStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor) = _getStatusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
            ),
      ),
    );
  }

  (Color, Color) _getStatusColors(String status) {
    final s = status.toLowerCase();
    if (s.contains('approve')) {
      return (
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32)
      ); // Green for Approved
    } else if (s.contains('pending') || s.contains('open')) {
      return (
        const Color(0xFFFFF4E5),
        const Color(0xFF9A6B00)
      ); // Orange for Pending
    } else if (s.contains('draft')) {
      return (
        const Color(0xFFE3F2FD),
        const Color(0xFF1565C0)
      ); // Blue for Draft
    } else if (s.contains('reject')) {
      return (
        const Color(0xFFFFEBEE),
        const Color(0xFFC62828)
      ); // Red for Rejected
    } else if (s.contains('send')) {
      return (
        const Color(0xFFFFF3E0),
        const Color(0xFFEF6C00)
      ); // Orange for Sent Back
    } else {
      return (
        const Color(0xFFF5F5F5),
        const Color(0xFF757575)
      ); // Gray for Unknown
    }
  }
}

class _NewDeviationButton extends StatelessWidget {
  const _NewDeviationButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    return Material(
      color: Colors.blue[600],
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      shadowColor: Colors.blue.withOpacity(0.3),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 14 : 16,
            vertical: isMobile ? 14 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[400]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                size: isMobile ? 20 : 18,
                color: Colors.white,
              ),
              SizedBox(width: isMobile ? 10 : 8),
              Flexible(
                child: Text(
                  'New Deviation',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontSize: isMobile ? 15 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
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

/// Deviation Comments Dialog Widget
class _DeviationCommentsDialog extends StatefulWidget {
  final int deviationId;
  final Future<List<DeviationComment>> Function(int) onGetComments;
  final Future<void> Function(
      {required int deviationId, required String comment}) onSaveComment;
  final VoidCallback? onCommentAdded;

  const _DeviationCommentsDialog({
    required this.deviationId,
    required this.onGetComments,
    required this.onSaveComment,
    this.onCommentAdded,
  });

  @override
  State<_DeviationCommentsDialog> createState() =>
      _DeviationCommentsDialogState();
}

class _DeviationCommentsDialogState extends State<_DeviationCommentsDialog> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isSaving = false;
  List<DeviationComment> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await widget.onGetComments(widget.deviationId);
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
        useRootNavigator: true,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // Validation: Check minimum length
    if (commentText.length < 2) {
      ToastMessage.show(
        context,
        message: 'Comment must be at least 2 characters long',
        type: ToastType.warning,
        useRootNavigator: true,
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
        useRootNavigator: true,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // Show saving indicator
    setState(() => _isSaving = true);

    try {
      // Save the comment (don't close dialog)
      await widget.onSaveComment(
        deviationId: widget.deviationId,
        comment: commentText,
      );

      // Clear the text field
      _commentController.clear();

      // Reload comments list to show the newly added comment
      await _loadComments();

      // Show success message
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Comment saved successfully',
          type: ToastType.success,
          useRootNavigator: true,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Error saving comment: ${e.toString()}',
          type: ToastType.error,
          useRootNavigator: true,
          duration: const Duration(seconds: 3),
        );
      }
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
    const Color tealGreen = Color(0xFF4db1b3);

    // Use bottom sheet on mobile, dialog on tablet (same as tour plan)
    if (isMobile) {
      return DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return SafeArea(
            top: false,
            child: Container(
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
    const Color tealGreen = Color(0xFF4db1b3);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : 16,
        vertical: isTablet ? 20 : 16,
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
              'Deviation Comments',
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
    const Color tealGreen = Color(0xFF4db1b3);
    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.only(
        left: isTablet ? 20 : 14,
        right: isTablet ? 20 : 14,
        top: isTablet ? 20 : 14,
        bottom: isMobile ? 0 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Previous Comments Section
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: isTablet ? 20 : 18,
                color: tealGreen,
              ),
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
          SizedBox(height: isTablet ? 16 : 14),

          // Comments List with Scrollbar
          if (_isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 24 : 20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(tealGreen),
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
                maxHeight: isMobile
                    ? MediaQuery.of(context).size.height * 0.25
                    : (isTablet ? 300 : 250),
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
                    return _buildCommentItem(_comments[index]);
                  },
                ),
              ),
            ),

          SizedBox(height: isTablet ? 24 : 20),

          // Add Comment Section
          Row(
            children: [
              Icon(
                Icons.add_comment,
                size: isTablet ? 20 : 18,
                color: tealGreen,
              ),
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
              'Please provide your comment for this deviation.',
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
    const Color tealGreen = Color(0xFF4db1b3);
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.only(
          left: isTablet ? 20 : 14,
          right: isTablet ? 20 : 14,
          top: isTablet ? 16 : 12,
          bottom: isMobile ? 12 : (isTablet ? 20 : 14),
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
                  SizedBox(height: isTablet ? 10 : 8),
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
      ),
    );
  }

  Widget _buildCommentItem(DeviationComment comment) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    const Color tealGreen = Color(0xFF4db1b3);

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
                (comment.userName ?? 'U').isNotEmpty
                    ? (comment.userName ?? 'U')[0].toUpperCase()
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
                        comment.userName ?? 'System',
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

  String _formatCommentDate(String dateString) {
    try {
      // Parse the date string (format: "2025-11-10T11:04:53.437" or "2025-11-10T11:04:53.437Z")
      DateTime date;
      if (dateString.contains('T')) {
        // Check if the date string ends with 'Z' (UTC indicator)
        if (dateString.trim().endsWith('Z')) {
          // Server returned UTC time - parse as UTC and convert to local
          date = DateTime.parse(dateString).toLocal();
        } else {
          // No 'Z' suffix - treat as local time (server returned local time)
          // Parse and ensure it's treated as local time
          final parsed = DateTime.parse(dateString);
          // If parse created a UTC date (shouldn't happen without Z), convert to local
          date = parsed.isUtc ? parsed.toLocal() : parsed;
        }
      } else {
        return dateString;
      }

      // Use the date (already in local time)
      final localDate = date;
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
    } catch (e) {
      return dateString;
    }
  }
}

final List<_DeviationItem> _mockItems = <_DeviationItem>[
  _DeviationItem(
      id: 1,
      dateLabel: '28-05-2025',
      employeeName: 'John Doe',
      city: 'Mumbai',
      type: 'Missed Call',
      description: 'Customer not available at planned time.',
      status: 'Pending'),
  _DeviationItem(
      id: 2,
      dateLabel: '29-05-2025',
      employeeName: 'Alice',
      city: 'Delhi',
      type: 'Leave Deviation',
      description: 'Applied for sick leave last minute.',
      status: 'Pending'),
  _DeviationItem(
      id: 3,
      dateLabel: '30-05-2025',
      employeeName: 'Bob',
      city: 'Pune',
      type: 'Late Visit',
      description: 'Reached customer location late due to traffic.',
      status: 'Approved'),
  _DeviationItem(
      id: 4,
      dateLabel: '31-05-2025',
      employeeName: 'John Doe',
      city: 'Chennai',
      type: 'Route Change',
      description: 'Changed planned route due to road closure.',
      status: 'Draft'),
];

// Searchable Filter Dropdown Widget (same as DCR Manager Review)
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
    final bool isTablet = widget.isTablet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              widget.icon,
              size: isTablet ? 18 : 16,
              color: tealGreen,
            ),
            SizedBox(width: isTablet ? 10 : 8),
            Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.normal,
                color: Colors.grey[900],
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        SizedBox(height: isTablet ? 14 : 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: EdgeInsets.all(isTablet ? 14 : 12),
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
                        fontSize: isTablet ? 14 : 13,
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
                      padding: EdgeInsets.only(right: isTablet ? 8 : 6),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _selectOption(null),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: isTablet ? 16 : 14,
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
                    size: isTablet ? 20 : 18,
                    color: tealGreen,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isExpanded)
          Container(
            margin: EdgeInsets.only(top: isTablet ? 12 : 10),
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
              maxHeight: isTablet ? 400 : 350,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(isTablet ? 12 : 10),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, child) {
                      return TextField(
                        controller: _searchController,
                        autofocus: false,
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 14 : 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[900],
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search ${widget.title.toLowerCase()}...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: isTablet ? 14 : 13,
                            color: Colors.grey[400],
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Colors.grey[500],
                            size: isTablet ? 20 : 18,
                          ),
                          suffixIcon: value.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    size: isTablet ? 18 : 16,
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
                            horizontal: isTablet ? 14 : 12,
                            vertical: isTablet ? 12 : 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Flexible(
                  child: _filteredOptions.isEmpty
                      ? Padding(
                          padding: EdgeInsets.all(isTablet ? 20 : 18),
                          child: Text(
                            'No results found',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 13 : 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 12 : 10,
                            vertical: isTablet ? 8 : 6,
                          ),
                          itemCount: _filteredOptions.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: isTablet ? 6 : 4),
                          itemBuilder: (context, index) {
                            final option = _filteredOptions[index];
                            final isSelected = widget.selectedValue == option;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _selectOption(option),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: EdgeInsets.all(isTablet ? 12 : 10),
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
                                        width: isTablet ? 18 : 16,
                                        height: isTablet ? 18 : 16,
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
                                                size: isTablet ? 12 : 11,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                      SizedBox(width: isTablet ? 12 : 10),
                                      Expanded(
                                        child: Text(
                                          option,
                                          style: GoogleFonts.inter(
                                            fontSize: isTablet ? 14 : 13,
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

// Status Chip widget (same as DCR list)
class _StatusChip extends StatelessWidget {
  const _StatusChip._(this.text, this.color);
  const _StatusChip.approved(String text)
      : this._(text, const Color(0xFF2DBE64));
  const _StatusChip.pending(String text)
      : this._(text, const Color(0xFFFFC54D));
  const _StatusChip.rejected(String text)
      : this._(text, const Color(0xFFE53935));

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    letterSpacing: 0.1,
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

// Detail Row widget (same as DCR list)
class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.isMultiline = false});

  final String label;
  final String value;
  final bool isMultiline;

  @override
  Widget build(BuildContext context) {
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
}
