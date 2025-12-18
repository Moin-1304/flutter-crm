import 'package:boilerplate/domain/entity/tour_plan/tour_plan.dart' as domain;
import 'package:boilerplate/presentation/crm/tour_plan/widgets/status_summary.dart';

List<domain.TourPlanEntry> mockTourPlanEntriesForMonth(DateTime month) {
  final DateTime m = DateTime(month.year, month.month, 1);
  final DateTime now = DateTime.now();
  final List<_Seed> seeds = <_Seed>[
    _Seed(day: 1, customer: 'Apollo Hospital', status: domain.TourPlanEntryStatus.approved, purposes: ['Product Detailing']),
    _Seed(day: 2, customer: 'Fortis Healthcare', status: domain.TourPlanEntryStatus.pending, purposes: ['Field Visit']),
    _Seed(day: 5, customer: 'Global Care', status: domain.TourPlanEntryStatus.draft, purposes: ['Onboarding']),
    _Seed(day: 6, customer: 'Medanta Clinic', status: domain.TourPlanEntryStatus.draft, purposes: ['Follow-up']),
    _Seed(day: 9, customer: 'LifeLine Hospital', status: domain.TourPlanEntryStatus.pending, purposes: ['Device Trial']),
    _Seed(day: 12, customer: 'Prime Health', status: domain.TourPlanEntryStatus.rejected, purposes: ['Adhoc Visit']),
    _Seed(day: 15, customer: 'City Pharma', status: domain.TourPlanEntryStatus.sentBack, purposes: ['Sample Collection']),
    _Seed(day: 18, customer: 'Care & Cure Center', status: domain.TourPlanEntryStatus.pending, purposes: ['Prescription Follow-up']),
    _Seed(day: 21, customer: 'Sunrise Clinic', status: domain.TourPlanEntryStatus.approved, purposes: ['Sample Collection']),
    _Seed(day: 24, customer: 'Hiranandani Hospital', status: domain.TourPlanEntryStatus.pending, purposes: ['Product Detailing']),
  ];
  return [
    for (final s in seeds)
      domain.TourPlanEntry(
        id: '${m.year}${m.month}${s.day}${s.customer.hashCode}',
        date: DateTime(m.year, m.month, s.day),
        cluster: 'Andheri East',
        customer: s.customer,
        employeeId: 'emp1',
        employeeName: 'John Manager',
        status: s.status,
        callDetails: domain.TourPlanCallDetails(
          purposes: s.purposes,
          productsToDiscuss: 'Device X, Device Y',
          samplesToDistribute: 'Sample A',
          remarks: 'Mock plan',
        ),
        createdAt: now,
        updatedAt: now,
      )
  ];
}


class _Seed {
  _Seed({required this.day, required this.customer, required this.status, required this.purposes});
  final int day;
  final String customer;
  final domain.TourPlanEntryStatus status;
  final List<String> purposes;
}


