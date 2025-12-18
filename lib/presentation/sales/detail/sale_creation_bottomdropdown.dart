import 'package:flutter/material.dart';

import 'models/sales_product.dart';

void main() {
  runApp(const MaterialApp(
    home: SaleCreationScreen(),
    debugShowCheckedModeBanner: false,
  ));
}
class SaleCreationScreen extends StatefulWidget {
  final String? contractId; // null => New mode, otherwise Edit mode

  const SaleCreationScreen({super.key, this.contractId});

  @override
  State<SaleCreationScreen> createState() => _SaleCreationScreenState();
}

class _SaleCreationScreenState extends State<SaleCreationScreen> {
// Mock master data
  final List<Customer> Customers = const [
    Customer(
        code: 'C001',
        name: 'Dr. Meera Joshi',
        address: '123 Health St, Wellness City, Mumbai - 400001'),
    Customer(
        code: 'C002',
        name: 'Sunrise Clinic',
        address: '21 Park Lane, Pune - 411001'),
    Customer(
        code: 'C003',
        name: 'Apollo Pharmacy',
        address: '402 Marine Drive, Mumbai - 400002'),
  ];

  final List<String> _salesReps = const ['Mr. John Doe', 'Ms. Jane Smith'];

  final List<String> _distributors = const [
    'Wellness Distributors',
    'Pharma Express'
  ];

  final List<Product> Products = const [
    Product(
        id: 'P001',
        name: 'Paracetamol 500mg',
        manufacturer: 'Cipla',
        rate: 200.00,
        uom: 'Box',
        availableQty: 120),
    Product(
        id: 'P002',
        name: 'Aspirin 75mg',
        manufacturer: 'Sun Pharma',
        rate: 150.50,
        uom: 'Strip',
        availableQty: 85),
    Product(
        id: 'P003',
        name: "Cough Syrup",
        manufacturer: "Dr. Reddy's",
        rate: 320.00,
        uom: 'Bottle',
        availableQty: 50),
  ];

// Form state
  late DateTime _contractDate;
  String? _selectedCustomerCode;
  final TextEditingController CustomerAddressController =
      TextEditingController();
  String _selectedSalesRep = 'Mr. John Doe';
  String? _selectedDistributor;

// Items
  final List<_LineItem> _items = [];

