class ExpenseSaveRequest {
  final int? id;
  final int dcrId;
  final String dateOfExpense;
  final int employeeId;
  final int cityId;
  final int? clusterId;
  final int bizUnit;
  final int expenceType;
  final double expenseAmount;
  final String remarks;
  final int userId;
  final String dcrStatus;
  final int dcrStatusId;
  final String? clusterNames;
  final int isGeneric;
  final String? employeeName;
  final List<ExpenseAttachment> attachments;

  ExpenseSaveRequest({
    this.id,
    required this.dcrId,
    required this.dateOfExpense,
    required this.employeeId,
    required this.cityId,
    this.clusterId,
    required this.bizUnit,
    required this.expenceType,
    required this.expenseAmount,
    required this.remarks,
    required this.userId,
    required this.dcrStatus,
    required this.dcrStatusId,
    this.clusterNames,
    required this.isGeneric,
    this.employeeName,
    this.attachments = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'DCRId': dcrId,
      'DateOfExpense': dateOfExpense,
      'EmployeeId': employeeId,
      'CityId': cityId,
      'ClusterId': clusterId,
      'BizUnit': bizUnit,
      'ExpenceType': expenceType,
      'ExpenseAmount': expenseAmount,
      'Remarks': remarks,
      'UserId': userId,
      'DCRStatus': dcrStatus,
      'DCRStatusId': dcrStatusId,
      'ClusterNames': clusterNames,
      'IsGeneric': isGeneric,
      'EmployeeName': employeeName,
      'Attachments': attachments.map((e) => e.toJson()).toList(),
    };
  }
}

class ExpenseGetRequest {
  final int id;

  ExpenseGetRequest({required this.id});

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
    };
  }
}

class ExpenseAttachment {
  final String fileName;
  final String fileType;
  final String filePath;
  final String type;
  final String? fileData; // Base64 encoded file data (for uploads)

  ExpenseAttachment({
    required this.fileName,
    required this.fileType,
    required this.filePath,
    required this.type,
    this.fileData,
  });

  factory ExpenseAttachment.fromJson(Map<String, dynamic> json) {
    return ExpenseAttachment(
      fileName: json['fileName'] ?? json['FileName'] ?? '',
      fileType: json['fileType'] ?? json['FileType'] ?? '',
      filePath: json['filePath'] ?? json['FilePath'] ?? '',
      type: json['type'] ?? json['Type'] ?? '',
      fileData: json['fileData'] ?? json['FileData'],
    );
  }

  Map<String, dynamic> toJson() {
    // Backend expects: FileName, FileType, FilePath, Type (NO FileData)
    // FilePath should be in format: /Uploads/Attachments/DCR/Expenses/{url_encoded_filename}
    return {
      'FileName': fileName,
      'FileType': fileType,
      'FilePath': filePath, // FilePath with URL encoded filename
      'Type': type,
      // FileData is NOT included in the request payload
    };
  }
}

class ExpenseDetailResponse {
  final int id;
  final int dcrId;
  final DateTime dateOfExpense;
  final int employeeId;
  final int cityId;
  final int clusterId;
  final int bizUnit;
  final int expenceType;
  final double expenseAmount;
  final String remarks;
  final int userId;
  final String dcrStatus;
  final int dcrStatusId;
  final String clusterNames;
  final int isGeneric;
  final String employeeName;
  final List<ExpenseAttachment> attachments;

  ExpenseDetailResponse({
    required this.id,
    required this.dcrId,
    required this.dateOfExpense,
    required this.employeeId,
    required this.cityId,
    required this.clusterId,
    required this.bizUnit,
    required this.expenceType,
    required this.expenseAmount,
    required this.remarks,
    required this.userId,
    required this.dcrStatus,
    required this.dcrStatusId,
    required this.clusterNames,
    required this.isGeneric,
    required this.employeeName,
    required this.attachments,
  });

