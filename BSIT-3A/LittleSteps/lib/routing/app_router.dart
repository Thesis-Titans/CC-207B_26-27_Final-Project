import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../screens/shell_screen.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/explore/activity_detail_screen.dart';
import '../screens/children/child_profile_screen.dart';
import '../screens/children/add_child_screen.dart';
import '../screens/account/account_info_screen.dart';
import '../screens/account/settings_screen.dart';
import '../screens/ai/ai_suggestions_screen.dart';

/// Application route generator and path constants.
abstract final class AppRouter {
  /// Initial route loaded on application launch.
  static const String initialRoute = '/';

  /// Generates application routes based on [RouteSettings].
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const ShellScreen());
      case '/sign-in':
        return MaterialPageRoute(builder: (_) => const SignInScreen());
      case '/account':
      case '/account/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case '/account/privacy':
        return MaterialPageRoute(
          builder: (_) =>
              const AccountInfoScreen(page: AccountInfoPage.privacy),
        );
      case '/account/about':
        return MaterialPageRoute(
          builder: (_) => const AccountInfoScreen(page: AccountInfoPage.about),
        );
      case '/account/help':
        return MaterialPageRoute(
          builder: (_) => const AccountInfoScreen(page: AccountInfoPage.help),
        );
      case '/children':
        return MaterialPageRoute(builder: (_) => const ChildProfileScreen());
      case '/children/add':
        return MaterialPageRoute(builder: (_) => const AddChildScreen());
      case '/ai-suggest':
        return MaterialPageRoute(builder: (_) => const AiSuggestionsScreen());
      case '/explore/activity':
        final activity = settings.arguments as Activity?;
        if (activity == null) {
          return MaterialPageRoute(
            builder: (_) =>
                const Scaffold(body: Center(child: Text('Activity not found'))),
          );
        }
        return MaterialPageRoute(
          builder: (_) => ActivityDetailScreen(activity: activity),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
        );
    }
  }
}
