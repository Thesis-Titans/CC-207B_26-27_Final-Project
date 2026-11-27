import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Card component that introduces the Idea Helper activity generator.
///
/// Prompts caregivers to generate play ideas tailored to available materials,
/// time constraints, and the child's developmental age band.
class IdeaHelperCard extends StatelessWidget {
  /// Creates an [IdeaHelperCard].
  const IdeaHelperCard({super.key, this.childName, this.onTap});

  /// Optional nickname of the active child to personalize the card copy.
  final String? childName;

  /// Optional callback invoked when the caregiver presses the card action.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = childName?.trim();
    final subtitleText = name != null && name.isNotEmpty
        ? 'Find a play idea for $name with the time and materials you have.'
        : 'Find a play idea with the time and materials you have.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.softGreen,
                child: Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(width: AppSpacing.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Idea helper',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    Text(
                      'Activity recommendations from everyday materials',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          Text(
            subtitleText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed:
                  onTap ?? () => Navigator.pushNamed(context, '/ai-suggest'),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Find ideas'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: AppColors.surfaceCard,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space20,
                  vertical: AppSpacing.space12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
