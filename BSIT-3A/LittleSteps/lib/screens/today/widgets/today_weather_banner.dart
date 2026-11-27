import 'package:flutter/material.dart';

import '../../../config/external_links.dart';
import '../../../models/weather.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/url_helper.dart';

/// Dismissible weather guidance banner with Open-Meteo attribution and action.
class TodayWeatherBanner extends StatelessWidget {
  /// Creates a [TodayWeatherBanner].
  const TodayWeatherBanner({
    super.key,
    required this.hint,
    required this.hasPlans,
    required this.onDismiss,
    required this.onApplyIndoorAction,
  });

  /// Weather hint returned by the backend weather service.
  final WeatherHint hint;

  /// Whether at least one activity is already scheduled for today.
  final bool hasPlans;

  /// Callback invoked when the caregiver dismisses the banner.
  final VoidCallback onDismiss;

  /// Callback invoked when the caregiver taps the indoor-ideas action.
  final VoidCallback onApplyIndoorAction;

  @override
  Widget build(BuildContext context) {
    final rawHint = hint.hint;
    if (rawHint == null || hint.isUnavailable) {
      return const SizedBox.shrink();
    }

    final showIndoorAction =
        hint.suggestedSetting == 'indoor' || rawHint.contains('Indoor');
    // Strip trailing action suffix when the banner renders an explicit button.
    final displayHint = showIndoorAction
        ? rawHint.replaceFirst(
            RegExp(r'\s*·\s*Indoor ideas$', caseSensitive: false),
            '',
          )
        : rawHint;
    final indoorActionLabel = hasPlans ? 'Filter indoor' : 'Find indoor ideas';

    return Semantics(
      liveRegion: true,
      label: 'Weather guidance: $displayHint',
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.space16),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space8,
        ),
        decoration: BoxDecoration(
          color: AppColors.softGreen,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  hint.isRainy ? Icons.cloud_outlined : Icons.wb_sunny_outlined,
                  size: 18,
                  color: AppColors.forest,
                ),
                const SizedBox(width: AppSpacing.space8),
                Expanded(
                  child: Text(
                    displayHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Dismiss weather hint',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: AppSizes.touchTarget,
                    minHeight: AppSizes.touchTarget,
                  ),
                  onPressed: onDismiss,
                ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.space12,
              runSpacing: AppSpacing.space4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InkWell(
                  onTap: () => openExternalUrl(context, AppLinks.openMeteo),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.space8,
                    ),
                    child: Text(
                      hint.attribution,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                if (showIndoorAction)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space8,
                      ),
                      minimumSize: const Size(0, AppSizes.touchTarget),
                    ),
                    onPressed: onApplyIndoorAction,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(indoorActionLabel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
