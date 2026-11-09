import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/app_info.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Needed before any await in main(): plugins (Firebase here) talk to the
  // platform, and that channel only exists once the binding is up.
  WidgetsFlutterBinding.ensureInitialized();

  // Nothing uses Firebase yet. It's initialised now so that a broken
  // flutterfire config fails today, on an almost empty app, rather than
  // tomorrow in the middle of the login work.
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
      theme: AppTheme.light(),
      home: const SplashScreen(),
    );
  }
}