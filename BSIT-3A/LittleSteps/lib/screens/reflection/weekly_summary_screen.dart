import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/summary.dart';
import '../../services/api_client.dart';
import '../../services/milestones_service.dart';
import '../../services/plan_service.dart';
import '../../services/summary_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/screen_header.dart';

/// View states for the weekly summary screen.
enum WeeklySummaryViewState {
  /// Weekly summary metrics and reflection card are displayed.
  ready,

  /// Weekly summary data is loading from the backend.
  loading,

  /// A recoverable request error occurred.
  error,

  /// Cached weekly summary data is displayed while offline.
  offline,
}

/// "This week" reflection tab presenting factual weekly summaries for the active child.
class WeeklySummaryScreen extends StatefulWidget {
  /// Creates a [WeeklySummaryScreen].
  const WeeklySummaryScreen({
    super.key,
    this.initialState = WeeklySummaryViewState.ready,
    this.initialWeek = '2026-W43',
    this.summaries,
    this.childName,
    this.childAgeBand,
    this.summaryService,
    this.onFindIdea,
  });

  /// Initial view state override for widget tests.
  final WeeklySummaryViewState initialState;

  /// Initial ISO week identifier selected on load.
  final String initialWeek;

  /// Optional map of preloaded summaries keyed by ISO week.
  final Map<String, WeeklySummary>? summaries;

  /// Optional child nickname override for widget tests.
  final String? childName;

  /// Optional child age-band override for widget tests.
  final String? childAgeBand;

  /// Optional service override for fetching weekly summaries.
  final SummaryService? summaryService;

  /// Optional callback invoked when the caregiver taps "Find a 10-minute idea".
  final VoidCallback? onFindIdea;

