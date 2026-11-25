import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/visit_template.dart';
import 'projections.dart';
import 'session_service.dart';

/// The Projections page as an Excel workbook: a Summary sheet, then one
/// sheet per month listing the farms behind that month's pigs.
///
/// Built on the phone from the same numbers the page shows, so it works
/// offline and the file always matches the screen.
class ProjectionExport {
  ProjectionExport._();

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  // FCL red for headers; the app's orange (alert) for "NA" and old
  // counts, so gaps in a farmer's record stand out on a printout too.
  static final _header = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#C8102E'),
  );
  static final _title = CellStyle(bold: true, fontSize: 14);
  static final _bold = CellStyle(bold: true);
  static final _muted = CellStyle(fontColorHex: ExcelColor.fromHexString('#6B6B6B'));
  static final _flag = CellStyle(bold: true, fontColorHex: ExcelColor.fromHexString('#C2410C'));
  static final _date = CellStyle(numberFormat: CustomDateTimeNumFormat(formatCode: 'd mmm yyyy'));

  /// The month sheets' columns, in order. The width is in characters.
  static const _columns = <(String, double)>[
    ('#', 5),
    ('Farmer', 28),
    ('ID No.', 13),
    ('PF No.', 11),
    ('Phone', 14),
    ('County', 14),
    ('Sub-county', 16),
    ('Ward', 14),
    ('Last visit', 13),
    ('Last visited by', 20),
    ('Count status', 15),
    ('Farm score (%)', 14),
    ('Age at last visit', 16),
    ('Pigs ready', 11),
    ('Pigs on farm', 12),
    ('Sows', 7),
  ];

  /// "RyanMburu-Projections-2026-11-25.xlsx", the same name style as the
  /// farm visit PDFs, so a folder of exports sorts by date.
  static String filename(String eoName, DateTime now) {
    final words = eoName
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join();
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${now.year}-${two(now.month)}-${two(now.day)}';
    return '${words.isEmpty ? 'EO' : words}-Projections-$date.xlsx';
  }

  static List<int> build(
    Projections p, {
    required String eoName,
    required DateTime now,
    required int staleMonths,
  }) {
    final excel = Excel.createExcel(); // starts with one sheet, "Sheet1"
    excel.rename('Sheet1', 'Summary');
    _summary(excel['Summary'], p, eoName: eoName, now: now, staleMonths: staleMonths);
    for (final m in p.months) {
      _month(excel[_sheetName(m.month)], m, now: now, staleMonths: staleMonths);
    }
    excel.setDefaultSheet('Summary'); // the file opens on the summary
    return excel.encode()!;
  }

  /// Builds the file and opens the share sheet. Throws if building fails;
  /// the screen catches it and says so.
  static Future<void> share(Projections p, {required int staleMonths}) async {
    final now = DateTime.now();
    final eo = SessionService.instance.profile.fullName;
    final bytes = build(p, eoName: eo, now: now, staleMonths: staleMonths);
    final name = filename(eo, now);
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      // XFile.fromData's own name is ignored on Android, which would send
      // a random string as the file name; this is the field that works.
      fileNameOverrides: [name],
      subject: 'Pig projections, ${_monthYear(p.months.first.month)} to '
          '${_monthYear(p.months.last.month)}',
    ));
  }

  // ── sheets ─────────────────────────────────────────────────────────────

  static void _summary(
    Sheet s,
    Projections p, {
    required String eoName,
    required DateTime now,
    required int staleMonths,
  }) {
    var r = 0;
    _put(s, 0, r++, TextCellValue('Pig projections: $eoName'), _title);
    _put(s, 0, r++, TextCellValue('Exported ${now.day} ${_months[now.month - 1]} ${now.year}'), _muted);
    _put(s, 0, r++,
        TextCellValue("Pigs reaching ${Projections.readyAge} months, from each farm's latest count."),
        _muted);
    r++;

    for (final (c, h) in ['Month', 'Pigs ready', 'Farms'].indexed) {
      _put(s, c, r, TextCellValue(h), _header);
    }
    r++;
    for (final m in p.months) {
      _put(s, 0, r, TextCellValue(_monthYear(m.month)));
      _put(s, 1, r, IntCellValue(m.pigs));
      _put(s, 2, r, IntCellValue(m.farms.length));
      r++;
    }
    _put(s, 0, r, TextCellValue('Total'), _bold);
    _put(s, 1, r, IntCellValue(p.totalPigs), _bold);
    _put(s, 2, r, IntCellValue(p.countedFarms), _bold);
    r += 2;

    // The same notes as the page, so the file can't be read as more
    // certain than the app says it is.
    _put(s, 0, r++, TextCellValue('About these numbers'), _bold);
    final first = _months[p.months.first.month.month - 1];
    final last = _months[p.months.last.month.month - 1];
    for (final line in [
      if (p.staleFarms > 0)
        '${p.staleFarms} of ${p.countedFarms} farms were last counted over $staleMonths months ago '
            '("Count status" on each month\'s sheet). Still included, but least reliable.',
      if (p.pastPigs > 0)
        '${p.pastPigs} pigs from older counts were ready before $first. Left out: most likely gone.',
      if (p.laterPigs > 0) '${p.laterPigs} younger pigs will be ready after $last.',
      if (p.uncountedFarms > 0) '${p.uncountedFarms} farms have no count yet and are not included.',
      'Litters born after a visit are not counted, so later months will turn out higher.',
      'These are pigs reaching market age, not confirmed deliveries to FCL.',
    ]) {
      _put(s, 0, r++, TextCellValue('• $line'));
    }

    s.setColumnWidth(0, 18);
    s.setColumnWidth(1, 12);
    s.setColumnWidth(2, 10);
  }

  static void _month(
    Sheet s,
    ProjectedMonth m, {
    required DateTime now,
    required int staleMonths,
  }) {
    // Header in the very first row, so Excel's filter and sort work on
    // the sheet without anyone having to select a range first.
    for (final (c, col) in _columns.indexed) {
      _put(s, c, 0, TextCellValue(col.$1), _header);
      s.setColumnWidth(c, col.$2);
    }

    final staleCutoff = DateTime(now.year, now.month - staleMonths, now.day);
    int index(DateTime d) => d.year * 12 + d.month - 1;

    var r = 1;
    for (final (f, pigs) in m.farms) {
      final sum = f.summary!; // only farms with counts reach a month
      final visited = sum.lastVisitDate!;
      // Which band these pigs were in at the visit: the one that reaches
      // 7 months in this sheet's month. One band per farm per month.
      final band = Projections.readyAge - (index(m.month) - index(visited));
      final old = visited.isBefore(staleCutoff);

      var c = 0;
      _put(s, c++, r, IntCellValue(r));
      _put(s, c++, r, TextCellValue(f.name));
      _textOrNa(s, c++, r, f.idNumber);
      _textOrNa(s, c++, r, f.pfNumber);
      // Text, not a number: a number would drop the leading 0 (0712…).
      _textOrNa(s, c++, r, f.mobile);
      _put(s, c++, r, TextCellValue(f.location.county));
      _put(s, c++, r, TextCellValue(f.location.subcounty));
      _put(s, c++, r, TextCellValue(f.location.ward ?? ''));
      _put(s, c++, r,
          DateCellValue(year: visited.year, month: visited.month, day: visited.day), _date);
      _put(s, c++, r, TextCellValue(sum.lastEoName ?? ''));
      _put(s, c++, r, TextCellValue(old ? 'Over $staleMonths months' : 'Recent'),
          old ? _flag : null);
      // Blank, not 0, for paper visits: they were never scored, and 0
      // would read as a terrible farm.
      _put(s, c++, r, sum.scorePct == null ? null : IntCellValue(sum.scorePct!));
      _put(s, c++, r,
          TextCellValue(band >= 0 && band < PopulationTemplate.bands.length
              ? '${PopulationTemplate.bands[band].$2} months'
              : ''));
      _put(s, c++, r, IntCellValue(pigs), _bold);
      _put(s, c++, r, sum.totalPigs == null ? null : IntCellValue(sum.totalPigs!));
      _put(s, c++, r, sum.sows == null ? null : IntCellValue(sum.sows!));
      r++;
    }

    // One empty row, then the total, so sorting the table above doesn't
    // drag the total row into the middle of it.
    r++;
    _put(s, 1, r, TextCellValue('Total, ${m.farms.length} farms'), _bold);
    _put(s, 13, r, IntCellValue(m.pigs), _bold);
  }

  // ── helpers ────────────────────────────────────────────────────────────

  static void _put(Sheet s, int c, int r, CellValue? v, [CellStyle? style]) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    // Value first, then the style: the package warns that setting a value
    // after a number format can reset the format.
    cell.value = v;
    if (style != null) cell.cellStyle = style;
  }

  /// Blank goes in as "NA" in orange (Ryan, 25 Nov), so missing PF and ID
  /// numbers are obvious to whoever reads the sheet.
  static void _textOrNa(Sheet s, int c, int r, String? v) {
    final t = v?.trim() ?? '';
    _put(s, c, r, TextCellValue(t.isEmpty ? 'NA' : t), t.isEmpty ? _flag : null);
  }

  static String _monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

  /// "Dec 2026": short, because Excel caps sheet names at 31 characters
  /// and the tabs are easier to tap on a phone.
  static String _sheetName(DateTime d) => '${_months[d.month - 1].substring(0, 3)} ${d.year}';
}