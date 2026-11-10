import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/snackbars.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tab_header.dart';

/// Placeholder until Phase 1, which brings the live list of the EO's
/// assigned farmers. The header and search are already in their final
/// positions, so Phase 1 only fills in the list.
class FarmersTab extends StatelessWidget {
  const FarmersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabHeader(
            title: 'My farmers',
            // No count until Phase 1: a "· 0" here would look like a
            // real (and alarming) number.
            action: IconButton(
              tooltip: 'Register a new farmer',
              icon: const Icon(Icons.person_add_alt_1_outlined,
                  color: AppColors.red),
              onPressed: () => showInfoSnack(
                  context, 'Farmer registration arrives in Phase 1'),
            ),
          ),
          const SizedBox(height: 14),
          const TextField(
            enabled: false,
            decoration: InputDecoration(
              hintText: 'Search name, PF or phone…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const Expanded(
            child: EmptyState(
              icon: Icons.groups_outlined,
              message: 'Your assigned farmers will appear here.',
            ),
          ),
        ],
      ),
    );
  }
}