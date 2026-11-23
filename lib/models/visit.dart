import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/visit_template.dart';

/// Where a section stands, for the hub's coloured circles.
enum SectionState { notStarted, inProgress, done }

/// One reviewed recommendation from the previous visit.
class RecReview {
  const RecReview(this.text, this.outcome);
  final String text;

  /// "done" | "partly" | "not_done" | null (not answered yet).
  final String? outcome;

  factory RecReview.fromMap(Map<String, dynamic> m) =>
      RecReview(m['text'] as String? ?? '', m['outcome'] as String?);

  Map<String, dynamic> toMap() => {'text': text, 'outcome': outcome};
}

/// One farm visit: a draft while being filled in, then submitted.
///
/// Visits are the permanent record. Everything else (a farmer's latest
/// herd, follow-ups, projections) is worked out FROM visits, and nothing
/// worked out is ever written back onto one.
class Visit {
  Visit({
    required this.id,
    required this.farmerId,
    this.pfNumber,
    required this.farmerName,
    this.county,
    this.subcounty,
    required this.eoUid,
    required this.eoName,
    required this.visitDate,
    required this.status,
    required this.targets,
    required this.data,
    this.submittedAt,
    this.createdAt,
    this.editCount = 0,
    this.hasPendingWrites = false,
  });

  final String id;

  /// The technical link to the farmer, which works before a PF exists.
  final String farmerId;

  // Snapshots of the farmer at visit time: exports and the web dashboard
  // read them without a second lookup, and they stay true even if the
  // farmer's details change later.
  final String? pfNumber;
  final String farmerName;
  final String? county;
  final String? subcounty;

  final String eoUid;
  final String eoName;

  /// When the visit happened (may be up to 7 days before it was entered).
  final DateTime visitDate;

  /// "draft" | "submitted".
  final String status;

  /// The KPI targets copied from settings when the visit STARTED, so a
  /// later change of targets never rewrites old visits.
  final Map<String, num> targets;

  /// The raw document, for the section maps and close-out fields.
  final Map<String, dynamic> data;

  final DateTime? submittedAt;
  final DateTime? createdAt;
  final int editCount;
  final bool hasPendingWrites;

  bool get isDraft => status == 'draft';

  /// Submitted visits stay editable by their EO for 7 days. The rules
  /// enforce this on the server; this is only for showing the button.
  ///
  /// No submitted_at yet means it was submitted offline a moment ago (the
  /// server stamps the time when it syncs), so it's well inside the
  /// window. Without this, a visit submitted with no signal would look
  /// locked until the phone found a network.
  bool get canEditSubmitted =>
      !isDraft &&
      (submittedAt == null ||
          DateTime.now().difference(submittedAt!) < const Duration(days: 7));

  Map<String, dynamic>? section(VisitSection s) {
    final v = data[s.key];
    return v is Map<String, dynamic> ? v : null;
  }

