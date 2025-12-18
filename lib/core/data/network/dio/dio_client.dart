import 'package:dio/dio.dart';
import 'configs/dio_configs.dart';

// Conditional import: use ssl_config_io.dart for native platforms, ssl_config_web.dart for web
import 'ssl_config_io.dart' if (dart.library.html) 'ssl_config_web.dart';

class DioClient {
  final DioConfigs dioConfigs;
  final Dio _dio;

  DioClient({required this.dioConfigs})
      : _dio = Dio()
          ..options.baseUrl = dioConfigs.baseUrl
          ..options.connectTimeout =
              Duration(milliseconds: dioConfigs.connectionTimeout)
          ..options.receiveTimeout =
              Duration(milliseconds: dioConfigs.receiveTimeout) {
    configureSSL(_dio);
  }

  Dio get dio => _dio;

  Dio addInterceptors(Iterable<Interceptor> interceptors) {
    return _dio..interceptors.addAll(interceptors);
  }
}
