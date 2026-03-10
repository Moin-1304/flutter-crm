import 'package:boilerplate/data/di/module/local_module.dart';
import 'package:boilerplate/data/di/module/network_module.dart';
import 'package:boilerplate/data/di/module/repository_module.dart';
import 'package:boilerplate/data/network/constants/endpoints.dart';
import 'package:boilerplate/data/secure_storage/secure_storage_helper.dart';

import '../../../di/service_locator.dart';

class DataLayerInjection {
  static Future<void> configureDataLayerInjection() async {
    await LocalModule.configureLocalModuleInjection();
    // Load API base URL from secure storage and apply so all API calls use it
    final baseUrl = await getIt<SecureStorageHelper>().getApiBaseUrl();
    if (baseUrl != null && baseUrl.isNotEmpty) {
      Endpoints.baseUrl = baseUrl;
    }
    await NetworkModule.configureNetworkModuleInjection();
    await RepositoryModule.configureRepositoryModuleInjection();
  }
}
