class UserDetail {
  final String? createdDate;
  final int? modifiedBy;
  final String? modifiedDate;
  final int id;
  final int? userId;
  final int sbuId;
  final int status;
  final String name;
  final String? password;
  final String? passwordHash;
  final bool emailConfirmed;
  final String? lastLoginDateTime;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String email;
  final String affiliation;
  final String company;
  final List<Division> divisions;
  final List<Division>? divisionLists;
  final String? roleRequested;
  final String? parent;
  final int? parentId;
  final String? code;
  final String? text;
  final String? type;
  final int? level;
  final String? subType;
  final String? typeText;
  final String? subTypeText;
  final String? parentName;
  final String dateFormat;
  final String dateTimeFormat;
  final List<UserRole> roles;
  final String serviceArea;
  final String notes;
  final int timezoneId;
  final int active;
  final int otpNumber;
  final List<dynamic>? rolesList;
  final String? otpCreatedDate;
  final int seccondOTPNumber;
  final int? createdBy;
  final bool termsAndConditions;
  final int isDelete;
  final String? activeStatusText;
  final String activeText;
  final String? rejectionReason;
  final int isApproved;
  final String? isApprovedText;
  final String userName;
  final String userImageName;
  final String userImagePhysicalLocation;
  final String userImagePhysicalFile;
  final int? displayOrder;
  final bool isAdmin;
  final String appType;
  final int userType;
  final int roleCategory;
  final dynamic file;
  final int? slNo;
  final String? physicalFile;
  final String? physicalLocation;
  final String? fileName;
  final String phoneNumber;
  final bool phoneNumberConfirmed;
  final bool twoFactorEnabled;
  final String? lockoutEnd;
  final bool lockoutEnabled;
  final int accessFailedCount;
  final String securityStamp;
  final double maxFileSize;
  final String fileType;
  final bool isParticipants;
  final bool isLocked;
  final int? groupId;
  final int? roleId;
  final int? pageId;
  final List<dynamic>? expandedItems;
  final List<dynamic>? checkedItems;
  final List<dynamic>? userPrivilegeList;
  final List<dynamic>? userPrivilegeMenuList;
  final String? userListCardTitile;
  final String primaryPwd;
  final String? userCardTitile;
  final String? approveduserMessage;
  final String? userUpdateMessage;
  final String? action;
  final String? edit;
  final String? view;
  final String? validationMessage;
  final int pageSize;
  final String decimalFormat;
  final String thousandSeparator;
  final bool isAllSelected;
  final bool enableAutoSave;
  final int? autoSaveIntervalInMinutes;
  final int idleTime;
  final int showPopupBefore;
  final String inputDecimalFormat;
  final String cellPhone;
  final int rowNumber;
  final int? organizationId;
  final String? organizationText;
  final bool? isTicketUserAdmin;
  final int baseCurrency;
  final String baseCurrencyText;
  final int employeeId;
  final String employeeName;
  final bool hasParent;
  final int sbuCompany;
  final String sbuName;
  final String? version;
  final String currencyFormat;
  final String quantityThousandSeparator;
  final int monthFilterFromBefore;
  final int sbuCountry;
  final String quantityFormat;
  final String exchangeRateFormat;
  final int? primarySBUId;
  final int? processGroupId;
  final String? processGroupText;
  final String? roleText;
  final bool iS_CHECKED;
  final int? moduleId;
  final String? moduleText;
  final String? signatureFileName;

