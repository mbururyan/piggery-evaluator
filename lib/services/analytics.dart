import 'package:flutter/foundation.dart';

import '../constants/visit_template.dart';
import '../models/farmer.dart';
import '../models/visit.dart';
import '../utils/formatters.dart';

/// The Analytics tab's time ranges. Every range runs from its start up
/// to the end of today, so "Month" on the 24th means 1–24 Nov, except
/// [lastWeek], which is the whole of last week (for Monday's meeting).
enum Period {
  week('This week'),
  lastWeek('Last week'),
  month('Month'),
  quarter('3 months'),
  year('Year');

  const Period(this.label);
  final String label;
}

/// From [start] (inclusive) to [end] (exclusive), both local midnights.
class DateRange {
  const DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
}

/// One bar on the visits chart.
class Bucket {
  const Bucket(this.label, this.count, {this.current = false});
  final String label;
  final int count;

  /// The week overlaps the selected period, so it's drawn darker: the
  /// chart always shows eight weeks, and this marks which of them the
  /// number cards are about.
  final bool current;
}

/// A question that often gets an answer that isn't good.
class WeakQuestion {
  const WeakQuestion(this.label, this.section, this.bad, this.answered);
  final String label;
  final VisitSection section;
  final int bad;
  final int answered;

  double get share => bad / answered;
}

/// One county or sub-county's herd, for "Herd by area". Mutable only
/// while [EoStats.herdByArea] adds farms into it.
class AreaHerd {
  AreaHerd(this.name);
  final String name;
  int pigs = 0;
  int sows = 0;

  /// Farms with a count, so "312 pigs" can be read as 3 farms or 30.
  int farms = 0;
}

const _mon = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "16–21 Nov" for the FCL week (Mon–Sat) starting on [monday].
String _weekDays(DateTime monday) {
  final sat = DateTime(monday.year, monday.month, monday.day + 5);
  return monday.month == sat.month
      ? '${monday.day}–${sat.day} ${_mon[sat.month - 1]}'
      : '${monday.day} ${_mon[monday.month - 1]}–${sat.day} ${_mon[sat.month - 1]}';
}

/// [d] moved by [n] calendar months, with the day held where it can be:
/// 31 Mar minus a month is 28 Feb, not 3 Mar (what DateTime would do).
DateTime addMonths(DateTime d, int n) {
  final first = DateTime(d.year, d.month + n, 1);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, d.day > lastDay ? lastDay : d.day);
}

/// The EO's own numbers for one period. Worked out on the phone from the
/// cached visits and farmers, so it works offline and costs no reads
/// beyond what the Visits and Farmers tabs already listen to.
///
/// Pure: no Firestore, no clock. [now] comes in as an argument so the
/// numbers can be checked by hand for any date.
class EoStats {
  EoStats._({
    required this.period,
    required this.range,
    required this.previous,
    required this.visits,
    required this.previousVisits,
    required this.drafts,
    required this.newFarmers,
    required this.avgPigs,
    required this.pigFarms,
    required this.avgScore,
    required this.buckets,
    required this.ratings,
    required this.subcounties,
    required this.sections,
    required this.weakQuestions,
  });

  final Period period;
  final DateRange range;

  /// The same stretch of the period before: 1–24 Oct against 1–24 Nov,
  /// so a month that's only three weeks old isn't compared with a full
  /// one and always looks worse.
  final DateRange previous;

  /// Submitted visits dated in [range]. Drafts aren't visits yet.
  final int visits;
  final int previousVisits;

  /// Drafts waiting, any date: a draft from last month still needs
  /// submitting, so this ignores the period.
  final int drafts;

  /// Farmers this EO registered in the field during [range].
  final int newFarmers;

  /// Average pigs per farm (age bands + sows + gilts + boars) over the
  /// farms visited in [range], or null with none. Replaced "Farmers
  /// visited" on 24 Nov (Ryan).
  final int? avgPigs;

