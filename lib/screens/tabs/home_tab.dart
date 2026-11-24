import 'package:flutter/material.dart';

import '../../models/visit.dart';
import '../../services/due_visits.dart';
import '../../services/session_service.dart';
import '../../services/visit_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/role_pill.dart';
import '../../widgets/sync_strip.dart';
import '../farmer_picker_screen.dart';
import '../register_farmer_screen.dart';
import '../visit_hub_screen.dart';

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
                builder: (ctx) => ValueListenableBuilder<DueVisits?>(
                  valueListenable: DueVisitsService.instance.due,
                  builder: (context, due, _) => IconButton(
                    tooltip: 'Menu',
                    // An orange dot when farmers are overdue for a visit:
                    // the reason to open the drawer. Farmers with no visit
                    // on record don't count, or it would always be on.
                    icon: Badge(
                      isLabelVisible: (due?.overdue.length ?? 0) > 0,
                      smallSize: 9,
                      backgroundColor: AppColors.alert,
                      child: const Icon(Icons.menu, color: AppColors.muted),
                    ),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          const SyncStrip(),
          const SizedBox(height: 14),

          // --- Unfinished visits ---
          // Above the hero, as in RE: finishing what's open outranks
          // starting something new. Hidden entirely when there are none.
          const _Drafts(),

          // --- Primary action ---
          _HeroCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const FarmerPickerScreen())),
          ),
          const SizedBox(height: 10),

          // --- Secondary action ---
          // Registering is a one-off, so it sits below the recurring job,
          // but it lives on Home because a new EO looks here first.
          _RegisterCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const RegisterFarmerScreen())),
          ),

          // Follow-ups live in the drawer (Phase 3), to keep Home clear.
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

/// "Unfinished visits": this EO's drafts, newest first, each one tap from
/// the hub. Draws nothing at all when there are none.
class _Drafts extends StatefulWidget {
  const _Drafts();

  @override
  State<_Drafts> createState() => _DraftsState();
}

class _DraftsState extends State<_Drafts> {
  // Made once: a new stream per rebuild would re-open the listener.
  late final Stream<List<Visit>> _stream = VisitService.instance.myDrafts();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Visit>>(
      stream: _stream,
      builder: (context, snap) {
        final drafts = snap.data ?? const <Visit>[];
        if (drafts.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Unfinished visits',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 8),
            for (final v in drafts) ...[
              _DraftCard(visit: v),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.visit});
  final Visit visit;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.amber),
    );
    return Material(
      color: AppColors.white,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => VisitHubScreen(visitId: visit.id))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.amberTint),
              child: const Icon(Icons.schedule, size: 19, color: AppColors.amber),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.pfNumber == null
                        ? visit.farmerName
                        : '${visit.farmerName} · ${visit.pfNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${visit.startedCount} of 9 sections · '
                    'visit ${Formatters.relativeDate(visit.visitDate)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.amberText),
                  ),
                ],
              ),
            ),
            const Text('resume ›',
                style: TextStyle(fontSize: 12, color: AppColors.amberText)),
          ]),
        ),
      ),
    );
  }
}