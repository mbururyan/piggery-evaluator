import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

import '../constants/app_info.dart';
import '../screens/due_visits_screen.dart';
import '../screens/login_screen.dart';
import '../screens/projections_screen.dart';
import '../services/auth_service.dart';
import '../services/due_visits.dart';
import '../services/session_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';
import 'role_pill.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    // Read the pending count right now, synchronously: no stream to wait on.
    final pending = SyncService.instance.status.value.count;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(pending == 0 ? 'Log out?' : 'Unsynced work on this phone',
            style: const TextStyle(fontSize: 17)),
        content: Text(
          pending == 0
              ? "You'll need your username and password to log back in."
              // Why this is a real warning, not a formality: queued writes
              // are sent with whoever is signed in when signal returns. After
              // a logout that's nobody (or another EO), so the rules reject
              // them and the work is lost.
              : '$pending ${pending == 1 ? 'item hasn\'t' : 'items haven\'t'} '
                  'reached the server yet. If you log out now, '
                  '${pending == 1 ? 'it' : 'they'} may be lost.\n\n'
                  'Get signal and wait for the Home strip to turn green first.',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        actions: pending == 0
            ? [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: const Text('Log out',
                      style: TextStyle(color: AppColors.alert)),
                ),
              ]
            : [
                // The safe choice is the prominent one.
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: const Text('Log out anyway',
                      style: TextStyle(color: AppColors.alert)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 40)),
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('Stay logged in'),
                ),
              ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await AuthService.instance.signOut();
    SessionService.instance.clear(); // also stops the sync listeners
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Bottom sheet listing everything still waiting to reach the server.
  /// The full Sync center screen can come later; this answers the one
  /// question an EO actually has: "has my work gone?"
  void _showSyncSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ValueListenableBuilder<SyncStatus>(
        valueListenable: SyncService.instance.status,
        builder: (_, status, __) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sync center',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(status.offline ? 'Offline' : 'Online',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 14),
              if (status.allSynced)
                const Row(children: [
                  Icon(Icons.cloud_done_outlined,
                      size: 18, color: AppColors.green),
                  SizedBox(width: 8),
                  Text('Everything has reached the server',
                      style: TextStyle(fontSize: 13)),
                ])
              else ...[
                for (final p in status.pending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      const Icon(Icons.schedule,
                          size: 16, color: AppColors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(p.label,
                              style: const TextStyle(fontSize: 13))),
                    ]),
                  ),
                const SizedBox(height: 6),
                const Text(
                  'Saved on this phone. Syncs automatically when back online.',
                  style: TextStyle(fontSize: 12, color: AppColors.green),
                ),
              ],
            ],
          ),
        ),
      ),
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
                  const AppLogo(size: 44),
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

            // Sync center row, with a live amber count while work is waiting.
            ValueListenableBuilder<SyncStatus>(
              valueListenable: SyncService.instance.status,
              builder: (context, status, _) => ListTile(
                leading:
                    const Icon(Icons.sync, size: 20, color: AppColors.muted),
                title: const Text('Sync center',
                    style: TextStyle(fontSize: 14, color: AppColors.ink)),
                trailing: status.allSynced
                    ? null
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.amberTint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('${status.count} pending',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.amberText)),
                      ),
                onTap: () {
                  Navigator.of(context).pop(); // close the drawer first
                  _showSyncSheet(context);
                },
              ),
            ),
            // Due for a visit, with an orange count when anyone is
            // overdue (the same number that puts the dot on ☰).
            ValueListenableBuilder<DueVisits?>(
              valueListenable: DueVisitsService.instance.due,
              builder: (context, due, _) {
                final n = due?.overdue.length ?? 0;
                return ListTile(
                  leading: const Icon(Icons.event_repeat_outlined,
                      size: 20, color: AppColors.muted),
                  title: const Text('Due for a visit',
                      style: TextStyle(fontSize: 14, color: AppColors.ink)),
                  trailing: n == 0
                      ? null
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.alertTint,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('$n',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.alert)),
                        ),
                  onTap: () {
                    Navigator.of(context).pop(); // close the drawer first
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DueVisitsScreen()));
                  },
                );
              },
            ),
            _item(
              context,
              icon: Icons.trending_up,
              label: 'Projections',
              onTap: () {
                Navigator.of(context).pop(); // close the drawer first
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProjectionsScreen()));
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
                  applicationIcon: const AppLogo(size: 48),
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
            // Long-press the version: sends a harmless test report, to
            // check crash reporting works on a release build (Crashlytics
            // is off in debug, so it says so instead). Hidden on purpose:
            // EOs never need it.
            GestureDetector(
              onLongPress: () {
                final c = FirebaseCrashlytics.instance;
                final on = c.isCrashlyticsCollectionEnabled;
                if (on) {
                  c.recordError(Exception('Test report from the drawer'),
                      StackTrace.current, reason: 'manual test', fatal: false);
                }
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(on
                      ? 'Test report sent'
                      : 'Crash reporting is off in debug builds'),
                ));
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 16, bottom: 10, right: 16, top: 4),
                child: Text('${AppInfo.name} v${AppInfo.version}',
                    style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}