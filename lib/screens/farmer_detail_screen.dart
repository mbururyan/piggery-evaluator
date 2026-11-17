import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/farmer.dart';
import '../services/auth_service.dart';
import '../services/farmer_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/snackbars.dart';
import '../widgets/empty_state.dart';
import 'register_farmer_screen.dart';
import 'visit_setup_screen.dart';

/// One farmer's page, pushed over the shell.
///
/// Takes an ID, not a Farmer object, because it's opened from three
/// places (the list, a duplicate warning, and straight after registering)
/// and must always show the live document: an edit appears here the
/// moment it's saved, offline included.
class FarmerDetailScreen extends StatelessWidget {
  const FarmerDetailScreen({super.key, required this.farmerId});

  final String farmerId;

  Future<void> _call(BuildContext context, String mobile) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: mobile));
    if (!ok && context.mounted) {
      showInfoSnack(context, 'Could not open the phone app');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Farmer?>(
      stream: FarmerService.instance.watch(farmerId),
      builder: (context, snap) {
        final farmer = snap.data;
        final uid = AuthService.instance.currentUser?.uid;
        // Only the farmer's own EO edits them (contact + location only);
        // everything else belongs to the office.
        final canEdit = farmer != null && farmer.assignedEoUid == uid;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.page,
            foregroundColor: AppColors.ink,
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              if (canEdit)
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => RegisterFarmerScreen(existing: farmer))),
                  child: const Text('Edit'),
                ),
            ],
          ),
          body: SafeArea(child: _body(context, snap, farmer)),
        );
      },
    );
  }

  Widget _body(
      BuildContext context, AsyncSnapshot<Farmer?> snap, Farmer? farmer) {
    if (snap.hasError) {
      return const EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load this farmer',
        message: 'Check your connection and try again.',
      );
    }
    if (snap.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (farmer == null) {
      // Usually another EO's farmer opened from a duplicate warning while
      // offline: it was never cached on this phone.
      return const EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Not on this phone',
        message: "This farmer isn't saved offline. Connect and try again.",
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Name + PF status ---
          Text(farmer.name,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 6),
          Row(
            children: [
              // No PF is shown quietly: the EO can't assign one (the office
              // does, from the web queue), so it isn't an amber "act now".
              _Pill(
                text: farmer.pfNumber ?? 'No PF',
                fg: farmer.pfNumber == null ? AppColors.muted : AppColors.green,
                bg: farmer.pfNumber == null ? AppColors.line : AppColors.greenTint,
              ),
              if (farmer.hasPendingWrites) ...[
                const SizedBox(width: 8),
                const Icon(Icons.cloud_upload_outlined,
                    size: 15, color: AppColors.amber),
                const SizedBox(width: 3),
                const Text('Not synced yet',
                    style: TextStyle(fontSize: 11.5, color: AppColors.amberText)),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // --- Missing details from the old app (seed farmers) ---
          if (farmer.needsUpdate.isNotEmpty) ...[
            _NeedsUpdateBanner(
              needs: farmer.needsUpdate,
              // Only the farmer's own EO can fix it; others just see it.
              onUpdate: farmer.assignedEoUid == AuthService.instance.currentUser?.uid
                  ? () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => RegisterFarmerScreen(existing: farmer)))
                  : null,
            ),
            const SizedBox(height: 16),
          ],

          // --- Details card ---
          _Card(children: [
            farmer.mobile.isEmpty
                ? const _Row('Mobile', '—')
                : _Row(
                    'Mobile',
                    Formatters.displayPhone(farmer.mobile),
                    onTap: () => _call(context, farmer.mobile),
                  ),
            _Row('ID number', farmer.idNumber ?? '—'),
            _Row('Email', farmer.email ?? '—'),
            _Row('Location',
                farmer.location.isEmpty ? '—' : farmer.location.full),
            _Row('Assigned EO',
                farmer.assignedEoName.isEmpty ? '—' : farmer.assignedEoName),
            if (farmer.previousEoName != null)
              _Row('Previous EO', farmer.previousEoName!),
            _Row('Registered', Formatters.date(farmer.registeredAt), last: true),
          ]),
          const SizedBox(height: 16),

          // --- Visits (filled in by the Phase 3 Cloud Function) ---
          _VisitSummary(summary: farmer.summary),
          const SizedBox(height: 20),

          // Open to every EO, not only the owner: a colleague covering an
          // area can record the visit (the farmer stays assigned).
          _StartVisitButton(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VisitSetupScreen(farmerId: farmer.id))),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.onTap, this.last = false});

  final String label;
  final String value;

  /// When set, the value shows in red with a phone icon and is tappable.
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      value,
      textAlign: TextAlign.right,
      style: TextStyle(
          fontSize: 13,
          color: onTap == null ? AppColors.ink : AppColors.red,
          fontWeight: onTap == null ? FontWeight.w400 : FontWeight.w600),
    );

    return Container(
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(width: 12),
          Expanded(
            child: onTap == null
                ? valueText
                : InkWell(
                    onTap: onTap,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        valueText,
                        const SizedBox(width: 6),
                        const Icon(Icons.call, size: 16, color: AppColors.red),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.fg, required this.bg});
  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

/// Last-visit numbers once the Cloud Function writes them; until then a
/// plain "no visits yet" card, so the page doesn't look broken.
class _VisitSummary extends StatelessWidget {
  const _VisitSummary({required this.summary});
  final FarmerSummary? summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    if (s == null || s.lastVisitDate == null) {
      return const _Card(children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Icon(Icons.assignment_outlined, size: 18, color: AppColors.muted),
            SizedBox(width: 10),
            Expanded(
              child: Text('No visits yet. Visit history appears here after the first one.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ),
          ]),
        ),
      ]);
    }

    Widget stat(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.page, borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text(value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text(label,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
            ]),
          ),
        );

    return _Card(children: [
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Last visit · ${Formatters.date(s.lastVisitDate)}'
            '${s.lastEoName == null ? '' : ' · by ${s.lastEoName}'}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          stat(s.sows?.toString() ?? '—', 'sows'),
          const SizedBox(width: 8),
          stat(s.scorePct == null ? '—' : '${s.scorePct}%', 'score'),
          const SizedBox(width: 8),
          stat('${s.visitCount}', 'visits'),
        ]),
      ),
    ]);
  }
}

