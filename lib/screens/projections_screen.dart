import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

import '../models/farmer.dart';
import '../services/due_visits.dart';
import '../services/farmer_service.dart';
import '../services/projection_export.dart';
import '../services/projections.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import 'due_visits_screen.dart';
import 'farmer_detail_screen.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "Projections", from the drawer: pigs reaching market age (7 months) per
/// month across the EO's own farmers, this month and the four after it.
///
/// Built from each farmer's summary (written by the Cloud Function), not
/// from visits: the phone only caches its EO's own visits, and a farm's
/// latest count may be a predecessor's or a paper one.
class ProjectionsScreen extends StatefulWidget {
  const ProjectionsScreen({super.key});

  @override
  State<ProjectionsScreen> createState() => _ProjectionsScreenState();
}

class _ProjectionsScreenState extends State<ProjectionsScreen> {
  final _farmers = FarmerService.instance.myFarmers();

  /// Which month rows are open, by position. Several can be open at once,
  /// so two months' farms can be compared side by side while scrolling.
  final _open = <int>{};

  /// True while the workbook is being built, so a second tap can't start
  /// a second export.
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    // The stream sits outside the Scaffold so the app bar's Excel button
    // exports exactly the numbers on screen.
    return StreamBuilder<List<Farmer>>(
      stream: _farmers,
      builder: (context, snap) {
        final farmers = snap.data;
        // The same limit as "Due for a visit", so "over 4 months old"
        // here and the drawer's count always agree.
        final staleMonths = DueVisitsService.instance.due.value?.months ?? 4;
        final p = farmers == null
            ? null
            : Projections.compute(farmers, now: DateTime.now(), staleMonths: staleMonths);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.page,
            foregroundColor: AppColors.ink,
            titleSpacing: 0,
            title: const Text('Projections',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            actions: [
              if (p != null && p.countedFarms > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: TextButton.icon(
                    onPressed: _exporting ? null : () => _export(p, staleMonths),
                    icon: _exporting
                        ? const SizedBox.square(
                            dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('Excel',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
          body: p == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
              : _body(p, staleMonths),
        );
      },
    );
  }

  Future<void> _export(Projections p, int staleMonths) async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ProjectionExport.share(p, staleMonths: staleMonths);
    } catch (e, st) {
      // Same as the PDF export: tell the EO, and send the details to
      // Crashlytics so the real error can be seen.
      FirebaseCrashlytics.instance.recordError(e, st, reason: 'Projections Excel export');
      messenger.showSnackBar(const SnackBar(
          content: Text("Couldn't make the Excel file. Please try again.")));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _body(Projections p, int staleMonths) {
    final first = p.months.first.month;
    final last = p.months.last.month;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: [
        const Text(
          "Pigs reaching ${Projections.readyAge} months, from each of your farms' latest count.",
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        if (p.countedFarms == 0)
          _card(const Text(
            'No counts yet. Projections appear once your farms have a submitted visit.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ))
        else ...[
          _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(
                child: Text('Pigs ready for market',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
              ),
              Text('${p.totalPigs} by ${_monthNames[last.month - 1].substring(0, 3)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
            const SizedBox(height: 2),
            Text('From ${p.countedFarms} ${p.countedFarms == 1 ? 'farm' : 'farms'}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            const SizedBox(height: 10),
            VBarChart(bars: [
              for (final m in p.months)
                BarDatum(_monthNames[m.month.month - 1].substring(0, 3), m.pigs,
                    highlight: m.month == first),
            ]),
          ])),
          for (var i = 0; i < p.months.length; i++) _monthRow(i, p.months[i], i == 0),
          const SizedBox(height: 4),
          _notes(p, staleMonths, first, last),
        ],
      ],
    );
  }

  /// A month's total; tap to see which farms make it up.
  Widget _monthRow(int i, ProjectedMonth m, bool isThisMonth) {
    final open = _open.contains(i);
    final name = '${_monthNames[m.month.month - 1]} ${m.month.year}';
    // A long list helps nobody on a phone: the biggest ten, then a count.
    const shown = 10;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.card,
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: m.farms.isEmpty
              ? null
              : () => setState(() => open ? _open.remove(i) : _open.add(i)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  Text(
                    isThisMonth
                        ? 'This month'
                        : '${m.farms.length} ${m.farms.length == 1 ? 'farm' : 'farms'}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ]),
              ),
              Text('${m.pigs}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const Text(' pigs', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(width: 4),
              Icon(open ? Icons.expand_less : Icons.expand_more,
                  size: 20, color: m.farms.isEmpty ? AppColors.line : AppColors.muted),
            ]),
          ),
        ),
        if (open) ...[
          const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final (f, pigs) in m.farms.take(shown))
                HBarRow(
                  label: f.name,
                  fraction: pigs / m.farms.first.$2,
                  value: '$pigs',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FarmerDetailScreen(farmerId: f.id))),
                ),
              if (m.farms.length > shown)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+ ${m.farms.length - shown} more farms, '
                    '${m.farms.skip(shown).fold<int>(0, (n, e) => n + e.$2)} pigs',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ),
            ]),
          ),
        ],
      ]),
    );
  }

  /// What the numbers leave out. Plain sentences: these are the questions
  /// a manager asks first when shown a forecast.
  Widget _notes(Projections p, int staleMonths, DateTime first, DateTime last) {
    final firstName = _monthNames[first.month - 1];
    final lastName = _monthNames[last.month - 1];
    final lines = <Widget>[
      if (p.staleFarms > 0)
        _note(
          '${p.staleFarms} of ${p.countedFarms} farms were last counted over '
          '$staleMonths months ago. Still included, but those numbers are the '
          'least reliable.',
          action: TextButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const DueVisitsScreen())),
            child: const Text("See who's due",
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ),
      if (p.pastPigs > 0)
        _note('${p.pastPigs} pigs from older counts were ready before $firstName. '
            "Left out: they've most likely gone."),
      if (p.laterPigs > 0)
        _note('${p.laterPigs} younger pigs will be ready after $lastName.'),
      if (p.uncountedFarms > 0)
        _note('${p.uncountedFarms} of your farms have no count yet and are not included.'),
      _note('Litters born after a visit are not counted, so later months will '
          'turn out higher than shown.'),
      _note('These are pigs reaching market age, not confirmed deliveries to FCL.'),
    ];
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('About these numbers',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
      const SizedBox(height: 6),
      ...lines,
    ]));
  }

  Widget _note(String text, {Widget? action}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 6, right: 8),
              child: Icon(Icons.circle, size: 5, color: AppColors.muted),
            ),
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.ink)),
            ),
          ]),
          if (action != null) Align(alignment: Alignment.centerRight, child: action),
        ]),
      );

  Widget _card(Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.card,
        ),
        child: child,
      );
}