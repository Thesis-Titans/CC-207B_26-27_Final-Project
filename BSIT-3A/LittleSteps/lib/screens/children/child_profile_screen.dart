import 'package:flutter/material.dart';

import '../../widgets/state_views.dart';

/// Children screen. Skeleton only; the feature is built in issue #3.
class ChildProfileScreen extends StatelessWidget {
  const ChildProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Children')),
      body: const EmptyStateView(
        title: 'Children',
        message: 'Child profiles and the switcher appear here.',
        icon: Icons.people_outline,
      ),
    );
  }
}
