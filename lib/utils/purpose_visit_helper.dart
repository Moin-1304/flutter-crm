import 'package:boilerplate/core/data/network/dio/dio_client.dart';
import 'package:boilerplate/data/network/apis/user/user_api_client.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/domain/entity/user/user_detail.dart';
import 'package:boilerplate/presentation/login/store/login_store.dart' as login;
import 'package:boilerplate/presentation/user/store/user_store.dart';

/// API [Text] values for Common/GetAuto CommandType 337 (Purpose of Visit).
class PurposeVisitTexts {
  PurposeVisitTexts._();

  static const String salesRep = 'Salesrep PurposeVisit';
  static const String serviceEng = 'ServiceEng PurposeVisit';
  static const String pocRepTourPlan = 'PocRep-PurposeofVisit';
  static const String applicationEng = 'ApplicationEng-PurposeOfVisit';
  static const String pocRepDcr = 'DCR-PocRepType';

  /// All purpose API texts merged for ID/name lookup across roles.
  static const List<String> allPurposeVisitApiTexts = <String>[
    salesRep,
    serviceEng,
    pocRepTourPlan,
    applicationEng,
    pocRepDcr,
  ];
}

/// Tour plan vs DCR can use different CommandType 337 [Text] for the same role (POC Rep).
enum PurposeVisitContext {
  tourPlan,
  dcr,
}

/// Resolves which Purpose-of-Visit master list to load from the API.
class PurposeVisitHelper {
  PurposeVisitHelper._();

  static String _normalize(String? value) =>
      (value ?? '').trim().toLowerCase();

  /// Web-aligned: [RepTypetext] from CommandType 276 → CommandType 337 [Text].
  static String purposeVisitTextFromRepTypeText(String? repTypeText) {
    final String t = _normalize(repTypeText);
    if (t.isEmpty) return PurposeVisitTexts.salesRep;

    if (t.contains('service engineer') || t.contains('service eng')) {
      return PurposeVisitTexts.serviceEng;
    }
    if (t.contains('poc')) {
      return PurposeVisitTexts.pocRepTourPlan;
    }
    if (t.contains('application')) {
      return PurposeVisitTexts.applicationEng;
    }
    if (t.contains('medical')) {
      return PurposeVisitTexts.salesRep;
    }
    if (t.contains('sales')) {
      return PurposeVisitTexts.salesRep;
    }
    return PurposeVisitTexts.salesRep;
  }

  /// When [serviceArea] is set on the user profile (CommandType 276 / User/Get).
  static String? purposeVisitTextFromServiceArea(String? serviceArea) {
    final String t = _normalize(serviceArea);
    if (t.isEmpty) return null;

    if (t.contains('service engineer') || t.contains('service eng')) {
      return PurposeVisitTexts.serviceEng;
    }
    if (t.contains('poc')) {
      return PurposeVisitTexts.pocRepTourPlan;
    }
    if (t.contains('application')) {
      return PurposeVisitTexts.applicationEng;
    }
    // Medical Rep and Sales Rep share the sales purpose master on the website.
    if (t.contains('medical') || t.contains('sales')) {
      return PurposeVisitTexts.salesRep;
    }
    return null;
  }

  /// Fallback when [repTypeText] and [serviceArea] are empty (common for SE managers).
  /// repType: 1 = Sales Rep, 2 = Medical Rep, 4/6 = Application Engineer, 5 = Service Engineer.
  static String? purposeVisitTextFromRepType(int? repType) {
    switch (repType) {
      case 5:
        return PurposeVisitTexts.serviceEng;
      case 4:
      case 6:
        return PurposeVisitTexts.applicationEng;
      case 2:
      case 1:
        return PurposeVisitTexts.salesRep;
      default:
        return null;
    }
  }

