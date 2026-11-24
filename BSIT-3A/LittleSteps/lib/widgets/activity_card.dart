import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../theme/app_tokens.dart';

/// A card displaying a summary of an activity in lists and search results.
class ActivityCard extends StatelessWidget {
  /// Creates an [ActivityCard].
  const ActivityCard({
    super.key,
    required this.activity,
    this.onTap,
    this.trailing,
  });

  /// The activity data to render.
  final Activity activity;

  /// Callback invoked when the card is pressed.
  final VoidCallback? onTap;

  /// Optional trailing widget displayed at the top right of the card.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      activity.title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: AppSpacing.space8),
              Wrap(
                spacing: AppSpacing.space8,
                runSpacing: AppSpacing.space4,
                children: [
                  _TagChip(label: activity.domain),
                  _TagChip(label: activity.durationEstimate),
                  _TagChip(label: activity.setting),
                  if (activity.materials.isNotEmpty)
                    _TagChip(label: '${activity.materials.length} materials'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceCanvas,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
