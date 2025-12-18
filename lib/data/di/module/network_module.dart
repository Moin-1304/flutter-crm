import 'package:boilerplate/core/data/network/dio/configs/dio_configs.dart';
import 'package:boilerplate/core/data/network/dio/dio_client.dart';
import 'package:boilerplate/core/data/network/dio/interceptors/auth_interceptor.dart';
import 'package:boilerplate/core/data/network/dio/interceptors/logging_interceptor.dart';
import 'package:boilerplate/data/network/apis/login/login_api.dart';
import 'package:boilerplate/data/network/apis/menu/menu_api.dart';
import 'package:boilerplate/data/network/apis/posts/post_api.dart';
import 'package:boilerplate/data/network/apis/dcr/dcr_api.dart';
import 'package:boilerplate/data/network/apis/deviation/deviation_api.dart';
import 'package:boilerplate/data/network/apis/common/common_api.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api.dart';
import 'package:boilerplate/data/network/apis/attendance/punch_in_out_api.dart';
import 'package:boilerplate/data/network/constants/endpoints.dart';
import 'package:boilerplate/data/network/interceptors/error_interceptor.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:event_bus/event_bus.dart';

import '../../../di/service_locator.dart';

class NetworkModule {
  static Future<void> configureNetworkModuleInjection() async {
    // event bus
    getIt.registerSingleton<EventBus>(EventBus());

    // interceptors
    getIt.registerSingleton<LoggingInterceptor>(LoggingInterceptor());
    getIt.registerSingleton<ErrorInterceptor>(ErrorInterceptor(getIt()));
    getIt.registerSingleton<AuthInterceptor>(
      AuthInterceptor(
        accessToken: () async =>
        await getIt<SharedPreferenceHelper>().authToken,
      ),
    );

    // Dio configs
    getIt.registerSingleton<DioConfigs>(
      const DioConfigs(
        baseUrl: Endpoints.baseUrl,
        connectionTimeout: Endpoints.connectionTimeout,
        receiveTimeout: Endpoints.receiveTimeout,
      ),
    );

    // Dio client (after interceptors and configs)
    getIt.registerSingleton<DioClient>(
      DioClient(dioConfigs: getIt<DioConfigs>())
        ..addInterceptors([
          getIt<AuthInterceptor>(),
          getIt<ErrorInterceptor>(),
          getIt<LoggingInterceptor>(),
        ]),
    );

    // APIs (after DioClient)
    getIt.registerSingleton<PostApi>(PostApi(getIt<DioClient>()));
    getIt.registerSingleton<LoginApi>(LoginApi(getIt<DioClient>()));
    getIt.registerSingleton<MenuApi>(MenuApi(getIt<DioClient>()));
    getIt.registerSingleton<DcrApi>(DcrApi(getIt<DioClient>()));
    getIt.registerSingleton<DeviationApi>(DeviationApi(getIt<DioClient>()));
    getIt.registerSingleton<CommonApi>(CommonApi(getIt<DioClient>()));
    getIt.registerSingleton<ExpenseApi>(ExpenseApi(getIt<DioClient>()));
    getIt.registerSingleton<PunchInOutApi>(PunchInOutApi(getIt<DioClient>()));
  }
}

