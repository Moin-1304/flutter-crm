import 'package:flutter/material.dart';
import 'package:boilerplate/presentation/crm/widgets/date_navigator.dart';
void main() {
  runApp(const MaterialApp(
    home: DCRListScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class DCRListScreen extends StatefulWidget {
  const DCRListScreen({super.key});

  @override
  State<DCRListScreen> createState() => _DCRListScreenState();
}

class _DCRListScreenState extends State<DCRListScreen> {
  String _employee = 'MR. John Doe';
  String _status = 'Status: All';
  DateTime _date = DateTime(2025, 8, 22);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color border = theme.dividerColor.withOpacity(.15);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isTablet = constraints.maxWidth >= 768;
          final bool isMobile = constraints.maxWidth < 600;
          
          return ListView(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            children: [
              // Header Section
              _buildHeader(isTablet, isMobile),
              const SizedBox(height: 16),
              
              // Filter Section
              _buildFilterSection(constraints, border),
              const SizedBox(height: 16),
              
              // Main Content - Clustered Lists
              _buildClusteredContent(isTablet, isMobile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isTablet, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Daily Call Report',
          style: TextStyle(
            fontSize: isMobile ? 20 : (isTablet ? 28 : 24),
            fontWeight: FontWeight.w700,
            color: const Color(0xFF12223B),
          ),
        ),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to new DCR
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 8 : 12,
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'New DCR',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {
                // Navigate to new expense
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 8 : 12,
                ),
              ),
              child: Text(
                'New Expense',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),

          ],
        ),
      ],
    );
  }

  Widget _buildFilterSection(BoxConstraints constraints, Color border) {
    final bool isMobile = constraints.maxWidth < 600;
    
    if (isMobile) {
      return Column(
        children: [
          // Employee selector (full width)
          _buildEmployeeSelector(constraints.maxWidth, border),
          const SizedBox(height: 12),
          // Date navigator (full width)
          SizedBox(
            width: constraints.maxWidth,
            child: DateNavigator(
              initialDate: _date,
              onChanged: (d) => setState(() => _date = d),
            ),
          ),
          const SizedBox(height: 12),
          // Status filter (full width)
          _buildStatusFilter(constraints.maxWidth, border),
        ],
      );
    }
    
    return Row(
      children: [
        // Employee selector
        _buildEmployeeSelector(280, border),
        const SizedBox(width: 12),
        // Date navigator
        SizedBox(
          width: 360,
          child: DateNavigator(
            initialDate: _date,
            onChanged: (d) => setState(() => _date = d),
          ),
        ),
        const SizedBox(width: 12),
        // Status filter
        _buildStatusFilter(200, border),
      ],
    );
  }

  Widget _buildEmployeeSelector(double width, Color border) {
    return Container(
      width: width,
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: border)),
        color: Colors.grey.shade100,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _employee,
          icon: const Icon(Icons.expand_more),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF12223B),
          ),
          items: const [
            DropdownMenuItem(value: 'MR. John Doe', child: Text('MR. John Doe')),
            DropdownMenuItem(value: 'Ms. Alice', child: Text('Ms. Alice')),
            DropdownMenuItem(value: 'Mr. Bob', child: Text('Mr. Bob')),
          ],
          onChanged: (v) => setState(() => _employee = v ?? _employee),
        ),
      ),
    );
  }

  Widget _buildStatusFilter(double width, Color border) {
    return Container(
      width: width,
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: border)),
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _status,
          icon: const Icon(Icons.expand_more),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF12223B),
          ),
          items: const [
            DropdownMenuItem(value: 'Status: All', child: Text('Status: All')),
            DropdownMenuItem(value: 'Status: Pending', child: Text('Status: Pending')),
            DropdownMenuItem(value: 'Status: Approved', child: Text('Status: Approved')),
            DropdownMenuItem(value: 'Status: Draft', child: Text('Status: Draft')),
          ],
          onChanged: (v) => setState(() => _status = v ?? _status),
        ),
      ),
    );
  }

  Widget _buildClusteredContent(bool isTablet, bool isMobile) {
    final filteredData = _getFilteredData();
    
    return Column(
      children: [
        // Andheri East Cluster
        if (filteredData['Andheri East']?.isNotEmpty ?? false)
          _buildClusterSection(
            'Andheri East',
            const Color(0xFF2563EB),
            filteredData['Andheri East']!,
            isTablet,
            isMobile,
          ),
        
        if ((filteredData['Andheri East']?.isNotEmpty ?? false) && 
            (filteredData['Bandra West']?.isNotEmpty ?? false))
          const SizedBox(height: 20),
        
        // Bandra West Cluster
        if (filteredData['Bandra West']?.isNotEmpty ?? false)
          _buildClusterSection(
            'Bandra West',
            const Color(0xFFE91E63),
            filteredData['Bandra West']!,
            isTablet,
            isMobile,
          ),
        
        if ((filteredData['Bandra West']?.isNotEmpty ?? false) && 
            (filteredData['Powai']?.isNotEmpty ?? false))
          const SizedBox(height: 20),
        
        // Powai Cluster
        if (filteredData['Powai']?.isNotEmpty ?? false)
          _buildClusterSection(
            'Powai',
            const Color(0xFF4CAF50),
            filteredData['Powai']!,
            isTablet,
            isMobile,
          ),
        
        if ((filteredData['Powai']?.isNotEmpty ?? false) && 
            (filteredData['Goregaon East']?.isNotEmpty ?? false))
          const SizedBox(height: 20),
        
        // Goregaon East Cluster
        if (filteredData['Goregaon East']?.isNotEmpty ?? false)
          _buildClusterSection(
            'Goregaon East',
            const Color(0xFF9C27B0),
            filteredData['Goregaon East']!,
            isTablet,
            isMobile,
          ),
        
        if ((filteredData['Goregaon East']?.isNotEmpty ?? false) && 
            (filteredData['Adhoc']?.isNotEmpty ?? false))
          const SizedBox(height: 20),
        
        // Adhoc Cluster
        if (filteredData['Adhoc']?.isNotEmpty ?? false)
          _buildClusterSection(
            'Adhoc',
            const Color(0xFF9C27B0),
            filteredData['Adhoc']!,
            isTablet,
            isMobile,
          ),
      ],
    );
  }

  Widget _buildClusterSection(
    String clusterName,
    Color clusterColor,
    List<DCRItem> items,
    bool isTablet,
    bool isMobile,
  ) {
    final callCount = items.where((item) => item.type == 'DCR').length;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Column(
        children: [
          // Cluster Header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 14 : 16,
            ),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: clusterColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    clusterName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: clusterColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$callCount Calls',
                    style: TextStyle(
                      color: clusterColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.currency_rupee,
                  color: Colors.orange,
                  size: 20,
                ),
              ],
            ),
          ),
          
           // Table Header (only for desktop/tablet)
           if (!isMobile)
             Container(
               padding: const EdgeInsets.symmetric(
                 horizontal: 16,
                 vertical: 14,
               ),
               decoration: BoxDecoration(
                 color: clusterColor.withOpacity(0.1),
                 borderRadius: const BorderRadius.only(
                   bottomLeft: Radius.circular(12),
                   bottomRight: Radius.circular(12),
                 ),
               ),
               child: _buildTableHeader(clusterColor),
             ),
          
          // Data Rows
          ...items.map((item) => _buildDataRow(item, clusterColor, isTablet, isMobile)),
        ],
      ),
    );
  }

  Widget _buildTableHeader(Color clusterColor) {
    return Row(
      children: const [
        Expanded(flex: 1, child: Text('Cluster', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
        SizedBox(width: 8),
        Expanded(flex: 2, child: Text('Customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
        SizedBox(width: 8),
        Expanded(flex: 2, child: Text('Purpose', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
        SizedBox(width: 8),
        SizedBox(width: 60, child: Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
        SizedBox(width: 8),
        SizedBox(width: 70, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
      ],
    );
  }

  Widget _buildMobileTableHeader(Color clusterColor) {
    return const Row(
      children: [
        Expanded(child: Text('Customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
        Expanded(child: Text('Purpose', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
        Expanded(child: Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
        Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
      ],
    );
  }

  Widget _buildDataRow(DCRItem item, Color clusterColor, bool isTablet, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 14 : 18,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: isMobile 
          ? _buildMobileDataRow(item, clusterColor)
          : _buildDesktopDataRow(item, clusterColor),
    );
  }

  Widget _buildDesktopDataRow(DCRItem item, Color clusterColor) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Text(
            item.cluster,
            style: const TextStyle(fontSize: 14, color: Color(0xFF12223B)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            item.customer,
            style: const TextStyle(fontSize: 14, color: Color(0xFF12223B)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            item.purpose,
            style: const TextStyle(fontSize: 14, color: Color(0xFF12223B)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: _buildTypeBadge(item.type),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusBadge(item.status),
              if (item.status == 'Approved') ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.purple,
                    shape: BoxShape.circle,
                  ),
                ),
              ] else if (item.status == 'Pending') ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ] else if (item.status == 'Draft') ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileDataRow(DCRItem item, Color clusterColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                item.customer,
                style: const TextStyle(fontSize: 14, color: Color(0xFF12223B), fontWeight: FontWeight.w500),
                maxLines: 3,
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
            ),
            const SizedBox(width: 8),
            _buildTypeBadge(item.type),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                item.purpose,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusBadge(item.status),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeBadge(String type) {
    Color backgroundColor;
    Color textColor;
    
    if (type == 'DCR') {
      backgroundColor = const Color(0xFF2563EB);
      textColor = Colors.white;
    } else {
      backgroundColor = Colors.orange;
      textColor = Colors.white;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    
    switch (status) {
      case 'Approved':
        backgroundColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        break;
      case 'Pending':
        backgroundColor = const Color(0xFFFFF4E5);
        textColor = const Color(0xFF9A6B00);
        break;
      case 'Draft':
        backgroundColor = const Color(0xFFF3E8FF);
        textColor = const Color(0xFF6A1B9A);
        break;
      default:
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Map<String, List<DCRItem>> _getFilteredData() {
    final allItems = _mockData;
    final filteredItems = <String, List<DCRItem>>{};
    
    for (final item in allItems) {
      // Filter by status
      final statusFilter = _status.replaceAll('Status: ', '');
      if (statusFilter != 'All' && item.status != statusFilter) {
        continue;
      }
      
      // Group by cluster
      if (filteredItems[item.cluster] == null) {
        filteredItems[item.cluster] = [];
      }
      filteredItems[item.cluster]!.add(item);
    }
    
    return filteredItems;
  }
}

class DCRItem {
  final String cluster;
  final String customer;
  final String purpose;
  final String type;
  final String status;

  DCRItem({
    required this.cluster,
    required this.customer,
    required this.purpose,
    required this.type,
    required this.status,
  });
}

final List<DCRItem> _mockData = [
  // Andheri East
  DCRItem(
    cluster: 'Andheri East',
    customer: 'Dr. Meera Joshi',
    purpose: 'Product Detailing',
    type: 'DCR',
    status: 'Approved',
  ),
  DCRItem(
    cluster: 'Andheri East',
    customer: 'Sunrise Clinic',
    purpose: 'Sample Collection',
    type: 'DCR',
    status: 'Pending',
  ),
  DCRItem(
    cluster: 'Andheri East',
    customer: 'Expense: Travel',
    purpose: 'Amount: Rs. 1,200',
    type: 'EXP',
    status: 'Pending',
  ),
  
  // Bandra West
  DCRItem(
    cluster: 'Bandra West',
    customer: 'Dr. Rajesh Shetty',
    purpose: 'Prescription Follow-up',
    type: 'DCR',
    status: 'Draft',
  ),
  DCRItem(
    cluster: 'Bandra West',
    customer: 'Expense: Food',
    purpose: 'Amount: Rs. 900',
    type: 'EXP',
    status: 'Draft',
  ),
  
  // Powai
  DCRItem(
    cluster: 'Powai',
    customer: 'Dr. Amit Deshmukh',
    purpose: 'Medicine Delivery',
    type: 'DCR',
    status: 'Approved',
  ),
  
  // Goregaon East
  DCRItem(
    cluster: 'Goregaon East',
    customer: 'Dr. Sneha Kulkarni',
    purpose: 'Adhoc Visit',
    type: 'DCR',
    status: 'Approved',
  ),
  
  // Adhoc
  DCRItem(
    cluster: 'Adhoc',
    customer: 'Apollo Pharmacy',
    purpose: 'Adhoc Visit',
    type: 'DCR',
    status: 'Approved',
  ),
  DCRItem(
    cluster: 'Adhoc',
    customer: 'Expense: Miscellaneous',
    purpose: 'Amount: Rs. 500',
    type: 'EXP',
    status: 'Pending',
  ),
];
