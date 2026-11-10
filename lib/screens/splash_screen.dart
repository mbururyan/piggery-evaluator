import 'package:flutter/material.dart';

import '../constants/app_info.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/g1_mark.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    // Held deliberately: long enough to read as branding rather than a
    // flash before the next screen.
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // Firebase Auth remembers the last sign-in on the phone, offline too.
    final user = AuthService.instance.currentUser;

    // A returning EO gets their cached profile loaded before Home, so
    // every write stamps the right name even with no signal.
    if (user != null) await SessionService.instance.load();
    if (!mounted) return;

    // pushReplacement, not push: Back from the next screen should leave
    // the app, not return to the splash.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => user != null ? const MainShell() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // White, not AppColors.page, so the logo's white tile blends in.
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const G1Mark(size: 108),
            const SizedBox(height: 20),
            const Text(
              AppInfo.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              AppInfo.tagline,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 36),
            // A sliding bar rather than RE's spinner, to match the web boot
            // loader, so mobile and web open the same way.
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: const LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: AppColors.line,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}