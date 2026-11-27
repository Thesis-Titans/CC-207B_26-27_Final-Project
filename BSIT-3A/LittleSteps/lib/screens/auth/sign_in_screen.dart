import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../services/auth_service.dart';
import '../../services/children_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/brand_logo.dart';

/// Screen that allows caregivers to sign in with their email and password.
///
/// Adapts between a zero-scroll compact layout on phones and a two-pane split
/// layout on wide tablet and desktop viewports while supporting screen readers
/// and 200% text scaling.
class SignInScreen extends StatefulWidget {
  /// Creates a [SignInScreen] with optional [notice] message.
  const SignInScreen({super.key, this.notice});

  /// Optional notice displayed above the form (e.g., from an expired session).
  final String? notice;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  static const double _wideLayoutMinWidth = 840;

  static const List<String> _desktopHighlights = [
    'Plan play and note what you can.',
    'Your journal stays private.',
    'Every activity shows where it comes from.',
  ];

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
            if (constraints.maxWidth >= _wideLayoutMinWidth) {
              return _buildWideLayout(
                context,
                theme,
                constraints,
                activeNotice,
              );
            }
            return _buildCompactLayout(
              context,
              theme,
              constraints,
              activeNotice,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    ThemeData theme,
    BoxConstraints constraints,
    String? activeNotice,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space24,
        vertical: AppSpacing.space16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (constraints.maxHeight - (AppSpacing.space16 * 2)).clamp(
            0.0,
            double.infinity,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: GrowthSymbol(size: 48)),
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
                  'Small steps. Brighter tomorrows.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space20),
                _buildFormCard(context, theme, activeNotice),
                const SizedBox(height: AppSpacing.space16),
                _buildAccountFooter(context, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    ThemeData theme,
    BoxConstraints constraints,
    String? activeNotice,
  ) {
    final panelWidth = (constraints.maxWidth * 0.40).clamp(340.0, 460.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left brand panel on warm cream
        Container(
          width: panelWidth,
          decoration: const BoxDecoration(
            color: AppColors.cream,
            border: Border(right: BorderSide(color: AppColors.borderSubtle)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 72).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandLogo(symbolSize: 38, showTagline: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.space24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space12),
                        Text(
                          'Plan short play ideas, notice small moments, and keep private notes for the children you care for.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space20),
                        for (final item in _desktopHighlights)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.space8,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.check,
                                    size: 16,
                                    color: AppColors.forest,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.space8),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Center(child: ParentChildIllustration(height: 168)),
                ],
              ),
            ),
          ),
        ),

        // Right sign-in form pane
        Expanded(
          child: ColoredBox(
            color: AppColors.surfaceCard,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space32,
                vertical: AppSpacing.space24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - (AppSpacing.space24 * 2))
                      .clamp(0.0, double.infinity),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildFormCard(context, theme, activeNotice),
                        const SizedBox(height: AppSpacing.space16),
                        _buildAccountFooter(context, theme),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(
    BuildContext context,
    ThemeData theme,
    String? activeNotice,
  ) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.space20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowCard,
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: AppColors.shadowSubtle,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sign in',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                'Sign in to your caregiver account',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space16),

              // Notice banner (if any)
              if (activeNotice != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.space12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAdvisory,
                      borderRadius: BorderRadius.circular(AppRadius.control),
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
                        const SizedBox(width: AppSpacing.space8),
                        Expanded(
                          child: Text(
                            activeNotice,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
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
                    padding: const EdgeInsets.all(AppSpacing.space12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceError,
                      borderRadius: BorderRadius.circular(AppRadius.control),
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
                  if (value == null || value.trim().isEmpty) {
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
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: Semantics(
                    label: _showPassword ? 'Hide password' : 'Show password',
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Password reset instructions will be sent to your registered email address.',
                        ),
                        duration: AppMotion.snackbarDefault,
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
                  onPressed: _submitting ? null : () => _submit(),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.surfaceCard,
                          ),
                        )
                      : const Text('Sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountFooter(BuildContext context, ThemeData theme) {
    return Wrap(
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
            minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
          ),
          onPressed: () {
            Navigator.pushNamed(context, '/register');
          },
          child: const Text('Create account'),
        ),
      ],
    );
  }
}
