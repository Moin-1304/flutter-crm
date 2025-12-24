import 'dart:async';

import 'package:boilerplate/core/stores/error/error_store.dart';
import 'package:boilerplate/core/stores/form/form_store.dart';
import 'package:boilerplate/data/network/apis/user/lib/data/network/constants/endpoints.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/domain/repository/setting/setting_repository.dart';
import 'package:boilerplate/domain/usecase/post/get_post_usecase.dart';
import 'package:boilerplate/presentation/home/store/language/language_store.dart';
import 'package:boilerplate/presentation/home/store/theme/theme_store.dart';
import 'package:boilerplate/presentation/login/store/login_store.dart';
import 'package:boilerplate/presentation/post/store/post_store.dart';
import 'package:boilerplate/presentation/crm/tour_plan/store/tour_plan_store.dart';
import 'package:boilerplate/domain/repository/tour_plan/tour_plan_repository.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/presentation/user/store/user_validation_store.dart';
import 'package:boilerplate/data/network/apis/user/user_api_client.dart';
import 'package:boilerplate/presentation/dashboard/store/menu_store.dart';

import '../../../core/data/network/dio/dio_client.dart';
import '../../../core/data/network/dio/configs/dio_configs.dart';
import '../../../data/network/apis/login/login_api.dart';
import '../../../di/service_locator.dart';
import '../../../domain/repository/user/user_repository.dart';
import '../../../domain/usecase/login/login_usecase.dart';

class StoreModule {
  static Future<void> configureStoreModuleInjection() async {
    // factories:---------------------------------------------------------------
    getIt.registerFactory(() => ErrorStore());
    getIt.registerFactory(() => FormErrorStore());
    getIt.registerFactory(
      () => FormStore(getIt<FormErrorStore>(), getIt<ErrorStore>()),
    );

   //login repo
    getIt.registerSingleton<UserRepository>(
      UserRepository(
        getIt<LoginApi>(),
        getIt<SharedPreferenceHelper>(),
      ),
    );
    getIt.registerSingleton<LoginUseCase>(
      LoginUseCase(getIt<UserRepository>()),
    );

    getIt.registerSingleton<LogoutUseCase>(
      LogoutUseCase(getIt<UserRepository>()),
    );

    getIt.registerSingleton<GetUserUseCase>(
      GetUserUseCase(getIt<UserRepository>()),
    );
    getIt.registerSingleton<UserStore>(
      UserStore(
        getIt<LoginUseCase>(),
        getIt<LogoutUseCase>(),
        getIt<GetUserUseCase>(),
      ),
    );
    //end login


    getIt.registerSingleton<PostStore>(
      PostStore(
        getIt<GetPostUseCase>(),
        getIt<ErrorStore>(),
      ),
    );

    getIt.registerSingleton<TourPlanStore>(
      TourPlanStore(
        getIt<TourPlanRepository>(),
        getIt<ErrorStore>(),
      ),
    );

    getIt.registerSingleton<ThemeStore>(
      ThemeStore(
        getIt<SettingRepository>(),
        getIt<ErrorStore>(),
      ),
    );

    getIt.registerSingleton<LanguageStore>(
      LanguageStore(
        getIt<SettingRepository>(),
        getIt<ErrorStore>(),
      ),
    );

    // User Detail Store
    getIt.registerSingleton<UserDetailStore>(
      UserDetailStore(
        UserApiClient(
          DioClient(
            dioConfigs: DioConfigs(
              baseUrl: Endpoints.baseUrl,
              connectionTimeout: 30000,
              receiveTimeout: 15000,
            ),
          ),
        ),
        getIt<ErrorStore>(),
      ),
    );

    // Menu Store
    getIt.registerSingleton<MenuStore>(MenuStore());

    // User Validation Store
    getIt.registerSingleton<UserValidationStore>(UserValidationStore());
  }
}
