import 'package:flutter/material.dart';

import '../../widgets/state_views.dart';

/// This week tab. Skeleton only; the feature is built in issue #8.
class WeeklySummaryScreen extends StatelessWidget {
  const WeeklySummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyStateView(
      title: 'This week',
      message: 'The weekly reflection appears here.',
      icon: Icons.insights_outlined,
    );
  }
}
