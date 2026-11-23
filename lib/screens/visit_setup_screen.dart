import 'package:flutter/material.dart';

import '../models/farmer.dart';
import '../services/auth_service.dart';
import '../services/farmer_service.dart';
import '../services/visit_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/farmer_card.dart';
import 'register_farmer_screen.dart';
import 'visit_hub_screen.dart';

/// "Start a visit": pick the date, deal with missing farmer details, then
/// open (or resume) the draft.
class VisitSetupScreen extends StatefulWidget {
  const VisitSetupScreen({super.key, required this.farmerId});

  final String farmerId;

  @override
  State<VisitSetupScreen> createState() => _VisitSetupScreenState();
}

class _VisitSetupScreenState extends State<VisitSetupScreen> {
  DateTime _date = _today();
  bool _starting = false;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Up to 7 days back for visits entered late, never in the future. The
  /// rules check the same thing on the server.
  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 7)),
      lastDate: today,
      helpText: 'When did the visit happen?',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _start(Farmer farmer) async {
    setState(() => _starting = true);
    final service = VisitService.instance;

    // Draft guard: resume this EO's unfinished visit to this farmer rather
    // than starting a second one (Ranch Evaluator's rule).
    final existing = await service.openDraftFor(farmer.id);
    if (!mounted) return;
    if (existing != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (dCtx) => AlertDialog(
          backgroundColor: AppColors.white,
          title: const Text('Unfinished visit',
              style: TextStyle(fontSize: 17)),
          content: Text(
            'You already started a visit to ${farmer.name} on '
            '${Formatters.date(existing.visitDate)} '
            '(${existing.startedCount} of 9 sections started).',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop('new'),
              child: const Text('Discard it, start new',
                  style: TextStyle(color: AppColors.alert)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => Navigator.of(dCtx).pop('resume'),
              child: const Text('Resume'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == null) {
        setState(() => _starting = false);
        return;
      }
      if (choice == 'resume') {
        _openHub(existing.id);
        return;
      }
      service.deleteDraft(existing.id);
    }

    final id = await service.startDraft(farmer: farmer, visitDate: _date);
    if (!mounted) return;
    _openHub(id);
  }

  // pushReplacement: Back from the hub returns to wherever the visit was
  // started from, not to this setup screen.
  void _openHub(String id) => Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => VisitHubScreen(visitId: id)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.page,
        foregroundColor: AppColors.ink,
        title: const Text('Start a visit',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: StreamBuilder<Farmer?>(
          stream: FarmerService.instance.watch(widget.farmerId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
            }
            final farmer = snap.data;
            if (farmer == null) {
              return const EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Farmer not on this phone',
                message: 'Connect and try again.',
              );
            }
            return _body(farmer);
          },
        ),
      ),
    );
  }

  Widget _body(Farmer farmer) {
    final uid = AuthService.instance.currentUser?.uid;
    final isOwner = farmer.assignedEoUid == uid;
    final needs = farmer.needsUpdate;

    // Location must be on the farmer before the visit, or the visit has no
    // county for projections. Only the owner can fix it; a colleague
    // covering can still go ahead (the owner is asked to update later).
    final blocking = isOwner &&
        (needs.contains('location') ||
            (needs.contains('phone') && farmer.mobile.isEmpty));

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: [
        // Same card as the lists, so the EO recognises the farmer.
        IgnorePointer(child: FarmerCard(farmer: farmer, currentUid: uid)),
        const SizedBox(height: 12),

        _Panel(children: [
          const Text('Visit date',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
              child: Text(
                _date == _today()
                    ? 'Today · ${Formatters.date(_date)}'
                    : Formatters.date(_date),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Can be set up to 7 days back if you\'re entering a visit late.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ]),
        const SizedBox(height: 12),

        if (needs.isNotEmpty) ...[
          _NeedsPrompt(
            farmer: farmer,
            isOwner: isOwner,
            blocking: blocking,
          ),
          const SizedBox(height: 12),
        ],

        if (farmer.summary?.lastVisitDate != null) ...[
          _Panel(children: [
            Text(
              'Last visit · ${Formatters.date(farmer.summary!.lastVisitDate)}'
              '${farmer.summary!.lastEoName == null ? '' : ' · by ${farmer.summary!.lastEoName}'}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 3),
            Text(
                farmer.summary!.scorePct == null
                    ? 'No score'
                    : 'Score ${farmer.summary!.scorePct}%',
                style: const TextStyle(fontSize: 13)),
          ]),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: (blocking || _starting) ? null : () => _start(farmer),
          child: _starting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.white))
              : const Text('Start visit'),
        ),
        const SizedBox(height: 8),
        Text(
          blocking
              ? 'Update the required details above first.'
              : 'Saved as a draft on this phone as you go.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 11,
              color: blocking ? AppColors.amberText : AppColors.muted),
        ),
      ],
    );
  }
}

/// The "details to update" box before a visit.
class _NeedsPrompt extends StatelessWidget {
  const _NeedsPrompt({
    required this.farmer,
    required this.isOwner,
    required this.blocking,
  });

  final Farmer farmer;
  final bool isOwner;
  final bool blocking;

  @override
  Widget build(BuildContext context) {
    final needs = farmer.needsUpdate;
    final lines = <String>[
      if (needs.contains('location')) 'County and sub-county (required)',
      if (needs.contains('phone'))
        farmer.mobile.isEmpty
            ? 'Mobile number (required)'
            : 'Mobile number: shared with another farmer, please confirm',
      if (needs.contains('id')) 'ID number (optional)',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amberTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Before you start: details to update',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.amberText)),
          const SizedBox(height: 4),
          for (final l in lines)
            Text('· $l',
                style: const TextStyle(fontSize: 12, color: AppColors.amberText)),
          const SizedBox(height: 8),
          if (isOwner)
            Row(children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.amberText,
                  side: const BorderSide(color: AppColors.amber),
                  backgroundColor: AppColors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RegisterFarmerScreen(existing: farmer))),
                child: const Text('Update now'),
              ),
              if (!blocking) ...[
                const SizedBox(width: 10),
                // Nothing required is missing, so the EO may just start.
                // (Saving the edit form clears "id" for good: ask-once.)
                const Expanded(
                  child: Text('Optional: you can start without it',
                      style: TextStyle(fontSize: 11.5, color: AppColors.amberText)),
                ),
              ],
            ])
          else
            Text(
              'Only ${farmer.assignedEoName.isEmpty ? 'their EO' : farmer.assignedEoName} '
              'can update these. You can still record the visit.',
              style: const TextStyle(fontSize: 11.5, color: AppColors.amberText),
            ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.card,
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}