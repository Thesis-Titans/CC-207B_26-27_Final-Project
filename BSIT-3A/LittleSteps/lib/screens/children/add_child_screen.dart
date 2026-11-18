import 'package:flutter/material.dart';

import '../../widgets/state_views.dart';

/// Add child profile screen. Skeleton only; the feature is built in issue #3.
class AddChildScreen extends StatelessWidget {
  const AddChildScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add child profile')),
      body: const EmptyStateView(
        title: 'Add child profile',
        message: 'The validated child profile form appears here.',
        icon: Icons.child_care_outlined,
      ),
    );
  }
}