/// Same red gradient as Home's hero card, painted with Ink so the tap
/// ripple shows on top of it.
class _StartVisitButton extends StatelessWidget {
  const _StartVisitButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            colors: [AppColors.red, AppColors.redDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.post_add, color: AppColors.white, size: 20),
                SizedBox(width: 8),
                Text('Start a visit',
                    style: TextStyle(
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Amber box listing details the old app never captured. Tapping
/// "Update details" opens the edit form; saving it clears what was fixed.
/// In Phase 2 the same prompt also appears when a visit starts.
class _NeedsUpdateBanner extends StatelessWidget {
  const _NeedsUpdateBanner({required this.needs, required this.onUpdate});

  final List<String> needs;

  /// Null for someone else's farmer: the banner shows, but no button.
  final VoidCallback? onUpdate;

  static const _labels = {
    'location': 'County and sub-county',
    'phone': 'Mobile number (missing or shared with another farmer)',
    'id': 'ID number (optional)',
  };

  @override
  Widget build(BuildContext context) {
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
          const Text('Details to update',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.amberText)),
          const SizedBox(height: 4),
          for (final n in needs)
            Text('· ${_labels[n] ?? n}',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.amberText)),
          if (onUpdate != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.amberText,
                  side: const BorderSide(color: AppColors.amber),
                  backgroundColor: AppColors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onUpdate,
                child: const Text('Update details'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}