  // ---- the Recommendations section lives in top-level fields ----
  // readyForMarket and the follow-up were dropped from the form on 23 Nov
  // (Ryan). Kept as getters only so visits made before then still read.
  int? get readyForMarket => (data['ready_for_market'] as num?)?.toInt();
  List<String> get recommendations =>
      (data['recommendations'] as List?)?.whereType<String>().toList() ?? const [];
  List<RecReview> get lastRecsReview => (data['last_recs_review'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .map(RecReview.fromMap)
          .toList() ??
      const [];
  bool? get followUpNeeded =>
      (data['follow_up'] as Map<String, dynamic>?)?['needed'] as bool?;
  DateTime? get followUpBy =>
      ((data['follow_up'] as Map<String, dynamic>?)?['by'] as Timestamp?)?.toDate();

  /// Done = at least one recommendation (required, 20 Nov). Reviewing
  /// last visit's recommendations is optional like everything else.
  bool get _closeOutComplete => recommendations.isNotEmpty;

  bool get _closeOutStarted =>
      recommendations.isNotEmpty || lastRecsReview.any((r) => r.outcome != null);

  /// Not started / in progress / done, straight from the templates, so
  /// the hub and the submit check can never disagree.
  SectionState stateOf(VisitSection s) {
    if (s == VisitSection.closeOut) {
      if (_closeOutComplete) return SectionState.done;
      return _closeOutStarted ? SectionState.inProgress : SectionState.notStarted;
    }
    final d = section(s);
    if (d == null || d.isEmpty) return SectionState.notStarted;
    final complete = switch (s) {
      VisitSection.production => ProductionTemplate.isComplete(d),
      VisitSection.breeding => BreedingTemplate.isComplete(d),
      VisitSection.population => PopulationTemplate.isComplete(d),
      _ => VisitTemplates.checklistFor(s)!.isComplete(d),
    };
    return complete ? SectionState.done : SectionState.inProgress;
  }

  /// A section's score, or null for the sections that aren't scored
  /// (population and recommendations are counts and plans, not quality).
  Score? scoreOf(VisitSection s) {
    final d = section(s);
    return switch (s) {
      VisitSection.production => ProductionTemplate.score(d, targets),
      VisitSection.breeding => BreedingTemplate.score(d),
      VisitSection.population || VisitSection.closeOut => null,
      _ => VisitTemplates.checklistFor(s)!.score(d),
    };
  }

  /// The whole visit's score: good answers out of every question that was
  /// ANSWERED, in any section, finished or not (23 Nov: questions can be
  /// skipped, and a skipped one isn't a fail). Always shown with its
  /// count ("11 of 14"), so a 3-answer visit can't pass for a full one.
  Score get score => VisitSection.values
      .map(scoreOf)
      .whereType<Score>()
      .fold(const Score(0, 0), (a, b) => a + b);

  int get doneCount =>
      VisitSection.values.where((s) => stateOf(s) == SectionState.done).length;

  /// Sections with anything in them: the hub's "5 of 9 sections".
  int get startedCount =>
      VisitSection.values.where((s) => stateOf(s) != SectionState.notStarted).length;

  /// Sections left out entirely: not on the report, named on review.
  List<VisitSection> get skipped =>
      VisitSection.values.where((s) => stateOf(s) == SectionState.notStarted).toList();

  /// What still blocks Submit, in words for the hub ("Population",
  /// "a recommendation"). Empty = ready.
  List<String> get missingRequired => [
        for (final s in VisitSection.values)
          if (s.required && stateOf(s) != SectionState.done)
            s == VisitSection.closeOut ? 'a recommendation' : s.label,
      ];

  /// Only the required sections gate Submit (23 Nov).
  bool get canSubmit => missingRequired.isEmpty;

  /// Sum of the age bands (growing pigs), for the hub subtitle.
  int? get growingPigs {
    final d = section(VisitSection.population);
    if (d == null) return null;
    return PopulationTemplate.bands
        .fold<int>(0, (n, b) => n + ((d[b.$1] as num?)?.toInt() ?? 0));
  }

  /// Sows on this visit, for the review screen.
  int? get sows => (section(VisitSection.population)?['sows'] as num?)?.toInt();

  /// A copy with one section's answers replaced: lets a save rescore
  /// the answers being saved, not the ones before.
  Visit withSection(VisitSection s, Map<String, dynamic> answers) =>
      withFields({s.key: answers});

  /// A copy with any top-level fields replaced (close-out's four fields).
  Visit withFields(Map<String, dynamic> fields) => Visit(
        id: id,
        farmerId: farmerId,
        pfNumber: pfNumber,
        farmerName: farmerName,
        county: county,
        subcounty: subcounty,
        eoUid: eoUid,
        eoName: eoName,
        visitDate: visitDate,
        status: status,
        targets: targets,
        data: {...data, ...fields},
        submittedAt: submittedAt,
        createdAt: createdAt,
        editCount: editCount,
        hasPendingWrites: hasPendingWrites,
      );

  /// Read-only on the phone? Drafts are always editable; submitted
  /// visits only within their 7-day window.
  bool get isLocked => !isDraft && !canEditSubmitted;

  factory Visit.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final rawTargets = d['targets'] as Map<String, dynamic>? ?? const {};
    return Visit(
      id: doc.id,
      farmerId: d['farmer_id'] as String? ?? '',
      pfNumber: d['pf_number'] as String?,
      farmerName: d['farmer_name'] as String? ?? '',
      county: d['county'] as String?,
      subcounty: d['subcounty'] as String?,
      eoUid: d['eo_uid'] as String? ?? '',
      eoName: d['eo_name'] as String? ?? '',
      // A draft written offline has its visit date from the phone, so
      // this is never null in practice; now() is only a safety net.
      visitDate: (d['visit_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: d['status'] as String? ?? 'draft',
      targets: {
        for (final e in rawTargets.entries)
          if (e.value is num) e.key: e.value as num,
      },
      data: d,
      submittedAt: (d['submitted_at'] as Timestamp?)?.toDate(),
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
      editCount: (d['edit_count'] as num?)?.toInt() ?? 0,
      hasPendingWrites: doc.metadata.hasPendingWrites,
    );
  }
}