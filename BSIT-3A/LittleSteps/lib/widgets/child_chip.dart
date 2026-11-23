import 'package:flutter/material.dart';

import '../models/child.dart';
import '../theme/app_tokens.dart';

/// A header chip displaying the active child profile.
class ChildChip extends StatelessWidget {
  const ChildChip({super.key, required this.activeChild, this.onTap});

  /// The active child profile, or `null` if none is selected.
  final Child? activeChild;

  /// Callback invoked when the chip is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = activeChild != null
        ? '${activeChild!.nickname} (${activeChild!.ageBand})'
        : 'Select Child';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSizes.touchTargetSecondary,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space12,
            vertical: AppSpacing.space8,
          ),
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.child_care, size: 18, color: AppColors.forest),
              const SizedBox(width: AppSpacing.space8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space4),
              const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: AppColors.forest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
