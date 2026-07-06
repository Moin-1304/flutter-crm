import 'package:flutter/foundation.dart';
import 'dcr_api_models.dart';
import 'package:boilerplate/utils/dcr_tour_plan_helper.dart';

/// Unified model to handle both DCR and Expense items from the API response
@immutable
class UnifiedDcrItem {
  const UnifiedDcrItem({
    required this.id,
    required this.transactionType,
    required this.employeeName,
    required this.designation,
    required this.clusterNames,
    required this.statusText,
    required this.dcrDate,
    required this.remarks,
    required this.customerName,
    required this.typeOfWork,
    required this.customerId,
    required this.cityId,
    required this.employeeId,
    required this.dcrId,
    required this.tourPlanId,
    required this.dcrStatusId,
    required this.typeOfWorkId,
    required this.isGeneric,
    this.customerLatitude,
    this.customerLongitude,
    this.samplesToDistribute,
    this.productsToDiscuss,
    this.expenses,
    // Service Engineer specific fields
    this.mappedInstruments,
    this.complaint,
    this.actionTaken,
    this.result,
    this.complaintStatus,
    this.complaintDate,
    this.complaintRemarks,
    this.serviceReportContactPerson,
    this.serviceReportContactMobile,
    this.serviceReportProduct,
    this.serviceReportSerialNumber,
    this.serviceReportServiceTypeText,
    this.dcrDetailIdServiceReport,
    this.serviceReportId,
    this.isServiceReportExists,
  });

  final int id;
  final String transactionType; // "DCR" or "Expense"
  final String employeeName;
  final String designation;
  final String clusterNames;
  final String statusText;
  final String dcrDate;
  final String remarks;
  final String customerName;
  final String typeOfWork;
  final int customerId;
  final int cityId;
  final int employeeId;
  final int dcrId;
  final int tourPlanId;
  final int dcrStatusId;
  final int typeOfWorkId;
  final int isGeneric;
  final double? customerLatitude;
  final double? customerLongitude;
  final String? samplesToDistribute;
  final String? productsToDiscuss;
  final List<ExpenseApiItem>? expenses;
  // Service Engineer specific fields (Service Report details)
  final List<Map<String, dynamic>>? mappedInstruments;
  final String? complaint;
  final String? actionTaken;
  final String? result;
  final String? complaintStatus; // Display string: "Resolved" or "Not Resolved"
  final String? complaintDate;
  final String? complaintRemarks;
  // Flattened Service Report fields from DCR list API
  final String? serviceReportContactPerson;
  final String? serviceReportContactMobile;
  final String? serviceReportProduct;
  final String? serviceReportSerialNumber;
  final String? serviceReportServiceTypeText;
  final int? dcrDetailIdServiceReport;
  final int? serviceReportId;
  final bool? isServiceReportExists;

  /// Whether the list API included any Service Report tab fields.
  bool get hasServiceReportListFields {
    return (serviceReportContactPerson?.trim().isNotEmpty ?? false) ||
        (serviceReportContactMobile?.trim().isNotEmpty ?? false) ||
        (serviceReportProduct?.trim().isNotEmpty ?? false) ||
        (serviceReportSerialNumber?.trim().isNotEmpty ?? false) ||
        (serviceReportServiceTypeText?.trim().isNotEmpty ?? false);
  }

