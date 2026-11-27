import 'package:flutter/foundation.dart';

/// A Philippine city location used for optional Open-Meteo weather hints.
@immutable
class WeatherLocation {
  /// Creates a [WeatherLocation] with display [name] and city coordinates.
  const WeatherLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  /// Display name of the city.
  final String name;

  /// Approximate city-center latitude in decimal degrees.
  final double latitude;

  /// Approximate city-center longitude in decimal degrees.
  final double longitude;

  /// Default city location for Iloilo City.
  static const WeatherLocation iloiloCity = WeatherLocation(
    name: 'Iloilo City',
    latitude: 10.7202,
    longitude: 122.5621,
  );

  /// Supported Philippine cities for optional play-weather guidance.
  static const List<WeatherLocation> philippinesCities = [
    WeatherLocation(name: 'Manila', latitude: 14.5995, longitude: 120.9842),
    iloiloCity,
    WeatherLocation(name: 'Cebu City', latitude: 10.3157, longitude: 123.8854),
    WeatherLocation(name: 'Davao City', latitude: 7.1907, longitude: 125.4553),
    WeatherLocation(name: 'Baguio', latitude: 16.4023, longitude: 120.5960),
  ];

  /// Returns the matching city from [philippinesCities], or `null` if unknown.
  static WeatherLocation? byName(String? name) {
    if (name == null || name.isEmpty) return null;
    final lower = name.toLowerCase();
    for (final city in philippinesCities) {
      if (city.name.toLowerCase() == lower) {
        return city;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeatherLocation &&
        other.name == name &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(name, latitude, longitude);
}

/// A weather advisory hint for indoor or outdoor play planning.
@immutable
class WeatherHint {
  /// Creates a [WeatherHint] describing current play-weather guidance.
  const WeatherHint({
    required this.condition,
    required this.rainChance,
    required this.heatFlag,
    required this.suggestedSetting,
    this.hint,
    required this.attribution,
  });

  /// Creates a [WeatherHint] from a JSON map returned by the catalog API.
  factory WeatherHint.fromJson(Map<String, dynamic> json) {
    final provenance = json['provenance'] as Map<String, dynamic>?;
    return WeatherHint(
      condition: json['condition'] as String? ?? 'unavailable',
      rainChance: (json['rainChance'] as num?)?.toInt() ?? 0,
      heatFlag: json['heatFlag'] as bool? ?? false,
      suggestedSetting: json['suggestedSetting'] as String? ?? 'either',
      hint: json['hint'] as String?,
      attribution:
          provenance?['attribution'] as String? ??
          'Weather data by Open-Meteo.com',
    );
  }

  /// Normalized weather condition label from the forecast service.
  final String condition;

  /// Estimated percentage probability of rain (0 to 100).
  final int rainChance;

  /// Whether elevated heat makes indoor play preferable.
  final bool heatFlag;

  /// Suggested play setting (`indoor`, `outdoor`, or `either`).
  final String suggestedSetting;

  /// Short caregiver-facing weather hint, or `null` when neutral.
  final String? hint;

  /// Required data-source attribution string.
  final String attribution;

  /// Whether current weather data is unavailable.
  bool get isUnavailable => condition == 'unavailable' || hint == null;

  /// Whether the forecast indicates rain, showers, or storms.
  bool get isRainy {
    const rainyConditions = {
      'rain',
      'rainy',
      'showers',
      'drizzle',
      'thunderstorm',
    };
    return rainyConditions.contains(condition.toLowerCase()) ||
        rainChance >= 50;
  }

  /// Serializes this [WeatherHint] to a JSON map.
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
