import 'package:flutter/material.dart';

import '../../widgets/state_views.dart';

/// Milestones tab. Skeleton only; the feature is built in issue #6.
class MilestonesScreen extends StatelessWidget {
  const MilestonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyStateView(
      title: 'Milestones',
      message: 'Observation prompts appear here.',
      icon: Icons.flag_outlined,
    );
  }
}
