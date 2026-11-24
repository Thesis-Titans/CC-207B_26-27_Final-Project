import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/journal_entry.dart';
import '../../models/journal_validators.dart';
import '../../services/api_client.dart';
import '../../services/journal_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/state_views.dart';

/// Form for writing a private journal note about the active child, or
/// editing and deleting one when [entry] is given (#7).
///
/// States the privacy boundary before the text box, shows a 2,000-character
/// counter, and checks the note and date before saving. If the device is
/// offline, the typed note stays in the box so nothing is lost.
class JournalNoteScreen extends StatefulWidget {
  /// Creates the form. Pass [entry] to edit that note instead of writing a
  /// new one. Pass [journalService] in tests; the app leaves it null and
  /// uses the signed-in API client.
  const JournalNoteScreen({super.key, this.entry, this.journalService});

  /// The note to edit, or null to write a new note.
  final JournalEntry? entry;

  /// The service used to save the note, or null to use the signed-in client.
  final JournalService? journalService;

  @override
  State<JournalNoteScreen> createState() => _JournalNoteScreenState();
}

/// State for [JournalNoteScreen].
class _JournalNoteScreenState extends State<JournalNoteScreen> {
  /// The API fields this form has an input for.
  static const _formFields = {'content', 'entryDate'};

  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();

  /// The day the note is about. Defaults to today.
  DateTime _date = DateTime.now();

  /// Whether the note is being sent to the server.
  bool _saving = false;

  /// Whether the last save failed because the device is offline.
  bool _offline = false;

  /// An error that does not belong to one field, shown above Save.
  String? _errorMessage;

  /// The server's error for each field from the last save, keyed by the
  /// API field name: `content` or `entryDate`.
  Map<String, String> _fieldErrors = const {};

  /// Whether the note no longer exists or is not this caregiver's (J4).
  bool _unavailable = false;

  /// Whether this form edits an existing note.
  bool get _isEditing => widget.entry != null;

