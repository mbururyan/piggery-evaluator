/// Small date helpers so screens don't each invent their own format.
class Formatters {
  Formatters._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "25 Jul 2026". Returns a dash when the date is still resolving.
  static String date(DateTime? d) {
    if (d == null) return '—';
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  /// ISO 8601 week number — the same numbering FCL's working calendar
  /// uses, where week 2 of 2026 begins Monday 5 January.
  ///
  /// The rule is that the Thursday of a week decides which year and
  /// which week the whole week belongs to, which is why a week
  /// straddling New Year does not get split in two.
  ///
  /// Computed rather than looked up: the company calendar is a plain
  /// Mon-Sat ISO week, so a shipped table would only be a copy of this
  /// arithmetic that goes stale every January.
  static int isoWeek(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final thursday = day.add(Duration(days: 4 - day.weekday));
    final dayOfYear =
        thursday.difference(DateTime(thursday.year, 1, 1)).inDays + 1;
    return (dayOfYear - 1) ~/ 7 + 1;
  }

  /// The year that owns this week, which is not always the calendar
  /// year — 31 December can belong to week 1 of the year after.
  static int isoWeekYear(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.add(Duration(days: 4 - day.weekday)).year;
  }

  /// "Wk 32" — chart labels and anywhere the office says "week 32".
  static String weekLabel(DateTime d) => 'Wk ${isoWeek(d)}';

  /// "Week 32 · 3-8 Aug" — for a tooltip or sheet where there is room
  /// to say which days that actually was.
  static String weekRange(DateTime weekStart) {
    // Saturday, not Sunday: the company calendar treats Mon-Sat as the
    // working week.
    final end = weekStart.add(const Duration(days: 6));
    final sameMonth = weekStart.month == end.month;
    final left = sameMonth
        ? '${weekStart.day}'
        : '${weekStart.day} ${_months[weekStart.month - 1]}';
    return 'Week ${isoWeek(weekStart)} · $left-${end.day} '
        '${_months[end.month - 1]}';
  }

  /// "today" / "yesterday" / "25 Jul 2026" — friendlier for recent items.
  static String relativeDate(DateTime? d) {
    if (d == null) return 'just now';
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 7) return '$days days ago';
    return date(d);
  }

  /// One canonical shape for every Kenyan mobile: "0" + 9 digits
  /// (0722123456). Duplicate checks compare exact strings, so "+254 722…",
  /// "254722…" and "0722 123 456" must all become the same value before
  /// they're stored or compared. Also restores a leading zero that Excel
  /// dropped ("722123456"). Anything unrecognised is returned trimmed, as
  /// typed, rather than mangled.
  static String normalizePhone(String raw) {
    final d = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (RegExp(r'^\+254[71]\d{8}$').hasMatch(d)) return '0${d.substring(4)}';
    if (RegExp(r'^254[71]\d{8}$').hasMatch(d)) return '0${d.substring(3)}';
    if (RegExp(r'^[71]\d{8}$').hasMatch(d)) return '0$d';
    return d;
  }

  /// "0722 123 456": easier to read back to a farmer than ten digits.
  static String displayPhone(String p) {
    if (p.length != 10) return p;
    return '${p.substring(0, 4)} ${p.substring(4, 7)} ${p.substring(7)}';
  }
}