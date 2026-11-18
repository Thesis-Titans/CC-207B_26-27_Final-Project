import 'package:flutter/material.dart';

import '../../widgets/state_views.dart';

/// Explore tab. Skeleton only; the feature is built in issue #4.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyStateView(
      title: 'Explore',
      message: 'The age-aware activity catalog appears here.',
      icon: Icons.explore_outlined,
    );
  }
}