  factory ExpenseDetailResponse.fromJson(Map<String, dynamic> json) {
    // Handle attachments - can be null, empty array, or array with items
    List<ExpenseAttachment> attachmentsList = [];
    if (json['attachments'] != null) {
      if (json['attachments'] is List) {
        attachmentsList = (json['attachments'] as List<dynamic>)
            .map((item) => ExpenseAttachment.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }
    
    return ExpenseDetailResponse(
      id: json['id'] ?? 0,
      dcrId: json['dcrId'] ?? 0,
      dateOfExpense: DateTime.parse(json['dateOfExpense'] ?? DateTime.now().toIso8601String()),
      employeeId: json['employeeId'] ?? 0,
      cityId: json['cityId'] ?? 0,
      clusterId: json['clusterId'] ?? 0,
      bizUnit: json['bizUnit'] ?? 0,
      expenceType: json['expenceType'] ?? 0,
      expenseAmount: (json['expenseAmount'] ?? 0).toDouble(),
      remarks: json['remarks'] ?? '',
      userId: json['userId'] ?? 0,
      dcrStatus: json['dcrStatus'] ?? '',
      dcrStatusId: json['dcrStatusId'] ?? 0,
      clusterNames: json['clusterNames'] ?? '',
      isGeneric: json['isGeneric'] ?? 0,
      employeeName: json['employeeName'] ?? '',
      attachments: attachmentsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dcrId': dcrId,
      'dateOfExpense': dateOfExpense.toIso8601String(),
      'employeeId': employeeId,
      'cityId': cityId,
      'clusterId': clusterId,
      'bizUnit': bizUnit,
      'expenceType': expenceType,
      'expenseAmount': expenseAmount,
      'remarks': remarks,
      'userId': userId,
      'dcrStatus': dcrStatus,
      'dcrStatusId': dcrStatusId,
      'clusterNames': clusterNames,
      'isGeneric': isGeneric,
      'employeeName': employeeName,
      'attachments': attachments.map((item) => item.toJson()).toList(),
    };
  }
}

class ExpenseActionRequest {
  final int id;
  final int action;
  final String comment;

  ExpenseActionRequest({
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

class ExpenseActionResponse {
  final bool success;
  final String message;

  ExpenseActionResponse({
    required this.success,
    required this.message,
  });

  factory ExpenseActionResponse.fromJson(Map<String, dynamic> json) {
    return ExpenseActionResponse(
      success: json['isSuccess'] ?? false,
      message: json['message'] ?? json['errorMessage'] ?? '',
    );
  }
}

class ExpenseSaveResponse {
  final bool success;
  final String message;
  final int? expenseId;

  ExpenseSaveResponse({
    required this.success,
    required this.message,
    this.expenseId,
  });

  factory ExpenseSaveResponse.fromJson(Map<String, dynamic> json) {
    return ExpenseSaveResponse(
      success: json['success'] == true || json['status'] == true || json.containsKey('Id'),
      message: json['message'] ?? json['msg'] ?? 'Expense saved successfully',
      expenseId: json['Id'] ?? json['id'],
    );
  }
}

// Bulk Expense Action Models
class ExpenseBulkApproveRequest {
  final int id;
  final String comments;
  final int userId;
  final int action;
  final List<ExpenseActionDetail> expenseAction;

  ExpenseBulkApproveRequest({
    required this.id,
    required this.comments,
    required this.userId,
    required this.action,
    required this.expenseAction,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Comments': comments,
      'UserId': userId,
      'Action': action,
      'ExpenseAction': expenseAction.map((detail) => detail.toJson()).toList(),
    };
  }
}

class ExpenseBulkRejectRequest {
  final int id;
  final String comments;
  final int userId;
  final int action;
  final List<ExpenseActionDetail> expenseAction;

  ExpenseBulkRejectRequest({
    required this.id,
    required this.comments,
    required this.userId,
    required this.action,
    required this.expenseAction,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Comments': comments,
      'UserId': userId,
      'Action': action,
      'ExpenseAction': expenseAction.map((detail) => detail.toJson()).toList(),
    };
  }
}

class ExpenseActionDetail {
  final int id;

  ExpenseActionDetail({
    required this.id,
  });

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
    };
  }
}

class ExpenseGetResponse {
  final int id;
  final int? dcrId;
  final String dateOfExpense;
  final int employeeId;
  final int cityId;
  final int? clusterId;
  final int bizUnit;
  final int expenceType;
  final double expenseAmount;
  final String remarks;
  final int userId;
  final String dcrStatus;
  final int dcrStatusId;
  final String? clusterNames;
  final int isGeneric;
  final String? employeeName;
  final List<ExpenseAttachment>? attachments;

  ExpenseGetResponse({
    required this.id,
    this.dcrId,
    required this.dateOfExpense,
    required this.employeeId,
    required this.cityId,
    this.clusterId,
    required this.bizUnit,
    required this.expenceType,
    required this.expenseAmount,
    required this.remarks,
    required this.userId,
    required this.dcrStatus,
    required this.dcrStatusId,
    this.clusterNames,
    required this.isGeneric,
    this.employeeName,
    this.attachments,
  });

  factory ExpenseGetResponse.fromJson(Map<String, dynamic> json) {
    return ExpenseGetResponse(
      id: json['id'] ?? 0,
      dcrId: json['dcrId'],
      dateOfExpense: json['dateOfExpense'] ?? '',
      employeeId: json['employeeId'] ?? 0,
      cityId: json['cityId'] ?? 0,
      clusterId: json['clusterId'],
      bizUnit: json['bizUnit'] ?? 0,
      expenceType: json['expenceType'] ?? 0,
      expenseAmount: (json['expenseAmount'] ?? 0).toDouble(),
      remarks: json['remarks'] ?? '',
      userId: json['userId'] ?? 0,
      dcrStatus: json['dcrStatus'] ?? '',
      dcrStatusId: json['dcrStatusId'] ?? 0,
      clusterNames: json['clusterNames'],
      isGeneric: json['isGeneric'] ?? 0,
      employeeName: json['employeeName'],
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((item) => ExpenseAttachment.fromJson(item))
          .toList(),
    );
  }
}

// File Upload API Response Models
class FileUploadResponse {
  final bool success;
  final String fileName;
  final String path;

  FileUploadResponse({
    required this.success,
    required this.fileName,
    required this.path,
  });

  factory FileUploadResponse.fromJson(Map<String, dynamic> json) {
    return FileUploadResponse(
      success: json['success'] ?? false,
      fileName: json['fileName'] ?? '',
      path: json['path'] ?? '',
    );
  }
}

class FileUploadBaseUrlResponse {
  final bool success;
  final String baseUrl;

  FileUploadBaseUrlResponse({
    required this.success,
    required this.baseUrl,
  });

  factory FileUploadBaseUrlResponse.fromJson(Map<String, dynamic> json) {
    return FileUploadBaseUrlResponse(
      success: json['success'] ?? false,
      baseUrl: json['baseUrl'] ?? '',
    );
  }
}
