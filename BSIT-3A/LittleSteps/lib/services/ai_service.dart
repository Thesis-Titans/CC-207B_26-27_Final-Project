import '../models/recommendation.dart';
import 'api_client.dart';

/// Service for requesting play suggestions with catalog fallback.
class AiService {
  AiService({required this.apiClient});

  /// The client used for API requests.
  final ApiClient apiClient;

  /// Requests play suggestions based on age band and available materials.
  Future<RecommendationResponse> getRecommendations({
    required String ageBand,
    String? domain,
    String setting = 'either',
    int timeMinutes = 15,
    List<String> materials = const [],
    String language = 'en',
    int count = 3,
  }) async {
    final body = <String, dynamic>{
      'ageBand': ageBand,
      'setting': setting,
      'timeMinutes': timeMinutes,
      'materials': materials,
      'language': language,
      'count': count,
    };
    if (domain != null) {
      body['domain'] = domain;
    }

    final data = await apiClient.post(
      '/api/v1/ai/recommendations',
      body: body,
    ) as Map<String, dynamic>;

    return RecommendationResponse.fromJson(data);
  }

  /// Requests companion activity ideas for a storybook.
  Future<Map<String, dynamic>> getStoryActivity({
    required String bookTitle,
    List<String> subjects = const [],
    required String ageBand,
  }) async {
    final body = {
      'bookTitle': bookTitle,
      'subjects': subjects,
      'ageBand': ageBand,
    };

    final data = await apiClient.post(
      '/api/v1/ai/story-activity',
      body: body,
    ) as Map<String, dynamic>;

    return data;
  }
}
