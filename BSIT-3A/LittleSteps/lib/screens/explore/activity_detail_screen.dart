import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/state_views.dart';

/// Screen displaying full activity instructions, required materials, and learning guidance.
class ActivityDetailScreen extends StatelessWidget {
  /// Creates an [ActivityDetailScreen] for [activity].
  const ActivityDetailScreen({super.key, required this.activity});

  /// Activity to show.
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(activity.title)),
      body: const ResponsiveContentBox(
        child: EmptyStateView(
          title: 'Activity detail',
          message: 'Steps, materials and safety notes appear here.',
          icon: Icons.extension_outlined,
        ),
      ),
    );
  }
}
