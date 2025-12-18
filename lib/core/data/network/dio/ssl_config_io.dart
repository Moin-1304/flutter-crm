import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:io';

void configureSSL(Dio dio) {
  (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
    final client = HttpClient();
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      // Bypass SSL certificate verification
      return true;
    };
    return client;
  };
}



