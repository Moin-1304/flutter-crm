import 'dart:async';

import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/presentation/my_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('Uncaught async error: $error\n$stack');
    }
    return true;
  };

  await runZonedGuarded(() async {
    // Prevent runtime HTTP font fetches (red screens on restricted/offline networks).
    GoogleFonts.config.allowRuntimeFetching = false;
    await setPreferredOrientations();
    await ServiceLocator.configureDependencies();
    runApp(MyApp());
  }, (Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('Zone error: $error\n$stack');
    }
  });
}

Future<void> setPreferredOrientations() {
  return SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);
}
