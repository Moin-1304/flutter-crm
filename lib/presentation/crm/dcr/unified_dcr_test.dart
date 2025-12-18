import 'package:flutter/material.dart';
import 'package:boilerplate/domain/entity/dcr/unified_dcr_item.dart';
import 'package:boilerplate/domain/entity/dcr/dcr_api_models.dart';

/// Test widget to demonstrate the unified DCR/Expense functionality
class UnifiedDcrTestScreen extends StatelessWidget {
  const UnifiedDcrTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample data based on the provided API response
    final sampleApiItems = [
      DcrApiItem(
        id: 65,
        cityId: 153024,
        createdBy: 0,
        status: 0,
        sbuId: 0,
        dcrStatusId: 3,
        dcrId: 52,
        tourPlanId: 9,
        employeeId: 61,
        dcrDate: "2025-10-30T00:00:00",
        isDeviationRequested: false,
        isBasedOnPlan: false,
        deviatedFrom: 0,
        customerLatitude: null,
        customerLongitude: null,
        remarks: null,
        active: true,
        userId: 0,
        tourPlanDCRDetails: const [],
        employeeName: "HOSHAN",
        designation: "Field Manager",
        clusterNames: "ATHURUGIRIYA",
        statusText: "Submitted",
        typeOfWork: "Product Promotion",
        customerName: "GOMEZ HOSPITAL",
        expenses: const [],
        customerId: 87,
        samplesToDistribute: null,
        productsToDiscuss: null,
        transactionType: "DCR",
        typeOfWorkId: 2,
        isGeneric: -1,
      ),
      DcrApiItem(
        id: 25,
        cityId: 152605,
        createdBy: 0,
        status: 0,
        sbuId: 0,
        dcrStatusId: 3,
        dcrId: 52,
        tourPlanId: 0,
        employeeId: 61,
        dcrDate: "2025-10-30T00:00:00",
        isDeviationRequested: false,
        isBasedOnPlan: false,
        deviatedFrom: 0,
        customerLatitude: 0,
        customerLongitude: 0,
        remarks: "Test",
        active: true,
        userId: 0,
        tourPlanDCRDetails: const [],
        employeeName: "HOSHAN",
        designation: "Field Manager",
        clusterNames: " HALI ELA",
        statusText: "Expense",
        typeOfWork: "Amount: 1200.00",
        customerName: "Expense: Accomodation",
        expenses: const [],
        customerId: 0,
        samplesToDistribute: null,
        productsToDiscuss: null,
        transactionType: "Expense",
        typeOfWorkId: 0,
        isGeneric: 1,
      ),
      DcrApiItem(
        id: 26,
        cityId: 152605,
        createdBy: 0,
        status: 0,
        sbuId: 0,
        dcrStatusId: 3,
        dcrId: 52,
        tourPlanId: 0,
        employeeId: 61,
        dcrDate: "2025-10-30T00:00:00",
        isDeviationRequested: false,
        isBasedOnPlan: false,
        deviatedFrom: 0,
        customerLatitude: 0,
        customerLongitude: 0,
        remarks: "Test",
        active: true,
        userId: 0,
        tourPlanDCRDetails: const [],
        employeeName: "HOSHAN",
        designation: "Field Manager",
        clusterNames: " HALI ELA",
        statusText: "Expense",
        typeOfWork: "Amount: 12.00",
        customerName: "Expense: Other",
        expenses: const [],
        customerId: 0,
        samplesToDistribute: null,
        productsToDiscuss: null,
        transactionType: "Expense",
        typeOfWorkId: 0,
        isGeneric: 1,
      ),
    ];

    // Convert to unified items
    final unifiedItems = sampleApiItems
        .map((item) => UnifiedDcrItem.fromDcrApiItem(item))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unified DCR/Expense Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Sample Unified DCR/Expense Items',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...unifiedItems.map((item) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.isDcr ? Colors.blue : Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.transactionType,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.statusText == 'Submitted' ? Colors.orange : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.statusText,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Employee: ${item.employeeName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Cluster: ${item.clusterDisplayName}'),
                  if (item.isDcr) ...[
                    Text('Customer: ${item.displayTitle}'),
                    Text('Purpose: ${item.displaySubtitle}'),
                  ] else ...[
                    Text('Expense Type: ${item.expenseType ?? 'Unknown'}'),
                    Text('Amount: ${item.expenseAmount != null ? 'Rs. ${item.expenseAmount!.toStringAsFixed(0)}' : 'Unknown'}'),
                    if (item.remarks.isNotEmpty) Text('Remarks: ${item.remarks}'),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // Simulate edit action
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Edit ${item.transactionType} ID: ${item.id}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (item.isDcr && item.tourPlanId == 0)
                        ElevatedButton.icon(
                          onPressed: () {
                            // Simulate create deviation action
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Create Deviation for DCR'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.alt_route, size: 16),
                          label: const Text('Create Dev'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}
