/// Everything that defines the Daily Farm Visit Report, in one place.
///
/// The screens are generic: one checklist screen draws five sections, the
/// hub lists whatever is here. Changing a LABEL is free at any time.
/// Changing an ID after visits exist is not: ids are the keys stored in
/// Firestore, read by exports, the web dashboard and the projections.
library;

/// The ten parts of a visit, in the order of the paper form (sections
/// 3–11, then close-out). [key] is the Firestore field the section's
/// answers live in.
enum VisitSection {
  production('production', 'Production', 'Actuals against targets'),
  biosecurity('biosecurity', 'Biosecurity', 'Wheel dip, foot bath, PPE…'),
  herdHealth('herd_health', 'Herd health', 'Piglets, weaners, growers…'),
  records('records', 'Farm records', 'Sow ID, vaccination, feeding…'),
  feeds('feeds', 'Feeds', 'Feed types, swill, water'),
  breeding('breeding', 'Breeding', 'Breed, replacement, AI'),
  housing('housing', 'Housing', 'Structures, spacing, hygiene…'),
  population('population', 'Population', 'Pigs by age, sows, boars'),
  intake('intake_schedule', 'Intake schedule', 'Pigs to deliver, 12 months'),
  closeOut('close_out', 'Close-out', 'Recommendations, follow-up');

  const VisitSection(this.key, this.label, this.hint);
  final String key;
  final String label;
  final String hint;
}

// ───────────────────────────── answer tones ──────────────────────────────

/// How an answer reads on screen: green, amber or orange. Only [good]
/// answers earn a point in a section's score.
enum Tone { good, warn, bad }

/// The word for a visit's overall score, shown on the visit page and the
/// farmer's PDF. Bands on the percentage (good answers out of scored
/// questions), so visits with a different number of scored questions
/// still compare fairly.
enum Rating {
  poor('Poor', Tone.bad),
  fair('Fair', Tone.warn),
  good('Good', Tone.good),
  excellent('Excellent', Tone.good);

  const Rating(this.label, this.tone);
  final String label;
  final Tone tone;

  /// 85+ Excellent, 70–84 Good, 50–69 Fair, under 50 Poor. A starting
  /// point (17 Nov): one place to change if the department sets its own.
  static Rating? of(int? pct) => pct == null
      ? null
      : pct >= 85
          ? excellent
          : pct >= 70
              ? good
              : pct >= 50
                  ? fair
                  : poor;
}

/// A section's score: good answers out of the questions that are scored.
/// Shown as "4/5"; stored as {good, of} so the web dashboard can add
/// sections together without rounding errors.
class Score {
  const Score(this.good, this.of);
  final int good;
  final int of;

  bool get perfect => of > 0 && good == of;

  /// Green at 80 %+, amber from 50 %, orange below: the colour of a
  /// section's strip and score on the visit page and in the PDF.
  Tone get tone {
    final p = pct ?? 0;
    return p >= 80 ? Tone.good : (p >= 50 ? Tone.warn : Tone.bad);
  }

  Score operator +(Score o) => Score(good + o.good, of + o.of);

  /// 0–100, or null when nothing was scored (avoids dividing by zero).
  int? get pct => of == 0 ? null : (100 * good / of).round();

  @override
  String toString() => '$good/$of';

  Map<String, int> toMap() => {'good': good, 'of': of};
}

/// One choice in a row: what's stored, what's shown, how it reads.
class AnswerOption {
  const AnswerOption(this.value, this.label, this.tone);
  final Object value;
  final String label;
  final Tone tone;
}

const _yes = AnswerOption(true, 'Yes', Tone.good);
const _no = AnswerOption(false, 'No', Tone.bad);

/// For rows where YES is the problem (swill feeding: ASF risk).
const _yesBad = AnswerOption(true, 'Yes', Tone.bad);
const _noGood = AnswerOption(false, 'No', Tone.good);

// ───────────────────────────── checklists ────────────────────────────────

/// One question in a checklist section.
class ChecklistRow {
  const ChecklistRow(this.id, this.label, {this.hint, this.options});
  final String id;
  final String label;

  /// Small text under the label, e.g. why swill's Yes is the bad answer.
  final String? hint;

  /// Overrides the section's options for this row only (swill).
  final List<AnswerOption>? options;
}

