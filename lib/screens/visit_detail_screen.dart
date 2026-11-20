import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/visit_template.dart';
import '../models/farmer.dart';
import '../models/visit.dart';
import '../services/farmer_service.dart';
import '../services/pdf_report.dart';
import '../services/visit_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/number_tile.dart';
import '../widgets/section_widgets.dart';
import 'visit_hub_screen.dart';

/// A submitted visit, laid out like Ranch Evaluator's: the facts, the
/// score and rating, Export as PDF, then every section as a one-line
/// summary that opens to its answers on a tap, Population first.
///
/// Live, like the hub, so an edit made a minute ago shows at once.
/// "Edit" in the corner opens the sections while the 7 days are open.
class VisitDetailScreen extends StatefulWidget {
  const VisitDetailScreen({super.key, required this.visitId});

  final String visitId;

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  late final Stream<Visit?> _stream = VisitService.instance.watch(widget.visitId);
  bool _exporting = false;

  /// The farmer's record, for the phone number: the visit doesn't store
  /// it, so it's read live (from the cache offline). Made once per
  /// farmer, not per rebuild, or every rebuild would re-subscribe.
  Stream<Farmer?>? _farmerStream;
  String? _farmerId;
  String? _phone;

  Stream<Farmer?> _farmerFor(String id) {
    if (_farmerId != id) {
      _farmerId = id;
      _farmerStream = FarmerService.instance.watch(id);
    }
    return _farmerStream!;
  }

  /// Built on the phone (no signal needed), then the share sheet opens:
  /// WhatsApp, email, Bluetooth, whatever the EO has.
  Future<void> _export(Visit v) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    String? error;
    try {
      await PdfReport.share(v, phone: _phone);
    } catch (e, stack) {
      error = 'Could not build the report';
      debugPrint('pdf export failed: $e');
      // Not a crash (the EO sees a message and carries on), but we want
      // to know: the PDF is what the farmer gets.
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'pdf export');
    }
    if (!mounted) return;
    setState(() => _exporting = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.alert));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Visit?>(
      stream: _stream,
      builder: (context, snap) {
        final v = snap.data;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.page,
            foregroundColor: AppColors.ink,
            titleSpacing: 0,
            // Just "Visit": the farmer's name leads the first card now.
            title: const Text('Visit',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            actions: [
              if (v != null && !v.isLocked)
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => VisitHubScreen(visitId: v.id))),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(v.isDraft ? 'Resume' : 'Edit'),
                ),
              const SizedBox(width: 6),
            ],
          ),
          body: v == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    children: [
                      StreamBuilder<Farmer?>(
                        stream: _farmerFor(v.farmerId),
                        builder: (context, fs) {
                          // Kept for the PDF, which is built outside this
                          // builder when Export is tapped.
                          _phone = fs.data?.mobile;
                          return _Facts(v, _phone);
                        },
                      ),
                      const SizedBox(height: 12),
                      _ScoreRow(v),
                      const SizedBox(height: 12),
                      _ExportCard(
                        busy: _exporting,
                        // A draft isn't a finished report yet.
                        onTap: v.isDraft ? null : () => _export(v),
                      ),
                      const SizedBox(height: 18),
                      const _Label('Sections'),
                      const SizedBox(height: 8),
                      // Population first (20 Nov, Ryan): the pig count is
                      // the first thing anyone asks about a farm. Close-out
                      // isn't a tile; it's the Recommendations card below.
                      _SectionTile(v, VisitSection.population),
                      for (final s in VisitSection.values)
                        if (s != VisitSection.closeOut && s != VisitSection.population)
                          _SectionTile(v, s),
                      const SizedBox(height: 10),
                      _Recommendations(v),
                      const SizedBox(height: 16),
                      _StatusLine(v),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

// --- top of the page ----------------------------------------------------

/// Date, farmer, location, PF, phone, evaluator: the same six lines, in
/// the same order, as the facts box on the PDF (20 Nov, Ryan).
class _Facts extends StatelessWidget {
  const _Facts(this.v, this.phone);
  final Visit v;

  /// From the farmer's record; null while it loads or if there's none.
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final place = [v.county, v.subcounty].whereType<String>().where((s) => s.isNotEmpty);
    final p = phone ?? '';

    return _Box(children: [
      _fact('Date', Text(Formatters.date(v.visitDate), style: _value)),
      _fact('Farmer',
          Text(v.farmerName, style: _value.copyWith(fontWeight: FontWeight.w600))),
      _fact('Location', Text(place.isEmpty ? '—' : place.join(' · '), style: _value)),
      _fact('PF', Text(v.pfNumber ?? 'No PF', style: _value)),
      _fact(
        'Phone',
        p.isEmpty
            ? const Text('—', style: _value)
            // Tap to call, like the farmer page.
            : GestureDetector(
                onTap: () => launchUrl(Uri(scheme: 'tel', path: p)),
                child: Text(Formatters.displayPhone(p),
                    style: _value.copyWith(
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted,
                        decorationColor: AppColors.muted)),
              ),
      ),
      _fact('Evaluator', Text(v.eoName.isEmpty ? '—' : v.eoName, style: _value), last: true),
    ]);
  }

  static const _value = TextStyle(fontSize: 13.5, color: AppColors.ink);

  Widget _fact(String label, Widget value, {bool last = false}) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 82,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: value)),
        ]),
      );
}

