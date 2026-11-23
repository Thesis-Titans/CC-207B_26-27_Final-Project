import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/age_band.dart';
import '../../models/child_validators.dart';
import '../../theme/app_tokens.dart';

/// Form for adding a child profile (issue #3).
///
/// Validates the nickname and birth month and year on the device first,
/// and shows the age band they lead to. The server still checks every
/// field when the profile is saved.
class AddChildScreen extends StatefulWidget {
  /// Creates the add child profile screen.
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

/// State for [AddChildScreen].
class _AddChildScreenState extends State<AddChildScreen> {
  /// How many birth years the year picker offers, counting this year.
  ///
  /// The oldest supported age is 71 months (just under 6 years), so a
  /// supported child is born at most 6 calendar years ago.
  static const _yearCount = 7;

  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  int? _birthYear;
  int? _birthMonth;

  /// Disposes the nickname controller when the screen is removed from the tree.
  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  /// Checks every field and shows its error message under it.
  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // Saving through ChildrenService is added in Step 3.
  }

  /// The age band for the picked birth month and year, or null if
  /// either is missing or the age is outside 0-71 months.
  AgeBand? get _derivedBand {
    final year = _birthYear;
    final month = _birthMonth;
    if (year == null || month == null) {
      return null;
    }
    final months = ageInMonths(
      birthYear: year,
      birthMonth: month,
      now: DateTime.now(),
    );
    return ageBandForMonths(months);
  }

  /// Checks the picked birth year together with the picked month.
  String? _validateBirthYear(int? year) {
    if (year == null) {
      return 'Choose a year';
    }
    final month = _birthMonth;
    if (month == null) {
      // The month field shows its own error.
      return null;
    }
    return validateBirthMonthYear(
      year: year,
      month: month,
      now: DateTime.now(),
    );
  }

  /// Builds the screen with a form for adding a child profile.
  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final band = _derivedBand;

    return Scaffold(
      appBar: AppBar(title: const Text('Add child profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.space16),
          children: [
            TextFormField(
              controller: _nicknameController,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nickname'),
              validator: validateNickname,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.space16),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _birthMonth,
              decoration: const InputDecoration(labelText: 'Birth month'),
              items: [
                for (var month = 1; month <= 12; month++)
                  DropdownMenuItem(
                    value: month,
                    child: Text(
                      DateFormat.MMMM().format(DateTime(2000, month)),
                    ),
                  ),
              ],
              onChanged: (value) {
                setState(() {
                  _birthMonth = value;
                });
              },
              validator: (value) => value == null ? 'Choose a month' : null,
            ),
            const SizedBox(height: AppSpacing.space16),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _birthYear,
              decoration: const InputDecoration(labelText: 'Birth year'),
              items: [
                for (var i = 0; i < _yearCount; i++)
                  DropdownMenuItem(
                    value: currentYear - i,
                    child: Text('${currentYear - i}'),
                  ),
              ],
              onChanged: (value) {
                setState(() {
                  _birthYear = value;
                });
              },
              validator: _validateBirthYear,
            ),
            if (band != null) ...[
              const SizedBox(height: AppSpacing.space8),
              Text('Age band: ${band.label}'),
            ],
            const SizedBox(height: AppSpacing.space16),
            SizedBox(
              height: AppSizes.touchTarget,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
