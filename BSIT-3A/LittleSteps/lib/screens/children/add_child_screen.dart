import 'package:flutter/material.dart';

import '../../models/child.dart';
import '../../services/api_client.dart';
import '../../services/children_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';

/// Developmental age bands supported by the child profile API contract.
enum ChildAgeBand {
  /// 0 to 5 months (`0-5m`).
  zeroToFiveMonths('0-5m', '0–5 months'),

  /// 6 to 11 months (`6-11m`).
  sixToElevenMonths('6-11m', '6–11 months'),

  /// 12 to 23 months (`12-23m`).
  twelveToTwentyThreeMonths('12-23m', '12–23 months'),

  /// 24 to 35 months (`24-35m`).
  twentyFourToThirtyFiveMonths('24-35m', '24–35 months'),

  /// 36 to 47 months (`36-47m`).
  thirtySixToFortySevenMonths('36-47m', '36–47 months'),

  /// 48 to 59 months (`48-59m`).
  fortyEightToFiftyNineMonths('48-59m', '48–59 months'),

  /// 60 to 71 months (`60-71m`).
  sixtyToSeventyOneMonths('60-71m', '60–71 months');

  const ChildAgeBand(this.code, this.label);

  /// Wire code sent to the backend API.
  final String code;

  /// Caregiver-facing label displayed in dropdown menus.
  final String label;
}

/// Form screen for registering a child profile with nickname and age band.
///
/// Collects only the fields required for age-appropriate activity filtering
/// (no legal surname, exact birthdate, or photo).
class AddChildScreen extends StatefulWidget {
  /// Creates an [AddChildScreen] with an optional [childrenService] override.
  const AddChildScreen({super.key, this.childrenService});

  /// Optional injected service used in widget tests.
  final ChildrenService? childrenService;

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  // Coordinates validation across all FormField descendants on submission.
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();

  ChildAgeBand _selectedAgeBand = ChildAgeBand.twelveToTwentyThreeMonths;
  bool _saving = false;

  @override
  void dispose() {
    // Release native text-input listeners when the screen leaves the tree.
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

    final service =
        widget.childrenService ??
        (sessionState != null
            ? ChildrenService(apiClient: AuthScope.apiClientOf(context))
            : null);

    if (service == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save a child profile.')),
      );
      return;
    }

    late final Child newChild;
    try {
      newChild = await service.createChild(
        nickname: nickname,
        ageBand: _selectedAgeBand.code,
      );
    } catch (error) {
      // Guard BuildContext usage after the async network gap.
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
      // Return the created Child model to the calling screen.
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
                    Text(
                      'Age range',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    DropdownButtonFormField<ChildAgeBand>(
                      initialValue: _selectedAgeBand,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.cake_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: ChildAgeBand.values
                          .map(
                            (band) => DropdownMenuItem(
                              value: band,
                              child: Text(band.label),
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
