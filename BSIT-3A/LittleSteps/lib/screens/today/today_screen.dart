import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../models/activity.dart';
import '../../models/child.dart';
import '../../models/plan.dart';
import '../../models/weather.dart';
import '../../services/api_client.dart';
import '../../services/catalog_service.dart';
import '../../services/plan_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/url_helper.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/state_views.dart';

/// Interaction states displayed by [TodayScreen].
enum TodayViewState {
  /// Initial network request is in flight.
  loading,

  /// Planned activities are loaded and displayed.
  ready,

  /// Zero activities are scheduled for the selected date.
  empty,

  /// A recoverable request error occurred.
  error,

  /// Cached activities are displayed while offline.
  offline,
}

/// Default sample activities used when catalog items are resolved offline.
final List<Activity> defaultTodayActivities = [
  const Activity(
    id: 'act-stack-cups',
    title: 'Stack the cups',
    type: 'activity',
    language: 'en',
    domain: 'motor',
    ageBand: '12-23m',
    durationMinutes: 10,
    durationEstimate: 'Under 10 mins',
    setting: 'indoor',
    materials: ['plastic cups'],
    instructions: [
      'Show how to stack two cups.',
      'Encourage knocking them down.',
    ],
    limitations: 'Watch small children near stacks.',
    status: 'synthetic_fixture',
    provenanceSource: 'LittleSteps',
  ),
  const Activity(
    id: 'act-shadow-dancing',
    title: 'Shadow dancing',
    type: 'activity',
    language: 'en',
    domain: 'socioEmotional',
    ageBand: '12-23m',
    durationMinutes: 8,
    durationEstimate: 'Under 10 mins',
    setting: 'indoor',
    materials: [],
    instructions: [
      'Turn off bright lights.',
      'Move hands to create animal shadows.',
    ],
    limitations: 'Keep floor clear of trip hazards.',
    status: 'synthetic_fixture',
    provenanceSource: 'LittleSteps',
  ),
  const Activity(
    id: 'act-nature-hunt',
    title: 'Nature treasure hunt',
    type: 'activity',
    language: 'en',
    domain: 'cognitive',
    ageBand: '12-23m',
    durationMinutes: 20,
    durationEstimate: '15-30 mins',
    setting: 'outdoor',
    materials: ['basket'],
    instructions: ['Look for two dry leaves.', 'Find a smooth pebble.'],
    limitations: 'Supervise outdoor exploration.',
    status: 'synthetic_fixture',
    provenanceSource: 'LittleSteps',
  ),
  const Activity(
    id: 'act-animal-sounds',
    title: 'Animal sound guessing',
    type: 'activity',
    language: 'en',
    domain: 'language',
    ageBand: '12-23m',
    durationMinutes: 5,
    durationEstimate: 'Under 10 mins',
    setting: 'indoor',
    materials: [],
    instructions: ['Make a cow sound.', 'Ask child who makes that sound.'],
    limitations: 'Keep volume comfortable.',
    status: 'synthetic_fixture',
    provenanceSource: 'LittleSteps',
  ),
];

/// In-memory store recording whether the non-diagnostic advisory was dismissed.
class TodayAdvisoryStorage {
  static final Set<String> _seenKeys = <String>{};

  /// Returns whether the advisory has been dismissed for [userKey].
  static bool hasSeen(String userKey) => _seenKeys.contains(userKey);

  /// Marks the advisory as dismissed for [userKey].
  static void markSeen(String userKey) => _seenKeys.add(userKey);

  /// Clears recorded dismissals for test isolation.
  static void reset() => _seenKeys.clear();
}

/// Today tab presenting planned play activities, completion status, and weather hints.
class TodayScreen extends StatefulWidget {
  /// Creates a [TodayScreen] with optional service and state overrides.
  const TodayScreen({
    super.key,
    this.planService,
    this.catalogService,
    this.initialState,
    this.initialPlans,
    this.initialActivities,
    this.initialWeatherHint,
    this.activeChild,
    this.initialDate,
    this.isOffline = false,
    this.onNavigateTab,
    this.planRefreshKey = 0,
  });

  /// Optional plan service override for managing activity plans.
  final PlanService? planService;