/// Small spaced capitals, the PDF's section-label style.
class _Kicker extends StatelessWidget {
  const _Kicker(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 10.5, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: AppColors.muted));
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(this.v);
  final Visit v;

  @override
  Widget build(BuildContext context) {
    final sc = v.score;
    final rating = Rating.of(sc.pct);
    final (fg, bg) = rating == null
        ? (AppColors.muted, AppColors.white)
        : toneColors(rating.tone);

    Widget panel(String label, String value, {Color? color, Color? fill, Color? edge}) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: fill ?? AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: edge ?? AppColors.white),
              boxShadow: fill == null ? AppShadows.card : null,
            ),
            child: Column(children: [
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: color ?? AppColors.ink)),
            ]),
          ),
        );

    return Row(children: [
      panel('Total score', '${sc.good}/${sc.of}'),
      const SizedBox(width: 10),
      panel('Rating', rating?.label ?? '—',
          color: fg, fill: rating == null ? null : bg, edge: rating == null ? null : fg.withValues(alpha: 0.45)),
    ]);
  }
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: enabled ? AppColors.green : AppColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled ? AppColors.greenTint : AppColors.page),
              child: Icon(Icons.description_outlined,
                  size: 20, color: enabled ? AppColors.green : AppColors.muted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Export as PDF',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(enabled ? 'Share with the farmer' : 'Submit the visit first',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
            if (busy)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green))
            else
              const Icon(Icons.chevron_right, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}

// --- sections -----------------------------------------------------------

/// One line per section: coloured strip, name, score. Tap to open the
/// answers. The strip and score share a colour: green 80 %+, amber from
/// 50 %, orange below. Unscored sections (population, intake) get a grey
/// strip and a count instead.
class _SectionTile extends StatelessWidget {
  const _SectionTile(this.v, this.s);
  final Visit v;
  final VisitSection s;

