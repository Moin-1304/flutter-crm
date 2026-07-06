import 'package:boilerplate/utils/purpose_visit_helper.dart';

/// DCR Form Type of Visit — separate from Tour Plan purpose-of-visit masters.
class DcrPurposeVisitCommandTypes {
  DcrPurposeVisitCommandTypes._();

  /// CommandType.DCRPurposeOfVisitServiceEngineer
  static const int purposeOfVisitServiceEngineer = 336;

  /// CommandType.DCRPurposeOfVisitSalesrep
  static const int purposeOfVisitSalesRep = 337;

  /// CommandType.DCRPocRepType (POC Rep + Application Engineer on website)
  static const int pocRepType = 338;
}

class DcrPurposeVisitTexts {
  DcrPurposeVisitTexts._();

  static const String serviceEngineer = 'DCRPurposeOfVisit - ServiceEngineer';
  static const String salesRep = 'DCRPurposeOfVisit - Salesrep';
  static const String pocRep = 'DCR-PocRepType';
  static const String applicationEng = 'DCR-ApplicationEngPurposeOfVisit';
}

/// One Common/GetAuto payload for DCR Type of Visit.
class DcrPurposeVisitConfig {
  const DcrPurposeVisitConfig({
    required this.commandType,
    required this.text,
  });

  final int commandType;
  final String text;
}

/// Resolves DCR Type of Visit API payloads from [CurrentEmployeeReptypeText].
class DcrPurposeVisitHelper {
  DcrPurposeVisitHelper._();

  static const DcrPurposeVisitConfig serviceEngineer = DcrPurposeVisitConfig(
    commandType: DcrPurposeVisitCommandTypes.purposeOfVisitServiceEngineer,
    text: DcrPurposeVisitTexts.serviceEngineer,
  );

  static const DcrPurposeVisitConfig pocRep = DcrPurposeVisitConfig(
    commandType: DcrPurposeVisitCommandTypes.pocRepType,
    text: DcrPurposeVisitTexts.pocRep,
  );

  /// Application Engineer: CommandType.DCRPocRepType + DCR-ApplicationEngPurposeOfVisit
  static const DcrPurposeVisitConfig application = DcrPurposeVisitConfig(
    commandType: DcrPurposeVisitCommandTypes.pocRepType,
    text: DcrPurposeVisitTexts.applicationEng,
  );

  static const DcrPurposeVisitConfig salesRep = DcrPurposeVisitConfig(
    commandType: DcrPurposeVisitCommandTypes.purposeOfVisitSalesRep,
    text: DcrPurposeVisitTexts.salesRep,
  );

  /// All DCR purpose masters (for ID/name lookup when viewing saved DCRs).
  static const List<DcrPurposeVisitConfig> allConfigs = <DcrPurposeVisitConfig>[
    serviceEngineer,
    pocRep,
    application,
    salesRep,
  ];

  static String _normalize(String? value) =>
      (value ?? '').trim().toLowerCase();

  /// Website: CurrentEmployeeReptypeText == "Service Engineer"
  static bool _isServiceEngineerRole(String? repTypeText) {
    final String t = _normalize(repTypeText);
    return t == 'service engineer' ||
        t.contains('service engineer') ||
        t.contains('service eng');
  }

  /// Website: CurrentEmployeeReptypeText == "Poc Rep"
  static bool _isPocRepRole(String? repTypeText) {
    final String t = _normalize(repTypeText);
    if (t.isEmpty) return false;
    return t == 'poc rep' ||
        t == 'poc representative' ||
        t.contains('poc');
  }

  /// Website: CurrentEmployeeReptypeText == "Application"
  static bool _isApplicationRole(String? repTypeText) {
    final String t = _normalize(repTypeText);
    if (t.isEmpty) return false;
    return t == 'application' ||
        t == 'application engineer' ||
        t == 'application eng' ||
        t.contains('application');
  }

  /// POC Rep for DCR when profile text is empty (repType 3).
  static bool isPocRepForDcr({
    int? repType,
    int? roleCategory,
    String? repTypeText,
    String? serviceArea,
    String? designation,
    String? roleText,
  }) {
    if (_isApplicationRole(repTypeText) ||
        _isApplicationRole(roleText) ||
        _normalize(serviceArea).contains('application') ||
        _normalize(designation).contains('application')) {
      return false;
    }
    if (PurposeVisitHelper.isPocRep(
      repType: repType,
      roleCategory: roleCategory,
      repTypeText: repTypeText,
      serviceArea: serviceArea,
      designation: designation,
    )) {
      return true;
    }
    if (_isPocRepRole(roleText)) return true;
    if (repType == 3) return true;
    return false;
  }

  /// Application Engineer for DCR (CommandType 338 + DCR-ApplicationEngPurposeOfVisit).
  static bool isApplicationEngineerForDcr({
    String? repTypeText,
    String? serviceArea,
    int? repType,
    String? designation,
    String? roleText,
  }) {
    if (_isApplicationRole(repTypeText)) return true;
    if (_isApplicationRole(roleText)) return true;
    if (PurposeVisitHelper.isApplicationEngineer(
      serviceArea: serviceArea,
      repType: repType,
      repTypeText: repTypeText ?? roleText,
      designation: designation ?? roleText,
    )) {
      return true;
    }
    if (_normalize(serviceArea).contains('application')) return true;
    if (_normalize(designation).contains('application')) return true;
    // ERP repType when repTypeText/serviceArea are empty (Production: Supunika = 6).
    if (repType == 4 || repType == 6) return true;
    return false;
  }

