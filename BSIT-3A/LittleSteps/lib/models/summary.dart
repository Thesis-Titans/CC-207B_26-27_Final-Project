import 'package:intl/intl.dart';

/// A child's weekly summary of completed activities and observations.
class WeeklySummary {
  /// Creates a [WeeklySummary].
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

  /// ISO week identifier (for example, `2026-W43`).
  final String id;

  /// Monday start date of the week in `YYYY-MM-DD` format.
  final String weekStartDate;

  /// Sunday end date of the week in `YYYY-MM-DD` format.
  final String weekEndDate;

  /// Number of planned activities completed during the week.
  final int completedActivityCount;

  /// Number of milestone observations recorded during the week.
  final int observedMilestoneCount;

  /// Total number of activities scheduled during the week.
  final int totalPlannedActivities;

  /// Count of completed activities grouped by developmental domain key.
  final Map<String, int> domainDistribution;

  /// Identifiers of the most frequently completed activities in the week.
  final List<String> topActivityIds;

  /// Factual, non-diagnostic reflection prompt summarizing the week.
  final String reflectionPrompt;

  /// Timestamp when the weekly summary was generated.
  final DateTime generatedAt;

  /// Whether zero completed activities and zero observations were recorded.
  bool get isEmptyWeek =>
      completedActivityCount == 0 && observedMilestoneCount == 0;

  /// Human-readable date range label (for example, `Oct 19 – 25, 2026`).
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

  /// Creates a [WeeklySummary] from a decoded JSON object.
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

/// Sample weekly summary dataset used for local development, previews, and testing.
final Map<String, WeeklySummary> sampleWeeklySummaries = {
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
