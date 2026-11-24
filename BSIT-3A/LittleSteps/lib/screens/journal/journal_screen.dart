import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/state_views.dart';

/// Journal navigation tab displaying private caregiver observations and reflections.
class JournalScreen extends StatelessWidget {
  /// Creates a [JournalScreen].
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activeChild = AuthScope.maybeOf(context)?.activeChild;
    final subtitle = activeChild != null
        ? 'Private notes about ${activeChild.nickname}.'
        : 'Private notes and everyday moments you choose to remember.';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space16),
      children: [
        ScreenHeader(title: 'Journal', subtitle: subtitle),
        const SizedBox(height: AppSpacing.space16),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space16,
            vertical: AppSpacing.space12,
          ),
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline, size: 18, color: AppColors.forest),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Text(
                  'Private by design. Only you can see these notes. They are never sent to external AI or shared.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space24),
        const EmptyStateView(
          title: 'No journal notes yet',
          message: 'Private observation notes appear here.',
          icon: Icons.book_outlined,
        ),
      ],
    );
  }
}