  /// Website if/else chain on [CurrentEmployeeReptypeText].
  static DcrPurposeVisitConfig resolveForRepTypeText(String? repTypeText) {
    if (_isServiceEngineerRole(repTypeText)) {
      return serviceEngineer;
    }
    if (_isPocRepRole(repTypeText)) {
      return pocRep;
    }
    if (_isApplicationRole(repTypeText)) {
      return application;
    }
    return salesRep;
  }

  /// Resolves DCR dropdown API for the current employee (website order).
  static DcrPurposeVisitConfig resolveForEmployee({
    String? repTypeText,
    String? serviceArea,
    int? repType,
    int? roleCategory,
    String? designation,
    String? roleText,
  }) {
    final String? primaryText = (repTypeText ?? '').trim().isNotEmpty
        ? repTypeText!.trim()
        : ((roleText ?? '').trim().isNotEmpty ? roleText!.trim() : null);

    // 1) Service Engineer
    if (_isServiceEngineerRole(primaryText) ||
        PurposeVisitHelper.isServiceEngineer(
          serviceArea: serviceArea,
          repType: repType,
          repTypeText: primaryText,
          designation: designation,
        ) ||
        repType == 5) {
      return serviceEngineer;
    }

    // 2) Poc Rep — before Application (website else-if order)
    if (isPocRepForDcr(
      repType: repType,
      roleCategory: roleCategory,
      repTypeText: primaryText,
      serviceArea: serviceArea,
      designation: designation,
      roleText: roleText,
    )) {
      return pocRep;
    }

    // 3) Application — CommandType.DCRPocRepType, Text DCR-ApplicationEngPurposeOfVisit
    if (isApplicationEngineerForDcr(
      repTypeText: primaryText,
      serviceArea: serviceArea,
      repType: repType,
      designation: designation,
      roleText: roleText,
    )) {
      return application;
    }

    if (primaryText != null) {
      return resolveForRepTypeText(primaryText);
    }

    final String area = _normalize(serviceArea);
    if (area.contains('service engineer') || area.contains('service eng')) {
      return serviceEngineer;
    }
    if (area.contains('poc')) {
      return pocRep;
    }
    if (area.contains('application')) {
      return application;
    }
    if (area.contains('medical') || area.contains('sales')) {
      return salesRep;
    }

    if (repType == 4 || repType == 6) {
      return application;
    }

    if (repType == 2 || repType == 1) {
      return salesRep;
    }

    return salesRep;
  }

  /// Label for logs from profile fields.
  static String describeEmployeeRole({
    String? repTypeText,
    String? serviceArea,
    int? repType,
    int? roleCategory,
    String? designation,
    String? roleText,
  }) {
    if ((repTypeText ?? '').trim().isNotEmpty) {
      return repTypeText!.trim();
    }
    if ((roleText ?? '').trim().isNotEmpty) {
      return roleText!.trim();
    }
    if (isApplicationEngineerForDcr(
      serviceArea: serviceArea,
      repType: repType,
      designation: designation,
      roleText: roleText,
    )) {
      return 'Application';
    }
    if (isPocRepForDcr(
      repType: repType,
      roleCategory: roleCategory,
      serviceArea: serviceArea,
      designation: designation,
      roleText: roleText,
    )) {
      return 'Poc Rep';
    }
    if (repType == 5) return 'Service Engineer';
    if (repType == 4 || repType == 6) return 'Application';
    if (repType == 2) return 'Medical Rep';
    if (repType == 1) return 'Sales Rep';
    final String area = (serviceArea ?? '').trim();
    if (area.isNotEmpty) return area;
    return '';
  }

  /// DCR website sends [UserId] = employee id (not login user id).
  static int resolveDcrPurposeUserId({
    required int? employeeId,
    int? loginUserId,
  }) {
    if (employeeId != null && employeeId > 0) {
      return employeeId;
    }
    if (loginUserId != null && loginUserId > 0) {
      return loginUserId;
    }
    return 0;
  }

  /// Service Engineer DCR purpose when no field visits are planned for the day.
  static const String serviceEngineerAvailablePurposeLabel = 'Available';

  /// Remarks shown when viewing/saving an Available DCR.
  static const String serviceEngineerAvailableRemarks =
      'Service engineer is available';

  static bool isServiceEngineerAvailablePurpose(String? purpose) {
    return _normalize(purpose) == 'available';
  }

  /// Ensures Available DCRs always persist/display the standard remarks text.
  static String resolveRemarksForAvailablePurpose({
    required String? purposeOfVisit,
    required String discussionText,
  }) {
    if (!isServiceEngineerAvailablePurpose(purposeOfVisit)) {
      return discussionText.trim();
    }
    final String trimmed = discussionText.trim();
    if (trimmed.isEmpty ||
        trimmed.toLowerCase() == serviceEngineerAvailablePurposeLabel) {
      return serviceEngineerAvailableRemarks;
    }
    return trimmed;
  }
}
