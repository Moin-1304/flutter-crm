// DCR Approve and SendBack API Models
class DcrApproveRequest {
  final int id;
  final int action;
  final String comment;

  DcrApproveRequest({
    required this.id,
    required this.action,
    required this.comment,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Action': action,
      'Comment': comment,
    };
  }
}

class DcrSendBackRequest {
  final int id;
  final int action;
  final String comment;

  DcrSendBackRequest({
    required this.id,
    required this.action,
    required this.comment,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Action': action,
      'Comment': comment,
    };
  }
}

// Bulk DCR Action Models
class DcrBulkApproveRequest {
  final int id;
  final String comments;
  final int userId;
  final int action;
  final List<DcrBulkDetail> tourPlanDCRDetails;

  DcrBulkApproveRequest({
    required this.id,
    required this.comments,
    required this.userId,
    required this.action,
    required this.tourPlanDCRDetails,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Comments': comments,
      'UserId': userId,
      'Action': action,
      'TourPlanDCRDetails': tourPlanDCRDetails.map((detail) => detail.toJson()).toList(),
    };
  }
}

class DcrBulkSendBackRequest {
  final int id;
  final String comments;
  final int userId;
  final int action;
  final List<DcrBulkDetail> tourPlanDCRDetails;

  DcrBulkSendBackRequest({
    required this.id,
    required this.comments,
    required this.userId,
    required this.action,
    required this.tourPlanDCRDetails,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Comments': comments,
      'UserId': userId,
      'Action': action,
      'TourPlanDCRDetails': tourPlanDCRDetails.map((detail) => detail.toJson()).toList(),
    };
  }
}

class DcrBulkDetail {
  final int id;

  DcrBulkDetail({
    required this.id,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
    };
  }
}

class DcrActionResponse {
  final bool status;
  final String message;

  DcrActionResponse({
    required this.status,
    required this.message,
  });

  factory DcrActionResponse.fromJson(Map<String, dynamic> json) {
    // Backend responses are inconsistent across endpoints/environments.
    // Common patterns observed: { isSuccess: true }, { status: true }, { success: true }
    final dynamic rawStatus =
        json['isSuccess'] ?? json['status'] ?? json['success'];
    final bool ok = rawStatus == true || rawStatus == 1 || rawStatus == '1';

    return DcrActionResponse(
      status: ok,
      message: (json['message'] ??
              json['msg'] ??
              json['errorMessage'] ??
              json['errormessage'] ??
              '')
          .toString(),
    );
  }
}
