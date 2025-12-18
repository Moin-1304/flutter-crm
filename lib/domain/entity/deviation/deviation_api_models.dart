class DeviationListRequest {
  final String searchText;
  final int pageNumber;
  final int pageSize;
  final int userId;
  final int bizUnit;
  final int employeeId;

  DeviationListRequest({
    required this.searchText,
    required this.pageNumber,
    required this.pageSize,
    required this.userId,
    required this.bizUnit,
    required this.employeeId,
  });

  Map<String, dynamic> toJson() {
    return {
      'SearchText': searchText,
      'PageNumber': pageNumber,
      'PageSize': pageSize,
      'UserId': userId,
      'BizUnit': bizUnit,
      'EmployeeId': employeeId,
    };
  }
}

class DeviationListResponse {
  final List<DeviationApiItem> items;
  final int totalRecords;
  final int filteredRecords;

  DeviationListResponse({
    required this.items,
    required this.totalRecords,
    required this.filteredRecords,
  });

  factory DeviationListResponse.fromJson(Map<String, dynamic> json) {
    return DeviationListResponse(
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => DeviationApiItem.fromJson(item))
          .toList() ?? [],
      totalRecords: json['totalRecords'] ?? 0,
      filteredRecords: json['filteredRecords'] ?? 0,
    );
  }
}

class DeviationApiItem {
  final int id;
  final int createdBy;
  final int status;
  final int sbuId;
  final int bizUnit;
  final int tourPlanDetailId;
  final int dcrDetailId;
  final String dateOfDeviation;
  final int typeOfDeviation;
  final String description;
  final int customerId;
  final int clusterId;
  final String impact;
  final String deviationType;
  final String deviationStatus;
  final int commentCount;
  final String clusterName;
  final int employeeId;
  final String employeeName;
  final String employeeCode;
  final String tourPlanName;
  final String createdDate;
  final int modifiedBy;
  final String modifiedDate;

  DeviationApiItem({
    required this.id,
    required this.createdBy,
    required this.status,
    required this.sbuId,
    required this.bizUnit,
    required this.tourPlanDetailId,
    required this.dcrDetailId,
    required this.dateOfDeviation,
    required this.typeOfDeviation,
    required this.description,
    required this.customerId,
    required this.clusterId,
    required this.impact,
    required this.deviationType,
    required this.deviationStatus,
    required this.commentCount,
    required this.clusterName,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.tourPlanName,
    required this.createdDate,
    required this.modifiedBy,
    required this.modifiedDate,
  });

  factory DeviationApiItem.fromJson(Map<String, dynamic> json) {
    return DeviationApiItem(
      id: json['id'] ?? 0,
      createdBy: json['createdBy'] ?? 0,
      status: json['status'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      bizUnit: json['bizUnit'] ?? 0,
      tourPlanDetailId: json['tourPlanDetailId'] ?? 0,
      dcrDetailId: json['dcrDetailId'] ?? 0,
      dateOfDeviation: json['dateOfDeviation'] ?? '',
      typeOfDeviation: json['typeOfDeviation'] ?? 0,
      description: json['description'] ?? '',
      customerId: json['customerId'] ?? 0,
      clusterId: json['clusterId'] ?? 0,
      impact: json['impact'] ?? '',
      deviationType: json['deviationType'] ?? '',
      deviationStatus: json['deviationStatus'] ?? '',
      commentCount: json['commentCount'] ?? 0,
      clusterName: json['clusterName'] ?? '',
      employeeId: json['employeeId'] ?? 0,
      employeeName: json['employeeName'] ?? '',
      employeeCode: json['employeeCode'] ?? '',
      tourPlanName: json['tourPlanName'] ?? '',
      createdDate: json['createdDate'] ?? '',
      modifiedBy: json['modifiedBy'] ?? 0,
      modifiedDate: json['modifiedDate'] ?? '',
    );
  }
}

// Deviation Save API Models
class DeviationSaveRequest {
  final int? id;
  final int createdBy;
  final int status;
  final int sbuId;
  final int bizUnit;
  final int? tourPlanDetailId;
  final int? dcrDetailId;
  final String dateOfDeviation;
  final int typeOfDeviation;
  final String description;
  final int customerId;
  final int clusterId;
  final String impact;
  final String deviationType;
  final String deviationStatus;
  final int? commentCount;
  final String? clusterName;
  final int employeeId;
  final String? employeeName;
  final String? employeeCode;
  final String? tourPlanName;

