import 'package:boilerplate/constants/app_theme.dart';
import 'package:boilerplate/constants/strings.dart';
import 'package:boilerplate/presentation/home/store/language/language_store.dart';
import 'package:boilerplate/presentation/home/store/theme/theme_store.dart';
import 'package:boilerplate/presentation/login/store/login_store.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/data/network/interceptors/error_interceptor.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/utils/locale/app_localization.dart';
import 'package:boilerplate/utils/routes/routes.dart';
import 'package:event_bus/event_bus.dart';
import 'package:boilerplate/presentation/sales/detail/sale_order_view_screen.dart';
import 'package:boilerplate/presentation/sales/detail/sale_creation.dart';
import 'package:boilerplate/domain/entity/sales/sales_api_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../di/service_locator.dart';

class MyApp extends StatefulWidget {
  MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  // Create your store as a final variable in a base Widget. This works better
  // with Hot Reload than creating it directly in the `build` function.
  final ThemeStore _themeStore = getIt<ThemeStore>();
  final LanguageStore _languageStore = getIt<LanguageStore>();
  final UserStore _userStore = getIt<UserStore>();
  final UserDetailStore _userDetailStore = getIt<UserDetailStore>();
  final EventBus _eventBus = getIt<EventBus>();
  
  @override
  void initState() {
    super.initState();
    _eventBus.on<UnauthorizedEvent>().listen((event) {
      _handleUnauthorized();
    });
  }

  void _handleUnauthorized() async {
    final sharedPrefHelper = getIt<SharedPreferenceHelper>();
    // Check both the store state and the persistent flag
    final bool wasLoggedIn = _userStore.isUserLoggedIn;
    
    // 1. Clear user data from stores
    _userStore.logout();
    _userDetailStore.clearUserData();
    
    // 2. Clear user data from shared preferences
    await sharedPrefHelper.clearUser();

    // 3. Navigate to login screen and clear backstack
    Routes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      Routes.login,
      (Route<dynamic> route) => false,
    );
    
    // 4. Show a message to the user ONLY if they were previously logged in
    if (wasLoggedIn) {
      ScaffoldMessenger.of(Routes.navigatorKey.currentContext!).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please login again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: Routes.navigatorKey,
          title: Strings.appName,
          theme: _themeStore.darkMode
              ? AppThemeData.darkThemeData
              : AppThemeData.lightThemeData,
          // Filter out saleCreate and saleView from routes map - they need arguments
          // so they're handled in onGenerateRoute instead
          routes: Map.fromEntries(
            Routes.routes.entries.where((entry) => 
              entry.key != Routes.saleCreate && entry.key != Routes.saleView
            )
          ),
          onGenerateRoute: (settings) {
            // Handle routes with arguments - check these FIRST before falling back to routes map
            if (settings.name == Routes.saleView) {
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (context) => SaleOrderViewScreen(
                  orderId: args?['orderId'] as String?,
                  orderData: args?['orderData'] as SalesOrderApiItem?,
                ),
              );
            }
            if (settings.name == Routes.saleCreate) {
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (context) => SaleCreationScreen(
                  orderId: args?['orderId'] as String?,
                  orderData: args?['orderData'] as SalesOrderApiItem?,
                ),
              );
            }
            // For other routes, use the routes map
            final builder = Routes.routes[settings.name];
            if (builder != null) {
              return MaterialPageRoute(builder: builder, settings: settings);
            }
            return null;
          },
          initialRoute: Routes.splash, // Always start with splash screen
          locale: Locale(_languageStore.locale),
          supportedLocales: _languageStore.supportedLanguages
              .map((language) => Locale(language.locale, language.code))
              .toList(),
          localizationsDelegates: [
            // A class which loads the translations from JSON files
            AppLocalizations.delegate,
            // Built-in localization of basic text for Material widgets
            GlobalMaterialLocalizations.delegate,
            // Built-in localization for text direction LTR/RTL
            GlobalWidgetsLocalizations.delegate,
            // Built-in localization of basic text for Cupertino widgets
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}
