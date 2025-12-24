import 'dart:async';

import 'package:boilerplate/data/network/apis/posts/post_api.dart';
import 'package:boilerplate/data/network/apis/menu/menu_api.dart';
import 'package:boilerplate/data/network/apis/expense/expense_api.dart';
import 'package:boilerplate/data/repository/post/post_repository_impl.dart';
import 'package:boilerplate/data/repository/menu/menu_repository_impl.dart';
import 'package:boilerplate/data/repository/setting/setting_repository_impl.dart';
import 'package:boilerplate/data/repository/tour_plan/tour_plan_repository_impl.dart';
import 'package:boilerplate/data/repository/dcr/dcr_repository_impl.dart';
import 'package:boilerplate/data/repository/expense/expense_repository_impl.dart';
import 'package:boilerplate/data/repository/deviation/deviation_repository_impl.dart';
import 'package:boilerplate/data/repository/common/common_repository_impl.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/domain/repository/post/post_repository.dart';
import 'package:boilerplate/domain/repository/menu/menu_repository.dart';
import 'package:boilerplate/domain/repository/setting/setting_repository.dart';
import 'package:boilerplate/domain/repository/tour_plan/tour_plan_repository.dart';
import 'package:boilerplate/domain/repository/dcr/dcr_repository.dart';
import 'package:boilerplate/domain/repository/expense/expense_repository.dart';
import 'package:boilerplate/domain/repository/deviation/deviation_repository.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/repository/attendance/punch_in_out_repository.dart';
import 'package:boilerplate/data/repository/attendance/punch_in_out_repository_impl.dart';
import 'package:boilerplate/domain/repository/item_issue/item_issue_repository.dart';
import 'package:boilerplate/data/repository/item_issue/item_issue_repository_impl.dart';

import '../../../di/service_locator.dart';
import '../../network/apis/attendance/punch_in_out_api.dart';

class RepositoryModule {
  static Future<void> configureRepositoryModuleInjection() async {
    // repository:--------------------------------------------------------------
    getIt.registerSingleton<SettingRepository>(SettingRepositoryImpl(
      getIt<SharedPreferenceHelper>(),
    ));

    getIt.registerSingleton<PostRepository>(PostRepositoryImpl(
      getIt<PostApi>(),
    ));

    getIt.registerSingleton<MenuRepository>(MenuRepositoryImpl(
      getIt<MenuApi>(),
    ));

    // Tour plan in-memory repository (replace with API-backed impl later)
    getIt.registerSingleton<TourPlanRepository>(TourPlanRepositoryImpl(
      sharedPreferenceHelper: getIt<SharedPreferenceHelper>(),
    ));

    // DCR & Expense in-memory repositories
    getIt.registerSingleton<DcrRepository>(DcrRepositoryImpl());
    getIt.registerSingleton<ExpenseRepository>(ExpenseRepositoryImpl(getIt<ExpenseApi>()));
    
    // Deviation repository
    getIt.registerSingleton<DeviationRepository>(DeviationRepositoryImpl());
    getIt.registerSingleton<CommonRepository>(CommonRepositoryImpl());
    
    // PunchInOut repository
    getIt.registerSingleton<PunchInOutRepository>(PunchInOutRepositoryImpl(
      getIt<PunchInOutApi>(),
    ));
    
    // ItemIssue repository
    getIt.registerSingleton<ItemIssueRepository>(ItemIssueRepositoryImpl());
  }
}
