import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/farmer.dart';
import '../utils/formatters.dart';
import '../utils/search_tokens.dart';
import 'auth_service.dart';
import 'session_service.dart';

/// A possible duplicate found before registering.
class DuplicateHit {
  const DuplicateHit({required this.farmer, required this.reason});

  final Farmer farmer;

  /// "same phone number" / "same ID number"
  final String reason;
}

/// One page of the All farmers list.
class FarmerPage {
  const FarmerPage(this.farmers, this.last, this.hasMore);

  final List<Farmer> farmers;

  /// Where the next page starts. Firestore pages by "start after this
  /// document", not by page number.
  final DocumentSnapshot<Map<String, dynamic>>? last;
  final bool hasMore;
}

/// Everything that touches farmers/. Screens get Farmer objects back and
/// never see Firestore.
class FarmerService {
  FarmerService._();
  static final instance = FarmerService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _farmers =>
      _db.collection('farmers');

  String get _uid => AuthService.instance.currentUser!.uid;

  /// Live list of the signed-in EO's own farmers.
  ///
  /// Deliberately the SAME query SyncService watches
  /// (assigned_eo_uid == uid), so the two share one cached result instead
  /// of paying for two. It's served from the phone's cache first, so it
  /// works offline and fills in instantly. Sorting happens on the phone
  /// (see FarmersTab), so no composite index is needed.
  ///
  /// includeMetadataChanges: so a card's "not synced" marker clears the
  /// moment the server confirms, not at the next data change.
  Stream<List<Farmer>> myFarmers() {
    return _farmers
        .where('assigned_eo_uid', isEqualTo: _uid)
        .snapshots(includeMetadataChanges: true)
        .map((snap) => snap.docs.map(Farmer.fromDoc).toList());
  }

  /// One farmer, live: an edit shows on the detail page the moment it's
  /// saved, offline included.
  Stream<Farmer?> watch(String id) {
    return _farmers
        .doc(id)
        .snapshots(includeMetadataChanges: true)
        .map((doc) => doc.exists ? Farmer.fromDoc(doc) : null);
  }

  /// Looks for farmers already using this phone or ID number.
  ///
  /// Online, this searches ALL farmers (any EO's), which catches the real
  /// problem: the same farmer registered by two officers. Offline it can
  /// only search what this phone has cached (the EO's own farmers). The
  /// 3-second cap matters: on a weak signal Firestore can take a long
  /// time to give up on the server, and the EO is standing at the farm.
  Future<List<DuplicateHit>> findDuplicates({
    required String mobile,
    String? idNumber,
    String? excludeId,
  }) async {
    Future<QuerySnapshot<Map<String, dynamic>>> query(
        String field, String value) async {
      final q = _farmers.where(field, isEqualTo: value).limit(5);
      try {
        return await q.get().timeout(const Duration(seconds: 3));
      } catch (_) {
        return q.get(const GetOptions(source: Source.cache));
      }
    }

    final hits = <String, DuplicateHit>{};

    final phone = Formatters.normalizePhone(mobile);
    for (final doc in (await query('mobile', phone)).docs) {
      if (doc.id == excludeId) continue;
      hits[doc.id] =
          DuplicateHit(farmer: Farmer.fromDoc(doc), reason: 'same phone number');
    }

    final id = idNumber?.trim() ?? '';
    if (id.isNotEmpty) {
      for (final doc in (await query('id_number', id)).docs) {
        if (doc.id == excludeId) continue;
        // putIfAbsent: if phone already matched, keep that reason.
        hits.putIfAbsent(doc.id,
            () => DuplicateHit(farmer: Farmer.fromDoc(doc), reason: 'same ID number'));
      }
    }
    return hits.values.toList();
  }

