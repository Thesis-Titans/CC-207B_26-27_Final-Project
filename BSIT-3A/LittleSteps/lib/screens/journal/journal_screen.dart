import 'package:flutter/material.dart';

import '../../widgets/state_views.dart';

/// Journal tab. Skeleton only; the feature is built in issue #7.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyStateView(
      title: 'Journal',
      message: 'Private observation notes appear here.',
      icon: Icons.book_outlined,
    );
  }
}
