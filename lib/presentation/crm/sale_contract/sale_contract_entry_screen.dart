import 'package:flutter/material.dart';
import 'package:boilerplate/core/widgets/app_buttons.dart';
import 'package:boilerplate/core/widgets/app_dropdowns.dart';
import 'package:boilerplate/core/widgets/date_picker_field.dart';

class SaleContractEntryScreen extends StatefulWidget {
  const SaleContractEntryScreen({super.key});

  @override
  State<SaleContractEntryScreen> createState() => _SaleContractEntryScreenState();
}

class _SaleContractEntryScreenState extends State<SaleContractEntryScreen> {
  String? _customer;
  String? _address;
  String? _salesRep;
  String? _distributor;
  DateTime _date = DateTime.now();

  final List<_ItemRowModel> _items = <_ItemRowModel>[
    _ItemRowModel(),
  ];

  double get _totalAmount => _items.fold(0.0, (sum, it) => sum + it.amount);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final InputBorder commonBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.black.withOpacity(.10)),
    );
    final screenTheme = theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: const Color(0xFFF5F6F8),
        border: commonBorder,
        enabledBorder: commonBorder,
        focusedBorder: commonBorder.copyWith(
          borderSide: BorderSide(color: Colors.black.withOpacity(.20)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Sale Contract Entry')),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Theme(
          data: screenTheme,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Card(
                      color: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Header', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, c) {
                                final bool stack = c.maxWidth < 720;
                                final dateField = _Labeled(child: DatePickerField(initialDate: _date, label: 'Date', onChanged: (d) => setState(() => _date = d)));
                                final custField = _Labeled(
                                  label: 'Customer',
                                  child: SingleSelectDropdown(
                                    options: const ['Apollo Hospital','Fortis Healthcare','Medanta Clinic'],
                                    value: _customer,
                                    hintText: 'Select customer',
                                    onChanged: (v) => setState(() {
                                      _customer = v;
                                      _distributor = _customer == null ? null : 'Default Distributor for $_customer';
                                      _address = _customer == null ? null : 'Address for $_customer';
                                    }),
                                  ),
                                );
                                final repField = _Labeled(
                                  label: 'Sales Rep',
                                  child: SingleSelectDropdown(
                                    options: const ['John Carter','Meera Joshi','Alex Singh'],
                                    value: _salesRep,
                                    hintText: 'Select sales rep',
                                    onChanged: (v) => setState(() => _salesRep = v),
                                  ),
                                );
                                if (stack) {
                                  return Column(children: [dateField, const SizedBox(height: 12), custField, const SizedBox(height: 12), repField]);
                                }
                                return Row(children: [Expanded(child: dateField), const SizedBox(width: 12), Expanded(child: custField), const SizedBox(width: 12), Expanded(child: repField)]);
                              },
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, c) {
                                final bool stack = c.maxWidth < 720;
                                final addrField = _Labeled(
                                  label: 'Customer Address',
                                  child: TextFormField(
                                    readOnly: true,
                                    maxLines: 2,
                                    decoration: InputDecoration(hintText: _address ?? 'Auto-filled'),
                                  ),
                                );
                                final distField = _Labeled(label: 'Distributor', child: TextFormField(readOnly: true, decoration: InputDecoration(hintText: _distributor ?? 'Auto-filled')));
                                if (stack) {
                                  return Column(children: [addrField, const SizedBox(height: 12), distField]);
                                }
                                return Row(children: [Expanded(child: addrField), const SizedBox(width: 12), Expanded(child: distField)]);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Item details
                    Card(
                      color: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text('Items', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                                AppTonalButton(label: '+ Add Item', onPressed: _addItem),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ..._items.asMap().entries.map((e) => _ItemRow(
                                  key: ValueKey('item_${e.key}'),
                                  model: e.value,
                                  onRemove: () => setState(() => _items.removeAt(e.key)),
                                  onChanged: () => setState(() {}),
                                )),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text('Total Amount: ₹${_totalAmount.toStringAsFixed(2)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: const [
                        Expanded(child: AppTonalButton(label: 'Save as Draft')),
                        SizedBox(width: 12),
                        Expanded(child: AppPrimaryButton(label: 'Submit for Approval')),
                      ],
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

  void _addItem() {
    setState(() => _items.add(_ItemRowModel()));
  }
}

class _ItemRowModel {
  String? item;
  DateTime? requiredBy;
  int qty = 0;
  double rate = 0.0;
  int bonusQty = 0;
  int addlBonusQty = 0;
  String notes = '';
  String manufacturer = '';
  String uom = 'Box';
  int availableQty = 0;

  double get amount => qty * rate;
}

class _ItemRow extends StatefulWidget {
  const _ItemRow({super.key, required this.model, required this.onRemove, required this.onChanged});
  final _ItemRowModel model;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleSelectDropdown(
                  options: const ['Item A','Item B','Item C'],
                  value: widget.model.item,
                  hintText: 'Item',
                  onChanged: (v) => setState(() {
                    widget.model.item = v;
                    // Demo auto-populate
                    widget.model.manufacturer = (v ?? '').isEmpty ? '' : 'Manufacturer of $v';
                    widget.model.rate = (v == 'Item A') ? 120.0 : (v == 'Item B') ? 80.0 : 50.0;
                    widget.model.availableQty = (v == 'Item A') ? 150 : 60;
                    widget.onChanged();
                  }),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: widget.onRemove, icon: const Icon(Icons.delete_outline, color: Colors.redAccent))
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MiniField(label: 'Required by Date', child: DatePickerField(initialDate: DateTime.now(), onChanged: (d) => setState(() { widget.model.requiredBy = d; widget.onChanged(); }))),
              _MiniNumber(label: 'Qty', value: widget.model.qty.toString(), onChanged: (v) => setState(() { widget.model.qty = int.tryParse(v) ?? 0; widget.onChanged(); })),
              _MiniNumber(label: 'Rate', value: widget.model.rate.toStringAsFixed(2), onChanged: (v) => setState(() { widget.model.rate = double.tryParse(v) ?? 0; widget.onChanged(); })),
              _MiniRead(label: 'Amount', value: '₹${widget.model.amount.toStringAsFixed(2)}'),
              _MiniNumber(label: 'Bonus Qty', value: widget.model.bonusQty.toString(), onChanged: (v) => setState(() { widget.model.bonusQty = int.tryParse(v) ?? 0; })),
              _MiniNumber(label: 'Addl. Bonus Qty', value: widget.model.addlBonusQty.toString(), onChanged: (v) => setState(() { widget.model.addlBonusQty = int.tryParse(v) ?? 0; })),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MiniRead(label: 'Manufacturer', value: widget.model.manufacturer.isEmpty ? '-' : widget.model.manufacturer, width: 240),
              _MiniRead(label: 'UoM', value: widget.model.uom, width: 140),
              _MiniRead(label: 'Available Qty', value: '${widget.model.availableQty}', width: 160),
            ],
          ),
          const SizedBox(height: 10),
          _MiniField(
            label: 'Notes/Remarks',
            child: TextFormField(
              maxLines: 3,
              onChanged: (v) => setState(() => widget.model.notes = v),
              decoration: const InputDecoration(hintText: 'Enter notes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField({required this.label, required this.child, this.width});
  final String label; final Widget child; final double? width;
  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        child,
      ],
    );
    return width == null ? content : SizedBox(width: width, child: content);
  }
}

class _MiniRead extends StatelessWidget {
  const _MiniRead({required this.label, required this.value, this.width});
  final String label; final String value; final double? width;
  @override
  Widget build(BuildContext context) {
    return _MiniField(
      label: label,
      width: width,
      child: TextFormField(readOnly: true, decoration: InputDecoration(hintText: value)),
    );
  }
}

class _MiniNumber extends StatelessWidget {
  const _MiniNumber({required this.label, required this.value, required this.onChanged, this.width});
  final String label; final String value; final ValueChanged<String> onChanged; final double? width;
  @override
  Widget build(BuildContext context) {
    return _MiniField(
      label: label,
      width: width,
      child: TextFormField(
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        decoration: InputDecoration(hintText: value),
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


