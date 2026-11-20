import 'package:flutter/material.dart';

import '../../constants/visit_template.dart';
import '../../models/visit.dart';
import '../../services/visit_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tab_header.dart';
import '../visit_detail_screen.dart';
import '../visit_hub_screen.dart';

enum _Filter { all, submitted, drafts }

/// Every visit this EO has made, newest first, grouped by FCL working
/// week (ISO weeks, Mon–Sat), so "what did I do this week" is one glance.
///
/// Works offline: it reads the phone's cache, and a visit submitted with
/// no signal shows "Waiting to sync" until it lands.
class VisitsTab extends StatefulWidget {
  const VisitsTab({super.key});

  @override
  State<VisitsTab> createState() => _VisitsTabState();
}

class _VisitsTabState extends State<VisitsTab> {
  // Made once: a new stream on every rebuild would re-subscribe and
  // flash the loading state each time a chip is tapped.
  final _stream = VisitService.instance.myVisits();
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Visit>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data;
        final shown = all?.where((v) => switch (_filter) {
              _Filter.all => true,
              _Filter.submitted => !v.isDraft,
              _Filter.drafts => v.isDraft,
            }).toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabHeader(title: 'My visits', count: shown?.length),
              const SizedBox(height: 6),
              Row(children: [
                for (final f in _Filter.values) ...[
                  _FilterPill(
                    label: switch (f) {
                      _Filter.all => 'All',
                      _Filter.submitted => 'Submitted',
                      _Filter.drafts => 'Drafts',
                    },
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 6),
                ],
              ]),
              const SizedBox(height: 10),
              Expanded(child: _body(all == null, shown)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(bool loading, List<Visit>? shown) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (shown!.isEmpty) {
      return EmptyState(
        icon: Icons.assignment_outlined,
        title: _filter == _Filter.drafts ? 'No drafts' : 'No visits yet',
        message: _filter == _Filter.drafts
            ? 'Visits you start and leave unfinished show here.'
            : 'Visits you submit will appear here, grouped by week.',
      );
    }

    // Flat list of week headers and cards; the list is already newest
    // first, so a header goes in whenever the week changes.
    final items = <Widget>[];
    String? lastWeek;
    for (final v in shown) {
      final key = '${Formatters.isoWeekYear(v.visitDate)}-${Formatters.isoWeek(v.visitDate)}';
      if (key != lastWeek) {
        final count = shown
            .where((x) =>
                Formatters.isoWeekYear(x.visitDate) == Formatters.isoWeekYear(v.visitDate) &&
                Formatters.isoWeek(x.visitDate) == Formatters.isoWeek(v.visitDate))
            .length;
        items.add(_WeekHeader(v.visitDate, count));
        lastWeek = key;
      }
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _VisitCard(visit: v),
      ));
    }
    return ListView(padding: const EdgeInsets.only(bottom: 18), children: items);
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? AppColors.ink : AppColors.white,
        shape: StadiumBorder(
            side: BorderSide(color: selected ? AppColors.ink : AppColors.inputBorder)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? AppColors.white : AppColors.ink)),
          ),
        ),
      );
}

/// "This week · 16–21 Nov · 4 visits". FCL weeks run Monday to Saturday.
class _WeekHeader extends StatelessWidget {
  const _WeekHeader(this.day, this.count);
  final DateTime day;
  final int count;

  static const _mon = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final d = DateTime(day.year, day.month, day.day);
    final monday = d.subtract(Duration(days: d.weekday - 1));
    final saturday = monday.add(const Duration(days: 5));
    final range = monday.month == saturday.month
        ? '${monday.day}–${saturday.day} ${_mon[saturday.month - 1]}'
        : '${monday.day} ${_mon[monday.month - 1]}–${saturday.day} ${_mon[saturday.month - 1]}';

    final now = DateTime.now();
    final sameWeek = Formatters.isoWeek(now) == Formatters.isoWeek(day) &&
        Formatters.isoWeekYear(now) == Formatters.isoWeekYear(day);
    final title = sameWeek ? 'This week' : 'Week ${Formatters.isoWeek(day)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Row(children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
        Text('  ·  $range',
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const Spacer(),
        Text('$count ${count == 1 ? 'visit' : 'visits'}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ]),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.visit});
  final Visit visit;

  /// Kept lean on purpose (17 Nov, Ryan): name, place and date, score on
  /// the right. Status only shows when it needs the EO's attention: a
  /// draft says so in amber, and a visit still on the phone gets a small
  /// cloud. Submitted-and-synced, the normal case, shows nothing extra.
  @override
  Widget build(BuildContext context) {
    final v = visit;
    final place = [v.county, v.subcounty].whereType<String>().where((s) => s.isNotEmpty);
    final pct = v.isDraft ? null : v.score.pct;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // Drafts open straight into the sections to carry on; submitted
        // visits open the visit page.
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => v.isDraft
                ? VisitHubScreen(visitId: v.id)
                : VisitDetailScreen(visitId: v.id))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.farmerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                const SizedBox(height: 3),
                Text(
                  [...place, Formatters.date(v.visitDate)].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            if (v.isDraft)
              Text('Draft · ${v.doneCount}/${VisitSection.values.length}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.amberText))
            else ...[
              if (v.hasPendingWrites)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Tooltip(
                    message: 'Waiting to sync',
                    child: Icon(Icons.cloud_upload_outlined,
                        size: 16, color: AppColors.amber),
                  ),
                ),
              Text(pct == null ? '—' : '$pct%',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ],
          ]),
        ),
      ),
    );
  }
}