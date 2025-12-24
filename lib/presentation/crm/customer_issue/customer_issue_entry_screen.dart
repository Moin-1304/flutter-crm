import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'customer_issue_list_screen.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/core/widgets/app_dropdowns.dart';
import 'package:boilerplate/data/network/constants/endpoints.dart';

class CustomerIssueEntryScreen extends StatefulWidget {
  final String? issueId; // Optional issue ID for edit/view mode
  final CustomerIssueItem? issueData; // Optional pre-loaded issue data
  final bool isViewOnly; // If true, shows read-only view mode

  const CustomerIssueEntryScreen({
    super.key,
    this.issueId,
    this.issueData,
    this.isViewOnly = false,
  });

  @override
  State<CustomerIssueEntryScreen> createState() =>
      _CustomerIssueEntryScreenState();
}

class _CustomerIssueEntryScreenState extends State<CustomerIssueEntryScreen> {
  // Form fields
  DateTime _stDate = DateTime.now();
  String? _issueAgainst;
  String? _issueTo;
  String? _fromStore;
  String? _toStore;
  final TextEditingController _referenceCtrl = TextEditingController();
  String? _stNo; // ST Number (read-only, from API)

  // Validation errors
  String? _issueAgainstError;
  String? _issueToError;
  String? _fromStoreError;
  String? _toStoreError;

  // Collapsible sections
  bool _isDetailsExpanded = true;
  bool _isListExpanded = true;

  // Items list
  final List<IssueItemDetail> _items = [];

  // Loading state
  bool _isLoading = false;

  // Check if in edit mode
  bool get _isEditMode =>
      !widget.isViewOnly &&
      (widget.issueId != null || widget.issueData != null);
  // Check if in view mode
  bool get _isViewMode => widget.isViewOnly;

  // Dropdown options
  List<String> _issueAgainstOptions = [
    'Customer',
    'Vendor',
    'Internal'
  ]; // Will be replaced by API data
  List<String> _issueToOptions = [
    'Warehouse',
    'Store',
    'Customer'
  ]; // Will be replaced by API data
  // Store list from API
  List<CommonDropdownItem> _storeList = [];
  List<String> _fromStoreOptions = [];
  List<String> _toStoreOptions = [];
  // Issue To list from API
  List<CommonDropdownItem> _issueToList = [];
  // Issue Against list from API
  List<CommonDropdownItem> _issueAgainstList = [];

  // Loading states
  bool _isLoadingStores = false;
  String? _storeLoadError;
  bool _isLoadingIssueTo = false;
  String? _issueToLoadError;
  bool _isLoadingIssueAgainst = false;
  String? _issueAgainstLoadError;

