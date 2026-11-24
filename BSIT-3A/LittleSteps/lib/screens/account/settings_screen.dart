import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/child.dart';
import '../../models/weather.dart';
import '../../services/account_service.dart';
import '../../services/children_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';

/// Account, child profile and data-rights settings.
class SettingsScreen extends StatefulWidget {
  /// Creates a [SettingsScreen].
  const SettingsScreen({
    super.key,
    this.email,
    this.children = const [],
    this.accountService,
    this.childrenService,
    this.onSignOut,
    this.onAccountDeleted,
    this.onChildDeleted,
  });

  /// Email address of the signed-in caregiver, when available.
  final String? email;

  /// Child profiles associated with this caregiver.
  final List<Child> children;

  /// Service for export and account deletion requests.
  final AccountService? accountService;

  /// Service for child profile deletion requests.
  final ChildrenService? childrenService;

  /// Called when the caregiver chooses to sign out.
  final VoidCallback? onSignOut;

  /// Called after account deletion succeeds.
  final VoidCallback? onAccountDeleted;

  /// Called with the id of a child after deletion succeeds.
  final ValueChanged<String>? onChildDeleted;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;
  final Set<String> _deletingChildren = {};
  bool _isDeletingAccount = false;
  late final List<Child> _children = List.of(widget.children);
  WeatherLocation? _localWeatherLocation = WeatherLocation.iloiloCity;

  WeatherLocation? _currentWeatherLocation(BuildContext context) {
    final session = AuthScope.maybeOf(context);
    if (session != null) return session.weatherLocation;
    return _localWeatherLocation;
  }

  void _updateWeatherLocation(BuildContext context, String? cityName) {
    final selected = WeatherLocation.byName(cityName);
    final session = AuthScope.maybeOf(context);
    if (session != null) {
      session.setWeatherLocation(selected);
    } else {
      setState(() => _localWeatherLocation = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.space16),
            children: [
              _SettingsGroup(
                title: 'Account',
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: Text(widget.email ?? 'Account details'),
                    subtitle: Text(
                      widget.email == null
                          ? 'Sign in to view caregiver details.'
                          : 'Signed-in caregiver',
                    ),
                  ),
                  _SettingsAction(
                    icon: Icons.logout,
                    title: 'Sign out',
                    subtitle: 'Sign out when you are done on a shared phone.',
                    onTap: widget.onSignOut ?? _showSignInUnavailable,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space16),
              _SettingsGroup(
                title: 'Children',
                children: [
                  if (_children.isEmpty)
                    ListTile(
                      leading: const Icon(Icons.child_care_outlined),
                      title: Text(
                        widget.email == null
                            ? 'Sign in to view child profiles'
                            : 'No children added yet',
                      ),
                    )
                  else
                    for (final child in _children)
                      _SettingsAction(
                        icon: Icons.delete_outline,
                        title: 'Delete ${child.nickname}’s records',
                        subtitle: 'Remove this child and their saved records.',
                        isLoading: _deletingChildren.contains(child.id),
                        isDestructive: true,
                        onTap: widget.childrenService == null
                            ? _showSignInUnavailable
                            : () => _confirmDeleteChild(child),
                      ),
                  _SettingsAction(
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'Add a child',
                    onTap: () => Navigator.pushNamed(context, '/children/add'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space16),
              _SettingsGroup(
                title: 'Your data',
                children: [
                  _SettingsAction(
                    icon: Icons.download_outlined,
                    title: 'Download my data',
                    subtitle: 'Get a JSON copy of your account and child data, including journal notes.',
                    isLoading: _isExporting,
                    onTap: _downloadData,
                  ),
                  _SettingsAction(
                    icon: Icons.delete_forever_outlined,
                    title: 'Delete my account',
                    subtitle:
                        'Permanently remove your account and its records.',
                    isLoading: _isDeletingAccount,
                    isDestructive: true,
                    onTap: widget.accountService == null
                        ? _showSignInUnavailable
                        : _confirmDeleteAccount,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space16),
              _SettingsGroup(
                title: 'Weather for activity ideas',
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.space16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          key: const ValueKey('settings_weather_city_dropdown'),
                          isExpanded: true,
                          initialValue:
                              _currentWeatherLocation(context)?.name ?? '',
                          decoration: const InputDecoration(
                            labelText: 'City',
                            prefixIcon: Icon(Icons.wb_sunny_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('Off (no weather hints)'),
                            ),
                            for (final city
                                in WeatherLocation.philippinesCities)
                              DropdownMenuItem<String>(
                                value: city.name,
                                child: Text(city.name),
                              ),
                          ],
                          onChanged: (value) =>
                              _updateWeatherLocation(context, value),
                        ),
                        const SizedBox(height: AppSpacing.space8),
                        Text(
                          'Weather data by Open-Meteo.com. No location data is stored beyond your chosen city.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.accountService == null ||
                  widget.childrenService == null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.space12),
                  child: Text(
                    'Account actions will be available after sign-in is connected.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadData() async {
    final service = widget.accountService;
    if (service == null) {
      _showSignInUnavailable();
      return;
    }

    setState(() => _isExporting = true);
    try {
      final json = const JsonEncoder.withIndent('  ')
          .convert(await service.exportData());
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(json),
              mimeType: 'application/json',
              name: 'littlesteps-data.json',
            ),
          ],
          fileNameOverrides: const ['littlesteps-data.json'],
          title: 'Your LittleSteps data',
          downloadFallbackEnabled: true,
        ),
      );
    } catch (_) {
      _showMessage('We could not prepare your data. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _confirmDeleteChild(Child child) async {
    final confirmed = await _confirmDeletion(
      title: 'Delete ${child.nickname}’s records?',
      message:
          'This permanently deletes ${child.nickname}’s profile, plans, '
          'observations, journal entries and weekly summaries.',
      confirmLabel: 'Delete records',
    );
    if (!confirmed || !mounted) return;

    final service = widget.childrenService;
    if (service == null) {
      _showSignInUnavailable();
      return;
    }

    setState(() => _deletingChildren.add(child.id));
    try {
      await service.deleteChild(child.id);
      if (mounted) {
        setState(() => _children.removeWhere((item) => item.id == child.id));
      }
      widget.onChildDeleted?.call(child.id);
      _showMessage('${child.nickname}’s records were deleted.');
    } catch (_) {
      _showMessage('We could not delete these records. Try again.');
    } finally {
      if (mounted) setState(() => _deletingChildren.remove(child.id));
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await _confirmDeletion(
      title: 'Delete your account?',
      message:
          'This permanently deletes your account, all child profiles, plans, '
          'observations, journal entries and weekly summaries.',
      confirmLabel: 'Delete account',
    );
    if (!confirmed || !mounted) return;

    final service = widget.accountService;
    if (service == null) {
      _showSignInUnavailable();
      return;
    }

    setState(() => _isDeletingAccount = true);
    try {
      await service.deleteAccount();
      if (widget.onAccountDeleted != null) {
        widget.onAccountDeleted!();
      } else if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/sign-in', (_) => false);
      }
    } catch (_) {
      _showMessage('We could not delete your account. Try again.');
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  Future<bool> _confirmDeletion({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSignInUnavailable() {
    _showMessage('Sign in to use this account action.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.space8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const Divider(height: 1),
                children[index],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isLoading = false,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.textError : null;
    return ListTile(
      minTileHeight: AppSizes.touchTarget,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: isLoading
          ? const SizedBox.square(
              dimension: AppSpacing.space24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: isLoading ? null : onTap,
    );
  }
}
