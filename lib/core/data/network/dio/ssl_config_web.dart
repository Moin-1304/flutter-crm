import 'package:dio/dio.dart';

void configureSSL(Dio dio) {
  // No SSL configuration needed for web platform
  // Web uses BrowserHttpClientAdapter which doesn't support custom SSL configuration
}