  /// Registers a new farmer as "PF pending", assigned to this EO.
  ///
  /// Offline-safe, same as Ranch Evaluator: the ID is made on the phone,
  /// so this returns at once with a real ID, and set() is NOT awaited
  /// (offline, the server never answers, so awaiting would hang). Returns
  /// the new ID plus a future the caller can briefly wait on to tell the
  /// EO whether it synced.
  ({String id, Future<void> serverAck}) register({
    required String name,
    required String mobile,
    String? idNumber,
    String? email,
    required FarmerLocation location,
  }) {
    final profile = SessionService.instance.profile;
    final ref = _farmers.doc();

    final ack = ref.set({
      'pf_number': null,
      'status': 'pending_pf',
      'name': name.trim(),
      'name_lower': name.trim().toLowerCase(),
      'search_tokens': SearchTokens.forName(name),
      'id_number': _blankToNull(idNumber),
      'mobile': Formatters.normalizePhone(mobile),
      'email': _blankToNull(email)?.toLowerCase(),
      'location': location.toMap(),
      // The registering EO looks after the farmer from now on. That's
      // what makes it appear in their list and their offline cache.
      'assigned_eo_uid': _uid,
      // Stamped from memory, never a Firestore read: a read would come
      // back blank when registering offline.
      'assigned_eo_name': profile.fullName,
      'source': 'app',
      'created_by': _uid,
      'created_at': FieldValue.serverTimestamp(),
      'registered_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    return (id: ref.id, serverAck: ack);
  }

  // ---------------------------------------------------------------------
  // ALL farmers (every EO's). Server-only on purpose: syncing ~2,800
  // farmers to every phone would cost a re-download of the whole list each
  // time the app reopens, and would put everyone's IDs and phones on every
  // EO's phone. These read only what's on screen.
  // ---------------------------------------------------------------------

  static const pageSize = 30;

  /// Server-only reads, capped so a weak signal fails fast and the screen
  /// can say "needs signal" instead of spinning.
  Future<QuerySnapshot<Map<String, dynamic>>> _server(
          Query<Map<String, dynamic>> q) =>
      q.get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

  /// How many farmers exist in total. A count query costs about one read
  /// per 1,000 farmers, not one per farmer.
  Future<int?> countAll() async {
    try {
      final agg = await _farmers
          .count()
          .get(source: AggregateSource.server)
          .timeout(const Duration(seconds: 10));
      return agg.count;
    } catch (_) {
      return null; // the header just shows no number
    }
  }

  /// One page of all farmers, A–Z or newest first.
  /// Both orders use single-field indexes Firestore creates by itself.
  Future<FarmerPage> allPage({
    required bool newestFirst,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> q = newestFirst
        ? _farmers.orderBy('registered_at', descending: true)
        : _farmers.orderBy('name_lower');
    if (startAfter != null) q = q.startAfterDocument(startAfter);
    final snap = await _server(q.limit(pageSize));
    return FarmerPage(
      snap.docs.map(Farmer.fromDoc).toList(),
      snap.docs.isEmpty ? startAfter : snap.docs.last,
      snap.docs.length == pageSize,
    );
  }

  /// Searches all farmers on the server.
  ///
  /// - Starts with "PF": PFs beginning with what was typed (PF145 → PF14500…).
  /// - Only digits: exact phone (any format) and exact ID number.
  /// - Anything else: a name word beginning (see SearchTokens), then the
  ///   other typed words are checked on the phone.
  /// Returns up to [pageSize] matches, A–Z: enough to find someone; the
  /// EO types more to narrow it down.
  Future<List<Farmer>> searchAll(String typed) async {
    final t = typed.trim();
    final digits = t.replaceAll(RegExp(r'[\s\-+]'), '');

    if (RegExp(r'^pf\d*$', caseSensitive: false).hasMatch(t.replaceAll(' ', ''))) {
      final pf = t.replaceAll(' ', '').toUpperCase();
      // Prefix match: everything from "PF145" up to "PF145" + the highest
      // possible character.
      final snap = await _server(_farmers
          .orderBy('pf_number')
          .startAt([pf])
          .endAt(['$pf\uf8ff'])
          .limit(pageSize));
      return snap.docs.map(Farmer.fromDoc).toList();
    }

    if (RegExp(r'^\d{6,12}$').hasMatch(digits)) {
      final phone = Formatters.normalizePhone(digits);
      final results = await Future.wait([
        _server(_farmers.where('mobile', isEqualTo: phone).limit(pageSize)),
        _server(_farmers.where('id_number', isEqualTo: digits).limit(pageSize)),
      ]);
      // A number can be someone's phone AND someone else's ID: merge,
      // without listing a farmer twice.
      final byId = <String, Farmer>{};
      for (final snap in results) {
        for (final d in snap.docs) {
          byId[d.id] = Farmer.fromDoc(d);
        }
      }
      return byId.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    final token = SearchTokens.queryToken(t);
    if (token == null) return const [];
    // array-contains + orderBy needs a composite index. The first time
    // this runs, Firestore's error message carries a link that creates it
    // (printed to the debug console by the Farmers tab).
    final snap = await _server(_farmers
        .where('search_tokens', arrayContains: token)
        .orderBy('name_lower')
        .limit(pageSize));
    final others = SearchTokens.words(t)..remove(token);
    return snap.docs.map(Farmer.fromDoc).where((f) {
      if (others.isEmpty) return true;
      final mine = SearchTokens.forName(f.name).toSet();
      return others.every((w) =>
          mine.contains(w.length > SearchTokens.maxLen
              ? w.substring(0, SearchTokens.maxLen)
              : w));
    }).toList();
  }

  /// Updates the fields an EO may change: name, contact and location,
  /// and clears whatever that fixes from needs_update. PF, status,
  /// assigned EO and summary are never sent from here, and the rules
  /// reject them if they ever are.
  void update({
    required Farmer existing,
    required String name,
    required String mobile,
    String? idNumber,
    String? email,
    required FarmerLocation location,
  }) {
    _farmers.doc(existing.id).update({
      'name': name.trim(),
      'name_lower': name.trim().toLowerCase(),
      // Rebuilt on every edit: a corrected name must stay findable.
      'search_tokens': SearchTokens.forName(name),
      'id_number': _blankToNull(idNumber),
      'mobile': Formatters.normalizePhone(mobile),
      'email': _blankToNull(email)?.toLowerCase(),
      'location': location.toMap(),
      'needs_update': remainingNeeds(existing.needsUpdate, location),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// What's still missing after an edit is saved.
  ///
  /// - location: cleared once county and sub-county are both set (the
  ///   form requires them, so a saved edit always clears it).
  /// - phone: cleared on save. Mobile is required, so saving means the EO
  ///   either filled a blank number or confirmed a shared one.
  /// - id: cleared on save EVEN IF left blank. Ryan's rule: an EO is asked
  ///   once; skipping counts as an answer. The office can still list
  ///   farmers without IDs from the web.
  static List<String> remainingNeeds(
      List<String> before, FarmerLocation location) {
    return before.where((n) {
      switch (n) {
        case 'location':
          return location.county.isEmpty || location.subcounty.isEmpty;
        case 'phone':
        case 'id':
          return false;
        default:
          return true; // unknown future values are left for the office
      }
    }).toList();
  }

  static String? _blankToNull(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();
}