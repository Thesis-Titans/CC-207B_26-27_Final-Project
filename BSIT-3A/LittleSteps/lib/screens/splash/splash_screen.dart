import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/brand_logo.dart';

/// Initial splash screen displayed on application launch.
///
/// Animates the brand logo and checks authentication state before routing to
/// the appropriate initial screen.
class SplashScreen extends StatefulWidget {
  /// Creates a [SplashScreen].
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.durationBase,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.easingStandard,
    );
    _controller.forward();

    // Wait briefly so the fade-in completes before replacing the splash route.
    _navigationTimer = Timer(AppMotion.splashDelay, _navigateNext);
  }

  // Routes signed-in caregivers to the main shell and others to sign-in.
  void _navigateNext() {
    if (!mounted) return;
    final sessionState = AuthScope.maybeOf(context);
    final isAuthenticated = sessionState?.isAuthenticated ?? false;

    if (isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/');
    } else {
      Navigator.pushReplacementNamed(context, '/sign-in');
    }
  }

  @override
  void dispose() {
    // Cancel the pending timer and dispose the animation controller to avoid
    // callbacks firing after this widget leaves the tree.
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GrowthSymbol(size: 64),
              SizedBox(height: AppSpacing.space16),
              BrandLogo(symbolSize: 0, showTagline: true),
            ],
          ),
        ),
      ),
    );
  }
}
