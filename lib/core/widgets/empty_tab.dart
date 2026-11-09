import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Placeholder body for tabs that aren't built yet (Farmers, Visits,
/// Analytics). Each one gets replaced by its real screen in a later phase.
class EmptyTab extends StatelessWidget {
  const EmptyTab({
    super.key,
    required this.icon,
    required this.message,
    this.searchHint,
  });

  final IconData icon;
  final String message;

  /// When set, a disabled search field sits on top, so the layout already
  /// matches what the real list screen will look like.
  final String? searchHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (searchHint != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: searchHint,
                prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                // Pill-shaped search, unlike the squarer form fields.
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
              ),
            ),
          ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: AppColors.muted),
                  const SizedBox(height: 12),
                  const Text(
                    'Nothing here yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}