import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boilerplate/domain/repository/expense/expense_repository.dart';
import 'package:boilerplate/domain/repository/dcr/dcr_repository.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/entity/expense/expense.dart';
import 'package:boilerplate/domain/entity/dcr/dcr_api_models.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api_models.dart';
import 'package:boilerplate/data/network/constants/endpoints.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';
import 'package:boilerplate/presentation/crm/widgets/manager_comment_dialog.dart';
import 'package:boilerplate/data/network/apis/dcr/dcr_api.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';

const String kFilterClearToken = '__CLEAR__';

/// Expense Manager Review screen for managers to review and approve/reject expenses
class ExpenseManagerReviewScreen extends StatefulWidget {
  const ExpenseManagerReviewScreen({super.key});

  @override
  ExpenseManagerReviewScreenState createState() => ExpenseManagerReviewScreenState();
}

// Expose state for parent to call reload
class ExpenseManagerReviewScreenState extends State<ExpenseManagerReviewScreen> with SingleTickerProviderStateMixin {
  // Initialize to first day of current month for month-wise filtering
  DateTime _date = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? _selectedEmployee;
  String? _status;
  List<ExpenseEntry> _expenseItems = [];
  final Set<String> _selectedItems = <String>{};
  bool _isLoading = false;
  
  // Employee options for manager's team
  List<String> _employeeOptions = [];
  Map<String, int> _employeeNameToId = {};
  
  // Status options
  List<String> _statusOptions = [];
  Map<String, int> _statusNameToId = {};
  
  // Map to store dcrStatusId for each expense (key: expense id, value: dcrStatusId)
  final Map<String, int> _expenseIdToDcrStatusId = {};
  
  // Filter modal state
  bool _showFilterModal = false;
  late AnimationController _filterModalController;
  late Animation<double> _filterModalAnimation;
  final ScrollController _filterScrollController = ScrollController();
  final GlobalKey _statusFilterSectionKey = GlobalKey();
  final GlobalKey _employeeFilterSectionKey = GlobalKey();
  VoidCallback? _pendingFilterApply;
  
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
  void initState() {
    super.initState();
    // Initialize filter modal animation
    _filterModalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _filterModalAnimation = CurvedAnimation(
      parent: _filterModalController,
      curve: Curves.easeOut,
    );
    _initializeData();
  }
  
  @override
  void dispose() {
    _filterModalController.dispose();
    _filterScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _getManagerTeamEmployees();
    await _getExpenseStatusList();
    await _load();
  }

