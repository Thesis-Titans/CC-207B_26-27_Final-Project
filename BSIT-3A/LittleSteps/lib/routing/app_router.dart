import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../screens/account/account_screen.dart';
import '../screens/ai/ai_suggestions_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/auth/signed_out_screen.dart';
import '../screens/children/add_child_screen.dart';
import '../screens/children/child_profile_screen.dart';
import '../screens/explore/activity_detail_screen.dart';
import '../screens/shell_screen.dart';
import '../widgets/auth_scope.dart';

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
        final notice = settings.arguments as String?;
        return MaterialPageRoute(builder: (_) => SignInScreen(notice: notice));
      case '/register':
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case '/signed-out':
        final message =
            settings.arguments as String? ?? 'Please sign in again to continue';
        return MaterialPageRoute(
          builder: (_) => SignedOutScreen(message: message),
        );
      case '/account':
        return MaterialPageRoute(builder: (_) => const AccountScreen());
      case '/children':
        return MaterialPageRoute(
          builder: (context) {
            final auth = AuthScope.maybeOf(context);
            if (auth != null && !auth.isAuthenticated) {
              return const SignInScreen(
                notice: 'Please sign in to view and manage child profiles.',
              );
            }
            return const ChildProfileScreen();
          },
        );
      case '/children/add':
        return MaterialPageRoute(
          builder: (context) {
            final auth = AuthScope.maybeOf(context);
            if (auth != null && !auth.isAuthenticated) {
              return const SignInScreen(
                notice: 'Please sign in before adding a child profile.',
              );
            }
            return const AddChildScreen();
          },
        );
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