  /// Factory constructor to create from DcrApiItem
  factory UnifiedDcrItem.fromDcrApiItem(DcrApiItem item) {
    // Try to get coordinates from tourPlanDCRDetails first, then fallback to direct fields
    double? latitude = item.customerLatitude;
    double? longitude = item.customerLongitude;
    
    // If direct coordinates are null, try to get from tourPlanDCRDetails
    if (latitude == null || longitude == null) {
      for (final detail in item.tourPlanDCRDetails) {
        if (detail.latitude != 0.0 && detail.longitude != 0.0) {
          latitude = detail.latitude;
          longitude = detail.longitude;
          break; // Use the first valid coordinate set
        }
      }
    }
    
    // Extract Service Report fields from the first TourPlanDcrDetail if available
    final TourPlanDcrDetail? detail = item.tourPlanDCRDetails.isNotEmpty
        ? item.tourPlanDCRDetails.first
        : null;

    final List<Map<String, dynamic>>? mappedInstruments = detail?.mappedInstruments;
    final String? complaint = detail?.complaint;
    final String? actionTaken = detail?.actionTaken;
    final String? result = detail?.result;
    final String? complaintStatus = detail?.complaintStatus != null
        ? (detail!.complaintStatus == 1 ? 'Resolved' : 'Not Resolved')
        : null;
    final String? complaintDate = detail?.complaintDate;
    final String? complaintRemarks = detail?.complaintRemarks;
    
    final int effectiveTypeOfWorkId = DcrTourPlanHelper.effectiveTypeOfWorkId(
      parentTypeOfWorkId: item.typeOfWorkId,
      detailTypeOfWorkId: detail?.typeOfWorkId,
    );

    final String apiPurposeText = DcrTourPlanHelper.apiPurposeText(
      parentTypeOfWork: item.typeOfWork,
    );

    final String remarksSource = DcrTourPlanHelper.resolveDcrRemarksSource(
      headerRemarks: item.remarks,
      detailRemarks: detail?.remarks ?? '',
    );

    return UnifiedDcrItem(
      id: item.id,
      transactionType: item.transactionType,
      employeeName: item.employeeName,
      designation: item.designation,
      clusterNames: item.clusterNames,
      statusText: item.statusText,
      dcrDate: item.dcrDate,
      remarks: DcrTourPlanHelper.resolveKeyDiscussionPoints(
        tourPlanId: item.tourPlanId,
        statusText: item.statusText,
        dcrStatusId: item.dcrStatusId,
        remarks: remarksSource,
        purposeOfVisit: apiPurposeText,
      ),
      customerName: item.customerName,
      typeOfWork: apiPurposeText,
      customerId: item.customerId,
      cityId: item.cityId,
      employeeId: item.employeeId,
      dcrId: item.dcrId,
      tourPlanId: item.tourPlanId,
      dcrStatusId: item.dcrStatusId,
      typeOfWorkId: effectiveTypeOfWorkId,
      isGeneric: item.isGeneric,
      customerLatitude: latitude,
      customerLongitude: longitude,
      samplesToDistribute: item.samplesToDistribute,
      productsToDiscuss: item.productsToDiscuss,
      expenses: item.expenses,
      // Extract Service Report fields from tourPlanDCRDetails if available
      mappedInstruments: mappedInstruments,
      complaint: complaint,
      actionTaken: actionTaken,
      result: result,
      complaintStatus: complaintStatus,
      complaintDate: complaintDate,
      complaintRemarks: complaintRemarks,
      serviceReportContactPerson: item.serviceReportContactPerson,
      serviceReportContactMobile: item.serviceReportContactMobile,
      serviceReportProduct: item.serviceReportProduct,
      serviceReportSerialNumber: item.serviceReportSerialNumber,
      serviceReportServiceTypeText: item.serviceReportServiceTypeText,
      dcrDetailIdServiceReport: item.dcrDetailIdServiceReport,
      serviceReportId: item.serviceReportId,
      isServiceReportExists: item.isServiceReportExists,
    );
  }

