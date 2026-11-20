import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'constants/app_info.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Needed before any await in main(): plugins (Firebase here) talk to the
  // platform, and that channel only exists once the binding is up.
  WidgetsFlutterBinding.ensureInitialized();

  // Every screen is light and none has an app bar, so no widget sets the
  // system bars per screen. Set them once here: dark icons on a see-through
  // status bar, and a white system nav bar to match the bottom nav.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Android
    statusBarBrightness: Brightness.light, // iOS (named the opposite way)
    systemNavigationBarColor: AppColors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Crash reports, so a failure on an EO's phone in the field reaches us
  // with the line that broke, instead of "it closed" a week later.
  // Off in debug: our own mistakes while building would bury the real ones.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  // Errors inside Flutter (a widget throwing while building).
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  // Everything else that escapes (a failed await nobody caught).
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const PiggeryEvaluatorApp());
}

class PiggeryEvaluatorApp extends StatelessWidget {
  const PiggeryEvaluatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashScreen(),
    );
  }
}