import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // The EO's first name is added in 2c, once SessionService exists.
        Text(
          _greeting(now),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        // "—" until Phase 1 gives us a real count of assigned farmers.
        Text(
          '${_dateLabel(now)} · — assigned farmers',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 16),

        // The sync strip slots in here in 2d.

        _ActionCard(
          primary: true,
          title: 'Start a farm visit',
          subtitle: 'Pick a farmer, then fill sections in any order',
          onTap: () => _comingSoon(context, 'Farm visits arrive in Phase 2'),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          primary: false,
          title: 'Register a new farmer',
          subtitle: 'Visit them right away; the office assigns the PF',
          onTap: () =>
              _comingSoon(context, 'Farmer registration arrives in Phase 1'),
        ),
      ],
    );
  }

  static String _greeting(DateTime t) {
    if (t.hour < 12) return 'Good morning';
    if (t.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // Hand-rolled "Mon 9 Nov" so we don't pull in the intl package for one
  // label. When real dates show up (visit dates, follow-ups), this moves to
  // intl's DateFormat.
  static String _dateLabel(DateTime t) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${days[t.weekday - 1]} ${t.day} ${months[t.month - 1]}';
  }

  static void _comingSoon(BuildContext context, String message) {
    // Hide any snackbar already showing, so tapping a card five times
    // doesn't queue up five snackbars.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The two big Home buttons. Primary = solid red, secondary = red outline.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.primary,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool primary;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      // BorderSide.none rather than width 0: in Flutter, width 0 still draws
      // a 1px hairline.
      side: primary
          ? BorderSide.none
          : const BorderSide(color: AppColors.red, width: 1.5),
    );
    final titleColor = primary ? AppColors.white : AppColors.red;
    final subColor = primary ? AppColors.redTint : AppColors.muted;

    // Material + InkWell instead of a plain Container, so the tap ripple is
    // drawn inside the rounded corners instead of spilling past them.
    return Material(
      color: primary ? AppColors.red : AppColors.white,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.5, color: subColor),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: titleColor),
            ],
          ),
        ),
      ),
    );
  }
}