  static bool isServiceEngineer({
    String? serviceArea,
    int? repType,
    String? repTypeText,
    String? designation,
    String? roleText,
  }) {
    final bool textMatch = _anyDesignationFieldMatches(
      <String?>[repTypeText, roleText, serviceArea, designation],
      (String t) =>
          t.contains('service engineer') || t.contains('service eng'),
    );
    if (textMatch) return true;
    return repType == 5;
  }

  static bool isMedicalRep({
    String? serviceArea,
    int? repType,
    String? repTypeText,
    String? roleText,
  }) {
    if (isServiceEngineer(
      serviceArea: serviceArea,
      repType: repType,
      repTypeText: repTypeText,
      roleText: roleText,
    )) {
      return false;
    }
    final bool textMatch = _anyDesignationFieldMatches(
      <String?>[repTypeText, roleText, serviceArea],
      (String t) => t.contains('medical'),
    );
    if (textMatch) return true;
    return repType == 2;
  }

  static bool isApplicationEngineer({
    String? serviceArea,
    int? repType,
    String? repTypeText,
    String? designation,
    String? roleText,
  }) {
    final bool textMatch = _anyDesignationFieldMatches(
      <String?>[repTypeText, roleText, serviceArea, designation],
      (String t) => t.contains('application'),
    );
    if (textMatch) return true;
    return repType == 4 || repType == 6;
  }

  static bool isPocRep({
    int? repType,
    int? roleCategory,
    String? repTypeText,
    String? serviceArea,
    String? designation,
    String? roleText,
  }) {
    final bool textMatch = _anyDesignationFieldMatches(
      <String?>[repTypeText, roleText, serviceArea, designation],
      (String t) => t.contains('poc'),
    );
    if (textMatch) return true;
    // repType 3 = POC Rep (do not require roleCategory when API omits it).
    if ((repType ?? 0) == 3) return true;
    return false;
  }

  static bool _anyDesignationFieldMatches(
    Iterable<String?> fields,
    bool Function(String normalized) test,
  ) {
    for (final String? field in fields) {
      final String t = _normalize(field);
      if (t.isNotEmpty && test(t)) return true;
    }
    return false;
  }

  /// Human-readable designation label from numeric repType.
  static String designationLabelFromRepType(int? repType) {
    switch (repType) {
      case 5:
        return 'Service Engineer';
      case 2:
        return 'Medical Rep';
      case 1:
        return 'Sales Rep';
      case 3:
        return 'POC Rep';
      case 4:
      case 6:
        return 'Application Engineer';
      default:
        return '';
    }
  }

  /// Infers non-manager field rep when API omits [roleCategory].
  static bool inferFieldRepRoleCategory({
    String? serviceArea,
    int? repType,
    String? repTypeText,
    String? roleText,
  }) {
    if (repType == 1 || repType == 2 || repType == 3 || repType == 5) {
      return true;
    }
    return _anyDesignationFieldMatches(
      <String?>[serviceArea, repTypeText, roleText],
      (String t) =>
          t.contains('service eng') ||
          t.contains('medical') ||
          t.contains('poc') ||
          t.contains('sales') ||
          t.contains('application'),
    );
  }

  static String _pocPurposeText(PurposeVisitContext context) {
    return context == PurposeVisitContext.dcr
        ? PurposeVisitTexts.pocRepDcr
        : PurposeVisitTexts.pocRepTourPlan;
  }

