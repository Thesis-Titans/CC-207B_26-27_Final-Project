import 'package:flutter/material.dart';

import '../../models/child.dart';
import '../../services/api_client.dart';
import '../../services/children_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';

/// Form screen for adding a new child profile.
///
/// Collects child nickname and age band while preserving privacy
/// without requiring full birthdates, legal names, or photos.
class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key, this.childrenService});

  /// Optional injected children service for testing.
  final ChildrenService? childrenService;

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();

  static const Map<String, String> _ageBands = {
    '0–5 months': '0-5m',
    '6–11 months': '6-11m',
    '12–23 months': '12-23m',
    '24–35 months': '24-35m',
    '36–47 months': '36-47m',
    '48–59 months': '48-59m',
    '60–71 months': '60-71m',
  };

  late String _selectedAgeBand;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedAgeBand = '12-23m';
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    final nickname = _nicknameController.text.trim();
    final sessionState = AuthScope.maybeOf(context);

    late final Child newChild;
    final service =
        widget.childrenService ??
        (sessionState != null && AuthScope.maybeOf(context) != null
            ? ChildrenService(apiClient: AuthScope.apiClientOf(context))
            : null);

    if (service == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save a child profile.')),
      );
      return;
    }

    try {
      newChild = await service.createChild(
        nickname: nickname,
        ageBand: _selectedAgeBand,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      final message = error is ApiException
          ? error.message
          : 'Check your connection and try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save child profile. $message')),
      );
      return;
    }

    if (sessionState != null) {
      sessionState.setActiveChild(newChild);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $nickname to your family'),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, newChild);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: AppBar(title: const Text('Add a child')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.space24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Intro
                    Text(
                      'Create a child profile',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    Text(
                      'Just enough details to show age-appropriate activities.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space24),

                    // Nickname Input
                    Text(
                      'Nickname',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    TextFormField(
                      controller: _nicknameController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Maya or Liam',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a nickname';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.space20),

                    // Age Range Dropdown
                    Text(
                      'Age range',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAgeBand,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.cake_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: _ageBands.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.value,
                              child: Text(entry.key),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedAgeBand = value);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.space24),

                    // Privacy Assurance Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.space16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            color: AppColors.forest,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.space12),
                          Expanded(
                            child: Text(
                              'LittleSteps does not require full names, exact birthdates, or photos. Your family data remains private.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space24),

                    // Submit Button
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          AppSizes.touchTarget,
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save child'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
