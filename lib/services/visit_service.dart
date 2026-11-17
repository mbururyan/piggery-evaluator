import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/visit_template.dart';
import '../models/farmer.dart';
import '../models/visit.dart';
import 'auth_service.dart';
import 'session_service.dart';

/// Everything that touches visits/. Same offline pattern as Ranch
/// Evaluator: IDs are made on the phone, writes are never awaited (offline
/// the server never answers), and Firestore queues them until signal.
class VisitService {
  VisitService._();
  static final instance = VisitService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _visits =>
      _db.collection('visits');

  String get _uid => AuthService.instance.currentUser!.uid;

  /// The office's KPI targets, for the snapshot taken at visit start.
  ///
  /// Server first (3 s cap), then whatever this phone cached last time,
  /// then the paper form's numbers. Falling back is safe because the
  /// snapshot records exactly which targets this visit was judged against.
  Future<Map<String, num>> _currentTargets() async {
    final ref = _db.collection('settings').doc('targets');
    Map<String, dynamic>? d;
    try {
      d = (await ref.get().timeout(const Duration(seconds: 3))).data();
    } catch (_) {
      try {
        d = (await ref.get(const GetOptions(source: Source.cache))).data();
      } catch (_) {/* never cached: use the defaults */}
    }
    return {
      for (final e in defaultTargets.entries)
        e.key: (d?[e.key] is num) ? d![e.key] as num : e.value,
    };
  }

  /// Opens a new draft visit for [farmer] and returns its ID straight away.
  ///
  /// The farmer's name, PF and location are COPIED onto the visit (as
  /// snapshots) so exports and the dashboard never need a second lookup,
  /// and an old visit still says where the farm was at the time.
  Future<String> startDraft({
    required Farmer farmer,
    required DateTime visitDate,
  }) async {
    final targets = await _currentTargets();
    final profile = SessionService.instance.profile;
    final ref = _visits.doc();

    ref.set({
      'farmer_id': farmer.id,
      'pf_number': farmer.pfNumber,
      'farmer_name': farmer.name,
      'county': farmer.location.county.isEmpty ? null : farmer.location.county,
      'subcounty':
          farmer.location.subcounty.isEmpty ? null : farmer.location.subcounty,
      'eo_uid': _uid,
      // From memory, never a Firestore read: offline a read could be blank.
      'eo_name': profile.fullName,
      // Whose farmer it is at visit time: lets the office see covering
      // visits (an EO visiting a colleague's farmer).
      'assigned_eo_uid': farmer.assignedEoUid,
      'visit_date': Timestamp.fromDate(visitDate),
      'status': 'draft',
      'source': 'app',
      'schema_version': 1,
      'targets': targets,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// This EO's open draft for [farmerId], if any, so "Start a visit"
  /// resumes it instead of creating a duplicate.
  ///
  /// Equality filters only, so Firestore needs no composite index. Served
  /// from the cache when offline.
  Future<Visit?> openDraftFor(String farmerId) async {
    final q = _visits
        .where('eo_uid', isEqualTo: _uid)
        .where('farmer_id', isEqualTo: farmerId)
        .where('status', isEqualTo: 'draft')
        .limit(1);
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await q.get().timeout(const Duration(seconds: 3));
    } catch (_) {
      snap = await q.get(const GetOptions(source: Source.cache));
    }
    return snap.docs.isEmpty ? null : Visit.fromDoc(snap.docs.first);
  }

  /// One visit, live: every section screen and the hub show the same
  /// saved state, offline included.
  Stream<Visit?> watch(String id) => _visits
      .doc(id)
      .snapshots(includeMetadataChanges: true)
      .map((d) => d.exists ? Visit.fromDoc(d) : null);

  /// This EO's unfinished visits for Home, newest first.
  /// Sorted on the phone so no composite index is needed.
  Stream<List<Visit>> myDrafts() => _visits
      .where('eo_uid', isEqualTo: _uid)
      .where('status', isEqualTo: 'draft')
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.docs.map(Visit.fromDoc).toList()
        ..sort((a, b) => b.visitDate.compareTo(a.visitDate)));

  /// The recommendations from this farmer's most recent SUBMITTED visit
  /// (by any EO), for close-out's "what happened?" check. Null if there
  /// was none.
  ///
  /// Equality filter only and sorted here, so no composite index; falls
  /// back to the cache offline. A farmer has a handful of visits, so
  /// reading them all is cheap.
  Future<({DateTime date, List<String> recs})?> previousRecommendations(
      String farmerId, {required String exceptVisitId}) async {
    final q = _visits.where('farmer_id', isEqualTo: farmerId);
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await q.get().timeout(const Duration(seconds: 3));
    } catch (_) {
      try {
        snap = await q.get(const GetOptions(source: Source.cache));
      } catch (_) {
        return null;
      }
    }
    final past = snap.docs
        .where((d) => d.id != exceptVisitId)
        .map(Visit.fromDoc)
        .where((v) => !v.isDraft)
        .toList()
      ..sort((a, b) => b.visitDate.compareTo(a.visitDate));
    if (past.isEmpty) return null;
    return (date: past.first.visitDate, recs: past.first.recommendations);
  }

