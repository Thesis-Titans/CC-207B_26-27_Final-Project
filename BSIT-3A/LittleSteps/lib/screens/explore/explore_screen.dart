import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/idea_helper_card.dart';
import '../../widgets/screen_header.dart';

/// Explore navigation tab providing access to the curated play activity catalog
/// and the Idea Helper activity generator.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionState = AuthScope.maybeOf(context);
    final activeChild = sessionState?.activeChild;

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space16,
            vertical: AppSpacing.space16,
          ),
          children: [
            const ScreenHeader(
              title: 'Explore',
              subtitle: 'Play ideas and activities for everyday moments.',
            ),
            const SizedBox(height: AppSpacing.space16),
            IdeaHelperCard(childName: activeChild?.nickname),
            const SizedBox(height: AppSpacing.space16),
            Container(
              padding: const EdgeInsets.all(AppSpacing.space24),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.explore_outlined,
                    size: 40,
                    color: AppColors.sage,
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  Text(
                    'Activity Catalog',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    'The age-aware activity catalog appears here.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
