import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/due_visits.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/farmer_card.dart';

/// "Due for a visit", from the drawer: the EO's farmers last visited more
/// than four months ago, longest ago first, then (folded away) those with
/// no visit on record yet.
///
/// Replaces the follow-ups list planned for Phase 3: the follow-up date
/// left the form on 23 Nov, so "due" is worked out from the last visit.
class DueVisitsScreen extends StatelessWidget {
  const DueVisitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.page,
        foregroundColor: AppColors.ink,
        titleSpacing: 0,
        title: const Text('Due for a visit',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ValueListenableBuilder<DueVisits?>(
        valueListenable: DueVisitsService.instance.due,
        builder: (context, due, _) {
          if (due == null) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            children: [
              Text(
                'Your farmers last visited more than ${due.months} months ago, '
                'longest ago first.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              if (due.overdue.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'Nobody is overdue',
                    message: 'Every farmer with a visit on record was seen recently.',
                  ),
                )
              else
                for (final f in due.overdue)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FarmerCard(farmer: f, currentUid: uid),
                  ),
              if (due.never.isNotEmpty) ...[
                const SizedBox(height: 8),
                _NeverVisited(count: due.never.length, children: [
                  for (final f in due.never)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FarmerCard(farmer: f, currentUid: uid),
                    ),
                ]),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Folded by default: a long list the EO opens on purpose, not a wall
/// under the overdue farmers.
class _NeverVisited extends StatelessWidget {
  const _NeverVisited({required this.count, required this.children});
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // copyWith, not a fresh ThemeData: a bare one resets the app theme.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: EdgeInsets.zero,
        iconColor: AppColors.muted,
        collapsedIconColor: AppColors.muted,
        title: Text('No visit on record ($count)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: const Text(
          'Paper visits show here until they\'re imported in December.',
          style: TextStyle(fontSize: 11.5, color: AppColors.muted),
        ),
        children: children,
      ),
    );
  }
}