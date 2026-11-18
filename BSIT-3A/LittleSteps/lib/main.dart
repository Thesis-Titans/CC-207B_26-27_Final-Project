import 'package:flutter/material.dart';

import 'routing/app_router.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const LittleStepsApp());
}

/// The root application widget for LittleSteps.
class LittleStepsApp extends StatelessWidget {
  const LittleStepsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LittleSteps',
      theme: AppTheme.light(),
      initialRoute: AppRouter.initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}
