import 'package:flutter/material.dart';

import '../models/child.dart';
import '../services/account_service.dart';
import '../services/api_client.dart';
import '../services/auth_session_state.dart';
import '../services/children_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/account_menu_sheet.dart';
import '../widgets/auth_scope.dart';
import '../widgets/brand_logo.dart';
import '../widgets/child_chip.dart';
import '../widgets/no_children_view.dart';
import '../widgets/state_views.dart';
import 'account/settings_screen.dart';
import 'today/today_screen.dart';
import 'explore/explore_screen.dart';
import 'milestones/milestones_screen.dart';
import 'journal/journal_screen.dart';
import 'reflection/weekly_summary_screen.dart';

/// Main navigation shell hosting the bottom navigation bar and shared header.
class ShellScreen extends StatefulWidget {
  const ShellScreen({
    super.key,
    this.email,
    this.children = const [],
    this.activeChildId,
    this.onChildSelected,
    this.onChildDeleted,
    this.onSignOut,
    this.onAccountDeleted,
    this.accountService,
    this.childrenService,
  });

  /// Email address from the shared signed-in session.
  final String? email;

  /// Child profiles from shared app state.
  final List<Child> children;

  /// Selected child identifier from shared app state.
  final String? activeChildId;

  /// Called when a caregiver selects a child in the account menu.
  final ValueChanged<Child>? onChildSelected;

  /// Called after a child profile and its saved records are deleted.
  final ValueChanged<String>? onChildDeleted;

  /// Called when the caregiver signs out.
  final VoidCallback? onSignOut;

  /// Called after the caregiver's account is deleted.
  final VoidCallback? onAccountDeleted;

  /// Authenticated account requests shared with the rest of the app.
  final AccountService? accountService;

  /// Authenticated child requests shared with the rest of the app.
  final ChildrenService? childrenService;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _currentIndex = 0;
  List<Child> _children = [];
  bool _isLoadingChildren = false;

  @override
  void initState() {
    super.initState();
    _children = List.of(widget.children);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadChildrenIfNeeded();
  }

  ChildrenService _resolveChildrenService() {
    if (widget.childrenService != null) return widget.childrenService!;
    final apiClient = AuthScope.maybeOf(context) != null
        ? AuthScope.apiClientOf(context)
        : ApiClient();
    return ChildrenService(apiClient: apiClient);
  }