  /// Fills in the form from the note being edited, if any.
  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry == null) {
      return;
    }
    _contentController.text = entry.content;
    _date = DateTime.tryParse(entry.entryDate) ?? _date;
  }

  /// Disposes the note controller when the screen is removed from the tree.
  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  /// Opens a date picker that cannot pick a future day.
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 6),
      lastDate: now,
      helpText: 'When did you notice it?',
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _fieldErrors = Map.of(_fieldErrors)..remove('entryDate');
      });
    }
  }

  /// Checks the note and date, then saves the note and goes back to the
  /// list with `true` so the list reloads.
  ///
  /// The note is sent as typed, not trimmed, so its line breaks are kept.
  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }
    final dateError = validateEntryDate(_date, now: DateTime.now());
    if (dateError != null) {
      setState(() => _errorMessage = dateError);
      return;
    }

    // Read everything that needs `context` before the first `await`.
    final child = AuthScope.of(context).activeChild;
    final navigator = Navigator.of(context);
    final service =
        widget.journalService ??
        JournalService(apiClient: AuthScope.apiClientOf(context));
    if (child == null) {
      setState(() => _errorMessage = 'Choose a child before writing a note.');
      return;
    }

    // ApiClient refuses every save while it is marked offline, until some
    // later request succeeds. Tapping Save asks to try again, so let this
    // save really try the connection.
    if (service.apiClient.isOffline) {
      service.apiClient.isOffline = false;
    }

    setState(() {
      _saving = true;
      _offline = false;
      _errorMessage = null;
      _fieldErrors = const {};
    });

    try {
      final entryDate = DateFormat('yyyy-MM-dd').format(_date);
      final editing = widget.entry;
      if (editing == null) {
        await service.createJournalEntry(
          childId: child.id,
          entryDate: entryDate,
          content: _contentController.text,
        );
      } else {
        await service.updateJournalEntry(
          childId: child.id,
          entryId: editing.id,
          content: _contentController.text,
          entryDate: entryDate,
        );
      }
      if (!mounted) {
        return;
      }
      navigator.pop(true);
    } on NotFoundApiException {
      // The note was deleted elsewhere, or is not this caregiver's.
      if (mounted) {
        setState(() => _unavailable = true);
      }
    } on NoConnectionApiException {
      // The typed note stays in the box, so it can be saved once online.
      if (mounted) {
        setState(() => _offline = true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        _showServerErrors(error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Asks the caregiver to confirm, then deletes the note being edited and
  /// goes back to the list with `true` so the list reloads.
  Future<void> _delete() async {
    final entry = widget.entry;
    final child = AuthScope.of(context).activeChild;
    if (_saving || entry == null || child == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this note?'),
        content: const Text("This can't be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    // Cancel, or tapping outside the dialog (null), keeps the note.
    if (confirmed != true || !mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    final service =
        widget.journalService ??
        JournalService(apiClient: AuthScope.apiClientOf(context));
    if (service.apiClient.isOffline) {
      service.apiClient.isOffline = false;
    }

    setState(() {
      _saving = true;
      _offline = false;
      _errorMessage = null;
    });

    try {
      await service.deleteJournalEntry(childId: child.id, entryId: entry.id);
      if (!mounted) {
        return;
      }
      navigator.pop(true);
    } on NotFoundApiException {
      if (mounted) {
        setState(() => _unavailable = true);
      }
    } on NoConnectionApiException {
      if (mounted) {
        setState(() => _offline = true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Shows the server's errors from [error] under the fields they belong
  /// to, and any other error above the Save button.
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

  /// Builds the screen: the form, or the "not available" view (J4).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit note' : 'New note'),
        actions: [
          if (_isEditing && !_unavailable)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete note',
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      // J4: reveal nothing about a note that is gone or not this
      // caregiver's, and drop what was on screen.
      body: _unavailable
          ? const EmptyStateView(
              title: "This note isn't available",
              message:
                  'It may have been removed, or it belongs to another account.',
              icon: Icons.lock_outline,
            )
          : _buildForm(context),
    );
  }

  /// The privacy card, the date, the note box and the Save button.
  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final dateError = _fieldErrors['entryDate'];

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.space16),
        children: [
          // The privacy boundary comes before the text box (#7).
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline, color: AppColors.forest),
                const SizedBox(width: AppSpacing.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Private to you',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      Text(
                        'Only you can see this note. It is never shared, '
                        'used for AI ideas, or shown to anyone else.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(DateFormat.yMMMd().format(_date)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppSizes.touchTarget),
              ),
            ),
          ),
          if (dateError != null) ...[
            const SizedBox(height: AppSpacing.space4),
            Text(
              dateError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textError,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.space16),
          TextFormField(
            controller: _contentController,
            keyboardType: TextInputType.multiline,
            minLines: 4,
            maxLines: 8,
            // Shows the "123/2000" counter without cutting pasted text, so
            // the validator can explain the limit instead.
            maxLength: maxJournalLength,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            decoration: InputDecoration(
              labelText: 'What did you notice?',
              alignLabelWithHint: true,
              errorText: _fieldErrors['content'],
            ),
            validator: validateJournalContent,
            onChanged: (_) {
              if (_fieldErrors.containsKey('content')) {
                setState(() {
                  _fieldErrors = Map.of(_fieldErrors)..remove('content');
                });
              }
            },
          ),
          const SizedBox(height: AppSpacing.space16),
          if (_offline) ...[
            const _OfflineDraftNotice(),
            const SizedBox(height: AppSpacing.space16),
          ],
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textError,
              ),
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
                  : const Text('Save note'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tells the caregiver the note was not saved because they are offline,
/// that the draft is kept, and that the note stays private.
class _OfflineDraftNotice extends StatelessWidget {
  const _OfflineDraftNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOffline,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wifi_off, color: AppColors.textOffline, size: 20),
              SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Text(
                  "You're offline",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textOffline,
                  ),
                ),
              ),
              Icon(Icons.lock_outline, color: AppColors.forest, size: 16),
              SizedBox(width: AppSpacing.space4),
              Text(
                'Private',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.space4),
          Text(
            'Reconnect to save changes. Your note is kept here.',
            style: TextStyle(color: AppColors.textOffline),
          ),
        ],
      ),
    );
  }
}
