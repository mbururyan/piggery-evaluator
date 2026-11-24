import 'package:flutter/material.dart';

import '../../constants/visit_template.dart';
import '../../models/farmer.dart';
import '../../models/visit.dart';
import '../../services/analytics.dart';
import '../../services/auth_service.dart';
import '../../services/due_visits.dart';
import '../../services/farmer_service.dart';
import '../../services/visit_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/tab_header.dart';
import '../due_visits_screen.dart';
import '../farmer_detail_screen.dart';

/// The EO's own numbers (24 Nov, Ryan: their own only, no team figures).
///
/// Two kinds of card, and each says which it is:
/// - follows the period pills: the four number cards, sub-counties,
///   farm scores, weak areas;
/// - always the last 8 weeks: visits by week, with the weeks inside the
///   selected period drawn darker;
/// - any date: top farms, herd by area (latest herd counts) and coverage
///   (who's due), because a herd or an overdue farmer doesn't belong to
///   a month.
///
/// Everything is worked out on the phone from the same cached streams
/// the Visits and Farmers tabs use, so it works offline and adds no reads.
class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  // Made once: a new stream per rebuild would re-subscribe and flash the
  // spinner every time a pill is tapped.
  final _visits = VisitService.instance.myVisits();
  final _farmers = FarmerService.instance.myFarmers();

  // Mondays open on last week (Ryan, 24 Nov): that's meeting day, and
  // this week has almost nothing in it yet. Every other day: this month.
  // Decided once, when the tab is first built after login.
  Period _period =
      DateTime.now().weekday == DateTime.monday ? Period.lastWeek : Period.month;
  bool _bySows = false;

  // Sub-county first: most EOs work inside one or two counties, so the
  // county view is often a single bar.
  bool _bySubcounty = true;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Visit>>(
      stream: _visits,
      builder: (context, vs) => StreamBuilder<List<Farmer>>(
        stream: _farmers,
        builder: (context, fs) {
          final visits = vs.data;
          final farmers = fs.data;
          final stats = (visits == null || farmers == null)
              ? null
              : EoStats.compute(
                  visits: visits,
                  farmers: farmers,
                  uid: AuthService.instance.currentUser?.uid ?? '',
                  period: _period,
                  now: DateTime.now(),
                );

          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TabHeader(title: 'Analytics'),
                const SizedBox(height: 6),
                // Five pills don't fit across a small phone, so the row
                // scrolls sideways instead of squeezing the labels.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final p in Period.values) ...[
                      _Pill(
                        label: p.label,
                        selected: _period == p,
                        onTap: () => setState(() => _period = p),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ]),
                ),
                const SizedBox(height: 6),
                Text(stats?.rangeLabel ?? '',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 10),
                Expanded(
                  child: stats == null
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
                      : _body(stats, farmers!),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _body(EoStats s, List<Farmer> farmers) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _numbers(s),
        if (s.drafts > 0) _draftsNote(s.drafts),
        const SizedBox(height: 10),
        _Card(
          title: 'Farm visits by week',
          caption: 'Last ${EoStats.chartWeeks} weeks, by week number · darker = the period above',
          child: VBarChart(bars: [
            for (final b in s.buckets) BarDatum(b.label, b.count, highlight: b.current),
          ]),
        ),
        _topFarms(farmers),
        _herdByArea(farmers),
        _subcounties(s),
        _coverage(farmers.length),
        _scores(s),
        _weakAreas(s),
      ],
    );
  }

  // ── number cards ─────────────────────────────────────────────────────

  Widget _numbers(EoStats s) {
    final diff = s.visits - s.previousVisits;
    final delta = diff == 0
        ? ('Same as ${s.comparedTo.substring(3)}', AppColors.muted)
        // Up is green; down is plain grey, not orange: a quiet week
        // (leave, rain, a training day) isn't a problem to flag.
        : diff > 0
            ? ('▲ $diff ${s.comparedTo}', AppColors.green)
            : ('▼ ${-diff} ${s.comparedTo}', AppColors.muted);
    final rating = Rating.of(s.avgScore);

    return Column(children: [
      Row(children: [
        Expanded(child: _Number('Farm visits', '${s.visits}', delta.$1, delta.$2)),
        const SizedBox(width: 10),
        Expanded(
            child: _Number('New farmers', '${s.newFarmers}', 'registered by you', AppColors.muted)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: _Number(
            'Avg pigs per farm',
            s.avgPigs == null ? '—' : '${s.avgPigs}',
            s.pigFarms == 0
                ? 'No farms counted'
                : 'across ${s.pigFarms} ${s.pigFarms == 1 ? 'farm' : 'farms'}',
            AppColors.muted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Number(
            'Average score',
            s.avgScore == null ? '—' : '${s.avgScore}%',
            rating?.label ?? 'No scored visits',
            rating == null ? AppColors.muted : _toneColor(rating.tone),
          ),
        ),
      ]),
    ]);
  }

  Widget _draftsNote(int n) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
            color: AppColors.amberTint, borderRadius: BorderRadius.circular(10)),
        child: Text(
          '$n ${n == 1 ? 'draft' : 'drafts'} not submitted yet: '
          '${n == 1 ? "it isn't" : "they aren't"} counted here.',
          style: const TextStyle(fontSize: 12, color: AppColors.amberText),
        ),
      );

  // ── top farms ────────────────────────────────────────────────────────

  Widget _topFarms(List<Farmer> farmers) {
    final rows = EoStats.topFarms(farmers, bySows: _bySows);
    final top = rows.isEmpty ? 1 : rows.first.$2;
    return _Card(
      title: 'Top farms',
      caption: "Latest count on each farm, any date",
      action: Row(mainAxisSize: MainAxisSize.min, children: [
        _Pill(label: 'Pigs', small: true, selected: !_bySows,
            onTap: () => setState(() => _bySows = false)),
        const SizedBox(width: 4),
        _Pill(label: 'Sows', small: true, selected: _bySows,
            onTap: () => setState(() => _bySows = true)),
      ]),
      child: rows.isEmpty
          ? const _Empty('No herd counts yet. They come in with submitted visits.')
          : Column(children: [
              for (final (f, n) in rows)
                HBarRow(
                  label: f.name,
                  fraction: n / top,
                  value: '$n',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FarmerDetailScreen(farmerId: f.id))),
                ),
            ]),
    );
  }

  // ── herd by area ─────────────────────────────────────────────────────

  Widget _herdByArea(List<Farmer> farmers) {
    final areas = EoStats.herdByArea(farmers, bySubcounty: _bySubcounty);
    // The rest are counted in a "+ N more" line underneath.
    final shown = areas
        .take(_bySubcounty ? EoStats.subcountyRows : EoStats.countyRows)
        .toList();
    final more = areas.length - shown.length;
    final word = _bySubcounty
        ? (more == 1 ? 'sub-county' : 'sub-counties')
        : (more == 1 ? 'county' : 'counties');
    return _Card(
      title: 'Herd by area',
      caption: 'Latest count on each farm, any date',
      action: Row(mainAxisSize: MainAxisSize.min, children: [
        _Pill(label: 'Sub-county', small: true, selected: _bySubcounty,
            onTap: () => setState(() => _bySubcounty = true)),
        const SizedBox(width: 4),
        _Pill(label: 'County', small: true, selected: !_bySubcounty,
            onTap: () => setState(() => _bySubcounty = false)),
      ]),
      child: shown.isEmpty
          ? const _Empty('No herd counts yet. They come in with submitted visits.')
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Row(children: [
                _Key('Pigs (whole herd)', AppColors.red),
                SizedBox(width: 14),
                _Key('Sows', Color(0xFFE7A3AE)),
              ]),
              const SizedBox(height: 4),
              for (final a in shown)
                PairBarRow(
                  label: a.name,
                  sub: '${a.farms} ${a.farms == 1 ? 'farm' : 'farms'}',
                  first: a.pigs,
                  second: a.sows,
                  max: shown.first.pigs,
                ),
              if (more > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('+ $more more $word',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ),
            ]),
    );
  }

  // ── sub-counties ─────────────────────────────────────────────────────

  /// Brand reds and greys for places: green, amber and orange are kept
  /// for good / so-so / bad, and a sub-county is none of those.
  static const _placeColours = [
    AppColors.red,
    Color(0xFFE7A3AE),
    AppColors.redDark,
    AppColors.muted,
    AppColors.inputBorder,
  ];

  Widget _subcounties(EoStats s) {
    // Four biggest, the rest folded into "Other" so the ring stays legible.
    final top = s.subcounties.take(4).toList();
    final rest = s.subcounties.skip(4).fold<int>(0, (n, e) => n + e.$2);
    final segs = [
      for (var i = 0; i < top.length; i++)
        DonutSegment(top[i].$1, top[i].$2, _placeColours[i]),
      if (rest > 0) DonutSegment('Other', rest, _placeColours[4]),
    ];
    return _Card(
      title: 'Visits by sub-county',
      child: s.visits == 0
          ? const _Empty('No visits in this period.')
          : _DonutRow(
              segments: segs,
              big: '${s.subcounties.length}',
              small: s.subcounties.length == 1 ? 'sub-county' : 'sub-counties',
            ),
    );
  }

  // ── coverage ─────────────────────────────────────────────────────────

  Widget _coverage(int total) {
    return ValueListenableBuilder<DueVisits?>(
      // The same numbers as the drawer's "Due for a visit" and the dot
      // on ☰, so the three can never disagree.
      valueListenable: DueVisitsService.instance.due,
      builder: (context, due, _) {
        if (due == null) return const SizedBox.shrink();
        final overdue = due.overdue.length;
        final never = due.never.length;
        // Clamped: the two streams can land a moment apart, and a farmer
        // registered in between would briefly make this negative.
        final recent = (total - overdue - never).clamp(0, total);
        final pct = total == 0 ? 0 : (100 * recent / total).round();
        return _Card(
          title: 'Farm coverage',
          caption: 'All your farmers, any date · recent = last ${due.months} months',
          child: Column(children: [
            _DonutRow(
              segments: [
                DonutSegment('Seen recently', recent, AppColors.green),
                DonutSegment('Overdue', overdue, AppColors.alert),
                DonutSegment('No visit on record', never, AppColors.inputBorder),
              ],
              big: '$pct%',
              small: 'seen',
            ),
            if (overdue > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DueVisitsScreen())),
                  child: const Text("See who's due",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        );
      },
    );
  }

  // ── scores ───────────────────────────────────────────────────────────

  Widget _scores(EoStats s) {
    final scored = s.ratings.values.fold<int>(0, (a, b) => a + b);
    return _Card(
      title: 'Farm scores',
      child: scored == 0
          ? const _Empty('No scored visits in this period.')
          : _DonutRow(
              segments: [
                DonutSegment('Excellent (85+)', s.ratings[Rating.excellent]!, AppColors.green),
                // A lighter green: Good is good, just not as good.
                DonutSegment('Good (70–84)', s.ratings[Rating.good]!, const Color(0xFF7DB592)),
                DonutSegment('Fair (50–69)', s.ratings[Rating.fair]!, AppColors.amber),
                DonutSegment('Poor (<50)', s.ratings[Rating.poor]!, AppColors.alert),
              ],
              big: '${s.avgScore}%',
              small: 'average',
            ),
    );
  }

  // ── weak areas ───────────────────────────────────────────────────────

  Widget _weakAreas(EoStats s) {
    return _Card(
      title: 'Weak areas',
      caption: 'Good answers out of answered questions, weakest first',
      child: s.sections.isEmpty
          ? const _Empty('No scored answers in this period.')
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (sec, score) in s.sections)
                HBarRow(
                  label: sec.label,
                  fraction: score.pct! / 100,
                  value: '${score.pct}%',
                  color: _toneColor(score.tone),
                ),
              if (s.weakQuestions.isNotEmpty) ...[
                const Divider(height: 22, color: AppColors.line),
                const Text('Most often not good',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                const SizedBox(height: 4),
                for (final q in s.weakQuestions) _WeakRow(q),
              ],
            ]),
    );
  }
}

