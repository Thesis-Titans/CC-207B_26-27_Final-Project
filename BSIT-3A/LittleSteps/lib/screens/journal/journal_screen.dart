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
        ? 'Everyday moments and notes about ${activeChild.nickname}.'
        : 'Everyday moments and notes you choose to remember.';
    final emptyTitle = activeChild != null
        ? 'No notes for ${activeChild.nickname} yet'
        : 'No notes yet';
    final emptyMessage = activeChild != null
        ? 'Jot down small wins, funny moments, or things ${activeChild.nickname} is trying.'
        : 'Jot down small wins, funny moments, or things your child is trying.';

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
                  'Only you can see your notes. They are never shared or sent to AI.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space24),
        EmptyStateView(
          title: emptyTitle,
          message: emptyMessage,
          icon: Icons.book_outlined,
        ),
      ],
    );
  }
}
