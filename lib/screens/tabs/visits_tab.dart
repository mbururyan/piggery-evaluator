import 'package:flutter/material.dart';

import '../../widgets/empty_state.dart';
import '../../widgets/tab_header.dart';

/// Placeholder until Phase 2 brings the EO's submitted visits.
class VisitsTab extends StatelessWidget {
  const VisitsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabHeader(title: 'My visits'),
          Expanded(
            child: EmptyState(
              icon: Icons.assignment_outlined,
              message: 'Visits you submit will appear here.',
            ),
          ),
        ],
      ),
    );
  }
}