import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A banner displaying a non-diagnostic advisory notice.
class AdvisoryBanner extends StatelessWidget {
  /// Creates an [AdvisoryBanner].
  const AdvisoryBanner({
    super.key,
    this.message = 'Not a diagnostic tool. Observational play suggestions only. You know your child best.',
  });

  /// The text message displayed in the banner.
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAdvisory,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderAdvisory),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 20,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: AppSpacing.space12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