  @override
  Widget build(BuildContext context) {
    final d = v.section(s);
    final sc = v.scoreOf(s);
    final notStarted = d == null;

    final Color strip;
    final String right;
    Color rightColor = AppColors.ink;
    if (notStarted) {
      strip = AppColors.line;
      right = '—';
      rightColor = AppColors.muted;
    } else if (sc != null) {
      final (fg, _) = toneColors(sc.tone);
      strip = fg;
      right = '$sc';
      rightColor = fg;
    } else {
      strip = AppColors.inputBorder;
      right = s == VisitSection.population
          ? '${v.growingPigs ?? 0} pigs'
          : '${v.intakeTotal} planned';
    }

    final remark = (d?['remark'] as String?)?.trim();

    // Clipped from outside, strip drawn as a left border inside: a
    // one-sided border can't carry a radius itself (Flutter asserts).
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(left: BorderSide(color: strip, width: 3)),
          ),
          child: Theme(
            // copyWith, not a fresh ThemeData: a bare one resets the app
            // theme inside the tile.
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              iconColor: AppColors.muted,
              collapsedIconColor: AppColors.muted,
              title: Row(children: [
                Expanded(
                    child: Text(s.label,
                        style: const TextStyle(fontSize: 14, color: AppColors.ink))),
                Text(right,
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600, color: rightColor)),
              ]),
              children: [
                if (notStarted)
                  const _Muted('Not filled in')
                else
                  ...switch (s) {
                    VisitSection.production => _production(d),
                    VisitSection.breeding => _breeding(d),
                    VisitSection.population => _population(d),
                    VisitSection.intake => _intake(d),
                    _ => _checklist(VisitTemplates.checklistFor(s)!, d),
                  },
                if (remark != null && remark.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.page, borderRadius: BorderRadius.circular(8)),
                    child: Text(remark,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _checklist(ChecklistTemplate t, Map<String, dynamic> d) => [
        for (final r in t.rows) _Answer(r.label, t.optionFor(r, d[r.id])),
      ];

  List<Widget> _production(Map<String, dynamic> d) => [
        for (final k in ProductionTemplate.kpis)
          _Value(
            k.short,
            d[k.id] is num ? '${TileFields.fmt(d[k.id] as num)} ${k.unit}' : '—',
            note: !k.hasTarget || v.targets[k.id] == null
                ? null
                : 'target ${k.higherIsBetter ? '' : '≤ '}${TileFields.fmt(v.targets[k.id]!)}',
            // On the record (not while typing) the figure shows whether
            // it met its target, like the PDF the farmer gets.
            color: switch (k.meets(d[k.id] as num?, v.targets[k.id])) {
              true => AppColors.green,
              false => AppColors.alert,
              null => AppColors.ink,
            },
          ),
      ];

  List<Widget> _breeding(Map<String, dynamic> d) {
    final breed = d['breed'] as String?;
    final other = (d['breed_other'] as String?)?.trim();
    return [
      _Value('Breed',
          breed == null ? '—' : (breed == 'Other' && (other ?? '').isNotEmpty ? other! : breed)),
      for (final r in BreedingTemplate.yesNoRows)
        _Answer(
          r.$2,
          d[r.$1] is bool
              ? (d[r.$1] == true
                  ? const AnswerOption(true, 'Yes', Tone.good)
                  : AnswerOption(false, 'No', r.$3 ? Tone.bad : Tone.warn))
              : null,
        ),
      _Value('Highest parity', '${d['highest_parity'] ?? '—'}'),
    ];
  }

  /// Everything counted on the day. The growing-pig total is already in
  /// the tile's header, so the body is the breeding stock and ready-for-
  /// market as four equal counts, then the eight age bands.
  List<Widget> _population(Map<String, dynamic> d) {
    int n(String k) => (d[k] as num?)?.toInt() ?? 0;

    Widget count(String label, int value) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$value',
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w700, height: 1.1, color: AppColors.ink)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, height: 1.2, color: AppColors.muted)),
          ]),
        );

    return [
      const SizedBox(height: 2),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        count('Sows', n('sows')),
        count('Gilts', n('gilts')),
        count('Boars', n('boars')),
        count('Ready for market', v.readyForMarket ?? 0),
      ]),
      const SizedBox(height: 14),
      const _Kicker('GROWING PIGS BY AGE (MONTHS)'),
      const SizedBox(height: 7),
      _MiniGrid([for (final b in PopulationTemplate.bands) (b.$2, '${n(b.$1)}')]),
    ];
  }

  List<Widget> _intake(Map<String, dynamic> d) {
    final months = IntakeTemplate.monthsOf(d) ?? const <String, dynamic>{};
    final planned = [
      for (final m in IntakeTemplate.monthsFrom(v.visitDate))
        if ((months[IntakeTemplate.keyOf(m)] as num? ?? 0) > 0)
          (_month(m), '${(months[IntakeTemplate.keyOf(m)] as num).toInt()}'),
    ];
    return [
      if (planned.isEmpty) const _Muted('None planned') else _MiniGrid(planned),
    ];
  }

  static const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _month(DateTime m) =>
      '${_mon[m.month - 1]} ${(m.year % 100).toString().padLeft(2, '0')}';
}

