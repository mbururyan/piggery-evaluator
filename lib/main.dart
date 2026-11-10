import 'package:firebase_core/firebase_core.dart';
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

  // Nothing uses Firebase yet. It's initialised now so that a broken
  // flutterfire config fails today, on an almost empty app, rather than
  // in the middle of the login work.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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