  @override
  void initState() {
    super.initState();
    // Load stores, issue-to, and issue-against options after the first frame is built to avoid blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStores();
      _loadIssueToOptions();
      _loadIssueAgainstOptions();
    });

    if (_isEditMode || _isViewMode) {
      _loadIssueData();
    }
  }

  /// Load store list from API
  Future<void> _loadStores() async {
    if (!mounted) return;

    setState(() {
      _isLoadingStores = true;
      _storeLoadError = null;
    });

    try {
      final commonRepository = getIt<CommonRepository>();
      // Add timeout to prevent hanging
      final stores = await commonRepository.getStoreList().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout: Failed to load stores');
        },
      );

      if (mounted) {
        setState(() {
          _storeList = stores;
          _fromStoreOptions = stores.map((store) => store.text).toList();
          _toStoreOptions = stores.map((store) => store.text).toList();
          _isLoadingStores = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStores = false;
          _storeLoadError = 'Failed to load stores: ${e.toString()}';
          // Fallback to empty list or show error
          _fromStoreOptions = [];
          _toStoreOptions = [];
        });

        // Show error message to user - use Future.microtask to ensure context is ready
        Future.microtask(() {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load stores. Please try again.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }

  /// Load Issue To list from API
  Future<void> _loadIssueToOptions() async {
    if (!mounted) return;

    setState(() {
      _isLoadingIssueTo = true;
      _issueToLoadError = null;
    });

    try {
      // Get user info for UserId and BizUnit
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();

      if (user == null) {
        throw Exception('User not available');
      }

      final userId = user.userId ?? user.id ?? 1;
      final bizUnit = user.sbuId ?? 1;

      final commonRepository = getIt<CommonRepository>();
      // Add timeout to prevent hanging
      final issueToList =
          await commonRepository.getIssueToList(userId, bizUnit).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout: Failed to load issue-to options');
        },
      );

      if (mounted) {
        setState(() {
          _issueToList = issueToList;
          _issueToOptions = issueToList.map((item) => item.text).toList();
          _isLoadingIssueTo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingIssueTo = false;
          _issueToLoadError =
              'Failed to load issue-to options: ${e.toString()}';
          // Fallback to empty list or show error
          _issueToOptions = [];
        });

        // Show error message to user - use Future.microtask to ensure context is ready
        Future.microtask(() {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Failed to load issue-to options. Please try again.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }

  /// Load Issue Against list from API
  Future<void> _loadIssueAgainstOptions() async {
    if (!mounted) return;

    setState(() {
      _isLoadingIssueAgainst = true;
      _issueAgainstLoadError = null;
    });

    try {
      final commonRepository = getIt<CommonRepository>();
      // Add timeout to prevent hanging
      final issueAgainstList =
          await commonRepository.getIssueAgainstList().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
              'Request timeout: Failed to load issue-against options');
        },
      );

      if (mounted) {
        setState(() {
          _issueAgainstList = issueAgainstList;
          _issueAgainstOptions =
              issueAgainstList.map((item) => item.text).toList();
          _isLoadingIssueAgainst = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingIssueAgainst = false;
          _issueAgainstLoadError =
              'Failed to load issue-against options: ${e.toString()}';
          // Fallback to empty list or show error
          _issueAgainstOptions = [];
        });

        // Show error message to user - use Future.microtask to ensure context is ready
        Future.microtask(() {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Failed to load issue-against options. Please try again.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _referenceCtrl.dispose();
    super.dispose();
  }

  void _loadIssueData() {
    // If issueData is provided, use it directly
    if (widget.issueData != null) {
      _populateFormFromIssue(widget.issueData!);
      return;
    }

    // Otherwise, load from API using issueId
    if (widget.issueId != null) {
      setState(() {
        _isLoading = true;
      });

      // TODO: Call API to load issue data
      // For now, using mock data based on screenshot
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _populateFormFromMockData();
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  void _populateFormFromIssue(CustomerIssueItem issue) {
    // Map issue data to form fields
    // Note: CustomerIssueItem from list screen has limited fields
    // In production, you'll need a full issue model with all fields
    setState(() {
      _stNo = issue.issueNo.isNotEmpty ? issue.issueNo : issue.id;
      _stDate = issue.stDate;
      _fromStore = issue.fromStore;
      // Other fields would come from a full issue API response
      // For now, using mock data for missing fields
      _populateFormFromMockData();
    });
  }

  void _populateFormFromMockData() {
    // Mock data based on screenshot
    setState(() {
      _stNo = 'CMI-25-12-0004';
      _stDate = DateTime(2025, 12, 19);
      _issueAgainst = 'Customer';
      _issueTo = null; // "Select" in screenshot
      _fromStore = 'Inventory';
      _toStore = 'Customer Store';
      _referenceCtrl.text = '';

      // Add mock item
      _items.add(IssueItemDetail(
        divisionCategory: 'Diagnostics',
        itemDescription:
            'CFX96 Touch Real-Time PCR Detection System with Starter Package - 1855195',
        batchNo: 'EMR-25-12-0008-BTCH/2210',
        qtyInStock: 230,
        qtyIssued: 12,
        uom: 'Each',
        rate: 654.00,
        amount: 7848.00,
        remarks: '',
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    const tealGreen = Color(0xFF4db1b3);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          _isViewMode
              ? 'View Customer Issue'
              : (_isEditMode ? 'Edit Customer Issue' : 'New Customer Issue'),
          style: GoogleFonts.inter(
            fontSize: isTablet ? 20 : 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: tealGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: _isViewMode
            ? [
                // View mode actions: Info, Print
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  onPressed: () {
                    // TODO: Show issue info
                  },
                  tooltip: 'Info',
                ),
                IconButton(
                  icon: const Icon(Icons.print, color: Colors.white),
                  onPressed: () {
                    // TODO: Print issue
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Printing...')),
                    );
                  },
                  tooltip: 'Print',
                ),
              ]
            : null, // Remove Save button from header - will be at bottom
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Breadcrumb in content area
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 16,
                vertical: 12,
              ),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(Icons.home, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    _isViewMode
                        ? 'Customer Issue > View'
                        : (_isEditMode
                            ? 'Customer Issue > Edit'
                            : 'Customer Issue > New'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Spacer(),
                  // Undo button in breadcrumb area (only in edit/create mode)
                  if (!_isViewMode)
                    TextButton.icon(
                      onPressed: () {
                        // TODO: Implement undo
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Undo last action')),
                        );
                      },
                      icon: Icon(Icons.undo,
                          size: 16, color: Colors.grey.shade600),
                      label: Text(
                        'Undo',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isTablet ? 24 : 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Customer Issue Details Section
                              _buildDetailsCard(context, isTablet),
                              const SizedBox(height: 32),
                              // Add to List Section
                              _buildListCard(context, isTablet),
                              const SizedBox(height: 32),
                              // Submit button at bottom (only in edit/create mode)
                              if (!_isViewMode)
                                _buildSubmitButton(context, isTablet),
                              SizedBox(
                                  height:
                                      MediaQuery.of(context).padding.bottom +
                                          16),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Simple text header (no card, no collapsible)
        Text(
          'Customer Issue Details',
          style: GoogleFonts.inter(
            fontSize: isTablet ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 20),
        // Form fields directly (no card wrapper)
        _buildDetailsForm(context, isTablet),
      ],
    );
  }

  Widget _buildDetailsForm(BuildContext context, bool isTablet) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _LabeledField(
                          label: 'ST No.',
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey
                                  .shade50, // Lighter background for read-only
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.grey.shade200, width: 1),
                            ),
                            child: Text(
                              _stNo ?? '[NEW]',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _LabeledField(
                          label: 'ST Date',
                          required: true,
                          child: _isViewMode
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.grey.shade200, width: 1),
                                  ),
                                  child: Text(
                                    DateFormat('dd-MMM-yyyy').format(_stDate),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                )
                              : InkWell(
                                  onTap: () async {
                                    final DateTime? picked =
                                        await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _stDate = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            DateFormat('dd-MMM-yyyy')
                                                .format(_stDate),
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                        Icon(Icons.calendar_today,
                                            size: 20,
                                            color: Colors.grey.shade600),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                        _LabeledField(
                          label: 'Issue Against',
                          required: true,
                          errorText: _issueAgainstError,
                          child: _isLoadingIssueAgainst
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.grey.shade600),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Loading issue-against options...',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _isViewMode
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        _issueAgainst ?? 'Not selected',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    )
                                  : SearchableDropdown(
                                      options: _issueAgainstOptions,
                                      value: _issueAgainst,
                                      hintText:
                                          'Type to search issue against...',
                                      searchHintText: 'Search issue against...',
                                      hasError: _issueAgainstError != null,
                                      onChanged: (value) {
                                        setState(() {
                                          _issueAgainst = value;
                                          _issueAgainstError = null;
                                        });
                                      },
                                    ),
                        ),
                        const SizedBox(height: 20),
                        _LabeledField(
                          label: 'Issue To',
                          required: true,
                          errorText: _issueToError,
                          child: _isLoadingIssueTo
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.grey.shade600),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Loading issue-to options...',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _isViewMode
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        _issueTo ?? 'Not selected',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    )
                                  : SearchableDropdown(
                                      options: _issueToOptions,
                                      value: _issueTo,
                                      hintText: '-- Select Issue To --',
                                      searchHintText: 'Search issue to...',
                                      hasError: _issueToError != null,
                                      onChanged: (value) {
                                        setState(() {
                                          _issueTo = value;
                                          _issueToError = null;
                                        });
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        _LabeledField(
                          label: 'From Store',
                          required: true,
                          errorText: _fromStoreError,
                          child: _isLoadingStores
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.grey.shade600),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Loading stores...',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _isViewMode
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        _fromStore ?? 'Not selected',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    )
                                  : SearchableDropdown(
                                      options: _fromStoreOptions,
                                      value: _fromStore,
                                      hintText: '-- Select From Store --',
                                      searchHintText: 'Search from store...',
                                      hasError: _fromStoreError != null,
                                      onChanged: (value) {
                                        _handleFromStoreChange(value);
                                      },
                                    ),
                        ),
                        const SizedBox(height: 20),
                        _LabeledField(
                          label: 'To Store',
                          required: true,
                          errorText: _toStoreError,
                          child: _isLoadingStores
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.grey.shade600),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Loading stores...',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _isViewMode
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        _toStore ?? 'Not selected',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    )
                                  : SearchableDropdown(
                                      options: _toStoreOptions,
                                      value: _toStore,
                                      hintText: '-- Select To Store --',
                                      searchHintText: 'Search to store...',
                                      hasError: _toStoreError != null,
                                      onChanged: (value) {
                                        _handleToStoreChange(value);
                                      },
                                    ),
                        ),
                        const SizedBox(height: 20),
                        _LabeledField(
                          label: 'Reference / Remarks',
                          hintText:
                              'Optional: PO number, ticket ID, or remarks',
                          child: _isViewMode
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.grey.shade200, width: 1),
                                  ),
                                  child: Text(
                                    _referenceCtrl.text.isEmpty
                                        ? 'Not provided'
                                        : _referenceCtrl.text,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: _referenceCtrl.text.isEmpty
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                )
                              : TextFormField(
                                  controller: _referenceCtrl,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                          width: 1),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                          width: 1),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: const Color(0xFF4db1b3),
                                          width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _LabeledField(
                    label: 'ST No.',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.grey.shade200, width: 1),
                      ),
                      child: Text(
                        _stNo ?? '[NEW]',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _LabeledField(
                    label: 'ST Date',
                    required: true,
                    child: _isViewMode
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.grey.shade200, width: 1),
                            ),
                            child: Text(
                              DateFormat('dd-MMM-yyyy').format(_stDate),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          )
                        : InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() {
                                  _stDate = picked;
                                });
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.grey.shade300, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      DateFormat('dd-MMM-yyyy').format(_stDate),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.calendar_today,
                                      size: 20, color: Colors.grey.shade600),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  _LabeledField(
                    label: 'Issue Against',
                    required: true,
                    errorText: _issueAgainstError,
                    child: _isLoadingIssueAgainst
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.grey.shade600),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading issue-against options...',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _isViewMode
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  _issueAgainst ?? 'Not selected',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              )
                            : SearchableDropdown(
                                options: _issueAgainstOptions,
                                value: _issueAgainst,
                                hintText: '-- Select Issue Against --',
                                searchHintText: 'Search issue against...',
                                hasError: _issueAgainstError != null,
                                onChanged: (value) {
                                  setState(() {
                                    _issueAgainst = value;
                                    _issueAgainstError = null;
                                  });
                                },
                              ),
                  ),
                  const SizedBox(height: 20),
                  _LabeledField(
                    label: 'Issue To',
                    required: true,
                    errorText: _issueToError,
                    child: _isLoadingIssueTo
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.grey.shade600),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading issue-to options...',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _isViewMode
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  _issueTo ?? 'Not selected',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              )
                            : SearchableDropdown(
                                options: _issueToOptions,
                                value: _issueTo,
                                hintText: '-- Select Issue To --',
                                searchHintText: 'Search issue to...',
                                hasError: _issueToError != null,
                                onChanged: (value) {
                                  setState(() {
                                    _issueTo = value;
                                    _issueToError = null;
                                  });
                                },
                              ),
                  ),
                  const SizedBox(height: 20),
                  _LabeledField(
                    label: 'From Store',
                    required: true,
                    errorText: _fromStoreError,
                    child: _isLoadingStores
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.grey.shade600),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading stores...',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _isViewMode
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  _fromStore ?? 'Not selected',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              )
                            : SearchableDropdown(
                                options: _fromStoreOptions,
                                value: _fromStore,
                                hintText: '-- Select From Store --',
                                searchHintText: 'Search from store...',
                                hasError: _fromStoreError != null,
                                onChanged: (value) {
                                  _handleFromStoreChange(value);
                                },
                              ),
                  ),
                  const SizedBox(height: 20),
                  _LabeledField(
                    label: 'To Store',
                    required: true,
                    errorText: _toStoreError,
                    child: _isLoadingStores
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.grey.shade600),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading stores...',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _isViewMode
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  _toStore ?? 'Not selected',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              )
                            : SearchableDropdown(
                                options: _toStoreOptions,
                                value: _toStore,
                                hintText: '-- Select To Store --',
                                searchHintText: 'Search to store...',
                                hasError: _toStoreError != null,
                                onChanged: (value) {
                                  _handleToStoreChange(value);
                                },
                              ),
                  ),
                  const SizedBox(height: 20),
                  _LabeledField(
                    label: 'Reference / Remarks',
                    hintText: 'Optional: PO number, ticket ID, or remarks',
                    child: _isViewMode
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.grey.shade200, width: 1),
                            ),
                            child: Text(
                              _referenceCtrl.text.isEmpty
                                  ? 'Not provided'
                                  : _referenceCtrl.text,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: _referenceCtrl.text.isEmpty
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          )
                        : TextFormField(
                            controller: _referenceCtrl,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: Colors.grey.shade300, width: 1),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: Colors.grey.shade300, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: const Color(0xFF4db1b3), width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                  ),
                ],
              );
      },
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required bool isTablet,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: isTablet ? 14 : 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Auto-generated',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 11 : 10,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 15 : 14,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(BuildContext context, bool isTablet) {
    final isToday = _stDate.year == DateTime.now().year &&
        _stDate.month == DateTime.now().month &&
        _stDate.day == DateTime.now().day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ST Date *',
          style: GoogleFonts.inter(
            fontSize: isTablet ? 14 : 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        if (!_isViewMode && !isToday)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Default: Today\'s date (${DateFormat('dd-MMM-yyyy').format(DateTime.now())})',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.orange.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _isViewMode
            ? Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Text(
                  DateFormat('dd-MMM-yyyy').format(_stDate),
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 15 : 14,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _stDate = picked;
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('dd-MMM-yyyy').format(_stDate),
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 15 : 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      Icon(Icons.calendar_today,
                          size: 22, color: Colors.grey.shade600),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> options,
    ValueChanged<String?>? onChanged,
    required bool isTablet,
    String? helperText,
    String? errorText,
    Widget? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (prefixIcon != null) ...[
              prefixIcon,
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: isTablet ? 14 : 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              helperText,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _isViewMode
            ? Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Text(
                  value ?? 'Not selected',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 15 : 14,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : DropdownButtonFormField<String>(
                value: value,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: errorText != null
                          ? Colors.red.shade400
                          : Colors.grey.shade300,
                      width: errorText != null ? 1.5 : 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: errorText != null
                          ? Colors.red.shade400
                          : Colors.grey.shade300,
                      width: errorText != null ? 1.5 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: errorText != null
                          ? Colors.red.shade400
                          : const Color(0xFF4db1b3),
                      width: 2,
                    ),
                  ),
                  errorText: errorText,
                  errorStyle: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.red.shade600,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  filled: true,
                  fillColor: Colors.white,
                ),
                isExpanded: true,
                hint: Text(
                  'Select',
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 15 : 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                items: options.map((option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Text(
                      option,
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 15 : 14,
                      ),
                    ),
                  );
                }).toList(),
                onChanged:
                    onChanged != null ? (value) => onChanged(value) : null,
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 15 : 14,
                  color: Colors.grey.shade800,
                ),
                icon: Icon(Icons.arrow_drop_down,
                    size: 24, color: Colors.grey.shade700),
              ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool isTablet,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isTablet ? 14 : 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              helperText,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _isViewMode
            ? Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Text(
                  controller.text.isEmpty ? 'Not provided' : controller.text,
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 15 : 14,
                    color: controller.text.isEmpty
                        ? Colors.grey.shade500
                        : Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF4db1b3), width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 15 : 14,
                  color: Colors.grey.shade800,
                ),
              ),
      ],
    );
  }

  Widget _buildListCard(BuildContext context, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Simple text header with Add Item button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Item Details',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            if (!_isViewMode)
              ElevatedButton.icon(
                onPressed: () {
                  _showAddItemDialog(context);
                },
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text(
                  'Add Item',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        // Items table directly (no card wrapper, no collapsible)
        _buildItemsTable(context, isTablet),
      ],
    );
  }

  Widget _buildItemsTable(BuildContext context, bool isTablet) {
    const headerColor = Color(0xFFE3F2FD);

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              'No items added yet',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 16 : 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add Item" above to continue',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 14 : 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                _showAddItemDialog(context);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Item'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
            MaterialStateProperty.all(headerColor.withOpacity(0.1)),
        columns: [
          if (!_isViewMode) const DataColumn(label: Text('Actions')),
          DataColumn(label: Text('Division / Category')),
          DataColumn(label: Text('Item Description')),
          DataColumn(label: Text('Batch No')),
          DataColumn(label: Text('Qty.InStock')),
          DataColumn(label: Text('Qty.Issued')),
          DataColumn(label: Text('UOM')),
          DataColumn(label: Text('Rate')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Remarks/Addl Description')),
        ],
        rows: _items.map((item) {
          final cells = <DataCell>[];
          if (!_isViewMode) {
            cells.add(
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit,
                          size: 20, color: Color(0xFF2196F3)),
                      onPressed: () {
                        // TODO: Edit item
                      },
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _items.remove(item);
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          }
          cells.addAll([
            DataCell(Text(item.divisionCategory)),
            DataCell(Text(item.itemDescription)),
            DataCell(Text(item.batchNo)),
            DataCell(Text(item.qtyInStock.toString())),
            DataCell(Text(item.qtyIssued.toString())),
            DataCell(Text(item.uom)),
            DataCell(Text(item.rate.toStringAsFixed(2))),
            DataCell(Text(item.amount.toStringAsFixed(2))),
            DataCell(Text(item.remarks)),
          ]);
          return DataRow(cells: cells);
        }).toList(),
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        onAdd: (item) {
          setState(() {
            _items.add(item);
          });
        },
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context, bool isTablet) {
    const tealGreen = Color(0xFF4db1b3);
    final bool canSubmit = _items.isNotEmpty &&
        _issueAgainst != null &&
        _issueTo != null &&
        _fromStore != null &&
        _toStore != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!canSubmit)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _items.isEmpty
                          ? 'Add at least one item to enable submission'
                          : 'Complete all required fields to submit',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Tooltip(
          message: canSubmit
              ? 'Submit customer issue'
              : (_items.isEmpty
                  ? 'Add at least one item first'
                  : 'Complete all required fields first'),
          child: ElevatedButton.icon(
            onPressed: canSubmit
                ? _handleSubmit
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _items.isEmpty
                              ? 'Please add at least one item before submitting'
                              : 'Please complete all required fields',
                        ),
                        backgroundColor: Colors.orange.shade700,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
            icon: Icon(
              canSubmit ? Icons.check_circle : Icons.info_outline,
              size: 22,
              color: canSubmit ? Colors.white : Colors.grey.shade700,
            ),
            label: Text(
              'Submit Customer Issue',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 16 : 15,
                fontWeight: FontWeight.w600,
                color: canSubmit ? Colors.white : Colors.grey.shade700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit ? tealGreen : Colors.grey.shade200,
              disabledBackgroundColor: Colors.grey.shade200,
              foregroundColor: canSubmit ? Colors.white : Colors.grey.shade700,
              disabledForegroundColor: Colors.grey.shade700,
              elevation: canSubmit ? 2 : 0,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 20,
                vertical: isTablet ? 16 : 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
      ],
    );
  }

  /// Handle From Store dropdown change
  void _handleFromStoreChange(String? value) {
    if (value != null && value == _toStore) {
      // Show information dialog
      _showStoreSameDialog();
      // Clear the selection
      setState(() {
        _fromStore = null;
        _fromStoreError = null;
      });
    } else {
      setState(() {
        _fromStore = value;
        _fromStoreError = null;
      });
    }
  }

  /// Handle To Store dropdown change
  void _handleToStoreChange(String? value) {
    if (value != null && value == _fromStore) {
      // Show information dialog
      _showStoreSameDialog();
      // Clear the selection
      setState(() {
        _toStore = null;
        _toStoreError = null;
      });
    } else {
      setState(() {
        _toStore = value;
        _toStoreError = null;
      });
    }
  }

  /// Show information dialog when From Store and To Store are the same
  void _showStoreSameDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Yellow warning icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 40,
                  color: Colors.amber.shade800,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                'Information',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              // Message
              Text(
                'From Store and To Store cannot be same',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'OK',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2196F3),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleSubmit() {
    if (_validateForm()) {
      // Print Customer Issue Submission
      print('═══════════════════════════════════════════════════════════');
      print('📤 SUBMITTING CUSTOMER ISSUE');
      print('═══════════════════════════════════════════════════════════');
      print('Customer Issue Details:');
      print('  - ST No: ${_stNo ?? "[NEW]"}');
      print('  - ST Date: ${DateFormat('dd-MMM-yyyy').format(_stDate)}');
      print('  - Issue Against: $_issueAgainst');
      print('  - Issue To: $_issueTo');
      print('  - From Store: $_fromStore');
      print('  - To Store: $_toStore');
      print('  - Reference/Remarks: ${_referenceCtrl.text}');
      print('');
      print('Items (${_items.length}):');
      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        print('  Item ${i + 1}:');
        print('    - Division/Category: ${item.divisionCategory}');
        print('    - Item Description: ${item.itemDescription}');
        print('    - Batch No: ${item.batchNo}');
        print('    - Qty In Stock: ${item.qtyInStock}');
        print('    - Qty Issued: ${item.qtyIssued}');
        print('    - UOM: ${item.uom}');
        print('    - Rate: ${item.rate}');
        print('    - Amount: ${item.amount}');
        print('    - Remarks: ${item.remarks}');
      }
      print('═══════════════════════════════════════════════════════════');

      // TODO: Call API to submit/update
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Customer Issue updated successfully'
                : 'Customer Issue submitted successfully',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  bool _validateForm() {
    bool isValid = true;

    if (_issueAgainst == null) {
      setState(() {
        _issueAgainstError = 'This field is required';
      });
      isValid = false;
    }

    if (_issueTo == null) {
      setState(() {
        _issueToError = 'This field is required';
      });
      isValid = false;
    }

    if (_fromStore == null) {
      setState(() {
        _fromStoreError = 'This field is required';
      });
      isValid = false;
    }

    if (_toStore == null) {
      setState(() {
        _toStoreError = 'This field is required';
      });
      isValid = false;
    }

    // Validate that From Store and To Store are not the same
    if (_fromStore != null && _toStore != null && _fromStore == _toStore) {
      _showStoreSameDialog();
      setState(() {
        _fromStoreError = 'From Store and To Store cannot be same';
        _toStoreError = 'From Store and To Store cannot be same';
      });
      isValid = false;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item before submitting'),
          backgroundColor: Colors.orange,
        ),
      );
      isValid = false;
    }

    if (!isValid) {
      // Scroll to first error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Scrollable.ensureVisible(context);
      });
    }

    return isValid;
  }
}

