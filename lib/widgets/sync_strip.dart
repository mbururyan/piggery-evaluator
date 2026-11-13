import 'package:flutter/material.dart';

import '../services/sync_service.dart';
import '../theme/app_theme.dart';

/// The Home strip that tells an EO whether their work has reached the
/// server. Green when everything has synced; amber and open, listing each
/// item, while anything is still waiting.
class SyncStrip extends StatefulWidget {
  const SyncStrip({super.key});

  @override
  State<SyncStrip> createState() => _SyncStripState();
}

class _SyncStripState extends State<SyncStrip> {
  /// The EO's own open/closed choice. Null = they haven't touched it, so
  /// pending work shows itself. Same reasoning as RE: the list is why the
  /// strip exists, and hiding it behind a tap meant an EO could leave
  /// signal without ever seeing what hadn't gone.
  bool? _userToggled;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: SyncService.instance.status,
      builder: (context, status, _) {
        final synced = status.allSynced;
        final n = status.count;

        // Once everything syncs, forget the EO's choice, so the next
        // queue opens by itself again.
        if (synced) _userToggled = null;
        final expanded = !synced && (_userToggled ?? true);

        final radius = BorderRadius.circular(10);

        return Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: radius,
            boxShadow: AppShadows.card,
            // Amber outline while waiting: noticeable without shouting.
            border: synced ? null : Border.all(color: AppColors.amber),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                InkWell(
                  borderRadius: radius,
                  // Nothing to open when everything has synced.
                  onTap: synced
                      ? null
                      : () => setState(() => _userToggled = !expanded),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Row(
                      children: [
                        Icon(
                          synced
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_upload_outlined,
                          size: 16,
                          color: synced ? AppColors.green : AppColors.amber,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          synced
                              ? 'All work synced'
                              : '$n ${n == 1 ? 'item' : 'items'} pending',
                          style:
                              const TextStyle(fontSize: 12, color: AppColors.ink),
                        ),
                        const Spacer(),
                        Text(
                          status.offline ? 'offline' : 'online',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted),
                        ),
                        if (!synced)
                          Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                            color: AppColors.muted,
                          ),
                      ],
                    ),
                  ),
                ),
                if (expanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(
                            height: 10, thickness: 0.5, color: AppColors.line),
                        for (final p in status.pending)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text('· ${p.label}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.muted)),
                          ),
                        const SizedBox(height: 4),
                        const Text(
                          'Saved on this phone. Syncs automatically when back online.',
                          style: TextStyle(fontSize: 11, color: AppColors.green),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}