  @override
  State<WeeklySummaryScreen> createState() => _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends State<WeeklySummaryScreen> {
  late WeeklySummaryViewState _currentState;
  late String _selectedWeekId;
  late Map<String, WeeklySummary> _summaries;
  String? _lastChildId;
  bool _initialLoadStarted = false;

  ApiClient _resolveApiClient() {
    return widget.summaryService?.apiClient ??
        (AuthScope.maybeOf(context) != null
            ? AuthScope.apiClientOf(context)
            : ApiClient());
  }

  SummaryService _resolveSummaryService() {
    if (widget.summaryService != null) return widget.summaryService!;
    return SummaryService(apiClient: _resolveApiClient());
  }

  String? get _childId {
    final session = AuthScope.maybeOf(context);
    return session?.activeChild?.id;
  }

  String get _childName {
    final session = AuthScope.maybeOf(context);
    return session?.activeChild?.nickname ?? widget.childName ?? 'Maya';
  }

  String get _childAgeDisplay {
    final session = AuthScope.maybeOf(context);
    final activeChild = session?.activeChild;
    if (activeChild != null) {
      final band = activeChild.ageBand;
      if (band.contains('month')) return band;
      if (band.endsWith('m')) {
        return '${band.substring(0, band.length - 1)} months';
      }
      return '$band months';
    }
    return widget.childAgeBand ?? '14 months';
  }

  MilestonesService _resolveMilestonesService() {
    return MilestonesService(apiClient: _resolveApiClient());
  }

  PlanService _resolvePlanService() {
    return PlanService(apiClient: _resolveApiClient());
  }

  static String dateToIsoWeek(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length < 3) return '';
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final date = DateTime.utc(year, month, day);

      final thursday = date.add(
        Duration(days: 4 - (date.weekday == 0 ? 7 : date.weekday)),
      );
      final isoYear = thursday.year;
      final jan4 = DateTime.utc(isoYear, 1, 4);
      final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
      final weekNumber =
          1 + ((thursday.difference(week1Monday).inDays) / 7).floor();
      return '$isoYear-W${weekNumber.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  static WeeklySummary _createEmptyWeekSummaryForId(String weekId) {
    try {
      final parts = weekId.split('-W');
      final year = int.parse(parts[0]);
      final week = int.parse(parts[1]);

      final jan4 = DateTime.utc(year, 1, 4);
      final jan4Dow = jan4.weekday;
      final week1Monday = jan4.subtract(Duration(days: jan4Dow - 1));
      final monday = week1Monday.add(Duration(days: (week - 1) * 7));
      final sunday = monday.add(const Duration(days: 6));

      return WeeklySummary(
        id: weekId,
        weekStartDate: DateFormat('yyyy-MM-dd').format(monday),
        weekEndDate: DateFormat('yyyy-MM-dd').format(sunday),
        completedActivityCount: 0,
        observedMilestoneCount: 0,
        totalPlannedActivities: 0,
        domainDistribution: const {
          'cognitive': 0,
          'motor': 0,
          'language': 0,
          'socioEmotional': 0,
        },
        topActivityIds: const [],
        reflectionPrompt: '',
        generatedAt: DateTime.now(),
      );
    } catch (_) {
      return WeeklySummary(
        id: weekId,
        weekStartDate: '',
        weekEndDate: '',
        completedActivityCount: 0,
        observedMilestoneCount: 0,
        totalPlannedActivities: 0,
        domainDistribution: const {},
        topActivityIds: const [],
        reflectionPrompt: '',
        generatedAt: DateTime.now(),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _currentState = widget.initialState;
    if (widget.summaries != null) {
      _selectedWeekId = widget.initialWeek;
      _summaries = widget.summaries!;
    } else {
      _currentState = WeeklySummaryViewState.loading;
      _selectedWeekId = '';
      _summaries = {};
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.summaries != null) {
      _summaries = widget.summaries!;
      _selectedWeekId = widget.initialWeek;
      _currentState = widget.initialState;
      return;
    }
    final childId = _childId;
    final childChanged = childId != _lastChildId;
    if (!_initialLoadStarted || childChanged) {
      _initialLoadStarted = true;
      _lastChildId = childId;
      _loadWeeklySummary(null, childId);
    }
  }

  Future<void> _loadWeeklySummary([String? weekId, String? childId]) async {
    final targetChildId = childId ?? _childId;
    if (targetChildId == null) {
      if (mounted) {
        setState(() {
          _currentState = WeeklySummaryViewState.ready;
        });
      }
      return;
    }

    try {
      final service = _resolveSummaryService();
      final summary = await service.getWeeklySummary(
        targetChildId,
        week: weekId,
      );
      if (!mounted || targetChildId != _lastChildId) return;

      final updatedSummaries = Map<String, WeeklySummary>.from(_summaries);
      updatedSummaries[summary.id] = summary;

      // Discover recorded past weeks with activities or milestones in database
      try {
        final milestonesService = _resolveMilestonesService();
        final planService = _resolvePlanService();
        final obsList = await milestonesService.getObservations(targetChildId);
        final plansList = await planService.getPlans(targetChildId);

        for (final obs in obsList) {
          if (obs.observedDate.isNotEmpty) {
            final w = dateToIsoWeek(obs.observedDate);
            if (w.isNotEmpty && !updatedSummaries.containsKey(w)) {
              updatedSummaries[w] = _createEmptyWeekSummaryForId(w);
            }
          }
        }
        for (final plan in plansList) {
          if (plan.scheduledDate.isNotEmpty) {
            final w = dateToIsoWeek(plan.scheduledDate);
            if (w.isNotEmpty && !updatedSummaries.containsKey(w)) {
              updatedSummaries[w] = _createEmptyWeekSummaryForId(w);
            }
          }
        }
      } catch (_) {}

      final sortedKeys = updatedSummaries.keys.toList()
        ..sort((a, b) => b.compareTo(a));
      final sortedMap = <String, WeeklySummary>{};
      for (final k in sortedKeys) {
        sortedMap[k] = updatedSummaries[k]!;
      }

      setState(() {
        _summaries = sortedMap;
        _selectedWeekId = summary.id;
        _currentState = WeeklySummaryViewState.ready;
      });
    } on NoConnectionApiException {
      if (!mounted || targetChildId != _lastChildId) return;
      setState(() => _currentState = WeeklySummaryViewState.offline);
    } on TimeoutApiException {
      if (!mounted || targetChildId != _lastChildId) return;
      setState(() => _currentState = WeeklySummaryViewState.offline);
    } catch (_) {
      if (!mounted || targetChildId != _lastChildId) return;
      setState(() => _currentState = WeeklySummaryViewState.error);
    }
  }

  WeeklySummary? get _currentSummary => _summaries[_selectedWeekId];

  void _showWeekPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select a week',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space12),
                ..._summaries.keys.map((weekId) {
                  final summary = _summaries[weekId]!;
                  final isSelected = weekId == _selectedWeekId;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space8,
                      vertical: AppSpacing.space4,
                    ),
                    title: Text(
                      summary.formattedRange,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? AppColors.forest
                            : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      summary.isEmptyWeek
                          ? 'No activities recorded'
                          : '${summary.completedActivityCount} activities · ${summary.observedMilestoneCount} milestones',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.forest)
                        : null,
                    onTap: () {
                      final picked = weekId;
                      setState(() => _selectedWeekId = picked);
                      Navigator.of(context).pop();
                      if (widget.summaries == null && _childId != null) {
                        _loadWeeklySummary(picked);
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space16,
      ),
      children: [
        const ScreenHeader(
          title: 'This week',
          subtitle: 'A look back at the moments you wrote down.',
        ),
        const SizedBox(height: AppSpacing.space12),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space12,
            vertical: AppSpacing.space8,
          ),
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.child_care_outlined,
                size: 16,
                color: AppColors.forest,
              ),
              const SizedBox(width: AppSpacing.space8),
              Text(
                'For $_childName · $_childAgeDisplay',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space12),
        InkWell(
          onTap: _showWeekPicker,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space12,
              vertical: AppSpacing.space8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.borderSubtle),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Week · Monday to Sunday',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _currentSummary?.formattedRange ??
                          (_selectedWeekId.isNotEmpty
                              ? _selectedWeekId
                              : 'Current week'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.space16),
        if (_currentState == WeeklySummaryViewState.loading)
          _buildLoadingState()
        else if (_currentState == WeeklySummaryViewState.error)
          _buildErrorState()
        else if (_currentState == WeeklySummaryViewState.offline) ...[
          _buildOfflineBanner(),
          if (_currentSummary != null && !_currentSummary!.isEmptyWeek)
            _buildPopulatedWeekView(_currentSummary!),
        ] else ...[
          if (_currentSummary == null || _currentSummary!.isEmptyWeek)
            _buildEmptyWeekCard()
          else
            _buildPopulatedWeekView(_currentSummary!),
        ],
      ],
    );
  }

