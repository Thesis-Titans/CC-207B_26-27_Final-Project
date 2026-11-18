/// A weather advisory hint for indoor or outdoor play planning.
class WeatherHint {
  const WeatherHint({
    required this.condition,
    required this.rainChance,
    required this.heatFlag,
    required this.suggestedSetting,
    this.hint,
    required this.attribution,
  });

  final String condition;
  final int rainChance;
  final bool heatFlag;
  final String suggestedSetting;
  final String? hint;
  final String attribution;

  /// Whether current weather data is unavailable.
  bool get isUnavailable => condition == 'unavailable' || hint == null;

  factory WeatherHint.fromJson(Map<String, dynamic> json) {
    final provenance = json['provenance'] as Map<String, dynamic>?;
    return WeatherHint(
      condition: json['condition'] as String? ?? 'unavailable',
      rainChance: json['rainChance'] as int? ?? 0,
      heatFlag: json['heatFlag'] as bool? ?? false,
      suggestedSetting: json['suggestedSetting'] as String? ?? 'either',
      hint: json['hint'] as String?,
      attribution:
          provenance?['attribution'] as String? ??
          'Weather data by Open-Meteo.com',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'condition': condition,
      'rainChance': rainChance,
      'heatFlag': heatFlag,
      'suggestedSetting': suggestedSetting,
      'hint': hint,
      'provenance': {
        'source': 'Open-Meteo',
        'attribution': attribution,
        'license': 'CC BY 4.0',
      },
    };
  }
}
