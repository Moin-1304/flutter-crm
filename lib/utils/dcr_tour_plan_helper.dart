import 'package:boilerplate/utils/dcr_purpose_visit_helper.dart';

/// Maps tour-plan-linked DCR fields for pending/auto-created records.

class DcrTourPlanHelper {

  DcrTourPlanHelper._();



  static const String autoCreatedDiscussionText =

      'Auto DCR created from Tour plan';



  /// True when DCR was auto-created from a tour plan and is not yet submitted.

  static bool isPendingTourPlanDcr({

    required int tourPlanId,

    required String statusText,

    int? dcrStatusId,

  }) {

    if (tourPlanId <= 0) return false;



    // Draft / pending status IDs from the API (0 = draft, 1 = pending / sent back).

    if (dcrStatusId != null && (dcrStatusId == 0 || dcrStatusId == 1)) {

      return true;

    }



    final String status = statusText.trim().toLowerCase();

    if (status.isEmpty) return false;

    return status.contains('pending') ||

        status.contains('draft') ||

        status.contains('missed') ||

        status == 'dcr pending';

  }



  /// Prefer detail-level [typeOfWorkId] when the parent value is missing (common for SE DCRs).

  static int effectiveTypeOfWorkId({

    required int parentTypeOfWorkId,

    int? detailTypeOfWorkId,

  }) {

    if (parentTypeOfWorkId > 0) return parentTypeOfWorkId;

    if (detailTypeOfWorkId != null && detailTypeOfWorkId > 0) {

      return detailTypeOfWorkId;

    }

    return parentTypeOfWorkId;

  }



  /// Key discussion / remarks: prefer DCR detail row over header.

  static String resolveDcrRemarksSource({

    required String headerRemarks,

    required String detailRemarks,

  }) {

    final String detail = detailRemarks.trim();

    if (detail.isNotEmpty) return detail;

    return headerRemarks.trim();

  }



  /// Best available purpose text from API before ID lookup (parent + detail context).

  static String apiPurposeText({

    required String parentTypeOfWork,

    String? detailTypeOfWork,

  }) {

    final String detail = (detailTypeOfWork ?? '').trim();

    if (detail.isNotEmpty && !_looksLikePlaceholderPurpose(detail)) {

      return detail;

    }

    final String parent = parentTypeOfWork.trim();

    if (parent.isNotEmpty && !_looksLikePlaceholderPurpose(parent)) {

      return parent;

    }

    return '';

  }



  static bool _looksLikePlaceholderPurpose(String raw) {

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



  /// Key discussion for pending tour-plan DCRs is fixed; otherwise use saved remarks.

  static String resolveKeyDiscussionPoints({

    required int tourPlanId,

    required String statusText,

    required String remarks,

    int? dcrStatusId,

    String? purposeOfVisit,

  }) {

    if (isPendingTourPlanDcr(

      tourPlanId: tourPlanId,

      statusText: statusText,

      dcrStatusId: dcrStatusId,

    )) {

      return autoCreatedDiscussionText;

    }

    return DcrPurposeVisitHelper.resolveRemarksForAvailablePurpose(

      purposeOfVisit: purposeOfVisit,

      discussionText: remarks,

    );

  }

}


