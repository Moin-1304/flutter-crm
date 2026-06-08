import 'package:flutter/material.dart';
import 'package:boilerplate/core/widgets/app_buttons.dart';
import 'package:boilerplate/core/widgets/app_form_fields.dart';
import 'package:boilerplate/core/widgets/app_dropdowns.dart';
import 'package:boilerplate/domain/entity/tour_plan/tour_plan.dart' as domain;
import 'package:boilerplate/domain/repository/tour_plan/tour_plan_repository.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/utils/purpose_visit_helper.dart';

import 'package:boilerplate/presentation/tour_plan/new_tour_plan_screen.dart';

import 'package:google_fonts/google_fonts.dart';

class TourPlanEntryScreen extends StatefulWidget {
  const TourPlanEntryScreen({super.key, this.entry});
  final domain.TourPlanEntry? entry; // if provided, edit mode

  @override
  State<TourPlanEntryScreen> createState() => _TourPlanEntryScreenState();
}

class _TourPlanEntryScreenState extends State<TourPlanEntryScreen> {
  final List<_CallModel> _calls = <_CallModel>[];
  final Set<String> _clusters = <String>{};
  final Set<String> _customers = <String>{};
  final TourPlanRepository _repo = getIt<TourPlanRepository>();
  DateTime _date = DateTime.now();
  final TextEditingController _dateCtrl = TextEditingController();
  List<String> _purposeOptions = <String>[];
  bool _isLoadingPurpose = false;

