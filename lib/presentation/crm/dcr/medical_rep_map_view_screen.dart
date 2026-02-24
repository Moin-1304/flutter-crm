import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:boilerplate/domain/entity/dcr/unified_dcr_item.dart';
import 'package:boilerplate/domain/entity/dcr/dcr_api_models.dart';
import 'package:boilerplate/domain/repository/dcr/dcr_repository.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart' show CommonDropdownItem;
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/presentation/crm/dcr/base_dcr_map_view_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Medical Rep Map View screen showing doctor visits on a map for selected date range
class MedicalRepMapViewScreen extends StatefulWidget {
  final DateTime fromDate;
  final DateTime toDate;
  final int? employeeId;
  
  const MedicalRepMapViewScreen({
    super.key,
    required this.fromDate,
    required this.toDate,
    this.employeeId,
  });

  @override
  State<MedicalRepMapViewScreen> createState() => _MedicalRepMapViewScreenState();
}

class _MedicalRepMapViewScreenState extends State<MedicalRepMapViewScreen> {
  bool _isLoading = true;
  List<UnifiedDcrItem> _dcrItems = [];

  @override
  void initState() {
    super.initState();
    _loadDcrData();
  }

  Future<void> _loadDcrData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final DcrRepository? dcrRepo = getIt.isRegistered<DcrRepository>()
          ? getIt<DcrRepository>()
          : null;
      final CommonRepository? commonRepo = getIt.isRegistered<CommonRepository>()
          ? getIt<CommonRepository>()
          : null;

      if (dcrRepo == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>()
          ? getIt<UserDetailStore>()
          : null;
      final int? managerId = userStore?.userDetail?.employeeId;

      if (managerId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      List<DcrApiItem> apiItems = [];

      if (widget.employeeId != null) {
        // Single employee (e.g. from filter)
        apiItems = await dcrRepo.getDcrListUnified(
          start: widget.fromDate,
          end: widget.toDate,
          employeeId: widget.employeeId.toString(),
          transactionType: 'DCR',
        );
      } else {
        // Load manager's DCRs + all team members' DCRs for the date range
        apiItems = await dcrRepo.getDcrListUnified(
          start: widget.fromDate,
          end: widget.toDate,
          employeeId: managerId.toString(),
          transactionType: 'DCR',
        );
        if (commonRepo != null) {
          try {
            final List<CommonDropdownItem> teamItems = await commonRepo.getEmployeesReportingTo(managerId);
            for (final item in teamItems) {
              final int empId = item.id;
              if (empId != managerId) {
                try {
                  final List<DcrApiItem> teamDcrs = await dcrRepo.getDcrListUnified(
                    start: widget.fromDate,
                    end: widget.toDate,
                    employeeId: empId.toString(),
                    transactionType: 'DCR',
                  );
                  apiItems.addAll(teamDcrs);
                } catch (e) {
                  print('MedicalRepMapViewScreen: Error loading DCRs for employee $empId: $e');
                }
              }
            }
          } catch (e) {
            print('MedicalRepMapViewScreen: Error loading team list: $e');
          }
        }
      }

      final validDcrs = apiItems
          .where((item) {
            if (item.transactionType != 'DCR') return false;
            final lat = item.customerLatitude;
            final lng = item.customerLongitude;
            return lat != null &&
                lng != null &&
                lat != 0.0 &&
                lng != 0.0;
          })
          .map((item) => UnifiedDcrItem.fromDcrApiItem(item))
          .toList();

      if (mounted) {
        setState(() {
          _dcrItems = validDcrs;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('MedicalRepMapViewScreen: Error loading DCR data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Map View For Doctors Visits',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final dateRangeText = '${DateFormat('MMM dd, yyyy').format(widget.fromDate)} - ${DateFormat('MMM dd, yyyy').format(widget.toDate)}';

    return BaseDcrMapViewScreen(
      dcrItems: _dcrItems,
      title: 'Map View For Doctors Visits',
      dateRangeText: dateRangeText,
      markerColor: BitmapDescriptor.hueCyan,
      emptyStateTitle: 'No DCR Data Found',
      emptyStateMessage: 'No doctor visits with location data available\nfor the selected date range',
      alwaysShowMap: true, // Always show map even if no data
    );
  }
}
