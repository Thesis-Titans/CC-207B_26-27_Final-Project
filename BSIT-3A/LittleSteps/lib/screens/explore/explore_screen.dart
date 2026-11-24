import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/activity.dart';
import '../../models/child.dart';
import '../../services/api_client.dart';
import '../../services/ai_service.dart';
import '../../services/books_service.dart';
import '../../services/catalog_service.dart';
import '../../services/plan_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/state_views.dart';
import 'storybooks_section.dart';

const _ageBands = <String, String>{
  '0-5m': '0–5 months',
  '6-11m': '6–11 months',
  '12-23m': '12–23 months',
  '24-35m': '24–35 months',
  '36-47m': '36–47 months',
  '48-59m': '48–59 months',
  '60-71m': '60–71 months',
};

const _domains = <String, String>{
  'cognitive': 'Thinking',
  'motor': 'Moving',
  'language': 'Talking',
  'socioEmotional': 'Feelings',
};

const _languages = <String, String>{
  'en': 'English',
  'fil': 'Filipino',
  'hil': 'Hiligaynon',
};

String? _catalogAgeBand(String? ageBand) {
  if (ageBand == null || _ageBands.containsKey(ageBand)) return ageBand;
  final monthMatch = RegExp(r'^(\d{1,2})m$').firstMatch(ageBand);
  final months = int.tryParse(monthMatch?.group(1) ?? '');
  if (months == null || months < 0 || months > 71) return null;
  if (months <= 5) return '0-5m';
  if (months <= 11) return '6-11m';
  if (months <= 23) return '12-23m';
  if (months <= 35) return '24-35m';
  if (months <= 47) return '36-47m';
  if (months <= 59) return '48-59m';
  return '60-71m';
}

String _childAgeLabel(Child child) {
  final birth = child.birthMonthYear;
  if (birth != null) {
    final parts = birth.split('-');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null && month >= 1 && month <= 12) {
        final now = DateTime.now();
        final age = (now.year - year) * 12 + now.month - month;
        if (age >= 0) return '$age ${age == 1 ? 'month' : 'months'}';
      }
    }
  }
  return _ageBands[_catalogAgeBand(child.ageBand)] ?? child.ageBand;
}