  DeviationSaveRequest({
    required this.id,
    required this.createdBy,
    required this.status,
    required this.sbuId,
    required this.bizUnit,
    required this.tourPlanDetailId,
    required this.dcrDetailId,
    required this.dateOfDeviation,
    required this.typeOfDeviation,
    required this.description,
    required this.customerId,
    required this.clusterId,
    required this.impact,
    required this.deviationType,
    required this.deviationStatus,
    required this.commentCount,
    required this.clusterName,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.tourPlanName,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'CreatedBy': createdBy,
      'Status': status,
      'SbuId': sbuId,
      'BizUnit': bizUnit,
      'TourPlanDetailId': tourPlanDetailId,
      'DCRDetailId': dcrDetailId,
      'DateOfDeviation': dateOfDeviation,
      'TypeOfDeviation': typeOfDeviation,
      'Description': description,
      'CustomerId': customerId,
      'ClusterId': clusterId,
      'Impact': impact,
      'DeviationType': deviationType,
      'DeviationStatus': deviationStatus,
      'CommentCount': commentCount,
      'ClusterName': clusterName,
      'EmployeeId': employeeId,
      'EmployeeName': employeeName,
      'EmployeeCode': employeeCode,
      'TourPlanName': tourPlanName,
    };
  }
}

class DeviationUpdateRequest {
  final int? id;
  final int createdBy;
  final int status;
  final int sbuId;
  final int bizUnit;
  final int? tourPlanDetailId;
  final int? dcrDetailId;
  final String dateOfDeviation;
  final int typeOfDeviation;
  final String description;
  final int customerId;
  final int clusterId;
  final String impact;
  final String deviationType;
  final String deviationStatus;
  final int? commentCount;
  final String? clusterName;
  final int employeeId;
  final String? employeeName;
  final String? employeeCode;
  final String? tourPlanName;

  DeviationUpdateRequest({
    required this.id,
    required this.createdBy,
    required this.status,
    required this.sbuId,
    required this.bizUnit,
    required this.tourPlanDetailId,
    required this.dcrDetailId,
    required this.dateOfDeviation,
    required this.typeOfDeviation,
    required this.description,
    required this.customerId,
    required this.clusterId,
    required this.impact,
    required this.deviationType,
    required this.deviationStatus,
    required this.commentCount,
    required this.clusterName,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.tourPlanName,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'CreatedBy': createdBy,
      'Status': status,
      'SbuId': sbuId,
      'BizUnit': bizUnit,
      'TourPlanDetailId': tourPlanDetailId,
      'DCRDetailId': dcrDetailId,
      'DateOfDeviation': dateOfDeviation,
      'TypeOfDeviation': typeOfDeviation,
      'Description': description,
      'CustomerId': customerId,
      'ClusterId': clusterId,
      'Impact': impact,
      'DeviationType': deviationType,
      'DeviationStatus': deviationStatus,
      'CommentCount': commentCount,
      'ClusterName': clusterName,
      'EmployeeId': employeeId,
      'EmployeeName': employeeName,
      'EmployeeCode': employeeCode,
      'TourPlanName': tourPlanName,
    };
  }
}

class DeviationSaveResponse {
  final int id;
  final int createdBy;
  final int status;
  final int sbuId;
  final int bizUnit;
  final int? tourPlanDetailId;
  final int? dcrDetailId;
  final String dateOfDeviation;
  final int typeOfDeviation;
  final String description;
  final int customerId;
  final int clusterId;
  final String impact;
  final String? deviationType;
  final String? deviationStatus;
  final int? commentCount;
  final String? clusterName;
  final int employeeId;
  final String? employeeName;
  final String? employeeCode;
  final String? tourPlanName;

  DeviationSaveResponse({
    required this.id,
    required this.createdBy,
    required this.status,
    required this.sbuId,
    required this.bizUnit,
    this.tourPlanDetailId,
    this.dcrDetailId,
    required this.dateOfDeviation,
    required this.typeOfDeviation,
    required this.description,
    required this.customerId,
    required this.clusterId,
    required this.impact,
    this.deviationType,
    this.deviationStatus,
    this.commentCount,
    this.clusterName,
    required this.employeeId,
    this.employeeName,
    this.employeeCode,
    this.tourPlanName,
  });

