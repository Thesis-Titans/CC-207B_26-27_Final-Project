import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/age_band.dart';
import '../../models/child.dart';
import '../../models/child_validators.dart';
import '../../routing/app_router.dart';
import '../../services/api_client.dart';
import '../../services/children_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import 'offline_notice.dart';

/// Form for adding a child profile, or editing one when [child] is given
/// (issue #3).
///
/// Caregivers give either a birth month and year (the app shows the age
/// band it leads to) or, if they prefer, an age band directly.
///
/// Fields are checked on the device first, and the server still checks every field
/// when the profile is saved.
class AddChildScreen extends StatefulWidget {
  /// Creates the form. Pass [child] to edit that profile instead of adding
  /// a new one.
  const AddChildScreen({super.key, this.child, this.childrenService});

  /// The profile to edit, or null to add a new child.
  final Child? child;

  /// The service used to save the profile. Tests pass a fake one; the app
  /// leaves it null and uses the signed-in API client.
  final ChildrenService? childrenService;

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

  /// Whether the caregiver picks an age band instead of a birth date.
  bool _useAgeBand = false;

  /// The age band picked when [_useAgeBand] is true.
  AgeBand? _ageBand;

  /// Whether this form edits an existing profile.
  bool get _isEditing => widget.child != null;

  /// Fills in the form from the child being edited, if any.
  @override
  void initState() {
    super.initState();
    final child = widget.child;
    if (child == null) {
      return;
    }
    _nicknameController.text = child.nickname;

    // A birth date is stored as 'YYYY-MM', such as '2025-03'.
    final parts = child.birthMonthYear?.split('-');
    final year = parts == null ? null : int.tryParse(parts[0]);
    final month = parts == null || parts.length < 2
        ? null
        : int.tryParse(parts[1]);
    if (year != null && month != null) {
      _birthYear = year;
      _birthMonth = month;
    } else {
      // No birth date was given, so the profile uses an age band.
      _useAgeBand = true;
      _ageBand = ageBandForCode(child.ageBand);
    }
  }

  /// Disposes the nickname controller when the screen is removed from the tree.
  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  /// Whether the profile is being sent to the server.
  bool _saving = false;

  /// The server's error message from the last save, if it failed.
  String? _errorMessage;

  /// Whether the last save failed because the device is offline.
  bool _offline = false;

  /// The server's error for each field from the last save, keyed by the
  /// API field name: `nickname`, `birthMonthYear` or `ageBand`.
  Map<String, String> _fieldErrors = const {};

  /// The API fields this form has an input for.
  static const _formFields = {'nickname', 'birthMonthYear', 'ageBand'};

  /// Shows the server's errors from [error] under the fields they belong to
  /// An error for a field the form has no input for (such as the
  /// limit on children) is shown above the Save button instead.
  void _showServerErrors(ApiException error) {
    final fieldErrors = <String, String>{};
    String? otherError;
    for (final detail in error.details) {
      final field = detail['field'];
      final issue = detail['issue'];
      if (field is! String || issue is! String) {
        continue;
      }
      if (_formFields.contains(field)) {
        fieldErrors[field] = issue;
      } else {
        otherError ??= issue;
      }
    }
    setState(() {
      _fieldErrors = fieldErrors;
      _errorMessage = fieldErrors.isEmpty
          ? (otherError ?? error.message)
          : otherError;
    });
  }

