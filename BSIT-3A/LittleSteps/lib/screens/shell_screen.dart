import 'package:flutter/material.dart';

import '../widgets/child_chip.dart';
import '../widgets/auth_scope.dart';
import '../widgets/state_views.dart';
import 'today/today_screen.dart';
import 'explore/explore_screen.dart';
import 'milestones/milestones_screen.dart';
import 'journal/journal_screen.dart';
import 'reflection/weekly_summary_screen.dart';

/// Main navigation shell hosting the bottom navigation bar and shared header.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final sessionState = AuthScope.maybeOf(context);
    final isAuthenticated = sessionState?.isAuthenticated ?? false;
    final activeChild = sessionState?.activeChild;

    final screens = <Widget>[
      isAuthenticated
          ? const TodayScreen()
          : EmptyStateView(
              title: "Sign in to see today's plan",
              message: 'Sign in with your caregiver account to view and plan play activities.',
              icon: Icons.lock_outline,
              actionLabel: 'Sign in',
              onAction: () => Navigator.pushNamed(context, '/sign-in'),
            ),
      const ExploreScreen(),
      isAuthenticated
          ? const MilestonesScreen()
          : EmptyStateView(
              title: 'Sign in to view milestones',
              message: 'Milestone observations are private to your caregiver account.',
              icon: Icons.flag_outlined,
              actionLabel: 'Sign in',
              onAction: () => Navigator.pushNamed(context, '/sign-in'),
            ),
      isAuthenticated
          ? const JournalScreen()
          : EmptyStateView(
              title: 'Sign in for private journal',
              message: 'Your caregiver notes are private and encrypted in your account.',
              icon: Icons.book_outlined,
              actionLabel: 'Sign in',
              onAction: () => Navigator.pushNamed(context, '/sign-in'),
            ),
      isAuthenticated
          ? const WeeklySummaryScreen()
          : EmptyStateView(
              title: 'Sign in for weekly summary',
              message: 'Weekly play progress is available when signed in.',
              icon: Icons.insights_outlined,
              actionLabel: 'Sign in',
              onAction: () => Navigator.pushNamed(context, '/sign-in'),
            ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: ChildChip(
          activeChild: activeChild,
          onTap: () {
            if (!isAuthenticated) {
              Navigator.pushNamed(
                context,
                '/sign-in',
                arguments: 'Please sign in to select or manage child profiles.',
              );
            } else {
              Navigator.pushNamed(context, '/children');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'AI Play Ideas',
            onPressed: () {
              Navigator.pushNamed(context, '/ai-suggest');
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Settings & Account',
            onPressed: () {
              Navigator.pushNamed(context, '/account');
            },
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Milestones',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'This week',
          ),
        ],
      ),
    );
  }
}
