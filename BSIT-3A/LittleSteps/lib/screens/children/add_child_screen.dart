import 'package:flutter/material.dart';

import '../../models/child.dart';
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

  static const List<String> _ageBands = [
    '0-11 months (Babies)',
    '12-23 months (Young Toddlers)',
    '24-35 months (Older Toddlers)',
    '36-47 months (Young Preschoolers)',
    '48-59 months (Older Preschoolers)',
  ];

  late String _selectedAgeBand;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedAgeBand = _ageBands[1]; // Default to 12-23 months
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

    // Format ageBand to clean string (e.g., '12-23m')
    final cleanAgeBand = _selectedAgeBand.split(' ').first;

    final newChild = Child(
      id: 'child-${DateTime.now().millisecondsSinceEpoch}',
      nickname: nickname,
      ageBand: cleanAgeBand,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

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
                      items: _ageBands.map((band) {
                        return DropdownMenuItem(value: band, child: Text(band));
                      }).toList(),
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