  Widget _buildPopulatedWeekView(WeeklySummary summary) {
    final summaryCard = Container(
      padding: const EdgeInsets.all(AppSpacing.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This week with $_childName',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.space12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.space12,
                    horizontal: AppSpacing.space12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${summary.completedActivityCount}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'activities\ncompleted',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.space12,
                    horizontal: AppSpacing.space12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${summary.observedMilestoneCount}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary.observedMilestoneCount == 1
                            ? 'milestone\nnoticed'
                            : 'milestones\nnoticed',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          Text(
            "Based only on what you wrote down. It's not a test, and it never compares $_childName with other children. Journal notes stay private.",
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary, height: 1.35),
          ),
        ],
      ),
    );

    final domainsCard = Container(
      padding: const EdgeInsets.all(AppSpacing.space16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Everyday play areas',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.space12),
          ..._buildDomainRows(summary.domainDistribution),
        ],
      ),
    );

    final promptCard = summary.reflectionPrompt.isNotEmpty
        ? Container(
            padding: const EdgeInsets.all(AppSpacing.space16),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Something to try',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space8),
                Text(
                  summary.reflectionPrompt,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textPrimary, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.space8),
                Text(
                  'An idea for play, not a goal to meet.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 860 && promptCard != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summaryCard,
                      const SizedBox(height: AppSpacing.space16),
                      domainsCard,
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.space24),
                SizedBox(width: 340, child: promptCard),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            summaryCard,
            const SizedBox(height: AppSpacing.space16),
            domainsCard,
            if (promptCard != null) ...[
              const SizedBox(height: AppSpacing.space16),
              promptCard,
            ],
            const SizedBox(height: AppSpacing.space24),
          ],
        );
      },
    );
  }

  List<Widget> _buildDomainRows(Map<String, int> distribution) {
    const domains = [
      ('cognitive', 'Thinking'),
      ('motor', 'Moving'),
      ('language', 'Talking'),
      ('socioEmotional', 'Feelings'),
    ];

    return domains.map((domain) {
      final count = distribution[domain.$1] ?? 0;
      final countText = count == 0
          ? 'None this week'
          : count == 1
          ? '1 activity'
          : '$count activities';

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(
              domain.$2,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              countText,
              style: TextStyle(
                color: count == 0
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
                fontWeight: count == 0 ? FontWeight.normal : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildEmptyWeekCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.cream,
            radius: 28,
            child: const Icon(
              Icons.bar_chart_outlined,
              color: AppColors.forest,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.space16),
          const Text(
            'Nothing recorded this week yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.space8),
          const Text(
            "This fills in when you finish an activity or note a milestone. There's no daily goal and nothing to catch up on.",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.space20),
          SizedBox(
            height: AppSizes.touchTarget,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
              ),
              onPressed: () {
                if (widget.onFindIdea != null) {
                  widget.onFindIdea!();
                } else {
                  Navigator.pushNamed(context, '/ai-suggest');
                }
              },
              child: const Text(
                'Find a 10-minute idea',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space12),
            child: Container(
              height: 90,
              padding: const EdgeInsets.all(AppSpacing.space16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.borderSubtle,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space8),
                        Container(
                          width: 160,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.borderSubtle.withValues(
                              alpha: 0.6,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceError,
        border: Border.all(color: AppColors.borderError),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.textError, size: 20),
              SizedBox(width: AppSpacing.space8),
              Text(
                "We couldn't load this right now",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textError,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          const Text(
            'Try again in a moment.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.space16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.borderInput),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
            ),
            onPressed: () =>
                setState(() => _currentState = WeeklySummaryViewState.ready),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space12),
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
            "Showing previously recorded moments. Connect to the internet to sync updates.",
            style: TextStyle(color: AppColors.textOffline, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.space12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
            ),
            onPressed: () =>
                setState(() => _currentState = WeeklySummaryViewState.ready),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
