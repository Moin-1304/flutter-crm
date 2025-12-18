import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:boilerplate/domain/repository/dcr/dcr_repository.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/entity/dcr/dcr.dart';
import 'package:boilerplate/domain/entity/dcr/dcr_api_models.dart';
import 'package:boilerplate/domain/entity/dcr/unified_dcr_item.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';
import 'package:boilerplate/presentation/crm/widgets/manager_comment_dialog.dart';

const String kFilterClearToken = '__CLEAR__';

/// DCR Manager Review screen for managers to review and approve/reject DCRs
class DcrManagerReviewScreen extends StatefulWidget {
  const DcrManagerReviewScreen({super.key});

  @override
  DcrManagerReviewScreenState createState() => DcrManagerReviewScreenState();
}

// Expose state for parent to call reload
class DcrManagerReviewScreenState extends State<DcrManagerReviewScreen> with SingleTickerProviderStateMixin {
  DateTime _date = DateTime.now();
  String? _selectedEmployee;
  String? _status;
  List<UnifiedDcrItem> _unifiedItems = const [];
  final Set<String> _selectedItems = <String>{};
  bool _isLoading = false;
  
  // Filter modal state (same UX as My DCR)
  bool _showFilterModal = false;
  late AnimationController _filterModalController;
  late Animation<double> _filterModalAnimation;
  final ScrollController _filterScrollController = ScrollController();
  final GlobalKey _statusFilterSectionKey = GlobalKey();
  final GlobalKey _employeeFilterSectionKey = GlobalKey();
  // Temp apply hook for modal (commits temp selections before Apply Filters)
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
  
  // Employee options for manager's team
  List<String> _employeeOptions = [];
  Map<String, int> _employeeNameToId = {};
  
  // Status options
  List<String> _statusOptions = [];
  Map<String, int> _statusNameToId = {};

