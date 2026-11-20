import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../constants/visit_template.dart';
import '../models/visit.dart';
import '../utils/formatters.dart';

/// The visit report, as the farmer receives it: built on the phone, no
/// signal needed, then handed to the share sheet (WhatsApp in practice).
///
/// Ported from Ranch Evaluator's report and kept to the same shape, so
/// the two departments' reports look like one family.
///
/// What is NOT in here matters as much as what is. The section remarks
/// are the EO's working notes and never appear; only the recommendations
/// are written for the farmer. Scores and answers keep the app's colours
/// (green / amber / orange) so a problem reads the same on paper.
class PdfReport {
  PdfReport._();

  static const _red = PdfColor.fromInt(0xFFC8102E); // brand, never a status
  static const _ink = PdfColor.fromInt(0xFF1E1E1E);
  static const _muted = PdfColor.fromInt(0xFF6B6B6B);
  static const _rule = PdfColor.fromInt(0xFFE4E0DB);
  static const _tint = PdfColor.fromInt(0xFFF7F5F2);
  static const _green = PdfColor.fromInt(0xFF1F7A3D);
  static const _amber = PdfColor.fromInt(0xFF8A560A); // the dark amber: readable as text
  static const _orange = PdfColor.fromInt(0xFFC2410C);

  static PdfColor _tone(Tone t) => switch (t) {
        Tone.good => _green,
        Tone.warn => _amber,
        Tone.bad => _orange,
      };

  /// Mix a colour toward white. Used instead of alpha: dart_pdf ignores a
  /// PdfColor's alpha in a box fill, so a "light" panel would print as
  /// solid colour with its own label invisible on it.
  static PdfColor _wash(PdfColor c, double amount) => PdfColor(
        c.red + (1 - c.red) * amount,
        c.green + (1 - c.green) * amount,
        c.blue + (1 - c.blue) * amount,
      );

  /// Loaded once. The built-in PDF fonts are Latin-1 only and dart_pdf
  /// THROWS on anything else, and this report is full of ≤, – and ·.
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> _loadTheme() async {
    return _theme ??= pw.ThemeData.withFont(
      base: pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSans-Regular.ttf')),
      bold: pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSans-SemiBold.ttf')),
    );
  }

  /// The pig × Farmer's Choice lockup, as a high-res PNG (dart_pdf's SVG
  /// support doesn't reliably cover the nested artwork). Null if it can't
  /// be read: a report without the lockup is still a report, so that
  /// never blocks the export.
  static pw.MemoryImage? _lockup;

  static Future<pw.Widget?> _logo() async {
    try {
      _lockup ??= pw.MemoryImage(
          (await rootBundle.load('assets/brand/lockup.png')).buffer.asUint8List());
      // Height only: the lockup is about 3.4:1, so fixing the width
      // instead would shrink it to a sliver.
      return pw.Image(_lockup!, height: 32);
    } catch (_) {
      return null;
    }
  }

  static String filenameFor(Visit v) =>
      '${_slug(v.farmerName)}-${_isoDate(v.visitDate)}.pdf';

  /// Build and open the share sheet. Works with no signal; only the
  /// sending (WhatsApp, email) needs one.
  ///
  /// [phone] comes from the farmer's record, not the visit (the visit
  /// doesn't store it), so the caller passes what it already has.
  static Future<void> share(Visit v, {String? phone}) async {
    final bytes = await build(v, phone: phone);
    await Printing.sharePdf(bytes: bytes, filename: filenameFor(v));
  }

