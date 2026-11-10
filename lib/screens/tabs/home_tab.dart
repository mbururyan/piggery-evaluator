import 'package:flutter/material.dart';

import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbars.dart';
import '../../widgets/role_pill.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Straight from the in-memory session: no async, no spinner, works
    // offline.
    final profile = SessionService.instance.profile;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Header: greeting + name, role pill, ☰ (RE's layout) ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting(DateTime.now())}, ${profile.fullName}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RolePill(label: profile.roleLabel),
                  ],
                ),
              ),
              // Builder gives this button a context *below* the Scaffold,
              // which Scaffold.of() needs to find the drawer. Home's own
              // context sits above it and would fail.
              Builder(
                builder: (ctx) => IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu, color: AppColors.muted),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // --- Sync strip slots in here (2d) ---

          // --- Unfinished visits slot in here (Phase 2) ---
          // Above the hero, as in RE: finishing what's open outranks
          // starting something new.

          // --- Primary action ---
          _HeroCard(
            onTap: () =>
                showInfoSnack(context, 'Farm visits arrive in Phase 2'),
          ),
          const SizedBox(height: 10),

          // --- Secondary action ---
          // Registering is a one-off, so it sits below the recurring job,
          // but it lives on Home because a new EO looks here first.
          _RegisterCard(
            onTap: () => showInfoSnack(
                context, 'Farmer registration arrives in Phase 1'),
          ),

          // --- Last visit / Follow-ups due slot in below (Phases 2–3) ---
        ],
      ),
    );
  }

  static String _greeting(DateTime t) {
    if (t.hour < 12) return 'Good morning';
    if (t.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// "Start a farm visit": the red gradient hero card.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    // Ink, not Container, paints the gradient. RE wrapped a Container in an
    // InkWell, which draws the tap ripple *underneath* the gradient, so you
    // never see it. Ink paints the gradient onto the Material, and the
    // ripple then shows on top.
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.red, AppColors.redDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: radius,
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              children: [
                Icon(Icons.post_add, size: 28, color: AppColors.white),
                SizedBox(height: 6),
                Text(
                  'Start a farm visit',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'works offline · syncs later',
                  style: TextStyle(fontSize: 11, color: AppColors.redTint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Register a new farmer": white card, red outline, icon in a tinted circle.
class _RegisterCard extends StatelessWidget {
  const _RegisterCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppColors.red, width: 0.8),
    );

    return Material(
      color: AppColors.white,
      shape: shape,
      child: InkWell(
        // customBorder keeps the ripple inside the rounded corners.
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.redTint,
                ),
                child: const Icon(Icons.person_add_alt_1_outlined,
                    size: 19, color: AppColors.red),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Register a new farmer',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Visit right away · office assigns the PF',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}