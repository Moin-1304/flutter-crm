import 'package:boilerplate/di/service_locator.dart';

import 'package:boilerplate/domain/entity/dcr/unified_dcr_item.dart';

import 'package:boilerplate/domain/entity/common/common_api_models.dart';

import 'package:boilerplate/domain/entity/user/user_detail.dart';

import 'package:boilerplate/domain/repository/common/common_repository.dart';

import 'package:boilerplate/presentation/user/store/user_store.dart';

import 'package:boilerplate/utils/dcr_tour_plan_helper.dart';

import 'package:boilerplate/utils/purpose_visit_helper.dart';
import 'package:boilerplate/utils/dcr_purpose_visit_helper.dart';



/// Resolves designation and purpose labels for DCR view screens when list/get

/// APIs return placeholders or parent-level [typeOfWork] text that does not

/// match [typeOfWorkId] (common for Service Engineer DCRs).

class DcrDisplayResolver {

  DcrDisplayResolver._();



  static Map<int, String>? _cachedPurposeIdToName;



  static bool looksLikePlaceholderDesignation(String raw) {

    final String t =

        raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

    return t == 'others new' ||

        t == 'other new' ||

        t == 'othersnew' ||

        t == 'others' ||

        t == 'new' ||

        t == 'n/a' ||

        t == '-' ||

        t == 'na';

  }



  static String? pickResolvedDesignation(String? candidate) {

    if (candidate == null) return null;

    final String t = candidate.trim();

    if (t.isEmpty) return null;

    if (looksLikePlaceholderDesignation(t)) return null;

    return t;

  }



  /// Prefer a real designation from the API; fall back to the viewer profile for

  /// the employee's own DCR (Service Engineer login).

  static String resolveDesignation({

    required String apiDesignation,

    UserDetail? viewer,

    int? recordEmployeeId,

  }) {

    final String? fromApi = pickResolvedDesignation(apiDesignation);

    if (fromApi != null) return fromApi;



    final bool isOwnRecord = viewer != null &&

        recordEmployeeId != null &&

        recordEmployeeId > 0 &&

        viewer.employeeId == recordEmployeeId;



    if (isOwnRecord) {

      final String? repTypeText = pickResolvedDesignation(viewer.repTypeText);

      if (repTypeText != null) return repTypeText;



      if (PurposeVisitHelper.isServiceEngineer(

        serviceArea: viewer.serviceArea,

        repType: viewer.repType,

        repTypeText: viewer.repTypeText,

      )) {

        return 'Service Engineer';

      }



      final String? serviceArea =

          pickResolvedDesignation(viewer.serviceArea);

      if (serviceArea != null) return serviceArea;

    }



    return fromApi ?? '';

  }



  static bool looksLikePlaceholderPurpose(String raw) {

    final String t =

        raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

    return t.isEmpty ||

        t == 'others new' ||

        t == 'other new' ||

        t == 'othersnew' ||

        t == 'others' ||

        t == 'n/a' ||

        t == '-' ||

        t == 'na' ||

        t == 'visit';

  }



  static void _mergePurposeItem(

    Map<int, String> idToName,

    CommonDropdownItem item,

  ) {

    final String label =

        (item.text.isNotEmpty ? item.text : item.typeText).trim();

    if (label.isEmpty) return;



    for (final int key in <int>[item.id, item.value, item.item]) {

      if (key > 0) {

        idToName[key] = label;

      }

    }

  }



  /// Loads merged DCR type-of-work ID → label map (all DCR role masters).
  static Future<Map<int, String>> loadTypeOfWorkIdToNameMap() async {
    final Map<int, String> idToName = <int, String>{};
    if (!getIt.isRegistered<CommonRepository>()) return idToName;

    final repo = getIt<CommonRepository>();
    final UserDetailStore? userStore =
        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final UserDetail? user =
        await PurposeVisitHelper.ensureLoggedInUserProfile(userStore);
    final int purposeUserId = DcrPurposeVisitHelper.resolveDcrPurposeUserId(
      employeeId: user?.employeeId,
      loginUserId: user?.id,
    );

    if (purposeUserId <= 0) return idToName;

    for (final config in DcrPurposeVisitHelper.allConfigs) {
      try {
        for (final item in await repo.getDcrPurposeOfVisitList(
          userId: purposeUserId,
          commandType: config.commandType,
          text: config.text,
        )) {
          _mergePurposeItem(idToName, item);
        }
      } catch (_) {}
    }

    return idToName;
  }