Color _toneColor(Tone t) => switch (t) {
      Tone.good => AppColors.green,
      Tone.warn => AppColors.amber,
      Tone.bad => AppColors.alert,
    };

// ── small pieces ─────────────────────────────────────────────────────────

/// Same look as the Visits tab's filter pills.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.small = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? AppColors.ink : AppColors.white,
        shape: StadiumBorder(
            side: BorderSide(color: selected ? AppColors.ink : AppColors.inputBorder)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: small ? 10 : 14, vertical: small ? 4 : 7),
            child: Text(label,
                style: TextStyle(
                    fontSize: small ? 11.5 : 12.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? AppColors.white : AppColors.ink)),
          ),
        ),
      );
}

/// White card with a title row; every chart sits in one.
class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.child,
    this.trailing,
    this.caption,
    this.action,
  });
  final String title;
  final Widget child;

  /// Muted text at the right of the title ("14 total").
  final String? trailing;

  /// A muted line under the title: says when a card ignores the period.
  final String? caption;

  /// A widget at the right of the title (the Pigs / Sows pills).
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.card,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
            ),
            if (trailing != null)
              Text(trailing!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            if (action != null) action!,
          ]),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ],
          const SizedBox(height: 10),
          child,
        ]),
      );
}

class _Number extends StatelessWidget {
  const _Number(this.label, this.value, this.sub, this.subColor);
  final String label;
  final String value;
  final String sub;
  final Color subColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.card,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink)),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: subColor)),
        ]),
      );
}

/// Donut on the left, its legend on the right.
class _DonutRow extends StatelessWidget {
  const _DonutRow({required this.segments, required this.big, required this.small});
  final List<DonutSegment> segments;
  final String big;
  final String small;

  @override
  Widget build(BuildContext context) => Row(children: [
        Donut(
          segments: segments,
          center: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(big,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
            Text(small, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(child: DonutLegend(segments: segments)),
      ]);
}

class _WeakRow extends StatelessWidget {
  const _WeakRow(this.q);
  final WeakQuestion q;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: q.label, style: const TextStyle(color: AppColors.ink)),
                TextSpan(
                    text: '  ·  ${q.section.label}',
                    style: const TextStyle(color: AppColors.muted)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 8),
          Text('${q.bad} of ${q.answered}',
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.alert)),
        ]),
      );
}

/// A colour dot and its name, for a chart's key.
class _Key extends StatelessWidget {
  const _Key(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ]);
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
      );
}