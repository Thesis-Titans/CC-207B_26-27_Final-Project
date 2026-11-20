import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';

/// Screen displayed when a session has expired, matching "MOBILE WEB 00a · J1 Signed out".
///
/// Prominently displays "Please sign in again to continue", preserves any unsaved
/// draft entered by the caregiver, and provides an immediate sign-in action.
class SignedOutScreen extends StatelessWidget {
  /// Creates a [SignedOutScreen] with optional [message].
  const SignedOutScreen({
    super.key,
    this.message = 'Please sign in again to continue',
  });

  /// Explanatory message for the signed-out state.
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionState = AuthScope.maybeOf(context);
    final draft = sessionState?.unsavedDraft;

    return Scaffold(
      appBar: AppBar(title: const Text('Signed out')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.space24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_clock_outlined,
                    size: 64,
                    color: AppColors.forest,
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  Text(
                    'Signed out',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  Text(
                    message,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (draft != null && draft.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.space20),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.space16),
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
                              const Icon(
                                Icons.save_outlined,
                                size: 18,
                                color: AppColors.forest,
                              ),
                              const SizedBox(width: AppSpacing.space8),
                              Text(
                                'Your unsaved draft is safe',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.forest,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.space8),
                          Text(
                            draft,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.space24),
                  SizedBox(
                    height: AppSizes.touchTarget,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          '/sign-in',
                          arguments: message,
                        );
                      },
                      child: const Text('Sign in again'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
