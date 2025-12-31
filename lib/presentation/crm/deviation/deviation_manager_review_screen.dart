import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:boilerplate/domain/repository/deviation/deviation_repository.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/domain/entity/deviation/deviation_api_models.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';

/// Format date string from ISO 8601 format to DD-MMM-YYYY
String _formatDateString(String? dateString) {
  if (dateString == null || dateString.isEmpty) {
    return 'N/A';
  }
  
  try {
    final dateTime = DateTime.tryParse(dateString);
    if (dateTime == null) {
      return dateString; // Return original if parsing fails
    }
    
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dateTime.day.toString().padLeft(2, '0')}-${months[dateTime.month - 1]}-${dateTime.year}';
  } catch (e) {
    return dateString; // Return original if formatting fails
  }
}

class DeviationManagerReviewScreen extends StatefulWidget {
  const DeviationManagerReviewScreen({super.key});

  @override
  State<DeviationManagerReviewScreen> createState() => _DeviationManagerReviewScreenState();
}

class _DeviationManagerReviewScreenState extends State<DeviationManagerReviewScreen> with SingleTickerProviderStateMixin {
  List<DeviationApiItem> _deviations = [];
  List<DeviationApiItem> _filteredDeviations = [];
  List<String> _employeeOptions = [];
  final Map<String, int> _employeeNameToId = {};
  String? _selectedEmployee;
  String? _selectedStatus;
  List<String> _statusOptions = [];
  final Map<String, int> _statusNameToId = {};
  bool _isLoading = false;
  bool _isManager = false;
  final TextEditingController _searchController = TextEditingController();
  
  // Filter modal state
  bool _showFilterModal = false;
  AnimationController? _filterModalController;
  Animation<Offset>? _filterModalAnimation;
  VoidCallback? _pendingFilterApply;
  final ScrollController _filterScrollController = ScrollController();
  final GlobalKey _statusFilterSectionKey = GlobalKey();
  final GlobalKey _employeeFilterSectionKey = GlobalKey();

