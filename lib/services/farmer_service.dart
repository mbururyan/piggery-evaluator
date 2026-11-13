import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/farmer.dart';
import '../utils/formatters.dart';
import 'auth_service.dart';
import 'session_service.dart';

/// A possible duplicate found before registering.
class DuplicateHit {
  const DuplicateHit({required this.farmer, required this.reason});

  final Farmer farmer;

  /// "same phone number" / "same ID number"
  final String reason;
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

  /// Updates the fields an EO may change: name, contact and location.
  /// PF, status, assigned EO and summary are never sent from here, and
  /// the rules reject them if they ever are.
  void update({
    required String farmerId,
    required String name,
    required String mobile,
    String? idNumber,
    String? email,
    required FarmerLocation location,
  }) {
    _farmers.doc(farmerId).update({
      'name': name.trim(),
      'name_lower': name.trim().toLowerCase(),
      'id_number': _blankToNull(idNumber),
      'mobile': Formatters.normalizePhone(mobile),
      'email': _blankToNull(email)?.toLowerCase(),
      'location': location.toMap(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static String? _blankToNull(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();
}