  static Future<Map<int, String>> ensurePurposeIdToNameMap() async {

    _cachedPurposeIdToName ??= await loadTypeOfWorkIdToNameMap();

    return _cachedPurposeIdToName!;

  }



  static void invalidatePurposeCache() {

    _cachedPurposeIdToName = null;

  }



  /// Resolves purpose label; [typeOfWorkId] wins over parent [typeOfWork] text.

  static String resolvePurposeDisplay({

    required String typeOfWork,

    required int typeOfWorkId,

    Map<int, String>? idToName,

  }) {

    if (typeOfWorkId > 0 && idToName != null) {

      final String? fromId = idToName[typeOfWorkId]?.trim();

      if (fromId != null && fromId.isNotEmpty) return fromId;

    }



    final String apiText = typeOfWork.trim();

    if (apiText.isNotEmpty && !looksLikePlaceholderPurpose(apiText)) {

      return apiText;

    }



    // ID present but label not loaded yet — leave empty (never generic "Visit").

    if (typeOfWorkId > 0) return '';



    return apiText.isNotEmpty ? apiText : 'Visit';

  }



  /// Applies purpose + key-discussion display rules to DCR list items.

  static Future<List<UnifiedDcrItem>> enrichItems(

    List<UnifiedDcrItem> items, {

    Map<int, String>? idToName,

    UserDetail? viewer,

  }) async {

    if (items.every((item) => !item.isDcr)) return items;



    final Map<int, String> purposeMap =

        idToName ?? await ensurePurposeIdToNameMap();



    final UserDetailStore? userStore =

        getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;

    final UserDetail? resolvedViewer = viewer ?? userStore?.userDetail;



    return items

        .map((item) => item.isDcr

            ? applyTourPlanDisplayRules(

                item,

                idToName: purposeMap,

                viewer: resolvedViewer,

              )

            : item)

        .toList();

  }



  /// For pending tour-plan DCRs, purpose comes from [typeOfWorkId] and key discussion

  /// is always [DcrTourPlanHelper.autoCreatedDiscussionText] (never tour-plan remarks).

  static UnifiedDcrItem applyTourPlanDisplayRules(

    UnifiedDcrItem item, {

    Map<int, String>? idToName,

    String? designation,

    UserDetail? viewer,

  }) {

    final String resolvedDesignation = designation ??

        resolveDesignation(

          apiDesignation: item.designation,

          viewer: viewer,

          recordEmployeeId: item.employeeId,

        );



    final String purpose = resolvePurposeDisplay(

      typeOfWork: item.typeOfWork,

      typeOfWorkId: item.typeOfWorkId,

      idToName: idToName,

    );



    final String keyDiscussion = DcrTourPlanHelper.resolveKeyDiscussionPoints(

      tourPlanId: item.tourPlanId,

      statusText: item.statusText,

      dcrStatusId: item.dcrStatusId,

      remarks: item.remarks,

      purposeOfVisit: purpose,

    );



    String displayPurpose = purpose;

    if (displayPurpose.isEmpty && item.typeOfWorkId > 0) {

      // Still resolving — keep empty rather than wrong "Visit".

      displayPurpose = '';

    } else if (displayPurpose.isEmpty &&

        item.typeOfWork.trim().isNotEmpty &&

        !looksLikePlaceholderPurpose(item.typeOfWork)) {

      displayPurpose = item.typeOfWork.trim();

    } else if (displayPurpose.isEmpty) {

      displayPurpose = 'Visit';

    }



    return item.copyWith(

      designation: resolvedDesignation,

      typeOfWork: displayPurpose,

      remarks: keyDiscussion,

    );

  }

}


