import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';

/// Summary shortcut cards for weekly reflection and everyday milestone cues.
class TodaySideCards extends StatelessWidget {
  /// Creates a [TodaySideCards] column.
  const TodaySideCards({
    super.key,
    required this.childName,
    required this.milestoneCues,
    this.onOpenReflection,
    this.onOpenMilestones,
  });

  /// Active child's nickname shown in the milestones card subtitle.
  final String childName;

  /// Everyday age-appropriate cues highlighted for the caregiver.
  final List<String> milestoneCues;

  /// Callback invoked when the caregiver taps "View reflection".
  final VoidCallback? onOpenReflection;

  /// Callback invoked when the caregiver taps "View milestones".
  final VoidCallback? onOpenMilestones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.space20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This week',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.space8),
              Text(
                'Reflect on everyday moments and shared play from this week.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onOpenReflection,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppSizes.touchTarget),
                    side: const BorderSide(color: AppColors.borderInput),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                  ),
                  child: const Text('View reflection'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space16),
        Container(
          padding: const EdgeInsets.all(AppSpacing.space20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Milestones to notice',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.space8),
              Text(
                'Everyday cues to notice for $childName:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space12),
              ...milestoneCues.map(
                (cue) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space8),
                      Expanded(
                        child: Text(
                          cue,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.space8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onOpenMilestones,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppSizes.touchTarget),
                    side: const BorderSide(color: AppColors.borderInput),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                  ),
                  child: const Text('View milestones'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
