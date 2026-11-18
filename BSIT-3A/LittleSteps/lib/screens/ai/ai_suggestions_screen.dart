import 'package:flutter/material.dart';

import '../../widgets/state_views.dart';

/// AI play ideas screen. Skeleton only; the feature is built in issue #9.
class AiSuggestionsScreen extends StatelessWidget {
  const AiSuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI play ideas')),
      body: const EmptyStateView(
        title: 'AI play ideas',
        message: 'AI suggestions with fallback appear here.',
        icon: Icons.psychology_outlined,
      ),
    );
  }
}
