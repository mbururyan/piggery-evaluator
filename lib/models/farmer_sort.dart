import 'farmer.dart';

/// The ways the My farmers list can be ordered. [key] is what gets saved
/// on the phone, so never rename a key once shipped (it would silently
/// reset everyone's choice).
enum FarmerSort {
  newest('newest', 'Newest registered', null),
  az('az', 'A–Z by name', null),
  longestSinceVisit('since_visit', 'Longest since last visit',
      'never-visited first'),
  mostVisited('most_visited', 'Most visited', 'needs visit history'),
  sowPopulation('sows', 'Sow population', 'largest first');

  const FarmerSort(this.key, this.label, this.note);

  final String key;
  final String label;

  /// Small grey hint in the sort menu, or null.
  final String? note;

  static FarmerSort fromKey(String? key) => FarmerSort.values
      .firstWhere((s) => s.key == key, orElse: () => FarmerSort.newest);

  /// Sorts [list] in place.
  ///
  /// Every order falls back to A–Z on ties. Without that, everyone loaded
  /// by the seed import (same registered time) or everyone with no visits
  /// yet would come out in a random order that shuffles on every rebuild.
  void apply(List<Farmer> list) {
    int byName(Farmer a, Farmer b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());

    late final int Function(Farmer, Farmer) primary;
    switch (this) {
      case FarmerSort.newest:
        // A farmer saved a moment ago has no server time yet (null): they
        // ARE the newest, so null sorts first.
        primary = (a, b) {
          final x = a.registeredAt, y = b.registeredAt;
          if (x == null && y == null) return 0;
          if (x == null) return -1;
          if (y == null) return 1;
          return y.compareTo(x);
        };
      case FarmerSort.az:
        primary = (a, b) => 0; // the A–Z tie-break does all the work
      case FarmerSort.longestSinceVisit:
        // Never visited = longest of all, so null goes first; then the
        // oldest last-visit date.
        primary = (a, b) {
          final x = a.summary?.lastVisitDate, y = b.summary?.lastVisitDate;
          if (x == null && y == null) return 0;
          if (x == null) return -1;
          if (y == null) return 1;
          return x.compareTo(y);
        };
      case FarmerSort.mostVisited:
        primary = (a, b) =>
            (b.summary?.visitCount ?? 0).compareTo(a.summary?.visitCount ?? 0);
      case FarmerSort.sowPopulation:
        // Farmers with no count yet go to the bottom, not the top: "no
        // data" is not "zero sows".
        primary = (a, b) {
          final x = a.summary?.sows, y = b.summary?.sows;
          if (x == null && y == null) return 0;
          if (x == null) return 1;
          if (y == null) return -1;
          return y.compareTo(x);
        };
    }

    list.sort((a, b) {
      final p = primary(a, b);
      return p != 0 ? p : byName(a, b);
    });
  }
}