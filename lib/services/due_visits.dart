import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/farmer.dart';
import 'farmer_service.dart';

/// The EO's farmers, split for the "Due for a visit" screen.
class DueVisits {
  const DueVisits({required this.overdue, required this.never, required this.months});

  /// Last visited more than [months] ago, longest ago first.
  final List<Farmer> overdue;

  /// No visit on record yet. Kept apart so they don't light the orange
  /// dot: until the paper visits are imported in December, that's nearly
  /// everyone, and a dot that's always on means nothing.
  final List<Farmer> never;

  final int months;
}

/// Works out who's due for a visit, from the farmer summaries the Cloud
/// Function keeps up to date. Runs on the phone, from the cache, so it
/// works offline.
///
/// One live calculation per signed-in EO, shared by everything that shows
/// it (the dot on ☰, the drawer count, the screen), started and stopped
/// with the session like SyncService.
class DueVisitsService {
  DueVisitsService._();
  static final instance = DueVisitsService._();

  /// Null until the first calculation lands.
  final due = ValueNotifier<DueVisits?>(null);

  /// The rule (Ryan, 24 Nov): due once the last visit is more than four
  /// months old. Read from settings/visits.due_after_months so the office
  /// can change it from the web app later; 4 if that's missing.
  static const _defaultMonths = 4;

  StreamSubscription<List<Farmer>>? _sub;
  String? _uid;

  Future<int> _months() async {
    final ref = FirebaseFirestore.instance.collection('settings').doc('visits');
    DocumentSnapshot<Map<String, dynamic>>? snap;
    try {
      snap = await ref.get().timeout(const Duration(seconds: 3));
    } catch (_) {
      try {
        snap = await ref.get(const GetOptions(source: Source.cache));
      } catch (_) {}
    }
    final m = (snap?.data()?['due_after_months'] as num?)?.toInt();
    return (m == null || m < 1) ? _defaultMonths : m;
  }

  Future<void> start(String uid) async {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    final months = await _months();
    if (_uid != uid) return; // logged out while settings loaded
    _sub = FarmerService.instance.myFarmers().listen((farmers) {
      due.value = split(farmers, months: months, now: DateTime.now());
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    due.value = null;
  }

  /// Pure, so it can be tested without Firestore.
  @visibleForTesting
  static DueVisits split(List<Farmer> farmers, {required int months, required DateTime now}) {
    // Calendar months, not 30-day blocks: "4 months" means the same date
    // four months back. Dart rolls a negative month into the year before.
    final cutoff = DateTime(now.year, now.month - months, now.day);
    final overdue = <Farmer>[];
    final never = <Farmer>[];
    for (final f in farmers) {
      final last = f.summary?.lastVisitDate;
      if (last == null) {
        never.add(f);
      } else if (last.isBefore(cutoff)) {
        overdue.add(f);
      }
    }
    overdue.sort((a, b) => a.summary!.lastVisitDate!.compareTo(b.summary!.lastVisitDate!));
    never.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return DueVisits(overdue: overdue, never: never, months: months);
  }
}