  /// Primary resolver: repTypeText → serviceArea → repType → role helpers.
  static String resolvePurposeVisitText({
    String? repTypeText,
    int? repType,
    int? roleCategory,
    String? serviceArea,
    String? designation,
    PurposeVisitContext context = PurposeVisitContext.tourPlan,
  }) {
    if ((repTypeText ?? '').trim().isNotEmpty) {
      if (isPocRep(
        repType: repType,
        roleCategory: roleCategory,
        repTypeText: repTypeText,
        serviceArea: serviceArea,
        designation: designation,
      )) {
        return _pocPurposeText(context);
      }
      if (isServiceEngineer(
        serviceArea: serviceArea,
        repType: repType,
        repTypeText: repTypeText,
        designation: designation,
      )) {
        return PurposeVisitTexts.serviceEng;
      }
      if (isApplicationEngineer(
        serviceArea: serviceArea,
        repType: repType,
        repTypeText: repTypeText,
        designation: designation,
      )) {
        return PurposeVisitTexts.applicationEng;
      }
      return purposeVisitTextFromRepTypeText(repTypeText);
    }

    final String? fromServiceArea =
        purposeVisitTextFromServiceArea(serviceArea);
    if (fromServiceArea != null) {
      if (isPocRep(
        repType: repType,
        roleCategory: roleCategory,
        serviceArea: serviceArea,
        designation: designation,
      )) {
        return _pocPurposeText(context);
      }
      return fromServiceArea;
    }

    final String? fromRepType = purposeVisitTextFromRepType(repType);
    if (fromRepType != null) {
      return fromRepType;
    }

    if (isPocRep(
      repType: repType,
      roleCategory: roleCategory,
      serviceArea: serviceArea,
      designation: designation,
    )) {
      return _pocPurposeText(context);
    }
    if (isServiceEngineer(
      serviceArea: serviceArea,
      repType: repType,
      repTypeText: repTypeText,
      designation: designation,
    )) {
      return PurposeVisitTexts.serviceEng;
    }
    if (isApplicationEngineer(
      serviceArea: serviceArea,
      repType: repType,
      repTypeText: repTypeText,
      designation: designation,
    )) {
      return PurposeVisitTexts.applicationEng;
    }
    if (isMedicalRep(
      serviceArea: serviceArea,
      repType: repType,
      repTypeText: repTypeText,
    )) {
      return PurposeVisitTexts.salesRep;
    }

    return PurposeVisitTexts.salesRep;
  }

  static String tourPlanPurposeVisitText({
    String? serviceArea,
    int? repType,
    int? roleCategory,
    String? repTypeText,
    String? designation,
  }) {
    return resolvePurposeVisitText(
      repTypeText: repTypeText,
      repType: repType,
      roleCategory: roleCategory,
      serviceArea: serviceArea,
      designation: designation,
      context: PurposeVisitContext.tourPlan,
    );
  }

  static String dcrPurposeVisitText({
    String? serviceArea,
    int? repType,
    int? roleCategory,
    String? repTypeText,
    String? designation,
  }) {
    return resolvePurposeVisitText(
      repTypeText: repTypeText,
      repType: repType,
      roleCategory: roleCategory,
      serviceArea: serviceArea,
      designation: designation,
      context: PurposeVisitContext.dcr,
    );
  }

  static List<String> dcrPurposeVisitTexts({
    String? serviceArea,
    int? repType,
    int? roleCategory,
    String? repTypeText,
    String? designation,
  }) {
    return [
      dcrPurposeVisitText(
        serviceArea: serviceArea,
        repType: repType,
        roleCategory: roleCategory,
        repTypeText: repTypeText,
        designation: designation,
      ),
    ];
  }

  static List<String> tourPlanPurposeVisitTexts({
    String? serviceArea,
    int? repType,
    int? roleCategory,
    String? repTypeText,
    String? designation,
  }) {
    return [
      tourPlanPurposeVisitText(
        serviceArea: serviceArea,
        repType: repType,
        roleCategory: roleCategory,
        repTypeText: repTypeText,
        designation: designation,
      ),
    ];
  }

  static bool isServiceEngineerUser(UserDetail? user) {
    if (user == null) return false;
    return isServiceEngineer(
      serviceArea: user.serviceArea,
      repType: user.repType,
      repTypeText: user.repTypeText,
      roleText: user.roleText,
    );
  }

  static bool isMedicalRepUser(UserDetail? user) {
    if (user == null) return false;
    return isMedicalRep(
      serviceArea: user.serviceArea,
      repType: user.repType,
      repTypeText: user.repTypeText,
      roleText: user.roleText,
    );
  }

