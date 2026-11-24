import 'dart:convert';

// Local in-memory and persistent cache for child profiles, catalog activities, and today's plans.
class LocalDataCache {
  // Creates a [LocalDataCache] with optional pre-populated cache data.
  LocalDataCache({Map<String, dynamic>? initialCache})
    : _store = initialCache != null
          ? Map<String, dynamic>.from(initialCache)
          : <String, dynamic>{};

  // Internal storage mapping cache keys to deserialized JSON data.
  final Map<String, dynamic> _store;

  // Whitelist of API endpoint prefixes permitted for offline local caching.
  static const List<String> _permittedPrefixes = [
    '/api/v1/children',
    '/api/v1/catalog/activities',
    '/api/v1/catalog/books',
  ];

  // Checks whether the given endpoint path is permitted for local offline caching.
  bool isCacheablePath(String path) {
    if (path.contains('/plans')) return true;
    if (RegExp(r'^/api/v1/children/[^/]+/books$').hasMatch(path)) {
      return true;
    }
    for (final prefix in _permittedPrefixes) {
      if (path == prefix || path.startsWith('$prefix?')) return true;
    }
    return false;
  }

  // Generates a normalized cache key from an endpoint path and optional query parameters.
  String generateKey(String path, [Map<String, String>? queryParams]) {
    if (queryParams == null || queryParams.isEmpty) return path;
    final sortedKeys = queryParams.keys.toList()..sort();
    final query = sortedKeys.map((k) => '$k=${queryParams[k]}').join('&');
    return '$path?$query';
  }

  // Retrieves cached data for the specified key if present.
  dynamic get(String key) {
    final raw = _store[key];
    if (raw == null) return null;
    return jsonDecode(jsonEncode(raw));
  }

  // Stores data for the specified key only if the path passes the privacy whitelist.
  void set(String key, dynamic data) {
    final basePath = key.split('?').first;
    if (!isCacheablePath(basePath)) return;
    _store[key] = jsonDecode(jsonEncode(data));
  }

  // Checks whether cached data exists for the given key.
  bool has(String key) => _store.containsKey(key);

  // Removes cached data associated with the given key.
  void remove(String key) => _store.remove(key);

  // Clears all stored cache entries across the application.
  void clear() => _store.clear();

  // Clears all private child records and plans while preserving public catalog cache.
  void clearChildData() {
    _store.removeWhere(
      (key, _) => key.contains('/children') || key.contains('/plans'),
    );
  }

  // Returns the count of currently cached dataset entries.
  int get entryCount => _store.length;
}
