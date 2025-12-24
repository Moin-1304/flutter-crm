class Endpoints {
  Endpoints._();

  // base url
  static const String baseUrl = "https://103.141.54.146:1445/erpapi/api";

  // receiveTimeout
  static const int receiveTimeout = 15000;

  // connectTimeout
  static const int connectionTimeout = 30000;

  // booking endpoints
  static const String getPosts = "$baseUrl/posts";

  //login endpoints
  static const String login = "$baseUrl/Login/Login";

  // menu endpoints
  static const String menuGet = "$baseUrl/Menu/Get";

  // user endpoints
  static const String userGet = "$baseUrl/User/Get";

  // tour plan endpoints
  static const String tourPlanGet = "$baseUrl/PharmaCRM/TourPlan/Get";

  static String tourPlanCalendarView="$baseUrl/PharmaCRM/TourPlan/GetCalendarViewData";

  static const String tourPlanSave = "$baseUrl/PharmaCRM/TourPlan/Save";

  static const String tourPlanUpdate = "$baseUrl/PharmaCRM/TourPlan/Update";

  static const String tourPlanAggregateCountSummary = "$baseUrl/PharmaCRM/TourPlan/GetAggregateCountSummary";

  static const String tourPlanGetSummary = "$baseUrl/PharmaCRM/TourPlan/GetSummary";

  static const String tourPlanGetManagerSummary = "$baseUrl/PharmaCRM/TourPlan/GetManagerSummary";

  static const String tourPlanGetEmployeeListSummary = "$baseUrl/PharmaCRM/TourPlan/GetEmployeeListSummary";

  // Tour Plan Action endpoints
  static const String tourPlanApproveSingle = "$baseUrl/PharmaCRM/TourPlan/ApproveSingle";
  
  static const String tourPlanRejectSingle = "$baseUrl/PharmaCRM/TourPlan/RejectSingle";
  
  static const String tourPlanBulkApprove = "$baseUrl/PharmaCRM/TourPlan/BulkApprove";
  
  static const String tourPlanBulkSendBack = "$baseUrl/PharmaCRM/TourPlan/BulkSendBack";

  static const String tourPlanGetMappedCustomersByEmployeeId = "$baseUrl/PharmaCRM/TourPlan/GetMappedCustomersByEmployeeId";

  static const String tourPlanList = "$baseUrl/PharmaCRM/TourPlan/List";

  static const String tourPlanDelete = "$baseUrl/PharmaCRM/TourPlan/Delete";

  // Tour Plan Comment endpoints
  static const String tourPlanCommentSave = "$baseUrl/PharmaCRM/TourPlanComment/Save";
  static const String tourPlanCommentGetList = "$baseUrl/PharmaCRM/TourPlanComment/GetList";

  // DCR endpoints
  static const String dcrList = "$baseUrl/PharmaCRM/DCR/List";

  static const String dcrSave = "$baseUrl/PharmaCRM/DCR/Save";
  static const String dcrUpdate = "$baseUrl/PharmaCRM/DCR/Update";
  static const String dcrGet = "$baseUrl/PharmaCRM/DCR/Get";
  static const String dcrGetExpense = "$baseUrl/PharmaCRM/DCR/GetExpense";
  static const String dcrApproveSingle = "$baseUrl/PharmaCRM/DCR/ApproveSingle";
  static const String dcrSendBackSingle = "$baseUrl/PharmaCRM/DCR/SendBackSingle";
  static const String dcrBulkApprove = "$baseUrl/PharmaCRM/DCR/BulkApprove";
  static const String dcrBulkSendBack = "$baseUrl/PharmaCRM/DCR/BulkReject";

// Common endpoints for dropdowns
  static const String commonGetAuto = "$baseUrl/Common/GetAuto";

  // Deviation endpoints
  static const String deviationList = "$baseUrl/PharmaCRM/Deviation/List";
  static const String deviationSave = "$baseUrl/PharmaCRM/Deviation/Save";
  static const String deviationUpdate = "$baseUrl/PharmaCRM/Deviation/DeviationUpdate";
  static const String deviationApprove = "$baseUrl/PharmaCRM/Deviation/Approve";
  static const String deviationGetComments = "$baseUrl/PharmaCRM/Deviation/GetCommentsList";
  static const String deviationAddComment = "$baseUrl/PharmaCRM/Deviation/AddManagerComment";

  // Expense endpoints
  static const String expenseSave = "$baseUrl/PharmaCRM/DCR/SaveExpenses";
  static const String expenseGet = "$baseUrl/PharmaCRM/DCR/GetExpense";
  static const String expenseApproveSingle = "$baseUrl/PharmaCRM/DCR/ApproveExpenseSingle";
  static const String expenseSendBackSingle = "$baseUrl/PharmaCRM/DCR/SendBackExpenseSingle";
  static const String expenseBulkApprove = "$baseUrl/PharmaCRM/DCR/BulkApproveExpense";
  static const String expenseBulkReject = "$baseUrl/PharmaCRM/DCR/BulkRejectExpense";

  // PunchInOut endpoints
  static const String punchInOutSave = "$baseUrl/PunchInOut/Save";
  static const String punchInOutList = "$baseUrl/PunchInOut/List";

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
    final url = "$fileDownloadBaseUrl/FileDownload/Download?path=$encodedPath&name=$encodedName";
    
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
  static String fileUpload({String relativePath = 'Uploads/Attachments/DCR/Expenses'}) {
    final encodedPath = Uri.encodeComponent(relativePath);
    return "$fileUploadBaseUrl/FilesUpload/upload?relativePath=$encodedPath";
  }
  
  // Option 2: Get Base URL API (Fallback)
  // GET /erpweb/api/FilesUpload/GetBaseUrl
  static String get fileUploadGetBaseUrl => "$fileUploadBaseUrl/FilesUpload/GetBaseUrl";

  // ItemIssue endpoints
  static const String itemIssueList = "$baseUrl/ItemIssue/List";
}
