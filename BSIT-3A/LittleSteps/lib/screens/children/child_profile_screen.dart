import 'package:flutter/material.dart';

import '../../models/age_band.dart';
import '../../models/child.dart';
import '../../services/api_client.dart';
import '../../services/children_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/no_children_view.dart';
import '../../widgets/state_views.dart';
import 'add_child_screen.dart';
import 'offline_notice.dart';

/// Lists the caregiver's child profiles and lets them switch or edit profiles.
///
/// Shows a loading state while fetching profiles, an offline notice or retryable
/// error view on failure, and [NoChildrenView] when no profiles exist yet.
class ChildProfileScreen extends StatefulWidget {
  /// Creates a [ChildProfileScreen].
  const ChildProfileScreen({
    super.key,
    this.children,
    this.childrenService,
    this.onChildSelected,
  });

  /// Optional list of child profiles to display instead of loading from the API.
  final List<Child>? children;

  /// Optional service override used to load profiles.
  ///
  /// When `null`, this screen builds a [ChildrenService] from [AuthScope].
  final ChildrenService? childrenService;

  /// Callback invoked after the caregiver switches the active child.
  final ValueChanged<Child>? onChildSelected;

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  // Pending request for the children list, or null before the first load.
  Future<List<Child>>? _childrenFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AuthScope cannot be read in initState, so the initial fetch starts here once.
    if (_childrenFuture == null) {
      _load();
    }
  }

  // Starts or restarts the profile list request.
  void _load() {
    setState(() {
      _childrenFuture = _fetchChildren();
    });
  }

  // Loads profiles from widget overrides or the API and selects the first child
  // when no active child is set yet.
  Future<List<Child>> _fetchChildren() async {
    final given = widget.children;
    if (given != null) {
      return given;
    }
    // Capture context-dependent references before awaiting network I/O.
    final session = AuthScope.maybeOf(context);
    final service =
        widget.childrenService ??
        ChildrenService(apiClient: AuthScope.apiClientOf(context));

    final children = await service.getChildren();
    if (session != null && session.activeChild == null && children.isNotEmpty) {
      session.setActiveChild(children.first);
    }
    return children;
  }

  // Opens the add-child form and reloads the list on return.
  Future<void> _openAddChild() async {
    await Navigator.pushNamed(context, '/children/add');
    if (!mounted) {
      return;
    }
    _load();
  }

  // Opens the edit-child form for the given profile and reloads on return.
  Future<void> _openEditChild(Child child) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => AddChildScreen(child: child)),
    );
    if (!mounted) {
      return;
    }
    _load();
  }

  // Updates the active child in AuthScope so shell indicators refresh.
  void _select(Child child) {
    AuthScope.maybeOf(context)?.setActiveChild(child);
    widget.onChildSelected?.call(child);
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Switched to ${child.nickname}'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // Derives a capitalized greeting name from the signed-in caregiver email.
  String? _caregiverName() {
    final email = AuthScope.maybeOf(context)?.currentUser?.email;
    if (email == null || !email.contains('@')) {
      return null;
    }
    final name = email.split('@').first;
    if (name.isEmpty) {
      return null;
    }
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: AppBar(title: const Text('Children')),
      body: FutureBuilder<List<Child>>(
        future: _childrenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView(message: 'Loading children...');
          }
          if (snapshot.hasError) {
            // ApiClient reports a lost connection as NoConnectionApiException.
            // Any error that is not an ApiException also means the server
            // was never reached. The list, and with it Add and Edit, waits
            // for a connection.
            final error = snapshot.error;
            if (error is NoConnectionApiException || error is! ApiException) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.space16),
                  child: OfflineNotice(onRetry: _load),
                ),
              );
            }
            return ErrorView(
              message: "Couldn't load children. Please try again.",
              onRetry: _load,
            );
          }

          final children = snapshot.data ?? const <Child>[];
          if (children.isEmpty) {
            return NoChildrenView(
              caregiverName: _caregiverName(),
              onAddChild: _openAddChild,
            );
          }
          return _buildChildrenList(context, children);
        },
      ),
    );
  }

  Widget _buildChildrenList(BuildContext context, List<Child> children) {
    final theme = Theme.of(context);
    final activeChildId = AuthScope.maybeOf(context)?.activeChild?.id;
    final profileWord = children.length == 1 ? 'profile' : 'profiles';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space16),
      children: [
        Text(
          'Manage your private family space.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.space16),
        Text(
          'Your children (${children.length} $profileWord)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.space12),
        for (final child in children)
          _buildChildCard(context, child, isCurrent: child.id == activeChildId),
        const SizedBox(height: AppSpacing.space12),
        OutlinedButton.icon(
          onPressed: _openAddChild,
          icon: const Icon(Icons.add),
          label: const Text('Add a child'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.touchTarget),
          ),
        ),
        const SizedBox(height: AppSpacing.space24),
        Container(
          padding: const EdgeInsets.all(AppSpacing.space16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Just enough to make ideas relevant',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                'We only keep a nickname and an age range or birth month. '
                'No full birthdays, surnames or photos are required.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChildCard(
    BuildContext context,
    Child child, {
    required bool isCurrent,
  }) {
    final theme = Theme.of(context);
    final bandLabel = ageBandForCode(child.ageBand)?.label ?? child.ageBand;

    return Semantics(
      selected: isCurrent,
      hint: isCurrent
          ? 'Current active child'
          : 'Switches active child to ${child.nickname}',
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.space12),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: isCurrent ? AppColors.forest : AppColors.borderSubtle,
            width: isCurrent ? 1.5 : 1.0,
          ),
        ),
        child: InkWell(
          onTap: isCurrent ? null : () => _select(child),
          hoverColor: AppColors.softGreen.withValues(alpha: 0.35),
          splashColor: AppColors.softGreen.withValues(alpha: 0.6),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.softGreen,
                      child: Text(
                        child.nickname.isNotEmpty
                            ? child.nickname[0].toUpperCase()
                            : 'C',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.nickname,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            bandLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit ${child.nickname}',
                      onPressed: () => _openEditChild(child),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space12),
                Align(
                  alignment: Alignment.centerRight,
                  child: isCurrent
                      ? _currentChildBadge(theme)
                      : Text(
                          'Tap to switch',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.forest,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _currentChildBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 14, color: AppColors.forest),
          const SizedBox(width: AppSpacing.space4),
          Text(
            'Current child',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.forest,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
