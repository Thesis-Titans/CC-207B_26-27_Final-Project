import 'package:flutter/material.dart';

import '../../models/age_band.dart';
import '../../models/child.dart';
import '../../services/children_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/state_views.dart';

/// Lists the caregiver's child profiles and lets them pick the active
/// child (issue #3).
///
/// Shows a loading view while the list loads, an error view with Retry if
/// it fails, and an empty view with an "Add a child" action when there are
/// no profiles yet.
class ChildProfileScreen extends StatefulWidget {
  /// Creates the children screen.
  const ChildProfileScreen({super.key});

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

  /// Loads the caregiver's children from the API.
  ///
  /// Calling it again (Retry, or after adding a child) starts a new
  /// request, and the list shows the loading view until it finishes.
  void _load() {
    setState(() {
      _childrenFuture = ChildrenService(
        apiClient: AuthScope.apiClientOf(context),
      ).getChildren();
    });
  }

  /// Opens the add child form, then reloads the list so a new child shows.
  Future<void> _openAddChild() async {
    await Navigator.pushNamed(context, '/children/add');
    if (!mounted) {
      return;
    }
    _load();
  }

  /// Makes [child] the active child and goes back.
  void _select(Child child) {
    AuthScope.of(context).setActiveChild(child);
    Navigator.pop(context);
  }

  /// Builds the screen for whichever state the children list is in.
  @override
  Widget build(BuildContext context) {
    final activeChildId = AuthScope.of(context).activeChild?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Children')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddChild,
        icon: const Icon(Icons.add),
        label: const Text('Add a child'),
      ),
      body: FutureBuilder<List<Child>>(
        future: _childrenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView(message: 'Loading children...');
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: "Couldn't load children. Check your connection.",
              onRetry: _load,
            );
          }

          final children = snapshot.data ?? const <Child>[];
          if (children.isEmpty) {
            return EmptyStateView(
              title: 'No children added yet',
              message: 'Add a child to start planning play.',
              icon: Icons.people_outline,
              actionLabel: 'Add a child',
              onAction: _openAddChild,
            );
          }

          return ListView.separated(
            // Extra bottom padding keeps the last child clear of the
            // floating "Add a child" button.
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space16,
              AppSpacing.space16,
              AppSpacing.space16,
              AppSpacing.space32 * 3,
            ),
            itemCount: children.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final child = children[index];
              final isActive = child.id == activeChildId;
              return ListTile(
                minTileHeight: AppSizes.touchTarget,
                leading: const Icon(Icons.child_care_outlined),
                title: Text(child.nickname),
                subtitle: Text(
                  ageBandForCode(child.ageBand)?.label ?? child.ageBand,
                ),
                trailing: isActive
                    ? const Icon(Icons.check_circle, semanticLabel: 'Active')
                    : null,
                selected: isActive,
                onTap: () => _select(child),
              );
            },
          );
        },
      ),
    );
  }
}
