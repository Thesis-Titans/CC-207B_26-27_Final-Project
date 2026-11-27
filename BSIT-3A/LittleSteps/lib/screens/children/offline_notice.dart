import 'package:flutter/material.dart';

import '../../widgets/state_views.dart';

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
    return OfflineStatusCard(
      message: 'Reconnect to save changes.',
      retryLabel: 'Try again',
      onRetry: onRetry,
    );
  }
}
