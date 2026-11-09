import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_info.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/g1_mark.dart';
import '../shell/home_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    // 2a placeholder: a fixed pause so the splash can be seen and checked.
    // In 2b this becomes "is someone signed in?" → Login or Home, and the
    // pause goes away.
    await Future.delayed(const Duration(milliseconds: 1200));

    // The user could have left the app during the pause; don't navigate on
    // a screen that's already gone.
    if (!mounted) return;

    // pushReplacement, not push: Back from Home should leave the app, not
    // return to the splash.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // There's no AppBar here to set the status bar, so set it directly:
    // dark icons on the white page.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        // White, not AppColors.page, so the logo's white tile blends in.
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const G1Mark(size: 92),
                      const SizedBox(height: 16),
                      const Text(
                        AppInfo.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        AppInfo.tagline,
                        style: TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                      const SizedBox(height: 24),
                      // Same sliding bar as the web boot loader, so the two
                      // feel like one app.
                      SizedBox(
                        width: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: const LinearProgressIndicator(
                            minHeight: 4,
                            color: AppColors.red,
                            backgroundColor: AppColors.line,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'v${AppInfo.version}',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}