  UserDetail({
    this.createdDate,
    this.modifiedBy,
    this.modifiedDate,
    required this.id,
    this.userId,
    required this.sbuId,
    required this.status,
    required this.name,
    this.password,
    this.passwordHash,
    required this.emailConfirmed,
    this.lastLoginDateTime,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.email,
    required this.affiliation,
    required this.company,
    required this.divisions,
    this.divisionLists,
    this.roleRequested,
    this.parent,
    this.parentId,
    this.code,
    this.text,
    this.type,
    this.level,
    this.subType,
    this.typeText,
    this.subTypeText,
    this.parentName,
    required this.dateFormat,
    required this.dateTimeFormat,
    required this.roles,
    required this.serviceArea,
    required this.notes,
    required this.timezoneId,
    required this.active,
    required this.otpNumber,
    this.rolesList,
    this.otpCreatedDate,
    required this.seccondOTPNumber,
    this.createdBy,
    required this.termsAndConditions,
    required this.isDelete,
    this.activeStatusText,
    required this.activeText,
    this.rejectionReason,
    required this.isApproved,
    this.isApprovedText,
    required this.userName,
    required this.userImageName,
    required this.userImagePhysicalLocation,
    required this.userImagePhysicalFile,
    this.displayOrder,
    required this.isAdmin,
    required this.appType,
    required this.userType,
    required this.roleCategory,
    this.file,
    this.slNo,
    this.physicalFile,
    this.physicalLocation,
    this.fileName,
    required this.phoneNumber,
    required this.phoneNumberConfirmed,
    required this.twoFactorEnabled,
    this.lockoutEnd,
    required this.lockoutEnabled,
    required this.accessFailedCount,
    required this.securityStamp,
    required this.maxFileSize,
    required this.fileType,
    required this.isParticipants,
    required this.isLocked,
    this.groupId,
    this.roleId,
    this.pageId,
    this.expandedItems,
    this.checkedItems,
    this.userPrivilegeList,
    this.userPrivilegeMenuList,
    this.userListCardTitile,
    required this.primaryPwd,
    this.userCardTitile,
    this.approveduserMessage,
    this.userUpdateMessage,
    this.action,
    this.edit,
    this.view,
    this.validationMessage,
    required this.pageSize,
    required this.decimalFormat,
    required this.thousandSeparator,
    required this.isAllSelected,
    required this.enableAutoSave,
    this.autoSaveIntervalInMinutes,
    required this.idleTime,
    required this.showPopupBefore,
    required this.inputDecimalFormat,
    required this.cellPhone,
    required this.rowNumber,
    this.organizationId,
    this.organizationText,
    this.isTicketUserAdmin,
    required this.baseCurrency,
    required this.baseCurrencyText,
    required this.employeeId,
    required this.employeeName,
    required this.hasParent,
    required this.sbuCompany,
    required this.sbuName,
    this.version,
    required this.currencyFormat,
    required this.quantityThousandSeparator,
    required this.monthFilterFromBefore,
    required this.sbuCountry,
    required this.quantityFormat,
    required this.exchangeRateFormat,
    this.primarySBUId,
    this.processGroupId,
    this.processGroupText,
    this.roleText,
    required this.iS_CHECKED,
    this.moduleId,
    this.moduleText,
    this.signatureFileName,
  });

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    return UserDetail(
      createdDate: json['createdDate'],
      modifiedBy: json['modifiedBy'],
      modifiedDate: json['modifiedDate'],
      id: json['id'] ?? 0,
      userId: json['userId'],
      sbuId: json['sbuId'] ?? 0,
      status: json['status'] ?? 0,
      name: json['name'] ?? '',
      password: json['password'],
      passwordHash: json['passwordHash'],
      emailConfirmed: json['emailConfirmed'] ?? false,
      lastLoginDateTime: json['lastLoginDateTime'],
      firstName: json['firstName'] ?? '',
      middleName: json['middleName'],
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      affiliation: json['affiliation'] ?? '',
      company: json['company'] ?? '',
      divisions: (json['division'] as List<dynamic>?)
          ?.map((e) => Division.fromJson(e))
          .toList() ?? [],
      divisionLists: (json['divisionLists'] as List<dynamic>?)
          ?.map((e) => Division.fromJson(e))
          .toList(),
      roleRequested: json['roleRequested'],
      parent: json['parent'],
      parentId: json['parentId'],
      code: json['code'],
      text: json['text'],
      type: json['type'],
      level: json['level'],
      subType: json['subType'],
      typeText: json['typeText'],
      subTypeText: json['subTypeText'],
      parentName: json['parentName'],
      dateFormat: json['dateFormat'] ?? 'dd-MMM-yyyy',
      dateTimeFormat: json['dateTimeFormat'] ?? 'dd-MMM-yyyy HH:mm:ss',
      roles: (json['role'] as List<dynamic>?)
          ?.map((e) => UserRole.fromJson(e))
          .toList() ?? [],
      serviceArea: json['serviceArea'] ?? '',
      notes: json['notes'] ?? '',
      timezoneId: json['timezoneId'] ?? 0,
      active: json['active'] ?? 0,
      otpNumber: json['otpNumber'] ?? 0,
      rolesList: json['roles'],
      otpCreatedDate: json['otpCreatedDate'],
      seccondOTPNumber: json['seccondOTPNumber'] ?? 0,
      createdBy: json['createdBy'],
      termsAndConditions: json['termsAndConditions'] ?? false,
      isDelete: json['isDelete'] ?? 0,
      activeStatusText: json['activeStatusText'],
      activeText: json['activeText'] ?? '',
      rejectionReason: json['rejectionReason'],
      isApproved: json['isApproved'] ?? 0,
      isApprovedText: json['isApprovedText'],
      userName: json['userName'] ?? '',
      userImageName: json['userImageName'] ?? '',
      userImagePhysicalLocation: json['userImagePhysicalLocation'] ?? '',
      userImagePhysicalFile: json['userImagePhysicalFile'] ?? '',
      displayOrder: json['displayOrder'],
      isAdmin: json['isAdmin'] ?? false,
      appType: json['appType'] ?? '',
      userType: json['userType'] ?? 0,
      roleCategory: json['roleCategory'] ?? 0,
      file: json['file'],
      slNo: json['slNo'],
      physicalFile: json['physicalFile'],
      physicalLocation: json['physicalLocation'],
      fileName: json['fileName'],
      phoneNumber: json['phoneNumber'] ?? '',
      phoneNumberConfirmed: json['phoneNumberConfirmed'] ?? false,
      twoFactorEnabled: json['twoFactorEnabled'] ?? false,
      lockoutEnd: json['lockoutEnd'],
      lockoutEnabled: json['lockoutEnabled'] ?? false,
      accessFailedCount: json['accessFailedCount'] ?? 0,
      securityStamp: json['securityStamp'] ?? '',
      maxFileSize: (json['maxFileSize'] ?? 0.0).toDouble(),
      fileType: json['fileType'] ?? '',
      isParticipants: json['isParticipants'] ?? false,
      isLocked: json['isLocked'] ?? false,
      groupId: json['groupId'],
      roleId: json['roleId'],
      pageId: json['pageId'],
      expandedItems: json['expandedItems'],
      checkedItems: json['checkedItems'],
      userPrivilegeList: json['userPrivilegeList'],
      userPrivilegeMenuList: json['userPrivilegeMenuList'],
      userListCardTitile: json['userListCardTitile'],
      primaryPwd: json['primaryPwd'] ?? '',
      userCardTitile: json['userCardTitile'],
      approveduserMessage: json['approveduserMessage'],
      userUpdateMessage: json['userUpdateMessage'],
      action: json['action'],
      edit: json['edit'],
      view: json['view'],
      validationMessage: json['validationMessage'],
      pageSize: json['pageSize'] ?? 15,
      decimalFormat: json['decimalFormat'] ?? '0.00',
      thousandSeparator: json['thousandSeparator'] ?? '#,##0.00',
      isAllSelected: json['isAllSelected'] ?? false,
      enableAutoSave: json['enableAutoSave'] ?? false,
      autoSaveIntervalInMinutes: json['autoSaveIntervalInMinutes'],
      idleTime: json['idleTime'] ?? 600,
      showPopupBefore: json['showPopupBefore'] ?? 5,
      inputDecimalFormat: json['inputDecimalFormat'] ?? '#,##0.00',
      cellPhone: json['cellPhone'] ?? '',
      rowNumber: json['rowNumber'] ?? 0,
      organizationId: json['organizationId'],
      organizationText: json['organizationText'],
      isTicketUserAdmin: json['isTicketUserAdmin'],
      baseCurrency: json['baseCurrency'] ?? 0,
      baseCurrencyText: json['baseCurrencyText'] ?? '',
      employeeId: json['employeeId'] ?? 0,
      employeeName: json['employeeName'] ?? '',
      hasParent: json['hasParent'] ?? false,
      sbuCompany: json['sbuCompany'] ?? 0,
      sbuName: json['sbuName'] ?? '',
      version: json['version'],
      currencyFormat: json['currencyFormat'] ?? '#,##0.00',
      quantityThousandSeparator: json['quantityThousandSeparator'] ?? '#,##0.00',
      monthFilterFromBefore: json['monthFilterFromBefore'] ?? 0,
      sbuCountry: json['sbuCountry'] ?? 0,
      quantityFormat: json['quantityFormat'] ?? '0.00',
      exchangeRateFormat: json['exchangeRateFormat'] ?? '#,##0.00000',
      primarySBUId: json['primarySBUId'],
      processGroupId: json['processGroupId'],
      processGroupText: json['processGroupText'],
      roleText: json['roleText'],
      iS_CHECKED: json['iS_CHECKED'] ?? false,
      moduleId: json['moduleId'],
      moduleText: json['moduleText'],
      signatureFileName: json['signatureFileName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'createdDate': createdDate,
      'modifiedBy': modifiedBy,
      'modifiedDate': modifiedDate,
      'id': id,
      'userId': userId,
      'sbuId': sbuId,
      'status': status,
      'name': name,
      'password': password,
      'passwordHash': passwordHash,
      'emailConfirmed': emailConfirmed,
      'lastLoginDateTime': lastLoginDateTime,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'email': email,
      'affiliation': affiliation,
      'company': company,
      'division': divisions.map((e) => e.toJson()).toList(),
      'divisionLists': divisionLists?.map((e) => e.toJson()).toList(),
      'roleRequested': roleRequested,
      'parent': parent,
      'parentId': parentId,
      'code': code,
      'text': text,
      'type': type,
      'level': level,
      'subType': subType,
      'typeText': typeText,
      'subTypeText': subTypeText,
      'parentName': parentName,
      'dateFormat': dateFormat,
      'dateTimeFormat': dateTimeFormat,
      'role': roles.map((e) => e.toJson()).toList(),
      'serviceArea': serviceArea,
      'notes': notes,
      'timezoneId': timezoneId,
      'active': active,
      'otpNumber': otpNumber,
      'roles': rolesList,
      'otpCreatedDate': otpCreatedDate,
      'seccondOTPNumber': seccondOTPNumber,
      'createdBy': createdBy,
      'termsAndConditions': termsAndConditions,
      'isDelete': isDelete,
      'activeStatusText': activeStatusText,
      'activeText': activeText,
      'rejectionReason': rejectionReason,
      'isApproved': isApproved,
      'isApprovedText': isApprovedText,
      'userName': userName,
      'userImageName': userImageName,
      'userImagePhysicalLocation': userImagePhysicalLocation,
      'userImagePhysicalFile': userImagePhysicalFile,
      'displayOrder': displayOrder,
      'isAdmin': isAdmin,
      'appType': appType,
      'userType': userType,
      'roleCategory': roleCategory,
      'file': file,
      'slNo': slNo,
      'physicalFile': physicalFile,
      'physicalLocation': physicalLocation,
      'fileName': fileName,
      'phoneNumber': phoneNumber,
      'phoneNumberConfirmed': phoneNumberConfirmed,
      'twoFactorEnabled': twoFactorEnabled,
      'lockoutEnd': lockoutEnd,
      'lockoutEnabled': lockoutEnabled,
      'accessFailedCount': accessFailedCount,
      'securityStamp': securityStamp,
      'maxFileSize': maxFileSize,
      'fileType': fileType,
      'isParticipants': isParticipants,
      'isLocked': isLocked,
      'groupId': groupId,
      'roleId': roleId,
      'pageId': pageId,
      'expandedItems': expandedItems,
      'checkedItems': checkedItems,
      'userPrivilegeList': userPrivilegeList,
      'userPrivilegeMenuList': userPrivilegeMenuList,
      'userListCardTitile': userListCardTitile,
      'primaryPwd': primaryPwd,
      'userCardTitile': userCardTitile,
      'approveduserMessage': approveduserMessage,
      'userUpdateMessage': userUpdateMessage,
      'action': action,
      'edit': edit,
      'view': view,
      'validationMessage': validationMessage,
      'pageSize': pageSize,
      'decimalFormat': decimalFormat,
      'thousandSeparator': thousandSeparator,
      'isAllSelected': isAllSelected,
      'enableAutoSave': enableAutoSave,
      'autoSaveIntervalInMinutes': autoSaveIntervalInMinutes,
      'idleTime': idleTime,
      'showPopupBefore': showPopupBefore,
      'inputDecimalFormat': inputDecimalFormat,
      'cellPhone': cellPhone,
      'rowNumber': rowNumber,
      'organizationId': organizationId,
      'organizationText': organizationText,
      'isTicketUserAdmin': isTicketUserAdmin,
      'baseCurrency': baseCurrency,
      'baseCurrencyText': baseCurrencyText,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'hasParent': hasParent,
      'sbuCompany': sbuCompany,
      'sbuName': sbuName,
      'version': version,
      'currencyFormat': currencyFormat,
      'quantityThousandSeparator': quantityThousandSeparator,
      'monthFilterFromBefore': monthFilterFromBefore,
      'sbuCountry': sbuCountry,
      'quantityFormat': quantityFormat,
      'exchangeRateFormat': exchangeRateFormat,
      'primarySBUId': primarySBUId,
      'processGroupId': processGroupId,
      'processGroupText': processGroupText,
      'roleText': roleText,
      'iS_CHECKED': iS_CHECKED,
      'moduleId': moduleId,
      'moduleText': moduleText,
      'signatureFileName': signatureFileName,
    };
  }
}

class Division {
  final int division;
  final String divisionText;

  Division({
    required this.division,
    required this.divisionText,
  });

  factory Division.fromJson(Map<String, dynamic> json) {
    return Division(
      division: json['division'] ?? 0,
      divisionText: json['divisionText'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'division': division,
      'divisionText': divisionText,
    };
  }
}

class UserRole {
  final int id;
  final int? createdBy;
  final int userId;
  final int sbuId;
  final int status;
  final int roleId;

  UserRole({
    required this.id,
    this.createdBy,
    required this.userId,
    required this.sbuId,
    required this.status,
    required this.roleId,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: json['id'] ?? 0,
      createdBy: json['createdBy'],
      userId: json['userId'] ?? 0,
      sbuId: json['sbuId'] ?? 0,
      status: json['status'] ?? 0,
      roleId: json['roleId'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdBy': createdBy,
      'userId': userId,
      'sbuId': sbuId,
      'status': status,
      'roleId': roleId,
    };
  }
}


