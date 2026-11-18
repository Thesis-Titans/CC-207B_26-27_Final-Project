import 'package:flutter/material.dart';

import '../../widgets/state_views.dart';

/// Account menu screen. Skeleton only; the feature is built in issue #2.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: const EmptyStateView(
        title: 'Account',
        message: 'Settings, privacy notice, about and help appear here.',
        icon: Icons.account_circle_outlined,
      ),
    );
  }
}
