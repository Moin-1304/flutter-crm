import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'customer_issue_list_screen.dart';

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
  State<CustomerIssueEntryScreen> createState() => _CustomerIssueEntryScreenState();
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
  bool get _isEditMode => !widget.isViewOnly && (widget.issueId != null || widget.issueData != null);
  // Check if in view mode
  bool get _isViewMode => widget.isViewOnly;

  // Dropdown options (mock data - replace with API calls)
  List<String> _issueAgainstOptions = ['Customer', 'Vendor', 'Internal'];
  List<String> _issueToOptions = ['Warehouse', 'Store', 'Customer'];
  List<String> _fromStoreOptions = ['Inventory', 'Customer Store', 'Warehouse'];
  List<String> _toStoreOptions = ['Inventory', 'Customer Store', 'Warehouse'];

  @override
  void initState() {
    super.initState();
    if (_isEditMode || _isViewMode) {
      _loadIssueData();
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
        itemDescription: 'CFX96 Touch Real-Time PCR Detection System with Starter Package - 1855195',
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
    const blueColor = Color(0xFF2196F3);

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
                // View mode actions: Info, Print, Refresh
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
            : [
                // Edit/Create mode: Save draft button
                TextButton.icon(
                  onPressed: () {
                    // TODO: Implement save draft
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Draft saved')),
                    );
                  },
                  icon: const Icon(Icons.save_outlined, size: 20, color: Colors.white),
                  label: Text(
                    'Save',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 14 : 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 16 : 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
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
                        : (_isEditMode ? 'Customer Issue > Edit' : 'Customer Issue > New'),
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
                      icon: Icon(Icons.undo, size: 16, color: Colors.grey.shade600),
                      label: Text(
                        'Undo',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              // Customer Issue Details Card
                              _buildDetailsCard(context, isTablet),
                              const SizedBox(height: 16),
                              // Add to List Card
                              _buildListCard(context, isTablet),
                              const SizedBox(height: 24),
                        // Submit button at bottom (only in edit/create mode)
                        if (!_isViewMode) _buildSubmitButton(context, isTablet),
                              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
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
    const headerColor = Color(0xFFE3F2FD);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Tooltip(
            message: _isDetailsExpanded ? 'Collapse section' : 'Expand section',
            child: InkWell(
              onTap: () {
                setState(() {
                  _isDetailsExpanded = !_isDetailsExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Customer Issue Details',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _isDetailsExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isDetailsExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildDetailsForm(context, isTablet),
            ),
          ],
        ],
      ),
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
                        _buildReadOnlyField(
                          label: 'ST No.',
                          value: _stNo ?? '[NEW]',
                          isTablet: isTablet,
                        ),
                        const SizedBox(height: 20),
                        _buildDateField(context, isTablet),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          label: 'Issue Against *',
                          value: _issueAgainst,
                          options: _issueAgainstOptions,
                          onChanged: (value) {
                            setState(() {
                              _issueAgainst = value;
                              _issueAgainstError = null;
                            });
                          },
                          isTablet: isTablet,
                          helperText: 'Select the department/vendor responsible',
                          errorText: _issueAgainstError,
                          prefixIcon: Icon(Icons.account_circle, size: 18, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          label: 'Issue To *',
                          value: _issueTo,
                          options: _issueToOptions,
                          onChanged: (value) {
                            setState(() {
                              _issueTo = value;
                              _issueToError = null;
                            });
                          },
                          isTablet: isTablet,
                          helperText: 'Select the receiving department/store',
                          errorText: _issueToError,
                          prefixIcon: Icon(Icons.send, size: 18, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        _buildDropdownField(
                          label: 'From Store *',
                          value: _fromStore,
                          options: _fromStoreOptions,
                          onChanged: (value) {
                            setState(() {
                              _fromStore = value;
                              _fromStoreError = null;
                            });
                          },
                          isTablet: isTablet,
                          helperText: 'Source store (where items are coming from)',
                          errorText: _fromStoreError,
                          prefixIcon: Icon(Icons.store, size: 18, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          label: 'To Store *',
                          value: _toStore,
                          options: _toStoreOptions,
                          onChanged: (value) {
                            setState(() {
                              _toStore = value;
                              _toStoreError = null;
                            });
                          },
                          isTablet: isTablet,
                          helperText: 'Destination store (where items are going to)',
                          errorText: _toStoreError,
                          prefixIcon: Icon(Icons.store_mall_directory, size: 18, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          label: 'Reference / Remarks',
                          controller: _referenceCtrl,
                          isTablet: isTablet,
                          helperText: 'Optional: PO number, ticket ID, or remarks',
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildReadOnlyField(
                    label: 'ST No.',
                    value: _stNo ?? '[NEW]',
                    isTablet: isTablet,
                  ),
                  const SizedBox(height: 20),
                  _buildDateField(context, isTablet),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    label: 'Issue Against *',
                    value: _issueAgainst,
                    options: _issueAgainstOptions,
                    onChanged: (value) {
                      setState(() {
                        _issueAgainst = value;
                        _issueAgainstError = null;
                      });
                    },
                    isTablet: isTablet,
                    helperText: 'Select the department/vendor responsible',
                    errorText: _issueAgainstError,
                    prefixIcon: Icon(Icons.account_circle, size: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  _buildDropdownField(
                    label: 'Issue To *',
                    value: _issueTo,
                    options: _issueToOptions,
                    onChanged: (value) {
                      setState(() {
                        _issueTo = value;
                        _issueToError = null;
                      });
                    },
                    isTablet: isTablet,
                    helperText: 'Select the receiving department/store',
                    errorText: _issueToError,
                    prefixIcon: Icon(Icons.send, size: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  _buildDropdownField(
                    label: 'From Store *',
                    value: _fromStore,
                    options: _fromStoreOptions,
                    onChanged: (value) {
                      setState(() {
                        _fromStore = value;
                        _fromStoreError = null;
                      });
                    },
                    isTablet: isTablet,
                    helperText: 'Source store (where items are coming from)',
                    errorText: _fromStoreError,
                    prefixIcon: Icon(Icons.store, size: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  _buildDropdownField(
                    label: 'To Store *',
                    value: _toStore,
                    options: _toStoreOptions,
                    onChanged: (value) {
                      setState(() {
                        _toStore = value;
                        _toStoreError = null;
                      });
                    },
                    isTablet: isTablet,
                    helperText: 'Destination store (where items are going to)',
                    errorText: _toStoreError,
                    prefixIcon: Icon(Icons.store_mall_directory, size: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    label: 'Reference / Remarks',
                    controller: _referenceCtrl,
                    isTablet: isTablet,
                    helperText: 'Optional: PO number, ticket ID, or remarks',
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                      Icon(Icons.calendar_today, size: 22, color: Colors.grey.shade600),
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
    required ValueChanged<String?> onChanged,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                color: errorText != null ? Colors.red.shade400 : Colors.grey.shade300,
                width: errorText != null ? 1.5 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: errorText != null ? Colors.red.shade400 : Colors.grey.shade300,
                width: errorText != null ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: errorText != null ? Colors.red.shade400 : const Color(0xFF4db1b3),
                width: 2,
              ),
            ),
            errorText: errorText,
            errorStyle: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.red.shade600,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
          onChanged: onChanged,
          style: GoogleFonts.inter(
            fontSize: isTablet ? 15 : 14,
            color: Colors.grey.shade800,
          ),
          icon: Icon(Icons.arrow_drop_down, size: 24, color: Colors.grey.shade700),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF4db1b3), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
    const headerColor = Color(0xFFE3F2FD);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header with Add Item button
          InkWell(
            onTap: () {
              setState(() {
                _isListExpanded = !_isListExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Item Details',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const Spacer(),
                  if (!_isViewMode)
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Show add item dialog
                        _showAddItemDialog(context);
                      },
                    icon: const                     Icon(Icons.add, size: 18, color: Colors.white),
                    label: const Text(
                      'Add Item',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  if (_isViewMode) const SizedBox(width: 8),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: _isListExpanded ? 'Collapse section' : 'Expand section',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isListExpanded = !_isListExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: AnimatedRotation(
                          turns: _isListExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isListExpanded) ...[
            const Divider(height: 1),
            _buildItemsTable(context, isTablet),
          ],
        ],
      ),
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
            const SizedBox(height: 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
        headingRowColor: MaterialStateProperty.all(headerColor.withOpacity(0.1)),
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
                      icon: const Icon(Icons.edit, size: 20, color: Color(0xFF2196F3)),
                      onPressed: () {
                        // TODO: Edit item
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
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
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: const Text('Add item dialog - to be implemented'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Add item logic
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
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
                  Icon(Icons.info_outline, size: 20, color: Colors.orange.shade700),
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

  void _handleSubmit() {
    if (_validateForm()) {
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

