import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The small red-tint pill showing the role ("EO", "Admin"). Used on the
/// Home header and in the drawer.
class RolePill extends StatelessWidget {
  const RolePill({super.key, required this.label, this.small = false});

  final String label;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 8 : 10, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: AppColors.redTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: small ? 11 : 12, color: AppColors.redDark),
      ),
    );
  }
}