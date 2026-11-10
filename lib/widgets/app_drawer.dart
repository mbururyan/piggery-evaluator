import 'package:flutter/material.dart';

import '../constants/app_info.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/snackbars.dart';
import 'g1_mark.dart';
import 'role_pill.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?', style: TextStyle(fontSize: 17)),
        // 2d makes this warn when unsynced work is still on the phone.
        content: const Text(
          "You'll need your username and password to log back in.",
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Log out',
                style: TextStyle(color: AppColors.alert)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await AuthService.instance.signOut();
    SessionService.instance.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// A drawer row. [onTap] null = not built yet: greyed with a "later" tag.
  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return ListTile(
      leading: Icon(icon,
          size: 20, color: enabled ? AppColors.muted : AppColors.inputBorder),
      title: Text(label,
          style: TextStyle(
              fontSize: 14,
              color: enabled ? AppColors.ink : AppColors.inputBorder)),
      trailing: enabled
          ? null
          : const Text('later',
              style: TextStyle(fontSize: 11, color: AppColors.inputBorder)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = SessionService.instance.profile;

    return Drawer(
      backgroundColor: AppColors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Profile card, read from the in-memory session: no
            //     Firestore read every time the drawer opens ---
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // Page tone, so the card reads as its own block on the
                // white drawer.
                color: AppColors.page,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const G1Mark(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (profile.username.isNotEmpty)
                              '@${profile.username}',
                            if (profile.phone.isNotEmpty) profile.phone,
                          ].join(' · '),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted),
                        ),
                        const SizedBox(height: 6),
                        RolePill(label: profile.roleLabel, small: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _item(
              context,
              icon: Icons.sync,
              label: 'Sync center',
              // Gets a live pending count in 2d.
              onTap: () {
                Navigator.of(context).pop(); // close the drawer first
                showInfoSnack(context, 'Sync center arrives in 2d');
              },
            ),
            _item(context,
                icon: Icons.description_outlined, label: 'My reports'),
            _item(
              context,
              icon: Icons.info_outline,
              label: 'About',
              onTap: () {
                Navigator.of(context).pop();
                // Flutter's built-in about box: also lists open-source
                // licences for free.
                showAboutDialog(
                  context: context,
                  applicationName: AppInfo.name,
                  applicationVersion: 'v${AppInfo.version}',
                  applicationIcon: const G1Mark(size: 48),
                  applicationLegalese: AppInfo.tagline,
                );
              },
            ),

            const Spacer(),

            // --- Logout: burnt orange because it's destructive ---
            const Divider(height: 1, color: AppColors.line),
            ListTile(
              leading:
                  const Icon(Icons.logout, size: 20, color: AppColors.alert),
              title: const Text('Log out',
                  style: TextStyle(fontSize: 14, color: AppColors.alert)),
              onTap: () => _confirmLogout(context),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 10),
              child: Text('${AppInfo.name} v${AppInfo.version}',
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ),
          ],
        ),
      ),
    );
  }
}