/// A section drawn by the shared checklist screen.
class ChecklistTemplate {
  const ChecklistTemplate({
    required this.section,
    required this.rows,
    required this.options,
  });

  final VisitSection section;
  final List<ChecklistRow> rows;

  /// The answers every row offers unless it overrides them.
  final List<AnswerOption> options;

  List<AnswerOption> optionsFor(ChecklistRow row) => row.options ?? options;

  /// The option a stored value corresponds to, or null if unanswered.
  AnswerOption? optionFor(ChecklistRow row, Object? value) {
    for (final o in optionsFor(row)) {
      if (o.value == value) return o;
    }
    return null;
  }

  bool isComplete(Map<String, dynamic>? data) =>
      data != null && rows.every((r) => optionFor(r, data[r.id]) != null);

  /// Every question counts; only a good (green) answer earns the point.
  /// Amber (Fair) earns nothing: it's shown, but it isn't good.
  Score score(Map<String, dynamic>? data) => Score(
        data == null
            ? 0
            : rows.where((r) => optionFor(r, data[r.id])?.tone == Tone.good).length,
        rows.length,
      );

  int answered(Map<String, dynamic>? data) => data == null
      ? 0
      : rows.where((r) => optionFor(r, data[r.id]) != null).length;
}

class VisitTemplates {
  VisitTemplates._();

  // Section 4. The paper's Good / Needs improvement column was crossed
  // out: availability only.
  static const biosecurity = ChecklistTemplate(
    section: VisitSection.biosecurity,
    options: [_yes, _no],
    rows: [
      ChecklistRow('wheel_dip', 'Wheel dip'),
      ChecklistRow('foot_bath', 'Foot bath'),
      ChecklistRow('shower_area', 'Shower / changing area'),
      ChecklistRow('ppe', 'PPE (boots, overalls)'),
    ],
  );

  // Section 5.
  static const herdHealth = ChecklistTemplate(
    section: VisitSection.herdHealth,
    options: [
      AnswerOption('okay', 'Okay', Tone.good),
      AnswerOption('needs_attention', 'Needs attention', Tone.bad),
    ],
    rows: [
      ChecklistRow('piglets', 'Piglets'),
      ChecklistRow('weaners', 'Weaners'),
      ChecklistRow('growers', 'Growers'),
      ChecklistRow('sow_condition', 'Sow body condition'),
      ChecklistRow('parasite_control', 'Parasite control'),
    ],
  );

  // Section 6.
  static const records = ChecklistTemplate(
    section: VisitSection.records,
    options: [_yes, _no],
    rows: [
      ChecklistRow('sow_id', 'Sow ID records'),
      ChecklistRow('pen', 'Pen records'),
      ChecklistRow('vaccination', 'Vaccination records'),
      ChecklistRow('treatment', 'Treatment records'),
      ChecklistRow('feeding', 'Feeding records'),
    ],
  );

  // Section 7.
  static const feeds = ChecklistTemplate(
    section: VisitSection.feeds,
    options: [_yes, _no],
    rows: [
      ChecklistRow('commercial', 'Commercial feeds'),
      ChecklistRow('fcl_feeds', 'FCL feeds'),
      ChecklistRow('swill', 'Swill feeding',
          hint: 'ASF risk',
          options: [_yesBad, _noGood]),
      ChecklistRow('piglets_fed', 'Piglets fed (creep feed)'),
      ChecklistRow('fcl_program', 'Follows FCL feeding programme'),
      ChecklistRow('water_24_7', 'Water available 24/7'),
    ],
  );

  // Section 9. Good / Fair / Poor (Ryan, 17 Nov) replaced the paper's
  // Meets / Approaching / Below. The stored values changed with them
  // before any real visit existed, so there's nothing old to convert.
  static const housing = ChecklistTemplate(
    section: VisitSection.housing,
    options: [
      AnswerOption('good', 'Good', Tone.good),
      AnswerOption('fair', 'Fair', Tone.warn),
      AnswerOption('poor', 'Poor', Tone.bad),
    ],
    rows: [
      ChecklistRow('structures', 'Structures'),
      ChecklistRow('creep_area', 'Creep area'),
      ChecklistRow('ventilation', 'Ventilation'),
      ChecklistRow('spacing', 'Spacing'),
      ChecklistRow('feeders', 'Feeders'),
      ChecklistRow('hygiene', 'Hygiene'),
      ChecklistRow('waste', 'Waste management'),
    ],
  );