  /// How many farms [avgPigs] averages over: different farms, so a farm
  /// visited twice in the month is counted once, from its latest visit.
  final int pigFarms;

  /// The mean of each visit's score, or null with no scored visit.
  final int? avgScore;

  /// One bar per week for the last [chartWeeks] weeks, oldest first.
  /// NOT tied to the period pills (Ryan, 24 Nov): the same eight weeks
  /// whatever's selected, so the trend is always there to glance at.
  final List<Bucket> buckets;

  /// How many visits landed in each rating band.
  final Map<Rating, int> ratings;

  /// Visits per sub-county, most first. The sub-county is the copy saved
  /// on the visit, so a farmer who moves later doesn't rewrite history.
  final List<(String name, int count)> subcounties;

  /// Each scored section's combined score over [range], weakest first.
  /// Sections nobody answered are left out rather than shown as 0 %.
  final List<(VisitSection section, Score score)> sections;

  /// Up to three questions most often answered badly.
  final List<WeakQuestion> weakQuestions;

  /// "vs Oct", "vs last week": what the visits card compares against.
  String get comparedTo => switch (period) {
        Period.week => 'vs last week',
        Period.lastWeek => 'vs ${_weekDays(previous.start)}',
        Period.month => 'vs ${_mon[previous.start.month - 1]}',
        Period.quarter =>
          'vs ${_mon[previous.start.month - 1]}–${_mon[addMonths(previous.start, 2).month - 1]}',
        Period.year => 'vs ${previous.start.year}',
      };

  /// "1–24 Nov 2026", shown under the period pills. Last week reads
  /// "Week 47 · 16–21 Nov 2026", the way it'll be called in the meeting.
  String get rangeLabel {
    if (period == Period.lastWeek) {
      return 'Week ${Formatters.isoWeek(range.start)} · ${_weekDays(range.start)} ${range.start.year}';
    }
    final s = range.start;
    final e = range.end.subtract(const Duration(days: 1));
    final sameMonth = s.month == e.month && s.year == e.year;
    return sameMonth
        ? '${s.day}–${e.day} ${_mon[e.month - 1]} ${e.year}'
        : '${s.day} ${_mon[s.month - 1]} – ${e.day} ${_mon[e.month - 1]} ${e.year}';
  }

  /// How many weeks the visits chart shows (Ryan, 24 Nov: last 8).
  static const chartWeeks = 8;

  /// A question needs this many answers before it can be called weak:
  /// with one visit, a single "No" would top the list at 100 %.
  static const minAnswers = 3;

  static DateRange rangeOf(Period p, DateTime now) {
    // Last week ends where this week starts (Monday 00:00), so a Sunday
    // visit still counts; every other period runs to the end of today.
    final end = p == Period.lastWeek
        ? DateTime(now.year, now.month, now.day - (now.weekday - 1))
        : DateTime(now.year, now.month, now.day + 1);
    final start = switch (p) {
      Period.week => DateTime(now.year, now.month, now.day - (now.weekday - 1)),
      Period.lastWeek => DateTime(now.year, now.month, now.day - (now.weekday - 1) - 7),
      Period.month => DateTime(now.year, now.month, 1),
      // This month and the two before it: Sep 1 – Nov 24.
      Period.quarter => DateTime(now.year, now.month - 2, 1),
      Period.year => DateTime(now.year, 1, 1),
    };
    return DateRange(start, end);
  }

  static DateRange previousOf(Period p, DateRange r) => switch (p) {
        // A full week against the full week before it.
        Period.week || Period.lastWeek => DateRange(
            DateTime(r.start.year, r.start.month, r.start.day - 7),
            DateTime(r.end.year, r.end.month, r.end.day - 7)),
        Period.month => DateRange(addMonths(r.start, -1), addMonths(r.end, -1)),
        Period.quarter => DateRange(addMonths(r.start, -3), addMonths(r.end, -3)),
        Period.year => DateRange(addMonths(r.start, -12), addMonths(r.end, -12)),
      };