/// Browse provisional learning activities and add one to today's plan.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    this.catalogService,
    this.planService,
    this.onPlanAdded,
  });

  /// Optional catalog service used by tests or a containing feature.
  final CatalogService? catalogService;

  /// Optional plans service used by tests or a containing feature.
  final PlanService? planService;

  /// Called when an item is added to today's plan.
  final ValueChanged<Activity>? onPlanAdded;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late CatalogService _catalogService;
  late PlanService _planService;
  List<Activity> _activities = const [];
  bool _loading = true;
  bool _offline = false;
  bool _initialLoadStarted = false;
  bool _storybooksSelected = false;
  BookshelfShelf _selectedBookshelf = BookshelfShelf.openLibrary;
  int _savedBookCount = 0;
  String? _errorMessage;
  String? _ageBand;
  String? _domain;
  String? _language;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _requestNumber = 0;
  String? _lastChildId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final apiClient = AuthScope.maybeOf(context) != null
        ? AuthScope.apiClientOf(context)
        : ApiClient();
    _catalogService =
        widget.catalogService ?? CatalogService(apiClient: apiClient);
    _planService = widget.planService ?? PlanService(apiClient: apiClient);

    final activeChild = AuthScope.maybeOf(context)?.activeChild;
    final childChanged = activeChild?.id != _lastChildId;
    if (childChanged) {
      _lastChildId = activeChild?.id;
      _ageBand = _catalogAgeBand(activeChild?.ageBand);
    }
    if (!_initialLoadStarted || childChanged) {
      _initialLoadStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadActivities());
      });
    }
  }

  Future<void> _loadActivities() async {
    final requestNumber = ++_requestNumber;
    _catalogService.apiClient.isOffline = false;
    setState(() {
      _loading = true;
      _offline = false;
      _errorMessage = null;
    });
    try {
      final activities = await _catalogService.getActivities(
        ageBand: _ageBand,
        domain: _domain,
        language: _language,
      );
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() {
        _activities = activities;
        _loading = false;
        _offline = _catalogService.apiClient.isOffline;
      });
    } catch (error) {
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() {
        _loading = false;
        _offline =
            error is NoConnectionApiException ||
            error is TimeoutApiException ||
            error is SocketException ||
            error is http.ClientException;
        _errorMessage =
            error is ApiException && error.code == 'SERVICE_UNAVAILABLE'
            ? 'The activity catalog is temporarily unavailable. Try again in a moment.'
            : 'The activity catalog could not be loaded. Try again in a moment.';
      });
    }
  }

  List<Activity> get _visibleActivities {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _activities;
    return _activities.where((activity) {
      final matchesTitle = activity.title.toLowerCase().contains(query);
      final matchesMaterial = activity.materials.any(
        (material) => material.toLowerCase().contains(query),
      );
      return matchesTitle || matchesMaterial;
    }).toList();
  }

  void _changeFilter({String? ageBand, String? domain, String? language}) {
    setState(() {
      _ageBand = ageBand;
      _domain = domain;
      _language = language;
    });
    unawaited(_loadActivities());
  }

  Future<void> _openMoreFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (sheetContext) => SizedBox(
        width: double.infinity,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space16,
              AppSpacing.space8,
              AppSpacing.space16,
              AppSpacing.space24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'More filters',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.space16),
                Text(
                  'Language',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.space8),
                Wrap(
                  spacing: AppSpacing.space8,
                  runSpacing: AppSpacing.space8,
                  children: [
                    _LanguageChip(
                      label: 'All languages',
                      selected: _language == null,
                      onSelected: () => _selectLanguage(sheetContext, null),
                    ),
                    ..._languages.entries.map(
                      (entry) => _LanguageChip(
                        label: entry.value,
                        selected: _language == entry.key,
                        onSelected: () =>
                            _selectLanguage(sheetContext, entry.key),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space16),
                Text(
                  'Choose a language for activities.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectLanguage(BuildContext sheetContext, String? language) {
    _changeFilter(ageBand: _ageBand, domain: _domain, language: language);
    Navigator.pop(sheetContext);
  }

  void _openChildContext() {
    final session = AuthScope.maybeOf(context);
    if (session == null || !session.isAuthenticated) {
      Navigator.pushNamed(context, '/sign-in');
    } else {
      Navigator.pushNamed(context, '/children');
    }
  }

  Future<void> _addToPlan(Activity activity) async {
    final session = AuthScope.maybeOf(context);
    if (session == null || !session.isAuthenticated) {
      Navigator.pushNamed(context, '/sign-in');
      return;
    }
    final child = session.activeChild;
    if (child == null) {
      Navigator.pushNamed(context, '/children');
      return;
    }

    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      await _planService.addActivityToPlan(
        childId: child.id,
        activityId: activity.id,
        scheduledDate: date,
        durationMinutes: activity.durationMinutes,
      );
      if (!mounted) return;
      widget.onPlanAdded?.call(activity);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Added to today's plan")));
    } catch (error) {
      if (!mounted) return;
      final message = switch (error) {
        ApiException(code: 'SERVICE_UNAVAILABLE') =>
          'The plan service is temporarily unavailable. Try again in a moment.',
        NoConnectionApiException() ||
        TimeoutApiException() ||
        SocketException() ||
        http.ClientException() => 'The activity could not be added. Check your connection and try again.',
        NotFoundApiException() => 'The child or activity was not found. Check that the child profile is saved to your account.',
        AuthApiException() => 'Sign in again before adding an activity.',
        _ => 'The activity could not be added. Please try again.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final activities = _visibleActivities;
    final activeChild = AuthScope.maybeOf(context)?.activeChild;
    final ageLabel = _ageBand == null
        ? 'All age bands'
        : _ageBands[_ageBand] ?? _ageBand!;
    final resultCount = activities.length;
    final resultMessage = _ageBand == null
        ? '$resultCount ${resultCount == 1 ? 'activity' : 'activities'}'
        : '$resultCount ${resultCount == 1 ? 'activity' : 'activities'} for $ageLabel';
    final languageFilterLabel = _language == null
        ? 'Language'
        : 'Language: ${_languages[_language] ?? _language}';

    return RefreshIndicator(
      onRefresh: _loadActivities,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space16,
              AppSpacing.space16,
              AppSpacing.space16,
              0,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const ScreenHeader(
                  title: 'Explore',
                  subtitle: 'Simple ideas with things you already have.',
                ),
                const SizedBox(height: AppSpacing.space8),
                _ChildContextButton(
                  child: activeChild,
                  onPressed: _openChildContext,
                ),
                const SizedBox(height: AppSpacing.space16),
                _ExploreSections(
                  storybooksSelected: _storybooksSelected,
                  selectedShelf: _selectedBookshelf,
                  savedBookCount: _savedBookCount,
                  onActivities: () =>
                      setState(() => _storybooksSelected = false),
                  onStorybooks: () => setState(() {
                    _storybooksSelected = true;
                    _selectedBookshelf = BookshelfShelf.openLibrary;
                  }),
                  onBookshelf: () => setState(() {
                    _storybooksSelected = true;
                    _selectedBookshelf = BookshelfShelf.ourBookshelf;
                  }),
                  onRhymes: () => setState(() {
                    _storybooksSelected = true;
                    _selectedBookshelf = BookshelfShelf.rhymes;
                  }),
                ),
                if (!_storybooksSelected) ...[
                  const SizedBox(height: AppSpacing.space16),
                  TextField(
                    key: const ValueKey('materials-search'),
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: const InputDecoration(
                      hintText: 'Search activities or materials',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  DropdownButtonFormField<String?>(
                    key: ValueKey('age-$_ageBand'),
                    initialValue: _ageBand,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Child's age"),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All age bands'),
                      ),
                      ..._ageBands.entries.map(
                        (entry) => DropdownMenuItem<String?>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      ),
                    ],
                    onChanged: (value) => _changeFilter(
                      ageBand: value,
                      domain: _domain,
                      language: _language,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space16),
                ],
              ]),
            ),
          ),
          if (!_storybooksSelected)
            SliverToBoxAdapter(
              child: _DomainFilters(
                selectedDomain: _domain,
                onSelected: (domain) => _changeFilter(
                  ageBand: _ageBand,
                  domain: domain,
                  language: _language,
                ),
              ),
            ),
          if (!_storybooksSelected)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space16,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  SizedBox(
                    height: AppSizes.touchTarget,
                    child: TextButton(
                      key: const ValueKey('more-filters'),
                      onPressed: _openMoreFilters,
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.zero,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: Text(
                        'More filters · $languageFilterLabel',
                        maxLines: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  if (_offline) const _OfflineCatalogNotice(),
                  if (_errorMessage != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: _CatalogErrorNotice(
                        message: _errorMessage!,
                        onRetry: _loadActivities,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space8),
                  ],
                  if (!_storybooksSelected &&
                      !_loading &&
                      _errorMessage == null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        resultMessage,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (_loading && !_storybooksSelected) ...[
                    const SizedBox(height: AppSpacing.space8),
                    Semantics(
                      liveRegion: true,
                      label: 'Loading activities',
                      child: Text('Loading activities…'),
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    const _ActivityLoadingSkeleton(),
                    const _ActivityLoadingSkeleton(),
                  ],
                  if (!_loading &&
                      _errorMessage == null &&
                      activities.isEmpty &&
                      !_storybooksSelected)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.space16),
                      child: EmptyStateView(
                        title: 'No activities found matching your filters',
                        message: _activities.isEmpty
                            ? 'Try another age band or filter. New catalog activities will appear here when available.'
                            : 'Try another activity or material search.',
                        icon: Icons.search_off_outlined,
                        actionLabel: 'Clear filters',
                        announce: true,
                        onAction: () {
                          _searchController.clear();
                          setState(() {
                            _ageBand = _catalogAgeBand(activeChild?.ageBand);
                            _domain = null;
                            _language = null;
                            _searchQuery = '';
                          });
                          unawaited(_loadActivities());
                        },
                      ),
                    ),
                  if (!_loading &&
                      _errorMessage == null &&
                      !_storybooksSelected)
                    ...activities.indexed.expand((entry) {
                      final index = entry.$1;
                      final activity = entry.$2;
                      return <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.space12,
                            bottom: AppSpacing.space4,
                          ),
                          child: _ActivityResultCard(
                            activity: activity,
                            onAdd: () => _addToPlan(activity),
                          ),
                        ),
                        if (index == 1) ...[
                          const SizedBox(height: AppSpacing.space12),
                          _IdeaHelperEntryCard(
                            onTap: () =>
                                Navigator.pushNamed(context, '/ai-suggest'),
                          ),
                        ],
                      ];
                    }),
                  if (!_loading &&
                      _errorMessage == null &&
                      !_storybooksSelected &&
                      activities.length < 2) ...[
                    const SizedBox(height: AppSpacing.space12),
                    _IdeaHelperEntryCard(
                      onTap: () => Navigator.pushNamed(context, '/ai-suggest'),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.space24),
                ]),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space16,
              AppSpacing.space8,
              AppSpacing.space16,
              AppSpacing.space24,
            ),
            sliver: SliverToBoxAdapter(
              child: Visibility(
                visible: _storybooksSelected,
                maintainState: true,
                child: StorybooksSection(
                  booksService: BooksService(
                    apiClient: _catalogService.apiClient,
                  ),
                  aiService: AiService(apiClient: _catalogService.apiClient),
                  planService: _planService,
                  activeChild: activeChild,
                  selectedShelf: _selectedBookshelf,
                  isOffline: _offline,
                  onShelfSelected: (shelf) =>
                      setState(() => _selectedBookshelf = shelf),
                  onSavedCountChanged: (count) =>
                      setState(() => _savedBookCount = count),
                  onPlanActivity: _addToPlan,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildContextButton extends StatelessWidget {
  const _ChildContextButton({required this.child, required this.onPressed});

  final Child? child;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = child == null
        ? 'Choose a child'
        : 'For ${child!.nickname} · ${_childAgeLabel(child!)}';
    return Semantics(
      button: true,
      label: label,
      child: OutlinedButton(
        key: const ValueKey('child-context'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            const Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
    );
  }
}

class _ExploreSections extends StatelessWidget {
  const _ExploreSections({
    required this.storybooksSelected,
    required this.selectedShelf,
    required this.savedBookCount,
    required this.onActivities,
    required this.onStorybooks,
    required this.onBookshelf,
    required this.onRhymes,
  });

  final bool storybooksSelected;
  final BookshelfShelf selectedShelf;
  final int savedBookCount;
  final VoidCallback onActivities;
  final VoidCallback onStorybooks;
  final VoidCallback onBookshelf;
  final VoidCallback onRhymes;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _SectionButton(
          label: const Text('Activities'),
          selected: !storybooksSelected,
          onPressed: onActivities,
        ),
        const SizedBox(width: AppSpacing.space8),
        _SectionButton(
          label: const Text('Storybooks'),
          selected:
              storybooksSelected && selectedShelf == BookshelfShelf.openLibrary,
          onPressed: onStorybooks,
        ),
        const SizedBox(width: AppSpacing.space8),
        _SectionButton(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Our Bookshelf'),
              if (savedBookCount > 0) ...[
                const SizedBox(width: AppSpacing.space8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space8,
                    vertical: AppSpacing.space4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        storybooksSelected &&
                            selectedShelf == BookshelfShelf.ourBookshelf
                        ? AppColors.surfaceCard
                        : AppColors.softGreen,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(
                    '$savedBookCount',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.forest,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          selected:
              storybooksSelected &&
              selectedShelf == BookshelfShelf.ourBookshelf,
          onPressed: onBookshelf,
        ),
        const SizedBox(width: AppSpacing.space8),
        _SectionButton(
          label: const Text('Read & Sing Together'),
          selected:
              storybooksSelected && selectedShelf == BookshelfShelf.rhymes,
          onPressed: onRhymes,
        ),
      ],
    ),
  );
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final Widget label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: selected
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space16,
                ),
              ),
              child: label,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space16,
                ),
                foregroundColor: theme.colorScheme.onSurface,
              ),
              child: label,
            ),
    );
  }
}

