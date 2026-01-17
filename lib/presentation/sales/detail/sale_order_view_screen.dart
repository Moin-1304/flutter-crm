import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:boilerplate/domain/entity/sales/sales_api_models.dart';
import 'package:boilerplate/domain/repository/sales/sales_repository.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
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
  String? _distributorName; // Store distributor name loaded from API
  
  // Collapsible sections
  bool _isOrderInfoExpanded = true;
  bool _isOrderDetailsExpanded = true;
  bool _isTaxSectionExpanded = true;
  bool _isAttachmentsExpanded = true;

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
      setState(() {
        _orderData = widget.orderData;
      });
      // Load distributor name if available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.orderData!.distributerForId != null && widget.orderData!.customerId != null) {
          _loadDistributorName(
            widget.orderData!.customerId!,
            widget.orderData!.distributerForId!,
          );
        }
      });
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
        
        // Load distributor name if available
        if (orderData.distributerForId != null && orderData.customerId != null) {
          _loadDistributorName(
            orderData.customerId!,
            orderData.distributerForId!,
          );
        }
        
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
            // Collapsible Header
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isOrderInfoExpanded = !_isOrderInfoExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                        'Sales Order Details',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
                      Icon(
                        _isOrderInfoExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.grey.shade600,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Content (shown when expanded)
            if (_isOrderInfoExpanded) ...[
            const SizedBox(height: 20),
            _buildDetailsForm(isTablet),
            ],
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
    // Display distributor name if loaded, otherwise show ID as fallback
    String distributorText = _distributorName ?? '';
    if (distributorText.isEmpty && _orderData?.distributerForId != null && _orderData!.distributerForId! > 0) {
      // Fallback to ID if name not loaded yet
      distributorText = 'ID: ${_orderData!.distributerForId}';
    }
    return _LabeledField(
      label: 'Distributer For',
      child: _buildReadOnlyField(distributorText),
    );
  }

  Future<void> _loadDistributorName(int customerId, int distributorId) async {
    try {
      // Get user info for bizUnit
      final sharedPrefHelper = getIt<SharedPreferenceHelper>();
      final user = await sharedPrefHelper.getUser();

      if (user == null) {
        print('Error: User not available for Distributor API');
        return;
      }

      // Get bizUnit from UserDetailStore or user prefs
      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;

      int? bizUnitFromStore = userStore?.userDetail?.sbuId;
      int? bizUnitFromPrefs = user.sbuId;
      final int bizUnit = (bizUnitFromStore != null && bizUnitFromStore > 0)
          ? bizUnitFromStore
          : ((bizUnitFromPrefs != null && bizUnitFromPrefs > 0)
              ? bizUnitFromPrefs
              : 1);

      if (bizUnit == 0) {
        print('Error: BizUnit is 0');
        return;
      }

      print('🔵 Loading Distributor Name for BizUnit: $bizUnit, CustomerId: $customerId, DistributorId: $distributorId');

      final commonRepository = getIt<CommonRepository>();
      final distributors = await commonRepository.getDistributorList(
        bizUnit: bizUnit,
        customerId: customerId,
      );

      if (mounted) {
        // Find distributor by ID
        String? distributorName;
        try {
          final distributorItem = distributors.firstWhere(
            (item) => item.id == distributorId,
          );
          distributorName = distributorItem.text;
          print('✅ Found Distributor Name: $distributorName');
        } catch (e) {
          // Distributor not found by ID
          distributorName = null;
          print('⚠️ Distributor not found by ID: $distributorId');
        }
        
        // Update state with the found name
        setState(() {
          _distributorName = distributorName;
        });
        print('✅ Loaded Distributor Name: ${_distributorName}');
      }
    } catch (e) {
      print('Error loading distributor name: $e');
      if (mounted) {
        setState(() {
          _distributorName = null;
        });
      }
    }
  }

  Widget _buildReadOnlyField(String value, {int maxLines = 1}) {
    final isTablet = MediaQuery.of(context).size.width >= 800;
    final border = OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(10),
    );
    
    return TextFormField(
      key: ValueKey(value), // Force rebuild when value changes
      readOnly: true,
      initialValue: value.isEmpty ? '-' : value,
      maxLines: maxLines,
      style: GoogleFonts.inter(
        fontSize: isTablet ? 15 : 14,
        fontWeight: FontWeight.w500,
        color: value.isEmpty ? Colors.grey.shade500 : const Color(0xFF111827),
      ),
      decoration: InputDecoration(
        hintText: value.isEmpty ? 'Not provided' : null,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 14,
          vertical: isTablet ? 16 : 14,
        ),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
        errorBorder: border,
        disabledBorder: border,
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
          'mrp': null, // MRP not available in summary data
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
          'mrp': (map['mrp'] ?? map['maxRetailPrice'] ?? map['mrpValue'] ?? 0).toDouble(),
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
            // Collapsible Header
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isOrderDetailsExpanded = !_isOrderDetailsExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Order Details',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
                      Icon(
                        _isOrderDetailsExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.grey.shade600,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Content (shown when expanded)
            if (_isOrderDetailsExpanded) ...[
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
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
              Expanded(child: _buildItemField('MRP', (item['mrp'] as num? ?? 0) > 0 ? (item['mrp'] as num).toStringAsFixed(2) : '-', isTablet)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildItemField('Amount', (item['amount'] as num).toStringAsFixed(2), isTablet)),
              const SizedBox(width: 12),
              Expanded(child: _buildItemField('Disc.', (item['discount'] as num).toStringAsFixed(2), isTablet)),
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
              Expanded(child: _buildItemField('Total Amount', (item['totalAmount'] as num).toStringAsFixed(2), isTablet)),
              const SizedBox(width: 12),
              Expanded(child: _buildItemField('Reqd. Date', reqdDate, isTablet)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemField(String label, String value, bool isTablet) {
    final border = OutlineInputBorder(
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      borderRadius: BorderRadius.circular(10),
    );
    
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
        TextFormField(
          readOnly: true,
          initialValue: value,
          style: GoogleFonts.inter(
            fontSize: isTablet ? 15 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade900,
          ),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 14,
              vertical: isTablet ? 16 : 14,
            ),
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            border: border,
            enabledBorder: border,
            focusedBorder: border,
            errorBorder: border,
            disabledBorder: border,
          ),
        ),
      ],
    );
  }

  Widget _buildTaxSection(bool isTablet) {
    // Parse tax and charges from taxAndOtherChargesDetail using typeText
    double subtotal = 0.0;
    double adjustment = 0.0;
    double grandTotalFromAPI = 0.0;
    final List<Map<String, dynamic>> taxRows = [];
    final List<Map<String, dynamic>> discountRows = [];
    final List<Map<String, dynamic>> otherChargeRows = [];

    if (_orderData?.taxAndOtherChargesDetail != null && _orderData!.taxAndOtherChargesDetail is List) {
      final charges = _orderData!.taxAndOtherChargesDetail as List;
      for (var charge in charges) {
        if (charge is Map<String, dynamic>) {
          final typeText = charge['typeText']?.toString() ?? '';
          final label = charge['label']?.toString() ?? '';
          final value = (charge['value'] ?? 0).toDouble();
          
          // Use typeText for exact matching (more reliable than label)
          if (typeText == 'SubTotal' || typeText.toLowerCase() == 'subtotal') {
            subtotal = value;
          } else if (typeText == 'Tax' || typeText.toLowerCase() == 'tax') {
            taxRows.add({
              'label': label.isNotEmpty ? label : 'Tax',
              'value': value,
              'type': charge['subTypeText']?.toString(),
            });
          } else if (typeText == 'Discount' || typeText.toLowerCase() == 'discount') {
            discountRows.add({
              'label': label.isNotEmpty ? label : 'Discount',
              'value': value,
              'type': charge['subTypeText']?.toString(),
            });
          } else if (typeText == 'OtherCharge' || typeText.toLowerCase() == 'othercharge') {
            otherChargeRows.add({
              'label': label.isNotEmpty ? label : 'Other Charge',
              'value': value,
            });
          } else if (typeText == 'PriceAdjustment' || typeText.toLowerCase() == 'priceadjustment') {
            adjustment = value;
          } else if (typeText == 'GrandTotal' || typeText.toLowerCase() == 'grandtotal') {
            grandTotalFromAPI = value;
          }
        }
      }
    }

    // Fallback to direct fields if taxAndOtherChargesDetail is not available
    if (subtotal == 0.0) subtotal = _orderData?.totalAmount ?? _orderData?.amount ?? 0.0;
    if (adjustment == 0.0) adjustment = _orderData?.totalAdjust ?? 0.0;
    
    // If no tax rows found, try to create from direct fields
    if (taxRows.isEmpty && (_orderData?.totalTax ?? 0.0) > 0) {
      taxRows.add({
        'label': 'Tax',
        'value': _orderData!.totalTax!,
        'type': null,
      });
    }
    if (discountRows.isEmpty && (_orderData?.totalDiscount ?? 0.0) > 0) {
      discountRows.add({
        'label': 'Discount',
        'value': _orderData!.totalDiscount!,
        'type': null,
      });
    }
    if (otherChargeRows.isEmpty && (_orderData?.totalShipCharge ?? 0.0) > 0) {
      otherChargeRows.add({
        'label': 'Other Charge',
        'value': _orderData!.totalShipCharge!,
      });
    }

    // Calculate totals - use GrandTotal from API if available, otherwise calculate
    final totalTax = taxRows.fold(0.0, (sum, row) => sum + (row['value'] as double));
    final totalDiscount = discountRows.fold(0.0, (sum, row) => sum + (row['value'] as double));
    final totalOtherCharge = otherChargeRows.fold(0.0, (sum, row) => sum + (row['value'] as double));
    final grandTotal = grandTotalFromAPI > 0.0 
        ? grandTotalFromAPI 
        : (subtotal + totalTax - totalDiscount + totalOtherCharge + adjustment);

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
            // Collapsible Header
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isTaxSectionExpanded = !_isTaxSectionExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tax',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
                      Icon(
                        _isTaxSectionExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.grey.shade600,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Tax Table Content (shown when expanded)
            if (_isTaxSectionExpanded) ...[
              const SizedBox(height: 20),
              // Different layout for mobile vs tablet
              isTablet
                  ? Container(
                      constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
                      child: SingleChildScrollView(
              child: Column(
                children: [
                            // Sub Total Row
                            _buildTaxTableRowReadOnly(
                              label: 'Sub Total',
                              value: subtotal,
                              isTablet: isTablet,
                            ),
                            Divider(height: 1, color: Colors.grey.shade200),
                            // Tax Rows
                            for (int i = 0; i < taxRows.length; i++) ...[
                              _buildTaxTableRowReadOnlyWithConfig(
                                label: 'Tax',
                                value: taxRows[i]['value'] as double,
                                configValue: taxRows[i]['type'] as String?,
                                isTablet: isTablet,
                              ),
                              Divider(height: 1, color: Colors.grey.shade200),
                            ],
                            // Discount Rows
                            for (int i = 0; i < discountRows.length; i++) ...[
                              _buildTaxTableRowReadOnlyWithConfig(
                                label: 'Discount',
                                value: discountRows[i]['value'] as double,
                                configValue: discountRows[i]['type'] as String?,
                                isTablet: isTablet,
                              ),
                              Divider(height: 1, color: Colors.grey.shade200),
                            ],
                            // Other Charge Rows
                            for (int i = 0; i < otherChargeRows.length; i++) ...[
                              _buildTaxTableRowReadOnly(
                                label: 'Other Charge',
                                value: otherChargeRows[i]['value'] as double,
                                isTablet: isTablet,
                              ),
                              Divider(height: 1, color: Colors.grey.shade200),
                            ],
                            // Price Adjustment Row
                            _buildTaxTableRowReadOnly(
                              label: 'Price Adjustment',
                              value: adjustment,
                              isTablet: isTablet,
                            ),
                            Divider(height: 1, color: Colors.grey.shade200, thickness: 2),
                            // Grand Total Row
                            _buildTaxTableRowReadOnly(
                              label: 'Grand Total',
                              value: grandTotal,
                              isTotal: true,
                              isTablet: isTablet,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // Sub Total Row
                        _buildTaxRowMobile(
                          label: 'Sub Total',
                          value: subtotal,
                        ),
                  const SizedBox(height: 12),
                        // Tax Rows
                        for (int i = 0; i < taxRows.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildTaxRowMobile(
                              label: 'Tax',
                              value: taxRows[i]['value'] as double,
                            ),
                          ),
                        // Discount Rows
                        for (int i = 0; i < discountRows.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildTaxRowMobile(
                              label: 'Discount',
                              value: discountRows[i]['value'] as double,
                            ),
                          ),
                        // Other Charge Rows
                        for (int i = 0; i < otherChargeRows.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildTaxRowMobile(
                              label: 'Other Charge',
                              value: otherChargeRows[i]['value'] as double,
                            ),
                          ),
                        // Price Adjustment Row
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildTaxRowMobile(
                            label: 'Price Adjustment',
                            value: adjustment,
                          ),
                        ),
                        const Divider(height: 24, thickness: 1, color: Colors.grey),
                        // Grand Total Row
                        _buildTaxRowMobile(
                          label: 'Grand Total',
                          value: grandTotal,
                          isTotal: true,
                        ),
                      ],
                    ),
            ],
          ],
        ),
      ),
    );
  }

  String? _extractTaxType(String label) {
    if (label.contains('VAT') || label.contains('18%')) return 'VAT 18%';
    if (label.contains('GST') || label.contains('5%')) return 'GST 5%';
    return null;
  }

  String? _extractDiscountType(String label) {
    if (label.contains('Percent') || label.contains('%')) return 'Percentage';
    if (label.contains('Fixed')) return 'Fixed Amount';
    return null;
  }

  Widget _buildTaxRowMobile({
    required String label,
    required double value,
    bool isTotal = false,
  }) {
    const Color tealGreen = Color(0xFF4db1b3);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 15 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: Colors.grey.shade900,
          ),
        ),
        Text(
          value == 0.0 ? '0' : _formatCurrency(value),
          style: GoogleFonts.inter(
            fontSize: isTotal ? 15 : 14,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
            color: isTotal ? tealGreen : Colors.grey.shade900,
              ),
            ),
          ],
    );
  }

  Widget _buildTaxTableRowReadOnly({
    required String label,
    required double value,
    bool isTotal = false,
    required bool isTablet,
  }) {
    const Color tealGreen = Color(0xFF4db1b3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 40),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: isTablet ? 14 : 13,
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          Expanded(flex: 2, child: const SizedBox.shrink()),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              value == 0.0 ? '0' : _formatCurrency(value),
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: isTablet ? 14 : 13,
                fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
                color: isTotal ? tealGreen : Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxTableRowReadOnlyWithConfig({
    required String label,
    required double value,
    String? configValue,
    required bool isTablet,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 40),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: isTablet ? 14 : 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: configValue != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      configValue,
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 13 : 12,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              value == 0.0 ? '0' : _formatCurrency(value),
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: isTablet ? 14 : 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
          ),
        ],
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
            // Collapsible Header
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isAttachmentsExpanded = !_isAttachmentsExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Attachments',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
                      Icon(
                        _isAttachmentsExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.grey.shade600,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Content (shown when expanded)
            if (_isAttachmentsExpanded) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'No attachments',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            ],
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

