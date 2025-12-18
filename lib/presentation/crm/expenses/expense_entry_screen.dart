import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boilerplate/core/widgets/app_buttons.dart';
import 'package:boilerplate/core/widgets/app_dropdowns.dart';
import 'package:boilerplate/core/widgets/date_picker_field.dart';
import 'package:boilerplate/domain/entity/expense/expense.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api_models.dart';
import 'package:boilerplate/domain/repository/expense/expense_repository.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/domain/repository/dcr/dcr_repository.dart';
import 'package:boilerplate/data/network/apis/dcr/dcr_api.dart';
import 'package:boilerplate/domain/entity/dcr/dcr_api_models.dart';
import 'package:boilerplate/domain/entity/dcr/dcr.dart' as domain;
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/presentation/crm/mock_data.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';

class ExpenseDetail {
  String? expenseType;
  TextEditingController amountController = TextEditingController();
  TextEditingController remarksController = TextEditingController();
  PlatformFile? receiptFile;
  String? expenseTypeError;
  String? amountError;
  String? remarksError;

  ExpenseDetail();

  void dispose() {
    amountController.dispose();
    remarksController.dispose();
  }
}

class ExpenseEntryScreen extends StatefulWidget {
  final String? expenseId; // Optional expense ID for editing existing expense
  final String? id; // Optional ID for editing existing expense
  final String? dcrId; // Optional DCR ID for editing existing expense

  const ExpenseEntryScreen({
    super.key,
    this.expenseId,
    this.id,
    this.dcrId,
  });

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  String? _cluster;
  String? _linkedDcrId;
  DateTime _date = DateTime.now();
  int? _currentExpenseId; // Store the current expense ID for editing
  String?
      _currentExpenseStatus; // Store the current expense status (e.g., "Draft", "Submitted")
  int?
      _currentExpenseStatusId; // Store the current expense status ID (e.g., 1 for Draft, 3 for Submitted)
  String? _clusterErrorText;
  bool _isInitializing = true;

  // Multiple expense details
  List<ExpenseDetail> _expenseDetails = [ExpenseDetail()];
  int _expandedIndex = 0; // Track which expense detail is expanded

  // API-loaded options
  List<String> _clusterOptions = [];
  final Map<String, int> _clusterNameToId = {};

  List<String> _expenseTypeOptions = [];
  final Map<String, int> _expenseTypeNameToId = {};
  Future<List<domain.DcrEntry>>? _dcrListFuture;

