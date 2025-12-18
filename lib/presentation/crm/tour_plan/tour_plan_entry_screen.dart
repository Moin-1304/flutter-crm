import 'package:flutter/material.dart';
import 'package:boilerplate/core/widgets/app_buttons.dart';
import 'package:boilerplate/core/widgets/app_form_fields.dart';
import 'package:boilerplate/core/widgets/app_dropdowns.dart';
import 'package:boilerplate/domain/entity/tour_plan/tour_plan.dart' as domain;
import 'package:boilerplate/domain/repository/tour_plan/tour_plan_repository.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/core/widgets/toast_message.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
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
    } else {
      // For new entries, add one empty call
      _calls.add(_CallModel(dateLabel: _format(_date), status: 'Draft'));
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.entry == null ? 'New Tour Plan' : 'Edit Tour Plan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Tour Plan Date',
              hint: 'dd-MMM-yyyy',
              controller: _dateCtrl,
              readOnly: true,
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            _Labeled(
              label: 'Cluster / City (multi-select)',
              child: MultiSelectDropdown(
                options: const ['Andheri East','Bandra West','Powai','Goregaon East','Adhoc'],
                selectedValues: _clusters,
                hintText: 'Select one or more clusters/cities',
                onChanged: (values) => setState(() {
                  _clusters
                    ..clear()
                    ..addAll(values);
                  // Reset customers if clusters changed
                  _customers.clear();
                }),
              ),
            ),
            const SizedBox(height: 12),
            _Labeled(
              label: 'Customer (multi-select)',
              child: MultiSelectDropdown(
                options: _customerOptionsForClusters(_clusters),
                selectedValues: _customers,
                hintText: _clusters.isEmpty ? 'Select clusters first' : 'Select one or more customers',
                onChanged: (values) => setState(() {
                  _customers
                    ..clear()
                    ..addAll(values);
                }),
              ),
            ),
            const SizedBox(height: 12),
            ..._calls.asMap().entries.map((e) => _CallCard(
                  key: ValueKey('call_${e.key}_${e.value.hashCode}'),
                  index: e.key,
                  model: e.value,
                  onRemove: () => setState(() => _calls.removeAt(e.key)),
                )),
            const SizedBox(height: 12),
            AppOutlinedButton(
              onPressed: () => setState(() => _calls.add(_CallModel(dateLabel: _format(_date), status: 'Draft'))),
              label: '+ Add Another Call',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
                  Text('Manager Approval', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 6),
                  Text('Status: Not Submitted'),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              if (widget.entry != null) ...[
                Expanded(
                  child: AppTonalButton(
                    label: 'Delete',
                    onPressed: _delete,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(child: AppTonalButton(label: 'Save as Draft', onPressed: _saveDraft)),
              const SizedBox(width: 12),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    filledButtonTheme: FilledButtonThemeData(
                      style: FilledButton.styleFrom(foregroundColor: Colors.white),
                    ),
                  ),
                  child: AppPrimaryButton(label: 'Submit for Approval', onPressed: _submit),
                ),
              ),
            ]),
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
  const _CallCard({super.key, required this.index, required this.model, required this.onRemove});
  final int index; final _CallModel model; final VoidCallback onRemove;
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(
            children: [
              Expanded(
                child: Text('${widget.model.dateLabel} | Call ${widget.index + 1}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.yellow[100], borderRadius: BorderRadius.circular(8)),
                child: Text(widget.model.status, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              TextButton(onPressed: widget.onRemove, child: const Text('Remove', style: TextStyle(color: Colors.red))),
            ],
          ),
          const SizedBox(height: 8),
          _Labeled(
            label: 'Customer',
            child: SingleSelectDropdown(
              options: const ['Apollo Hospital','Fortis Healthcare','Medanta Clinic'],
              value: widget.model.customer,
              hintText: 'Select customer',
              onChanged: (v) {
                widget.model.customer = v;
                _customerCtrl.text = v ?? '';
              },
            ),
          ),
          const SizedBox(height: 8),
          _Labeled(
            label: 'Purpose of Visit',
            child: SingleSelectDropdown(
              options: const ['Field Visit','Product Detailing','Follow-up'],
              value: widget.model.purpose,
              hintText: 'Select purpose',
              onChanged: (v) {
                widget.model.purpose = v;
                _purposeCtrl.text = v ?? '';
              },
            ),
          ),
          const SizedBox(height: 8),
          _Labeled(
            label: 'Products to Discuss',
            child: TextField(
              controller: _productsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter products to discuss',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => widget.model.productsToDiscuss = v,
            ),
          ),
          const SizedBox(height: 8),
          _Labeled(
            label: 'Samples to Distribute',
            child: TextField(
              controller: _samplesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter samples to distribute',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => widget.model.samplesToDistribute = v,
            ),
          ),
          const SizedBox(height: 8),
          _Labeled(
            label: 'Notes/Remarks',
            child: TextField(
              controller: _remarksCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter notes or remarks',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => widget.model.remarks = v,
            ),
          ),
        ]),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({this.label, required this.child});
  final String? label; final Widget child;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [if (label != null) ...[Text(label!, style: Theme.of(context).textTheme.labelMedium), const SizedBox(height: 6)], child]);
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

