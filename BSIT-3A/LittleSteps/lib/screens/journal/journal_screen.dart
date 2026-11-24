import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/child.dart';
import '../../models/journal_entry.dart';
import '../../services/api_client.dart';
import '../../services/journal_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/state_views.dart';

/// Maximum allowed length for a single private journal note.
const int maxJournalNoteLength = 2000;

/// Journal tab displaying private caregiver observations for the active child.
///
/// Supports creating, editing, searching, date filtering, and deleting private
/// notes while enforcing strict privacy boundaries and offline draft retention.
class JournalScreen extends StatefulWidget {
  /// Creates a [JournalScreen].
  const JournalScreen({
    super.key,
    this.journalService,
    this.activeChild,
    this.initialEntries,
  });

  /// Optional journal service override used in tests.
  final JournalService? journalService;

  /// Optional active child override used outside [AuthScope].
  final Child? activeChild;

  /// Optional preloaded entries used in tests or previews.
  final List<JournalEntry>? initialEntries;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<JournalEntry> _entries = const [];
  bool _loading = true;
  bool _offline = false;
  bool _accessDenied = false;
  String? _errorMessage;

  String _searchQuery = '';
  String? _selectedDateFilter;

  String? _lastChildId;
  bool _initialLoadStarted = false;
  int _requestNumber = 0;

  Child? get _effectiveChild =>
      widget.activeChild ?? AuthScope.maybeOf(context)?.activeChild;