  factory DeviationSaveResponse.fromJson(Map<String, dynamic> json) {
    return DeviationSaveResponse(
      id: json['id'] ?? 0,
      createdBy: json['createdBy'] ?? 0,
      status: json['status'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      bizUnit: json['bizUnit'] ?? 0,
      tourPlanDetailId: json['tourPlanDetailId'],
      dcrDetailId: json['dcrDetailId'],
      dateOfDeviation: json['dateOfDeviation'] ?? '',
      typeOfDeviation: json['typeOfDeviation'] ?? 0,
      description: json['description'] ?? '',
      customerId: json['customerId'] ?? 0,
      clusterId: json['clusterId'] ?? 0,
      impact: json['impact'] ?? '',
      deviationType: json['deviationType'],
      deviationStatus: json['deviationStatus'],
      commentCount: json['commentCount'],
      clusterName: json['clusterName'],
      employeeId: json['employeeId'] ?? 0,
      employeeName: json['employeeName'],
      employeeCode: json['employeeCode'],
      tourPlanName: json['tourPlanName'],
    );
  }
}

// Deviation Status Update API Models
class DeviationStatusUpdateRequest {
  final int id;
  final int action; // 1 = Reject, 2 = Approve, 3 = Send Back
  final String comment;
  final int employeeId;

  DeviationStatusUpdateRequest({
    required this.id,
    required this.action,
    required this.comment,
    required this.employeeId,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Action': action,
      'Comment': comment,
      'EmployeeId': employeeId,
    };
  }
}

class DeviationStatusUpdateResponse {
  final int id;
  final int createdBy;
  final int status;
  final int sbuId;
  final int bizUnit;
  final int tourPlanDetailId;
  final int dcrDetailId;
  final String dateOfDeviation;
  final int typeOfDeviation;
  final String description;
  final int customerId;
  final int clusterId;
  final String impact;
  final String deviationType;
  final String deviationStatus;
  final int commentCount;
  final String clusterName;
  final int employeeId;
  final String employeeName;
  final String employeeCode;
  final String tourPlanName;

  DeviationStatusUpdateResponse({
    required this.id,
    required this.createdBy,
    required this.status,
    required this.sbuId,
    required this.bizUnit,
    required this.tourPlanDetailId,
    required this.dcrDetailId,
    required this.dateOfDeviation,
    required this.typeOfDeviation,
    required this.description,
    required this.customerId,
    required this.clusterId,
    required this.impact,
    required this.deviationType,
    required this.deviationStatus,
    required this.commentCount,
    required this.clusterName,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.tourPlanName,
  });

  factory DeviationStatusUpdateResponse.fromJson(Map<String, dynamic> json) {
    return DeviationStatusUpdateResponse(
      id: json['id'] ?? 0,
      createdBy: json['createdBy'] ?? 0,
      status: json['status'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      bizUnit: json['bizUnit'] ?? 0,
      tourPlanDetailId: json['tourPlanDetailId'] ?? 0,
      dcrDetailId: json['dcrDetailId'] ?? 0,
      dateOfDeviation: json['dateOfDeviation'] ?? '',
      typeOfDeviation: json['typeOfDeviation'] ?? 0,
      description: json['description'] ?? '',
      customerId: json['customerId'] ?? 0,
      clusterId: json['clusterId'] ?? 0,
      impact: json['impact'] ?? '',
      deviationType: json['deviationType'] ?? '',
      deviationStatus: json['deviationStatus'] ?? '',
      commentCount: json['commentCount'] ?? 0,
      clusterName: json['clusterName'] ?? '',
      employeeId: json['employeeId'] ?? 0,
      employeeName: json['employeeName'] ?? '',
      employeeCode: json['employeeCode'] ?? '',
      tourPlanName: json['tourPlanName'] ?? '',
    );
  }
}

// Deviation Comments API Models
class DeviationGetCommentsRequest {
  final int id;

