import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/activity.dart';
import '../../models/child.dart';
import '../../models/plan.dart';
import '../../services/ai_service.dart';
import '../../services/api_client.dart';
import '../../services/books_service.dart';
import '../../services/catalog_service.dart';
import '../../services/plan_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/state_views.dart';
import 'storybooks_section.dart';
import 'widgets/explore_activity_card.dart';
import 'widgets/explore_filter_controls.dart';
import 'widgets/explore_state_notices.dart';

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

const _settings = <String, String>{'indoor': 'Indoor', 'outdoor': 'Outdoor'};

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
  /// Creates an [ExploreScreen].
  const ExploreScreen({
    super.key,
    this.catalogService,
    this.planService,
    this.onPlanAdded,
    this.initialSetting,
    this.settingTriggerKey = 0,
  });

  /// Optional catalog service used by tests or a containing feature.
  final CatalogService? catalogService;

  /// Optional plans service used by tests or a containing feature.
  final PlanService? planService;

  /// Called when an item is added to today's plan.
  final ValueChanged<Activity>? onPlanAdded;

  /// Optional play-space filter (`indoor` or `outdoor`) applied when opening
  /// Explore from a contextual prompt such as Today's weather hint.
  final String? initialSetting;

  /// Incremented by the shell to re-apply [initialSetting] on demand.
  final int settingTriggerKey;

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
  String? _setting;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _requestNumber = 0;
  String? _lastChildId;

  @override
  void initState() {
    super.initState();
    _setting = widget.initialSetting;
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settingTriggerKey != oldWidget.settingTriggerKey &&
        widget.initialSetting != null) {
      setState(() {
        _storybooksSelected = false;
        _setting = widget.initialSetting;
      });
      unawaited(_loadActivities());
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
        setting: _setting,
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

  void _changeFilter({
    String? ageBand,
    String? domain,
    String? language,
    String? setting,
    bool updateSetting = false,
  }) {
    setState(() {
      _ageBand = ageBand;
      _domain = domain;
      _language = language;
      if (updateSetting) {
        _setting = setting;
      }
    });
    unawaited(_loadActivities());
  }

  Future<void> _openMoreFilters(Child? activeChild) async {
    final defaultAgeBand = _catalogAgeBand(activeChild?.ageBand);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final hasCustomFilters =
              _ageBand != defaultAgeBand ||
              _language != null ||
              _setting != null;
          return SizedBox(
            width: double.infinity,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filters',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (hasCustomFilters)
                          TextButton(
                            onPressed: () {
                              _changeFilter(
                                ageBand: defaultAgeBand,
                                domain: _domain,
                                language: null,
                                setting: null,
                                updateSetting: true,
                              );
                              Navigator.pop(sheetContext);
                            },
                            child: const Text('Reset filters'),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space16),
                    Text(
                      "Child's age",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    DropdownButtonFormField<String?>(
                      key: ValueKey('age-$_ageBand'),
                      initialValue: _ageBand,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Child's age",
                      ),
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
                      onChanged: (value) {
                        _changeFilter(
                          ageBand: value,
                          domain: _domain,
                          language: _language,
                        );
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: AppSpacing.space20),
                    Text(
                      'Language',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    Wrap(
                      spacing: AppSpacing.space8,
                      runSpacing: AppSpacing.space8,
                      children: [
                        LanguageFilterChip(
                          label: 'All languages',
                          selected: _language == null,
                          onSelected: () => _selectLanguage(sheetContext, null),
                        ),
                        ..._languages.entries.map(
                          (entry) => LanguageFilterChip(
                            label: entry.value,
                            selected: _language == entry.key,
                            onSelected: () =>
                                _selectLanguage(sheetContext, entry.key),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space20),
                    Text(
                      'Play space',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    Wrap(
                      spacing: AppSpacing.space8,
                      runSpacing: AppSpacing.space8,
                      children: [
                        LanguageFilterChip(
                          label: 'Any space',
                          selected: _setting == null,
                          onSelected: () => _selectSetting(sheetContext, null),
                        ),
                        ..._settings.entries.map(
                          (entry) => LanguageFilterChip(
                            label: entry.value,
                            selected: _setting == entry.key,
                            onSelected: () =>
                                _selectSetting(sheetContext, entry.key),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space16),
                    Text(
                      'Defaults to your active child\'s age range. Adjust anytime to browse other ages or languages.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _selectLanguage(BuildContext sheetContext, String? language) {
    _changeFilter(ageBand: _ageBand, domain: _domain, language: language);
    Navigator.pop(sheetContext);
  }

  void _selectSetting(BuildContext sheetContext, String? setting) {
    _changeFilter(
      ageBand: _ageBand,
      domain: _domain,
      language: _language,
      setting: setting,
      updateSetting: true,
    );
    Navigator.pop(sheetContext);
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
    final isCustomNonCatalog =
        activity.type == 'story' ||
        activity.type == 'rhyme' ||
        activity.type == 'custom' ||
        activity.id.startsWith('story-') ||
        activity.id.startsWith('rhyme-') ||
        activity.id.startsWith('custom-');
    final customSnapshot = isCustomNonCatalog
        ? CustomPlanActivity.fromActivity(
            activity,
            sourceLabel: activity.type == 'story'
                ? 'Storybook companion'
                : activity.type == 'rhyme'
                ? 'Read & Sing Together'
                : 'Material adaptation',
          )
        : null;
    try {
      await _planService.addActivityToPlan(
        childId: child.id,
        activityId: activity.id,
        scheduledDate: date,
        durationMinutes: activity.durationMinutes,
        customActivity: customSnapshot,
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

    final childLabel = activeChild == null
        ? 'Choose a child'
        : 'For ${activeChild.nickname} · ${_childAgeLabel(activeChild)}';

    return RefreshIndicator(
      onRefresh: _loadActivities,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideLayout = constraints.maxWidth >= 860;
          final mainColumn = _buildExploreColumn(
            context: context,
            activities: activities,
            activeChild: activeChild,
            childLabel: childLabel,
            resultMessage: resultMessage,
            languageFilterLabel: languageFilterLabel,
            showInlineIdeaHelper: !isWideLayout,
          );

          if (!isWideLayout) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.wideContentMaxWidth,
                ),
                child: mainColumn,
              ),
            );
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.wideContentMaxWidth,
              ),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ScreenHeader(
                      title: 'Explore',
                      subtitle: 'Simple ideas with things you already have.',
                    ),
                    const SizedBox(height: AppSpacing.space16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildExploreMainSections(
                            context: context,
                            activities: activities,
                            activeChild: activeChild,
                            resultMessage: resultMessage,
                            languageFilterLabel: languageFilterLabel,
                            showInlineIdeaHelper: false,
                          ),
                        ),
                        if (!_storybooksSelected) ...[
                          const SizedBox(width: AppSpacing.space24),
                          SizedBox(
                            width: 340,
                            child: IdeaHelperEntryCard(
                              onTap: () =>
                                  Navigator.pushNamed(context, '/ai-suggest'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExploreColumn({
    required BuildContext context,
    required List<Activity> activities,
    required Child? activeChild,
    required String childLabel,
    required String resultMessage,
    required String languageFilterLabel,
    required bool showInlineIdeaHelper,
  }) {
    return CustomScrollView(
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
              const SizedBox(height: AppSpacing.space16),
              ExploreSectionTabs(
                storybooksSelected: _storybooksSelected,
                selectedShelf: _selectedBookshelf,
                savedBookCount: _savedBookCount,
                onActivities: () => setState(() => _storybooksSelected = false),
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
                const SizedBox(height: AppSpacing.space12),
                _buildSearchAndFilterRow(activeChild),
                const SizedBox(height: AppSpacing.space12),
              ],
            ]),
          ),
        ),
        if (!_storybooksSelected) ...[
          SliverToBoxAdapter(
            child: ExploreDomainFilters(
              domains: _domains,
              selectedDomain: _domain,
              onSelected: (domain) => _changeFilter(
                ageBand: _ageBand,
                domain: domain,
                language: _language,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _buildResultsChildren(
                  context: context,
                  activities: activities,
                  activeChild: activeChild,
                  resultMessage: resultMessage,
                  languageFilterLabel: languageFilterLabel,
                  showInlineIdeaHelper: showInlineIdeaHelper,
                ),
              ),
            ),
          ),
        ],
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
    );
  }

  Widget _buildExploreMainSections({
    required BuildContext context,
    required List<Activity> activities,
    required Child? activeChild,
    required String resultMessage,
    required String languageFilterLabel,
    required bool showInlineIdeaHelper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExploreSectionTabs(
          storybooksSelected: _storybooksSelected,
          selectedShelf: _selectedBookshelf,
          savedBookCount: _savedBookCount,
          onActivities: () => setState(() => _storybooksSelected = false),
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
          const SizedBox(height: AppSpacing.space12),
          _buildSearchAndFilterRow(activeChild),
          const SizedBox(height: AppSpacing.space12),
          ExploreDomainFilters(
            domains: _domains,
            selectedDomain: _domain,
            horizontalPadding: 0,
            onSelected: (domain) => _changeFilter(
              ageBand: _ageBand,
              domain: domain,
              language: _language,
            ),
          ),
          ..._buildResultsChildren(
            context: context,
            activities: activities,
            activeChild: activeChild,
            resultMessage: resultMessage,
            languageFilterLabel: languageFilterLabel,
            showInlineIdeaHelper: showInlineIdeaHelper,
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.space16),
          StorybooksSection(
            booksService: BooksService(apiClient: _catalogService.apiClient),
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
        ],
      ],
    );
  }

  Widget _buildSearchAndFilterRow(Child? activeChild) {
    final defaultAgeBand = _catalogAgeBand(activeChild?.ageBand);
    final activeFilterCount =
        (_ageBand != defaultAgeBand ? 1 : 0) +
        (_language != null ? 1 : 0) +
        (_setting != null ? 1 : 0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('materials-search'),
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: const InputDecoration(
              hintText: 'Search activities or materials',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space8),
        SizedBox(
          width: AppSizes.touchTarget,
          height: AppSizes.touchTarget,
          child: OutlinedButton(
            key: const ValueKey('more-filters'),
            onPressed: () => _openMoreFilters(activeChild),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              side: BorderSide(
                color: activeFilterCount > 0
                    ? AppColors.forest
                    : AppColors.borderInput,
              ),
              backgroundColor: activeFilterCount > 0
                  ? AppColors.softGreen
                  : AppColors.surfaceCard,
            ),
            child: Tooltip(
              message: activeFilterCount > 0
                  ? 'Filters ($activeFilterCount active)'
                  : 'Filters',
              child: Badge.count(
                count: activeFilterCount,
                isLabelVisible: activeFilterCount > 0,
                backgroundColor: AppColors.forest,
                child: const Icon(Icons.tune, color: AppColors.forest),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildResultsChildren({
    required BuildContext context,
    required List<Activity> activities,
    required Child? activeChild,
    required String resultMessage,
    required String languageFilterLabel,
    required bool showInlineIdeaHelper,
  }) {
    final defaultAgeBand = _catalogAgeBand(activeChild?.ageBand);
    final hasCustomFilter =
        _ageBand != defaultAgeBand ||
        _language != null ||
        _setting != null ||
        _domain != null ||
        _searchQuery.trim().isNotEmpty;
    final summaryParts = <String>[
      resultMessage,
      if (_language != null) _languages[_language] ?? _language!,
      if (_setting != null) _settings[_setting] ?? _setting!,
    ];
    final activeSummary = summaryParts.join(' · ');

    return [
      const SizedBox(height: AppSpacing.space8),
      if (_offline) const OfflineCatalogNotice(),
      if (_errorMessage != null) ...[
        Semantics(
          liveRegion: true,
          child: CatalogErrorNotice(
            message: _errorMessage!,
            onRetry: _loadActivities,
          ),
        ),
        const SizedBox(height: AppSpacing.space8),
      ],
      if (!_storybooksSelected && !_loading && _errorMessage == null)
        Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  activeSummary,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            if (hasCustomFilter)
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _ageBand = defaultAgeBand;
                    _domain = null;
                    _language = null;
                    _setting = null;
                    _searchQuery = '';
                  });
                  unawaited(_loadActivities());
                },
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space8,
                  ),
                ),
                child: const Text('Reset'),
              ),
          ],
        ),
      if (showInlineIdeaHelper &&
          !_loading &&
          _errorMessage == null &&
          !_storybooksSelected) ...[
        const SizedBox(height: AppSpacing.space8),
        CompactIdeaHelperBar(
          onTap: () => Navigator.pushNamed(context, '/ai-suggest'),
        ),
      ],
      if (_loading && !_storybooksSelected) ...[
        const SizedBox(height: AppSpacing.space8),
        Semantics(
          liveRegion: true,
          label: 'Loading activities',
          child: const Text('Loading activities…'),
        ),
        const SizedBox(height: AppSpacing.space8),
        const ActivityLoadingSkeleton(),
        const ActivityLoadingSkeleton(),
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
                _ageBand = defaultAgeBand;
                _domain = null;
                _language = null;
                _searchQuery = '';
              });
              unawaited(_loadActivities());
            },
          ),
        ),
      if (_storybooksSelected)
        const EmptyStateView(
          title: 'Storybooks',
          message: 'Browse and save family storybooks here.',
          icon: Icons.menu_book_outlined,
        ),
      if (!_loading && _errorMessage == null && !_storybooksSelected)
        ...activities.map(
          (activity) => Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.space12,
              bottom: AppSpacing.space4,
            ),
            child: ExploreActivityCard(
              activity: activity,
              domainLabel: _domains[activity.domain] ?? activity.domain,
              onAdd: () => _addToPlan(activity),
            ),
          ),
        ),
      const SizedBox(height: AppSpacing.space24),
    ];
  }
}
