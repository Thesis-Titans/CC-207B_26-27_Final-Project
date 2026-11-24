import 'package:flutter/material.dart';

import '../models/activity.dart';
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

/// Main navigation shell hosting adaptive navigation and the shared app header.
///
/// Uses a bottom [NavigationBar] on compact viewports and switches to a side
/// [NavigationRail] at or above [AppSizes.wideLayoutBreakpoint] while keeping
/// tab content centered within [AppSizes.contentMaxWidth].
class ShellScreen extends StatefulWidget {
  /// Creates a [ShellScreen].
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

  final String? email;
  final List<Child> children;
  final String? activeChildId;
  final ValueChanged<Child>? onChildSelected;
  final ValueChanged<String>? onChildDeleted;
  final VoidCallback? onSignOut;
  final VoidCallback? onAccountDeleted;
  final AccountService? accountService;
  final ChildrenService? childrenService;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  static const double _extendedRailBreakpoint = 1080;

  static const List<({IconData icon, IconData selectedIcon, String label})>
  _destinations = [
    (icon: Icons.today_outlined, selectedIcon: Icons.today, label: 'Today'),
    (
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: 'Explore',
    ),
    (icon: Icons.flag_outlined, selectedIcon: Icons.flag, label: 'Milestones'),
    (icon: Icons.book_outlined, selectedIcon: Icons.book, label: 'Journal'),
    (
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights,
      label: 'This week',
    ),
  ];

  int _currentIndex = 0;
  int _todayPlanRefreshKey = 0;
  List<Child> _children = [];
  Map<String, Activity> _scheduledActivityDetails = {};
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

