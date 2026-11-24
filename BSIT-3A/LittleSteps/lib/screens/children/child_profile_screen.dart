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

/// Lists the caregiver's child profiles and lets them switch the active
/// child or edit a profile (issue #3).
///
/// Shows a loading view while the list loads, an offline notice or an
/// error view with Retry if it fails, and the onboarding view when there
/// are no profiles yet.
class ChildProfileScreen extends StatefulWidget {
  /// Creates the children screen.
  const ChildProfileScreen({
    super.key,
    this.children,
    this.childrenService,
    this.onChildSelected,
  });

  /// Children to show instead of loading them, for tests and previews.
  final List<Child>? children;

  /// The service used to load profiles. Tests pass a fake one; the app
  /// leaves it null and uses the signed-in API client.
  final ChildrenService? childrenService;

  /// Called after the caregiver switches to another child.
  final ValueChanged<Child>? onChildSelected;

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

/// State for [ChildProfileScreen].
class _ChildProfileScreenState extends State<ChildProfileScreen> {
  /// The request for the children list, or null before the first load.
  Future<List<Child>>? _childrenFuture;

  /// Starts the first load. `AuthScope` cannot be read in `initState`,
  /// so the load starts here, once.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_childrenFuture == null) {
      _load();
    }
  }

  /// Loads the caregiver's children.
  ///
  /// Calling it again (Retry, or after adding or editing a child) starts a
  /// new request, and the screen shows the loading view until it finishes.
  void _load() {
    setState(() {
      _childrenFuture = _fetchChildren();
    });
  }

  /// Gets the children from [ChildProfileScreen.children] or the API, and
  /// makes the first one active if no child is active yet.
  Future<List<Child>> _fetchChildren() async {
    final given = widget.children;
    if (given != null) {
      return given;
    }
    // Read everything that needs `context` before the first `await`.
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

  /// Opens the add child form, then reloads the list so a new child shows.
  Future<void> _openAddChild() async {
    await Navigator.pushNamed(context, '/children/add');
    if (!mounted) {
      return;
    }
    _load();
  }

  /// Opens the form to edit [child], then reloads the list so the changes
  /// show.
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

  /// Makes [child] the active child. The header chip and the "Current
  /// child" badge update because [AuthScope] notifies its listeners.
  void _select(Child child) {
    AuthScope.maybeOf(context)?.setActiveChild(child);
    widget.onChildSelected?.call(child);
  }

  /// The part of the caregiver's email before the @, capitalized, used to
  /// greet them on the onboarding view.
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

  /// Builds the screen for whichever state the children list is in.
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

  /// The list of child cards, the add button and the privacy note.
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

  /// One child's card: initial, nickname, age band, the "Current child"
  /// badge or a switch button, and an edit button.
  Widget _buildChildCard(
    BuildContext context,
    Child child, {
    required bool isCurrent,
  }) {
    final theme = Theme.of(context);
    final bandLabel = ageBandForCode(child.ageBand)?.label ?? child.ageBand;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.space12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: isCurrent ? AppColors.forest : AppColors.borderSubtle,
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
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
                  : TextButton(
                      onPressed: () => _select(child),
                      child: const Text('Switch to this child'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// The "Current child" badge shown on the active child's card.
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
