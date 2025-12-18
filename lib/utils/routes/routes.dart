import 'package:boilerplate/presentation/home/home.dart';
import 'package:boilerplate/presentation/login/login.dart';
import 'package:boilerplate/presentation/welcome/welcome_screen.dart';
import 'package:boilerplate/presentation/crm/crm_shell.dart';
import 'package:boilerplate/presentation/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import '../../presentation/sales/detail/sale_creation.dart';
import '../../presentation/sales/detail/sale_order_creation_screen.dart';
import '../../presentation/sales/sale_screen.dart';

class Routes {
  Routes._();

  //static variables
  static const String splash = '/splash';
  static const String login = '/login';
  static const String welcome = '/welcome';
  static const String home = '/post';
  // CRM base and subroutes
  static const String crm = '/crm';
  static const String crmDcr = '/crm/dcr';
  static const String crmExpenses = '/crm/expenses';
  static const String crmDeviation = '/crm/deviation';
  static const String crmTourPlan = '/crm/tour_plan';
  static const String crmContracts = '/crm/contracts';
  static const String punch = '/attendance/punch';
  static const String saleCreate = 'sells-create';
  static const String saleList = 'sells-list';

  static final routes = <String, WidgetBuilder>{
    splash: (BuildContext context) => const SplashScreen(),
    welcome: (BuildContext context) => const WelcomeScreen(),
    login: (BuildContext context) => const LoginScreen(),
    home: (BuildContext context) => const HomeScreen(),
    // CRM shell with optional initial tab based on route
    crm: (BuildContext context) => const CRMShell(),
    crmDcr: (BuildContext context) => const CRMShell(initialIndex: 0),
    crmDeviation: (BuildContext context) => const CRMShell(initialIndex: 1),
    crmExpenses: (BuildContext context) => const CRMShell(initialIndex: 3),
    crmTourPlan: (BuildContext context) => const CRMShell(initialIndex: 2),
    crmContracts: (BuildContext context) => const CRMShell(initialIndex: 3),
    saleCreate: (BuildContext context) =>  SaleCreationScreen(),
    saleList: (BuildContext context) =>  SaleOrderScreen(),
  };
}