  JournalService _resolveJournalService() {
    if (widget.journalService != null) return widget.journalService!;
    final apiClient = AuthScope.maybeOf(context) != null
        ? AuthScope.apiClientOf(context)
        : ApiClient();
    return JournalService(apiClient: apiClient);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialEntries != null) {
      _entries = _sortedEntries(widget.initialEntries!);
      _loading = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final activeChild = _effectiveChild;
    final childId = activeChild?.id;
    final childChanged = childId != _lastChildId;

    if (!_initialLoadStarted || childChanged) {
      _initialLoadStarted = true;
      _lastChildId = childId;
      // Clear displayed entries and filters immediately on child switch so
      // private notes from one child never flash under another child's header.
      if (childChanged) {
        _searchController.clear();
        _searchQuery = '';
        _selectedDateFilter = null;
        _accessDenied = false;
        _errorMessage = null;
        _offline = false;
        if (widget.initialEntries == null) {
          _entries = const [];
        }
      }
      if (widget.initialEntries == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_loadEntries());
        });
      }
    }
  }

  List<JournalEntry> _sortedEntries(List<JournalEntry> items) {
    final copy = List<JournalEntry>.of(items);
    copy.sort((a, b) {
      final dateCmp = b.entryDate.compareTo(a.entryDate);
      if (dateCmp != 0) return dateCmp;
      return b.createdAt.compareTo(a.createdAt);
    });
    return copy;
  }

  Future<void> _loadEntries() async {
    final childId = _effectiveChild?.id;
    final session = AuthScope.maybeOf(context);
    final canFetch =
        widget.journalService != null || (session?.isAuthenticated ?? false);
    if (childId == null || !canFetch) {
      setState(() {
        _loading = false;
        _entries = const [];
      });
      return;
    }

    final requestNumber = ++_requestNumber;
    final requestChildId = childId;
    final service = _resolveJournalService();
    service.apiClient.isOffline = false;

    setState(() {
      _loading = true;
      _offline = false;
      _accessDenied = false;
      _errorMessage = null;
    });

    try {
      final fetched = await service.getJournalEntries(requestChildId);
      // Drop stale responses if the caregiver switched children mid-request.
      if (!mounted ||
          _lastChildId != requestChildId ||
          requestNumber != _requestNumber) {
        return;
      }
      setState(() {
        _entries = _sortedEntries(fetched);
        _loading = false;
        _offline = service.apiClient.isOffline;
      });
    } on NoConnectionApiException {
      if (!mounted ||
          _lastChildId != requestChildId ||
          requestNumber != _requestNumber) {
        return;
      }
      setState(() {
        _loading = false;
        _offline = true;
      });
    } on TimeoutApiException {
      if (!mounted ||
          _lastChildId != requestChildId ||
          requestNumber != _requestNumber) {
        return;
      }
      setState(() {
        _loading = false;
        _offline = true;
      });
    } on ApiException catch (error) {
      if (!mounted ||
          _lastChildId != requestChildId ||
          requestNumber != _requestNumber) {
        return;
      }
      if (error.statusCode == 403 || error.statusCode == 404) {
        setState(() {
          _loading = false;
          _accessDenied = true;
          _entries = const [];
        });
      } else {
        setState(() {
          _loading = false;
          _errorMessage = 'Your journal notes could not be loaded right now. Try again in a moment.';
        });
      }
    } catch (error) {
      if (!mounted ||
          _lastChildId != requestChildId ||
          requestNumber != _requestNumber) {
        return;
      }
      final isNetworkError =
          error is NoConnectionApiException ||
          error is TimeoutApiException ||
          error is SocketException ||
          error is http.ClientException;
      setState(() {
        _loading = false;
        _offline = isNetworkError;
        _errorMessage = isNetworkError ? null : 'Your journal notes could not be loaded right now. Try again in a moment.';
      });
    }
  }

  List<JournalEntry> get _filteredEntries {
    final query = _searchQuery.trim().toLowerCase();
    return _entries.where((entry) {
      if (_selectedDateFilter != null &&
          entry.entryDate != _selectedDateFilter) {
        return false;
      }
      if (query.isNotEmpty &&
          !entry.content.toLowerCase().contains(query) &&
          !entry.entryDate.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  String _formatDateIso(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _pickDateFilter() async {
    final now = DateTime.now();
    final initial = _selectedDateFilter != null
        ? (DateTime.tryParse(_selectedDateFilter!) ?? now)
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDateFilter = _formatDateIso(picked);
    });
  }

  Future<void> _openEditor({JournalEntry? existing}) async {
    final child = _effectiveChild;
    if (child == null) return;
    final service = _resolveJournalService();
    final session = AuthScope.maybeOf(context);
    final savedEntry = await showModalBottomSheet<JournalEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (sheetContext) => _JournalEditorSheet(
        child: child,
        existing: existing,
        initialDraft: existing == null ? session?.unsavedDraft : null,
        onDraftChanged: (draft) {
          if (existing == null) {
            session?.setUnsavedDraft(draft.isEmpty ? null : draft);
          }
        },
        onSave: (entryDate, content) async {
          if (service.apiClient.isOffline) {
            service.apiClient.isOffline = false;
          }
          if (existing == null) {
            final created = await service.createJournalEntry(
              childId: child.id,
              entryDate: entryDate,
              content: content,
            );
            session?.clearUnsavedDraft();
            return created;
          }
          return service.updateJournalEntry(
            childId: child.id,
            entryId: existing.id,
            content: content,
          );
        },
      ),
    );

    if (savedEntry == null || !mounted) return;
    setState(() {
      final updated = List<JournalEntry>.of(_entries)
        ..removeWhere((item) => item.id == savedEntry.id)
        ..add(savedEntry);
      _entries = _sortedEntries(updated);
      _accessDenied = false;
      _errorMessage = null;
      _offline = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? 'Private note saved.' : 'Private note updated.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(JournalEntry entry) async {
    final child = _effectiveChild;
    if (child == null) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete this note?'),
            content: const Text(
              'This permanently deletes this private note from your journal.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete note'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    final service = _resolveJournalService();
    try {
      await service.deleteJournalEntry(childId: child.id, entryId: entry.id);
      if (!mounted) return;
      setState(() {
        _entries = _entries.where((item) => item.id != entry.id).toList();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Private note deleted.')));
    } on NoConnectionApiException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You're offline. Reconnect to delete this private note.",
          ),
        ),
      );
    } on TimeoutApiException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You're offline. Reconnect to delete this private note.",
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 403 || error.statusCode == 404) {
        setState(() => _accessDenied = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We could not delete this note. Please try again.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You're offline. Reconnect to delete this private note.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeChild = _effectiveChild;
    final subtitle = activeChild != null
        ? 'Private notes about ${activeChild.nickname}.'
        : 'Private notes and everyday moments you choose to remember.';
    final visibleEntries = _filteredEntries;

    return RefreshIndicator(
      onRefresh: _loadEntries,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.space16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ScreenHeader(title: 'Journal', subtitle: subtitle),
              ),
              if (activeChild != null && _entries.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.space8),
                SizedBox(
                  height: AppSizes.touchTarget,
                  child: FilledButton.icon(
                    onPressed: () => _openEditor(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add note'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.space16),
          const _PrivacyNoticeBanner(),
          const SizedBox(height: AppSpacing.space16),
          if (_offline) ...[
            _OfflineJournalBanner(onRetry: _loadEntries),
            const SizedBox(height: AppSpacing.space16),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.space24),
              child: LoadingView(message: 'Loading journal notes...'),
            )
          else if (_accessDenied)
            _AccessDeniedJournalCard(onRetry: _loadEntries)
          else if (_errorMessage != null)
            ErrorView(message: _errorMessage!, onRetry: _loadEntries)
          else if (_entries.isEmpty)
            EmptyStateView(
              title: 'No journal notes yet',
              message: 'Your journal is private to you. Jot down a memory or everyday moment.',
              icon: Icons.book_outlined,
              actionLabel: activeChild != null ? 'Add observation' : null,
              onAction: activeChild != null ? () => _openEditor() : null,
            )
          else ...[
            _buildSearchAndDateRow(),
            const SizedBox(height: AppSpacing.space12),
            if (visibleEntries.isEmpty)
              EmptyStateView(
                title: 'No matching notes',
                message: 'Try another search word or clear the date filter.',
                icon: Icons.search_off_outlined,
                actionLabel: 'Clear filters',
                onAction: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedDateFilter = null;
                  });
                },
              )
            else
              for (final entry in visibleEntries)
                _JournalEntryCard(
                  entry: entry,
                  onEdit: () => _openEditor(existing: entry),
                  onDelete: () => _confirmDelete(entry),
                ),
          ],
          const SizedBox(height: AppSpacing.space24),
        ],
      ),
    );
  }

  Widget _buildSearchAndDateRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('journal-search'),
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: const InputDecoration(
              hintText: 'Search your notes',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space8),
        SizedBox(
          height: AppSizes.touchTarget,
          child: OutlinedButton.icon(
            key: const ValueKey('journal-date-filter'),
            onPressed: _selectedDateFilter == null
                ? _pickDateFilter
                : () => setState(() => _selectedDateFilter = null),
            icon: Icon(
              _selectedDateFilter == null
                  ? Icons.calendar_today_outlined
                  : Icons.close,
              size: 18,
            ),
            label: Text(_selectedDateFilter ?? 'Date'),
          ),
        ),
      ],
    );
  }
}

