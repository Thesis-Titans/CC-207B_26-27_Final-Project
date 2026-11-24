import '../models/recommendation.dart';
import 'api_client.dart';

/// Client service for requesting AI play recommendations and story activities.
class AiService {
  /// Creates an [AiService] backed by [apiClient].
  AiService({required this.apiClient});

  /// HTTP client used to send authenticated requests to the backend API.
  final ApiClient apiClient;

  /// Requests play suggestions for [ageBand], [setting], [timeMinutes], and [materials].
  ///
  /// Sends only non-identifying play context so child names and private notes
  /// never leave the device in AI prompts.
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
