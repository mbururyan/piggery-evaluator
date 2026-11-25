import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/farmer.dart';
import '../models/visit.dart';
import '../services/pdf_report.dart';
import '../services/report_mail.dart';
import '../services/visit_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

const _mon = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "My reports", from the drawer: the farm visit PDFs of every visit this
/// EO has submitted, by week, to view, re-share or email again.
///
/// Nothing is stored (Ryan, 25 Nov): each PDF is built on the phone when
/// it's opened, exactly like Export PDF on a visit. So it works offline,
/// costs nothing, and a visit edited within its 7 days always shows its
/// latest answers.
class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final _visits = VisitService.instance.myVisits();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.page,
        foregroundColor: AppColors.ink,
        titleSpacing: 0,
        title: const Text('FV Reports (PDF)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
          child: TextField(
            onChanged: (q) => setState(() => _query = q.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search farmer',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Visit>>(
            stream: _visits,
            builder: (context, snap) {
              final all = snap.data;
              if (all == null) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
              }
              // Drafts have no report yet: the PDF is what Submit produces.
              final reports = all
                  .where((v) => !v.isDraft)
                  .where((v) => _query.isEmpty || v.farmerName.toLowerCase().contains(_query))
                  .toList()
                ..sort((a, b) => b.visitDate.compareTo(a.visitDate));
              if (reports.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _query.isEmpty
                          ? 'Reports appear here once you submit a visit.'
                          : 'No reports for "$_query".',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ),
                );
              }
              return _list(reports);
            },
          ),
        ),
      ]),
    );
  }

  /// Monday of [d]'s week, the same Mon–Sat weeks as the Visits tab.
  static DateTime _monday(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

  Widget _list(List<Visit> reports) {
    final items = <Widget>[];
    DateTime? week;
    for (final v in reports) {
      final m = _monday(v.visitDate);
      if (m != week) {
        week = m;
        final n = reports.where((r) => _monday(r.visitDate) == m).length;
        items.add(_weekHeader(m, n));
      }
      items.add(_row(v));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 24), children: items);
  }

  Widget _weekHeader(DateTime monday, int count) {
    final sat = DateTime(monday.year, monday.month, monday.day + 5);
    final days = monday.month == sat.month
        ? '${monday.day}–${sat.day} ${_mon[sat.month - 1]}'
        : '${monday.day} ${_mon[monday.month - 1]} – ${sat.day} ${_mon[sat.month - 1]}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
      child: Row(children: [
        Text('Week ${Formatters.isoWeek(monday)}',
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
        Text('  ·  $days', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const Spacer(),
        Text('$count ${count == 1 ? 'report' : 'reports'}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
      ]),
    );
  }

  Widget _row(Visit v) {
    final pct = v.score.pct;
    final place = v.subcounty?.trim() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.card,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _actions(v),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 22, color: AppColors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.farmerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                Text(
                  place.isEmpty
                      ? Formatters.date(v.visitDate)
                      : '${Formatters.date(v.visitDate)}  ·  $place',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ]),
            ),
            if (pct != null)
              Text('$pct%',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(width: 4),
            const Icon(Icons.more_vert, size: 18, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }

  /// The three things an EO does with a report, in one sheet.
  Future<void> _actions(Visit v) async {
    // The farmer's record holds the phone (printed on the PDF) and the
    // email address. From the phone's cache, so near-instant, even offline.
    final farmer = await ReportMail.farmerOf(v.farmerId);
    if (!mounted) return;
    final address = ReportMail.addressOf(farmer);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                Expanded(
                  child: Text(v.farmerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                ),
                Text(Formatters.date(v.visitDate),
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('View report'),
              onTap: () {
                Navigator.of(sheet).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ReportViewScreen(visit: v, phone: farmer?.mobile)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share PDF'),
              subtitle: const Text('WhatsApp, Gmail, Drive…'),
              onTap: () {
                Navigator.of(sheet).pop();
                _share(v, farmer);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Email to farmer'),
              // Shown greyed rather than hidden, so the EO knows why it
              // can't be emailed and can add the address on the next visit.
              subtitle: Text(address ?? 'No email on record'),
              enabled: address != null,
              onTap: address == null
                  ? null
                  : () {
                      Navigator.of(sheet).pop();
                      _email(v, farmer, address);
                    },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _share(Visit v, Farmer? farmer) async {
    try {
      await PdfReport.share(v, phone: farmer?.mobile);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't make the PDF. Please try again.")));
    }
  }

  /// Same flow as "Email again" on the visit page: ask first, because the
  /// farmer already got this report on Submit.
  Future<void> _email(Visit v, Farmer? farmer, String address) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text('Email the report again?', style: TextStyle(fontSize: 17)),
        content: Text('A new copy goes to $address.',
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final text = ReportMail.message(await ReportMail.queue(v, farmer));
    if (!mounted || text == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

/// One report on screen, from the printing package's viewer: pinch to
/// zoom, plus its own share and print buttons along the bottom.
class ReportViewScreen extends StatelessWidget {
  const ReportViewScreen({super.key, required this.visit, this.phone});

  final Visit visit;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.page,
        foregroundColor: AppColors.ink,
        titleSpacing: 0,
        title: Text(visit.farmerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: PdfPreview(
        build: (_) => PdfReport.build(visit, phone: phone),
        pdfFileName: PdfReport.filenameFor(visit),
        // The report is always A4 portrait; letting an EO switch to
        // Letter or landscape would only produce a broken layout.
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
      ),
    );
  }
}