  /// Factory constructor to create from DcrMapDetailsItem
  factory UnifiedDcrItem.fromDcrMapDetailsItem(DcrMapDetailsItem item) {
    // Use latitude/longitude from the item (prefer latitude/longitude over customerLatitude/customerLongitude)
    double? latitude = item.latitude;
    double? longitude = item.longitude;
    
    // Fallback to customerLatitude/customerLongitude if latitude/longitude are null
    if (latitude == null || longitude == null) {
      latitude = item.customerLatitude;
      longitude = item.customerLongitude;
    }

    // For managers, prefer createdDate (when DCR was entered) over dcrDate
    // createdDate represents the actual time when the DCR was entered
    String dcrDateTime;
    if (item.createdDate != null && 
        item.createdDate!.isNotEmpty && 
        !item.createdDate!.startsWith('0001-01-01')) {
      // Use createdDate if it's valid (not the default null date)
      dcrDateTime = item.createdDate!;
    } else if (item.dcrDate != null && 
               item.dcrDate!.isNotEmpty && 
               !item.dcrDate!.startsWith('0001-01-01')) {
      // Fallback to dcrDate if createdDate is not valid
      dcrDateTime = item.dcrDate!;
    } else {
      // Use current time as last resort
      dcrDateTime = DateTime.now().toIso8601String();
    }

    final int typeOfWorkId = item.typeOfWorkId ?? 0;
    final String apiPurposeText = DcrTourPlanHelper.apiPurposeText(
      parentTypeOfWork: item.typeOfWork ?? '',
    );

    return UnifiedDcrItem(
      id: item.id ?? 0,
      transactionType: item.transactionType ?? 'DCR',
      employeeName: item.employeeName ?? 'Unknown',
      designation: item.designation ?? '',
      clusterNames: item.clusterNames ?? '',
      statusText: item.statusText ?? 'Unknown',
      dcrDate: dcrDateTime,
      remarks: DcrTourPlanHelper.resolveKeyDiscussionPoints(
        tourPlanId: item.tourPlanId ?? 0,
        statusText: item.statusText ?? '',
        dcrStatusId: item.dcrStatusId,
        remarks: item.remarks ?? '',
        purposeOfVisit: apiPurposeText,
      ),
      customerName: item.customerName ?? 'Unknown Customer',
      typeOfWork: apiPurposeText,
      customerId: item.customerId ?? 0,
      cityId: item.cityId ?? 0,
      employeeId: item.employeeId ?? 0,
      dcrId: item.dcrId ?? 0,
      tourPlanId: item.tourPlanId ?? 0,
      dcrStatusId: item.dcrStatusId ?? 0,
      typeOfWorkId: typeOfWorkId,
      isGeneric: item.isGeneric ?? 0,
      customerLatitude: latitude,
      customerLongitude: longitude,
      samplesToDistribute: item.samplesToDistribute,
      productsToDiscuss: item.productsToDiscuss,
      expenses: null,
    );
  }

