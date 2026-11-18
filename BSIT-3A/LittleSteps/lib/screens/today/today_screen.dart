import 'package:flutter/material.dart';

import '../../widgets/state_views.dart';

/// Today tab. Skeleton only; the feature is built in issue #5.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyStateView(
      title: 'Today',
      message: 'Planned activities and weather hint appear here.',
      icon: Icons.today_outlined,
    );
  }
}
