import 'package:flutter/material.dart';

import '../models/child.dart';
import '../theme/app_tokens.dart';

/// Account actions and child switching displayed from the app header.
class AccountMenuSheet extends StatelessWidget {
  const AccountMenuSheet({
    super.key,
    this.email,
    this.children = const [],
    this.activeChildId,
    this.onChildSelected,
    this.onSignOut,
    this.onOpenSettings,
  });

  /// Email address of the signed-in caregiver, when available.
  final String? email;

  /// Child profiles available to the caregiver.
  final List<Child> children;

  /// Identifier of the currently selected child.
  final String? activeChildId;

  /// Called after the caregiver selects a different child.
  final ValueChanged<Child>? onChildSelected;

  /// Called when the caregiver chooses to sign out.
  final VoidCallback? onSignOut;

  /// Opens settings with the current caregiver and child data.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space24,
            AppSpacing.space8,
            AppSpacing.space24,
            AppSpacing.space24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: AppSpacing.space4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.space16),
              Text(
                email ?? 'Account',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.space16),
              if (children.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.space8,
                  ),
                  child: Text(
                    email == null
                        ? 'Sign in to view child profiles.'
                        : 'No children added yet.',
                  ),
                )
              else ...[
                for (final child in children)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: AppSizes.touchTarget,
                    leading: const Icon(Icons.child_care_outlined),
                    title: Text(child.nickname),
                    subtitle: Text(child.ageBand),
                    trailing: child.id == activeChildId
                        ? const Icon(Icons.check, color: AppColors.forest)
                        : null,
                    onTap: onChildSelected == null
                        ? null
                        : () {
                            onChildSelected!(child);
                            Navigator.pop(context);
                          },
                  ),
              ],
              _MenuAction(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Add a child',
                onTap: () => _openRoute(context, '/children/add'),
              ),
              const Divider(height: AppSpacing.space16),
              _MenuAction(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap:
                    onOpenSettings ??
                    () => _openRoute(context, '/account/settings'),
              ),
              _MenuAction(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy notice',
                onTap: () => _openRoute(context, '/account/privacy'),
              ),
              _MenuAction(
                icon: Icons.info_outline,
                label: 'About LittleSteps',
                onTap: () => _openRoute(context, '/account/about'),
              ),
              _MenuAction(
                icon: Icons.help_outline,
                label: 'Help and support',
                onTap: () => _openRoute(context, '/account/help'),
              ),
              const SizedBox(height: AppSpacing.space8),
              OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
              const SizedBox(height: AppSpacing.space8),
              Text(
                'If you share this phone, sign out when you are done.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRoute(BuildContext context, String route) {
    Navigator.pop(context);
    Navigator.pushNamed(context, route);
  }
}

class _MenuAction extends StatelessWidget {
  const _MenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: AppSizes.touchTarget,
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