  /// Factory constructor to create from DcrGetResponse (Get API)
  factory UnifiedDcrItem.fromDcrGetResponse(DcrGetResponse response) {
    // Get the first DCR detail from tourPlanDCRDetails array
    final TourPlanDcrDetailGet? detail = response.tourPlanDCRDetails.isNotEmpty
        ? response.tourPlanDCRDetails.first
        : null;

    if (detail == null) {
      throw Exception('No DCR details found in response');
    }

    // Extract Service Report fields from TourPlanDcrDetailGet
    final List<Map<String, dynamic>>? mappedInstruments = detail.mappedInstruments;
    final String? complaint = detail.complaint;
    final String? actionTaken = detail.actionTaken;
    final String? result = detail.result;
    final String? complaintStatus = detail.complaintStatus != null
        ? (detail.complaintStatus == 1 ? 'Resolved' : 'Not Resolved')
        : null;
    final String? complaintDate = detail.complaintDate;
    final String? complaintRemarks = detail.complaintRemarks;

    // Get coordinates
    double? latitude = detail.customerLatitude;
    double? longitude = detail.customerLongitude;
    if (latitude == null || longitude == null || latitude == 0.0 || longitude == 0.0) {
      latitude = detail.latitude != 0.0 ? detail.latitude : null;
      longitude = detail.longitude != 0.0 ? detail.longitude : null;
    }

    print('UnifiedDcrItem.fromDcrGetResponse - Service Report Fields Extraction:');
    print('  - DCR ID: ${response.dcrId}, Response ID: ${response.id}');
    print('  - tourPlanDCRDetails count: ${response.tourPlanDCRDetails.length}');
    if (detail != null) {
      print('  - First detail ID: ${detail.id}');
      print('  - mappedInstruments from Get API: "${detail.mappedInstruments}"');
      print('  - complaint from Get API: "${detail.complaint}"');
      print('  - actionTaken from Get API: "${detail.actionTaken}"');
      print('  - result from Get API: "${detail.result}"');
      print('  - complaintStatus from Get API: "${detail.complaintStatus}"');
      print('  - complaintDate from Get API: "${detail.complaintDate}"');
      print('  - complaintRemarks from Get API: "${detail.complaintRemarks}"');
    }
    print('  - Extracted mappedInstruments: "$mappedInstruments"');
    print('  - Extracted complaint: "$complaint"');
    print('  - Extracted actionTaken: "$actionTaken"');
    print('  - Extracted result: "$result"');
    print('  - Extracted complaintStatus: "$complaintStatus"');
    print('  - Extracted complaintDate: "$complaintDate"');
    print('  - Extracted complaintRemarks: "$complaintRemarks"');

    final int effectiveTypeOfWorkId = DcrTourPlanHelper.effectiveTypeOfWorkId(
      parentTypeOfWorkId: response.typeOfWorkId,
      detailTypeOfWorkId: detail.typeOfWorkId,
    );

    final String apiPurposeText = DcrTourPlanHelper.apiPurposeText(
      parentTypeOfWork: response.typeOfWork,
    );

    final String remarksSource = DcrTourPlanHelper.resolveDcrRemarksSource(
      headerRemarks: response.remarks,
      detailRemarks: detail.remarks,
    );

    return UnifiedDcrItem(
      id: detail.id ?? response.id,
      transactionType: response.transactionType.isNotEmpty ? response.transactionType : 'DCR',
      employeeName: response.employeeName.isNotEmpty ? response.employeeName : 'Unknown',
      designation: response.designation.isNotEmpty ? response.designation : '',
      clusterNames: detail.clusterNames.isNotEmpty ? detail.clusterNames : (response.clusterNames.isNotEmpty ? response.clusterNames : 'Unknown'),
      statusText: response.statusText.isNotEmpty ? response.statusText : 'Unknown',
      dcrDate: response.dcrDate.isNotEmpty ? response.dcrDate : DateTime.now().toIso8601String(),
      remarks: DcrTourPlanHelper.resolveKeyDiscussionPoints(
        tourPlanId: response.tourPlanId,
        statusText: response.statusText,
        dcrStatusId: response.dcrStatusId,
        remarks: remarksSource,
        purposeOfVisit: apiPurposeText,
      ),
      customerName: detail.customerName.isNotEmpty ? detail.customerName : (response.customerName.isNotEmpty ? response.customerName : 'Unknown Customer'),
      typeOfWork: apiPurposeText,
      customerId: detail.customerId,
      cityId: detail.cityId,
      employeeId: response.employeeId,
      dcrId: response.dcrId > 0 ? response.dcrId : response.id,
      tourPlanId: response.tourPlanId,
      dcrStatusId: response.dcrStatusId,
      typeOfWorkId: effectiveTypeOfWorkId,
      isGeneric: response.isGeneric,
      customerLatitude: latitude,
      customerLongitude: longitude,
      samplesToDistribute: detail.samplesToDistribute.isNotEmpty ? detail.samplesToDistribute : (response.samplesToDistribute.isNotEmpty ? response.samplesToDistribute : null),
      productsToDiscuss: detail.productsToDiscuss.isNotEmpty ? detail.productsToDiscuss : (response.productsToDiscuss.isNotEmpty ? response.productsToDiscuss : null),
      expenses: response.expenses.isNotEmpty ? response.expenses : null,
      // Service Report fields from Get API
      mappedInstruments: mappedInstruments,
      complaint: complaint,
      actionTaken: actionTaken,
      result: result,
      complaintStatus: complaintStatus,
      complaintDate: complaintDate,
      complaintRemarks: complaintRemarks,
    );
  }

  /// Check if this is a DCR item
  bool get isDcr => transactionType == 'DCR';

  /// Check if this is an Expense item
  bool get isExpense => transactionType == 'Expense';

  /// Get the display title for the item
  String get displayTitle {
    if (isDcr) {
      return customerName;
    } else {
      return customerName; // For expenses, customerName contains the expense description
    }
  }

  /// Get the display subtitle for the item
  String get displaySubtitle {
    if (isDcr) {
      return typeOfWork;
    } else {
      return typeOfWork; // For expenses, typeOfWork contains the amount
    }
  }

  /// Get the cluster name for display
  String get clusterDisplayName {
    return clusterNames.trim().isNotEmpty ? clusterNames.trim() : 'Unknown';
  }