  @override
  void initState() {
    super.initState();
    // Initialize filter modal animation (same as My DCR)
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
    await _getDcrDetailStatusList();
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
      // Get employee ID from UserDetailStore
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
      final int? managerId = userStore?.userDetail?.employeeId;
      
      if (managerId == null) {
        print('Error: Manager ID not available. Please ensure user is logged in.');
        if (!mounted) return;
        setState(() {
          _unifiedItems = [];
          _isLoading = false;
        });
        return;
      }

      final DateTime start = DateTime(_date.year, _date.month, _date.day);
      final DateTime end = start;
      final DcrRepository? dcrRepo = getIt.isRegistered<DcrRepository>() ? getIt<DcrRepository>() : null;

      if (dcrRepo == null) {
        print('Error: DCR Repository not registered');
        if (!mounted) return;
        setState(() {
          _unifiedItems = [];
          _isLoading = false;
        });
        return;
      }

      // Use selected employee if provided, else get all team DCRs
      final int? selectedEmployeeId = _selectedEmployeeId();
      final int? selectedStatusId = _statusIdFromText(_status);
      
      List<DcrApiItem> apiItems = [];
      
      if (selectedEmployeeId != null) {
        // Load DCRs for specific employee
        apiItems = await dcrRepo.getDcrListUnified(
          start: start,
          end: end,
          employeeId: selectedEmployeeId.toString(),
          statusId: selectedStatusId,
          transactionType: "DCR", // Filter for DCR items only
        );
      } else {
        // Load DCRs for all team members
        // First get the manager's own DCRs
        apiItems = await dcrRepo.getDcrListUnified(
          start: start,
          end: end,
          employeeId: managerId.toString(),
          statusId: selectedStatusId,
          transactionType: "DCR", // Filter for DCR items only
        );
        
        // Then get DCRs for each team member
        if (_employeeOptions.isNotEmpty) {
          for (final employeeName in _employeeOptions) {
            final int? employeeId = _employeeNameToId[employeeName];
            if (employeeId != null && employeeId != managerId) {
              try {
                final List<DcrApiItem> teamMemberDcrs = await dcrRepo.getDcrListUnified(
                  start: start,
                  end: end,
                  employeeId: employeeId.toString(),
                  statusId: selectedStatusId,
                  transactionType: "DCR", // Filter for DCR items only
                );
                apiItems.addAll(teamMemberDcrs);
              } catch (e) {
                print('Error loading DCRs for employee $employeeName (ID: $employeeId): $e');
              }
            }
          }
        }
      }
      
      // Filter for DCR items only (exclude Expense items) - client-side filter as API may return mixed results
      final List<DcrApiItem> dcrApiItems = apiItems
          .where((item) => item.transactionType == "DCR")
          .toList();
      
      // Convert API items to unified items
      // Show ALL DCRs (Approved, Pending, Submitted, etc.) regardless of status filter
      final List<UnifiedDcrItem> unifiedItems = dcrApiItems
          .map<UnifiedDcrItem>((item) => UnifiedDcrItem.fromDcrApiItem(item))
          .toList();
      
      print('DcrManagerReviewScreen: Loaded ${apiItems.length} API items (${dcrApiItems.length} DCR items), ${unifiedItems.length} unified items after reviewable filter');
      print('DcrManagerReviewScreen: Status filter: $_status, TransactionType: DCR');
      
      if (!mounted) return;
      
      setState(() {
        _unifiedItems = unifiedItems;
        _selectedItems.clear(); // Clear selections when data changes
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading DCR data for manager review: $e');
      if (!mounted) return;
      setState(() {
        _unifiedItems = [];
        _isLoading = false;
      });
    }
  }

  bool _isReviewableStatus(UnifiedDcrItem item) {
    final statusText = item.statusText.toLowerCase();
    return statusText.contains('submitted') || 
           statusText.contains('sent back') ||
           statusText.contains('pending');
  }

  /// Check if a DCR item is approved (cannot be selected for review)
  bool _isApproved(UnifiedDcrItem item) {
    final statusText = item.statusText.toLowerCase();
    return statusText.contains('approved');
  }

  /// Build empty state widget for manager review when no DCRs are available
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
              Icons.assignment_turned_in_outlined,
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
                : 'No Daily Call Reports are available for review\nfor the selected date and filters.',
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
                      onPressed: () async {
                        await _load();
                        if (mounted) {
                          _showToast(
                            'Data refreshed',
                            type: ToastType.success,
                            icon: Icons.refresh,
                          );
                        }
                      },
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
                      onPressed: () async {
                        await _load();
                        if (mounted) {
                          _showToast(
                            'Data refreshed',
                            type: ToastType.success,
                            icon: Icons.refresh,
                          );
                        }
                      },
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
            color: const Color(0xFF4db1b3),
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
                    // Header with filter icon (same pattern as My DCR)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedItems.isNotEmpty 
                                    ? '${_selectedItems.length} DCR(s) selected'
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
                                    ? 'Review selected DCRs'
                                    : 'Select DCRs to review',
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
                    if (_selectedItems.isEmpty && _unifiedItems.isNotEmpty)
                      Row(
                        children: [
                          // Select All Button - 50% width
                          Expanded(
                            child: SizedBox(
                              height: actionHeight,
                              child: FilledButton.icon(
                                onPressed: _selectAllDcrs,
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
                    const SizedBox(height: 12),

        // Selection summary and actions - similar to tour plan manager review
        if (_selectedItems.isNotEmpty) ...[
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
                        '${_selectedItems.length} DCR(s) selected',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4db1b3),
                          fontSize: isMobile ? 13 : 14,
                        ),
                      ),
                    ),
                    // Clear Selection text and X button on right
                    InkWell(
                      onTap: () => setState(() => _selectedItems.clear()),
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

        // Cards list (grouped by cluster/city or Ad-hoc) - same as DCR list
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF4db1b3)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading DCRs...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else if (_unifiedItems.isEmpty)
          _buildManagerReviewEmptyState()
        else ...[
          for (final e in _groupedByClusterOrAdhoc()) ...[  
            _SectionCard(
              title: '${e.cluster} • ${e.items.length} items',
              actionText: _groupInRangeText(e),
              child: Column(
                children: [
                  for (final item in e.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ManagerReviewUnifiedItemCard(
                        item: item,
                        isSelected: _selectedItems.contains(item.id.toString()),
                        isEnabled: !_isApproved(item), // Disable selection for approved DCRs
                        onSelectionChanged: (selected) {
                          // Only allow selection if item is not approved
                          if (!_isApproved(item)) {
                            setState(() {
                              if (selected) {
                                _selectedItems.add(item.id.toString());
                              } else {
                                _selectedItems.remove(item.id.toString());
                              }
                            });
                          }
                        },
                        onViewDetails: () => _showDcrDetails(item),
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
  /// 1. Only "Submitted" DCRs can be approved or sent back
  /// 2. "DCR Pending" (draft/pending status) should NOT be allowed to be approved or sent back
  /// 3. Approved DCRs cannot be approved or sent back again
  
  /// Check if an item has "Submitted" status
  /// Only returns true for items with "Submitted" status, excluding "Pending", "Draft", etc.
  bool _isSubmittedStatus(UnifiedDcrItem item) {
    // Check by dcrStatusId first (3 = submitted)
    if (item.isDcr && item.dcrStatusId == 3) {
      return true;
    }
    
    // Also check statusText for "submitted" (case-insensitive)
    final statusText = item.statusText.trim().toLowerCase();
    
    // Explicitly exclude "pending" and "draft" statuses
    if (statusText.contains('pending') || statusText.contains('draft')) {
      return false;
    }
    
    // Check if statusText contains "submitted"
    if (statusText.contains('submitted')) {
      return true;
    }
    
    return false;
  }
  
  bool _canApproveSelected() {
    if (_selectedItems.isEmpty) return false;
    
    final selectedItems = _unifiedItems
        .where((item) => _selectedItems.contains(item.id.toString()))
        .toList();
    
    if (selectedItems.isEmpty) return false;
    
    // Check if all items are approved (statusText contains "approved" or dcrStatusId == 5)
    final allApproved = selectedItems.every((item) {
      if (item.isDcr && item.dcrStatusId == 5) {
        return true; // dcrStatusId 5 = approved
      }
      final statusText = item.statusText.trim().toLowerCase();
      return statusText.contains('approved');
    });
    
    // Check if any item has dcrStatusId == 4 (rejected, but treated as approved for this check)
    final hasStatusId4 = selectedItems.any((item) {
      if (item.isDcr) {
        return item.dcrStatusId == 4;
      }
      return false;
    });
    
    // Only allow approval if:
    // 1. Not all are approved
    // 2. No item has dcrStatusId == 4
    // 3. ALL selected items have "Submitted" status
    final allSubmitted = selectedItems.every((item) => _isSubmittedStatus(item));
    
    return !allApproved && !hasStatusId4 && allSubmitted;
  }
  
  bool _canSendBackSelected() {
    if (_selectedItems.isEmpty) return false;
    
    final selectedItems = _unifiedItems
        .where((item) => _selectedItems.contains(item.id.toString()))
        .toList();
    
    if (selectedItems.isEmpty) return false;
    
    // Check if all items are approved
    final allApproved = selectedItems.every((item) {
      if (item.isDcr && item.dcrStatusId == 5) {
        return true; // dcrStatusId 5 = approved
      }
      final statusText = item.statusText.trim().toLowerCase();
      return statusText.contains('approved');
    });
    
    // Check if all items are sent back
    final allSentBack = selectedItems.every((item) {
      if (item.isDcr && item.dcrStatusId == 2) {
        return true; // dcrStatusId 2 = sent back
      }
      final statusText = item.statusText.trim().toLowerCase();
      return statusText.contains('sent back') || statusText.contains('sentback');
    });
    
    // Only allow send back if:
    // 1. Not all are approved
    // 2. Not all are sent back
    // 3. ALL selected items have "Submitted" status
    final allSubmitted = selectedItems.every((item) => _isSubmittedStatus(item));
    
    return !allApproved && !allSentBack && allSubmitted;
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
      _date = DateTime.now(); // Reset date to today
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
    final DateTime today = DateTime.now();
    final bool isDateFiltered = !(_date.year == today.year && 
                                 _date.month == today.month && 
                                 _date.day == today.day);
    return _status != null || _selectedEmployee != null || isDateFiltered;
  }

  // Get filter badge text showing filtered records count
  String _getFilterBadgeText() {
    if (_unifiedItems.isEmpty) {
      return 'No records';
    }
    
    // Always show filtered records count
    final count = _unifiedItems.length;
    return count == 1 ? '$count record' : '$count records';
  }

  /// Select all visible DCRs (excluding approved ones)
  void _selectAllDcrs() {
    setState(() {
      _selectedItems.clear();
      
      for (final item in _unifiedItems) {
        // Only select items that are not approved
        if (!_isApproved(item)) {
          _selectedItems.add(item.id.toString());
        }
      }
    });
    
    _showToast(
      'Selected ${_selectedItems.length} DCR(s)',
      type: ToastType.success,
      icon: Icons.check_circle,
    );
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
              _employeeOptions = names.toList();
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
                print('DcrManagerReviewScreen: Auto-selected employee: $selectedEmployeeName (ID: $managerId)');
              }
            });
            print('DcrManagerReviewScreen: Loaded ${_employeeOptions.length} team employees');
          }
        }
      }
    } catch (e) {
      print('DcrManagerReviewScreen: Error getting team employees: $e');
    }
  }

  Future<void> _getDcrDetailStatusList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        final List<CommonDropdownItem> items = await commonRepo.getDcrDetailStatusList();
        final statuses = items.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toSet();
        
        if (statuses.isNotEmpty) {
          _statusOptions = statuses.toList();
          for (final item in items) {
            final String key = item.text.trim();
            if (key.isNotEmpty) _statusNameToId[key] = item.id;
          }
          print('DcrManagerReviewScreen: Loaded ${_statusOptions.length} statuses for filter');
        }
      }
    } catch (e) {
      print('DcrManagerReviewScreen: Error getting DCR detail status list: $e');
    }
  }

