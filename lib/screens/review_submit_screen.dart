import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/visit_template.dart';
import '../models/visit.dart';
import '../services/report_mail.dart';
import '../services/visit_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/section_widgets.dart';

/// One last look before submitting, as wireframe 8 (23 Nov, Ryan): the
/// farmer and the score on a brand-red banner, a white sheet over it with
/// each section's score, what was skipped, and the recommendations.
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
    // The farmer's emailed report (20 Nov). Runs on after this screen has
    // closed, so it holds only the messenger, not this screen's context.
    unawaited(_emailFarmer(v, messenger));
  }

  /// Builds the PDF and queues the email, if the farmer has an address.
  /// Most don't, and that's normal: no message then. Anything else is
  /// reported, so the EO never assumes an email went when it didn't.
  static Future<void> _emailFarmer(Visit v, ScaffoldMessengerState messenger) async {
    final farmer = await ReportMail.farmerOf(v.farmerId);
    if (ReportMail.addressOf(farmer) == null) return;
    final text = ReportMail.message(await ReportMail.queue(v, farmer));
    if (text == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    // White status-bar icons over the red banner.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.page,
        body: StreamBuilder<Visit?>(
          stream: _stream,
          builder: (context, snap) {
            final v = snap.data;
            if (v == null) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
            }
            // Banner and sheet scroll as one, so the sheet's overlap never
            // leaves a band of red showing above the buttons.
            return Column(children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [_Banner(v), _Sheet(v)],
                ),
              ),
              Container(
                color: AppColors.page,
                padding: EdgeInsets.fromLTRB(
                    18, 4, 18, 12 + MediaQuery.of(context).padding.bottom),
                child: Column(children: [
                  ElevatedButton(
                    // Guarded again here: a required part could have been
                    // removed since the hub checked.
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

/// Red banner: back, farmer, PF and date, the big score and its rating.
/// Red is the brand here, not a verdict: the rating word carries the
/// verdict, in white.
class _Banner extends StatelessWidget {
  const _Banner(this.v);
  final Visit v;

  @override
  Widget build(BuildContext context) {
    final sc = v.score;
    final rating = Rating.of(sc.pct);
    const white = Colors.white;
    final soft = Colors.white.withValues(alpha: 0.82);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.red, AppColors.redDark],
        ),
      ),
      // Extra bottom padding: the white sheet overlaps the banner's foot.
      padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 4, 20, 34),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text('Review & submit', style: TextStyle(fontSize: 13, color: soft)),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text(v.farmerName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: white)),
            const SizedBox(height: 2),
            Text('${v.pfNumber ?? 'No PF'} · ${Formatters.date(v.visitDate)}',
                style: TextStyle(fontSize: 12.5, color: soft)),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(sc.pct == null ? '—' : '${sc.pct}%',
                    style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w700, color: white)),
                const SizedBox(width: 10),
                if (rating != null)
                  Text(rating.label,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: white)),
              ],
            ),
            // Always with its count, so a short visit can't pass for a
            // full one.
            Text(
              sc.of == 0
                  ? 'No scored questions answered'
                  : '${sc.good} of ${sc.of} answered questions',
              style: TextStyle(fontSize: 12.5, color: soft),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// The white sheet: section scores, what was skipped, recommendations.
class _Sheet extends StatelessWidget {
  const _Sheet(this.v);
  final Visit v;

  @override
  Widget build(BuildContext context) {
    final scored = [
      for (final s in VisitSection.values)
        if (v.scoreOf(s) case final sc? when sc.of > 0) (s, sc),
    ];
    final skipped = v.skipped;

    return Transform.translate(
      // Pulled up over the banner's foot: the "sheet" look of the
      // wireframe.
      offset: const Offset(0, -20),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.page,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Card(children: [
              const _CardTitle('Sections'),
              _Line('Population', '${v.growingPigs ?? 0} growing pigs'),
              for (final (s, sc) in scored)
                _Line(s.label, '$sc', color: toneColors(sc.tone).$1),
              if (skipped.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Skipped: ${skipped.map((s) => s.label).join(', ')}. '
                  "They're left off the farmer's report.",
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ]),
            const SizedBox(height: 10),
            _Card(children: [
              const _CardTitle('Recommendations'),
              for (var i = 0; i < v.recommendations.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('${i + 1}. ${v.recommendations[i]}',
                      style: const TextStyle(fontSize: 13.5)),
                ),
            ]),
            const SizedBox(height: 10),
            const Text(
              'You can still change this visit for 7 days after submitting.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.card,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
              child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
          Text(value,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}