  Future<void> _refreshChildren({bool force = false}) async {
    final sessionState = AuthScope.maybeOf(context);
    if (sessionState == null || !sessionState.isAuthenticated) return;
    if (!force && _children.isNotEmpty && sessionState.activeChild != null) {
      return;
    }
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

      final currentActiveId = sessionState.activeChild?.id;
      final stillExists =
          currentActiveId != null &&
          fetched.any((child) => child.id == currentActiveId);
      if (!stillExists) {
        sessionState.setActiveChild(fetched.isNotEmpty ? fetched.first : null);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingChildren = false;
        });
      }
    }
  }

  Future<void> _loadChildrenIfNeeded() => _refreshChildren();

  void _goToToday() {
    setState(() {
      _currentIndex = 0;
    });
  }

  void _handlePlanAdded(Activity activity) {
    setState(() {
      _scheduledActivityDetails = {
        ..._scheduledActivityDetails,
        activity.id: activity,
      };
      _todayPlanRefreshKey++;
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

    void onDestinationSelected(int index) {
      setState(() {
        _currentIndex = index;
      });
    }

    final screens = <Widget>[
      isAuthenticated
          ? (activeChild != null
                ? TodayScreen(
                    onNavigateTab: onDestinationSelected,
                    planRefreshKey: _todayPlanRefreshKey,
                    initialActivities: _scheduledActivityDetails,
                  )
                : noChildView)
          : EmptyStateView(
              title: "Sign in to see today's plan",
              message: 'Sign in with your caregiver account to view and plan play activities.',
              icon: Icons.lock_outline,
              actionLabel: 'Sign in',
              onAction: () => Navigator.pushNamed(context, '/sign-in'),
            ),
      isAuthenticated
          ? (activeChild != null
                ? ExploreScreen(onPlanAdded: _handlePlanAdded)
                : noChildView)
          : ExploreScreen(onPlanAdded: _handlePlanAdded),
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
          ? (activeChild != null
                ? WeeklySummaryScreen(
                    onFindIdea: () => onDestinationSelected(1),
                  )
                : noChildView)
          : EmptyStateView(
              title: 'Sign in for weekly summary',
              message: 'Weekly play progress is available when signed in.',
              icon: Icons.insights_outlined,
              actionLabel: 'Sign in',
              onAction: () => Navigator.pushNamed(context, '/sign-in'),
            ),
    ];

    Future<void> onChildChipTap() async {
      if (!isAuthenticated) {
        await Navigator.pushNamed(
          context,
          '/sign-in',
          arguments: 'Please sign in to select or manage child profiles.',
        );
      } else {
        await Navigator.pushNamed(context, '/children');
        if (mounted) {
          await _refreshChildren(force: true);
        }
      }
    }

    Widget buildAccountIcon() => const Icon(
      Icons.account_circle_outlined,
      size: 26,
      color: AppColors.forest,
    );

    // IndexedStack keeps all five tab subtrees mounted so scroll position and
    // filter inputs persist when switching tabs.
    final tabStack = IndexedStack(index: _currentIndex, children: screens);
    final compactContent = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
        child: tabStack,
      ),
    );
    final wideContent = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSizes.wideContentMaxWidth,
        ),
        child: tabStack,
      ),
    );

    // LayoutBuilder inspects available width to switch between compact mobile
    // bottom navigation (< 840dp) and wide side navigation (>= 840dp).
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppSizes.wideLayoutBreakpoint;
        final isExtendedRail = constraints.maxWidth >= _extendedRailBreakpoint;

        return Scaffold(
          appBar: isWide
              ? null
              : AppBar(
                  title: compactHeader
                      ? IconButton(
                          tooltip: 'LittleSteps home',
                          onPressed: _goToToday,
                          icon: const GrowthSymbol(size: 26),
                        )
                      : BrandLogo(onTap: _goToToday),
                  actions: [
                    if (activeChild != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: compactHeader ? 148 : 220,
                        ),
                        child: ChildChip(
                          activeChild: activeChild,
                          compact: compactHeader,
                          onTap: onChildChipTap,
                        ),
                      ),
                    IconButton(
                      icon: buildAccountIcon(),
                      tooltip: 'Account',
                      onPressed: () => _showAccountMenu(sessionState),
                    ),
                    const SizedBox(width: AppSpacing.space4),
                  ],
                ),
          body: isWide
              ? Row(
                  children: [
                    Material(
                      color: AppColors.surfaceCard,
                      child: SizedBox(
                        width: isExtendedRail ? AppSizes.sidebarWidth : 80,
                        child: Column(
                          crossAxisAlignment: isExtendedRail
                              ? CrossAxisAlignment.stretch
                              : CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                isExtendedRail
                                    ? AppSpacing.space16
                                    : AppSpacing.space8,
                                AppSpacing.space20,
                                isExtendedRail
                                    ? AppSpacing.space16
                                    : AppSpacing.space8,
                                AppSpacing.space12,
                              ),
                              child: Column(
                                crossAxisAlignment: isExtendedRail
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.center,
                                children: [
                                  if (isExtendedRail)
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: BrandLogo(onTap: _goToToday),
                                    )
                                  else
                                    IconButton(
                                      tooltip: 'LittleSteps home',
                                      onPressed: _goToToday,
                                      icon: const GrowthSymbol(size: 28),
                                    ),
                                  if (activeChild != null &&
                                      isExtendedRail) ...[
                                    const SizedBox(height: AppSpacing.space16),
                                    ChildChip(
                                      activeChild: activeChild,
                                      onTap: onChildChipTap,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, railConstraints) {
                                  return SingleChildScrollView(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: railConstraints.maxHeight,
                                      ),
                                      child: IntrinsicHeight(
                                        child: NavigationRail(
                                          selectedIndex: _currentIndex,
                                          extended: isExtendedRail,
                                          minExtendedWidth:
                                              AppSizes.sidebarWidth,
                                          labelType: isExtendedRail
                                              ? NavigationRailLabelType.none
                                              : NavigationRailLabelType.all,
                                          backgroundColor:
                                              AppColors.surfaceCard,
                                          useIndicator: true,
                                          indicatorColor: AppColors.softGreen,
                                          indicatorShape:
                                              RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.control,
                                                    ),
                                              ),
                                          selectedIconTheme:
                                              const IconThemeData(
                                                color: AppColors.forest,
                                                size: 22,
                                              ),
                                          unselectedIconTheme:
                                              const IconThemeData(
                                                color: AppColors.textSecondary,
                                                size: 22,
                                              ),
                                          selectedLabelTextStyle:
                                              const TextStyle(
                                                color: AppColors.forest,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                          unselectedLabelTextStyle:
                                              const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                          onDestinationSelected:
                                              onDestinationSelected,
                                          destinations: _destinations
                                              .map(
                                                (d) =>
                                                    NavigationRailDestination(
                                                      icon: Icon(d.icon),
                                                      selectedIcon: Icon(
                                                        d.selectedIcon,
                                                      ),
                                                      label: Text(d.label),
                                                    ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: AppColors.borderSubtle,
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isExtendedRail
                                    ? AppSpacing.space12
                                    : AppSpacing.space8,
                                vertical: AppSpacing.space12,
                              ),
                              child: isExtendedRail
                                  ? TextButton.icon(
                                      onPressed: () =>
                                          _showAccountMenu(sessionState),
                                      style: TextButton.styleFrom(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.space8,
                                          vertical: AppSpacing.space8,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.person_outline,
                                        size: 20,
                                        color: AppColors.forest,
                                      ),
                                      label: Text(
                                        formattedCaregiver ?? 'Account',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.person_outline,
                                        size: 20,
                                        color: AppColors.forest,
                                      ),
                                      tooltip: 'Account',
                                      onPressed: () =>
                                          _showAccountMenu(sessionState),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.borderSubtle,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space32,
                          vertical: AppSpacing.space16,
                        ),
                        child: wideContent,
                      ),
                    ),
                  ],
                )
              : compactContent,
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: _destinations
                      .map(
                        (d) => NavigationDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: d.label,
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }

  Future<void> _handleSignOut(AuthSessionState? sessionState) async {
    if (sessionState != null) {
      await sessionState.signOut();
    }
    widget.onSignOut?.call();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/sign-in', (route) => false);
    }
  }

  void _handleChildDeleted(AuthSessionState? sessionState, String childId) {
    final remaining = _children.where((c) => c.id != childId).toList();
    setState(() {
      _children = remaining;
    });
    if (sessionState != null && sessionState.activeChild?.id == childId) {
      sessionState.setActiveChild(
        remaining.isNotEmpty ? remaining.first : null,
      );
    }
    widget.onChildDeleted?.call(childId);
  }

  Future<void> _showAccountMenu(AuthSessionState? sessionState) async {
    final effectiveEmail = sessionState?.currentUser?.email ?? widget.email;
    final effectiveChildren = _children.isNotEmpty
        ? _children
        : (sessionState?.activeChild != null
              ? <Child>[sessionState!.activeChild!]
              : widget.children);
    final isAuthenticated = sessionState?.isAuthenticated ?? false;
    final resolvedApiClient = isAuthenticated
        ? AuthScope.apiClientOf(context)
        : null;
    final effectiveAccountService =
        widget.accountService ??
        (resolvedApiClient != null
            ? AccountService(apiClient: resolvedApiClient)
            : null);
    final effectiveChildrenService =
        widget.childrenService ??
        (resolvedApiClient != null
            ? ChildrenService(apiClient: resolvedApiClient)
            : null);

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
          // Close the modal bottom sheet before clearing session routes.
          Navigator.pop(sheetContext);
          await _handleSignOut(sessionState);
        },
        onOpenSettings: () {
          // Close the modal bottom sheet first so it is not still open on back.
          Navigator.pop(sheetContext);
          Navigator.of(context)
              .push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsScreen(
                    email: effectiveEmail,
                    children: effectiveChildren,
                    accountService: effectiveAccountService,
                    childrenService: effectiveChildrenService,
                    onSignOut: isAuthenticated || widget.onSignOut != null
                        ? () => _handleSignOut(sessionState)
                        : null,
                    onAccountDeleted:
                        widget.onAccountDeleted ??
                        (isAuthenticated
                            ? () => _handleSignOut(sessionState)
                            : null),
                    onChildDeleted: (childId) =>
                        _handleChildDeleted(sessionState, childId),
                  ),
                ),
              )
              .then((_) {
                if (mounted && isAuthenticated) {
                  _refreshChildren(force: true);
                }
              });
        },
      ),
    );
  }
}
