/// @docImport 'activity.dart';
library;

/// A planned activity for a child on a given date.
///
/// Mirrors the API `PublicPlan`. Title and domain are not stored on the plan;
/// look them up from the catalog [Activity] by [activityId].
class PlanItem {
  /// Creates a [PlanItem].
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

  /// Unique identifier of the scheduled plan record.
  final String id;

  /// Identifier of the child profile this plan belongs to.
  final String childId;

  /// Identifier of the scheduled catalog [Activity].
  final String activityId;

  /// Local calendar date in `YYYY-MM-DD` form.
  final String scheduledDate;

  /// Plan status (`planned`, `completed`, or `skipped`).
  final String status;

  /// Timestamp when the activity was marked completed, if completed.
  final DateTime? completedAt;

  /// Optional play duration recorded in minutes.
  final int? durationMinutes;

  /// Optional caregiver feedback note on the session.
  final String? feedbackNote;

  /// Timestamp when the plan record was created.
  final DateTime createdAt;

  /// Timestamp when the plan record was last updated.
  final DateTime updatedAt;

  /// Whether this activity has been completed.
  bool get isCompleted => status == 'completed';

  /// Creates a [PlanItem] from a decoded JSON object.
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
