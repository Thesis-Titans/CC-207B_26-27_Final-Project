import 'activity.dart';

/// A suggested play activity with caregiver rationale.
class Recommendation {
  const Recommendation({
    required this.activityId,
    required this.title,
    required this.whyPicked,
    this.activity,
  });

  final String activityId;
  final String title;
  final String whyPicked;
  final Activity? activity;

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      activityId: json['activityId'] as String? ?? '',
      title: json['title'] as String? ?? 'Suggested Activity',
      whyPicked: json['whyPicked'] as String? ?? '',
      activity: json['activity'] != null
          ? Activity.fromJson(json['activity'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A set of play recommendations accompanied by provenance metadata.
class RecommendationResponse {
  const RecommendationResponse({
    required this.suggestions,
    required this.source,
    required this.tier,
    this.badge,
    this.label,
    required this.disclaimer,
  });

  final List<Recommendation> suggestions;
  final String source;
  final int tier;
  final String? badge;
  final String? label;
  final String disclaimer;

  bool get isAiGenerated => tier == 1 && source == 'ai' && badge != null;

  factory RecommendationResponse.fromJson(Map<String, dynamic> json) {
    final rawSuggestions = json['suggestions'] as List<dynamic>? ?? [];
    final suggestions = rawSuggestions
        .map((e) => Recommendation.fromJson(e as Map<String, dynamic>))
        .toList();
    final provenance = json['provenance'] as Map<String, dynamic>?;

    return RecommendationResponse(
      suggestions: suggestions,
      source: json['source'] as String? ?? 'catalog_fallback',
      tier: json['tier'] as int? ?? 3,
      badge: provenance?['badge'] as String?,
      label: provenance?['label'] as String?,
      disclaimer:
          provenance?['disclaimer'] as String? ??
          'Observational play suggestion only. Not developmental assessment.',
    );
  }
}