  static ChecklistTemplate? checklistFor(VisitSection s) => switch (s) {
        VisitSection.biosecurity => biosecurity,
        VisitSection.herdHealth => herdHealth,
        VisitSection.records => records,
        VisitSection.feeds => feeds,
        VisitSection.housing => housing,
        _ => null,
      };
}

// ───────────────────────────── production ────────────────────────────────

/// One production KPI row (section 3).
class Kpi {
  const Kpi({
    required this.id,
    required this.label,
    required this.unit,
    String? short,
    this.higherIsBetter = true,
    this.decimals = false,
    this.max,
    this.hasTarget = true,
  }) : short = short ?? label;

  /// Both the answer key in production{} and the key in targets{}.
  final String id;
  final String label;

  /// One-line name for the compact Production tiles. The full [label]
  /// stays for exports and the web, where there's room.
  final String short;
  final String unit;
  final bool higherIsBetter;
  final bool decimals;
  final num? max;
  final bool hasTarget;

  /// Meets target? Null when there's no target or no value to compare.
  /// "Meets" includes equal: 35 days weaning against a 35-day target is
  /// on target, not below it.
  bool? meets(num? actual, num? target) {
    if (!hasTarget || actual == null || target == null) return null;
    return higherIsBetter ? actual >= target : actual <= target;
  }
}

class ProductionTemplate {
  ProductionTemplate._();

  static const kpis = [
    Kpi(id: 'born_alive', label: 'Average born alive', short: 'Born alive (avg)',
        unit: 'piglets'),
    Kpi(id: 'pre_wean_mortality_pct', label: 'Pre-weaning mortality',
        short: 'Pre-wean mortality', unit: '%',
        higherIsBetter: false, decimals: true, max: 100),
    Kpi(id: 'post_wean_mortality_pct', label: 'Post-weaning mortality',
        short: 'Post-wean mortality', unit: '%',
        higherIsBetter: false, decimals: true, max: 100),
    Kpi(id: 'weaning_age_days', label: 'Age at weaning', short: 'Weaning age',
        unit: 'days',
        higherIsBetter: false),
    Kpi(id: 'weaning_weight_kg', label: 'Weight at weaning', short: 'Weaning weight',
        unit: 'kg',
        decimals: true),
    Kpi(id: 'slaughter_age_weeks', label: 'Age at slaughter', short: 'Slaughter age',
        unit: 'weeks',
        higherIsBetter: false),
    Kpi(id: 'finish_weight_kg', label: 'Finish weight', unit: 'kg',
        decimals: true),
    Kpi(id: 'pigs_per_sow_year', label: 'Pigs per sow per year',
        short: 'Pigs / sow / year', unit: 'pigs',
        decimals: true),
    // Counted in pigs (Ryan, 16 Nov), no target on the form.
    Kpi(id: 'monthly_sales_fcl', label: 'Monthly sales to FCL',
        short: 'Sales to FCL / month', unit: 'pigs',
        hasTarget: false),
  ];

  /// How the screen groups the tiles. Ids only: the order here is the
  /// order the keyboard's Next key walks through.
  static const groups = <(String title, List<String> ids)>[
    ('Litters', ['born_alive', 'pre_wean_mortality_pct',
        'weaning_age_days', 'weaning_weight_kg']),
    ('Growing pigs', ['post_wean_mortality_pct', 'slaughter_age_weeks',
        'finish_weight_kg']),
    ('Herd output', ['pigs_per_sow_year', 'monthly_sales_fcl']),
  ];

  static Kpi byId(String id) => kpis.firstWhere((k) => k.id == id);

  static bool isComplete(Map<String, dynamic>? data) =>
      data != null && kpis.every((k) => data[k.id] is num);

  /// One point per KPI on target. Only KPIs with a target in this visit's
  /// snapshot count, so monthly sales (no target) is never scored.
  static Score score(Map<String, dynamic>? data, Map<String, num> targets) {
    final scored = kpis.where((k) => k.hasTarget && targets[k.id] != null);
    final good = data == null
        ? 0
        : scored.where((k) => k.meets(data[k.id] as num?, targets[k.id]) == true).length;
    return Score(good, scored.length);
  }
}

