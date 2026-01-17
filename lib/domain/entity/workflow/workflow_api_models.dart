/// Workflow API Models

class WorkflowGetAllActionsRequest {
  final int? refId;
  final int? applicationId;
  final int menuId;
  final int userId;
  final int module;
  final int bizUnit;
  final String url;

  WorkflowGetAllActionsRequest({
    this.refId,
    this.applicationId,
    required this.menuId,
    required this.userId,
    required this.module,
    required this.bizUnit,
    required this.url,
  });

  Map<String, dynamic> toJson() {
    return {
      'RefId': refId,
      'ApplicationId': applicationId,
      'MenuId': menuId,
      'UserId': userId,
      'Module': module,
      'BizUnit': bizUnit,
      'Url': url,
    };
  }
}

class WorkflowGetAllActionsResponse {
  final int id;
  final String processName;
  final int workFlowStatus;
  final bool hasEdit;
  final List<ProcessActionDetail> processActionDetails;

  WorkflowGetAllActionsResponse({
    required this.id,
    required this.processName,
    required this.workFlowStatus,
    required this.hasEdit,
    required this.processActionDetails,
  });

  factory WorkflowGetAllActionsResponse.fromJson(Map<String, dynamic> json) {
    return WorkflowGetAllActionsResponse(
      id: json['id'] ?? 0,
      processName: json['processName'] ?? '',
      workFlowStatus: json['workFlowStatus'] ?? 0,
      hasEdit: json['hasEdit'] ?? false,
      processActionDetails: (json['processActionDetails'] as List<dynamic>?)
          ?.map((item) => ProcessActionDetail.fromJson(item))
          .toList() ?? [],
    );
  }
}

class ProcessActionDetail {
  final int processID;
  final String processName;
  final int processActionId;
  final String name;
  final String color;
  final bool hasMultipleAction;
  final bool iscomplete;
  final bool hasRights;
  final int? currProcessActionId;
  final int detailID;
  final dynamic relatedActions;
  final int displayOrder;
  final bool hasEdit;
  final bool transactionCompleted;
  final int actionValue;
  final List<ProcessAction>? processAction;

  ProcessActionDetail({
    required this.processID,
    required this.processName,
    required this.processActionId,
    required this.name,
    required this.color,
    required this.hasMultipleAction,
    required this.iscomplete,
    required this.hasRights,
    this.currProcessActionId,
    required this.detailID,
    this.relatedActions,
    required this.displayOrder,
    required this.hasEdit,
    required this.transactionCompleted,
    required this.actionValue,
    this.processAction,
  });

  factory ProcessActionDetail.fromJson(Map<String, dynamic> json) {
    return ProcessActionDetail(
      processID: json['processID'] ?? 0,
      processName: json['processName'] ?? '',
      processActionId: json['processActionId'] ?? 0,
      name: json['name'] ?? '',
      color: json['color'] ?? '',
      hasMultipleAction: json['hasMultipleAction'] ?? false,
      iscomplete: json['iscomplete'] ?? false,
      hasRights: json['hasRights'] ?? false,
      currProcessActionId: json['currProcessActionId'],
      detailID: json['detailID'] ?? 0,
      relatedActions: json['relatedActions'],
      displayOrder: json['displayOrder'] ?? 0,
      hasEdit: json['hasEdit'] ?? false,
      transactionCompleted: json['transactionCompleted'] ?? false,
      actionValue: json['actionValue'] ?? 0,
      processAction: (json['processAction'] as List<dynamic>?)
          ?.map((item) => ProcessAction.fromJson(item))
          .toList(),
    );
  }
}

class ProcessAction {
  final int processActionId;
  final String actionName;

  ProcessAction({
    required this.processActionId,
    required this.actionName,
  });

  factory ProcessAction.fromJson(Map<String, dynamic> json) {
    return ProcessAction(
      processActionId: json['processActionId'] ?? 0,
      actionName: json['actionName'] ?? '',
    );
  }
}

/// GetUserPagePrivileges API Models

class WorkflowGetUserPagePrivilegesRequest {
  final String? groupName;
  final String? pageName;
  final int userId;
  final int? roleId;
  final int? groupId;
  final int? pageId;
  final String pageUrl;
  final int menuId;
  final int module;
  final bool hasRight;
  final String? hierarchy;
  final int? sectorId;
  final String? tabName;
  final String? subTabName;
  final int bizunit;

  WorkflowGetUserPagePrivilegesRequest({
    this.groupName,
    this.pageName,
    required this.userId,
    this.roleId,
    this.groupId,
    this.pageId,
    required this.pageUrl,
    required this.menuId,
    required this.module,
    required this.hasRight,
    this.hierarchy,
    this.sectorId,
    this.tabName,
    this.subTabName,
    required this.bizunit,
  });

  Map<String, dynamic> toJson() {
    return {
      'GroupName': groupName,
      'PageName': pageName,
      'UserId': userId,
      'RoleId': roleId,
      'GroupId': groupId,
      'PageId': pageId,
      'PageUrl': pageUrl,
      'MenuId': menuId,
      'Module': module,
      'HasRight': hasRight,
      'Hierarchy': hierarchy,
      'SectorId': sectorId,
      'TabName': tabName,
      'SubTabName': subTabName,
      'Bizunit': bizunit,
    };
  }
}

class WorkflowGetUserPagePrivilegesResponse {
  final Map<String, ButtonPrivilege> buttonPrivileges;

  WorkflowGetUserPagePrivilegesResponse({
    required this.buttonPrivileges,
  });

  factory WorkflowGetUserPagePrivilegesResponse.fromJson(Map<String, dynamic> json) {
    final Map<String, ButtonPrivilege> privileges = {};
    
    // Parse all button privileges from the response
    json.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        privileges[key] = ButtonPrivilege.fromJson(value);
      } else if (value is bool) {
        // If value is just a boolean, create a ButtonPrivilege with hasRight = value
        privileges[key] = ButtonPrivilege(hasRight: value);
      }
    });
    
    return WorkflowGetUserPagePrivilegesResponse(
      buttonPrivileges: privileges,
    );
  }
}

class ButtonPrivilege {
  final bool hasRight;
  final String? buttonName;
  final String? action;

  ButtonPrivilege({
    required this.hasRight,
    this.buttonName,
    this.action,
  });

  factory ButtonPrivilege.fromJson(Map<String, dynamic> json) {
    return ButtonPrivilege(
      hasRight: json['HasRight'] == true || json['hasRight'] == true || json['HasRight'] == 1 || json['hasRight'] == 1,
      buttonName: json['ButtonName'] ?? json['buttonName'],
      action: json['Action'] ?? json['action'],
    );
  }
}



