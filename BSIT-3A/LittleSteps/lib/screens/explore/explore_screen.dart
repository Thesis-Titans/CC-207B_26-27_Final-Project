import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/activity.dart';
import '../../models/child.dart';
import '../../models/plan.dart';
import '../../services/api_client.dart';
import '../../services/ai_service.dart';
import '../../services/books_service.dart';
import '../../services/catalog_service.dart';
import '../../services/plan_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../utils/url_helper.dart';
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
                        _LanguageChip(
                          label: 'Any space',
                          selected: _setting == null,
                          onSelected: () => _selectSetting(sheetContext, null),
                        ),
                        ..._settings.entries.map(
                          (entry) => _LanguageChip(
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
                            child: _IdeaHelperEntryCard(
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
              _ExploreSections(
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
            child: _DomainFilters(
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
        _ExploreSections(
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
          _DomainFilters(
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
        _CompactIdeaHelperBar(
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
            child: _ActivityResultCard(
              activity: activity,
              onAdd: () => _addToPlan(activity),
            ),
          ),
        ),
      const SizedBox(height: AppSpacing.space24),
    ];
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
  Widget build(BuildContext context) => _HorizontalScrollFade(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(right: AppSpacing.space24),
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
                storybooksSelected &&
                selectedShelf == BookshelfShelf.openLibrary,
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
    this.horizontalPadding = AppSpacing.space16,
  });

  final String? selectedDomain;
  final ValueChanged<String?> onSelected;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final filters = <(String, String?)>[
      ('All', null),
      ..._domains.entries.map((entry) => (entry.value, entry.key)),
    ];
    return SizedBox(
      height: 48,
      child: _HorizontalScrollFade(
        child: ListView.separated(
          key: const ValueKey('domain-filters'),
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding + AppSpacing.space20,
            0,
          ),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideCard = constraints.maxWidth >= 520;
          return Padding(
            padding: EdgeInsets.all(
              isWideCard ? AppSpacing.space20 : AppSpacing.space16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 112,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/catalog_cover.png',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    semanticLabel: '',
                  ),
                ),
                const SizedBox(height: AppSpacing.space12),
                Text(activity.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  meta,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.space12),
                Text(
                  activity.instructions.join(' '),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.space12),
                Wrap(
                  spacing: AppSpacing.space8,
                  runSpacing: AppSpacing.space4,
                  children: activity.materials
                      .map((material) => _MaterialPill(label: material))
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.space12),
                _ReviewBadge(
                  reviewed: isReviewed,
                  source: activity.provenanceSource,
                  limitations: activity.limitations,
                ),
                const SizedBox(height: AppSpacing.space16),
                if (isWideCard)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text("Add to today's plan"),
                    ),
                  )
                else
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
          );
        },
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

  void _showSourceDetails(BuildContext context) {
    String? sourceUrl;
    String? buttonLabel;
    String? domainCaption;
    String frameworkTitle = 'Published early childhood guide';

    if (source.contains('NELF')) {
      frameworkTitle = 'Philippine National Early Learning Framework (NELF)';
      sourceUrl = 'https://eccdcouncil.gov.ph';
      buttonLabel = 'Visit ECCD Council website';
      domainCaption = 'eccdcouncil.gov.ph';
    } else if (source.contains('NELC')) {
      frameworkTitle = 'Philippine National Early Learning Curriculum (NELC)';
      sourceUrl = 'https://eccdcouncil.gov.ph';
      buttonLabel = 'Visit ECCD Council website';
      domainCaption = 'eccdcouncil.gov.ph';
    } else if (source.contains('ECCD')) {
      frameworkTitle = 'Early Childhood Care and Development (ECCD) Council';
      sourceUrl = 'https://eccdcouncil.gov.ph';
      buttonLabel = 'Visit ECCD Council website';
      domainCaption = 'eccdcouncil.gov.ph';
    } else if (source.contains('CDC')) {
      frameworkTitle = 'CDC Developmental Milestones';
      sourceUrl = 'https://www.cdc.gov/ncbddd/actearly/milestones/';
      buttonLabel = 'Visit CDC website';
      domainCaption = 'cdc.gov';
    } else if (source.contains('WHO')) {
      frameworkTitle = 'WHO Nurturing Care Framework';
      sourceUrl = 'https://nurturing-care.org';
      buttonLabel = 'Visit WHO website';
      domainCaption = 'nurturing-care.org';
    } else if (source.contains('AAP')) {
      frameworkTitle = 'American Academy of Pediatrics (AAP)';
      sourceUrl = 'https://www.healthychildren.org';
      buttonLabel = 'Visit AAP website';
      domainCaption = 'healthychildren.org';
    }

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space24,
          AppSpacing.space8,
          AppSpacing.space24,
          AppSpacing.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.forest,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.space8),
                Expanded(
                  child: Text(
                    'Where this activity comes from',
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space12),
            Text(
              frameworkTitle,
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (source.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.space4),
              Text(
                source,
                style: Theme.of(sheetContext).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.space12),
            Text(
              'Adapted from published early childhood play and learning guidelines.',
              style: Theme.of(sheetContext).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            if (sourceUrl != null && buttonLabel != null) ...[
              const SizedBox(height: AppSpacing.space16),
              SizedBox(
                width: double.infinity,
                height: AppSizes.touchTarget,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    openExternalUrl(context, sourceUrl!);
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(buttonLabel),
                ),
              ),
              if (domainCaption != null) ...[
                const SizedBox(height: AppSpacing.space8),
                Center(
                  child: Text(
                    domainCaption,
                    style: Theme.of(sheetContext).textTheme.labelSmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.space8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColors = theme.extension<AppStatusColors>()!;
    const subtitle = 'Educational play reference';
    return InkWell(
      onTap: () => _showSourceDetails(context),
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space8,
        ),
        decoration: BoxDecoration(
          color: statusColors.infoBackground,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                reviewed ? Icons.verified_outlined : Icons.menu_book_outlined,
                size: 16,
                color: statusColors.infoForeground,
              ),
            ),
            const SizedBox(width: AppSpacing.space8),
            Expanded(
              child: Semantics(
                label: source.isNotEmpty
                    ? 'Source: $source. $subtitle.'
                    : '$subtitle.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (source.isNotEmpty)
                      Text(
                        'Source: $source',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactIdeaHelperBar extends StatelessWidget {
  const _CompactIdeaHelperBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      color: AppColors.softGreen.withValues(alpha: 0.45),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space12,
            vertical: AppSpacing.space12,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: AppColors.forest,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need a play idea?',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Match time and items at home.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space8),
              OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space12,
                  ),
                ),
                child: const Text('Get a play idea'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HorizontalScrollFade extends StatefulWidget {
  const _HorizontalScrollFade({required this.child});

  final Widget child;

  @override
  State<_HorizontalScrollFade> createState() => _HorizontalScrollFadeState();
}

class _HorizontalScrollFadeState extends State<_HorizontalScrollFade> {
  bool _showRightFade = true;

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.horizontal) return false;
    final hasMoreRight =
        notification.metrics.maxScrollExtent > 0 &&
        notification.metrics.extentAfter > 4;
    if (hasMoreRight != _showRightFade) {
      setState(() => _showRightFade = hasMoreRight);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: _showRightFade
          ? ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.9, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: widget.child,
            )
          : widget.child,
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
