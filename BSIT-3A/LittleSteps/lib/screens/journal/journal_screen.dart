import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/journal_entry.dart';
import '../../services/api_client.dart';
import '../../services/journal_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/state_views.dart';
import 'journal_note_screen.dart';

/// Displays private observation notes for the active child, newest first.
///
/// Handles loading, empty, error, offline, and access-denied states without
/// logging note content.
class JournalScreen extends StatefulWidget {
  /// Creates a [JournalScreen].
  ///
  /// Supply [journalService] in tests to override the signed-in API client.
  const JournalScreen({super.key, this.journalService});

  /// Service used to load notes, or null to use the signed-in client.
  final JournalService? journalService;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  Future<List<JournalEntry>>? _entriesFuture;
  String? _loadedChildId;
  final _searchController = TextEditingController();
  DateTime? _filterDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filters notes on-device so search terms are never sent to the server.
  List<JournalEntry> _filtered(List<JournalEntry> entries) {
    final query = _searchController.text.trim().toLowerCase();
    final filterDate = _filterDate;
    final day = filterDate == null
        ? null
        : DateFormat('yyyy-MM-dd').format(filterDate);

    return entries.where((entry) {
      final matchesQuery =
          query.isEmpty || entry.content.toLowerCase().contains(query);
      final matchesDay = day == null || entry.entryDate == day;
      return matchesQuery && matchesDay;
    }).toList();
  }

  Future<void> _pickFilterDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 6);
    var initialDate = _filterDate ?? now;
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    } else if (initialDate.isAfter(now)) {
      initialDate = now;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: now,
      helpText: 'Show notes from',
    );
    if (picked != null && mounted) {
      setState(() {
        _filterDate = picked;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final childId = AuthScope.of(context).activeChild?.id;
    if (childId != null && childId != _loadedChildId) {
      // Clear active filters when switching to a different child so previous
      // criteria do not hide the newly selected child's notes.
      if (_loadedChildId != null) {
        _searchController.clear();
        _filterDate = null;
      }
      _load(childId);
    }
  }

  void _load(String childId) {
    final service =
        widget.journalService ??
        JournalService(apiClient: AuthScope.apiClientOf(context));
    setState(() {
      _loadedChildId = childId;
      _entriesFuture = service.getJournalEntries(childId).then(_newestFirst);
    });
  }

  void _reload() {
    final childId = _loadedChildId;
    if (childId != null) {
      _load(childId);
    }
  }

  // Sorts newest first by ISO 'YYYY-MM-DD' entry date, then creation time.
  List<JournalEntry> _newestFirst(List<JournalEntry> entries) {
    final sortedEntries = List<JournalEntry>.from(entries);
    sortedEntries.sort((a, b) {
      final dateComparison = b.entryDate.compareTo(a.entryDate);
      if (dateComparison != 0) {
        return dateComparison;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sortedEntries;
  }

  @override
  Widget build(BuildContext context) {
    final childName = AuthScope.of(context).activeChild?.nickname;

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewNote,
        icon: const Icon(Icons.add),
        label: const Text('New note'),
      ),
      body: ListView(
        // Leave bottom clearance so the extended FAB does not cover the last card.
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space16,
          AppSpacing.space16,
          88,
        ),
        children: [
          ScreenHeader(
            title: 'Journal',
            subtitle: childName == null
                ? 'Your private notes.'
                : 'Your private notes about $childName.',
          ),
          const SizedBox(height: AppSpacing.space16),
          _buildFilters(),
          const SizedBox(height: AppSpacing.space16),
          FutureBuilder<List<JournalEntry>>(
            future: _entriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingView(message: 'Loading notes...');
              }
              if (snapshot.hasError) {
                return _buildError(snapshot.error);
              }
              final entries = snapshot.data ?? const <JournalEntry>[];
              if (entries.isEmpty) {
                return const EmptyStateView(
                  title: 'No notes yet',
                  message:
                      'Write down a moment you noticed. '
                      'Only you can see your notes.',
                  icon: Icons.edit_note,
                );
              }
              final shown = _filtered(entries);
              if (shown.isEmpty) {
                return const EmptyStateView(
                  title: 'No notes match your search',
                  message:
                      'Try a different word or date, '
                      'or clear the filters to see all notes.',
                  icon: Icons.search_off,
                );
              }
              return Column(
                children: [
                  for (final entry in shown)
                    _JournalEntryCard(
                      entry: entry,
                      onTap: () => _openNote(entry),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openNewNote() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            JournalNoteScreen(journalService: widget.journalService),
      ),
    );
    if (saved == true && mounted) {
      _reload();
    }
  }

  Future<void> _openNote(JournalEntry entry) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => JournalNoteScreen(
          entry: entry,
          journalService: widget.journalService,
        ),
      ),
    );
    if (changed == true && mounted) {
      _reload();
    }
  }

  Widget _buildFilters() {
    final filterDate = _filterDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Search notes',
            prefixIcon: Icon(Icons.search),
          ),
          // Rebuild on every change so the list filters while typing.
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.space12),
        Wrap(
          spacing: AppSpacing.space8,
          runSpacing: AppSpacing.space8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _pickFilterDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(
                filterDate == null
                    ? 'Filter by date'
                    : DateFormat.yMMMd().format(filterDate),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppSizes.touchTarget),
              ),
            ),
            if (filterDate != null)
              TextButton(
                onPressed: () => setState(() => _filterDate = null),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.touchTarget),
                ),
                child: const Text('Clear date'),
              ),
          ],
        ),
      ],
    );
  }

  // Omits raw exception text so note or child details are never revealed.
  Widget _buildError(Object? error) {
    if (error is NoConnectionApiException) {
      return _OfflineView(onRetry: _reload);
    }
    // Treat 403 and 404 identically to avoid leaking profile existence.
    final denied =
        error is NotFoundApiException ||
        (error is ApiException && error.statusCode == 403);
    if (denied) {
      return const EmptyStateView(
        title: "This journal isn't available",
        message: 'It may have been removed, or it belongs to another account.',
        icon: Icons.lock_outline,
      );
    }
    return ErrorView(
      message: "Couldn't load your notes. Please try again.",
      onRetry: _reload,
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  const _JournalEntryCard({required this.entry, required this.onTap});

  final JournalEntry entry;
  final VoidCallback onTap;

  String get _formattedDate {
    final date = DateTime.tryParse(entry.entryDate);
    return date == null ? entry.entryDate : DateFormat.yMMMd().format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.space12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      // Clip so the tap ripple stays inside the rounded corners.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formattedDate,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const _PrivateBadge(),
                ],
              ),
              const SizedBox(height: AppSpacing.space8),
              Text(
                entry.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivateBadge extends StatelessWidget {
  const _PrivateBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Icon(Icons.lock_outline, size: 14, color: AppColors.forest),
          const SizedBox(width: AppSpacing.space4),
          Text(
            'Private',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.forest,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineView extends StatelessWidget {
  const _OfflineView({required this.onRetry});

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
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          const Text(
            'Your notes will show when you reconnect.',
            style: TextStyle(color: AppColors.textOffline),
          ),
          const SizedBox(height: AppSpacing.space12),
          SizedBox(
            height: AppSizes.touchTarget,
            child: OutlinedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }
}