  /// Removes the server's error for [field] once the caregiver changes it.
  void _clearFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) {
      return;
    }
    setState(() {
      _fieldErrors = Map.of(_fieldErrors)..remove(field);
    });
  }

  /// Checks every field, then saves the profile and makes it the active
  /// child.
  ///
  /// Sends either the age band or the birth month and year, never both,
  /// because the API accepts exactly one of them.
  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    // Read everything that needs `context` before the first `await`.
    final session = AuthScope.of(context);
    final navigator = Navigator.of(context);
    final childrenService =
        widget.childrenService ??
        ChildrenService(apiClient: AuthScope.apiClientOf(context));

    // ApiClient refuses every save while it is marked offline, until some
    // later request succeeds. Tapping Save is the caregiver asking to try
    // again, so let this save really try the connection.
    final apiClient = childrenService.apiClient;
    if (apiClient.isOffline) {
      apiClient.isOffline = false;
    }

    setState(() {
      _saving = true;
      _offline = false;
      _errorMessage = null;
      _fieldErrors = const {};
    });

    try {
      final nickname = _nicknameController.text.trim();
      final ageBand = _useAgeBand ? _ageBand!.code : null;
      final birthMonthYear = _useAgeBand ? null : _birthMonthYear;
      final editing = widget.child;

      final Child child;
      if (editing == null) {
        child = await childrenService.createChild(
          nickname: nickname,
          ageBand: ageBand,
          birthMonthYear: birthMonthYear,
        );
        // A newly added child becomes the active child.
        session.setActiveChild(child);
      } else {
        child = await childrenService.updateChild(
          id: editing.id,
          nickname: nickname,
          ageBand: ageBand,
          birthMonthYear: birthMonthYear,
        );
        // Keep the header chip up to date if the active child was edited.
        if (session.activeChild?.id == child.id) {
          session.setActiveChild(child);
        }
      }
      if (!mounted) {
        return;
      }
      if (navigator.canPop()) {
        navigator.pop(child);
      } else {
        navigator.pushReplacementNamed(AppRouter.initialRoute);
      }
    } on NoConnectionApiException {
      // ApiClient reports a lost connection (and a save tried while it
      // knows it is offline) as NoConnectionApiException. The form keeps
      // what was typed, so Save can simply be tapped again.
      if (!mounted) {
        return;
      }
      setState(() {
        _offline = true;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showServerErrors(error);
    } catch (_) {
      // Any other error also means the request never reached the server.
      if (!mounted) {
        return;
      }
      setState(() {
        _offline = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  /// The picked birth month and year in the API's `YYYY-MM` format,
  /// such as `2025-03`.
  String get _birthMonthYear {
    final month = _birthMonth!.toString().padLeft(2, '0');
    return '$_birthYear-$month';
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
    final years = [for (var i = 0; i < _yearCount; i++) currentYear - i];
    // A dropdown must contain its selected value. An edited child who is
    // now older than the list covers keeps their year, and the birth date
    // check then explains that the age is out of range.
    final birthYear = _birthYear;
    if (birthYear != null && !years.contains(birthYear)) {
      years.add(birthYear);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit child profile' : 'Add child profile'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.space16),
          children: [
            TextFormField(
              controller: _nicknameController,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nickname',
                errorText: _fieldErrors['nickname'],
              ),
              validator: validateNickname,
              onChanged: (_) => _clearFieldError('nickname'),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.space16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Choose an age band instead'),
              value: _useAgeBand,
              onChanged: (value) {
                setState(() {
                  _useAgeBand = value;
                  _fieldErrors = Map.of(_fieldErrors)
                    ..remove('ageBand')
                    ..remove('birthMonthYear');
                });
              },
            ),
            const SizedBox(height: AppSpacing.space8),
            // Only one way of giving the age is on screen, so the form only
            // checks that one. The API needs exactly one of the two.
            if (_useAgeBand)
              DropdownButtonFormField<AgeBand>(
                isExpanded: true,
                initialValue: _ageBand,
                decoration: InputDecoration(
                  labelText: 'Age band',
                  errorText: _fieldErrors['ageBand'],
                ),
                items: [
                  for (final ageBand in ageBands)
                    DropdownMenuItem(
                      value: ageBand,
                      child: Text(ageBand.label),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _ageBand = value;
                  });
                  _clearFieldError('ageBand');
                },
                validator: (value) =>
                    value == null ? 'Choose an age band' : null,
              )
            else ...[
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
                  _clearFieldError('birthMonthYear');
                },
                validator: (value) => value == null ? 'Choose a month' : null,
              ),
              const SizedBox(height: AppSpacing.space16),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _birthYear,
                // A server error about the birth date shows here, under
                // the year, where the local birth date check shows too.
                decoration: InputDecoration(
                  labelText: 'Birth year',
                  errorText: _fieldErrors['birthMonthYear'],
                ),
                items: [
                  for (final year in years)
                    DropdownMenuItem(value: year, child: Text('$year')),
                ],
                onChanged: (value) {
                  setState(() {
                    _birthYear = value;
                  });
                  _clearFieldError('birthMonthYear');
                },
                validator: _validateBirthYear,
              ),
              if (band != null) ...[
                const SizedBox(height: AppSpacing.space8),
                Text('Age band: ${band.label}'),
              ],
            ],
            const SizedBox(height: AppSpacing.space16),
            if (_offline) ...[
              const OfflineNotice(),
              const SizedBox(height: AppSpacing.space16),
            ],
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textError),
              ),
              const SizedBox(height: AppSpacing.space16),
            ],
            SizedBox(
              height: AppSizes.touchTarget,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