  static EoStats compute({
    required List<Visit> visits,
    required List<Farmer> farmers,
    required String uid,
    required Period period,
    required DateTime now,
  }) {
    final range = rangeOf(period, now);
    final previous = previousOf(period, range);

    final submitted = visits.where((v) => !v.isDraft).toList();
    final inRange = submitted.where((v) => range.contains(v.visitDate)).toList();

    // Scores: worked out from the answers each time, the same way the
    // visit cards do, so the tab and the cards never disagree.
    final pcts = inRange.map((v) => v.score.pct).whereType<int>().toList();
    final ratings = {for (final r in Rating.values) r: 0};
    for (final p in pcts) {
      ratings[Rating.of(p)!] = ratings[Rating.of(p)!]! + 1;
    }

    // One herd per farm: its latest visit in the period. inRange is
    // newest first (myVisits sorts it), so the first one seen wins.
    final seen = <String>{};
    final herd = <int>[];
    for (final v in inRange) {
      if (!seen.add(v.farmerId)) continue;
      final pop = v.section(VisitSection.population);
      if (pop == null) continue;
      herd.add(PopulationTemplate.allKeys
          .fold<int>(0, (n, k) => n + ((pop[k] as num?)?.toInt() ?? 0)));
    }

    final places = <String, int>{};
    for (final v in inRange) {
      final s = v.subcounty?.trim() ?? '';
      final key = s.isEmpty ? 'Not recorded' : s;
      places[key] = (places[key] ?? 0) + 1;
    }
    final subcounties = places.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    final sections = <(VisitSection, Score)>[
      for (final s in VisitSection.values)
        if (inRange
                .map((v) => v.scoreOf(s))
                .whereType<Score>()
                .fold(const Score(0, 0), (a, b) => a + b)
            case final total when total.of > 0)
          (s, total),
    ]..sort((a, b) => a.$2.pct!.compareTo(b.$2.pct!));

    return EoStats._(
      period: period,
      range: range,
      previous: previous,
      visits: inRange.length,
      previousVisits: submitted.where((v) => previous.contains(v.visitDate)).length,
      drafts: visits.where((v) => v.isDraft).length,
      newFarmers: farmers
          .where((f) =>
              f.source == 'app' &&
              f.createdBy == uid &&
              f.registeredAt != null &&
              range.contains(f.registeredAt!))
          .length,
      avgPigs: herd.isEmpty ? null : (herd.reduce((a, b) => a + b) / herd.length).round(),
      pigFarms: herd.length,
      avgScore: pcts.isEmpty ? null : (pcts.reduce((a, b) => a + b) / pcts.length).round(),
      buckets: _lastWeeks(submitted, now, range),
      ratings: ratings,
      subcounties: subcounties,
      sections: sections,
      weakQuestions: findWeakQuestions(inRange),
    );
  }

  /// The visits chart: this week and the seven before it, Mon–Sun each
  /// (a Sunday visit counts in its week). Always eight bars, so the chart
  /// is the same size on day one and after two years.
  static List<Bucket> _lastWeeks(List<Visit> submitted, DateTime now, DateRange selected) {
    final thisMonday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final out = <Bucket>[];
    for (var i = chartWeeks - 1; i >= 0; i--) {
      final start = DateTime(thisMonday.year, thisMonday.month, thisMonday.day - 7 * i);
      final week = DateRange(start, DateTime(start.year, start.month, start.day + 7));
      out.add(Bucket(
        // Number only: eight "Wk 48"s don't fit under narrow bars; the
        // card's caption says they're week numbers.
        '${Formatters.isoWeek(start)}',
        submitted.where((v) => week.contains(v.visitDate)).length,
        current: week.start.isBefore(selected.end) && selected.start.isBefore(week.end),
      ));
    }
    return out;
  }