  /// Optional catalog service override for activity details and weather hints.
  final CatalogService? catalogService;

  /// Optional forced initial view state for widget tests.
  final TodayViewState? initialState;

  /// Optional initial list of planned items for widget tests.
  final List<PlanItem>? initialPlans;

  /// Optional lookup map of activity metadata for widget tests.
  final Map<String, Activity>? initialActivities;

  /// Optional weather hint override for widget tests.
  final WeatherHint? initialWeatherHint;

  /// Currently selected active child profile.
  final Child? activeChild;

  /// Calendar date for which the plan is viewed.
  final DateTime? initialDate;

  /// Whether offline mode is simulated or active.
  final bool isOffline;

  /// Optional callback invoked to switch to another tab in the app shell.
  final ValueChanged<int>? onNavigateTab;

  /// Incremented when another tab adds a plan item.
  final int planRefreshKey;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

// State container managing TodayScreen filters, completion requests, undo snackbars, and advisories.
class _TodayScreenState extends State<TodayScreen> {
  late TodayViewState _viewState;
  late DateTime _currentDate;
  late bool _isOffline;

  List<PlanItem> _plans = [];
  Map<String, Activity> _activityLookup = {};
  WeatherHint? _weatherHint;
  String? _errorMessage;

  bool _filterUnder10Mins = false;
  bool _filterNoMaterials = false;
  bool _filterIndoor = false;
  bool _advisorySeen = false;
  bool _weatherDismissed = false;

  // Active child profile resolved from widget injection or session state.
  Child? get _resolvedChild =>
      widget.activeChild ?? AuthScope.maybeOf(context)?.activeChild;

  // Safe accessor for the child identifier used for plan requests.
  String get _effectiveChildId => _resolvedChild?.id ?? 'c-maya-default';

  // Display name of the active child profile.
  String get _childName => _resolvedChild?.nickname ?? 'Maya';

  // Time-of-day greeting subtitle personalized for the active child.
  String get _greetingSubtitle {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    return "$greeting! Here's $_childName's play plan for today.";
  }

  // Sample observational milestone cues tailored to the active child's age band.
  List<String> get _milestoneCues {
    switch (_resolvedChild?.ageBand) {
      case '0-5m':
        return const [
          'Follows a moving face or toy with both eyes',
          'Turns head toward familiar voices and sounds',
          'Brings hands to mouth and kicks legs during play',
        ];
      case '6-11m':
        return const [
          'Passes a soft toy from one hand to the other',
          'Looks when you call their name or play peekaboo',
          'Babbles chains of vowel and consonant sounds',
        ];
      case '24-35m':
        return const [
          'Puts two or more words together during play',
          'Pretends to feed a doll or stir a toy cup',
          'Kicks a ball forward or climbs low steps with help',
        ];
      case '36-47m':
        return const [
          'Asks simple "what" or "where" questions while playing',
          'Takes turns in short games with a caregiver',
          'Sorts everyday objects by color or size',
        ];
      case '48-59m':
        return const [
          'Tells a short story about a drawing or pretend game',
          'Hops or balances briefly on one foot',
          'Counts a small group of household items together',
        ];
      case '60-71m':
        return const [
          'Follows two- or three-step game rules with ease',
          'Shares ideas and solves simple puzzles during play',
          'Draws shapes or letters and talks about what they mean',
        ];
      default:
        return const [
          'Explores toys by banging, shaking, or dropping',
          'Reaches out or gestures to show you something interesting',
          'Copies actions like waving goodbye or clapping',
        ];
    }
  }

  // Navigates to Explore or Idea Helper when requesting a play idea.
  void _openFindIdea() {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(1);
    } else {
      Navigator.pushNamed(context, '/ai-suggest');
    }
  }

  // Key used to persist advisory view state per child or install.
  String get _advisoryKey => 'advisory_$_effectiveChildId';

