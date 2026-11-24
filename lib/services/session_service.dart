import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'auth_service.dart';
import 'due_visits.dart';
import 'sync_service.dart';

/// The signed-in user, as this phone knows them.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.username,
    required this.phone,
    required this.role,
  });

  final String uid;
  final String fullName;
  final String username;
  final String phone;

  /// 'eo' or 'admin', exactly as stored.
  final String role;

  /// What the pill shows. Stored values stay short and lowercase; this
  /// is only the display form.
  String get roleLabel => role == 'admin' ? 'Admin' : 'EO';

  static const unknown = UserProfile(
    uid: '',
    fullName: 'Extension officer',
    username: '',
    phone: '',
    role: 'eo',
  );
}

/// Holds the signed-in EO's profile in memory for the whole session.
///
/// Why this exists (same reason as in Ranch Evaluator): every visit and
/// farmer we write carries a copy of the EO's name. Reading users/{uid}
/// at write time would stamp a blank name whenever that read misses,
/// which is exactly the offline case. So we load the profile ONCE at
/// sign-in, hold it, and stamp from memory.
class SessionService {
  SessionService._();
  static final instance = SessionService._();

  UserProfile? _profile;

  /// Never null at call sites: falls back rather than crashing a write.
  UserProfile get profile => _profile ?? UserProfile.unknown;

  bool get isLoaded => _profile != null;

  /// Call after login, and on the splash before entering the shell.
  ///
  /// Firestore serves this from its local cache when offline, so a
  /// returning EO keeps their name with no signal. get() rather than a
  /// stream because a profile changes about once a year.
  Future<void> load() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final d = doc.data();
      // No early return here: sync must still start below even when the
      // profile doc is missing.
      if (d != null) {
        _profile = UserProfile(
          uid: user.uid,
          fullName: d['full_name'] as String? ?? 'Extension officer',
          username: d['username'] as String? ?? '',
          phone: d['phone'] as String? ?? '',
          role: d['role'] as String? ?? 'eo',
        );
      }
    } catch (_) {
      // Offline with nothing cached: stay null, callers get the fallback.
      // Better a generic name than a crash mid-visit.
    }

    // Start watching for unsynced work as soon as we know who's signed in,
    // even if the profile read above failed: pending writes matter either way.
    SyncService.instance.start(user.uid);
    // Who's due for a visit, for the dot on ☰ and the drawer count.
    DueVisitsService.instance.start(user.uid);

    // Tag crash reports with who was using the phone, so "James's app
    // crashed" can be found. uid and username only: no names or phone
    // numbers leave the phone in a crash report.
    final c = FirebaseCrashlytics.instance;
    c.setUserIdentifier(user.uid);
    c.setCustomKey('username', _profile?.username ?? '');
    c.setCustomKey('role', _profile?.role ?? '');
  }

  /// Wipe on logout so the next EO on this phone never inherits a name,
  /// and stop the sync listeners that were watching the previous EO's work.
  void clear() {
    _profile = null;
    SyncService.instance.stop();
    DueVisitsService.instance.stop();
    // The next person to sign in on this phone gets their own reports.
    FirebaseCrashlytics.instance.setUserIdentifier('');
  }
}