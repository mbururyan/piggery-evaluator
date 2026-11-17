import 'package:flutter/material.dart';

import '../constants/visit_template.dart';
import '../models/visit.dart';
import '../services/visit_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// One last look before submitting: the score, each section's score, the
/// herd and plan, the recommendations and the follow-up.
///
/// Reads the visit live, like the hub, so it always shows what's saved.
/// Submit is one write (status + time + scores together), not awaited:
/// offline it's queued and the sync strip shows it until it lands.
class ReviewSubmitScreen extends StatefulWidget {
  const ReviewSubmitScreen({super.key, required this.visitId});

  final String visitId;

  @override
  State<ReviewSubmitScreen> createState() => _ReviewSubmitScreenState();
}

class _ReviewSubmitScreenState extends State<ReviewSubmitScreen> {
  late final Stream<Visit?> _stream = VisitService.instance.watch(widget.visitId);

  /// Stops a double tap submitting twice.
  bool _submitting = false;

  void _submit(Visit v) {
    if (_submitting) return;
    setState(() => _submitting = true);
    VisitService.instance.submit(v);
    // Taken before leaving: this screen's context is on its way out.
    final messenger = ScaffoldMessenger.of(context);
    // Back to Home: the draft leaves "Unfinished visits" straight away,
    // even offline, because the write is applied to the cache first.
    Navigator.of(context).popUntil((r) => r.isFirst);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Visit submitted: ${v.farmerName}')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.page,
        foregroundColor: AppColors.ink,
        titleSpacing: 0,
        title: const Text('Review & submit',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: StreamBuilder<Visit?>(
          stream: _stream,
          builder: (context, snap) {
            final v = snap.data;
            if (v == null) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
            }
            return Column(children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                  children: [
                    _ScoreCard(v),
                    const SizedBox(height: 10),
                    _Card(title: 'Scores by section', children: [
                      for (final s in VisitSection.values)
                        if (v.scoreOf(s) case final sc?)
                          _Line(s.label, '$sc',
                              color: sc.perfect ? AppColors.green : AppColors.ink),
                    ]),
                    const SizedBox(height: 10),
                    _Card(title: 'Herd and plan', children: [
                      _Line('Growing pigs', '${v.growingPigs ?? 0}'),
                      _Line('Sows', '${v.sows ?? 0}'),
                      _Line('Ready for market now', '${v.readyForMarket ?? 0} pigs'),
                      _Line('To FCL, next 12 months', '${v.intakeTotal} pigs'),
                    ]),
                    const SizedBox(height: 10),
                    _Card(title: 'Recommendations', children: [
                      if (v.recommendations.isEmpty)
                        const Text('None',
                            style: TextStyle(fontSize: 13, color: AppColors.muted)),
                      for (var i = 0; i < v.recommendations.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('${i + 1}. ${v.recommendations[i]}',
                              style: const TextStyle(fontSize: 13.5)),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        v.followUpNeeded == true
                            ? 'Follow-up by ${Formatters.date(v.followUpBy)}'
                            : 'No follow-up visit',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: v.followUpNeeded == true
                                ? AppColors.amberText
                                : AppColors.muted),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    const Text(
                      'You can still change this visit for 7 days after '
                      'submitting. After that, corrections go through the office.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Column(children: [
                  ElevatedButton(
                    // Guarded again here: a section could have been
                    // changed back to unfinished since the hub checked.
                    onPressed: v.isDraft && v.canSubmit && !_submitting
                        ? () => _submit(v)
                        : null,
                    child: const Text('Submit visit'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to sections'),
                  ),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

/// The big number at the top.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard(this.v);
  final Visit v;

  @override
  Widget build(BuildContext context) {
    final sc = v.score;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.farmerName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${v.pfNumber ?? 'No PF'} · ${Formatters.date(v.visitDate)}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 6),
            Text('${v.doneCount} of ${VisitSection.values.length} sections done',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(sc.pct == null ? '—' : '${sc.pct}%',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
          Text('score · ${sc.good} of ${sc.of}',
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.card,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...children,
        ]),
      );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.color = AppColors.ink});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted))),
          Text(value,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}