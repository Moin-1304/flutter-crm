class PunchInOutSaveRequest {
  final int id;
  final int createdBy;
  final int status;
  final int sbuId;
  final int employeeId;
  final int userId;
  final int checkInStatus;
  final int bizUnit;
  final double? kilometerIn;
  final double? kilometerOut;
  final double? privateKilometers;

  PunchInOutSaveRequest({
    required this.id,
    required this.createdBy,
    required this.status,
    required this.sbuId,
    required this.employeeId,
    required this.userId,
    required this.checkInStatus,
    required this.bizUnit,
    this.kilometerIn,
    this.kilometerOut,
    this.privateKilometers,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'CreatedBy': createdBy,
      'Status': status,
      'SbuId': sbuId,
      'EmployeeId': employeeId,
      'UserId': userId,
      'CheckInStatus': checkInStatus,
      'BizUnit': bizUnit,
      'KilometerIn': kilometerIn,
      'KilometerOut': kilometerOut,
      'PrivateKilometers': privateKilometers,
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
  final double? kilometerIn;
  final double? kilometerOut;

  LogDetail({
    required this.id,
    required this.userId,
    required this.sbuId,
    required this.checkInStatus,
    required this.checkOutStatus,
    required this.checkDateTime,
    required this.activity,
    this.kilometerIn,
    this.kilometerOut,
  });

  factory LogDetail.fromJson(Map<String, dynamic> json) {
    return LogDetail(
      id: json['id'] ?? json['Id'] ?? 0,
      userId: json['userId'] ?? json['UserId'] ?? 0,
      sbuId: json['sbuId'] ?? json['SbuId'] ?? 0,
      checkInStatus: json['checkInStatus'] ?? json['CheckInStatus'] ?? 0,
      checkOutStatus: json['checkOutStatus'] ?? json['CheckOutStatus'] ?? 0,
      checkDateTime: DateTime.parse(json['checkDateTime'] ?? json['CheckDateTime'] ?? DateTime.now().toIso8601String()),
      activity: json['activity'] ?? json['Activity'] ?? '',
      kilometerIn: _parseDouble(json['kilometerIn'] ?? json['KilometerIn']),
      kilometerOut: _parseDouble(json['kilometerOut'] ?? json['KilometerOut']),
    );
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String && v.trim().isNotEmpty) return double.tryParse(v.trim());
    return null;
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
      'kilometerIn': kilometerIn,
      'kilometerOut': kilometerOut,
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
  final double? kilometerIn;
  final double? kilometerOut;

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
    this.kilometerIn,
    this.kilometerOut,
  });

  factory PunchInOutResponse.fromJson(Map<String, dynamic> json) {
    return PunchInOutResponse(
      id: json['id'] ?? json['Id'] ?? 0,
      createdBy: json['createdBy'] ?? json['CreatedBy'] ?? 0,
      status: json['status'] ?? json['Status'] ?? 0,
      sbuId: json['sbuId'] ?? json['SbuId'] ?? 0,
      employeeId: json['employeeId'] ?? json['EmployeeId'] ?? 0,
      userId: json['userId'] ?? json['UserId'] ?? 0,
      checkInStatus: json['checkInStatus'] ?? json['CheckInStatus'] ?? 0,
      bizUnit: json['bizUnit'] ?? json['BizUnit'] ?? 0,
      userName: json['userName'] ?? json['UserName'] ?? '',
      sbuName: json['sbuName'] ?? json['SbuName'] ?? '',
      lastLoggedOutTime: () {
        final v = json['lastLoggedOutTime'] ?? json['LastLoggedOutTime'];
        if (v == null) return null;
        return DateTime.tryParse(v.toString());
      }(),
      logDetails: ((json['logDetails'] ?? json['LogDetails']) as List<dynamic>?)
          ?.map((item) => LogDetail.fromJson(item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map)))
          .toList() ?? [],
      kilometerIn: LogDetail._parseDouble(json['kilometerIn'] ?? json['KilometerIn']),
      kilometerOut: LogDetail._parseDouble(json['kilometerOut'] ?? json['KilometerOut']),
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