  // Public method to reload data (called when tab becomes visible)
  void reload() {
    if (mounted) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final DcrRepository? dcrRepo = getIt.isRegistered<DcrRepository>() ? getIt<DcrRepository>() : null;
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
      final int? managerId = userStore?.userDetail?.employeeId;
      
      if (dcrRepo == null || managerId == null) {
        if (!mounted) return;
        setState(() {
          _expenseItems = [];
          _isLoading = false;
        });
        return;
      }

      // Calculate first and last day of the selected month
      final DateTime start = DateTime(_date.year, _date.month, 1); // First day of month
      final DateTime end = DateTime(_date.year, _date.month + 1, 0); // Last day of month
      
      // Format dates with full ISO8601 format (with time)
      final String fromDateStr = DateTime(start.year, start.month, start.day, 0, 0, 0, 0)
          .toIso8601String()
          .replaceAll(RegExp(r'\.\d{6}'), '.000');
      final String toDateStr = DateTime(end.year, end.month, end.day, 23, 59, 59, 999)
          .toIso8601String()
          .replaceAll(RegExp(r'\.\d{6}'), '.000');
      
      // Use selected employee if provided, else get all team expenses
      final int? selectedEmployeeId = _selectedEmployeeId();
      final int? selectedStatusId = _statusIdFromText(_status);
      
      List<DcrApiItem> apiItems = [];
      
      if (_isAllStaffSelected()) {
        // When "All Staff" is selected, call API with EmployeeId: 0 and ManagerId: 61
        try {
          if (getIt.isRegistered<DcrApi>()) {
            final dcrApi = getIt<DcrApi>();
            final sharedPrefHelper = getIt<SharedPreferenceHelper>();
            final user = await sharedPrefHelper.getUser();
            
            if (user != null) {
              final request = DcrListRequest(
                pageNumber: 1,
                pageSize: 1000,
                sortOrder: 0,
                sortDir: 0,
                sortField: 'DCRDate',
                fromDate: fromDateStr,
                toDate: toDateStr,
                userId: user.userId ?? user.id,
                bizunit: user.sbuId,
                status: selectedStatusId,
                employeeId: 0, // EmployeeId: 0 for "All Staff"
                managerId: 61, // ManagerId: 61 as specified
                transactionType: "Expense", // Filter for expenses only
                dcrDate: null, // Set to null as per requirement
              );
              
              final response = await dcrApi.getDcrList(request);
              apiItems = response.items;
              print('ExpenseManagerReviewScreen: Loaded expenses with All Staff filter (EmployeeId: 0, ManagerId: 61)');
            }
          }
        } catch (e) {
          print('Error loading expenses with All Staff filter: $e');
        }
      } else if (selectedEmployeeId != null) {
        // Load expenses for specific employee
        apiItems = await dcrRepo.getDcrListUnified(
          start: start,
          end: end,
          employeeId: selectedEmployeeId.toString(),
          statusId: selectedStatusId,
          transactionType: "Expense", // Filter for expenses only
        );
      } else {
        // Load expenses for all team members
        // First get the manager's own expenses
        apiItems = await dcrRepo.getDcrListUnified(
          start: start,
          end: end,
          employeeId: managerId.toString(),
          statusId: selectedStatusId,
          transactionType: "Expense", // Filter for expenses only
        );
        
        // Then get expenses for each team member
        if (_employeeOptions.isNotEmpty) {
          for (final employeeName in _employeeOptions) {
            // Skip "All Staff" option
            if (employeeName == 'All Staff') continue;
            
            final int? employeeId = _employeeNameToId[employeeName];
            if (employeeId != null && employeeId != managerId) {
              try {
                final List<DcrApiItem> teamMemberExpenses = await dcrRepo.getDcrListUnified(
                  start: start,
                  end: end,
                  employeeId: employeeId.toString(),
                  statusId: selectedStatusId,
                  transactionType: "Expense", // Filter for expenses only
                );
                apiItems.addAll(teamMemberExpenses);
              } catch (e) {
                print('Error loading expenses for employee $employeeName (ID: $employeeId): $e');
              }
            }
          }
        }
      }
      
      // Filter for Expense items only (exclude DCR items) - client-side filter as API may return mixed results
      final List<DcrApiItem> expenseApiItems = apiItems
          .where((item) => item.transactionType == "Expense")
          .toList();
      
      // Convert API items to ExpenseEntry objects and store dcrStatusId mapping
      _expenseIdToDcrStatusId.clear(); // Clear previous mappings
      final List<ExpenseEntry> expenseItems = expenseApiItems
          .map((item) {
            final expenseEntry = _convertDcrApiItemToExpenseEntry(item);
            // Store the dcrStatusId for this expense
            _expenseIdToDcrStatusId[expenseEntry.id] = item.dcrStatusId;
            return expenseEntry;
          })
          .toList();
      
      // Show ALL expenses (Approved, Pending, Submitted, etc.) - status filter applied at API level
      final List<ExpenseEntry> reviewableExpenses = expenseItems;
      
      print('ExpenseManagerReviewScreen: Loaded ${apiItems.length} API items (${expenseApiItems.length} Expense items), ${reviewableExpenses.length} expenses after reviewable filter');
      print('ExpenseManagerReviewScreen: Status filter: $_status, TransactionType: Expense');
      
      if (!mounted) return;
      
      setState(() {
        _expenseItems = reviewableExpenses;
        _selectedItems.clear(); // Clear selections when data changes
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading expense data for manager review: $e');
      if (!mounted) return;
      setState(() {
        _expenseItems = [];
        _isLoading = false;
      });
    }
  }

  /// Convert DcrApiItem to ExpenseEntry for expense items
  ExpenseEntry _convertDcrApiItemToExpenseEntry(DcrApiItem item) {
    // Parse amount from typeOfWork field (e.g., "Amount: 1200.00")
    double amount = 0.0;
    if (item.typeOfWork.startsWith('Amount: ')) {
      final amountStr = item.typeOfWork.replaceFirst('Amount: ', '').replaceAll(',', '');
      amount = double.tryParse(amountStr) ?? 0.0;
    }
    
    // Parse expense head from customerName field (e.g., "Expense: Accomodation")
    String expenseHead = 'Unknown';
    if (item.customerName.startsWith('Expense: ')) {
      expenseHead = item.customerName.replaceFirst('Expense: ', '');
    }
    
    // Map status
    // For expenses, statusText might be "Expense" (transaction type), so use dcrStatusId
    ExpenseStatus status = ExpenseStatus.submitted;
    
    // If statusText is "Expense", use dcrStatusId to determine actual status
    if (item.statusText != null && item.statusText.toLowerCase() == 'expense') {
      // Map dcrStatusId to ExpenseStatus
      // Common mappings: 0=Draft, 1=Draft, 2=SentBack, 3=Submitted, 4=SentBack, 5=Approved
      switch (item.dcrStatusId) {
        case 0:
        case 1:
          status = ExpenseStatus.draft;
          break;
        case 2:
          status = ExpenseStatus.sentBack;
          break;
        case 3:
          status = ExpenseStatus.submitted;
          break;
        case 4:
          status = ExpenseStatus.sentBack;
          break;
        case 5:
          status = ExpenseStatus.approved;
          break;
        default:
          status = ExpenseStatus.submitted;
      }
    } else if (item.statusText != null) {
      // Use statusText if it's not "Expense"
      switch (item.statusText.toLowerCase()) {
        case 'submitted':
          status = ExpenseStatus.submitted;
          break;
        case 'approved':
          status = ExpenseStatus.approved;
          break;
        case 'rejected':
          status = ExpenseStatus.rejected;
          break;
        case 'sent back':
        case 'sentback':
          status = ExpenseStatus.sentBack;
          break;
        case 'draft':
          status = ExpenseStatus.draft;
          break;
        default:
          status = ExpenseStatus.submitted;
      }
    }
    
    return ExpenseEntry(
      id: item.id.toString(),
      date: DateTime.parse(item.dcrDate),
      cluster: item.clusterNames.trim(),
      expenseHead: expenseHead,
      amount: amount,
      remarks: item.remarks ?? '',
      status: status,
      employeeId: item.employeeId.toString(),
      employeeName: item.employeeName,
      createdAt: DateTime.now(),
    );
  }

  bool _isReviewableStatus(ExpenseEntry item) {
    return item.status == ExpenseStatus.submitted || 
           item.status == ExpenseStatus.sentBack;
  }

  bool _isApproved(ExpenseEntry item) {
    return item.status == ExpenseStatus.approved;
  }

  int? _selectedEmployeeId() {
    // Handle special option: "All Staff" means pass EmployeeId: 0 and ManagerId: 61
    if (_selectedEmployee == null || _selectedEmployee == 'All Staff') {
      return null; // null indicates "All Staff" selection
    }
    if (_selectedEmployee != null && _employeeNameToId.containsKey(_selectedEmployee)) {
      return _employeeNameToId[_selectedEmployee!];
    }
    return null;
  }
  
  // Check if "All Staff" is selected
  bool _isAllStaffSelected() {
    return _selectedEmployee == 'All Staff';
  }

  ExpenseStatus? _statusFromText(String? statusText) {
    if (statusText == null) return null;
    switch (statusText.toLowerCase()) {
      case 'draft': return ExpenseStatus.draft;
      case 'submitted': return ExpenseStatus.submitted;
      case 'approved': return ExpenseStatus.approved;
      case 'rejected': return ExpenseStatus.rejected;
      case 'sent back': return ExpenseStatus.sentBack;
      default: return null;
    }
  }

  int? _statusIdFromText(String? statusText) {
    if (statusText == null) return null;
    return _statusNameToId[statusText];
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isTablet = MediaQuery.of(context).size.width > 800;
    const Color tealGreen = Color(0xFF4db1b3);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 600;
          final double actionHeight = isTablet ? 54 : 48;
          return RefreshIndicator(
            onRefresh: () async {
              await _load();
              if (mounted) {
                _showToast(
                  'Data refreshed',
                  type: ToastType.success,
                  icon: Icons.refresh,
                );
              }
            },
            color: tealGreen,
            child: Stack(
              children: [
                ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  shrinkWrap: false,
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 12 : 16, 
                    8, 
                    isMobile ? 12 : 16, 
                    16
                  ),
                  children: [
                    // Header with filter icon (same pattern as DCR Manager Review)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedItems.isNotEmpty 
                                    ? '${_selectedItems.length} Expense(s) selected'
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
                                _selectedItems.isNotEmpty 
                                    ? 'Review selected expenses'
                                    : 'Select expenses to review',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 14 : 13,
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
                    SizedBox(height: isTablet ? 20 : 16),
                    // Action Buttons Row - Select All and Filter Count in one row (50% 50%)
                    // Hide entire row when items are selected
                    if (_selectedItems.isEmpty)
                      Row(
                        children: [
                          // Select All Button - 50% width
                          if (_expenseItems.isNotEmpty)
                            Expanded(
                              child: SizedBox(
                                height: actionHeight,
                                child: FilledButton.icon(
                                  onPressed: _selectAllExpenses,
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
                          if (_expenseItems.isNotEmpty)
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
                                        _getFilterBadgeText(),
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
                    // Only add spacing if the action buttons row is visible
                    if (_selectedItems.isEmpty)
                      const SizedBox(height: 12),

          // Selection summary and actions - similar to DCR manager review
          if (_selectedItems.isNotEmpty) ...[
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
                          '${_selectedItems.length} Expense(s) selected',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4db1b3),
                            fontSize: isMobile ? 13 : 14,
                          ),
                        ),
                      ),
                      // Clear Selection text and X button on right
                      InkWell(
                        onTap: () {
                          setState(() => _selectedItems.clear());
                          _showToast(
                            'Selection cleared',
                            type: ToastType.success,
                            icon: Icons.clear,
                          );
                        },
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

          // Expense list
          if (_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFF4db1b3), // Teal green color
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading Expenses...',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else if (_expenseItems.isEmpty)
            _buildManagerReviewEmptyState()
          else ...[
            for (final e in _groupedByCluster()) ...[  
              _SectionCard(
                title: '${e.cluster} • ${e.items.length} items',
                actionText: '${e.items.length} expenses',
                child: Column(
                  children: [
                    for (final item in e.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ManagerReviewExpenseItemCard(
                          item: item,
                          isSelected: _selectedItems.contains(item.id),
                          isEnabled: !_isApproved(item), // Disable selection for approved expenses
                          onSelectionChanged: (selected) {
                            // Only allow selection if item is not approved
                            if (!_isApproved(item)) {
                              setState(() {
                                if (selected) {
                                  _selectedItems.add(item.id);
                                } else {
                                  _selectedItems.remove(item.id);
                                }
                              });
                            }
                          },
                          onViewDetails: () => _showExpenseDetails(item),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
          const SizedBox(height: 16),
        ],
                ),
                // Filter Modal overlay
                if (_showFilterModal) _buildFilterModal(isMobile, isTablet, tealGreen),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _selectedItems.isNotEmpty
          ? _BottomActionBar(
              selectedCount: _selectedItems.length,
              onApprove: () => _showBulkActionDialog('Approve'),
              onSendBack: () => _showBulkActionDialog('Send Back'),
              onClear: () {
                setState(() => _selectedItems.clear());
                _showToast(
                  'Selection cleared',
                  type: ToastType.success,
                  icon: Icons.clear,
                );
              },
              canApprove: _canApproveSelected(),
              canSendBack: _canSendBackSelected(),
            )
          : null,
    );
  }

  /// Helper methods to determine button states based on selected items' statuses
  /// Workflow rules:
  /// 1. Only "Submitted" Expenses can be approved, sent back, or rejected
  /// 2. "Draft" Expenses should NOT be allowed to be approved, sent back, or rejected
  /// 3. Approved Expenses cannot be approved, sent back, or rejected again
  
  bool _canApproveSelected() {
    if (_selectedItems.isEmpty) return false;
    
    final selectedItems = _expenseItems
        .where((item) => _selectedItems.contains(item.id))
        .toList();
    
    if (selectedItems.isEmpty) return false;
    
    // Check if all items are approved
    final allApproved = selectedItems.every((item) => item.status == ExpenseStatus.approved);
    
    // Check if any selected expense has dcrStatusId == 4 (Sent Back - should not be approved)
    final hasStatusId4 = selectedItems.any((item) {
      final dcrStatusId = _expenseIdToDcrStatusId[item.id];
      return dcrStatusId == 4;
    });
    
    // Only allow approval if:
    // 1. Not all are approved
    // 2. No item has dcrStatusId == 4
    // 3. ALL selected items have "Submitted" status
    final allSubmitted = selectedItems.every((item) => item.status == ExpenseStatus.submitted);
    
    return !allApproved && !hasStatusId4 && allSubmitted;
  }
  
  bool _canSendBackSelected() {
    if (_selectedItems.isEmpty) return false;
    
    final selectedItems = _expenseItems
        .where((item) => _selectedItems.contains(item.id))
        .toList();
    
    if (selectedItems.isEmpty) return false;
    
    // Check if all items are approved
    final allApproved = selectedItems.every((item) => item.status == ExpenseStatus.approved);
    
    // Check if all items are sent back
    final allSentBack = selectedItems.every((item) => item.status == ExpenseStatus.sentBack);
    
    // Only allow send back if:
    // 1. Not all are approved
    // 2. Not all are sent back
    // 3. ALL selected items have "Submitted" status
    final allSubmitted = selectedItems.every((item) => item.status == ExpenseStatus.submitted);
    
    return !allApproved && !allSentBack && allSubmitted;
  }
  
  bool _canRejectSelected() {
    if (_selectedItems.isEmpty) return false;
    
    final selectedItems = _expenseItems
        .where((item) => _selectedItems.contains(item.id))
        .toList();
    
    if (selectedItems.isEmpty) return false;
    
    // Check if any item is approved
    final hasApproved = selectedItems.any((item) => item.status == ExpenseStatus.approved);
    
    // Check if any item is sent back
    final hasSentBack = selectedItems.any((item) => item.status == ExpenseStatus.sentBack);
    
    // Check if any item is rejected
    final hasRejected = selectedItems.any((item) => item.status == ExpenseStatus.rejected);
    
    // Only allow reject if:
    // 1. No item is approved
    // 2. No item is sent back
    // 3. No item is rejected
    // 4. ALL selected items have "Submitted" status
    final allSubmitted = selectedItems.every((item) => item.status == ExpenseStatus.submitted);
    
    return !hasApproved && !hasSentBack && !hasRejected && allSubmitted;
  }

  /// Select all visible expenses
  void _selectAllExpenses() {
    setState(() {
      _selectedItems.clear();
      
      for (final item in _expenseItems) {
        // Only select items that are not approved
        if (!_isApproved(item)) {
          _selectedItems.add(item.id);
        }
      }
    });
    
    _showToast(
      'Selected ${_selectedItems.length} Expense(s)',
      type: ToastType.success,
      icon: Icons.check_circle,
    );
  }

  Future<void> _clearAllFilters() async {
    // Get logged-in employee (manager) to set as default
    final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final int? managerId = userStore?.userDetail?.employeeId;
    
    // Find the manager's employee name from the options
    String? managerEmployeeName;
    if (managerId != null && _employeeNameToId.isNotEmpty) {
      _employeeNameToId.forEach((name, id) {
        if (id == managerId) {
          managerEmployeeName = name;
        }
      });
    }
    
    setState(() {
      _status = null;
      _selectedEmployee = managerEmployeeName; // Set to logged-in employee (manager) instead of null
      final now = DateTime.now();
      _date = DateTime(now.year, now.month, 1); // Reset to first day of current month
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
    final DateTime now = DateTime.now();
    final bool isDateFiltered = !(_date.year == now.year && _date.month == now.month);
    return _status != null || _selectedEmployee != null || isDateFiltered;
  }

  // Get filter badge text showing filtered records count
  String _getFilterBadgeText() {
    if (_expenseItems.isEmpty) {
      return 'No records';
    }
    
    // Always show filtered records count
    final count = _expenseItems.length;
    return count == 1 ? '$count record' : '$count records';
  }

  /// Build empty state widget for expense manager review
  Widget _buildManagerReviewEmptyState() {
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
              Icons.account_balance_wallet_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          
          // Title
          Text(
            'No Expense Data Found',
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
                : 'No expenses are available for review\nfor the selected date and filters.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 32),
          
          // Action buttons
          LayoutBuilder(builder: (context, constraints) {
            final bool isVeryNarrow = constraints.maxWidth < 380;
            if (isVeryNarrow) {
              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4db1b3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _clearAllFilters,
                      icon: const Icon(Icons.filter_alt_off, size: 18),
                      label: const Text('Clear Filters'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF4db1b3), width: 1.5),
                        foregroundColor: const Color(0xFF4db1b3),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text('Refresh'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4db1b3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearAllFilters,
                      icon: const Icon(Icons.filter_alt_off, size: 20),
                      label: const Text('Clear Filters'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF4db1b3), width: 1.5),
                        foregroundColor: const Color(0xFF4db1b3),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  // Get filter count (number of active filters)
  int _getFilterCount() {
    int count = 0;
    if (_status != null) count++;
    if (_selectedEmployee != null) count++;
    final DateTime now = DateTime.now();
    final bool isDateFiltered = !(_date.year == now.year && _date.month == now.month);
    if (isDateFiltered) count++;
    return count;
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

  // Build Filter Modal
  Widget _buildFilterModal(bool isMobile, bool isTablet, Color tealGreen) {
    // Temp selections that live for the lifetime of the modal
    String? _tempStatus = _status;
    String? _tempEmployee = _selectedEmployee;
    DateTime _tempDate = _date;

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
                              MediaQuery.of(context).viewInsets.bottom + (isMobile ? 16 : 20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                  onExpanded: () => _scrollFilterSectionIntoView(_statusFilterSectionKey),
                                ),
                                
                                const SizedBox(height: 24),
                                // Date Section
                                Text(
                                  'Date',
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 14 : 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[900],
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _EnhancedDateSelector(
                                  label: ExpenseManagerReviewScreenState._formatDate(_tempDate),
                                  isActive: !ExpenseManagerReviewScreenState._isToday(_tempDate),
                                  onTap: () async {
                                    // Show month/year picker
                                    final DateTime? picked = await _showMonthYearPicker(context, _tempDate, tealGreen);
                                    if (picked != null) {
                                      setModalState(() {
                                        // Set to first day of selected month
                                        _tempDate = DateTime(picked.year, picked.month, 1);
                                      });
                                    }
                                  },
                                ),
                                
                                const SizedBox(height: 24),
                                // Employee Section (Searchable)
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
                                
                                const SizedBox(height: 8),
                                // Capture temps for Apply
                                Builder(
                                  builder: (_) {
                                    _pendingFilterApply = () {
                                      setState(() {
                                        _status = _tempStatus;
                                        _selectedEmployee = _tempEmployee;
                                        _date = _tempDate;
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
                                await _clearAllFilters();
                                _closeFilterModal();
                              },
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: isMobile ? 14 : isTablet ? 16 : 18,
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
                                  fontSize: isMobile ? 13 : isTablet ? 14 : 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isMobile ? 12 : 16),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                _pendingFilterApply?.call();
                                _applyFiltersFromModal();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: tealGreen,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  vertical: isMobile ? 14 : isTablet ? 16 : 18,
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
                                  fontSize: isMobile ? 13 : isTablet ? 14 : 15,
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

  static String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.year}'; // Month and year only
  }

  static bool _isToday(DateTime d) {
    final DateTime now = DateTime.now();
    return now.year == d.year && now.month == d.month; // Check month only
  }

  // Show month/year picker
  Future<DateTime?> _showMonthYearPicker(BuildContext context, DateTime initialDate, Color tealGreen) async {
    int selectedYear = initialDate.year;
    int selectedMonth = initialDate.month;
    
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                          final double itemWidth = (availableWidth - (crossAxisSpacing * (crossAxisCount - 1))) / crossAxisCount;
                          final double itemHeight = isMobile ? 48 : 56;
                          
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                                    color: isSelected ? tealGreen : Colors.grey.shade300,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  backgroundColor: isSelected ? tealGreen.withOpacity(0.1) : Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 8 : 12,
                                    vertical: isMobile ? 12 : 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][index],
                                    style: GoogleFonts.inter(
                                      fontSize: isMobile ? 14 : 16,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                      color: isSelected ? tealGreen : Colors.grey[900],
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
                            Navigator.of(context).pop(DateTime(selectedYear, selectedMonth, 1));
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
                      SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 0),
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
  void _showToast(String message, {ToastType type = ToastType.info, IconData? icon}) {
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

  // Grouping methods - similar to DCR manager review
  List<_ExpenseClusterGroup> _groupedByCluster() {
    final Map<String, List<ExpenseEntry>> itemsByCluster = {};
    
    for (final item in _expenseItems) {
      final group = item.cluster.isNotEmpty ? item.cluster : 'Unassigned';
      (itemsByCluster[group] ??= []).add(item);
    }
    
    return itemsByCluster.entries
        .map((entry) => _ExpenseClusterGroup(cluster: entry.key, items: entry.value))
        .toList();
  }

  Future<void> _getManagerTeamEmployees() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
        final int? managerId = userStore?.userDetail?.employeeId;
        
        if (managerId != null) {
          final List<CommonDropdownItem> items = await commonRepo.getEmployeesReportingTo(managerId);
          final names = items.map((e) => (e.employeeName.isNotEmpty ? e.employeeName : e.text).trim()).where((s) => s.isNotEmpty).toSet();
          
          if (names.isNotEmpty && mounted) {
            setState(() {
              // Add "All Staff" option at the beginning (removed "Select All")
              _employeeOptions = ['All Staff', ...names.toList()];
              String? selectedEmployeeName;
              for (final item in items) {
                final String key = (item.employeeName.isNotEmpty ? item.employeeName : item.text).trim();
                if (key.isNotEmpty) {
                  _employeeNameToId[key] = item.id;
                  // Auto-select the manager's own employee if found
                  if (item.id == managerId) {
                    selectedEmployeeName = key;
                  }
                }
              }
              // Auto-select the manager's employee only if no employee is currently selected (first time initialization)
              if (selectedEmployeeName != null && _selectedEmployee == null) {
                _selectedEmployee = selectedEmployeeName;
                print('ExpenseManagerReviewScreen: Auto-selected employee: $selectedEmployeeName (ID: $managerId)');
              }
            });
            print('ExpenseManagerReviewScreen: Loaded ${_employeeOptions.length} team employees (including All Staff)');
          }
        }
      }
    } catch (e) {
      print('Error getting manager team employees: $e');
    }
  }

  Future<void> _getExpenseStatusList() async {
    try {
      // Use the same API as DCR to get status list with correct IDs
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        final List<CommonDropdownItem> items = await commonRepo.getDcrDetailStatusList();
        final statuses = items.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toSet();
        
        if (statuses.isNotEmpty) {
          if (mounted) {
            setState(() {
              _statusOptions = statuses.toList();
              _statusNameToId.clear();
              for (final item in items) {
                final String key = item.text.trim();
                if (key.isNotEmpty) _statusNameToId[key] = item.id;
              }
            });
          } else {
            _statusOptions = statuses.toList();
            _statusNameToId.clear();
            for (final item in items) {
              final String key = item.text.trim();
              if (key.isNotEmpty) _statusNameToId[key] = item.id;
            }
          }
          print('ExpenseManagerReviewScreen: Loaded ${_statusOptions.length} statuses for filter');
          print('ExpenseManagerReviewScreen: Status ID mapping: $_statusNameToId');
        } else {
          // Fallback to hardcoded values if API returns empty
          if (mounted) {
            setState(() {
              _statusOptions = ['Draft', 'Submitted', 'Approved', 'Rejected', 'Sent Back'];
              // Based on conversion function: 0/1=Draft, 2=SentBack, 3=Submitted, 4=SentBack, 5=Approved
              _statusNameToId = {
                'Draft': 1,
                'Submitted': 3,
                'Approved': 5,
                'Rejected': 4,
                'Sent Back': 2,
              };
            });
          } else {
            _statusOptions = ['Draft', 'Submitted', 'Approved', 'Rejected', 'Sent Back'];
            _statusNameToId = {
              'Draft': 1,
              'Submitted': 3,
              'Approved': 5,
              'Rejected': 4,
              'Sent Back': 2,
            };
          }
          print('ExpenseManagerReviewScreen: Using fallback status options');
        }
      } else {
        // Fallback if CommonRepository is not registered
        if (mounted) {
          setState(() {
            _statusOptions = ['Draft', 'Submitted', 'Approved', 'Rejected', 'Sent Back'];
            // Based on conversion function: 0/1=Draft, 2=SentBack, 3=Submitted, 4=SentBack, 5=Approved
            _statusNameToId = {
              'Draft': 1,
              'Submitted': 3,
              'Approved': 5,
              'Rejected': 4,
              'Sent Back': 2,
            };
          });
        } else {
          _statusOptions = ['Draft', 'Submitted', 'Approved', 'Rejected', 'Sent Back'];
          _statusNameToId = {
            'Draft': 1,
            'Submitted': 3,
            'Approved': 5,
            'Rejected': 4,
            'Sent Back': 2,
          };
        }
        print('ExpenseManagerReviewScreen: Using fallback status options (CommonRepository not registered)');
      }
    } catch (e) {
      print('Error getting expense status list: $e');
      // Fallback on error
      if (mounted) {
        setState(() {
          _statusOptions = ['Draft', 'Submitted', 'Approved', 'Rejected', 'Sent Back'];
          // Based on conversion function: 0/1=Draft, 2=SentBack, 3=Submitted, 4=SentBack, 5=Approved
          _statusNameToId = {
            'Draft': 1,
            'Submitted': 3,
            'Approved': 5,
            'Rejected': 4,
            'Sent Back': 2,
          };
        });
      } else {
        _statusOptions = ['Draft', 'Submitted', 'Approved', 'Rejected', 'Sent Back'];
        _statusNameToId = {
          'Draft': 1,
          'Submitted': 3,
          'Approved': 5,
          'Rejected': 4,
          'Sent Back': 2,
        };
      }
    }
  }

  void _showExpenseDetails(ExpenseEntry item) async {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    
    // Fetch expense details from API
    ExpenseDetailResponse? expenseDetails;
    bool isLoadingDetails = true;
    
    try {
      final expenseId = int.tryParse(item.id);
      if (expenseId != null) {
        final ExpenseRepository? expenseRepo = getIt.isRegistered<ExpenseRepository>() ? getIt<ExpenseRepository>() : null;
        if (expenseRepo != null) {
          expenseDetails = await expenseRepo.getExpenseFromApi(expenseId);
          
          // Log attachment details for debugging
          if (expenseDetails != null) {
            print('ExpenseDetails loaded - ID: ${expenseDetails!.id}');
            print('Attachments count: ${expenseDetails!.attachments.length}');
            for (int i = 0; i < expenseDetails!.attachments.length; i++) {
              final att = expenseDetails!.attachments[i];
              print('Attachment $i - FileName: ${att.fileName}, FilePath: ${att.filePath}, FileType: ${att.fileType}');
            }
          } else {
            print('ExpenseDetails is null for expense ID: $expenseId');
          }
        }
      }
    } catch (e) {
      print('Error fetching expense details: $e');
    } finally {
      isLoadingDetails = false;
    }
    
    if (!mounted) return;
    
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header (mint like tour plan)
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
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
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
                                  'Expense Details',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[900],
                                    fontSize: isTablet ? 16 : 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _getStatusChipForExpense(item),
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
                child: isLoadingDetails
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          20,
                          20,
                          MediaQuery.of(context).padding.bottom + 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailRow('Transaction Type', 'Expense'),
                            const SizedBox(height: 12),
                            _DetailRow('Date', ExpenseManagerReviewScreenState._formatDate(item.date)),
                            const SizedBox(height: 12),
                            _DetailRow('Employee', expenseDetails?.employeeName ?? item.employeeName),
                            const SizedBox(height: 12),
                            _DetailRow('Cluster', expenseDetails?.clusterNames ?? item.cluster),
                            const SizedBox(height: 12),
                            _DetailRow('Status', _getStatusText(item.status)),
                            const SizedBox(height: 20),
                            Divider(height: 1, color: Colors.grey.shade300),
                            const SizedBox(height: 20),
                            _DetailRow('Expense Head', item.expenseHead),
                            const SizedBox(height: 12),
                            _DetailRow('Amount', 'Rs. ${(expenseDetails?.expenseAmount ?? item.amount).toStringAsFixed(2)}'),
                            if ((expenseDetails?.remarks ?? item.remarks).isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Divider(height: 1, color: Colors.grey.shade300),
                              const SizedBox(height: 20),
                              _DetailRow('Remarks', expenseDetails?.remarks ?? item.remarks, isMultiline: true),
                            ],
                            // Attachments section
                            if (expenseDetails != null && expenseDetails!.attachments.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Divider(height: 1, color: Colors.grey.shade300),
                              const SizedBox(height: 20),
                              Text(
                                'Attachments',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: isTablet ? 15 : 14,
                                  color: Colors.grey[900],
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...expenseDetails!.attachments.map((attachment) => _buildAttachmentCard(attachment, isTablet)),
                            ],
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

  Widget _buildAttachmentCard(ExpenseAttachment attachment, bool isTablet) {
    // Use FileDownload API with URL-encoded path and name parameters
    // IMPORTANT: Use the EXACT FilePath and FileName from the backend response
    // Do NOT modify or rebuild the path - use it exactly as returned
    // Format: /api/FileDownload/Download?path=<urlEncodedFilePath>&name=<urlEncodedFileName>
    
    // Get exact values from backend response
    final exactFilePath = attachment.filePath; // Use exactly as returned by backend
    final exactFileName = attachment.fileName; // Use exactly as returned by backend
    
    // Log for debugging
    print('Attachment Download - FilePath: $exactFilePath, FileName: $exactFileName');
    
    final fileUrl = Endpoints.fileDownload(exactFilePath, exactFileName);
    
    print('Generated Download URL: $fileUrl');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF4db1b3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getFileIcon(attachment.fileType),
              color: const Color(0xFF4db1b3),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 13 : 12,
                    color: Colors.grey[900],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (attachment.fileType.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    attachment.fileType.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 11 : 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => _openAttachment(fileUrl),
            icon: const Icon(Icons.open_in_new, size: 20),
            color: const Color(0xFF4db1b3),
            tooltip: 'View attachment',
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    final type = fileType.toLowerCase();
    if (type.contains('image') || type.contains('jpg') || type.contains('jpeg') || type.contains('png') || type.contains('gif')) {
      return Icons.image;
    } else if (type.contains('pdf')) {
      return Icons.picture_as_pdf;
    } else if (type.contains('doc') || type.contains('word')) {
      return Icons.description;
    } else {
      return Icons.attach_file;
    }
  }

  void _openAttachment(String url) async {
    try {
      print('Opening attachment URL: $url');
      
      final Uri uri = Uri.parse(url);
      
      // Verify URL structure
      print('Parsed URI - Scheme: ${uri.scheme}, Host: ${uri.host}, Path: ${uri.path}, Query: ${uri.query}');
      
      // Try to launch URL directly
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // Opens in external browser/app
      );
      
      if (!launched) {
        print('Failed to launch URL');
        _showToast('Could not open attachment. Please check the URL.', type: ToastType.error);
      } else {
        print('URL launched successfully');
      }
    } catch (e) {
      print('Error opening attachment: $e');
      _showToast('Failed to open attachment: ${e.toString()}', type: ToastType.error);
    }
  }

  _StatusChip _getStatusChipForExpense(ExpenseEntry item) {
    switch (item.status) {
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


  String _getStatusText(ExpenseStatus status) {
    switch (status) {
      case ExpenseStatus.draft: return 'Draft';
      case ExpenseStatus.submitted: return 'Submitted';
      case ExpenseStatus.approved: return 'Approved';
      case ExpenseStatus.rejected: return 'Rejected';
      case ExpenseStatus.sentBack: return 'Sent Back';
    }
  }

  Future<void> _showBulkActionDialog(String action) async {
    if (_selectedItems.isEmpty) {
      _showToast(
        'Please select at least one expense',
        type: ToastType.warning,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    final String? comment = await ManagerCommentDialog.show(
      context,
      action: action,
      entityLabel: 'Expenses',
      description: 'Please provide a comment for $action action:',
      hintText: 'Enter your comment...',
      requireComment: true,
    );

    if (comment == null || comment.trim().isEmpty) {
      // _showToast(
      //   'Comment is required for this action',
      //   type: ToastType.error,
      //   icon: Icons.error_outline,
      // );
      return;
    }

    _performBulkAction(action, comment.trim());
  }

  Future<void> _performBulkAction(String action, String comments) async {
    if (!mounted) return;
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF4db1b3), // Teal green color
            ),
            const SizedBox(width: 16),
            const Text('Processing...'),
          ],
        ),
      ),
    );

    try {
      final ExpenseRepository? expenseRepo = getIt.isRegistered<ExpenseRepository>() ? getIt<ExpenseRepository>() : null;
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
      final int? userId = userStore?.userDetail?.employeeId;
      
      if (expenseRepo == null || userId == null) {
        throw Exception('Unable to access expense repository or user information');
      }

      // Get selected expense IDs
      final List<int> selectedExpenseIds = _selectedItems
          .map((id) => int.tryParse(id))
          .where((id) => id != null)
          .cast<int>()
          .toList();

      if (selectedExpenseIds.isEmpty) {
        throw Exception('No valid expense IDs selected');
      }

      // Create expense action details
      final List<ExpenseActionDetail> expenseActions = selectedExpenseIds
          .map((id) => ExpenseActionDetail(id: id))
          .toList();

      bool success = false;
      String message = '';

      if (action == 'Approve') {
        final request = ExpenseBulkApproveRequest(
          id: userId, // Using manager's ID as the ID
          comments: comments,
          userId: userId,
          action: 5, // Action 5 for approve
          expenseAction: expenseActions,
        );
        
        final response = await expenseRepo.bulkApproveExpenses(request);
        success = response.success;
        message = response.message;
        print('Bulk Approve Response - Success: $success, Message: $message');
      } else if (action == 'Send Back' || action == 'Reject') {
        final request = ExpenseBulkRejectRequest(
          id: userId, // Using manager's ID as the ID
          comments: comments,
          userId: userId,
          action: 4, // Action 4 for reject/send back
          expenseAction: expenseActions,
        );
        
        final response = await expenseRepo.bulkRejectExpenses(request);
        success = response.success;
        message = response.message;
        print('Bulk Reject Response - Success: $success, Message: $message');
      }

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (success) {
        // Clear selections and reload data
        setState(() {
          _selectedItems.clear();
        });
        await _load();
        
        if (mounted) {
          // Ensure any remaining dialogs (like comment dialog) are closed
          // Try to pop from root navigator if there's still a dialog open
          final rootNavigator = Navigator.of(context, rootNavigator: true);
          if (rootNavigator.canPop()) {
            rootNavigator.pop();
          }
          
          _showToast(
            'Successfully ${action.toLowerCase()}ed ${selectedExpenseIds.length} expense(s)',
            type: ToastType.success,
            icon: Icons.check_circle,
          );
        }
      } else {
        if (mounted) {
          _showToast(
            'Failed to ${action.toLowerCase()} expenses: $message',
            type: ToastType.error,
            icon: Icons.error_outline,
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        // Ensure any remaining dialogs are closed
        final rootNavigator = Navigator.of(context, rootNavigator: true);
        if (rootNavigator.canPop()) {
          rootNavigator.pop();
        }
      }
      
      if (mounted) {
        _showToast(
          'Error: ${e.toString()}',
          type: ToastType.error,
          icon: Icons.error_outline,
        );
      }
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

// Reuse existing UI components
class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

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
              Flexible(
                child: Text(
                  label, 
                  style: Theme.of(context).textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 16),
            ],
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
              const Icon(Icons.calendar_today, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label, 
                  style: Theme.of(context).textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerReviewExpenseItemCard extends StatelessWidget {
  const _ManagerReviewExpenseItemCard({
    required this.item,
    required this.isSelected,
    required this.onSelectionChanged,
    required this.onViewDetails,
    this.isEnabled = true, // Default to enabled
  });
  
  final ExpenseEntry item;
  final bool isSelected;
  final ValueChanged<bool> onSelectionChanged;
  final VoidCallback onViewDetails;
  final bool isEnabled; // Whether the item can be selected

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallMobile = screenWidth < 360;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600;
    
    final TextStyle label = GoogleFonts.inter(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: isMobile ? 13 : 14);
    final TextStyle value = GoogleFonts.inter(color: const Color(0xFF1F2937), fontWeight: FontWeight.w600, fontSize: isMobile ? 14 : 15);
    
    final String headerTitle = item.expenseHead.isNotEmpty ? item.expenseHead : 'Expense';
    
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.6, // Reduce opacity for approved/disabled items
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF4db1b3) : Colors.black.withOpacity(.06),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          padding: EdgeInsets.all(isSmallMobile ? 10 : (isMobile ? 12 : 14)),
          margin: EdgeInsets.only(bottom: isMobile ? 8 : 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Checkbox + Icon + Title + View
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: isEnabled ? (value) => onSelectionChanged(value ?? false) : null,
                    activeColor: const Color(0xFF4db1b3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: isTablet ? 40 : 36,
                    height: isTablet ? 40 : 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF7F7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Color(0xFF4db1b3),
                      size: 18,
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
                      item.employeeName.isNotEmpty ? item.employeeName : 'Unknown',
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
              // Status and amount row
              Row(
                children: [
                  _getStatusChipForExpense(item),
                  const Spacer(),
                  Text(
                    'Rs. ${item.amount.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 12 : 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
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

  _StatusChip _getStatusChipForExpense(ExpenseEntry item) {
    switch (item.status) {
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

  String _formatItemDate(ExpenseEntry item) {
    try {
      final DateTime date = item.date;
      return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    } catch (e) {
      return item.date.toIso8601String().split('T').first;
    }
  }
}

// Helper widgets for expense manager review
class _ExpenseClusterGroup {
  _ExpenseClusterGroup({required this.cluster, required this.items});
  final String cluster; 
  final List<ExpenseEntry> items;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.actionText, required this.child});
  final String title;
  final String actionText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const statusColor = Color(0xFF4db1b3); // Use teal for expenses
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 12, offset: const Offset(0, 4)),
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
                    style: GoogleFonts.inter(
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
                        border: Border.all(color: statusColor.withOpacity(.25), width: 2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      actionText,
                      style: GoogleFonts.inter(
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

class _StatusChip extends StatelessWidget {
  const _StatusChip._(this.text, this.color);
  const _StatusChip.approved(String text) : this._(text, const Color(0xFF2DBE64));
  const _StatusChip.pending(String text) : this._(text, const Color(0xFFFFC54D));
  const _StatusChip.expense(String text) : this._(text, const Color(0xFF00C4DE));
  const _StatusChip.rejected(String text) : this._(text, const Color(0xFFE53935));

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 9, vertical: isMobile ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isMobile ? 4 : 5,
            height: isMobile ? 4 : 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: isMobile ? 4 : 5),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 10 : 11,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.isMultiline = false});
  
  final String label;
  final String value;
  final bool isMultiline;

  @override
  Widget build(BuildContext context) {
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
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});
  final IconData icon; 
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

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
    const Color tealGreen = Color(0xFF4db1b3);
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
                                color: tealGreen,
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
                                '$selectedCount Expense(s) selected',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: tealGreen,
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
                                color: tealGreen,
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
                                '$selectedCount Expense(s) selected',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: tealGreen,
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

// Enhanced UI Components for Expense Manager Review Filters
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
    const Color teal = Color(0xFF4db1b3);
    final Color backgroundColor = isActive ? teal.withOpacity(0.1) : Colors.white;
    final Color iconColor = isActive ? teal : theme.colorScheme.primary;
    final Color textColor = isActive ? teal : Colors.grey.shade700;
    final Color borderColor = isActive ? teal.withOpacity(0.3) : Colors.grey.shade200;
    
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      elevation: isActive ? 3 : 2,
      shadowColor: isActive ? teal.withOpacity(0.2) : Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: 12,
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
    this.isTablet = false,
  });
  final VoidCallback onPressed;
  final bool isActive;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const Color teal = Color(0xFF4db1b3);
    final Color backgroundColor = isActive ? teal.withOpacity(0.08) : Colors.grey.shade100;
    final Color iconColor = isActive ? teal : Colors.grey.shade600;
    final Color textColor = isActive ? teal : Colors.grey.shade600;
    
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isActive ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 14 : 12,
            vertical: isTablet ? 10 : 8,
          ),
          constraints: BoxConstraints(minHeight: isTablet ? 44 : 40),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isActive ? Border.all(color: teal.withOpacity(0.3)) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.filter_alt_off,
                size: isTablet ? 16 : 14,
                color: iconColor,
              ),
              SizedBox(width: isTablet ? 6 : 4),
              Text(
                'Clear',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColor,
                  fontSize: isTablet ? 14 : 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Searchable Filter Dropdown (same as DCR Manager Review)
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
  State<_SearchableFilterDropdown> createState() => _SearchableFilterDropdownState();
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
      // Filter options including special options like "All Staff" and "Select All"
      _filteredOptions = widget.options.where((o) => o.toLowerCase().contains(query)).toList();
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
    const Color primary = Color(0xFF4db1b3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(widget.icon, size: widget.isTablet ? 17 : 15, color: primary),
            SizedBox(width: widget.isTablet ? 10 : 8),
            Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: widget.isTablet ? 15 : 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey[900],
              ),
            ),
          ],
        ),
        SizedBox(height: widget.isTablet ? 13 : 11),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: EdgeInsets.all(widget.isTablet ? 14 : 12),
              decoration: BoxDecoration(
                color: widget.selectedValue != null ? primary.withOpacity(0.1) : Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.selectedValue != null ? primary.withOpacity(0.3) : Colors.grey[200]!,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.selectedValue ?? 'Select ${widget.title}',
                      style: GoogleFonts.inter(
                        fontSize: widget.isTablet ? 13 : 12,
                        fontWeight: widget.selectedValue != null ? FontWeight.w600 : FontWeight.w500,
                        color: widget.selectedValue != null ? primary : Colors.grey[600],
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
                            child: Icon(Icons.close_rounded, size: 16, color: primary),
                          ),
                        ),
                      ),
                    ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: widget.isTablet ? 20 : 18,
                    color: primary,
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
              border: Border.all(color: primary.withOpacity(0.2), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            constraints: BoxConstraints(maxHeight: widget.isTablet ? 400 : 350),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search field
                Padding(
                  padding: EdgeInsets.all(widget.isTablet ? 11 : 9),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, child) {
                      return TextField(
                        controller: _searchController,
                        autofocus: false,
                        style: GoogleFonts.inter(
                          fontSize: widget.isTablet ? 13 : 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[900],
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search ${widget.title.toLowerCase()}...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: widget.isTablet ? 13 : 12,
                            color: Colors.grey[400],
                          ),
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[500], size: widget.isTablet ? 19 : 17),
                          suffixIcon: value.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear_rounded, color: Colors.grey[500], size: widget.isTablet ? 17 : 15),
                                  onPressed: () => setState(() => _searchController.clear()),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: primary, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: widget.isTablet ? 13 : 11,
                            vertical: widget.isTablet ? 11 : 9,
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
                          padding: EdgeInsets.all(widget.isTablet ? 22 : 18),
                          child: Text(
                            'No results found',
                            style: GoogleFonts.inter(
                              fontSize: widget.isTablet ? 12 : 11,
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
                                    color: isSelected ? primary.withOpacity(0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected ? Border.all(color: primary.withOpacity(0.3), width: 1) : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: widget.isTablet ? 17 : 15,
                                        height: widget.isTablet ? 17 : 15,
                                        decoration: BoxDecoration(
                                          color: isSelected ? primary : Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: isSelected ? primary : Colors.grey[400]!, width: 2),
                                        ),
                                        child: isSelected ? const Icon(Icons.check_rounded, size: 11, color: Colors.white) : null,
                                      ),
                                      SizedBox(width: widget.isTablet ? 12 : 10),
                                      Expanded(
                                        child: Text(
                                          option,
                                          style: GoogleFonts.inter(
                                            fontSize: widget.isTablet ? 13 : 12,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                            color: isSelected ? primary : Colors.grey[700],
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
    // Use app teal theme for consistency with DCR Manager Review design
    const Color primary = Color(0xFF4db1b3);
    final Color backgroundColor = isActive ? primary.withOpacity(0.10) : Colors.grey.shade50;
    final Color iconColor = isActive ? primary : Colors.grey.shade600;
    final Color textColor = isActive ? primary : Colors.grey.shade700;
    final Color borderColor = isActive ? primary.withOpacity(0.30) : Colors.grey.shade200;
    
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      elevation: isActive ? 3 : 2,
      shadowColor: isActive ? primary.withOpacity(0.2) : Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          constraints: const BoxConstraints(minWidth: 200),
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
