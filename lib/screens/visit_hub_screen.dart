import 'package:flutter/material.dart';

import '../constants/visit_template.dart';
import '../models/visit.dart';
import '../services/visit_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/snackbars.dart';
import '../widgets/empty_state.dart';
import 'review_submit_screen.dart';
import 'sections/section_router.dart';

/// The spine of a visit: all ten sections, in any order, because a real
/// farm visit wanders (Ranch Evaluator's model). Nothing here holds
/// unsaved state: every section saves itself, so leaving loses nothing.
class VisitHubScreen extends StatelessWidget {
  const VisitHubScreen({super.key, required this.visitId});

  final String visitId;

  Future<void> _confirmDelete(BuildContext context, Visit visit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text('Delete this draft?', style: TextStyle(fontSize: 17)),
        content: Text(
          'Everything entered for ${visit.farmerName} on '
          '${Formatters.date(visit.visitDate)} will be removed.',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dCtx).pop(false),
              child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.alert)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    VisitService.instance.deleteDraft(visit.id);
    Navigator.of(context).pop();
    showInfoSnack(context, 'Draft deleted');
  }

  void _openSection(BuildContext context, Visit visit, VisitSection s) =>
      openSection(context, visit, s);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Visit?>(
      stream: VisitService.instance.watch(visitId),
      builder: (context, snap) {
        final visit = snap.data;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.page,
            foregroundColor: AppColors.ink,
            titleSpacing: 0,
            title: visit == null
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(visit.farmerName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(
                        '${visit.pfNumber ?? 'No PF'} · visit ${Formatters.date(visit.visitDate)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
            actions: [
              if (visit != null && visit.isDraft)
                PopupMenuButton<String>(
                  color: AppColors.white,
                  onSelected: (v) {
                    if (v == 'delete') _confirmDelete(context, visit);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete draft',
                          style: TextStyle(color: AppColors.alert)),
                    ),
                  ],
                ),
            ],
          ),
          body: SafeArea(child: _body(context, snap, visit)),
        );
      },
    );
  }

  Widget _body(BuildContext context, AsyncSnapshot<Visit?> snap, Visit? visit) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (visit == null) {
      return const EmptyState(
        icon: Icons.delete_outline,
        title: 'This visit no longer exists',
        message: 'It may have been deleted.',
      );
    }

    final done = visit.doneCount;
    final pct = visit.score.pct;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            children: [
              // --- Progress card ---
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.card,
                ),
                child: Column(children: [
                  Row(children: [
                    Text('$done of ${VisitSection.values.length} sections done',
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    // Calm on purpose: the score is information for the
                    // EO, not an alarm, so it's grey whatever the number.
                    if (pct != null)
                      _Pill('Score $pct%', AppColors.ink, AppColors.page),
                    if (visit.isDraft) ...[
                      const SizedBox(width: 6),
                      const _Pill('Draft', AppColors.amberText, AppColors.amberTint),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: done / VisitSection.values.length,
                      minHeight: 6,
                      backgroundColor: AppColors.line,
                      color: AppColors.green,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // --- The ten sections ---
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.card,
                ),
                child: Column(children: [
                  for (final s in VisitSection.values)
                    _SectionRow(
                      section: s,
                      state: visit.stateOf(s),
                      score: visit.stateOf(s) == SectionState.done
                          ? visit.scoreOf(s)
                          : null,
                      subtitle: _subtitle(visit, s),
                      last: s == VisitSection.values.last,
                      onTap: () => _openSection(context, visit, s),
                    ),
                ]),
              ),
            ],
          ),
        ),

        // --- Submit, pinned at the bottom (drafts only) ---
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: visit.isDraft
              ? Column(children: [
                  ElevatedButton(
                    onPressed: visit.canSubmit
                        ? () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ReviewSubmitScreen(visitId: visit.id)))
                        : null,
                    child: const Text('Review & submit'),
                  ),
                  if (!visit.canSubmit)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('Unlocks when every section is done',
                          style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    ),
                ])
              // A submitted visit opened later: no button, just where it
              // stands. Edits save as they're made, like a draft.
              : Text(
                  visit.isLocked
                      ? 'Submitted · read-only (over 7 days)'
                      : visit.submittedAt == null
                          ? 'Submitted · waiting to sync'
                          : 'Submitted · you can edit until '
                              '${Formatters.date(visit.submittedAt!.add(const Duration(days: 7)))}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
        ),
      ],
    );
  }

  /// The grey line under each section name.
  String _subtitle(Visit v, VisitSection s) {
    final state = v.stateOf(s);
    if (state == SectionState.notStarted) return s.hint;
    if (state == SectionState.inProgress) {
      final t = VisitTemplates.checklistFor(s);
      return t == null
          ? 'In progress'
          : 'In progress · ${t.answered(v.section(s))} of ${t.rows.length} answered';
    }
    return switch (s) {
      VisitSection.population => 'Done · ${v.growingPigs ?? 0} growing pigs',
      VisitSection.intake => 'Done · ${v.intakeTotal} pigs planned',
      VisitSection.closeOut => v.followUpNeeded == true
          ? 'Done · follow-up by ${Formatters.date(v.followUpBy)}'
          : 'Done',
      _ => 'Done',
    };
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.section,
    required this.state,
    required this.score,
    required this.subtitle,
    required this.last,
    required this.onTap,
  });

  final VisitSection section;
  final SectionState state;
  /// Shown on the right once the section is done; null if unscored.
  final Score? score;
  final String subtitle;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Grey = not started, amber = in progress, green ✓ = done. The score
    // sits on the right; a perfect one is green, the rest plain ink.
    // Red is never used: it's the brand.
    final (Color bg, Color fg, Widget mark) = switch (state) {
      SectionState.notStarted => (
          AppColors.page,
          AppColors.muted,
          const SizedBox.shrink()
        ),
      SectionState.inProgress => (
          AppColors.amberTint,
          AppColors.amberText,
          const Icon(Icons.more_horiz, size: 16, color: AppColors.amberText)
        ),
      SectionState.done => (
          AppColors.greenTint,
          AppColors.green,
          const Icon(Icons.check, size: 16, color: AppColors.green)
        ),
    };

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
            child: mark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.label,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink)),
                const SizedBox(height: 1),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: state == SectionState.notStarted
                            ? AppColors.muted
                            : fg)),
              ],
            ),
          ),
          if (score case final sc?)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('$sc',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sc.perfect ? AppColors.green : AppColors.ink)),
            ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.fg, this.bg);
  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      );
}