  /// Parse the DCR date to DateTime
  DateTime? get parsedDate {
    try {
      return DateTime.parse(dcrDate);
    } catch (e) {
      return null;
    }
  }

  /// Get the amount for expense items
  double? get expenseAmount {
    if (isExpense && typeOfWork.contains('Amount:')) {
      try {
        final amountStr = typeOfWork.replaceAll('Amount:', '').replaceAll('LKR', '').trim();
        return double.parse(amountStr);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Get the expense type for expense items
  String? get expenseType {
    if (isExpense && customerName.contains('Expense:')) {
      return customerName.replaceAll('Expense:', '').trim();
    }
    return null;
  }

  UnifiedDcrItem copyWith({
    int? id,
    String? transactionType,
    String? employeeName,
    String? designation,
    String? clusterNames,
    String? statusText,
    String? dcrDate,
    String? remarks,
    String? customerName,
    String? typeOfWork,
    int? customerId,
    int? cityId,
    int? employeeId,
    int? dcrId,
    int? tourPlanId,
    int? dcrStatusId,
    int? typeOfWorkId,
    int? isGeneric,
    double? customerLatitude,
    double? customerLongitude,
    String? samplesToDistribute,
    String? productsToDiscuss,
    List<ExpenseApiItem>? expenses,
    List<Map<String, dynamic>>? mappedInstruments,
    String? complaint,
    String? actionTaken,
    String? result,
    String? complaintStatus,
    String? complaintDate,
    String? complaintRemarks,
    String? serviceReportContactPerson,
    String? serviceReportContactMobile,
    String? serviceReportProduct,
    String? serviceReportSerialNumber,
    String? serviceReportServiceTypeText,
    int? dcrDetailIdServiceReport,
    int? serviceReportId,
    bool? isServiceReportExists,
  }) {
    return UnifiedDcrItem(
      id: id ?? this.id,
      transactionType: transactionType ?? this.transactionType,
      employeeName: employeeName ?? this.employeeName,
      designation: designation ?? this.designation,
      clusterNames: clusterNames ?? this.clusterNames,
      statusText: statusText ?? this.statusText,
      dcrDate: dcrDate ?? this.dcrDate,
      remarks: remarks ?? this.remarks,
      customerName: customerName ?? this.customerName,
      typeOfWork: typeOfWork ?? this.typeOfWork,
      customerId: customerId ?? this.customerId,
      cityId: cityId ?? this.cityId,
      employeeId: employeeId ?? this.employeeId,
      dcrId: dcrId ?? this.dcrId,
      tourPlanId: tourPlanId ?? this.tourPlanId,
      dcrStatusId: dcrStatusId ?? this.dcrStatusId,
      typeOfWorkId: typeOfWorkId ?? this.typeOfWorkId,
      isGeneric: isGeneric ?? this.isGeneric,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      samplesToDistribute: samplesToDistribute ?? this.samplesToDistribute,
      productsToDiscuss: productsToDiscuss ?? this.productsToDiscuss,
      expenses: expenses ?? this.expenses,
      mappedInstruments: mappedInstruments ?? this.mappedInstruments,
      complaint: complaint ?? this.complaint,
      actionTaken: actionTaken ?? this.actionTaken,
      result: result ?? this.result,
      complaintStatus: complaintStatus ?? this.complaintStatus,
      complaintDate: complaintDate ?? this.complaintDate,
      complaintRemarks: complaintRemarks ?? this.complaintRemarks,
      serviceReportContactPerson:
          serviceReportContactPerson ?? this.serviceReportContactPerson,
      serviceReportContactMobile:
          serviceReportContactMobile ?? this.serviceReportContactMobile,
      serviceReportProduct: serviceReportProduct ?? this.serviceReportProduct,
      serviceReportSerialNumber:
          serviceReportSerialNumber ?? this.serviceReportSerialNumber,
      serviceReportServiceTypeText:
          serviceReportServiceTypeText ?? this.serviceReportServiceTypeText,
      dcrDetailIdServiceReport:
          dcrDetailIdServiceReport ?? this.dcrDetailIdServiceReport,
      serviceReportId: serviceReportId ?? this.serviceReportId,
      isServiceReportExists:
          isServiceReportExists ?? this.isServiceReportExists,
    );
  }
}
