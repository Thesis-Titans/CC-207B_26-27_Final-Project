import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/journal_entry.dart';
import '../../services/api_client.dart';
import '../../services/journal_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/state_views.dart';

/// Journal tab: the caregiver's private notes about the active child,
/// newest first (issue #7).
///
/// Shows loading, empty, error, offline and access denied states. The
/// shell only shows this tab when a caregiver is signed in and a child is
/// active. Note text is never logged.
class JournalScreen extends StatefulWidget {
  /// Creates the journal tab. Pass [journalService] in tests; the app
  /// leaves it null and uses the signed-in API client.
  const JournalScreen({super.key, this.journalService});

  /// The service used to load notes, or null to use the signed-in client.
  final JournalService? journalService;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

/// State for [JournalScreen].
class _JournalScreenState extends State<JournalScreen> {
  /// The request for the active child's notes, or null before the first
  /// load.
  Future<List<JournalEntry>>? _entriesFuture;

  /// The child whose notes are loaded, so switching child reloads them.
  String? _loadedChildId;

  /// Loads the notes the first time, and again whenever the active child
  /// changes. `AuthScope` notifies this screen when the child changes.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final childId = AuthScope.of(context).activeChild?.id;
    if (childId != null && childId != _loadedChildId) {
      _load(childId);
    }
  }

  /// Loads the notes for [childId], sorted newest first.
  void _load(String childId) {
    final service =
        widget.journalService ??
        JournalService(apiClient: AuthScope.apiClientOf(context));
    setState(() {
      _loadedChildId = childId;
      _entriesFuture = service.getJournalEntries(childId).then(_newestFirst);
    });
  }

  /// Loads the notes again for the same child (Retry and Try again).
  void _reload() {
    final childId = _loadedChildId;
    if (childId != null) {
      _load(childId);
    }
  }

  /// Sorts notes by entry date, then by creation time, newest first.
  ///
  /// Entry dates are 'YYYY-MM-DD' text, which sorts in date order.
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

  /// Builds the header and whichever state the notes are in.
  @override
  Widget build(BuildContext context) {
    final childName = AuthScope.of(context).activeChild?.nickname;

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.space16),
        children: [
          ScreenHeader(
            title: 'Journal',
            subtitle: childName == null
                ? 'Your private notes.'
                : 'Your private notes about $childName.',
          ),
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
              return Column(
                children: [
                  for (final entry in entries) _JournalEntryCard(entry: entry),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// The view for a failed load. It never shows the error's own text,
  /// so nothing about the note or child is revealed.
  Widget _buildError(Object? error) {
    if (error is NoConnectionApiException) {
      return _OfflineView(onRetry: _reload);
    }
    // 404 (missing, or not this caregiver's) and 403 look the same, so
    // the caregiver learns nothing about whether the profile exists (J4).
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

/// One note in the list: its date, a short preview and a Private badge.
class _JournalEntryCard extends StatelessWidget {
  const _JournalEntryCard({required this.entry});

  /// The note to show.
  final JournalEntry entry;

  /// Shows 'YYYY-MM-DD' as a readable date, such as 'Nov 24, 2026'.
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
    );
  }
}

/// A small lock badge that marks a note as private.
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

/// Tells the caregiver they are offline, with a "Try again" button.
///
/// Styled like the offline banner on the Milestones screen.
class _OfflineView extends StatelessWidget {
  const _OfflineView({required this.onRetry});

  /// Called when the caregiver taps "Try again".
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