/// The paper form's targets. Used only if settings/targets can't be read
/// (e.g. first ever visit, offline). The office's settings normally win.
const defaultTargets = <String, num>{
  'born_alive': 13,
  'pre_wean_mortality_pct': 5,
  'post_wean_mortality_pct': 2,
  'weaning_age_days': 35,
  'weaning_weight_kg': 8,
  'slaughter_age_weeks': 24,
  'finish_weight_kg': 105,
  'pigs_per_sow_year': 26,
};

// ───────────────────────────── breeding ──────────────────────────────────

class BreedingTemplate {
  BreedingTemplate._();

  static const breeds = ['Large White', 'Landrace', 'Duroc', 'Crossbreed', 'Other'];

  /// Yes/No rows. [scored] false = recorded but left out of the score
  /// (synchronisation and AI are practices, not failings), so their No
  /// shows amber rather than orange.
  static const yesNoRows = <(String id, String label, bool scored)>[
    ('source_fcl', 'Source of breeds: FCL', true),
    ('replacement_program', 'Replacement programme (45% of population)', true),
    ('synchronization', 'Synchronisation done', false),
    ('uses_ai', 'Uses AI', false),
  ];

  static bool isComplete(Map<String, dynamic>? d) {
    if (d == null) return false;
    final breed = d['breed'];
    if (breed is! String || breed.isEmpty) return false;
    if (breed == 'Other' && ((d['breed_other'] as String?)?.trim().isEmpty ?? true)) {
      return false;
    }
    if (d['highest_parity'] is! num) return false;
    return yesNoRows.every((r) => d[r.$1] is bool);
  }

  static Score score(Map<String, dynamic>? d) {
    final scored = yesNoRows.where((r) => r.$3);
    return Score(
      d == null ? 0 : scored.where((r) => d[r.$1] == true).length,
      scored.length,
    );
  }
}

// ───────────────────────────── population ────────────────────────────────

class PopulationTemplate {
  PopulationTemplate._();

  /// Age bands in months. Keys are FIXED everywhere: model, rules,
  /// exports, the projection engine. Never rename them.
  static const bands = <(String key, String label)>[
    ('m0_1', '0–1'), ('m1_2', '1–2'), ('m2_3', '2–3'), ('m3_4', '3–4'),
    ('m4_5', '4–5'), ('m5_6', '5–6'), ('m6_7', '6–7'), ('m7p', '7+'),
  ];

  static const stock = <(String key, String label)>[
    ('sows', 'Sows'), ('gilts', 'Gilts'),  ('boars', 'Boars'),
  ];

  static Iterable<String> get allKeys =>
      [...bands.map((b) => b.$1), ...stock.map((s) => s.$1)];

  static bool isComplete(Map<String, dynamic>? d) =>
      d != null && allKeys.every((k) => d[k] is num);
}

// ───────────────────────────── intake ────────────────────────────────────

class IntakeTemplate {
  IntakeTemplate._();

  /// The 12 months a visit's plan covers, starting with the visit month,
  /// as "YYYY-MM" keys: a 17 Nov 2026 visit -> 2026-11 … 2027-10.
  static List<DateTime> monthsFrom(DateTime visitDate) =>
      List.generate(12, (i) => DateTime(visitDate.year, visitDate.month + i));

  static String keyOf(DateTime m) =>
      '${m.year}-${m.month.toString().padLeft(2, '0')}';

  /// Stored as intake_schedule: {months: {"2026-11": 15, …}, remark}.
  /// The months sit in their own map so nothing reading the plan (the
  /// web, projections) ever has to skip over "remark".
  static Map<String, dynamic>? monthsOf(Map<String, dynamic>? d) =>
      d?['months'] is Map<String, dynamic> ? d!['months'] as Map<String, dynamic> : null;

  /// Blank months mean "none planned", so the section is done once saved;
  /// the screen stores all 12 months (blanks as 0).
  static bool isComplete(Map<String, dynamic>? d) => (monthsOf(d)?.length ?? 0) >= 12;

  static int total(Map<String, dynamic>? d) =>
      monthsOf(d)?.values.whereType<num>().fold<int>(0, (n, v) => n + v.toInt()) ?? 0;
}