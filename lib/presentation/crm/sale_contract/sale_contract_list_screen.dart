import 'package:flutter/material.dart';

class SaleContractListScreen extends StatefulWidget {
  const SaleContractListScreen({super.key});

  @override
  State<SaleContractListScreen> createState() => _SaleContractListScreenState();
}

class _SaleContractListScreenState extends State<SaleContractListScreen> {
  String? _customer;
  String? _status;
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _FilterPill(
              icon: Icons.date_range,
              label: _range == null
                  ? 'Date Range'
                  : '${_fmt(_range!.start)} — ${_fmt(_range!.end)}',
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(now.year - 3, 1, 1),
                  lastDate: DateTime(now.year + 3, 12, 31),
                );
                if (picked != null) setState(() => _range = picked);
              },
            ),
            _FilterPill(
              icon: Icons.person_outline,
              label: _customer ?? 'Customer',
              onTap: () async {
                final String? value = await _pickFromList(
                  context,
                  title: 'Select Customer',
                  options: const ['Apollo Hospital','Fortis Healthcare','Medanta Clinic'],
                  selected: _customer,
                );
                if (value != null) setState(() => _customer = value);
              },
            ),
            _FilterPill(
              icon: Icons.verified_outlined,
              label: _status ?? 'Status',
              onTap: () async {
                final String? value = await _pickFromList(
                  context,
                  title: 'Select Status',
                  options: const ['Draft','Pending','Approved','Rejected'],
                  selected: _status,
                );
                if (value != null) setState(() => _status = value);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < 8; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text('SC-2025-${1000 + i}'),
                subtitle: const Text('Customer: Apollo Hospital • 22 Aug 2025'),
                trailing: _StatusBadge(status: i % 4 == 0 ? 'Draft' : i % 4 == 1 ? 'Pending' : i % 4 == 2 ? 'Approved' : 'Rejected'),
                onTap: () {},
              ),
            ),
          ),
      ],
    );
  }

  static String _fmt(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.icon, required this.label, this.onTap});
  final IconData icon; final String label; final VoidCallback? onTap;
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
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      'Approved' => const Color(0xFF2DBE64),
      'Pending' => const Color(0xFFFFA41C),
      'Rejected' => const Color(0xFFFF6A21),
      _ => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.4)),
      ),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
    );
  }
}

Future<String?> _pickFromList(BuildContext context, {required String title, required List<String> options, String? selected}) async {
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


