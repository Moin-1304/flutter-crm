class Endpoints {
  // Base URL - replace with your actual API base URL
  static const String baseUrl = 'https://your-api-base-url.com';
  
  // Connection timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // User endpoints
  static const String userGet = '/api/User/Get';

  // Tour Plan endpoints
  static const String tourPlanCalendarView = '/api/PharmaCRM/TourPlan/GetCalendarViewData';
}
