import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../models/book.dart';
import '../../models/child.dart';
import '../../models/plan.dart';
import '../../models/rhyme.dart';
import '../../services/ai_service.dart';
import '../../services/api_client.dart';
import '../../services/books_service.dart';
import '../../services/catalog_service.dart';
import '../../services/plan_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_formatting.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/state_views.dart';
import 'play_companion_dialog.dart';
import 'widgets/rhymes_shelf.dart';
import 'widgets/storybook_grid.dart';

/// Shelf tabs available inside [StorybooksSection].
enum BookshelfShelf {
  /// Searchable children's catalog sourced from Open Library.
  openLibrary,

  /// Books saved to the active child's family bookshelf.
  ourBookshelf,

  /// Curated traditional Philippine rhymes and singing routines.
  rhymes,
}

/// Explore section hosting Open Library books, saved books, and rhymes.
class StorybooksSection extends StatefulWidget {
  /// Creates a [StorybooksSection].
  const StorybooksSection({
    super.key,
    this.booksService,
    this.catalogService,
    this.aiService,
    this.planService,
    this.activeChild,
    this.selectedShelf = BookshelfShelf.openLibrary,
    this.isOffline = false,
    this.onShelfSelected,
    this.onSavedCountChanged,
    this.onPlanActivity,
  });

  /// Optional books service override used in tests.
  final BooksService? booksService;

  /// Optional catalog service override for fetching live Philippine rhymes.
  final CatalogService? catalogService;

  /// Optional AI service override for generating story play companions.
  final AiService? aiService;

  /// Optional plan service override for scheduling story activities.
  final PlanService? planService;

  /// Currently selected child profile, or `null` when unavailable.
  final Child? activeChild;

  /// Active bookshelf tab to display.
  final BookshelfShelf selectedShelf;

  /// Whether the parent screen is currently offline.
  final bool isOffline;

  /// Callback invoked when the caregiver switches bookshelf tabs.
  final ValueChanged<BookshelfShelf>? onShelfSelected;

  /// Callback invoked whenever the saved books count changes.
  final ValueChanged<int>? onSavedCountChanged;

  /// Callback invoked when a story or rhyme activity is added to today's plan.
  final void Function(Activity activity)? onPlanActivity;

  @override
  State<StorybooksSection> createState() => _StorybooksSectionState();
}

class _StorybooksSectionState extends State<StorybooksSection> {
  String? _selectedSubject;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _isLoadingBooks = true;
  bool _initialBooksLoaded = false;
  bool _isLoadingRhymes = false;
  bool _initialRhymesLoaded = false;
  String? _booksError;
  String? _rhymesError;
  bool _showingOfflineBooks = false;
  List<BookItem> _openLibraryBooks = [];
  List<PhilippineRhyme> _rhymes = [];

  bool _isLoadingSaved = false;
  String? _savedBooksError;
  bool _showingSavedBooksOffline = false;
  String? _lastLoadedChildId;
  List<SavedBook> _savedBooks = [];
  final Set<String> _pendingSaves = {};

  static const List<Map<String, String>> _subjects = [
    {'id': 'picture_books', 'label': 'Picture books'},
    {'id': 'animals', 'label': 'Animals'},
    {'id': 'bedtime', 'label': 'Bedtime'},
    {'id': 'colors', 'label': 'Colors'},
  ];
  static const int _bookPageSize = 8;
  static const int _catalogLimit = 30;
  static const int _searchLimit = 20;

  int _visibleCatalogCount = _bookPageSize;
  int _visibleSavedCount = _bookPageSize;

  BooksService _resolveBooksService() {
    if (widget.booksService != null) return widget.booksService!;
    final session = AuthScope.maybeOf(context);
    final client = session != null && AuthScope.maybeOf(context) != null
        ? AuthScope.apiClientOf(context)
        : ApiClient();
    return BooksService(apiClient: client);
  }

  CatalogService _resolveCatalogService() {
    if (widget.catalogService != null) return widget.catalogService!;
    return CatalogService(apiClient: _resolveBooksService().apiClient);
  }

