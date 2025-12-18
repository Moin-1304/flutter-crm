import 'package:flutter/material.dart';

class SaleOrderListScreen extends StatefulWidget {
  const SaleOrderListScreen({super.key});
  @override
  State<SaleOrderListScreen> createState() => _SaleOrderListScreenState();
}

class _SaleOrderListScreenState extends State<SaleOrderListScreen> {
  final searchCtrl = TextEditingController();
  final fromCtrl = TextEditingController(text: '24-Aug-25');
  final toCtrl = TextEditingController(text: '24-Sep-25');

  String customer = 'Dr. Meera Joshi';
  String status = '';

  final orders = <Map<String, String>>[
    {
      'date': '18-Sep-2025',
      'order': 'SO-1001',
      'customer': 'Dr. Meera Joshi',
      'qty': '12',
      'amount': '₹2,400',
      'status': 'Pending',
      'delivery': 'Delivered',
    },
    {
      'date': '17-Sep-2025',
      'order': 'SO-1000',
      'customer': 'Sunrise Clinic',
      'qty': '8',
      'amount': '₹1,600',
      'status': 'Approved',
      'delivery': 'Delivered',
    },
    {
      'date': '16-Sep-2025',
      'order': 'SO-0999',
      'customer': 'Dr. Rajesh Shetty',
      'qty': '5',
      'amount': '₹1,000',
      'status': 'Draft',
      'delivery': 'Pending',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header + Filters
            SaleOrdersHeader(
              onRaiseOrder: () {
                // TODO: Navigate to form
              },
              searchCtrl: searchCtrl,
              fromCtrl: fromCtrl,
              toCtrl: toCtrl,
              customers: const [
                'Dr. Meera Joshi',
                'Sunrise Clinic',
                'Dr. Rajesh Shetty'
              ],
              statuses: const ['All', 'Pending', 'Approved', 'Draft', 'Delivered'],
              selectedCustomer: customer,
              selectedStatus: status,
              onCustomerChanged: (v) => setState(() => customer = v ?? ''),
              onStatusChanged: (v) => setState(() => status = v ?? ''),
            ),
            // Table/List
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              child: _ResponsiveOrdersTable(
                data: orders,
                isTablet: isTablet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SaleOrdersHeader extends StatelessWidget {
  final VoidCallback onRaiseOrder;
  final TextEditingController searchCtrl;
  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final List<String> customers;
  final List<String> statuses;
  final String selectedCustomer;
  final String selectedStatus;
  final ValueChanged<String?> onCustomerChanged;
  final ValueChanged<String?> onStatusChanged;

  const SaleOrdersHeader({
    super.key,
    required this.onRaiseOrder,
    required this.searchCtrl,
    required this.fromCtrl,
    required this.toCtrl,
    required this.customers,
    required this.statuses,
    required this.selectedCustomer,
    required this.selectedStatus,
    required this.onCustomerChanged,
    required this.onStatusChanged,
  });

  OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color, width: 1.2),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 700;

    const borderColor = Color(0xFFCED4DA); // subtle gray to match HTML
    final placeholder = theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF9AA0A6));
    const inputPad = EdgeInsets.symmetric(horizontal: 12, vertical: 10);

    final customerField = SizedBox(
      width: isTablet ? 260 : double.infinity,
      child: InputDecorator(
        decoration: InputDecoration(
          contentPadding: inputPad,
          enabledBorder: _fieldBorder(borderColor),
          focusedBorder: _fieldBorder(theme.colorScheme.primary),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: selectedCustomer.isEmpty ? null : selectedCustomer,
            hint: Text('Dr. Meera Joshi', style: placeholder),
            items: customers
                .map((c) => DropdownMenuItem(
              value: c,
              child: Text(c),
            ))
                .toList(),
            onChanged: onCustomerChanged,
          ),
        ),
      ),
    );

