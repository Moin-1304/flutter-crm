class MenuResponse {
  final int id;
  final int sbuId;
  final int createdBy;
  final int status;
  final int userId;
  final int roleId;
  final int groupId;
  final String groupName;
  final int pageId;
  final String pageName;
  final List<dynamic> userPrivilegeList;
  final List<UserPrivilegeMenu> userPrivilegeMenuList;

  MenuResponse({
    required this.id,
    required this.sbuId,
    required this.createdBy,
    required this.status,
    required this.userId,
    required this.roleId,
    required this.groupId,
    required this.groupName,
    required this.pageId,
    required this.pageName,
    required this.userPrivilegeList,
    required this.userPrivilegeMenuList,
  });

  factory MenuResponse.fromJson(Map<String, dynamic> json) {
    return MenuResponse(
      id: json['id'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      createdBy: json['createdBy'] ?? 0,
      status: json['status'] ?? 0,
      userId: json['userId'] ?? 0,
      roleId: json['roleId'] ?? 0,
      groupId: json['groupId'] ?? 0,
      groupName: json['groupName'] ?? '',
      pageId: json['pageId'] ?? 0,
      pageName: json['pageName'] ?? '',
      userPrivilegeList: (json['userPrivilegeList'] ?? []) as List<dynamic>,
      userPrivilegeMenuList: (json['userPrivilegeMenuList'] as List<dynamic>? ?? [])
          .map((e) => UserPrivilegeMenu.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sbuId': sbuId,
      'createdBy': createdBy,
      'status': status,
      'userId': userId,
      'roleId': roleId,
      'groupId': groupId,
      'groupName': groupName,
      'pageId': pageId,
      'pageName': pageName,
      'userPrivilegeList': userPrivilegeList,
      'userPrivilegeMenuList':
      userPrivilegeMenuList.map((e) => e.toJson()).toList(),
    };
  }
}

class UserPrivilegeMenu {
  final int id;
  final int sbuId;
  final int createdBy;
  final int status;
  final String name;
  final int parentId;
  final int menuType;
  final String privilegeTypeText;
  final bool hasChild;
  final bool hasRight;
  final int displayOrder;
  final String icon;
  final String pageUrl;

  UserPrivilegeMenu({
    required this.id,
    required this.sbuId,
    required this.createdBy,
    required this.status,
    required this.name,
    required this.parentId,
    required this.menuType,
    required this.privilegeTypeText,
    required this.hasChild,
    required this.hasRight,
    required this.displayOrder,
    required this.icon,
    required this.pageUrl,
  });

  factory UserPrivilegeMenu.fromJson(Map<String, dynamic> json) {
    return UserPrivilegeMenu(
      id: json['id'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      createdBy: json['createdBy'] ?? 0,
      status: json['status'] ?? 0,
      name: json['name'] ?? '',
      parentId: json['parentId'] ?? 0,
      menuType: json['menuType'] ?? 0,
      privilegeTypeText: json['privilegeTypeText'] ?? '',
      hasChild: json['hasChild'] ?? false,
      hasRight: json['hasRight'] ?? false,
      displayOrder: json['displayOrder'] ?? 0,
      icon: json['icon'] ?? '',
      pageUrl: json['pageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sbuId': sbuId,
      'createdBy': createdBy,
      'status': status,
      'name': name,
      'parentId': parentId,
      'menuType': menuType,
      'privilegeTypeText': privilegeTypeText,
      'hasChild': hasChild,
      'hasRight': hasRight,
      'displayOrder': displayOrder,
      'icon': icon,
      'pageUrl': pageUrl,
    };
  }
}



