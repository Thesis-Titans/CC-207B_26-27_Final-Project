import 'package:flutter/material.dart';

import '../models/child.dart';
import '../widgets/child_chip.dart';
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

  // Set by the shared app state (issue #13).
  final Child? _activeChild = null;

  final List<Widget> _screens = const [
    TodayScreen(),
    ExploreScreen(),
    MilestonesScreen(),
    JournalScreen(),
    WeeklySummaryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ChildChip(
          activeChild: _activeChild,
          onTap: () {
            Navigator.pushNamed(context, '/children');
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
      body: IndexedStack(index: _currentIndex, children: _screens),
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
