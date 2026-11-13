import 'package:cloud_firestore/cloud_firestore.dart';

/// Where a farmer is. Stored as one nested map so the three parts always
/// travel together: location: { county, subcounty, ward }.
class FarmerLocation {
  const FarmerLocation({
    required this.county,
    required this.subcounty,
    this.ward,
  });

  final String county;
  final String subcounty;

  /// Free text in v1; null when the EO left it blank.
  final String? ward;

  /// "Kiambu · Githunguri" (ward left off: list rows stay one line).
  String get short => subcounty.isEmpty ? county : '$county · $subcounty';

  /// "Kiambu · Githunguri · Ikinu" for the detail page.
  String get full =>
      (ward == null || ward!.isEmpty) ? short : '$short · $ward';

  factory FarmerLocation.fromMap(Map<String, dynamic>? m) => FarmerLocation(
        county: m?['county'] as String? ?? '',
        subcounty: m?['subcounty'] as String? ?? '',
        ward: m?['ward'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'county': county.trim(),
        'subcounty': subcounty.trim(),
        // Stored as null rather than "" so "no ward" is one value, not two.
        'ward': (ward == null || ward!.trim().isEmpty) ? null : ward!.trim(),
      };
}

/// What the Phase 3 Cloud Function writes about a farmer's latest visit.
/// Read-only for the app: the rules stop any phone writing it. Every field
/// is nullable because seed farmers and new farmers have no summary yet.
class FarmerSummary {
  const FarmerSummary({
    this.lastVisitDate,
    this.lastEoName,
    this.visitCount = 0,
    this.sows,
    this.flagsCount,
  });

  final DateTime? lastVisitDate;
  final String? lastEoName;
  final int visitCount;

  /// Sows on the latest visit: drives the "Sow population" sort. Sows
  /// rather than a pig total, because whether gilts are also counted
  /// inside the age bands is still an open question.
  final int? sows;
  final int? flagsCount;

  factory FarmerSummary.fromMap(Map<String, dynamic> m) {
    final pop = m['population'] as Map<String, dynamic>?;
    return FarmerSummary(
      lastVisitDate: (m['last_visit_date'] as Timestamp?)?.toDate(),
      lastEoName: m['last_eo_name'] as String?,
      visitCount: (m['visit_count'] as num?)?.toInt() ?? 0,
      sows: (pop?['sows'] as num?)?.toInt(),
      flagsCount: (m['flags_count'] as num?)?.toInt(),
    );
  }
}

/// One farmer. Visits point at a farmer by [id], never by PF number,
/// because a farmer registered in the field has no PF yet.
class Farmer {
  // Not const: the search text below is worked out lazily, once per farmer.
  Farmer({
    required this.id,
    this.pfNumber,
    required this.status,
    required this.name,
    this.idNumber,
    required this.mobile,
    this.email,
    required this.location,
    required this.assignedEoUid,
    required this.assignedEoName,
    required this.source,
    required this.createdBy,
    this.registeredAt,
    this.summary,
    this.hasPendingWrites = false,
  });

  /// Firestore auto ID: the technical key.
  final String id;

  /// "PF15760": the business key. Null until the office assigns one.
  final String? pfNumber;

  /// "active" or "pending_pf".
  final String status;

  /// "Name of farm / owner": one field, as on the paper form.
  final String name;

  /// National ID, digits only. Optional, but it's the second key for
  /// matching old-app visits, so worth collecting.
  final String? idNumber;

  /// Always canonical "07…"/"01…" (see Formatters.normalizePhone).
  final String mobile;
  final String? email;
  final FarmerLocation location;

  final String assignedEoUid;
  final String assignedEoName;

  /// "seed" (bulk import) or "app" (registered by an EO).
  final String source;
  final String createdBy;

  /// When the farmer joined: drives "Newest registered". Seed farmers
  /// get the date from the import file, app farmers the moment they're
  /// saved. Null for a moment while a server timestamp resolves.
  final DateTime? registeredAt;

  final FarmerSummary? summary;

  /// True while this phone holds changes the server hasn't confirmed.
  final bool hasPendingWrites;

  bool get isPendingPf => status == 'pending_pf' || pfNumber == null;

  /// "Achieng Rose · PF0412", or just the name before a PF exists.
  String get title => pfNumber == null ? name : '$name · $pfNumber';

  /// Lowercased once per farmer, so search doesn't redo it per keystroke.
  late final String _haystack = [
    name,
    pfNumber ?? '',
    mobile,
    idNumber ?? '',
  ].join(' ').toLowerCase();

  /// Case-insensitive match on name, PF, phone or ID. A phone typed with
  /// spaces ("0722 111") still matches the stored "0722111…".
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return _haystack.contains(q) ||
        _haystack.contains(q.replaceAll(' ', ''));
  }

  /// Firestore document → Farmer. The ONLY place that reads these keys.
  /// Every read is null-safe: one odd document must never break the list.
  factory Farmer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final summary = d['summary'];
    return Farmer(
      id: doc.id,
      pfNumber: d['pf_number'] as String?,
      status: d['status'] as String? ?? 'pending_pf',
      name: d['name'] as String? ?? '',
      idNumber: d['id_number'] as String?,
      mobile: d['mobile'] as String? ?? '',
      email: d['email'] as String?,
      location: FarmerLocation.fromMap(d['location'] as Map<String, dynamic>?),
      assignedEoUid: d['assigned_eo_uid'] as String? ?? '',
      assignedEoName: d['assigned_eo_name'] as String? ?? '',
      source: d['source'] as String? ?? 'app',
      createdBy: d['created_by'] as String? ?? '',
      registeredAt: (d['registered_at'] as Timestamp?)?.toDate(),
      summary: summary is Map<String, dynamic>
          ? FarmerSummary.fromMap(summary)
          : null,
      hasPendingWrites: doc.metadata.hasPendingWrites,
    );
  }
}