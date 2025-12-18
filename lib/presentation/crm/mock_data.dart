import 'package:boilerplate/domain/entity/dcr/dcr.dart';
import 'package:boilerplate/domain/entity/expense/expense.dart';

const List<String> kClusters = <String>[
  'Andheri East',
  'Bandra West',
  'Powai',
  'Goregaon East',
  'Adhoc',
];

const List<String> kCustomers = <String>[
  'Dr. Meera Joshi',
  'Sunrise Clinic',
  'Apollo Pharmacy',
  'Hiranandani Hospital',
  'Global Care',
];

const List<String> kPurposes = <String>[
  'Product Detailing',
  'Sample Collection',
  'Prescription Follow-up',
  'Medicine Delivery',
  'Adhoc Visit',
];

const List<String> kExpenseHeads = <String>[
  'Travel',
  'Food',
  'Miscellaneous',
];

List<DcrEntry> mockDcrsForDate(DateTime date) {
  final DateTime d = DateTime(date.year, date.month, date.day);
  return <DcrEntry>[
    DcrEntry(
      id: 'm1',
      date: d,
      cluster: 'Andheri East',
      customer: 'Sunrise Clinic',
      purposeOfVisit: 'Product Detailing',
      callDurationMinutes: 25,
      productsDiscussed: 'Device X',
      samplesDistributed: 'Sample A',
      keyDiscussionPoints: 'Discussed features',
      status: DcrStatus.approved,
      employeeId: 'me',
      employeeName: 'John Doe',
      linkedTourPlanId: 'tp_1',
      geoProximity: GeoProximity.at,
      createdAt: d,
      updatedAt: d,
    ),
    DcrEntry(
      id: 'm2',
      date: d,
      cluster: 'Andheri East',
      customer: 'Dr. Meera Joshi',
      purposeOfVisit: 'Follow-up',
      callDurationMinutes: 15,
      productsDiscussed: 'Device Y',
      samplesDistributed: 'Sample B',
      keyDiscussionPoints: 'Next steps',
      status: DcrStatus.submitted,
      employeeId: 'me',
      employeeName: 'John Doe',
      linkedTourPlanId: null,
      geoProximity: GeoProximity.near,
      createdAt: d,
      updatedAt: d,
    ),
    DcrEntry(
      id: 'm3',
      date: d,
      cluster: 'Bandra West',
      customer: 'Apollo Pharmacy',
      purposeOfVisit: 'Adhoc Visit',
      callDurationMinutes: 10,
      productsDiscussed: 'Device Z',
      samplesDistributed: 'Sample C',
      keyDiscussionPoints: 'Quick intro',
      status: DcrStatus.sentBack,
      employeeId: 'me',
      employeeName: 'John Doe',
      linkedTourPlanId: null,
      geoProximity: GeoProximity.away,
      createdAt: d,
      updatedAt: d,
    ),
  ];
}

List<ExpenseEntry> mockExpensesForDate(DateTime date) {
  final DateTime d = DateTime(date.year, date.month, date.day);
  return <ExpenseEntry>[
    ExpenseEntry(
      id: 'ex1',
      date: d,
      cluster: 'Andheri East',
      expenseHead: 'Travel',
      amount: 1200,
      remarks: 'Auto fare',
      proofFilePath: null,
      linkedDcrId: 'm2',
      status: ExpenseStatus.submitted,
      employeeId: 'me',
      employeeName: 'John Doe',
      createdAt: d,
      updatedAt: d,
    ),
    ExpenseEntry(
      id: 'ex2',
      date: d,
      cluster: 'Bandra West',
      expenseHead: 'Food',
      amount: 350,
      remarks: 'Lunch',
      proofFilePath: null,
      linkedDcrId: null,
      status: ExpenseStatus.draft,
      employeeId: 'me',
      employeeName: 'John Doe',
      createdAt: d,
      updatedAt: d,
    ),
  ];
}