  /// Deletes an unfinished visit. The rules only allow this on the EO's
  /// own drafts: a submitted visit is a record and is never deleted from
  /// a phone.
  void deleteDraft(String id) => _visits.doc(id).delete();

  /// Saves one section's answers. Each section is its own top-level map,
  /// so this replaces exactly one field. Called when the EO leaves a
  /// section (partial answers included), so nothing is ever lost.
  ///
  /// On a SUBMITTED visit (the 7-day edit window), the scores are
  /// worked out again from the new answers and written in the same
  /// update, so the stored scores can never disagree with the answers.
  void saveSection(Visit visit, VisitSection section, Map<String, dynamic> answers) {
    final after = visit.withSection(section, answers);
    _visits.doc(visit.id).update({
      section.key: answers,
      ..._editStamp(visit),
      if (!visit.isDraft) ..._scoreFields(after),
    });
  }

  /// Saves close-out, which lives in four top-level fields.
  void saveCloseOut(
    Visit visit, {
    required int? readyForMarket,
    required List<String> recommendations,
    required List<RecReview>? lastRecsReview,
    required bool? followUpNeeded,
    required DateTime? followUpBy,
  }) {
    _visits.doc(visit.id).update({
      'ready_for_market': readyForMarket,
      // Max 5, as on the paper form; blanks dropped.
      'recommendations': recommendations
          .map((r) => r.trim())
          .where((r) => r.isNotEmpty)
          .take(5)
          .toList(),
      // Null = the last visit hasn't been looked up yet: leave the field
      // out so it's looked up next time close-out opens.
      if (lastRecsReview != null)
        'last_recs_review': lastRecsReview.map((r) => r.toMap()).toList(),
      'follow_up': {
        'needed': followUpNeeded,
        'by': followUpNeeded == true && followUpBy != null
            ? Timestamp.fromDate(followUpBy)
            : null,
      },
      ..._editStamp(visit),
    });
  }

  /// Submits a complete draft. Status, the time and the scores go in ONE
  /// update, so a visit can never be "submitted" without its scores (or
  /// the other way round) if the write is interrupted.
  void submit(Visit visit) {
    _visits.doc(visit.id).update({
      'status': 'submitted',
      'submitted_at': FieldValue.serverTimestamp(),
      ..._scoreFields(visit),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Extra fields for every save. A submitted visit being edited (within
  /// its 7-day window) is stamped so the office can see it changed after
  /// submission.
  Map<String, dynamic> _editStamp(Visit visit) {
    if (visit.isDraft) {
      return {'updated_at': FieldValue.serverTimestamp()};
    }
    return {
      'updated_at': FieldValue.serverTimestamp(),
      'edited_at': FieldValue.serverTimestamp(),
      'edit_count': FieldValue.increment(1),
    };
  }

  /// The stored scores, worked out from a visit's answers. score_pct is
  /// for sorting and filtering on the web; scores_by_section keeps the
  /// raw good/of so sections can be added up without rounding.
  Map<String, dynamic> _scoreFields(Visit v) => {
        'score_pct': v.score.pct,
        'scores_by_section': {
          for (final s in VisitSection.values)
            if (v.scoreOf(s) case final sc?) s.key: sc.toMap(),
        },
      };
} 