    final fromField = SizedBox(
      width: 130,
      child: TextField(
        controller: fromCtrl,
        readOnly: true,
        decoration: InputDecoration(
          contentPadding: inputPad,
          labelText: 'From',
          enabledBorder: _fieldBorder(borderColor),
          focusedBorder: _fieldBorder(theme.colorScheme.primary),
          hintText: '24-Aug-25',
          hintStyle: placeholder,
        ),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: now,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            fromCtrl.text =
            '${picked.day.toString().padLeft(2, '0')}-${_mon(picked.month)}-${picked.year}';
          }
        },
      ),
    );

    final toField = SizedBox(
      width: 130,
      child: TextField(
        controller: toCtrl,
        readOnly: true,
        decoration: InputDecoration(
          contentPadding: inputPad,
          labelText: 'To',
          enabledBorder: _fieldBorder(borderColor),
          focusedBorder: _fieldBorder(theme.colorScheme.primary),
          hintText: '24-Sep-25',
          hintStyle: placeholder,
        ),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: now,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            toCtrl.text =
            '${picked.day.toString().padLeft(2, '0')}-${_mon(picked.month)}-${picked.year}';
          }
        },
      ),
    );

    final statusField = SizedBox(
      width: isTablet ? 160 : double.infinity,
      child: InputDecorator(
        decoration: InputDecoration(
          contentPadding: inputPad,
          enabledBorder: _fieldBorder(borderColor),
          focusedBorder: _fieldBorder(theme.colorScheme.primary),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: selectedStatus.isEmpty ? null : selectedStatus,
            hint: Text('Status', style: placeholder),
            items: statuses
                .map((s) => DropdownMenuItem(
              value: s == 'All' ? '' : s,
              child: Text(s),
            ))
                .toList(),
            onChanged: onStatusChanged,
          ),
        ),
      ),
    );

    final searchField = Expanded(
      child: TextField(
        controller: searchCtrl,
        decoration: InputDecoration(
          hintText: 'Search Sale Orders…',
          hintStyle: placeholder,
          contentPadding: inputPad,
          enabledBorder: _fieldBorder(borderColor),
          focusedBorder: _fieldBorder(theme.colorScheme.primary),
          suffixIcon: const Icon(Icons.search, color: Color(0xFF9AA0A6)),
        ),
      ),
    );

    final raiseBtn = FilledButton.icon(
      onPressed: onRaiseOrder,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.add, size: 20),
      label: const Text('Raise New Sale Order'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Sales Orders',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              raiseBtn,
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE9EFFD),
                child: Text('JD', style: theme.textTheme.labelLarge),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Filters
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: LayoutBuilder(
            builder: (context, c) {
              final isTablet = c.maxWidth >= 700;
              final children = <Widget>[
                SizedBox(width: isTablet ? null : double.infinity, child: customerField),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  fromField,
                  const SizedBox(width: 8),
                  toField,
                ]),
                statusField,
                if (isTablet) searchField,
              ];

              return Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: children,
                  ),
                  if (!isTablet) ...[
                    const SizedBox(height: 12),
                    Row(children: [Expanded(child: searchField)]),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ResponsiveOrdersTable extends StatelessWidget {
  final List<Map<String, String>> data;
  final bool isTablet;
  const _ResponsiveOrdersTable({required this.data, required this.isTablet});

  Color _statusColor(String v) {
    switch (v) {
      case 'Pending':
        return Colors.orange;
      case 'Delivered':
        return Colors.green;
      case 'Approved':
        return Colors.blue;
      case 'Draft':
        return Colors.grey;
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    // On small phones, render as cards; on tablets, render a DataTable
    if (!isTablet) {
      return Column(
        children: data.map((o) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv('Date', o['date'] ?? ''),
                  _kv('Sale Order #', o['order'] ?? ''),
                  _kv('Customer', o['customer'] ?? ''),
                  _kv('Qty', o['qty'] ?? ''),
                  _kv('Amount', o['amount'] ?? ''),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _chip(o['status'] ?? '', _statusColor(o['status'] ?? '')),
                      const SizedBox(width: 8),
                      _chip(o['delivery'] ?? '', _statusColor(o['delivery'] ?? '')),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(Colors.grey.shade50),
        columnSpacing: 24,
        horizontalMargin: 16,
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Sale Order #')),
          DataColumn(label: Text('Customer')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Delivery')),
        ],
        rows: data.map((o) {
          return DataRow(
            cells: [
              DataCell(Text(o['date'] ?? '')),
              DataCell(Text(o['order'] ?? '')),
              DataCell(Text(o['customer'] ?? '')),
              DataCell(Text(o['qty'] ?? '')),
              DataCell(Text(o['amount'] ?? '')),
              DataCell(_chip(o['status'] ?? '', _statusColor(o['status'] ?? ''))),
              DataCell(_chip(o['delivery'] ?? '', _statusColor(o['delivery'] ?? ''))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Color(0xFF6B7280)))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

String _mon(int m) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return months[m - 1];
}
