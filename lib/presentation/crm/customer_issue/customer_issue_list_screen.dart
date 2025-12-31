import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'customer_issue_entry_screen.dart';
import 'package:boilerplate/domain/repository/item_issue/item_issue_repository.dart';
import 'package:boilerplate/domain/entity/item_issue/item_issue_api_models.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';

class CustomerIssueListScreen extends StatefulWidget {
  const CustomerIssueListScreen({super.key});

  @override
  State<CustomerIssueListScreen> createState() =>
      _CustomerIssueListScreenState();
}

class _CustomerIssueListScreenState extends State<CustomerIssueListScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  final ScrollController _listScrollController = ScrollController();

  // Filter modal state
  AnimationController? _filterModalController;
  Animation<Offset>? _filterModalAnimation;
  bool _showFilterModal = false;
  VoidCallback? _pendingFilterApply;
  final ScrollController _filterScrollController = ScrollController();

  // Filter state - simplified like deviation
  String? _status;
  String? _fromStore;
  String? _issueNo;
  DateTime? _stDateFrom;
  DateTime? _stDateTo;

  // Filter options
  final List<String> _statusList = ['Approved', 'Drafted', 'Cancelled'];
  final List<String> _fromStoreList = ['Inventory', 'Customer Store'];
  List<String> _issueNoList = [];

  // Column filter state - keep for complex filters
  final Map<String, ColumnFilterState> _columnFilters = {
    'stDate': ColumnFilterState(),
    'fromStore': ColumnFilterState(),
    'itemDetails': ColumnFilterState(),
  };

  // Status filter state (multi-select checkbox)
  final Set<String> _selectedStatusFilters = <String>{};
  String _statusSearchText = '';

  // Issue No filter state (multi-select checkbox)
  final Set<String> _selectedIssueNoFilters = <String>{};
  String _issueNoSearchText = '';

  // Old filter methods - keeping for compatibility but not used in new card-based layout
  String? _activeFilterColumn;

  // API-loaded data
  List<CustomerIssueItem> _issues = [];
  // Store full API items by ID for editing
  final Map<String, ItemIssueApiItem> _apiItemsById = {};
  String? _loadError;
  int _currentPage = 1;
  final int _pageSize = 15;
  bool _hasMore = true;

  // Cached filtered issues for performance optimization
  List<CustomerIssueItem>? _cachedFilteredIssues;

  final List<String> _filterOperators = [
    'Is equal to',
    'Is not equal to',
    'Starts with',
    'Contains',
    'Does not contain',
    'Ends with',
    'Is null',
    'Is not null',
    'Is empty',
    'Is not empty',
    'Has no value',
    'Has value',
  ];

  final List<String> _dateFilterOperators = [
    'Is equal to',
    'Is not equal to',
    'Is after or equal to',
    'Is after',
    'Is before or equal to',
    'Is before',
    'Is null',
    'Is not null',
  ];

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

    // Load data from API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadItemIssues();
    });
  }

  /// Load ItemIssue list from API
  Future<void> _loadItemIssues({bool refresh = false}) async {
    if (!mounted) return;

    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _apiItemsById.clear(); // Clear API items map on refresh
    }

    if (!_hasMore && !refresh) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      // Get user info from SharedPreferences for userId
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();

      if (user == null) {
        throw Exception('User not available');
      }

      final userId = user.userId ?? user.id;

      // Get bizUnit from UserDetailStore (more reliable than SharedPreferences)
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;

      int? bizUnitFromStore = userStore?.userDetail?.sbuId;
      int? bizUnitFromPrefs = user.sbuId;

      // Prefer UserDetailStore, fallback to SharedPreferences, then default to 1
      final int bizUnit = bizUnitFromStore ?? bizUnitFromPrefs ?? 1;

      // Log for debugging
      print(
          'CustomerIssueListScreen: bizUnit from UserDetailStore: $bizUnitFromStore');
      print(
          'CustomerIssueListScreen: bizUnit from SharedPreferences: $bizUnitFromPrefs');
      print('CustomerIssueListScreen: Final bizUnit: $bizUnit');

      // Validate bizUnit - it should not be 0
      if (bizUnit == 0) {
        throw Exception(
            'BizUnit is 0. UserDetailStore sbuId: $bizUnitFromStore, SharedPreferences sbuId: $bizUnitFromPrefs. Please ensure user details are loaded correctly.');
      }

      // Get menuId (default to 1554 as per API example)
      final menuId = 1554;

      // Prepare date filters
      String? fromDateStr;
      if (_stDateFrom != null) {
        fromDateStr =
            DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS").format(_stDateFrom!);
      }

      // Prepare status filter
      int? statusFilter;
      if (_status != null) {
        // Map status text to status code
        // 2 = Approved, 1 = Drafted, 0 = Cancelled (approximate mapping)
        if (_status == 'Approved') {
          statusFilter = 2;
        } else if (_status == 'Drafted') {
          statusFilter = 1;
        } else if (_status == 'Cancelled') {
          statusFilter = 0;
        }
      }

      // Prepare toStore filter
      int? toStoreFilter;
      if (_fromStore != null) {
        // Map store text to store ID
        // 6 = Inventory, 12 = Customer Store (from API response)
        if (_fromStore == 'Inventory') {
          toStoreFilter = 6;
        } else if (_fromStore == 'Customer Store') {
          toStoreFilter = 12;
        }
      }

      final request = ItemIssueListRequest(
        pageNumber: _currentPage,
        pageSize: _pageSize,
        userId: userId,
        bizUnit: bizUnit,
        menuId: menuId,
        fromDate: fromDateStr,
        toDate: _stDateTo != null
            ? DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS").format(_stDateTo!)
            : null,
        status: statusFilter,
        toStore: toStoreFilter,
        searchText: _issueNo, // Use issueNo as search text if provided
        transactionType: 14, // Customer Issue transaction type
      );

      final itemIssueRepository = getIt<ItemIssueRepository>();
      final response = await itemIssueRepository.getItemIssueList(request);

      if (mounted) {
        setState(() {
          if (refresh) {
            _issues = _convertApiItemsToCustomerIssues(response.items);
            _apiItemsById.clear(); // Clear map on refresh
          } else {
            _issues.addAll(_convertApiItemsToCustomerIssues(response.items));
          }

          // Store full API items by ID for editing
          for (var apiItem in response.items) {
            _apiItemsById[apiItem.id.toString()] = apiItem;
          }

          _hasMore = response.items.length >= _pageSize;
          _isLoading = false;

          // Update issue number list for filters
          _issueNoList = _issues
              .where((issue) => issue.issueNo.isNotEmpty)
              .map((issue) => issue.issueNo)
              .toSet()
              .toList();

          // Invalidate filter cache when data changes
          _invalidateFilterCache();
        });
      }
    } catch (e) {
      print('Error loading ItemIssue list: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Failed to load customer issues: ${e.toString()}';
        });
      }
    }
  }

  /// Convert API items to CustomerIssueItem list
  List<CustomerIssueItem> _convertApiItemsToCustomerIssues(
      List<ItemIssueApiItem> apiItems) {
    return apiItems.map((apiItem) {
      // Parse date string to DateTime
      DateTime? parsedDate;
      try {
        if (apiItem.date.isNotEmpty) {
          // Try parsing ISO format first
          parsedDate = DateTime.tryParse(apiItem.date);
          // If that fails, try other formats
          if (parsedDate == null) {
            parsedDate = DateFormat('yyyy-MM-dd').parse(apiItem.date);
          }
        }
      } catch (e) {
        print('Error parsing date: ${apiItem.date}');
        parsedDate = DateTime.now();
      }

      return CustomerIssueItem(
        id: apiItem.id.toString(),
        stDate: parsedDate ?? DateTime.now(),
        issueNo: apiItem.no,
        fromStore: apiItem.toStoreText.isNotEmpty
            ? apiItem.toStoreText
            : apiItem.departmentText,
        itemDetails: apiItem.itemText,
        status: apiItem.statusText,
      );
    }).toList();
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    _filterScrollController.dispose();
    _filterModalController?.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
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
    // Reload data from API with new filters
    _loadItemIssues(refresh: true);
  }

  // Clear all filters
  Future<void> _clearAllFilters() async {
    setState(() {
      _status = null;
      _fromStore = null;
      _issueNo = null;
      _stDateFrom = null;
      _stDateTo = null;
      _selectedStatusFilters.clear();
      _selectedIssueNoFilters.clear();
      for (var filter in _columnFilters.values) {
        filter.clear();
      }
      // Invalidate filter cache when filters change
      _invalidateFilterCache();
    });
    await _loadItemIssues(refresh: true);
  }

  // Get filter count
  int _getFilterCount() {
    int count = 0;
    if (_status != null) count++;
    if (_fromStore != null) count++;
    if (_issueNo != null) count++;
    if (_stDateFrom != null || _stDateTo != null) count++;
    if (_selectedStatusFilters.isNotEmpty) count++;
    if (_selectedIssueNoFilters.isNotEmpty) count++;
    for (var filter in _columnFilters.values) {
      if (filter.isActive) count++;
    }
    return count;
  }

  List<CustomerIssueItem> get _filteredIssues {
    // Use cached result if available and data/filters haven't changed
    if (_cachedFilteredIssues != null) {
      return _cachedFilteredIssues!;
    }

    // Compute filtered list
    List<CustomerIssueItem> filtered = List.from(_issues);

    // Apply status filter (multi-select)
    if (_selectedStatusFilters.isNotEmpty) {
      filtered = filtered.where((issue) {
        return _selectedStatusFilters.contains(issue.status);
      }).toList();
    }

    // Apply simple status filter
    if (_status != null) {
      filtered = filtered.where((issue) => issue.status == _status).toList();
    }

    // Apply Issue No filter (multi-select)
    if (_selectedIssueNoFilters.isNotEmpty) {
      filtered = filtered.where((issue) {
        final issueNo =
            issue.issueNo.isEmpty ? 'Issue #${issue.id}' : issue.issueNo;
        return _selectedIssueNoFilters.contains(issueNo);
      }).toList();
    }

    // Apply simple issue no filter
    if (_issueNo != null) {
      filtered = filtered.where((issue) => issue.issueNo == _issueNo).toList();
    }

    // Apply from store filter
    if (_fromStore != null) {
      filtered =
          filtered.where((issue) => issue.fromStore == _fromStore).toList();
    }

    // Apply column filters
    for (final entry in _columnFilters.entries) {
      final columnKey = entry.key;
      final filterState = entry.value;

      if (!filterState.isActive) continue;
      if (columnKey == 'status') continue; // Status handled separately
      if (columnKey == 'issueNo') continue; // Issue No handled separately

      filtered = filtered.where((issue) {
        String value = '';
        if (columnKey == 'stDate') {
          // Skip - date filtering handled separately with date comparison
          return true;
        } else if (columnKey == 'issueNo') {
          value = issue.issueNo.toLowerCase();
        } else if (columnKey == 'fromStore') {
          value = issue.fromStore.toLowerCase();
        } else if (columnKey == 'itemDetails') {
          value = issue.itemDetails.toLowerCase();
        }

        bool condition1Result;
        bool condition2Result;

        if (columnKey == 'stDate') {
          // Date-specific filtering
          condition1Result = _evaluateDateCondition(
            issue.stDate,
            filterState.condition1Operator,
            filterState.condition1Value,
          );
          condition2Result = _evaluateDateCondition(
            issue.stDate,
            filterState.condition2Operator,
            filterState.condition2Value,
          );
        } else {
          // Text-based filtering
          condition1Result = _evaluateCondition(
            value,
            filterState.condition1Operator,
            filterState.condition1Value.toLowerCase(),
          );
          condition2Result = _evaluateCondition(
            value,
            filterState.condition2Operator,
            filterState.condition2Value.toLowerCase(),
          );
        }

        if (filterState.logicalOperator == 'And') {
          return condition1Result && condition2Result;
        } else {
          return condition1Result || condition2Result;
        }
      }).toList();
    }

    // Cache the result
    _cachedFilteredIssues = filtered;
    return filtered;
  }

  /// Invalidate the filtered issues cache
  void _invalidateFilterCache() {
    _cachedFilteredIssues = null;
  }

  /// Show issue details modal (popup)
  void _showIssueDetails(BuildContext context, CustomerIssueItem issue) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final String statusLabel =
        issue.status.isNotEmpty ? issue.status : 'Status';

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
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F7),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4db1b3).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: Color(0xFF4db1b3),
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
                              'Customer Issue Details',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[900],
                                fontSize: isTablet ? 16 : 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _getStatusChip(statusLabel),
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
                      _DetailRow('ST Date',
                          DateFormat('dd-MMM-yyyy').format(issue.stDate)),
                      const SizedBox(height: 12),
                      _DetailRow('Issue No',
                          issue.issueNo.isEmpty ? 'N/A' : issue.issueNo),
                      const SizedBox(height: 12),
                      _DetailRow('From Store', issue.fromStore),
                      const SizedBox(height: 12),
                      _DetailRow('Status', issue.status),
                      const SizedBox(height: 20),
                      Divider(height: 1, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      _DetailRow('Item Details', issue.itemDetails,
                          isMultiline: true),
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
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            // Get full API item data for editing
                            final apiItem = _apiItemsById[issue.id];
                            print('═══════════════════════════════════════════════════════════');
                            print('✏️ EDIT BUTTON CLICKED');
                            print('═══════════════════════════════════════════════════════════');
                            print('Issue ID: ${issue.id}');
                            print('API Items Map Size: ${_apiItemsById.length}');
                            print('API Items Keys: ${_apiItemsById.keys.take(5).toList()}');
                            print('API Item Found: ${apiItem != null}');
                            if (apiItem != null) {
                              print('API Item ID: ${apiItem.id}');
                              print('API Item No: ${apiItem.no}');
                              print('API Item Details Count: ${apiItem.details?.length ?? 0}');
                            } else {
                              print('⚠️ WARNING: API Item not found in map!');
                            }
                            print('═══════════════════════════════════════════════════════════');
                            
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CustomerIssueEntryScreen(
                                  issueId: issue.id,
                                  issueData: issue,
                                  apiIssueData: apiItem, // Pass full API data
                                ),
                              ),
                            );
                            if (result == true) {
                              setState(() {}); // Refresh list
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
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Get full API item data for viewing
                            final apiItem = _apiItemsById[issue.id];
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CustomerIssueEntryScreen(
                                  issueId: issue.id,
                                  issueData: issue,
                                  apiIssueData: apiItem, // Pass full API data
                                  isViewOnly: true,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('View'),
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

  Widget _getStatusChip(String status) {
    final statusLower = status.toLowerCase();
    Color backgroundColor;
    Color textColor;

    // Match DCR screen styling
    if (statusLower.contains('approved')) {
      backgroundColor = const Color(0xFFE8F5E9); // Light green
      textColor = const Color(0xFF2E7D32); // Dark green
    } else if (statusLower.contains('drafted') ||
        statusLower.contains('draft')) {
      backgroundColor = const Color(0xFFF3E8FF); // Light purple
      textColor = const Color(0xFF6A1B9A); // Dark purple
    } else if (statusLower.contains('cancelled') ||
        statusLower.contains('cancel')) {
      backgroundColor = Colors.grey.shade200; // Light grey
      textColor = Colors.grey.shade700; // Dark grey
    } else {
      backgroundColor = Colors.grey.shade200;
      textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  bool _evaluateCondition(String value, String operator, String filterValue) {
    switch (operator) {
      case 'Is equal to':
        return value == filterValue;
      case 'Is not equal to':
        return value != filterValue;
      case 'Starts with':
        return value.startsWith(filterValue);
      case 'Contains':
        return value.contains(filterValue);
      case 'Does not contain':
        return !value.contains(filterValue);
      case 'Ends with':
        return value.endsWith(filterValue);
      case 'Is null':
        return value.isEmpty;
      case 'Is not null':
        return value.isNotEmpty;
      case 'Is empty':
        return value.isEmpty || value.trim().isEmpty;
      case 'Is not empty':
        return value.isNotEmpty && value.trim().isNotEmpty;
      case 'Has no value':
        return value.isEmpty;
      case 'Has value':
        return value.isNotEmpty;
      default:
        return true;
    }
  }

  bool _evaluateDateCondition(
      DateTime issueDate, String operator, String filterValue) {
    if (filterValue.isEmpty) {
      // For operators that don't need a value
      switch (operator) {
        case 'Is null':
          return false; // Dates are never null in our model
        case 'Is not null':
          return true;
        default:
          return true;
      }
    }

    final filterDate = DateTime.tryParse(filterValue);
    if (filterDate == null) {
      // Try parsing as M/d/yyyy format
      final parts = filterValue.split('/');
      if (parts.length == 3) {
        try {
          final month = int.parse(parts[0]);
          final day = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          final parsedDate = DateTime(year, month, day);
          return _compareDates(issueDate, operator, parsedDate);
        } catch (e) {
          return true;
        }
      }
      return true;
    }

    return _compareDates(issueDate, operator, filterDate);
  }

  bool _compareDates(DateTime issueDate, String operator, DateTime filterDate) {
    // Normalize to date only (remove time)
    final issueDateOnly =
        DateTime(issueDate.year, issueDate.month, issueDate.day);
    final filterDateOnly =
        DateTime(filterDate.year, filterDate.month, filterDate.day);

    switch (operator) {
      case 'Is equal to':
        return issueDateOnly.isAtSameMomentAs(filterDateOnly);
      case 'Is not equal to':
        return !issueDateOnly.isAtSameMomentAs(filterDateOnly);
      case 'Is after or equal to':
        return issueDateOnly.isAfter(filterDateOnly) ||
            issueDateOnly.isAtSameMomentAs(filterDateOnly);
      case 'Is after':
        return issueDateOnly.isAfter(filterDateOnly);
      case 'Is before or equal to':
        return issueDateOnly.isBefore(filterDateOnly) ||
            issueDateOnly.isAtSameMomentAs(filterDateOnly);
      case 'Is before':
        return issueDateOnly.isBefore(filterDateOnly);
      case 'Is null':
        return false;
      case 'Is not null':
        return true;
      default:
        return true;
    }
  }

  void _showStatusFilter(BuildContext context, GlobalKey? buttonKey) {
    final RenderBox? button =
        buttonKey?.currentContext?.findRenderObject() as RenderBox?;
    final isMobile = MediaQuery.of(context).size.width < 600;

    // On mobile, show as bottom sheet or centered dialog
    if (button == null || isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext dialogContext) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(16),
            child: _StatusFilterPopup(
              selectedStatuses: _selectedStatusFilters,
              searchText: _statusSearchText,
              onSearchChanged: (text) {
                setState(() {
                  _statusSearchText = text;
                });
              },
              onStatusToggled: (status) {
                setState(() {
                  if (_selectedStatusFilters.contains(status)) {
                    _selectedStatusFilters.remove(status);
                  } else {
                    _selectedStatusFilters.add(status);
                  }
                  _invalidateFilterCache();
                });
              },
              onSelectAll: (selectAll) {
                setState(() {
                  if (selectAll) {
                    _selectedStatusFilters.addAll(_statusOptions);
                  } else {
                    _selectedStatusFilters.clear();
                  }
                  _invalidateFilterCache();
                });
              },
              onApply: () {
                Navigator.of(context).pop();
              },
              onClear: () {
                setState(() {
                  _selectedStatusFilters.clear();
                  _statusSearchText = '';
                });
                Navigator.of(context).pop();
              },
            ),
          );
        },
      );
      return;
    }

    final Offset buttonPosition = button.localToGlobal(Offset.zero);
    final Size buttonSize = button.size;
    final Size screenSize = MediaQuery.of(context).size;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        double left = buttonPosition.dx;
        double top = buttonPosition.dy + buttonSize.height + 4;

        const double popupWidth = 280;
        if (left + popupWidth > screenSize.width) {
          left = screenSize.width - popupWidth - 8;
        }
        if (left < 8) {
          left = 8;
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(4),
                child: _StatusFilterPopup(
                  selectedStatuses: _selectedStatusFilters,
                  searchText: _statusSearchText,
                  onSearchChanged: (text) {
                    setState(() {
                      _statusSearchText = text;
                    });
                  },
                  onStatusToggled: (status) {
                    setState(() {
                      if (_selectedStatusFilters.contains(status)) {
                        _selectedStatusFilters.remove(status);
                      } else {
                        _selectedStatusFilters.add(status);
                      }
                    });
                  },
                  onSelectAll: (selectAll) {
                    setState(() {
                      if (selectAll) {
                        _selectedStatusFilters.addAll(_statusOptions);
                      } else {
                        _selectedStatusFilters.clear();
                      }
                    });
                  },
                  onApply: () {
                    Navigator.of(dialogContext).pop();
                  },
                  onClear: () {
                    setState(() {
                      _selectedStatusFilters.clear();
                      _statusSearchText = '';
                    });
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<String> get _statusOptions => ['Drafted', 'Approved', 'Cancelled'];

  List<String> get _issueNoOptions {
    return _issues
        .map((issue) {
          return issue.issueNo.isEmpty ? 'Issue #${issue.id}' : issue.issueNo;
        })
        .toSet()
        .toList()
      ..sort();
  }

  void _showIssueNoFilter(BuildContext context, GlobalKey? buttonKey) {
    final RenderBox? button =
        buttonKey?.currentContext?.findRenderObject() as RenderBox?;
    final isMobile = MediaQuery.of(context).size.width < 600;

    // On mobile, show as bottom sheet
    if (isMobile || button == null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext dialogContext) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(16),
            child: _IssueNoFilterPopup(
              selectedIssueNos: _selectedIssueNoFilters,
              searchText: _issueNoSearchText,
              issueNoOptions: _issueNoOptions,
              onSearchChanged: (text) {
                setState(() {
                  _issueNoSearchText = text;
                });
              },
              onIssueNoToggled: (issueNo) {
                setState(() {
                  if (_selectedIssueNoFilters.contains(issueNo)) {
                    _selectedIssueNoFilters.remove(issueNo);
                  } else {
                    _selectedIssueNoFilters.add(issueNo);
                  }
                  _invalidateFilterCache();
                });
              },
              onSelectAll: (selectAll) {
                setState(() {
                  if (selectAll) {
                    _selectedIssueNoFilters.addAll(_issueNoOptions);
                  } else {
                    _selectedIssueNoFilters.clear();
                  }
                  _invalidateFilterCache();
                });
              },
              onApply: () {
                Navigator.of(context).pop();
              },
              onClear: () {
                setState(() {
                  _selectedIssueNoFilters.clear();
                  _issueNoSearchText = '';
                  _invalidateFilterCache();
                });
                Navigator.of(context).pop();
              },
            ),
          );
        },
      );
      return;
    }

    final Offset buttonPosition = button.localToGlobal(Offset.zero);
    final Size buttonSize = button.size;
    final Size screenSize = MediaQuery.of(context).size;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        double left = buttonPosition.dx;
        double top = buttonPosition.dy + buttonSize.height + 4;

        const double popupWidth = 280;
        if (left + popupWidth > screenSize.width) {
          left = screenSize.width - popupWidth - 8;
        }
        if (left < 8) {
          left = 8;
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(4),
                child: _IssueNoFilterPopup(
                  selectedIssueNos: _selectedIssueNoFilters,
                  searchText: _issueNoSearchText,
                  issueNoOptions: _issueNoOptions,
                  onSearchChanged: (text) {
                    setState(() {
                      _issueNoSearchText = text;
                    });
                  },
                  onIssueNoToggled: (issueNo) {
                    setState(() {
                      if (_selectedIssueNoFilters.contains(issueNo)) {
                        _selectedIssueNoFilters.remove(issueNo);
                      } else {
                        _selectedIssueNoFilters.add(issueNo);
                      }
                      _invalidateFilterCache();
                    });
                  },
                  onSelectAll: (selectAll) {
                    setState(() {
                      if (selectAll) {
                        _selectedIssueNoFilters.addAll(_issueNoOptions);
                      } else {
                        _selectedIssueNoFilters.clear();
                      }
                      _invalidateFilterCache();
                    });
                  },
                  onApply: () {
                    Navigator.of(dialogContext).pop();
                  },
                  onClear: () {
                    setState(() {
                      _selectedIssueNoFilters.clear();
                      _issueNoSearchText = '';
                      _invalidateFilterCache();
                    });
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showStDateFilter(BuildContext context, GlobalKey? buttonKey) {
    final RenderBox? button =
        buttonKey?.currentContext?.findRenderObject() as RenderBox?;
    final isMobile = MediaQuery.of(context).size.width < 600;

    // On mobile, show as bottom sheet
    if (isMobile || button == null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext dialogContext) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(16),
            child: _DateFilterPopup(
              filterState: _columnFilters['stDate']!,
              operators: _dateFilterOperators,
              onApply: () {
                setState(() {
                  _columnFilters['stDate']!.isActive = true;
                  _invalidateFilterCache();
                });
                Navigator.of(dialogContext).pop();
              },
              onClear: () {
                setState(() {
                  _columnFilters['stDate']!.clear();
                  _invalidateFilterCache();
                });
                Navigator.of(dialogContext).pop();
              },
            ),
          );
        },
      );
      return;
    }

    final Offset buttonPosition = button.localToGlobal(Offset.zero);
    final Size buttonSize = button.size;
    final Size screenSize = MediaQuery.of(context).size;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        double left = buttonPosition.dx;
        double top = buttonPosition.dy + buttonSize.height + 4;

        const double popupWidth = 320;
        if (left + popupWidth > screenSize.width) {
          left = screenSize.width - popupWidth - 8;
        }
        if (left < 8) {
          left = 8;
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(4),
                child: _DateFilterPopup(
                  filterState: _columnFilters['stDate']!,
                  operators: _dateFilterOperators,
                  onApply: () {
                    setState(() {
                      _columnFilters['stDate']!.isActive = true;
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  onClear: () {
                    setState(() {
                      _columnFilters['stDate']!.clear();
                    });
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showColumnFilter(
      BuildContext context, String columnKey, GlobalKey buttonKey) {
    // For status, use special multi-select filter
    if (columnKey == 'status') {
      _showStatusFilter(context, buttonKey);
      return;
    }
    // For issueNo, use special multi-select filter
    if (columnKey == 'issueNo') {
      _showIssueNoFilter(context, buttonKey);
      return;
    }
    // For stDate, use date-specific filter
    if (columnKey == 'stDate') {
      _showStDateFilter(context, buttonKey);
      return;
    }
    final RenderBox? button =
        buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final isMobile = MediaQuery.of(context).size.width < 600;

    // On mobile, show as bottom sheet or centered dialog
    if (isMobile || button == null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext dialogContext) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(16),
            child: _ColumnFilterPopup(
              filterState: _columnFilters[columnKey]!,
              operators: _filterOperators,
              onApply: () {
                setState(() {
                  _columnFilters[columnKey]!.isActive = true;
                  _invalidateFilterCache();
                });
                Navigator.of(dialogContext).pop();
              },
              onClear: () {
                setState(() {
                  _columnFilters[columnKey]!.clear();
                  _invalidateFilterCache();
                });
                Navigator.of(dialogContext).pop();
              },
            ),
          );
        },
      );
      return;
    }

    final Offset buttonPosition = button.localToGlobal(Offset.zero);
    final Size buttonSize = button.size;
    final Size screenSize = MediaQuery.of(context).size;

    setState(() {
      _activeFilterColumn = columnKey;
    });

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        // Calculate position - adjust if too close to screen edges
        double left = buttonPosition.dx;
        double top = buttonPosition.dy + buttonSize.height + 4;

        // Ensure popup doesn't go off screen
        const double popupWidth = 320;
        if (left + popupWidth > screenSize.width) {
          left = screenSize.width - popupWidth - 8;
        }
        if (left < 8) {
          left = 8;
        }

        return Stack(
          children: [
            // Click outside to close
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  setState(() {
                    _activeFilterColumn = null;
                  });
                },
                child: Container(color: Colors.transparent),
              ),
            ),
            // Filter popup
            Positioned(
              left: left,
              top: top,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(4),
                child: _ColumnFilterPopup(
                  filterState: _columnFilters[columnKey]!,
                  operators: _filterOperators,
                  onApply: () {
                    setState(() {
                      _columnFilters[columnKey]!.isActive = true;
                    });
                    Navigator.of(dialogContext).pop();
                    setState(() {
                      _activeFilterColumn = null;
                    });
                  },
                  onClear: () {
                    setState(() {
                      _columnFilters[columnKey]!.clear();
                    });
                    Navigator.of(dialogContext).pop();
                    setState(() {
                      _activeFilterColumn = null;
                    });
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Build Header Section (matches DCR pattern)
  Widget _buildHeader(bool isTablet, Color tealGreen) {
    final bool isMobile = !isTablet;
    return Container(
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
                  'Customer Issues',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey[900],
                    letterSpacing: -0.8,
                  ),
                ),
                SizedBox(height: isTablet ? 6 : 4),
                Text(
                  'View and manage customer issues',
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

  // Build Filter Button with Record Count (display only, not clickable)
  Widget _buildFilterButtonWithCount(bool isTablet, Color tealGreen) {
    final bool isMobile = !isTablet;
    final int recordCount = _filteredIssues.length;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
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
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(
            Icons.filter_alt_rounded,
            color: tealGreen,
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$recordCount ${recordCount == 1 ? 'record' : 'records'}',
              style: GoogleFonts.inter(
                fontSize: 14,
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
    );
  }

  // Build Action Buttons Section (matches DCR pattern)
  Widget _buildActionButtonsSection(bool isTablet, Color tealGreen) {
    final bool isMobile = !isTablet;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double w = constraints.maxWidth;
          final bool isVeryNarrow = w < 380;
          if (isVeryNarrow) {
            // Stack vertically on small phones
            return Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomerIssueEntryScreen(),
                        ),
                      );
                      if (context.mounted) {
                        await _loadItemIssues(refresh: true);
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      'Customer Issue',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: tealGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Filter button with record count
                SizedBox(
                  width: double.infinity,
                  child: _buildFilterButtonWithCount(isTablet, tealGreen),
                ),
              ],
            );
          } else {
            // Side by side on larger screens
            return Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomerIssueEntryScreen(),
                        ),
                      );
                      if (context.mounted) {
                        await _loadItemIssues(refresh: true);
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      'Customer Issue',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: tealGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Filter button with record count - same width as Customer Issue button
                Expanded(
                  child: _buildFilterButtonWithCount(isTablet, tealGreen),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isTablet = MediaQuery.of(context).size.width >= 800;
    const Color tealGreen = Color(0xFF4db1b3);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _dismissKeyboard,
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadItemIssues(refresh: true);
        },
        color: tealGreen,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _listScrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // Header Section
                SliverToBoxAdapter(
                  child: _buildHeader(isTablet, tealGreen),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: isTablet ? 14 : 12),
                ),

                // Action Buttons Section
                SliverToBoxAdapter(
                  child: _buildActionButtonsSection(isTablet, tealGreen),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: isTablet ? 14 : 12),
                ),
                // List of issues (cards)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    MediaQuery.of(context).size.width >= 600 ? 16 : 12,
                    0,
                    MediaQuery.of(context).size.width >= 600 ? 16 : 12,
                    16,
                  ),
                  sliver: _isLoading && _issues.isEmpty
                      ? SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            child: const Center(
                                child: CircularProgressIndicator()),
                          ),
                        )
                      : _loadError != null && _issues.isEmpty
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
                                      'Failed to load customer issues',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _loadError!,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _loadItemIssues(refresh: true),
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
                          : _filteredIssues.isEmpty
                              ? SliverToBoxAdapter(
                                  child: Container(
                                    padding: const EdgeInsets.all(40),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.inbox,
                                            size: 64,
                                            color: Colors.grey.shade400),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No customer issues found',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Try adjusting your search or filter criteria',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
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
                                      final issue = _filteredIssues[index];
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: _CustomerIssueCard(
                                          issue: issue,
                                          onViewDetails: () =>
                                              _showIssueDetails(context, issue),
                                        ),
                                      );
                                    },
                                    childCount: _filteredIssues.length,
                                  ),
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
    String? _tempFromStore = _fromStore;
    String? _tempIssueNo = _issueNo;

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
                              fontWeight: FontWeight.w900,
                              color: Colors.grey[900],
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    StatefulBuilder(
                      builder: (context, setModalState) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: SingleChildScrollView(
                                controller: _filterScrollController,
                                padding: EdgeInsets.fromLTRB(
                                  isMobile ? 16 : 20,
                                  isMobile ? 16 : 20,
                                  isMobile ? 16 : 20,
                                  isMobile ? 16 : 20,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Status Filter (multi-select checkbox)
                                    _buildFilterSection(
                                      title: 'Status',
                                      icon: Icons.flag_outlined,
                                      hasActiveFilter:
                                          _selectedStatusFilters.isNotEmpty,
                                      onTap: () =>
                                          _showStatusFilter(context, null),
                                      selectedCount:
                                          _selectedStatusFilters.length,
                                      isTablet: isTablet,
                                    ),
                                    const SizedBox(height: 24),
                                    // Issue No Filter (multi-select checkbox)
                                    _buildFilterSection(
                                      title: 'Issue No',
                                      icon: Icons.numbers_outlined,
                                      hasActiveFilter:
                                          _selectedIssueNoFilters.isNotEmpty,
                                      onTap: () =>
                                          _showIssueNoFilter(context, null),
                                      selectedCount:
                                          _selectedIssueNoFilters.length,
                                      isTablet: isTablet,
                                    ),
                                    const SizedBox(height: 24),
                                    // ST Date Filter (date filter with operators)
                                    _buildFilterSection(
                                      title: 'ST Date',
                                      icon: Icons.calendar_today_outlined,
                                      hasActiveFilter:
                                          _columnFilters['stDate']!.isActive,
                                      onTap: () =>
                                          _showStDateFilter(context, null),
                                      selectedCount:
                                          _columnFilters['stDate']!.isActive
                                              ? 1
                                              : 0,
                                      isTablet: isTablet,
                                    ),
                                    const SizedBox(height: 24),
                                    // From Store Filter (column filter with operators)
                                    _buildFilterSection(
                                      title: 'From Store',
                                      icon: Icons.store_outlined,
                                      hasActiveFilter:
                                          _columnFilters['fromStore']!.isActive,
                                      onTap: () => _showColumnFilter(
                                          context, 'fromStore', GlobalKey()),
                                      selectedCount:
                                          _columnFilters['fromStore']!.isActive
                                              ? 1
                                              : 0,
                                      isTablet: isTablet,
                                    ),
                                    const SizedBox(height: 24),
                                    // Item Details Filter (column filter with operators)
                                    _buildFilterSection(
                                      title: 'Item Details',
                                      icon: Icons.description_outlined,
                                      hasActiveFilter:
                                          _columnFilters['itemDetails']!
                                              .isActive,
                                      onTap: () => _showColumnFilter(
                                          context, 'itemDetails', GlobalKey()),
                                      selectedCount:
                                          _columnFilters['itemDetails']!
                                                  .isActive
                                              ? 1
                                              : 0,
                                      isTablet: isTablet,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Footer
                            Container(
                              padding: EdgeInsets.all(isMobile ? 16 : 20),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                      color: Colors.grey.withOpacity(0.1),
                                      width: 1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        setModalState(() {
                                          _tempStatus = null;
                                          _tempFromStore = null;
                                          _tempIssueNo = null;
                                          _selectedStatusFilters.clear();
                                          _selectedIssueNoFilters.clear();
                                          for (var filter
                                              in _columnFilters.values) {
                                            filter.clear();
                                          }
                                        });
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
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        side: BorderSide(
                                            color: tealGreen, width: 1.5),
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
                                        setState(() {
                                          _status = _tempStatus;
                                          _fromStore = _tempFromStore;
                                          _issueNo = _tempIssueNo;
                                        });
                                        _closeFilterModal();
                                        _loadItemIssues(refresh: true);
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
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        'Apply Filter',
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required bool hasActiveFilter,
    required VoidCallback onTap,
    required int selectedCount,
    required bool isTablet,
  }) {
    const tealGreen = Color(0xFF4db1b3);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(isTablet ? 16 : 14),
        decoration: BoxDecoration(
          color: hasActiveFilter
              ? tealGreen.withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasActiveFilter
                ? tealGreen.withOpacity(0.3)
                : Colors.grey.shade300,
            width: hasActiveFilter ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: isTablet ? 20 : 18,
              color: hasActiveFilter ? tealGreen : Colors.grey.shade700,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 15 : 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  if (hasActiveFilter && selectedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        selectedCount == 1
                            ? '1 filter applied'
                            : '$selectedCount filters applied',
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 12 : 11,
                          color: tealGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (hasActiveFilter)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tealGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  selectedCount.toString(),
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 12 : 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: isTablet ? 14 : 12,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCardList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredIssues.length,
      itemBuilder: (context, index) {
        final issue = _filteredIssues[index];
        return _CustomerIssueCard(
          issue: issue,
          onViewDetails: () => _showIssueDetails(context, issue),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMultiline;

  const _DetailRow(this.label, this.value, {this.isMultiline = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade900,
          ),
          maxLines: isMultiline ? null : 2,
          overflow: isMultiline ? null : TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _CustomerIssueCard extends StatelessWidget {
  final CustomerIssueItem issue;
  final VoidCallback? onViewDetails;

  const _CustomerIssueCard({
    required this.issue,
    this.onViewDetails,
  });

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
                  child: const Icon(
                    Icons.error_outline,
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
                        issue.issueNo.isEmpty
                            ? 'Issue #${issue.id}'
                            : issue.issueNo,
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
                      _getStatusChip(issue.status),
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
            _iconKvRow(context, Icons.calendar_today_outlined, 'ST Date',
                DateFormat('dd-MMM-yyyy').format(issue.stDate)),
            SizedBox(height: isMobile ? 6 : 8),
            _iconKvRow(
                context, Icons.store_outlined, 'From Store', issue.fromStore),
          ],
        ),
      ),
    );
  }

  // Icon + key/value row (same as deviation)
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

  static Widget _getStatusChip(String status) {
    final statusLower = status.toLowerCase();
    Color backgroundColor;
    Color textColor;

    // Match DCR screen styling
    if (statusLower.contains('approved')) {
      backgroundColor = const Color(0xFFE8F5E9); // Light green
      textColor = const Color(0xFF2E7D32); // Dark green
    } else if (statusLower.contains('drafted') ||
        statusLower.contains('draft')) {
      backgroundColor = const Color(0xFFF3E8FF); // Light purple
      textColor = const Color(0xFF6A1B9A); // Dark purple
    } else if (statusLower.contains('cancelled') ||
        statusLower.contains('cancel')) {
      backgroundColor = Colors.grey.shade200; // Light grey
      textColor = Colors.grey.shade700; // Dark grey
    } else {
      backgroundColor = Colors.grey.shade200;
      textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

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

    return Container(
      width: isMobile ? screenWidth - 32 : 320,
      constraints: BoxConstraints(
        maxWidth: isMobile ? screenWidth - 32 : 320,
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              const Icon(Icons.filter_list, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Filter',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

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
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'And', child: Text('And')),
                DropdownMenuItem(value: 'Or', child: Text('Or')),
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
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onClear,
                child: const Text(
                  'Clear',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  widget.filterState
                    ..condition1Operator = _localState.condition1Operator
                    ..condition1Value = _localState.condition1Value
                    ..logicalOperator = _localState.logicalOperator
                    ..condition2Operator = _localState.condition2Operator
                    ..condition2Value = _localState.condition2Value;
                  widget.onApply();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('Filter'),
              ),
            ],
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              flex: needsValue ? 1 : 2,
              child: DropdownButtonFormField<String>(
                value: operator,
                isExpanded: true,
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
                      borderSide: BorderSide(color: Colors.grey.shade300),
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

// Status Filter Popup (Multi-select with checkboxes)
class _StatusFilterPopup extends StatefulWidget {
  final Set<String> selectedStatuses;
  final String searchText;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusToggled;
  final ValueChanged<bool> onSelectAll;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const _StatusFilterPopup({
    required this.selectedStatuses,
    required this.searchText,
    required this.onSearchChanged,
    required this.onStatusToggled,
    required this.onSelectAll,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_StatusFilterPopup> createState() => _StatusFilterPopupState();
}

class _StatusFilterPopupState extends State<_StatusFilterPopup> {
  late TextEditingController _searchController;
  final List<String> _allStatuses = ['Drafted', 'Approved', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchText);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredStatuses {
    if (_searchController.text.isEmpty) {
      return _allStatuses;
    }
    return _allStatuses.where((status) {
      return status
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
    }).toList();
  }

  bool get _isAllSelected {
    final filtered = _filteredStatuses;
    return filtered.isNotEmpty &&
        filtered.every((status) => widget.selectedStatuses.contains(status));
  }

  @override
  Widget build(BuildContext context) {
    const blueColor = Color(0xFF2196F3);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: isMobile ? double.infinity : 280,
      constraints: BoxConstraints(
        maxHeight: isMobile ? double.infinity : 400,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              const Icon(Icons.filter_list, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Filter',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon:
                  const Icon(Icons.search, size: 20, color: Colors.grey),
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
                borderSide: BorderSide(color: blueColor, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (value) {
              widget.onSearchChanged(value);
              setState(() {}); // Rebuild to update filtered list
            },
          ),
          const SizedBox(height: 12),

          // Status list with checkboxes
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // Select All
                CheckboxListTile(
                  title: Text(
                    'Select All',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  value: _isAllSelected,
                  onChanged: (value) {
                    widget.onSelectAll(value ?? false);
                    setState(() {});
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 1),
                // Individual statuses
                ..._filteredStatuses.map((status) {
                  return CheckboxListTile(
                    title: Text(
                      status,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                      ),
                    ),
                    value: widget.selectedStatuses.contains(status),
                    onChanged: (value) {
                      widget.onStatusToggled(status);
                      setState(() {});
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onClear,
                child: const Text(
                  'Clear',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: widget.onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('Filter'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Issue No Filter Popup (Multi-select with checkboxes)
class _IssueNoFilterPopup extends StatefulWidget {
  final Set<String> selectedIssueNos;
  final String searchText;
  final List<String> issueNoOptions;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onIssueNoToggled;
  final ValueChanged<bool> onSelectAll;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const _IssueNoFilterPopup({
    required this.selectedIssueNos,
    required this.searchText,
    required this.issueNoOptions,
    required this.onSearchChanged,
    required this.onIssueNoToggled,
    required this.onSelectAll,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_IssueNoFilterPopup> createState() => _IssueNoFilterPopupState();
}

class _IssueNoFilterPopupState extends State<_IssueNoFilterPopup> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchText);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredIssueNos {
    if (_searchController.text.isEmpty) {
      return widget.issueNoOptions;
    }
    return widget.issueNoOptions.where((issueNo) {
      return issueNo
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
    }).toList();
  }

  bool get _isAllSelected {
    final filtered = _filteredIssueNos;
    return filtered.isNotEmpty &&
        filtered.every((issueNo) => widget.selectedIssueNos.contains(issueNo));
  }

  @override
  Widget build(BuildContext context) {
    const blueColor = Color(0xFF2196F3);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: isMobile ? double.infinity : 280,
      constraints: BoxConstraints(
        maxHeight: isMobile ? double.infinity : 400,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              const Icon(Icons.filter_list, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Filter',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon:
                  const Icon(Icons.search, size: 20, color: Colors.grey),
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
                borderSide: BorderSide(color: blueColor, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (value) {
              widget.onSearchChanged(value);
              setState(() {}); // Rebuild to update filtered list
            },
          ),
          const SizedBox(height: 12),

          // Issue No list with checkboxes
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // Select All
                CheckboxListTile(
                  title: Text(
                    'Select All',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  value: _isAllSelected,
                  onChanged: (value) {
                    widget.onSelectAll(value ?? false);
                    setState(() {});
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 1),
                // Individual issue numbers
                ..._filteredIssueNos.map((issueNo) {
                  return CheckboxListTile(
                    title: Text(
                      issueNo,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                      ),
                    ),
                    value: widget.selectedIssueNos.contains(issueNo),
                    onChanged: (value) {
                      widget.onIssueNoToggled(issueNo);
                      setState(() {});
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onClear,
                child: const Text(
                  'Clear',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: widget.onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('Filter'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Date Filter Popup (with date pickers)
class _DateFilterPopup extends StatefulWidget {
  final ColumnFilterState filterState;
  final List<String> operators;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const _DateFilterPopup({
    required this.filterState,
    required this.operators,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_DateFilterPopup> createState() => _DateFilterPopupState();
}

class _DateFilterPopupState extends State<_DateFilterPopup> {
  late ColumnFilterState _localState;
  late TextEditingController _condition1DateController;
  late TextEditingController _condition2DateController;

  @override
  void initState() {
    super.initState();
    // Validate operators - if not in date operators list, reset to default
    String op1 = widget.filterState.condition1Operator;
    if (!widget.operators.contains(op1)) {
      op1 = 'Is equal to';
    }
    String op2 = widget.filterState.condition2Operator;
    if (!widget.operators.contains(op2)) {
      op2 = 'Is equal to';
    }

    _localState = ColumnFilterState()
      ..condition1Operator = op1
      ..condition1Value = widget.filterState.condition1Value
      ..logicalOperator = widget.filterState.logicalOperator
      ..condition2Operator = op2
      ..condition2Value = widget.filterState.condition2Value;

    _condition1DateController =
        TextEditingController(text: _localState.condition1Value);
    _condition2DateController =
        TextEditingController(text: _localState.condition2Value);
  }

  @override
  void dispose() {
    _condition1DateController.dispose();
    _condition2DateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isCondition1) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final formattedDate = DateFormat('M/d/yyyy').format(picked);
      setState(() {
        if (isCondition1) {
          _localState.condition1Value = formattedDate;
          _condition1DateController.text = formattedDate;
        } else {
          _localState.condition2Value = formattedDate;
          _condition2DateController.text = formattedDate;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const blueColor = Color(0xFF2196F3);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: isMobile ? screenWidth - 32 : 320,
      constraints: BoxConstraints(
        maxWidth: isMobile ? screenWidth - 32 : 320,
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              const Icon(Icons.filter_list, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Filter',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Condition 1
          _buildDateConditionRow(
            operator: _localState.condition1Operator,
            dateValue: _localState.condition1Value,
            controller: _condition1DateController,
            onOperatorChanged: (op) {
              setState(() {
                _localState.condition1Operator = op;
              });
            },
            onDateChanged: (date) {
              setState(() {
                _localState.condition1Value = date;
              });
            },
            onDatePickerTap: () => _selectDate(context, true),
          ),

          // Logical operator and Condition 2 (always shown)
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: DropdownButtonFormField<String>(
              value: _localState.logicalOperator,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'And', child: Text('And')),
                DropdownMenuItem(value: 'Or', child: Text('Or')),
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
          _buildDateConditionRow(
            operator: _localState.condition2Operator,
            dateValue: _localState.condition2Value,
            controller: _condition2DateController,
            onOperatorChanged: (op) {
              setState(() {
                _localState.condition2Operator = op;
              });
            },
            onDateChanged: (date) {
              setState(() {
                _localState.condition2Value = date;
              });
            },
            onDatePickerTap: () => _selectDate(context, false),
          ),

          const SizedBox(height: 16),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onClear,
                child: const Text(
                  'Clear',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  widget.filterState
                    ..condition1Operator = _localState.condition1Operator
                    ..condition1Value = _localState.condition1Value
                    ..logicalOperator = _localState.logicalOperator
                    ..condition2Operator = _localState.condition2Operator
                    ..condition2Value = _localState.condition2Value;
                  widget.onApply();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('Filter'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateConditionRow({
    required String operator,
    required String dateValue,
    required TextEditingController controller,
    required ValueChanged<String> onOperatorChanged,
    required ValueChanged<String> onDateChanged,
    required VoidCallback onDatePickerTap,
  }) {
    final bool needsValue = !['Is null', 'Is not null'].contains(operator);

    return Row(
      children: [
        Expanded(
          flex: needsValue ? 1 : 2,
          child: DropdownButtonFormField<String>(
            value: operator,
            isExpanded: true,
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
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                onOperatorChanged(val);
                setState(() {}); // Rebuild to show/hide date field
              }
            },
          ),
        ),
        if (needsValue) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'M/d/yyyy',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today, size: 20),
                  onPressed: onDatePickerTap,
                  padding: EdgeInsets.zero,
                ),
              ),
              onChanged: onDateChanged,
              readOnly: true,
              onTap: onDatePickerTap,
            ),
          ),
        ],
      ],
    );
  }
}

class CustomerIssueItem {
  final String id;
  final DateTime stDate;
  final String issueNo;
  final String fromStore;
  final String itemDetails;
  final String status;

  CustomerIssueItem({
    required this.id,
    required this.stDate,
    required this.issueNo,
    required this.fromStore,
    required this.itemDetails,
    required this.status,
  });
}
