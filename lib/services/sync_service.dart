import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// One thing written on this phone that the server hasn't confirmed yet.
class PendingItem {
  const PendingItem(this.label);

  /// e.g. "New farmer: Mwangi Peter", "Visit: Achieng Rose"
  final String label;
}

/// How this phone stands with the server right now.
class SyncStatus {
  const SyncStatus({required this.pending, required this.offline});

  final List<PendingItem> pending;

  /// True when Firestore is answering from the phone's cache instead of
  /// the server: the closest honest signal we have for "no connection".
  final bool offline;

  int get count => pending.length;
  bool get allSynced => pending.isEmpty;

  static const empty = SyncStatus(pending: [], offline: false);
}

/// Watches for writes made on this phone that haven't reached the server.
///
/// Firestore tracks this itself: every document carries
/// metadata.hasPendingWrites, true from the moment it's written locally
/// until the server confirms it. We never guess from signal bars: having
/// signal is not the same as having delivered.
///
/// Changed from Ranch Evaluator: RE gave every widget its own stream, so
/// the strip and the drawer each opened their own Firestore listeners.
/// Here ONE set of listeners runs for the whole session and publishes into
/// [status]; widgets just read it. That's also what lets the logout dialog
/// check the pending count instantly, without waiting on a stream.
class SyncService {
  SyncService._();
  static final instance = SyncService._();

  final _db = FirebaseFirestore.instance;
  final _subs = <StreamSubscription>[];

  /// Read with ValueListenableBuilder, or `.value` for a one-off check.
  final status = ValueNotifier<SyncStatus>(SyncStatus.empty);

  var _farmers = <PendingItem>[];
  var _visits = <PendingItem>[];
  var _offline = false;

  /// Started by SessionService once the EO's profile is loaded.
  void start(String uid) {
    stop(); // never stack a second set of listeners on top of the first

    // includeMetadataChanges is essential on all three: without it
    // Firestore only emits when DATA changes, so the moment a pending
    // write is acknowledged (data unchanged, metadata changed) would never
    // reach the screen.

    // 1. Online/offline signal from the EO's own profile doc. It's tiny,
    //    and the rules always allow reading it.
    _subs.add(_db
        .collection('users')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snap) {
      _offline = snap.metadata.isFromCache;
      _emit();
    }, onError: _ignore));

    // 2. Farmers this EO looks after: covers new registrations and edits.
    //    Filtered to the EO (~260 docs), not the whole ~2,100. Phase 1's
    //    farmers list uses this same query, so the two share one cache.
    _subs.add(_db
        .collection('farmers')
        .where('assigned_eo_uid', isEqualTo: uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snap) {
      _farmers = snap.docs
          .where((d) => d.metadata.hasPendingWrites)
          .map((d) => PendingItem(
              'Farmer: ${d.data()['name'] ?? 'Unnamed farmer'}'))
          .toList();
      _emit();
    }, onError: _ignore));

    // 3. This EO's own visits.
    // TODO(scale): grows by ~10 visits a day per EO. Once Phase 2 adds the
    // created_at index, narrow this to recent visits only.
    _subs.add(_db
        .collection('visits')
        .where('eo_uid', isEqualTo: uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snap) {
      _visits = snap.docs.where((d) => d.metadata.hasPendingWrites).map((d) {
        final data = d.data();
        final farmer = data['farmer_name'] ?? 'Unknown farmer';
        // A submitted visit and a half-done draft are both unsynced, but
        // the EO cares about them differently.
        return PendingItem(data['status'] == 'submitted'
            ? 'Visit: $farmer'
            : 'Draft visit: $farmer');
      }).toList();
      _emit();
    }, onError: _ignore));
  }

  /// Called on logout: drop every listener and reset to "nothing pending".
  void stop() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _farmers = [];
    _visits = [];
    _offline = false;
    status.value = SyncStatus.empty;
  }

  void _emit() {
    status.value = SyncStatus(
      pending: [..._farmers, ..._visits],
      offline: _offline,
    );
  }

  // farmers/ and visits/ have no rules until Phases 1–2, so those
  // listeners get "permission denied" until then. That's expected, not a
  // crash: treat it as "nothing pending" and carry on.
  void _ignore(Object _) {}
}