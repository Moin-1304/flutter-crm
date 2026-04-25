class Endpoints {
  Endpoints._();

  /// Default base URL (used when none is stored). Shown as suggestion on server setup.
  static const String _defaultBaseUrl = "https://103.141.54.146:1443/erpuatapi/api";

  /// Suggested base URL for server setup screen (e.g. for existing users upgrading).
  static const String suggestedBaseUrl = _defaultBaseUrl;

  /// Runtime base URL for API calls. Set from secure storage at startup or when user configures server.
  static String _baseUrl = _defaultBaseUrl;

  static String get baseUrl => _baseUrl;
  static set baseUrl(String value) {
    _baseUrl = value.isEmpty ? _defaultBaseUrl : value;
  }

  // receiveTimeout
  static const int receiveTimeout = 15000;

  // connectTimeout
  static const int connectionTimeout = 30000;

  // booking endpoints
  static String get getPosts => "$baseUrl/posts";

  //login endpoints
  static String get login => "$baseUrl/Login/Login";

  // menu endpoints
  static String get menuGet => "$baseUrl/Menu/Get";

  // user endpoints
  static String get userGet => "$baseUrl/User/Get";

  // tour plan endpoints
  static String get tourPlanGet => "$baseUrl/PharmaCRM/TourPlan/Get";

  static String get tourPlanCalendarView =>
      "$baseUrl/PharmaCRM/TourPlan/GetCalendarViewData";

  static String get tourPlanSave => "$baseUrl/PharmaCRM/TourPlan/Save";

  static String get tourPlanUpdate => "$baseUrl/PharmaCRM/TourPlan/Update";

  static String get tourPlanAggregateCountSummary =>
      "$baseUrl/PharmaCRM/TourPlan/GetAggregateCountSummary";

  static String get tourPlanGetSummary =>
      "$baseUrl/PharmaCRM/TourPlan/GetSummary";

  static String get tourPlanDashboard =>
      "$baseUrl/PharmaCRM/TourPlan/TourPlanDashboard";

  static String get tourPlanGetManagerSummary =>
      "$baseUrl/PharmaCRM/TourPlan/GetManagerSummary";

  static String get tourPlanGetEmployeeListSummary =>
      "$baseUrl/PharmaCRM/TourPlan/GetEmployeeListSummary";

  // Tour Plan Action endpoints
  static String get tourPlanApproveSingle =>
      "$baseUrl/PharmaCRM/TourPlan/ApproveSingle";

  static String get tourPlanRejectSingle =>
      "$baseUrl/PharmaCRM/TourPlan/RejectSingle";

  static String get tourPlanBulkApprove =>
      "$baseUrl/PharmaCRM/TourPlan/BulkApprove";

  static String get tourPlanBulkSendBack =>
      "$baseUrl/PharmaCRM/TourPlan/BulkSendBack";

  static String get tourPlanGetMappedCustomersByEmployeeId =>
      "$baseUrl/PharmaCRM/TourPlan/GetMappedCustomersByEmployeeId";

  static String get tourPlanList => "$baseUrl/PharmaCRM/TourPlan/List";

  static String get tourPlanDelete => "$baseUrl/PharmaCRM/TourPlan/Delete";

  // Tour Plan Comment endpoints
  static String get tourPlanCommentSave =>
      "$baseUrl/PharmaCRM/TourPlanComment/Save";
  static String get tourPlanCommentGetList =>
      "$baseUrl/PharmaCRM/TourPlanComment/GetList";

  // DCR endpoints
  static String get dcrList => "$baseUrl/PharmaCRM/DCR/List";

  static String get dcrSave => "$baseUrl/PharmaCRM/DCR/Save";
  static String get dcrUpdate => "$baseUrl/PharmaCRM/DCR/Update";
  static String get dcrGet => "$baseUrl/PharmaCRM/DCR/Get";
  static String get dcrGetExpense => "$baseUrl/PharmaCRM/DCR/GetExpense";
  static String get dcrApproveSingle => "$baseUrl/PharmaCRM/DCR/ApproveSingle";
  static String get dcrSendBackSingle =>
      "$baseUrl/PharmaCRM/DCR/SendBackSingle";
  static String get dcrBulkApprove => "$baseUrl/PharmaCRM/DCR/BulkApprove";
  /// Bulk reject DCRs (Action: 8)
  static String get dcrBulkReject => "$baseUrl/PharmaCRM/DCR/BulkReject";
  static String get dcrValidateUser => "$baseUrl/PharmaCRM/DCR/ValidateUser";
  static String get dcrGetMapDetails =>
      "$baseUrl/PharmaCRM/DCR/GetDCRMapDetails";

  // Placeholder endpoint for creating a new customer from DCR Customer tab.
  // NOTE: The actual URL can be updated later without changing UI logic.
  static String get dcrCustomerSaveDummy =>
      "$baseUrl/PharmaCRM/DCR/SaveCustomerDummy";

  /// Medical Rep: save doctor/customer from DCR Customer tab
  static String get doctorSave => "$baseUrl/Doctor/Save";

  /// Sales Rep: save pharmacy/customer from DCR Customer tab
  static String get pharmacySave => "$baseUrl/Pharmacy/Save";
  // Service Report Save endpoint
  static String get serviceReportSave =>
      "$baseUrl/PharmaCRM/ServiceReport/Save";
  static String get serviceReportUpdate =>
      "$baseUrl/PharmaCRM/ServiceReport/Update";

  /// Service Report Get: pass DCR details Id to autofill service report when updating DCR.
  /// Only used when editing existing DCR (not when creating new).
  static String serviceReportGet(int dcrDetailId) =>
      "$baseUrl/PharmaCRM/ServiceReport/Get?Id=$dcrDetailId";

// Common endpoints for dropdowns
  static String get commonGetAuto => "$baseUrl/Common/GetAuto";
  static String get commonGetAutoBigInt => "$baseUrl/Common/GetAutoBigInt";
  static String get commonGetCatItemTax => "$baseUrl/Common/GetCatItemTax";
  static String get commonGetItemDetail => "$baseUrl/Common/GetItemDetail";

  // Tax Component endpoints
  static String get taxComponentGet => "$baseUrl/TaxComponent/Get";

  // Workflow endpoints
  static String get workflowGetAllActions =>
      "$baseUrl/WorkFlowMaster/GetAllActions";
  static String get workflowGetUserPagePrivileges =>
      "$baseUrl/WorkFlow/GetUserPagePrivileges";

  // Deviation endpoints
  static String get deviationList => "$baseUrl/PharmaCRM/Deviation/List";
  static String get deviationSave => "$baseUrl/PharmaCRM/Deviation/Save";
  static String get deviationUpdate =>
      "$baseUrl/PharmaCRM/Deviation/DeviationUpdate";
  static String get deviationApprove => "$baseUrl/PharmaCRM/Deviation/Approve";
  static String get deviationGetComments =>
      "$baseUrl/PharmaCRM/Deviation/GetCommentsList";
  static String get deviationAddComment =>
      "$baseUrl/PharmaCRM/Deviation/AddManagerComment";

  // Expense endpoints
  static String get expenseSave => "$baseUrl/PharmaCRM/DCR/SaveExpenses";
  static String get expenseGet => "$baseUrl/PharmaCRM/DCR/GetExpense";
  static String get expenseApproveSingle =>
      "$baseUrl/PharmaCRM/DCR/ApproveExpenseSingle";
  static String get expenseSendBackSingle =>
      "$baseUrl/PharmaCRM/DCR/SendBackExpenseSingle";
  static String get expenseBulkApprove =>
      "$baseUrl/PharmaCRM/DCR/BulkApproveExpense";
  static String get expenseBulkReject =>
      "$baseUrl/PharmaCRM/DCR/BulkRejectExpense";

  // PunchInOut endpoints
  static String get punchInOutSave => "$baseUrl/PunchInOut/Save";
  static String get punchInOutList => "$baseUrl/PunchInOut/List";

  // File Download endpoint
  // Base URL for file downloads (erpweb instead of erpapi)
  // Uses same IP/port as main API but with /erpweb/api instead of /erpapi/api
  static String get fileDownloadBaseUrl {
    // Extract base from main API URL and replace erpapi with erpweb
    return baseUrl.replaceAll('/erpapi/api', '/erpweb/api');
  }

  static String fileDownload(String path, String name) {
    // IMPORTANT: Use exact FilePath and FileName from backend response
    // Do NOT modify or rebuild the path - use it exactly as returned
    // Both path and name must be URL-encoded

    // Validate inputs
    if (path.isEmpty) {
      throw ArgumentError('FilePath cannot be empty');
    }
    if (name.isEmpty) {
      throw ArgumentError('FileName cannot be empty');
    }

    // URL encode both path and name parameters
    // Use Uri.encodeComponent to properly encode special characters
    final encodedPath = Uri.encodeComponent(path);
    final encodedName = Uri.encodeComponent(name);

    // Construct URL: https://[host]:[port]/erpweb/api/FileDownload/Download?path=<encodedPath>&name=<encodedName>
    final url =
        "$fileDownloadBaseUrl/FileDownload/Download?path=$encodedPath&name=$encodedName";

    return url;
  }

  // File Upload endpoints (erpweb instead of erpapi)
  // Base URL for file uploads (erpweb instead of erpapi)
  static String get fileUploadBaseUrl {
    // Extract base from main API URL and replace erpapi with erpweb
    return baseUrl.replaceAll('/erpapi/api', '/erpweb/api');
  }

  // Option 1: File Upload API (Recommended)
  // POST /erpweb/api/FilesUpload/upload?relativePath=Uploads/Attachments/DCR/Expenses
  static String fileUpload(
      {String relativePath = 'Uploads/Attachments/DCR/Expenses'}) {
    final encodedPath = Uri.encodeComponent(relativePath);
    return "$fileUploadBaseUrl/FilesUpload/upload?relativePath=$encodedPath";
  }

  // Option 2: Get Base URL API (Fallback)
  // GET /erpweb/api/FilesUpload/GetBaseUrl
  static String get fileUploadGetBaseUrl =>
      "$fileUploadBaseUrl/FilesUpload/GetBaseUrl";

  // ItemIssue endpoints
  static String get itemIssueList => "$baseUrl/ItemIssue/List";
  static String get itemIssueSave => "$baseUrl/ItemIssue/Save";
  static String itemIssueGet(int id) => "$baseUrl/ItemIssue/Get?Id=$id";

  // Sales endpoints
  static String get salesOrderList => "$baseUrl/SaleOrder/List";
  static String get salesOrderGet => "$baseUrl/SaleOrder/Get";
  static String get salesOrderSave => "$baseUrl/SaleOrder/Save";
  static String get salesOrderDelete => "$baseUrl/SaleOrder/Delete";
  static String get salesOrderTransactionCancel =>
      "$baseUrl/SaleOrder/TransactionCancel";
  static String get salesInvoiceCommonAuto =>
      "$baseUrl/SaleOrder/GetSalesInvoiceCommonAuto";
  static String get materialBonusList => "$baseUrl/Material/BonusList";
  static String get materialSlabList => "$baseUrl/Material/SlabList";
  static String get materialDiscountList => "$baseUrl/Material/DiscountList";
  static String get salesOrderBonusApprovalList =>
      "$baseUrl/SalesOrderItemApproval/List";
  static String get salesOrderBonusApprove =>
      "$baseUrl/SalesOrderItemApproval/Approve";
  static String get salesOrderBonusApprovedList =>
      "$baseUrl/SalesOrderItemApproval/ApprovedList";
}