  AiService _resolveAiService() {
    if (widget.aiService != null) return widget.aiService!;
    final session = AuthScope.maybeOf(context);
    final client = session != null && AuthScope.maybeOf(context) != null
        ? AuthScope.apiClientOf(context)
        : ApiClient();
    return AiService(apiClient: client);
  }

  PlanService _resolvePlanService() {
    if (widget.planService != null) return widget.planService!;
    final session = AuthScope.maybeOf(context);
    final client = session != null && AuthScope.maybeOf(context) != null
        ? AuthScope.apiClientOf(context)
        : ApiClient();
    return PlanService(apiClient: client);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialBooksLoaded) {
      _initialBooksLoaded = true;
      _loadOpenLibraryBooks();
    }
    if (!_initialRhymesLoaded) {
      _initialRhymesLoaded = true;
      _loadRhymes();
    }
    final childId = widget.activeChild?.id;
    if (_lastLoadedChildId != childId) {
      _lastLoadedChildId = childId;
      _loadSavedBooks();
    }
  }

  @override
  void didUpdateWidget(covariant StorybooksSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeChild?.id != widget.activeChild?.id) {
      _lastLoadedChildId = widget.activeChild?.id;
      _loadSavedBooks();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRhymes() async {
    final canFetch =
        widget.catalogService != null || AuthScope.maybeOf(context) != null;
    if (!canFetch) return;

    setState(() {
      _isLoadingRhymes = true;
      _rhymesError = null;
    });

    try {
      final fetched = await _resolveCatalogService().getRhymes();
      if (!mounted) return;
      setState(() {
        _rhymes = fetched;
        _isLoadingRhymes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingRhymes = false;
        if (_rhymes.isEmpty) {
          _rhymesError = 'Could not load rhymes right now. Please check your connection and try again.';
        }
      });
    }
  }

  Future<void> _loadOpenLibraryBooks() async {
    setState(() {
      _isLoadingBooks = true;
      _booksError = null;
    });

    try {
      final service = _resolveBooksService();
      final results = _searchQuery.trim().isNotEmpty
          ? await service.searchBooks(_searchQuery.trim(), limit: _searchLimit)
          : await service.fetchBooks(
              subject: _selectedSubject,
              limit: _catalogLimit,
            );

      if (mounted) {
        setState(() {
          _openLibraryBooks = results;
          _visibleCatalogCount = _bookPageSize;
          _isLoadingBooks = false;
          _showingOfflineBooks =
              widget.isOffline || service.apiClient.isOffline;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _openLibraryBooks = [];
          _visibleCatalogCount = _bookPageSize;
          _isLoadingBooks = false;
          _showingOfflineBooks = false;
          _booksError = 'Could not load storybooks right now. Please check your connection and try again.';
        });
      }
    }
  }

  Future<void> _loadSavedBooks() async {
    final childId = widget.activeChild?.id;
    final session = AuthScope.maybeOf(context);
    final canFetchSaved =
        widget.booksService != null || (session?.isAuthenticated ?? false);
    if (childId == null || !canFetchSaved) {
      setState(() {
        _savedBooks = [];
        _visibleSavedCount = _bookPageSize;
        _isLoadingSaved = false;
        _savedBooksError = null;
        _showingSavedBooksOffline = false;
      });
      widget.onSavedCountChanged?.call(0);
      return;
    }

    setState(() {
      _isLoadingSaved = true;
      _savedBooksError = null;
    });

    try {
      final service = _resolveBooksService();
      final saved = await service.fetchSavedBooks(childId);
      if (mounted) {
        setState(() {
          _savedBooks = saved;
          _visibleSavedCount = _bookPageSize;
          _isLoadingSaved = false;
          _showingSavedBooksOffline =
              widget.isOffline || service.apiClient.isOffline;
        });
        widget.onSavedCountChanged?.call(saved.length);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingSaved = false;
          _savedBooksError = 'Your bookshelf could not be loaded. Check your connection and try again.';
        });
      }
    }
  }

  bool _isBookSaved(String bookId) {
    return _savedBooks.any((b) => b.id == bookId);
  }

  Future<void> _handleToggleSave(BookItem book) async {
    final childId = widget.activeChild?.id;
    if (childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a child to save books.'),
        ),
      );
      return;
    }

    final isCurrentlySaved = _isBookSaved(book.id);
    setState(() => _pendingSaves.add(book.id));

    final service = _resolveBooksService();
    try {
      if (isCurrentlySaved) {
        await service.removeBookFromShelf(childId, book.id);
        if (mounted) {
          setState(() {
            _savedBooks.removeWhere((b) => b.id == book.id);
            _pendingSaves.remove(book.id);
          });
          widget.onSavedCountChanged?.call(_savedBooks.length);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed "${book.title}" from your bookshelf.'),
            ),
          );
        }
      } else {
        final saved = await service.saveBookToShelf(childId, book);
        if (mounted) {
          setState(() {
            _savedBooks.insert(0, saved);
            _pendingSaves.remove(book.id);
          });
          widget.onSavedCountChanged?.call(_savedBooks.length);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved "${book.title}" to your bookshelf.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pendingSaves.remove(book.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCurrentlySaved
                  ? 'Could not remove book. Check your connection.'
                  : 'Could not save book. Check your connection.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleGetPlayIdea(BookItem book) async {
    final childNickname = widget.activeChild?.nickname ?? 'your child';
    final ageBand = widget.activeChild?.ageBand ?? '12-23m';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.forest),
                SizedBox(height: AppSpacing.space16),
                Text('Finding play companion idea…'),
              ],
            ),
          ),
        ),
      ),
    );

    String ideaTitle = 'Story & Play: ${book.title}';
    String domain = 'language';
    String instructions =
        'Read through "${book.title}" together at a gentle pace. Point out pictures of characters and invite $childNickname to mimic their sounds or gestures.';
    String safetyNotice =
        'Always stay close during play and keep small objects out of reach.';
    String? badge = 'Suggested by AI';

    try {
      final ai = _resolveAiService();
      final res = await ai.getStoryActivity(
        bookTitle: book.title,
        subjects: book.subjects,
        ageBand: ageBand,
      );

      final suggestion = res['suggestion'] as Map<String, dynamic>?;
      if (suggestion != null) {
        ideaTitle = suggestion['title'] as String? ?? ideaTitle;
        domain = suggestion['domain'] as String? ?? domain;
        instructions = suggestion['instructions'] as String? ?? instructions;
        safetyNotice = suggestion['safetyNotice'] as String? ?? safetyNotice;
      }
      final provenance = res['provenance'] as Map<String, dynamic>?;
      if (provenance != null) {
        badge = provenance['badge'] as String? ?? badge;
      }
    } catch (_) {
      badge = 'Our pick';
    } finally {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (!mounted) return;

    final dialog = PlayCompanionDialog(
      book: book,
      ideaTitle: ideaTitle,
      domain: domain,
      instructions: instructions,
      safetyNotice: safetyNotice,
      badge: badge,
      onAddToPlan: () async {
        Navigator.of(context).pop();
        await _schedulePlayCompanion(
          book: book,
          ideaTitle: ideaTitle,
          domain: domain,
          instructions: instructions,
          safetyNotice: safetyNotice,
        );
      },
    );

    showDialog<void>(context: context, builder: (ctx) => dialog);
  }

  Future<void> _schedulePlayCompanion({
    required BookItem book,
    required String ideaTitle,
    required String domain,
    required String instructions,
    required String safetyNotice,
  }) async {
    final childId = widget.activeChild?.id;
    final childNickname = widget.activeChild?.nickname;

    final dialog = PlayCompanionDialog(
      book: book,
      ideaTitle: ideaTitle,
      domain: domain,
      instructions: instructions,
      safetyNotice: safetyNotice,
    );
    final activity = dialog.toActivity(childNickname: childNickname);

    if (widget.onPlanActivity != null) {
      widget.onPlanActivity!(activity);
      return;
    }

    if (childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a child profile to schedule activities.',
          ),
        ),
      );
      return;
    }

    try {
      final planService = _resolvePlanService();
      await planService.addActivityToPlan(
        childId: childId,
        activityId: activity.id,
        scheduledDate: todayIsoDate(),
        durationMinutes: activity.durationMinutes,
        customActivity: CustomPlanActivity.fromActivity(
          activity,
          sourceLabel: 'Storybook companion',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${activity.title}" to today\'s plan!'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add to plan right now.')),
        );
      }
    }
  }

  Future<void> _scheduleRhyme(PhilippineRhyme rhyme) async {
    final childId = widget.activeChild?.id;
    final childNickname = widget.activeChild?.nickname;
    final activity = rhyme.toActivity(childNickname: childNickname);

    if (widget.onPlanActivity != null) {
      widget.onPlanActivity!(activity);
      return;
    }

    if (childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a child profile to schedule rhymes.'),
        ),
      );
      return;
    }

    try {
      final planService = _resolvePlanService();
      await planService.addActivityToPlan(
        childId: childId,
        activityId: activity.id,
        scheduledDate: todayIsoDate(),
        durationMinutes: activity.durationMinutes,
        customActivity: CustomPlanActivity.fromActivity(
          activity,
          sourceLabel: 'Read & Sing Together',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "${rhyme.title}" to today\'s plan!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add to plan right now.')),
        );
      }
    }
  }

  void _showRhymeDetails(PhilippineRhyme rhyme) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(rhyme.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(rhyme.subtitle),
              const SizedBox(height: AppSpacing.space16),
              Text(
                rhyme.lyrics.join('\n'),
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: AppSpacing.space16),
              Text('How to play: ${rhyme.actionPrompt}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _scheduleRhyme(rhyme);
            },
            child: const Text("Add to today's plan"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.selectedShelf == BookshelfShelf.openLibrary)
          _buildOpenLibraryShelf()
        else if (widget.selectedShelf == BookshelfShelf.ourBookshelf)
          _buildOurBookshelfShelf()
        else
          _buildRhymesShelf(),
      ],
    );
  }

  Widget _buildOpenLibraryShelf() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search books by title or topic',
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.textSecondary,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchDebounce?.cancel();
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _loadOpenLibraryBooks();
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.surfaceCard,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
              borderSide: const BorderSide(color: AppColors.borderInput),
            ),
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
            _searchDebounce?.cancel();
            _searchDebounce = Timer(AppMotion.searchDebounce, () {
              if (mounted) _loadOpenLibraryBooks();
            });
          },
        ),
        const SizedBox(height: AppSpacing.space12),

        if (_searchQuery.isEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(right: AppSpacing.space24),
            child: Row(
              children: [
                _buildSubjectChip('All books', null),
                ..._subjects.map(
                  (subject) =>
                      _buildSubjectChip(subject['label']!, subject['id']),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space12),
        ],

        if (_showingOfflineBooks) ...[
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.space12),
            padding: const EdgeInsets.all(AppSpacing.space12),
            decoration: BoxDecoration(
              color: AppColors.surfaceOffline,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: const Text(
              'Open Library is unavailable. Showing a few suggested books.',
              style: TextStyle(color: AppColors.textOffline),
            ),
          ),
        ],

        if (!_isLoadingBooks && _openLibraryBooks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space12),
            child: Text(
              '${_openLibraryBooks.length} ${_searchQuery.isNotEmpty ? "results for \"$_searchQuery\"" : (_selectedSubject?.replaceAll("_", " ") ?? "books")}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),

        if (_isLoadingBooks)
          _buildLoadingGrid()
        else if (_booksError != null && _openLibraryBooks.isEmpty)
          ErrorView(message: _booksError!, onRetry: _loadOpenLibraryBooks)
        else if (_openLibraryBooks.isEmpty)
          EmptyStateView(
            title: 'No books found for this topic.',
            message: 'Try another topic, like animals or bedtime.',
            icon: Icons.menu_book_outlined,
            actionLabel: 'Show picture books',
            onAction: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
                _selectedSubject = 'picture_books';
              });
              _loadOpenLibraryBooks();
            },
          )
        else
          _buildBookGrid(
            _openLibraryBooks,
            visibleCount: _visibleCatalogCount,
            onLoadMore: () =>
                setState(() => _visibleCatalogCount += _bookPageSize),
          ),
      ],
    );
  }

  Widget _buildSubjectChip(String label, String? subject) {
    final isSelected = _selectedSubject == subject;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (selected) {
          if (!selected && isSelected) {
            setState(() => _selectedSubject = null);
          } else {
            setState(() => _selectedSubject = subject);
          }
          _loadOpenLibraryBooks();
        },
        selectedColor: AppColors.forest,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.surfaceCard : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildOurBookshelfShelf() {
    if (_isLoadingSaved) {
      return _buildLoadingGrid();
    }

    if (_savedBooksError != null && _savedBooks.isEmpty) {
      return ErrorView(message: _savedBooksError!, onRetry: _loadSavedBooks);
    }

    if (_savedBooks.isEmpty) {
      if (widget.activeChild == null) {
        return const EmptyStateView(
          title: 'Choose a child',
          message: 'Select a child to see and save books on their bookshelf.',
          icon: Icons.menu_book_outlined,
        );
      }
      return EmptyStateView(
        title: 'Your bookshelf is empty.',
        message: 'Have favorite books at home? Search Open Library to save bedtime stories or picture books here.',
        icon: Icons.bookmark_border_outlined,
        actionLabel: 'Search books',
        onAction: () =>
            widget.onShelfSelected?.call(BookshelfShelf.openLibrary),
      );
    }

    final savedItems = _savedBooks.map((b) => b.toBook()).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showingSavedBooksOffline)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.space12),
            padding: const EdgeInsets.all(AppSpacing.space12),
            decoration: BoxDecoration(
              color: AppColors.surfaceOffline,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: const Text(
              'Showing books we saved earlier.',
              style: TextStyle(color: AppColors.textOffline),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.space12),
          child: Text(
            '${_savedBooks.length} ${_savedBooks.length == 1 ? "saved storybook" : "saved storybooks"} at home',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        _buildBookGrid(
          savedItems,
          visibleCount: _visibleSavedCount,
          onLoadMore: () => setState(() => _visibleSavedCount += _bookPageSize),
        ),
      ],
    );
  }

  Widget _buildRhymesShelf() {
    if (_isLoadingRhymes && _rhymes.isEmpty) {
      return _buildLoadingGrid();
    }

    if (_rhymesError != null && _rhymes.isEmpty) {
      return ErrorView(message: _rhymesError!, onRetry: _loadRhymes);
    }

    if (_rhymes.isEmpty) {
      return const EmptyStateView(
        title: 'No rhymes available yet.',
        message: 'Check back soon for traditional songs and rhythm games.',
        icon: Icons.music_note_outlined,
      );
    }

    return RhymesShelf(
      rhymes: _rhymes,
      childNickname: widget.activeChild?.nickname ?? 'your child',
      onShowDetails: _showRhymeDetails,
      onScheduleRhyme: _scheduleRhyme,
    );
  }

  Widget _buildBookGrid(
    List<BookItem> books, {
    required int visibleCount,
    required VoidCallback onLoadMore,
  }) {
    return StorybookGrid(
      books: books,
      visibleCount: visibleCount,
      isBookSaved: _isBookSaved,
      pendingSaveIds: _pendingSaves,
      onToggleSave: _handleToggleSave,
      onGetPlayIdea: _handleGetPlayIdea,
      onLoadMore: onLoadMore,
    );
  }

  Widget _buildLoadingGrid() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(child: CircularProgressIndicator(color: AppColors.forest)),
    );
  }
}
