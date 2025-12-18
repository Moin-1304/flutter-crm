class PunchInOutSaveRequest {
  final int id;
  final int createdBy;
  final int status;
  final int sbuId;
  final int employeeId;
  final int userId;
  final int checkInStatus;
  final int bizUnit;

  PunchInOutSaveRequest({
    required this.id,
    required this.createdBy,
    required this.status,
    required this.sbuId,
    required this.employeeId,
    required this.userId,
    required this.checkInStatus,
    required this.bizUnit,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdBy': createdBy,
      'status': status,
      'sbuId': sbuId,
      'employeeId': employeeId,
      'userId': userId,
      'checkInStatus': checkInStatus,
      'bizUnit': bizUnit,
    };
  }
}

class PunchInOutListRequest {
  final int pageNumber;
  final int pageSize;
  final int sortOrder;
  final int sortDir;
  final String searchText;
  final int userId;
  final String logDate;

  PunchInOutListRequest({
    required this.pageNumber,
    required this.pageSize,
    required this.sortOrder,
    required this.sortDir,
    required this.searchText,
    required this.userId,
    required this.logDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'pageNumber': pageNumber,
      'pageSize': pageSize,
      'sortOrder': sortOrder,
      'sortDir': sortDir,
      'searchText': searchText,
      'userId': userId,
      'logDate': logDate,
    };
  }
}

class LogDetail {
  final int id;
  final int userId;
  final int sbuId;
  final int checkInStatus;
  final int checkOutStatus;
  final DateTime checkDateTime;
  final String activity;

  LogDetail({
    required this.id,
    required this.userId,
    required this.sbuId,
    required this.checkInStatus,
    required this.checkOutStatus,
    required this.checkDateTime,
    required this.activity,
  });

  factory LogDetail.fromJson(Map<String, dynamic> json) {
    return LogDetail(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      checkInStatus: json['checkInStatus'] ?? 0,
      checkOutStatus: json['checkOutStatus'] ?? 0,
      checkDateTime: DateTime.parse(json['checkDateTime'] ?? DateTime.now().toIso8601String()),
      activity: json['activity'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'sbuId': sbuId,
      'checkInStatus': checkInStatus,
      'checkOutStatus': checkOutStatus,
      'checkDateTime': checkDateTime.toIso8601String(),
      'activity': activity,
    };
  }
}

class PunchInOutResponse {
  final int id;
  final int createdBy;
  final int status;
  final int sbuId;
  final int employeeId;
  final int userId;
  final int checkInStatus;
  final int bizUnit;
  final String userName;
  final String sbuName;
  final DateTime? lastLoggedOutTime;
  final List<LogDetail> logDetails;

  PunchInOutResponse({
    required this.id,
    required this.createdBy,
    required this.status,
    required this.sbuId,
    required this.employeeId,
    required this.userId,
    required this.checkInStatus,
    required this.bizUnit,
    required this.userName,
    required this.sbuName,
    this.lastLoggedOutTime,
    required this.logDetails,
  });

  factory PunchInOutResponse.fromJson(Map<String, dynamic> json) {
    return PunchInOutResponse(
      id: json['id'] ?? 0,
      createdBy: json['createdBy'] ?? 0,
      status: json['status'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      employeeId: json['employeeId'] ?? 0,
      userId: json['userId'] ?? 0,
      checkInStatus: json['checkInStatus'] ?? 0,
      bizUnit: json['bizUnit'] ?? 0,
      userName: json['userName'] ?? '',
      sbuName: json['sbuName'] ?? '',
      lastLoggedOutTime: json['lastLoggedOutTime'] != null 
          ? DateTime.parse(json['lastLoggedOutTime']) 
          : null,
      logDetails: (json['logDetails'] as List<dynamic>?)
          ?.map((item) => LogDetail.fromJson(item))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdBy': createdBy,
      'status': status,
      'sbuId': sbuId,
      'employeeId': employeeId,
      'userId': userId,
      'checkInStatus': checkInStatus,
      'bizUnit': bizUnit,
      'userName': userName,
      'sbuName': sbuName,
      'lastLoggedOutTime': lastLoggedOutTime?.toIso8601String(),
      'logDetails': logDetails.map((item) => item.toJson()).toList(),
    };
  }
}

class PunchInOutListResponse {
  final List<PunchInOutResponse> items;
  final int totalRecords;
  final int filteredRecords;

  PunchInOutListResponse({
    required this.items,
    required this.totalRecords,
    required this.filteredRecords,
  });

  factory PunchInOutListResponse.fromJson(Map<String, dynamic> json) {
    return PunchInOutListResponse(
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => PunchInOutResponse.fromJson(item))
          .toList() ?? [],
      totalRecords: json['totalRecords'] ?? 0,
      filteredRecords: json['filteredRecords'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
      'totalRecords': totalRecords,
      'filteredRecords': filteredRecords,
    };
  }
}