  bool get _isEditMode => widget.contractId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadEditModeData(widget.contractId!);
    } else {
      _loadNewModeData();
    }
  }

  @override
  void dispose() {
    CustomerAddressController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _loadEditModeData(String id) {
// Header
    _contractDate = DateTime(2025, 9, 18);
    _selectedCustomerCode = 'C001';
    CustomerAddressController.text =
        '123 Health St, Wellness City, Mumbai - 400001';
    _selectedDistributor = 'Wellness Distributors';
    _selectedSalesRep = _salesReps.first;

// Items
    _items.clear();
    _items.addAll([
      _LineItem.fromProduct(
        _findProduct('P001'),
        reqDate: DateTime(2025, 9, 25),
        qty: 12,
        bonusQty: 1,
        addlBonusQty: 0,
        notes: 'Diwali Offer',
        expanded: true,
      ),
      _LineItem.fromProduct(
        _findProduct('P003'),
        reqDate: DateTime(2025, 9, 24),
        qty: 5,
        bonusQty: 0,
        addlBonusQty: 0,
        notes: '',
        expanded: false,
      ),
    ]);
    setState(() {});
  }

  void _loadNewModeData() {
    _contractDate = DateTime.now();
    _selectedCustomerCode = null;
    CustomerAddressController.text = '';
    _selectedDistributor = null;
    _selectedSalesRep = _salesReps.first;
    _items.clear();
    _items.add(_LineItem.fromProduct(Products.first, expanded: true));
    setState(() {});
  }

  Product _findProduct(String id) {
    return Products.firstWhere((p) => p.id == id);
  }

  Customer? get _selectedCustomer {
    if (_selectedCustomerCode == null) return null;
    return Customers.firstWhere((c) => c.code == _selectedCustomerCode);
  }

  String _formatCurrency(double value) {
// Simple INR-like formatting without extra dependencies
    return '₹${value.toStringAsFixed(2)}';
  }

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime initialDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final DateTime first = DateTime(2000);
    final DateTime last = DateTime(2100);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: first,
      lastDate: last,
      helpText: 'Select Date',
    );
    if (picked != null) {
      onPicked(picked);
      setState(() {});
    }
  }

  Color _statusBackgroundColor() {
    return _isEditMode ? const Color(0xFFDCFCE7) : const Color(0xFFE5E7EB);
  }

  Color _statusTextColor() {
    return _isEditMode ? const Color(0xFF16A34A) : const Color(0xFF4B5563);
  }

  String _statusText() {
    return _isEditMode ? 'Approved' : 'Draft';
  }

  @override
  Widget build(BuildContext context) {
// Tablet vs Mobile responsive: width breakpoint ~ 800
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 800;
        final EdgeInsets screenPadding = EdgeInsets.symmetric(
          horizontal: isTablet ? 24 : 12,
          vertical: isTablet ? 16 : 8,
        );
        final double maxContentWidth = isTablet ? 720 : double.infinity;

        return Scaffold(
          backgroundColor: const Color(0xFFE5E7EB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.blue),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'Back',
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                 Text(
                  'Sale Contract',
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.bold,
                      fontSize: isTablet? 25 : 20
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isEditMode ? (widget.contractId ?? '') : '<NEW>',
                  style:  TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet? 20 : 14
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusBackgroundColor(),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusText(),
                    style: TextStyle(
                      color: _statusTextColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: ElevatedButton(
                  onPressed: _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: screenPadding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(isTablet: isTablet),
                      const SizedBox(height: 12),
                      _buildItemsCard(isTablet: isTablet),
                      const SizedBox(height: 12),
                      _buildFooterActions(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard({required bool isTablet}) {
    final border = OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(10),
    );

    return Card(
      color: Colors.white,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
// Row 1: Date + Customer
            isTablet
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 220,
                        child: _DateField(
                          label: 'Date',
                          value: _contractDate,
                          onTap: () => _pickDate(
                            context: context,
                            initialDate: _contractDate,
                            onPicked: (d) => _contractDate = d,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _DropdownField<String>(
                          label: 'Customer',
                          value: _selectedCustomerCode,
                          hint: '-- Select Customer --',
                          items: [
                            for (final c in Customers)
                              DropdownMenuItem(
                                value: c.code,
                                child: Text(c.name),
                              ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _selectedCustomerCode = v;
                              CustomerAddressController.text =
                                  _selectedCustomer?.address ?? '';
                            });
                          },
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _DateField(
                        label: 'Date',
                        value: _contractDate,
                        onTap: () => _pickDate(
                          context: context,
                          initialDate: _contractDate,
                          onPicked: (d) => _contractDate = d,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DropdownField<String>(
                        label: 'Customer',
                        value: _selectedCustomerCode,
                        hint: '-- Select Customer --',
                        items: [
                          for (final c in Customers)
                            DropdownMenuItem(
                              value: c.code,
                              child: Text(c.name),
                            ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _selectedCustomerCode = v;
                            CustomerAddressController.text =
                                _selectedCustomer?.address ?? '';
                          });
                        },
                      ),
                    ],
                  ),
            const SizedBox(height: 12),

// Customer Address
            _TextAreaField(
              label: 'Customer Address',
              controller: CustomerAddressController,
              hintText: 'Customer address will be populated here',
              minLines: 2,
              maxLines: 4,
              border: border,
            ),
            const SizedBox(height: 12),

// Sales Rep + Distributor
            isTablet
                ? Row(
                    children: [
                      Expanded(
                        child: _DropdownField<String>(
                          label: 'Sales Rep',
                          value: _selectedSalesRep,
                          items: [
                            for (final s in _salesReps)
                              DropdownMenuItem(value: s, child: Text(s)),
                          ],
                          onChanged: (v) => setState(
                              () => _selectedSalesRep = v ?? _salesReps.first),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _DropdownField<String>(
                          label: 'Distributor',
                          value: _selectedDistributor,
                          hint: '-- Select Distributor --',
                          items: [
                            for (final d in _distributors)
                              DropdownMenuItem(value: d, child: Text(d)),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedDistributor = v),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _DropdownField<String>(
                        label: 'Sales Rep',
                        value: _selectedSalesRep,
                        items: [
                          for (final s in _salesReps)
                            DropdownMenuItem(value: s, child: Text(s)),
                        ],
                        onChanged: (v) => setState(
                            () => _selectedSalesRep = v ?? _salesReps.first),
                      ),
                      const SizedBox(height: 12),
                      _DropdownField<String>(
                        label: 'Distributor',
                        value: _selectedDistributor,
                        hint: '-- Select Distributor --',
                        items: [
                          for (final d in _distributors)
                            DropdownMenuItem(value: d, child: Text(d)),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedDistributor = v),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard({required bool isTablet}) {
    return Card(
      color: Colors.white,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (int i = 0; i < _items.length; i++) ...[
              _ItemCard(
                index: i,
                totalCount: _items.length,
                item: _items[i],
                products: Products,
                onRemove: () {
                  setState(() {
                    _items.removeAt(i);
                  });
                },
                onChanged: () => setState(() {}),
                onToggle: () {
                  setState(() {
                    final wasExpanded = _items[i].expanded;
                    for (final it in _items) {
                      it.expanded = false;
                    }
                    _items[i].expanded = !wasExpanded;
                  });
                },
                formatCurrency: _formatCurrency,
              ),
              if (i != _items.length - 1) const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    for (final it in _items) {
                      it.expanded = false;
                    }
                    _items.add(
                        _LineItem.fromProduct(Products.first, expanded: true));
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  backgroundColor: const Color(0xFFF3F4F6),
                ),
                child: const Text(
                  '+ Add Another Item',
                  style: TextStyle(
                      color: Color(0xFF374151), fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _onSaveDraft,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              backgroundColor: const Color(0xFFC0C1C3),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: const Text(
              'Save as Draft',
              style: TextStyle(
                  color: Color(0xFF374151), fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _onSubmitForApproval,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Submit for Approval',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  void _onSave() {
// TODO: Replace with actual save logic
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Saved')));
  }

  void _onSaveDraft() {
// TODO: Replace with actual draft logic
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Saved as Draft')));
  }

  void _onSubmitForApproval() {
// TODO: Replace with actual submit logic
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Submitted for Approval')));
  }
}

class _ItemCard extends StatelessWidget {
  final int index;
  final int totalCount;
  final _LineItem item;
  final List<Product> products;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final VoidCallback onToggle; // explicit toggle button + header tap
  final String Function(double) formatCurrency;

  const _ItemCard({
    required this.index,
    required this.totalCount,
    required this.item,
    required this.products,
    required this.onRemove,
    required this.onChanged,
    required this.onToggle,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final bool canRemove = totalCount > 1;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
// Title Row (tappable + explicit toggle button)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Text(
                      'Item Details #${index + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151)),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggle,
                tooltip: item.expanded ? 'Collapse' : 'Expand',
                icon: Icon(
                  item.expanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF6B7280),
                ),
              ),
              if (canRemove)
                TextButton(
                  onPressed: onRemove,
                  child: const Text(
                    'Remove',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (item.expanded) ...[
// Item + Req Date
            LayoutBuilder(
              builder: (context, constraints) {
                final bool wide = constraints.maxWidth >= 720;
                if (wide) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: constraints.maxWidth * 0.58,
                        child: _DropdownField<Product>(
                          label: 'Item (${item.product.manufacturer})',
                          value: item.product,
                          items: [
                            for (final p in products)
                              DropdownMenuItem(
                                value: p,
                                child: Text(p.name),
                              ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            item.setProduct(v);
                            onChanged();
                          },
                          footer: Text(
                            'Available: ${item.product.availableQty}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: constraints.maxWidth * 0.38,
                        child: _DateField(
                          label: 'Required by Date',
                          value: item.requiredDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: item.requiredDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              helpText: 'Required by Date',
                            );
                            if (picked != null) {
                              item.requiredDate = picked;
                              onChanged();
                            }
                          },
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _DropdownField<Product>(
                      label: 'Item (${item.product.manufacturer})',
                      value: item.product,
                      items: [
                        for (final p in products)
                          DropdownMenuItem(
                            value: p,
                            child: Text(p.name),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        item.setProduct(v);
                        onChanged();
                      },
                      footer: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Available: ${item.product.availableQty}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DateField(
                      label: 'Required by Date',
                      value: item.requiredDate,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: item.requiredDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          helpText: 'Required by Date',
                        );
                        if (picked != null) {
                          item.requiredDate = picked;
                          onChanged();
                        }
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

// Qty, Rate, Amount, Bonus, Addl Bonus
            LayoutBuilder(
              builder: (context, constraints) {
                final bool wide = constraints.maxWidth >= 720;
                final children = [
                  Expanded(
                    child: _NumberField(
                      label: 'Qty (${item.product.uom})',
                      controller: item.qtyController,
                      min: 0,
                      onChanged: (v) => onChanged(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ReadonlyField(
                      label: 'Rate',
                      value: item.product.rate.toStringAsFixed(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ReadonlyField(
                      label: 'Amount',
                      value: formatCurrency(item.amount),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NumberField(
                      label: 'Bonus Qty',
                      controller: item.bonusQtyController,
                      min: 0,
                      onChanged: (v) => onChanged(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NumberField(
                      label: 'Addl. Bonus Qty',
                      controller: item.addlBonusQtyController,
                      min: 0,
                      onChanged: (v) => onChanged(),
                    ),
                  ),
                ];
                if (wide) {
                  return Row(children: children);
                }
                return Column(
                  children: [
                    Row(children: children.sublist(0, 3)),
                    const SizedBox(height: 12),
                    Row(children: children.sublist(3)),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

// Notes
            _TextField(
              label: 'Notes / Remarks',
              controller: item.notesController,
              hintText: 'e.g., promotional offer',
              onChanged: (v) => onChanged(),
            ),
          ],
        ],
      ),
    );
  }
}


class _LineItem {
  Product product;
  DateTime requiredDate;

  final TextEditingController qtyController;
  final TextEditingController bonusQtyController;
  final TextEditingController addlBonusQtyController;
  final TextEditingController notesController;

  bool expanded;

  _LineItem({
    required this.product,
    required this.requiredDate,
    required this.qtyController,
    required this.bonusQtyController,
    required this.addlBonusQtyController,
    required this.notesController,
    this.expanded = true,
  });

  factory _LineItem.fromProduct(
    Product product, {
    DateTime? reqDate,
    int qty = 1,
    int bonusQty = 0,
    int addlBonusQty = 0,
    String notes = '',
    bool expanded = true,
  }) {
    return _LineItem(
      product: product,
      requiredDate: reqDate ?? DateTime.now(),
      qtyController: TextEditingController(text: qty.toString()),
      bonusQtyController: TextEditingController(text: bonusQty.toString()),
      addlBonusQtyController:
          TextEditingController(text: addlBonusQty.toString()),
      notesController: TextEditingController(text: notes),
      expanded: expanded,
    );
  }

  void setProduct(Product newProduct) {
    product = newProduct;
  }

  double get amount {
    final qty = int.tryParse(qtyController.text) ?? 0;
    return product.rate * qty.toDouble();
  }

  void dispose() {
    qtyController.dispose();
    bonusQtyController.dispose();
    addlBonusQtyController.dispose();
    notesController.dispose();
  }
}

// Reusable form widgets
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  const _DateField(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, size: 18, color: Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Text(
                  '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Color(0xFF111827)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final Widget? footer;
  final bool searchable;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    this.hint,
    this.onChanged,
    this.footer,
    this.searchable = true,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(10),
    );

    String _labelForValue(T? v) {
      if (v == null) return '';
      for (final item in items) {
        if (item.value == v) {
          final child = item.child;
          if (child is Text) {
            return child.data ?? child.toString();
          }
          return v.toString();
        }
      }
      return v.toString();
    }

    Future<void> _openSearchablePicker() async {
      final List<MapEntry<T, String>> options = [
        for (final it in items)
          if (it.value != null)
            MapEntry(
              it.value as T,
              (it.child is Text)
                  ? (((it.child as Text).data) ?? it.value.toString())
                  : it.value.toString(),
            ),
      ];

      final selected = await showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          String query = '';
          List<MapEntry<T, String>> filtered = List.of(options);
          return SafeArea(
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                void applyFilter(String q) {
                  setSheetState(() {
                    query = q.toLowerCase();
                    filtered = options
                        .where((e) => e.value.toLowerCase().contains(query))
                        .toList(growable: false);
                  });
                }

                return Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    top: 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Select $label',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: const Icon(Icons.search),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: border,
                          enabledBorder: border,
                          focusedBorder: border.copyWith(
                            borderSide:
                                const BorderSide(color: Color(0xFF2563EB)),
                          ),
                        ),
                        onChanged: applyFilter,
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 420,
                        ),
                        child: Material(
                          color: Colors.white,
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: Color(0xFFF3F4F6),
                            ),
                            itemBuilder: (context, index) {
                              final entry = filtered[index];
                              final bool isSelected = value == entry.key;
                              return ListTile(
                                title: Text(entry.value),
                                trailing: isSelected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF2563EB),
                                      )
                                    : null,
                                onTap: () => Navigator.of(context).pop(entry.key),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );

      if (selected != null) {
        onChanged?.call(selected);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: searchable ? _openSearchablePicker : null,
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: hint,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
            child: Text(
              value == null
                  ? (hint ?? '')
                  : _labelForValue(value),
              style: TextStyle(
                color: value == null
                    ? const Color(0xFF6B7280)
                    : const Color(0xFF111827),
              ),
            ),
          ),
        ),
        if (footer != null) ...[
          const SizedBox(height: 6),
          footer!,
        ],
      ],
    );
  }
}

class _TextAreaField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final int minLines;
  final int maxLines;
  final InputBorder? border;

  const _TextAreaField({
    required this.label,
    required this.controller,
    this.hintText,
    this.minLines = 2,
    this.maxLines = 4,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final baseBorder = border ??
        OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(10),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: baseBorder,
            enabledBorder: baseBorder,
            focusedBorder: baseBorder.copyWith(
                borderSide: const BorderSide(color: Color(0xFF2563EB))),
          ),
        ),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;

  const _TextField({
    required this.label,
    required this.controller,
    this.hintText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(10),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
                borderSide: const BorderSide(color: Color(0xFF2563EB))),
          ),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int min;
  final ValueChanged<String>? onChanged;

  const _NumberField({
    required this.label,
    required this.controller,
    this.min = 0,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(10),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (v) {
// clamp to min
            final parsed = int.tryParse(v) ?? min;
            if (parsed < min) {
              controller.text = min.toString();
              controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: controller.text.length));
            }
            onChanged?.call(controller.text);
          },
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
                borderSide: const BorderSide(color: Color(0xFF2563EB))),
          ),
        ),
      ],
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadonlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(10),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: border,
            enabledBorder: border,
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
          ),
          child: Text(value, style: const TextStyle(color: Color(0xFF111827))),
        ),
      ],
    );
  }
}
