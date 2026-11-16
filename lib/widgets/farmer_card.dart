import 'package:flutter/material.dart';

import '../models/farmer.dart';
import '../screens/farmer_detail_screen.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// One farmer in a list: the "avatar row" layout (variant B).
///
///   [AK]  Agnes Kawira Nkonge          Last visit
///         PF23240 · Nairobi · Roysambu      3 Nov
///         0725 249 525
///
/// Used by both My farmers and All farmers, so the two views look the
/// same; All farmers adds whose farmer it is to the third line.
class FarmerCard extends StatelessWidget {
  const FarmerCard({
    super.key,
    required this.farmer,
    required this.currentUid,
    this.showEo = false,
  });

  final Farmer farmer;

  /// Who's signed in: decides "EO: You" and whether the amber
  /// details-to-update dot shows (only the owner can fix it).
  final String? currentUid;

  /// True in All farmers.
  final bool showEo;

  bool get _isMine => farmer.assignedEoUid == currentUid;

  /// "AK" from "Agnes Kawira Nkonge": first and last word. One word -> its
  /// first two letters. Nothing usable -> "?".
  static String initials(String name) {
    final w = name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (w.isEmpty) return '?';
    if (w.length == 1) {
      return w.first.substring(0, w.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (w.first[0] + w.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final lastVisit = farmer.summary?.lastVisitDate;
    final needsUpdate = _isMine && farmer.needsUpdate.isNotEmpty;

    // Line 2: PF (or a quiet "No PF") and where they are.
    final line2 = [
      farmer.pfNumber ?? 'No PF',
      farmer.location.isEmpty ? 'No location' : farmer.location.short,
    ].join(' · ');

    // Line 3: phone, plus whose farmer it is in All farmers.
    final line3 = [
      if (farmer.mobile.isNotEmpty) Formatters.displayPhone(farmer.mobile),
      if (showEo)
        'EO: ${_isMine ? 'You' : (farmer.assignedEoName.isEmpty ? '—' : farmer.assignedEoName)}',
    ].join(' · ');

    final radius = BorderRadius.circular(14);

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: AppShadows.card),
      child: Material(
        color: AppColors.white,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FarmerDetailScreen(farmerId: farmer.id))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(
              children: [
                _Avatar(text: initials(farmer.name), alert: needsUpdate),
                const SizedBox(width: 11),

                // --- Middle: who and where ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              farmer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink),
                            ),
                          ),
                          if (farmer.hasPendingWrites) ...[
                            const SizedBox(width: 5),
                            const Tooltip(
                              message: 'Not synced yet',
                              child: Icon(Icons.cloud_upload_outlined,
                                  size: 14, color: AppColors.amber),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      _meta(line2),
                      if (line3.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        _meta(line3),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // --- Right: the visit story ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: lastVisit == null
                      ? const [
                          Text('Not visited',
                              style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        ]
                      : [
                          const Text('Last visit',
                              style: TextStyle(fontSize: 10.5, color: AppColors.muted)),
                          const SizedBox(height: 1),
                          Text(
                            Formatters.relativeDate(lastVisit),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink),
                          ),
                        ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _meta(String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
      );
}

/// Initials in a red-tint circle. The amber dot = details to update.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.text, required this.alert});

  final String text;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppColors.redTint),
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.redDark)),
          ),
          if (alert)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.amber,
                  // White ring so the dot reads against the red tint.
                  border: Border.all(color: AppColors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}