/// Close-out, always open below the sections: it's what the farmer
/// walks away with, so it shouldn't hide behind a tap.
class _Recommendations extends StatelessWidget {
  const _Recommendations(this.v);
  final Visit v;

  static const _outcomes = {
    'done': AnswerOption('done', 'Done', Tone.good),
    'partly': AnswerOption('partly', 'Partly', Tone.warn),
    'not_done': AnswerOption('not_done', 'Not done', Tone.bad),
  };

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (v.lastRecsReview.isNotEmpty) ...[
        const _Label("Last visit's recommendations"),
        const SizedBox(height: 6),
        _Box(children: [
          for (final r in v.lastRecsReview) _Answer(r.text, _outcomes[r.outcome]),
        ]),
        const SizedBox(height: 14),
      ],
      const _Label('Recommendations'),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(left: BorderSide(color: AppColors.green, width: 3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (v.recommendations.isEmpty) const _Muted('None this visit'),
            for (var i = 0; i < v.recommendations.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${i + 1}. ${v.recommendations[i]}',
                    style: const TextStyle(fontSize: 13.5)),
              ),
            const SizedBox(height: 4),
            Text(
              [
                'Ready for market: ${v.readyForMarket ?? 0} pigs',
                v.followUpNeeded == true
                    ? 'Follow-up by ${Formatters.date(v.followUpBy)}'
                    : 'No follow-up',
              ].join(' · '),
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine(this.v);
  final Visit v;

  @override
  Widget build(BuildContext context) {
    final until = v.submittedAt?.add(const Duration(days: 7));
    final text = v.isDraft
        ? 'Draft · not submitted yet'
        : v.hasPendingWrites
            ? 'Saved on this phone · waiting to sync'
            : v.isLocked
                ? 'Submitted over 7 days ago. Corrections go through the office.'
                : until == null
                    ? 'Submitted'
                    : 'You can edit this visit until ${Formatters.date(until)}';
    return Column(children: [
      Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
      if (v.editCount > 0)
        Text('Edited ${v.editCount} ${v.editCount == 1 ? 'time' : 'times'} after submitting',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
    ]);
  }
}

// --- small pieces -------------------------------------------------------

class _Box extends StatelessWidget {
  const _Box({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.card,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.muted));
}

/// A question and its answer in the answer's colour.
class _Answer extends StatelessWidget {
  const _Answer(this.label, this.answer);
  final String label;
  final AnswerOption? answer;

  @override
  Widget build(BuildContext context) {
    final a = answer;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
        const SizedBox(width: 10),
        Text(a?.label ?? '—',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: a == null ? AppColors.muted : toneColors(a.tone).$1)),
      ]),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.label, this.value, {this.note, this.color = AppColors.ink});
  final String label;
  final String value;
  final String? note;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                  child: Text(label,
                      style: const TextStyle(fontSize: 13, color: AppColors.muted))),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(note!,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ),
              Text(value,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: color)),
            ]),
      );
}

/// Label-over-number cells, four across: age bands and planned months.
class _MiniGrid extends StatelessWidget {
  const _MiniGrid(this.cells);
  final List<(String label, String value)> cells;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        const gap = 6.0;
        final w = (c.maxWidth - gap * 3) / 4;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final cell in cells)
            Container(
              width: w,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration:
                  BoxDecoration(color: AppColors.page, borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Text(cell.$1, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                Text(cell.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]);
      });
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
      );
}