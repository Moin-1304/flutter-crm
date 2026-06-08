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
  static const String pocRepDcr = 'DCR-PocRepType';
}

/// Resolves which Purpose-of-Visit master list to load from the API.
class PurposeVisitHelper {
  PurposeVisitHelper._();

  /// repType 5 = Service Engineer (when serviceArea is empty on user profile).
  static bool isServiceEngineer({
    String? serviceArea,
    int? repType,
    String? designation,
  }) {
    if ((serviceArea ?? '').trim().toLowerCase() == 'service engineer') {
      return true;
    }
    if (repType == 5) return true;
    final String des = (designation ?? '').trim().toLowerCase();
    return des.contains('service engineer') || des.contains('service eng');
  }

  static bool isPocRep({int? repType, int? roleCategory}) {
    return (repType ?? 0) == 3 && (roleCategory ?? 0) == 3;
  }

  static String tourPlanPurposeVisitText({
    String? serviceArea,
    int? repType,
    int? roleCategory,
    String? designation,
  }) {
    if (isPocRep(repType: repType, roleCategory: roleCategory)) {
      return PurposeVisitTexts.pocRepTourPlan;
    }
    if (isServiceEngineer(
      serviceArea: serviceArea,
      repType: repType,
      designation: designation,
    )) {
      return PurposeVisitTexts.serviceEng;
    }
    return PurposeVisitTexts.salesRep;
  }

  static String dcrPurposeVisitText({
    String? serviceArea,
    int? repType,
    int? roleCategory,
    String? designation,
  }) {
    if (isPocRep(repType: repType, roleCategory: roleCategory)) {
      return PurposeVisitTexts.pocRepDcr;
    }
    if (isServiceEngineer(
      serviceArea: serviceArea,
      repType: repType,
      designation: designation,
    )) {
      return PurposeVisitTexts.serviceEng;
    }
    return PurposeVisitTexts.salesRep;
  }

  static List<String> dcrPurposeVisitTexts({
    String? serviceArea,
    int? repType,
    int? roleCategory,
    String? designation,
  }) {
    return [
      dcrPurposeVisitText(
        serviceArea: serviceArea,
        repType: repType,
        roleCategory: roleCategory,
        designation: designation,
      ),
    ];
  }

  static bool isServiceEngineerUser(UserDetail? user) {
    if (user == null) return false;
    return isServiceEngineer(
      serviceArea: user.serviceArea,
      repType: user.repType,
    );
  }

  /// True when [selectedEmployeeId] is the logged-in user's employee id.
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
    String? reportingStaffDesignation,
  }) {
    final bool forSelf = isPlanningForSelf(
      loggedInUser: loggedInUser,
      selectedEmployeeId: selectedEmployeeId,
    );

    int? repType =
        forSelf ? loggedInUser?.repType : reportingStaffRepType;
    // Profile may load after screen open — fall back to reporting-staff repType for self.
    if (forSelf && (repType == null || repType <= 0) && reportingStaffRepType != null) {
      repType = reportingStaffRepType;
    }
    final String? serviceArea = forSelf ? loggedInUser?.serviceArea : null;
    // For staff plans use rep roleCategory (3) so manager's roleCategory (1/2) is not applied.
    final int? roleCategory = forSelf ? loggedInUser?.roleCategory : 3;

    return tourPlanPurposeVisitText(
      serviceArea: serviceArea,
      repType: repType,
      roleCategory: roleCategory,
      designation: reportingStaffDesignation,
    );
  }

  /// Waits for logged-in user profile and refreshes when [repType] is missing.
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

    if (store.userDetail?.repType == null) {
      await store.refreshUserData();
    }
    return store.userDetail;
  }

  /// UserId for Common/GetAuto CommandType 337.
  /// When planning for self, use login [UserDetail.id] (not employeeId).
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

  /// Loads another user's profile without replacing the logged-in [UserDetailStore].
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