  static bool isApplicationEngineerUser(UserDetail? user) {
    if (user == null) return false;
    return isApplicationEngineer(
      serviceArea: user.serviceArea,
      repType: user.repType,
      repTypeText: user.repTypeText,
      roleText: user.roleText,
    );
  }

  static bool isPocRepUser(UserDetail? user) {
    if (user == null) return false;
    return isPocRep(
      repType: user.repType,
      roleCategory: user.roleCategory,
      repTypeText: user.repTypeText,
      serviceArea: user.serviceArea,
      roleText: user.roleText,
    );
  }

  static bool isManagerOrFieldManagerUser(UserDetail? user) {
    if (user == null) return false;
    final int roleCategory = user.roleCategory;
    return roleCategory == 1 || roleCategory == 2;
  }

  static bool isFieldCoordinator({
    String? serviceArea,
    String? repTypeText,
    String? designation,
    String? roleText,
  }) {
    return _anyDesignationFieldMatches(
      <String?>[repTypeText, roleText, serviceArea, designation],
      (String t) =>
          t.contains('field coordinator') || t.contains('field coord'),
    );
  }

  static bool isFieldCoordinatorUser(UserDetail? user) {
    if (user == null) return false;
    return isFieldCoordinator(
      serviceArea: user.serviceArea,
      repTypeText: user.repTypeText,
      roleText: user.roleText,
    );
  }

  /// Managers who plan their own tour plan without selecting reporting staff
  /// (clusters, customer type, purpose, products load using own employeeId).
  static bool managerPreselectsSelfForTourPlan(UserDetail? user) {
    if (user == null || !isManagerOrFieldManagerUser(user)) return false;
    return isServiceEngineerUser(user) ||
        isApplicationEngineerUser(user) ||
        isFieldCoordinatorUser(user);
  }

  /// Field reps (non-managers): Medical Rep, Service Engineer, POC, Sales, etc.
  static bool isFieldRepUser(UserDetail? user) {
    if (user == null) return false;
    if (isManagerOrFieldManagerUser(user)) return false;
    if (user.roleCategory == 3) return true;
    return isServiceEngineerUser(user) ||
        isMedicalRepUser(user) ||
        isPocRepUser(user) ||
        isApplicationEngineerUser(user) ||
        user.repType == 1;
  }

  /// CRM/Tour Plan manager-review tabs are hidden for field reps only.
  static bool shouldHideManagerReview(UserDetail? user) {
    return isFieldRepUser(user);
  }

  /// Customer Type list API [type] param — uses designation fields, not serviceArea alone.
  static String customerTypeApiTypeParam(UserDetail? user) {
    if (user == null) return 'Sales Rep';
    final String serviceArea = user.serviceArea.trim();
    if (serviceArea.isNotEmpty) return serviceArea;
    if (isServiceEngineerUser(user)) return 'Service Engineer';
    if (isMedicalRepUser(user)) return 'Medical Rep';
    final String fromRepType = designationLabelFromRepType(user.repType);
    if (fromRepType.isNotEmpty) return fromRepType;
    final String fromText = (user.repTypeText ?? user.roleText ?? '').trim();
    if (fromText.isNotEmpty) return fromText;
    return 'Sales Rep';
  }

  /// Service Engineer, POC Rep, and Application Engineer bypass validate-user lock
  /// for all gated actions (new tour plan, DCR, expense, deviation, edits).
  static bool bypassesValidateUserLock(UserDetail? user) {
    if (user == null) return false;
    return isServiceEngineerUser(user) ||
        isPocRepUser(user) ||
        isApplicationEngineerUser(user);
  }

  /// Whether a validate-user-gated action is allowed for [user].
  static bool allowsValidateUserGatedAction(UserDetail? user, bool apiAllows) {
    return bypassesValidateUserLock(user) || apiAllows;
  }

  /// @deprecated Use [bypassesValidateUserLock].
  static bool bypassesDeviationValidateUser(UserDetail? user) =>
      bypassesValidateUserLock(user);

