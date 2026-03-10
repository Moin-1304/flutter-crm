import 'dart:async';

import 'package:boilerplate/data/secure_storage/secure_storage_helper.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../di/service_locator.dart';

class LocalModule {
  static Future<void> configureLocalModuleInjection() async {
    // preference manager:------------------------------------------------------
    getIt.registerSingletonAsync<SharedPreferences>(
        SharedPreferences.getInstance);
    getIt.registerSingleton<SharedPreferenceHelper>(
      SharedPreferenceHelper(await getIt.getAsync<SharedPreferences>()),
    );
    // secure storage for API base URL and other sensitive data
    getIt.registerSingleton<SecureStorageHelper>(SecureStorageHelper());
  }
}