class _DomainFilters extends StatelessWidget {
  const _DomainFilters({
    required this.selectedDomain,
    required this.onSelected,
  });

  final String? selectedDomain;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final filters = <(String, String?)>[
      ('All', null),
      ..._domains.entries.map((entry) => (entry.value, entry.key)),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        key: const ValueKey('domain-filters'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.space8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = selectedDomain == filter.$2;
          return SizedBox(
            height: 48,
            child: ChoiceChip(
              key: ValueKey('domain-${filter.$2 ?? 'all'}'),
              label: Text(filter.$1),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) => onSelected(filter.$2),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space12,
              ),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
          );
        },
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    onSelected: (_) => onSelected(),
  );
}

class _ActivityResultCard extends StatelessWidget {
  const _ActivityResultCard({required this.activity, required this.onAdd});

  final Activity activity;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReviewed = activity.status == 'reviewed_approved';
    final domainLabel = _domains[activity.domain] ?? activity.domain;
    final setting = activity.setting.isEmpty
        ? activity.setting
        : '${activity.setting[0].toUpperCase()}${activity.setting.substring(1)}';
    final meta = '${activity.durationEstimate} · $domainLabel · $setting';

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: AspectRatio(
                aspectRatio: 250 / 72,
                child: Image.asset(
                  'assets/images/catalog_cover.png',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  semanticLabel: '',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            Text(activity.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.space4),
            Text(
              meta,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            Text(
              activity.instructions.join(' '),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.space8),
            Wrap(
              spacing: AppSpacing.space8,
              runSpacing: AppSpacing.space4,
              children: activity.materials
                  .map((material) => _MaterialPill(label: material))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.space8),
            _ReviewBadge(
              reviewed: isReviewed,
              source: activity.provenanceSource,
              limitations: activity.limitations,
            ),
            const SizedBox(height: AppSpacing.space8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text("Add to today's plan"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialPill extends StatelessWidget {
  const _MaterialPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 28),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.space12,
      vertical: AppSpacing.space4,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(AppRadius.chip),
    ),
    child: Text(label, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge({
    required this.reviewed,
    required this.source,
    required this.limitations,
  });

  final bool reviewed;
  final String source;
  final String limitations;

  @override
  Widget build(BuildContext context) {
    final statusColors = Theme.of(context).extension<AppStatusColors>()!;
    final label = reviewed
        ? 'Source: $source · reviewed'
        : 'Provisional Academic Reference — Pending Review';
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.all(AppSpacing.space8),
      decoration: BoxDecoration(
        color: reviewed
            ? statusColors.infoBackground
            : statusColors.cautionBackground,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            reviewed ? Icons.verified_outlined : Icons.circle,
            size: 16,
            color: reviewed
                ? statusColors.infoForeground
                : statusColors.cautionForeground,
          ),
          const SizedBox(width: AppSpacing.space8),
          Expanded(
            child: Semantics(
              label: '$label. Source: $source. $limitations',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  if (source.isNotEmpty)
                    Text(
                      'Source: $source',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdeaHelperEntryCard extends StatelessWidget {
  const _IdeaHelperEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Need a play idea?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.space8),
          Text(
            'Tell us how much time you have and what is nearby.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.space12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('Get a play idea'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActivityLoadingSkeleton extends StatelessWidget {
  const _ActivityLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final placeholder = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 72, width: double.infinity, color: placeholder),
            const SizedBox(height: AppSpacing.space12),
            Container(height: 20, width: 180, color: placeholder),
            const SizedBox(height: AppSpacing.space8),
            Container(height: 14, width: double.infinity, color: placeholder),
            const SizedBox(height: AppSpacing.space8),
            Container(height: 14, width: 220, color: placeholder),
          ],
        ),
      ),
    );
  }
}

class _OfflineCatalogNotice extends StatelessWidget {
  const _OfflineCatalogNotice();

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).extension<AppStatusColors>()!.offlineBackground,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.space12),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: Theme.of(context)
                  .extension<AppStatusColors>()!
                  .offlineForeground,
            ),
            const SizedBox(width: AppSpacing.space8),
            Expanded(
              child: Text('You are offline. Reconnect to load activities.'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CatalogErrorNotice extends StatelessWidget {
  const _CatalogErrorNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).extension<AppStatusColors>()!.errorBackground,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.space8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
