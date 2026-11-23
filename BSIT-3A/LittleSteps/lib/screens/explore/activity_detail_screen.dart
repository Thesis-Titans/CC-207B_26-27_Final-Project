import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../widgets/state_views.dart';

/// Screen displaying full activity instructions, required materials, and learning guidance.
class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({super.key, required this.activity});

  /// Activity to show.
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(activity.title)),
      body: const EmptyStateView(
        title: 'Activity detail',
        message: 'Steps, materials and safety notes appear here.',
        icon: Icons.extension_outlined,
      ),
    );
  }
}