// Add Item Dialog Widget
class _AddItemDialog extends StatefulWidget {
  final Function(IssueItemDetail) onAdd;

  const _AddItemDialog({required this.onAdd});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  String? _divisionCategory;
  String?
      _itemDescription; // Changed from TextEditingController to String for dropdown
  String? _batchNo; // Changed from TextEditingController to String for dropdown
  final TextEditingController _qtyInStockCtrl = TextEditingController();
  final TextEditingController _qtyIssuedCtrl = TextEditingController();
  final TextEditingController _uomCtrl = TextEditingController();
  final TextEditingController _rateCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();

  // Division/Category dropdown options
  List<String> _divisionCategoryOptions = [];
  List<CommonDropdownItem> _divisionCategoryList = [];
  bool _isLoadingDivisionCategory = false;
  String? _divisionCategoryError;

  // Item Description dropdown options
  List<String> _itemDescriptionOptions = [];
  List<CommonDropdownItem> _itemDescriptionList = [];
  bool _isLoadingItemDescription = false;
  String? _itemDescriptionLoadError;

  // Batch No dropdown options
  List<String> _batchNoOptions = [];
  List<CommonDropdownItem> _batchNoList = [];
  bool _isLoadingBatchNo = false;
  String? _batchNoLoadError;

  // Validation errors
  String? _divisionCategoryFormError;
  String? _itemDescriptionError;
  String? _qtyIssuedError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDivisionCategoryOptions();
    });
  }

  @override
  void dispose() {
    // _itemDescriptionCtrl and _batchNoCtrl removed - now using String? for dropdowns
    _qtyInStockCtrl.dispose();
    _qtyIssuedCtrl.dispose();
    _uomCtrl.dispose();
    _rateCtrl.dispose();
    _amountCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  /// Load Division/Category list from API
  Future<void> _loadDivisionCategoryOptions() async {
    if (!mounted) return;

    setState(() {
      _isLoadingDivisionCategory = true;
      _divisionCategoryError = null;
    });

    try {
      final commonRepository = getIt<CommonRepository>();
      final divisionCategoryList =
          await commonRepository.getDivisionCategoryList().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
              'Request timeout: Failed to load division/category options');
        },
      );

      if (mounted) {
        setState(() {
          _divisionCategoryList = divisionCategoryList;
          _divisionCategoryOptions =
              divisionCategoryList.map((item) => item.text).toList();
          _isLoadingDivisionCategory = false;
        });

        // Debug: Print loaded options
        print(
            'Division/Category options loaded: ${_divisionCategoryOptions.length} items');
        if (_divisionCategoryOptions.isNotEmpty) {
          print('First option: ${_divisionCategoryOptions.first}');
        }
      }
    } catch (e) {
      print('Error loading division/category: $e');
      if (mounted) {
        setState(() {
          _isLoadingDivisionCategory = false;
          _divisionCategoryError =
              'Failed to load division/category options: ${e.toString()}';
          _divisionCategoryOptions = [];
        });

        Future.microtask(() {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Failed to load division/category options. Please try again.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }

  /// Load Item Description list from API based on selected Division ID
  Future<void> _loadItemDescriptions(int divisionId) async {
    if (!mounted) return;

    setState(() {
      _isLoadingItemDescription = true;
      _itemDescriptionLoadError = null;
      _itemDescription = null; // Clear previous selection
      _itemDescriptionOptions = [];
    });

    try {
      final commonRepository = getIt<CommonRepository>();
      final itemDescriptionList =
          await commonRepository.getItemDescriptionList(divisionId).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout: Failed to load item descriptions');
        },
      );

      if (mounted) {
        setState(() {
          _itemDescriptionList = itemDescriptionList;
          _itemDescriptionOptions =
              itemDescriptionList.map((item) => item.text).toList();
          _isLoadingItemDescription = false;
        });

        print(
            'Item Description options loaded: ${_itemDescriptionOptions.length} items');
      }
    } catch (e) {
      print('Error loading item descriptions: $e');
      if (mounted) {
        setState(() {
          _isLoadingItemDescription = false;
          _itemDescriptionLoadError =
              'Failed to load item descriptions: ${e.toString()}';
          _itemDescriptionOptions = [];
        });

        Future.microtask(() {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Failed to load item descriptions. Please try again.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }

  /// Load Batch No list from API based on selected Item ID
  Future<void> _loadBatchNumbers(int itemId) async {
    if (!mounted) return;

    setState(() {
      _isLoadingBatchNo = true;
      _batchNoLoadError = null;
      _batchNo = null; // Clear previous selection
      _batchNoOptions = [];
    });

    try {
      // Get user info for EmployeeId and BizUnit
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();

      if (user == null) {
        throw Exception('User not available');
      }

      // Get employeeId from UserDetailStore
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      final employeeId = userStore?.userDetail?.employeeId ?? 1;

      // Get BizUnit - prioritize UserDetailStore, then SharedPreferenceHelper, then default to 1
      // Same logic as customer_issue_list_screen.dart
      int? bizUnitFromStore = userStore?.userDetail?.sbuId;
      int? bizUnitFromPrefs = user.sbuId;

      // Prefer UserDetailStore, fallback to SharedPreferences, then default to 1
      // If either value is 0, treat it as null and use default
      int bizUnit = (bizUnitFromStore != null && bizUnitFromStore! > 0)
          ? bizUnitFromStore!
          : ((bizUnitFromPrefs != null && bizUnitFromPrefs! > 0)
              ? bizUnitFromPrefs!
              : 1);

      // Log for debugging
      print('BatchNo API: bizUnit from UserDetailStore: $bizUnitFromStore');
      print('BatchNo API: bizUnit from SharedPreferences: $bizUnitFromPrefs');
      print('BatchNo API: Final bizUnit: $bizUnit');

      // Validate BizUnit - it should not be 0
      if (bizUnit == 0) {
        throw Exception(
            'BizUnit is 0. UserDetailStore sbuId: $bizUnitFromStore, SharedPreferences sbuId: $bizUnitFromPrefs. Please ensure user details are loaded correctly.');
      }

      // Get current date in yyyy-MM-dd format
      final toDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // For CustomerId, we'll use a default value for now (can be updated later if needed)
      // In a real scenario, this might come from the customer issue context
      final customerId =
          0; // Default value, can be updated based on business logic

      // Create request object to get full JSON
      final batchNoRequest = BatchNoRequest(
        itemId: itemId,
        employeeId: employeeId,
        toDate: toDate,
        bizUnit: bizUnit,
        module: 6,
        customerId: customerId,
        transactionType: 14,
      );

      // Print Batch No API Request Parameters
      print('═══════════════════════════════════════════════════════════');
      print('📦 BATCH NO API REQUEST (Customer Issue - Add Item)');
      print('═══════════════════════════════════════════════════════════');
      print('API Endpoint: POST ${Endpoints.commonGetAuto}');
      print('Request Parameters:');
      print('  - CommandType: 332');
      print('  - Id (ItemId): $itemId');
      print('  - EmployeeId: $employeeId');
      print('  - ToDate: $toDate');
      print(
          '  - BizUnit: $bizUnit (${bizUnit == 0 ? "⚠️ WARNING: BizUnit is 0!" : "✓ Valid"})');
      print(
          '    - BizUnit Source: ${bizUnitFromStore != null ? "UserDetailStore" : (bizUnitFromPrefs != null ? "SharedPreferences" : "Default (1)")}');
      print('  - Module: 6');
      print('  - CustomerId: $customerId');
      print('  - TransactionType: 14');
      print('');
      print('Full Request JSON:');
      print(batchNoRequest.toJson());
      print('═══════════════════════════════════════════════════════════');

      final commonRepository = getIt<CommonRepository>();
      final batchNoList = await commonRepository
          .getBatchNoList(
        itemId: itemId,
        employeeId: employeeId,
        toDate: toDate,
        bizUnit: bizUnit,
        customerId: customerId,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout: Failed to load batch numbers');
        },
      );

      if (mounted) {
        setState(() {
          _batchNoList = batchNoList;
          _batchNoOptions = batchNoList.map((item) => item.text).toList();
          _isLoadingBatchNo = false;
        });

        // Print Batch No API Response
        print('✅ BATCH NO API RESPONSE');
        print('═══════════════════════════════════════════════════════════');
        print('Status: Success');
        print('Total Items: ${_batchNoOptions.length}');
        if (_batchNoOptions.isNotEmpty) {
          print('Batch Numbers:');
          for (int i = 0; i < _batchNoOptions.length && i < 10; i++) {
            print('  ${i + 1}. ${_batchNoOptions[i]}');
          }
          if (_batchNoOptions.length > 10) {
            print('  ... and ${_batchNoOptions.length - 10} more');
          }
        } else {
          print('⚠️  No batch numbers found');
        }
        print('═══════════════════════════════════════════════════════════');
      }
    } catch (e) {
      print('Error loading batch numbers: $e');
      if (mounted) {
        setState(() {
          _isLoadingBatchNo = false;
          _batchNoLoadError = 'Failed to load batch numbers: ${e.toString()}';
          _batchNoOptions = [];
        });

        Future.microtask(() {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Failed to load batch numbers. Please try again.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }

  void _handleAdd() {
    // Validate form
    bool isValid = true;

    if (_divisionCategory == null) {
      setState(() {
        _divisionCategoryFormError = 'This field is required';
      });
      isValid = false;
    } else {
      setState(() {
        _divisionCategoryFormError = null;
      });
    }

    if (_itemDescription == null || _itemDescription!.trim().isEmpty) {
      setState(() {
        _itemDescriptionError = 'This field is required';
      });
      isValid = false;
    } else {
      setState(() {
        _itemDescriptionError = null;
      });
    }

    final qtyIssued = int.tryParse(_qtyIssuedCtrl.text.trim());
    if (qtyIssued == null || qtyIssued <= 0) {
      setState(() {
        _qtyIssuedError = 'Please enter a valid quantity';
      });
      isValid = false;
    } else {
      setState(() {
        _qtyIssuedError = null;
      });
    }

    if (!isValid) {
      return;
    }

    // Calculate amount if rate is provided
    double amount = 0.0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    if (rate > 0 && qtyIssued != null) {
      amount = rate * qtyIssued;
      _amountCtrl.text = amount.toStringAsFixed(2);
    } else {
      amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    }

    // Print item being added
    print('═══════════════════════════════════════════════════════════');
    print('➕ ADDING ITEM TO CUSTOMER ISSUE');
    print('═══════════════════════════════════════════════════════════');
    print('Item Details:');
    print('  - Division/Category: $_divisionCategory');
    print('  - Item Description: $_itemDescription');
    print('  - Batch No: $_batchNo');
    print('  - Qty In Stock: ${_qtyInStockCtrl.text}');
    print('  - Qty Issued: ${_qtyIssuedCtrl.text}');
    print('  - UOM: ${_uomCtrl.text}');
    print('  - Rate: ${_rateCtrl.text}');
    print('  - Amount: ${_amountCtrl.text}');
    print('  - Remarks: ${_remarksCtrl.text}');
    print('═══════════════════════════════════════════════════════════');

    // Create item
    final item = IssueItemDetail(
      divisionCategory: _divisionCategory!,
      itemDescription: _itemDescription!,
      batchNo: _batchNo ?? '',
      qtyInStock: int.tryParse(_qtyInStockCtrl.text.trim()) ?? 0,
      qtyIssued: qtyIssued!,
      uom: _uomCtrl.text.trim(),
      rate: rate,
      amount: amount,
      remarks: _remarksCtrl.text.trim(),
    );

    widget.onAdd(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Add Item',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Required fields note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fields marked with * are mandatory',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Item Info Section
                      _buildSectionHeader('Item Information'),
                      const SizedBox(height: 12),

                      // Division/Category dropdown with improved loading
                      _buildDivisionCategoryField(),
                      const SizedBox(height: 20),

                      // Item Description (Dropdown, loads based on Division/Category)
                      _buildItemDescriptionField(),
                      const SizedBox(height: 20),

                      // Batch No (Dropdown, loads based on Item Description)
                      _buildBatchNoField(),
                      const SizedBox(height: 24),

                      // Quantity Section
                      _buildSectionHeader('Quantity'),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildSecondaryTextField(
                              controller: _qtyInStockCtrl,
                              label: 'Stock Quantity',
                              icon: Icons.inventory_2,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildPrimaryTextField(
                              controller: _qtyIssuedCtrl,
                              label: 'Order Quantity',
                              isRequired: true,
                              icon: Icons.shopping_cart,
                              errorText: _qtyIssuedError,
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _calculateAmount();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Pricing Section
                      _buildSectionHeader('Pricing'),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildSecondaryTextField(
                              controller: _uomCtrl,
                              label: 'Unit of Measure',
                              icon: Icons.straighten,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildPrimaryTextField(
                              controller: _rateCtrl,
                              label: 'Rate',
                              icon: Icons.attach_money,
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              onChanged: (value) {
                                _calculateAmount();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Amount (Read-only, auto-calculated)
                      _buildReadOnlyAmountField(),
                      const SizedBox(height: 24),

                      // Notes Section
                      _buildSectionHeader('Notes'),
                      const SizedBox(height: 12),

                      _buildSecondaryTextField(
                        controller: _remarksCtrl,
                        label: 'Remarks',
                        icon: Icons.note,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Sticky footer with buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _handleAdd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4db1b3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Add Item',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDivisionCategoryField() {
    return _LabeledField(
      label: 'Division / Category',
      required: true,
      errorText: _divisionCategoryFormError,
      child: _isLoadingDivisionCategory
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading categories...',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : SearchableDropdown(
              options: _divisionCategoryOptions,
              value: _divisionCategory,
              hintText: '-- Select Division/Category --',
              searchHintText: 'Search division/category...',
              hasError: _divisionCategoryFormError != null,
              onChanged: _divisionCategoryOptions.isEmpty
                  ? (_) {}
                  : (value) {
                      setState(() {
                        _divisionCategory = value;
                        _divisionCategoryFormError = null;
                        _itemDescription =
                            null; // Clear item description when division changes
                      });

                      // Load item descriptions based on selected division
                      if (value != null) {
                        // Find the division ID from the selected division/category
                        final selectedDivision =
                            _divisionCategoryList.firstWhere(
                          (item) => item.text == value,
                          orElse: () => _divisionCategoryList.first,
                        );

                        if (selectedDivision.id > 0) {
                          _loadItemDescriptions(selectedDivision.id);
                        }
                      }
                    },
            ),
    );
  }

  Widget _buildLoadingDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading categories...',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemDescriptionField() {
    return _LabeledField(
      label: 'Item Description',
      required: true,
      errorText: _itemDescriptionError,
      child: _divisionCategory == null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade100,
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please select Division/Category first',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _isLoadingItemDescription
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Loading items...',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : SearchableDropdown(
                  options: _itemDescriptionOptions,
                  value: _itemDescription,
                  hintText: '-- Select Item Description --',
                  searchHintText: 'Search item description...',
                  hasError: _itemDescriptionError != null,
                  onChanged: _itemDescriptionOptions.isEmpty
                      ? (_) {}
                      : (value) {
                          setState(() {
                            _itemDescription = value;
                            _itemDescriptionError = null;
                            _batchNo = null; // Clear batch no when item changes
                          });

                          // Load batch numbers based on selected item
                          if (value != null) {
                            // Find the item ID from the selected item description
                            final selectedItem =
                                _itemDescriptionList.firstWhere(
                              (item) => item.text == value,
                              orElse: () => _itemDescriptionList.first,
                            );

                            if (selectedItem.id > 0) {
                              _loadBatchNumbers(selectedItem.id);
                            }
                          }
                        },
                ),
    );
  }

  Widget _buildBatchNoField() {
    return _LabeledField(
      label: 'Batch No',
      required: false,
      child: _itemDescription == null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 1),
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: Colors.grey.shade500),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please select Item Description first',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _isLoadingBatchNo
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey.shade50,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Loading batch numbers...',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : SearchableDropdown(
                  options: _batchNoOptions,
                  value: _batchNo,
                  hintText: '-- Select Batch No --',
                  searchHintText: 'Search batch number...',
                  hasError: false,
                  onChanged: _batchNoOptions.isEmpty
                      ? (_) {}
                      : (value) {
                          setState(() {
                            _batchNo = value;

                            // Auto-fill fields from selected batch
                            if (value != null && _batchNoList.isNotEmpty) {
                              try {
                                final selectedBatch = _batchNoList.firstWhere(
                                  (item) => item.text == value,
                                  orElse: () => _batchNoList.first,
                                );

                                // Auto-fill Stock Quantity
                                if (selectedBatch.stock > 0) {
                                  _qtyInStockCtrl.text =
                                      selectedBatch.stock.toString();
                                } else {
                                  _qtyInStockCtrl.clear();
                                }

                                // Auto-fill UOM (Unit of Measure)
                                if (selectedBatch.uom > 0) {
                                  _uomCtrl.text = selectedBatch.uom.toString();
                                } else {
                                  _uomCtrl.clear();
                                }

                                // Auto-fill Rate
                                if (selectedBatch.rate > 0) {
                                  _rateCtrl.text =
                                      selectedBatch.rate.toString();
                                  // Recalculate amount if order quantity is already entered
                                  _calculateAmount();
                                } else {
                                  _rateCtrl.clear();
                                  _calculateAmount(); // Recalculate to set amount to 0
                                }

                                print('✅ Auto-filled from Batch No:');
                                print('  - Stock: ${selectedBatch.stock}');
                                print('  - UOM: ${selectedBatch.uom}');
                                print('  - Rate: ${selectedBatch.rate}');
                              } catch (e) {
                                print('Error auto-filling from batch: $e');
                              }
                            } else {
                              // Clear auto-filled fields when batch is cleared
                              _qtyInStockCtrl.clear();
                              _uomCtrl.clear();
                              _rateCtrl.clear();
                              _calculateAmount(); // Recalculate to set amount to 0
                            }
                          });
                        },
                ),
    );
  }

  Widget _buildPrimaryTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    String? errorText,
    TextInputType? keyboardType,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isRequired)
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )
        else
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            errorText: errorText,
            prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: const Color(0xFF4db1b3), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Amount',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Auto-calculated',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountCtrl,
          readOnly: true,
          decoration: InputDecoration(
            prefixIcon:
                Icon(Icons.calculate, size: 20, color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  void _calculateAmount() {
    final qty = int.tryParse(_qtyIssuedCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    if (rate > 0 && qty > 0) {
      setState(() {
        _amountCtrl.text = (rate * qty).toStringAsFixed(2);
      });
    } else {
      setState(() {
        _amountCtrl.text = '0.00';
      });
    }
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> options,
    Function(String?)? onChanged,
    String? helperText,
    String? errorText,
    Widget? prefixIcon,
    bool isSecondary = false, // For optional fields with lighter styling
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label.isEmpty ? null : label,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isSecondary ? Colors.grey.shade300 : Colors.grey.shade400,
            width: isSecondary ? 1 : 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isSecondary ? Colors.grey.shade300 : Colors.grey.shade400,
            width: isSecondary ? 1 : 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isSecondary ? Colors.grey.shade400 : const Color(0xFF4db1b3),
            width: isSecondary ? 1.5 : 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        filled: true,
        fillColor: isSecondary ? Colors.grey.shade50 : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      hint: Text(
        options.isEmpty ? 'No options available' : 'Select an option',
        style: GoogleFonts.inter(
          fontSize: 15,
          color: Colors.grey.shade600,
        ),
      ),
      items: options.isEmpty
          ? [
              DropdownMenuItem<String>(
                value: null,
                enabled: false,
                child: Text(
                  'No options available',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade400,
                    fontSize: 15,
                  ),
                ),
              ),
            ]
          : options.map((option) {
              final isDisabled = option == 'Loading...';
              return DropdownMenuItem<String>(
                value: isDisabled ? null : option,
                enabled: !isDisabled,
                child: Text(
                  option,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: isDisabled
                        ? Colors.grey.shade400
                        : Colors.grey.shade900,
                  ),
                ),
              );
            }).toList(),
      onChanged: options.isEmpty ? null : onChanged,
      isExpanded: true,
      menuMaxHeight: 300,
      icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
      iconSize: 24,
      style: GoogleFonts.inter(
        fontSize: 15,
        color: Colors.grey.shade900,
      ),
    );
  }
}

// LabeledField widget matching reference design
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.errorText,
    this.required = false,
    this.hintText,
  });
  final String label;
  final Widget child;
  final String? errorText;
  final bool required;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400, // Lighter font weight
              color: Colors.grey.shade700,
            ),
            children: required
                ? [
                    TextSpan(
                      text: ' *',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 8),
        child,
        if (hintText != null && hintText!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            hintText!,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.red.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

// Item detail model for the table (different from CustomerIssueItem in list screen)
class IssueItemDetail {
  final String divisionCategory;
  final String itemDescription;
  final String batchNo;
  final int qtyInStock;
  final int qtyIssued;
  final String uom;
  final double rate;
  final double amount;
  final String remarks;

  IssueItemDetail({
    required this.divisionCategory,
    required this.itemDescription,
    required this.batchNo,
    required this.qtyInStock,
    required this.qtyIssued,
    required this.uom,
    required this.rate,
    required this.amount,
    required this.remarks,
  });
}