  @override
  void initState() {
    super.initState();
    // Legacy screen used hardcoded purpose options — route new plans to API-driven screen.
    if (widget.entry == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const NewTourPlanScreen()),
        );
      });
      return;
    }
    _date = widget.entry!.date;
    _dateCtrl.text = _format(_date);
    _clusters.add(widget.entry!.cluster);
    _customers.add(widget.entry!.customer);

    // Prefill call details from the entry
    _calls.add(_CallModel(
      dateLabel: _format(_date),
      status: _getStatusText(widget.entry!.status),
      customer: widget.entry!.customer,
      purpose: widget.entry!.callDetails.purposes.isNotEmpty
          ? widget.entry!.callDetails.purposes.first
          : null,
      productsToDiscuss: widget.entry!.callDetails.productsToDiscuss,
      samplesToDistribute: widget.entry!.callDetails.samplesToDistribute,
      remarks: widget.entry!.callDetails.remarks,
    ));
    _loadPurposeOptionsFromApi();
  }

  Future<void> _loadPurposeOptionsFromApi() async {
    if (!getIt.isRegistered<CommonRepository>()) return;
    setState(() => _isLoadingPurpose = true);
    try {
      final UserDetailStore? userStore =
          getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
      final loggedInUser =
          await PurposeVisitHelper.ensureLoggedInUserProfile(userStore);
      final int userId = loggedInUser?.id ?? 0;
      if (userId <= 0) return;

      final String purposeText = PurposeVisitHelper.dcrPurposeVisitText(
        serviceArea: loggedInUser?.serviceArea,
        repType: loggedInUser?.repType,
        roleCategory: loggedInUser?.roleCategory,
      );

      final List<CommonDropdownItem> items =
          await getIt<CommonRepository>().getPurposeOfVisitList(userId, purposeText);

      final Map<String, String> normalized = <String, String>{};
      for (final item in items) {
        final String raw =
            (item.text.isNotEmpty ? item.text : item.typeText).trim();
        if (raw.isNotEmpty) {
          normalized.putIfAbsent(raw.toLowerCase(), () => raw);
        }
      }

      if (!mounted) return;
      setState(() {
        _purposeOptions = normalized.values.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      });
    } catch (e) {
      print('TourPlanEntryScreen: purpose API load failed: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPurpose = false);
    }
  }

  String _getStatusText(domain.TourPlanEntryStatus status) {
    switch (status) {
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

  @override
  Widget build(BuildContext context) {
    const Color tealGreen = Color(0xFF4db1b3);
    const Color lightMint = Color(0xFFEAF7F7);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.entry == null ? 'New Tour Plan' : 'Edit Tour Plan',
          style: GoogleFonts.inter(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tour Plan Date Section
            _Labeled(
              label: 'Tour Plan Date',
              isRequired: true,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: AppTextField(
                  label: '',
                  hint: 'dd-MMM-yyyy',
                  controller: _dateCtrl,
                  readOnly: true,
                  onTap: _pickDate,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Location Section
            _Labeled(
              label: 'Cluster / City (multi-select)',
              isRequired: true,
              child: MultiSelectDropdown(
                options: const ['Andheri East', 'Bandra West', 'Powai', 'Goregaon East', 'Adhoc'],
                selectedValues: _clusters,
                hintText: 'Select clusters',
                onChanged: (values) => setState(() {
                  _clusters
                    ..clear()
                    ..addAll(values);
                  _customers.clear();
                }),
              ),
            ),
            const SizedBox(height: 20),

            _Labeled(
              label: 'Customer (multi-select)',
              isRequired: true,
              child: MultiSelectDropdown(
                options: _customerOptionsForClusters(_clusters),
                selectedValues: _customers,
                hintText: _clusters.isEmpty ? 'Select clusters first' : 'Select customers',
                onChanged: (values) => setState(() {
                  _customers
                    ..clear()
                    ..addAll(values);
                }),
              ),
            ),
            const SizedBox(height: 24),

            // Call Cards
            ..._calls.asMap().entries.map((e) => _CallCard(
                  key: ValueKey('call_${e.key}_${e.value.hashCode}'),
                  index: e.key,
                  model: e.value,
                  purposeOptions: _purposeOptions,
                  isLoadingPurpose: _isLoadingPurpose,
                  onRemove: () => setState(() => _calls.removeAt(e.key)),
                  tealGreen: tealGreen,
                  lightMint: lightMint,
                )),

            const SizedBox(height: 12),
            
            // Add Another Call Button
            OutlinedButton.icon(
              onPressed: () => setState(() => _calls.add(_CallModel(dateLabel: _format(_date), status: 'Draft'))),
              icon: const Icon(Icons.add, size: 20),
              label: Text(
                'Add Another Call',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: tealGreen,
                side: const BorderSide(color: tealGreen, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            
            const SizedBox(height: 24),

            // Manager Approval Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD0E3FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Color(0xFF0066FF)),
                      const SizedBox(width: 8),
                      Text(
                        'Manager Approval',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0044AA),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Status: Not Submitted',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0066FF),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),

            // Footer Buttons
            Row(
              children: [
                if (widget.entry != null) ...[
                  Expanded(
                    child: _FooterButton(
                      label: 'Delete',
                      onPressed: _delete,
                      color: Colors.red,
                      isOutlined: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _FooterButton(
                    label: 'Save Draft',
                    onPressed: _saveDraft,
                    color: tealGreen,
                    isOutlined: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FooterButton(
                    label: 'Submit',
                    onPressed: _submit,
                    color: tealGreen,
                    isOutlined: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      builder: (context, child) {
        final ThemeData base = Theme.of(context);
        return Theme(
          data: base.copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4db1b3),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4db1b3),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateCtrl.text = _format(picked);
      });
    }
  }

  String _format(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day.toString().padLeft(2, '0')}-${months[d.month - 1]}-${d.year}';
  }

  void _showSnack(String message, {Color backgroundColor = Colors.orange}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  bool _validateTourPlan() {
    if (_dateCtrl.text.trim().isEmpty) {
      _showSnack('⚠ Select a tour plan date');
      return false;
    }
    if (_clusters.isEmpty) {
      _showSnack('⚠ Select at least one cluster/city');
      return false;
    }
    if (_customers.isEmpty) {
      _showSnack('⚠ Select at least one customer');
      return false;
    }
    if (_calls.isEmpty) {
      _showSnack('⚠ Add at least one call before saving');
      return false;
    }

    for (int i = 0; i < _calls.length; i++) {
      final call = _calls[i];
      final callLabel = 'call ${i + 1}';

      if ((call.customer ?? '').trim().isEmpty) {
        _showSnack('⚠ Select customer for $callLabel');
        return false;
      }
      if ((call.purpose ?? '').trim().isEmpty) {
        _showSnack('⚠ Select purpose for $callLabel');
        return false;
      }
      if ((call.samplesToDistribute ?? '').trim().isEmpty) {
        _showSnack('⚠ Enter samples to distribute for $callLabel');
        return false;
      }
    }

    return true;
  }

  Future<bool> _saveDraftInternal({bool popOnSuccess = true}) async {
    if (!_validateTourPlan()) {
      return false;
    }

    if (widget.entry != null) {
      final updated = widget.entry!.copyWith(
        date: _date,
        cluster: _clusters.isNotEmpty ? _clusters.first : widget.entry!.cluster,
        customer: _customers.isNotEmpty ? _customers.first : widget.entry!.customer,
        status: domain.TourPlanEntryStatus.draft,
      );
      await _repo.update(updated);
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Draft updated successfully',
          type: ToastType.success,
          duration: const Duration(seconds: 3),
        );
        if (popOnSuccess) {
          Navigator.of(context).pop();
        }
      }
      return true;
    }

    // Get employee details from UserStore
    final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final int? employeeId = userStore?.userDetail?.employeeId;
    final String? employeeName = userStore?.userDetail?.employeeName;

    if (employeeId == null || employeeName == null) {
      _showSnack('⚠ User information not available. Please login again.');
      return false;
    }

    for (final c in _customers) {
      await _repo.create(CreateTourPlanParams(
        date: _date,
        clusters: _clusters.toList(),
        customers: [c],
        employeeId: employeeId.toString(),
        employeeName: employeeName,
        callDetailsByCustomer: {c: const domain.TourPlanCallDetails(purposes: <String>[])},
      ));
    }

    if (mounted) {
      ToastMessage.show(
        context,
        message: 'Draft saved successfully',
        type: ToastType.success,
        duration: const Duration(seconds: 3),
      );
      if (popOnSuccess) {
        Navigator.of(context).pop();
      }
    }
    return true;
  }

  Future<void> _saveDraft() async {
    await _saveDraftInternal(popOnSuccess: true);
  }

  Future<void> _submit() async {
    if (widget.entry != null) {
      if (!_validateTourPlan()) {
        return;
      }
      await _repo.submitForApproval([widget.entry!.id]);
      if (mounted) {
        ToastMessage.show(
          context,
          message: 'Submitted for approval',
          type: ToastType.success,
          duration: const Duration(seconds: 3),
        );
        Navigator.of(context).pop();
      }
      return;
    }
    // Create drafts for selected customers, then submit all for this date
    final draftSaved = await _saveDraftInternal(popOnSuccess: false);
    if (!draftSaved) {
      return;
    }
    // Get employee ID from UserStore for listing
    final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final int? employeeId = userStore?.userDetail?.employeeId;
    
    if (employeeId == null) {
      _showSnack('⚠ User information not available. Please login again.');
      return;
    }
    
    final items = await _repo.listMonth(month: DateTime(_date.year, _date.month, 1), employeeId: employeeId.toString());
    final ids = items.where((e) => e.date.year == _date.year && e.date.month == _date.month && e.date.day == _date.day).map((e) => e.id).toList();
    if (ids.isNotEmpty) {
      await _repo.submitForApproval(ids);
    }
    if (mounted) {
      ToastMessage.show(
        context,
        message: 'Submitted for approval',
        type: ToastType.success,
        duration: const Duration(seconds: 3),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    if (widget.entry == null) return;
    await _repo.delete(widget.entry!.id);
    if (mounted) {
      ToastMessage.show(
        context,
        message: 'Tour plan deleted',
        type: ToastType.success,
        duration: const Duration(seconds: 3),
      );
      Navigator.of(context).pop();
    }
  }
}

class _CallModel {
  _CallModel({
    required this.dateLabel, 
    required this.status,
    this.customer,
    this.purpose,
    this.productsToDiscuss,
    this.samplesToDistribute,
    this.remarks,
  });
  String dateLabel;
  String status;
  String? customer;
  String? purpose;
  String? productsToDiscuss;
  String? samplesToDistribute;
  String? remarks;
}

class _CallCard extends StatefulWidget {
  const _CallCard({
    super.key,
    required this.index,
    required this.model,
    required this.purposeOptions,
    this.isLoadingPurpose = false,
    required this.onRemove,
    required this.tealGreen,
    required this.lightMint,
  });

  final int index;
  final _CallModel model;
  final List<String> purposeOptions;
  final bool isLoadingPurpose;
  final VoidCallback onRemove;
  final Color tealGreen;
  final Color lightMint;

  @override
  State<_CallCard> createState() => _CallCardState();
}

class _CallCardState extends State<_CallCard> {
  late TextEditingController _customerCtrl;
  late TextEditingController _purposeCtrl;
  late TextEditingController _productsCtrl;
  late TextEditingController _samplesCtrl;
  late TextEditingController _remarksCtrl;

  @override
  void initState() {
    super.initState();
    _customerCtrl = TextEditingController(text: widget.model.customer ?? '');
    _purposeCtrl = TextEditingController(text: widget.model.purpose ?? '');
    _productsCtrl = TextEditingController(text: widget.model.productsToDiscuss ?? '');
    _samplesCtrl = TextEditingController(text: widget.model.samplesToDistribute ?? '');
    _remarksCtrl = TextEditingController(text: widget.model.remarks ?? '');
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _purposeCtrl.dispose();
    _productsCtrl.dispose();
    _samplesCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.tealGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.phone_in_talk_rounded,
                  color: widget.tealGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${widget.model.dateLabel} | Call ${widget.index + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.lightMint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.model.status,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.tealGreen,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const Divider(height: 32),

          // Customer
          _Labeled(
            label: 'Customer',
            isRequired: true,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: SingleSelectDropdown(
                options: const ['Apollo Hospital', 'Fortis Healthcare', 'Medanta Clinic'],
                value: widget.model.customer,
                hintText: 'Select customer',
                onChanged: (v) {
                  setState(() {
                    widget.model.customer = v;
                    _customerCtrl.text = v ?? '';
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Purpose
          _Labeled(
            label: 'Purpose of Visit',
            isRequired: true,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: SingleSelectDropdown(
                options: widget.purposeOptions,
                value: widget.model.purpose,
                hintText: widget.isLoadingPurpose
                    ? 'Loading purpose...'
                    : widget.purposeOptions.isEmpty
                        ? 'Select purpose'
                        : 'Select purpose (${widget.purposeOptions.length} options)',
                onChanged: (v) {
                  setState(() {
                    widget.model.purpose = v;
                    _purposeCtrl.text = v ?? '';
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Products
          _Labeled(
            label: 'Products to Discuss',
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: TextField(
                controller: _productsCtrl,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter products to discuss',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                onChanged: (v) => widget.model.productsToDiscuss = v,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Samples
          _Labeled(
            label: 'Samples to Distribute',
            isRequired: true,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: TextField(
                controller: _samplesCtrl,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter samples to distribute',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                onChanged: (v) => widget.model.samplesToDistribute = v,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Remarks
          _Labeled(
            label: 'Notes / Remarks',
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: TextField(
                controller: _remarksCtrl,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter notes or remarks',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                onChanged: (v) => widget.model.remarks = v,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({this.label, required this.child, this.isRequired = false});
  final String? label;
  final Widget child;
  final bool isRequired;

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
                color: Colors.grey[600],
                letterSpacing: 0.1,
              ),
              children: isRequired
                  ? [
                      TextSpan(
                        text: ' *',
                        style: GoogleFonts.inter(
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 8),
        ],
        child,
      ],
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.label,
    required this.onPressed,
    required this.color,
    this.isOutlined = false,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;
  final bool isOutlined;

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

List<String> _customerOptionsForClusters(Set<String> clusters) {
  // Demo data mapping; in real app, fetch from API based on selected clusters
  const Map<String, List<String>> byCluster = {
    'Andheri East': ['Apollo Hospital','Sunrise Clinic'],
    'Bandra West': ['Fortis Healthcare','Sea View Clinic'],
    'Powai': ['Medanta Clinic','Hiranandani Hospital'],
    'Goregaon East': ['City Care Center'],
    'Adhoc': ['Any Customer'],
  };
  final Set<String> all = <String>{};
  for (final c in clusters) {
    all.addAll(byCluster[c] ?? const <String>[]);
  }
  return all.toList()..sort();
}

