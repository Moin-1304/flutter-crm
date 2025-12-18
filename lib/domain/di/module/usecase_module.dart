import 'dart:async';

import 'package:boilerplate/domain/repository/post/post_repository.dart';
import 'package:boilerplate/domain/repository/menu/menu_repository.dart';
import 'package:boilerplate/domain/repository/attendance/punch_in_out_repository.dart';
import 'package:boilerplate/domain/usecase/post/get_post_usecase.dart';
import 'package:boilerplate/domain/usecase/menu/get_menu_usecase.dart';
import 'package:boilerplate/domain/usecase/attendance/punch_in_out_usecase.dart';

import '../../../di/service_locator.dart';

class UseCaseModule {
  static Future<void> configureUseCaseModuleInjection() async {

    // post:--------------------------------------------------------------------
    getIt.registerSingleton<GetPostUseCase>(
      GetPostUseCase(getIt<PostRepository>()),
    );
    getIt.registerSingleton<GetMenuUseCase>(
      GetMenuUseCase(getIt<MenuRepository>()),
    );
    
    // PunchInOut use case
    getIt.registerSingleton<PunchInOutUseCase>(
      PunchInOutUseCase(getIt<PunchInOutRepository>()),
    );
    
    // Removed DB-related post use cases
  }
}
