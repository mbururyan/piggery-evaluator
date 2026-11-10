import 'package:flutter/material.dart';

import '../../widgets/empty_state.dart';
import '../../widgets/tab_header.dart';

/// Placeholder until the EO's own numbers are built (after the demo phases).
class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabHeader(title: 'Analytics'),
          Expanded(
            child: EmptyState(
              icon: Icons.bar_chart,
              message: 'Your visit numbers will appear here.',
            ),
          ),
        ],
      ),
    );
  }
}