  int? _selectedEmployeeId() {
    if (_selectedEmployee == null) return null;
    return _employeeNameToId[_selectedEmployee!];
  }

  int? _statusIdFromText(String? text) => text == null ? null : _statusNameToId[text];

  void _showDcrDetails(UnifiedDcrItem item) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
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
                          child: Icon(
                            item.isDcr ? Icons.assignment_outlined : Icons.account_balance_wallet_outlined,
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
                                  item.isDcr ? 'DCR Details' : 'Expense Details',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[900],
                                    fontSize: isTablet ? 16 : 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _getStatusChipForItem(item),
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
                      _DetailRow('Transaction Type', item.transactionType),
                      const SizedBox(height: 12),
                      _DetailRow('Date', _formatDate(item.parsedDate ?? DateTime.now())),
                      const SizedBox(height: 12),
                      _DetailRow('Employee', item.employeeName),
                      const SizedBox(height: 12),
                      if (item.designation.isNotEmpty) ...[
                        _DetailRow('Designation', item.designation),
                        const SizedBox(height: 12),
                      ],
                      _DetailRow('Cluster', item.clusterDisplayName),
                      const SizedBox(height: 12),
                      _DetailRow('Status', item.statusText),
                      if (item.isDcr) ...[
                        const SizedBox(height: 20),
                        Divider(height: 1, color: Colors.grey.shade300),
                        const SizedBox(height: 20),
                        _DetailRow('Customer', item.customerName),
                        const SizedBox(height: 12),
                        _DetailRow('Purpose', item.typeOfWork),
                        const SizedBox(height: 12),
                        if (item.samplesToDistribute != null && item.samplesToDistribute!.isNotEmpty) ...[
                          _DetailRow('Samples to Distribute', item.samplesToDistribute!),
                          const SizedBox(height: 12),
                        ],
                        if (item.productsToDiscuss != null && item.productsToDiscuss!.isNotEmpty) ...[
                          _DetailRow('Products to Discuss', item.productsToDiscuss!),
                          const SizedBox(height: 12),
                        ],
                      ] else ...[
                        const SizedBox(height: 20),
                        Divider(height: 1, color: Colors.grey.shade300),
                        const SizedBox(height: 20),
                        _DetailRow('Expense Type', item.expenseType ?? 'Unknown'),
                        const SizedBox(height: 12),
                        _DetailRow('Amount', item.expenseAmount != null ? 'Rs. ${item.expenseAmount!.toStringAsFixed(2)}' : 'Unknown'),
                      ],
                      if (item.remarks.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Divider(height: 1, color: Colors.grey.shade300),
                        const SizedBox(height: 20),
                        _DetailRow('Remarks', item.remarks, isMultiline: true),
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

  Future<void> _showBulkActionDialog(String action) async {
    if (_selectedItems.isEmpty) {
      _showToast(
        'Please select at least one DCR',
        type: ToastType.warning,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    final bool requireComment = action != 'Approve';
    final String? comment = await ManagerCommentDialog.show(
      context,
      action: action,
      entityLabel: 'DCRs',
      description:
          'Please provide ${requireComment ? 'a' : 'an optional'} comment for $action action:',
      hintText: 'Enter your comment...',
      requireComment: requireComment,
    );

    if (comment == null) return;

    final trimmed = comment.trim();
    if (requireComment && trimmed.isEmpty) {
      _showToast(
        'Comment is required for this action',
        type: ToastType.error,
        icon: Icons.error_outline,
      );
      return;
    }

    _performBulkAction(action, trimmed);
  }

  Future<void> _performBulkAction(String action, String comment) async {
    if (comment.trim().isEmpty && (action == 'Send Back' || action == 'Reject')) {
      _showToast(
        'Comments are required for Send Back and Reject actions',
        type: ToastType.error,
        icon: Icons.error_outline,
      );
      return;
    }

    try {
      final DcrRepository? dcrRepo = getIt.isRegistered<DcrRepository>() ? getIt<DcrRepository>() : null;
      if (dcrRepo == null) return;

      final List<String> selectedIds = _selectedItems.toList();

      switch (action) {
        case 'Approve':
          await dcrRepo.bulkApprove(selectedIds, comment: comment);
          break;
        case 'Send Back':
          await dcrRepo.bulkSendBack(selectedIds, comment: comment);
          break;
        case 'Reject':
          await dcrRepo.bulkReject(selectedIds, comment: comment);
          break;
      }

      if (mounted) {
        _showToast(
          'Successfully ${action.toLowerCase()}ed ${selectedIds.length} DCR(s)',
          type: ToastType.success,
          icon: Icons.check_circle,
        );
        setState(() => _selectedItems.clear());
        await _load(); // Reload data
      }
    } catch (e) {
      if (mounted) {
        _showToast(
          'Error: ${e.toString()}',
          type: ToastType.error,
          icon: Icons.error_outline,
        );
      }
    }
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  static bool _isToday(DateTime d) {
    final DateTime now = DateTime.now();
    return now.year == d.year && now.month == d.month && now.day == d.day;
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

  // Grouping methods - same as DCR list screen
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
    final filtered = list.where((item) {
      // Manager review shows only DCR items
      final bool byTransactionType = item.isDcr;
      final statusChip = _getStatusChipForItem(item);
      final byStatus = _status == null || statusChip.text == _status;
      if (!byStatus && _status != null) {
        print('DcrManagerReviewScreen: Filtered out item - statusChip.text: "${statusChip.text}", _status: "$_status", item.statusText: "${item.statusText}"');
      }
      return byTransactionType && byStatus;
    }).toList();
    
    print('DcrManagerReviewScreen: _applyFilters - input: ${list.length}, output: ${filtered.length}, status filter: $_status');
    
    return filtered;
  }

  // Filter badge count (same logic as My DCR)
  int _getFilterCount() {
    int count = 0;
    if (_status != null) count++;
    if (_selectedEmployee != null) count++;
    // Count date if not today
    if (!_isToday(_date)) count++;
    return count;
  }

  _StatusChip _getStatusChipForItem(UnifiedDcrItem item) {
    final statusText = item.statusText.trim().toLowerCase();
    
    if (item.isDcr) {
      if (statusText.contains('draft')) {
        return const _StatusChip.pending('Draft');
      } else if (statusText.contains('submitted')) {
        return const _StatusChip.pending('Submitted');
      } else if (statusText.contains('approved')) {
        return const _StatusChip.approved('Approved');
      } else if (statusText.contains('rejected')) {
        return const _StatusChip.rejected('Rejected');
      } else if (statusText.contains('sent back') || statusText.contains('sentback')) {
        return const _StatusChip.pending('Sent Back');
      } else {
        // If we don't recognize the status, try to map based on dcrStatusId
        // Map based on dcrStatusId as fallback
        switch (item.dcrStatusId) {
          case 0:
          case 1:
            return const _StatusChip.pending('Draft');
          case 2:
            return const _StatusChip.pending('Sent Back');
          case 3:
            return const _StatusChip.pending('Submitted');
          case 4:
            return const _StatusChip.rejected('Rejected');
          case 5:
            return const _StatusChip.approved('Approved');
          case 6:
            return const _StatusChip.pending('Sent Back');
          default:
            return _StatusChip.pending(item.statusText.isNotEmpty ? item.statusText : 'Unknown');
        }
      }
    } else {
      if (statusText.contains('draft')) {
        return const _StatusChip.pending('Draft');
      } else if (statusText.contains('submitted')) {
        return const _StatusChip.pending('Submitted');
      } else if (statusText.contains('approved')) {
        return const _StatusChip.approved('Approved');
      } else if (statusText.contains('rejected')) {
        return const _StatusChip.rejected('Rejected');
      } else if (statusText.contains('sent back') || statusText.contains('sentback')) {
        return const _StatusChip.pending('Sent Back');
      } else if (statusText.contains('expense')) {
        return const _StatusChip.expense('Expense');
      } else {
        return _StatusChip.pending(item.statusText.isNotEmpty ? item.statusText : 'Unknown');
      }
    }
  }

  String _groupInRangeText(_ClusterGroup g) {
    final int total = g.items.length;
    final int inRange = g.items.where((item) {
      if (item.isDcr) {
        return item.customerLatitude != null && item.customerLongitude != null;
      }
      return false; // Expenses don't have location data
    }).length;
    return inRange > 0 ? 'In-range $inRange/$total' : 'Out-of-range 0/$total';
  }

  // Open/close modal hooks (same pattern as My DCR)
  void _openFilterModal() {
    setState(() {
      _showFilterModal = true;
    });
    _filterModalController.forward();
  }

  void _closeFilterModal() {
    _filterModalController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showFilterModal = false;
        });
      }
    });
  }

