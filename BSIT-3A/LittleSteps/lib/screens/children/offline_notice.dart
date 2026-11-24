import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Banner indicating that the device is offline and profile changes require a
/// connection.
class OfflineNotice extends StatelessWidget {
  /// Creates an [OfflineNotice].
  ///
  /// Renders a retry button when [onRetry] is provided.
  const OfflineNotice({super.key, this.onRetry});

  /// Callback invoked when the caregiver taps "Try again".
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final onRetry = this.onRetry;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOffline,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wifi_off, color: AppColors.textOffline, size: 20),
              SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Text(
                  "You're offline",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textOffline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          const Text(
            'Reconnect to save changes.',
            style: TextStyle(color: AppColors.textOffline),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.space12),
            SizedBox(
              height: AppSizes.touchTarget,
              child: OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
