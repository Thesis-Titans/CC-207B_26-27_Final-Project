/// A caregiver's saved observation for one milestone prompt.
///
/// The prompt text itself is not stored by the API; [milestoneId] links the
/// observation to a prompt in the app's prompt list.
class MilestoneObservation {
  const MilestoneObservation({
    required this.id,
    required this.childId,
    required this.milestoneId,
    required this.status,
    required this.observedDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String childId;
  final String milestoneId;

  /// One of `observed`, `not_yet_observed` or `not_sure`.
  final String status;

  /// Local calendar date in `YYYY-MM-DD` form.
  final String observedDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether the caregiver has seen the child do this.
  bool get isObserved => status == 'observed';

  factory MilestoneObservation.fromJson(Map<String, dynamic> json) {
    return MilestoneObservation(
      id: json['id'] as String,
      childId: json['childId'] as String,
      milestoneId: json['milestoneId'] as String,
      status: json['status'] as String,
      observedDate: json['observedDate'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
