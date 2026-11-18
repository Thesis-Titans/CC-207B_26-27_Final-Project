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