class _PrivacyNoticeBanner extends StatelessWidget {
  const _PrivacyNoticeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space12,
      ),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 18, color: AppColors.forest),
          const SizedBox(width: AppSpacing.space8),
          Expanded(
            child: Text(
              'Private by design. Only you can see these notes. They are never sent to external AI, analytics, or logs.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineJournalBanner extends StatelessWidget {
  const _OfflineJournalBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOffline,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wifi_off, size: 18, color: AppColors.textOffline),
              SizedBox(width: AppSpacing.space8),
              Text(
                "You're offline",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textOffline,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          const Text(
            'Reconnect to sync private notes. Any open draft stays on screen.',
            style: TextStyle(color: AppColors.textOffline),
          ),
          const SizedBox(height: AppSpacing.space12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _AccessDeniedJournalCard extends StatelessWidget {
  const _AccessDeniedJournalCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lock_outline, color: AppColors.textError, size: 20),
                SizedBox(width: AppSpacing.space8),
                Expanded(
                  child: Text(
                    "We can't open this note",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textError,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space8),
            const Text(
              "We can't open this note. It may have been deleted. Your own notes are safe.",
            ),
            const SizedBox(height: AppSpacing.space12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  const _JournalEntryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final JournalEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: AppSpacing.space12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.space8,
                    runSpacing: AppSpacing.space4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        entry.entryDate,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.softGreen,
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              size: 12,
                              color: AppColors.forest,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Private',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.forest,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit note',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Delete note',
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.textError,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space8),
            Text(entry.content, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _JournalEditorSheet extends StatefulWidget {
  const _JournalEditorSheet({
    required this.child,
    required this.onSave,
    this.existing,
    this.initialDraft,
    this.onDraftChanged,
  });

  final Child child;
  final JournalEntry? existing;
  final String? initialDraft;
  final ValueChanged<String>? onDraftChanged;
  final Future<JournalEntry> Function(String entryDate, String content) onSave;

  @override
  State<_JournalEditorSheet> createState() => _JournalEditorSheetState();
}

class _JournalEditorSheetState extends State<_JournalEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contentController;
  late DateTime _selectedDate;
  bool _saving = false;
  bool _offlineError = false;
  String? _submitError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.existing?.content ?? widget.initialDraft ?? '',
    );
    final existingDate = widget.existing != null
        ? DateTime.tryParse(widget.existing!.entryDate)
        : null;
    _selectedDate = existingDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  String _formatDateIso(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _offlineError = false;
      _submitError = null;
    });

    try {
      final saved = await widget.onSave(
        _formatDateIso(_selectedDate),
        _contentController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, saved);
    } on NoConnectionApiException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _offlineError = true;
      });
    } on TimeoutApiException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _offlineError = true;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _submitError = error.statusCode == 400 || error.statusCode == 422
            ? 'Notes can be up to 2,000 characters. Please make this one a little shorter.'
            : 'We could not save this note right now. Try again in a moment.';
      });
    } catch (error) {
      if (!mounted) return;
      final isNetworkError =
          error is NoConnectionApiException ||
          error is TimeoutApiException ||
          error is SocketException ||
          error is http.ClientException;
      setState(() {
        _saving = false;
        _offlineError = isNetworkError;
        _submitError = isNetworkError
            ? null
            : 'We could not save this note right now. Try again in a moment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final currentLength = _contentController.text.length;
    final isOverLimit = currentLength > maxJournalNoteLength;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space8,
        AppSpacing.space16,
        bottomInset + AppSpacing.space24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Edit private note' : 'New private note',
                    style: theme.textTheme.titleLarge,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space8,
                      vertical: AppSpacing.space4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.softGreen,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: AppColors.forest,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Private',
                          style: TextStyle(
                            color: AppColors.forest,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                'For ${widget.child.nickname}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space12),
              const _PrivacyNoticeBanner(),
              const SizedBox(height: AppSpacing.space12),
              if (!_isEditing) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const ValueKey('journal-editor-date'),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text('Date: ${_formatDateIso(_selectedDate)}'),
                  ),
                ),
                const SizedBox(height: AppSpacing.space12),
              ],
              TextFormField(
                key: const ValueKey('journal-note-input'),
                controller: _contentController,
                maxLines: 5,
                minLines: 3,
                onChanged: (value) {
                  setState(() {});
                  widget.onDraftChanged?.call(value);
                },
                decoration: const InputDecoration(
                  labelText: 'Observation note',
                  hintText: 'Write a private memory or everyday moment...',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Write a short note before saving.';
                  }
                  if (trimmed.length > maxJournalNoteLength) {
                    return 'Notes can be up to 2,000 characters. Please make this one a little shorter.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.space4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$currentLength / 2,000',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isOverLimit
                        ? AppColors.textError
                        : AppColors.textSecondary,
                    fontWeight: isOverLimit ? FontWeight.bold : null,
                  ),
                ),
              ),
              if (_offlineError) ...[
                const SizedBox(height: AppSpacing.space12),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOffline,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: const Text(
                    "You're offline. Your note wasn't saved. Keep this screen open and tap Save when you're back online.",
                    style: TextStyle(color: AppColors.textOffline),
                  ),
                ),
              ],
              if (_submitError != null) ...[
                const SizedBox(height: AppSpacing.space12),
                Text(
                  _submitError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textError,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.space16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () {
                              widget.onDraftChanged?.call('');
                              Navigator.pop(context);
                            },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('journal-save-button'),
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save note'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
