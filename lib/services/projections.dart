import '../constants/visit_template.dart';
import '../models/farmer.dart';

/// One month on the Projections page.
class ProjectedMonth {
  ProjectedMonth(this.month);

  /// The 1st of the month, local time.
  final DateTime month;
  int pigs = 0;

  /// Each farm's share of this month, biggest first once [Projections.compute]
  /// has finished: what the month expands to on tap.
  final List<(Farmer, int)> farms = [];
}

/// Pigs reaching market age per month, from each farm's latest count.
///
/// The rule is the one in Ryan's projections R script: a pig counted in
/// age band N (0–1 is 0, 1–2 is 1 … 6–7 is 6, 7+ is 7) is ready
/// (7 − N) months after the month of the visit. So a November visit's 7+
/// pigs are ready in November and its 0–1 pigs in June.
///
/// What it can't know, and the page says so:
/// - litters born after the visit aren't counted, so later months always
///   look lower than they'll turn out;
/// - it's pigs reaching 7 months, not pigs FCL will receive.
///
/// Pure: no Firestore, no clock, so it can be checked by hand for any date.
class Projections {
  Projections._({
    required this.months,
    required this.pastPigs,
    required this.laterPigs,
    required this.countedFarms,
    required this.staleFarms,
    required this.uncountedFarms,
  });

  /// Ready age in months (Ryan, 17 Nov: 7+). Also the top band's number.
  static const readyAge = 7;

  /// This month and the four after it (Ryan, 25 Nov: like the Aug–Dec
  /// workbook, five months in all).
  static const monthsAhead = 4;

  final List<ProjectedMonth> months;

  /// Pigs whose ready month came before this month, so they're left out
  /// (25 Nov: very likely sold already). Shown as a count, not hidden.
  final int pastPigs;

  /// Pigs ready after the last month shown: young pigs from recent visits
  /// (a November 0–1 pig is ready in June). Not lost, just beyond the page.
  final int laterPigs;

  /// Farms with band counts, all of which are in the numbers.
  final int countedFarms;

  /// Of [countedFarms], those whose latest count is older than the "due
  /// for a visit" limit. Still counted (25 Nov), but flagged as shaky.
  final int staleFarms;

  /// Farms with no band counts: never visited, or visited before the
  /// bands were added to the summary and not yet backfilled.
  final int uncountedFarms;

  int get totalPigs => months.fold(0, (n, m) => n + m.pigs);

  /// [staleMonths] is the same "due for a visit" limit as the drawer's
  /// list, passed in so both always use one number.
  static Projections compute(
    List<Farmer> farmers, {
    required DateTime now,
    required int staleMonths,
  }) {
    // Months counted from year 0, so "7 months after October 2026" is
    // plain addition and December rolls into January by itself. This is
    // what the R script's hand-typed month grid did, without the typos.
    int index(DateTime d) => d.year * 12 + d.month - 1;
    final thisMonth = index(now);

    final months = [
      for (var i = 0; i <= monthsAhead; i++) ProjectedMonth(DateTime(now.year, now.month + i, 1)),
    ];
    final staleCutoff = DateTime(now.year, now.month - staleMonths, now.day);

    var past = 0, later = 0, counted = 0, stale = 0, uncounted = 0;

    for (final f in farmers) {
      final s = f.summary;
      if (s == null || s.lastVisitDate == null || s.bands.isEmpty) {
        uncounted++;
        continue;
      }
      counted++;
      if (s.lastVisitDate!.isBefore(staleCutoff)) stale++;

      final visited = index(s.lastVisitDate!);
      // Per farm first, so a month's list shows each farm once with its
      // total for that month, not once per band.
      final perMonth = <int, int>{};
      for (var n = 0; n < PopulationTemplate.bands.length; n++) {
        final pigs = s.bands[PopulationTemplate.bands[n].$1] ?? 0;
        if (pigs <= 0) continue;
        final ready = visited + (readyAge - n);
        if (ready < thisMonth) {
          past += pigs;
        } else if (ready - thisMonth <= monthsAhead) {
          perMonth[ready - thisMonth] = (perMonth[ready - thisMonth] ?? 0) + pigs;
        } else {
          later += pigs;
        }
      }
      perMonth.forEach((i, pigs) {
        months[i].pigs += pigs;
        months[i].farms.add((f, pigs));
      });
    }

    for (final m in months) {
      m.farms.sort((a, b) => b.$2.compareTo(a.$2));
    }

    return Projections._(
      months: months,
      pastPigs: past,
      laterPigs: later,
      countedFarms: counted,
      staleFarms: stale,
      uncountedFarms: uncounted,
    );
  }
}