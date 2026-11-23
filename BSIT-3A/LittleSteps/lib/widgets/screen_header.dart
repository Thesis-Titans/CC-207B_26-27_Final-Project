import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Consistent top header for primary screen views.
///
/// Renders the page title in standard typography hierarchy, accompanied by a
/// contextual subtitle and an optional non-diagnostic advisory toggle button.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onAdvisoryTap,
    this.advisoryLabel = 'Not a diagnostic tool',
  });

  /// Main page title (H1, sentence case, 26px Bold).
  final String title;

  /// Explanatory subtitle (14px Regular, calm non-diagnostic voice).
  final String? subtitle;

  /// Optional callback to open the non-diagnostic advisory modal or toggle banner.
  final VoidCallback? onAdvisoryTap;

  /// Label for the advisory button.
  final String advisoryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.space4),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (onAdvisoryTap != null) ...[
          const SizedBox(height: AppSpacing.space4),
          Semantics(
            button: true,
            label: advisoryLabel,
            child: InkWell(
              onTap: onAdvisoryTap,
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.touchTargetSecondary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 15,
                      color: AppColors.forest,
                    ),
                    const SizedBox(width: AppSpacing.space4),
                    Text(
                      advisoryLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.forest,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