  /// Every scored question, counted across [visits]: how often it was
  /// answered, and how often the answer wasn't the good one. Amber
  /// answers (housing "Fair") count as not good, same as in the score.
  @visibleForTesting
  static List<WeakQuestion> findWeakQuestions(List<Visit> visits) {
    final found = <WeakQuestion>[];

    for (final s in VisitSection.values) {
      final t = VisitTemplates.checklistFor(s);
      if (t == null) continue;
      for (final row in t.rows) {
        var answered = 0, bad = 0;
        for (final v in visits) {
          final o = t.optionFor(row, v.section(s)?[row.id]);
          if (o == null) continue;
          answered++;
          if (o.tone != Tone.good) bad++;
        }
        found.add(WeakQuestion(row.label, s, bad, answered));
      }
    }

    // Production: "not good" = missed the target that visit carried.
    for (final k in ProductionTemplate.kpis.where((k) => k.hasTarget)) {
      var answered = 0, bad = 0;
      for (final v in visits) {
        final value = v.section(VisitSection.production)?[k.id];
        final meets = k.meets(value is num ? value : null, v.targets[k.id]);
        if (meets == null) continue;
        answered++;
        if (!meets) bad++;
      }
      found.add(WeakQuestion(k.short, VisitSection.production, bad, answered));
    }

    // Breeding: only the scored yes/no rows; synchronisation and AI are
    // practices, not failings, so they never show as weak.
    for (final (id, label, scored) in BreedingTemplate.yesNoRows) {
      if (!scored) continue;
      var answered = 0, bad = 0;
      for (final v in visits) {
        final value = v.section(VisitSection.breeding)?[id];
        if (value is! bool) continue;
        answered++;
        if (!value) bad++;
      }
      found.add(WeakQuestion(label, VisitSection.breeding, bad, answered));
    }

    final ranked = found.where((q) => q.answered >= minAnswers && q.bad > 0).toList()
      ..sort((a, b) {
        final byShare = b.share.compareTo(a.share);
        return byShare != 0 ? byShare : b.bad.compareTo(a.bad);
      });
    return ranked.take(3).toList();
  }

  /// Pigs and sows added up per county or sub-county, from each farm's
  /// latest count, biggest herd first. Like [topFarms], not tied to the
  /// period. Uses the farmer's location as it is NOW (where the herd is
  /// today), not the copy saved on an old visit.
  ///
  /// Farms with no count yet are left out entirely, so an area full of
  /// never-visited farmers doesn't show as a long row of zeros.
  /// How many areas get a row in "Herd by area" (Ryan, 24 Nov).
  static const subcountyRows = 5;
  static const countyRows = 3;

  static List<AreaHerd> herdByArea(List<Farmer> farmers, {required bool bySubcounty}) {
    final areas = <String, AreaHerd>{};
    for (final f in farmers) {
      final pigs = f.summary?.totalPigs;
      if (pigs == null) continue;
      final raw = (bySubcounty ? f.location.subcounty : f.location.county).trim();
      final name = raw.isEmpty ? 'No location' : raw;
      final a = areas[name] ?? AreaHerd(name);
      a.pigs += pigs;
      a.sows += f.summary?.sows ?? 0;
      a.farms++;
      areas[name] = a;
    }
    return areas.values.toList()..sort((a, b) => b.pigs.compareTo(a.pigs));
  }

  /// The biggest farms by their latest count, whoever visited (top 10,
  /// Ryan 24 Nov). Not tied
  /// to the period: a herd is a herd whether it was counted this month
  /// or in July.
  static List<(Farmer, int)> topFarms(List<Farmer> farmers, {required bool bySows, int take = 10}) {
    final rows = [
      for (final f in farmers)
        if ((bySows ? f.summary?.sows : f.summary?.totalPigs) case final n? when n > 0) (f, n),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return rows.take(take).toList();
  }
}