import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../services/auth_service.dart';
import '../../services/children_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/brand_logo.dart';

/// Screen that allows caregivers to sign in with their email and password.
///
/// Validates user credentials, displays errors calmly, and supports
/// accessibility features such as screen reader announcements and text scaling.
class SignInScreen extends StatefulWidget {
  /// Creates a [SignInScreen] with optional [notice] message.
  const SignInScreen({super.key, this.notice});

  /// Optional notice displayed above the form (e.g., from an expired session).
  final String? notice;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _announce(String message) {
    final view = View.maybeOf(context);
    if (view != null) {
      SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);
    }
  }

  Future<void> _submit([
    String? overrideEmail,
    String? overridePassword,
  ]) async {
    final email = overrideEmail ?? _emailController.text.trim();
    final password = overridePassword ?? _passwordController.text;

    if (overrideEmail == null && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final sessionState = AuthScope.of(context);
    final apiClient = AuthScope.apiClientOf(context);

    try {
      await sessionState.signIn(email: email, password: password);
      try {
        final childrenService = ChildrenService(apiClient: apiClient);
        final children = await childrenService.getChildren();
        if (children.isNotEmpty && sessionState.activeChild == null) {
          sessionState.setActiveChild(children.first);
        }
      } catch (_) {}
      if (!mounted) return;
      _announce('Signed in successfully');
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
          'Something went wrong while signing in. Please try again.';
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
    final sessionState = AuthScope.maybeOf(context);
    final activeNotice =
        widget.notice ??
        (sessionState?.unsavedDraft != null
            ? 'Please sign in again to continue. Your unsaved draft has been kept.'
            : null);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space24,
                vertical: AppSpacing.space16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - (AppSpacing.space16 * 2))
                      .clamp(0.0, double.infinity),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Compact brand header directly on the canvas
                            const ParentChildIllustration(height: 84),
                            const SizedBox(height: AppSpacing.space8),
                            Text(
                              'LittleSteps',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: AppColors.forest,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.space4),
                            Text(
                              'Sign in to your caregiver account',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.space20),

                            // Single focal credentials card
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.space20),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceCard,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                                border: Border.all(
                                  color: AppColors.borderSubtle,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0F1A2B29),
                                    blurRadius: 14,
                                    offset: Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: Color(0x0A1A2B29),
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Notice banner (if any)
                                  if (activeNotice != null) ...[
                                    Semantics(
                                      liveRegion: true,
                                      child: Container(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.space12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceAdvisory,
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.control,
                                          ),
                                          border: Border.all(
                                            color: AppColors.borderAdvisory,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.info_outline,
                                              size: 20,
                                              color: AppColors.textPrimary,
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.space8,
                                            ),
                                            Expanded(
                                              child: Text(
                                                activeNotice,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          AppColors.textPrimary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.space12),
                                  ],

                                  // Error banner (if any)
                                  if (_errorMessage != null) ...[
                                    Semantics(
                                      liveRegion: true,
                                      child: Container(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.space12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceError,
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.control,
                                          ),
                                          border: Border.all(
                                            color: AppColors.borderError,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.error_outline,
                                              size: 20,
                                              color: AppColors.error,
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.space8,
                                            ),
                                            Expanded(
                                              child: Text(
                                                _errorMessage!,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          AppColors.textError,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.space12),
                                  ],

                                  // Email input
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
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter your email.';
                                      }
                                      if (!value.contains('@')) {
                                        return 'Please enter a valid email address.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.space12),

                                  // Password input
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: !_showPassword,
                                    textInputAction: TextInputAction.done,
                                    enableInteractiveSelection: true,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
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
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your password.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.space4),

                                  // Forgot password link
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Password reset instructions will be sent to your registered email address.',
                                                ),
                                                duration: Duration(seconds: 4),
                                              ),
                                            );
                                      },
                                      child: const Text('Forgot password?'),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.space12),

                                  // Primary sign-in CTA
                                  SizedBox(
                                    height: AppSizes.touchTarget,
                                    child: FilledButton(
                                      onPressed: _submitting
                                          ? null
                                          : () => _submit(),
                                      child: _submitting
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Sign in'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.space16),

                            // Lightweight account creation footer
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: AppSpacing.space4,
                              children: [
                                Text(
                                  'New to LittleSteps?',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(
                                      AppSizes.touchTarget,
                                      AppSizes.touchTarget,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/register');
                                  },
                                  child: const Text('Create account'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