  Future<void> _loadChildrenIfNeeded() async {
    final sessionState = AuthScope.maybeOf(context);
    if (sessionState == null || !sessionState.isAuthenticated) return;
    if (_children.isNotEmpty && sessionState.activeChild != null) return;
    if (_isLoadingChildren) return;

    _isLoadingChildren = true;

    try {
      final service = _resolveChildrenService();
      final fetched = await service.getChildren();
      if (!mounted) return;

      setState(() {
        _children = fetched;
        _isLoadingChildren = false;
      });

      if (sessionState.activeChild == null && fetched.isNotEmpty) {
        sessionState.setActiveChild(fetched.first);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingChildren = false;
        });
      }
    }
  }

  void _goToToday() {
    setState(() {
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final compactHeader = MediaQuery.sizeOf(context).width < 380;
    final sessionState = AuthScope.maybeOf(context);
    final isAuthenticated = sessionState?.isAuthenticated ?? false;
    final activeChild = sessionState?.activeChild;

    final rawEmail = sessionState?.currentUser?.email ?? widget.email;
    final caregiverName = rawEmail != null && rawEmail.contains('@')
        ? rawEmail.split('@').first
        : rawEmail;
    final formattedCaregiver = caregiverName != null && caregiverName.isNotEmpty
        ? '${caregiverName[0].toUpperCase()}${caregiverName.substring(1)}'
        : null;

    final noChildView = NoChildrenView(
      caregiverName: formattedCaregiver,
      onAddChild: () => Navigator.pushNamed(context, '/children/add'),
    );

    final screens = <Widget>[
      isAuthenticated
          ? (activeChild != null ? const TodayScreen() : noChildView)
          : EmptyStateView(
              title: "Sign in to see today's plan",
              message: 'Sign in with your caregiver account to view and plan play activities.',
              icon: Icons.lock_outline,
              actionLabel: 'Sign in',
              onAction: () => Navigator.pushNamed(context, '/sign-in'),
            ),
      isAuthenticated
          ? (activeChild != null ? const ExploreScreen() : noChildView)
          : const ExploreScreen(),
      isAuthenticated
          ? (activeChild != null ? const MilestonesScreen() : noChildView)
          : EmptyStateView(
              title: 'Sign in to view milestones',
              message: 'Milestone observations are private to your caregiver account.',
              icon: Icons.flag_outlined,
              actionLabel: 'Sign in',
              onAction: () => Navigator.pushNamed(context, '/sign-in'),
            ),
      isAuthenticated
          ? (activeChild != null ? const JournalScreen() : noChildView)
          : EmptyStateView(
              title: 'Sign in for private journal',
              message: 'Your caregiver notes are private and encrypted in your account.',
              icon: Icons.book_outlined,
              actionLabel: 'Sign in',
              onAction: () => Navigator.pushNamed(context, '/sign-in'),
            ),
      isAuthenticated
          ? (activeChild != null ? const WeeklySummaryScreen() : noChildView)
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
        title: compactHeader
            ? IconButton(
                tooltip: 'LittleSteps home',
                onPressed: _goToToday,
                icon: const GrowthSymbol(size: 26),
              )
            : BrandLogo(onTap: _goToToday),
        actions: [
          if (activeChild != null)
            SizedBox(
              width: compactHeader ? 132 : null,
              child: ChildChip(
                activeChild: activeChild,
                compact: compactHeader,
                onTap: () {
                  if (!isAuthenticated) {
                    Navigator.pushNamed(
                      context,
                      '/sign-in',
                      arguments:
                          'Please sign in to select or manage child profiles.',
                    );
                  } else {
                    Navigator.pushNamed(context, '/children');
                  }
                },
              ),
            ),
          IconButton(
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.softGreen,
              child: Text(
                activeChild != null && activeChild.nickname.isNotEmpty
                    ? activeChild.nickname[0].toUpperCase()
                    : ((sessionState?.currentUser?.email ?? widget.email) !=
                                  null &&
                              (sessionState?.currentUser?.email ??
                                      widget.email)!
                                  .isNotEmpty
                          ? (sessionState?.currentUser?.email ??
                                    widget.email)![0]
                                .toUpperCase()
                          : 'C'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.forest,
                ),
              ),
            ),
            tooltip: 'Account',
            onPressed: () => _showAccountMenu(sessionState),
          ),
          const SizedBox(width: AppSpacing.space4),
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

  Future<void> _showAccountMenu(AuthSessionState? sessionState) async {
    final effectiveEmail = sessionState?.currentUser?.email ?? widget.email;
    final effectiveChildren = _children.isNotEmpty
        ? _children
        : (sessionState?.activeChild != null
              ? <Child>[sessionState!.activeChild!]
              : widget.children);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (sheetContext) => AccountMenuSheet(
        email: effectiveEmail,
        children: effectiveChildren,
        activeChildId: sessionState?.activeChild?.id ?? widget.activeChildId,
        onChildSelected: (child) {
          if (sessionState != null) {
            sessionState.setActiveChild(child);
          }
          widget.onChildSelected?.call(child);
        },
        onSignOut: () async {
          Navigator.pop(sheetContext);
          if (sessionState != null) {
            await sessionState.signOut();
          }
          widget.onSignOut?.call();
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/sign-in',
              (route) => false,
            );
          }
        },
        onOpenSettings: () {
          Navigator.pop(sheetContext);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SettingsScreen(
                email: effectiveEmail,
                children: effectiveChildren,
                accountService: widget.accountService,
                childrenService: widget.childrenService,
                onSignOut: widget.onSignOut,
                onAccountDeleted: widget.onAccountDeleted,
                onChildDeleted: widget.onChildDeleted,
              ),
            ),
          );
        },
      ),
    );
  }
}