  void _applyFiltersFromModal() {
    _closeFilterModal();
    _load();
    _showToast(
      'Filters applied',
      type: ToastType.success,
      icon: Icons.filter_alt,
    );
  }
}

class _ClusterGroup {
  _ClusterGroup({required this.cluster, required this.items});
  final String cluster; 
  final List<UnifiedDcrItem> items;
}

// ------- Filter Modal & Searchable Dropdown (ported from My DCR) -------
extension _FilterModal on DcrManagerReviewScreenState {
  Widget _buildFilterModal(bool isMobile, bool isTablet, Color tealGreen) {
    // Temp selections that live during modal lifetime
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
                          bottom: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
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
                              child: Icon(Icons.close, size: 18, color: Colors.grey[700]),
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
                              MediaQuery.of(context).viewInsets.bottom + (isMobile ? 16 : 20),
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
                                  options: _statusOptions,
                                  onChanged: (v) => setModalState(() => _tempStatus = v),
                                  isTablet: isTablet,
                                  onExpanded: () => _scrollFilterSectionIntoView(_statusFilterSectionKey),
                                ),
                                const SizedBox(height: 24),
                                // Date
                                Text(
                                  'Date',
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 15 : 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[900],
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _EnhancedDateSelector(
                                  label: DcrManagerReviewScreenState._formatDate(_tempDate),
                                  isActive: !DcrManagerReviewScreenState._isToday(_tempDate),
                                  onTap: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: _tempDate,
                                      firstDate: DateTime(2020, 1, 1),
                                      lastDate: DateTime(2035, 12, 31),
                                      builder: (context, child) {
                                        final ThemeData base = Theme.of(context);
                                        return Theme(
                                          data: base.copyWith(
                                            colorScheme: ColorScheme.light(
                                              primary: tealGreen,
                                              onPrimary: Colors.white,
                                              onSurface: Colors.grey.shade900,
                                            ),
                                            textButtonTheme: TextButtonThemeData(
                                              style: TextButton.styleFrom(foregroundColor: tealGreen),
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setModalState(() {
                                        _tempDate = DateTime(picked.year, picked.month, picked.day);
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 24),
                                // Employee
                                _SearchableFilterDropdown(
                                  key: _employeeFilterSectionKey,
                                  title: 'Employee',
                                  icon: Icons.badge_outlined,
                                  selectedValue: _tempEmployee,
                                  options: _employeeOptions,
                                  onChanged: (v) => setModalState(() => _tempEmployee = v),
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
                    // Footer
                    Container(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
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
                                padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                _pendingFilterApply?.call();
                                _applyFiltersFromModal();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: tealGreen,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                activeColor: const Color(0xFF4db1b3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
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
}

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
            Icon(widget.icon, size: widget.isTablet ? 18 : 16, color: primary),
            SizedBox(width: widget.isTablet ? 10 : 8),
            Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: widget.isTablet ? 16 : 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey[900],
              ),
            ),
          ],
        ),
        SizedBox(height: widget.isTablet ? 14 : 12),
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
                        fontSize: widget.isTablet ? 14 : 13,
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
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[500], size: widget.isTablet ? 20 : 18),
                          suffixIcon: value.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear_rounded, color: Colors.grey[500], size: widget.isTablet ? 18 : 16),
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
                                        width: widget.isTablet ? 18 : 16,
                                        height: widget.isTablet ? 18 : 16,
                                        decoration: BoxDecoration(
                                          color: isSelected ? primary : Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: isSelected ? primary : Colors.grey[400]!, width: 2),
                                        ),
                                        child: isSelected ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
                                      ),
                                      SizedBox(width: widget.isTablet ? 12 : 10),
                                      Expanded(
                                        child: Text(
                                          option,
                                          style: GoogleFonts.inter(
                                            fontSize: widget.isTablet ? 14 : 13,
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

class _ManagerReviewUnifiedItemCard extends StatelessWidget {
  const _ManagerReviewUnifiedItemCard({
    required this.item,
    required this.isSelected,
    required this.onSelectionChanged,
    required this.onViewDetails,
    this.isEnabled = true, // Default to enabled
  });
  
  final UnifiedDcrItem item;
  final bool isSelected;
  final ValueChanged<bool> onSelectionChanged;
  final VoidCallback onViewDetails;
  final bool isEnabled; // Whether the item can be selected

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallMobile = screenWidth < 360;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600;
    
    final TextStyle label = GoogleFonts.inter(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: isMobile ? 13 : 14);
    final TextStyle value = GoogleFonts.inter(color: const Color(0xFF1F2937), fontWeight: FontWeight.w600, fontSize: isMobile ? 14 : 15);
    
    final String headerTitle = (item.displayTitle ?? '').isNotEmpty
        ? item.displayTitle!
        : (item.isExpense ? 'Expense' : 'DCR');
    
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
                SizedBox(
                  width: isTablet ? 20 : 18,
                  height: isTablet ? 20 : 18,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: isEnabled ? (value) => onSelectionChanged(value ?? false) : null,
                    activeColor: const Color(0xFF4db1b3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: isTablet ? 40 : 36,
                  height: isTablet ? 40 : 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.isExpense ? Icons.account_balance_wallet_outlined : Icons.description_outlined,
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
                // View Button - Right side (visual only, card is clickable)
                if (onViewDetails != null)
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
                    'Rs. ${item.expenseAmount!.toStringAsFixed(0)}',
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
      ),
    );
  }

  _StatusChip _getStatusChipForItem(UnifiedDcrItem item) {
    final statusText = item.statusText.trim().toLowerCase();
    
    if (item.isDcr) {
      if (statusText.contains('draft')) {
        return const _StatusChip.pending('Draft');
      } else if (statusText.contains('submitted')) {
        return const _StatusChip.pending('Submitted');
      } else if (statusText.contains('approved')) {
        return const _StatusChip.approved('Approved');
      } else if (statusText.contains('rejected')) {
        return const _StatusChip.rejected('Rejected');
      } else if (statusText.contains('sent back') || statusText.contains('sentback')) {
        return const _StatusChip.pending('Sent Back');
      } else {
        // If we don't recognize the status, try to map based on dcrStatusId
        // Map based on dcrStatusId as fallback
        switch (item.dcrStatusId) {
          case 0:
          case 1:
            return const _StatusChip.pending('Draft');
          case 2:
            return const _StatusChip.pending('Sent Back');
          case 3:
            return const _StatusChip.pending('Submitted');
          case 4:
            return const _StatusChip.rejected('Rejected');
          case 5:
            return const _StatusChip.approved('Approved');
          case 6:
            return const _StatusChip.pending('Sent Back');
          default:
            return _StatusChip.pending(item.statusText.isNotEmpty ? item.statusText : 'Unknown');
        }
      }
    } else {
      if (statusText.contains('draft')) {
        return const _StatusChip.pending('Draft');
      } else if (statusText.contains('submitted')) {
        return const _StatusChip.pending('Submitted');
      } else if (statusText.contains('approved')) {
        return const _StatusChip.approved('Approved');
      } else if (statusText.contains('rejected')) {
        return const _StatusChip.rejected('Rejected');
      } else if (statusText.contains('sent back') || statusText.contains('sentback')) {
        return const _StatusChip.pending('Sent Back');
      } else if (statusText.contains('expense')) {
        // If statusText is "Expense", use dcrStatusId to determine actual status
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
        return _StatusChip.pending(item.statusText.isNotEmpty ? item.statusText : 'Unknown');
      }
    }
  }

  bool _isInRange(UnifiedDcrItem item) {
    // For now, we'll consider items with valid coordinates as "in range"
    // In a real implementation, you would check the user's current location
    // against the customer's coordinates using geolocation
    return item.customerLatitude != null && 
           item.customerLongitude != null &&
           item.customerLatitude != 0.0 && 
           item.customerLongitude != 0.0;
  }

  String? _getDistanceText(UnifiedDcrItem item) {
    // Only show distance for DCR items with valid coordinates
    if (!item.isDcr) {
      return null;
    }
    
    if (item.customerLatitude == null || 
        item.customerLongitude == null ||
        item.customerLatitude == 0.0 || 
        item.customerLongitude == 0.0) {
      return null;
    }
    
    // For manager review, we don't have current position, so return null
    // This matches the DCR list screen behavior when location is unavailable
    return null;
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

  // Icon + key/value row to match compact list design (same as DCR list screen)
  static Widget _iconKvRow(BuildContext context, IconData icon, String label, String valueText) {
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
                                '$selectedCount DCR(s) selected',
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
                                '$selectedCount DCR(s) selected',
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

// Helper widget for floating action buttons - similar to tour plan manager review
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

// Reuse existing UI components from dcr_list_screen.dart
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

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});
  final IconData icon; 
  final String label;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 400;
    return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 10, 
            vertical: isMobile ? 4 : 6
          ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(color: Colors.black.withOpacity(.06)),
      ),
          child: Row(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Icon(icon, size: isMobile ? 12 : 14, color: Colors.black54),
              SizedBox(width: isMobile ? 4 : 6),
              Flexible(
                child: Text(
                  label, 
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: isMobile ? 11 : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      },
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.actionText, required this.child});
  final String title;
  final String actionText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isInRange = actionText.toLowerCase().contains('in-range');
    final statusColor = isInRange ? const Color(0xFF2DBE64) : const Color(0xFFE53935);
    
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

class _ProximityDot extends StatelessWidget {
  const _ProximityDot({required this.inRange});
  final bool inRange;
  @override
  Widget build(BuildContext context) {
    final Color color = inRange ? const Color(0xFF2DBE64) : const Color(0xFFFFC54D);
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

// Enhanced UI Components for DCR Manager Review Filters
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          constraints: const BoxConstraints(minHeight: 40),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: textColor,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          constraints: const BoxConstraints(minHeight: 40),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isActive ? Border.all(color: teal.withOpacity(0.3)) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.filter_alt_off,
                size: 14,
                color: iconColor,
              ),
              const SizedBox(width: 4),
              Text(
                'Clear',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced Date Selector for Manager Review
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
    const Color teal = Color(0xFF4db1b3);
    final Color backgroundColor = isActive ? teal.withOpacity(0.1) : Colors.grey.shade50;
    final Color iconColor = isActive ? teal : Colors.grey.shade600;
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(minHeight: 40),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: textColor,
                  ),
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
