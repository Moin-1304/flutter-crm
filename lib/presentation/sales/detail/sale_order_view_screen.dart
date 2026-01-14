import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:boilerplate/domain/entity/sales/sales_api_models.dart';
import 'package:boilerplate/domain/repository/sales/sales_repository.dart';
import 'package:boilerplate/di/service_locator.dart';

class SaleOrderViewScreen extends StatefulWidget {
  final String? orderId;
  final SalesOrderApiItem? orderData;

  const SaleOrderViewScreen({
    super.key,
    this.orderId,
    this.orderData,
  });

  @override
  State<SaleOrderViewScreen> createState() => _SaleOrderViewScreenState();
}

class _SaleOrderViewScreenState extends State<SaleOrderViewScreen> {
  bool _isLoading = false;
  SalesOrderApiItem? _orderData;

  @override
  void initState() {
    super.initState();
    print('🔍 [SaleOrderView] initState called');
    print('   orderId: ${widget.orderId}');
    print('   orderData: ${widget.orderData?.id}');
    print('   orderData SO Number: ${widget.orderData?.soNumber}');
    
    // Use orderData for immediate display if provided
    _orderData = widget.orderData;
    
    // ALWAYS call API if orderId is provided to get complete details with all fields
    // This ensures we have the full data including salesContractItems and taxAndOtherChargesDetail
    if (widget.orderId != null) {
      print('   📡 Will call API to load complete order details...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadOrderData();
      });
    } else if (widget.orderData != null) {
      print('   ✅ Using provided orderData (no orderId, so no API call)');
    } else {
      print('   ⚠️ No orderId or orderData provided');
    }
  }

  Future<void> _loadOrderData() async {
    if (widget.orderId == null) {
      print('⚠️ [SaleOrderView] _loadOrderData: No orderId provided');
      return;
    }
    
    print('🔄 [SaleOrderView] _loadOrderData: Starting API call for orderId: ${widget.orderId}');
    
    setState(() {
      _isLoading = true;
    });

    try {
      final orderId = int.tryParse(widget.orderId!);
      if (orderId == null || orderId <= 0) {
        throw Exception('Invalid order ID: ${widget.orderId}');
      }

      print('📞 [SaleOrderView] Calling getSalesOrderById with id: $orderId');
      final salesRepository = getIt<SalesRepository>();
      final orderData = await salesRepository.getSalesOrderById(orderId);
      
      print('✅ [SaleOrderView] API call successful');
      print('   Order ID: ${orderData.id}');
      print('   SO Number: ${orderData.soNumber}');
      print('   Customer: ${orderData.customer}');
      print('   Items count: ${orderData.salesContractItems is List ? (orderData.salesContractItems as List).length : 0}');
      
      if (mounted) {
        setState(() {
          _orderData = orderData;
          _isLoading = false;
        });
        print('✅ [SaleOrderView] State updated with order data');
      }
    } catch (e, stackTrace) {
      print('❌ [SaleOrderView] Error loading order: $e');
      print('   Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load order: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 800;
    const Color tealGreen = Color(0xFF4db1b3);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Sale Order',
          style: GoogleFonts.inter(
            fontSize: isTablet ? 20 : 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: tealGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orderData == null
              ? const Center(child: Text('Order not found'))
              : Theme(
                  data: Theme.of(context).copyWith(
                    inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF4db1b3), width: 2),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 16 : 14,
                        vertical: isTablet ? 16 : 14,
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 16 : 12,
                    12,
                    isTablet ? 16 : 12,
                    16 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSaleOrderDetailsSection(isTablet),
                          const SizedBox(height: 14),
                          _buildOrderDetailsSection(isTablet),
                          const SizedBox(height: 14),
                          _buildTaxSection(isTablet),
                          const SizedBox(height: 14),
                          _buildAttachmentsSection(isTablet),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildSaleOrderDetailsSection(bool isTablet) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Order Information',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailsForm(isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsForm(bool isTablet) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        return isWide
            ? Column(
                children: [
                  // Top Row: Customer, SO Number, Date
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTopRowField1(isTablet)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTopRowField2(isTablet)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTopRowField3(isTablet)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Bottom Row: Customer Address, Delivery Date, Sales Rep, Distributor For
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildBottomRowField1(isTablet)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildBottomRowField2(isTablet)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildBottomRowField3(isTablet)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildBottomRowField4(isTablet)),
                    ],
                  ),
                ],
              )
            : Column(
                children: [
                  // Top Row fields
                  _buildTopRowField1(isTablet),
                  const SizedBox(height: 20),
                  _buildTopRowField2(isTablet),
                  const SizedBox(height: 20),
                  _buildTopRowField3(isTablet),
                  const SizedBox(height: 20),
                  // Bottom Row fields
                  _buildBottomRowField1(isTablet),
                  const SizedBox(height: 20),
                  _buildBottomRowField2(isTablet),
                  const SizedBox(height: 20),
                  _buildBottomRowField3(isTablet),
                  const SizedBox(height: 20),
                  _buildBottomRowField4(isTablet),
                ],
              );
      },
    );
  }

  // Top Row Field 1: Customer
  Widget _buildTopRowField1(bool isTablet) {
    return _LabeledField(
      label: 'Customer',
      child: _buildReadOnlyField(_orderData?.customerName ?? _orderData?.customer ?? ''),
    );
  }

  // Top Row Field 2: SO Number
  Widget _buildTopRowField2(bool isTablet) {
    return _LabeledField(
      label: 'SO Number',
      child: _buildReadOnlyField(_orderData?.soNumber ?? ''),
    );
  }

  // Top Row Field 3: Date
  Widget _buildTopRowField3(bool isTablet) {
    return _LabeledField(
      label: 'Date',
      child: _buildReadOnlyField(
        _orderData?.date != null
            ? DateFormat('dd-MMM-yyyy').format(DateTime.parse(_orderData!.date!))
            : '',
      ),
    );
  }

  // Bottom Row Field 1: Customer Address
  Widget _buildBottomRowField1(bool isTablet) {
    return _LabeledField(
      label: 'Customer Address',
      child: _buildReadOnlyField(_orderData?.cusAddress ?? '', maxLines: 3),
    );
  }

  // Bottom Row Field 2: Delivery Date
  Widget _buildBottomRowField2(bool isTablet) {
    return _LabeledField(
      label: 'Delivery Date',
      child: _buildReadOnlyField(
        _orderData?.deliveryDate != null
            ? DateFormat('dd-MMM-yyyy').format(DateTime.parse(_orderData!.deliveryDate!))
            : '',
      ),
    );
  }

  // Bottom Row Field 3: Sales Rep
  Widget _buildBottomRowField3(bool isTablet) {
    return _LabeledField(
      label: 'Sales Rep',
      child: _buildReadOnlyField(_orderData?.salesRepName ?? _orderData?.salesRep ?? ''),
    );
  }

  // Bottom Row Field 4: Distributor For
  Widget _buildBottomRowField4(bool isTablet) {
    // Note: The API model has distributerForId but no distributor name field
    // Display empty string for now, or could fetch distributor name from ID if needed
    return _LabeledField(
      label: 'Distributer For',
      child: _buildReadOnlyField(''), // TODO: Map distributerForId to distributor name if available
    );
  }

  Widget _buildReadOnlyField(String value, {int maxLines = 1}) {
    final isTablet = MediaQuery.of(context).size.width >= 800;
    return TextFormField(
      readOnly: true,
      initialValue: value.isEmpty ? '-' : value,
      maxLines: maxLines,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: value.isEmpty ? Colors.grey.shade500 : Colors.grey.shade800,
      ),
      decoration: InputDecoration(
        hintText: value.isEmpty ? 'Not provided' : null,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 14,
          vertical: isTablet ? 16 : 14,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _parseOrderItems() {
    if (_orderData == null) return [];
    
    // Try to parse salesContractItems
    final items = _orderData!.salesContractItems;
    if (items == null) {
      // If no items list, create a single row from order summary
      return [
        {
          'itemDescription': _orderData!.itemName ?? '-',
          'quantity': _orderData!.totalQuantity ?? 0,
          'uom': '-',
          'rate': _orderData!.amount,
          'amount': _orderData!.amount,
          'bonusQty': _orderData!.bonusQuantity,
          'addlBonus': _orderData!.additionalBonusQuantity,
          'discount': _orderData!.totalDiscount ?? 0.0,
          'tax': _orderData!.totalTax ?? 0.0,
          'totalAmount': _orderData!.totalAmount ?? _orderData!.amount,
          'manufacturer': '-',
          'reqdDate': _orderData!.deliveryDate,
          'division': _orderData!.divisionText ?? _orderData!.division ?? '-',
        }
      ];
    }
    
    // If items is a List, parse it
    if (items is List) {
      return items.map((item) {
        final map = item is Map<String, dynamic> ? item : {};
        return {
          'itemDescription': map['itemText'] ?? map['itemName'] ?? map['itemDescription'] ?? '-',
          'quantity': (map['quantity'] ?? 0).toDouble(),
          'uom': map['uomText'] ?? map['uom'] ?? '-',
          'rate': (map['unitPrice'] ?? map['rate'] ?? 0).toDouble(),
          'amount': (map['amount'] ?? 0).toDouble(),
          'bonusQty': (map['bonusQuantity'] ?? map['bonusQty'] ?? 0).toDouble(),
          'addlBonus': (map['additionalQuantity'] ?? map['addlBonus'] ?? map['additionalBonusQuantity'] ?? 0).toDouble(),
          'discount': (map['discount'] ?? map['discountAmount'] ?? 0).toDouble(),
          'tax': (map['tax'] ?? 0).toDouble(),
          'totalAmount': (map['totalAmount'] ?? map['amount'] ?? 0).toDouble(),
          'manufacturer': map['manufacturerName'] ?? map['manufacturer'] ?? '-',
          'reqdDate': map['reqdDate'] ?? map['requiredDate'] ?? map['deliveryDate'],
          'division': map['divisionGroupName'] ?? map['divisionGroupText'] ?? map['divisionText'] ?? map['division'] ?? '-',
        };
      }).toList();
    }
    
    return [];
  }

  Widget _buildOrderDetailsSection(bool isTablet) {
    final items = _parseOrderItems();
    
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Order Details',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 20),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No items found',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              )
            else
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildOrderItemCard(item, index, items.length, isTablet);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemCard(Map<String, dynamic> item, int index, int total, bool isTablet) {
    final reqdDate = item['reqdDate'] != null
        ? (item['reqdDate'] is String
            ? (() {
                try {
                  return DateFormat('dd-MMM-yyyy').format(DateTime.parse(item['reqdDate']));
                } catch (e) {
                  return item['reqdDate'].toString();
                }
              })()
            : item['reqdDate'].toString())
        : '-';

    return Container(
      margin: EdgeInsets.only(bottom: index < total - 1 ? 16 : 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildItemField('Item Description', item['itemDescription'].toString(), isTablet),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildItemField('Quantity', (item['quantity'] as num).toStringAsFixed(2), isTablet)),
              const SizedBox(width: 12),
              Expanded(child: _buildItemField('UOM', item['uom'].toString(), isTablet)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildItemField('Rate', (item['rate'] as num).toStringAsFixed(2), isTablet)),
              const SizedBox(width: 12),
              Expanded(child: _buildItemField('Amount', (item['amount'] as num).toStringAsFixed(2), isTablet)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildItemField('Bonus Qty', (item['bonusQty'] as num).toStringAsFixed(2), isTablet)),
              const SizedBox(width: 12),
              Expanded(child: _buildItemField('Addl. Bonus', (item['addlBonus'] as num).toStringAsFixed(2), isTablet)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildItemField('Disc.', (item['discount'] as num).toStringAsFixed(2), isTablet)),
              const SizedBox(width: 12),
              Expanded(child: _buildItemField('Tax', (item['tax'] as num).toStringAsFixed(2), isTablet)),
            ],
          ),
          const SizedBox(height: 16),
          _buildItemField('Total Amount', (item['totalAmount'] as num).toStringAsFixed(2), isTablet),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildItemField('Manufacturer', item['manufacturer'].toString(), isTablet)),
              const SizedBox(width: 12),
              Expanded(child: _buildItemField('Reqd. Date', reqdDate, isTablet)),
            ],
          ),
          const SizedBox(height: 16),
          _buildItemField('Division', item['division'].toString(), isTablet),
        ],
      ),
    );
  }

  Widget _buildItemField(String label, String value, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          readOnly: true,
          initialValue: value,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey.shade800,
          ),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 14,
              vertical: isTablet ? 16 : 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaxSection(bool isTablet) {
    // Try to get values from taxAndOtherChargesDetail first
    double subtotal = 0.0;
    double tax = 0.0;
    double discount = 0.0;
    double otherCharge = 0.0;
    double adjustment = 0.0;
    double grandTotal = 0.0;

    if (_orderData?.taxAndOtherChargesDetail != null && _orderData!.taxAndOtherChargesDetail is List) {
      final charges = _orderData!.taxAndOtherChargesDetail as List;
      for (var charge in charges) {
        if (charge is Map<String, dynamic>) {
          final label = charge['label']?.toString().toLowerCase() ?? '';
          final value = (charge['value'] ?? 0).toDouble();
          
          if (label.contains('sub total') || label.contains('subtotal')) {
            subtotal = value;
          } else if (label.contains('tax')) {
            tax = value;
          } else if (label.contains('discount')) {
            discount = value;
          } else if (label.contains('other charge')) {
            otherCharge = value;
          } else if (label.contains('price adjustment')) {
            adjustment = value;
          } else if (label.contains('grand total')) {
            grandTotal = value;
          }
        }
      }
    }

    // Fallback to direct fields if taxAndOtherChargesDetail is not available
    if (subtotal == 0.0) subtotal = _orderData?.totalAmount ?? _orderData?.amount ?? 0.0;
    if (tax == 0.0) tax = _orderData?.totalTax ?? 0.0;
    if (discount == 0.0) discount = _orderData?.totalDiscount ?? 0.0;
    if (otherCharge == 0.0) otherCharge = _orderData?.totalShipCharge ?? 0.0;
    if (adjustment == 0.0) adjustment = _orderData?.totalAdjust ?? 0.0;
    if (grandTotal == 0.0) grandTotal = subtotal + tax - discount + otherCharge + adjustment;

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tax',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Column(
                children: [
                  _buildTaxRow('Sub Total', subtotal),
                  const SizedBox(height: 12),
                  _buildTaxRow('Tax', tax),
                  const SizedBox(height: 12),
                  _buildTaxRow('Discount', discount),
                  const SizedBox(height: 12),
                  _buildTaxRow('Other Charge', otherCharge),
                  const SizedBox(height: 12),
                  _buildTaxRow('Price Adjustment', adjustment),
                  const Divider(height: 24),
                  _buildTaxRow('Grand Total', grandTotal, isTotal: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxRow(String label, double value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: Colors.grey.shade900,
          ),
        ),
        Text(
          _formatCurrency(value),
          style: GoogleFonts.inter(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: Colors.grey.shade900,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double value) {
    final s = value.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '';
    final buf = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      buf.write(intPart[i]);
      count++;
      if (i > 0 && ((count == 3) || (count > 3 && (count - 3) % 2 == 0))) {
        buf.write(',');
      }
    }
    final formattedInt = buf.toString().split('').reversed.join();
    return decPart.isNotEmpty ? '$formattedInt.$decPart' : formattedInt;
  }

  Widget _buildAttachmentsSection(bool isTablet) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Attachments',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Center(
                child: Text(
                  'No attachments',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