  void _scrollFilterSectionIntoView(GlobalKey key) {
    // Use multiple post-frame callbacks to ensure layout is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait for another frame to ensure layout is stable
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          final context = key.currentContext;
          if (context == null || !_filterScrollController.hasClients) return;
          final RenderObject? renderObject = context.findRenderObject();
          if (renderObject == null || !renderObject.attached) return;
          
          // Check if layout is needed
          if (renderObject.debugNeedsLayout) return;
          
          final RenderAbstractViewport? viewport = RenderAbstractViewport.of(renderObject);
          if (viewport == null) return;
          
          final double target = viewport.getOffsetToReveal(renderObject, 0.05).offset;
          final position = _filterScrollController.position;
          if (!position.hasContentDimensions) return;
          
          final double clamped = target.clamp(position.minScrollExtent, position.maxScrollExtent);
          _filterScrollController.animateTo(
            clamped,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        } catch (e) {
          // Silently handle any scroll errors to prevent layout issues
          print('Error scrolling to filter section: $e');
        }
      });
    });
  }
  
  static const Color tealGreen = Color(0xFF4db1b3);

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
    
    _checkManagerStatus();
    _loadEmployeeList();
    _loadStatusList();
    _loadDeviations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterModalController?.dispose();
    _filterScrollController.dispose();
    super.dispose();
  }

  Future<void> _checkManagerStatus() async {
    try {
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
      final userDetail = userStore?.userDetail;
      
      if (userDetail != null) {
        setState(() {
          _isManager = userDetail.roleText?.toLowerCase().contains('manager') ?? false;
        });
      }
    } catch (e) {
      print('Error checking manager status: $e');
    }
  }

  /// Load employee list from API for employee filter (same as DCR screen)
  Future<void> _loadEmployeeList({int? employeeId}) async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        // Get employeeId from user store if not provided
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
        final int? finalEmployeeId = employeeId ?? userStore?.userDetail?.employeeId;
        
        // Use same API call as DCR screen (CommandType 106 or 276 if employeeId provided)
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
            // Update even if _selectedEmployee is already set to ensure it's correct
            if (selectedEmployeeName != null) {
              _selectedEmployee = selectedEmployeeName;
              print('DeviationManagerReviewScreen: Auto-selected employee: $selectedEmployeeName (ID: $finalEmployeeId)');
            }
          });
          print('DeviationManagerReviewScreen: Loaded ${_employeeOptions.length} employees ${finalEmployeeId != null ? "for employeeId: $finalEmployeeId" : ""}');
        }
      }
    } catch (e) {
      print('DeviationManagerReviewScreen: Error getting employee list: $e');
      // Fallback to default employees
      if (mounted) {
        setState(() {
          _employeeOptions = ['All Employees', 'John Doe', 'Jane Smith', 'Mike Johnson', 'Sarah Wilson'];
        });
      }
    }
  }

  Future<void> _loadStatusList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        
        if (user != null) {
          final List<CommonDropdownItem> items = await commonRepo.getDeviationStatusList(user.sbuId);
          final statuses = items.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toSet();
          
          if (statuses.isNotEmpty && mounted) {
            setState(() {
              _statusOptions = statuses.toList();
              for (final item in items) {
                final String key = item.text.trim();
                if (key.isNotEmpty) _statusNameToId[key] = item.id;
              }
            });
            print('Status options loaded: $_statusOptions');
          }
        }
      }
    } catch (e) {
      print('Error loading status list: $e');
      if (mounted) {
        setState(() {
          _statusOptions = ['All Statuses', 'Pending', 'Approved', 'Rejected', 'Sent Back'];
        });
      }
    }
  }

  Future<void> _loadDeviations() async {
    setState(() => _isLoading = true);
    
    try {
      if (getIt.isRegistered<DeviationRepository>()) {
        final deviationRepo = getIt<DeviationRepository>();
        final sharedPrefHelper = getIt<SharedPreferenceHelper>();
        final user = await sharedPrefHelper.getUser();
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
        final int? currentEmployeeId = userStore?.userDetail?.employeeId;

        if (user != null && currentEmployeeId != null) {
          // Get the selected employee ID for filtering
          int? filterEmployeeId = currentEmployeeId; // Default to current user
          if (_selectedEmployee != null) {
            filterEmployeeId = _employeeNameToId[_selectedEmployee];
            print('Filtering by employee: $_selectedEmployee (ID: $filterEmployeeId)');
            if (filterEmployeeId == null) {
              print('ERROR: Employee ID not found for $_selectedEmployee');
              print('Available employees: $_employeeNameToId');
            }
          } else {
            print('Showing all employees (current user: $currentEmployeeId)');
          }
          
          print('Loading deviations with filters - Employee: $filterEmployeeId, Status: $_selectedStatus');
          
          final response = await deviationRepo.getDeviationList(
            searchText: _searchController.text,
            pageNumber: 1,
            pageSize: 1000,
            userId: user.userId,
            bizUnit: user.sbuId,
            employeeId: filterEmployeeId ?? currentEmployeeId,
          );
          
          if (mounted) {
            setState(() {
              _deviations = response.items;
              print('Loaded ${_deviations.length} deviations from API');
              _applyStatusFilter(); // Apply status filter on client side
            });
          }
        }
      }
    } catch (e) {
      print('Error loading deviations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading deviations: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  void _applyStatusFilter() {
    setState(() {
      if (_selectedStatus == null) {
        _filteredDeviations = _deviations;
        print('No status filter applied - showing all ${_deviations.length} deviations');
      } else {
        _filteredDeviations = _deviations.where((deviation) {
          final matches = deviation.deviationStatus != null && 
                 deviation.deviationStatus!.trim().toLowerCase() == _selectedStatus!.trim().toLowerCase();
          if (matches) {
            print('Status match: ${deviation.deviationStatus} == $_selectedStatus');
          }
          return matches;
        }).toList();
        print('Status filter applied: $_selectedStatus - showing ${_filteredDeviations.length} out of ${_deviations.length} deviations');
      }
    });
  }

  void _onEmployeeFilterChanged(String? employee) {
    print('Employee filter changed to: $employee');
    print('Current employee mapping: $_employeeNameToId');
    setState(() {
      _selectedEmployee = employee;
    });
    _loadDeviations(); // Reload data from API with new filter
  }

  void _onStatusFilterChanged(String? status) {
    print('Status filter changed to: $status');
    print('Current status options: $_statusOptions');
    setState(() {
      _selectedStatus = status;
    });
    _applyStatusFilter(); // Apply status filter on client side
  }


  void _onSearchChanged() {
    _loadDeviations();
  }

  Future<void> _clearAllFilters() async {
    final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final int? managerId = userStore?.userDetail?.employeeId;
    String? managerEmployeeName;
    if (managerId != null && _employeeNameToId.isNotEmpty) {
      _employeeNameToId.forEach((name, id) {
        if (id == managerId) {
          managerEmployeeName = name;
        }
      });
    }
    setState(() {
      _selectedStatus = null;
      _selectedEmployee = managerEmployeeName; // Set to logged-in employee (manager)
      _searchController.clear();
    });
    await _loadDeviations();
  }
  
  int _getFilterCount() {
    int count = 0;
    if (_selectedStatus != null) count++;
    if (_selectedEmployee != null) count++;
    return count;
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
  
  void _applyFiltersFromModal() {
    _closeFilterModal();
    _pendingFilterApply?.call();
    _loadDeviations();
  }

  // Check if employee filter should be disabled (when roleCategory === 3)
  bool _shouldDisableEmployeeFilter() {
    final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    return userStore?.userDetail?.roleCategory == 3;
  }

  bool _hasActiveFilters() {
    final hasActive = _selectedEmployee != null || _selectedStatus != null;
    print('Has active filters: $hasActive (Employee: $_selectedEmployee, Status: $_selectedStatus)');
    return hasActive;
  }



  /// Build empty state widget for manager review when no deviations are available
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
              Icons.warning_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          
          // Title
          Text(
            'No Deviations Pending Review',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          
          // Description
          Text(
            'No deviations are available for review\nfor the selected filters.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _loadDeviations,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Refresh'),
                style: FilledButton.styleFrom(
                  backgroundColor: tealGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.filter_alt_off, size: 20),
                label: const Text('Clear Filters'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tealGreen, width: 1.5),
                  foregroundColor: tealGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Future<void> _performIndividualAction(String action, int deviationId, String comment, {BuildContext? dialogContext, BuildContext? viewDetailsContext}) async {
    try {
      print('Performing $action on deviation $deviationId with comment: $comment');
      
      // Get the repository and user store
      if (!getIt.isRegistered<DeviationRepository>()) {
        throw Exception('DeviationRepository is not registered');
      }
      
      final deviationRepo = getIt<DeviationRepository>();
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
      final int? employeeId = userStore?.userDetail?.employeeId;
      
      if (employeeId == null) {
        throw Exception('Employee ID is not available');
      }
      
      // Call the appropriate repository method based on action
      DeviationStatusUpdateResponse response;
      switch (action.toLowerCase()) {
        case 'approve':
          print('Calling approveDeviation API...');
          response = await deviationRepo.approveDeviation(
            id: deviationId,
            comment: comment,
            employeeId: employeeId,
          );
          break;
        case 'reject':
          print('Calling rejectDeviation API...');
          response = await deviationRepo.rejectDeviation(
            id: deviationId,
            comment: comment,
            employeeId: employeeId,
          );
          break;
        case 'send back':
          print('Calling sendBackDeviation API...');
          response = await deviationRepo.sendBackDeviation(
            id: deviationId,
            comment: comment,
            employeeId: employeeId,
          );
          break;
        default:
          throw Exception('Unknown action: $action');
      }
      
      print('API call completed successfully. Response: ID=${response.id}, Status=${response.deviationStatus}');
      
      // Use dialog context if provided, otherwise use widget context
      final contextToUse = dialogContext ?? context;
      
      if (mounted && contextToUse.mounted) {
        _showToast(
          'Deviation ${action.toLowerCase()}d successfully',
          type: ToastType.success,
          icon: Icons.check_circle,
        );
        
        // Close the comment dialog after successful action (same as DCR manager review)
        if (dialogContext != null && Navigator.of(dialogContext, rootNavigator: true).canPop()) {
          Navigator.of(dialogContext, rootNavigator: true).pop();
        }
        
        // Close the view details modal if it was opened from there
        // Use rootNavigator: false for bottom sheet, true for dialog
        if (viewDetailsContext != null) {
          // Try with rootNavigator false first (for bottom sheet)
          if (Navigator.of(viewDetailsContext, rootNavigator: false).canPop()) {
            Navigator.of(viewDetailsContext, rootNavigator: false).pop();
          } else if (Navigator.of(viewDetailsContext, rootNavigator: true).canPop()) {
            Navigator.of(viewDetailsContext, rootNavigator: true).pop();
          }
        }
        
        // Reload deviations to reflect the updated status
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _loadDeviations();
          }
        });
      }
    } catch (e) {
      print('Error performing $action on deviation: $e');
      final contextToUse = dialogContext ?? context;
      if (mounted && contextToUse.mounted) {
        _showToast(
          'Error: ${e.toString()}',
          type: ToastType.error,
          icon: Icons.error_outline,
        );
      }
    }
  }

  // Helper method to show toast message at the top - same as DCR manager review
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

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'approve':
        return tealGreen; // Teal green for approve - matches theme
      case 'reject':
        return Colors.red;
      case 'send back':
        return tealGreen; // Teal green for send back - matches theme
      default:
        return tealGreen;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'approve':
        return Icons.check_circle;
      case 'reject':
        return Icons.cancel;
      case 'send back':
        return Icons.undo;
      default:
        return Icons.info;
    }
  }



  /// Get deviation comments list from API
  Future<List<DeviationComment>> _getDeviationCommentsList(int deviationId) async {
    try {
      if (getIt.isRegistered<DeviationRepository>()) {
        final deviationRepo = getIt<DeviationRepository>();
        final comments = await deviationRepo.getDeviationComments(id: deviationId);
        return comments;
      }
    } catch (e) {
      print('DeviationManagerReviewScreen: Error getting comments list: $e');
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
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
        final int? employeeId = userStore?.userDetail?.employeeId;
        
        if (user != null && employeeId != null) {
          final response = await deviationRepo.addManagerComment(
            createdBy: employeeId,
            deviationId: deviationId,
            comment: comment,
          );
          
          print('DeviationManagerReviewScreen: Comment saved successfully: ${response.id}');
        } else {
          throw Exception('User information not available. Please login again.');
        }
      }
    } catch (e) {
      print('DeviationManagerReviewScreen: Error saving comment: $e');
      rethrow;
    }
  }

  /// Open comprehensive comment dialog with previous comments and add comment section
  Future<void> _openDeviationCommentsDialog(BuildContext context, {required int deviationId}) async {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    if (isMobile) {
      // Use bottom sheet on mobile (same as tour plan)
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useRootNavigator: false, // Don't use root navigator so it doesn't close bottom sheets
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
        useRootNavigator: false, // Don't use root navigator so it doesn't close bottom sheets
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

  // Convert DeviationApiItem to _DeviationItem
  _DeviationItem _convertApiItemToDeviationItem(DeviationApiItem apiItem) {
    String? dateLabel;
    try {
      final date = DateTime.parse(apiItem.dateOfDeviation);
      // Format as DD-MM-YYYY (e.g., "11-11-2025")
      dateLabel = DateFormat('dd-MM-yyyy').format(date);
    } catch (_) {
      dateLabel = apiItem.dateOfDeviation;
    }
    
    return _DeviationItem(
      id: apiItem.id ?? 0,
      dateLabel: dateLabel,
      employeeName: apiItem.employeeName,
      city: apiItem.clusterName,
      type: apiItem.deviationType,
      description: apiItem.description,
      status: apiItem.deviationStatus,
    );
  }

  /// Parse From Cluster from Tour Plan name (format: "text | customer | date")
  /// Returns the text part which represents the cluster
  String _parseFromClusterFromTourPlan(String? tourPlanName) {
    if (tourPlanName == null || tourPlanName.trim().isEmpty) {
      return 'Not Available';
    }
    try {
      final parts = tourPlanName.split('|');
      if (parts.isNotEmpty) {
        return parts[0].trim().isEmpty ? 'Not Available' : parts[0].trim();
      }
    } catch (e) {
      // If parsing fails, return original
    }
    return 'Not Available';
  }

  /// Parse From Customer from Tour Plan name (format: "text | customer | date")
  /// Returns the customer part
  String _parseFromCustomerFromTourPlan(String? tourPlanName) {
    if (tourPlanName == null || tourPlanName.trim().isEmpty) {
      return 'Not Available';
    }
    try {
      final parts = tourPlanName.split('|');
      if (parts.length >= 2) {
        return parts[1].trim().isEmpty ? 'Not Available' : parts[1].trim();
      }
    } catch (e) {
      // If parsing fails, return original
    }
    return 'Not Available';
  }

  /// Show deviation details modal (same as deviation list screen)
  void _showDeviationDetails(DeviationApiItem data) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final String typeLabel = data.deviationType.isNotEmpty ? data.deviationType : 'Deviation';
    final String statusLabel = data.deviationStatus.isNotEmpty ? data.deviationStatus : 'Status';
    final String statusLower = statusLabel.toLowerCase();
    final bool isApproved = statusLower.contains('approved');
    final bool isSentBack = statusLower.contains('sent back') || statusLower.contains('sentback');
    final bool isOpen = statusLower.contains('open') || statusLower.contains('pending');
    // Enable buttons only if status is "Open" (or "Pending")
    final bool buttonsEnabled = isOpen && !isApproved && !isSentBack;
    
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
              // Header (mint like DCR list)
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
                              _EnhancedDeviationCard._getStatusChipForDeviation(statusLabel),
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
                      _DetailRow('Date', _EnhancedDeviationCard._formatDate(data.dateOfDeviation)),
                      const SizedBox(height: 12),
                      _DetailRow('Employee', _EnhancedDeviationCard._valueOrPlaceholder(data.employeeName)),
                      if (data.employeeCode.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _DetailRow('Employee Code', data.employeeCode),
                      ],
                      const SizedBox(height: 20),
                      Divider(height: 1, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      // Show From and To Area/Customer for "UnPlanned Visit"
                      if (typeLabel.toLowerCase().contains('unplanned visit')) ...[
                        // From Area / Customer (from Tour Plan) - Only show if Tour Plan is linked
                        if (data.tourPlanName.isNotEmpty) ...[
                          Text(
                            'From Area / Customer',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _DetailRow('From Cluster', _parseFromClusterFromTourPlan(data.tourPlanName)),
                          const SizedBox(height: 12),
                          _DetailRow('From Customer', _parseFromCustomerFromTourPlan(data.tourPlanName)),
                          const SizedBox(height: 20),
                        ],
                        // To Area / Customer
                        Text(
                          'To Area / Customer',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _DetailRow('To Cluster', _EnhancedDeviationCard._valueOrPlaceholder(data.clusterName, placeholder: 'Not Assigned')),
                        const SizedBox(height: 12),
                        _DetailRow('To Customer', data.customerId > 0 ? 'Customer ID: ${data.customerId}' : 'Not Assigned'),
                        const SizedBox(height: 20),
                      ],
                      _DetailRow('Tour Plan', _EnhancedDeviationCard._valueOrPlaceholder(data.tourPlanName, placeholder: 'Not Linked')),
                      const SizedBox(height: 20),
                      Divider(height: 1, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      _DetailRow('Impact', _EnhancedDeviationCard._valueOrPlaceholder(data.impact, placeholder: 'Not Provided')),
                      const SizedBox(height: 12),
                      _DetailRow('Description', _EnhancedDeviationCard._valueOrPlaceholder(data.description, placeholder: 'No description provided'), isMultiline: true),
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
                    children: [
                      Row(
                        children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: buttonsEnabled ? () async {
                                  // Pass the view details modal context so it can be closed after successful action
                                  await _showIndividualActionModal('Approve', data, viewDetailsContext: context);
                                } : null,
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('Approve'),
                              style: FilledButton.styleFrom(
                                backgroundColor: buttonsEnabled ? const Color(0xFF4db1b3) : Colors.grey,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                disabledForegroundColor: Colors.grey.shade600,
                                minimumSize: const Size.fromHeight(44),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: buttonsEnabled ? () async {
                                  // Pass the view details modal context so it can be closed after successful action
                                  await _showIndividualActionModal('Send Back', data, viewDetailsContext: context);
                                } : null,
                              icon: const Icon(Icons.undo_outlined, size: 18),
                              label: const Text('Send Back'),
                              style: FilledButton.styleFrom(
                                backgroundColor: buttonsEnabled ? const Color(0xFF4db1b3) : Colors.grey,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                disabledForegroundColor: Colors.grey.shade600,
                                minimumSize: const Size.fromHeight(44),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          ),
        ),
      ),
    );
  }

  Future<void> _showIndividualActionModal(String action, DeviationApiItem deviation, {BuildContext? viewDetailsContext}) async {
    final TextEditingController commentController = TextEditingController();
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final titleFont = isTablet ? 18.0 : 16.0;
    final bodyFont = isTablet ? 14.0 : 13.0;
    final requireComment = action != 'Approve';
    final descriptionText = 'Please provide ${requireComment ? 'a' : 'an optional'} comment for $action action:';
    
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      useRootNavigator: true,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Dialog(
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
                      _getActionIcon(action),
                      color: tealGreen,
                      size: isTablet ? 20 : 18,
                    ),
                  ),
                  SizedBox(width: isTablet ? 14 : 12),
                  Expanded(
                    child: Text(
                      '$action Deviation',
                      style: GoogleFonts.inter(
                        fontSize: titleFont,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[900],
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (Navigator.of(ctx, rootNavigator: true).canPop()) {
                        Navigator.of(ctx, rootNavigator: true).pop();
                      }
                    },
                    icon: Icon(Icons.close, color: Colors.grey[600], size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 20 : 16),
              Text(
                descriptionText,
                style: GoogleFonts.inter(
                  fontSize: bodyFont,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: isTablet ? 16 : 14),
              TextField(
                controller: commentController,
                maxLines: 4,
                style: GoogleFonts.inter(
                  fontSize: bodyFont,
                  color: Colors.grey[900],
                ),
                decoration: InputDecoration(
                  hintText: 'Enter your comment for ${action.toLowerCase()}...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: bodyFont,
                    color: Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 14,
                    vertical: isTablet ? 16 : 14,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              SizedBox(height: isTablet ? 24 : 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      if (Navigator.of(ctx, rootNavigator: true).canPop()) {
                        Navigator.of(ctx, rootNavigator: true).pop();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 20 : 18,
                        vertical: isTablet ? 12 : 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: bodyFont,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  SizedBox(width: isTablet ? 12 : 10),
                  FilledButton(
                    onPressed: () async {
                      final comment = commentController.text.trim();
                      if (requireComment && comment.isEmpty) {
                        ToastMessage.show(
                          ctx,
                          message: 'Please enter a comment to continue',
                          type: ToastType.warning,
                          useRootNavigator: true,
                          duration: const Duration(seconds: 2),
                        );
                        return;
                      }
                      
                      // Perform action - both comment dialog and view details modal will close automatically after successful action
                      await _performIndividualAction(
                        action, 
                        deviation.id ?? 0, 
                        comment, 
                        dialogContext: ctx, 
                        viewDetailsContext: viewDetailsContext,
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _getActionColor(action),
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 20 : 18,
                        vertical: isTablet ? 12 : 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      action,
                      style: GoogleFonts.inter(
                        fontSize: bodyFont,
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
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _getFilterBadgeText() {
    if (_filteredDeviations.isEmpty) {
      return 'No records';
    }
    final count = _filteredDeviations.length;
    return count == 1 ? '$count record' : '$count records';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isTablet = MediaQuery.of(context).size.width >= 600;
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _loadDeviations,
        color: tealGreen,
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 12 : 16,
                8,
                isMobile ? 12 : 16,
                16,
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
                            'Manager Review',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 20 : 18,
                              fontWeight: FontWeight.normal,
                              color: Colors.grey[900],
                              letterSpacing: -0.8,
                            ),
                          ),
                          SizedBox(height: isTablet ? 6 : 4),
                          Text(
                            'Review and take action on deviations',
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
                const SizedBox(height: 12),
                // Filter count display
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 14,
                    vertical: isTablet ? 12 : 10,
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
                const SizedBox(height: 16),

                // Deviations List
                if (_isLoading)
                  Container(
                    height: 200,
                    margin: const EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(tealGreen),
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
                  )
                else if (_filteredDeviations.isEmpty)
                  _buildManagerReviewEmptyState()
                else
                  ..._filteredDeviations.map((deviation) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                      child: _EnhancedDeviationCard(
                        item: _convertApiItemToDeviationItem(deviation),
                        deviationId: deviation.id,
                        apiItem: deviation,
                        onViewDetails: () => _showDeviationDetails(deviation),
                      ),
                    );
                  }).toList(),
              ],
            ),
            // Filter Modal overlay
            if (_showFilterModal) _buildFilterModal(isMobile, isTablet, tealGreen),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFilterModal(bool isMobile, bool isTablet, Color tealGreen) {
    // Temp selections that live during modal lifetime
    String? _tempStatus = _selectedStatus;
    String? _tempEmployee = _selectedEmployee;
    
    return GestureDetector(
      onTap: _closeFilterModal,
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: SlideTransition(
          position: _filterModalAnimation ?? const AlwaysStoppedAnimation(Offset.zero),
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
                                  // Removed onExpanded to prevent layout conflicts during scrolling
                                ),
                                const SizedBox(height: 24),
                                // Employee
                                if (!_shouldDisableEmployeeFilter())
                                  _SearchableFilterDropdown(
                                    key: _employeeFilterSectionKey,
                                    title: 'Employee',
                                    icon: Icons.person_outline,
                                    selectedValue: _tempEmployee,
                                    options: _employeeOptions,
                                    onChanged: (v) => setModalState(() => _tempEmployee = v),
                                    isTablet: isTablet,
                                    // Removed onExpanded to prevent layout conflicts during scrolling
                                  ),
                                if (!_shouldDisableEmployeeFilter()) const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Footer buttons
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
                                  fontSize: isMobile ? 14 : 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: () {
                                _pendingFilterApply = () {
                                  setState(() {
                                    _selectedStatus = _tempStatus;
                                    _selectedEmployee = _tempEmployee;
                                  });
                                };
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
  

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'sent back':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<String?> _pickFromList(BuildContext context, {
    required String title,
    required List<String> options,
    String? selected,
    bool searchable = false,
  }) async {
    // If searchable is true or options list is large, use searchable version
    final bool useSearch = searchable || options.length > 10;
    
    if (useSearch) {
      return _pickFromListSearchable(context, title: title, options: options, selected: selected);
    }
    
    return showModalBottomSheet<String>(
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
            
            // Header with close button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // Options list with separators (consistent with My Deviations screen)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = option == selected;
                  return ListTile(
                    title: Text(
                      option,
                      style: isSelected
                          ? Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade800,
                            ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () => Navigator.pop(ctx, option),
                  );
                },
                separatorBuilder: (_, __) => const Divider(height: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                    color: textColor,
                    fontSize: 13, // Slightly smaller for better mobile fit
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
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
    // Removed onExpanded callback to prevent layout conflicts during scrolling
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
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 12 : 10,
                            vertical: isTablet ? 8 : 6,
                          ),
                          itemCount: _filteredOptions.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: isTablet ? 6 : 4),
                          itemBuilder: (context, index) {
                            final option = _filteredOptions[index];
                            final isSelected =
                                widget.selectedValue == option;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _selectOption(option),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: EdgeInsets.all(
                                      isTablet ? 12 : 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? tealGreen.withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(
                                            color:
                                                tealGreen.withOpacity(0.3),
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
                                      SizedBox(
                                          width: isTablet ? 12 : 10),
                                      Expanded(
                                        child: Text(
                                          option,
                                          style: GoogleFonts.inter(
                                            fontSize:
                                                isTablet ? 14 : 13,
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


// Action button for individual deviation actions
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool isEnabled;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? onPressed : null,
        icon: Icon(icon, size: isMobile ? 14 : 16),
        label: Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 11 : 13,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? color : Colors.grey,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 8 : 8)),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 4 : 6,
            vertical: isMobile ? 10 : 8,
          ),
          elevation: isEnabled ? 1 : 0,
          minimumSize: Size(0, isMobile ? 40 : 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

// Deviation Item class
class _DeviationItem {
  const _DeviationItem({required this.id, this.dateLabel, this.employeeName, this.city, this.type, this.description, this.status});
  final int id; 
  final String? dateLabel; 
  final String? employeeName; 
  final String? city; 
  final String? type; 
  final String? description; 
  final String? status;
}

// Enhanced Deviation Card (same as deviation list screen)
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
            Divider(height: 1, thickness: 1, color: Colors.black.withOpacity(.06)),
            const SizedBox(height: 10),
            _iconKvRow(context, Icons.person_outline, 'Employee', item.employeeName ?? 'Unknown'),
            // Show cluster only for "UnPlanned Visit"
            if ((item.type ?? '').toLowerCase().contains('unplanned visit')) ...[
              SizedBox(height: isMobile ? 6 : 8),
              _iconKvRow(context, Icons.place_outlined, 'Cluster', item.city ?? 'Unknown'),
            ],
            SizedBox(height: isMobile ? 6 : 8),
            _iconKvRow(context, Icons.calendar_today_outlined, 'Date', item.dateLabel ?? 'Unknown'),
          ],
        ),
      ),
    );
  }

  // Icon + key/value row (same as DCR list)
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
      statusChip = _StatusChip.pending(statusText.isNotEmpty ? statusText : 'Pending');
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
      // Format as DD-MM-YYYY (e.g., "11-11-2025")
      return DateFormat('dd-MM-yyyy').format(date);
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

  static String _valueOrPlaceholder(String? value, {String placeholder = 'N/A'}) {
    if (value == null) {
      return placeholder;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? placeholder : trimmed;
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(.06)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.black54),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.labelLarge),
      ]),
    );
  }
}

// Status Chip widget (same as DCR list)
class _StatusChip extends StatelessWidget {
  const _StatusChip._(this.text, this.color);
  const _StatusChip.approved(String text) : this._(text, const Color(0xFF2DBE64));
  const _StatusChip.pending(String text) : this._(text, const Color(0xFFFFC54D));
  const _StatusChip.rejected(String text) : this._(text, const Color(0xFFE53935));

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

/// Deviation Comments Dialog Widget (same as deviation list screen)
class _DeviationCommentsDialog extends StatefulWidget {
  final int deviationId;
  final Future<List<DeviationComment>> Function(int) onGetComments;
  final Future<void> Function({required int deviationId, required String comment}) onSaveComment;
  final VoidCallback? onCommentAdded;

  const _DeviationCommentsDialog({
    required this.deviationId,
    required this.onGetComments,
    required this.onSaveComment,
    this.onCommentAdded,
  });

  @override
  State<_DeviationCommentsDialog> createState() => _DeviationCommentsDialogState();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a comment'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Validation: Check minimum length
    if (commentText.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment must be at least 2 characters long'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Validation: Check maximum length
    if (commentText.length > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment must be less than 1000 characters'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Comment saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Error saving comment: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
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
            icon: Icon(Icons.close, color: Colors.grey, size: isTablet ? 24 : 20),
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
        bottom: 0,
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
                              Icon(Icons.chat_bubble_outline, size: isTablet ? 48 : 40, color: Colors.grey[400]),
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
                          maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.25 : (isTablet ? 300 : 250),
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
                            separatorBuilder: (context, index) => SizedBox(height: isTablet ? 8 : 6),
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
                    SizedBox(height: isTablet ? 16 : 12),

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
              errorText: _commentController.text.trim().isEmpty && _commentController.text.isNotEmpty
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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                        padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
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
                        padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: tealGreen,
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                (comment.userName ?? 'U').isNotEmpty ? (comment.userName ?? 'U')[0].toUpperCase() : 'U',
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
        final hour = localDate.hour > 12 ? localDate.hour - 12 : (localDate.hour == 0 ? 12 : localDate.hour);
        final minute = localDate.minute.toString().padLeft(2, '0');
        final period = localDate.hour >= 12 ? 'PM' : 'AM';
        return 'Today at $hour:$minute $period';
      } else if (difference.inDays == 1) {
        // Yesterday
        final hour = localDate.hour > 12 ? localDate.hour - 12 : (localDate.hour == 0 ? 12 : localDate.hour);
        final minute = localDate.minute.toString().padLeft(2, '0');
        final period = localDate.hour >= 12 ? 'PM' : 'AM';
        return 'Yesterday at $hour:$minute $period';
      } else {
        // Format as "Nov 10, 2025 at 03:09 PM"
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final month = months[localDate.month - 1];
        final day = localDate.day;
        final year = localDate.year;
        final hour = localDate.hour > 12 ? localDate.hour - 12 : (localDate.hour == 0 ? 12 : localDate.hour);
        final minute = localDate.minute.toString().padLeft(2, '0');
        final period = localDate.hour >= 12 ? 'PM' : 'AM';
        return '$month $day, $year at $hour:$minute $period';
      }
    } catch (e) {
      return dateString;
    }
  }
}