  static Future<Uint8List> build(Visit v, {String? phone}) async {
    final theme = await _loadTheme();
    final logo = await _logo();

    final doc = pw.Document(
      theme: theme,
      title: '${v.farmerName} — farm visit report',
      author: "Farmer's Choice · Pig Procurement",
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(38, 36, 38, 30),
        // Page one has the masthead, so the running header starts on page
        // two; otherwise the name appears twice an inch apart.
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 14),
                padding: const pw.EdgeInsets.only(bottom: 6),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(v.farmerName,
                        style: pw.TextStyle(
                            fontSize: 9, color: _muted, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Farm visit report',
                        style: const pw.TextStyle(fontSize: 9, color: _muted)),
                  ],
                ),
              ),
        footer: _footer,
        build: (context) => [
          _masthead(logo),
          pw.SizedBox(height: 16),
          _facts(v, phone),
          pw.SizedBox(height: 14),
          _scoreBlock(v),
          pw.SizedBox(height: 14),
          _herdBlock(v),
          pw.SizedBox(height: 18),
          ..._production(v),
          ..._findings(v),
          ..._intake(v),
          ..._recommendations(v),
        ],
      ),
    );
    return doc.save();
  }

  // --- blocks ---------------------------------------------------------

  /// The farmer's name moved into the facts box (20 Nov, Ryan), so the
  /// big title is the document's name, with the lockup on the right.
  static pw.Widget _masthead(pw.Widget? logo) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("FARMER'S CHOICE · PIG PROCUREMENT",
                    style: pw.TextStyle(
                        fontSize: 8,
                        letterSpacing: 1.4,
                        color: _red,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 7),
                pw.Text('Farm visit report',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              ]),
            ),
            pw.SizedBox(width: 16),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              if (logo != null) logo,
              pw.SizedBox(height: 6),
              pw.Text('PIGGERY EVALUATOR',
                  style: pw.TextStyle(
                      fontSize: 7,
                      letterSpacing: 1.2,
                      color: _muted,
                      fontWeight: pw.FontWeight.bold)),
            ]),
          ]),
          pw.SizedBox(height: 12),
          pw.Container(height: 2, color: _red),
        ],
      );

  /// Same six lines, same order, as the top card in the app.
  static pw.Widget _facts(Visit v, String? phone) {
    pw.Widget row(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.SizedBox(
                width: 92,
                child: pw.Text(label, style: const pw.TextStyle(fontSize: 9.5, color: _muted))),
            pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10.5))),
          ]),
        );
    final place = [v.county, v.subcounty].whereType<String>().where((s) => s.isNotEmpty);
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: _tint, borderRadius: pw.BorderRadius.circular(5)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        row('Date of visit', Formatters.date(v.visitDate)),
        row('Farmer', v.farmerName),
        row('Location', place.isEmpty ? '—' : place.join(' · ')),
        row('PF number', v.pfNumber ?? '—'),
        row('Phone', phone == null || phone.isEmpty ? '—' : Formatters.displayPhone(phone)),
        row('Visited by', v.eoName.isEmpty ? '—' : v.eoName),
      ]),
    );
  }

  static pw.Widget _scoreBlock(Visit v) {
    final sc = v.score;
    final rating = Rating.of(sc.pct);
    final color = rating == null ? _muted : _tone(rating.tone);

    pw.Widget panel(String label, String big, PdfColor bigColor,
            {String? small, PdfColor? fill, PdfColor? edge}) =>
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 13),
            decoration: pw.BoxDecoration(
              color: fill,
              border: pw.Border.all(color: edge ?? _rule),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(children: [
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 8, letterSpacing: 1.1, color: _muted)),
              pw.SizedBox(height: 5),
              pw.Text(big,
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold, color: bigColor)),
              if (small != null)
                pw.Text(small, style: const pw.TextStyle(fontSize: 9, color: _muted)),
            ]),
          ),
        );

    return pw.Row(children: [
      panel('TOTAL SCORE', '${sc.good} / ${sc.of}', _ink,
          small: sc.pct == null ? null : '${sc.pct} %'),
      pw.SizedBox(width: 10),
      panel('RATING', rating?.label ?? '—', color,
          fill: _wash(color, 0.9), edge: _wash(color, 0.5)),
    ]);
  }

  /// The pigs counted on the day: the figure a farmer checks first.
  static pw.Widget _herdBlock(Visit v) {
    final pop = v.section(VisitSection.population) ?? const <String, dynamic>{};
    int n(String k) => (pop[k] as num?)?.toInt() ?? 0;

    pw.Widget cell(String label, int value, {bool emphasis = false}) => pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('$value',
                style: pw.TextStyle(
                    fontSize: emphasis ? 17 : 15,
                    fontWeight: pw.FontWeight.bold,
                    color: emphasis ? _red : _ink)),
            pw.SizedBox(height: 2),
            pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
          ]),
        );

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _rule),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _label('PIGS AT THIS VISIT'),
        pw.SizedBox(height: 9),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          cell('Growing pigs', v.growingPigs ?? 0, emphasis: true),
          cell('Sows', n('sows')),
          cell('Gilts', n('gilts')),
          cell('Boars', n('boars')),
          cell('Ready for market', v.readyForMarket ?? 0),
        ]),
        pw.SizedBox(height: 10),
        _label('GROWING PIGS BY AGE (MONTHS)'),
        pw.SizedBox(height: 5),
        pw.Row(children: [
          for (final b in PopulationTemplate.bands)
            pw.Expanded(
              child: pw.Container(
                margin: const pw.EdgeInsets.only(right: 4),
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: pw.BoxDecoration(color: _tint, borderRadius: pw.BorderRadius.circular(3)),
                child: pw.Column(children: [
                  pw.Text(b.$2, style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
                  pw.Text('${n(b.$1)}',
                      style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }

  /// Production figures against their targets. Kept as a small table:
  /// "your farm vs the target" is the most useful line for the farmer.
  static List<pw.Widget> _production(Visit v) {
    final d = v.section(VisitSection.production);
    if (d == null) return const [];
    final rows = <pw.Widget>[];
    for (final k in ProductionTemplate.kpis) {
      final value = d[k.id] as num?;
      final target = v.targets[k.id];
      final meets = k.meets(value, target);
      rows.add(pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
        decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFF0EDE9)))),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(k.label, style: const pw.TextStyle(fontSize: 9.5))),
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              value == null ? '—' : '${_num(value)} ${k.unit}',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: meets == null ? _ink : (meets ? _green : _orange)),
            ),
          ),
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              !k.hasTarget || target == null
                  ? ''
                  : 'target ${k.higherIsBetter ? '' : '≤ '}${_num(target)}',
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 8.5, color: _muted),
            ),
          ),
        ]),
      ));
    }
    return [
      _heading('Production figures'),
      pw.SizedBox(height: 8),
      _sectionHeader('Your farm against the targets', v.scoreOf(VisitSection.production)),
      pw.SizedBox(height: 4),
      ...rows,
      pw.SizedBox(height: 16),
    ];
  }

  /// Every checklist section, answer by answer. The score tells a farmer
  /// they lost a point; the line tells them which one.
  static List<pw.Widget> _findings(Visit v) {
    final out = <pw.Widget>[];
    for (final s in VisitSection.values) {
      final d = v.section(s);
      if (d == null) continue;
      final List<pw.Widget> rows;
      if (s == VisitSection.breeding) {
        final breed = d['breed'] as String?;
        final other = (d['breed_other'] as String?)?.trim();
        rows = [
          _finding('Breed',
              breed == null ? '—' : (breed == 'Other' && (other ?? '').isNotEmpty ? other! : breed)),
          for (final r in BreedingTemplate.yesNoRows)
            if (d[r.$1] is bool)
              _finding(r.$2, d[r.$1] == true ? 'Yes' : 'No',
                  tone: d[r.$1] == true ? Tone.good : (r.$3 ? Tone.bad : Tone.warn)),
          _finding('Highest parity', '${d['highest_parity'] ?? '—'}'),
        ];
      } else {
        final t = VisitTemplates.checklistFor(s);
        if (t == null) continue; // production, population, intake: own blocks
        rows = [
          for (final r in t.rows)
            if (t.optionFor(r, d[r.id]) case final o?) _finding(r.label, o.label, tone: o.tone),
        ];
      }
      if (out.isEmpty) {
        out.add(_heading('Findings by section'));
        out.add(pw.SizedBox(height: 8));
      }
      // One column per section so MultiPage keeps a section together
      // where it fits, and a heading never sits alone at a page foot.
      out.add(pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _sectionHeader(s.label, v.scoreOf(s)),
        pw.SizedBox(height: 5),
        ...rows,
        pw.SizedBox(height: 12),
      ]));
    }
    return out;
  }

  static List<pw.Widget> _intake(Visit v) {
    final d = v.section(VisitSection.intake);
    if (d == null) return const [];
    final months = IntakeTemplate.monthsOf(d) ?? const <String, dynamic>{};
    final planned = [
      for (final m in IntakeTemplate.monthsFrom(v.visitDate))
        if ((months[IntakeTemplate.keyOf(m)] as num? ?? 0) > 0)
          (m, (months[IntakeTemplate.keyOf(m)] as num).toInt()),
    ];
    return [
      _heading('Planned deliveries to FCL'),
      pw.SizedBox(height: 7),
      if (planned.isEmpty)
        pw.Text('None planned in the next 12 months',
            style: const pw.TextStyle(fontSize: 9.5, color: _muted))
      else
        pw.Wrap(spacing: 5, runSpacing: 5, children: [
          for (final p in planned)
            pw.Container(
              width: 60,
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              decoration: pw.BoxDecoration(color: _tint, borderRadius: pw.BorderRadius.circular(3)),
              child: pw.Column(children: [
                pw.Text(_month(p.$1), style: const pw.TextStyle(fontSize: 8, color: _muted)),
                pw.Text('${p.$2}',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ]),
            ),
        ]),
      pw.SizedBox(height: 5),
      pw.Text('${v.intakeTotal} pigs over the next 12 months',
          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 16),
    ];
  }

  static List<pw.Widget> _recommendations(Visit v) {
    const outcomes = {
      'done': ('Done', Tone.good),
      'partly': ('Partly done', Tone.warn),
      'not_done': ('Not done', Tone.bad),
    };
    final review = v.lastRecsReview.where((r) => r.outcome != null).toList();
    final recs = v.recommendations;
    if (review.isEmpty && recs.isEmpty && v.followUpNeeded != true) return const [];

    return [
      if (review.isNotEmpty) ...[
        _heading('Since the last visit'),
        pw.SizedBox(height: 6),
        for (final r in review)
          _finding(r.text, outcomes[r.outcome]!.$1, tone: outcomes[r.outcome]!.$2),
        pw.SizedBox(height: 14),
      ],
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(13),
        // No borderRadius on purpose: dart_pdf only allows a radius with
        // a UNIFORM border, and this one is left-side only.
        decoration: const pw.BoxDecoration(
          color: _tint,
          border: pw.Border(left: pw.BorderSide(color: _green, width: 3)),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('RECOMMENDATIONS',
              style: pw.TextStyle(
                  fontSize: 8, letterSpacing: 1.1, color: _green, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 7),
          if (recs.isEmpty)
            pw.Text('None this visit', style: const pw.TextStyle(fontSize: 10.5, color: _muted)),
          for (var i = 0; i < recs.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text('${i + 1}.  ${recs[i]}',
                  style: const pw.TextStyle(fontSize: 11, lineSpacing: 2.5)),
            ),
          if (v.followUpNeeded == true && v.followUpBy != null) ...[
            pw.SizedBox(height: 6),
            pw.Text('Next visit planned by ${Formatters.date(v.followUpBy)}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ],
        ]),
      ),
    ];
  }

  // --- pieces ---------------------------------------------------------

  /// Section name, a bar filled to the score, and "4 / 5". The bar is one
  /// proportional strip because sections have different question counts.
  static pw.Widget _sectionHeader(String label, Score? sc) {
    final color = sc == null ? _muted : _tone(sc.tone);
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 5),
      decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.6))),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Expanded(
            child: pw.Text(label,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
        if (sc != null && sc.of > 0) ...[
          pw.Container(
            width: 80,
            height: 6,
            decoration: pw.BoxDecoration(color: _rule, borderRadius: pw.BorderRadius.circular(1.5)),
            alignment: pw.Alignment.centerLeft,
            child: pw.Container(
              width: 80 * sc.good / sc.of,
              height: 6,
              decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(1.5)),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text('${sc.good} / ${sc.of}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ]),
    );
  }

  /// One question and its answer, the answer in its tone's colour.
  static pw.Widget _finding(String label, String value, {Tone? tone}) {
    final color = tone == null ? _ink : _tone(tone);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // A dot rather than a tick: the answer word already carries the
        // verdict, and two markers per line reads as clutter on paper.
        pw.Container(
          width: 3,
          height: 3,
          margin: const pw.EdgeInsets.only(top: 4.5, right: 7),
          decoration: pw.BoxDecoration(color: tone == null ? _muted : color, shape: pw.BoxShape.circle),
        ),
        pw.Expanded(child: pw.Text(label, style: const pw.TextStyle(fontSize: 9.5))),
        pw.SizedBox(width: 10),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: color)),
      ]),
    );
  }

  static pw.Widget _label(String text) => pw.Text(text,
      style: const pw.TextStyle(fontSize: 8, letterSpacing: 1.1, color: _muted));

  static pw.Widget _heading(String text) => pw.Text(text.toUpperCase(),
      style: pw.TextStyle(
          fontSize: 8.5, letterSpacing: 1.2, color: _muted, fontWeight: pw.FontWeight.bold));

  static pw.Widget _footer(pw.Context context) => pw.Column(children: [
        pw.Container(height: 0.6, color: _rule),
        pw.SizedBox(height: 7),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(
            'Generated ${Formatters.date(DateTime.now())} · '
            "Farmer's Choice · Piggery Evaluator",
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ]),
      ]);

  // --- formatting -----------------------------------------------------

  static String _num(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _month(DateTime m) =>
      '${_mon[m.month - 1]} ${(m.year % 100).toString().padLeft(2, '0')}';

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _slug(String s) {
    final cleaned = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return cleaned.isEmpty ? 'visit' : cleaned;
  }
}