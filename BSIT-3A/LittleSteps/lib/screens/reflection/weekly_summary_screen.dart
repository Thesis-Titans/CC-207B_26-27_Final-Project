import 'package:flutter/material.dart';

import '../../models/summary.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/screen_header.dart';

/// View states for the weekly summary screen.
enum WeeklySummaryViewState { ready, loading, error, offline }

/// "This week" reflection tab presenting factual weekly summaries for the active child.
class WeeklySummaryScreen extends StatefulWidget {
  const WeeklySummaryScreen({
    super.key,
    this.initialState = WeeklySummaryViewState.ready,
    this.initialWeek = '2026-W43',
    this.summaries,
    this.childName,
    this.childAgeBand,
  });

  final WeeklySummaryViewState initialState;
  final String initialWeek;
  final Map<String, WeeklySummary>? summaries;
  final String? childName;
  final String? childAgeBand;

  @override
  State<WeeklySummaryScreen> createState() => _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends State<WeeklySummaryScreen> {
  late WeeklySummaryViewState _currentState;
  late String _selectedWeekId;
  late Map<String, WeeklySummary> _summaries;

  String get _childName {
    final session = AuthScope.maybeOf(context);
    return session?.activeChild?.nickname ?? widget.childName ?? 'Maya';
  }

  String get _childAgeDisplay {
    final session = AuthScope.maybeOf(context);
    final activeChild = session?.activeChild;
    if (activeChild != null) {
      return activeChild.ageBand.contains('month')
          ? activeChild.ageBand
          : '${activeChild.ageBand} months';
    }
    return widget.childAgeBand ?? '14 months';
  }

  @override
  void initState() {
    super.initState();
    _currentState = widget.initialState;
    _selectedWeekId = widget.initialWeek;
    _summaries = widget.summaries ?? sampleWeeklySummaries;
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
                      setState(() => _selectedWeekId = weekId);
                      Navigator.of(context).pop();
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
        // Title & Subtitle
        const ScreenHeader(
          title: 'This week',
          subtitle: 'A look back at the moments you wrote down.',
        ),
        const SizedBox(height: AppSpacing.space12),

        // Child Selector Pill
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space12,
            vertical: AppSpacing.space8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.borderSubtle),
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Row(
            children: [
              Text(
                'For $_childName · $_childAgeDisplay',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space12),

        // Week Selector Box
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
                      _currentSummary?.formattedRange ?? _selectedWeekId,
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

        // State-driven Content
        if (_currentState == WeeklySummaryViewState.loading)
          _buildLoadingState()
        else if (_currentState == WeeklySummaryViewState.error)
          _buildErrorState()
        else ...[
          if (_currentState == WeeklySummaryViewState.offline)
            _buildOfflineBanner(),

          // Populated vs Empty week views
          if (_currentSummary == null || _currentSummary!.isEmptyWeek)
            _buildEmptyWeekCard()
          else
            _buildPopulatedWeekView(_currentSummary!),
        ],
      ],
    );
  }

  Widget _buildPopulatedWeekView(WeeklySummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card 1: "This week with Maya"
        Container(
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

              // Two Stats Cards
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

              // Non-diagnostic Disclaimer
              Text(
                "Based only on what you wrote down. It's not a test, and it never compares $_childName with other children. Journal notes stay private.",
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space16),

        // Card 2: "Everyday play areas" (Activities by domain)
        Container(
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
        ),
        const SizedBox(height: AppSpacing.space16),

        // Card 3: "Something to try" (Reflection Prompt Card)
        if (summary.reflectionPrompt.isNotEmpty)
          Container(
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
          ),
        const SizedBox(height: AppSpacing.space24),
      ],
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
                // Navigate to Explore tab or initial route
                Navigator.of(context).maybePop();
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