  static bool isPlanningForSelf({
    required UserDetail? loggedInUser,
    int? selectedEmployeeId,
  }) {
    if (loggedInUser == null || selectedEmployeeId == null) return false;
    final int? loginEmployeeId = loggedInUser.employeeId;
    return loginEmployeeId != null &&
        loginEmployeeId > 0 &&
        selectedEmployeeId == loginEmployeeId;
  }

  /// Resolves CommandType 337 [Text] for tour plan (manager + field rep).
  static String resolveTourPlanPurposeText({
    required UserDetail? loggedInUser,
    int? selectedEmployeeId,
    int? reportingStaffRepType,
    String? reportingStaffRepTypeText,
    String? reportingStaffDesignation,
  }) {
    final bool forSelf = isPlanningForSelf(
      loggedInUser: loggedInUser,
      selectedEmployeeId: selectedEmployeeId,
    );

    String? repTypeText = forSelf
        ? (loggedInUser?.repTypeText ?? reportingStaffRepTypeText)
        : reportingStaffRepTypeText;
    if (forSelf &&
        (repTypeText == null || repTypeText.trim().isEmpty) &&
        (reportingStaffRepTypeText ?? '').trim().isNotEmpty) {
      repTypeText = reportingStaffRepTypeText;
    }

    int? repType = forSelf ? loggedInUser?.repType : reportingStaffRepType;
    if (forSelf &&
        (repType == null || repType <= 0) &&
        reportingStaffRepType != null) {
      repType = reportingStaffRepType;
    }

    final String? serviceArea = forSelf ? loggedInUser?.serviceArea : null;
    final int? roleCategory = forSelf ? loggedInUser?.roleCategory : 3;

    return resolvePurposeVisitText(
      repTypeText: repTypeText,
      repType: repType,
      roleCategory: roleCategory,
      serviceArea: serviceArea,
      designation: reportingStaffDesignation,
      context: PurposeVisitContext.tourPlan,
    );
  }

  /// Waits for logged-in user profile and refreshes once when [repType] is missing.
  static Future<UserDetail?> ensureLoggedInUserProfile(
    UserDetailStore? store, {
    int maxWaitMs = 6000,
  }) async {
    if (store == null) return null;

    final int maxRetries = maxWaitMs ~/ 300;
    int retry = 0;
    while (!store.isUserLoaded && retry < maxRetries) {
      await Future.delayed(const Duration(milliseconds: 300));
      retry++;
    }
    if (!store.isUserLoaded) return null;

    final UserDetail? current = store.userDetail;
    if (current?.repType == null ||
        (current?.repTypeText ?? '').trim().isEmpty) {
      await store.refreshUserData();
    }
    return store.userDetail;
  }

  /// UserId for Common/GetAuto CommandType 337.
  static int resolvePurposeApiUserId({
    required UserDetail? loggedInUser,
    int? selectedEmployeeId,
  }) {
    if (loggedInUser == null) return 0;
    if (isPlanningForSelf(
      loggedInUser: loggedInUser,
      selectedEmployeeId: selectedEmployeeId,
    )) {
      return loggedInUser.id;
    }
    if (selectedEmployeeId != null && selectedEmployeeId > 0) {
      return selectedEmployeeId;
    }
    return loggedInUser.id;
  }

  static Future<UserDetail?> fetchUserProfile(int userId) async {
    if (!getIt.isRegistered<DioClient>()) return null;

    final login.UserStore? loginStore = getIt.isRegistered<login.UserStore>()
        ? getIt<login.UserStore>()
        : null;
    final UserDetailStore? detailStore =
        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final String? token =
        loginStore?.currentUser?.token ?? detailStore?.authToken;
    if (token == null || token.isEmpty) return null;

    try {
      final client = UserApiClient(getIt<DioClient>());
      return await client.getUserById(userId, token);
    } catch (_) {
      return null;
    }
  }
}