  @override
  void initState() {
    super.initState();
    _currentDate = widget.initialDate ?? DateTime.now();
    _isOffline = widget.isOffline;
    if (widget.activeChild != null) {
      _advisorySeen = TodayAdvisoryStorage.hasSeen(_advisoryKey);
    }

    if (widget.initialActivities != null) {
      _activityLookup = Map.from(widget.initialActivities!);
    } else {
      for (final act in defaultTodayActivities) {
        _activityLookup[act.id] = act;
      }
    }

    if (widget.initialWeatherHint != null) {
      _weatherHint = widget.initialWeatherHint;
    }

    if (widget.initialPlans != null) {
      _plans = List.from(widget.initialPlans!);
    }

    if (widget.initialState != null) {
      _viewState = widget.initialState!;
    } else if (widget.initialPlans != null) {
      _viewState = _plans.isEmpty ? TodayViewState.empty : TodayViewState.ready;
    } else {
      _viewState = _isOffline ? TodayViewState.offline : TodayViewState.loading;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadTodayPlan();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _advisorySeen = TodayAdvisoryStorage.hasSeen(_advisoryKey);
  }

  @override
  void didUpdateWidget(covariant TodayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialActivities != widget.initialActivities) {
      _activityLookup.addAll(widget.initialActivities ?? const {});
    }
    if (oldWidget.planRefreshKey != widget.planRefreshKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadTodayPlan();
      });
    }
  }

  // Resolves the ApiClient using planService or context AuthScope.
  ApiClient _resolveApiClient() {
    return widget.planService?.apiClient ??
        (AuthScope.maybeOf(context) != null
            ? AuthScope.apiClientOf(context)
            : ApiClient());
  }

  // Resolves the PlanService using widget injection or context-scoped ApiClient.
  PlanService _resolvePlanService() {
    if (widget.planService != null) return widget.planService!;
    final apiClient = AuthScope.maybeOf(context) != null
        ? AuthScope.apiClientOf(context)
        : ApiClient();
    return PlanService(apiClient: apiClient);
  }

  // Resolves the CatalogService using widget injection or context-scoped ApiClient.
  CatalogService _resolveCatalogService() {
    if (widget.catalogService != null) return widget.catalogService!;
    final apiClient = AuthScope.maybeOf(context) != null
        ? AuthScope.apiClientOf(context)
        : ApiClient();
    return CatalogService(apiClient: apiClient);
  }

  // Sends an accessible announcement to screen readers and live regions.
  void _announce(String message) {
    try {
      final view = View.of(context);
      SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);
    } catch (_) {}
  }

  // Formats a DateTime object as YYYY-MM-DD.
  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  // Loads today's planned activities and optional weather hint from the backend services.
  Future<void> _loadTodayPlan() async {
    if (_isOffline) {
      setState(() {
        _viewState = TodayViewState.offline;
      });
      _announce('Working offline. Planned activities for today.');
      return;
    }

    setState(() {
      _viewState = TodayViewState.loading;
      _errorMessage = null;
    });

    final planService = _resolvePlanService();
    final catalogService = _resolveCatalogService();
    final dateString = _formatDate(_currentDate);
    final session = AuthScope.maybeOf(context);
    final weatherLocation = session != null
        ? session.weatherLocation
        : WeatherLocation.iloiloCity;

    try {
      final results = await Future.wait([
        planService.getPlans(_effectiveChildId, date: dateString),
        if (weatherLocation != null)
          catalogService.getWeather(
            latitude: weatherLocation.latitude,
            longitude: weatherLocation.longitude,
          )
        else
          Future<WeatherHint?>.value(null),
      ]);

      final fetchedPlans = results[0] as List<PlanItem>;
      final fetchedWeather = results[1] as WeatherHint?;

      for (final plan in fetchedPlans) {
        if (!_activityLookup.containsKey(plan.activityId)) {
          try {
            final act = await catalogService.getActivityById(plan.activityId);
            _activityLookup[act.id] = act;
          } catch (_) {}
        }
      }

      if (!mounted) return;

      final isClientOffline = _resolveApiClient().isOffline;

      setState(() {
        _plans = fetchedPlans;
        _weatherHint = fetchedWeather;
        _isOffline = _isOffline || isClientOffline;
        _viewState = fetchedPlans.isEmpty
            ? TodayViewState.empty
            : TodayViewState.ready;
      });
    } on NoConnectionApiException {
      if (!mounted) return;
      setState(() {
        _viewState = TodayViewState.offline;
        _isOffline = true;
      });
      _announce('Working offline. Planned activities for today.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _viewState = TodayViewState.error;
        if (e.statusCode == 404 ||
            e.code == 'RESOURCE_NOT_FOUND' ||
            e.code == 'NOT_FOUND') {
          _errorMessage = "This activity isn't available anymore. It was taken off our list. The rest of your plan is still here.";
        } else {
          _errorMessage = e.message;
        }
      });
      _announce(_errorMessage ?? 'An error occurred loading today plan');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _viewState = _isOffline ? TodayViewState.offline : TodayViewState.error;
        _errorMessage =
            'Unable to connect. Please check your network and try again.';
      });
      _announce('Unable to connect. Working offline.');
    }
  }

  // Marks an activity complete and presents a 10-second undo snackbar.
  Future<void> _markComplete(PlanItem plan, Activity activity) async {
    if (_isOffline || _resolveApiClient().isOffline) {
      _announce("This activity wasn't marked complete");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This activity wasn't marked complete"),
          duration: Duration(seconds: 4),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final previousIndex = _plans.indexWhere((p) => p.id == plan.id);
    if (previousIndex == -1) return;

    final updatedPlan = PlanItem(
      id: plan.id,
      childId: plan.childId,
      activityId: plan.activityId,
      scheduledDate: plan.scheduledDate,
      status: 'completed',
      completedAt: DateTime.now(),
      durationMinutes: plan.durationMinutes,
      feedbackNote: plan.feedbackNote,
      createdAt: plan.createdAt,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _plans[previousIndex] = updatedPlan;
    });

    try {
      final planService = _resolvePlanService();
      await planService.updatePlanStatus(
        childId: _effectiveChildId,
        planId: plan.id,
        status: 'completed',
      );

      _announce('${activity.title} marked complete');

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${activity.title} marked complete'),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.cream,
            onPressed: () {
              _undoComplete(plan, activity);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _plans[previousIndex] = plan;
      });

      _announce("This activity wasn't marked complete");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This activity wasn't marked complete"),
          duration: Duration(seconds: 4),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // Reverses a previously recorded completion back to planned status.
  Future<void> _undoComplete(PlanItem plan, Activity activity) async {
    final targetIndex = _plans.indexWhere((p) => p.id == plan.id);
    if (targetIndex == -1) return;

    final restoredPlan = PlanItem(
      id: plan.id,
      childId: plan.childId,
      activityId: plan.activityId,
      scheduledDate: plan.scheduledDate,
      status: 'planned',
      completedAt: null,
      durationMinutes: plan.durationMinutes,
      feedbackNote: plan.feedbackNote,
      createdAt: plan.createdAt,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _plans[targetIndex] = restoredPlan;
    });

    try {
      final planService = _resolvePlanService();
      await planService.updatePlanStatus(
        childId: _effectiveChildId,
        planId: plan.id,
        status: 'planned',
      );
      _announce('Completion undone for ${activity.title}');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not undo completion. Please try again.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // Marks the non-diagnostic advisory banner as dismissed and persists the state.
  void _dismissAdvisory() {
    setState(() {
      _advisorySeen = true;
    });
    TodayAdvisoryStorage.markSeen(_advisoryKey);
    _announce('Advisory minimized. Persistent link available.');
  }

  // Displays a modal dialog with the full non-diagnostic advisory guidance.
  void _showAdvisoryDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Not a diagnostic tool'),
          content: const SingleChildScrollView(
            child: Text(
              'Not a diagnostic tool. Observational play suggestions only. You know your child best. Every child develops at their own pace with unique milestones.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Resets all quick filter chips back to unselected.
  void _clearFilters() {
    setState(() {
      _filterUnder10Mins = false;
      _filterNoMaterials = false;
      _filterIndoor = false;
    });
    _announce('All activity filters cleared');
  }

  // Filters the current list of plans based on active filter criteria.
  List<PlanItem> _getFilteredPlans() {
    return _plans.where((plan) {
      final activity = _activityLookup[plan.activityId];
      if (activity == null) return true;

      if (_filterUnder10Mins) {
        if (activity.durationMinutes > 10) return false;
      }

      if (_filterNoMaterials) {
        final hasMaterials = activity.materials.any(
          (m) => m.trim().isNotEmpty && m.toLowerCase() != 'none',
        );
        if (hasMaterials) return false;
      }

      if (_filterIndoor) {
        final setting = activity.setting.toLowerCase();
        if (setting != 'indoor' && setting != 'either') return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isOffline || _viewState == TodayViewState.offline)
              const OfflineBanner(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // Renders the appropriate view corresponding to the current TodayViewState.
  Widget _buildBody() {
    switch (_viewState) {
      case TodayViewState.loading:
        return const LoadingView(message: "Loading today's plan...");
      case TodayViewState.error:
        return ErrorView(
          message: _errorMessage ?? 'Something went wrong loading today plan.',
          onRetry: _loadTodayPlan,
        );
      case TodayViewState.empty:
        return _buildEmptyState();
      case TodayViewState.offline:
      case TodayViewState.ready:
        return _buildPopulatedView();
    }
  }

  // Renders the shared Today header, advisory, and weather hint.
  Widget _buildHeaderBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeader(title: 'Today', subtitle: _greetingSubtitle),
        const SizedBox(height: AppSpacing.space12),
        _buildAdvisorySection(),
        const SizedBox(height: AppSpacing.space12),
        _buildWeatherHintSection(),
      ],
    );
  }

  // Arranges the plan column beside reflection and milestone shortcuts on wide screens.
  Widget _buildDashboardContent({required Widget mainColumn}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 860) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: mainColumn),
              const SizedBox(width: AppSpacing.space24),
              SizedBox(width: 340, child: _buildSideCards()),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            mainColumn,
            const SizedBox(height: AppSpacing.space20),
            _buildSideCards(),
          ],
        );
      },
    );
  }

  // Renders the empty state when no activities are scheduled for today.
  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _loadTodayPlan,
      color: AppColors.forest,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.space16),
        children: [
          _buildHeaderBlock(),
          _buildDashboardContent(
            mainColumn: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$_childName's plan for today",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space12),
                _buildEmptyPlanCard(),
                const SizedBox(height: AppSpacing.space24),
                _buildHistorySection(completedCount: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Renders the main populated list with filters, weather hint, and activity cards.
  Widget _buildPopulatedView() {
    final filteredPlans = _getFilteredPlans();
    final hasActiveFilters =
        _filterUnder10Mins || _filterNoMaterials || _filterIndoor;
    final completedCount = _plans.where((plan) => plan.isCompleted).length;

    return RefreshIndicator(
      onRefresh: _loadTodayPlan,
      color: AppColors.forest,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.space16),
        children: [
          _buildHeaderBlock(),
          _buildDashboardContent(
            mainColumn: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$_childName's plan for today",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space8),
                _buildFilterChips(),
                const SizedBox(height: AppSpacing.space12),
                if (filteredPlans.isEmpty && hasActiveFilters)
                  _buildEmptyFilterState()
                else if (_plans.isEmpty)
                  _buildEmptyPlanCard()
                else
                  ...filteredPlans.map((plan) {
                    final activity =
                        _activityLookup[plan.activityId] ??
                        Activity(
                          id: plan.activityId,
                          title: 'Scheduled activity',
                          type: 'activity',
                          language: 'en',
                          domain: 'play',
                          ageBand: '0-5y',
                          durationMinutes: plan.durationMinutes ?? 10,
                          durationEstimate:
                              '${plan.durationMinutes ?? 10} mins',
                          setting: 'indoor',
                          materials: const [],
                          instructions: const [],
                          limitations: '',
                          status: 'synthetic_fixture',
                          provenanceSource: 'LittleSteps',
                        );
                    return _TodayActivityCard(
                      plan: plan,
                      activity: activity,
                      onCompleteToggle: () => _markComplete(plan, activity),
                    );
                  }),
                const SizedBox(height: AppSpacing.space20),
                _buildHistorySection(completedCount: completedCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Renders the white card shown when no activities are planned yet for today.
  Widget _buildEmptyPlanCard() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.today_outlined,
                size: 20,
                color: AppColors.forest,
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: Text(
                  'No activities planned for today',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space8),
          Text(
            'Want a quick idea? Most take 10 minutes or less.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
          OutlinedButton(
            onPressed: _openFindIdea,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, AppSizes.touchTarget),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space16,
              ),
              side: const BorderSide(color: AppColors.borderInput),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
            ),
            child: const Text('Find an idea'),
          ),
        ],
      ),
    );
  }

  // Renders the History summary section below today's play plan.
  Widget _buildHistorySection({required int completedCount}) {
    final theme = Theme.of(context);
    final summaryText = completedCount == 0
        ? 'Completed activities for $_childName will show here.'
        : completedCount == 1
        ? '1 activity completed for $_childName today.'
        : '$completedCount activities completed for $_childName today.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'History',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.space8),
        Text(
          summaryText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // Renders the "This week" and "Milestones to notice" summary shortcut cards.
  Widget _buildSideCards() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.space20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This week',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.space8),
              Text(
                'Reflect on everyday moments and shared play from this week.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.onNavigateTab != null
                      ? () => widget.onNavigateTab!(4)
                      : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppSizes.touchTarget),
                    side: const BorderSide(color: AppColors.borderInput),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                  ),
                  child: const Text('View reflection'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space16),
        Container(
          padding: const EdgeInsets.all(AppSpacing.space20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Milestones to notice',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.space8),
              Text(
                'Everyday cues to notice for $_childName:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space12),
              ..._milestoneCues.map(
                (cue) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space8),
                      Expanded(
                        child: Text(
                          cue,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.space8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.onNavigateTab != null
                      ? () => widget.onNavigateTab!(2)
                      : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppSizes.touchTarget),
                    side: const BorderSide(color: AppColors.borderInput),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                  ),
                  child: const Text('View milestones'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Renders the advisory banner or persistent link depending on dismissal state.
  Widget _buildAdvisorySection() {
    if (!_advisorySeen) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceAdvisory,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.borderAdvisory),
        ),
        padding: const EdgeInsets.all(AppSpacing.space12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline,
              size: 20,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Text(
                'Not a diagnostic tool. Observational play suggestions only. You know your child best.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textPrimary),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Dismiss advisory',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: _dismissAdvisory,
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _showAdvisoryDialog,
        icon: const Icon(
          Icons.info_outline,
          size: 16,
          color: AppColors.textSecondary,
        ),
        label: Text(
          'Not a diagnostic tool',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  // Renders the dismissible weather guidance hint with Open-Meteo attribution.
  Widget _buildWeatherHintSection() {
    final hint = _weatherHint;
    if (_weatherDismissed ||
        hint == null ||
        hint.hint == null ||
        hint.isUnavailable) {
      return const SizedBox.shrink();
    }

    final showIndoorAction =
        hint.suggestedSetting == 'indoor' ||
        (hint.hint?.contains('Indoor') ?? false);

    return Semantics(
      liveRegion: true,
      label: 'Weather guidance: ${hint.hint}',
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.space16),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space8,
        ),
        decoration: BoxDecoration(
          color: AppColors.softGreen,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  hint.isRainy ? Icons.cloud_outlined : Icons.wb_sunny_outlined,
                  size: 18,
                  color: AppColors.forest,
                ),
                const SizedBox(width: AppSpacing.space8),
                Expanded(
                  child: Text(
                    hint.hint!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Dismiss weather hint',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () {
                    setState(() {
                      _weatherDismissed = true;
                    });
                  },
                ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.space12,
              runSpacing: AppSpacing.space4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InkWell(
                  onTap: () =>
                      openExternalUrl(context, 'https://open-meteo.com'),
                  child: Text(
                    hint.attribution,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                if (showIndoorAction)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space8,
                      ),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      setState(() {
                        _filterIndoor = true;
                      });
                      if (_plans.isEmpty && widget.onNavigateTab != null) {
                        widget.onNavigateTab!(1);
                        _announce(
                          'Navigating to Explore for indoor play ideas',
                        );
                      } else {
                        _announce('Indoor filter applied from weather hint');
                      }
                    },
                    icon: const Icon(Icons.arrow_forward, size: 14),
                    label: const Text('Indoor ideas'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Renders quick filter chips for duration, materials, and setting.
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text('Under 10 mins'),
            selected: _filterUnder10Mins,
            onSelected: (selected) {
              setState(() {
                _filterUnder10Mins = selected;
              });
              _announce(
                selected
                    ? 'Filtered to under 10 minutes'
                    : 'Under 10 minutes filter removed',
              );
            },
          ),
          const SizedBox(width: AppSpacing.space8),
          FilterChip(
            label: const Text('No materials needed'),
            selected: _filterNoMaterials,
            onSelected: (selected) {
              setState(() {
                _filterNoMaterials = selected;
              });
              _announce(
                selected
                    ? 'Filtered to no materials needed'
                    : 'No materials filter removed',
              );
            },
          ),
          const SizedBox(width: AppSpacing.space8),
          FilterChip(
            label: const Text('Indoor'),
            selected: _filterIndoor,
            onSelected: (selected) {
              setState(() {
                _filterIndoor = selected;
              });
              _announce(
                selected
                    ? 'Filtered to indoor activities'
                    : 'Indoor filter removed',
              );
            },
          ),
        ],
      ),
    );
  }

  // Renders the empty state when no activities match active filters with a clear filter action.
  Widget _buildEmptyFilterState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.filter_list_off,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.space16),
          Text(
            'No activities match your filters',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.space8),
          Text(
            'Try clearing one or more filters to see planned activities.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.space16),
          FilledButton.tonal(
            onPressed: _clearFilters,
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}

// Card widget rendering a planned activity with duration, domain, completion badge, and action.
class _TodayActivityCard extends StatelessWidget {
  // Creates a [_TodayActivityCard] with the given plan and activity data.
  const _TodayActivityCard({
    required this.plan,
    required this.activity,
    required this.onCompleteToggle,
  });

  // The plan item tracking schedule and completion state.
  final PlanItem plan;

  // The resolved catalog activity details.
  final Activity activity;

  // Callback invoked when the caregiver toggles completion.
  final VoidCallback onCompleteToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = plan.isCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.space12),
      color: AppColors.surfaceCard,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      Wrap(
                        spacing: AppSpacing.space8,
                        runSpacing: AppSpacing.space4,
                        children: [
                          _TagBadge(label: activity.domain),
                          _TagBadge(label: '${activity.durationMinutes} mins'),
                          _TagBadge(label: activity.setting),
                          if (activity.materials.isEmpty ||
                              activity.materials.every(
                                (m) => m.toLowerCase() == 'none',
                              ))
                            const _TagBadge(label: 'No materials')
                          else
                            _TagBadge(
                              label: '${activity.materials.length} materials',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.space8),
                _buildCompletionAction(context),
              ],
            ),
            if (isCompleted) ...[
              const SizedBox(height: AppSpacing.space12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space12,
                  vertical: AppSpacing.space4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(
                    color: AppColors.forest.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: AppColors.forest,
                    ),
                    const SizedBox(width: AppSpacing.space4),
                    Text(
                      'Completed today',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.forest,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Renders the accessible 48x48dp button or checkbox for completing an activity.
  Widget _buildCompletionAction(BuildContext context) {
    if (plan.isCompleted) {
      return Semantics(
        label: 'Marked complete. Tapping will toggle status.',
        child: IconButton(
          icon: const Icon(
            Icons.check_circle,
            color: AppColors.forest,
            size: 28,
          ),
          tooltip: 'Completed today',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: onCompleteToggle,
        ),
      );
    }

    return Semantics(
      label: 'Mark ${activity.title} complete',
      child: OutlinedButton(
        onPressed: onCompleteToggle,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space12),
          side: const BorderSide(color: AppColors.forest),
        ),
        child: const Text('Mark complete'),
      ),
    );
  }
}

// Badge widget rendering a metadata tag chip.
class _TagBadge extends StatelessWidget {
  // Creates a [_TagBadge] with a text label.
  const _TagBadge({required this.label});

  // Label text displayed inside the badge.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceCanvas,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
