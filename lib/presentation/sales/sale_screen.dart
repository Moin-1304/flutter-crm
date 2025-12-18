import 'package:flutter/material.dart';

import '../../utils/routes/routes.dart';

class SaleOrderScreen extends StatefulWidget {
  const SaleOrderScreen({super.key});

  @override
  State<SaleOrderScreen> createState() => _SaleOrderScreenState();
}

class _SaleOrderScreenState extends State<SaleOrderScreen> {
  final List<String> _customers = <String>[
    'All Customers',
    'Dr. Meera Joshi',
    'Sunrise Clinic',
    'Dr. Rajesh Shetty',
    'Dr. Amit Deshmukh',
    'Dr. Sneha Kulkarni',
    'Apollo Pharmacy',
  ];

  final List<String> _statuses = <String>['Status', 'Open', 'Closed'];

  String _selectedCustomer = 'All Customers';
  String _selectedStatus = 'Status';
  String _searchText = '';

  DateTime? _fromDate;
  DateTime? _toDate;

  final List<_SaleOrder> _allOrders = <_SaleOrder>[
    _SaleOrder(
      id: 'SC-2509-034',
      date: DateTime(2025, 9, 18),
      number: 'SO-1001',
      customer: 'Dr. Meera Joshi',
      qty: 12,
      amount: 2400,
      status1:
          _StatusChip('Pending', Colors.amber.shade100, Colors.amber.shade800),
      status2: _StatusChip(
          'Delivered', Colors.green.shade100, Colors.green.shade800),
    ),
    _SaleOrder(
      id: 'SO-1000',
      date: DateTime(2025, 9, 17),
      number: 'SO-1000',
      customer: 'Sunrise Clinic',
      qty: 8,
      amount: 1600,
      status1:
          _StatusChip('Approved', Colors.green.shade100, Colors.green.shade800),
      status2: _StatusChip(
          'Delivered', Colors.green.shade100, Colors.green.shade800),
    ),
    _SaleOrder(
      id: 'SO-0999',
      date: DateTime(2025, 9, 16),
      number: 'SO-0999',
      customer: 'Dr. Rajesh Shetty',
      qty: 5,
      amount: 1000,
      status1:
          _StatusChip('Draft', Colors.purple.shade100, Colors.purple.shade800),
      status2:
          _StatusChip('Pending', Colors.grey.shade300, Colors.grey.shade800),
    ),
  ];

  List<_SaleOrder> get _filteredOrders {
    return _allOrders.where((o) {
      final matchesCustomer = _selectedCustomer == 'All Customers' ||
          o.customer == _selectedCustomer;
      final matchesStatus = _selectedStatus == 'Status'
          ? true
          : (_selectedStatus == 'Open'
              ? (o.status2.label == 'Pending' ||
                  o.status1.label == 'Draft' ||
                  o.status1.label == 'Pending')
              : (o.status1.label == 'Approved' ||
                  o.status2.label == 'Delivered'));
      final matchesSearch = _searchText.trim().isEmpty ||
          o.number.toLowerCase().contains(_searchText.toLowerCase()) ||
          o.customer.toLowerCase().contains(_searchText.toLowerCase());
      final matchesFrom =
          _fromDate == null || !o.date.isBefore(_stripTime(_fromDate!));
      final matchesTo =
          _toDate == null || !o.date.isAfter(_stripTime(_toDate!));
      return matchesCustomer &&
          matchesStatus &&
          matchesSearch &&
          matchesFrom &&
          matchesTo;
    }).toList();
  }

  static DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  String _formatDate(DateTime d) {
    const month = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final dd = d.day.toString().padLeft(2, '0');
    final mmm = month[d.month - 1];
    final yy = (d.year % 100).toString().padLeft(2, '0');
    return '$dd-$mmm-$yy';
  }

