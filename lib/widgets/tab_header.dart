import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The in-page title row used instead of an app bar: "My farmers · 260"
/// with an optional action icon on the right. Same pattern as RE's
/// "Farms · 28" header. Home has its own header (greeting + role pill).
class TabHeader extends StatelessWidget {
  const TabHeader({
    super.key,
    required this.title,
    this.count,
    this.action,
  });

  final String title;

  /// Shown muted after the title. Null hides it (e.g. before data loads).
  final int? count;

  /// Usually an IconButton.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // Fixed height so the title sits at the same spot on every tab,
    // whether or not that tab has an action button. Without it, tabs
    // with no button would jump up a few pixels when you switch.
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text(
              '· $count',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}