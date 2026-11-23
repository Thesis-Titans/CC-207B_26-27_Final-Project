import 'package:flutter/material.dart';

import '../../models/child.dart';
import '../../services/children_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/no_children_view.dart';

/// Screen for viewing and managing family child profiles.
///
/// Displays the empty onboarding view when no profiles exist,
/// and the family profile management list when children have been added.
class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({
    super.key,
    this.children,
    this.childrenService,
    this.onChildSelected,
  });

  /// Injected children list for testing or previews.
  final List<Child>? children;

  /// Service for child profile persistence.
  final ChildrenService? childrenService;

  /// Callback when a child profile is selected as active.
  final ValueChanged<Child>? onChildSelected;

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  late List<Child> _children;

  @override
  void initState() {
    super.initState();
    _children = widget.children ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = AuthScope.maybeOf(context);
    final effectiveChildren =
        widget.children ??
        (sessionState?.activeChild != null
            ? <Child>[sessionState!.activeChild!]
            : _children);
    final activeChild =
        sessionState?.activeChild ??
        (effectiveChildren.isNotEmpty ? effectiveChildren.first : null);

    final email = sessionState?.currentUser?.email;
    final caregiverName = email != null && email.contains('@')
        ? email.split('@').first
        : null;

    final formattedCaregiver = caregiverName != null && caregiverName.isNotEmpty
        ? '${caregiverName[0].toUpperCase()}${caregiverName.substring(1)}'
        : null;

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: AppBar(title: const Text('Children')),
      body: effectiveChildren.isEmpty
          ? NoChildrenView(
              caregiverName: formattedCaregiver,
              onAddChild: () => _navigateToAddChild(context),
            )
          : _buildChildrenList(context, effectiveChildren, activeChild),
    );
  }

  Widget _buildChildrenList(
    BuildContext context,
    List<Child> children,
    Child? activeChild,
  ) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space16,
      ),
      children: [
        // Subtitle
        Text(
          'Manage your private family space.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.space16),

        // Count Header
        Text(
          'Your children (${children.length} ${children.length == 1 ? 'profile' : 'profiles'})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.space12),

        // Child Profile Cards
        for (final child in children)
          _buildChildCard(context, child, child.id == activeChild?.id),

        const SizedBox(height: AppSpacing.space12),

        // Add Another Child Button
        OutlinedButton.icon(
          onPressed: () => _navigateToAddChild(context),
          icon: const Icon(Icons.add),
          label: const Text('Add a child'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.touchTarget),
          ),
        ),
        const SizedBox(height: AppSpacing.space24),

        // Privacy Reassurance Card
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
                'We only keep a nickname and age range. '
                'No birthdays, surnames or photos are required.',
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

  Widget _buildChildCard(BuildContext context, Child child, bool isCurrent) {
    final theme = Theme.of(context);
    final sessionState = AuthScope.maybeOf(context);

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
                        child.ageBand,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
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
                        const Icon(
                          Icons.check,
                          size: 14,
                          color: AppColors.forest,
                        ),
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
                  ),
              ],
            ),
            if (!isCurrent) ...[
              const SizedBox(height: AppSpacing.space12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    sessionState?.setActiveChild(child);
                    widget.onChildSelected?.call(child);
                    setState(() {});
                  },
                  child: const Text('Switch to this child'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToAddChild(BuildContext context) {
    Navigator.pushNamed(context, '/children/add').then((_) {
      if (mounted) setState(() {});
    });
  }
}