  void _refreshDcrListIfNeeded() {
    if (!mounted) return;
    _dcrListFuture =
        (_cluster != null && _clusterNameToId.containsKey(_cluster))
            ? _getDcrListForDate()
            : null;
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // Load dropdown options first
      await Future.wait([
        _loadClusterList(),
        _loadExpenseTypeList(),
      ]);

      // Then load existing expense data if editing
      if (widget.expenseId != null || widget.id != null) {
        await _loadExpenseData();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final detail in _expenseDetails) {
      detail.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExpenseData() async {
    try {
      // Use id parameter if available, otherwise fall back to expenseId
      final String? expenseIdToLoad = widget.id ?? widget.expenseId;

      if (expenseIdToLoad != null) {
        print(
            'Loading expense details for ID: $expenseIdToLoad, DCRId: ${widget.dcrId}');

        // Try to use DCR API first for expense details
        if (getIt.isRegistered<DcrApi>() && widget.dcrId != null) {
          final dcrApi = getIt<DcrApi>();
          final intId = int.tryParse(expenseIdToLoad) ?? 0;
          final intDcrId = int.tryParse(widget.dcrId!) ?? 0;

          try {
            print('Expense Get API Request - Id: $intId, DCRId: $intDcrId');
            final response = await dcrApi.getExpenseDetails(intId, intDcrId);
            print(
                'Expense Get API Response: ${response.employeeName} - ${response.expenseAmount}');

            // Prefill form with API data
            setState(() {
              _currentExpenseId =
                  response.id; // Store the expense ID for editing
              _currentExpenseStatus =
                  response.dcrStatus; // Store the expense status
              _currentExpenseStatusId =
                  response.dcrStatusId; // Store the expense status ID
              _cluster = response.clusterNames;
              _date = DateTime.parse(response.dateOfExpense);
              _refreshDcrListIfNeeded();

              // Clear existing expense details and add one with API data
              for (final detail in _expenseDetails) {
                detail.dispose();
              }
              _expenseDetails = [ExpenseDetail()];

              // Set the expense data
              final detail = _expenseDetails.first;
              final expenseTypeName = _getExpenseTypeName(response.expenceType);
              print(
                  'Setting expense type: $expenseTypeName for ID: ${response.expenceType}');
              detail.expenseType = expenseTypeName;
              detail.amountController.text = response.expenseAmount.toString();
              detail.remarksController.text = response.remarks;
              detail.expenseTypeError = null;
              detail.amountError = null;
              detail.remarksError = null;
              _clusterErrorText = null;

              print('After setting expense data:');
              print('  - Expense Type: ${detail.expenseType}');
              print('  - Amount: ${detail.amountController.text}');
              print('  - Remarks: ${detail.remarksController.text}');
              print(
                  '  - Status: ${response.dcrStatus} (ID: ${response.dcrStatusId})');

              // Set linked DCR if available
              if (response.dcrId != null) {
                _linkedDcrId = response.dcrId.toString();
              }
            });

            print('Expense form prefilled successfully');
            return;
          } catch (e) {
            print('Expense Get API failed: $e');
            // Fall through to repository fallback
          }
        }

        // Fallback to repository
        if (getIt.isRegistered<ExpenseRepository>()) {
          final expenseRepo = getIt<ExpenseRepository>();
          final expenseId = int.tryParse(expenseIdToLoad);

          if (expenseId != null) {
            // Load expense data from repository
            final expense = await expenseRepo.getById(expenseId.toString());
            if (expense != null && mounted) {
              // Map ExpenseStatus enum to status string and ID
              String statusStr = 'Draft';
              int statusId = 1;
              switch (expense.status) {
                case ExpenseStatus.draft:
                  statusStr = 'Draft';
                  statusId = 1;
                  break;
                case ExpenseStatus.submitted:
                  statusStr = 'Submitted';
                  statusId = 3;
                  break;
                case ExpenseStatus.approved:
                  statusStr = 'Approved';
                  statusId = 5;
                  break;
                case ExpenseStatus.rejected:
                  statusStr = 'Rejected';
                  statusId = 4;
                  break;
                case ExpenseStatus.sentBack:
                  statusStr = 'Sent Back';
                  statusId = 2;
                  break;
              }

              setState(() {
                _currentExpenseId =
                    expenseId; // Store the expense ID for editing
                _currentExpenseStatus = statusStr; // Store the expense status
                _currentExpenseStatusId =
                    statusId; // Store the expense status ID
                _cluster = expense.cluster;
                _date = expense.date;
                _refreshDcrListIfNeeded();
                _linkedDcrId = expense.linkedDcrId;

                // Create expense details from the loaded expense
                _expenseDetails = [
                  ExpenseDetail()
                    ..expenseType = expense.expenseHead
                    ..amountController.text = expense.amount.toString()
                    ..remarksController.text = expense.remarks ?? ''
                    ..expenseTypeError = null
                    ..amountError = null
                    ..remarksError = null
                ];
                _clusterErrorText = null;
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error loading expense data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const Color tealGreen = Color(0xFF4db1b3);
    final InputBorder commonBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
    );
    final screenTheme = theme.copyWith(
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF4db1b3),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
        border: commonBorder,
        enabledBorder: commonBorder,
        focusedBorder: commonBorder.copyWith(
          borderSide: const BorderSide(color: tealGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2.2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: tealGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _currentExpenseId != null ? 'Update Expense' : 'New Expense',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            fontSize: 20,
          ),
        ),
      ),
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Theme(
          data: screenTheme,
          child: _isInitializing
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                        AlwaysStoppedAnimation(Color(0xFF4db1b3)),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Expense Details',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          _Labeled(
                            child: DatePickerField(
                              initialDate: _date,
                              label: 'Date',
                              onChanged: (d) {
                                setState(() {
                                  _date = d;
                                  // Clear linked DCR when date changes
                                  _linkedDcrId = null;
                                  _refreshDcrListIfNeeded();
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Labeled(
                            label: 'Cluster / City',
                            required: true,
                            errorText: _clusterErrorText,
                            child: SearchableDropdown(
                              options: _clusterOptions,
                              value: _cluster,
                              hintText: '-- Select City --',
                              searchHintText: 'Search city...',
                              hasError: _clusterErrorText != null,
                              onChanged: (v) => setState(() {
                                _cluster = v;
                                _clusterErrorText = null;
                                // Clear linked DCR when city changes
                                _linkedDcrId = null;
                                _refreshDcrListIfNeeded();
                              }),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Labeled(
                            label: 'Link to DCR (optional)',
                            child: _cluster == null
                                ? SearchableDropdown(
                                    options: const [],
                                    value: null,
                                    hintText: 'Select City first',
                                    searchHintText: 'Select City first',
                                    onChanged: (_) {},
                                  )
                                : FutureBuilder<List<domain.DcrEntry>>(
                                    future: _dcrListFuture,
                                    builder: (context, snap) {
                                      final isLoading = snap.connectionState ==
                                          ConnectionState.waiting;
                                      final items = snap.data ?? const [];
                                      final labels = items
                                          .map((e) =>
                                              '${e.customer} • ${e.purposeOfVisit}')
                                          .toList();
                                      String? current;
                                      if (_linkedDcrId != null) {
                                        final idx = items.indexWhere(
                                            (e) => e.id == _linkedDcrId);
                                        if (idx >= 0) current = labels[idx];
                                      }
                                      return Stack(
                                        alignment: Alignment.centerRight,
                                        children: [
                                          SearchableDropdown(
                                            options: labels,
                                            value: current,
                                            hintText: labels.isEmpty
                                                ? 'No DCRs found for this date and city'
                                                : 'Select DCR to link',
                                            searchHintText: 'Search DCR...',
                                            onChanged: (v) {
                                              final idx =
                                                  labels.indexOf(v ?? '');
                                              setState(() => _linkedDcrId =
                                                  idx >= 0
                                                      ? items[idx].id
                                                      : null);
                                            },
                                          ),
                                          if (isLoading)
                                            Positioned(
                                              right: 12,
                                              child: SizedBox(
                                                height: 18,
                                                width: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation(
                                                          tealGreen),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 20),

                          // Multiple Expense Details Section
                          ..._buildExpenseDetailsSections(),

                          const SizedBox(height: 16),
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: _addAnotherExpense,
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text('Add Another Expense'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Color(0xFF4db1b3),
                                side: const BorderSide(
                                    color: Color(0xFF4db1b3), width: 1.5),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  List<Widget> _buildExpenseDetailsSections() {
    final List<Widget> sections = [];

    for (int i = 0; i < _expenseDetails.length; i++) {
      final detail = _expenseDetails[i];
      final bool isExpanded =
          _expenseDetails.length == 1 || _expandedIndex == i;

      sections.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7F7),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: const Color(0xFF4db1b3).withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with expand/collapse functionality
              InkWell(
                onTap: _expenseDetails.length > 1
                    ? () {
                        setState(() {
                          _expandedIndex = isExpanded ? -1 : i;
                        });
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        _expenseDetails.length > 1
                            ? 'Expense Detail ${i + 1}'
                            : 'Expense Details',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4db1b3),
                            ),
                      ),
                      if (detail.expenseType != null &&
                          detail.amountController.text.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '(${detail.expenseType} - ₹${detail.amountController.text})',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF4db1b3),
                                      fontStyle: FontStyle.italic,
                                    ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (_expenseDetails.length > 1) ...[
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: const Color(0xFF4db1b3),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (_expenseDetails.length > 1)
                        IconButton(
                          onPressed: () => _removeExpenseDetail(i),
                          icon: const Icon(Icons.close, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),
              ),

              // Expandable content
              if (isExpanded) ...[
                const Divider(height: 1, color: Color(0xFF4db1b3)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Labeled(
                        label: 'Expense Type',
                        required: true,
                        errorText: detail.expenseTypeError,
                        child: SearchableDropdown(
                          options: _expenseTypeOptions,
                          value: detail.expenseType,
                          hintText: 'Travel',
                          searchHintText: 'Search expense type...',
                          hasError: detail.expenseTypeError != null,
                          onChanged: (v) {
                            print('Expense type dropdown changed to: $v');
                            setState(() {
                              detail.expenseType = v;
                              detail.expenseTypeError = null;
                            });
                            print(
                                'After setState - detail.expenseType: ${detail.expenseType}');
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Labeled(
                        label: 'Amount (₹)',
                        required: true,
                        errorText: detail.amountError,
                        child: TextFormField(
                          controller: detail.amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            hintText: 'e.g. 1500',
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: detail.amountError != null
                                      ? Colors.red.shade400
                                      : Colors.grey.shade300,
                                  width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: detail.amountError != null
                                      ? Colors.red.shade400
                                      : Colors.blue.shade200,
                                  width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          onChanged: (_) =>
                              setState(() => detail.amountError = null),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Labeled(
                        label: 'Remarks',
                        required: true,
                        errorText: detail.remarksError,
                        child: TextFormField(
                          controller: detail.remarksController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Add remarks',
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: detail.remarksError != null
                                      ? Colors.red.shade400
                                      : Colors.grey.shade300,
                                  width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: detail.remarksError != null
                                      ? Colors.red.shade400
                                      : Colors.blue.shade200,
                                  width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          onChanged: (_) =>
                              setState(() => detail.remarksError = null),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Labeled(
                        label: 'Upload Receipt (Optional)',
                        child: InkWell(
                          onTap: () => _pickReceiptFile(i),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.black.withOpacity(.10)),
                              borderRadius: BorderRadius.circular(16),
                              color: const Color(0xFFF5F6F8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.attach_file, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    detail.receiptFile?.name ?? 'Choose File',
                                    style: TextStyle(
                                      color: detail.receiptFile != null
                                          ? Colors.black
                                          : Colors.black54,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (detail.receiptFile != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.blue.shade200),
                                    ),
                                    child: Text(
                                      _getFileTypeLabel(
                                          detail.receiptFile!.extension),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => setState(
                                        () => detail.receiptFile = null),
                                    child: const Icon(Icons.close, size: 16),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return sections;
  }

  void _addAnotherExpense() {
    setState(() {
      _expenseDetails.add(ExpenseDetail());
      // Expand the newly added expense
      _expandedIndex = _expenseDetails.length - 1;
    });
  }

  void _removeExpenseDetail(int index) {
    if (_expenseDetails.length > 1) {
      setState(() {
        _expenseDetails[index].dispose();
        _expenseDetails.removeAt(index);

        // Adjust expanded index after removal
        if (_expandedIndex == index) {
          // If we removed the expanded item, expand the first one
          _expandedIndex = 0;
        } else if (_expandedIndex > index) {
          // If we removed an item before the expanded one, adjust the index
          _expandedIndex--;
        }

        // If only one item left, reset to always expanded
        if (_expenseDetails.length == 1) {
          _expandedIndex = 0;
        }
      });
    }
  }

  Widget _buildActionButtons() {
    final List<_ActionButtonConfig> actions = [];
    if (_currentExpenseId != null) {
      if (_isDraftExpense()) {
        actions
          ..add(_ActionButtonConfig(label: 'Save Draft', onPressed: _saveDraft))
          ..add(_ActionButtonConfig(
              label: 'Submit', onPressed: _submit, primary: true));
      } else {
        actions
          ..add(_ActionButtonConfig(
              label: 'Save as Draft', onPressed: _saveDraft))
          ..add(_ActionButtonConfig(
              label: 'Update Expense', onPressed: _submit, primary: true));
      }
    } else {
      actions
        ..add(_ActionButtonConfig(label: 'Save Draft', onPressed: _saveDraft))
        ..add(_ActionButtonConfig(
            label: 'Submit', onPressed: _submit, primary: true));
    }

    return Row(
      children: [
        for (int i = 0; i < actions.length; i++) ...[
          Expanded(
            child: actions[i].primary
                ? FilledButton(
                    onPressed: actions[i].onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4db1b3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    child: Text(actions[i].label,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  )
                : OutlinedButton(
                    onPressed: actions[i].onPressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4db1b3),
                      side: const BorderSide(
                          color: Color(0xFF4db1b3), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(actions[i].label,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
          ),
          if (i != actions.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Future<void> _pickReceiptFile(int index) async {
    try {
      // Check and request storage permissions
      bool hasPermission = await _checkAndRequestStoragePermission();
      if (!hasPermission) {
        if (mounted) {
          ToastMessage.show(
            context,
            message: 'Storage permission is required to select files',
            type: ToastType.error,
            duration: const Duration(seconds: 3),
          );
        }
        return;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          // Images
          'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp',
          // Documents
          'pdf', 'doc', 'docx', 'txt',
          // Spreadsheets
          'xls', 'xlsx',
          // Presentations
          'ppt', 'pptx',
        ],
        allowMultiple: false,
        withData: true, // Load file data for base64 encoding
        withReadStream: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        print('FilePicker: File selected - Name: ${file.name}, Size: ${file.size} bytes');
        print('FilePicker: File path: ${file.path}');
        print('FilePicker: File bytes available: ${file.bytes != null ? 'Yes (${file.bytes!.length} bytes)' : 'No'}');
        print('FilePicker: File extension: ${file.extension}');

        // Check file size (limit to 10MB)
        if (file.size > 10 * 1024 * 1024) {
          if (mounted) {
            ToastMessage.show(
              context,
              message: 'File size should be less than 10MB',
              type: ToastType.error,
              duration: const Duration(seconds: 3),
            );
          }
          return;
        }

        if (mounted) {
          setState(() {
            _expenseDetails[index].receiptFile = file;
          });
          print('FilePicker: File stored in expense detail at index $index');
          ToastMessage.show(
            context,
            message: 'File selected: ${file.name}',
            type: ToastType.info,
            duration: const Duration(seconds: 2),
          );
        }
      } else {
        print('FilePicker: No file selected or result is null');
      }
    } catch (e) {
      print('Error picking file: $e');
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Error selecting file. Please try again.',
          type: ToastType.error,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  bool _validate({required bool forSubmit}) {
    bool isValid = true;
    String? firstMessage;
    int? firstInvalidDetailIndex;

    String? clusterError;
    if (_cluster == null || _cluster!.trim().isEmpty) {
      clusterError = 'Please select a cluster / city';
      isValid = false;
      firstMessage ??= 'Select a cluster / city';
    }

    for (int i = 0; i < _expenseDetails.length; i++) {
      final detail = _expenseDetails[i];
      detail.expenseTypeError = null;
      detail.amountError = null;
      detail.remarksError = null;

      final expenseLabel =
          _expenseDetails.length > 1 ? 'Expense ${i + 1}' : 'this expense';

      if (detail.expenseType == null || detail.expenseType!.trim().isEmpty) {
        detail.expenseTypeError = 'Select an expense type';
        isValid = false;
        firstMessage ??= 'Select an expense type for $expenseLabel';
        firstInvalidDetailIndex ??= i;
      }

      final amountText = detail.amountController.text.trim();
      if (amountText.isEmpty) {
        detail.amountError = 'Enter the amount';
        isValid = false;
        firstMessage ??= 'Enter the amount for $expenseLabel';
        firstInvalidDetailIndex ??= i;
      } else {
        final double? amount = double.tryParse(amountText);
        if (amount == null || amount <= 0) {
          detail.amountError = 'Enter a valid amount greater than 0';
          isValid = false;
          firstMessage ??= 'Enter a valid amount for $expenseLabel';
          firstInvalidDetailIndex ??= i;
        }
      }

      final remarksText = detail.remarksController.text.trim();
      if (remarksText.isEmpty) {
        detail.remarksError = 'Please enter remarks';
        isValid = false;
        firstMessage ??= 'Add remarks for $expenseLabel';
        firstInvalidDetailIndex ??= i;
      }
    }

    setState(() {
      _clusterErrorText = clusterError;
      if (firstInvalidDetailIndex != null) {
        _expandedIndex = firstInvalidDetailIndex!;
      }
    });

    if (!isValid) {
      _showSnack('⚠ ${firstMessage ?? 'Please review the highlighted fields'}');
    }

    return isValid;
  }

  Future<void> _saveDraft() async {
    if (!_validate(forSubmit: false)) {
      return;
    }
    await _createOrSubmit(submit: false);
  }

  Future<void> _submit() async {
    // Add a small delay to ensure setState has completed
    await Future.delayed(const Duration(milliseconds: 100));

    if (!_validate(forSubmit: true)) {
      return;
    }
    await _createOrSubmit(submit: true);
  }

  Future<void> _createOrSubmit({required bool submit}) async {
    final repo = getIt<ExpenseRepository>();

    try {
      // Get user details from UserStore
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      final int? userId = userStore?.userDetail?.id;
      final int? employeeId = userStore?.userDetail?.employeeId;
      final int? sbuId = userStore?.userDetail?.sbuId;
      final String? employeeName = userStore?.userDetail?.name;

      if (userId == null || employeeId == null) {
        if (!mounted) return;
        ToastMessage.show(
          context,
          message: 'User information not available. Please login again.',
          type: ToastType.error,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Get cluster ID
      final cityId =
          _clusterNameToId[_cluster!] ?? 150953; // Default to Andheri East

      // Process each expense detail
      for (final detail in _expenseDetails) {
        if (detail.expenseType == null) continue;

        final double? amount =
            double.tryParse(detail.amountController.text.trim());
        if (amount == null || amount <= 0) continue;

        // Get expense type ID
        final expenseTypeId = _expenseTypeNameToId[detail.expenseType!] ??
            3; // Default to miscellaneous

        // Prepare attachments - backend will populate FilePath after upload
        // We'll pass empty attachments array and let backend handle file upload
        List<ExpenseAttachment>? attachments = [];

        // Format date as ISO 8601: 2025-10-16T00:00:00
        final dateFormatted =
            '${_date.toIso8601String().split('T')[0]}T00:00:00';

        final apiParams = SaveExpenseApiParams(
          id: _currentExpenseId, // Use existing ID for editing, null for new expense
          dcrId: _linkedDcrId != null ? int.tryParse(_linkedDcrId!) : 0,
          dateOfExpense: dateFormatted,
          employeeId: employeeId,
          cityId: cityId,
          clusterId: submit
              ? cityId
              : null, // Only set clusterId for submitted expenses
          bizUnit: sbuId ?? 1,
          expenceType: expenseTypeId,
          expenseAmount: amount,
          remarks: detail.remarksController.text.trim(),
          userId: userId,
          dcrStatus: submit
              ? 'Submitted'
              : 'Draft', // 'Draft' for draft, 'Submitted' for submit
          dcrStatusId: submit ? 3 : 1, // 1 for Draft, 3 for Submitted
          clusterNames: submit
              ? _cluster
              : null, // Only set cluster name for submitted expenses
          isGeneric: 1,
          employeeName: submit
              ? employeeName
              : null, // Only set employee name for submitted expenses
          attachments: attachments,
        );

        // Debug logging
        print('ExpenseEntryScreen: Saving expense with user details:');
        print(
            '  - Operation: ${_currentExpenseId != null ? 'UPDATE' : 'CREATE'}');
        print('  - Expense ID: $_currentExpenseId');
        print('  - User ID: $userId');
        print('  - Employee ID: $employeeId');
        print('  - SBU ID: $sbuId');
        print('  - Employee Name: $employeeName');
        print('  - Cluster: $_cluster (ID: $cityId)');
        print('  - Expense Type: ${detail.expenseType} (ID: $expenseTypeId)');
        print('  - Amount: $amount');
        print('  - Status: ${submit ? 'Submitted' : 'Draft'}');
        print('  - Receipt: ${detail.receiptFile?.name ?? 'None'}');

        // Collect files for upload
        List<PlatformFile> filesToUpload = [];
        if (detail.receiptFile != null) {
          print('File selected for upload: ${detail.receiptFile!.name}');
          print('File path: ${detail.receiptFile!.path}');
          print('File bytes: ${detail.receiptFile!.bytes != null ? 'Available (${detail.receiptFile!.bytes!.length} bytes)' : 'Not available'}');
          print('File size: ${detail.receiptFile!.size} bytes');
          filesToUpload.add(detail.receiptFile!);
        } else {
          print('No file selected for upload');
        }

        print('Files to upload count: ${filesToUpload.length}');
        final result = await repo.saveExpenseToApi(apiParams, files: filesToUpload.isNotEmpty ? filesToUpload : null);
        print('Expense saved to API: $result');
      }

      if (!mounted) return;
      ToastMessage.show(
        context,
        message: submit
            ? 'Expenses submitted successfully'
            : 'Expense drafts saved successfully',
        type: ToastType.success,
        duration: const Duration(seconds: 3),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      print('Error saving expenses to API: $e');
      if (!mounted) return;
      ToastMessage.show(
        context,
        message: 'Failed to save expenses: ${e.toString()}',
        type: ToastType.error,
        duration: const Duration(seconds: 4),
      );
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _loadClusterList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();

        // Get employee ID from UserStore
        final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
            ? getIt<UserDetailStore>()
            : null;
        final int? employeeId = userStore?.userDetail?.employeeId;

        if (employeeId == null) {
          print(
              'ExpenseEntryScreen: Employee ID not available for cluster list');
          return;
        }

        const int countryId = 208;
        final List<CommonDropdownItem> items =
            await repo.getClusterList(countryId, employeeId);
        final clusters = items
            .map((e) => (e.text.isNotEmpty ? e.text : e.cityName).trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        if (clusters.isNotEmpty && mounted) {
          setState(() {
            _clusterOptions = {..._clusterOptions, ...clusters}.toList();
            // map names to ids for submit
            for (final item in items) {
              final String key =
                  (item.text.isNotEmpty ? item.text : item.cityName).trim();
              if (key.isNotEmpty) _clusterNameToId[key] = item.id;
            }
          });
          print(
              'ExpenseEntryScreen: Loaded ${_clusterOptions.length} clusters for employee $employeeId');
        }
      }
    } catch (e) {
      print('ExpenseEntryScreen: Error loading cluster list: $e');
    }
  }

  Future<void> _loadExpenseTypeList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        final List<CommonDropdownItem> items = await repo.getExpenseTypeList();
        final expenseTypes =
            items.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toSet();
        if (expenseTypes.isNotEmpty && mounted) {
          setState(() {
            _expenseTypeOptions =
                {..._expenseTypeOptions, ...expenseTypes}.toList();
            // map names to ids for submit
            for (final item in items) {
              final String key = item.text.trim();
              if (key.isNotEmpty) _expenseTypeNameToId[key] = item.id;
            }
          });
          print(
              'ExpenseEntryScreen: Loaded ${_expenseTypeOptions.length} expense types');
        }
      }
    } catch (e) {
      print('ExpenseEntryScreen: Error loading expense type list: $e');
    }
  }

  Future<bool> _checkAndRequestStoragePermission() async {
    try {
      // Try to request storage permission first (works for most cases)
      PermissionStatus status = await Permission.storage.status;

      if (!status.isGranted) {
        status = await Permission.storage.request();
      }

      // If storage permission is granted, we're good to go
      if (status.isGranted) {
        return true;
      }

      // If storage permission is not available (Android 13+), try media permissions
      try {
        // Check photos permission (most common for receipts)
        PermissionStatus photosStatus = await Permission.photos.status;

        if (!photosStatus.isGranted) {
          photosStatus = await Permission.photos.request();
        }

        if (photosStatus.isGranted) {
          return true;
        }

        // If photos permission is permanently denied, use that status for dialog
        if (photosStatus.isPermanentlyDenied) {
          status = photosStatus;
        }
      } catch (e) {
        // Photos permission not available, continue with storage permission status
        print('ExpenseEntryScreen: Photos permission not available: $e');
      }

      // If permission is denied permanently, show dialog to open settings
      if (status.isPermanentlyDenied) {
        if (!mounted) return false;

        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Storage permission is required to select files. Please enable it in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );

        if (shouldOpenSettings == true && mounted) {
          await openAppSettings();
        }
        return false;
      }

      return status.isGranted;
    } catch (e) {
      // If permission_handler is not available or fails, proceed without permission check
      print(
          'ExpenseEntryScreen: Permission check failed, proceeding without permission validation: $e');
      return true; // Allow file picker to proceed and let the system handle permissions
    }
  }

  /// Get DCR list using DCR/List API with dynamic CityId and DCRDate
  Future<List<domain.DcrEntry>> _getDcrListForDate() async {
    try {
      // Check if cluster is selected
      if (_cluster == null || !_clusterNameToId.containsKey(_cluster)) {
        print('ExpenseEntryScreen: Cluster not selected for DCR list');
        return [];
      }

      // Get CityId from selected cluster
      final int? cityId = _clusterNameToId[_cluster];
      if (cityId == null) {
        print('ExpenseEntryScreen: CityId not found for cluster: $_cluster');
        return [];
      }

      // Get user details
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      final int? employeeId = userStore?.userDetail?.employeeId;

      if (employeeId == null) {
        print('ExpenseEntryScreen: Employee ID not available for DCR list');
        return [];
      }

      // Get user info for UserId and Bizunit
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();

      if (user == null) {
        print('ExpenseEntryScreen: User not available for DCR list');
        return [];
      }

      // Format DCRDate as yyyy-MM-dd
      final dcrDate =
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

      // Create DCR list request
      final request = DcrListRequest(
        pageNumber: 1,
        pageSize: 1000,
        sortOrder: 0,
        sortDir: 0,
        userId: user.userId ?? user.id,
        bizunit: user.sbuId,
        transactionType: '',
        employeeId: employeeId,
        cityId: cityId,
        dcrDate: dcrDate,
        managerId: 0,
      );

      print('ExpenseEntryScreen: DCR List Request: ${request.toJson()}');

      // Call DCR API directly
      if (!getIt.isRegistered<DcrApi>()) {
        print('ExpenseEntryScreen: DcrApi not registered');
        return [];
      }

      final dcrApi = getIt<DcrApi>();
      final response = await dcrApi.getDcrList(request);

      print(
          'ExpenseEntryScreen: DCR List Response: ${response.items.length} items');

      // Convert DcrApiItem to DcrEntry
      return response.items
          .map((apiItem) => _convertApiItemToDcrEntry(apiItem))
          .toList();
    } catch (e) {
      print('ExpenseEntryScreen: Error loading DCR list: $e');
      return [];
    }
  }

  /// Convert DcrApiItem to DcrEntry
  domain.DcrEntry _convertApiItemToDcrEntry(DcrApiItem apiItem) {
    // Convert API status to DcrStatus enum
    domain.DcrStatus status;
    switch (apiItem.statusText.toLowerCase()) {
      case 'approved':
        status = domain.DcrStatus.approved;
        break;
      case 'submitted':
        status = domain.DcrStatus.submitted;
        break;
      case 'rejected':
        status = domain.DcrStatus.rejected;
        break;
      case 'sent back':
        status = domain.DcrStatus.sentBack;
        break;
      default:
        status = domain.DcrStatus.draft;
    }

    // Parse date from API response
    DateTime dcrDate;
    try {
      dcrDate = DateTime.parse(apiItem.dcrDate);
    } catch (e) {
      dcrDate = _date;
    }

    return domain.DcrEntry(
      id: apiItem.id.toString(),
      date: dcrDate,
      cluster:
          apiItem.clusterNames.isNotEmpty ? apiItem.clusterNames : 'Unknown',
      customer: apiItem.customerName.isNotEmpty
          ? apiItem.customerName
          : 'Unknown Customer',
      purposeOfVisit:
          apiItem.typeOfWork.isNotEmpty ? apiItem.typeOfWork : 'Visit',
      callDurationMinutes: 0, // Not available in list response
      productsDiscussed: apiItem.productsToDiscuss ?? '',
      samplesDistributed: apiItem.samplesToDistribute ?? '',
      keyDiscussionPoints: apiItem.remarks ?? '',
      status: status,
      employeeId: apiItem.employeeId.toString(),
      employeeName:
          apiItem.employeeName.isNotEmpty ? apiItem.employeeName : 'Unknown',
      linkedTourPlanId:
          apiItem.tourPlanId > 0 ? apiItem.tourPlanId.toString() : null,
      geoProximity: domain.GeoProximity.away,
      customerLatitude: apiItem.customerLatitude,
      customerLongitude: apiItem.customerLongitude,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      typeOfWorkId: apiItem.typeOfWorkId,
      cityId: apiItem.cityId,
      customerId: apiItem.customerId,
      clusterId: null, // Not available in API response
    );
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  String _getFileTypeLabel(String? extension) {
    if (extension == null) return 'FILE';
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return 'IMG';
      case 'pdf':
        return 'PDF';
      case 'doc':
      case 'docx':
        return 'DOC';
      case 'xls':
      case 'xlsx':
        return 'XLS';
      case 'ppt':
      case 'pptx':
        return 'PPT';
      case 'txt':
        return 'TXT';
      default:
        return 'FILE';
    }
  }

  String? _getExpenseTypeName(int expenseTypeId) {
    // Find the expense type name from the loaded options
    print('Looking for expense type ID: $expenseTypeId');
    print('Available expense types: $_expenseTypeNameToId');

    for (final entry in _expenseTypeNameToId.entries) {
      if (entry.value == expenseTypeId) {
        print('Found expense type: ${entry.key}');
        return entry.key;
      }
    }
    print('Expense type not found, returning null');
    return null;
  }

  /// Check if the current expense is a draft
  bool _isDraftExpense() {
    // Check if status is "Draft" or statusId is 1
    if (_currentExpenseStatus != null) {
      final statusLower = _currentExpenseStatus!.toLowerCase();
      if (statusLower.contains('draft')) {
        return true;
      }
    }
    // Also check statusId - 1 means Draft
    if (_currentExpenseStatusId != null && _currentExpenseStatusId == 1) {
      return true;
    }
    return false;
  }
}

class _ActionButtonConfig {
  const _ActionButtonConfig({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;
}

class _Labeled extends StatelessWidget {
  const _Labeled(
      {this.label, required this.child, this.errorText, this.required = false});
  final String? label;
  final Widget child;
  final String? errorText;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          RichText(
            text: TextSpan(
              text: label!,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 0.1,
              ),
              children: required
                  ? [
                      TextSpan(
                        text: ' *',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 6),
        ],
        child,
        if (errorText != null && errorText!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.red.shade600,
            ),
          ),
        ],
      ],
    );
  }
}