  String _formatCurrencyINR(num value) {
// Simple grouping for thousands; for full locale use intl.
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (i > 0 && ((count == 3) || (count > 3 && (count - 3) % 2 == 0))) {
        buf.write(',');
      }
    }
    final grouped = buf.toString().split('').reversed.join();
    return '₹$grouped';
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final initial = _fromDate ?? now.subtract(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final initial = _toDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  @override
  void initState() {
    super.initState();
// Defaults similar to HTML: last month to today
    final today = DateTime.now();
    final lastMonth = DateTime(today.year, today.month - 1, today.day);
    _fromDate = lastMonth;
    _toDate = today;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 600;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            centerTitle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.blue),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'Back',
            ),
            titleSpacing: 0,
            title: Text('Sales Orders', style: TextStyle(color: Colors.black,fontSize: isTablet? 24:20,fontWeight: FontWeight.w600)),
            actions: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                ),
                onPressed: () => _openSaleOrderDetail(context, null),
                icon: const Icon(Icons.add),
                label:  Text('Raise New Sale Order', style: TextStyle(fontSize: isTablet? 16:12,fontWeight: FontWeight.w600))
              ),

              const SizedBox(width: 12),
            ],
          ),
          body: Container(
            color: const Color(0xFFF5F5F5),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: isTablet ? 16 : 8),
                  _buildFilters(isTablet),
                  const SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(isTablet ? 16 : 5),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: EdgeInsets.all(isTablet ? 16 : 8),
                        child: isTablet ? _buildTableView() : _buildCardListView(),
                      ),
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 8), // Add bottom padding
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters(bool isTablet) {
    final filterRow = Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: _buildDropdown(
            label: 'Customer',
            value: _selectedCustomer,
            items: _customers,
            onChanged: (v) =>
                setState(() => _selectedCustomer = v ?? _selectedCustomer),
          ),
        ),
        _buildDateRangePicker(),
        SizedBox(
          width: 160,
          child: _buildDropdown(
            label: 'Status',
            value: _selectedStatus,
            items: _statuses,
            onChanged: (v) =>
                setState(() => _selectedStatus = v ?? _selectedStatus),
          ),
        ),
        SizedBox(
          width: 260,
          child: _buildSearch(),
        ),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: filterRow,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(text: label),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: Colors.white,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: Colors.blue.shade200, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangePicker() {
    final fromText = _fromDate == null ? 'From' : _formatDate(_fromDate!);
    final toText = _toDate == null ? 'To' : _formatDate(_toDate!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(text: 'Date Range'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DateChip(text: fromText, onTap: _pickFromDate),
            const SizedBox(width: 8),
            _DateChip(text: toText, onTap: _pickToDate),
          ],
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(text: 'Search Sale Orders'),
        TextField(
          onChanged: (v) => setState(() => _searchText = v),
          decoration: InputDecoration(
            hintText: 'Search sale orders...',
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: Colors.blue.shade200, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardListView() {
    final orders = _filteredOrders;
    if (orders.isEmpty) {
      return const Center(child: Text('No sale orders found'));
    }
    return Column(
      children: orders.asMap().entries.map((entry) {
        final index = entry.key;
        final o = entry.value;
        return Column(
          children: [
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openSaleOrderDetail(context, o.id),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text(_formatDate(o.date),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                          Text(_formatCurrencyINR(o.amount),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(o.number, style: TextStyle(color: Colors.grey.shade700)),
                      const SizedBox(height: 4),
                      Text(o.customer,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Qty: ${o.qty}',
                              style: TextStyle(color: Colors.grey.shade700)),
                          const Spacer(),
                          _StatusPill(chip: o.status1),
                          const SizedBox(width: 6),
                          _StatusPill(chip: o.status2),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (index < orders.length - 1) const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTableView() {
    final orders = _filteredOrders;
    if (orders.isEmpty) {
      return const Center(child: Text('No sale orders found'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.lightBlue.shade50), // background
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
        showCheckboxColumn: false,
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Sale Order #')),
          DataColumn(label: Text('Customer')),
          DataColumn(label: Text('Qty'), numeric: true),
          DataColumn(label: Text('Amount'), numeric: true),
          DataColumn(label: Text('')),
          DataColumn(label: Text('')),
        ],
        rows: orders.map((o) {
          return DataRow(
            cells: [
              DataCell(Text(_formatDate(o.date))),
              DataCell(Text(o.number)),
              DataCell(Text(o.customer)),
              DataCell(Align(
                  alignment: Alignment.centerRight,
                  child: Text(o.qty.toString()))),
              DataCell(Align(
                  alignment: Alignment.centerRight,
                  child: Text(_formatCurrencyINR(o.amount)))),
              DataCell(_StatusPill(chip: o.status1)),
              DataCell(_StatusPill(chip: o.status2)),
            ],
            onSelectChanged: (_) => _openSaleOrderDetail(context, o.id),
          );
        }).toList(),
      ),
    );
  }

  void _openSaleOrderDetail(BuildContext context, String? id) {
    Navigator.pushNamed(context, Routes.saleCreate);
  }
}

class _DateChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _DateChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child:
              Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.w600)),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Profile',
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        const PopupMenuItem(value: 'tour_plan', child: Text('Tour Plan')),
        const PopupMenuItem(value: 'dcr', child: Text('DCR')),
        const PopupMenuItem(value: 'deviation', child: Text('Deviation')),
        const PopupMenuDivider(),
        const PopupMenuItem(
            value: 'tour_plan_review', child: Text('Tour Plan Review')),
        const PopupMenuItem(value: 'dcr_review', child: Text('DCR Review')),
        const PopupMenuItem(
            value: 'deviation_review', child: Text('Deviation Review')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'attendance', child: Text('Punch In / Out')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'logout', child: Text('Logout')),
      ],
      child: CircleAvatar(
        backgroundColor: Colors.grey.shade300,
        child: const Text('JD', style: TextStyle(color: Colors.black)),
      ),
      onSelected: (v) {
// Hook up routes as needed
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Selected: $v')));
      },
    );
  }
}

class _SaleOrder {
  final String id;
  final DateTime date;
  final String number;
  final String customer;
  final int qty;
  final num amount;
  final _StatusChip status1;
  final _StatusChip status2;

  _SaleOrder({
    required this.id,
    required this.date,
    required this.number,
    required this.customer,
    required this.qty,
    required this.amount,
    required this.status1,
    required this.status2,
  });
}

class _StatusChip {
  final String label;
  final Color bg;
  final Color fg;

  _StatusChip(this.label, this.bg, this.fg);
}

class _StatusPill extends StatelessWidget {
  final _StatusChip chip;
  const _StatusPill({required this.chip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chip.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(chip.label,
          style: TextStyle(color: chip.fg, fontWeight: FontWeight.w700)),
    );
  }
}
