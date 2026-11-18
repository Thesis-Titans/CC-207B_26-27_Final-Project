import 'package:flutter/material.dart';

import '../../widgets/state_views.dart';

/// Sign in screen. Skeleton only; the feature is built in issue #1.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: const EmptyStateView(
        title: 'Sign in',
        message: 'Caregiver sign-in appears here.',
        icon: Icons.login,
      ),
    );
  }
}
