import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/accessibility.dart';
import '../../widgets/auth_scope.dart';

/// Caregiver registration screen.
///
/// Displays the privacy notice before account creation, supports password
/// managers and paste input through [AutofillGroup], and announces validation
/// and submission status changes to assistive technologies.
class RegisterScreen extends StatefulWidget {
  /// Creates a [RegisterScreen].
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _acceptedPrivacy = false;
  bool _submitting = false;
  String? _errorMessage;

  static const List<MapEntry<String, String>> _privacyPoints = [
    MapEntry(
      'What we collect',
      'A child nickname, birth month and year, activity records and your notes.',
    ),
    MapEntry(
      'Why',
      'To suggest age-suitable activities and keep your own record.',
    ),
    MapEntry(
      'Who sees it',
      'Only you. Notes never go to external AI, analytics, or error logs.',
    ),
    MapEntry(
      'Your rights',
      'You can view and modify what you entered anytime in the app.',
    ),
    MapEntry(
      'If something goes wrong',
      'We aim to notify you and the National Privacy Commission within 72 hours.',
    ),
    MapEntry('Contact', 'privacy@littlesteps.local / Data Protection Officer'),
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _announce(String message) => announceForAccessibility(context, message);

  Future<void> _submit() async {
    if (!_acceptedPrivacy) {
      setState(() {
        _errorMessage = 'Please read and accept the privacy notice before creating an account.';
      });
      _announce(
        'Please read and accept the privacy notice before creating an account.',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final sessionState = AuthScope.of(context);

    try {
      await sessionState.createAccount(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      _announce('Account created successfully');
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _submitting = false;
      });
      _announce(e.message);
    } catch (_) {
      if (!mounted) return;
      const generic =
          'Something went wrong while creating your account. Please try again.';
      setState(() {
        _errorMessage = generic;
        _submitting = false;
      });
      _announce(generic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space24,
              vertical: AppSpacing.space16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create an account',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.space8),
                      Text(
                        "For parents and guardians who add their own child's details.",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.space20),

                      // Privacy Notice Box
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.space16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                            color: AppColors.forest,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.lock_outline,
                                  size: 20,
                                  color: AppColors.forest,
                                ),
                                const SizedBox(width: AppSpacing.space8),
                                Text(
                                  'Privacy Notice',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.forest,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.space12),
                            ..._privacyPoints.map((point) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.space8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      point.key,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Text(
                                      point.value,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const Divider(),
                            Material(
                              color: Colors.transparent,
                              child: CheckboxListTile(
                                value: _acceptedPrivacy,
                                onChanged: (val) {
                                  setState(() {
                                    _acceptedPrivacy = val ?? false;
                                    if (_acceptedPrivacy) _errorMessage = null;
                                  });
                                },
                                title: Text(
                                  'I have read the privacy summary above',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space16),

                      // Error Banner (if any)
                      if (_errorMessage != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.space12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceError,
                              borderRadius: BorderRadius.circular(
                                AppRadius.control,
                              ),
                              border: Border.all(color: AppColors.borderError),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 20,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: AppSpacing.space8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textError,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space16),
                      ],

                      // Email field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        enableInteractiveSelection: true,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'you@example.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email.';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.space16),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        enableInteractiveSelection: true,
                        autofillHints: const [AutofillHints.newPassword],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText: 'At least 8 characters. Password managers are welcome.',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: Semantics(
                            label: _showPassword
                                ? 'Hide password'
                                : 'Show password',
                            child: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showPassword = !_showPassword;
                                });
                              },
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 8) {
                            return 'Password must be at least 8 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.space24),

                      // Submit button
                      SizedBox(
                        height: AppSizes.touchTarget,
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.surfaceCard,
                                  ),
                                )
                              : const Text('Create account'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space12),

                      // Link back to sign in
                      SizedBox(
                        height: AppSizes.touchTarget,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Already have an account? Sign in'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
