import 'package:intl/intl.dart';

/// A child's weekly summary of completed activities and observations.
class WeeklySummary {
  const WeeklySummary({
    required this.id,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.completedActivityCount,
    required this.observedMilestoneCount,
    required this.totalPlannedActivities,
    required this.domainDistribution,
    required this.topActivityIds,
    required this.reflectionPrompt,
    required this.generatedAt,
  });

  /// ISO week, for example `2026-W47`.
  final String id;

  /// Monday of the week, `YYYY-MM-DD`.
  final String weekStartDate;

  /// Sunday of the week, `YYYY-MM-DD`.
  final String weekEndDate;
  final int completedActivityCount;
  final int observedMilestoneCount;
  final int totalPlannedActivities;

  /// Completed activities per domain: `cognitive`, `motor`, `language`,
  /// `socioEmotional`.
  final Map<String, int> domainDistribution;

  /// Up to three most-completed activity ids.
  final List<String> topActivityIds;
  final String reflectionPrompt;
  final DateTime generatedAt;

  /// Whether this week has zero completed activities and zero milestones.
  bool get isEmptyWeek =>
      completedActivityCount == 0 && observedMilestoneCount == 0;

  /// Formatted week range, for example `Oct 19 – 25, 2026`.
  String get formattedRange {
    final start = DateTime.tryParse(weekStartDate);
    final end = DateTime.tryParse(weekEndDate);
    if (start == null || end == null) {
      return '$weekStartDate – $weekEndDate';
    }
    final startMonth = DateFormat('MMM').format(start);
    final endMonth = DateFormat('MMM').format(end);
    final year = DateFormat('yyyy').format(end);

    if (start.month == end.month) {
      return '$startMonth ${start.day} – ${end.day}, $year';
    } else {
      return '$startMonth ${start.day} – $endMonth ${end.day}, $year';
    }
  }

  factory WeeklySummary.fromJson(Map<String, dynamic> json) {
    return WeeklySummary(
      id: json['id'] as String,
      weekStartDate: json['weekStartDate'] as String,
      weekEndDate: json['weekEndDate'] as String,
      completedActivityCount: json['completedActivityCount'] as int,
      observedMilestoneCount: json['observedMilestoneCount'] as int,
      totalPlannedActivities: json['totalPlannedActivities'] as int,
      domainDistribution: (json['domainDistribution'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as int)),
      topActivityIds: (json['topActivityIds'] as List<dynamic>).cast<String>(),
      reflectionPrompt: json['reflectionPrompt'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }
}

/// Synthetic weekly summaries matching the Figma wireframes for testing and offline demo.
final Map<String, WeeklySummary> sampleWeeklySummaries = {
  // Populated week (Matching Figma Screen 1: Oct 19 - 25, 2026)
  '2026-W43': WeeklySummary(
    id: '2026-W43',
    weekStartDate: '2026-10-19',
    weekEndDate: '2026-10-25',
    completedActivityCount: 4,
    observedMilestoneCount: 1,
    totalPlannedActivities: 5,
    domainDistribution: const {
      'cognitive': 1,
      'motor': 1,
      'language': 2,
      'socioEmotional': 0,
    },
    topActivityIds: const ['act-1', 'act-2'],
    reflectionPrompt: 'Maya enjoyed talking games this week. Next time you read together, pause on a page and let her point first.',
    generatedAt: DateTime(2026, 10, 25),
  ),

  // Partial week (Oct 12 - 18, 2026)
  '2026-W42': WeeklySummary(
    id: '2026-W42',
    weekStartDate: '2026-10-12',
    weekEndDate: '2026-10-18',
    completedActivityCount: 2,
    observedMilestoneCount: 0,
    totalPlannedActivities: 4,
    domainDistribution: const {
      'cognitive': 0,
      'motor': 1,
      'language': 1,
      'socioEmotional': 0,
    },
    topActivityIds: const ['act-3'],
    reflectionPrompt: 'You and Maya shared quiet moments of connection during everyday routines.',
    generatedAt: DateTime(2026, 10, 18),
  ),

  // Empty week (Matching Figma Screen 2: Oct 5 - 11, 2026)
  '2026-W41': WeeklySummary(
    id: '2026-W41',
    weekStartDate: '2026-10-05',
    weekEndDate: '2026-10-11',
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
    generatedAt: DateTime(2026, 10, 11),
  ),
};