  DeviationGetCommentsRequest({
    required this.id,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}

class DeviationComment {
  final int id;
  final int? tourPlanId;
  final int? dcrId;
  final int deviationId;
  final String? tourPlanType;
  final String comment;
  final int isSystemGenerated;
  final int? userId;
  final String? userName;
  final String commentDate;
  final int? bizUnit;
  final String createdDate;
  final String modifiedDate;
  final String? userRole;

  DeviationComment({
    required this.id,
    this.tourPlanId,
    this.dcrId,
    required this.deviationId,
    this.tourPlanType,
    required this.comment,
    required this.isSystemGenerated,
    this.userId,
    this.userName,
    required this.commentDate,
    this.bizUnit,
    required this.createdDate,
    required this.modifiedDate,
    this.userRole,
  });

  factory DeviationComment.fromJson(Map<String, dynamic> json) {
    // Helper function to parse date strings
    String parseDate(String? dateString) {
      if (dateString == null || dateString.isEmpty) {
        return '';
      }
      return dateString;
    }

    return DeviationComment(
      id: json['id'] ?? 0,
      tourPlanId: json['tourPlanId'],
      dcrId: json['dcrId'],
      deviationId: json['deviationId'] ?? 0,
      tourPlanType: json['tourPlanType'],
      comment: json['comment'] ?? '',
      isSystemGenerated: json['isSystemGenerated'] ?? 0,
      userId: json['userId'],
      userName: json['userName'],
      commentDate: parseDate(json['commentDate']),
      bizUnit: json['bizUnit'],
      createdDate: parseDate(json['createdDate']),
      modifiedDate: parseDate(json['modifiedDate']),
      userRole: json['userRole'],
    );
  }
}

class DeviationAddCommentRequest {
  final int createdBy;
  final int deviationId;
  final String comment;
  final String? commentDate; // Optional: if not provided, server will use current time

  DeviationAddCommentRequest({
    required this.createdBy,
    required this.deviationId,
    required this.comment,
    this.commentDate,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'CreatedBy': createdBy,
      'DeviationId': deviationId,
      'Comment': comment,
    };
    // Only include CommentDate if provided
    if (commentDate != null && commentDate!.isNotEmpty) {
      json['CommentDate'] = commentDate;
    }
    return json;
  }
}

class DeviationAddCommentResponse {
  final int id;
  final int createdBy;
  final int status;
  final int sbuId;
  final int tourPlanId;
  final int dcrId;
  final int deviationId;
  final String tourPlanType;
  final String comment;
  final int isSystemGenerated;
  final int userId;
  final String commentDate;
  final int bizUnit;
  final bool active;
  final String userName;
  final String userRole;
  final String createdAt;
  final String updatedAt;
  final int isSystemGeneratedInt;
  final int activeInt;

  DeviationAddCommentResponse({
    required this.id,
    required this.createdBy,
    required this.status,
    required this.sbuId,
    required this.tourPlanId,
    required this.dcrId,
    required this.deviationId,
    required this.tourPlanType,
    required this.comment,
    required this.isSystemGenerated,
    required this.userId,
    required this.commentDate,
    required this.bizUnit,
    required this.active,
    required this.userName,
    required this.userRole,
    required this.createdAt,
    required this.updatedAt,
    required this.isSystemGeneratedInt,
    required this.activeInt,
  });

  factory DeviationAddCommentResponse.fromJson(Map<String, dynamic> json) {
    return DeviationAddCommentResponse(
      id: json['id'] ?? 0,
      createdBy: json['createdBy'] ?? 0,
      status: json['status'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      tourPlanId: json['tourPlanId'] ?? 0,
      dcrId: json['dcrId'] ?? 0,
      deviationId: json['deviationId'] ?? 0,
      tourPlanType: json['tourPlanType'] ?? '',
      comment: json['comment'] ?? '',
      isSystemGenerated: json['isSystemGenerated'] ?? 0,
      userId: json['userId'] ?? 0,
      commentDate: json['commentDate'] ?? '',
      bizUnit: json['bizUnit'] ?? 0,
      active: json['active'] ?? false,
      userName: json['userName'] ?? '',
      userRole: json['userRole'] ?? '',
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      isSystemGeneratedInt: json['isSystemGeneratedInt'] ?? 0,
      activeInt: json['activeInt'] ?? 0,
    );
  }
}