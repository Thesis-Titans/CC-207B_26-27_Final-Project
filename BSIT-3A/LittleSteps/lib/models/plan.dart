/// A planned activity for a child on a given date.
///
/// Mirrors the API `PublicPlan`. Title and domain are not stored on the plan;
/// look them up from the catalog [Activity] by [activityId].
class PlanItem {
  const PlanItem({
    required this.id,
    required this.childId,
    required this.activityId,
    required this.scheduledDate,
    required this.status,
    this.completedAt,
    this.durationMinutes,
    this.feedbackNote,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String childId;
  final String activityId;

  /// Local calendar date in `YYYY-MM-DD` form.
  final String scheduledDate;

  /// One of `planned`, `completed` or `skipped`.
  final String status;
  final DateTime? completedAt;
  final int? durationMinutes;
  final String? feedbackNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether this activity has been completed.
  bool get isCompleted => status == 'completed';

  factory PlanItem.fromJson(Map<String, dynamic> json) {
    return PlanItem(
      id: json['id'] as String,
      childId: json['childId'] as String,
      activityId: json['activityId'] as String,
      scheduledDate: json['scheduledDate'] as String,
      status: json['status'] as String,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      durationMinutes: json['durationMinutes'] as int?,
      feedbackNote: json['feedbackNote'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
