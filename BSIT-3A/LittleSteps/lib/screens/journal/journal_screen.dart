import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/state_views.dart';

/// Journal navigation tab displaying private caregiver observations and reflections.
class JournalScreen extends StatelessWidget {
  /// Creates a [JournalScreen].
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space16),
      children: const [
        ScreenHeader(
          title: 'Journal',
          subtitle:
              'Private notes and everyday moments you choose to remember.',
        ),
        SizedBox(height: AppSpacing.space24),
        EmptyStateView(
          title: 'No journal notes yet',
          message: 'Private observation notes appear here.',
          icon: Icons.book_outlined,
        ),
      ],
    );
  }
}
